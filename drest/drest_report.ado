*! drest_report Version 1.0.0  2026/03/15
*! Summary tables for doubly robust estimation
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  drest_report [, excel(filename) replace detail]

Requires: drest_estimate has been run

See help drest_report for complete documentation
*/

program define drest_report, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    syntax [, EXcel(string) replace Detail]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================
    _drest_check_estimated
    _drest_get_settings

    local outcome    "`_drest_outcome'"
    local treatment  "`_drest_treatment'"
    local omodel     "`_drest_omodel'"
    local ofamily    "`_drest_ofamily'"
    local tmodel     "`_drest_tmodel'"
    local tfamily    "`_drest_tfamily'"
    local estimand   "`_drest_estimand'"
    local tau        "`_drest_ate'"
    local se         "`_drest_ate_se'"
    local level      "`_drest_level'"
    local N          "`_drest_N'"
    local n_trimmed  "`_drest_n_trimmed'"
    local po1        "`_drest_po1'"
    local po0        "`_drest_po0'"
    local trim_lo    "`_drest_trimps_lo'"
    local trim_hi    "`_drest_trimps_hi'"

    capture confirm variable _drest_esample
    if _rc {
        set varabbrev `_vaset'
        display as error "_drest_esample not found; re-run drest_estimate"
        exit 111
    }

    local z = invnormal(1 - (100 - `level') / 200)
    local ci_lo = `tau' - `z' * `se'
    local ci_hi = `tau' + `z' * `se'
    local pvalue = 2 * normal(-abs(`tau' / `se'))

    * =========================================================================
    * DISPLAY TABLE
    * =========================================================================
    _drest_display_header "drest_report" "AIPW Summary Report"

    display as text "{bf:Model Specification}"
    display as text "{hline 50}"
    display as text "Outcome variable:   " as result "`outcome'"
    display as text "Treatment variable: " as result "`treatment'"
    display as text "Estimand:           " as result "`estimand'"
    display as text "Outcome model:      " as result "`ofamily' (`omodel')"
    display as text "Treatment model:    " as result "`tfamily' (`tmodel')"
    display as text "PS trimming:        " as result "[`trim_lo', `trim_hi']"
    display as text ""

    display as text "{bf:Sample}"
    display as text "{hline 50}"
    display as text "Total observations: " as result %10.0fc `N'
    quietly count if _drest_esample == 1 & `treatment' == 1
    display as text "Treated:            " as result %10.0fc r(N)
    quietly count if _drest_esample == 1 & `treatment' == 0
    display as text "Control:            " as result %10.0fc r(N)
    if `n_trimmed' > 0 {
        display as text "PS trimmed:         " as result %10.0fc `n_trimmed'
    }
    display as text ""

    display as text "{bf:Results}"
    display as text "{hline 50}"
    display as text "`estimand':               " as result %12.4f `tau'
    display as text "Standard error:       " as result %12.4f `se'
    display as text "z-statistic:          " as result %12.2f (`tau' / `se')
    display as text "P-value:              " as result %12.4f `pvalue'
    display as text "`level'% CI:              [" as result %8.4f `ci_lo' ///
        as text ", " as result %8.4f `ci_hi' as text "]"
    display as text ""
    display as text "PO mean (treated):   " as result %12.4f `po1'
    display as text "PO mean (control):   " as result %12.4f `po0'
    display as text "{hline 50}"

    if "`detail'" != "" {
        display as text ""
        display as text "{bf:Propensity Score Summary}"
        display as text "{hline 50}"
        quietly summarize _drest_ps if _drest_esample == 1
        display as text "Mean:   " as result %8.4f r(mean) ///
            as text "  SD: " as result %8.4f r(sd)
        display as text "Range:  [" as result %6.4f r(min) ///
            as text ", " as result %6.4f r(max) as text "]"

        display as text ""
        display as text "{bf:Influence Function Summary}"
        display as text "{hline 50}"
        quietly summarize _drest_if if _drest_esample == 1, detail
        display as text "Mean:   " as result %12.6f r(mean) ///
            as text "  SD: " as result %12.6f r(sd)
        display as text "Skewness: " as result %8.3f r(skewness) ///
            as text "  Kurtosis: " as result %8.3f r(kurtosis)
    }

    * =========================================================================
    * EXCEL EXPORT
    * =========================================================================
    if "`excel'" != "" {
        if "`replace'" == "" {
            capture confirm file "`excel'"
            if _rc == 0 {
                set varabbrev `_vaset'
                display as error "file `excel' already exists; use replace option"
                exit 602
            }
        }

        quietly {
            preserve
            clear
            set obs 1

            gen str20 estimand = "`estimand'"
            gen str20 outcome = "`outcome'"
            gen str20 treatment = "`treatment'"
            gen str20 method = "AIPW"
            gen double estimate = `tau'
            gen double std_err = `se'
            gen double ci_lower = `ci_lo'
            gen double ci_upper = `ci_hi'
            gen double p_value = `pvalue'
            gen double po_treated = `po1'
            gen double po_control = `po0'
            gen long n_obs = `N'

            export excel using "`excel'", firstrow(variables) replace
            restore
        }

        display as text ""
        display as text "Results exported to: " as result "`excel'"
    }

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================
    return scalar N = `N'
    return scalar tau = `tau'
    return scalar se = `se'
    return scalar ci_lo = `ci_lo'
    return scalar ci_hi = `ci_hi'
    return scalar p = `pvalue'
    return scalar po1 = `po1'
    return scalar po0 = `po0'

    return local estimand "`estimand'"
    return local outcome "`outcome'"
    return local treatment "`treatment'"
    return local method "aipw"

    set varabbrev `_vaset'
end
