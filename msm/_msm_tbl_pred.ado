*! _msm_tbl_pred Version 1.1.0  2026/06/14
program define _msm_tbl_pred, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _restore_needed = 0
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

    preserve
    local _restore_needed = 1
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
        local _widths ""
        forvalues _ci = 1/`n_cols' {
            local _widths "`_widths' `_w_`_ci''"
        }
        _msm_xlsx_colwidths, object(_msm_xl) widths(`_widths')

        * Convert period + estimate cells to numeric (skip CI columns)
        forvalues _r = `data_start'/`total_rows' {
            * Column A (period)
            local _cellstr = A[`_r']
            if `"`_cellstr'"' != "" & `"`_cellstr'"' != "." {
                local _cellnum = real("`_cellstr'")
                if `_cellnum' != . {
                    _msm_xlsx_put_number, object(_msm_xl) row(`_r') ///
                        col(1) value(`_cellnum')
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
                    if `"`nformat'"' != "" {
                        _msm_xlsx_put_number, object(_msm_xl) row(`_r') ///
                            col(`_col_idx') value(`_cellnum') ///
                            nformat("`nformat'")
                    }
                    else {
                        _msm_xlsx_put_number, object(_msm_xl) row(`_r') ///
                            col(`_col_idx') value(`_cellnum')
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
        local _restore_needed = 0
        exit `saved_rc'
    }
    capture mata: mata drop _msm_xl

    * Mata xl() formatting
    capture {
        mata: b = xl()
        mata: b.load_book("`xlsx'")
        mata: b.set_sheet("`sheet'")

        * Font
        mata: b.set_font((1,`total_rows'), (1,`n_cols'), "`font'", `fontsize')
        mata: b.set_font((1,1), (1,`n_cols'), "`font'", `=`fontsize'+2')

        * Title
        mata: b.set_sheet_merge("`sheet'", (1,1), (1,`n_cols'))
        mata: b.set_text_wrap(1, 1, "on")
        mata: b.set_horizontal_align(1, 1, "left")
        mata: b.set_vertical_align(1, 1, "center")
        mata: b.set_font_bold(1, 1, "on")

        * Group header row 2
        mata: b.set_top_border(2, (1,`n_cols'), "`_hborder'")
        if "`strategy'" == "both" {
            mata: b.set_sheet_merge("`sheet'", (2,2), (2,3))
            mata: b.set_horizontal_align(2, 2, "center")
            mata: b.set_vertical_align(2, 2, "center")
            mata: b.set_font_bold(2, 2, "on")
            mata: b.set_text_wrap(2, 2, "on")
            mata: b.set_sheet_merge("`sheet'", (2,2), (4,5))
            mata: b.set_horizontal_align(2, 4, "center")
            mata: b.set_vertical_align(2, 4, "center")
            mata: b.set_font_bold(2, 4, "on")
            mata: b.set_text_wrap(2, 4, "on")
            if `has_diff' {
                mata: b.set_sheet_merge("`sheet'", (2,2), (6,7))
                mata: b.set_horizontal_align(2, 6, "center")
                mata: b.set_vertical_align(2, 6, "center")
                mata: b.set_font_bold(2, 6, "on")
                mata: b.set_text_wrap(2, 6, "on")
            }
        }
        else {
            mata: b.set_sheet_merge("`sheet'", (2,2), (2,3))
            mata: b.set_horizontal_align(2, 2, "center")
            mata: b.set_vertical_align(2, 2, "center")
            mata: b.set_font_bold(2, 2, "on")
            mata: b.set_text_wrap(2, 2, "on")
        }

        * Column headers (row 3)
        mata: b.set_font_bold(3, (1,`n_cols'), "on")
        mata: b.set_horizontal_align(3, (1,`n_cols'), "center")
        mata: b.set_vertical_align(3, (1,`n_cols'), "center")
        mata: b.set_text_wrap(3, (1,`n_cols'), "on")
        mata: b.set_fill_pattern(3, (1,`n_cols'), "solid", "219 229 241")
        mata: b.set_bottom_border(3, (1,`n_cols'), "`_hborder'")

        * Borders
        if "`borderstyle'" != "academic" {
            mata: b.set_left_border((2,`total_rows'), 1, "`borderstyle'")
            mata: b.set_right_border((2,`total_rows'), `n_cols', "`borderstyle'")
        }
        mata: b.set_bottom_border(`total_rows', (1,`n_cols'), "`_hborder'")

        * Data alignment
        if `total_rows' >= `data_start' {
            mata: b.set_horizontal_align((`data_start',`total_rows'), (1,`n_cols'), "center")
        }

        * Vertical separators
        if "`strategy'" == "both" & "`borderstyle'" != "academic" {
            mata: b.set_left_border((2,`total_rows'), 4, "`borderstyle'")
            if `has_diff' {
                mata: b.set_left_border((2,`total_rows'), 6, "`borderstyle'")
            }
        }

        * Zebra striping
        if "`zebra'" != "" {
            _msm_xlsx_zebra, object(b) startrow(`data_start') ///
                lastrow(`last_data') ncols(`n_cols')
        }

        * Footnote
        if `_has_footnote' {
            local _fn_fontsize = max(`fontsize' - 2, 6)
            _msm_xlsx_footnote, object(b) sheet("`sheet'") ///
                row(`footnote_row') ncols(`n_cols') ///
                footnote(`"`footnote'"') font("`font'") ///
                fontsize(`_fn_fontsize')
        }

        mata: b.close_book()
    }
    if _rc {
        local saved_rc = _rc
        capture mata: b.close_book()
        capture mata: mata drop b
        noisily display as error "Excel formatting failed with error `saved_rc'"
        restore
        local _restore_needed = 0
        exit `saved_rc'
    }
    capture mata: mata drop b

    restore
    local _restore_needed = 0
    display as text "  Sheet: `sheet'"

    } /* end capture noisily */
    local _rc = _rc
    if `_restore_needed' {
        capture restore
    }
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
