*! finegray Version 1.1.1  2026/07/04
*! Fine-Gray competing risks regression
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
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
         STRata(varlist numeric) CLuster(varname numeric) noROBust ///
         noLOG ///
         ITERate(integer 200) TOLerance(real 1e-8)]

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
    * Save original varlist before FV expansion (for e(fvvarlist))
    local _orig_varlist "`varlist'"

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

        * --- persist each subject's earliest entry for post-estimation ---
        * Post-estimation (finegray_cif, finegray_predict ci/schoenfeld,
        * finegray_phtest, bootstrap refits) recomputes risk sets from the
        * data; the kept record's own _t0 is its last interval start, so the
        * true entry must survive outside this program's preserve block.
        capture confirm variable _fg_entry
        if !_rc {
            if `"`_dta[_finegray_entryvar]'"' == "_fg_entry" {
                display as text "(note: replacing existing variable _fg_entry)"
                quietly drop _fg_entry
            }
            else {
                display as error "variable _fg_entry already exists"
                display as error "finegray uses this name to record subject entry times"
                display as error "for multiple-record data; rename or drop it before running finegray"
                exit 198
            }
        }
        quietly gen double _fg_entry = `_fg_mint0'
        label variable _fg_entry "finegray: earliest subject entry time (multi-record reduction)"
        local _fg_entryvar "_fg_entry"

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
    if `tolerance' <= 0 {
        display as error "tolerance() must be positive"
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
    if `N_compete' == 0 {
        display as error "no competing events found"
        display as error "with cause(`cause') and censvalue(`censvalue'), " ///
            "compete() contains no other event types"
        exit 198
    }

    * Count censored
    quietly count if `compete' == `censvalue' & `touse'
    local N_cens = r(N)
    if `N_cens' == 0 {
        display as error "no censored observations found"
        exit 198
    }

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
    * EXPAND FACTOR VARIABLES (fvrevar-based: supports i., ib#., ##, #, c.)
    * =========================================================================
    local _fv_created ""
    local _prev_fv_created `"`_dta[_finegray_fvvars]'"'
    local _has_fv = 0
    local _fv_nrefs = 0

    * Check if any FV operators present
    foreach _fv_tok of local varlist {
        if strpos("`_fv_tok'", ".") > 0 {
            local _has_fv = 1
            continue, break
        }
    }

    * Clean up the entry-time variable from any prior finegray run when this
    * run did not just (re)create it in the reduction step above.
    local _prev_entryvar `"`_dta[_finegray_entryvar]'"'
    if `"`_dta[_finegray_estimated]'"' == "1" & `"`_prev_entryvar'"' != "" ///
        & "`_prev_entryvar'" != "`_fg_entryvar'" {
        capture confirm variable `_prev_entryvar'
        if !_rc quietly drop `_prev_entryvar'
    }

    * Clean up FV variables from any prior finegray run, unconditionally.
    * This ensures stale _fg_* columns are dropped even when the new run
    * does not use factor variables.
    if `"`_dta[_finegray_estimated]'"' == "1" & `"`_prev_fv_created'"' != "" {
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

    * =========================================================================
    * LOAD MATA ENGINE
    * =========================================================================
    capture program list _finegray_mata_loaded
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

        sort _t

        if "`log'" != "nolog" {
            display as text "Fitting Fine-Gray model..."
        }

        mata: _finegray_engine( ///
            "`varlist'", "`compete'", `cause', `censvalue', ///
            "`_byg_mata'", "`vce_type'", "`cluster'", ///
            `iterate', `tolerance', ("`log'" != "nolog"))
    }

    local _rc_fit = _rc
    restore

    if `_rc_fit' {
        exit `_rc_fit'
    }

    * =========================================================================
    * RETRIEVE AND POST E() RESULTS
    * =========================================================================

    tempname b V basehaz
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
    ereturn scalar converged = `_fg_conv'
    ereturn scalar level = `level'
    ereturn scalar cause = `cause'
    ereturn scalar censvalue = `censvalue'
    ereturn scalar iterate = `iterate'
    ereturn scalar tolerance = `tolerance'

    ereturn local cmd "finegray"
    ereturn local cmdline `"`_cmdline'"'
    ereturn local predict "finegray_predict"
    ereturn local depvar "`compete'"
    ereturn local compete "`compete'"
    ereturn local covariates "`varlist'"
    if `_has_fv' ereturn local fvvarlist "`_orig_varlist'"
    if "`strata'" != "" ereturn local strata "`strata'"
    if "`cluster'" != "" ereturn local clustvar "`cluster'"
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

    capture matrix `basehaz' = _finegray_basehaz
    if _rc == 0 {
        ereturn matrix basehaz = `basehaz'
    }

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

    if "`shr'" == "noshr" {
        ereturn display, level(`level')
    }
    else {
        ereturn display, eform(SHR) level(`level')
    }

    if `_fg_conv' == 0 {
        display as error "convergence not achieved"
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
        _finegray_basehaz {
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
