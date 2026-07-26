*! _msm_smd Version 1.4.0  2026/07/26
*! Compute standardized mean difference between treatment groups
*! Author: Timothy P Copeland, Karolinska Institutet

* Computes the SMD = (mean_1 - mean_0) / sqrt((var_1 + var_0) / 2)
* Optionally weighted by an analysis weight variable.
*
* Denominator convention (Austin & Stuart 2015, Stat Med 34:3661-3679, s4.1.1):
* when a weight is supplied, BOTH the means and the variances are replaced by
* their weighted equivalents -- "each sample estimate can be replaced by its
* weighted equivalent" -- so the pooled SD in the denominator is the weighted
* pooled SD of the pseudo-population, not the crude-sample SD. The alternative
* convention (a common unweighted denominator so that pre- and post-weighting
* SMDs share one scale, as in the R package cobalt) is deliberately NOT used
* here and must not be attributed to Austin & Stuart. Consequence: the
* unweighted and weighted SMDs msm_diagnose reports side by side are each
* standardized by their own sample's SD.
*
* Stata's aweight variance normalizes the weights to sum to N and divides by
* N-1; the paper's reliability-weight form divides by
* (sum w)^2 - sum(w^2) over sum w. The two agree exactly under equal weights
* and differ by O(1/n) otherwise.
*
* Arguments:
*   varname      - covariate to compute SMD for
*   treatment    - binary treatment indicator
*   [weight]     - optional weight variable (for weighted SMD)
*
* Returns via c_local: _msm_smd_value (the SMD)

program define _msm_smd
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax varname, treatment(varname) [weight(varname) touse(varname)]

        local x "`varlist'"

        * Default touse
        if "`touse'" == "" {
            tempvar touse
            gen byte `touse' = 1
        }

        quietly {
            if "`weight'" != "" {
                * Weighted means and variances
                summarize `x' [aw=`weight'] if `treatment' == 1 & `touse'
                local mean1 = r(mean)
                local var1  = r(Var)

                summarize `x' [aw=`weight'] if `treatment' == 0 & `touse'
                local mean0 = r(mean)
                local var0  = r(Var)
            }
            else {
                * Unweighted
                summarize `x' if `treatment' == 1 & `touse'
                local mean1 = r(mean)
                local var1  = r(Var)

                summarize `x' if `treatment' == 0 & `touse'
                local mean0 = r(mean)
                local var0  = r(Var)
            }
        }

        * Pooled SD (average of variances, then square root)
        local pooled_sd = sqrt((`var1' + `var0') / 2)

        if missing(`mean1') | missing(`mean0') | missing(`pooled_sd') {
            local smd = .
        }
        else if `pooled_sd' > 0 {
            local smd = (`mean1' - `mean0') / `pooled_sd'
        }
        else if `mean1' == `mean0' {
            local smd = 0
        }
        else {
            * Zero variance in both groups but different means: the SMD is
            * undefined (infinite); report missing rather than a false 0.
            local smd = .
        }

        c_local _msm_smd_value "`smd'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
