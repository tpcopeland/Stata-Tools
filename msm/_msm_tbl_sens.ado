*! _msm_tbl_sens Version 1.2.2  2026/07/02
*! Author: Timothy P Copeland
program define _msm_tbl_sens, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _restore_needed = 0
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
    local _restore_needed = 1
    quietly {
        clear
        set obs `total_rows'

        gen str40 A = ""
        gen str24 B = ""

        * Row 1: title
        if `"`title'"' != "" {
            replace A = `"`title'"' in 1
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
        _msm_xlsx_colwidths, object(_msm_xl) widths(`_w_1' `_w_2')

        * Convert numeric value cells (skip CI range string)
        forvalues _r = 3/`total_rows' {
            local _cellstr = B[`_r']
            if `"`_cellstr'"' == "" | `"`_cellstr'"' == "." continue
            if strpos(`"`_cellstr'"', " - ") > 0 continue
            local _cellclean = subinstr(`"`_cellstr'"', ",", "", .)
            local _cellnum = real("`_cellclean'")
            if `_cellnum' != . {
                if `"`nformat'"' != "" {
                    _msm_xlsx_put_number, object(_msm_xl) row(`_r') ///
                        col(2) value(`_cellnum') nformat("`nformat'")
                }
                else {
                    _msm_xlsx_put_number, object(_msm_xl) row(`_r') ///
                        col(2) value(`_cellnum')
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
            nrows(`total_rows') ncols(2) font("`font'") ///
            fontsize(`fontsize') headerrow(2) hborder("`_hborder'") ///
            borderstyle("`borderstyle'")
        mata: b.set_bottom_border(`total_rows', (1,2), "`_hborder'")
        if `total_rows' >= 3 {
            mata: b.set_horizontal_align((3,`total_rows'), 2, "center")
        }

        if "`zebra'" != "" {
            _msm_xlsx_zebra, object(b) startrow(3) ///
                lastrow(`last_data') ncols(2)
        }

        if `_has_footnote' {
            local _fn_fontsize = max(`fontsize' - 2, 6)
            _msm_xlsx_footnote, object(b) sheet("`sheet'") ///
                row(`footnote_row') ncols(2) footnote(`"`footnote'"') ///
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
