*! _msm_tbl_coef Version 1.0.3  2026/05/06
program define _msm_tbl_coef, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _restore_needed = 0
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
    _msm_coef_scale_label, model("`model'") `eform'
    local eff_label "`r(label)'"

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
    local _restore_needed = 1
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
            _msm_coef_display_name, name("`cname'")
            local display_name `"`r(display_name)'"'

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

            replace B = strtrim(string(`d_coef', "`fmt'")) in `row'

            local ci_lo_s = strtrim(string(`d_lo', "`fmt'"))
            local ci_hi_s = strtrim(string(`d_hi', "`fmt'"))
            replace C = "(" + "`ci_lo_s'" + "`sep'" + ///
                "`ci_hi_s'" + ")" in `row'

            _msm_coef_pvalue_string, pvalue(`p')
            local p_str "`r(pvalue)'"
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
        _msm_xlsx_colwidths, object(_msm_xl) ///
            widths(`_w_1' `_w_2' `_w_3' `_w_4')

        * Write coefficient estimates as proper Excel numerics
        forvalues _i = 1/`k' {
            local _r = `_i' + 2
            local _v_ii = `V'[`_i', `_i']
            if `_v_ii' <= 0 continue
            local _coef_val = `b'[1, `_i']
            if "`eform'" != "" local _coef_val = exp(`_coef_val')
            _msm_xlsx_put_number, object(_msm_xl) row(`_r') ///
                col(2) value(`_coef_val') nformat("`coef_xfmt'")
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

    * Pre-extract p-values for conditional formatting
    if `boldp' > 0 | `highlight' > 0 {
        forvalues _br = 3/`last_data' {
            local _pval = D[`_br']
            if `"`_pval'"' == "<0.001" {
                local _pnum_`_br' = 0.0001
            }
            else if `"`_pval'"' != "" & `"`_pval'"' != "." {
                local _pnum_`_br' = real("`_pval'")
            }
            else {
                local _pnum_`_br' = .
            }
        }
    }

    * Mata xl() formatting
    capture {
        mata: b = xl()
        mata: b.load_book("`xlsx'")
        mata: b.set_sheet("`sheet'")

        _msm_xlsx_title_header_style, object(b) sheet("`sheet'") ///
            nrows(`nrows') ncols(4) font("`font'") ///
            fontsize(`fontsize') headerrow(2) hborder("`_hborder'") ///
            borderstyle("`borderstyle'")

        mata: b.set_bottom_border(`nrows', (1,4), "`_hborder'")
        if "`borderstyle'" != "academic" {
            mata: b.set_left_border((2,`nrows'), 4, "`borderstyle'")
        }

        * Data alignment
        if `nrows' >= 3 {
            mata: b.set_horizontal_align((3,`nrows'), (2,3), "center")
            mata: b.set_horizontal_align((3,`nrows'), 4, "right")
        }

        * Zebra striping
        if "`zebra'" != "" {
            _msm_xlsx_zebra, object(b) startrow(3) ///
                lastrow(`last_data') ncols(4)
        }

        * Bold significant p-values
        if `boldp' > 0 {
            forvalues _br = 3/`last_data' {
                if `_pnum_`_br'' != . & `_pnum_`_br'' < `boldp' {
                    mata: b.set_font_bold(`_br', 4, "on")
                }
            }
        }

        * Highlight rows
        if `highlight' > 0 {
            forvalues _hr = 3/`last_data' {
                if `_pnum_`_hr'' != . & `_pnum_`_hr'' < `highlight' {
                    mata: b.set_fill_pattern(`_hr', (1,4), "solid", "255 255 204")
                }
            }
        }

        * Footnote
        if `_has_footnote' {
            local _fn_fontsize = max(`fontsize' - 2, 6)
            _msm_xlsx_footnote, object(b) sheet("`sheet'") ///
                row(`footnote_row') ncols(4) footnote(`"`footnote'"') ///
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
