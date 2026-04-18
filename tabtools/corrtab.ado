*! corrtab Version 1.0.7  2026/04/18
*! Correlation matrix table
*! Author: Timothy P Copeland
*! Program class: rclass

capture program list _tabtools_guard
if _rc {
    capture findfile _tabtools_guard.ado
    if _rc == 0 {
        run "`r(fn)'"
    }
    else {
        display as error "_tabtools_guard.ado not found; reinstall tabtools"
        exit 111
    }
}

program define corrtab, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        _tabtools_guard enter

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

        if "`sheet'" == "" local sheet "Correlation"
        _tabtools_validate_sheet "`sheet'" "sheet()"
        if `_has_xlsx' _tabtools_validate_path "`xlsx'" "xlsx()"
        if "`csv'" != "" _tabtools_validate_path "`csv'" "csv()"

        _tabtools_settings_resolve, theme(`theme') borderstyle(`borderstyle') ///
            headercolor(`headercolor') zebracolor(`zebracolor') ///
            `headershade' `zebra' digits(`digits')

        if "`lower'" == "" & "`upper'" == "" & "`full'" == "" local lower "lower"
        if "`star'" == "" & "`pvalues'" == "" local star "0.001 0.01 0.05"
        local n_stars : word count `star'

        marksample touse
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
            quietly spearman `varlist' if `_pwtouse', pw matrix
            matrix `_corr' = r(Rho)
            matrix `_pmat' = J(`nvars', `nvars', .)
            forvalues i = 1/`nvars' {
                forvalues j = `=`i' + 1'/`nvars' {
                    local _vi : word `i' of `varlist'
                    local _vj : word `j' of `varlist'
                    local _cn = `_nmat'[`i', `j']
                    if `_cn' < 30 {
                        quietly spearman `_vi' `_vj' if `_pwtouse'
                        matrix `_pmat'[`i', `j'] = r(p)
                        matrix `_pmat'[`j', `i'] = r(p)
                    }
                    else {
                        local _r = `_corr'[`i', `j']
                        if abs(`_r') < 1 {
                            local _t = `_r' * sqrt((`_cn' - 2) / (1 - (`_r')^2))
                            matrix `_pmat'[`i', `j'] = 2 * ttail(`_cn' - 2, abs(`_t'))
                            matrix `_pmat'[`j', `i'] = `_pmat'[`i', `j']
                        }
                        else {
                            matrix `_pmat'[`i', `j'] = 0
                            matrix `_pmat'[`j', `i'] = 0
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
                        if `_cn' > 2 & abs(`_r') < 1 {
                            local _t = `_r' * sqrt((`_cn' - 2) / (1 - (`_r')^2))
                            matrix `_pmat'[`i', `j'] = 2 * ttail(`_cn' - 2, abs(`_t'))
                        }
                        else if abs(`_r') >= 1 {
                            matrix `_pmat'[`i', `j'] = 0
                        }
                    }
                    else {
                        matrix `_pmat'[`i', `j'] = .
                    }
                }
            }
        }

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
                        quietly replace c`_col' = "1.00" in `row'
                    }
                    else {
                        local _r = `_corr'[`i', `j']
                        local _p = `_pmat'[`i', `j']
                        local _rstr = string(`_r', "%6.`_digits'f")
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

        local _label_width = max(12, `_max_label_len' * 0.85 + 2)
        local _data_width = cond("`pvalues'" != "", 14, 10)
        local _data_width = max(`_data_width', min(24, ceil(`_max_label_len' * 0.80) + 2))

        _tabtools_table_spec_init, title(`"`title'"') headerstart(2) headerend(2) ///
            datastart(3) numcols(`out_ncols') footnote(`"`footnote'"') ///
            starnote(`"`_star_note'"') tablestart(1) datafontstart(1) ///
            centerstart(3) bottomstart(2) hastitle(1) widthmode(fixed) ///
            widths("1 `_label_width' `_data_width'") exportxlsx(`"`xlsx'"') ///
            exportcsv(`"`csv'"') exportframe(`"`frame'"') exportdisplay("`display'") ///
            sheetreplace(1)

        _tabtools_export, xlsx(`"`xlsx'"') sheet(`"`sheet'"') csv(`"`csv'"') ///
            frame(`"`frame'"') `display' `open' replace

        restore

        return matrix C = `_corr'
        capture return matrix P = `_pmat'
        capture return matrix N = `_nmat'
        if `_has_xlsx' {
            return local xlsx "`xlsx'"
            return local sheet "`sheet'"
        }
        if "`_tabtools_export_frame'" != "" {
            return local frame "`_tabtools_export_frame'"
        }

        local _method_type = cond("`spearman'" != "", "Spearman rank", "Pearson")
        local _methods "`_method_type' correlation coefficients are reported."
        if "`star'" != "" local _methods "`_methods' Significance levels: `_star_note'."
        local _methods "`_methods' Analysis performed in Stata `c(stata_version)' (StataCorp, College Station, TX)."
        return local methods "`_methods'"
    }
    local rc = _rc
    _tabtools_guard exit, rc(`rc') noexit
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
