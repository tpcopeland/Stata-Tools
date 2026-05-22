*! corrtab Version 1.3.0  2026/05/23
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
            csv(string) FRAme(string) DISplay open]

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
        matrix `_nmat' = J(`nvars', `nvars', 0)
        forvalues i = 1/`nvars' {
            forvalues j = `i'/`nvars' {
                local _vi : word `i' of `varlist'
                local _vj : word `j' of `varlist'
                quietly count if `_pwtouse' & !missing(`_vi') & !missing(`_vj')
                matrix `_nmat'[`i', `j'] = r(N)
                matrix `_nmat'[`j', `i'] = r(N)
            }
        }
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

        local _diag_str = string(1, "%6.`digits'f")
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
                        local _rstr = string(`_r', "%6.`digits'f")
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

        if !`_has_xlsx' | "`display'" != "" {
            noisily _tabtools_console_display `out_ncols' `"`title'"'
            if `"`_star_note'"' != "" noisily display as text `"`_star_note'"'
            if `"`footnote'"' != "" noisily display as text `"`footnote'"'
            noisily display as text ""
        }

        if "`csv'" != "" {
            export delimited using "`csv'", replace
            capture confirm file "`csv'"
            if _rc {
                noisily display as error "CSV export completed but file was not created"
                restore
                exit 601
            }
        }

        if `"`frame'"' != "" {
            _tabtools_frame_put `"`frame'"'
            local frame "`_frame_name'"
        }

        return matrix C = `_corr'
        capture return matrix P = `_pmat'
        capture return matrix N = `_nmat'
        if "`frame'" != "" return local frame "`frame'"

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
            capture noisily _tabtools_xlsx_write_current using "`xlsx'", sheet("`sheet'") book(b)
            if _rc {
                local _export_rc = _rc
                noisily display as error "Failed to export to `xlsx'"
                noisily display as error "Hint: ensure the xlsx file is not open in another application"
                restore
                exit `_export_rc'
            }

            capture {
                * Column widths
                mata: b.set_column_width(1, 1, 1)
                mata: b.set_column_width(2, 2, `_label_width')
                forvalues _wc = 3/`num_cols' {
                    mata: b.set_column_width(`_wc', `_wc', `_data_width')
                }

                * Font for entire table
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
                mata: b.set_text_wrap(`_header_row', (2,`num_cols'), "on")

                * Data alignment
                if `num_rows' >= `_data_start' & `num_cols' >= 3 {
                    mata: b.set_horizontal_align((`_data_start',`num_rows'), (3,`num_cols'), "center")
                }

                * Bottom border
                mata: b.set_bottom_border(`num_rows', (2,`num_cols'), "`_hborder'")

                * Header background
                if "`headershade'" != "" {
                    mata: b.set_fill_pattern(`_header_row', (2,`num_cols'), "solid", "`_headercolor'")
                }

                * Zebra striping
                if "`zebra'" != "" {
                    forvalues _zr = `=`_data_start'+1'(2)`num_rows' {
                        mata: b.set_fill_pattern(`_zr', (2,`num_cols'), "solid", "`_zebracolor'")
                    }
                }

                * Footnotes
                local _foot_row = `num_rows'
                local _fn_fontsize = max(`_fontsize' - 2, 6)
                if `"`_star_note'"' != "" {
                    local _foot_row = `_foot_row' + 1
                    mata: b.put_string(`_foot_row', 2, `"`_star_note'"')
                    mata: b.set_sheet_merge("`sheet'", (`_foot_row',`_foot_row'), (2,`num_cols'))
                    mata: b.set_horizontal_align(`_foot_row', 2, "left")
                    mata: b.set_vertical_align(`_foot_row', 2, "center")
                    mata: b.set_text_wrap(`_foot_row', 2, "on")
                    mata: b.set_font(`_foot_row', 2, "`_font'", `_fn_fontsize')
                    mata: b.set_font_italic(`_foot_row', 2, "on")
                }
                if `"`footnote'"' != "" {
                    local _foot_row = `_foot_row' + 1
                    mata: b.put_string(`_foot_row', 2, `"`footnote'"')
                    mata: b.set_sheet_merge("`sheet'", (`_foot_row',`_foot_row'), (2,`num_cols'))
                    mata: b.set_horizontal_align(`_foot_row', 2, "left")
                    mata: b.set_vertical_align(`_foot_row', 2, "center")
                    mata: b.set_text_wrap(`_foot_row', 2, "on")
                    mata: b.set_font(`_foot_row', 2, "`_font'", `_fn_fontsize')
                    mata: b.set_font_italic(`_foot_row', 2, "on")
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
