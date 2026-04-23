*! msm_table Version 1.0.0  2026/04/08
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
  font(string)         Font name (default: Arial)
  fontsize(#)          Font size in points (default: 10)
  borderstyle(string)  Border style: thin, medium, or academic (default: thin)
  nformat(string)      Excel number format for numeric cells
  zebra                Alternating row shading (light gray)
  boldp(#)             Bold p-values below threshold (Coefficients only)
  highlight(#)         Highlight rows where p < threshold (Coefficients only)
  footnote(string)     Merged footnote below each table
  open                 Auto-open Excel file after export

See help msm_table for complete documentation
*/

* =========================================================================
* MAIN DISPATCHER
* =========================================================================

program define msm_table, nclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    set varabbrev off
    set more off

    capture noisily {

    syntax , XLSX(string) [COEFficients PREDictions BALance WEIGHTs ///
        SENSitivity ALL EForm DECimals(integer 3) SEP(string) ///
        TITle(string) REPLACE Font(string) FONTSize(integer 10) ///
        BORDERstyle(string) NFORmat(string) ZEBRA BOLDp(real 0) ///
        HIGHlight(real 0) FOOTnote(string) OPEN]

    * Defaults
    if "`sep'" == "" local sep ", "
    if "`font'" == "" local font "Arial"
    if "`borderstyle'" == "" local borderstyle "thin"

    if `decimals' < 0 | `decimals' > 10 {
        display as error "decimals() must be between 0 and 10"
        exit 198
    }

    if !inlist("`borderstyle'", "thin", "medium", "academic") {
        display as error "borderstyle() must be thin, medium, or academic"
        exit 198
    }

    * Academic borderstyle uses medium for horizontal borders
    local _hborder = "`borderstyle'"
    if "`borderstyle'" == "academic" local _hborder "medium"

    if `fontsize' < 6 | `fontsize' > 72 {
        display as error "fontsize() must be between 6 and 72"
        exit 198
    }

    if `boldp' < 0 | `boldp' > 1 {
        display as error "boldp() must be between 0 and 1"
        exit 198
    }

    if `highlight' < 0 | `highlight' > 1 {
        display as error "highlight() must be between 0 and 1"
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
            capture matrix list _msm_fit_b
            if _rc {
                if `auto' local do_coef = 0
                else {
                    display as error "saved model coefficients not found; re-run msm_fit"
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
            sep("`sep'") title("`title'") `eform' ///
            font("`font'") fontsize(`fontsize') ///
            borderstyle("`borderstyle'") nformat("`nformat'") ///
            `zebra' boldp(`boldp') highlight(`highlight') ///
            footnote(`"`footnote'"')
    }
    if `do_pred' {
        _msm_tbl_pred, xlsx("`xlsx'") decimals(`decimals') ///
            sep("`sep'") title("`title'") ///
            font("`font'") fontsize(`fontsize') ///
            borderstyle("`borderstyle'") nformat("`nformat'") ///
            `zebra' footnote(`"`footnote'"')
    }
    if `do_bal' {
        _msm_tbl_bal, xlsx("`xlsx'") decimals(`decimals') ///
            title("`title'") ///
            font("`font'") fontsize(`fontsize') ///
            borderstyle("`borderstyle'") nformat("`nformat'") ///
            `zebra' footnote(`"`footnote'"')
    }
    if `do_wt' {
        _msm_tbl_wt, xlsx("`xlsx'") decimals(`decimals') ///
            title("`title'") ///
            font("`font'") fontsize(`fontsize') ///
            borderstyle("`borderstyle'") nformat("`nformat'") ///
            `zebra' footnote(`"`footnote'"')
    }
    if `do_sens' {
        _msm_tbl_sens, xlsx("`xlsx'") decimals(`decimals') ///
            title("`title'") ///
            font("`font'") fontsize(`fontsize') ///
            borderstyle("`borderstyle'") nformat("`nformat'") ///
            `zebra' footnote(`"`footnote'"')
    }

    display as text ""
    display as result "`n_sheets'" as text " table(s) exported to " ///
        as result "`xlsx'"

    if "`open'" != "" {
        _msm_post_export_open, file(`"`xlsx'"')
    }

    } /* end capture noisily */
    local _rc = _rc

    set varabbrev `_varabbrev'
    set more `_more'

    if `_rc' exit `_rc'
end

* =========================================================================
* COEFFICIENTS SHEET
* =========================================================================

program define _msm_tbl_coef
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    syntax , xlsx(string) decimals(integer) sep(string) ///
        [title(string) eform font(string) fontsize(integer 10) ///
         borderstyle(string) nformat(string) zebra boldp(real 0) ///
         highlight(real 0) footnote(string)]

    local sheet "Coefficients"
    local _hborder = "`borderstyle'"
    if "`borderstyle'" == "academic" local _hborder "medium"
    local model : char _dta[_msm_model]
    local fmt "%9.`decimals'f"
    local coef_xfmt "`nformat'"
    if `"`coef_xfmt'"' == "" {
        local coef_xfmt "0"
        if `decimals' > 0 {
            local coef_xfmt "0."
            forvalues _di = 1/`decimals' {
                local coef_xfmt "`coef_xfmt'0"
            }
        }
    }

    * Effect measure label
    if "`eform'" != "" {
        if "`model'" == "logistic"      local eff_label "OR"
        else if "`model'" == "cox"      local eff_label "HR"
        else                            local eff_label "exp(b)"
    }
    else {
        local eff_label "Coef."
    }

    * Get coefficients from saved fit matrices
    tempname b V
    matrix `b' = _msm_fit_b
    matrix `V' = _msm_fit_V
    local k = colsof(`b')
    local coef_names : colnames `b'

    * Read fit level BEFORE preserve/clear (chars lost on clear)
    local _fit_level : char _dta[_msm_fit_level]
    if "`_fit_level'" == "" local _fit_level "95"

    * Total rows: title + header + k data rows
    local nrows = `k' + 2
    local last_data = `nrows'
    local _has_footnote = (`"`footnote'"' != "")
    local footnote_row = `nrows' + 1
    local n_cols = 4

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
            replace A = "Outcome Model (`model')" in 1
        }
        replace A = "Variable" in 2
        replace B = "`eff_label'" in 2
        replace C = "`_fit_level'% CI" in 2
        replace D = "p-value" in 2

        * Data rows
        forvalues i = 1/`k' {
            local row = `i' + 2
            local cname : word `i' of `coef_names'
            local coef = `b'[1, `i']
            local v_ii = `V'[`i', `i']
            local display_name "`cname'"
            if "`cname'" == "_cons" local display_name "Constant"
            else if "`cname'" == "_msm_period_sq" local display_name "Period^2"
            else if "`cname'" == "period" local display_name "Period"
            else if "`cname'" == "treatment" local display_name "Treatment"
            else {
                capture confirm variable `cname'
                if !_rc {
                    local vlabel : variable label `cname'
                    if `"`vlabel'"' != "" local display_name `"`vlabel'"'
                }
            }

            replace A = `"`display_name'"' in `row'

            * Skip omitted/base variables
            if `v_ii' <= 0 {
                replace B = "(omitted)" in `row'
                continue
            }

            local se = sqrt(`v_ii')
            local z = invnormal((100 + `_fit_level') / 200)
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

            local _coef_num_`row' = `d_coef'

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

        * Calculate dynamic column widths
        local _col_idx = 0
        foreach _var of varlist * {
            local _col_idx = `_col_idx' + 1
            gen _len_`_col_idx' = length(`_var')
            summarize _len_`_col_idx', meanonly
            local _maxlen_`_col_idx' = r(max)
            drop _len_`_col_idx'
        }
        local _w_1 = ceil(`_maxlen_1' * 0.90)
        if `_w_1' < 14 local _w_1 = 14
        if `_w_1' > 50 local _w_1 = 50
        local _w_2 = ceil(`_maxlen_2' * 0.85)
        if `_w_2' < 10 local _w_2 = 10
        if `_w_2' > 30 local _w_2 = 30
        local _w_3 = ceil(`_maxlen_3' * 0.85)
        if `_w_3' < 18 local _w_3 = 18
        if `_w_3' > 30 local _w_3 = 30
        local _w_4 = ceil(`_maxlen_4' * 0.85)
        if `_w_4' < 10 local _w_4 = 10
        if `_w_4' > 14 local _w_4 = 14

        export excel using "`xlsx'", sheet("`sheet'") sheetreplace
    }

    * Mata: column widths + numeric conversion
    capture {
        mata: _msm_xl = xl()
        mata: _msm_xl.load_book("`xlsx'")
        mata: _msm_xl.set_sheet("`sheet'")
        mata: _msm_xl.set_row_height(1, 1, 30)
        mata: _msm_xl.set_column_width(1, 1, `_w_1')
        mata: _msm_xl.set_column_width(2, 2, `_w_2')
        mata: _msm_xl.set_column_width(3, 3, `_w_3')
        mata: _msm_xl.set_column_width(4, 4, `_w_4')

        * Write coefficient estimates as proper Excel numerics
        forvalues _i = 1/`k' {
            local _r = `_i' + 2
            local _v_ii = `V'[`_i', `_i']
            if `_v_ii' <= 0 continue
            local _coef_val = `b'[1, `_i']
            if "`eform'" != "" local _coef_val = exp(`_coef_val')
            mata: _msm_xl.put_number(`_r', 2, `_coef_val')
            mata: _msm_xl.set_number_format(`_r', 2, "`coef_xfmt'")
        }

        mata: _msm_xl.close_book()
    }
    if _rc {
        local saved_rc = _rc
        capture mata: _msm_xl.close_book()
        capture mata: mata drop _msm_xl
        noisily display as error "Excel formatting (Mata) failed with error `saved_rc'"
        restore
        exit `saved_rc'
    }
    capture mata: mata drop _msm_xl

    * putexcel: formatting
    capture {
        putexcel set "`xlsx'", sheet("`sheet'") modify

        * Title: merge, wrap, vcenter, bold
        putexcel (A1:D1), merge txtwrap left vcenter bold

        * Headers: bold, centered, wrapped
        putexcel (A2:D2), bold hcenter vcenter txtwrap
        putexcel (A2:D2), fpattern(solid, "219 229 241")

        * Full rectangular border frame
        putexcel (A2:D2), border(top, `_hborder')
        putexcel (A2:D2), border(bottom, `_hborder')
        if "`borderstyle'" != "academic" {
            putexcel (A2:A`nrows'), border(left, `borderstyle')
            putexcel (D2:D`nrows'), border(right, `borderstyle')
        }
        putexcel (A`nrows':D`nrows'), border(bottom, `_hborder')

        * Data alignment: center numeric cols, right-align p-value
        putexcel (B3:C`nrows'), hcenter
        putexcel (D3:D`nrows'), right

        * Vertical separator before p-value
        if "`borderstyle'" != "academic" {
            putexcel (D2:D`nrows'), border(left, `borderstyle')
        }

        * Zebra striping
        if "`zebra'" != "" {
            forvalues _zr = 3(2)`last_data' {
                putexcel (A`_zr':D`_zr'), fpattern(solid, "237 242 249")
            }
        }

        * Bold significant p-values
        if `boldp' > 0 {
            forvalues _br = 3/`last_data' {
                local _pval = D[`_br']
                if `"`_pval'"' == "<0.001" {
                    putexcel (D`_br'), bold
                }
                else if `"`_pval'"' != "" & `"`_pval'"' != "." {
                    local _pnum = real("`_pval'")
                    if `_pnum' != . & `_pnum' < `boldp' {
                        putexcel (D`_br'), bold
                    }
                }
            }
        }

        * Highlight rows with significant p-values
        if `highlight' > 0 {
            forvalues _hr = 3/`last_data' {
                local _pval = D[`_hr']
                local _pnum = .
                if `"`_pval'"' == "<0.001" {
                    local _pnum = 0.0001
                }
                else if `"`_pval'"' != "" & `"`_pval'"' != "." {
                    local _pnum = real("`_pval'")
                }
                if `_pnum' != . & `_pnum' < `highlight' {
                    putexcel (A`_hr':D`_hr'), fpattern(solid, "255 255 204")
                }
            }
        }

        * Font
        putexcel (A1:D`nrows'), font("`font'", `fontsize')
        putexcel (A1:D1), font("`font'", `=`fontsize'+2')

        * Footnote
        if `_has_footnote' {
            putexcel A`footnote_row' = `"`footnote'"'
            putexcel (A`footnote_row':D`footnote_row'), merge italic txtwrap left
            local _fn_fontsize = max(`fontsize' - 2, 6)
            putexcel (A`footnote_row':D`footnote_row'), font("`font'", `_fn_fontsize')
        }

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

    } /* end capture noisily */
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end

* =========================================================================
* PREDICTIONS SHEET
* =========================================================================

program define _msm_tbl_pred
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    syntax , xlsx(string) decimals(integer) sep(string) ///
        [title(string) font(string) fontsize(integer 10) ///
         borderstyle(string) nformat(string) zebra footnote(string)]

    local sheet "Predictions"
    local _hborder = "`borderstyle'"
    if "`borderstyle'" == "academic" local _hborder "medium"
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

    * Rows: title + group header + column header + data [+ footnote]
    local hdr_rows = 3
    local data_start = 4
    local total_rows = `n_times' + `hdr_rows'
    local last_data = `total_rows'
    local _has_footnote = (`"`footnote'"' != "")
    local footnote_row = `total_rows' + 1

    * Get last column letter
    _msm_col_letter `n_cols'
    local last_col "`result'"

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
            replace A = "Counterfactual `type_label'" in 1
        }

        * Row 2: group headers
        if "`strategy'" == "both" {
            replace c1 = "Never treated" in 2
            replace c3 = "Always treated" in 2
            if `has_diff' {
                replace c5 = "Risk difference" in 2
            }
        }
        else {
            local strat_label = cond("`strategy'" == "always", ///
                "Always treated", "Never treated")
            replace c1 = "`strat_label'" in 2
        }

        * Row 3: column headers
        replace A = "Period" in 3
        if "`strategy'" == "both" {
            replace c1 = "Estimate" in 3
            replace c2 = "`level'% CI" in 3
            replace c3 = "Estimate" in 3
            replace c4 = "`level'% CI" in 3
            if `has_diff' {
                replace c5 = "Estimate" in 3
                replace c6 = "`level'% CI" in 3
            }
        }
        else {
            replace c1 = "Estimate" in 3
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

        * Calculate dynamic column widths
        local _col_idx = 0
        foreach _var of varlist * {
            local _col_idx = `_col_idx' + 1
            gen _len_`_col_idx' = length(`_var')
            summarize _len_`_col_idx', meanonly
            local _maxlen_`_col_idx' = r(max)
            drop _len_`_col_idx'
        }
        * Period column
        local _w_1 = ceil(`_maxlen_1' * 0.90)
        if `_w_1' < 10 local _w_1 = 10
        if `_w_1' > 30 local _w_1 = 30
        * Data columns: estimate cols narrower, CI cols wider
        forvalues _ci = 2/`_col_idx' {
            local _w_`_ci' = ceil(`_maxlen_`_ci'' * 0.85)
            * CI columns (even-numbered: c2, c4, c6) need more width
            local _rel_col = `_ci' - 1
            if mod(`_rel_col', 2) == 0 {
                if `_w_`_ci'' < 18 local _w_`_ci' = 18
            }
            else {
                if `_w_`_ci'' < 10 local _w_`_ci' = 10
            }
            if `_w_`_ci'' > 30 local _w_`_ci' = 30
        }

        export excel using "`xlsx'", sheet("`sheet'") sheetreplace
    }

    * Mata: column widths + numeric conversion
    capture {
        mata: _msm_xl = xl()
        mata: _msm_xl.load_book("`xlsx'")
        mata: _msm_xl.set_sheet("`sheet'")
        mata: _msm_xl.set_row_height(1, 1, 30)
        forvalues _ci = 1/`n_cols' {
            mata: _msm_xl.set_column_width(`_ci', `_ci', `_w_`_ci'')
        }

        * Convert period + estimate cells to numeric (skip CI columns)
        forvalues _r = `data_start'/`total_rows' {
            * Column A (period)
            local _cellstr = A[`_r']
            if `"`_cellstr'"' != "" & `"`_cellstr'"' != "." {
                local _cellnum = real("`_cellstr'")
                if `_cellnum' != . {
                    mata: _msm_xl.put_number(`_r', 1, `_cellnum')
                }
            }
            * Estimate columns only (skip CI columns with parens)
            local _col_idx = 1
            foreach _var of varlist c* {
                local _col_idx = `_col_idx' + 1
                local _cellstr = `_var'[`_r']
                if `"`_cellstr'"' == "" | `"`_cellstr'"' == "." continue
                if strpos(`"`_cellstr'"', "(") > 0 continue
                local _cellclean = subinstr(`"`_cellstr'"', ",", "", .)
                local _cellnum = real("`_cellclean'")
                if `_cellnum' != . {
                    mata: _msm_xl.put_number(`_r', `_col_idx', `_cellnum')
                    if `"`nformat'"' != "" {
                        mata: _msm_xl.set_number_format(`_r', `_col_idx', "`nformat'")
                    }
                }
            }
        }

        mata: _msm_xl.close_book()
    }
    if _rc {
        local saved_rc = _rc
        capture mata: _msm_xl.close_book()
        capture mata: mata drop _msm_xl
        noisily display as error "Excel formatting (Mata) failed with error `saved_rc'"
        restore
        exit `saved_rc'
    }
    capture mata: mata drop _msm_xl

    * putexcel: formatting
    capture {
        putexcel set "`xlsx'", sheet("`sheet'") modify

        * Title: merge, wrap, vcenter, bold
        putexcel (A1:`last_col'1), merge txtwrap left vcenter bold

        * Group header row 2
        putexcel (A2:`last_col'2), border(top, `_hborder')
        if "`strategy'" == "both" {
            putexcel (B2:C2), merge hcenter vcenter bold txtwrap
            putexcel (D2:E2), merge hcenter vcenter bold txtwrap
            if `has_diff' {
                putexcel (F2:G2), merge hcenter vcenter bold txtwrap
            }
        }
        else {
            putexcel (B2:C2), merge hcenter vcenter bold txtwrap
        }

        * Column headers (row 3)
        putexcel (A3:`last_col'3), bold hcenter vcenter txtwrap
        putexcel (A3:`last_col'3), fpattern(solid, "219 229 241")
        putexcel (A3:`last_col'3), border(bottom, `_hborder')

        * Full rectangular border frame
        if "`borderstyle'" != "academic" {
            putexcel (A2:A`total_rows'), border(left, `borderstyle')
            putexcel (`last_col'2:`last_col'`total_rows'), border(right, `borderstyle')
        }
        putexcel (A`total_rows':`last_col'`total_rows'), border(bottom, `_hborder')

        * Data alignment
        putexcel (A`data_start':`last_col'`total_rows'), hcenter

        * Vertical separators between strategy groups
        if "`strategy'" == "both" & "`borderstyle'" != "academic" {
            putexcel (D2:D`total_rows'), border(left, `borderstyle')
            if `has_diff' {
                putexcel (F2:F`total_rows'), border(left, `borderstyle')
            }
        }

        * Zebra striping
        if "`zebra'" != "" {
            forvalues _zr = `data_start'(2)`last_data' {
                putexcel (A`_zr':`last_col'`_zr'), fpattern(solid, "237 242 249")
            }
        }

        * Font
        putexcel (A1:`last_col'`total_rows'), font("`font'", `fontsize')
        putexcel (A1:`last_col'1), font("`font'", `=`fontsize'+2')

        * Footnote
        if `_has_footnote' {
            putexcel A`footnote_row' = `"`footnote'"'
            putexcel (A`footnote_row':`last_col'`footnote_row'), merge italic txtwrap left
            local _fn_fontsize = max(`fontsize' - 2, 6)
            putexcel (A`footnote_row':`last_col'`footnote_row'), font("`font'", `_fn_fontsize')
        }

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

    } /* end capture noisily */
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end

* =========================================================================
* BALANCE SHEET
* =========================================================================

program define _msm_tbl_bal
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    syntax , xlsx(string) decimals(integer) ///
        [title(string) font(string) fontsize(integer 10) ///
         borderstyle(string) nformat(string) zebra footnote(string)]

    local sheet "Balance"
    local _hborder = "`borderstyle'"
    if "`borderstyle'" == "academic" local _hborder "medium"
    local threshold : char _dta[_msm_bal_threshold]
    if "`threshold'" == "" local threshold "0.10"
    local fmt "%9.`decimals'f"

    tempname M
    matrix `M' = _msm_bal_matrix
    local n_covs = rowsof(`M')
    local cov_names : rownames `M'

    * Rows: title + header + data + footer [+ footnote]
    local footer_row = `n_covs' + 3
    local total_rows = `footer_row'
    local last_data = `footer_row' - 1
    local _has_footnote = (`"`footnote'"' != "")
    local footnote_row = `total_rows' + 1
    local n_cols = 5

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

        * Calculate dynamic column widths
        local _col_idx = 0
        foreach _var of varlist * {
            local _col_idx = `_col_idx' + 1
            gen _len_`_col_idx' = length(`_var')
            summarize _len_`_col_idx', meanonly
            local _maxlen_`_col_idx' = r(max)
            drop _len_`_col_idx'
        }
        local _w_1 = ceil(`_maxlen_1' * 0.90)
        if `_w_1' < 14 local _w_1 = 14
        if `_w_1' > 50 local _w_1 = 50
        forvalues _ci = 2/`_col_idx' {
            local _w_`_ci' = ceil(`_maxlen_`_ci'' * 0.85)
            if `_w_`_ci'' < 12 local _w_`_ci' = 12
            if `_w_`_ci'' > 30 local _w_`_ci' = 30
        }

        export excel using "`xlsx'", sheet("`sheet'") sheetreplace
    }

    * Mata: column widths + numeric conversion
    capture {
        mata: _msm_xl = xl()
        mata: _msm_xl.load_book("`xlsx'")
        mata: _msm_xl.set_sheet("`sheet'")
        mata: _msm_xl.set_row_height(1, 1, 30)
        forvalues _ci = 1/`n_cols' {
            mata: _msm_xl.set_column_width(`_ci', `_ci', `_w_`_ci'')
        }

        * Convert SMD cells to numeric (skip % and Yes/empty cols)
        forvalues _r = 3/`last_data' {
            foreach _cvar in B C {
                local _cnum = cond("`_cvar'" == "B", 2, 3)
                local _cellstr = `_cvar'[`_r']
                if `"`_cellstr'"' == "" | `"`_cellstr'"' == "." continue
                local _cellclean = subinstr(`"`_cellstr'"', ",", "", .)
                local _cellnum = real("`_cellclean'")
                if `_cellnum' != . {
                    mata: _msm_xl.put_number(`_r', `_cnum', `_cellnum')
                    if `"`nformat'"' != "" {
                        mata: _msm_xl.set_number_format(`_r', `_cnum', "`nformat'")
                    }
                }
            }
        }

        mata: _msm_xl.close_book()
    }
    if _rc {
        local saved_rc = _rc
        capture mata: _msm_xl.close_book()
        capture mata: mata drop _msm_xl
        noisily display as error "Excel formatting (Mata) failed with error `saved_rc'"
        restore
        exit `saved_rc'
    }
    capture mata: mata drop _msm_xl

    * putexcel formatting
    capture {
        putexcel set "`xlsx'", sheet("`sheet'") modify

        * Title: merge, wrap, vcenter, bold
        putexcel (A1:E1), merge txtwrap left vcenter bold

        * Headers: bold, centered, wrapped
        putexcel (A2:E2), bold hcenter vcenter txtwrap
        putexcel (A2:E2), fpattern(solid, "219 229 241")

        * Full rectangular border frame
        putexcel (A2:E2), border(top, `_hborder')
        putexcel (A2:E2), border(bottom, `_hborder')
        if "`borderstyle'" != "academic" {
            putexcel (A2:A`total_rows'), border(left, `borderstyle')
            putexcel (E2:E`total_rows'), border(right, `borderstyle')
        }

        * Data alignment
        putexcel (B3:E`last_data'), hcenter

        * Bottom border before footer (separator)
        putexcel (A`last_data':E`last_data'), border(bottom, `_hborder')

        * Vertical separator before Balanced column
        if "`borderstyle'" != "academic" {
            putexcel (E2:E`last_data'), border(left, `borderstyle')
        }

        * Footer: merge, italic
        putexcel (A`footer_row':E`footer_row'), merge italic

        * Zebra striping
        if "`zebra'" != "" {
            forvalues _zr = 3(2)`last_data' {
                putexcel (A`_zr':E`_zr'), fpattern(solid, "237 242 249")
            }
        }

        * Font
        putexcel (A1:E`total_rows'), font("`font'", `fontsize')
        putexcel (A1:E1), font("`font'", `=`fontsize'+2')

        * Footnote
        if `_has_footnote' {
            putexcel A`footnote_row' = `"`footnote'"'
            putexcel (A`footnote_row':E`footnote_row'), merge italic txtwrap left
            local _fn_fontsize = max(`fontsize' - 2, 6)
            putexcel (A`footnote_row':E`footnote_row'), font("`font'", `_fn_fontsize')
        }

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

    } /* end capture noisily */
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end

* =========================================================================
* WEIGHTS SHEET
* =========================================================================

program define _msm_tbl_wt
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    syntax , xlsx(string) decimals(integer) ///
        [title(string) font(string) fontsize(integer 10) ///
         borderstyle(string) nformat(string) zebra footnote(string)]

    local sheet "Weights"
    local _hborder = "`borderstyle'"
    if "`borderstyle'" == "academic" local _hborder "medium"
    local fmt "%9.`decimals'f"
    local n_cols = 2

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
    local last_data = `total_rows'
    local _has_footnote = (`"`footnote'"' != "")
    local footnote_row = `total_rows' + 1

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

        * Calculate dynamic column widths
        local _col_idx = 0
        foreach _var of varlist * {
            local _col_idx = `_col_idx' + 1
            gen _len_`_col_idx' = length(`_var')
            summarize _len_`_col_idx', meanonly
            local _maxlen_`_col_idx' = r(max)
            drop _len_`_col_idx'
        }
        local _w_1 = ceil(`_maxlen_1' * 0.90)
        if `_w_1' < 14 local _w_1 = 14
        if `_w_1' > 30 local _w_1 = 30
        local _w_2 = ceil(`_maxlen_2' * 0.85)
        if `_w_2' < 12 local _w_2 = 12
        if `_w_2' > 30 local _w_2 = 30

        export excel using "`xlsx'", sheet("`sheet'") sheetreplace
    }

    * Mata: column widths + numeric conversion
    capture {
        mata: _msm_xl = xl()
        mata: _msm_xl.load_book("`xlsx'")
        mata: _msm_xl.set_sheet("`sheet'")
        mata: _msm_xl.set_row_height(1, 1, 30)
        mata: _msm_xl.set_column_width(1, 1, `_w_1')
        mata: _msm_xl.set_column_width(2, 2, `_w_2')

        * Convert numeric value cells (skip ESS% row with %)
        forvalues _r = 3/`total_rows' {
            local _cellstr = B[`_r']
            if `"`_cellstr'"' == "" | `"`_cellstr'"' == "." continue
            if strpos(`"`_cellstr'"', "%") > 0 continue
            local _cellclean = subinstr(`"`_cellstr'"', ",", "", .)
            local _cellnum = real("`_cellclean'")
            if `_cellnum' != . {
                mata: _msm_xl.put_number(`_r', 2, `_cellnum')
                if `"`nformat'"' != "" {
                    mata: _msm_xl.set_number_format(`_r', 2, "`nformat'")
                }
            }
        }

        mata: _msm_xl.close_book()
    }
    if _rc {
        local saved_rc = _rc
        capture mata: _msm_xl.close_book()
        capture mata: mata drop _msm_xl
        noisily display as error "Excel formatting (Mata) failed with error `saved_rc'"
        restore
        exit `saved_rc'
    }
    capture mata: mata drop _msm_xl

    * putexcel formatting
    capture {
        putexcel set "`xlsx'", sheet("`sheet'") modify

        * Title: merge, wrap, vcenter, bold
        putexcel (A1:B1), merge txtwrap left vcenter bold

        * Headers: bold, centered, wrapped
        putexcel (A2:B2), bold hcenter vcenter txtwrap
        putexcel (A2:B2), fpattern(solid, "219 229 241")

        * Full rectangular border frame
        putexcel (A2:B2), border(top, `_hborder')
        putexcel (A2:B2), border(bottom, `_hborder')
        if "`borderstyle'" != "academic" {
            putexcel (A2:A`total_rows'), border(left, `borderstyle')
            putexcel (B2:B`total_rows'), border(right, `borderstyle')
        }
        putexcel (A`total_rows':B`total_rows'), border(bottom, `_hborder')

        * Data alignment
        putexcel (B3:B`total_rows'), hcenter

        * Zebra striping
        if "`zebra'" != "" {
            forvalues _zr = 3(2)`last_data' {
                putexcel (A`_zr':B`_zr'), fpattern(solid, "237 242 249")
            }
        }

        * Font
        putexcel (A1:B`total_rows'), font("`font'", `fontsize')
        putexcel (A1:B1), font("`font'", `=`fontsize'+2')

        * Footnote
        if `_has_footnote' {
            putexcel A`footnote_row' = `"`footnote'"'
            putexcel (A`footnote_row':B`footnote_row'), merge italic txtwrap left
            local _fn_fontsize = max(`fontsize' - 2, 6)
            putexcel (A`footnote_row':B`footnote_row'), font("`font'", `_fn_fontsize')
        }

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

    } /* end capture noisily */
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end

* =========================================================================
* SENSITIVITY SHEET
* =========================================================================

program define _msm_tbl_sens
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    syntax , xlsx(string) decimals(integer) ///
        [title(string) font(string) fontsize(integer 10) ///
         borderstyle(string) nformat(string) zebra footnote(string)]

    local sheet "Sensitivity"
    local _hborder = "`borderstyle'"
    if "`borderstyle'" == "academic" local _hborder "medium"
    local fmt "%9.`decimals'f"
    local n_cols = 2

    * Read from chars (BEFORE preserve/clear)
    local effect    : char _dta[_msm_sens_effect]
    local effect_lo : char _dta[_msm_sens_effect_lo]
    local effect_hi : char _dta[_msm_sens_effect_hi]
    local eff_label : char _dta[_msm_sens_effect_label]
    local evalue_pt : char _dta[_msm_sens_evalue_point]
    local evalue_ci : char _dta[_msm_sens_evalue_ci]
    local _sens_level : char _dta[_msm_sens_level]
    if "`_sens_level'" == "" local _sens_level "95"

    * Count rows: title + header + effect + CI [+ evalue_point + evalue_ci]
    local n_data = 2
    local has_evalue = ("`evalue_pt'" != "")
    if `has_evalue' {
        local n_data = `n_data' + 2
    }
    local total_rows = `n_data' + 2
    local last_data = `total_rows'
    local _has_footnote = (`"`footnote'"' != "")
    local footnote_row = `total_rows' + 1

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
        replace A = "`_sens_level'% CI" in 4
        replace B = "`ci_lo_s' - `ci_hi_s'" in 4

        * E-values
        if `has_evalue' {
            replace A = "E-value (point estimate)" in 5
            replace B = strtrim(string(`evalue_pt', "`fmt'")) in 5
            replace A = "E-value (CI limit)" in 6
            replace B = strtrim(string(`evalue_ci', "`fmt'")) in 6
        }

        * Calculate dynamic column widths
        local _col_idx = 0
        foreach _var of varlist * {
            local _col_idx = `_col_idx' + 1
            gen _len_`_col_idx' = length(`_var')
            summarize _len_`_col_idx', meanonly
            local _maxlen_`_col_idx' = r(max)
            drop _len_`_col_idx'
        }
        local _w_1 = ceil(`_maxlen_1' * 0.90)
        if `_w_1' < 18 local _w_1 = 18
        if `_w_1' > 50 local _w_1 = 50
        local _w_2 = ceil(`_maxlen_2' * 0.85)
        if `_w_2' < 14 local _w_2 = 14
        if `_w_2' > 30 local _w_2 = 30

        export excel using "`xlsx'", sheet("`sheet'") sheetreplace
    }

    * Mata: column widths + numeric conversion
    capture {
        mata: _msm_xl = xl()
        mata: _msm_xl.load_book("`xlsx'")
        mata: _msm_xl.set_sheet("`sheet'")
        mata: _msm_xl.set_row_height(1, 1, 30)
        mata: _msm_xl.set_column_width(1, 1, `_w_1')
        mata: _msm_xl.set_column_width(2, 2, `_w_2')

        * Convert numeric value cells (skip CI range string)
        forvalues _r = 3/`total_rows' {
            local _cellstr = B[`_r']
            if `"`_cellstr'"' == "" | `"`_cellstr'"' == "." continue
            if strpos(`"`_cellstr'"', " - ") > 0 continue
            local _cellclean = subinstr(`"`_cellstr'"', ",", "", .)
            local _cellnum = real("`_cellclean'")
            if `_cellnum' != . {
                mata: _msm_xl.put_number(`_r', 2, `_cellnum')
                if `"`nformat'"' != "" {
                    mata: _msm_xl.set_number_format(`_r', 2, "`nformat'")
                }
            }
        }

        mata: _msm_xl.close_book()
    }
    if _rc {
        local saved_rc = _rc
        capture mata: _msm_xl.close_book()
        capture mata: mata drop _msm_xl
        noisily display as error "Excel formatting (Mata) failed with error `saved_rc'"
        restore
        exit `saved_rc'
    }
    capture mata: mata drop _msm_xl

    * putexcel formatting
    capture {
        putexcel set "`xlsx'", sheet("`sheet'") modify

        * Title: merge, wrap, vcenter, bold
        putexcel (A1:B1), merge txtwrap left vcenter bold

        * Headers: bold, centered, wrapped
        putexcel (A2:B2), bold hcenter vcenter txtwrap
        putexcel (A2:B2), fpattern(solid, "219 229 241")

        * Full rectangular border frame
        putexcel (A2:B2), border(top, `_hborder')
        putexcel (A2:B2), border(bottom, `_hborder')
        if "`borderstyle'" != "academic" {
            putexcel (A2:A`total_rows'), border(left, `borderstyle')
            putexcel (B2:B`total_rows'), border(right, `borderstyle')
        }
        putexcel (A`total_rows':B`total_rows'), border(bottom, `_hborder')

        * Data alignment
        putexcel (B3:B`total_rows'), hcenter

        * Zebra striping
        if "`zebra'" != "" {
            forvalues _zr = 3(2)`last_data' {
                putexcel (A`_zr':B`_zr'), fpattern(solid, "237 242 249")
            }
        }

        * Font
        putexcel (A1:B`total_rows'), font("`font'", `fontsize')
        putexcel (A1:B1), font("`font'", `=`fontsize'+2')

        * Footnote
        if `_has_footnote' {
            putexcel A`footnote_row' = `"`footnote'"'
            putexcel (A`footnote_row':B`footnote_row'), merge italic txtwrap left
            local _fn_fontsize = max(`fontsize' - 2, 6)
            putexcel (A`footnote_row':B`footnote_row'), font("`font'", `_fn_fontsize')
        }

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

    } /* end capture noisily */
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
