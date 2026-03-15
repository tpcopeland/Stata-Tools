*! drest_sensitivity Version 1.0.0  2026/03/15
*! E-value sensitivity analysis for unmeasured confounding
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  drest_sensitivity [, evalue rare detail]

Requires: drest_estimate has been run

References:
  VanderWeele TJ, Ding P (2017). "Sensitivity Analysis in Observational
  Research: Introducing the E-Value." Annals of Internal Medicine.

See help drest_sensitivity for complete documentation
*/

program define drest_sensitivity, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    syntax [, EVALue RARE Detail]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================
    _drest_check_estimated
    _drest_get_settings

    local outcome    "`_drest_outcome'"
    local treatment  "`_drest_treatment'"
    local estimand   "`_drest_estimand'"
    local tau        "`_drest_ate'"
    local se         "`_drest_ate_se'"
    local level      "`_drest_level'"
    local ofamily    "`_drest_ofamily'"

    capture confirm variable _drest_esample
    if _rc {
        set varabbrev `_vaset'
        display as error "_drest_esample not found; re-run drest_estimate"
        exit 111
    }

    * Default: show E-value
    if "`evalue'" == "" local evalue "evalue"

    local z = invnormal(1 - (100 - `level') / 200)
    local ci_lo = `tau' - `z' * `se'
    local ci_hi = `tau' + `z' * `se'

    _drest_display_header "drest_sensitivity" "Sensitivity Analysis"

    * =========================================================================
    * E-VALUE COMPUTATION
    * =========================================================================
    if "`evalue'" != "" {
        * Convert to risk ratio scale for E-value
        * For continuous outcomes, use approximate conversion: RR ≈ exp(0.91*d)
        * where d = tau / SD(Y|control)
        * For binary outcomes with rare outcome, OR ≈ RR
        * For binary outcomes common, use sqrt conversion

        if inlist("`ofamily'", "logit", "probit") {
            * Binary outcome — convert to RR scale
            * Use PO means to compute RR
            local po1 "`_drest_po1'"
            local po0 "`_drest_po0'"

            if `po0' > 0 {
                local rr = `po1' / `po0'
            }
            else {
                set varabbrev `_vaset'
                display as error "cannot compute risk ratio: control PO mean is zero"
                exit 198
            }

            * For common outcomes, use the square root approximation
            * RR_approx from OR: RR = OR / (1 - p0 + p0*OR)
            if "`rare'" != "" {
                * Rare outcome assumption: RR ≈ OR
                local rr_label "Risk Ratio (rare outcome)"
            }
            else {
                local rr_label "Risk Ratio"
            }
        }
        else {
            * Continuous outcome — approximate RR
            * Cohen's d = tau / pooled SD
            quietly summarize `outcome' if _drest_esample == 1 & `treatment' == 0
            local sd_ctrl = r(sd)

            if `sd_ctrl' > 0 {
                local d = `tau' / `sd_ctrl'
                * Convert d to approximate RR: RR ≈ exp(0.91 * d)
                local rr = exp(0.91 * `d')
                local rr_label "Approximate RR (via Cohen's d)"
            }
            else {
                set varabbrev `_vaset'
                display as error "cannot compute effect size: control group SD is zero"
                exit 198
            }
        }

        * E-value for point estimate
        * E = RR + sqrt(RR * (RR - 1))  when RR >= 1
        * E = 1/RR + sqrt(1/RR * (1/RR - 1))  when RR < 1
        if `rr' >= 1 {
            local evalue_pt = `rr' + sqrt(`rr' * (`rr' - 1))
        }
        else {
            local rr_inv = 1 / `rr'
            local evalue_pt = `rr_inv' + sqrt(`rr_inv' * (`rr_inv' - 1))
        }

        * E-value for CI bound closest to null
        * If CI includes null (1 for RR), E-value for CI = 1
        if inlist("`ofamily'", "logit", "probit") {
            * CI for RR from PO means
            local rr_lo = (`po1' - `z' * `se') / `po0'
            local rr_hi = (`po1' + `z' * `se') / `po0'

            if `rr_lo' <= 1 & `rr_hi' >= 1 {
                local evalue_ci = 1
            }
            else if `rr' >= 1 {
                * Lower CI bound
                if `rr_lo' >= 1 {
                    local evalue_ci = `rr_lo' + sqrt(`rr_lo' * (`rr_lo' - 1))
                }
                else {
                    local evalue_ci = 1
                }
            }
            else {
                if `rr_hi' <= 1 {
                    local rr_hi_inv = 1 / `rr_hi'
                    local evalue_ci = `rr_hi_inv' + sqrt(`rr_hi_inv' * (`rr_hi_inv' - 1))
                }
                else {
                    local evalue_ci = 1
                }
            }
        }
        else {
            * Continuous: CI for d, then convert
            local d_lo = `ci_lo' / `sd_ctrl'
            local d_hi = `ci_hi' / `sd_ctrl'
            local rr_lo = exp(0.91 * `d_lo')
            local rr_hi = exp(0.91 * `d_hi')

            if `rr_lo' <= 1 & `rr_hi' >= 1 {
                local evalue_ci = 1
            }
            else if `rr' >= 1 {
                if `rr_lo' >= 1 {
                    local evalue_ci = `rr_lo' + sqrt(`rr_lo' * (`rr_lo' - 1))
                }
                else {
                    local evalue_ci = 1
                }
            }
            else {
                if `rr_hi' <= 1 {
                    local rr_hi_inv = 1 / `rr_hi'
                    local evalue_ci = `rr_hi_inv' + sqrt(`rr_hi_inv' * (`rr_hi_inv' - 1))
                }
                else {
                    local evalue_ci = 1
                }
            }
        }

        * Display
        display as text "{bf:E-Value Sensitivity Analysis}"
        display as text "{hline 50}"
        display as text "`estimand':           " as result %12.4f `tau'
        display as text "`rr_label': " as result %8.3f `rr'
        display as text ""
        display as text "E-value (point estimate): " as result %8.3f `evalue_pt'
        display as text "E-value (`level'% CI limit):   " as result %8.3f `evalue_ci'
        display as text ""

        if `evalue_pt' > 2 {
            display as text "Interpretation: An unmeasured confounder would need"
            display as text "to be associated with both treatment and outcome by"
            display as text "a risk ratio of at least " as result %5.2f `evalue_pt' ///
                as text " each, above and beyond"
            display as text "the measured confounders, to explain away the effect."
        }
        else {
            display as text "Interpretation: A relatively weak unmeasured confounder"
            display as text "could potentially explain the observed effect."
        }

        if "`detail'" != "" {
            display as text ""
            display as text "{bf:Details}"
            display as text "{hline 50}"
            display as text "Method: VanderWeele & Ding (2017)"
            display as text "Formula: E = RR + sqrt(RR * (RR - 1))"
            if !inlist("`ofamily'", "logit", "probit") {
                display as text "Cohen's d:    " as result %8.4f `d'
                display as text "Conversion: RR = exp(0.91 * d)"
            }
        }

        return scalar evalue = `evalue_pt'
        return scalar evalue_ci = `evalue_ci'
        return scalar rr = `rr'
    }

    return scalar tau = `tau'
    return scalar se = `se'
    return local estimand "`estimand'"
    return local outcome "`outcome'"
    return local treatment "`treatment'"

    set varabbrev `_vaset'
end
