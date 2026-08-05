*! _msm_smd Version 1.4.4  2026/08/05
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
* Continuous weighted covariates use the paper's reliability-weight variance:
*   sum(w) / (sum(w)^2 - sum(w^2)) * sum(w * (x - mean_w)^2).
* Stata's summarize [aw=] variance uses a different finite-sample
* normalization and is not interchangeable when weights are variable.
* Dichotomous covariates use the paper's prevalence form p_w * (1 - p_w).
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

        confirm numeric variable `x'
        confirm numeric variable `treatment'
        if "`weight'" != "" confirm numeric variable `weight'
        if "`touse'" != "" confirm numeric variable `touse'

        * Default touse
        if "`touse'" == "" {
            tempvar touse
            gen byte `touse' = 1
        }

        tempvar _use
        quietly gen byte `_use' = `touse' != 0 & !missing(`touse') & ///
            inlist(`treatment', 0, 1) & !missing(`x')

        if "`weight'" != "" {
            quietly count if `_use' & !missing(`weight') & `weight' <= 0
            if r(N) > 0 {
                display as error "weights must be positive"
                exit 402
            }
            quietly replace `_use' = `_use' & !missing(`weight') & `weight' > 0
        }

        * Austin & Stuart give a separate prevalence formula for a binary
        * covariate. Detect exact 0/1 support over the usable sample.
        quietly count if `_use' & !inlist(`x', 0, 1)
        local _binary = (r(N) == 0)

        if "`weight'" != "" {
            tempvar _wx _w2 _dev2
            quietly gen double `_wx' = `weight' * `x' if `_use'
            quietly gen double `_w2' = `weight'^2 if `_use'

            foreach _g in 1 0 {
                quietly summarize `weight' if `_use' & ///
                    `treatment' == `_g', meanonly
                local _sw`_g' = r(sum)
                quietly summarize `_wx' if `_use' & ///
                    `treatment' == `_g', meanonly
                local mean`_g' = r(sum) / `_sw`_g''
                quietly summarize `_w2' if `_use' & ///
                    `treatment' == `_g', meanonly
                local _sw2`_g' = r(sum)
                * Force the mathematical zero for a constant group.  The
                * centered weighted sum can otherwise retain round-off on the
                * order of 1e-28, producing a finite SMD near 1e15 instead of
                * the undefined zero-denominator result.
                quietly summarize `x' if `_use' & ///
                    `treatment' == `_g', meanonly
                local _constant`_g' = (r(N) > 0 & r(min) == r(max))
            }

            if `_binary' {
                local var1 = `mean1' * (1 - `mean1')
                local var0 = `mean0' * (1 - `mean0')
            }
            else {
                quietly gen double `_dev2' = ///
                    cond(`treatment' == 1, ///
                        `weight' * (`x' - `mean1')^2, ///
                        `weight' * (`x' - `mean0')^2) if `_use'
                foreach _g in 1 0 {
                    quietly summarize `_dev2' if `_use' & ///
                        `treatment' == `_g', meanonly
                    local _denom = `_sw`_g''^2 - `_sw2`_g''
                    if missing(`_denom') | `_denom' <= 0 {
                        local var`_g' = .
                    }
                    else if `_constant`_g'' {
                        local var`_g' = 0
                    }
                    else {
                        local var`_g' = `_sw`_g'' / `_denom' * r(sum)
                    }
                }
            }
        }
        else {
            quietly summarize `x' if `_use' & `treatment' == 1
            local mean1 = r(mean)
            local var1  = r(Var)
            quietly summarize `x' if `_use' & `treatment' == 0
            local mean0 = r(mean)
            local var0  = r(Var)

            if `_binary' {
                local var1 = `mean1' * (1 - `mean1')
                local var0 = `mean0' * (1 - `mean0')
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
