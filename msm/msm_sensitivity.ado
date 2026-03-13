*! msm_sensitivity Version 1.0.0  2026/03/03
*! Sensitivity analysis for unmeasured confounding in MSM
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  msm_sensitivity [, options]

Description:
  E-value (VanderWeele & Ding 2017): computes the minimum strength of
  association on the risk ratio scale that an unmeasured confounder would
  need to have with both treatment and outcome to explain away the effect.

  Confounding strength bounds: given hypothetical confounder-treatment
  and confounder-outcome associations, computes the bias factor.

Options:
  evalue           - Compute E-value (default if no options)
  bound(numlist)   - Bias bound parameters
  confounding_strength(# #) - RR_UD and RR_UY for bias factor
  level(#)         - Confidence level (default: 95)

See help msm_sensitivity for complete documentation
*/

program define msm_sensitivity, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    set varabbrev off
    set more off

    syntax [, EVAlue BOUND(numlist) ///
        CONFounding_strength(numlist min=2 max=2) ///
        Level(cilevel)]

    _msm_check_fitted
    _msm_get_settings

    local treatment "`_msm_treatment'"
    local model : char _dta[_msm_model]

    if "`level'" == "" local level 95

    * Default to E-value
    if "`evalue'" == "" & "`confounding_strength'" == "" {
        local evalue "evalue"
    }

    * Get treatment effect
    local b_treat = _b[`treatment']
    local se_treat = _se[`treatment']

    * Convert to risk ratio scale for E-value
    * For logistic model: OR -> approximate RR using Zhang & Yu (1998) or
    * simply use the OR as conservative approximation
    * VanderWeele (2017) recommends using OR directly for rare outcomes

    if "`model'" == "logistic" {
        local or = exp(`b_treat')
        local or_lo = exp(`b_treat' - invnormal((100+`level')/200) * `se_treat')
        local or_hi = exp(`b_treat' + invnormal((100+`level')/200) * `se_treat')
        local effect = `or'
        local effect_lo = `or_lo'
        local effect_hi = `or_hi'
        local effect_label "OR"
    }
    else if "`model'" == "cox" {
        local hr = exp(`b_treat')
        local hr_lo = exp(`b_treat' - invnormal((100+`level')/200) * `se_treat')
        local hr_hi = exp(`b_treat' + invnormal((100+`level')/200) * `se_treat')
        local effect = `hr'
        local effect_lo = `hr_lo'
        local effect_hi = `hr_hi'
        local effect_label "HR"
    }
    else {
        * Linear model: use coefficient directly for bounds
        local effect = `b_treat'
        local effect_lo = `b_treat' - invnormal((100+`level')/200) * `se_treat'
        local effect_hi = `b_treat' + invnormal((100+`level')/200) * `se_treat'
        local effect_label "Coef"
    }

    display as text ""
    display as text "{hline 70}"
    display as result "msm_sensitivity" as text " - Sensitivity Analysis"
    display as text "{hline 70}"
    display as text ""

    display as text "Treatment effect:"
    display as text "  `effect_label':             " as result %9.4f `effect'
    display as text "  `level'% CI:          " as result %9.4f `effect_lo' ///
        as text " - " as result %9.4f `effect_hi'

    * =========================================================================
    * E-VALUE
    * =========================================================================

    if "`evalue'" != "" {
        display as text ""
        display as text "{bf:E-value (VanderWeele & Ding 2017)}"
        display as text ""
        display as text "The E-value is the minimum strength of association"
        display as text "on the risk ratio scale that an unmeasured confounder"
        display as text "would need with both the treatment and the outcome"
        display as text "to fully explain away the observed effect."
        display as text ""

        if inlist("`model'", "logistic", "cox") {
            * E-value for point estimate
            * If RR >= 1: E = RR + sqrt(RR * (RR - 1))
            * If RR < 1: convert to 1/RR first
            local rr_point = `effect'
            if `rr_point' < 1 {
                local rr_use = 1 / `rr_point'
            }
            else {
                local rr_use = `rr_point'
            }
            local evalue_point = `rr_use' + sqrt(`rr_use' * (`rr_use' - 1))

            * E-value for CI bound closest to null (1)
            * For protective effect (OR < 1): use upper CI bound
            * For harmful effect (OR > 1): use lower CI bound
            if `effect' < 1 {
                local ci_bound = `effect_hi'
            }
            else {
                local ci_bound = `effect_lo'
            }

            * If CI crosses null, E-value for CI = 1
            if (`effect_lo' <= 1 & `effect_hi' >= 1) {
                local evalue_ci = 1
            }
            else {
                local rr_ci = `ci_bound'
                if `rr_ci' < 1 {
                    local rr_ci = 1 / `rr_ci'
                }
                local evalue_ci = `rr_ci' + sqrt(`rr_ci' * (`rr_ci' - 1))
            }

            display as text "  E-value (point estimate): " as result %9.4f `evalue_point'
            display as text "  E-value (`level'% CI limit):   " as result %9.4f `evalue_ci'
            display as text ""

            if `evalue_ci' <= 1 {
                display as text "  The `level'% CI includes the null."
                display as text "  No unmeasured confounding is needed to explain"
                display as text "  the observed association at the `level'% level."
            }
            else if `evalue_point' < 2 {
                display as text "  A relatively weak unmeasured confounder"
                display as text "  could explain the observed effect."
            }
            else if `evalue_point' < 3 {
                display as text "  A moderately strong unmeasured confounder"
                display as text "  would be needed to explain the observed effect."
            }
            else {
                display as text "  A strong unmeasured confounder would be needed"
                display as text "  to explain the observed effect."
            }

            return scalar evalue_point = `evalue_point'
            return scalar evalue_ci = `evalue_ci'
        }
        else {
            display as text "  E-value not available for linear models."
            display as text "  Use confounding_strength() for bias bounds."
        }
    }

    * =========================================================================
    * CONFOUNDING STRENGTH BOUNDS
    * =========================================================================

    if "`confounding_strength'" != "" {
        local rr_ud: word 1 of `confounding_strength'
        local rr_uy: word 2 of `confounding_strength'

        display as text ""
        display as text "{bf:Confounding Strength Bounds}"
        display as text ""
        display as text "  Hypothetical confounder parameters:"
        display as text "  RR(U,D) [confounder-treatment]: " as result %6.2f `rr_ud'
        display as text "  RR(U,Y) [confounder-outcome]:   " as result %6.2f `rr_uy'

        * Bias factor = (RR_UD * RR_UY) / (RR_UD + RR_UY - 1)
        * VanderWeele & Ding (2017) formula
        local bias_factor = (`rr_ud' * `rr_uy') / (`rr_ud' + `rr_uy' - 1)

        display as text ""
        display as text "  Bias factor: " as result %9.4f `bias_factor'

        if inlist("`model'", "logistic", "cox") {
            local corrected = `effect' / `bias_factor'
            display as text "  Observed `effect_label':    " as result %9.4f `effect'
            display as text "  Corrected `effect_label':   " as result %9.4f `corrected'

            * If corrected crosses null
            if (`effect' < 1 & `corrected' >= 1) | (`effect' > 1 & `corrected' <= 1) {
                display as text ""
                display as text "  This confounder strength would explain away the effect."
            }
            else {
                display as text ""
                display as text "  This confounder strength would not fully explain"
                display as text "  away the observed effect."
            }

            return scalar bias_factor = `bias_factor'
            return scalar corrected_effect = `corrected'
        }

        return scalar rr_ud = `rr_ud'
        return scalar rr_uy = `rr_uy'
    }

    display as text ""
    display as text "{hline 70}"

    return scalar effect = `effect'
    return scalar effect_lo = `effect_lo'
    return scalar effect_hi = `effect_hi'
    return local effect_label "`effect_label'"
    return local model "`model'"

    * Persist for msm_table
    char _dta[_msm_sens_effect] "`effect'"
    char _dta[_msm_sens_effect_lo] "`effect_lo'"
    char _dta[_msm_sens_effect_hi] "`effect_hi'"
    char _dta[_msm_sens_effect_label] "`effect_label'"
    char _dta[_msm_sens_model] "`model'"
    if "`evalue'" != "" & inlist("`model'", "logistic", "cox") {
        char _dta[_msm_sens_evalue_point] "`evalue_point'"
        char _dta[_msm_sens_evalue_ci] "`evalue_ci'"
    }
    char _dta[_msm_sens_saved] "1"

    set varabbrev `_varabbrev'
    set more `_more'
end
