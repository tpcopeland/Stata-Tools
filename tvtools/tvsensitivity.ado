*! tvsensitivity Version 1.0.1  2026/02/23
*! Sensitivity analysis for unmeasured confounding
*! Author: Tim Copeland
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tvsensitivity, rr(#) [method(string) cilow(#) rru(numlist) rrU(numlist)]

Required:
  rr(#)           - Observed relative risk / hazard ratio

Optional:
  method(string)  - Method: evalue (default), bias
  cilow(#)        - Lower bound of confidence interval for E-value CI calculation
  rru(numlist)    - Sensitivity parameters for RR(U|A=1) vs RR(U|A=0)
  rrU(numlist)    - Sensitivity parameters for RR(Y|U)

Description:
  Calculates E-values and bias parameters for sensitivity to
  unmeasured confounding.

See help tvsensitivity for complete documentation
*/

program define tvsensitivity, rclass
    version 16.0
    set varabbrev off
    set more off

    syntax , RR(real) [METHOD(string) RRU(numlist) RROU(numlist) LEVEL(integer 95) CILow(real 0)]

    * Set defaults
    if "`method'" == "" local method "evalue"
    local method = lower("`method'")

    * =========================================================================
    * VALIDATE INPUT
    * =========================================================================

    if `rr' <= 0 {
        display as error "rr() must be positive"
        exit 198
    }

    if !inlist("`method'", "evalue", "bias") {
        display as error "method() must be evalue or bias"
        exit 198
    }

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as text "{bf:Sensitivity Analysis for Unmeasured Confounding}"
    display as text "{hline 70}"
    display as text ""
    display as text "Observed RR/HR: " as result %6.3f `rr'
    display as text "Method:         " as result "`method'"
    display as text ""

    * =========================================================================
    * E-VALUE CALCULATION
    * =========================================================================

    if "`method'" == "evalue" {
        display as text "{bf:E-value Analysis}"
        display as text ""

        * E-value formula: E = RR + sqrt(RR * (RR - 1))
        * For RR > 1
        if `rr' >= 1 {
            local evalue = `rr' + sqrt(`rr' * (`rr' - 1))
        }
        else {
            * For protective effects, use 1/RR
            local rr_inv = 1 / `rr'
            local evalue = `rr_inv' + sqrt(`rr_inv' * (`rr_inv' - 1))
        }

        display as text "E-value: " as result %6.3f `evalue'
        display as text ""
        display as text "Interpretation:"
        display as text "  The observed RR of " %5.3f `rr' " could be explained away"
        display as text "  by an unmeasured confounder associated with both"
        display as text "  exposure and outcome by a RR of " %5.3f `evalue' " each,"
        display as text "  above and beyond measured confounders."
        display as text ""
        display as text "  Weaker confounding could not fully explain the effect."
        display as text ""

        * E-value for confidence interval bound
        if `cilow' > 0 {
            * Use user-supplied lower CI bound
            local rr_lo = `cilow'

            if `rr_lo' > 1 {
                local evalue_lo = `rr_lo' + sqrt(`rr_lo' * (`rr_lo' - 1))
                display as text "E-value for lower CI bound (" %5.3f `rr_lo' "): " as result %6.3f `evalue_lo'
            }
            else if `rr_lo' > 0 & `rr_lo' < 1 {
                local rr_lo_inv = 1 / `rr_lo'
                local evalue_lo = `rr_lo_inv' + sqrt(`rr_lo_inv' * (`rr_lo_inv' - 1))
                display as text "E-value for lower CI bound (" %5.3f `rr_lo' "): " as result %6.3f `evalue_lo'
            }
            else {
                display as text "Lower CI bound crosses null - E-value for CI = 1.0"
                local evalue_lo = 1
            }

            return scalar evalue_ci = `evalue_lo'
        }
        else {
            display as text "Note: specify cilow() for E-value of the confidence interval bound"
        }

        return scalar evalue = `evalue'
        return scalar rr = `rr'
    }

    * =========================================================================
    * BIAS ANALYSIS
    * =========================================================================

    if "`method'" == "bias" {
        display as text "{bf:Quantitative Bias Analysis}"
        display as text ""

        if "`rru'" == "" {
            local rru "1.5 2.0 3.0"
        }
        if "`rrou'" == "" {
            local rrou "1.5 2.0 3.0"
        }

        display as text "Bias-corrected RR under different confounding scenarios:"
        display as text ""
        display as text "{hline 55}"
        display as text "RR(U|A=1)/RR(U|A=0)   RR(Y|U)   Bias Factor   Adj. RR"
        display as text "{hline 55}"

        foreach gamma of numlist `rru' {
            foreach delta of numlist `rrou' {
                * Bias factor = (gamma * delta + 1) / (gamma + delta)
                local bias = (`gamma' * `delta' + 1) / (`gamma' + `delta')
                local rr_adj = `rr' / `bias'

                display as text %10.2f `gamma' %13.2f `delta' ///
                    %14.3f `bias' as result %12.3f `rr_adj'
            }
        }

        display as text "{hline 55}"
        display as text ""

        return local rru "`rru'"
        return local rrou "`rrou'"
        return scalar rr = `rr'
    }

    * =========================================================================
    * RETURN VALUES
    * =========================================================================

    return local method "`method'"

    display as text "{hline 70}"
    display as text "Reference: VanderWeele & Ding (2017). Ann Intern Med."
    display as text "{hline 70}"

end
