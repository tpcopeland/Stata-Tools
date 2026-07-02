*! msm_report Version 1.2.2  2026/07/02
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
  replace            - Replace report sheet(s) in existing workbook
  title(string)      - Title for Excel table (A1 row)
  font(string)       - Font name (default: Arial)
  fontsize(integer)  - Font size in points (default: 10)
  borderstyle(string)- Border style: thin, medium, or academic (default: thin)
  zebra              - Alternating row shading
  footnote(string)   - Merged footnote below table
  open               - Auto-open file after export

See help msm_report for complete documentation
*/

program define msm_report, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    local _restore_needed = 0
    set varabbrev off
    set more off

    capture noisily {

    syntax [, EXPort(string) FORmat(string) DECimals(integer 4) ///
        EFORM REPLACE TITle(string) Font(string) FONTSize(integer 10) ///
        BORDERstyle(string) ZEBRA FOOTnote(string) OPEN]

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

    if "`font'" == "" local font "Arial"
    if "`borderstyle'" == "" local borderstyle "thin"

    if !inlist("`borderstyle'", "thin", "medium", "academic") {
        display as error "borderstyle() must be thin, medium, or academic"
        exit 198
    }

    * Academic borderstyle uses medium for horizontal borders
    local _hborder = "`borderstyle'"
    if "`borderstyle'" == "academic" local _hborder "medium"

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
    local _weighted_flag : char _dta[_msm_weighted]
    capture confirm variable _msm_weight
    if _rc == 0 & "`_weighted_flag'" == "1" {
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
    local fit_level : char _dta[_msm_fit_level]
    if "`fit_level'" == "" local fit_level "95"
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

            * Use saved fit matrices instead of live e()
            tempname _rpt_b _rpt_V
            matrix `_rpt_b' = _msm_fit_b
            matrix `_rpt_V' = _msm_fit_V
            local coef_names: colnames `_rpt_b'
            local n_coefs: word count `coef_names'
            local _z_crit = invnormal((100 + `fit_level') / 200)

            if "`eform'" != "" {
                _msm_coef_scale_label, model("`model'") eform report
                local transform_label "`r(label)'"
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
                local b = `_rpt_b'[1, `i']
                local v_ii = `_rpt_V'[`i', `i']
                if `v_ii' <= 0 continue
                local se = sqrt(`v_ii')
                local z = `b' / `se'
                local p = 2 * normal(-abs(`z'))

                local abbrev_name = abbrev("`cname'", 20)

                if "`eform'" != "" {
                    local ef = exp(`b')
                    local ef_lo = exp(`b' - `_z_crit' * `se')
                    local ef_hi = exp(`b' + `_z_crit' * `se')
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
        local _fh_open = 0
        capture noisily {
            file open `fh' using "`export'", write `replace'
            local _fh_open = 1

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
                    _msm_coef_scale_label, model("`model'") eform report
                    local tf_label "`r(label)'"
                    file write `fh' "Variable,`tf_label',CI_low,CI_high,p-value" _n
                }
                else {
                    file write `fh' "Variable,Coefficient,SE,p-value" _n
                }

                tempname _csv_b _csv_V
                matrix `_csv_b' = _msm_fit_b
                matrix `_csv_V' = _msm_fit_V
                local coef_names: colnames `_csv_b'
                local n_coefs: word count `coef_names'
                local _z_crit = invnormal((100 + `fit_level') / 200)
                forvalues i = 1/`n_coefs' {
                    local cname: word `i' of `coef_names'
                    local b = `_csv_b'[1, `i']
                    local v_ii = `_csv_V'[`i', `i']
                    if `v_ii' <= 0 continue
                    local se = sqrt(`v_ii')
                    local p = 2 * normal(-abs(`b'/`se'))

                    if "`eform'" != "" {
                        local ef = exp(`b')
                        local ef_lo = exp(`b' - `_z_crit' * `se')
                        local ef_hi = exp(`b' + `_z_crit' * `se')
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
            local _fh_open = 0
        }
        if _rc {
            if `_fh_open' capture file close `fh'
            exit _rc
        }
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

        if !regexm("`export'", "\.xlsx$") {
            display as error "export() must specify a .xlsx file for excel format"
            exit 198
        }

        local rep_opt ""
        if "`replace'" != "" local rep_opt "sheetreplace"
        local coef_sheet_opt "sheetmodify"
        if "`replace'" != "" local coef_sheet_opt "sheetreplace"

        * Build title text
        local _title `"`title'"'
        if `"`_title'"' == "" local _title "MSM Analysis Summary"

        local _has_footnote = (`"`footnote'"' != "")

        * ---------------------------------------------------------------
        * Sheet 1: Summary
        * ---------------------------------------------------------------

        local _sum_rows = 5
        if `n_censored' > 0 local _sum_rows = 6
        if `has_weights' local _sum_rows = `_sum_rows' + 5
        local _sum_total = `_sum_rows' + 2
        local _sum_last_data = `_sum_total'
        local _sum_footnote_row = `_sum_total' + 1

        quietly {
            preserve
            local _restore_needed = 1
            clear
            set obs `_sum_total'

            gen str40 A = ""
            gen str40 B = ""

            * Row 1: title
            replace A = `"`_title'"' in 1

            * Row 2: headers
            replace A = "Metric" in 2
            replace B = "Value" in 2

            * Data rows
            replace A = "Person-periods" in 3
            replace B = "`N'" in 3
            replace A = "Individuals" in 4
            replace B = "`n_ids'" in 4
            replace A = "Period range" in 5
            replace B = "`min_per' - `max_per'" in 5
            replace A = "Outcome events" in 6
            replace B = "`n_events'" in 6

            local _r = 7
            if `n_censored' > 0 {
                replace A = "Treated obs" in 7
                replace B = "`n_treated'" in 7
                local _r = 8
                replace A = "Censored obs" in `_r'
                replace B = "`n_censored'" in `_r'
                local ++_r
            }
            else {
                replace A = "Treated obs" in 7
                replace B = "`n_treated'" in 7
                local _r = 8
            }

            if `has_weights' {
                replace A = "" in `_r'
                local ++_r
                replace A = "IP Weight Mean" in `_r'
                replace B = string(`w_mean', "%9.`decimals'f") in `_r'
                local ++_r
                replace A = "IP Weight SD" in `_r'
                replace B = string(`w_sd', "%9.`decimals'f") in `_r'
                local ++_r
                replace A = "IP Weight Range" in `_r'
                replace B = string(`w_min', "%9.`decimals'f") + ///
                    " - " + string(`w_max', "%9.`decimals'f") in `_r'
                local ++_r
                replace A = "ESS" in `_r'
                replace B = string(`ess', "%9.1f") in `_r'
            }

            drop if A == "" & B == ""

            local _sum_total = _N
            local _sum_last_data = `_sum_total'
            local _sum_footnote_row = `_sum_total' + 1

            export excel using "`export'", sheet("Summary") ///
                `rep_opt'

            * Mata: column widths + numeric conversion
            capture {
                mata: _msm_xl = xl()
                mata: _msm_xl.load_book("`export'")
                mata: _msm_xl.set_sheet("Summary")
                mata: _msm_xl.set_row_height(1, 1, 30)
                _msm_xlsx_colwidths, object(_msm_xl) widths(22 20)

                * Convert numeric values
                forvalues _r = 3/`_sum_total' {
                    local _cellstr = B[`_r']
                    if `"`_cellstr'"' == "" | `"`_cellstr'"' == "." continue
                    if strpos(`"`_cellstr'"', " - ") > 0 continue
                    local _cellclean = subinstr(`"`_cellstr'"', ",", "", .)
                    local _cellnum = real("`_cellclean'")
                    if `_cellnum' != . {
                        _msm_xlsx_put_number, object(_msm_xl) ///
                            row(`_r') col(2) value(`_cellnum')
                    }
                }

                mata: _msm_xl.close_book()
            }
            if _rc {
                capture mata: _msm_xl.close_book()
                capture mata: mata drop _msm_xl
            }
            capture mata: mata drop _msm_xl

            * Mata xl() formatting
            capture {
                mata: b = xl()
                mata: b.load_book("`export'")
                mata: b.set_sheet("Summary")

                mata: b.set_font((1,`_sum_total'), (1,2), "`font'", `fontsize')
                mata: b.set_sheet_merge("Summary", (1,1), (1,2))
                mata: b.set_text_wrap(1, 1, "on")
                mata: b.set_horizontal_align(1, 1, "left")
                mata: b.set_vertical_align(1, 1, "center")
                mata: b.set_font_bold(1, 1, "on")

                mata: b.set_font_bold(2, (1,2), "on")
                mata: b.set_horizontal_align(2, (1,2), "center")
                mata: b.set_vertical_align(2, (1,2), "center")
                mata: b.set_text_wrap(2, (1,2), "on")
                mata: b.set_fill_pattern(2, (1,2), "solid", "219 229 241")
                mata: b.set_top_border(2, (1,2), "`_hborder'")
                mata: b.set_bottom_border(2, (1,2), "`_hborder'")
                if "`borderstyle'" != "academic" {
                    mata: b.set_left_border((2,`_sum_total'), 1, "`borderstyle'")
                    mata: b.set_right_border((2,`_sum_total'), 2, "`borderstyle'")
                }
                mata: b.set_bottom_border(`_sum_total', (1,2), "`_hborder'")
                if `_sum_total' >= 3 {
                    mata: b.set_horizontal_align((3,`_sum_total'), 2, "center")
                }

                if "`zebra'" != "" {
                    _msm_xlsx_zebra, object(b) startrow(3) ///
                        lastrow(`_sum_last_data') ncols(2)
                }

                if `_has_footnote' {
                    local _fn_fontsize = max(`fontsize' - 2, 6)
                    _msm_xlsx_footnote, object(b) sheet("Summary") ///
                        row(`_sum_footnote_row') ncols(2) ///
                        footnote(`"`footnote'"') font("`font'") ///
                        fontsize(`_fn_fontsize')
                }

                mata: b.close_book()
            }
            if _rc {
                local saved_rc = _rc
                capture mata: b.close_book()
                capture mata: mata drop b
                restore
                local _restore_needed = 0
                exit `saved_rc'
            }
            capture mata: mata drop b

            restore
            local _restore_needed = 0
        }

        * ---------------------------------------------------------------
        * Sheet 2: Coefficients (if model available)
        * ---------------------------------------------------------------

        if `has_model' {
            quietly {
                tempname _xl_b _xl_V
                matrix `_xl_b' = _msm_fit_b
                matrix `_xl_V' = _msm_fit_V
                local coef_names: colnames `_xl_b'
                local n_coefs: word count `coef_names'
                local _z_crit = invnormal((100 + `fit_level') / 200)
                local _coef_xfmt "0"
                if `decimals' > 0 {
                    local _coef_xfmt "0."
                    forvalues _di = 1/`decimals' {
                        local _coef_xfmt "`_coef_xfmt'0"
                    }
                }

                preserve
                local _restore_needed = 1
                clear
                local _coef_total = `n_coefs' + 2
                set obs `_coef_total'

                if "`eform'" != "" {
                    _msm_coef_scale_label, model("`model'") eform report
                    local _eff_label "`r(label)'"
                    gen str40 A = ""
                    gen str20 B = ""
                    gen str30 C = ""
                    gen str12 D = ""

                    replace A = "Outcome Model (`model')" in 1
                    replace A = "Variable" in 2
                    replace B = "`_eff_label'" in 2
                    replace C = "`fit_level'% CI" in 2
                    replace D = "p-value" in 2

                    forvalues i = 1/`n_coefs' {
                        local _row = `i' + 2
                        local cname: word `i' of `coef_names'
                        local _b_i = `_xl_b'[1, `i']
                        local _v_ii = `_xl_V'[`i', `i']
                        _msm_coef_display_name, name("`cname'")
                        local _display_name `"`r(display_name)'"'
                        replace A = `"`_display_name'"' in `_row'
                        if `_v_ii' <= 0 {
                            replace B = "(omitted)" in `_row'
                            continue
                        }
                        local _se_i = sqrt(`_v_ii')
                        local _lo = `_b_i' - `_z_crit' * `_se_i'
                        local _hi = `_b_i' + `_z_crit' * `_se_i'
                        local _p = 2 * normal(-abs(`_b_i'/`_se_i'))
                        local _disp_b = exp(`_b_i')
                        replace B = strtrim(string(`_disp_b', "%9.`decimals'f")) in `_row'
                        local _ci_lo = strtrim(string(exp(`_lo'), "%9.`decimals'f"))
                        local _ci_hi = strtrim(string(exp(`_hi'), "%9.`decimals'f"))
                        replace C = "(" + "`_ci_lo'" + ", " + "`_ci_hi'" + ")" in `_row'

                        _msm_coef_pvalue_string, pvalue(`_p')
                        replace D = "`r(pvalue)'" in `_row'
                    }
                }
                else {
                    gen str40 A = ""
                    gen str20 B = ""
                    gen str20 C = ""
                    gen str12 D = ""

                    replace A = "Outcome Model (`model')" in 1
                    replace A = "Variable" in 2
                    _msm_coef_scale_label, model("`model'")
                    replace B = "`r(label)'" in 2
                    replace C = "SE" in 2
                    replace D = "p-value" in 2

                    forvalues i = 1/`n_coefs' {
                        local _row = `i' + 2
                        local cname: word `i' of `coef_names'
                        local _b_i = `_xl_b'[1, `i']
                        local _v_ii = `_xl_V'[`i', `i']
                        _msm_coef_display_name, name("`cname'")
                        local _display_name `"`r(display_name)'"'
                        replace A = `"`_display_name'"' in `_row'
                        if `_v_ii' <= 0 {
                            replace B = "(omitted)" in `_row'
                            continue
                        }
                        local _se_i = sqrt(`_v_ii')
                        local _p = 2 * normal(-abs(`_b_i'/`_se_i'))
                        replace B = strtrim(string(`_b_i', "%9.`decimals'f")) in `_row'
                        replace C = strtrim(string(`_se_i', "%9.`decimals'f")) in `_row'

                        _msm_coef_pvalue_string, pvalue(`_p')
                        replace D = "`r(pvalue)'" in `_row'
                    }
                }

                local _coef_last_data = `_coef_total'
                local _coef_footnote_row = `_coef_total' + 1

                export excel using "`export'", sheet("Coefficients") ///
                    `coef_sheet_opt'

                * Mata: column widths + numeric conversion
                capture {
                    mata: _msm_xl = xl()
                    mata: _msm_xl.load_book("`export'")
                    mata: _msm_xl.set_sheet("Coefficients")
                    mata: _msm_xl.set_row_height(1, 1, 30)
                    _msm_xlsx_colwidths, object(_msm_xl) ///
                        widths(22 14 20 12)

                    * Write coefficient estimates as proper Excel numerics
                    forvalues _i = 1/`n_coefs' {
                        local _r = `_i' + 2
                        local _v_ii = `_xl_V'[`_i', `_i']
                        if `_v_ii' <= 0 continue
                        local _coef_val = `_xl_b'[1, `_i']
                        if "`eform'" != "" local _coef_val = exp(`_coef_val')
                        _msm_xlsx_put_number, object(_msm_xl) row(`_r') ///
                            col(2) value(`_coef_val') nformat("`_coef_xfmt'")
                    }

                    mata: _msm_xl.close_book()
                }
                if _rc {
                    capture mata: _msm_xl.close_book()
                    capture mata: mata drop _msm_xl
                }
                capture mata: mata drop _msm_xl

                * Mata xl() formatting
                capture {
                    mata: b = xl()
                    mata: b.load_book("`export'")
                    mata: b.set_sheet("Coefficients")

                    mata: b.set_font((1,`_coef_total'), (1,4), "`font'", `fontsize')
                    mata: b.set_sheet_merge("Coefficients", (1,1), (1,4))
                    mata: b.set_text_wrap(1, 1, "on")
                    mata: b.set_horizontal_align(1, 1, "left")
                    mata: b.set_vertical_align(1, 1, "center")
                    mata: b.set_font_bold(1, 1, "on")

                    mata: b.set_font_bold(2, (1,4), "on")
                    mata: b.set_horizontal_align(2, (1,4), "center")
                    mata: b.set_vertical_align(2, (1,4), "center")
                    mata: b.set_text_wrap(2, (1,4), "on")
                    mata: b.set_fill_pattern(2, (1,4), "solid", "219 229 241")
                    mata: b.set_top_border(2, (1,4), "`_hborder'")
                    mata: b.set_bottom_border(2, (1,4), "`_hborder'")
                    if "`borderstyle'" != "academic" {
                        mata: b.set_left_border((2,`_coef_total'), 1, "`borderstyle'")
                        mata: b.set_right_border((2,`_coef_total'), 4, "`borderstyle'")
                        mata: b.set_left_border((2,`_coef_total'), 4, "`borderstyle'")
                    }
                    mata: b.set_bottom_border(`_coef_total', (1,4), "`_hborder'")
                    if `_coef_total' >= 3 {
                        mata: b.set_horizontal_align((3,`_coef_total'), (2,3), "center")
                        mata: b.set_horizontal_align((3,`_coef_total'), 4, "right")
                    }

                    if "`zebra'" != "" {
                        _msm_xlsx_zebra, object(b) startrow(3) ///
                            lastrow(`_coef_last_data') ncols(4)
                    }

                    if `_has_footnote' {
                        local _fn_fontsize = max(`fontsize' - 2, 6)
                        _msm_xlsx_footnote, object(b) ///
                            sheet("Coefficients") row(`_coef_footnote_row') ///
                            ncols(4) footnote(`"`footnote'"') font("`font'") ///
                            fontsize(`_fn_fontsize')
                    }

                    mata: b.close_book()
                }
                if _rc {
                    local saved_rc = _rc
                    capture mata: b.close_book()
                    capture mata: mata drop b
                    restore
                    local _restore_needed = 0
                    exit `saved_rc'
                }
                capture mata: mata drop b

                restore
                local _restore_needed = 0
            }
        }

        display as text "Report exported to: " as result "`export'"

        if "`open'" != "" {
            _msm_post_export_open, file(`"`export'"')
        }
    }

    return local format "`format'"
    if "`export'" != "" return local export "`export'"

    } /* end capture noisily */
    local _rc = _rc

    if `_restore_needed' {
        capture restore
    }

    set varabbrev `_varabbrev'
    set more `_more'

    if `_rc' exit `_rc'
end
