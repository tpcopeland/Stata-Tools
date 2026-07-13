*! corrtab Version 1.9.7  2026/07/10
*! Correlation matrix table
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define corrtab, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        capture putexcel close

        * Auto-load shared helper programs
        capture _tabtools_helpers_ready
        if _rc {
            capture findfile _tabtools_common.ado
            if _rc == 0 {
                run "`r(fn)'"
                capture _tabtools_helpers_ready
                if _rc {
                    display as error "_tabtools_common.ado failed to load fully; reinstall tabtools"
                    exit 111
                }
            }
            else {
                display as error "_tabtools_common.ado not found; reinstall tabtools"
                exit 111
            }
        }
        _tabtools_require_helpers

        syntax varlist(min=2 numeric) [if] [in], ///
            [xlsx(string) excel(string) sheet(string) ///
            SPEarman LOWer UPPer FULL ///
            STAR(numlist sort) PVALues DIGits(integer -1) ///
            title(string) ///
            FOOTnote(string) THEme(string) BORDERstyle(string) ///
            HEADERColor(string) ZEBRAColor(string) ZEBra HEADERShade ///
            csv(string) MARKdown(string) MDAPPend FRAme(string) open]

        if "`xlsx'" == "" & "`excel'" != "" local xlsx "`excel'"
        local _has_xlsx = (`"`xlsx'"' != "")
        if "`open'" != "" & !`_has_xlsx' {
            noisily display as error "open requires xlsx() or excel()"
            exit 198
        }

        if "`sheet'" == "" local sheet "Correlation"
        _tabtools_validate_sheet "`sheet'" "sheet()"
        if `_has_xlsx' {
            if !strmatch(lower("`xlsx'"), "*.xlsx") {
                noisily display as error "xlsx() must have .xlsx extension"
                exit 198
            }
            _tabtools_validate_path "`xlsx'" "xlsx()"
        }
        if "`csv'" != "" _tabtools_validate_path "`csv'" "csv()"
        if "`mdappend'" != "" & `"`markdown'"' == "" {
            noisily display as error "mdappend requires markdown()"
            exit 198
        }
        if `"`markdown'"' != "" {
            _tabtools_validate_path `"`markdown'"' "markdown()"
            local _md_lower = lower(`"`markdown'"')
            if !(strmatch(`"`_md_lower'"', "*.md") | ///
                 strmatch(`"`_md_lower'"', "*.markdown") | ///
                 strmatch(`"`_md_lower'"', "*.qmd") | ///
                 strmatch(`"`_md_lower'"', "*.rmd")) {
                noisily display as error "markdown() must specify a .md, .markdown, .qmd, or .rmd file"
                exit 198
            }
        }

        if `digits' == -1 {
            if "$TABTOOLS_DIGITS" != "" local digits = $TABTOOLS_DIGITS
            else local digits = 2
        }
        if `digits' < 0 | `digits' > 6 {
            noisily display as error "digits() must be between 0 and 6"
            exit 198
        }

        _tabtools_resolve_format, theme(`theme') borderstyle(`borderstyle') ///
            headershade(`headershade') zebra(`zebra')

        _tabtools_resolve_colors, headercolor(`"`headercolor'"') zebracolor(`"`zebracolor'"')

        local _shape_modes = 0
        if "`lower'" != "" local ++_shape_modes
        if "`upper'" != "" local ++_shape_modes
        if "`full'" != "" local ++_shape_modes
        if `_shape_modes' > 1 {
            noisily display as error "Specify only one of lower, upper, or full"
            exit 198
        }
        if "`lower'" == "" & "`upper'" == "" & "`full'" == "" local lower "lower"
        if "`pvalues'" != "" & "`star'" != "" {
            noisily display as error "star() cannot be combined with pvalues"
            exit 198
        }
        if "`star'" == "" & "`pvalues'" == "" local star "0.001 0.01 0.05"
        if "`star'" != "" {
            local _prev_star .
            foreach _sl of local star {
                if `_sl' <= 0 | `_sl' >= 1 {
                    noisily display as error "star() thresholds must be strictly between 0 and 1"
                    exit 198
                }
                if !missing(`_prev_star') & `_sl' <= `_prev_star' {
                    noisily display as error "star() thresholds must be strictly increasing"
                    exit 198
                }
                local _prev_star = `_sl'
            }
        }
        local n_stars : word count `star'

        marksample _pwtouse, novarlist

        quietly count if `_pwtouse'
        if r(N) == 0 {
            noisily display as error "no observations"
            noisily display as error ///
                "Hint: check your {bf:if}/{bf:in} conditions and whether variables have missing values"
            exit 2000
        }

        local nvars : word count `varlist'
        tempname _corr _pmat _nmat
        mata: st_matrix("`_nmat'", _corrtab_pairwise_n(tokens("`varlist'"), "`_pwtouse'"))
        matrix rownames `_nmat' = `varlist'
        matrix colnames `_nmat' = `varlist'

        if "`spearman'" != "" {
            matrix `_corr' = J(`nvars', `nvars', .)
            matrix `_pmat' = J(`nvars', `nvars', .)
            forvalues i = 1/`nvars' {
                if `_nmat'[`i', `i'] > 0 {
                    matrix `_corr'[`i', `i'] = 1
                }
                forvalues j = `=`i' + 1'/`nvars' {
                    local _vi : word `i' of `varlist'
                    local _vj : word `j' of `varlist'
                    local _cn = `_nmat'[`i', `j']
                    if `_cn' > 1 {
                        capture quietly spearman `_vi' `_vj' if `_pwtouse' & !missing(`_vi') & !missing(`_vj')
                        if !_rc {
                            matrix `_corr'[`i', `j'] = r(rho)
                            matrix `_corr'[`j', `i'] = r(rho)
                            matrix `_pmat'[`i', `j'] = r(p)
                            matrix `_pmat'[`j', `i'] = r(p)
                        }
                    }
                }
            }
        }
        else {
            quietly pwcorr `varlist' if `_pwtouse', sig
            matrix `_corr' = r(C)
            matrix `_pmat' = J(`nvars', `nvars', .)
            forvalues i = 1/`nvars' {
                forvalues j = 1/`nvars' {
                    if `i' != `j' {
                        local _r = `_corr'[`i', `j']
                        local _cn = `_nmat'[`i', `j']
                        if missing(`_r') | `_cn' <= 2 {
                            matrix `_pmat'[`i', `j'] = .
                        }
                        else if abs(`_r') < 1 {
                            local _t = `_r' * sqrt((`_cn' - 2) / (1 - (`_r')^2))
                            matrix `_pmat'[`i', `j'] = 2 * ttail(`_cn' - 2, abs(`_t'))
                        }
                        else if abs(`_r') == 1 {
                            matrix `_pmat'[`i', `j'] = 0
                        }
                    }
                    else {
                        matrix `_pmat'[`i', `j'] = .
                    }
                }
            }
        }
        matrix rownames `_corr' = `varlist'
        matrix colnames `_corr' = `varlist'
        matrix rownames `_pmat' = `varlist'
        matrix colnames `_pmat' = `varlist'

        local _max_label_len 0
        forvalues _vi = 1/`nvars' {
            local _vn : word `_vi' of `varlist'
            local _vlbl_`_vi' : variable label `_vn'
            if `"`_vlbl_`_vi''"' == "" local _vlbl_`_vi' "`_vn'"
            local _vl_len : strlen local _vlbl_`_vi'
            if `_vl_len' > `_max_label_len' local _max_label_len = `_vl_len'
        }

        local _star_note ""
        if "`star'" != "" & "`pvalues'" == "" {
            local _fn_count 0
            forvalues s = `n_stars'(-1)1 {
                local _sl : word `s' of `star'
                local _smark ""
                local _nstars = `n_stars' - `s' + 1
                forvalues _k = 1/`_nstars' {
                    local _smark "`_smark'*"
                }
                local ++_fn_count
                if `_fn_count' > 1 local _star_note "`_star_note', "
                local _star_note "`_star_note'`_smark' p<`_sl'"
            }
        }

        preserve
        clear

        local out_ncols = 1 + `nvars'
        forvalues c = 1/`out_ncols' {
            quietly generate str244 c`c' = ""
        }
        quietly generate str244 title = ""

        local row 1
        quietly set obs 1
        quietly replace title = `"`title'"' in 1

        local row = `row' + 1
        quietly set obs `row'
        quietly replace c1 = "" in `row'
        forvalues v = 1/`nvars' {
            local _col = `v' + 1
            quietly replace c`_col' = `"`_vlbl_`v''"' in `row'
        }

        local _diag_str = strtrim(string(1, "%21.`digits'f"))
        forvalues i = 1/`nvars' {
            local row = `row' + 1
            quietly set obs `row'
            quietly replace c1 = `"`_vlbl_`i''"' in `row'

            forvalues j = 1/`nvars' {
                local _col = `j' + 1
                local _show 0
                if "`full'" != "" local _show 1
                else if "`lower'" != "" & `j' < `i' local _show 1
                else if "`upper'" != "" & `j' > `i' local _show 1
                else if `i' == `j' local _show 1

                if `_show' {
                    if `i' == `j' {
                        if `_nmat'[`i', `i'] > 0 & !missing(`_corr'[`i', `i']) {
                            quietly replace c`_col' = "`_diag_str'" in `row'
                        }
                    }
                    else {
                        local _r = `_corr'[`i', `j']
                        local _p = `_pmat'[`i', `j']
                        local _rstr = strtrim(string(`_r', "%21.`digits'f"))
                        if "`pvalues'" != "" {
                            if !missing(`_p') {
                                local _pstr = cond(`_p' < 0.001, "<0.001", string(`_p', "%5.3f"))
                                local _rstr "`_rstr' (`_pstr')"
                            }
                        }
                        else if "`star'" != "" & !missing(`_p') {
                            local _stars_str ""
                            forvalues s = `n_stars'(-1)1 {
                                local _sl : word `s' of `star'
                                if `_p' < `_sl' local _stars_str "`_stars_str'*"
                            }
                            local _rstr "`_rstr'`_stars_str'"
                        }
                        quietly replace c`_col' = "`_rstr'" in `row'
                    }
                }
            }
        }

        noisily _tabtools_console_display `out_ncols' `"`title'"'
        if `"`_star_note'"' != "" noisily display as text `"`_star_note'"'
        if `"`footnote'"' != "" noisily display as text `"`footnote'"'
        noisily display as text ""

        if "`csv'" != "" {
            _tabtools_csv_write using "`csv'"
            capture confirm file "`csv'"
            if _rc {
                noisily display as error "CSV export completed but file was not created"
                restore
                exit 601
            }
        }

        local _ret_markdown ""
        local _ret_markdown_rows .
        local _ret_markdown_cols .
        if `"`markdown'"' != "" {
            local _mdappend_opt ""
            if "`mdappend'" != "" local _mdappend_opt "append"
            capture noisily _tabtools_markdown_write using `"`markdown'"', ///
                `_mdappend_opt' title(`"`title'"') footnote(`"`footnote'"') strictheaders
            if _rc {
                local _md_rc = _rc
                noisily display as error "Failed to export Markdown to `markdown'"
                restore
                exit `_md_rc'
            }
            local _ret_markdown `"`markdown'"'
            local _ret_markdown_rows = r(n_rows)
            local _ret_markdown_cols = r(n_cols)
            noisily display as text "Markdown exported to `markdown'"
        }

        if `"`frame'"' != "" {
            _tabtools_frame_put `"`frame'"'
            local frame "`_frame_name'"
        }

        return matrix C = `_corr'
        capture return matrix P = `_pmat'
        capture return matrix N = `_nmat'
        if "`frame'" != "" return local frame "`frame'"
        if `"`_ret_markdown'"' != "" {
            return local markdown `"`_ret_markdown'"'
            return scalar markdown_rows = `_ret_markdown_rows'
            return scalar markdown_cols = `_ret_markdown_cols'
        }

        local _method_type = cond("`spearman'" != "", "Spearman rank", "Pearson")
        local _methods "`_method_type' correlation coefficients are reported."
        if "`pvalues'" != "" local _methods "`_methods' Pairwise p-values are shown in parentheses."
        else if `"`_star_note'"' != "" local _methods "`_methods' Significance levels: `_star_note'."
        local _methods "`_methods' Analysis performed in Stata `c(stata_version)' (StataCorp, College Station, TX)."
        return local methods "`_methods'"

        local _xlsx_ok 0
        if `_has_xlsx' {
            local num_rows = _N
            local num_cols = `out_ncols' + 1
            local _header_row 2
            local _data_start 3
            local _label_width = max(12, ceil(`_max_label_len' * 0.85) + 2)
            local _data_width = cond("`pvalues'" != "", 14, 10)
            local _data_width = max(`_data_width', min(24, ceil(`_max_label_len' * 0.80) + 2))

            order title c*
            capture noisily _tabtools_xlsx_write using "`xlsx'", sheet("`sheet'") book(b)
            if _rc {
                local _export_rc = _rc
                noisily display as error "Failed to export to `xlsx'"
                noisily display as error "Hint: ensure the xlsx file is not open in another application"
                restore
                exit `_export_rc'
            }

            capture {
                local _hborder_code = 1
                if "`_hborder'" == "medium" local _hborder_code = 2
                if "`_hborder'" == "thick" local _hborder_code = 3
                if "`_hborder'" == "none" local _hborder_code = 4

                tempname _style_rules
                matrix `_style_rules' = (13, 1, 1, 1, 1, 1, 0, 0, 0)
                matrix `_style_rules' = `_style_rules' \ ///
                    (13, 1, 1, 2, 2, `_label_width', 0, 0, 0)
                forvalues _wc = 3/`num_cols' {
                    matrix `_style_rules' = `_style_rules' \ ///
                        (13, 1, 1, `_wc', `_wc', `_data_width', 0, 0, 0)
                }

                matrix `_style_rules' = `_style_rules' \ ///
                    (1, 1, `num_rows', 1, `num_cols', `_fontsize', 1, 0, 0) \ ///
                    (1, 1, 1, 1, `num_cols', `=`_fontsize'+2', 1, 0, 0) \ ///
                    (14, 1, 1, 1, `num_cols', 0, 0, 0, 0) \ ///
                    (2, 1, 1, 1, 1, 0, 1, 0, 0) \ ///
                    (4, 1, 1, 1, 1, 0, 1, 0, 0) \ ///
                    (5, 1, 1, 1, 1, 0, 1, 0, 0) \ ///
                    (6, 1, 1, 1, 1, 0, 2, 0, 0) \ ///
                    (8, `_header_row', `_header_row', 2, `num_cols', 0, `_hborder_code', 0, 0) \ ///
                    (9, `_header_row', `_header_row', 2, `num_cols', 0, `_hborder_code', 0, 0) \ ///
                    (2, `_header_row', `_header_row', 2, `num_cols', 0, 1, 0, 0) \ ///
                    (5, `_header_row', `_header_row', 2, `num_cols', 0, 2, 0, 0) \ ///
                    (4, `_header_row', `_header_row', 2, `num_cols', 0, 1, 0, 0)
                if `num_rows' >= `_data_start' & `num_cols' >= 3 {
                    matrix `_style_rules' = `_style_rules' \ ///
                        (5, `_data_start', `num_rows', 3, `num_cols', 0, 2, 0, 0)
                }
                matrix `_style_rules' = `_style_rules' \ ///
                    (9, `num_rows', `num_rows', 2, `num_cols', 0, `_hborder_code', 0, 0)
                if "`headershade'" != "" {
                    matrix `_style_rules' = `_style_rules' \ ///
                        (7, `_header_row', `_header_row', 2, `num_cols', 0, -1, 0, 0)
                }
                if "`zebra'" != "" {
                    forvalues _zr = `=`_data_start'+1'(2)`num_rows' {
                        matrix `_style_rules' = `_style_rules' \ ///
                            (7, `_zr', `_zr', 2, `num_cols', 0, -2, 0, 0)
                    }
                }

                local _foot_row = `num_rows'
                local _fn_fontsize = max(`_fontsize' - 2, 6)
                if `"`_star_note'"' != "" {
                    local _foot_row = `_foot_row' + 1
                    mata: b.put_string(`_foot_row', 2, `"`_star_note'"')
                    matrix `_style_rules' = `_style_rules' \ ///
                        (14, `_foot_row', `_foot_row', 2, `num_cols', 0, 0, 0, 0) \ ///
                        (5, `_foot_row', `_foot_row', 2, 2, 0, 1, 0, 0) \ ///
                        (6, `_foot_row', `_foot_row', 2, 2, 0, 2, 0, 0) \ ///
                        (4, `_foot_row', `_foot_row', 2, 2, 0, 1, 0, 0) \ ///
                        (1, `_foot_row', `_foot_row', 2, 2, `_fn_fontsize', 1, 0, 0) \ ///
                        (3, `_foot_row', `_foot_row', 2, 2, 0, 1, 0, 0)
                }
                if `"`footnote'"' != "" {
                    local _foot_row = `_foot_row' + 1
                    mata: b.put_string(`_foot_row', 2, `"`footnote'"')
                    matrix `_style_rules' = `_style_rules' \ ///
                        (14, `_foot_row', `_foot_row', 2, `num_cols', 0, 0, 0, 0) \ ///
                        (5, `_foot_row', `_foot_row', 2, 2, 0, 1, 0, 0) \ ///
                        (6, `_foot_row', `_foot_row', 2, 2, 0, 2, 0, 0) \ ///
                        (4, `_foot_row', `_foot_row', 2, 2, 0, 1, 0, 0) \ ///
                        (1, `_foot_row', `_foot_row', 2, 2, `_fn_fontsize', 1, 0, 0) \ ///
                        (3, `_foot_row', `_foot_row', 2, 2, 0, 1, 0, 0)
                }

                _tabtools_xlsx_apply_styles, book(b) sheet("`sheet'") ///
                    rules(`_style_rules') font("`_font'") ///
                    color1("`_headercolor'") color2("`_zebracolor'")
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
            noisily display as text "Exported to " as result `"`xlsx'"' ///
                as text ", sheet " as result `"`sheet'"'
        }

        restore

        if `_xlsx_ok' {
            return local xlsx "`xlsx'"
            return local sheet "`sheet'"
        }
        if "`open'" != "" & `_xlsx_ok' _tabtools_open_file "`xlsx'"
    }
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end

version 16.0
capture mata: mata drop _corrtab_pairwise_n()

mata:
mata set matastrict on

real matrix _corrtab_pairwise_n(string rowvector vars, string scalar tousevar)
{
    real matrix x, out
    real colvector ok_i, ok_j
    real scalar i, j, k

    x = st_data(., vars, tousevar)
    k = cols(x)
    out = J(k, k, 0)

    for (i = 1; i <= k; i++) {
        ok_i = (x[, i] :< .)
        for (j = i; j <= k; j++) {
            ok_j = (x[, j] :< .)
            out[i, j] = sum(ok_i :& ok_j)
            out[j, i] = out[i, j]
        }
    }

    return(out)
}

end
