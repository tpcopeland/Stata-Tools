*! tte_report Version 1.1.1  2026/03/14
*! Publication-quality results tables for target trial emulation
*! Author: Timothy P Copeland
*! Author: Tania F Reza
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Department of Global Public Health, Karolinska Institutet
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
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    syntax [, FORmat(string) EXPort(string) DECimals(integer 3) ///
        EFORM CI_separator(string) TItle(string) REPLACE ///
        PREDictions(name)]

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

    * Resolve weight variable (custom name, then default)
    local weight_var ""
    local _wvar_meta : char _dta[_tte_weight_var]
    if "`_wvar_meta'" != "" {
        capture confirm variable `_wvar_meta'
        if _rc == 0 {
            local weight_var "`_wvar_meta'"
        }
    }
    if "`weight_var'" == "" {
        capture confirm variable `prefix'weight
        if _rc == 0 {
            local weight_var "`prefix'weight"
        }
    }

    if "`weight_var'" != "" {
        display as text ""
        display as text "{bf:IP Weight Summary}"
        display as text ""

        quietly summarize `weight_var', detail

        local fmt "%10.`decimals'f"

        display as text "  Mean (SD):    " as result `fmt' r(mean) as text " (" as result `fmt' r(sd) as text ")"
        display as text "  Median:       " as result `fmt' r(p50)
        display as text "  Range:        " as result `fmt' r(min) as text " - " as result `fmt' r(max)
        display as text "  IQR:          " as result `fmt' r(p25) as text " - " as result `fmt' r(p75)

        * ESS
        quietly {
            summarize `weight_var'
            local sum_w = r(sum)
            tempvar _w2
            gen double `_w2' = `weight_var'^2
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
        * Verify e() results are from tte_fit
        if "`e(tte_cmd)'" != "tte_fit" {
            display as text ""
            display as text "{bf:Warning:} e() results are not from tte_fit."
            display as text "Re-run {cmd:tte_fit} before {cmd:tte_report} for coefficient table."
            local fitted ""
        }
    }

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

        local fmt "%10.`decimals'f"

        * Export summary to Excel
        quietly {
            putexcel set "`export'", sheet("Summary") `replace'
            putexcel A1 = "`title'"
            putexcel A3 = "Parameter" B3 = "Value"
            putexcel A4 = "Estimand" B4 = "`estimand'"
            putexcel A5 = "Total person-periods" B5 = `n_obs'
            putexcel A6 = "Treatment arm" B6 = `n_treat'
            putexcel A7 = "Control arm" B7 = `n_control'
            putexcel A8 = "Events" B8 = `n_events'
            putexcel A9 = "Trials" B9 = `n_trials'
        }

        display as text "  Summary exported to sheet: Summary"

        * Export coefficients if fitted
        local coef_last_row = 1
        if "`fitted'" == "1" {
            quietly {
                putexcel set "`export'", sheet("Coefficients") modify
                putexcel A1 = "Variable" B1 = "`effect_label'" C1 = "`ci_level'% CI Lower" D1 = "`ci_level'% CI Upper" E1 = "P-value"

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

                    * Use string() with format for clean values
                    local est_s = string(`est', "`fmt'")
                    local ci_lo_s = string(`ci_lo', "`fmt'")
                    local ci_hi_s = string(`ci_hi', "`fmt'")
                    local p_s = string(`p', "%8.`decimals'f")

                    putexcel A`row' = "`cname'" B`row' = "`est_s'" C`row' = "`ci_lo_s'" D`row' = "`ci_hi_s'" E`row' = "`p_s'"
                    local ++row
                }
                local coef_last_row = `row' - 1
            }
            display as text "  Coefficients exported to sheet: Coefficients"
        }

        * Export predictions if provided
        if "`predictions'" != "" {
            capture confirm matrix `predictions'
            if _rc == 0 {
                quietly {
                    local pred_rows = rowsof(`predictions')
                    local pred_cols = colsof(`predictions')
                    local pred_colnames: colnames `predictions'

                    putexcel set "`export'", sheet("Predictions") modify

                    * Write header with human-readable labels
                    local pcol = 1
                    foreach pname of local pred_colnames {
                        _tte_col_letter `pcol'
                        local pletter "`result'"
                        local plabel "`pname'"
                        if "`pname'" == "time"    local plabel "Follow-up Time"
                        if "`pname'" == "est_0"   local plabel "Control"
                        if "`pname'" == "ci_lo_0" local plabel "Control CI Lower"
                        if "`pname'" == "ci_hi_0" local plabel "Control CI Upper"
                        if "`pname'" == "est_1"   local plabel "Treatment"
                        if "`pname'" == "ci_lo_1" local plabel "Treatment CI Lower"
                        if "`pname'" == "ci_hi_1" local plabel "Treatment CI Upper"
                        if "`pname'" == "diff"    local plabel "Difference"
                        if "`pname'" == "diff_lo" local plabel "Difference CI Lower"
                        if "`pname'" == "diff_hi" local plabel "Difference CI Upper"
                        if "`pname'" == "rr"      local plabel "Risk Ratio"
                        if "`pname'" == "rr_lo"   local plabel "RR CI Lower"
                        if "`pname'" == "rr_hi"   local plabel "RR CI Upper"
                        putexcel `pletter'1 = "`plabel'"
                        local ++pcol
                    }

                    * Write data rows using format
                    forvalues pr = 1/`pred_rows' {
                        local excel_row = `pr' + 1
                        forvalues pc = 1/`pred_cols' {
                            _tte_col_letter `pc'
                            local pletter "`result'"
                            local val = `predictions'[`pr', `pc']
                            local val_s = string(`val', "`fmt'")
                            putexcel `pletter'`excel_row' = "`val_s'"
                        }
                    }
                }
                display as text "  Predictions exported to sheet: Predictions"
            }
        }

        * Apply formatting (non-fatal, each sheet independent)
        capture {
            mata: b = xl()
            mata: b.load_book("`export'")
            mata: b.set_sheet("Summary")
            mata: b.set_column_width(1, 1, 25)
            mata: b.set_column_width(2, 2, 20)
            mata: b.close_book()
        }
        if _rc {
            local saved_rc = _rc
            capture mata: b.close_book()
            capture mata: mata drop b
            noisily display as error ///
                "Excel formatting (Mata) failed with error `saved_rc'"
        }
        capture mata: mata drop b

        capture {
            putexcel set "`export'", sheet("Summary") modify
            putexcel (A1:B1), merge bold
            putexcel (A3:B3), bold hcenter
            putexcel (A3:B3), border(top, thin)
            putexcel (A3:B3), border(bottom, thin)
            putexcel (A9:B9), border(bottom, thin)
            putexcel (A1:B9), font(Arial, 10)
            putexcel clear
        }
        if _rc {
            local saved_rc = _rc
            capture putexcel clear
            noisily display as error ///
                "Excel cell formatting failed with error `saved_rc'"
        }

        if "`fitted'" == "1" {
            capture {
                mata: b = xl()
                mata: b.load_book("`export'")
                mata: b.set_sheet("Coefficients")
                mata: b.set_column_width(1, 1, 22)
                mata: b.set_column_width(2, 5, 14)
                mata: b.close_book()
            }
            if _rc {
                local saved_rc = _rc
                capture mata: b.close_book()
                capture mata: mata drop b
                noisily display as error ///
                    "Excel formatting (Mata) failed with error `saved_rc'"
            }
            capture mata: mata drop b

            capture {
                putexcel set "`export'", sheet("Coefficients") modify
                putexcel (A1:E1), bold hcenter
                putexcel (A1:E1), border(top, thin)
                putexcel (A1:E1), border(bottom, thin)
                putexcel (A`coef_last_row':E`coef_last_row'), border(bottom, thin)
                putexcel (A1:E`coef_last_row'), font(Arial, 10)
                putexcel clear
            }
            if _rc {
                local saved_rc = _rc
                capture putexcel clear
                noisily display as error ///
                    "Excel cell formatting failed with error `saved_rc'"
            }
        }

        if "`predictions'" != "" {
            local has_pred_mat = 0
            capture confirm matrix `predictions'
            if _rc == 0 local has_pred_mat = 1
            if `has_pred_mat' {
                local pred_last_row = `pred_rows' + 1
                _tte_col_letter `pred_cols'
                local pred_last_col "`result'"

                capture {
                    mata: b = xl()
                    mata: b.load_book("`export'")
                    mata: b.set_sheet("Predictions")
                    mata: b.set_column_width(1, `pred_cols', 16)
                    mata: b.close_book()
                }
                if _rc {
                    local saved_rc = _rc
                    capture mata: b.close_book()
                    capture mata: mata drop b
                    noisily display as error ///
                        "Excel formatting (Mata) failed with error `saved_rc'"
                }
                capture mata: mata drop b

                capture {
                    putexcel set "`export'", sheet("Predictions") modify
                    putexcel (A1:`pred_last_col'1), bold hcenter
                    putexcel (A1:`pred_last_col'1), border(top, thin)
                    putexcel (A1:`pred_last_col'1), border(bottom, thin)
                    putexcel (A`pred_last_row':`pred_last_col'`pred_last_row'), border(bottom, thin)
                    putexcel (A1:`pred_last_col'`pred_last_row'), font(Arial, 10)
                    putexcel clear
                }
                if _rc {
                    local saved_rc = _rc
                    capture putexcel clear
                    noisily display as error ///
                        "Excel cell formatting failed with error `saved_rc'"
                }
            }
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

    set varabbrev `_vaset'
end
