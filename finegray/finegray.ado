*! finegray Version 1.3.0  2026/08/25
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
  bstrata(varname)  - Stratify the BASELINE subdistribution hazard (shared beta)
  cluster(varname)  - Clustered standard errors
  norobust          - Model-based SEs instead of default sandwich
  nolog             - Suppress iteration log
  iterate(#)        - Max iterations (default: 200)
  tolerance(#)      - Convergence tolerance (default: 1e-8)

See help finegray for complete documentation
*/

program define finegray, eclass sortpreserve
    version 16.0

    * Replay.  `finegray' typed with no varlist (or with display options only)
    * redisplays the last finegray results, as every Stata e-class estimator
    * does; `finegray, level(90)' redisplays at another confidence level and
    * `finegray, noshr' on the log-SHR scale.  Before this the command answered
    * `varlist required' r(100) and the only way back to the table was to refit
    * -- the expensive thing this package exists to avoid.
    *
    * Handled HERE, ahead of the varabbrev wrapper and the capture block below,
    * so that the `exit' costs no cleanup: nothing has been set, opened, or
    * preserved yet.  _finegray_display runs its own wrapper.
    if replay() {
        if `"`e(cmd)'"' != "finegray" {
            * `mi estimate, cmdok: finegray ...' leaves mi's POOLED results in
            * e(), which finegray cannot replay and mi can.  Say that rather
            * than "you must run finegray", which reads as though they had not.
            if `"`e(cmd)'"' == "mi estimate" & `"`e(cmd_mi)'"' == "finegray" {
                display as error "last estimates are pooled {bf:mi estimate} results, not a finegray fit"
                display as error "replay them with {bf:mi estimate} (with no command), or refit on a"
                display as error "single dataset with {bf:mi extract 0, clear} and run {bf:finegray} there;"
                display as error "see {help finegray##mi:help finegray}"
                exit 301
            }
            display as error "last estimates not found"
            display as error "you must run {bf:finegray} before replaying its results"
            exit 301
        }
        _finegray_display `0'
        exit
    }

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
         BSTRata(varname numeric) ///
         TVC(varlist numeric) TSPLIT(numlist ascending) ///
         CLuster(varname numeric) noROBust ///
         noADJust noLOG BASEHaz NUISance ///
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

    * cluster() requests a cluster-robust sandwich while norobust requests the
    * model-based inverse information. Accepting both used the clustered
    * sandwich in the engine but posted and displayed parts of the norobust
    * contract, yielding a contradictory rc=0 result.
    if "`cluster'" != "" & "`robust'" == "norobust" {
        display as error "cluster() is not allowed with norobust"
        display as error "cluster() requests a cluster-robust sandwich variance; " ///
            "norobust requests the model-based inverse information"
        exit 198
    }

    * nuisance adds the Fine-Gray (1999) eq. 7-8 psi term to the sandwich meat.
    * It is a property of the SANDWICH, so it is meaningless without one.
    if "`nuisance'" != "" & "`robust'" == "norobust" {
        display as error "nuisance is not allowed with norobust"
        display as error "the nuisance (psi) correction applies to the " ///
            "robust (sandwich) variance only"
        exit 198
    }

    * bstrata() frees the baseline per stratum, so S0(s) and zbar(s) become
    * stratum-specific.  Zhou et al. (2011) sec. 4.1 DOES define the stratified
    * psi -- it is Fine & Gray (1999) eq. 7-8 "with the added subscript k",
    * i.e. computed inside the stratum -- so the quantity is grounded; what is
    * missing is the implementation.  _finegray_psi_residuals builds q_g(t)
    * from the POOLED S0(s) and zbar(s), and this version does not stratify it.
    * Accepting the pair would therefore add an unstratified correction to a
    * stratified sandwich: not the paper's variance, and not this package's
    * either.  Refuse rather than report it as though it were.
    if "`nuisance'" != "" & "`bstrata'" != "" {
        display as error "nuisance is not allowed with bstrata()"
        display as error "the psi correction is Fine & Gray (1999) eq. 7-8, " ///
            "computed against a single pooled baseline"
        display as error "Zhou et al. (2011) sec. 4.1 defines its stratified " ///
            "form, but finegray does not implement it"
        display as error "applying the pooled term to a stratified fit would " ///
            "not be either variance"
        display as error "use bootstrap coefficient inference instead; " ///
            "see {help finegray##bstrata:help finegray}"
        exit 198
    }

    * =========================================================================
    * PIECEWISE-CONSTANT beta(t): tvc() / tsplit() OPTION GRAMMAR
    * =========================================================================
    * tvc() names the covariates whose effect varies with analysis time and
    * tsplit() the interior boundaries of the intervals it is constant on.
    * Neither means anything without the other: tvc() alone does not say WHERE
    * the effect changes, and tsplit() alone splits nothing.  Refuse both ways
    * rather than silently ignoring one of them.
    if "`tvc'" != "" & "`tsplit'" == "" {
        display as error "tvc() requires tsplit()"
        display as error "tsplit() gives the interior interval boundaries on " ///
            "the analysis-time scale"
        display as error "as in {bf:tvc(x) tsplit(5 10)}; " ///
            "see {help finegray##tvc:help finegray}"
        exit 198
    }
    if "`tsplit'" != "" & "`tvc'" == "" {
        display as error "tsplit() requires tvc()"
        display as error "tvc() names the covariates whose coefficient is " ///
            "allowed to differ across the intervals"
        display as error "as in {bf:tvc(x) tsplit(5 10)}; " ///
            "see {help finegray##tvc:help finegray}"
        exit 198
    }

    local _fg_ntv = 0
    local _fg_nint = 1
    if "`tvc'" != "" {
        * `numlist ascending' already refuses a repeated or out-of-order
        * boundary at the syntax statement (r(124); pinned by T14 in
        * qa/test_finegray_tvc.do).  What it does NOT enforce is positivity:
        * tsplit(0) parses, and a boundary at or below zero would define an
        * empty leading interval (0, 0] carrying its own unidentified
        * coefficient.
        local _fg_ncut : word count `tsplit'
        local _fg_nint = `_fg_ncut' + 1
        foreach _fg_c of local tsplit {
            if `_fg_c' <= 0 {
                display as error "tsplit() boundaries must be positive"
                display as error "`_fg_c' is not a time inside the follow-up"
                exit 198
            }
        }

        * Both refusals are §3 scope fences, not implementation gaps that a user
        * can work around by rearranging the command.
        *
        * bstrata(): each reshapes the scan on its own axis (per-stratum row
        * subsets; per-interval accumulator rebuilds).  They compose
        * mechanically, but the composition has no reference implementation to
        * validate against and doubles the QA surface of each; it is out of
        * scope for this release rather than impossible.
        if "`bstrata'" != "" {
            display as error "tvc() is not allowed with bstrata()"
            display as error "each option reshapes the risk-set scan on its own axis, and the"
            display as error "combination has no reference implementation to validate against"
            display as error "fit within baseline stratum, or drop one of the two options;"
            display as error "see {help finegray##tvc:help finegray}"
            exit 198
        }
        * nuisance: the psi term is Fine & Gray (1999) eq. 7-8, built from ONE
        * S0(s) and zbar(s) per event time.  Under beta(t) both are
        * interval-specific and the correction has not been re-derived here.
        if "`nuisance'" != "" {
            display as error "nuisance is not allowed with tvc()"
            display as error "the psi correction is Fine & Gray (1999) eq. 7-8, computed from a"
            display as error "single S0(s) and zbar(s) at each cause-event time"
            display as error "under a piecewise beta(t) both are interval-specific and the"
            display as error "corresponding term is not derived here"
            display as error "use bootstrap coefficient inference instead; " ///
                "see {help finegray##variance:help finegray}"
            exit 198
        }
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
    * MULTIPLE-IMPUTATION DATA DETECTION
    * =========================================================================
    * finegray writes package-owned PERMANENT columns into the caller's data --
    * _fg_entry for a multiple-record fit and one _fg_<term> column per factor
    * term -- so that post-estimation can rebuild the fit's design.  In mi data
    * those columns are unregistered variables: `mi describe' reports them, and
    * under mlong/flong they carry values on some m and not others.  Fitting
    * `finegray i.grp x' directly on `mi set wide' data left _fg_grp_2 and
    * _fg_grp_3 behind exactly that way.
    *
    * The fix is not new machinery: the fit itself already runs on tempvars
    * inside `preserve', and only the post-estimation SUPPORT is permanent.  On
    * mi data that support is routed through tempvars instead, which means it
    * does not survive the command -- so post-estimation is refused rather than
    * silently answering from columns that are gone (see e(postest) below and
    * the guards in finegray_predict / finegray_cif / finegray_phtest).
    *
    * The detection has to work in three contexts.  All twelve style x context
    * cells below were enumerated by running them on 2026-08-25 (hypoxia, two
    * imputations) and dumping `: char _dta[]' from inside the fitted command:
    *
    *   context               mlong     wide      flong        flongsep
    *   1 typed directly      mlong     wide      flong        flongsep
    *   2 mi estimate,cmdok:  bad       bad       ABSENT       flongsep
    *   3 mi xeq #:           flongsep_sub (all four styles)
    *
    * so _dta[_mi_style] alone misses exactly one cell: flong inside
    * `mi estimate'.  That cell is not char-free, however -- it carries
    * _dta[_mi_substyle] == "bad", the only _mi_* characteristic mi leaves on
    * the completed dataset it hands the command.  Every other cell carries
    * _mi_style plus several more (_mi_M, _mi_ivars, _mi_update, ...).
    *
    * Detection is therefore "does the DATASET carry any _mi_* characteristic",
    * which is true in all twelve cells and false on ordinary data.
    *
    * It must NOT be "does a variable named _mi_m / _mi_id / _mi_miss exist".
    * Those are legal names in an ordinary dataset, and the earlier probe on
    * them was a false positive: `generate long _mi_id = _n' on plain webuse
    * hypoxia produced e(mi_data)=1, e(postest)=unavailable_mi, and r(301) from
    * every post-estimation command, on data that had never been near mi.
    * Reproduced 2026-08-25; regression tests 14-16 in qa/test_finegray_mi.do.
    local _fg_is_mi = 0
    local _fg_dtachars : char _dta[]
    foreach _fg_dtachar of local _fg_dtachars {
        if substr("`_fg_dtachar'", 1, 4) == "_mi_" {
            local _fg_is_mi = 1
            continue, break
        }
    }

    * =========================================================================
    * MARK SAMPLE
    * =========================================================================
    marksample touse
    * NOTE: compete() is deliberately NOT passed to `markout'.  It is the
    * outcome classification, not a covariate, and an unknown event type is
    * refused below rather than dropped.  See "compete() MUST BE OBSERVED".

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
    * bstrata() assigns every subject to a baseline.  Changing it after the fit
    * must make post-estimation FAIL, not silently answer a row from another
    * stratum's baseline curve.
    if "`bstrata'" != "" {
        local _sig_seen : list posof "`bstrata'" in _fg_sigvars
        if `_sig_seen' == 0 local _fg_sigvars "`_fg_sigvars' `bstrata'"
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
    if "`bstrata'" != "" markout `touse' `bstrata'
    if "`cluster'" != "" markout `touse' `cluster'

    quietly replace `touse' = 0 if _st != 1

    * =========================================================================
    * compete() MUST BE OBSERVED ON EVERY ESTIMATION-SAMPLE RECORD
    * =========================================================================
    * This used to be `markout `touse' `compete'' beside `marksample'.  markout
    * is the right tool for a covariate and the wrong one for the outcome
    * classification: it dropped every record whose event type was UNKNOWN
    * with no message, no e() count and no note -- including failure records
    * (_d==1), where the drop removes an event from the estimand and moves the
    * coefficients.  Live on webuse hypoxia, blanking compete() on five records
    * of which three were cause-1 failures returned rc 0 with N 109 -> 104,
    * N_fail 33 -> 30 and b(ifp) .0326664 -> .04609379, a 41% change.
    *
    * It was also strictly inconsistent with the consistency checks further
    * below, which fail closed at r(198) on a record whose event type merely
    * DISAGREES with _d -- and those counts are restricted to `touse', so the
    * stricter case was the one that survived.  Refuse the unknown case too.
    *
    * Placed AFTER the covariate/strata/cluster markouts and the _st filter, so
    * a record already excluded for a missing covariate or an out-of-sample _st
    * cannot raise this error: only a record that would otherwise have been fit
    * counts.
    *
    * The common way in is stsetting the failure indicator ON the event-type
    * variable and then splitting: `stset t, failure(status) id(id)' followed by
    * `stsplit' sets `status' to missing on every non-terminal episode.  The
    * EXPRESSION form does it too -- verified 2026-08-19, `failure(ev == 1 2)'
    * then `stsplit sp, at(2 6)' blanked 765 of 1365 records -- so what makes
    * the ordinary fixtures safe is not the form but that they stset a SEPARATE
    * indicator, `failure(dfcens == 1)' with `compete(status)'.  Before this
    * guard that configuration reached r(459) "positivity violation in the
    * delayed-entry weights ... use coarser strata()", a message about a cause
    * that was not the cause: the blanked episodes were dropped, every surviving
    * record started at the last split boundary, and the reverse-time product
    * limit for H hit zero there.
    quietly count if `touse' & missing(`compete')
    if r(N) > 0 {
        local _fg_nmiss = r(N)
        quietly count if `touse' & missing(`compete') & _d == 1
        local _fg_nmissfail = r(N)
        display as error "compete() is missing on `_fg_nmiss' record(s) of the estimation sample"
        display as error "`_fg_nmissfail' of them are stset failures (_d==1)"
        display as error "finegray cannot classify a record whose event type is unknown, and"
        display as error "dropping such records would remove events from the estimand silently"
        display as error "if these data were {help stsplit:stsplit} after an {cmd:stset} whose {cmd:failure()}"
        display as error "was built on `compete', {cmd:stsplit} set `compete' to missing on every"
        display as error "non-terminal episode; carry the subject's event type onto every episode,"
        display as error "or exclude those records with {cmd:if}"
        exit 198
    }

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
    * the engine's left-truncation handle the rest.
    *
    * What is NOT supported here is time-varying COVARIATES: a covariate that
    * changes value within subject cannot survive the reduction, and internal
    * time-varying covariates generally lack the model's direct CIF
    * interpretation after a competing event anyway.  The constancy check below
    * is what enforces that.
    *
    * Time-varying COEFFICIENTS are a different thing and ARE supported here.
    * tvc()/tsplit() vary beta(t), not x, so the reduction does not touch them:
    * the subject's one risk-set unit still spans the whole tsplit() grid.  Only
    * DELAYED ENTRY is refused with tvc() (see the _fg_has_lt guard below), and
    * on multiple-record data with earliest entry zero that guard does not fire.
    * Verified 2026-08-25: a 1200-subject fixture split into 2280 zero-entry
    * (start,stop] episodes and fitted with tvc(x1) tsplit(0.7) returns e(b),
    * e(V) and e(ll) BIT-IDENTICAL to the single-record fit of the same data.
    * Pinned by test T26 in qa/test_finegray_tvc.do.
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
        * A subject cannot move baselines part-way through follow-up: bstrata()
        * must be constant within id().  The constancy loop below reports it in
        * the same words as a time-varying covariate, which is what it is.
        if "`bstrata'" != "" {
            local _seen : list posof "`bstrata'" in _fg_checkvars
            if `_seen' == 0 local _fg_checkvars "`_fg_checkvars' `bstrata'"
        }
        if "`cluster'" != "" {
            local _seen : list posof "`cluster'" in _fg_checkvars
            if `_seen' == 0 local _fg_checkvars "`_fg_checkvars' `cluster'"
        }

        * Put selected records first once.  The former `egen sd(), by(id)'
        * loop re-ran grouped aggregation (and its sort machinery) for every
        * covariate.  Direct comparison with the first selected record has the
        * same O(N*p) information requirement without p grouped egen passes;
        * this ordering is also the one needed by the interval check below.
        quietly gsort `_fg_id' -`touse' _t0 _t `_fg_row0'
        tempvar _fg_vary
        foreach _cv of local _fg_checkvars {
            capture drop `_fg_vary'
            quietly by `_fg_id': gen byte `_fg_vary' = ///
                (`touse' & abs(`_cv' - `_cv'[1]) >= 1e-9)
            quietly count if `_fg_vary'
            if r(N) > 0 {
                display as error "finegray requires covariates constant within id()"
                display as error "covariate `_cv' varies within subject"
                display as error "this implementation does not support time-varying covariates"
                display as error "for internal time-varying covariates, consider a cause-specific"
                display as error "model with {help stcox}; see {help finegray##lt:finegray}"
                exit 198
            }
        }

        * --- gap / overlap check: intervals must be contiguous within id ---
        * Check every adjacent boundary.  Comparing total covered time with the
        * overall span is insufficient: an overlap and an equal-sized gap cancel
        * arithmetically, after which the reduction silently invents continuous
        * follow-up across the gap.  Put selected records first, order them by
        * start/stop time with a total row-order key, and compare each start with
        * the preceding stop.  This one grouped pass also supplies the subject's
        * earliest entry time used below, replacing three egen passes.
        tempvar _fg_seq _fg_badspan _fg_mint0
        quietly by `_fg_id': gen long `_fg_seq' = sum(`touse')
        quietly by `_fg_id': gen byte `_fg_badspan' = ///
            (`touse' & `_fg_seq' > 1 & ///
            abs(_t0 - _t[_n - 1]) >= 1e-9)
        quietly count if `_fg_badspan'
        if r(N) > 0 {
            display as error "finegray: subject records have gaps or overlaps"
            display as error "each subject's intervals must be contiguous"
            display as error "(no gaps or overlapping time spans); collapse to one"
            display as error "record per subject before fitting"
            exit 198
        }
        quietly by `_fg_id': gen double `_fg_mint0' = _t0[1] if `touse'

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
        * On mi data the entry column is a TEMPVAR (see the mi block above), so
        * it claims no name in the caller's dataset and this check has nothing
        * to adjudicate: an existing user variable called _fg_entry is not in
        * its way and must not be refused over a name finegray will not take.
        if !`_fg_is_mi' {
            capture confirm variable _fg_entry
            if !_rc & `"`_dta[_finegray_entryvar]'"' != "_fg_entry" {
                display as error "variable _fg_entry already exists"
                display as error "finegray uses this name to record subject entry times"
                display as error "for multiple-record data; rename or drop it before running finegray"
                exit 198
            }
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
    * Kept as well as tested: the header reports HOW MANY subjects entered late,
    * because "this fit has delayed entry" and "three of 4,000 subjects entered
    * late" are different facts and only the second one tells the reader how
    * much of the estimate rides on the entry weights.
    local _fg_n_lt = r(N)
    local _fg_has_lt = (r(N) > 0)

    * The psi term is Fine & Gray (1999) eq. 7-8, derived for right censoring
    * with no entry times.  Its delayed-entry analogue is the ZZF (2011)
    * Appendix B term, which this package does not implement.  Refuse rather
    * than apply a right-censoring correction to left-truncated data, which
    * would return a plausible number with no derivation behind it.
    if "`nuisance'" != "" & `_fg_has_lt' {
        display as error "nuisance is not allowed with delayed entry"
        display as error "the psi correction is Fine & Gray (1999) eq. 7-8, " ///
            "derived for right censoring only"
        display as error "under left truncation the corresponding term is " ///
            "ZZF (2011) Appendix B, which finegray does not implement"
        display as error "use bootstrap coefficient inference instead; " ///
            "see {help finegray##variance:help finegray}"
        exit 198
    }

    * Zhou, Latouche, Rocha & Fine (2011) derive the stratified proportional
    * subdistribution hazards model for RIGHT-CENSORED data; neither that paper
    * nor Zhang/Zhang/Fine (2011) treats left truncation, so a stratified
    * baseline on the delayed-entry branch would be a package invention with no
    * derivation behind it.  This is also what keeps bstrata() a five-scan-
    * function change instead of a ten: the ZZF branch is untouched.
    if "`bstrata'" != "" & `_fg_has_lt' {
        display as error "bstrata() is not supported with delayed entry"
        display as error "`_fg_n_lt' subject(s) in the estimation sample enter after time 0"
        display as error "the stratified subdistribution hazard of Zhou et al. (2011) is"
        display as error "derived for right censoring only, and its left-truncated analogue"
        display as error "is not published; fitting one here would be unsourced"
        display as error "fit within stratum, or drop the delayed entry;"
        display as error "see {help finegray##bstrata:help finegray}"
        exit 198
    }

    * The piecewise scans rebuild the risk set and the retained-competing
    * accumulator at every interval boundary, and they do it by re-running the
    * RIGHT-CENSORING scan once per interval.  The delayed-entry (ZZF) branch is
    * a separate family of five scan functions with no piecewise form, and it is
    * already this package's own extension of Zhang/Zhang/Fine (2011) rather
    * than a published estimator, so a beta(t) built on top of it would be
    * unsourced twice over.  Refuse instead of quietly fitting the proportional
    * estimator under a piecewise coefficient stripe.
    if "`tvc'" != "" & `_fg_has_lt' {
        display as error "tvc() is not supported with delayed entry"
        display as error "`_fg_n_lt' subject(s) in the estimation sample enter after time 0"
        display as error "the piecewise-constant beta(t) scan is derived for right censoring;"
        display as error "the delayed-entry weights have no published piecewise analogue"
        display as error "drop the delayed entry, or model the effect as proportional;"
        display as error "see {help finegray##tvc:help finegray}"
        exit 198
    }

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
        if `_fg_is_mi' {
            * mi data: a tempvar, dropped when this command returns.  The fit
            * itself is unaffected -- the engine consumes this column inside
            * `preserve' either way -- and nothing is written to the caller's
            * mi dataset.  Post-estimation is refused on this fit (e(postest)).
            tempvar _fg_entry_tv
            quietly gen double `_fg_entry_tv' = `_fg_mint0'
            local _fg_entryvar "`_fg_entry_tv'"
        }
        else {
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
    }

    * =========================================================================
    * EXPAND FACTOR VARIABLES (fvrevar-based: supports i., ib#., ##, #, c.)
    * =========================================================================
    local _fv_created ""
    local _prev_estimated `"`_dta[_finegray_estimated]'"'
    local _prev_fv_created `"`_dta[_finegray_fvvars]'"'
    local _prev_entryvar `"`_dta[_finegray_entryvar]'"'
    local _has_fv = 0

    * Input validation above leaves a prior successful fit intact. Once this
    * new fit begins mutating package-owned columns, invalidate the old state
    * first so a failed re-fit cannot masquerade as the previous success.
    *
    * The mark is "0", not "": it has to be TELLABLE from a dataset that never
    * carried the characteristic at all.  Post-estimation now recognises a
    * finegray fit restored by `estimates use' over a dataset saved before the
    * fit -- which has no characteristic -- and both states used to spell
    * themselves the same way, so writing "" here would have let a re-fit that
    * failed mid-mutation fall through to the prior fit's e() and answer from
    * it.  "0" means INVALIDATED and is refused; absent means UNKNOWN and is
    * adjudicated against e().  Guarded by test_finegray_v110.do.
    char _dta[_finegray_estimated] "0"
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

        * Build final varlist and create the design columns.
        *
        * _fv_final holds the columns the engine will read; _fv_names holds the
        * _fg_<term> NAMES those columns would take in the caller's data.  Off
        * mi data the two lists are identical.  On mi data _fv_final holds
        * tempvars (nothing is written to the caller's dataset) while _fv_names
        * still carries the intended names, so the 32-character truncation
        * collision test below adjudicates the same specification in both
        * modes.  A collision cannot actually corrupt anything in mi mode --
        * the tempvars are distinct whatever the terms are called -- but a fit
        * that errors on complete-case data and succeeds under `mi estimate'
        * would be a worse surprise than a refusal the user can act on.
        local _fv_final ""
        local _fv_names ""

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
                local _fv_names "`_fv_names' `_var'"
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

                * A kept factor level part is `N.var' or `Nbn.var' (base-none:
                * ibn. omits no reference, so its first level 1bn.var carries a
                * REAL coefficient and must produce a legal name, not the raw
                * token _fg_1bn.varXx that r(198)'d before).  Base parts (Nb.var)
                * never reach here -- the whole term is skipped above.
                if regexm("`_part'", "^([0-9]+)(bn)?\.(.+)$") {
                    if "`_fg_parts'" != "" local _fg_parts "`_fg_parts'X"
                    local _fg_parts "`_fg_parts'`=regexs(3)'_`=regexs(1)'"
                }
                else if regexm("`_part'", "^c\.(.+)$") {
                    if "`_fg_parts'" != "" local _fg_parts "`_fg_parts'X"
                    local _fg_parts "`_fg_parts'`=regexs(1)'"
                }
                else if strpos("`_part'", ".") {
                    * A dotted operator the shared grammar does not model (o., a
                    * future marker).  Copying it verbatim into a variable name
                    * produced an illegal name; refuse explicitly instead.
                    display as error "factor-variable operator in `_part' is not supported"
                    display as error "finegray supports i., ib#., ibn., c., #, and ## terms"
                    exit 198
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
            local _collision : list posof "`_fg_name'" in _fv_names
            if `_collision' > 0 {
                display as error "factor variable names too similar"
                display as error "`_fg_name' collides after truncation to 32 characters"
                display as error "use shorter variable names or fewer interaction levels"
                exit 198
            }

            local _fv_names "`_fv_names' `_fg_name'"

            * mi data: the design column is a tempvar.  It claims no name in the
            * caller's dataset, so the existing-variable check has nothing to
            * adjudicate and the column does not outlive this command -- which
            * is the point: an unregistered _fg_<term> column in mi data is what
            * this branch exists to avoid.  Post-estimation is refused on this
            * fit (e(postest)), so nothing later reads the column back.
            if `_fg_is_mi' {
                tempvar _fg_col
                quietly generate double `_fg_col' = `_var'
                local _fv_final "`_fv_final' `_fg_col'"
                continue
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

                if regexm("`_lbl_part'", "^([0-9]+)(bn)?\.(.+)$") {
                    * Factor part: use value label if available (Nbn. base-none
                    * levels label like ordinary levels; they have no reference)
                    local _lp_lev = regexs(1)
                    local _lp_var = regexs(3)
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

        * The `Reference:' lines used to be built here, from locals the display
        * block then read.  They are now derived from e(fvsemantic) inside
        * _finegray_display, so that a replay prints the same lines as the fit.
    }

    * The unpenalized Fine-Gray likelihood cannot identify constant or exactly
    * collinear columns.  Do not silently substitute arbitrary ridge estimates:
    * reject the specification with the offending expanded columns named.
    quietly _rmcoll `varlist' if `touse', forcedrop
    if r(k_omitted) > 0 {
        local _fg_identified `r(varlist)'
        local _fg_omitted : list varlist - _fg_identified

        * Name the offending terms the way the USER wrote them.  `varlist' is
        * the design columns here, and the non-base fit-time terms pair 1:1 and
        * in order with them (the same pairing e(covariates)/e(fvsemantic) is
        * built on), so an omitted column maps back by position.  Reporting
        * `_fg_grp_2' left the reader to work out which level that was, for a
        * name they never typed.
        local _rk_report "`_fg_omitted'"
        if `_has_fv' {
            local _rk_nb ""
            foreach _rk_t of local _fv_semantic {
                if regexm("`_rk_t'", "[0-9]+b\.") continue
                local _rk_nb "`_rk_nb' `_rk_t'"
            }
            local _rk_nnb : word count `_rk_nb'
            local _rk_nvl : word count `varlist'
            if `_rk_nnb' == `_rk_nvl' {
                local _rk_report ""
                foreach _rk_c of local _fg_omitted {
                    local _rk_p : list posof "`_rk_c'" in varlist
                    if `_rk_p' > 0 {
                        local _rk_report "`_rk_report' `: word `_rk_p' of `_rk_nb''"
                    }
                    else local _rk_report "`_rk_report' `_rk_c'"
                }
                local _rk_report : list retokenize _rk_report
            }
        }

        * A bare `ibn.' main effect is the one rank failure that is a property
        * of the MODEL rather than of the data, so it earns its own note: the
        * Fine-Gray partial likelihood has no intercept, adding a constant to
        * every level's coefficient leaves the likelihood unchanged, and the
        * level indicators sum to 1.  Without this the user reads "constant or
        * collinear" about a variable that is neither, and reaches for a data
        * fix that cannot work.  Detected on a bare `Nbn.var' term -- inside an
        * interaction (`c.x#ibn.grp') the columns do not sum to a constant and
        * ibn. is perfectly estimable, so the note must not fire there.
        local _rk_bn = 0
        local _rk_bnvar ""
        if `_has_fv' {
            foreach _rk_t of local _fv_semantic {
                if strpos("`_rk_t'", "#") continue
                if regexm("`_rk_t'", "^[0-9]+bn\.(.+)$") {
                    local _rk_bn = 1
                    local _rk_bnvar = regexs(1)
                }
            }
        }

        if "`_fv_created'" != "" quietly drop `_fv_created'
        display as error "finegray covariates are not full rank"
        display as error "constant or collinear term(s): `_rk_report'"
        if `_rk_bn' {
            display as error "an ibn. main effect names every level, and the Fine-Gray partial"
            display as error "likelihood has no intercept to absorb the redundancy: the level"
            display as error "indicators sum to 1, so one of them is not identified"
            display as error "use i.`_rk_bnvar' or ib#.`_rk_bnvar' for a main effect; ibn. is estimable"
            display as error "inside an interaction, as in c.x#ibn.`_rk_bnvar'"
        }
        else {
            display as error "remove or recode these terms and fit the model again"
        }
        exit 459
    }

    * =========================================================================
    * MAP tvc() ONTO THE FITTED DESIGN COLUMNS
    * =========================================================================
    * tvc() names VARIABLES; the engine works in design columns.  Off factor
    * variables the two coincide.  With factor variables one variable can supply
    * several columns (i.grp -> two indicators; c.x#i.grp -> one column per
    * level), and the rule is stated rather than guessed at: every coefficient
    * whose TERM involves a tvc() variable becomes interval-specific.  So
    * tvc(grp) frees all of i.grp's level effects together, and tvc(x) in a model
    * containing x and c.x#i.grp frees the interaction columns too.
    *
    * What travels to the engine is POSITIONS, not names.  The design columns are
    * package-owned _fg_* variables that post-estimation is allowed to drop and
    * rebuild as tempvars (see finegray_predict), and a position survives that
    * where a name does not.
    local _fg_tvcpos ""
    local _fg_tvccols ""
    if "`tvc'" != "" {
        local _fg_ncols : word count `varlist'

        * One "source variables" list per design column, in column order.
        forvalues _tv_c = 1/`_fg_ncols' {
            local _tv_src`_tv_c' ""
        }
        if `_has_fv' {
            local _tv_c = 0
            foreach _tv_term of local _fv_semantic {
                if regexm("`_tv_term'", "[0-9]+b\.") continue
                local ++_tv_c
                local _tv_parts = subinstr(subinstr("`_tv_term'", "##", "#", .), "#", " ", .)
                foreach _tv_p of local _tv_parts {
                    if regexm("`_tv_p'", "\.(.+)$") local _tv_p = regexs(1)
                    local _tv_seen : list posof "`_tv_p'" in _tv_src`_tv_c'
                    if `_tv_seen' == 0 local _tv_src`_tv_c' "`_tv_src`_tv_c'' `_tv_p'"
                }
            }
            if `_tv_c' != `_fg_ncols' {
                display as error "internal error: factor expansion and design columns disagree"
                display as error "(`_tv_c' non-base terms, `_fg_ncols' design columns)"
                exit 198
            }
        }
        else {
            forvalues _tv_c = 1/`_fg_ncols' {
                local _tv_src`_tv_c' "`: word `_tv_c' of `varlist''"
            }
        }

        * Match, in ASCENDING design-column order: that is the order the engine
        * assigns the piecewise blocks in, and the coefficient stripe built below
        * has to agree with it column for column.
        forvalues _tv_c = 1/`_fg_ncols' {
            local _tv_hit = 0
            foreach _tv_v of local tvc {
                local _tv_in : list posof "`_tv_v'" in _tv_src`_tv_c'
                if `_tv_in' > 0 {
                    local _tv_hit = 1
                    continue, break
                }
            }
            if `_tv_hit' {
                local _fg_tvcpos "`_fg_tvcpos' `_tv_c'"
                local _fg_tvccols "`_fg_tvccols' `: word `_tv_c' of `varlist''"
            }
        }
        local _fg_tvcpos : list retokenize _fg_tvcpos
        local _fg_tvccols : list retokenize _fg_tvccols

        * A tvc() variable that names no coefficient is a specification error,
        * not a no-op: the user asked for a time-varying effect and would have
        * been handed a fit without one.
        foreach _tv_v of local tvc {
            local _tv_any = 0
            forvalues _tv_c = 1/`_fg_ncols' {
                local _tv_in : list posof "`_tv_v'" in _tv_src`_tv_c'
                if `_tv_in' > 0 {
                    local _tv_any = 1
                    continue, break
                }
            }
            if !`_tv_any' {
                display as error "tvc(`_tv_v') is not in the model"
                display as error "tvc() names covariates the model already fits; add `_tv_v' to"
                display as error "the varlist, or remove it from tvc()"
                exit 198
            }
        }

        local _fg_ntv : word count `_fg_tvcpos'

        * ---- every interval must carry a cause event ------------------------
        * Interval j is (cut[j-1], cut[j]], so a boundary at or beyond the last
        * cause-event time leaves the final interval with no events at all and
        * its coefficients unidentified.  The information matrix would catch it,
        * but as "not full rank" naming a design column -- which sends the reader
        * looking for collinearity.  Name the interval instead.
        local _fg_lo = 0
        local _fg_tvnfail ""
        forvalues _tv_j = 1/`_fg_nint' {
            if `_tv_j' == `_fg_nint' {
                local _tv_cond "_t > `_fg_lo'"
                local _tv_lbl "_t > `_fg_lo'"
            }
            else {
                local _tv_hi : word `_tv_j' of `tsplit'
                local _tv_cond "_t > `_fg_lo' & _t <= `_tv_hi'"
                if `_tv_j' == 1 local _tv_lbl "_t <= `_tv_hi'"
                else            local _tv_lbl "`_fg_lo' < _t <= `_tv_hi'"
            }
            quietly count if `touse' & `compete' == `cause' & `_tv_cond'
            * Kept, not just tested.  An interval is identified as soon as it
            * carries one cause event, but a coefficient estimated from two or
            * three of them is a monotone-likelihood accident waiting to happen
            * -- and the fit converges and prints a finite (enormous) subhazard
            * ratio when it does.  The count belongs next to the interval in the
            * output, where the reader can see what each estimate rests on.
            local _fg_tvnfail "`_fg_tvnfail' `r(N)'"
            if r(N) == 0 {
                display as error "tsplit() interval `_tv_j' (`_tv_lbl') contains no cause `cause' event"
                display as error "its coefficients are not identified by the subdistribution"
                display as error "likelihood, so the interval cannot be estimated"
                display as error "move or drop that boundary; the last cause event is the upper"
                display as error "limit of any usable tsplit() value"
                exit 459
            }
            if `_tv_j' < `_fg_nint' local _fg_lo : word `_tv_j' of `tsplit'
        }
        local _fg_tvnfail : list retokenize _fg_tvnfail
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
        if `_fg_reduced' quietly replace _t0 = `_fg_entryvar'

        * Combine multiple strata variables into a single group variable
        local _byg_mata "`strata'"
        if "`strata'" != "" {
            local _byg_nvar : word count `strata'
            if `_byg_nvar' > 1 {
                tempvar _byg_grp
                _finegray_weight_groups, strata(`strata') bygname(`_byg_grp')
                local _byg_mata "`_byg_grp'"
            }
        }

        * Truncation strata: the entry distribution H is estimated within these
        * groups. Empty means one pooled H group; H == 1 only when there is no
        * delayed entry, so the no-delayed-entry path remains bit-identical.
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
                    display as error "under delayed entry G is stratum-specific, H is pooled,"
                    display as error "and A is evaluated separately for every strata() level"
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

        * Baseline strata travel to the engine as the RAW variable.  The scans
        * map its values to 1..K themselves (uniqrows), so the fit and every
        * post-estimation rebuild agree about which stratum is which even when
        * the later call sees only some of the fit's rows.
        mata: _finegray_engine( ///
            "`varlist'", "`compete'", `cause', `censvalue', ///
            "`_byg_mata'", "`_tg_mata'", "`vce_type'", "`cluster'", ///
            `iterate', `tolerance', ("`log'" != "nolog"), ///
            ("`adjust'" != "noadjust"), ("`basehaz'" != ""), ///
            ("`nuisance'" != ""), "`bstrata'", ///
            "`_fg_tvcpos'", "`tsplit'")
    }

    local _rc_fit = _rc
    restore

    if `_rc_fit' {
        exit `_rc_fit'
    }

    * Baseline strata that contributed no cause event.  `_fg_bs_noevent' is set
    * in this scope by _finegray_engine via st_local; it is "" (or unset) when
    * every stratum has at least one.  These strata are not a fit error -- their
    * likelihood terms are empty -- but they have no baseline curve, so a later
    * CIF or basecshazard request for one of them fails closed at r(459).
    if "`_fg_bs_noevent'" != "" {
        display as text "(note: bstrata() level(s) `_fg_bs_noevent' contain no cause `cause' event;"
        display as text " they contribute no likelihood terms and have no baseline to predict from)"
    }

    * =========================================================================
    * RETRIEVE AND POST E() RESULTS
    * =========================================================================

    tempname b V
    matrix `b' = _finegray_b
    matrix `V' = _finegray_V

    * Column names.  For a factor-variable fit these are the terms the USER
    * typed (`1.pelnode', `1.pelnode#c.ifp'), taken from the fit-time expansion,
    * NOT the package-owned design-column names.  The internal names stay in
    * e(covariates), which is what the post-estimation rebuild machinery reads
    * and what finegray_predict re-stripes onto its own scoring copy of e(b);
    * the coefficient stripe is what the READER sees -- and with it `test',
    * `testparm', `estimates table' and every estout-style exporter.
    *
    * Before this, an interaction row printed as `_fg_pelnod~p' (the 12-char
    * abbreviation of _fg_pelnode_1Xifp) and was undecodable from the printed
    * output alone, `estimates table' exported the same names, and
    * `test 1.pelnode' failed r(111) -- the user had to discover and type
    * `test _fg_pelnode_1'.
    *
    * The count guard is not optional: `matrix colnames' given FEWER names than
    * columns silently repeats the last one across the remainder, which would
    * mislabel every coefficient at rc 0.  The capture guards a term the matrix
    * stripe parser will not take; a fit must never be lost over its labels.
    * One base name per DESIGN COLUMN.  Under tvc() the coefficient vector is
    * wider than the design (one coefficient per interval for each time-varying
    * column), so the stripe is built from these in a second step below rather
    * than being the stripe itself.
    local _fg_ncol : word count `varlist'
    local _fg_bnames "`varlist'"
    if `_has_fv' {
        local _cn_fv ""
        foreach _cn_t of local _fv_semantic {
            if regexm("`_cn_t'", "[0-9]+b\.") continue
            local _cn_fv "`_cn_fv' `_cn_t'"
        }
        local _cn_n : word count `_cn_fv'
        if `_cn_n' == `_fg_ncol' {
            local _cn_try : list retokenize _cn_fv
            capture matrix colnames `b' = `_cn_try'
            if _rc == 0 local _fg_bnames "`_cn_try'"
        }
    }

    * Piecewise beta(t) stripe.  The fixed-effect columns come first, in design
    * order, under equation `main'; then one equation per interval carrying the
    * time-varying columns.  Equation names are plain `tvcN' on purpose: the
    * interval bounds read better (`5 < _t <= 10') but `<' and `=' break
    * [eqname] parsing, so `test [tvc1]x = [tvc2]x' -- the Wald test of "is this
    * effect constant?", which is most of the reason to fit the model -- would
    * fail r(132).  _finegray_display prints the bounds under the table.
    local cnames ""
    local ceqs ""
    if "`tvc'" == "" {
        local cnames "`_fg_bnames'"
    }
    else {
        forvalues _cn_c = 1/`_fg_ncol' {
            local _cn_hit : list posof "`_cn_c'" in _fg_tvcpos
            if `_cn_hit' == 0 {
                local cnames "`cnames' `: word `_cn_c' of `_fg_bnames''"
                local ceqs "`ceqs' main"
            }
        }
        forvalues _cn_j = 1/`_fg_nint' {
            foreach _cn_c of local _fg_tvcpos {
                local cnames "`cnames' `: word `_cn_c' of `_fg_bnames''"
                local ceqs "`ceqs' tvc`_cn_j'"
            }
        }
        local cnames : list retokenize cnames
        local ceqs : list retokenize ceqs
    }

    * `matrix colnames' given FEWER names than columns silently repeats the LAST
    * one across the remainder, which mislabels every coefficient after the first
    * shortfall at rc 0.  Never let that happen by construction alone.
    local _cn_have : word count `cnames'
    if `_cn_have' != colsof(`b') {
        display as error "internal error: `_cn_have' coefficient name(s) for " ///
            "`=colsof(`b')' coefficients"
        exit 498
    }

    matrix colnames `b' = `cnames'
    matrix colnames `V' = `cnames'
    matrix rownames `V' = `cnames'
    if "`ceqs'" != "" {
        matrix coleq `b' = `ceqs'
        matrix coleq `V' = `ceqs'
        matrix roweq `V' = `ceqs'
    }

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
    * st_local (a string cannot ride back in a matrix). _finegray_weight_diag runs
    * on every fit (including the ordinary no-delayed-entry branch, where it scores
    * the A=G weights); the local is "" whenever nothing tripped a threshold.

    * Compute p-value from chi2
    if `_fg_chi2' != . & `_fg_df_m' > 0 {
        local _fg_p = chi2tail(`_fg_df_m', `_fg_chi2')
    }
    else {
        local _fg_p = .
    }

    * The values pooled as COMPETING, for the header.  "Competing events: status"
    * names the variable; a miscoded event code (a stray 9 alongside 2 and 3) is
    * then invisible in the output and the reader cannot verify what was pooled.
    * Computed here, after `restore', so the levelsof sort cannot perturb the row
    * order the engine consumed, and stored in e() so replay reports the same
    * list without re-reading data that may since have changed.
    local _fg_cvals ""
    if `N_compete' > 0 {
        quietly levelsof `compete' if `touse' & `compete' != `censvalue' ///
            & `compete' != `cause', local(_fg_cvals) clean
    }

    * Post results.  depname("_t") matches stcrreg: the modelled outcome is
    * time-to-cause on the stset clock, not the event-type variable, and a
    * `status |' stub said otherwise.  The event-type variable is e(compete).
    ereturn post `b' `V', obs(`N') esample(`touse') depname("_t") properties(b V)

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
    * Subjects whose earliest entry time is positive.  Reported in the header:
    * a delayed-entry fit and an ordinary one were display-indistinguishable,
    * and the ZZF weight construction is a materially different estimator.
    ereturn scalar N_delayed = `_fg_n_lt'
    * Baseline strata actually fitted.  1 on an unstratified fit, so a consumer
    * never has to test e(bstrata) for emptiness to know the baseline's shape:
    * e(k_bstrata) > 1 means e(basehaz) is K x 3 and every baseline lookup needs
    * a stratum.
    ereturn scalar k_bstrata = _finegray_kbstrata[1,1]
    * Piecewise beta(t) shape.  A consumer must be able to tell from e() alone
    * that e(b) is wider than e(covariates) and why: n_intervals is 1 on an
    * ordinary fit, so `e(n_intervals) > 1' is the single test for "this fit has
    * interval-specific coefficients".
    ereturn scalar n_intervals = `_fg_nint'
    ereturn scalar k_tvc = `_fg_ntv'
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
    * move e(b).  nuisance is absent for the same reason one level up: it changes
    * only the sandwich meat in e(V), never e(b), and the bootstrap consumers of
    * e(refitcmd) read only each replicate's e(b) -- replaying it would pay the
    * psi-term cost once per replication for a variance nobody reads.
    local _refitcmd `"finegray `_orig_varlist', compete(`compete') cause(`cause') censvalue(`censvalue') iterate(`iterate') tolerance(`tolerance') nolog"'
    if "`strata'" != ""          local _refitcmd `"`_refitcmd' strata(`strata')"'
    if "`truncstrata'" != ""     local _refitcmd `"`_refitcmd' truncstrata(`truncstrata')"'
    if "`bstrata'" != ""         local _refitcmd `"`_refitcmd' bstrata(`bstrata')"'
    if "`tvc'" != ""             local _refitcmd `"`_refitcmd' tvc(`tvc') tsplit(`tsplit')"'
    if "`cluster'" != ""         local _refitcmd `"`_refitcmd' cluster(`cluster')"'
    if "`robust'" == "norobust"  local _refitcmd `"`_refitcmd' norobust"'
    if "`adjust'" == "noadjust"  local _refitcmd `"`_refitcmd' noadjust"'
    ereturn local refitcmd `"`_refitcmd'"'

    ereturn local predict "finegray_predict"

    * Multiple-imputation contract.  A consumer must never have to infer from
    * the data in memory whether this fit left post-estimation support behind.
    *   e(mi_data)  "1" when the fit ran on mi data (typed directly on an mi
    *               dataset, or executed by `mi estimate, cmdok:' / `mi xeq');
    *               absent otherwise
    *   e(postest)  "unavailable_mi" on such a fit; absent otherwise.  This is
    *               the flag finegray_predict, finegray_cif, finegray_phtest and
    *               _finegray_check_data refuse on.
    * The coefficients and variance are ordinary M-estimator output and pool
    * under Rubin's rules exactly as they do off mi data; it is only the
    * row-level post-estimation, which needs the fit's design columns and its
    * single baseline hazard, that has nothing to run on.
    if `_fg_is_mi' {
        ereturn local mi_data "1"
        ereturn local postest "unavailable_mi"
    }

    ereturn local compete "`compete'"
    * The values `compete' takes in the estimation sample that are neither the
    * cause of interest nor the censoring value -- i.e. what was pooled as a
    * competing event.  Empty when there are none.
    ereturn local compete_values "`_fg_cvals'"
    ereturn local covariates "`varlist'"
    * The package-owned entry-time column of a multiple-record fit, empty for a
    * single-record fit.  It is also written to _dta[_finegray_entryvar], but a
    * dataset characteristic travels with the DATA and e() travels with the
    * ESTIMATES: after `estimates use' over a dataset saved BEFORE the fit, only
    * e() is left.  Post-estimation reads the characteristic first and falls
    * back to this, so a restored fit that needs an entry column it cannot see
    * fails closed by name instead of silently reverting to per-record _t0.
    ereturn local entryvar "`_fg_entryvar'"
    if `_has_fv' ereturn local fvvarlist "`_orig_varlist'"
    * The fit-time factor expansion, INCLUDING base terms (1b.grp).  This is the
    * semantic record of which level each coefficient belongs to.  Post-estimation
    * must align factor terms against this by LEVEL VALUE; re-expanding the
    * current data and matching positionally silently applies the fitted
    * coefficients to whatever levels happen to be present now.
    if `_has_fv' ereturn local fvsemantic "`_fv_semantic'"
    if "`strata'" != "" ereturn local strata "`strata'"
    if "`truncstrata'" != "" ereturn local truncstrata "`truncstrata'"
    * The BASELINE stratification variable.  A different axis from strata()
    * (censoring KM) and truncstrata() (entry distribution); see the option
    * table in help finegray.
    if "`bstrata'" != "" ereturn local bstrata "`bstrata'"
    * bstrata() levels that carried no cause event.  Their Breslow baseline is
    * identically zero -- a degenerate curve, not an estimate -- so every
    * baseline consumer refuses them by name.  Posted rather than recomputed
    * because `predict, cif' on NEW data is a documented workflow: the
    * estimation sample may be gone by the time the question is asked.
    if "`_fg_bs_noevent'" != "" ereturn local bstrata_noevent "`_fg_bs_noevent'"
    * Piecewise beta(t).
    *   e(tvc)            the variables the user named
    *   e(tsplit)         the interior boundaries, ascending
    *   e(tvc_covariates) the DESIGN COLUMNS those variables resolved to
    *   e(tvc_pos)        those columns' positions in e(covariates)
    * Post-estimation reads e(tvc_pos), not e(tvc_covariates): the design
    * columns are package-owned _fg_* variables that a supported `drop _fg_*'
    * removes and every rebuild path recreates as tempvars, so a NAME does not
    * survive the round trip and a position does.  The names are posted anyway
    * because they are what a reader needs to check the mapping tvc(x) made.
    if "`tvc'" != "" {
        ereturn local tvc "`tvc'"
        ereturn local tsplit "`tsplit'"
        ereturn local tvc_covariates "`_fg_tvccols'"
        ereturn local tvc_pos "`_fg_tvcpos'"
        * Cause events per interval, in interval order.  Reported in the
        * interval legend; a small count is the visible face of the monotone-
        * likelihood risk that a piecewise fit runs and a proportional one
        * does not.
        ereturn local tsplit_nfail "`_fg_tvnfail'"
    }
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
    *                       et al.; it requires factor-specific separability:
    *                       G may not vary across omitted truncation groups and H
    *                       may not vary across omitted censoring groups. It is
    *                       named apart from zzf1_stratified because its validity
    *                       conditions differ, so a consumer can branch on it.
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
    *   model_based          inverse information, no sandwich (Geskus 2011 p.44)
    *   fixed_weight_sandwich  score-residual sandwich that treats the estimated
    *                  censoring distribution G -- and, under delayed entry, the
    *                  entry distribution H, carried as A = G(t-)H(t-) -- as
    *                  FIXED.  It is cluster-robust when cluster() is given.  This
    *                  is NOT the full Fine-Gray (1999) eq. 7-8 / ZZF (2011)
    *                  nuisance-adjusted variance: the two-part influence term for
    *                  having ESTIMATED G (and H) is not added.  That term's
    *                  explicit form is in ZZF (2011) Appendix B, whose display
    *                  equations are images in every copy obtainable and are not
    *                  being written from memory (see literature/_requested.md);
    *                  its omission is documented and, in the right-censored and
    *                  tested left-truncated settings, empirically small (see
    *                  finegray.sthlp, Variance).  For nuisance-adjusted
    *                  coefficient inference, bootstrap the whole fit (help
    *                  finegray, "Bootstrap coefficient inference").
    *   not_applicable no delayed entry -- the right-censoring branch is unchanged
    *                  from prior releases and its variance is not at issue here
    if !`_fg_has_lt'                      ereturn local lt_vce "not_applicable"
    else if "`robust'" == "norobust"      ereturn local lt_vce "model_based"
    else                                  ereturn local lt_vce "fixed_weight_sandwich"

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
    * Observations whose censoring survivor G(t) was floored at 1e-10 during the
    * fit's own KM sweep.  `_fg_ntrunc' is set directly in this scope by
    * _finegray_km_censor via st_local (see its header for why it reports rather
    * than prints).  Missing would be indistinguishable from "none", so treat an
    * unset local as a broken contract rather than as a reassuring zero.
    if "`_fg_ntrunc'" == "" {
        display as error "internal error: the G(t) truncation count was not returned"
        exit 498
    }
    ereturn scalar N_G_trunc = `_fg_ntrunc'
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
    * Which sandwich meat was used.  A consumer must never have to infer from
    * the option list whether the FG (1999) eq. 7-8 psi term is in e(V).
    *   fixed_weight   sum_i eta_i^(x)2        -- G treated as known (default)
    *   nuisance_adjusted  sum_i (eta_i+psi_i)^(x)2 -- G estimated (nuisance)
    *   not_applicable model-based variance; no sandwich meat exists
    if "`robust'" == "norobust"      ereturn local vce_meat "not_applicable"
    else if "`nuisance'" != ""       ereturn local vce_meat "nuisance_adjusted"
    else                             ereturn local vce_meat "fixed_weight"
    ereturn local title "Fine-Gray competing risks regression"
    * margins consumes xb as a single linear predictor.  Under tvc() there is no
    * single xb: the linear predictor depends on which interval the evaluation
    * time falls in, and margins has no way to say which.  Withdraw it rather
    * than let margins average a quantity it cannot address.
    if `_has_fv' | "`tvc'" != "" {
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

    * Store dataset chars for predict.
    *
    * NOT on mi data.  These characteristics are the receipt for the permanent
    * support columns, and on mi data there are none: the entry column and every
    * _fg_<term> design column were tempvars and are about to be dropped.  A
    * receipt naming columns that no longer exist is the rc=0-but-wrong shape
    * this package spends most of its comments avoiding -- worse here than
    * elsewhere, because a tempvar NAME is reused by the next command that asks
    * for one, so a stale e(covariates)/char pair could resolve to somebody
    * else's column rather than failing to resolve at all.
    *
    * What is left standing instead is the "0" (INVALIDATED) mark written before
    * the fit began mutating anything, so _finegray_check_data refuses this
    * dataset outright.  The explicit e(postest) guards in finegray_predict,
    * finegray_cif and finegray_phtest fire first and name the actual reason.
    if !`_fg_is_mi' {
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
    }

    * =========================================================================
    * DISPLAY RESULTS
    * =========================================================================
    * The whole display lives in _finegray_display and reads e() only, so a
    * replay (`finegray' with no varlist) reproduces the fit-time output exactly
    * rather than a second, drifting copy of it.  Every quantity it needs is
    * posted above -- including e(N_delayed) and e(compete_values), which exist
    * for no other reason.
    _finegray_display, level(`level') `shr'

    } /* end capture noisily */

    local rc = _rc

    * Clean up temporary matrices (runs on both success and error paths)
    foreach m in _finegray_b _finegray_V _finegray_ll _finegray_ll_0 ///
        _finegray_chi2 _finegray_df_m _finegray_conv ///
        _finegray_rank _finegray_nclust _finegray_basehaz ///
        _finegray_kbstrata ///
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
