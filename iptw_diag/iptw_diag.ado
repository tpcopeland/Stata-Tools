*! iptw_diag Version 1.0.0  2025/12/21
*! IPTW weight diagnostics - distribution, ESS, extreme weights, trimming
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())

/*
DESCRIPTION:
    Comprehensive diagnostics for inverse probability of treatment weights (IPTW).
    Assesses weight distribution, calculates effective sample size, detects
    extreme weights, and provides weight trimming/stabilization utilities.

SYNTAX:
    iptw_diag wvar [if] [in], TREATment(varname) [options]

Required:
    wvar                - IPTW weight variable
    treatment(varname)  - Binary treatment indicator (0/1)

Options:
    trim(#)             - Trim weights at specified percentile (e.g., 99)
    truncate(#)         - Truncate weights at maximum value
    stabilize           - Calculate stabilized weights
    GENerate(name)      - Name for trimmed/stabilized weight variable
    replace             - Allow replacing existing variable
    detail              - Show detailed percentile distribution
    GRaph               - Display weight distribution histogram
    saving(string)      - Save graph to file
    xlabel(numlist)     - Custom x-axis labels for graph

EXAMPLES:
    * Basic weight diagnostics
    iptw_diag ipw, treatment(treated)

    * With detailed percentiles
    iptw_diag ipw, treatment(treated) detail

    * Trim at 99th percentile
    iptw_diag ipw, treatment(treated) trim(99) generate(ipw_trimmed)

    * Truncate at maximum weight
    iptw_diag ipw, treatment(treated) truncate(10) generate(ipw_trunc)

    * Create stabilized weights
    iptw_diag ipw, treatment(treated) stabilize generate(ipw_stab)

STORED RESULTS:
    r(N)            - Number of observations
    r(mean_wt)      - Mean weight
    r(sd_wt)        - SD of weights
    r(min_wt)       - Minimum weight
    r(max_wt)       - Maximum weight
    r(cv)           - Coefficient of variation
    r(ess)          - Effective sample size
    r(ess_pct)      - ESS as percentage of N
    r(n_extreme)    - Number of extreme weights (>10)
    r(pct_extreme)  - Percentage of extreme weights
*/

program define iptw_diag, rclass
    version 16.0
    set varabbrev off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax varname(numeric) [if] [in], ///
        TREATment(varname) ///
        [TRIM(real 0) ///
         TRUNCate(real 0) ///
         STABilize ///
         GENerate(name) ///
         replace ///
         DETail ///
         GRaph ///
         SAVing(string) ///
         xlabel(numlist)]

    local wvar `varlist'

    * =========================================================================
    * MARK SAMPLE
    * =========================================================================
    marksample touse
    markout `touse' `treatment'

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    * =========================================================================
    * VALIDATE INPUTS
    * =========================================================================
    * Validate treatment is binary
    capture assert inlist(`treatment', 0, 1) if `touse'
    if _rc {
        display as error "treatment() must be binary (0/1)"
        exit 198
    }

    * Check weights are positive
    quietly summarize `wvar' if `touse'
    if r(min) <= 0 {
        display as error "weights must be positive"
        exit 198
    }

    * Validate trim percentile
    if `trim' != 0 {
        if `trim' < 50 | `trim' > 99.9 {
            display as error "trim() must be between 50 and 99.9"
            exit 198
        }
    }

    * Validate truncate value
    if `truncate' != 0 {
        if `truncate' <= 0 {
            display as error "truncate() must be positive"
            exit 198
        }
    }

    * Check for conflicting options
    if `trim' != 0 & `truncate' != 0 {
        display as error "cannot specify both trim() and truncate()"
        exit 198
    }

    * Validate generate options
    if "`generate'" != "" & "`replace'" == "" {
        capture confirm new variable `generate'
        if _rc {
            display as error "variable `generate' already exists; use replace option"
            exit 110
        }
    }

    * =========================================================================
    * CALCULATE WEIGHT STATISTICS
    * =========================================================================
    quietly {
        * Overall weight statistics
        summarize `wvar' if `touse', detail
        local mean_wt = r(mean)
        local sd_wt = r(sd)
        local min_wt = r(min)
        local max_wt = r(max)
        local p1 = r(p1)
        local p5 = r(p5)
        local p10 = r(p10)
        local p25 = r(p25)
        local p50 = r(p50)
        local p75 = r(p75)
        local p90 = r(p90)
        local p95 = r(p95)
        local p99 = r(p99)

        * Coefficient of variation
        local cv = `sd_wt' / `mean_wt'

        * Statistics by treatment group
        summarize `wvar' if `touse' & `treatment' == 1, detail
        local mean_wt_t = r(mean)
        local sd_wt_t = r(sd)
        local min_wt_t = r(min)
        local max_wt_t = r(max)
        local n_treated = r(N)

        summarize `wvar' if `touse' & `treatment' == 0, detail
        local mean_wt_c = r(mean)
        local sd_wt_c = r(sd)
        local min_wt_c = r(min)
        local max_wt_c = r(max)
        local n_control = r(N)

        * -----------------------------------------------------------------
        * Effective Sample Size (ESS)
        * ESS = (sum of weights)^2 / sum of weights^2
        * -----------------------------------------------------------------
        tempvar wt_sq
        gen double `wt_sq' = `wvar'^2 if `touse'

        * Overall ESS
        summarize `wvar' if `touse'
        local sum_wt = r(sum)
        summarize `wt_sq' if `touse'
        local sum_wt_sq = r(sum)
        local ess = (`sum_wt'^2) / `sum_wt_sq'
        local ess_pct = 100 * `ess' / `N'

        * ESS by treatment group
        summarize `wvar' if `touse' & `treatment' == 1
        local sum_wt_t = r(sum)
        summarize `wt_sq' if `touse' & `treatment' == 1
        local sum_wt_sq_t = r(sum)
        local ess_t = (`sum_wt_t'^2) / `sum_wt_sq_t'
        local ess_pct_t = 100 * `ess_t' / `n_treated'

        summarize `wvar' if `touse' & `treatment' == 0
        local sum_wt_c = r(sum)
        summarize `wt_sq' if `touse' & `treatment' == 0
        local sum_wt_sq_c = r(sum)
        local ess_c = (`sum_wt_c'^2) / `sum_wt_sq_c'
        local ess_pct_c = 100 * `ess_c' / `n_control'

        drop `wt_sq'

        * -----------------------------------------------------------------
        * Extreme weights (>10 is common threshold)
        * -----------------------------------------------------------------
        count if `wvar' > 10 & `touse'
        local n_extreme = r(N)
        local pct_extreme = 100 * `n_extreme' / `N'

        count if `wvar' > 20 & `touse'
        local n_very_extreme = r(N)
    }

    * =========================================================================
    * DISPLAY OUTPUT
    * =========================================================================
    display as text _n "{hline 70}"
    display as text "IPTW Weight Diagnostics"
    display as text "{hline 70}"
    display as text "Weight variable:   " as result "`wvar'"
    display as text "Treatment:         " as result "`treatment'"
    display as text "Observations:      " as result %10.0fc `N'
    display as text "{hline 70}"
    display ""

    * Weight distribution summary
    display as text "{hline 70}"
    display as text "Weight Distribution Summary"
    display as text "{hline 70}"
    display as text %25s "" "Overall" %15s "Treated" %15s "Control"
    display as text "{hline 70}"
    display as text %25s "N" ///
        as result %15.0fc `N' %15.0fc `n_treated' %15.0fc `n_control'
    display as text %25s "Mean" ///
        as result %15.3f `mean_wt' %15.3f `mean_wt_t' %15.3f `mean_wt_c'
    display as text %25s "SD" ///
        as result %15.3f `sd_wt' %15.3f `sd_wt_t' %15.3f `sd_wt_c'
    display as text %25s "Min" ///
        as result %15.3f `min_wt' %15.3f `min_wt_t' %15.3f `min_wt_c'
    display as text %25s "Max" ///
        as result %15.3f `max_wt' %15.3f `max_wt_t' %15.3f `max_wt_c'
    display as text "{hline 70}"
    display ""

    * Percentile distribution
    if "`detail'" != "" {
        display as text "{hline 50}"
        display as text "Percentile Distribution (Overall)"
        display as text "{hline 50}"
        display as text %15s "Percentile" %15s "Weight"
        display as text "{hline 50}"
        display as text %15s "1%" as result %15.3f `p1'
        display as text %15s "5%" as result %15.3f `p5'
        display as text %15s "10%" as result %15.3f `p10'
        display as text %15s "25%" as result %15.3f `p25'
        display as text %15s "50% (median)" as result %15.3f `p50'
        display as text %15s "75%" as result %15.3f `p75'
        display as text %15s "90%" as result %15.3f `p90'
        display as text %15s "95%" as result %15.3f `p95'
        display as text %15s "99%" as result %15.3f `p99'
        display as text "{hline 50}"
        display ""
    }

    * Effective sample size
    display as text "{hline 70}"
    display as text "Effective Sample Size (ESS)"
    display as text "{hline 70}"
    display as text %25s "" "Overall" %15s "Treated" %15s "Control"
    display as text "{hline 70}"
    display as text %25s "ESS" ///
        as result %15.1f `ess' %15.1f `ess_t' %15.1f `ess_c'
    display as text %25s "ESS % of N" ///
        as result %14.1f `ess_pct' "%" %14.1f `ess_pct_t' "%" %14.1f `ess_pct_c' "%"
    display as text "{hline 70}"
    display ""

    * Extreme weights
    display as text "{hline 50}"
    display as text "Extreme Weight Detection"
    display as text "{hline 50}"
    display as text "Coefficient of Variation: " as result %8.3f `cv'
    display as text "Weights > 10:             " as result %8.0f `n_extreme' ///
        as text " (" as result %5.2f `pct_extreme' as text "%)"
    display as text "Weights > 20:             " as result %8.0f `n_very_extreme'
    display as text "{hline 50}"

    * Interpretation
    display ""
    if `ess_pct' < 50 {
        display as error "Warning: ESS is less than 50% of N. Consider trimming weights."
    }
    if `cv' > 1 {
        display as error "Warning: High CV indicates substantial weight variability."
    }
    if `n_extreme' > 0 {
        display as error "Warning: " `n_extreme' " extreme weights detected (>10)."
    }
    if `max_wt' > 20 {
        display as error "Warning: Maximum weight exceeds 20. Consider truncation."
    }

    * =========================================================================
    * WEIGHT TRIMMING/STABILIZATION
    * =========================================================================
    if `trim' != 0 | `truncate' != 0 | "`stabilize'" != "" {
        if "`generate'" == "" {
            display as error "generate() required with trim(), truncate(), or stabilize"
            exit 198
        }

        quietly {
            if "`replace'" != "" {
                capture drop `generate'
            }

            if `trim' != 0 {
                * Percentile trimming
                _pctile `wvar' if `touse', p(`trim')
                local trim_val = r(r1)
                gen double `generate' = min(`wvar', `trim_val') if `touse'
                label variable `generate' "`wvar' trimmed at p`trim'"
                local action "Trimmed at p`trim' (cutoff: `=string(`trim_val', "%6.3f")')"
            }
            else if `truncate' != 0 {
                * Fixed truncation
                gen double `generate' = min(`wvar', `truncate') if `touse'
                label variable `generate' "`wvar' truncated at `truncate'"
                local action "Truncated at `truncate'"
            }
            else if "`stabilize'" != "" {
                * Stabilized weights: multiply by marginal probability
                summarize `treatment' if `touse'
                local p_treat = r(mean)

                gen double `generate' = cond(`treatment' == 1, ///
                    `p_treat' * `wvar', (1 - `p_treat') * `wvar') if `touse'
                label variable `generate' "`wvar' stabilized"
                local action "Stabilized (P(T=1) = `=string(`p_treat', "%6.3f")')"
            }

            * Report new weight statistics
            summarize `generate' if `touse', detail
            local new_mean = r(mean)
            local new_sd = r(sd)
            local new_min = r(min)
            local new_max = r(max)
            local new_cv = `new_sd' / `new_mean'

            * New ESS
            tempvar new_wt_sq
            gen double `new_wt_sq' = `generate'^2 if `touse'
            summarize `generate' if `touse'
            local new_sum_wt = r(sum)
            summarize `new_wt_sq' if `touse'
            local new_sum_wt_sq = r(sum)
            local new_ess = (`new_sum_wt'^2) / `new_sum_wt_sq'
            local new_ess_pct = 100 * `new_ess' / `N'
            drop `new_wt_sq'
        }

        display ""
        display as text "{hline 70}"
        display as text "Modified Weight Statistics: `generate'"
        display as text "`action'"
        display as text "{hline 70}"
        display as text %25s "Statistic" %15s "Original" %15s "Modified"
        display as text "{hline 70}"
        display as text %25s "Mean" ///
            as result %15.3f `mean_wt' %15.3f `new_mean'
        display as text %25s "SD" ///
            as result %15.3f `sd_wt' %15.3f `new_sd'
        display as text %25s "Max" ///
            as result %15.3f `max_wt' %15.3f `new_max'
        display as text %25s "CV" ///
            as result %15.3f `cv' %15.3f `new_cv'
        display as text %25s "ESS" ///
            as result %15.1f `ess' %15.1f `new_ess'
        display as text %25s "ESS % of N" ///
            as result %14.1f `ess_pct' "%" %14.1f `new_ess_pct' "%"
        display as text "{hline 70}"

        return scalar new_mean = `new_mean'
        return scalar new_sd = `new_sd'
        return scalar new_max = `new_max'
        return scalar new_ess = `new_ess'
        return scalar new_ess_pct = `new_ess_pct'
        return local generate "`generate'"
    }

    * =========================================================================
    * WEIGHT DISTRIBUTION GRAPH
    * =========================================================================
    if "`graph'" != "" {
        quietly {
            if "`xlabel'" == "" {
                local xlabel "0 2 5 10 15 20"
            }

            twoway (histogram `wvar' if `touse' & `treatment' == 1, ///
                       fcolor(navy%50) lcolor(navy) width(0.5)) ///
                   (histogram `wvar' if `touse' & `treatment' == 0, ///
                       fcolor(cranberry%50) lcolor(cranberry) width(0.5)), ///
                   legend(order(1 "Treated" 2 "Control") rows(1)) ///
                   xtitle("IPTW Weight") ytitle("Frequency") ///
                   title("IPTW Weight Distribution") ///
                   xlabel(`xlabel') ///
                   xline(1, lcolor(gs8) lpattern(dash)) ///
                   name(iptw_hist, replace)

            if "`saving'" != "" {
                graph export "`saving'", replace
            }
        }
    }

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================
    return scalar N = `N'
    return scalar N_treated = `n_treated'
    return scalar N_control = `n_control'
    return scalar mean_wt = `mean_wt'
    return scalar sd_wt = `sd_wt'
    return scalar min_wt = `min_wt'
    return scalar max_wt = `max_wt'
    return scalar cv = `cv'
    return scalar ess = `ess'
    return scalar ess_pct = `ess_pct'
    return scalar ess_treated = `ess_t'
    return scalar ess_control = `ess_c'
    return scalar n_extreme = `n_extreme'
    return scalar pct_extreme = `pct_extreme'
    return scalar p1 = `p1'
    return scalar p5 = `p5'
    return scalar p95 = `p95'
    return scalar p99 = `p99'
    return local wvar "`wvar'"
    return local treatment "`treatment'"

end
