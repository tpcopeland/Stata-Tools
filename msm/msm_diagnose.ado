*! msm_diagnose Version 1.0.0  2026/03/03
*! Weight diagnostics and covariate balance for MSM
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  msm_diagnose [, options]

Description:
  Displays weight distribution summaries (mean, SD, percentiles, ESS)
  and covariate balance (SMD before/after weighting).

Options:
  balance_covariates(varlist)  - Covariates for balance assessment
  by_period                    - Show weight stats by period
  threshold(#)                 - SMD threshold for balance (default: 0.1)

See help msm_diagnose for complete documentation
*/

program define msm_diagnose, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    set varabbrev off
    set more off

    syntax [, BALance_covariates(varlist numeric) BY_period THReshold(real 0.1)]

    * Check prerequisites
    _msm_check_prepared
    _msm_check_weighted
    _msm_get_settings

    local id         "`_msm_id'"
    local period     "`_msm_period'"
    local treatment  "`_msm_treatment'"
    local outcome    "`_msm_outcome'"

    * Default balance covariates to mapped covariates
    if "`balance_covariates'" == "" {
        local balance_covariates "`_msm_covariates' `_msm_bl_covs'"
        local balance_covariates = strtrim("`balance_covariates'")
    }

    * =========================================================================
    * WEIGHT DISTRIBUTION
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as result "msm_diagnose" as text " - Weight Diagnostics"
    display as text "{hline 70}"
    display as text ""

    * Overall weight distribution
    display as text "{bf:Weight Distribution}"
    display as text ""

    quietly summarize _msm_weight, detail
    local w_mean = r(mean)
    local w_sd   = r(sd)
    local w_min  = r(min)
    local w_max  = r(max)
    local w_p1   = r(p1)
    local w_p5   = r(p5)
    local w_p25  = r(p25)
    local w_p50  = r(p50)
    local w_p75  = r(p75)
    local w_p95  = r(p95)
    local w_p99  = r(p99)

    display as text "  Mean:     " as result %9.4f `w_mean'
    display as text "  SD:       " as result %9.4f `w_sd'
    display as text "  Min:      " as result %9.4f `w_min'
    display as text "  P1:       " as result %9.4f `w_p1'
    display as text "  P5:       " as result %9.4f `w_p5'
    display as text "  P25:      " as result %9.4f `w_p25'
    display as text "  Median:   " as result %9.4f `w_p50'
    display as text "  P75:      " as result %9.4f `w_p75'
    display as text "  P95:      " as result %9.4f `w_p95'
    display as text "  P99:      " as result %9.4f `w_p99'
    display as text "  Max:      " as result %9.4f `w_max'

    * Effective sample size
    quietly {
        summarize _msm_weight
        local sum_w = r(sum)
        local n_total = r(N)
        tempvar _w2
        gen double `_w2' = _msm_weight^2
        summarize `_w2'
        local sum_w2 = r(sum)
        drop `_w2'
    }
    local ess = (`sum_w'^2) / `sum_w2'
    local ess_pct = 100 * `ess' / `n_total'

    display as text ""
    display as text "  ESS:      " as result %9.1f `ess' ///
        as text " (" as result %4.1f `ess_pct' "%" as text " of " as result `n_total' as text ")"

    * By treatment group
    display as text ""
    display as text "  {bf:By treatment group:}"

    forvalues t = 0/1 {
        local t_label = cond(`t' == 0, "Untreated", "Treated")
        quietly summarize _msm_weight if `treatment' == `t', detail
        local tw_mean = r(mean)
        local tw_sd = r(sd)
        local tw_n = r(N)

        quietly {
            summarize _msm_weight if `treatment' == `t'
            local tw_sum = r(sum)
            tempvar _tw2
            gen double `_tw2' = _msm_weight^2 if `treatment' == `t'
            summarize `_tw2'
            local tw_sum2 = r(sum)
            drop `_tw2'
        }
        local tw_ess = (`tw_sum'^2) / `tw_sum2'

        display as text "    `t_label' (n=" as result `tw_n' as text "): mean=" ///
            as result %6.4f `tw_mean' as text ", SD=" as result %6.4f `tw_sd' ///
            as text ", ESS=" as result %6.1f `tw_ess'
    }

    * Extreme weights
    quietly count if _msm_weight > `w_p99' & !missing(_msm_weight)
    local n_extreme = r(N)
    if `n_extreme' > 0 {
        display as text ""
        display as text "  Extreme weights (>" as result %6.4f `w_p99' as text "): " ///
            as result `n_extreme' as text " obs"
    }

    * =========================================================================
    * BY-PERIOD WEIGHT STATS (optional)
    * =========================================================================

    if "`by_period'" != "" {
        display as text ""
        display as text "{bf:Weight Distribution by Period}"
        display as text ""
        display as text %6s "Period" "  " %8s "N" "  " ///
            %10s "Mean" "  " %10s "SD" "  " %10s "Min" "  " %10s "Max"
        display as text _dup(60) "-"

        quietly levelsof `period', local(periods)
        foreach p of local periods {
            quietly summarize _msm_weight if `period' == `p'
            display as text %6.0f `p' "  " ///
                as result %8.0f r(N) "  " ///
                %10.4f r(mean) "  " %10.4f r(sd) "  " ///
                %10.4f r(min) "  " %10.4f r(max)
        }
    }

    * =========================================================================
    * COVARIATE BALANCE (SMD)
    * =========================================================================

    if "`balance_covariates'" != "" {
        display as text ""
        display as text "{bf:Covariate Balance (Standardized Mean Difference)}"
        display as text ""
        display as text %20s "Covariate" "  " ///
            %12s "Unweighted" "  " %12s "Weighted" "  " %8s "Change"
        display as text _dup(58) "-"

        local n_balanced = 0
        local n_imbalanced = 0
        local n_covs : word count `balance_covariates'

        tempname bal_matrix
        matrix `bal_matrix' = J(`n_covs', 3, .)

        local cov_idx = 0
        foreach var of local balance_covariates {
            local ++cov_idx

            * Unweighted SMD
            _msm_smd `var', treatment(`treatment')
            local smd_uw = `_msm_smd_value'

            * Weighted SMD
            _msm_smd `var', treatment(`treatment') weight(_msm_weight)
            local smd_w = `_msm_smd_value'

            * Change
            if abs(`smd_uw') > 0.001 {
                local pct_change = 100 * (abs(`smd_w') - abs(`smd_uw')) / abs(`smd_uw')
            }
            else {
                local pct_change = 0
            }

            matrix `bal_matrix'[`cov_idx', 1] = `smd_uw'
            matrix `bal_matrix'[`cov_idx', 2] = `smd_w'
            matrix `bal_matrix'[`cov_idx', 3] = `pct_change'

            * Display with balance indicator
            local bal_flag ""
            if abs(`smd_w') > `threshold' {
                local bal_flag " *"
                local ++n_imbalanced
            }
            else {
                local ++n_balanced
            }

            local abbrev_var = abbrev("`var'", 20)
            display as text %20s "`abbrev_var'" "  " ///
                as result %12.4f `smd_uw' "  " %12.4f `smd_w' "  " ///
                %7.1f `pct_change' "%" as text "`bal_flag'"
        }

        display as text _dup(58) "-"
        display as text "Threshold: |SMD| < " as result `threshold'
        display as text "Balanced:   " as result `n_balanced' as text "/" as result `n_covs'
        if `n_imbalanced' > 0 {
            display as text "Imbalanced: " as error `n_imbalanced' as text " covariates marked with *"
        }

        * Add names and persist for msm_table
        matrix rownames `bal_matrix' = `balance_covariates'
        matrix colnames `bal_matrix' = raw_smd weighted_smd pct_change
        capture matrix drop _msm_bal_matrix
        matrix _msm_bal_matrix = `bal_matrix'
        char _dta[_msm_bal_saved] "1"
        char _dta[_msm_bal_threshold] "`threshold'"

        return matrix balance = `bal_matrix'
    }

    display as text ""
    display as text "{hline 70}"

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return scalar mean_weight = `w_mean'
    return scalar sd_weight = `w_sd'
    return scalar min_weight = `w_min'
    return scalar max_weight = `w_max'
    return scalar p1_weight = `w_p1'
    return scalar p99_weight = `w_p99'
    return scalar ess = `ess'
    return scalar ess_pct = `ess_pct'
    return scalar n_extreme = `n_extreme'

    * Persist weight diagnostics for msm_table
    char _dta[_msm_diag_mean] "`w_mean'"
    char _dta[_msm_diag_sd] "`w_sd'"
    char _dta[_msm_diag_min] "`w_min'"
    char _dta[_msm_diag_max] "`w_max'"
    char _dta[_msm_diag_p1] "`w_p1'"
    char _dta[_msm_diag_p50] "`w_p50'"
    char _dta[_msm_diag_p99] "`w_p99'"
    char _dta[_msm_diag_ess] "`ess'"
    char _dta[_msm_diag_ess_pct] "`ess_pct'"
    char _dta[_msm_diag_saved] "1"

    set varabbrev `_varabbrev'
    set more `_more'
end
