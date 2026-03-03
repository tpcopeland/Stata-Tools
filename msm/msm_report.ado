*! msm_report Version 1.0.0  2026/03/03
*! Publication-quality results tables for MSM
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  msm_report [, options]

Description:
  Generates publication tables summarizing the MSM analysis:
  analysis summary, weight summary, balance table, model coefficients.

Options:
  export(string)     - File path for export
  format(string)     - display (default) | csv | excel
  decimals(integer)  - Decimal places (default: 4)
  eform              - Exponentiated coefficients (OR/HR)
  replace            - Replace existing export file

See help msm_report for complete documentation
*/

program define msm_report, rclass
    version 16.0
    set varabbrev off
    set more off

    syntax [, EXPort(string) FORmat(string) DECimals(integer 4) ///
        EFORM REPLACE]

    _msm_check_prepared
    _msm_get_settings

    local id         "`_msm_id'"
    local period     "`_msm_period'"
    local treatment  "`_msm_treatment'"
    local outcome    "`_msm_outcome'"
    local censor     "`_msm_censor'"

    if "`format'" == "" local format "display"
    if !inlist("`format'", "display", "csv", "excel") {
        display as error "format() must be display, csv, or excel"
        exit 198
    }

    * =========================================================================
    * GATHER INFORMATION
    * =========================================================================

    * Data summary
    quietly count
    local N = r(N)

    tempvar _id_tag
    quietly bysort `id': gen byte `_id_tag' = (_n == 1)
    quietly count if `_id_tag'
    local n_ids = r(N)
    drop `_id_tag'

    quietly count if `outcome' == 1
    local n_events = r(N)

    quietly count if `treatment' == 1
    local n_treated = r(N)

    local n_censored = 0
    if "`censor'" != "" {
        quietly count if `censor' == 1
        local n_censored = r(N)
    }

    quietly summarize `period'
    local min_per = r(min)
    local max_per = r(max)

    * Weight info
    local has_weights = 0
    capture confirm variable _msm_weight
    if _rc == 0 {
        local has_weights = 1
        quietly summarize _msm_weight, detail
        local w_mean = r(mean)
        local w_sd = r(sd)
        local w_min = r(min)
        local w_max = r(max)
        local w_p50 = r(p50)

        quietly {
            summarize _msm_weight
            local sum_w = r(sum)
            tempvar _w2
            gen double `_w2' = _msm_weight^2
            summarize `_w2'
            local sum_w2 = r(sum)
            drop `_w2'
        }
        local ess = (`sum_w'^2) / `sum_w2'
    }

    * Model info
    local has_model = 0
    local model : char _dta[_msm_model]
    if "`model'" != "" {
        local has_model = 1
        local period_spec : char _dta[_msm_period_spec]
        local outcome_cov : char _dta[_msm_outcome_cov]
    }

    * =========================================================================
    * DISPLAY FORMAT
    * =========================================================================

    if "`format'" == "display" {
        display as text ""
        display as text "{hline 70}"
        display as result "msm_report" as text " - Analysis Summary"
        display as text "{hline 70}"

        * Section 1: Data summary
        display as text ""
        display as text "{bf:Data Summary}"
        display as text "  Person-periods:     " as result %10.0fc `N'
        display as text "  Individuals:        " as result %10.0fc `n_ids'
        display as text "  Period range:       " as result "`min_per' - `max_per'"
        display as text "  Outcome events:     " as result %10.0fc `n_events'
        display as text "  Treated obs:        " as result %10.0fc `n_treated'
        if `n_censored' > 0 {
            display as text "  Censored obs:       " as result %10.0fc `n_censored'
        }

        * Section 2: Weights
        if `has_weights' {
            display as text ""
            display as text "{bf:IP Weight Summary}"
            display as text "  Mean:     " as result %9.`decimals'f `w_mean'
            display as text "  SD:       " as result %9.`decimals'f `w_sd'
            display as text "  Range:    " as result %9.`decimals'f `w_min' ///
                as text " - " as result %9.`decimals'f `w_max'
            display as text "  Median:   " as result %9.`decimals'f `w_p50'
            display as text "  ESS:      " as result %9.1f `ess'
        }

        * Section 3: Model coefficients
        if `has_model' {
            display as text ""
            display as text "{bf:Outcome Model (`model')}"
            display as text "  Period spec:        " as result "`period_spec'"
            if "`outcome_cov'" != "" {
                display as text "  Covariates:         " as result "`outcome_cov'"
            }
            display as text ""

            * Coefficient table
            local coef_names: colnames e(b)
            local n_coefs: word count `coef_names'

            if "`eform'" != "" {
                local transform_label = cond("`model'" == "cox", "HR", "OR")
                display as text %20s "Variable" "  " ///
                    %10s "`transform_label'" "  " ///
                    %10s "CI low" "  " %10s "CI high" "  " %8s "p-value"
            }
            else {
                display as text %20s "Variable" "  " ///
                    %10s "Coef" "  " %10s "SE" "  " %8s "p-value"
            }
            display as text _dup(60) "-"

            forvalues i = 1/`n_coefs' {
                local cname: word `i' of `coef_names'
                local b = _b[`cname']
                local se = _se[`cname']
                local z = `b' / `se'
                local p = 2 * normal(-abs(`z'))

                local abbrev_name = abbrev("`cname'", 20)

                if "`eform'" != "" {
                    local ef = exp(`b')
                    local ef_lo = exp(`b' - 1.96 * `se')
                    local ef_hi = exp(`b' + 1.96 * `se')
                    display as text %20s "`abbrev_name'" "  " ///
                        as result %10.`decimals'f `ef' "  " ///
                        %10.`decimals'f `ef_lo' "  " ///
                        %10.`decimals'f `ef_hi' "  " ///
                        %8.4f `p'
                }
                else {
                    display as text %20s "`abbrev_name'" "  " ///
                        as result %10.`decimals'f `b' "  " ///
                        %10.`decimals'f `se' "  " ///
                        %8.4f `p'
                }
            }
        }

        display as text ""
        display as text "{hline 70}"
    }

    * =========================================================================
    * CSV FORMAT
    * =========================================================================

    else if "`format'" == "csv" {
        if "`export'" == "" {
            display as error "export() required for csv format"
            exit 198
        }

        tempname fh
        file open `fh' using "`export'", write `replace'

        * Header
        file write `fh' "MSM Analysis Report" _n
        file write `fh' "" _n

        * Data summary
        file write `fh' "Data Summary" _n
        file write `fh' "Metric,Value" _n
        file write `fh' "Person-periods,`N'" _n
        file write `fh' "Individuals,`n_ids'" _n
        file write `fh' "Period range,`min_per' - `max_per'" _n
        file write `fh' "Outcome events,`n_events'" _n
        file write `fh' "Treated obs,`n_treated'" _n

        if `has_weights' {
            file write `fh' "" _n
            file write `fh' "IP Weight Summary" _n
            file write `fh' "Metric,Value" _n
            file write `fh' `"Mean,`=string(`w_mean', "%9.`decimals'f")'"' _n
            file write `fh' `"SD,`=string(`w_sd', "%9.`decimals'f")'"' _n
            file write `fh' `"Min,`=string(`w_min', "%9.`decimals'f")'"' _n
            file write `fh' `"Max,`=string(`w_max', "%9.`decimals'f")'"' _n
            file write `fh' `"ESS,`=string(`ess', "%9.1f")'"' _n
        }

        if `has_model' {
            file write `fh' "" _n
            file write `fh' "Model Coefficients" _n

            if "`eform'" != "" {
                local tf_label = cond("`model'" == "cox", "HR", "OR")
                file write `fh' "Variable,`tf_label',CI_low,CI_high,p-value" _n
            }
            else {
                file write `fh' "Variable,Coefficient,SE,p-value" _n
            }

            local coef_names: colnames e(b)
            local n_coefs: word count `coef_names'
            forvalues i = 1/`n_coefs' {
                local cname: word `i' of `coef_names'
                local b = _b[`cname']
                local se = _se[`cname']
                local p = 2 * normal(-abs(`b'/`se'))

                if "`eform'" != "" {
                    local ef = exp(`b')
                    local ef_lo = exp(`b' - 1.96 * `se')
                    local ef_hi = exp(`b' + 1.96 * `se')
                    file write `fh' "`cname'," ///
                        "`=string(`ef', "%9.`decimals'f")'," ///
                        "`=string(`ef_lo', "%9.`decimals'f")'," ///
                        "`=string(`ef_hi', "%9.`decimals'f")'," ///
                        "`=string(`p', "%8.4f")'" _n
                }
                else {
                    file write `fh' "`cname'," ///
                        "`=string(`b', "%9.`decimals'f")'," ///
                        "`=string(`se', "%9.`decimals'f")'," ///
                        "`=string(`p', "%8.4f")'" _n
                }
            }
        }

        file close `fh'
        display as text "Report exported to: " as result "`export'"
    }

    * =========================================================================
    * EXCEL FORMAT
    * =========================================================================

    else if "`format'" == "excel" {
        if "`export'" == "" {
            display as error "export() required for excel format"
            exit 198
        }

        local rep_opt ""
        if "`replace'" != "" local rep_opt "replace"

        * Sheet 1: Summary
        quietly {
            preserve
            clear
            set obs 8
            gen str40 metric = ""
            gen str40 value = ""

            replace metric = "Person-periods" in 1
            replace value = "`N'" in 1
            replace metric = "Individuals" in 2
            replace value = "`n_ids'" in 2
            replace metric = "Period range" in 3
            replace value = "`min_per' - `max_per'" in 3
            replace metric = "Outcome events" in 4
            replace value = "`n_events'" in 4
            replace metric = "Treated obs" in 5
            replace value = "`n_treated'" in 5

            local row = 6
            if `has_weights' {
                replace metric = "Weight mean" in `row'
                replace value = string(`w_mean', "%9.`decimals'f") in `row'
                local ++row
                replace metric = "Weight SD" in `row'
                replace value = string(`w_sd', "%9.`decimals'f") in `row'
                local ++row
                replace metric = "ESS" in `row'
                replace value = string(`ess', "%9.1f") in `row'
            }

            drop if metric == ""

            export excel using "`export'", sheet("Summary") ///
                firstrow(variables) `rep_opt'
            restore
        }

        * Sheet 2: Coefficients
        if `has_model' {
            quietly {
                local coef_names: colnames e(b)
                local n_coefs: word count `coef_names'

                preserve
                clear
                set obs `n_coefs'
                gen str40 variable = ""
                gen double coefficient = .
                gen double se = .
                gen double p_value = .

                if "`eform'" != "" {
                    gen double or_hr = .
                    gen double ci_low = .
                    gen double ci_high = .
                }

                forvalues i = 1/`n_coefs' {
                    local cname: word `i' of `coef_names'
                    replace variable = "`cname'" in `i'
                    replace coefficient = _b[`cname'] in `i'
                    replace se = _se[`cname'] in `i'
                    replace p_value = 2 * normal(-abs(_b[`cname']/_se[`cname'])) in `i'

                    if "`eform'" != "" {
                        replace or_hr = exp(_b[`cname']) in `i'
                        replace ci_low = exp(_b[`cname'] - 1.96 * _se[`cname']) in `i'
                        replace ci_high = exp(_b[`cname'] + 1.96 * _se[`cname']) in `i'
                    }
                }

                export excel using "`export'", sheet("Coefficients") ///
                    firstrow(variables) sheetmodify
                restore
            }
        }

        display as text "Report exported to: " as result "`export'"
    }

    return local format "`format'"
    if "`export'" != "" return local export "`export'"
end
