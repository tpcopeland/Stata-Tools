*! crosstab Version 1.0.7  2026/04/18
*! Cross-tabulation with association measures
*! Author: Timothy P Copeland
*! Program class: rclass

/*
DESCRIPTION:
    Cross-tabulation table with association measures (OR, RR, RD),
    Chi-squared or Fisher's exact tests, and trend tests.

SYNTAX:
    crosstab rowvar colvar [if] [in] [weight], xlsx(filename)
        [colpct rowpct totalpct exact fisher
        or rr rd trend label missing
        sheet(string) title(string)
        footnote(string) theme(string) borderstyle(string)
        boldp(real) zebra
        csv(filename) frame(name) display open]
*/

program define crosstab, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

capture noisily {

    * Auto-load shared helper programs
    local _needs_helpers 0
    foreach _helper in _tabtools_validate_path _tabtools_validate_sheet ///
        _tabtools_resolve_format _tabtools_console_display ///
        _tabtools_build_col_letters _tabtools_footnote ///
        _tabtools_frame_put _tabtools_open_file {
        capture program list `_helper'
        if _rc local _needs_helpers 1
    }
    if `_needs_helpers' {
        capture findfile _tabtools_common.ado
        if _rc == 0 {
            run "`r(fn)'"
        }
        else {
            display as error "_tabtools_common.ado not found; reinstall tabtools"
            exit 111
        }
    }

**# Syntax and Validation
    syntax varlist(min=2 max=2) [if] [in] [fweight], ///
        [xlsx(string) excel(string) sheet(string) ///
        COLPct ROWPct TOTALPct EXact FIsher ///
        OR RR RD TRend LABel MISsing ///
        DIGits(integer -1) ///
        title(string) ///
        FOOTnote(string) THEme(string) BORDERstyle(string) ///
        BOLDp(real -1) zebra ///
        csv(string) FRAme(string) DISplay open]

    gettoken rowvar colvar : varlist

    capture confirm numeric variable `rowvar'
    if _rc {
        noisily display as error "rowvar and colvar must be numeric categorical variables"
        exit 109
    }
    capture confirm numeric variable `colvar'
    if _rc {
        noisily display as error "rowvar and colvar must be numeric categorical variables"
        exit 109
    }

    * Accept excel() as synonym
    if "`xlsx'" == "" & "`excel'" != "" local xlsx "`excel'"
    local _has_xlsx = "`xlsx'" != ""
    if "`open'" != "" & !`_has_xlsx' {
        noisily display as error "open requires xlsx() or excel()"
        exit 198
    }

    * Resolve persistent defaults
    if `boldp' == -1 & "$TABTOOLS_BOLDP" != "" local boldp = $TABTOOLS_BOLDP
    if `digits' == -1 {
        if "$TABTOOLS_DIGITS" != "" local digits = $TABTOOLS_DIGITS
        else local digits = 1
    }
    if `digits' < 0 | `digits' > 6 {
        noisily display as error "digits() must be between 0 and 6"
        exit 198
    }
    if `boldp' != -1 & (`boldp' <= 0 | `boldp' >= 1) {
        noisily display as error "boldp() must be between 0 and 1"
        exit 198
    }

    * Defaults
    if "`sheet'" == "" local sheet "Crosstab"
    _tabtools_validate_sheet "`sheet'" "sheet()"
    if `_has_xlsx' {
        if !strmatch(lower("`xlsx'"), "*.xlsx") {
            noisily display as error "xlsx() must have .xlsx extension"
            exit 198
        }
        _tabtools_validate_path "`xlsx'" "xlsx()"
    }
    if "`csv'" != "" _tabtools_validate_path "`csv'" "csv()"

    local _pct_modes = 0
    if "`colpct'" != "" local ++_pct_modes
    if "`rowpct'" != "" local ++_pct_modes
    if "`totalpct'" != "" local ++_pct_modes
    if `_pct_modes' > 1 {
        noisily display as error "Specify only one of colpct, rowpct, or totalpct"
        exit 198
    }

    * Default to column percentages
    if "`colpct'" == "" & "`rowpct'" == "" & "`totalpct'" == "" local colpct "colpct"

    marksample touse, novarlist
    if "`missing'" == "" markout `touse' `rowvar' `colvar'

    quietly count if `touse'
    if r(N) == 0 {
        noisily display as error "no observations"
        noisily display as error "Hint: check your {bf:if}/{bf:in} conditions and whether variables have missing values"
        exit 2000
    }

    * Resolve formatting
    _tabtools_resolve_format, theme(`theme') borderstyle(`borderstyle')

**# Cross-tabulation
    preserve
    qui keep if `touse'
    local _missing_opt ""
    if "`missing'" != "" local _missing_opt "missing"

    * Get levels
    qui levelsof `rowvar', local(row_levels) `missing'
    qui levelsof `colvar', local(col_levels) `missing'
    local n_rows : word count `row_levels'
    local n_cols : word count `col_levels'
    if ("`or'" != "" | "`rr'" != "" | "`rd'" != "") & (`n_rows' != 2 | `n_cols' != 2) {
        noisily display as error "or, rr, and rd require a 2x2 table"
        restore
        exit 198
    }

    * Row and column labels
    forvalues r = 1/`n_rows' {
        local _rlv : word `r' of `row_levels'
        if "`label'" != "" {
            if substr("`_rlv'", 1, 1) == "." local _rlbl "Missing"
            else local _rlbl : label (`rowvar') `_rlv'
        }
        else {
            if substr("`_rlv'", 1, 1) == "." local _rlbl "Missing"
            else local _rlbl "`_rlv'"
        }
        if "`_rlbl'" == "" local _rlbl "`_rlv'"
        local rlabel_`r' "`_rlbl'"
    }
    forvalues c = 1/`n_cols' {
        local _clv : word `c' of `col_levels'
        if "`label'" != "" {
            if substr("`_clv'", 1, 1) == "." local _clbl "Missing"
            else local _clbl : label (`colvar') `_clv'
        }
        else {
            if substr("`_clv'", 1, 1) == "." local _clbl "Missing"
            else local _clbl "`_clv'"
        }
        if "`_clbl'" == "" local _clbl "`_clv'"
        local clabel_`c' "`_clbl'"
    }

    * Variable labels
    local _rowlabel : variable label `rowvar'
    if "`_rowlabel'" == "" local _rowlabel "`rowvar'"
    local _collabel : variable label `colvar'
    if "`_collabel'" == "" local _collabel "`colvar'"

    * Tabulate with matcell
    tempname _freq _rowsum _colsum
    qui tab `rowvar' `colvar' [`weight'`exp'], matcell(`_freq') `_missing_opt'
    local _total_n = r(N)

    * Row and column marginals
    matrix `_rowsum' = `_freq' * J(`n_cols', 1, 1)
    matrix `_colsum' = J(1, `n_rows', 1) * `_freq'

    * Chi-squared / Fisher's exact test
    local _chi2 .
    local _p .
    local _test_name ""
    * Check expected cell counts for auto-Fisher
    local _min_expected = .
    forvalues r = 1/`n_rows' {
        forvalues c = 1/`n_cols' {
            local _exp_cell = `_rowsum'[`r',1] * `_colsum'[1,`c'] / `_total_n'
            if `_exp_cell' < `_min_expected' | missing(`_min_expected') {
                local _min_expected = `_exp_cell'
            }
        }
    }

    if "`fisher'" != "" | "`exact'" != "" | `_min_expected' < 5 {
        qui tab `rowvar' `colvar' [`weight'`exp'], exact `_missing_opt'
        local _p = r(p_exact)
        local _test_name "Fisher's exact test"
    }
    else {
        qui tab `rowvar' `colvar' [`weight'`exp'], chi2 `_missing_opt'
        local _chi2 = r(chi2)
        local _p = r(p)
        local _test_name "Pearson's chi-squared test"
    }
    return scalar chi2 = `_chi2'
    return scalar p = `_p'

    * Association measures for 2x2 tables
    local _or .
    local _rr .
    local _rd .
    if `n_rows' == 2 & `n_cols' == 2 {
        if "`or'" != "" {
            qui cc `rowvar' `colvar' if `touse' [`weight'`exp']
            local _or = r(or)
            local _or_lo = r(lb_or)
            local _or_hi = r(ub_or)
            return scalar or = `_or'
        }
        if "`rr'" != "" | "`rd'" != "" {
            qui cs `rowvar' `colvar' if `touse' [`weight'`exp']
            if "`rr'" != "" {
                local _rr = r(rr)
                local _rr_lo = r(lb_rr)
                local _rr_hi = r(ub_rr)
                return scalar rr = `_rr'
            }
            if "`rd'" != "" {
                local _rd = r(rd)
                local _rd_lo = r(lb_rd)
                local _rd_hi = r(ub_rd)
                return scalar rd = `_rd'
            }
        }
    }

    * Trend test (Spearman rank correlation)
    local _p_trend .
    if "`trend'" != "" {
        * Assign ordinal scores to column levels and test rank correlation
        tempvar _trend_score
        qui egen `_trend_score' = group(`colvar')
        capture qui spearman `rowvar' `_trend_score'
        if !_rc {
            local _p_trend = r(p)
        }
        drop `_trend_score'
        return scalar p_trend = `_p_trend'
    }

**# Build Output Dataset
    clear
    local out_ncols = `n_cols' + 2
    forvalues c = 1/`out_ncols' {
        qui gen str244 c`c' = ""
    }
    qui gen str244 title = ""

    * Row 1: Title
    local row 1
    qui set obs `row'
    qui replace title = "`title'" in `row'

    * Row 2: Column headers
    local row = `row' + 1
    qui set obs `row'
    qui replace c1 = "`_rowlabel'" in `row'
    forvalues c = 1/`n_cols' {
        local _col = `c' + 1
        qui replace c`_col' = "`clabel_`c''" in `row'
    }
    qui replace c`out_ncols' = "Total" in `row'

    * Data rows
    forvalues r = 1/`n_rows' {
        local row = `row' + 1
        qui set obs `row'
        qui replace c1 = "`rlabel_`r''" in `row'
        local _row_total = `_rowsum'[`r', 1]
        forvalues c = 1/`n_cols' {
            local _col = `c' + 1
            local _freq_val = `_freq'[`r', `c']
            local _col_total = `_colsum'[1, `c']
            local _cell_str = string(`_freq_val', "%11.0fc")
            if "`colpct'" != "" {
                local _pct = string(`_freq_val' / `_col_total' * 100, "%5.`digits'f")
                local _cell_str "`_cell_str' (`_pct'%)"
            }
            else if "`rowpct'" != "" {
                local _pct = string(`_freq_val' / `_row_total' * 100, "%5.`digits'f")
                local _cell_str "`_cell_str' (`_pct'%)"
            }
            else if "`totalpct'" != "" {
                local _pct = string(`_freq_val' / `_total_n' * 100, "%5.`digits'f")
                local _cell_str "`_cell_str' (`_pct'%)"
            }
            qui replace c`_col' = strtrim("`_cell_str'") in `row'
        }
        qui replace c`out_ncols' = string(`_row_total', "%11.0fc") in `row'
    }

    * Total row
    local row = `row' + 1
    qui set obs `row'
    qui replace c1 = "Total" in `row'
    forvalues c = 1/`n_cols' {
        local _col = `c' + 1
        qui replace c`_col' = string(`_colsum'[1,`c'], "%11.0fc") in `row'
    }
    qui replace c`out_ncols' = string(`_total_n', "%11.0fc") in `row'

    * Track first measure row for formatting
    local _first_measure_row = `row' + 1

    * Test result row
    local row = `row' + 1
    qui set obs `row'
    local _p_row = `row'
    local _trend_row = 0
    local _p_str = cond(`_p' < 0.001, "<0.001", string(`_p', "%5.3f"))
    if "`_test_name'" == "Fisher's exact test" {
        qui replace c1 = "`_test_name': p = `_p_str'" in `row'
    }
    else {
        local _chi2_str = string(`_chi2', "%6.2f")
        qui replace c1 = "`_test_name': chi2 = `_chi2_str', p = `_p_str'" in `row'
    }

    * Association measure row
    if !missing(`_or') {
        local row = `row' + 1
        qui set obs `row'
        qui replace c1 = "OR = " + string(`_or', "%5.`digits'f") + " (95% CI: " + string(`_or_lo', "%5.`digits'f") + ", " + string(`_or_hi', "%5.`digits'f") + ")" in `row'
    }
    if !missing(`_rr') {
        local row = `row' + 1
        qui set obs `row'
        qui replace c1 = "RR = " + string(`_rr', "%5.`digits'f") + " (95% CI: " + string(`_rr_lo', "%5.`digits'f") + ", " + string(`_rr_hi', "%5.`digits'f") + ")" in `row'
    }
    if !missing(`_rd') {
        local row = `row' + 1
        qui set obs `row'
        qui replace c1 = "RD = " + string(`_rd', "%5.`=`digits'+2'f") + " (95% CI: " + string(`_rd_lo', "%5.`=`digits'+2'f") + ", " + string(`_rd_hi', "%5.`=`digits'+2'f") + ")" in `row'
    }
    if !missing(`_p_trend') {
        local row = `row' + 1
        qui set obs `row'
        local _trend_row = `row'
        local _pt_str = cond(`_p_trend' < 0.001, "<0.001", string(`_p_trend', "%5.3f"))
        qui replace c1 = "P for trend = `_pt_str'" in `row'
    }

    local num_rows = _N
    local num_cols = `out_ncols' + 1
    local _header_row = 2
    local _data_start = `_header_row' + 1
    local _total_row = `_data_start' + `n_rows'
    local _first_measure_row = `_total_row' + 1

    * Build return matrix
    tempname _rtable
    matrix `_rtable' = `_freq'
    capture matrix rownames `_rtable' = `row_levels'
    capture matrix colnames `_rtable' = `col_levels'
    order title c*

**# Console Display
    if !`_has_xlsx' | "`display'" != "" {
        noisily _tabtools_console_display `out_ncols' `"`title'"'
    }

**# CSV Export
    if "`csv'" != "" {
        export delimited using "`csv'", replace
        noisily display as text "CSV exported to `csv'"
    }

**# Frame Output
    if `"`frame'"' != "" {
        _tabtools_frame_put `"`frame'"'
        local frame "`_frame_name'"
    }

**# Excel Export
    if `_has_xlsx' {
        order title c*
        capture export excel using "`xlsx'", sheet("`sheet'") sheetreplace
        if _rc {
            local _export_rc = _rc
            noisily display as error "Failed to export to `xlsx'"
            noisily display as error "Hint: ensure the xlsx file is not open in another application"
            restore
            exit `_export_rc'
        }

        capture {
            putexcel set "`xlsx'", sheet("`sheet'") modify

            _tabtools_build_col_letters `num_cols'
            local letters "`result'"
            local lastcol : word `num_cols' of `letters'

            putexcel (A1:`lastcol'1), merge bold txtwrap left vcenter font("`_font'", `=`_fontsize'+2')
            putexcel (B`_header_row':`lastcol'`_header_row'), border(top, `_hborder') bold hcenter font("`_font'", `_fontsize')
            putexcel (B`_header_row':`lastcol'`_header_row'), border(bottom, `_hborder')
            putexcel (A`_data_start':`lastcol'`num_rows'), font("`_font'", `_fontsize')
            putexcel (C`_data_start':`lastcol'`num_rows'), hcenter

            * Border above total row and below it
            putexcel (B`_total_row':`lastcol'`_total_row'), border(top, `_hborder')
            putexcel (B`_total_row':`lastcol'`_total_row'), border(bottom, `_hborder')

            * Merge and format measure rows (chi-sq, OR, RR, etc.)
            local _fm = `_first_measure_row'
            if `_fm' <= `num_rows' {
                putexcel (B`_fm':`lastcol'`_fm'), border(top, `_hborder')
                forvalues _mr = `_fm'/`num_rows' {
                    putexcel (B`_mr':`lastcol'`_mr'), merge left vcenter
                }
                putexcel (B`num_rows':`lastcol'`num_rows'), border(bottom, `_hborder')
            }

            if `boldp' != -1 & !missing(`_p') & `_p' < `boldp' {
                putexcel (B`_p_row':`lastcol'`_p_row'), bold
            }
            if `boldp' != -1 & !missing(`_p_trend') & `_p_trend' < `boldp' & `_trend_row' > 0 {
                putexcel (B`_trend_row':`lastcol'`_trend_row'), bold
            }

            * Column widths via Mata
            mata: b = xl()
            mata: b.load_book("`xlsx'")
            mata: b.set_sheet("`sheet'")
            mata: b.set_column_width(1, 1, 1)
            local _rlbl_maxlen = strlen("`_rowlabel'")
            forvalues _ri = 1/`n_rows' {
                local _rlen = strlen("`rlabel_`_ri''")
                if `_rlen' > `_rlbl_maxlen' local _rlbl_maxlen = `_rlen'
            }
            local _b_width = max(12, ceil(`_rlbl_maxlen' * 0.85) + 2)
            mata: b.set_column_width(2, 2, `_b_width')
            forvalues _ci = 3/`num_cols' {
                mata: b.set_column_width(`_ci', `_ci', 14)
            }
            mata: b.close_book()
            capture mata: mata drop b

            if "`zebra'" != "" {
                local _zebracolor "237 242 249"
                if "$TABTOOLS_ZEBRACOLOR" != "" local _zebracolor "$TABTOOLS_ZEBRACOLOR"
                forvalues _zr = `=`_data_start'+1'(2)`_total_row' {
                    putexcel (B`_zr':`lastcol'`_zr'), fpattern(solid, "`_zebracolor'")
                }
            }

            if `"`footnote'"' != "" {
                _tabtools_footnote `"`footnote'"' "`lastcol'" `num_rows' "`_font'" `_fontsize'
            }

            putexcel clear
        }
        if _rc {
            local _format_rc = _rc
            capture putexcel clear
            capture mata: mata drop b
            noisily display as error "Excel formatting failed with error `_format_rc'"
            restore
            exit `_format_rc'
        }
        capture confirm file "`xlsx'"
        if _rc {
            noisily display as error "Export command succeeded but file not found"
            restore
            exit 601
        }
        noisily display as text "Exported to " as result `"`xlsx'"' as text ", sheet " as result `"`sheet'"'
    }

    if "`open'" != "" & `_has_xlsx' _tabtools_open_file "`xlsx'"

    restore

**# Return Results
    capture return matrix table = `_rtable'
    return scalar N = `_total_n'
    if `_has_xlsx' {
        return local xlsx "`xlsx'"
        return local sheet "`sheet'"
    }
    if "`frame'" != "" return local frame "`frame'"

    * Methods paragraph
    local _methods "Cross-tabulation was performed for `_rowlabel' by `_collabel'."
    local _methods "`_methods' Statistical significance was assessed using `_test_name'."
    if !missing(`_or') local _methods "`_methods' The odds ratio comparing column `clabel_2' versus `clabel_1' for row `rlabel_2' versus `rlabel_1' is reported with a 95% confidence interval."
    if !missing(`_rr') local _methods "`_methods' The risk ratio comparing column `clabel_2' versus `clabel_1' for row `rlabel_2' versus `rlabel_1' is reported with a 95% confidence interval."
    if !missing(`_rd') local _methods "`_methods' The risk difference comparing column `clabel_2' versus `clabel_1' for row `rlabel_2' versus `rlabel_1' is reported with a 95% confidence interval."
    if !missing(`_p_trend') local _methods "`_methods' A trend test across ordered column levels is also reported."
    local _methods "`_methods' Analysis performed in Stata `c(stata_version)' (StataCorp, College Station, TX)."
    return local methods "`_methods'"

} // end capture noisily
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
