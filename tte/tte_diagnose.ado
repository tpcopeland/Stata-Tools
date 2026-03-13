*! tte_diagnose Version 1.1.0  2026/03/10
*! Weight diagnostics and balance assessment for target trial emulation
*! Author: Timothy P Copeland
*! Author: Tania F Reza
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Department of Global Public Health, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tte_diagnose [, balance_covariates(varlist) weight_summary
      by_trial by_period export(filename)]

Description:
  Comprehensive diagnostics for IP weights and covariate balance.

See help tte_diagnose for complete documentation
*/

program define tte_diagnose, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    syntax [, BALance_covariates(varlist numeric) ///
        BY_trial EQUIPoise]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================

    _tte_check_expanded
    _tte_get_settings

    local id      "`_tte_id'"
    local prefix  "`_tte_prefix'"

    * Check for weight variable
    local weight_var "`prefix'weight"
    capture confirm variable `weight_var'
    local has_weights = (_rc == 0)

    if !`has_weights' {
        display as text "Note: no weight variable found; showing unweighted diagnostics only"
        local weight_var ""
    }

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as result "tte_diagnose" as text " - Diagnostics"
    display as text "{hline 70}"

    * =========================================================================
    * WEIGHT SUMMARY
    * =========================================================================

    if `has_weights' {
        display as text ""
        display as text "{bf:Weight Distribution}"
        display as text ""

        quietly summarize `weight_var', detail
        local w_mean = r(mean)
        local w_sd = r(sd)
        local w_min = r(min)
        local w_max = r(max)
        local w_p1 = r(p1)
        local w_p5 = r(p5)
        local w_p25 = r(p25)
        local w_p50 = r(p50)
        local w_p75 = r(p75)
        local w_p95 = r(p95)
        local w_p99 = r(p99)

        display as text "  Mean:        " as result %9.4f `w_mean'
        display as text "  SD:          " as result %9.4f `w_sd'
        display as text "  Min:         " as result %9.4f `w_min'
        display as text "  Max:         " as result %9.4f `w_max'
        display as text ""
        display as text "  Percentiles:"
        display as text "    1st:       " as result %9.4f `w_p1'
        display as text "    5th:       " as result %9.4f `w_p5'
        display as text "    25th:      " as result %9.4f `w_p25'
        display as text "    50th:      " as result %9.4f `w_p50'
        display as text "    75th:      " as result %9.4f `w_p75'
        display as text "    95th:      " as result %9.4f `w_p95'
        display as text "    99th:      " as result %9.4f `w_p99'

        * Effective sample size
        quietly {
            summarize `weight_var'
            local sum_w = r(sum)
            tempvar _w2
            gen double `_w2' = `weight_var'^2
            summarize `_w2'
            local sum_w2 = r(sum)
            drop `_w2'
        }
        local ess = (`sum_w'^2) / `sum_w2'

        * ESS by arm
        forvalues a = 0/1 {
            quietly {
                summarize `weight_var' if `prefix'arm == `a'
                local sum_w_a = r(sum)
                local n_arm_`a' = r(N)
                tempvar _w2a
                gen double `_w2a' = `weight_var'^2 if `prefix'arm == `a'
                summarize `_w2a' if `prefix'arm == `a'
                local sum_w2_a = r(sum)
                drop `_w2a'
            }
            local ess_`a' = (`sum_w_a'^2) / `sum_w2_a'
        }

        display as text ""
        display as text "  Effective Sample Size:"
        display as text "    Overall:   " as result %9.1f `ess'
        display as text "    Control:   " as result %9.1f `ess_0' as text " (of " as result `n_arm_0' as text " obs)"
        display as text "    Treated:   " as result %9.1f `ess_1' as text " (of " as result `n_arm_1' as text " obs)"

        * Extreme weights
        quietly count if `weight_var' > `w_p99' & !missing(`weight_var')
        local n_extreme = r(N)
        if `n_extreme' > 0 {
            display as text ""
            display as text "  Extreme weights (>`w_p99'): " as result `n_extreme' as text " observations"
        }

        return scalar ess = `ess'
        return scalar ess_treat = `ess_1'
        return scalar ess_control = `ess_0'
        return scalar w_mean = `w_mean'
        return scalar w_sd = `w_sd'
        return scalar w_min = `w_min'
        return scalar w_max = `w_max'

        * Weight by trial period
        if "`by_trial'" != "" {
            display as text ""
            display as text "{bf:Weight Distribution by Trial Period}"
            display as text ""
            display as text %8s "Trial" "  " %8s "N" "  " %10s "Mean Wt" "  " %10s "Max Wt"
            display as text _dup(42) "-"

            quietly levelsof `prefix'trial, local(trials)
            foreach t of local trials {
                quietly summarize `weight_var' if `prefix'trial == `t'
                display as text %8.0f `t' "  " ///
                    as result %8.0f r(N) "  " %10.4f r(mean) "  " %10.4f r(max)
            }
        }
    }

    * =========================================================================
    * COVARIATE BALANCE
    * =========================================================================

    if "`balance_covariates'" != "" {
        display as text ""
        display as text "{bf:Covariate Balance (Standardized Mean Differences)}"
        display as text ""

        local n_covs: word count `balance_covariates'
        tempname balance_mat
        matrix `balance_mat' = J(`n_covs', 3, .)

        if `has_weights' {
            display as text %20s "Covariate" "  " %10s "SMD Unwt" "  " %10s "SMD Wt"
            display as text _dup(46) "-"
        }
        else {
            display as text %20s "Covariate" "  " %10s "SMD"
            display as text _dup(34) "-"
        }

        local max_smd_unwt = 0
        local max_smd_wt = 0
        local cov_idx = 0

        foreach var of local balance_covariates {
            local ++cov_idx
            local varlabel "`var'"
            if length("`varlabel'") > 20 {
                local varlabel = substr("`varlabel'", 1, 20)
            }

            * Unweighted SMD
            quietly summarize `var' if `prefix'arm == 1
            local mean1 = r(mean)
            local var1 = r(Var)
            quietly summarize `var' if `prefix'arm == 0
            local mean0 = r(mean)
            local var0 = r(Var)

            local pooled_sd = sqrt((`var1' + `var0') / 2)
            if missing(`pooled_sd') | `pooled_sd' == 0 {
                local smd_unwt = 0
            }
            else {
                local smd_unwt = (`mean1' - `mean0') / `pooled_sd'
            }

            matrix `balance_mat'[`cov_idx', 1] = abs(`smd_unwt')

            if abs(`smd_unwt') > `max_smd_unwt' {
                local max_smd_unwt = abs(`smd_unwt')
            }

            if `has_weights' {
                * Weighted SMD (summarize [aw=] gives weighted mean and variance)
                quietly summarize `var' [aw=`weight_var'] if `prefix'arm == 1
                local wmean1 = r(mean)
                local wvar1 = r(Var)

                quietly summarize `var' [aw=`weight_var'] if `prefix'arm == 0
                local wmean0 = r(mean)
                local wvar0 = r(Var)

                local wpooled_sd = sqrt((`wvar1' + `wvar0') / 2)
                if missing(`wpooled_sd') | `wpooled_sd' == 0 {
                    local smd_wt = 0
                }
                else {
                    local smd_wt = (`wmean1' - `wmean0') / `wpooled_sd'
                }

                matrix `balance_mat'[`cov_idx', 2] = abs(`smd_wt')

                if abs(`smd_wt') > `max_smd_wt' {
                    local max_smd_wt = abs(`smd_wt')
                }

                display as text %20s "`varlabel'" "  " ///
                    as result %10.4f abs(`smd_unwt') "  " %10.4f abs(`smd_wt')
            }
            else {
                display as text %20s "`varlabel'" "  " ///
                    as result %10.4f abs(`smd_unwt')
            }
        }

        display as text ""
        display as text "  Max SMD (unweighted): " as result %7.4f `max_smd_unwt'
        if `has_weights' {
            display as text "  Max SMD (weighted):   " as result %7.4f `max_smd_wt'
        }

        * Assessment
        local threshold = 0.1
        if `has_weights' & `max_smd_wt' < `threshold' {
            display as text ""
            display as result "  Balance achieved (max weighted SMD < 0.1)"
        }
        else if `has_weights' & `max_smd_wt' >= `threshold' {
            display as text ""
            display as text "  Some imbalance remains (max weighted SMD >= 0.1)"
        }

        matrix rownames `balance_mat' = `balance_covariates'
        matrix colnames `balance_mat' = SMD_Unwt SMD_Wt Threshold
        * Fill threshold column
        forvalues i = 1/`n_covs' {
            matrix `balance_mat'[`i', 3] = 0.1
        }

        return matrix balance = `balance_mat'
        return scalar max_smd_unwt = `max_smd_unwt'
        if `has_weights' {
            return scalar max_smd_wt = `max_smd_wt'
        }
    }

    * =========================================================================
    * EQUIPOISE ASSESSMENT (preference scores)
    * =========================================================================

    if "`equipoise'" != "" {
        display as text ""
        display as text "{bf:Equipoise Assessment (Preference Scores)}"
        display as text ""

        * Check for PS variable
        local ps_var : char _dta[_tte_pscore_var]
        if "`ps_var'" == "" {
            display as error "no propensity score variable found"
            display as error "run {cmd:tte_weight, save_ps} first"
            exit 198
        }

        capture confirm variable `ps_var'
        if _rc != 0 {
            display as error "propensity score variable `ps_var' not found in dataset"
            exit 111
        }

        * Compute treatment prevalence at baseline (followup==0)
        quietly summarize `prefix'arm if `prefix'followup == 0
        local prevalence = r(mean)

        * Compute preference score: pref = invlogit(logit(ps) - logit(prevalence))
        * logit(x) = ln(x/(1-x))
        tempvar _pref_score
        local logit_prev = ln(`prevalence' / (1 - `prevalence'))
        quietly gen double `_pref_score' = invlogit(ln(`ps_var' / (1 - `ps_var')) - `logit_prev') ///
            if !missing(`ps_var') & `ps_var' > 0.001 & `ps_var' < 0.999

        * Percentage in equipoise zone [0.3, 0.7]
        quietly count if `_pref_score' >= 0.3 & `_pref_score' <= 0.7 & !missing(`_pref_score')
        local n_equip = r(N)
        quietly count if !missing(`_pref_score')
        local n_ps_total = r(N)
        local pct_equipoise = 100 * `n_equip' / `n_ps_total'

        * Mean preference score by arm
        quietly summarize `_pref_score' if `prefix'arm == 1 & !missing(`_pref_score')
        local mean_pref_treat = r(mean)
        quietly summarize `_pref_score' if `prefix'arm == 0 & !missing(`_pref_score')
        local mean_pref_control = r(mean)

        display as text "  Treatment prevalence:     " as result %7.4f `prevalence'
        display as text "  Mean pref score (treated):" as result %7.4f `mean_pref_treat'
        display as text "  Mean pref score (control):" as result %7.4f `mean_pref_control'
        display as text "  % in equipoise [0.3,0.7]: " as result %7.1f `pct_equipoise' as text "%"
        display as text ""

        if `pct_equipoise' >= 50 {
            display as result "  Good overlap: majority of observations in equipoise zone"
        }
        else {
            display as text "  Limited overlap: " as result string(100 - `pct_equipoise', "%4.1f") ///
                as text "% of observations outside equipoise zone"
        }

        drop `_pref_score'

        return scalar prevalence = `prevalence'
        return scalar pct_equipoise = `pct_equipoise'
        return scalar mean_pref_treat = `mean_pref_treat'
        return scalar mean_pref_control = `mean_pref_control'
    }

    display as text ""
    display as text "{hline 70}"

    return local weight_var "`weight_var'"

    set varabbrev `_vaset'
end
