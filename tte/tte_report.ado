*! tte_report Version 1.0.2  2026/02/28
*! Publication-quality results tables for target trial emulation
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tte_report [, format(string) export(filename) decimals(#)
      eform ci_separator(string) title(string) replace]

Description:
  Generates formatted results tables suitable for manuscripts.
  Summarizes the outcome model, weight diagnostics, and predictions.

Options:
  format(string)       - display (default) | csv | excel
  export(filename)     - Export file path
  decimals(#)          - Decimal places (default: 3)
  eform                - Exponentiate coefficients (OR/HR)
  ci_separator(string) - CI separator (default: " to ")
  title(string)        - Table title
  replace              - Replace existing file

See help tte_report for complete documentation
*/

program define tte_report, rclass
    version 16.0
    set varabbrev off
    set more off

    syntax [, FORmat(string) EXPort(string) DECimals(integer 3) ///
        EFORM CI_separator(string) TItle(string) REPLACE]

    * =========================================================================
    * DEFAULTS
    * =========================================================================

    if "`format'" == "" local format "display"
    if "`ci_separator'" == "" local ci_separator " to "
    if "`title'" == "" local title "Target Trial Emulation Results"

    if !inlist("`format'", "display", "csv", "excel") {
        display as error "format() must be display, csv, or excel"
        exit 198
    }

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================

    _tte_check_expanded
    _tte_get_settings

    local prefix   "`_tte_prefix'"
    local estimand "`_tte_estimand'"

    * Check for fitted model
    local fitted : char _dta[_tte_fitted]
    local model  : char _dta[_tte_model]

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as result "`title'"
    display as text "{hline 70}"
    display as text ""

    * =========================================================================
    * TABLE 1: Analysis Summary
    * =========================================================================

    display as text "{bf:Analysis Summary}"
    display as text ""

    quietly count
    local n_obs = r(N)
    quietly count if `prefix'arm == 1
    local n_treat = r(N)
    quietly count if `prefix'arm == 0
    local n_control = r(N)
    quietly count if `prefix'outcome_obs == 1
    local n_events = r(N)

    quietly levelsof `prefix'trial, local(trials)
    local n_trials: word count `trials'

    display as text "  Estimand:           " as result "`estimand'"
    display as text "  Total person-periods: " as result %10.0fc `n_obs'
    display as text "  Treatment arm:      " as result %10.0fc `n_treat'
    display as text "  Control arm:        " as result %10.0fc `n_control'
    display as text "  Outcome events:     " as result %10.0fc `n_events'
    display as text "  Emulated trials:    " as result `n_trials'

    * =========================================================================
    * TABLE 2: Weight Summary (if available)
    * =========================================================================

    capture confirm variable `prefix'weight
    if _rc == 0 {
        display as text ""
        display as text "{bf:IP Weight Summary}"
        display as text ""

        quietly summarize `prefix'weight, detail

        local fmt "%10.`decimals'f"

        display as text "  Mean (SD):    " as result `fmt' r(mean) as text " (" as result `fmt' r(sd) as text ")"
        display as text "  Median:       " as result `fmt' r(p50)
        display as text "  Range:        " as result `fmt' r(min) as text " - " as result `fmt' r(max)
        display as text "  IQR:          " as result `fmt' r(p25) as text " - " as result `fmt' r(p75)

        * ESS
        quietly {
            summarize `prefix'weight
            local sum_w = r(sum)
            tempvar _w2
            gen double `_w2' = `prefix'weight^2
            summarize `_w2'
            local sum_w2 = r(sum)
            drop `_w2'
        }
        local ess = (`sum_w'^2) / `sum_w2'
        display as text "  ESS:          " as result %10.1f `ess'
    }

    * =========================================================================
    * TABLE 3: Outcome Model (if fitted)
    * =========================================================================

    if "`fitted'" == "1" {
        display as text ""
        display as text "{bf:Outcome Model Coefficients}"
        display as text ""

        local model_var : char _dta[_tte_model_var]

        if "`model'" == "logistic" {
            local effect_label = cond("`eform'" != "", "OR", "Log-odds")
        }
        else {
            local effect_label = cond("`eform'" != "", "HR", "Log-HR")
        }

        * Get confidence level from model (default 95)
        local ci_level = e(level)
        if "`ci_level'" == "" local ci_level 95
        local z_crit = invnormal((100 + `ci_level') / 200)

        * Get coefficient names and values
        tempname b_coef V_coef
        matrix `b_coef' = e(b)
        matrix `V_coef' = e(V)
        local coef_names: colnames `b_coef'
        local n_coefs: word count `coef_names'

        display as text %20s "Variable" "  " %10s "`effect_label'" "  " ///
            %20s "`ci_level'% CI" "  " %8s "p-value"
        display as text _dup(64) "-"

        forvalues i = 1/`n_coefs' {
            local cname: word `i' of `coef_names'
            if "`cname'" == "_cons" continue

            local b = `b_coef'[1, `i']
            local se = sqrt(`V_coef'[`i', `i'])
            local z = `b' / `se'
            local p = 2 * normal(-abs(`z'))

            if "`eform'" != "" {
                local est = exp(`b')
                local ci_lo = exp(`b' - `z_crit' * `se')
                local ci_hi = exp(`b' + `z_crit' * `se')
            }
            else {
                local est = `b'
                local ci_lo = `b' - `z_crit' * `se'
                local ci_hi = `b' + `z_crit' * `se'
            }

            local fmt "%10.`decimals'f"
            local ci_str: display `fmt' `ci_lo' "`ci_separator'" `fmt' `ci_hi'

            display as text %20s "`cname'" "  " ///
                as result `fmt' `est' "  " ///
                as text %20s "`ci_str'" "  " ///
                as result %8.4f `p'
        }
    }

    * =========================================================================
    * EXPORT
    * =========================================================================

    if "`export'" != "" & "`format'" == "excel" {
        display as text ""
        display as text "Exporting to: " as result "`export'"

        * Export summary to Excel
        quietly {
            putexcel set "`export'", sheet("Summary") `replace'
            putexcel A1 = "`title'"
            putexcel A3 = "Estimand" B3 = "`estimand'"
            putexcel A4 = "Total person-periods" B4 = `n_obs'
            putexcel A5 = "Treatment arm" B5 = `n_treat'
            putexcel A6 = "Control arm" B6 = `n_control'
            putexcel A7 = "Events" B7 = `n_events'
            putexcel A8 = "Trials" B8 = `n_trials'
        }

        display as text "  Summary exported to sheet: Summary"

        * Export coefficients if fitted
        if "`fitted'" == "1" {
            quietly {
                putexcel set "`export'", sheet("Coefficients") modify
                putexcel A1 = "Variable" B1 = "`effect_label'" C1 = "CI Lower" D1 = "CI Upper" E1 = "p-value"

                local row = 2
                forvalues i = 1/`n_coefs' {
                    local cname: word `i' of `coef_names'
                    if "`cname'" == "_cons" continue

                    local b = `b_coef'[1, `i']
                    local se = sqrt(`V_coef'[`i', `i'])
                    local p = 2 * normal(-abs(`b'/`se'))

                    if "`eform'" != "" {
                        local est = exp(`b')
                        local ci_lo = exp(`b' - `z_crit' * `se')
                        local ci_hi = exp(`b' + `z_crit' * `se')
                    }
                    else {
                        local est = `b'
                        local ci_lo = `b' - `z_crit' * `se'
                        local ci_hi = `b' + `z_crit' * `se'
                    }

                    putexcel A`row' = "`cname'" B`row' = `est' C`row' = `ci_lo' D`row' = `ci_hi' E`row' = `p'
                    local ++row
                }
            }
            display as text "  Coefficients exported to sheet: Coefficients"
        }
    }
    else if "`export'" != "" & "`format'" == "csv" {
        * CSV export
        tempname fh
        file open `fh' using "`export'", write `replace'
        file write `fh' "`title'" _n
        file write `fh' "Estimand,`estimand'" _n
        file write `fh' "Total person-periods,`n_obs'" _n
        file write `fh' "Treatment arm,`n_treat'" _n
        file write `fh' "Control arm,`n_control'" _n
        file write `fh' "Events,`n_events'" _n
        file write `fh' "Trials,`n_trials'" _n
        file close `fh'
        display as text "Results exported to: " as result "`export'"
    }

    display as text ""
    display as text "{hline 70}"

    return local format "`format'"
    return local estimand "`estimand'"
    return scalar n_obs = `n_obs'
    return scalar n_events = `n_events'
    return scalar n_trials = `n_trials'
end
