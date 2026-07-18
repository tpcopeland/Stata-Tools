*! finegray_phtest Version 1.2.0  2026/07/18
*! Proportional subdistribution hazards diagnostic after finegray
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
Basic syntax:
  finegray_phtest [, time(rank|log|identity) detail]

Description:
  Exploratory diagnostic for the proportional subdistribution hazards
  assumption after finegray.  Computes scaled Schoenfeld residuals and reports,
  per covariate, the CORRELATION between the residual and a function of event
  time (diagonal scaling).  It reports no chi-squared statistic and no p-value:
  no published null calibration exists for the marginal n*rho^2 statistic under
  the subdistribution-hazards model, so a nominal p-value would assert a level
  the package has not established.  A correlation far from zero flags a covariate
  for follow-up (residual plot; time-interaction fit).  No omnibus statistic is
  reported.

Options:
  time(string)  - time function: rank (default), log, identity
  detail        - display scaled Schoenfeld residuals

See help finegray_phtest for complete documentation
*/

program define finegray_phtest, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _preserved = 0

    capture noisily {

    syntax [, TIME(string) DETail]

    * Check finegray was run
    if "`e(cmd)'" != "finegray" {
        display as error "last estimates not found"
        display as error "you must run {bf:finegray} before using finegray_phtest"
        exit 301
    }
    * Schoenfeld residuals are defined against the fitted beta. A last iterate
    * that is not a solution makes the PH test meaningless -- and it would
    * otherwise return rc 0 with a chi2 and a p-value.
    if e(converged) != 1 {
        display as error "last estimates did not converge"
        display as error "finegray_phtest requires a converged fit; refit finegray"
        display as error "with a larger iterate() or a different specification"
        exit 430
    }
    _finegray_check_data

    * Default time function
    if "`time'" == "" local time "rank"
    if !inlist("`time'", "rank", "log", "identity") {
        display as error "time() must be rank, log, or identity"
        exit 198
    }

    * Get model info from e()
    local covariates "`e(covariates)'"
    local events "`e(compete)'"
    local cause = e(cause)
    local censvalue = e(censvalue)
    local byg "`e(strata)'"
    local p : word count `covariates'

    if `p' == 0 {
        display as error "no covariates in model"
        exit 198
    }

    * Preflight: schoenfeld residuals require original stset estimation data
    capture confirm variable _t
    if _rc {
        display as error "variable _t not found"
        display as error "finegray_phtest requires the original stset estimation data"
        exit 111
    }
    capture confirm variable _d
    if _rc {
        display as error "variable _d not found"
        display as error "finegray_phtest requires the original stset estimation data"
        exit 111
    }
    quietly count if e(sample)
    if r(N) == 0 {
        display as error "no observations in estimation sample"
        display as error "finegray_phtest requires the original stset estimation data"
        exit 2000
    }

    * Entry-time source: multi-record fits persist each subject's earliest
    * entry in a finegray-created variable; single-record fits use _t0.
    local _t0var "_t0"
    if `"`_dta[_finegray_entryvar]'"' != "" {
        local _t0var `"`_dta[_finegray_entryvar]'"'
        capture confirm numeric variable `_t0var'
        if _rc {
            display as error "variable `_t0var' not found"
            display as error "finegray recorded subject entry times in `_t0var' for its"
            display as error "multiple-record reduction; re-run finegray before finegray_phtest"
            exit 111
        }
    }

    * Load Mata engine
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

    * For FV models, reconstruct the design matrix if _fg_* columns are gone
    local covlabels "`covariates'"
    if `"`e(fvvarlist)'"' != "" {
        local _need_rebuild = 0
        foreach _cov of local covariates {
            capture confirm variable `_cov'
            if _rc {
                local _need_rebuild = 1
                continue, break
            }
        }
        if `_need_rebuild' {
            capture noisily fvexpand `e(fvvarlist)' if e(sample)
            if _rc {
                display as error "unable to expand factor-variable terms for PH test"
                exit _rc
            }
            local _fv_semantic `r(varlist)'

            capture noisily fvrevar `e(fvvarlist)' if e(sample)
            if _rc {
                display as error "unable to reconstruct factor-variable design for PH test"
                exit _rc
            }
            local _fv_actual `r(varlist)'

            local _n_sem : word count `_fv_semantic'
            local _n_act : word count `_fv_actual'
            if `_n_sem' != `_n_act' {
                display as error "internal error: fvexpand/fvrevar mismatch in PH test"
                exit 198
            }

            local _rebuild_varlist ""
            local _rebuild_labels ""
            forvalues _i = 1/`_n_sem' {
                local _term : word `_i' of `_fv_semantic'
                local _var : word `_i' of `_fv_actual'
                local _label_term = subinstr("`_term'", "c.", "", .)
                if regexm("`_term'", "[0-9]+b\.") {
                    continue
                }
                if substr("`_var'", 1, 2) != "__" {
                    local _rebuild_varlist "`_rebuild_varlist' `_var'"
                    local _rebuild_labels "`_rebuild_labels' `_label_term'"
                    continue
                }
                local _tvname "_fg_ph_`_i'"
                tempvar `_tvname'
                local _tv ``_tvname''
                quietly gen double `_tv' = `_var'
                local _rebuild_varlist "`_rebuild_varlist' `_tv'"
                local _rebuild_labels "`_rebuild_labels' `_label_term'"
            }

            local covariates : list retokenize _rebuild_varlist
            local covlabels : list retokenize _rebuild_labels

            local _n_score : word count `covariates'
            local _n_b = colsof(e(b))
            if `_n_score' != `_n_b' {
                display as error "reconstructed FV design does not match stored coefficients"
                exit 198
            }
            local p : word count `covariates'
        }
    }

    * Preserve and compute Schoenfeld residuals on estimation sample
    preserve
    local _preserved = 1
    quietly keep if e(sample)

    sort _t

    * Combine byg variables if multiple
    local _byg_mata "`byg'"
    if "`byg'" != "" {
        local _byg_nvar : word count `byg'
        if `_byg_nvar' > 1 {
            tempvar _byg_grp
            quietly egen long `_byg_grp' = group(`byg')
            local _byg_mata "`_byg_grp'"
        }
    }

    * Compute scaled Schoenfeld residuals via Mata
    local _tg_mata ""
    if `"`e(truncstrata)'"' != "" {
        tempvar _tg_grp
        _finegray_weight_groups, truncstrata(`e(truncstrata)') tgname(`_tg_grp')
        local _tg_mata "`_tg_grp'"
    }

    mata: _finegray_schoenfeld_compute( ///
        "`covariates'", "`events'", `cause', `censvalue', ///
        "`_byg_mata'", "`_tg_mata'", 1, "`_t0var'")

    restore
    local _preserved = 0

    * Retrieve the Schoenfeld matrix (n_fail x (p+1))
    tempname sch_mat
    matrix `sch_mat' = _finegray_schoenfeld
    capture matrix drop _finegray_schoenfeld

    local n_fail = rowsof(`sch_mat')

    if `n_fail' < 3 {
        display as error "too few cause events (`n_fail') for PH test"
        exit 198
    }

    * The test correlates each Schoenfeld residual with a function of the event
    * TIME, so it is undefined unless the event times actually vary.  With every
    * cause event at a single time the time function is constant, correlate()
    * returns a missing rho, and chi2 = n*rho^2 and its p-value are missing --
    * which v1.1.0 reported at rc 0, as a completed test with blank statistics.
    tempname _uniqt
    mata: st_numscalar("`_uniqt'", ///
        rows(uniqrows(st_matrix("`sch_mat'")[., 1])))
    if scalar(`_uniqt') < 2 {
        display as error "all `n_fail' cause events occur at a single time"
        display as error "the proportional-hazards test correlates the Schoenfeld"
        display as error "residuals against a function of event time, which is"
        display as error "undefined when event time does not vary"
        exit 459
    }

    * Build diagnostic results: p x 2 matrix [correlation, n_event_times].
    * This command reports the scaled-Schoenfeld/time CORRELATION as an
    * exploratory diagnostic only.  It deliberately does NOT form chi2 = n*rho^2
    * or a p-value: no published null calibration exists for that statistic under
    * the proportional SUBDISTRIBUTION hazards model (the Cox Grambsch-Therneau
    * reference distribution does not transfer -- see the long note below), so a
    * printed Prob>chi2 would assert a nominal level the package has not
    * established.  Users needing a formal test should fit the time-interaction
    * model directly or use a published subdistribution PH test.
    tempname test_mat
    matrix `test_mat' = J(`p', 2, .)

    * Load Schoenfeld matrix into a temporary dataset once (svmat),
    * then loop correlations over columns — avoids O(p) preserve/clear cycles.
    tempvar _tfunc
    preserve
    local _preserved = 1
    quietly {
        clear
        svmat double `sch_mat', names(_sch)

        * _sch1 = time, _sch2.._sch`=`p'+1' = residuals per covariate
        if "`time'" == "rank" {
            egen double `_tfunc' = rank(_sch1)
        }
        else if "`time'" == "log" {
            gen double `_tfunc' = ln(_sch1)
        }
        else {
            gen double `_tfunc' = _sch1
        }
    }

    forvalues v = 1/`p' {
        local col = `v' + 1
        quietly correlate _sch`col' `_tfunc'
        local rho = r(rho)
        local n_corr = r(N)

        if `n_corr' < `n_fail' {
            local vname : word `v' of `covlabels'
            noisily display as text ///
                "note: `=`n_fail'-`n_corr'' event times produced " ///
                "missing values after `time' transform for `vname'"
        }

        * A missing rho means the residual or the time function had no variation,
        * so this variable's diagnostic does not exist.  It must not be reported
        * as a blank row -- flag it and refuse rather than emit a hollow zero.
        if missing(`rho') {
            local vname : word `v' of `covlabels'
            local _undef "`_undef' `vname'"
            continue
        }

        matrix `test_mat'[`v', 1] = `rho'
        matrix `test_mat'[`v', 2] = `n_corr'
    }
    restore
    local _preserved = 0

    if "`_undef'" != "" {
        display as error "proportional-hazards test is undefined for:`_undef'"
        display as error "the Schoenfeld residuals for these terms do not vary"
        display as error "across cause-event times, so no correlation exists"
        exit 459
    }

    * No omnibus statistic is reported.  Through v1.1.0 this command summed the
    * per-covariate 1-df statistics and referred the total to chi2(p).  That is
    * valid only if the components are independent; the scaled Schoenfeld
    * residuals are correlated across covariates whenever the covariates are,
    * so the printed Prob>chi2 had no stated reference distribution and its
    * error was in an unknown direction.
    *
    * The obvious repair -- build the joint quadratic form from the p x p
    * inverse information, as Grambsch-Therneau (1994) do for the Cox model --
    * does NOT transfer to this estimator.  GT's null covariance for the scaled
    * residuals is the Cox information, an identity that holds because the Cox
    * score is a martingale integral.  finegray's score is IPCW-weighted with an
    * ESTIMATED censoring distribution, so its true variance is a sandwich and in
    * principle carries an extra term for that estimation (Fine & Gray 1999, eq.
    * 7-8; Bellach et al. 2019, Sec. 3.3: "this additional variability cannot be
    * ignored").  That is why the fit defaults to a sandwich rather than the
    * inverse information -- though the shipped default is the FIXED-WEIGHT
    * sandwich (e(lt_vce)=fixed_weight_sandwich), which does not add that extra
    * term either.  Reusing the information as a null covariance here would
    * reintroduce the same defect -- an unstated reference distribution -- in a
    * form that merely looks rigorous.
    *
    * No published omnibus test for the proportional SUBDISTRIBUTION hazards
    * assumption is implemented here.  Candidates exist (Zhou et al. 2013, Stat
    * Med 32:3804-3811, a score test on modified Schoenfeld residuals; Li,
    * Scheike & Zhang 2015, Lifetime Data Anal, cumulative sums of residuals),
    * but neither is grounded in this package's literature corpus yet.  PSHREG
    * (Kohl et al. 2015), the closest reference implementation, likewise reports
    * only per-covariate correlation tests and residual plots.  Users needing a
    * global claim should Bonferroni-adjust across the p rows below, or fit the
    * time-interaction model directly.

    * Label test matrix
    local rownames ""
    foreach v of local covlabels {
        local rownames "`rownames' `v'"
    }
    matrix rownames `test_mat' = `rownames'
    matrix colnames `test_mat' = correlation events

    * Display results.  This is a DIAGNOSTIC, not a test: it reports the
    * correlation between each scaled Schoenfeld residual and the time function.
    * A correlation far from zero is a sign of nonproportionality worth
    * following up (plot the residual, fit the time interaction); it is not
    * referred to any null distribution and carries no p-value.
    display as text ""
    display as text "Proportional subdistribution hazards diagnostic (exploratory)"
    display as text ""
    display as text "Time function: " as result "`time'"
    display as text "Cause events:  " as result "`n_fail'"
    display as text ""

    display as text "{hline 13}{c TT}{hline 30}"
    display as text %12s "Variable" " {c |}" ///
        %14s "correlation" %10s "events"
    display as text "{hline 13}{c +}{hline 30}"

    forvalues v = 1/`p' {
        local vname : word `v' of `covlabels'
        local rho_v = `test_mat'[`v', 1]
        local n_v   = `test_mat'[`v', 2]
        display as text %12s abbrev("`vname'", 12) " {c |}" ///
            as result %14.4f `rho_v' %10.0f `n_v'
    }

    display as text "{hline 13}{c BT}{hline 30}"
    display as text ""
    display as text "Correlation of the scaled Schoenfeld residual with the time"
    display as text "function; exploratory diagnostic only, no test or p-value is"
    display as text "reported.  See {bf:help finegray_phtest}."

    * Return results.  r(phtest) carries the diagnostic correlations (and the
    * per-covariate event count), NOT chi2/df/p -- those are deliberately absent.
    return scalar N_fail = `n_fail'
    return local time "`time'"
    return matrix phtest = `test_mat'

    if "`detail'" != "" {
        display as text ""
        display as text "Scaled Schoenfeld residuals (first 20 rows):"
        local show_rows = min(`n_fail', 20)
        tempname sch_show
        matrix `sch_show' = `sch_mat'[1..`show_rows', 1...]
        local colnames "time"
        foreach v of local covlabels {
            local colnames "`colnames' `v'"
        }
        matrix colnames `sch_show' = `colnames'
        matrix list `sch_show', format(%9.4f) noheader
    }

    } /* end capture noisily */

    local rc = _rc
    if `_preserved' capture restore
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
