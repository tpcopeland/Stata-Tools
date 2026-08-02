*! finegray_phtest Version 1.2.0  2026/08/02
*! Proportional subdistribution hazards diagnostic after finegray
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
Basic syntax:
  finegray_phtest [, time(rank|log|identity) detail]

Description:
  Exploratory diagnostic for the proportional subdistribution hazards
  assumption after finegray. Computes raw Schoenfeld residuals and reports, per
  covariate, the CORRELATION between the residual and a function of event time.
  It reports no chi-squared statistic and no p-value:
  no null calibration is implemented or established here for this simple
  marginal correlation statistic under the subdistribution-hazards model, so
  a nominal p-value would assert a level the package has not established. A
  correlation far from zero flags a covariate for follow-up with a published
  PSH diagnostic or time-effects implementation. No omnibus statistic is
  reported.

Options:
  time(string)  - time function: rank (default), log, identity
  detail        - display raw Schoenfeld residuals

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
    * otherwise return rc 0 with a diagnostic computed at a non-solution.
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

    * For FV models: label every design column with the term the user typed,
    * and reconstruct the columns themselves if they have been dropped.
    *
    * THE LABELLING IS NOT GATED ON THE REBUILD.  Through 2026-07-20 it was,
    * and the effect was that one fit described itself two different ways: the
    * table said `_fg_pelnode_2' while finegray's own design columns were still
    * in memory, and `2.pelnode' once the user dropped them -- which is a
    * documented, supported thing to do.  Same fit, same correlations, two
    * vocabularies, and the internal spelling is the one the user never typed.
    * The names are a property of the FIT, not of what happens to survive in
    * memory afterwards, so they are computed whenever e(fvvarlist) is set.
    *
    * Both the names and the rebuilt columns come from e(fvsemantic), the
    * fit-time expansion, via _finegray_fv_design.  Through 2026-07-21 this
    * block re-ran fvexpand/fvrevar on the CURRENT data instead, which made an
    * fvset base change between the fit and this call silently relabel -- and,
    * once the columns had been dropped, silently recompute -- the whole table
    * at rc 0.  See that helper's header for the observed numbers.
    local covlabels "`covariates'"
    if `"`e(fvvarlist)'"' != "" {
        _finegray_fv_design, caller("finegray_phtest")
        * Copy the whole r() payload out BEFORE anything else touches r().
        local _fvk = r(k)
        local covlabels "`r(terms)'"
        forvalues _j = 1/`_fvk' {
            local _fvexpr`_j' "`r(expr`_j')'"
        }

        local _need_rebuild = 0
        foreach _cov of local covariates {
            capture confirm variable `_cov'
            if _rc {
                local _need_rebuild = 1
                continue, break
            }
        }

        if `_need_rebuild' {
            * Built only over e(sample); outside it a `(race == 2)' indicator
            * would read a missing race as 0 and quietly assign the base
            * category.  _finegray_check_data has already verified the data
            * signature over e(sample).
            local _rebuild_varlist ""
            forvalues _j = 1/`_fvk' {
                local _tvname "_fg_ph_`_j'"
                tempvar `_tvname'
                quietly gen double ``_tvname'' = `_fvexpr`_j'' if e(sample)
                local _rebuild_varlist "`_rebuild_varlist' ``_tvname''"
            }
            local covariates : list retokenize _rebuild_varlist
        }

        local _n_lab : word count `covlabels'
        local _n_score : word count `covariates'
        if `_n_lab' != `_n_score' | `_n_score' != colsof(e(b)) {
            display as error "reconstructed FV design does not match stored coefficients"
            display as error "(`_n_score' columns, `_n_lab' labels, `=colsof(e(b))' coefficients)"
            exit 198
        }
        local p = `_n_score'
    }

    * Preserve and compute Schoenfeld residuals on estimation sample
    preserve
    local _preserved = 1
    quietly keep if e(sample)

    * Sort on a TOTAL key, not a bare `sort _t'.  _t is heavily tied, Stata
    * breaks sort ties with a seed that ADVANCES on every sort, and the Mata
    * scan breaks its own ties by ROW INDEX (order((t, row_id), (1, 2)) in
    * _finegray_schoenfeld) -- so the row order this command hands the engine
    * IS the tiebreak.  With a bare `sort _t' two identical calls accumulate
    * the risk sets in different floating-point orders and the reported
    * correlations differ in their last digits; measured 8e-16 across six
    * identical calls on a 1200-subject fixture with 248 rows at the modal
    * event time.  finegray.ado:792 and finegray_predict.ado:700,777 already
    * stamp a row id for exactly this reason; this command was the one that
    * did not.  Guarded by test_finegray_determinism.do.
    tempvar _ph_row0
    quietly gen long `_ph_row0' = _n
    sort _t `_ph_row0'

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

    * Compute raw Fine-Gray Schoenfeld residuals via Mata. Earlier 1.2.0
    * prerelease code requested a package-specific diagonal rescaling whose
    * applicability to this estimator was not grounded. The rescaling could
    * not change the reported correlation but did change detail's units.
    local _tg_mata ""
    if `"`e(truncstrata)'"' != "" {
        tempvar _tg_grp
        _finegray_weight_groups, truncstrata(`e(truncstrata)') tgname(`_tg_grp')
        local _tg_mata "`_tg_grp'"
    }

    mata: _finegray_schoenfeld_compute( ///
        "`covariates'", "`events'", `cause', `censvalue', ///
        "`_byg_mata'", "`_tg_mata'", 0, "`_t0var'")

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
    * returns a missing rho -- which v1.1.0 reported at rc 0, as a completed
    * diagnostic with blank statistics.
    tempname _uniqt
    mata: st_numscalar("`_uniqt'", ///
        rows(uniqrows(st_matrix("`sch_mat'")[., 1])))
    if scalar(`_uniqt') < 2 {
        display as error "all `n_fail' cause events occur at a single time"
        display as error "the proportional-hazards diagnostic correlates Schoenfeld"
        display as error "residuals against a function of event time, which is"
        display as error "undefined when event time does not vary"
        exit 459
    }

    * Build diagnostic results: p x 2 matrix [correlation, n_event_times].
    * This command reports the raw-Schoenfeld/time CORRELATION as an
    * exploratory diagnostic only.  It deliberately does NOT form chi2 = n*rho^2
    * or a p-value: no null calibration is implemented or established here for
    * that simple statistic under the proportional SUBDISTRIBUTION hazards model.
    * A printed Prob>chi2 would assert a nominal level the package has not
    * established. Users needing formal inference must use a published
    * subdistribution-PH test or an implementation that supports PSH time effects.
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
        display as error "proportional-hazards diagnostic is undefined for:`_undef'"
        display as error "the Schoenfeld residuals for these terms do not vary"
        display as error "across cause-event times, so no correlation exists"
        exit 459
    }

    * No omnibus statistic is reported. Through v1.1.0 this command summed
    * per-covariate 1-df statistics and used chi2(p) without estimating their
    * joint covariance, so the printed probability had no established null
    * distribution. Zhou et al. (2013) and Li, Scheike & Zhang (2015) give
    * formal methods, but this descriptive correlation is neither method and
    * is not a collection of p-values to adjust.

    * Label test matrix
    local rownames ""
    foreach v of local covlabels {
        local rownames "`rownames' `v'"
    }
    matrix rownames `test_mat' = `rownames'
    matrix colnames `test_mat' = correlation events

    * Display results.  This is a DIAGNOSTIC, not a test: it reports the
    * correlation between each raw Schoenfeld residual and the time function.
    * A correlation far from zero is a sign of nonproportionality worth
    * following up with a published PSH method; it is not referred to any null
    * distribution and carries no p-value.
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
    display as text "Correlation of the raw Schoenfeld residual with the time"
    display as text "function; exploratory diagnostic only, no test or p-value is"
    display as text "reported.  See {bf:help finegray_phtest}."

    * Return results.  r(phtest) carries the diagnostic correlations (and the
    * per-covariate event count), NOT chi2/df/p -- those are deliberately absent.
    return scalar N_fail = `n_fail'
    return local time "`time'"
    return local residual_scale "raw"
    return matrix phtest = `test_mat'

    if "`detail'" != "" {
        display as text ""
        display as text "Raw Schoenfeld residuals (first 20 rows):"
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
