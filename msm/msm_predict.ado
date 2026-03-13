*! msm_predict Version 1.0.0  2026/03/03
*! Counterfactual predictions from marginal structural models
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
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

See help msm_predict for complete documentation
*/

program define msm_predict, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax , TIMEs(numlist sort integer >=0) ///
        [STRAtegy(string) TYPe(string) SAMPles(integer 100) ///
         SEED(integer -1) Level(cilevel) DIFFerence]

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
    local model       : char _dta[_msm_model]
    local period_spec : char _dta[_msm_period_spec]
    local outcome_cov : char _dta[_msm_outcome_cov]

    * =========================================================================
    * DEFAULTS AND VALIDATION
    * =========================================================================

    if "`strategy'" == "" local strategy "both"
    if "`type'" == "" local type "cum_inc"
    if "`level'" == "" local level 95

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
    if "`model'" != "logistic" {
        display as error "msm_predict currently only supports logistic model"
        display as error "For Cox model, use standard Stata post-estimation."
        exit 198
    }
    if `seed' >= 0 {
        set seed `seed'
    }

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
    display as text "Confidence level: " as result "`level'%"
    if "`difference'" != "" {
        display as text "Risk difference:  " as result "Yes"
    }
    display as text ""

    * =========================================================================
    * GET COEFFICIENT VECTOR AND VARIANCE MATRIX
    * =========================================================================

    tempname b_hat V_hat
    matrix `b_hat' = e(b)
    matrix `V_hat' = e(V)
    local n_coefs = colsof(`b_hat')

    * =========================================================================
    * PREPARE PREDICTION DATA
    * =========================================================================

    display as text "Computing predictions..."

    preserve

    * Reference population: unique individuals at first period
    quietly summarize `period'
    local min_period = r(min)
    quietly keep if `period' == `min_period'
    capture confirm variable _msm_esample
    if _rc == 0 {
        quietly keep if _msm_esample == 1
    }
    quietly bysort `id': keep if _n == 1

    local n_ref = _N

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

    * Cholesky decomposition
    tempname L_chol V_use b_use
    local chol_ok = 1

    * Check for zero-variance (dropped) coefficients
    local n_keep = 0
    forvalues i = 1/`n_coefs' {
        if `V_hat'[`i', `i'] > 0 {
            local ++n_keep
        }
    }

    if `n_keep' == `n_coefs' {
        matrix `V_use' = `V_hat'
        matrix `b_use' = `b_hat'
        capture matrix `L_chol' = cholesky(`V_use')
        if _rc != 0 {
            local chol_ok = 0
        }
    }
    else if `n_keep' > 0 {
        * Build reduced matrices
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
        capture matrix `L_chol' = cholesky(`V_use')
        if _rc != 0 {
            local chol_ok = 0
        }
    }
    else {
        local chol_ok = 0
    }

    if !`chol_ok' {
        display as text "  Warning: using diagonal approximation for MC draws"
    }

    forvalues sim = 1/`samples' {
        * Draw from MVN(b_hat, V_hat)
        tempname b_draw
        if `chol_ok' {
            tempname z_draw b_reduced
            matrix `z_draw' = J(1, `n_keep', 0)
            forvalues j = 1/`n_keep' {
                matrix `z_draw'[1, `j'] = rnormal()
            }
            matrix `b_reduced' = `b_use' + `z_draw' * `L_chol''

            * Reconstruct full vector
            matrix `b_draw' = `b_hat'
            local ki = 0
            forvalues i = 1/`n_coefs' {
                if `V_hat'[`i', `i'] > 0 {
                    local ++ki
                    matrix `b_draw'[1, `i'] = `b_reduced'[1, `ki']
                }
            }
        }
        else {
            matrix `b_draw' = `b_hat'
            forvalues j = 1/`n_coefs' {
                local se_j = sqrt(`V_hat'[`j', `j'])
                if `se_j' > 0 {
                    matrix `b_draw'[1, `j'] = `b_hat'[1, `j'] + rnormal() * `se_j'
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
            local _rd_`t' = `results'[`time_idx', 8]
        }
    }

    return matrix predictions = `results'
    return local type "`type'"
    return local strategy "`strategy'"
    return scalar n_times = `n_times'
    return scalar n_ref = `n_ref'
    return scalar samples = `samples'
    return scalar level = `level'

    local time_idx = 0
    foreach t of local times {
        local ++time_idx
        if "`difference'" != "" & "`strategy'" == "both" {
            return scalar rd_`t' = `_rd_`t''
        }
    }

    set varabbrev `_varabbrev'
    set more `_more'
end

* =========================================================================
* _msm_predict_xb: Compute predicted probabilities at a time point
*   for a given treatment value, using provided coefficient vector.
* =========================================================================
program define _msm_predict_xb
    version 16.0
    set varabbrev off
    set more off

    syntax , time(integer) treat_val(integer) ///
        treatment(varname) period(varname) ///
        period_spec(string) ///
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
            if `_n_int' == 1 {
                local jj = 2
                local _bval = (max(0, `time' - `_pk1')^3 - ///
                    max(0, `time' - `_t_last')^3) / ///
                    (`_t_last' - `_pk1')
                forvalues i = 1/`n_coefs' {
                    local cname: word `i' of `coef_names'
                    if "`cname'" == "_msm_per_ns`jj'" {
                        quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `_bval'
                    }
                }
            }
            else {
                local _n_nonlin = `_n_int' - 1
                forvalues j = 1/`_n_nonlin' {
                    local jj = `j' + 1
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
end

* =========================================================================
* MATA HELPER FUNCTIONS
* =========================================================================

mata:
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
