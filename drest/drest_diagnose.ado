*! drest_diagnose Version 1.0.0  2026/03/15
*! Diagnostics for doubly robust estimation
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  drest_diagnose [, overlap propensity influence balance all graph
                    saving(filename) scheme(string)]

Requires: drest_estimate has been run

See help drest_diagnose for complete documentation
*/

program define drest_diagnose, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax [, OVERlap PROPensity INFLuence BALance ALL ///
              GRaph SAVing(string) SCHeme(string) Name(string)]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================
    _drest_check_estimated
    _drest_get_settings

    local outcome   "`_drest_outcome'"
    local treatment "`_drest_treatment'"
    local omodel    "`_drest_omodel'"
    local tmodel    "`_drest_tmodel'"
    local estimand  "`_drest_estimand'"

    * Confirm required variables exist
    foreach v in _drest_ps _drest_mu1 _drest_mu0 _drest_if _drest_esample {
        capture confirm variable `v'
        if _rc {
            set varabbrev `_vaset'
            display as error "variable `v' not found; re-run drest_estimate"
            exit 111
        }
    }

    * Default: if nothing specified, show all
    if "`overlap'" == "" & "`propensity'" == "" & "`influence'" == "" & "`balance'" == "" & "`all'" == "" {
        local all "all"
    }
    if "`all'" != "" {
        local overlap "overlap"
        local propensity "propensity"
        local influence "influence"
        local balance "balance"
    }

    if "`scheme'" == "" local scheme "plotplainblind"

    _drest_display_header "drest_diagnose" "Doubly Robust Diagnostics"

    * =========================================================================
    * PROPENSITY SCORE SUMMARY
    * =========================================================================
    if "`propensity'" != "" {
        display as text "{bf:Propensity Score Summary}"
        display as text "{hline 50}"

        quietly summarize _drest_ps if _drest_esample == 1
        local ps_mean = r(mean)
        local ps_sd   = r(sd)
        local ps_min  = r(min)
        local ps_max  = r(max)

        display as text "Overall:   mean = " as result %7.4f `ps_mean' ///
            as text "  sd = " as result %7.4f `ps_sd' ///
            as text "  range = [" as result %6.4f `ps_min' ///
            as text ", " as result %6.4f `ps_max' as text "]"

        quietly summarize _drest_ps if _drest_esample == 1 & `treatment' == 1
        local ps_mean1 = r(mean)
        local ps_sd1   = r(sd)

        quietly summarize _drest_ps if _drest_esample == 1 & `treatment' == 0
        local ps_mean0 = r(mean)
        local ps_sd0   = r(sd)

        display as text "Treated:   mean = " as result %7.4f `ps_mean1' ///
            as text "  sd = " as result %7.4f `ps_sd1'
        display as text "Control:   mean = " as result %7.4f `ps_mean0' ///
            as text "  sd = " as result %7.4f `ps_sd0'

        * Extreme PS count
        quietly count if _drest_esample == 1 & (_drest_ps < 0.05 | _drest_ps > 0.95)
        local n_extreme = r(N)
        quietly count if _drest_esample == 1
        local pct_extreme = 100 * `n_extreme' / r(N)

        display as text "Extreme (< 0.05 or > 0.95): " ///
            as result %4.0f `n_extreme' ///
            as text " (" as result %4.1f `pct_extreme' as text "%)"

        display as text ""

        return scalar ps_mean = `ps_mean'
        return scalar ps_sd = `ps_sd'
        return scalar ps_min = `ps_min'
        return scalar ps_max = `ps_max'
        return scalar n_extreme = `n_extreme'
        return scalar pct_extreme = `pct_extreme'
    }

    * =========================================================================
    * OVERLAP ASSESSMENT
    * =========================================================================
    if "`overlap'" != "" {
        display as text "{bf:Overlap Assessment}"
        display as text "{hline 50}"

        * Effective sample size
        quietly {
            tempvar ipw
            gen double `ipw' = cond(`treatment' == 1, 1 / _drest_ps, 1 / (1 - _drest_ps)) if _drest_esample == 1

            summarize `ipw' if _drest_esample == 1, meanonly
            local sum_w  = r(sum)
            local N_ess  = r(N)

            tempvar ipw2
            gen double `ipw2' = `ipw'^2 if _drest_esample == 1
            summarize `ipw2' if _drest_esample == 1, meanonly
            local sum_w2 = r(sum)
        }
        local ess = (`sum_w'^2) / `sum_w2'
        local ess_pct = 100 * `ess' / `N_ess'

        display as text "Effective sample size (ESS): " as result %10.1f `ess' ///
            as text " (" as result %4.1f `ess_pct' as text "% of N=" ///
            as result %6.0fc `N_ess' as text ")"

        * C-statistic (discrimination of treatment model)
        quietly {
            tempvar ps_rank
            count if _drest_esample == 1
            local Ntot = r(N)
            * Use rank-based concordance
            egen double `ps_rank' = rank(_drest_ps) if _drest_esample == 1
            summarize `ps_rank' if _drest_esample == 1 & `treatment' == 1, meanonly
            local sum_ranks1 = r(sum)
            local n1 = r(N)
            local n0 = `Ntot' - `n1'
        }
        local c_stat = (`sum_ranks1' - `n1' * (`n1' + 1) / 2) / (`n1' * `n0')

        display as text "C-statistic: " as result %7.4f `c_stat'
        if `c_stat' > 0.8 {
            display as text "  {it:Warning: High discrimination suggests limited overlap}"
        }

        display as text ""

        return scalar ess = `ess'
        return scalar ess_pct = `ess_pct'
        return scalar c_stat = `c_stat'
    }

    * =========================================================================
    * INFLUENCE FUNCTION DIAGNOSTICS
    * =========================================================================
    if "`influence'" != "" {
        display as text "{bf:Influence Function Diagnostics}"
        display as text "{hline 50}"

        quietly summarize _drest_if if _drest_esample == 1
        local if_mean = r(mean)
        local if_sd   = r(sd)
        local if_min  = r(min)
        local if_max  = r(max)

        display as text "Mean:     " as result %12.6f `if_mean'
        display as text "Std Dev:  " as result %12.6f `if_sd'
        display as text "Range:    [" as result %10.4f `if_min' ///
            as text ", " as result %10.4f `if_max' as text "]"

        * Outlier detection: |IF| > 3*SD
        quietly count if _drest_esample == 1 & abs(_drest_if - `if_mean') > 3 * `if_sd'
        local n_outliers = r(N)

        display as text "Outliers (> 3 SD): " as result %4.0f `n_outliers'

        * Skewness
        quietly summarize _drest_if if _drest_esample == 1, detail
        local if_skew = r(skewness)
        local if_kurt = r(kurtosis)

        display as text "Skewness: " as result %8.3f `if_skew'
        display as text "Kurtosis: " as result %8.3f `if_kurt'

        display as text ""

        return scalar if_mean = `if_mean'
        return scalar if_sd = `if_sd'
        return scalar if_min = `if_min'
        return scalar if_max = `if_max'
        return scalar n_outliers = `n_outliers'
        return scalar if_skew = `if_skew'
        return scalar if_kurt = `if_kurt'
    }

    * =========================================================================
    * COVARIATE BALANCE
    * =========================================================================
    if "`balance'" != "" {
        display as text "{bf:Covariate Balance (IPW-weighted)}"
        display as text "{hline 50}"
        display as text %20s "Variable" as text " {c |}" ///
            as text %12s "Raw SMD" as text %12s "Wt'd SMD"
        display as text "{hline 20}{c +}{hline 24}"

        local max_smd = 0
        local max_smd_wt = 0

        * Use treatment model covariates for balance
        foreach var of local tmodel {
            quietly {
                * Raw (unweighted) SMD
                summarize `var' if _drest_esample == 1 & `treatment' == 1
                local m1 = r(mean)
                local v1 = r(Var)
                summarize `var' if _drest_esample == 1 & `treatment' == 0
                local m0 = r(mean)
                local v0 = r(Var)
                local pooled_sd = sqrt((`v1' + `v0') / 2)
                if `pooled_sd' > 0 {
                    local raw_smd = (`m1' - `m0') / `pooled_sd'
                }
                else {
                    local raw_smd = 0
                }

                * IPW-weighted SMD
                tempvar wt_var
                gen double `wt_var' = cond(`treatment' == 1, 1 / _drest_ps, 1 / (1 - _drest_ps)) if _drest_esample == 1

                summarize `var' [aw = `wt_var'] if _drest_esample == 1 & `treatment' == 1
                local wm1 = r(mean)
                summarize `var' [aw = `wt_var'] if _drest_esample == 1 & `treatment' == 0
                local wm0 = r(mean)
                if `pooled_sd' > 0 {
                    local wt_smd = (`wm1' - `wm0') / `pooled_sd'
                }
                else {
                    local wt_smd = 0
                }
                drop `wt_var'
            }

            local abs_raw = abs(`raw_smd')
            local abs_wt  = abs(`wt_smd')
            if `abs_raw' > `max_smd' local max_smd = `abs_raw'
            if `abs_wt' > `max_smd_wt' local max_smd_wt = `abs_wt'

            * Flag imbalance
            local flag ""
            if `abs_wt' > 0.1 local flag " *"

            display as text %20s abbrev("`var'", 20) as text " {c |}" ///
                as result %12.4f `raw_smd' ///
                as result %12.4f `wt_smd' ///
                as text "`flag'"
        }

        display as text "{hline 20}{c +}{hline 24}"
        display as text "Max |SMD|:" ///
            as text "           " as text " {c |}" ///
            as result %12.4f `max_smd' ///
            as result %12.4f `max_smd_wt'
        if `max_smd_wt' > 0.1 {
            display as text "  {it:* Residual imbalance > 0.1 after weighting}"
        }

        display as text ""

        return scalar max_smd = `max_smd'
        return scalar max_smd_wt = `max_smd_wt'
    }

    * =========================================================================
    * GRAPHS
    * =========================================================================
    if "`graph'" != "" {
        if "`overlap'" != "" {
            * PS overlap histogram
            local gopts `"title("Propensity Score Overlap") scheme(`scheme')"'
            if "`saving'" != "" local gopts `"`gopts' saving(`saving'_overlap, replace)"'
            if "`name'" != "" {
                local gopts `"`gopts' name(`name'_overlap, replace)"'
            }
            else {
                local gopts `"`gopts' name(drest_overlap, replace)"'
            }

            capture noisily twoway (histogram _drest_ps if _drest_esample == 1 & `treatment' == 1, ///
                    color(navy%50) width(0.02) frequency) ///
                   (histogram _drest_ps if _drest_esample == 1 & `treatment' == 0, ///
                    color(cranberry%50) width(0.02) frequency), ///
                legend(order(1 "Treated" 2 "Control") position(1) ring(0)) ///
                xtitle("Propensity Score") ytitle("Frequency") ///
                `gopts'
            if _rc {
                set varabbrev `_vaset'
                exit _rc
            }
        }

        if "`influence'" != "" {
            * IF distribution
            local gopts2 `"title("Influence Function Distribution") scheme(`scheme')"'
            if "`saving'" != "" local gopts2 `"`gopts2' saving(`saving'_influence, replace)"'
            if "`name'" != "" {
                local gopts2 `"`gopts2' name(`name'_influence, replace)"'
            }
            else {
                local gopts2 `"`gopts2' name(drest_influence, replace)"'
            }

            capture noisily twoway (histogram _drest_if if _drest_esample == 1, ///
                    color(navy%70) frequency), ///
                xtitle("Influence Function Value") ytitle("Frequency") ///
                xline(0, lcolor(red) lpattern(dash)) ///
                `gopts2'
            if _rc {
                set varabbrev `_vaset'
                exit _rc
            }
        }
    }

    return local outcome "`outcome'"
    return local treatment "`treatment'"
    return local estimand "`estimand'"
    return local diagnostics "`overlap' `propensity' `influence' `balance'"

    set varabbrev `_vaset'
end
