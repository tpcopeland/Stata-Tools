*! _msm_smd Version 1.0.0  2026/03/03
*! Compute standardized mean difference between treatment groups
*! Author: Timothy P Copeland

* Computes the SMD = (mean_1 - mean_0) / sqrt((var_1 + var_0) / 2)
* Optionally weighted by an analysis weight variable.
*
* Arguments:
*   varname      - covariate to compute SMD for
*   treatment    - binary treatment indicator
*   [weight]     - optional weight variable (for weighted SMD)
*
* Returns via c_local: _msm_smd_value (the SMD)

program define _msm_smd
    version 16.0
    set varabbrev off
    set more off

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

    if `pooled_sd' > 0 {
        local smd = (`mean1' - `mean0') / `pooled_sd'
    }
    else {
        local smd = 0
    }

    c_local _msm_smd_value "`smd'"
end
