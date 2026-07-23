*! msm_predict Version 1.2.4  2026/07/23
*! Counterfactual predictions from marginal structural models
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  msm_predict, times(numlist) [options]

Description:
  Generates counterfactual predictions under always-treated and
  never-treated strategies. Uses Monte Carlo simulation from the
  coefficient distribution (Cholesky decomposition) for CIs.

  For pooled logistic models: computes individual-level discrete-time
  survival via G-formula standardization, then averages across the
  reference population (individuals at baseline).

Options:
  times(numlist)      - Time periods for prediction (required)
  strategy(string)    - always | never | both (default: both)
  type(string)        - cum_inc (default) | survival
  samples(#)          - MC samples for CIs (default: 100)
  seed(#)             - Random seed
  level(#)            - Confidence level (default: 95)
  difference          - Compute treatment contrast (risk difference)
  extrapolate         - Allow predictions beyond observed follow-up

See help msm_predict for complete documentation
*/

program define msm_predict, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    local _restore_needed = 0
    set varabbrev off
    set more off


    * Several steps below use bysort over each individual's history, which
    * leaves the caller's observations in id/period order. Capture the incoming
    * order now and restore it on every exit path (audit A06).
    tempvar _msm_orig_order

    capture noisily {

    quietly gen long `_msm_orig_order' = _n

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    * times() accepts the external period scale, which may be signed when the
    * fit used negative external periods (audit A17). The lower bound is enforced
    * against the fitted risk-set support below, not by the numlist range.
    syntax , TIMEs(numlist sort integer) ///
        [STRAtegy(string) TYPe(string) SAMPles(integer 100) ///
         SEED(integer -1) Level(cilevel) DIFFerence EXTRApolate]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================

    _msm_check_fitted
    _msm_get_settings

    local id        "`_msm_id'"
    local period    "`_msm_period'"
    local treatment "`_msm_treatment'"
    local outcome   "`_msm_outcome'"

    * Get model info
    local model            : char _dta[_msm_model]
    local period_spec      : char _dta[_msm_period_spec]
    local outcome_cov      : char _dta[_msm_outcome_cov]
    local predict_disabled : char _dta[_msm_predict_disabled]
    local history_spec     : char _dta[_msm_history_spec]

    * =========================================================================
    * DEFAULTS AND VALIDATION
    * =========================================================================

    if "`strategy'" == "" local strategy "both"
    if "`type'" == "" local type "cum_inc"

    * The contrast is a difference of the DISPLAYED quantity: a risk difference
    * under cum_inc (F1-F0), a survival difference under survival (S1-S0). The
    * old code always computed always-minus-never and returned/labelled it a
    * "risk difference", so under survival it silently reported -(F1-F0) as a
    * risk difference (audit A14). Label and name the return by the actual type.
    local diff_label  = cond("`type'" == "survival", "Survival difference", "Risk difference")
    local diff_prefix = cond("`type'" == "survival", "sd", "rd")

    if !inlist("`strategy'", "always", "never", "both") {
        display as error "strategy() must be always, never, or both"
        exit 198
    }
    if !inlist("`type'", "cum_inc", "survival") {
        display as error "type() must be cum_inc or survival"
        exit 198
    }
    if `samples' < 10 {
        display as error "samples() must be at least 10"
        exit 198
    }
    if "`predict_disabled'" == "1" {
        display as error "msm_predict is not available for this fit"
        display as error "msm_fit used exposure() or tvcov(); counterfactual standardization is undefined for a continuous or time-varying exposure model."
        display as error "Use msm_report, msm_table, or msm_sensitivity instead."
        exit 198
    }
    if "`model'" != "logistic" {
        display as error "msm_predict currently only supports logistic model"
        display as error "Use msm_report, msm_table, or msm_sensitivity for non-logistic fits."
        exit 198
    }
    if "`outcome_cov'" != "" {
        _msm_timefixed `outcome_cov', id(`id')
        local varying_outcome_cov "`r(varying)'"
        if "`varying_outcome_cov'" != "" {
            display as error "msm_predict requires outcome_cov() variables to be time-fixed within id"
            display as error "These variables vary over time: `varying_outcome_cov'"
            display as error "Refit {bf:msm_fit} without time-varying outcome_cov() terms before predicting."
            exit 198
        }
    }
    local seed_source "session_rng_state"
    if `seed' >= 0 {
        set seed `seed'
        local seed_source "seed()"
        local seed_used "`seed'"
    }
    else {
        local seed_used `"`c(seed)'"'
    }
    local seed_state `"`c(seed)'"'

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as result "msm_predict" as text " - Counterfactual Predictions"
    display as text "{hline 70}"
    display as text ""
    display as text "Strategy:         " as result "`strategy'"
    display as text "Prediction type:  " as result "`type'"
    display as text "MC samples:       " as result "`samples'"
    if "`seed_source'" == "seed()" {
        display as text "Seed used:        " as result "`seed_used'"
    }
    else {
        local seed_preview = substr("`seed_state'", 1, 32)
        display as text "Seed used:        " as result "`seed_preview'..." ///
            as text " (session RNG state)"
    }
    display as text "Confidence level: " as result "`level'%"
    if "`difference'" != "" {
        if "`strategy'" != "both" {
            display as text "Note: difference requires strategy(both); ignored."
            local difference ""
        }
        else {
            display as text "`diff_label':  " as result "Yes"
        }
    }
    display as text ""

    * =========================================================================
    * GET COEFFICIENT VECTOR AND VARIANCE MATRIX
    * =========================================================================

    tempname b_hat V_hat
    matrix `b_hat' = _msm_fit_b
    matrix `V_hat' = _msm_fit_V
    local n_coefs = colsof(`b_hat')

    * =========================================================================
    * PREPARE PREDICTION DATA
    * =========================================================================

    display as text "Computing predictions..."

    preserve
    local _restore_needed = 1

    * -------------------------------------------------------------------------
    * Fitted risk-set support (audit A15)
    *
    * Prediction support is defined by the periods that actually contributed a
    * fitted risk set (_msm_esample == 1), NOT by the raw data range. Post-event,
    * post-censor, and held-out rows can extend `period' well beyond the fitted
    * support; validating times() against the raw max silently authorized
    * extrapolation. _msm_esample is created by every msm_fit, so require it.
    * -------------------------------------------------------------------------
    capture confirm variable _msm_esample
    if _rc != 0 {
        display as error "msm_predict requires the fitted estimation-sample marker _msm_esample"
        display as error "Re-run {bf:msm_fit}: prediction support is defined by the fitted risk sets."
        restore
        local _restore_needed = 0
        exit 198
    }
    quietly summarize `period' if _msm_esample == 1
    if r(N) == 0 {
        display as error "the fitted estimation sample (_msm_esample) is empty; cannot define prediction support"
        restore
        local _restore_needed = 0
        exit 2000
    }
    local min_period = r(min)
    local max_period = r(max)
    local min_support = r(min)
    local max_support = r(max)

    * Validate requested times against the fitted support. Beyond the support,
    * only explicit extrapolate proceeds, and it is flagged in the returns.
    local extrapolated = 0
    foreach t of local times {
        if `t' < `min_support' {
            display as error "times() value `t' is less than the first fitted period (`min_support')"
            restore
            local _restore_needed = 0
            exit 198
        }
        if `t' > `max_support' {
            if "`extrapolate'" == "" {
                display as error "times() value `t' exceeds the fitted risk-set support (max fitted period `max_support')"
                display as error "Post-event/censor rows may extend the data further, but the fit does not support this period."
                display as error "Use the {bf:extrapolate} option to allow predictions beyond fitted support."
                restore
                local _restore_needed = 0
                exit 198
            }
            local extrapolated = 1
        }
    }
    if `extrapolated' {
        display as text "  Warning: one or more times() exceed fitted support `max_support'; extrapolating."
    }

    quietly keep if `period' == `min_support'
    quietly keep if _msm_esample == 1
    quietly bysort `id': keep if _n == 1

    local n_ref = _N
    if `n_ref' == 0 {
        display as error "no reference population remains for prediction"
        display as error "msm_predict requires at least one baseline row in the fitted estimation sample."
        display as error "Re-run {bf:msm_fit} or check why baseline rows are excluded from _msm_esample."
        restore
        local _restore_needed = 0
        capture matrix drop _msm_pred_matrix
        char _dta[_msm_pred_saved]
        char _dta[_msm_pred_type]
        char _dta[_msm_pred_strategy]
        char _dta[_msm_pred_level]
        exit 2000
    }

    * Number of prediction times
    local n_times: word count `times'

    * Parse max requested time
    local last_time: word `n_times' of `times'

    * Initialize results matrix
    * Columns: time | est_never | lo_never | hi_never | est_always | lo_always | hi_always [| diff | diff_lo | diff_hi]
    local n_cols = 7
    if "`difference'" != "" local n_cols = 10
    tempname results
    matrix `results' = J(`n_times', `n_cols', .)

    local time_idx = 0
    foreach t of local times {
        local ++time_idx
        matrix `results'[`time_idx', 1] = `t'
    }

    * CI percentiles
    local alpha = (100 - `level') / 2
    local lo_pct = `alpha'
    local hi_pct = 100 - `alpha'

    * =====================================================================
    * POINT ESTIMATES
    * =====================================================================

    * For strategy "never" (treatment=0) and "always" (treatment=1)
    local strategies ""
    if "`strategy'" == "both" | "`strategy'" == "never" {
        local strategies "`strategies' 0"
    }
    if "`strategy'" == "both" | "`strategy'" == "always" {
        local strategies "`strategies' 1"
    }

    foreach treat_val of local strategies {
        tempvar _cum_surv_i _prob_i
        gen double `_cum_surv_i' = 1
        gen double `_prob_i' = .

        forvalues s = `min_period'/`last_time' {
            quietly _msm_predict_xb, time(`s') treat_val(`treat_val') ///
                treatment(`treatment') period(`period') ///
                period_spec(`period_spec') ///
                baseline(`min_period') ///
                outcome_cov(`outcome_cov') b_hat(`b_hat') ///
                probvar(`_prob_i')

            quietly replace `_cum_surv_i' = `_cum_surv_i' * (1 - `_prob_i')

            * Check if this is a requested time
            local time_idx = 0
            foreach t of local times {
                local ++time_idx
                if `s' == `t' {
                    quietly summarize `_cum_surv_i'
                    local mean_surv = r(mean)

                    if "`type'" == "cum_inc" {
                        local point_est = 1 - `mean_surv'
                    }
                    else {
                        local point_est = `mean_surv'
                    }

                    * Column: never=2, always=5
                    local col = cond(`treat_val' == 0, 2, 5)
                    matrix `results'[`time_idx', `col'] = `point_est'
                }
            }
        }
        drop `_cum_surv_i' `_prob_i'
    }

    * =====================================================================
    * MC CONFIDENCE INTERVALS
    * =====================================================================

    display as text "Running `samples' Monte Carlo simulations..."

    * Store MC results
    tempname mc_0 mc_1
    matrix `mc_0' = J(`samples', `n_times', .)
    matrix `mc_1' = J(`samples', `n_times', .)

    * -----------------------------------------------------------------
    * MVN factor for coefficient draws (audit A19)
    *
    * The old code used cholesky() and, when it failed, fell back to
    * INDEPENDENT per-coefficient normal draws -- discarding every
    * off-diagonal covariance in V and returning an ordinary-looking MC CI
    * from the wrong joint distribution (correlation among intercept,
    * treatment, and time terms drives cumulative-risk uncertainty). Instead
    * symmetrize V and take an eigendecomposition. Tiny negative eigenvalues
    * (numerical noise) are clipped to zero under a relative tolerance; a
    * genuinely indefinite V is refused rather than approximated. The draw
    * method and any repair are returned in r(draw_method).
    * -----------------------------------------------------------------
    tempname V_use b_use F_fac
    local mvn_tol = 1e-6

    * Reduce to the coefficients with positive fitted variance; a dropped
    * (zero-variance) coefficient is held at its point value in every draw.
    local n_keep = 0
    forvalues i = 1/`n_coefs' {
        if `V_hat'[`i', `i'] > 0 {
            local ++n_keep
        }
    }
    * A fully degenerate covariance (every coefficient has zero variance, e.g. a
    * deterministic/separated fit) yields point predictions with a zero-width
    * interval: every MC draw equals b_hat. That is uninformative but not
    * invalid, so predict rather than refuse; the draw method records it.
    local _degenerate = 0
    if `n_keep' == 0 {
        local _degenerate = 1
        local draw_method "degenerate"
    }
    else {
        matrix `V_use' = J(`n_keep', `n_keep', 0)
        matrix `b_use' = J(1, `n_keep', 0)
        local ki = 0
        forvalues i = 1/`n_coefs' {
            if `V_hat'[`i', `i'] > 0 {
                local ++ki
                matrix `b_use'[1, `ki'] = `b_hat'[1, `i']
                local kj = 0
                forvalues j = 1/`n_coefs' {
                    if `V_hat'[`j', `j'] > 0 {
                        local ++kj
                        matrix `V_use'[`ki', `kj'] = `V_hat'[`i', `j']
                    }
                }
            }
        }

        local draw_status ""
        mata: st_local("draw_status", _msm_mvn_factor("`V_use'", "`F_fac'", `mvn_tol'))
        if "`draw_status'" == "fail" {
            display as error "the fitted coefficient covariance is not positive semidefinite"
            display as error "(a genuinely indefinite V, beyond the numerical clip tolerance `mvn_tol')."
            display as error "Monte Carlo draws from a non-PSD covariance are invalid; refusing to fabricate a CI."
            restore
            local _restore_needed = 0
            exit 506
        }
        local draw_method = cond("`draw_status'" == "clipped", "eigen(clipped)", "eigen")
        if "`draw_status'" == "clipped" {
            display as text "  Note: clipped tiny negative eigenvalues of V (tolerance `mvn_tol'); draw method eigen."
        }
    }

    forvalues sim = 1/`samples' {
        * Draw from MVN(b_hat, V_hat) via the eigen factor F (F F' = V_use), or
        * hold at b_hat when the covariance is fully degenerate.
        tempname b_draw
        matrix `b_draw' = `b_hat'
        if !`_degenerate' {
            tempname z_draw b_reduced
            matrix `z_draw' = J(1, `n_keep', 0)
            forvalues j = 1/`n_keep' {
                matrix `z_draw'[1, `j'] = rnormal()
            }
            matrix `b_reduced' = `b_use' + `z_draw' * `F_fac''

            * Reconstruct full vector; dropped coefficients keep their point value.
            local ki = 0
            forvalues i = 1/`n_coefs' {
                if `V_hat'[`i', `i'] > 0 {
                    local ++ki
                    matrix `b_draw'[1, `i'] = `b_reduced'[1, `ki']
                }
            }
        }

        * Compute for each strategy
        foreach treat_val of local strategies {
            tempvar _cum_surv_mc _prob_mc
            gen double `_cum_surv_mc' = 1
            gen double `_prob_mc' = .

            forvalues s = `min_period'/`last_time' {
                quietly _msm_predict_xb, time(`s') treat_val(`treat_val') ///
                    treatment(`treatment') period(`period') ///
                    period_spec(`period_spec') ///
                    baseline(`min_period') ///
                    outcome_cov(`outcome_cov') b_hat(`b_draw') ///
                    probvar(`_prob_mc')

                quietly replace `_cum_surv_mc' = `_cum_surv_mc' * (1 - `_prob_mc')

                local time_idx = 0
                foreach t of local times {
                    local ++time_idx
                    if `s' == `t' {
                        quietly summarize `_cum_surv_mc'
                        local mean_surv = r(mean)

                        if "`type'" == "cum_inc" {
                            local pred = 1 - `mean_surv'
                        }
                        else {
                            local pred = `mean_surv'
                        }

                        if `treat_val' == 0 {
                            matrix `mc_0'[`sim', `time_idx'] = `pred'
                        }
                        else {
                            matrix `mc_1'[`sim', `time_idx'] = `pred'
                        }
                    }
                }
            }
            drop `_cum_surv_mc' `_prob_mc'
        }

        * Progress
        if mod(`sim', 50) == 0 {
            display as text "  ... `sim' of `samples' samples completed"
        }
    }

    * =====================================================================
    * COMPUTE CIs FROM MC SAMPLES
    * =====================================================================

    local time_idx = 0
    foreach t of local times {
        local ++time_idx

        * CIs for never-treated (strategy 0)
        if "`strategy'" == "both" | "`strategy'" == "never" {
            mata: st_local("ci_lo_0", strofreal(_msm_pctile("`mc_0'", `time_idx', `lo_pct')))
            mata: st_local("ci_hi_0", strofreal(_msm_pctile("`mc_0'", `time_idx', `hi_pct')))
            matrix `results'[`time_idx', 3] = `ci_lo_0'
            matrix `results'[`time_idx', 4] = `ci_hi_0'
        }

        * CIs for always-treated (strategy 1)
        if "`strategy'" == "both" | "`strategy'" == "always" {
            mata: st_local("ci_lo_1", strofreal(_msm_pctile("`mc_1'", `time_idx', `lo_pct')))
            mata: st_local("ci_hi_1", strofreal(_msm_pctile("`mc_1'", `time_idx', `hi_pct')))
            matrix `results'[`time_idx', 6] = `ci_lo_1'
            matrix `results'[`time_idx', 7] = `ci_hi_1'
        }

        * Risk difference
        if "`difference'" != "" & "`strategy'" == "both" {
            local rd = `results'[`time_idx', 5] - `results'[`time_idx', 2]
            matrix `results'[`time_idx', 8] = `rd'

            mata: st_local("rd_lo", strofreal(_msm_diff_pctile("`mc_1'", "`mc_0'", `time_idx', `lo_pct')))
            mata: st_local("rd_hi", strofreal(_msm_diff_pctile("`mc_1'", "`mc_0'", `time_idx', `hi_pct')))
            matrix `results'[`time_idx', 9] = `rd_lo'
            matrix `results'[`time_idx', 10] = `rd_hi'
        }
    }

    restore
    local _restore_needed = 0

    * =========================================================================
    * DISPLAY RESULTS
    * =========================================================================

    display as text ""
    local type_label = cond("`type'" == "cum_inc", "Cumulative Incidence", "Survival")

    display as text "{hline 70}"
    display as text "`type_label' Estimates (`level'% CI)"
    display as text "{hline 70}"
    display as text ""

    if "`strategy'" == "both" {
        if "`difference'" != "" {
            display as text %6s "Period" "  " ///
                %12s "Never-treat" "  " %12s "Always-treat" "  " %12s "Diff"
            display as text _dup(50) "-"
        }
        else {
            display as text %6s "Period" "  " ///
                %12s "Never-treat" "  " %12s "Always-treat"
            display as text _dup(34) "-"
        }

        local time_idx = 0
        foreach t of local times {
            local ++time_idx
            local est_0 = `results'[`time_idx', 2]
            local est_1 = `results'[`time_idx', 5]

            if "`difference'" != "" {
                local rd_val = `results'[`time_idx', 8]
                display as text %6.0f `t' "  " ///
                    as result %12.4f `est_0' "  " %12.4f `est_1' "  " %12.4f `rd_val'
            }
            else {
                display as text %6.0f `t' "  " ///
                    as result %12.4f `est_0' "  " %12.4f `est_1'
            }

            * CIs
            local lo_0 = `results'[`time_idx', 3]
            local hi_0 = `results'[`time_idx', 4]
            local lo_1 = `results'[`time_idx', 6]
            local hi_1 = `results'[`time_idx', 7]

            if "`difference'" != "" {
                local rd_lo_v = `results'[`time_idx', 9]
                local rd_hi_v = `results'[`time_idx', 10]
                display as text "      " "  " ///
                    as text "(" %6.4f `lo_0' "-" %6.4f `hi_0' ")" ///
                    "  (" %6.4f `lo_1' "-" %6.4f `hi_1' ")" ///
                    "  (" %6.4f `rd_lo_v' "-" %6.4f `rd_hi_v' ")"
            }
            else {
                display as text "      " "  " ///
                    as text "(" %6.4f `lo_0' "-" %6.4f `hi_0' ")" ///
                    "  (" %6.4f `lo_1' "-" %6.4f `hi_1' ")"
            }
        }
    }
    else {
        local strat_label = cond("`strategy'" == "always", "Always-treat", "Never-treat")
        display as text %6s "Period" "  " %12s "`strat_label'"
        display as text _dup(22) "-"

        local time_idx = 0
        foreach t of local times {
            local ++time_idx
            local col = cond("`strategy'" == "never", 2, 5)
            local est = `results'[`time_idx', `col']
            display as text %6.0f `t' "  " as result %12.4f `est'

            local lo_col = `col' + 1
            local hi_col = `col' + 2
            local lo = `results'[`time_idx', `lo_col']
            local hi = `results'[`time_idx', `hi_col']
            display as text "      " "  " ///
                as text "(" %6.4f `lo' "-" %6.4f `hi' ")"
        }
    }

    display as text ""
    display as text "Reference population: " as result `n_ref' as text " individuals"
    display as text ""
    * Uncertainty disclosure (audit A22): MC draws come only from the saved
    * outcome-model covariance; the weight models and reference rows are held
    * fixed, so these intervals are final-stage, conditional-on-estimated-weights.
    display as text "Note: Monte Carlo intervals draw from the outcome-model covariance only."
    display as text "      They condition on the estimated IP weights and the reference sample"
    display as text "      and do not propagate weight-model estimation (audit A22)."
    display as text "{hline 70}"

    * =========================================================================
    * STORE RESULTS
    * =========================================================================

    if "`difference'" != "" {
        matrix colnames `results' = period est_never ci_lo_never ci_hi_never ///
            est_always ci_lo_always ci_hi_always diff diff_lo diff_hi
    }
    else {
        matrix colnames `results' = period est_never ci_lo_never ci_hi_never ///
            est_always ci_lo_always ci_hi_always
    }

    * Persist for msm_table
    capture matrix drop _msm_pred_matrix
    matrix _msm_pred_matrix = `results'
    char _dta[_msm_pred_saved] "1"
    char _dta[_msm_pred_type] "`type'"
    char _dta[_msm_pred_strategy] "`strategy'"
    char _dta[_msm_pred_level] "`level'"

    * Extract scalars before return matrix
    local time_idx = 0
    foreach t of local times {
        local ++time_idx
        if "`difference'" != "" & "`strategy'" == "both" {
            local _diff_`t' = `results'[`time_idx', 8]
        }
    }

    return matrix predictions = `results'
    return local seed `"`seed_used'"'
    return local seed_source "`seed_source'"
    return local seed_state `"`seed_state'"'
    return local type "`type'"
    return local strategy "`strategy'"
    return local history_spec "`history_spec'"
    return local diff_type "`diff_prefix'"
    return local draw_method "`draw_method'"
    return scalar n_times = `n_times'
    return scalar n_ref = `n_ref'
    return scalar samples = `samples'
    return scalar level = `level'
    return scalar min_support = `min_support'
    return scalar max_support = `max_support'
    return scalar extrapolated = `extrapolated'

    * The contrast return is named for the actual quantity (audit A14):
    * rd_<t> under cum_inc, sd_<t> under survival.
    local time_idx = 0
    foreach t of local times {
        local ++time_idx
        if "`difference'" != "" & "`strategy'" == "both" {
            return scalar `diff_prefix'_`t' = `_diff_`t''
        }
    }

    } /* end capture noisily */
    local _rc = _rc

    if `_restore_needed' {
        capture restore
    }

    * Restore the caller's observation order on success and on every error path.
    capture _msm_restore_order `_msm_orig_order'
    local _order_rc = _rc
    if `_rc' == 0 & `_order_rc' != 0 local _rc = `_order_rc'

    set varabbrev `_varabbrev'
    set more `_more'

    if `_rc' exit `_rc'
end

* =========================================================================
* _msm_predict_xb: Compute predicted probabilities at a time point
*   for a given treatment value, using provided coefficient vector.
* =========================================================================
cap program drop _msm_predict_xb
program define _msm_predict_xb
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax , time(integer) treat_val(integer) ///
            treatment(varname) period(varname) ///
            period_spec(string) baseline(real) ///
            [outcome_cov(string)] b_hat(name) probvar(varname)

        * Get coefficient names
        local coef_names: colnames `b_hat'
        local n_coefs: word count `coef_names'

        tempvar _xb
        gen double `_xb' = 0

        * Constant
        forvalues i = 1/`n_coefs' {
            local cname: word `i' of `coef_names'
            if "`cname'" == "_cons" {
                quietly replace `_xb' = `_xb' + `b_hat'[1, `i']
            }
        }

        * Treatment
        forvalues i = 1/`n_coefs' {
            local cname: word `i' of `coef_names'
            if "`cname'" == "`treatment'" {
                quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `treat_val'
            }
        }

        * Built-in treatment-history terms under static always/never regimes.
        * elapsed is the number of completed treatment decisions before time().
        local _elapsed = `time' - `baseline'
        local _lag = cond(`_elapsed' > 0, `treat_val', 0)
        local _cum = `treat_val' * max(0, `_elapsed')
        local _dur = `treat_val' * max(0, `_elapsed')
        local _int = `treat_val' * `_lag'
        forvalues i = 1/`n_coefs' {
            local cname: word `i' of `coef_names'
            if "`cname'" == "_msm_hist_lag1" {
                quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `_lag'
            }
            else if "`cname'" == "_msm_hist_cum" {
                quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `_cum'
            }
            else if "`cname'" == "_msm_hist_dur" {
                quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `_dur'
            }
            else if "`cname'" == "_msm_hist_int" {
                quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `_int'
            }
        }

        * Period terms
        forvalues i = 1/`n_coefs' {
            local cname: word `i' of `coef_names'
            if "`cname'" == "`period'" {
                quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `time'
            }
            else if "`cname'" == "_msm_period_sq" {
                quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `time'^2
            }
            else if "`cname'" == "_msm_period_cu" {
                quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `time'^3
            }
        }

        * Natural spline terms for period
        local per_ns_knots : char _dta[_msm_per_ns_knots]
        local per_ns_df    : char _dta[_msm_per_ns_df]
        if "`per_ns_knots'" != "" & "`per_ns_df'" != "" {
            local ns_df = `per_ns_df'
            local _ki = 0
            foreach _kv of local per_ns_knots {
                local _pk`_ki' = `_kv'
                local ++_ki
            }
            * Basis 1: linear
            forvalues i = 1/`n_coefs' {
                local cname: word `i' of `coef_names'
                if "`cname'" == "_msm_per_ns1" {
                    quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `time'
                }
            }
            * Additional nonlinear bases
            if `ns_df' > 1 {
                local _n_int = `ns_df' - 1
                local _t_last = `_pk`ns_df''
                local _t_pen  = `_pk`_n_int''
                * Natural cubic spline bases d_j - d_pen, matching the
                * construction in _msm_natural_spline (covers _n_int == 1).
                forvalues j = 0/`=`_n_int'-1' {
                    local jj = `j' + 2
                    local _d_j = (max(0, `time' - `_pk`j'')^3 - ///
                        max(0, `time' - `_t_last')^3) / ///
                        (`_t_last' - `_pk`j'')
                    local _d_pen = (max(0, `time' - `_t_pen')^3 - ///
                        max(0, `time' - `_t_last')^3) / ///
                        (`_t_last' - `_t_pen')
                    local _bval = `_d_j' - `_d_pen'
                    forvalues i = 1/`n_coefs' {
                        local cname: word `i' of `coef_names'
                        if "`cname'" == "_msm_per_ns`jj'" {
                            quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `_bval'
                        }
                    }
                }
            }
        }

        * Other covariates: use each observation's actual values
        if "`outcome_cov'" != "" {
            foreach var of local outcome_cov {
                forvalues i = 1/`n_coefs' {
                    local cname: word `i' of `coef_names'
                    if "`cname'" == "`var'" {
                        quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `var'
                    }
                }
            }
        }

        * Convert to probability
        quietly replace `probvar' = invlogit(`_xb')
        drop `_xb'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

* =========================================================================
* MATA HELPER FUNCTIONS
* =========================================================================

mata:
// Symmetrized-eigendecomposition MVN factor (audit A19).
// Writes an n x n factor F with F*F' ~= (V+V')/2 into `fname' and returns a
// status string: "psd" (all eigenvalues positive), "clipped" (tiny negatives
// zeroed under the relative tolerance), or "fail" (genuinely indefinite).
string scalar _msm_mvn_factor(string scalar vname, string scalar fname, real scalar tol)
{
    real matrix V, Vs, X, F
    real rowvector L
    real scalar mx, mn

    V  = st_matrix(vname)
    Vs = (V + V') / 2
    symeigensystem(Vs, X=., L=.)
    mx = max(abs(L))
    if (mx == 0) mx = 1
    mn = min(L)
    if (mn < -tol * mx) {
        return("fail")
    }
    // Clip tiny negatives / zeros to exactly 0, then form F = X * sqrt(diag(L)).
    L = L :* (L :> 0)
    F = X * diag(sqrt(L))
    st_matrix(fname, F)
    if (mn > 0) return("psd")
    return("clipped")
}

real scalar _msm_pctile(string scalar matname, real scalar col, real scalar pct)
{
    real matrix M
    real colvector v
    real scalar n, idx

    M = st_matrix(matname)
    v = sort(M[., col], 1)
    n = rows(v)
    idx = max((1, ceil(n * pct / 100)))
    idx = min((idx, n))
    return(v[idx])
}

real scalar _msm_diff_pctile(string scalar mat1, string scalar mat0, real scalar col, real scalar pct)
{
    real matrix M1, M0
    real colvector d
    real scalar n, idx

    M1 = st_matrix(mat1)
    M0 = st_matrix(mat0)
    d = sort(M1[., col] - M0[., col], 1)
    n = rows(d)
    idx = max((1, ceil(n * pct / 100)))
    idx = min((idx, n))
    return(d[idx])
}
end
