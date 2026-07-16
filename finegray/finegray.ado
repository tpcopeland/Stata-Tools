*! finegray Version 1.2.0  2026/07/16
*! Fine-Gray competing risks regression
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: eclass (returns results in e())

/*
Basic syntax:
  finegray varlist [if] [in], compete(varname) cause(#) [options]

Description:
  Fits Fine-Gray subdistribution hazard model for competing risks.
  Uses native Mata forward-backward scan algorithm (Kawaguchi et al. 2021).

  Data must be stset with id().

Required options:
  compete(varname)  - Event type variable (0=cens, 1=cause1, 2=cause2, ...)
  cause(#)          - Which event value is cause of interest

Optional options:
  censvalue(#)      - Censoring value (default: 0)
  noshr             - Display log-SHR instead of SHR
  level(cilevel)    - Confidence level
  strata(varlist)   - Stratify censoring distribution
  cluster(varname)  - Clustered standard errors
  norobust          - Model-based SEs instead of default sandwich
  nolog             - Suppress iteration log
  iterate(#)        - Max iterations (default: 200)
  tolerance(#)      - Convergence tolerance (default: 1e-8)

See help finegray for complete documentation
*/

program define finegray, eclass sortpreserve
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    local _cmdline `"finegray `0'"'

    capture noisily {

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax varlist(numeric fv) [if] [in] , ///
        COMPete(varname numeric) CAUse(integer) ///
        [CENSvalue(integer 0) noSHR Level(cilevel) ///
         STRata(varlist numeric) TRUNCstrata(varlist numeric) ///
         CLuster(varname numeric) noROBust ///
         noADJust noLOG BASEHaz ///
         ITERate(integer 200) TOLerance(real 1e-8)]

    * noadjust suppresses the finite-sample correction applied to the sandwich
    * variance; the model-based (norobust) variance has no such correction, so
    * the combination is a contradiction rather than a no-op.
    if "`adjust'" == "noadjust" & "`robust'" == "norobust" {
        display as error "noadjust is not allowed with norobust"
        display as error "the finite-sample adjustment applies to the robust " ///
            "(sandwich) variance only"
        exit 198
    }

    * =========================================================================
    * VALIDATE STSET (must come before marksample references _st)
    * =========================================================================
    capture st_is 2 analysis
    if _rc {
        display as error "data not st; see {helpb stset}"
        exit 119
    }

    * =========================================================================
    * MARK SAMPLE
    * =========================================================================
    marksample touse
    markout `touse' `compete'

    * Stamp the caller's row order NOW, before any egen/gsort/sort in this
    * command can permute it.  Stata (and Mata) break sort ties using a seed
    * that ADVANCES on every sort, so a bare `sort _t' -- _t is heavily tied --
    * hands the engine a different row order on each fit, and the risk-set scan
    * then accumulates in a different floating-point order.  This key makes the
    * pre-engine sort total, so the same data always yields the same estimates.
    tempvar _fg_row0
    quietly gen long `_fg_row0' = _n

    * Save original varlist before FV expansion (for e(fvvarlist))
    local _orig_varlist "`varlist'"

    * Variables whose estimation-sample values define the post-estimation
    * contract. Factor/interactions are reduced to their underlying variables.
    local _fg_sigvars "_t _t0 _d `compete'"
    foreach _sig_tok of local _orig_varlist {
        local _sig_parts = subinstr(subinstr("`_sig_tok'", "##", "#", .), "#", " ", .)
        foreach _sig_part of local _sig_parts {
            if regexm("`_sig_part'", "\.(.+)$") local _sig_part = regexs(1)
            capture confirm numeric variable `_sig_part'
            if !_rc {
                local _sig_seen : list posof "`_sig_part'" in _fg_sigvars
                if `_sig_seen' == 0 local _fg_sigvars "`_fg_sigvars' `_sig_part'"
            }
        }
    }
    foreach _sig_var of local strata {
        local _sig_seen : list posof "`_sig_var'" in _fg_sigvars
        if `_sig_seen' == 0 local _fg_sigvars "`_fg_sigvars' `_sig_var'"
    }
    * truncstrata() variables define the weight design, so they belong in the
    * estimation-data signature: changing them after the fit must make every
    * postestimation command FAIL rather than silently rebuild different groups.
    foreach _sig_var of local truncstrata {
        local _sig_seen : list posof "`_sig_var'" in _fg_sigvars
        if `_sig_seen' == 0 local _fg_sigvars "`_fg_sigvars' `_sig_var'"
    }
    if "`cluster'" != "" {
        local _sig_seen : list posof "`cluster'" in _fg_sigvars
        if `_sig_seen' == 0 local _fg_sigvars "`_fg_sigvars' `cluster'"
    }

    * Mark out missing values in variables referenced by FV specifications
    foreach _fv_tok of local varlist {
        if strpos("`_fv_tok'", ".") > 0 {
            local _mk_tok = subinstr(subinstr("`_fv_tok'", "##", "#", .), "#", " ", .)
            foreach _mk_part of local _mk_tok {
                if regexm("`_mk_part'", "\.(.+)$") {
                    local _mk_var = regexs(1)
                    capture confirm numeric variable `_mk_var'
                    if !_rc markout `touse' `_mk_var'
                }
            }
        }
    }
    if "`strata'" != "" markout `touse' `strata'
    if "`truncstrata'" != "" markout `touse' `truncstrata'
    if "`cluster'" != "" markout `touse' `cluster'

    quietly replace `touse' = 0 if _st != 1

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    if `"`_dta[st_id]'"' == "" {
        display as error "finegray requires stset with id() variable"
        display as error "Example: {cmd:stset time, failure(event) id(id)}"
        exit 198
    }

    * =========================================================================
    * MULTIPLE-RECORD REDUCTION
    * =========================================================================
    * Subjects may contribute multiple in-sample records (delayed entry /
    * (start,stop] intervals / stsplit).  When covariates are constant within
    * subject this is purely a data-shape issue: reduce each subject to a
    * single risk-set unit (earliest entry, latest exit, final status) and let
    * the engine's left-truncation handle the rest.  Genuinely time-varying
    * covariates are NOT supported (the subdistribution hazard is undefined
    * with internal time-varying covariates; cf. stcrreg has no tvc()).
    local _fg_id `"`_dta[st_id]'"'
    local _fg_nrecords = `N'

    tempvar _fg_nrec
    quietly egen long `_fg_nrec' = total(`touse'), by(`_fg_id')
    quietly summarize `_fg_nrec' if `touse', meanonly
    local _fg_maxrec = r(max)

    local _fg_reduced = 0
    local _fg_entryvar ""
    local _fg_entry_pending = 0
    if `_fg_maxrec' > 1 {
        * --- covariate constancy check (raw vars, strata, cluster) ---
        local _fg_checkvars ""
        foreach _cv of local _orig_varlist {
            local _cvtok = subinstr(subinstr("`_cv'", "##", "#", .), "#", " ", .)
            foreach _cp of local _cvtok {
                if regexm("`_cp'", "\.(.+)$") local _cp = regexs(1)
                capture confirm numeric variable `_cp'
                if !_rc {
                    local _seen : list posof "`_cp'" in _fg_checkvars
                    if `_seen' == 0 local _fg_checkvars "`_fg_checkvars' `_cp'"
                }
            }
        }
        foreach _cv of local strata {
            local _seen : list posof "`_cv'" in _fg_checkvars
            if `_seen' == 0 local _fg_checkvars "`_fg_checkvars' `_cv'"
        }
        foreach _cv of local truncstrata {
            local _seen : list posof "`_cv'" in _fg_checkvars
            if `_seen' == 0 local _fg_checkvars "`_fg_checkvars' `_cv'"
        }
        if "`cluster'" != "" {
            local _seen : list posof "`cluster'" in _fg_checkvars
            if `_seen' == 0 local _fg_checkvars "`_fg_checkvars' `cluster'"
        }

        tempvar _fg_sd
        foreach _cv of local _fg_checkvars {
            capture drop `_fg_sd'
            quietly egen double `_fg_sd' = sd(`_cv') if `touse', by(`_fg_id')
            capture assert (abs(`_fg_sd') < 1e-9 | `_fg_sd' >= .) if `touse'
            if _rc {
                display as error "finegray requires covariates constant within id()"
                display as error "covariate `_cv' varies within subject"
                display as error "the subdistribution hazard model is not defined with"
                display as error "time-varying covariates; use {help stcox} for a"
                display as error "cause-specific model with time-varying covariates"
                exit 198
            }
        }

        * --- gap / overlap check: intervals must be contiguous within id ---
        * Covered follow-up time per subject must equal max(_t) - min(_t0).
        tempvar _fg_len _fg_maxt _fg_mint0
        quietly egen double `_fg_len' = total(cond(`touse', _t - _t0, 0)), ///
            by(`_fg_id')
        quietly egen double `_fg_maxt' = max(cond(`touse', _t, .)), by(`_fg_id')
        quietly egen double `_fg_mint0' = min(cond(`touse', _t0, .)), by(`_fg_id')
        capture assert reldif(`_fg_len', `_fg_maxt' - `_fg_mint0') < 1e-7 ///
            if `touse' & (`_fg_maxt' - `_fg_mint0') > 0
        if _rc {
            display as error "finegray: subject records have gaps or overlaps"
            display as error "each subject's intervals must be contiguous"
            display as error "(no gaps or overlapping time spans); collapse to one"
            display as error "record per subject before fitting"
            exit 198
        }

        * --- claim the entry-time name, but do not write it yet ---
        * Post-estimation (finegray_cif, finegray_predict ci/schoenfeld,
        * finegray_phtest, bootstrap refits) recomputes risk sets from the
        * data; the kept record's own _t0 is its last interval start, so the
        * true entry must survive outside this program's preserve block.
        * Creating _fg_entry here would mutate the dataset BEFORE the input
        * validation below: a validation failure then drops the column in the
        * cleanup zone while a prior fit's e() still refers to it.  Check the
        * name is available now (a pure error path), and materialise the
        * column only once validation has passed.
        capture confirm variable _fg_entry
        if !_rc & `"`_dta[_finegray_entryvar]'"' != "_fg_entry" {
            display as error "variable _fg_entry already exists"
            display as error "finegray uses this name to record subject entry times"
            display as error "for multiple-record data; rename or drop it before running finegray"
            exit 198
        }
        local _fg_entry_pending = 1

        * --- reduce: keep the record at max(_t) per subject ---
        tempvar _fg_obs _fg_seen _fg_surv
        gen long `_fg_obs' = _n
        gsort `_fg_id' -_t -_d -`_fg_obs'
        by `_fg_id': gen long `_fg_seen' = sum(`touse')
        gen byte `_fg_surv' = (`touse' & `_fg_seen' == 1)
        quietly replace `touse' = 0 if !`_fg_surv'

        quietly count if `touse'
        local N = r(N)
        local _fg_reduced = 1
        display as text "(note: `_fg_nrecords' records reduced to `N' subjects)"
    }

    * Delayed entry is a property of the SUBJECT, not of the record: with
    * (start, stop] intervals every record after the first has _t0 > 0 without any
    * left truncation at all.  A subject has delayed entry only if its EARLIEST
    * entry is positive.  This flag selects the weight (A = G*H vs A = G) and is
    * reported in e(lt_weight), so getting it wrong silently switches estimators.
    *
    * Derived from quantities the reduction already computed.  An `egen ... by()`
    * here would RE-SORT the data, permuting records tied on _t and changing the
    * scan's floating-point accumulation order -- which perturbs every no-delayed-
    * entry result in its last digits.  Gate Z-perf #3 caught exactly that.
    if `_fg_reduced' {
        quietly count if `touse' & `_fg_mint0' > 0 & !missing(`_fg_mint0')
    }
    else {
        quietly count if `touse' & _t0 > 0
    }
    local _fg_has_lt = (r(N) > 0)

    if "`truncstrata'" != "" & !`_fg_has_lt' {
        display as error "truncstrata() requires delayed entry"
        display as error "no subject in the estimation sample enters after time 0, " ///
            "so there is no entry distribution to stratify"
        display as error "stset with enter() to specify delayed entry"
        exit 198
    }

    * =========================================================================
    * VALIDATE INPUTS
    * =========================================================================
    if `cause' == `censvalue' {
        display as error "cause() and censvalue() must differ"
        exit 198
    }

    if `iterate' < 1 {
        display as error "iterate() must be a positive integer"
        exit 198
    }
    * syntax's real type ACCEPTS a missing value, and `. <= 0' is false in
    * Stata (missing sorts above any number), so a bare `<= 0' test lets
    * tolerance(.) through -- and every convergence comparison against a
    * missing tolerance is then vacuously true.  iterate(.) is already rejected
    * by syntax's integer type; mirror that here.
    if missing(`tolerance') | `tolerance' <= 0 {
        display as error "tolerance() must be a positive number"
        exit 198
    }

    * Check compete variable has cause value
    quietly count if `compete' == `cause' & `touse'
    local N_fail = r(N)
    if `N_fail' == 0 {
        display as error "no observations with compete() == `cause'"
        exit 198
    }

    * Count competing events
    quietly count if `compete' != `censvalue' & `compete' != `cause' & `touse'
    local N_compete = r(N)

    * Count censored
    quietly count if `compete' == `censvalue' & `touse'
    local N_cens = r(N)

    * FG-M06: the "no competing events" and "no censored observations" guards that
    * used to sit here are GONE.  Both are legitimate limiting cases of the model,
    * not user errors, and the combined-weight path handles each exactly:
    *
    *   no competing events -> no subject is ever retained in a risk set past its
    *     own exit, so the subdistribution risk set IS the ordinary risk set and the
    *     estimator collapses to Cox on cause `cause'.  (Verified against stcox.)
    *   no censoring -> G(t) == 1 everywhere, so A == H (== 1 too without delayed
    *     entry) and every weight is 1.  Complete follow-up is not a defect.
    *
    * They were refused before only because the old G-only weight path had not been
    * shown to degrade gracefully.  Refusing to fit a model that is perfectly well
    * defined is its own kind of wrong answer.  Both cases are gated in
    * qa/test_finegray_zzf.do.

    * Validate compete/stset consistency (both directions)
    quietly count if _d == 0 & `compete' != `censvalue' & `touse'
    if r(N) > 0 {
        display as error "compete() and stset failure indicator do not match"
        display as error "_d==0 but compete() != `censvalue' for `r(N)' observations"
        exit 198
    }

    quietly count if _d == 1 & `compete' == `censvalue' & `touse'
    if r(N) > 0 {
        display as error "compete() and stset failure indicator do not match"
        display as error "_d==1 but compete() == `censvalue' for `r(N)' observations"
        exit 198
    }

    if "`level'" == "" local level = c(level)

    * =========================================================================
    * MATERIALISE THE ENTRY-TIME COLUMN (multi-record fits only)
    * =========================================================================
    * Deferred from the reduction step above: every check that can reject this
    * fit has now run, so writing the package-owned column here cannot strand a
    * prior fit's e() behind a dropped variable.
    if `_fg_entry_pending' {
        capture confirm variable _fg_entry
        if !_rc {
            display as text "(note: replacing existing variable _fg_entry)"
            quietly drop _fg_entry
        }
        quietly gen double _fg_entry = `_fg_mint0'
        label variable _fg_entry ///
            "finegray: earliest subject entry time (multi-record reduction)"
        local _fg_entryvar "_fg_entry"
    }

    * =========================================================================
    * EXPAND FACTOR VARIABLES (fvrevar-based: supports i., ib#., ##, #, c.)
    * =========================================================================
    local _fv_created ""
    local _prev_estimated `"`_dta[_finegray_estimated]'"'
    local _prev_fv_created `"`_dta[_finegray_fvvars]'"'
    local _prev_entryvar `"`_dta[_finegray_entryvar]'"'
    local _has_fv = 0
    local _fv_nrefs = 0

    * Input validation above leaves a prior successful fit intact. Once this
    * new fit begins mutating package-owned columns, invalidate the old state
    * first so a failed re-fit cannot masquerade as the previous success.
    char _dta[_finegray_estimated] ""
    char _dta[_finegray_compete] ""
    char _dta[_finegray_cause] ""
    char _dta[_finegray_covars] ""
    char _dta[_finegray_fvvars] ""
    char _dta[_finegray_fvvarlist] ""
    char _dta[_finegray_entryvar] ""

    * Check if any FV operators present
    foreach _fv_tok of local varlist {
        if strpos("`_fv_tok'", ".") > 0 {
            local _has_fv = 1
            continue, break
        }
    }

    * Clean up the entry-time variable from any prior finegray run when this
    * run did not just (re)create it in the reduction step above.
    if `"`_prev_estimated'"' == "1" & `"`_prev_entryvar'"' != "" ///
        & "`_prev_entryvar'" != "`_fg_entryvar'" {
        capture confirm variable `_prev_entryvar'
        if !_rc quietly drop `_prev_entryvar'
    }

    * Clean up FV variables from any prior finegray run, unconditionally.
    * This ensures stale _fg_* columns are dropped even when the new run
    * does not use factor variables.
    if `"`_prev_estimated'"' == "1" & `"`_prev_fv_created'"' != "" {
        local _drop_prev ""
        foreach _old_fg of local _prev_fv_created {
            capture confirm variable `_old_fg'
            if !_rc local _drop_prev "`_drop_prev' `_old_fg'"
        }
        if "`_drop_prev'" != "" {
            display as text "(note: dropping prior finegray FV variables)"
            quietly drop `_drop_prev'
        }
    }

    if `_has_fv' {
        * Get semantic expansion (includes base markers like 1b.race)
        fvexpand `varlist' if `touse'
        local _fv_semantic `r(varlist)'

        * Get actual variable columns (one per term, including base)
        fvrevar `varlist' if `touse'
        local _fv_actual `r(varlist)'

        * Verify counts match (both include base terms)
        local _n_sem : word count `_fv_semantic'
        local _n_act : word count `_fv_actual'
        if `_n_sem' != `_n_act' {
            display as error "internal error: fvexpand/fvrevar term count mismatch"
            display as error "(`_n_sem' semantic terms vs `_n_act' fvrevar variables)"
            exit 198
        }

        * Build final varlist and create persistent _fg_ variables
        local _fv_final ""

        forvalues _i = 1/`_n_sem' {
            local _term : word `_i' of `_fv_semantic'
            local _var : word `_i' of `_fv_actual'

            * Skip base categories (marked with Nb. in fvexpand output)
            if regexm("`_term'", "[0-9]+b\.") {
                continue
            }

            * If fvrevar returned original variable (not tempvar), use directly
            if substr("`_var'", 1, 2) != "__" {
                local _fv_final "`_fv_final' `_var'"
                continue
            }

            * Generate _fg_ variable name from FV term
            * Parse parts separated by # : N.var → var_N, c.var → var
            local _fg_parts ""
            local _remaining "`_term'"
            while "`_remaining'" != "" {
                local _hashpos = strpos("`_remaining'", "#")
                if `_hashpos' > 0 {
                    local _part = substr("`_remaining'", 1, `_hashpos' - 1)
                    local _remaining = substr("`_remaining'", `_hashpos' + 1, .)
                }
                else {
                    local _part "`_remaining'"
                    local _remaining ""
                }

                if regexm("`_part'", "^([0-9]+)\.(.+)$") {
                    if "`_fg_parts'" != "" local _fg_parts "`_fg_parts'X"
                    local _fg_parts "`_fg_parts'`=regexs(2)'_`=regexs(1)'"
                }
                else if regexm("`_part'", "^c\.(.+)$") {
                    if "`_fg_parts'" != "" local _fg_parts "`_fg_parts'X"
                    local _fg_parts "`_fg_parts'`=regexs(1)'"
                }
                else {
                    if "`_fg_parts'" != "" local _fg_parts "`_fg_parts'X"
                    local _fg_parts "`_fg_parts'`_part'"
                }
            }

            local _fg_name "_fg_`_fg_parts'"
            if length("`_fg_name'") > 32 {
                local _fg_name = substr("`_fg_name'", 1, 32)
            }

            * Detect name collision from truncation within this run
            local _collision : list posof "`_fg_name'" in _fv_final
            if `_collision' > 0 {
                display as error "factor variable names too similar"
                display as error "`_fg_name' collides after truncation to 32 characters"
                display as error "use shorter variable names or fewer interaction levels"
                exit 198
            }

            * Check for existing _fg_ variable in dataset
            capture confirm variable `_fg_name'
            if !_rc {
                local _prev_match : list posof "`_fg_name'" in _prev_fv_created
                if `_prev_match' > 0 {
                    * Prior finegray-created variable — safe to replace
                    display as text "(note: replacing existing variable `_fg_name')"
                    quietly drop `_fg_name'
                }
                else {
                    display as error "variable `_fg_name' already exists"
                    display as error "rename or drop it before running finegray with factor variables"
                    exit 198
                }
            }

            * Create persistent copy
            quietly generate double `_fg_name' = `_var'
            local _fv_created "`_fv_created' `_fg_name'"

            * Label: build from value labels (factors) and variable labels (continuous)
            * Parse each part of the term to build a descriptive label
            local _lbl_full ""
            local _lbl_remaining "`_term'"
            while "`_lbl_remaining'" != "" {
                local _lbl_hashpos = strpos("`_lbl_remaining'", "#")
                if `_lbl_hashpos' > 0 {
                    local _lbl_part = substr("`_lbl_remaining'", 1, `_lbl_hashpos' - 1)
                    local _lbl_remaining = substr("`_lbl_remaining'", `_lbl_hashpos' + 1, .)
                }
                else {
                    local _lbl_part "`_lbl_remaining'"
                    local _lbl_remaining ""
                }

                if regexm("`_lbl_part'", "^([0-9]+)\.(.+)$") {
                    * Factor part: use value label if available
                    local _lp_lev = regexs(1)
                    local _lp_var = regexs(2)
                    local _lp_vallbl : value label `_lp_var'
                    local _lp_txt ""
                    if "`_lp_vallbl'" != "" {
                        local _lp_txt : label `_lp_vallbl' `_lp_lev'
                    }
                    if `"`_lp_txt'"' == "" local _lp_txt "`_lp_lev'"
                    * Find reference category for (vs. ref) suffix
                    local _lp_ref ""
                    foreach _bterm of local _fv_semantic {
                        if regexm("`_bterm'", "^([0-9]+)b\.`_lp_var'$") {
                            local _lp_ref = regexs(1)
                        }
                    }
                    if "`_lp_ref'" != "" {
                        local _lp_reftxt ""
                        if "`_lp_vallbl'" != "" {
                            local _lp_reftxt : label `_lp_vallbl' `_lp_ref'
                        }
                        if `"`_lp_reftxt'"' == "" local _lp_reftxt "`_lp_ref'"
                        local _lp_txt `"`_lp_txt' (vs. `_lp_reftxt')"'
                    }
                    if `"`_lbl_full'"' != "" local _lbl_full `"`_lbl_full' # "'
                    local _lbl_full `"`_lbl_full'`_lp_txt'"'
                }
                else if regexm("`_lbl_part'", "^c\.(.+)$") {
                    * Continuous part: use variable label if available
                    local _lp_var = regexs(1)
                    local _lp_txt : variable label `_lp_var'
                    if `"`_lp_txt'"' == "" local _lp_txt "`_lp_var'"
                    if `"`_lbl_full'"' != "" local _lbl_full `"`_lbl_full' # "'
                    local _lbl_full `"`_lbl_full'`_lp_txt'"'
                }
                else {
                    if `"`_lbl_full'"' != "" local _lbl_full `"`_lbl_full' # "'
                    local _lbl_full `"`_lbl_full'`_lbl_part'"'
                }
            }
            label variable `_fg_name' `"`_lbl_full'"'

            local _fv_final "`_fv_final' `_fg_name'"
        }

        local varlist : list retokenize _fv_final

        * Extract reference categories from base terms for display
        foreach _term of local _fv_semantic {
            if regexm("`_term'", "^([0-9]+)b\.(.+)$") & !strpos("`_term'", "#") {
                local _ref_lev = regexs(1)
                local _ref_var = regexs(2)
                local ++_fv_nrefs
                local _ref_vallbl : value label `_ref_var'
                local _ref_txt ""
                if "`_ref_vallbl'" != "" {
                    local _ref_txt : label `_ref_vallbl' `_ref_lev'
                }
                if `"`_ref_txt'"' == "" local _ref_txt "`_ref_lev'"
                local _fv_refinfo`_fv_nrefs' `"i.`_ref_var': `_ref_txt' (`_ref_var'==`_ref_lev')"'
            }
        }
    }

    * The unpenalized Fine-Gray likelihood cannot identify constant or exactly
    * collinear columns.  Do not silently substitute arbitrary ridge estimates:
    * reject the specification with the offending expanded columns named.
    quietly _rmcoll `varlist' if `touse', forcedrop
    if r(k_omitted) > 0 {
        local _fg_identified `r(varlist)'
        local _fg_omitted : list varlist - _fg_identified
        if "`_fv_created'" != "" quietly drop `_fv_created'
        display as error "finegray covariates are not full rank"
        display as error "constant or collinear term(s): `_fg_omitted'"
        display as error "remove or recode these terms and fit the model again"
        exit 459
    }

    * =========================================================================
    * LOAD MATA ENGINE
    * =========================================================================
    capture mata: _finegray_mata_ok()
    * probe MATA, not a Stata program: `mata clear' drops Mata functions but
    * leaves Stata programs standing, so a program sentinel says "loaded" when
    * the engine is gone and the next Mata call dies with r(3499).
    if _rc {
        capture findfile _finegray_mata.ado
        if _rc == 0 {
            run "`r(fn)'"
        }
        else {
            display as error "_finegray_mata.ado not found; reinstall finegray"
            exit 111
        }
    }

    * =========================================================================
    * FIT MODEL (Mata forward-backward scan engine)
    * =========================================================================
    local vce_type "robust"
    if "`cluster'" != "" local vce_type "cluster"
    else if "`robust'" == "norobust" local vce_type "model"

    preserve
    local _rc_fit = 0

    capture noisily {
        quietly keep if `touse'

        * Use each subject's earliest entry time after multi-record reduction
        * (engine left-truncation consumes _t0). Non-destructive: inside preserve.
        if `_fg_reduced' quietly replace _t0 = _fg_entry

        * Combine multiple strata variables into a single group variable
        local _byg_mata "`strata'"
        if "`strata'" != "" {
            local _byg_nvar : word count `strata'
            if `_byg_nvar' > 1 {
                tempvar _byg_grp
                quietly egen long `_byg_grp' = group(`strata')
                local _byg_mata "`_byg_grp'"
            }
        }

        * Truncation strata: the entry distribution H is estimated within these
        * groups.  Empty => one group => H == 1 => the combined weight A collapses
        * to G and the no-delayed-entry path is bit-identical to previous releases.
        local _tg_mata ""
        if "`truncstrata'" != "" {
            tempvar _tg_grp
            _finegray_weight_groups, truncstrata(`truncstrata') ///
                tgname(`_tg_grp') touse(`touse')
            local _tg_mata "`_tg_grp'"
        }

        * ---- Support boundary for the combined-weight design.
        *
        * The factorized weights are EVALUATED for each observed joint (censoring x
        * truncation) stratum: G is estimated within censoring strata and H within
        * truncation strata.  Every observed combination must still carry enough
        * support to make its configured weight usable.  Both limits are hard
        * failures: silently pooling groups the user asked to keep separate would
        * change the estimand without saying so, which is the failure class this
        * package treats as worst.
        *
        * Enforced only on the ZZF (delayed-entry) branch.  A right-censoring fit
        * with many strata() levels is unchanged released behaviour, and turning
        * that into an error would break existing analyses -- the no-LT path is
        * required to stay bit-identical, and an error is not bit-identical.
        *
        * BREAKING CHANGE, stated so nobody rediscovers it as a bug: a delayed-entry
        * fit with more than 100 strata() levels used to run and now hard-errors,
        * EVEN WITHOUT truncstrata().  Under delayed entry the weights are A = G*H,
        * and A is evaluated for every observed joint group, so 150 censoring strata
        * are 150 weight strata whether or not the user asked for entry strata.
        * Guarded by Z21/Z22.
        if `_fg_has_lt' {
            tempvar _fg_jgrp _fg_jn
            if "`_byg_mata'" == "" & "`_tg_mata'" == "" {
                quietly gen byte `_fg_jgrp' = 1
            }
            else {
                quietly egen long `_fg_jgrp' = group(`_byg_mata' `_tg_mata')
            }
            quietly summarize `_fg_jgrp', meanonly
            local _fg_njgrp = r(max)

            * Name only the options that actually formed the groups.  Blaming a
            * cross-classification with truncstrata() when the user never typed
            * truncstrata() sends them looking for an option they did not use.
            *
            * Keep each line short.  Stata wraps display output at linesize, and
            * test Z22 greps this text -- a message that wraps mid-token would make
            * the guard's own regression test unfalsifiable.
            if `_fg_njgrp' > 100 {
                display as error "too many weight strata: `_fg_njgrp' observed joint groups (limit 100)"
                if "`_byg_mata'" != "" & "`_tg_mata'" != "" {
                    display as error "strata() and truncstrata() are cross-classified:"
                    display as error "the weight strata are their observed combinations"
                }
                else if "`_tg_mata'" != "" {
                    display as error "the weight strata are the observed levels of truncstrata()"
                }
                else {
                    display as error "the weight strata are the observed levels of strata()"
                    display as error "under delayed entry the entry distribution is estimated"
                    display as error "within each censoring stratum, so strata() alone bounds it"
                }
                display as error "this limit applies to delayed-entry fits only"
                display as error "use coarser grouping variables"
                exit 459
            }

            quietly bysort `_fg_jgrp': gen long `_fg_jn' = _N
            quietly summarize `_fg_jn', meanonly
            local _fg_minjn = r(min)

            if `_fg_minjn' < 20 {
                display as error "a weight stratum has only `_fg_minjn' subjects (minimum 20)"
                display as error "the factorized weight is evaluated within each observed joint"
                display as error "stratum; too few subjects makes that configured weight unusable"
                display as error "use coarser grouping variables"
                exit 459
            }
        }

        sort _t `_fg_row0'

        if "`log'" != "nolog" {
            display as text "Fitting Fine-Gray model..."
        }

        mata: _finegray_engine( ///
            "`varlist'", "`compete'", `cause', `censvalue', ///
            "`_byg_mata'", "`_tg_mata'", "`vce_type'", "`cluster'", ///
            `iterate', `tolerance', ("`log'" != "nolog"), ///
            ("`adjust'" != "noadjust"), ("`basehaz'" != ""))
    }

    local _rc_fit = _rc
    restore

    if `_rc_fit' {
        exit `_rc_fit'
    }

    * =========================================================================
    * RETRIEVE AND POST E() RESULTS
    * =========================================================================

    tempname b V
    matrix `b' = _finegray_b
    matrix `V' = _finegray_V

    * Column names from varlist
    local cnames ""
    foreach v of local varlist {
        local cnames "`cnames' `v'"
    }
    matrix colnames `b' = `cnames'
    matrix colnames `V' = `cnames'
    matrix rownames `V' = `cnames'

    local _fg_ll       = _finegray_ll[1,1]
    local _fg_ll_0     = _finegray_ll_0[1,1]
    local _fg_chi2     = _finegray_chi2[1,1]
    local _fg_df_m     = _finegray_df_m[1,1]
    local _fg_conv     = _finegray_conv[1,1]
    local _fg_rank     = _finegray_rank[1,1]
    local _fg_nclust   = .
    capture local _fg_nclust = _finegray_nclust[1,1]
    local _fg_nclust_rc = _rc
    if "`cluster'" != "" & `_fg_nclust_rc' {
        display as error "internal cluster-count result is unavailable"
        exit 498
    }

    * `_fg_warnstrata' is set directly in this scope by _finegray_weight_diag via
    * st_local (a string cannot ride back in a matrix). It is "" when nothing was
    * flagged, and on the no-LT branch where the diagnostics do not run.

    * Compute p-value from chi2
    if `_fg_chi2' != . & `_fg_df_m' > 0 {
        local _fg_p = chi2tail(`_fg_df_m', `_fg_chi2')
    }
    else {
        local _fg_p = .
    }

    * Post results
    ereturn post `b' `V', obs(`N') esample(`touse') depname("`compete'") properties(b V)

    ereturn scalar N = `N'
    ereturn scalar N_fail = `N_fail'
    ereturn scalar N_compete = `N_compete'
    ereturn scalar N_cens = `N_cens'
    ereturn scalar ll = `_fg_ll'
    ereturn scalar ll_0 = `_fg_ll_0'
    ereturn scalar chi2 = `_fg_chi2'
    ereturn scalar p = `_fg_p'
    ereturn scalar df_m = `_fg_df_m'
    ereturn scalar rank = `_fg_rank'
    if "`cluster'" != "" ereturn scalar N_clust = `_fg_nclust'
    ereturn scalar converged = `_fg_conv'
    ereturn scalar level = `level'
    ereturn scalar cause = `cause'
    ereturn scalar censvalue = `censvalue'
    ereturn scalar iterate = `iterate'
    ereturn scalar tolerance = `tolerance'

    ereturn local cmd "finegray"
    ereturn local cmdline `"`_cmdline'"'

    * Refit command line for the bootstrap paths in finegray_cif /
    * finegray_predict.  e(cmdline) is the user's command AS TYPED and must stay
    * that way, but a refit runs on data already restricted to e(sample) and
    * then resampled, so replaying an `if'/`in' qualifier there is at best
    * redundant and, for `in' (or any _n-dependent `if'), plainly wrong: after
    * `finegray x in 101/200' the resampled dataset has 100 rows, `in 101/200'
    * selects nothing, and every replication fails with rc 498.  Rebuild the
    * line from the parsed options with no sample qualifier.
    * Every option that changes e(b) MUST be replayed here.  e(refitcmd) is what
    * finegray_cif's bootstrap re-issues on each resample, and a dropped fit option
    * does not error there: the refit converges, its covariates still match, so the
    * replication is ACCEPTED and the bootstrap silently describes a DIFFERENT
    * estimator than the point estimate it is wrapped around.
    *
    * truncstrata() was missing here, which meant a bootstrapped ZZF fit resampled
    * the POOLED-weight estimator.  Guarded by Z24, which does not check for the
    * option by name -- it asserts that running e(refitcmd) reproduces e(b), so any
    * future fit option dropped from this list fails the test on its own.
    *
    * noshr and level() are deliberately absent: both are display-only and cannot
    * move e(b).
    local _refitcmd `"finegray `_orig_varlist', compete(`compete') cause(`cause') censvalue(`censvalue') iterate(`iterate') tolerance(`tolerance') nolog"'
    if "`strata'" != ""          local _refitcmd `"`_refitcmd' strata(`strata')"'
    if "`truncstrata'" != ""     local _refitcmd `"`_refitcmd' truncstrata(`truncstrata')"'
    if "`cluster'" != ""         local _refitcmd `"`_refitcmd' cluster(`cluster')"'
    if "`robust'" == "norobust"  local _refitcmd `"`_refitcmd' norobust"'
    if "`adjust'" == "noadjust"  local _refitcmd `"`_refitcmd' noadjust"'
    ereturn local refitcmd `"`_refitcmd'"'

    ereturn local predict "finegray_predict"
    ereturn local depvar "`compete'"
    ereturn local compete "`compete'"
    ereturn local covariates "`varlist'"
    if `_has_fv' ereturn local fvvarlist "`_orig_varlist'"
    * The fit-time factor expansion, INCLUDING base terms (1b.grp).  This is the
    * semantic record of which level each coefficient belongs to.  Post-estimation
    * must align factor terms against this by LEVEL VALUE; re-expanding the
    * current data and matching positionally silently applies the fitted
    * coefficients to whatever levels happen to be present now.
    if `_has_fv' ereturn local fvsemantic "`_fv_semantic'"
    if "`strata'" != "" ereturn local strata "`strata'"
    if "`truncstrata'" != "" ereturn local truncstrata "`truncstrata'"
    if "`cluster'" != "" ereturn local clustvar "`cluster'"

    * Combined-weight contract.  lt_weight names the weight actually computed:
    *   right_censoring : no delayed entry; A == G; identical to prior releases
    *   zzf1_geskus       : one weight stratum; Geskus product-limit form
    *   zzf1_stratified   : ZZF eq. 7 pooled-stabilizer form; strata() and
    *                       truncstrata() name the SAME grouping -- the paper's
    *                       stratified nonparametric construction
    *   zzf1_factorized   : ZZF eq. 7 machinery, but strata() and truncstrata()
    *                       name DIFFERENT groupings (including one side left
    *                       unspecified): G is estimated within strata(), H
    *                       within truncstrata(), and the components multiply.
    *                       This is a package extension, NOT attributed to Zhang
    *                       et al.; it is valid only when entry and censoring are
    *                       independent within each joint cell.  It is named apart
    *                       from zzf1_stratified because its validity conditions
    *                       differ, so a consumer can branch on it.
    * "Same grouping" compares the sorted variable lists: order does not change
    * the partition egen group() forms, so a re-ordered strata() is still ZZF.
    * _fg_njgrp is defined only on the delayed-entry branch, so every reference
    * to it stays inside `if _fg_has_lt'; _fg_factorized is initialized here so
    * the fit-time note below can test it unconditionally.
    local _fg_factorized = 0
    if `_fg_has_lt' {
        if `_fg_njgrp' > 1 {
            local _fg_strata_sorted : list sort strata
            local _fg_trunc_sorted  : list sort truncstrata
            if `"`_fg_strata_sorted'"' != `"`_fg_trunc_sorted'"' ///
                local _fg_factorized = 1
            if `_fg_factorized' ereturn local lt_weight "zzf1_factorized"
            else                ereturn local lt_weight "zzf1_stratified"
        }
        else ereturn local lt_weight "zzf1_geskus"
    }
    else ereturn local lt_weight "right_censoring"

    * LT variance contract.  lt_vce names the variance actually computed on the
    * delayed-entry branch, so a consumer never has to infer it from the option
    * list.  Adjudicated by Gate Z-inference (qa/validation_finegray_zzf_coverage.do),
    * which measures 95% coverage against a known truth across two truncation
    * intensities and two sample sizes:
    *   model_based    inverse information, no sandwich (Geskus 2011 p.44)
    *   fg_sandwich    Fine-Gray (1999) eq. 7-8 sandwich, carrying A = G(t-)H(t-);
    *                  cluster-robust when cluster() is given
    *   not_applicable no delayed entry -- the right-censoring branch is unchanged
    *                  from prior releases and its variance is not at issue here
    * nuisance_adjusted (the ZZF two-part influence function) is NOT implemented:
    * its explicit form is in ZZF (2011) Appendix B, whose display equations are
    * images in every copy obtainable, and it is not being written from memory.
    * See literature/_requested.md.
    if !`_fg_has_lt'                      ereturn local lt_vce "not_applicable"
    else if "`robust'" == "norobust"      ereturn local lt_vce "model_based"
    else                                  ereturn local lt_vce "fg_sandwich"

    * Weight-sensitivity diagnostics, computed once by _finegray_weight_diag over
    * the cells the scan ACTUALLY consults (a stratum's A may collapse in a tail
    * it carries no competing mass into; that cell is never divided by).
    *   N_weight_strata : observed joint (censoring x truncation) strata
    *   min_weight_prob : smallest consulted A
    *   max_lt_weight   : largest retained subject-by-cause-time weight
    *   N_prob_warn     : consulted A cells below 1e-10
    *   N_weight_warn   : retained weights above 1e6
    *   weight_warn_strata : joint-group codes contributing a flagged cell/weight
    * NOT wrapped in -capture-.  The engine posts these unconditionally, so a
    * missing matrix means the weight diagnostics did not run -- and a silent
    * e(min_weight_prob) == . would be indistinguishable from "no weight was ever
    * near zero", which is the reassuring reading of a broken contract.  Fail loudly.
    ereturn scalar N_weight_strata = _finegray_nwstrata[1,1]
    ereturn scalar min_weight_prob = _finegray_minprob[1,1]
    ereturn scalar max_lt_weight   = _finegray_maxwt[1,1]
    ereturn scalar N_prob_warn     = _finegray_nprobwarn[1,1]
    ereturn scalar N_weight_warn   = _finegray_nwtwarn[1,1]
    ereturn local weight_warn_strata "`_fg_warnstrata'"
    * VCE type: cluster > robust (default) > oim (norobust)
    if "`cluster'" != "" {
        ereturn local vce "cluster"
    }
    else if "`robust'" != "norobust" {
        ereturn local vce "robust"
    }
    else {
        ereturn local vce "oim"
    }
    ereturn local title "Fine-Gray competing risks regression"
    if `_has_fv' {
        ereturn local marginsok ""
    }
    else {
        ereturn local marginsok "xb"
    }

    local _sig_entry_seen = 0
    if "`_fg_entryvar'" != "" {
        local _sig_entry_seen : list posof "`_fg_entryvar'" in _fg_sigvars
        if `_sig_entry_seen' == 0 local _fg_sigvars "`_fg_sigvars' `_fg_entryvar'"
    }
    * Package-owned _fg_* design columns are deliberately NOT in this signature.
    * They are derived from the raw factor variables, and post-estimation is
    * allowed to rebuild them when they have been dropped -- putting them here
    * would turn a supported `drop _fg_*' into a hard error.  A _fg_ column that
    * is PRESENT but no longer matches what the fit-time expansion implies is a
    * different matter, and _finegray_check_data verifies that separately
    * (flipping _fg_grp_2 moved the CIF from 0.18367237 to 0.18251435 at rc 0).
    quietly _datasignature `_fg_sigvars' if e(sample), nodefault nonames
    ereturn local datasignature `"`r(datasignature)'"'
    ereturn local datasignaturevars "`_fg_sigvars'"

    * e(basehaz) carries one row per distinct cause-event time, so K is roughly
    * n/2.  Creating ANY K-row Stata matrix is O(K^2) -- Stata builds the
    * dimension-name stripe quadratically, and it hits every route (st_matrix,
    * mkmat, plain copy, transpose, submatrix) alike: 38.6 s of the 95.0 s fit at
    * n = 200,000.  That round trip was the package's ENTIRE superlinearity
    * (slope 1.65 with it, 1.05 without), so it is now opt-in via basehaz.
    * Postestimation never needs it -- finegray_cif and finegray_predict rebuild
    * the same curve in Mata -- and `predict, basecshazard' gives the baseline as
    * a VARIABLE, which is O(n) and is the form stcrreg users already know.
    * ereturn MOVES a named matrix rather than copying it (free: 0.02 s at
    * K = 40,000), so post the Mata-built matrix directly.  The cleanup loop below
    * is a `capture matrix drop', so the moved-away name is not an error.
    if "`basehaz'" != "" {
        capture confirm matrix _finegray_basehaz
        if _rc == 0 {
            ereturn matrix basehaz = _finegray_basehaz
        }
    }

    * The key to the Mata baseline cache (see _finegray_bh_store).  The curve
    * itself lives in Mata, where it costs nothing; this is only its receipt.  A
    * consumer must present this seq to get the cache back, so a stale curve from
    * a PREVIOUS fit can never be used to answer for this one -- that would be a
    * wrong CIF at rc 0, which is the failure class that matters.
    ereturn local bh_seq "`_fg_bh_seq'"

    * Store dataset chars for predict
    char _dta[_finegray_estimated] "1"
    char _dta[_finegray_compete]   "`compete'"
    char _dta[_finegray_cause]     "`cause'"
    char _dta[_finegray_covars]    "`varlist'"
    char _dta[_finegray_fvvars]    "`_fv_created'"
    char _dta[_finegray_entryvar]  "`_fg_entryvar'"
    if `_has_fv' {
        char _dta[_finegray_fvvarlist] "`_orig_varlist'"
    }
    else {
        char _dta[_finegray_fvvarlist] ""
    }

    * =========================================================================
    * DISPLAY RESULTS
    * =========================================================================
    display as text "Fine-Gray competing risks regression"
    display as text ""
    display as text "Competing events:" _col(24) as result "`compete'"
    display as text "Cause of interest:" _col(24) as result "`cause'"
    display as text "Censoring value:" _col(24) as result "`censvalue'"
    if "`strata'" != "" {
        display as text "Censoring strata:" _col(24) as result "`strata'"
    }
    display as text ""
    display as text "No. of obs" _col(24) "= " as result %10.0fc `N'
    display as text "No. of cause events" _col(24) "= " as result %10.0fc `N_fail'
    display as text "No. of competing" _col(24) "= " as result %10.0fc `N_compete'
    display as text "No. censored" _col(24) "= " as result %10.0fc `N_cens'
    if "`cluster'" != "" {
        display as text "No. of clusters" _col(24) "= " ///
            as result %10.0fc `_fg_nclust'
    }
    display as text ""

    if `_fg_ll' != . {
        display as text "Log pseudo-likelihood" _col(24) "= " ///
            as result %12.4f `_fg_ll'
    }
    if `_fg_chi2' != . {
        display as text "Wald chi2(" as result "`_fg_df_m'" ///
            as text ")" _col(24) "= " as result %10.2f `_fg_chi2'
        display as text "Prob > chi2" _col(24) "= " as result %10.4f `_fg_p'
    }
    display as text ""

    * Warn BEFORE the table, as stcrreg does. Printed after the coefficients it
    * discredits, this is trivially scrolled past -- and the coefficients are
    * the thing the reader takes away.
    if `_fg_conv' == 0 {
        display as error "convergence not achieved"
        display as text "(the coefficients below are the last iterate, not a " ///
            "solution; post-estimation commands will refuse them)"
        display as text ""
    }

    * Weight-sensitivity warnings, for the same reason: before the coefficients
    * they discredit, not after.  These are not errors -- the fit is reported --
    * but a near-zero A or an enormous weight means a handful of subjects carry
    * the estimate, and the reader must see that next to the numbers.
    if `_fg_has_lt' {
        local _fg_npw = e(N_prob_warn)
        local _fg_nww = e(N_weight_warn)
        local _fg_mxw : display %9.3e e(max_lt_weight)
        local _fg_mxw = trim("`_fg_mxw'")

        if `_fg_npw' > 0 & `_fg_npw' < . {
            display as error "warning: the combined weight A(t) falls below 1e-10 in `_fg_npw' consulted cells"
            display as text "(near-zero censoring or entry probability: the weights there are" ///
                " not estimable and the fit leans on very few subjects)"
        }
        if `_fg_nww' > 0 & `_fg_nww' < . {
            display as error "warning: `_fg_nww' retained weights exceed 1e6 (largest `_fg_mxw')"
            display as text "(a few subjects dominate the risk sets; treat these coefficients" ///
                " as unstable)"
        }
        local _fg_ws "`e(weight_warn_strata)'"
        if "`_fg_ws'" != "" {
            display as text "(affected joint weight strata: `_fg_ws')"
            display as text ""
        }
    }

    * Factorized-extension note.  When strata() and truncstrata() name different
    * groupings the weight is the package's factorized A=G*H extension, not the
    * ZZF stratified construction.  The help file documents this, but the fit
    * itself otherwise reports only e(lt_weight)=zzf1_factorized; say at fit time
    * that the estimator differs from ZZF and under what condition it is valid.
    if `_fg_factorized' {
        display as text ""
        display as text "note: the censoring weight G and entry weight H use different groupings,"
        display as text "so finegray uses the factorized A=G*H extension -- a package extension,"
        display as text "valid only when entry and censoring are independent within each joint"
        display as text "cell. See Left truncation in {help finegray}. e(lt_weight)=zzf1_factorized."
    }

    if "`shr'" == "noshr" {
        ereturn display, level(`level')
    }
    else {
        ereturn display, eform(SHR) level(`level')
    }

    * The Fine-Gray objective is a PSEUDO-likelihood: the IPCW risk sets make
    * subjects' contributions dependent, so the inverse information is not the
    * sampling variance of beta-hat.  norobust is a diagnostic, not an
    * inference option -- say so every time it is used.
    if "`robust'" == "norobust" {
        display as text ""
        display as error "Warning: norobust reports model-based (inverse-information) standard errors."
        display as error "The Fine-Gray subdistribution likelihood is a pseudo-likelihood -- the"
        display as error "inverse-probability-of-censoring weights make subjects' contributions"
        display as error "dependent -- so the information matrix does not estimate the sampling"
        display as error "variance of the coefficients.  These standard errors are generally too"
        display as error "small and their confidence intervals do not have nominal coverage."
        display as error "Use the default robust (sandwich) variance for inference; norobust is"
        display as error "provided for comparison with the naive likelihood only."

        * Under delayed entry this is not a caution, it is a MEASURED defect, and
        * it is far larger than the right-censoring case above.  The weights A(t)
        * are estimated, and their uncertainty is absent from the information
        * matrix; the damage grows with the truncation fraction.
        *
        * qa/validation_finegray_zzf_coverage.do, 1000 replications per arm,
        * known truth, 95% nominal:
        *
        *   truncation    norobust coverage   default (sandwich) coverage
        *        0%          0.956 / 0.949        0.954 / 0.943
        *       37%          0.897 / 0.901        0.941 / 0.951
        *       69%          0.850 / 0.850        0.955 / 0.953
        *
        * The model-based SE runs up to 38% below the true sampling SD at 69%
        * truncation.  Quote the numbers: a user who is told "generally too small"
        * cannot tell whether that means 1% or 30%.
        if `_fg_has_lt' {
            display as error ""
            display as error "This fit has DELAYED ENTRY, where the defect above is measured and severe."
            display as error "The truncation weights are themselves estimated and the information matrix"
            display as error "does not carry their uncertainty.  In this package's coverage study (1000"
            display as error "replications, known truth, nominal 95%) norobust intervals covered only"
            display as error "89% at 37% truncation and 85% at 69% truncation, and the model-based"
            display as error "standard errors ran up to 38% below the true sampling variability.  The"
            display as error "failure gets WORSE as the truncation fraction rises."
            display as error "Do not use norobust for inference on left-truncated data."
        }
    }

    if `_fv_nrefs' > 0 {
        display as text ""
        forvalues _i = 1/`_fv_nrefs' {
            display as text `"Reference: `_fv_refinfo`_i''"'
        }
    }

    } /* end capture noisily */

    local rc = _rc

    * Clean up temporary matrices (runs on both success and error paths)
    foreach m in _finegray_b _finegray_V _finegray_ll _finegray_ll_0 ///
        _finegray_chi2 _finegray_df_m _finegray_conv ///
        _finegray_rank _finegray_nclust _finegray_basehaz ///
        _finegray_nwstrata _finegray_minprob _finegray_maxwt ///
        _finegray_nprobwarn _finegray_nwtwarn {
        capture matrix drop `m'
    }

    * Drop FV indicators on error (they persist on success for predict)
    if `rc' & "`_fv_created'" != "" {
        foreach v of local _fv_created {
            capture drop `v'
        }
    }

    * Drop the entry-time variable on error (persists on success for
    * post-estimation on reduced multi-record fits)
    if `rc' & "`_fg_entryvar'" != "" {
        capture drop `_fg_entryvar'
    }

    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
