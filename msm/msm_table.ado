*! msm_table Version 1.0.0  2026/03/03
*! Publication-quality Excel tables for MSM pipeline results
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet

/*
Syntax:
  msm_table , xlsx(string) [table_options formatting_options]

Required:
  xlsx(string)         Excel output file (.xlsx extension)

Table selection (default: all available):
  coefficients         Model coefficients (requires msm_fit)
  predictions          Counterfactual outcomes (requires msm_predict)
  balance              Covariate balance (requires msm_diagnose)
  weights              Weight distribution (requires msm_diagnose)
  sensitivity          E-value analysis (requires msm_sensitivity)
  all                  All available tables on separate sheets

Formatting:
  eform                Exponentiated coefficients (OR/HR)
  decimals(#)          Decimal places (default: 3)
  sep(string)          CI delimiter (default: ", ")
  title(string)        Table title for cell A1
  replace              Replace existing file

See help msm_table for complete documentation
*/

* =========================================================================
* MAIN DISPATCHER
* =========================================================================

program define msm_table
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    set varabbrev off
    set more off

    syntax , XLSX(string) [COEFficients PREDictions BALance WEIGHTs ///
        SENSitivity ALL EForm DECimals(integer 3) SEP(string) ///
        TITle(string) REPLACE]

    * Defaults
    if "`sep'" == "" local sep ", "

    if `decimals' < 0 | `decimals' > 10 {
        display as error "decimals() must be between 0 and 10"
        exit 198
    }

    * Validate xlsx extension
    if !regexm("`xlsx'", "\.xlsx$") {
        display as error "xlsx() must specify a .xlsx file"
        exit 198
    }

    * Handle file existence
    if "`replace'" != "" {
        capture erase "`xlsx'"
    }
    else {
        capture confirm new file "`xlsx'"
        if _rc {
            display as error "file {bf:`xlsx'} already exists; use {bf:replace} option"
            exit 602
        }
    }

    * Determine which tables to produce
    local any_explicit = ("`coefficients'" != "") | ("`predictions'" != "") | ///
        ("`balance'" != "") | ("`weights'" != "") | ("`sensitivity'" != "")

    local auto = ("`all'" != "") | !`any_explicit'

    local do_coef = `auto' | ("`coefficients'" != "")
    local do_pred = `auto' | ("`predictions'" != "")
    local do_bal  = `auto' | ("`balance'" != "")
    local do_wt   = `auto' | ("`weights'" != "")
    local do_sens = `auto' | ("`sensitivity'" != "")

    * Check availability and count sheets
    local n_sheets = 0

    if `do_coef' {
        local has : char _dta[_msm_fitted]
        if "`has'" != "1" {
            if `auto' local do_coef = 0
            else {
                display as error "coefficients table requires msm_fit"
                exit 198
            }
        }
        else {
            capture matrix list e(b)
            if _rc {
                if `auto' local do_coef = 0
                else {
                    display as error "e(b) not found; re-run msm_fit"
                    exit 301
                }
            }
            else local ++n_sheets
        }
    }

    if `do_pred' {
        local has : char _dta[_msm_pred_saved]
        if "`has'" != "1" {
            if `auto' local do_pred = 0
            else {
                display as error "predictions table requires msm_predict"
                exit 198
            }
        }
        else {
            capture matrix list _msm_pred_matrix
            if _rc {
                if `auto' local do_pred = 0
                else {
                    display as error "predictions matrix not found; re-run msm_predict"
                    exit 111
                }
            }
            else local ++n_sheets
        }
    }

    if `do_bal' {
        local has : char _dta[_msm_bal_saved]
        if "`has'" != "1" {
            if `auto' local do_bal = 0
            else {
                display as error "balance table requires msm_diagnose"
                exit 198
            }
        }
        else {
            capture matrix list _msm_bal_matrix
            if _rc {
                if `auto' local do_bal = 0
                else {
                    display as error "balance matrix not found; re-run msm_diagnose"
                    exit 111
                }
            }
            else local ++n_sheets
        }
    }

    if `do_wt' {
        local has : char _dta[_msm_diag_saved]
        if "`has'" != "1" {
            if `auto' local do_wt = 0
            else {
                display as error "weights table requires msm_diagnose"
                exit 198
            }
        }
        else local ++n_sheets
    }

    if `do_sens' {
        local has : char _dta[_msm_sens_saved]
        if "`has'" != "1" {
            if `auto' local do_sens = 0
            else {
                display as error "sensitivity table requires msm_sensitivity"
                exit 198
            }
        }
        else local ++n_sheets
    }

    if `n_sheets' == 0 {
        display as error "no MSM results available for table export"
        exit 198
    }

    * Export tables
    if `do_coef' {
        _msm_tbl_coef, xlsx("`xlsx'") decimals(`decimals') ///
            sep("`sep'") title("`title'") `eform'
    }
    if `do_pred' {
        _msm_tbl_pred, xlsx("`xlsx'") decimals(`decimals') ///
            sep("`sep'") title("`title'")
    }
    if `do_bal' {
        _msm_tbl_bal, xlsx("`xlsx'") decimals(`decimals') ///
            title("`title'")
    }
    if `do_wt' {
        _msm_tbl_wt, xlsx("`xlsx'") decimals(`decimals') ///
            title("`title'")
    }
    if `do_sens' {
        _msm_tbl_sens, xlsx("`xlsx'") decimals(`decimals') ///
            title("`title'")
    }

    display as text ""
    display as result "`n_sheets'" as text " table(s) exported to " ///
        as result "`xlsx'"

    set varabbrev `_varabbrev'
    set more `_more'
end

* =========================================================================
* COEFFICIENTS SHEET
* =========================================================================

program define _msm_tbl_coef
    version 16.0
    set varabbrev off
    set more off

    syntax , xlsx(string) decimals(integer) sep(string) ///
        [title(string) eform]

    local sheet "Coefficients"
    local model : char _dta[_msm_model]
    local fmt "%9.`decimals'f"

    * Effect measure label
    if "`eform'" != "" {
        if "`model'" == "logistic"      local eff_label "OR"
        else if "`model'" == "cox"      local eff_label "HR"
        else                            local eff_label "exp(b)"
    }
    else {
        local eff_label "Coef."
    }

    * Get coefficients
    tempname b V
    matrix `b' = e(b)
    matrix `V' = e(V)
    local k = colsof(`b')
    local coef_names : colnames `b'

    * Total rows: title + header + k data rows
    local nrows = `k' + 2

    preserve
    quietly {
        clear
        set obs `nrows'

        gen str80 A = ""
        gen str20 B = ""
        gen str40 C = ""
        gen str20 D = ""

        * Row 1: title
        if "`title'" != "" {
            replace A = "`title'" in 1
        }
        else {
            replace A = "`sheet'" in 1
        }

        * Row 2: headers
        replace A = "Variable" in 2
        replace B = "`eff_label'" in 2
        replace C = "95% CI" in 2
        replace D = "p-value" in 2

        * Data rows
        forvalues i = 1/`k' {
            local row = `i' + 2
            local cname : word `i' of `coef_names'
            local coef = `b'[1, `i']
            local v_ii = `V'[`i', `i']

            replace A = "`cname'" in `row'

            * Skip omitted/base variables
            if `v_ii' <= 0 {
                replace B = "(omitted)" in `row'
                continue
            }

            local se = sqrt(`v_ii')
            local z = invnormal(0.975)
            local lo = `coef' - `z' * `se'
            local hi = `coef' + `z' * `se'
            local p = 2 * normal(-abs(`coef' / `se'))

            * Exponentiate if requested
            if "`eform'" != "" {
                local d_coef = exp(`coef')
                local d_lo = exp(`lo')
                local d_hi = exp(`hi')
            }
            else {
                local d_coef = `coef'
                local d_lo = `lo'
                local d_hi = `hi'
            }

            replace B = strtrim(string(`d_coef', "`fmt'")) in `row'

            local ci_lo_s = strtrim(string(`d_lo', "`fmt'"))
            local ci_hi_s = strtrim(string(`d_hi', "`fmt'"))
            replace C = "(" + "`ci_lo_s'" + "`sep'" + ///
                "`ci_hi_s'" + ")" in `row'

            * P-value formatting (tabtools recipe)
            local p_str ""
            if `p' < 0.001 {
                local p_str "<0.001"
            }
            else if `p' >= 0.995 {
                local p_str "0.99"
            }
            else if `p' < 0.05 {
                local p_str = strtrim(string(`p', "%5.3f"))
            }
            else {
                local p_str = strtrim(string(`p', "%4.2f"))
            }
            if substr("`p_str'", 1, 1) == "." {
                local p_str "0`p_str'"
            }
            replace D = "`p_str'" in `row'
        }

        export excel using "`xlsx'", sheet("`sheet'") sheetreplace
    }

    * Mata: column widths
    capture {
        mata: b = xl()
        mata: b.load_book("`xlsx'")
        mata: b.set_sheet("`sheet'")
        mata: b.set_row_height(1, 1, 30)
        mata: b.set_column_width(1, 1, 22)
        mata: b.set_column_width(2, 2, 12)
        mata: b.set_column_width(3, 3, 24)
        mata: b.set_column_width(4, 4, 12)
        mata: b.close_book()
    }
    if _rc {
        local saved_rc = _rc
        capture mata: b.close_book()
        capture mata: mata drop b
        noisily display as error "Excel formatting (Mata) failed with error `saved_rc'"
        restore
        exit `saved_rc'
    }
    capture mata: mata drop b

    * putexcel: formatting
    capture {
        putexcel set "`xlsx'", sheet("`sheet'") modify
        putexcel (A1:D1), merge txtwrap left top bold
        putexcel (A2:D2), bold hcenter vcenter
        putexcel (A2:D2), border(top, thin)
        putexcel (A2:D2), border(bottom, thin)
        putexcel (B3:D`nrows'), hcenter
        putexcel (A`nrows':D`nrows'), border(bottom, thin)
        putexcel (A1:D`nrows'), font(Arial, 10)
        putexcel clear
    }
    if _rc {
        local saved_rc = _rc
        capture putexcel clear
        noisily display as error "Excel cell formatting failed with error `saved_rc'"
        restore
        exit `saved_rc'
    }

    restore
    display as text "  Sheet: `sheet'"
end

* =========================================================================
* PREDICTIONS SHEET
* =========================================================================

program define _msm_tbl_pred
    version 16.0
    set varabbrev off
    set more off

    syntax , xlsx(string) decimals(integer) sep(string) ///
        [title(string)]

    local sheet "Predictions"
    local strategy : char _dta[_msm_pred_strategy]
    local pred_type : char _dta[_msm_pred_type]
    local level : char _dta[_msm_pred_level]
    local fmt "%9.`decimals'f"

    tempname M
    matrix `M' = _msm_pred_matrix
    local n_times = rowsof(`M')
    local n_mcols = colsof(`M')
    local has_diff = (`n_mcols' == 10)

    local type_label = cond("`pred_type'" == "cum_inc", ///
        "Cumulative Incidence", "Survival")

    * Determine number of table columns
    if "`strategy'" == "both" {
        local n_cols = cond(`has_diff', 7, 5)
    }
    else {
        local n_cols = 3
    }

    * Rows: title + group header + column header + data
    local hdr_rows = 3
    local data_start = 4
    local total_rows = `n_times' + `hdr_rows'

    preserve
    quietly {
        clear
        set obs `total_rows'

        gen str80 A = ""
        forvalues c = 1/`=`n_cols'-1' {
            gen str40 c`c' = ""
        }

        * Row 1: title
        if "`title'" != "" {
            replace A = "`title'" in 1
        }
        else {
            replace A = "`type_label' Predictions" in 1
        }

        * Row 2: group headers
        if "`strategy'" == "both" {
            replace c1 = "Never-Treat" in 2
            replace c3 = "Always-Treat" in 2
            if `has_diff' {
                replace c5 = "Risk Difference" in 2
            }
        }
        else {
            local strat_label = cond("`strategy'" == "always", ///
                "Always-Treat", "Never-Treat")
            replace c1 = "`strat_label'" in 2
        }

        * Row 3: column headers
        replace A = "Period" in 3
        if "`strategy'" == "both" {
            replace c1 = "Est." in 3
            replace c2 = "`level'% CI" in 3
            replace c3 = "Est." in 3
            replace c4 = "`level'% CI" in 3
            if `has_diff' {
                replace c5 = "RD" in 3
                replace c6 = "`level'% CI" in 3
            }
        }
        else {
            replace c1 = "Est." in 3
            replace c2 = "`level'% CI" in 3
        }

        * Data rows
        forvalues i = 1/`n_times' {
            local row = `i' + `hdr_rows'
            local t = `M'[`i', 1]
            replace A = strtrim(string(`t', "%9.0f")) in `row'

            if "`strategy'" == "both" {
                * Never-treat: matrix columns 2-4
                local est = `M'[`i', 2]
                local lo = `M'[`i', 3]
                local hi = `M'[`i', 4]
                local ci_lo_s = strtrim(string(`lo', "`fmt'"))
                local ci_hi_s = strtrim(string(`hi', "`fmt'"))
                replace c1 = strtrim(string(`est', "`fmt'")) in `row'
                replace c2 = "(" + "`ci_lo_s'" + "`sep'" + ///
                    "`ci_hi_s'" + ")" in `row'

                * Always-treat: matrix columns 5-7
                local est = `M'[`i', 5]
                local lo = `M'[`i', 6]
                local hi = `M'[`i', 7]
                local ci_lo_s = strtrim(string(`lo', "`fmt'"))
                local ci_hi_s = strtrim(string(`hi', "`fmt'"))
                replace c3 = strtrim(string(`est', "`fmt'")) in `row'
                replace c4 = "(" + "`ci_lo_s'" + "`sep'" + ///
                    "`ci_hi_s'" + ")" in `row'

                * Risk difference: matrix columns 8-10
                if `has_diff' {
                    local rd = `M'[`i', 8]
                    local lo = `M'[`i', 9]
                    local hi = `M'[`i', 10]
                    local ci_lo_s = strtrim(string(`lo', "`fmt'"))
                    local ci_hi_s = strtrim(string(`hi', "`fmt'"))
                    replace c5 = strtrim(string(`rd', "`fmt'")) in `row'
                    replace c6 = "(" + "`ci_lo_s'" + "`sep'" + ///
                        "`ci_hi_s'" + ")" in `row'
                }
            }
            else if "`strategy'" == "never" {
                local est = `M'[`i', 2]
                local lo = `M'[`i', 3]
                local hi = `M'[`i', 4]
                local ci_lo_s = strtrim(string(`lo', "`fmt'"))
                local ci_hi_s = strtrim(string(`hi', "`fmt'"))
                replace c1 = strtrim(string(`est', "`fmt'")) in `row'
                replace c2 = "(" + "`ci_lo_s'" + "`sep'" + ///
                    "`ci_hi_s'" + ")" in `row'
            }
            else {
                * always strategy: data in matrix columns 5-7
                local est = `M'[`i', 5]
                local lo = `M'[`i', 6]
                local hi = `M'[`i', 7]
                local ci_lo_s = strtrim(string(`lo', "`fmt'"))
                local ci_hi_s = strtrim(string(`hi', "`fmt'"))
                replace c1 = strtrim(string(`est', "`fmt'")) in `row'
                replace c2 = "(" + "`ci_lo_s'" + "`sep'" + ///
                    "`ci_hi_s'" + ")" in `row'
            }
        }

        export excel using "`xlsx'", sheet("`sheet'") sheetreplace
    }

    * Mata: column widths
    _msm_col_letter `n_cols'
    local last_col "`result'"

    capture {
        mata: b = xl()
        mata: b.load_book("`xlsx'")
        mata: b.set_sheet("`sheet'")
        mata: b.set_row_height(1, 1, 30)
        mata: b.set_column_width(1, 1, 10)
        forvalues c = 2/`n_cols' {
            if mod(`c', 2) == 0 {
                mata: b.set_column_width(`c', `c', 12)
            }
            else {
                mata: b.set_column_width(`c', `c', 24)
            }
        }
        mata: b.close_book()
    }
    if _rc {
        local saved_rc = _rc
        capture mata: b.close_book()
        capture mata: mata drop b
        noisily display as error "Excel formatting (Mata) failed with error `saved_rc'"
        restore
        exit `saved_rc'
    }
    capture mata: mata drop b

    * putexcel: formatting
    capture {
        putexcel set "`xlsx'", sheet("`sheet'") modify

        * Title merge
        putexcel (A1:`last_col'1), merge txtwrap left top bold

        * Group header row 2
        putexcel (A2:`last_col'2), border(top, thin)
        if "`strategy'" == "both" {
            putexcel (B2:C2), merge hcenter vcenter bold
            putexcel (D2:E2), merge hcenter vcenter bold
            if `has_diff' {
                putexcel (F2:G2), merge hcenter vcenter bold
            }
        }
        else {
            putexcel (B2:C2), merge hcenter vcenter bold
        }

        * Column headers (row 3)
        putexcel (A3:`last_col'3), bold hcenter vcenter
        putexcel (A3:`last_col'3), border(bottom, thin)

        * Data alignment
        putexcel (A`data_start':`last_col'`total_rows'), hcenter

        * Bottom border
        putexcel (A`total_rows':`last_col'`total_rows'), border(bottom, thin)

        * Font
        putexcel (A1:`last_col'`total_rows'), font(Arial, 10)
        putexcel clear
    }
    if _rc {
        local saved_rc = _rc
        capture putexcel clear
        noisily display as error "Excel cell formatting failed with error `saved_rc'"
        restore
        exit `saved_rc'
    }

    restore
    display as text "  Sheet: `sheet'"
end

* =========================================================================
* BALANCE SHEET
* =========================================================================

program define _msm_tbl_bal
    version 16.0
    set varabbrev off
    set more off

    syntax , xlsx(string) decimals(integer) [title(string)]

    local sheet "Balance"
    local threshold : char _dta[_msm_bal_threshold]
    if "`threshold'" == "" local threshold "0.10"
    local fmt "%9.`decimals'f"

    tempname M
    matrix `M' = _msm_bal_matrix
    local n_covs = rowsof(`M')
    local cov_names : rownames `M'

    * Rows: title + header + data + footer
    local footer_row = `n_covs' + 3
    local total_rows = `footer_row'

    * Count balanced covariates
    local n_balanced = 0
    forvalues i = 1/`n_covs' {
        if abs(`M'[`i', 2]) < `threshold' {
            local ++n_balanced
        }
    }

    preserve
    quietly {
        clear
        set obs `total_rows'

        gen str80 A = ""
        gen str16 B = ""
        gen str16 C = ""
        gen str16 D = ""
        gen str10 E = ""

        * Row 1: title
        if "`title'" != "" {
            replace A = "`title'" in 1
        }
        else {
            replace A = "Covariate Balance" in 1
        }

        * Row 2: headers
        replace A = "Covariate" in 2
        replace B = "Raw SMD" in 2
        replace C = "Weighted SMD" in 2
        replace D = "% Change" in 2
        replace E = "Balanced" in 2

        * Data rows
        forvalues i = 1/`n_covs' {
            local row = `i' + 2
            local cname : word `i' of `cov_names'
            local raw_smd = `M'[`i', 1]
            local wt_smd = `M'[`i', 2]
            local pct_chg = `M'[`i', 3]

            replace A = "`cname'" in `row'
            replace B = strtrim(string(`raw_smd', "`fmt'")) in `row'
            replace C = strtrim(string(`wt_smd', "`fmt'")) in `row'
            replace D = strtrim(string(`pct_chg', "%9.1f")) + "%" in `row'

            if abs(`wt_smd') < `threshold' {
                replace E = "Yes" in `row'
            }
        }

        * Footer row
        replace A = "Balanced: `n_balanced'/`n_covs' " + ///
            "covariates (threshold |SMD| < `threshold')" in `footer_row'

        export excel using "`xlsx'", sheet("`sheet'") sheetreplace
    }

    * Mata: widths
    capture {
        mata: b = xl()
        mata: b.load_book("`xlsx'")
        mata: b.set_sheet("`sheet'")
        mata: b.set_row_height(1, 1, 30)
        mata: b.set_column_width(1, 1, 22)
        mata: b.set_column_width(2, 2, 14)
        mata: b.set_column_width(3, 3, 16)
        mata: b.set_column_width(4, 4, 12)
        mata: b.set_column_width(5, 5, 12)
        mata: b.close_book()
    }
    if _rc {
        local saved_rc = _rc
        capture mata: b.close_book()
        capture mata: mata drop b
        noisily display as error "Excel formatting (Mata) failed with error `saved_rc'"
        restore
        exit `saved_rc'
    }
    capture mata: mata drop b

    * putexcel formatting
    local last_data = `footer_row' - 1
    capture {
        putexcel set "`xlsx'", sheet("`sheet'") modify
        putexcel (A1:E1), merge txtwrap left top bold
        putexcel (A2:E2), bold hcenter vcenter
        putexcel (A2:E2), border(top, thin)
        putexcel (A2:E2), border(bottom, thin)
        putexcel (B3:E`last_data'), hcenter
        putexcel (A`last_data':E`last_data'), border(bottom, thin)
        putexcel (A`footer_row':E`footer_row'), merge italic
        putexcel (A1:E`total_rows'), font(Arial, 10)
        putexcel clear
    }
    if _rc {
        local saved_rc = _rc
        capture putexcel clear
        noisily display as error "Excel cell formatting failed with error `saved_rc'"
        restore
        exit `saved_rc'
    }

    restore
    display as text "  Sheet: `sheet'"
end

* =========================================================================
* WEIGHTS SHEET
* =========================================================================

program define _msm_tbl_wt
    version 16.0
    set varabbrev off
    set more off

    syntax , xlsx(string) decimals(integer) [title(string)]

    local sheet "Weights"
    local fmt "%9.`decimals'f"

    * Read weight diagnostics from chars
    local w_mean    : char _dta[_msm_diag_mean]
    local w_sd      : char _dta[_msm_diag_sd]
    local w_min     : char _dta[_msm_diag_min]
    local w_p1      : char _dta[_msm_diag_p1]
    local w_p50     : char _dta[_msm_diag_p50]
    local w_p99     : char _dta[_msm_diag_p99]
    local w_max     : char _dta[_msm_diag_max]
    local w_ess     : char _dta[_msm_diag_ess]
    local w_ess_pct : char _dta[_msm_diag_ess_pct]

    * 9 statistics + title + header = 11 rows
    local total_rows = 11

    preserve
    quietly {
        clear
        set obs `total_rows'

        gen str30 A = ""
        gen str20 B = ""

        * Row 1: title
        if "`title'" != "" {
            replace A = "`title'" in 1
        }
        else {
            replace A = "Weight Distribution" in 1
        }

        * Row 2: header
        replace A = "Statistic" in 2
        replace B = "Value" in 2

        * Data rows
        replace A = "Mean"    in 3
        replace B = strtrim(string(`w_mean', "`fmt'")) in 3
        replace A = "SD"      in 4
        replace B = strtrim(string(`w_sd', "`fmt'")) in 4
        replace A = "Min"     in 5
        replace B = strtrim(string(`w_min', "`fmt'")) in 5
        replace A = "P1"      in 6
        replace B = strtrim(string(`w_p1', "`fmt'")) in 6
        replace A = "Median"  in 7
        replace B = strtrim(string(`w_p50', "`fmt'")) in 7
        replace A = "P99"     in 8
        replace B = strtrim(string(`w_p99', "`fmt'")) in 8
        replace A = "Max"     in 9
        replace B = strtrim(string(`w_max', "`fmt'")) in 9
        replace A = "ESS"     in 10
        replace B = strtrim(string(`w_ess', "%9.1f")) in 10
        replace A = "ESS (%)" in 11
        replace B = strtrim(string(`w_ess_pct', "%9.1f")) + "%" in 11

        export excel using "`xlsx'", sheet("`sheet'") sheetreplace
    }

    * Mata: widths
    capture {
        mata: b = xl()
        mata: b.load_book("`xlsx'")
        mata: b.set_sheet("`sheet'")
        mata: b.set_row_height(1, 1, 30)
        mata: b.set_column_width(1, 1, 18)
        mata: b.set_column_width(2, 2, 16)
        mata: b.close_book()
    }
    if _rc {
        local saved_rc = _rc
        capture mata: b.close_book()
        capture mata: mata drop b
        noisily display as error "Excel formatting (Mata) failed with error `saved_rc'"
        restore
        exit `saved_rc'
    }
    capture mata: mata drop b

    * putexcel formatting
    capture {
        putexcel set "`xlsx'", sheet("`sheet'") modify
        putexcel (A1:B1), merge txtwrap left top bold
        putexcel (A2:B2), bold hcenter vcenter
        putexcel (A2:B2), border(top, thin)
        putexcel (A2:B2), border(bottom, thin)
        putexcel (B3:B`total_rows'), hcenter
        putexcel (A`total_rows':B`total_rows'), border(bottom, thin)
        putexcel (A1:B`total_rows'), font(Arial, 10)
        putexcel clear
    }
    if _rc {
        local saved_rc = _rc
        capture putexcel clear
        noisily display as error "Excel cell formatting failed with error `saved_rc'"
        restore
        exit `saved_rc'
    }

    restore
    display as text "  Sheet: `sheet'"
end

* =========================================================================
* SENSITIVITY SHEET
* =========================================================================

program define _msm_tbl_sens
    version 16.0
    set varabbrev off
    set more off

    syntax , xlsx(string) decimals(integer) [title(string)]

    local sheet "Sensitivity"
    local fmt "%9.`decimals'f"

    * Read from chars
    local effect    : char _dta[_msm_sens_effect]
    local effect_lo : char _dta[_msm_sens_effect_lo]
    local effect_hi : char _dta[_msm_sens_effect_hi]
    local eff_label : char _dta[_msm_sens_effect_label]
    local evalue_pt : char _dta[_msm_sens_evalue_point]
    local evalue_ci : char _dta[_msm_sens_evalue_ci]

    * Count rows: title + header + effect + CI [+ evalue_point + evalue_ci]
    local n_data = 2
    local has_evalue = ("`evalue_pt'" != "")
    if `has_evalue' {
        local n_data = `n_data' + 2
    }
    local total_rows = `n_data' + 2

    preserve
    quietly {
        clear
        set obs `total_rows'

        gen str40 A = ""
        gen str24 B = ""

        * Row 1: title
        if "`title'" != "" {
            replace A = "`title'" in 1
        }
        else {
            replace A = "Sensitivity Analysis" in 1
        }

        * Row 2: header
        replace A = "Parameter" in 2
        replace B = "Value" in 2

        * Treatment effect
        replace A = "Treatment Effect (`eff_label')" in 3
        replace B = strtrim(string(`effect', "`fmt'")) in 3

        * CI
        local ci_lo_s = strtrim(string(`effect_lo', "`fmt'"))
        local ci_hi_s = strtrim(string(`effect_hi', "`fmt'"))
        replace A = "95% CI" in 4
        replace B = "`ci_lo_s' - `ci_hi_s'" in 4

        * E-values
        if `has_evalue' {
            replace A = "E-value (point estimate)" in 5
            replace B = strtrim(string(`evalue_pt', "`fmt'")) in 5
            replace A = "E-value (CI limit)" in 6
            replace B = strtrim(string(`evalue_ci', "`fmt'")) in 6
        }

        export excel using "`xlsx'", sheet("`sheet'") sheetreplace
    }

    * Mata: widths
    capture {
        mata: b = xl()
        mata: b.load_book("`xlsx'")
        mata: b.set_sheet("`sheet'")
        mata: b.set_row_height(1, 1, 30)
        mata: b.set_column_width(1, 1, 30)
        mata: b.set_column_width(2, 2, 18)
        mata: b.close_book()
    }
    if _rc {
        local saved_rc = _rc
        capture mata: b.close_book()
        capture mata: mata drop b
        noisily display as error "Excel formatting (Mata) failed with error `saved_rc'"
        restore
        exit `saved_rc'
    }
    capture mata: mata drop b

    * putexcel formatting
    capture {
        putexcel set "`xlsx'", sheet("`sheet'") modify
        putexcel (A1:B1), merge txtwrap left top bold
        putexcel (A2:B2), bold hcenter vcenter
        putexcel (A2:B2), border(top, thin)
        putexcel (A2:B2), border(bottom, thin)
        putexcel (B3:B`total_rows'), hcenter
        putexcel (A`total_rows':B`total_rows'), border(bottom, thin)
        putexcel (A1:B`total_rows'), font(Arial, 10)
        putexcel clear
    }
    if _rc {
        local saved_rc = _rc
        capture putexcel clear
        noisily display as error "Excel cell formatting failed with error `saved_rc'"
        restore
        exit `saved_rc'
    }

    restore
    display as text "  Sheet: `sheet'"
end
