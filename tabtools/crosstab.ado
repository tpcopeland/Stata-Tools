*! crosstab Version 1.0.13  2026/04/27
*! Cross-tabulation with association measures
*! Author: Timothy P Copeland, Karolinska Institutet
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
        COLpct ROWpct TOTALpct EXact FIsher ///
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
    if "`zebra'" != "" {
        local _zebracolor "237 242 249"
        if "$TABTOOLS_ZEBRACOLOR" != "" local _zebracolor "$TABTOOLS_ZEBRACOLOR"
        _tabtools_validate_color "`_zebracolor'" "zebracolor()"
    }

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
    local _assoc_requested = ("`or'" != "" | "`rr'" != "" | "`rd'" != "")
    if `_assoc_requested' & (`n_rows' != 2 | `n_cols' != 2) {
        noisily display as error "or, rr, and rd require a 2x2 table"
        restore
        exit 198
    }
    if `_assoc_requested' {
        local _assoc_row0 : word 1 of `row_levels'
        local _assoc_row1 : word 2 of `row_levels'
        local _assoc_col0 : word 1 of `col_levels'
        local _assoc_col1 : word 2 of `col_levels'
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
        if `_assoc_requested' {
            tempvar _assoc_row01 _assoc_col01
            * Code the second observed row/column levels as 1 so OR/RR/RD
            * keep the documented orientation: row level 2 by column level 2.
            qui gen byte `_assoc_row01' = .
            qui replace `_assoc_row01' = 0 if `rowvar' == `_assoc_row0'
            qui replace `_assoc_row01' = 1 if `rowvar' == `_assoc_row1'
            qui gen byte `_assoc_col01' = .
            qui replace `_assoc_col01' = 0 if `colvar' == `_assoc_col0'
            qui replace `_assoc_col01' = 1 if `colvar' == `_assoc_col1'
        }
        if "`or'" != "" {
            qui cc `_assoc_row01' `_assoc_col01' [`weight'`exp']
            local _or = r(or)
            if missing(`_or') {
                noisily display as error "odds ratio is undefined for this 2x2 table"
                restore
                exit 498
            }
            local _or_lo = r(lb_or)
            local _or_hi = r(ub_or)
            return scalar or = `_or'
        }
        if "`rr'" != "" | "`rd'" != "" {
            qui cs `_assoc_row01' `_assoc_col01' [`weight'`exp']
            if "`rr'" != "" {
                local _rr = r(rr)
                if missing(`_rr') {
                    noisily display as error "risk ratio is undefined for this 2x2 table"
                    restore
                    exit 498
                }
                local _rr_lo = r(lb_rr)
                local _rr_hi = r(ub_rr)
                return scalar rr = `_rr'
            }
            if "`rd'" != "" {
                local _rd = r(rd)
                if missing(`_rd') {
                    noisily display as error "risk difference is undefined for this 2x2 table"
                    restore
                    exit 498
                }
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
	        if "`weight'" == "fweight" {
	            local _fwexp = substr("`exp'", 2, .)
	            qui expand `_fwexp'
	        }
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
                if `_col_total' > 0 {
                    local _pct = string(`_freq_val' / `_col_total' * 100, "%5.`digits'f")
                    local _cell_str "`_cell_str' (`_pct'%)"
                }
            }
            else if "`rowpct'" != "" {
                if `_row_total' > 0 {
                    local _pct = string(`_freq_val' / `_row_total' * 100, "%5.`digits'f")
                    local _cell_str "`_cell_str' (`_pct'%)"
                }
            }
            else if "`totalpct'" != "" {
                if `_total_n' > 0 {
                    local _pct = string(`_freq_val' / `_total_n' * 100, "%5.`digits'f")
                    local _cell_str "`_cell_str' (`_pct'%)"
                }
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

**# Return Results
    capture return matrix table = `_rtable'
    return scalar N = `_total_n'
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

**# Excel Export
    local _xlsx_ok 0
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

        * Pre-compute column B width
        local _rlbl_maxlen = strlen("`_rowlabel'")
        forvalues _ri = 1/`n_rows' {
            local _rlen = strlen("`rlabel_`_ri''")
            if `_rlen' > `_rlbl_maxlen' local _rlbl_maxlen = `_rlen'
        }
        local _b_width = max(12, ceil(`_rlbl_maxlen' * 0.85) + 2)

        capture {
            mata: b = xl()
            mata: b.load_book("`xlsx'")
            mata: b.set_sheet("`sheet'")

            * Column widths
            mata: b.set_column_width(1, 1, 1)
            mata: b.set_column_width(2, 2, `_b_width')
            forvalues _wc = 3/`num_cols' {
                mata: b.set_column_width(`_wc', `_wc', 14)
            }

            * Font
            mata: b.set_font((1,`num_rows'), (1,`num_cols'), "`_font'", `_fontsize')
            mata: b.set_font((1,1), (1,`num_cols'), "`_font'", `=`_fontsize'+2')

            * Title row
            mata: b.set_sheet_merge("`sheet'", (1,1), (1,`num_cols'))
            mata: b.set_font_bold(1, 1, "on")
            mata: b.set_text_wrap(1, 1, "on")
            mata: b.set_horizontal_align(1, 1, "left")
            mata: b.set_vertical_align(1, 1, "center")

            * Header row
            mata: b.set_top_border(`_header_row', (2,`num_cols'), "`_hborder'")
            mata: b.set_bottom_border(`_header_row', (2,`num_cols'), "`_hborder'")
            mata: b.set_font_bold(`_header_row', (2,`num_cols'), "on")
            mata: b.set_horizontal_align(`_header_row', (2,`num_cols'), "center")

            * Data alignment
            if `num_rows' >= `_data_start' & `num_cols' >= 3 {
                mata: b.set_horizontal_align((`_data_start',`num_rows'), (3,`num_cols'), "center")
            }

            * Total row borders
            mata: b.set_top_border(`_total_row', (2,`num_cols'), "`_hborder'")
            mata: b.set_bottom_border(`_total_row', (2,`num_cols'), "`_hborder'")

            * Measure rows (chi-sq, OR, RR, etc.)
            local _fm = `_first_measure_row'
            if `_fm' <= `num_rows' {
                mata: b.set_top_border(`_fm', (2,`num_cols'), "`_hborder'")
                forvalues _mr = `_fm'/`num_rows' {
                    mata: b.set_sheet_merge("`sheet'", (`_mr',`_mr'), (2,`num_cols'))
                    mata: b.set_horizontal_align(`_mr', 2, "left")
                    mata: b.set_vertical_align(`_mr', 2, "center")
                }
                mata: b.set_bottom_border(`num_rows', (2,`num_cols'), "`_hborder'")
            }

            * Bold p-value rows
            if `boldp' != -1 & !missing(`_p') & `_p' < `boldp' {
                mata: b.set_font_bold(`_p_row', (2,`num_cols'), "on")
            }
            if `boldp' != -1 & !missing(`_p_trend') & `_p_trend' < `boldp' & `_trend_row' > 0 {
                mata: b.set_font_bold(`_trend_row', (2,`num_cols'), "on")
            }

            * Zebra striping
            if "`zebra'" != "" {
                forvalues _zr = `=`_data_start'+1'(2)`_total_row' {
                    mata: b.set_fill_pattern(`_zr', (2,`num_cols'), "solid", "`_zebracolor'")
                }
            }

            * Footnote
            if `"`footnote'"' != "" {
                local _fn_row = `num_rows' + 1
                local _fn_fontsize = max(`_fontsize' - 2, 6)
                mata: b.put_string(`_fn_row', 2, `"`footnote'"')
                mata: b.set_sheet_merge("`sheet'", (`_fn_row',`_fn_row'), (2,`num_cols'))
                mata: b.set_horizontal_align(`_fn_row', 2, "left")
                mata: b.set_vertical_align(`_fn_row', 2, "center")
                mata: b.set_text_wrap(`_fn_row', 2, "on")
                mata: b.set_font(`_fn_row', 2, "`_font'", `_fn_fontsize')
                mata: b.set_font_italic(`_fn_row', 2, "on")
            }

            mata: b.close_book()
        }
        if _rc {
            local _format_rc = _rc
            capture mata: b.close_book()
            capture mata: mata drop b
            noisily display as error "Excel formatting failed with error `_format_rc'"
            restore
            exit `_format_rc'
        }
        capture mata: mata drop b
        capture confirm file "`xlsx'"
        if _rc {
            noisily display as error "Export command succeeded but file not found"
            restore
            exit 601
        }
        local _xlsx_ok 1
        noisily display as text "Exported to " as result `"`xlsx'"' as text ", sheet " as result `"`sheet'"'
    }

    restore

    if `_xlsx_ok' {
        return local xlsx "`xlsx'"
        return local sheet "`sheet'"
    }
    if "`open'" != "" & `_xlsx_ok' _tabtools_open_file "`xlsx'"

} // end capture noisily
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
