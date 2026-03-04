*! tte_predict Version 1.0.2  2026/02/28
*! Marginal predictions with confidence intervals for target trial emulation
*! Author: Timothy P Copeland
*! Author: Tania F Reza
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Department of Global Public Health, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tte_predict, times(numlist) [options]

Description:
  Generates marginal cumulative incidence or survival predictions with
  confidence intervals from the fitted model. Uses Monte Carlo simulation
  from the coefficient distribution.

  Computes individual-level survival curves first, then averages
  across the reference population (correct G-formula standardization).

Options:
  times(numlist)      - Follow-up times for prediction (required)
  type(string)        - cum_inc (default) | survival
  samples(#)          - MC samples for CIs (default: 100)
  seed(#)             - Random seed
  level(#)            - Confidence level (default: 95)
  difference          - Compute treatment contrast (risk difference)

See help tte_predict for complete documentation
*/

program define tte_predict, rclass
    version 16.0
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax , TIMEs(numlist sort) ///
        [TYPe(string) SAMPles(integer 100) SEED(integer -1) ///
         Level(cilevel) DIFFerence]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================

    _tte_check_fitted
    _tte_get_settings

    local prefix    "`_tte_prefix'"
    local id        "`_tte_id'"
    local estimand  "`_tte_estimand'"

    * Get model info from characteristics
    local model       : char _dta[_tte_model]
    local model_var   : char _dta[_tte_model_var]
    local fu_spec     : char _dta[_tte_followup_spec]
    local trial_spec  : char _dta[_tte_trial_spec]
    local outcome_cov : char _dta[_tte_outcome_cov]
    local time_vars   : char _dta[_tte_time_vars]

    * =========================================================================
    * DEFAULTS AND VALIDATION
    * =========================================================================

    if "`type'" == "" local type "cum_inc"
    if !inlist("`type'", "cum_inc", "survival") {
        display as error "type() must be cum_inc or survival"
        exit 198
    }

    if "`level'" == "" local level 95
    if `samples' < 10 {
        display as error "samples() must be at least 10"
        exit 198
    }

    if `seed' >= 0 {
        set seed `seed'
    }

    * Only logistic model supports marginal predictions via this approach
    if "`model'" != "logistic" {
        display as error "tte_predict currently only supports logistic model"
        display as error "For Cox model, use standard Stata post-estimation (predict, stcurve)"
        exit 198
    }

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as result "tte_predict" as text " - Marginal Predictions"
    display as text "{hline 70}"
    display as text ""
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

    * Get estimates from last model
    tempname b_hat V_hat
    matrix `b_hat' = e(b)
    matrix `V_hat' = e(V)
    local n_coefs = colsof(`b_hat')

    * =========================================================================
    * PREPARE PREDICTION DATA
    * =========================================================================

    display as text "Computing predictions..."

    preserve

    * Get the maximum time requested
    local max_time: word count `times'
    local last_time: word `max_time' of `times'

    * We need a reference population: use unique individuals at baseline
    * (followup=0) restricted to the estimation sample from tte_fit
    quietly keep if `prefix'followup == 0
    capture confirm variable `prefix'esample
    if _rc == 0 {
        quietly keep if `prefix'esample == 1
    }
    quietly bysort `id' `prefix'trial: keep if _n == 1

    * Number of prediction times
    local n_times: word count `times'

    * Initialize results matrix
    * Columns: time | est_0 | ci_lo_0 | ci_hi_0 | est_1 | ci_lo_1 | ci_hi_1 | [diff | diff_lo | diff_hi]
    local n_cols = 7
    if "`difference'" != "" local n_cols = 10
    tempname results
    matrix `results' = J(`n_times', `n_cols', .)

    * CI percentiles
    local alpha = (100 - `level') / 2
    local lo_pct = `alpha'
    local hi_pct = 100 - `alpha'

    * Store requested times in results matrix
    local time_idx = 0
    foreach t of local times {
        local ++time_idx
        matrix `results'[`time_idx', 1] = `t'
    }

    * Parse max requested time
    local last_time: word `n_times' of `times'

    * =====================================================================
    * POINT ESTIMATES: Individual-level survival, then average
    * =====================================================================

    * For arm=0 and arm=1, compute cumulative incidence at each time
    * Correct G-formula: S_i(t) = prod_{s=0}^{t} (1 - h_i(s))
    * Marginal S(t) = E[S_i(t)] = mean of individual S_i(t)

    forvalues arm = 0/1 {
        * Initialize per-individual cumulative survival
        tempvar _cum_surv_i _prob_i
        quietly gen double `_cum_surv_i' = 1
        quietly gen double `_prob_i' = .

        * Iterate over ALL integer follow-up periods from 0 to max time
        forvalues s = 0/`last_time' {
            * Compute individual-level P(Y=1|t=s) for each person
            quietly _tte_predict_xb, time(`s') arm(`arm') ///
                model_var(`model_var') prefix(`prefix') ///
                fu_spec(`fu_spec') trial_spec(`trial_spec') ///
                outcome_cov(`outcome_cov') b_hat(`b_hat') ///
                probvar(`_prob_i')

            * Update individual cumulative survival
            quietly replace `_cum_surv_i' = `_cum_surv_i' * (1 - `_prob_i')

            * Record result only at requested time points
            local is_requested = 0
            foreach t of local times {
                if `s' == `t' {
                    local is_requested = 1
                }
            }

            if `is_requested' {
                * Average individual survival across reference population
                quietly summarize `_cum_surv_i'
                local mean_surv = r(mean)

                if "`type'" == "cum_inc" {
                    local point_est = 1 - `mean_surv'
                }
                else {
                    local point_est = `mean_surv'
                }

                * Find the time index
                local tidx = 0
                foreach tt of local times {
                    local ++tidx
                    if `tt' == `s' {
                        local col = 2 + `arm' * 3
                        matrix `results'[`tidx', `col'] = `point_est'
                    }
                }
            }
        }
        drop `_cum_surv_i' `_prob_i'
    }

    * =====================================================================
    * MC CONFIDENCE INTERVALS
    * =====================================================================

    display as text "Running `samples' MC simulations... " _continue

    * Store MC results
    local n_times: word count `times'
    tempname mc_0 mc_1
    matrix `mc_0' = J(`samples', `n_times', .)
    matrix `mc_1' = J(`samples', `n_times', .)

    * Cholesky decomposition of V for drawing correlated normals
    * Handle semi-definite matrices (dropped covariates)
    tempname L_chol V_use b_use
    local chol_ok = 1
    local dropped_cols ""

    * Check for zero-variance (dropped) coefficients
    local n_keep = 0
    forvalues i = 1/`n_coefs' {
        if `V_hat'[`i', `i'] > 0 {
            local ++n_keep
        }
        else {
            local dropped_cols "`dropped_cols' `i'"
        }
    }

    if `n_keep' < `n_coefs' & `n_keep' > 0 {
        * Build reduced V and b matrices excluding dropped columns
        local n_dropped: word count `dropped_cols'
        display as text "  Note: `n_dropped' dropped covariate(s) excluded from MC draws"

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
    else if `n_keep' == `n_coefs' {
        matrix `V_use' = `V_hat'
        matrix `b_use' = `b_hat'
        capture matrix `L_chol' = cholesky(`V_use')
        if _rc != 0 {
            local chol_ok = 0
        }
    }
    else {
        local chol_ok = 0
    }

    if !`chol_ok' {
        display as text "{p}"
        display as text "{bf:Warning:} variance matrix is not positive definite."
        display as text "MC confidence intervals will use diagonal approximation."
        display as text "{p_end}"
    }

    forvalues s = 1/`samples' {
        * Draw from MVN(b_hat, V_hat)
        tempname b_draw
        if `chol_ok' {
            tempname z_draw b_reduced
            matrix `z_draw' = J(1, `n_keep', 0)
            forvalues j = 1/`n_keep' {
                matrix `z_draw'[1, `j'] = rnormal()
            }
            matrix `b_reduced' = `b_use' + `z_draw' * `L_chol''

            * Reconstruct full coefficient vector
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
            * Diagonal approximation fallback
            matrix `b_draw' = `b_hat'
            forvalues j = 1/`n_coefs' {
                local se_j = sqrt(`V_hat'[`j', `j'])
                if `se_j' > 0 {
                    matrix `b_draw'[1, `j'] = `b_hat'[1, `j'] + rnormal() * `se_j'
                }
            }
        }

        * Compute individual-level survival for arm=0 and arm=1
        forvalues arm = 0/1 {
            tempvar _cum_surv_mc _prob_mc
            quietly gen double `_cum_surv_mc' = 1
            quietly gen double `_prob_mc' = .

            forvalues ss = 0/`last_time' {
                quietly _tte_predict_xb, time(`ss') arm(`arm') ///
                    model_var(`model_var') prefix(`prefix') ///
                    fu_spec(`fu_spec') trial_spec(`trial_spec') ///
                    outcome_cov(`outcome_cov') b_hat(`b_draw') ///
                    probvar(`_prob_mc')

                quietly replace `_cum_surv_mc' = `_cum_surv_mc' * (1 - `_prob_mc')

                * Record only at requested time points
                local is_requested = 0
                foreach t of local times {
                    if `ss' == `t' {
                        local is_requested = 1
                    }
                }

                if `is_requested' {
                    quietly summarize `_cum_surv_mc'
                    local mean_surv = r(mean)

                    if "`type'" == "cum_inc" {
                        local pred = 1 - `mean_surv'
                    }
                    else {
                        local pred = `mean_surv'
                    }

                    local tidx = 0
                    foreach t of local times {
                        local ++tidx
                        if `t' == `ss' {
                            if `arm' == 0 {
                                matrix `mc_0'[`s', `tidx'] = `pred'
                            }
                            else {
                                matrix `mc_1'[`s', `tidx'] = `pred'
                            }
                        }
                    }
                }
            }
            drop `_cum_surv_mc' `_prob_mc'
        }

        * Progress display
        display as text _char(13) "Running `samples' MC simulations... " ///
            string(round(`s'/`samples'*100), "%3.0f") "%" _continue
    }

    display as text _char(13) "Running `samples' MC simulations... done" _newline

    * =====================================================================
    * COMPUTE CIs FROM MC SAMPLES
    * =====================================================================

    local time_idx = 0
    foreach t of local times {
        local ++time_idx

        * CIs for arm=0
        mata: st_local("ci_lo_0", strofreal(_tte_pctile("`mc_0'", `time_idx', `lo_pct')))
        mata: st_local("ci_hi_0", strofreal(_tte_pctile("`mc_0'", `time_idx', `hi_pct')))
        matrix `results'[`time_idx', 3] = `ci_lo_0'
        matrix `results'[`time_idx', 4] = `ci_hi_0'

        * CIs for arm=1
        mata: st_local("ci_lo_1", strofreal(_tte_pctile("`mc_1'", `time_idx', `lo_pct')))
        mata: st_local("ci_hi_1", strofreal(_tte_pctile("`mc_1'", `time_idx', `hi_pct')))
        matrix `results'[`time_idx', 6] = `ci_lo_1'
        matrix `results'[`time_idx', 7] = `ci_hi_1'

        * Risk difference
        if "`difference'" != "" {
            local rd = `results'[`time_idx', 5] - `results'[`time_idx', 2]
            matrix `results'[`time_idx', 8] = `rd'

            * Difference CIs from MC
            mata: st_local("rd_lo", strofreal(_tte_diff_pctile("`mc_1'", "`mc_0'", `time_idx', `lo_pct')))
            mata: st_local("rd_hi", strofreal(_tte_diff_pctile("`mc_1'", "`mc_0'", `time_idx', `hi_pct')))
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

    * Header
    if "`difference'" != "" {
        display as text %5s "Time" "  " ///
            %10s "Control" "  " %10s "Treated" "  " %10s "Diff"
        display as text _dup(45) "-"
    }
    else {
        display as text %5s "Time" "  " ///
            %10s "Control" "  " %10s "Treated"
        display as text _dup(30) "-"
    }

    local time_idx = 0
    foreach t of local times {
        local ++time_idx

        local est_0 = `results'[`time_idx', 2]
        local est_1 = `results'[`time_idx', 5]

        if "`difference'" != "" {
            local rd_val = `results'[`time_idx', 8]
            display as text %5.0f `t' "  " ///
                as result %10.4f `est_0' "  " %10.4f `est_1' "  " %10.4f `rd_val'
        }
        else {
            display as text %5.0f `t' "  " ///
                as result %10.4f `est_0' "  " %10.4f `est_1'
        }

        * Show CIs
        local lo_0 = `results'[`time_idx', 3]
        local hi_0 = `results'[`time_idx', 4]
        local lo_1 = `results'[`time_idx', 6]
        local hi_1 = `results'[`time_idx', 7]

        if "`difference'" != "" {
            local rd_lo_val = `results'[`time_idx', 9]
            local rd_hi_val = `results'[`time_idx', 10]
            display as text "     " "  " ///
                as text "(" %5.4f `lo_0' "-" %5.4f `hi_0' ")" ///
                "  (" %5.4f `lo_1' "-" %5.4f `hi_1' ")" ///
                "  (" %5.4f `rd_lo_val' "-" %5.4f `rd_hi_val' ")"
        }
        else {
            display as text "     " "  " ///
                as text "(" %5.4f `lo_0' "-" %5.4f `hi_0' ")" ///
                "  (" %5.4f `lo_1' "-" %5.4f `hi_1' ")"
        }
    }

    display as text ""
    display as text "{hline 70}"

    * =========================================================================
    * STORE MATRIX COLUMN NAMES
    * =========================================================================

    if "`difference'" != "" {
        matrix colnames `results' = time est_0 ci_lo_0 ci_hi_0 est_1 ci_lo_1 ci_hi_1 diff diff_lo diff_hi
    }
    else {
        matrix colnames `results' = time est_0 ci_lo_0 ci_hi_0 est_1 ci_lo_1 ci_hi_1
    }

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    * Individual time-point scalars (must extract before return matrix moves it)
    local time_idx = 0
    foreach t of local times {
        local ++time_idx
        if "`difference'" != "" {
            local _rd_`t' = `results'[`time_idx', 8]
        }
    }

    return matrix predictions = `results'
    return local type "`type'"
    return local estimand "`estimand'"
    return scalar n_times = `n_times'
    return scalar samples = `samples'
    return scalar level = `level'

    local time_idx = 0
    foreach t of local times {
        local ++time_idx
        if "`difference'" != "" {
            return scalar rd_`t' = `_rd_`t''
        }
    }
end

* =========================================================================
* _tte_predict_xb: Compute individual predicted probabilities at a time
*   point for a given arm value, using provided coefficient vector.
*   Stores results in the variable specified by probvar().
* =========================================================================
program define _tte_predict_xb
    version 16.0
    set varabbrev off
    set more off

    syntax , time(integer) arm(integer) ///
        model_var(string) prefix(string) ///
        fu_spec(string) trial_spec(string) ///
        [outcome_cov(string)] b_hat(name) probvar(varname)

    * Build the linear predictor for each observation at (time, arm)
    * Using the coefficient vector b_hat

    * Get coefficient names
    local coef_names: colnames `b_hat'
    local n_coefs: word count `coef_names'

    * Build xb manually
    tempvar _xb
    gen double `_xb' = 0

    * Constant term
    forvalues i = 1/`n_coefs' {
        local cname: word `i' of `coef_names'
        if "`cname'" == "_cons" {
            quietly replace `_xb' = `_xb' + `b_hat'[1, `i']
        }
    }

    * Treatment variable
    forvalues i = 1/`n_coefs' {
        local cname: word `i' of `coef_names'
        if "`cname'" == "`model_var'" {
            quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `arm'
        }
    }

    * Follow-up time terms
    forvalues i = 1/`n_coefs' {
        local cname: word `i' of `coef_names'
        if "`cname'" == "`prefix'followup" {
            quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `time'
        }
        else if "`cname'" == "`prefix'followup_sq" {
            quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `time'^2
        }
        else if "`cname'" == "`prefix'followup_cu" {
            quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `time'^3
        }
    }

    * Trial period terms: use each observation's actual trial period
    forvalues i = 1/`n_coefs' {
        local cname: word `i' of `coef_names'
        if "`cname'" == "`prefix'trial" {
            quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `prefix'trial
        }
        else if "`cname'" == "`prefix'trial_sq" {
            quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `prefix'trial^2
        }
        else if "`cname'" == "`prefix'trial_cu" {
            quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `prefix'trial^3
        }
    }

    * Other covariates: use each observation's actual covariate values
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

    * Natural spline terms — recompute basis at prediction time/values
    * Follow-up NS: recompute at prediction `time' using stored knots
    local fu_ns_knots : char _dta[_tte_fu_ns_knots]
    local fu_ns_df    : char _dta[_tte_fu_ns_df]
    if "`fu_ns_knots'" != "" & "`fu_ns_df'" != "" {
        local ns_df = `fu_ns_df'
        * Parse knots: knot0, knot1, ..., knot_df
        local _ki = 0
        foreach _kv of local fu_ns_knots {
            local _fk`_ki' = `_kv'
            local ++_ki
        }
        * Basis 1: x itself (linear)
        forvalues i = 1/`n_coefs' {
            local cname: word `i' of `coef_names'
            if "`cname'" == "`prefix'fu_ns1" {
                quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `time'
            }
        }
        * Additional basis columns using Harrell RCS formula
        if `ns_df' > 1 {
            local _n_int = `ns_df' - 1
            local _t_last = `_fk`ns_df''
            local _t_pen  = `_fk`_n_int''
            if `_n_int' == 1 {
                * df=2: single nonlinear basis
                local jj = 2
                local _bval = (max(0, `time' - `_fk1')^3 - ///
                    max(0, `time' - `_t_last')^3) / ///
                    (`_t_last' - `_fk1')
                forvalues i = 1/`n_coefs' {
                    local cname: word `i' of `coef_names'
                    if "`cname'" == "`prefix'fu_ns`jj'" {
                        quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `_bval'
                    }
                }
            }
            else {
                * df>=3: Harrell RCS nonlinear bases
                local _n_nonlin = `_n_int' - 1
                forvalues j = 1/`_n_nonlin' {
                    local jj = `j' + 1
                    local _d_j = (max(0, `time' - `_fk`j'')^3 - ///
                        max(0, `time' - `_t_last')^3) / ///
                        (`_t_last' - `_fk`j'')
                    local _d_pen = (max(0, `time' - `_t_pen')^3 - ///
                        max(0, `time' - `_t_last')^3) / ///
                        (`_t_last' - `_t_pen')
                    local _bval = `_d_j' - `_d_pen'
                    forvalues i = 1/`n_coefs' {
                        local cname: word `i' of `coef_names'
                        if "`cname'" == "`prefix'fu_ns`jj'" {
                            quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `_bval'
                        }
                    }
                }
            }
        }
    }

    * Trial period NS: use each observation's actual trial period data values
    forvalues i = 1/`n_coefs' {
        local cname: word `i' of `coef_names'
        if regexm("`cname'", "^`prefix'tr_ns") {
            capture confirm variable `cname'
            if _rc == 0 {
                quietly replace `_xb' = `_xb' + `b_hat'[1, `i'] * `cname'
            }
        }
    }

    * Convert to probability via logit link and store in probvar
    quietly replace `probvar' = invlogit(`_xb')

    drop `_xb'
end

* =========================================================================
* MATA HELPER FUNCTIONS
* =========================================================================

mata:
real scalar _tte_pctile(string scalar matname, real scalar col, real scalar pct)
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

real scalar _tte_diff_pctile(string scalar mat1, string scalar mat0, real scalar col, real scalar pct)
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
