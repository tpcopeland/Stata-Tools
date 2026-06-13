*! _msm_tbl_bal Version 1.1.0  2026/06/14
program define _msm_tbl_bal, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _restore_needed = 0
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
    local _restore_needed = 1
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
        local _widths ""
        forvalues _ci = 1/`n_cols' {
            local _widths "`_widths' `_w_`_ci''"
        }
        _msm_xlsx_colwidths, object(_msm_xl) widths(`_widths')

        * Convert SMD cells to numeric (skip % and Yes/empty cols)
        forvalues _r = 3/`last_data' {
            foreach _cvar in B C {
                local _cnum = cond("`_cvar'" == "B", 2, 3)
                local _cellstr = `_cvar'[`_r']
                if `"`_cellstr'"' == "" | `"`_cellstr'"' == "." continue
                local _cellclean = subinstr(`"`_cellstr'"', ",", "", .)
                local _cellnum = real("`_cellclean'")
                if `_cellnum' != . {
                    if `"`nformat'"' != "" {
                        _msm_xlsx_put_number, object(_msm_xl) row(`_r') ///
                            col(`_cnum') value(`_cellnum') ///
                            nformat("`nformat'")
                    }
                    else {
                        _msm_xlsx_put_number, object(_msm_xl) row(`_r') ///
                            col(`_cnum') value(`_cellnum')
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

        _msm_xlsx_title_header_style, object(b) sheet("`sheet'") ///
            nrows(`total_rows') ncols(5) font("`font'") ///
            fontsize(`fontsize') headerrow(2) hborder("`_hborder'") ///
            borderstyle("`borderstyle'")

        if "`borderstyle'" != "academic" {
            mata: b.set_left_border((2,`last_data'), 5, "`borderstyle'")
        }

        if `last_data' >= 3 {
            mata: b.set_horizontal_align((3,`last_data'), (2,5), "center")
        }
        mata: b.set_bottom_border(`last_data', (1,5), "`_hborder'")

        mata: b.set_sheet_merge("`sheet'", (`footer_row',`footer_row'), (1,5))
        mata: b.set_font_italic(`footer_row', 1, "on")

        if "`zebra'" != "" {
            _msm_xlsx_zebra, object(b) startrow(3) ///
                lastrow(`last_data') ncols(5)
        }

        if `_has_footnote' {
            local _fn_fontsize = max(`fontsize' - 2, 6)
            _msm_xlsx_footnote, object(b) sheet("`sheet'") ///
                row(`footnote_row') ncols(5) footnote(`"`footnote'"') ///
                font("`font'") fontsize(`_fn_fontsize')
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
