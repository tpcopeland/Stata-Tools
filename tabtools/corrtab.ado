*! corrtab Version 1.0.2  2026/04/12
*! Correlation matrix table
*! Author: Timothy P Copeland
*! Program class: rclass

/*
DESCRIPTION:
    Generates a formatted correlation matrix with significance stars or
    p-values. Supports Pearson (default) and Spearman correlations.
    Exports lower/upper/full triangle to Excel with professional formatting.

SYNTAX:
    corrtab varlist [if] [in], xlsx(filename)
        [spearman lower upper full
        star(numlist) pvalues digits(int)
        sheet(string) title(string) subtitle(string)
        footnote(string) theme(string) borderstyle(string)
        csv(filename) frame(name) display open]
*/

program define corrtab, rclass
    version 17.0
    local _prev_varabbrev = c(varabbrev)
    set varabbrev off

    * Auto-load shared helper programs
    capture program list _tabtools_validate_path
    if _rc {
        capture findfile _tabtools_common.ado
        if _rc == 0 {
            run "`r(fn)'"
        }
        else {
            display as error "_tabtools_common.ado not found; reinstall tabtools"
            set varabbrev `_prev_varabbrev'
            exit 111
        }
    }

capture noisily {

**# Syntax and Validation
    syntax varlist(min=2 numeric) [if] [in], ///
        [xlsx(string) excel(string) sheet(string) ///
        SPEarman LOWer UPPer FULL ///
        STAR(numlist sort) PVALues DIGits(integer -1) ///
        title(string) SUBTitle(string) ///
        FOOTnote(string) THEme(string) BORDERStyle(string) ///
        HEADERColor(string) ZEBRAColor(string) ZEBra HEADERShade ///
        csv(string) FRAme(string) DISPlay open]

    if "`xlsx'" == "" & "`excel'" != "" local xlsx "`excel'"
    local _has_xlsx = "`xlsx'" != ""

    if "`sheet'" == "" local sheet "Correlation"

    * Resolve persistent defaults
    if `digits' == -1 {
        if "$TABTOOLS_DIGITS" != "" local digits = $TABTOOLS_DIGITS
        else local digits = 2
    }
    _tabtools_validate_sheet "`sheet'" "sheet()"
    if `_has_xlsx' _tabtools_validate_path "`xlsx'" "xlsx()"
    if "`csv'" != "" _tabtools_validate_path "`csv'" "csv()"

    * Default to lower triangle
    if "`lower'" == "" & "`upper'" == "" & "`full'" == "" local lower "lower"

    * Default star thresholds
    if "`star'" == "" & "`pvalues'" == "" local star "0.001 0.01 0.05"
    local n_stars : word count `star'

    marksample touse

    * Pairwise touse: respects if/in but not variable missingness
    marksample _pwtouse, novarlist

    quietly count if `_pwtouse'
    if r(N) == 0 {
        noisily display as error "no observations"
        noisily display as error "Hint: check your {bf:if}/{bf:in} conditions and whether variables have missing values"
        exit 2000
    }

    * Resolve formatting
    _tabtools_resolve_format, theme(`theme') borderstyle(`borderstyle') ///
        headershade(`headershade') zebra(`zebra')

    * Resolve header/zebra colors
    local _headercolor "219 229 241"
    local _zebracolor "237 242 249"
    if "$TABTOOLS_HEADERCOLOR" != "" local _headercolor "$TABTOOLS_HEADERCOLOR"
    if "$TABTOOLS_ZEBRACOLOR" != "" local _zebracolor "$TABTOOLS_ZEBRACOLOR"
    if "`headercolor'" != "" local _headercolor "`headercolor'"
    if "`zebracolor'" != "" local _zebracolor "`zebracolor'"

**# Compute Correlations
    local nvars : word count `varlist'
    local corr_cmd = cond("`spearman'" != "", "spearman", "pwcorr")

    * Get correlation matrix and p-values
    tempname _corr _pmat
    * Compute pairwise N matrix for accurate p-values
    tempname _nmat
    matrix `_nmat' = J(`nvars', `nvars', 0)
    forvalues i = 1/`nvars' {
        forvalues j = `i'/`nvars' {
            local _vi : word `i' of `varlist'
            local _vj : word `j' of `varlist'
            qui count if `_pwtouse' & !missing(`_vi') & !missing(`_vj')
            matrix `_nmat'[`i', `j'] = r(N)
            matrix `_nmat'[`j', `i'] = r(N)
        }
    }
    matrix rownames `_nmat' = `varlist'
    matrix colnames `_nmat' = `varlist'

    if "`spearman'" != "" {
        qui spearman `varlist' if `_pwtouse', pw matrix
        matrix `_corr' = r(Rho)
        matrix `_pmat' = J(`nvars', `nvars', .)
        forvalues i = 1/`nvars' {
            forvalues j = `=`i'+1'/`nvars' {
                local _vi : word `i' of `varlist'
                local _vj : word `j' of `varlist'
                local _cn = `_nmat'[`i', `j']
                if `_cn' < 30 {
                    * Use Stata's native spearman for exact p-values with small N
                    qui spearman `_vi' `_vj' if `_pwtouse'
                    matrix `_pmat'[`i', `j'] = r(p)
                    matrix `_pmat'[`j', `i'] = r(p)
                }
                else {
                    * t-approximation for p-values (adequate for N >= 30)
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
        qui pwcorr `varlist' if `_pwtouse', sig
        matrix `_corr' = r(C)
        * Compute p-values using pairwise N for each variable pair
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

    * Cache variable labels before clearing data
    forvalues _vi = 1/`nvars' {
        local _vn : word `_vi' of `varlist'
        local _vlbl_`_vi' : variable label `_vn'
        if "`_vlbl_`_vi''" == "" local _vlbl_`_vi' "`_vn'"
    }

**# Build Output Dataset
    preserve
    clear

    local out_ncols = 1 + `nvars'
    forvalues c = 1/`out_ncols' {
        qui gen str244 c`c' = ""
    }
    qui gen str244 title = ""

    * Row 1: Title
    local row 1
    qui set obs 1
    qui replace title = "`title'" in 1

    * Row 2: Column headers
    local row = `row' + 1
    qui set obs `row'
    qui replace c1 = "" in `row'
    forvalues v = 1/`nvars' {
        local _vlabel "`_vlbl_`v''"
        local _col = `v' + 1
        qui replace c`_col' = "`_vlabel'" in `row'
    }

    * Correlation rows
    forvalues i = 1/`nvars' {
        local row = `row' + 1
        qui set obs `row'
        local _vlabel "`_vlbl_`i''"
        qui replace c1 = "`_vlabel'" in `row'

        forvalues j = 1/`nvars' {
            local _col = `j' + 1
            * Determine if this cell should be shown
            local _show 0
            if "`full'" != "" local _show 1
            else if "`lower'" != "" & `j' < `i' local _show 1
            else if "`upper'" != "" & `j' > `i' local _show 1
            else if `i' == `j' local _show 1

            if `_show' {
                if `i' == `j' {
                    qui replace c`_col' = "1.00" in `row'
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
                    qui replace c`_col' = "`_rstr'" in `row'
                }
            }
        }
    }

    * Build star legend text
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

    * Star footnote as data row (console display only; Excel uses _tabtools_footnote)
    local _data_end_row = `row'
    if "`_star_note'" != "" {
        local row = `row' + 1
        qui set obs `row'
        qui replace c1 = "`_star_note'" in `row'
    }

    local num_rows = _N
    local num_cols = `out_ncols' + 1

**# Console Display
    if !`_has_xlsx' | "`display'" != "" {
        noisily _tabtools_console_display `out_ncols' `"`title'"'
    }

**# CSV/Frame/Excel Export
    if "`csv'" != "" {
        export delimited using "`csv'", replace
    }
    if `"`frame'"' != "" {
        _tabtools_frame_put `"`frame'"'
        local frame "`_frame_name'"
    }

    if `_has_xlsx' {
        * Drop star footnote data row for Excel (use _tabtools_footnote instead)
        if "`_star_note'" != "" & _N > `_data_end_row' {
            qui drop in `=`_data_end_row'+1'/l
        }
        local _xl_rows = _N
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
            putexcel (A2:`lastcol'2), border(top, `_hborder') bold hcenter font("`_font'", `_fontsize')
            putexcel (A2:`lastcol'2), border(bottom, `_hborder')
            putexcel (A3:`lastcol'`_xl_rows'), font("`_font'", `_fontsize')
            putexcel (C3:`lastcol'`_xl_rows'), hcenter
            putexcel (B`_xl_rows':`lastcol'`_xl_rows'), border(bottom, `_hborder')

            * Header background fill
            if "`headershade'" != "" {
                putexcel (A2:`lastcol'2), fpattern(solid, "`_headercolor'")
            }

            * Zebra striping
            if "`zebra'" != "" {
                forvalues _zr = 4(2)`_xl_rows' {
                    putexcel (A`_zr':`lastcol'`_zr'), fpattern(solid, "`_zebracolor'")
                }
            }

            * Star legend via _tabtools_footnote
            local _fn_row = `_xl_rows'
            if "`_star_note'" != "" {
                _tabtools_footnote `"`_star_note'"' "`lastcol'" `_fn_row' "`_font'" `_fontsize'
                local _fn_row = `_fn_row' + 1
            }
            if `"`footnote'"' != "" {
                _tabtools_footnote `"`footnote'"' "`lastcol'" `_fn_row' "`_font'" `_fontsize'
            }
            putexcel clear
        }
        if _rc {
            capture putexcel clear
        }

        * Set column widths via Mata
        capture {
            * Compute label column width from longest variable label
            local _max_label_len 0
            forvalues _vi = 1/`nvars' {
                local _vl "`_vlbl_`_vi''"
                local _vl_len : strlen local _vl
                if `_vl_len' > `_max_label_len' local _max_label_len = `_vl_len'
            }
            local _label_width = max(12, `_max_label_len' * 0.85 + 2)
            local _data_width = cond("`pvalues'" != "", 14, 10)
            mata: b = xl()
            mata: b.load_book("`xlsx'")
            mata: b.set_sheet("`sheet'")
            mata: b.set_column_width(1, 1, 1)
            mata: b.set_column_width(2, 2, `_label_width')
            mata: b.set_column_width(3, `num_cols', `_data_width')
            mata: b.close_book()
        }
        if _rc {
            capture mata: b.close_book()
            capture mata: mata drop b
        }
        capture mata: mata drop b

        noisily display as text "Exported to " as result `"`xlsx'"' as text ", sheet " as result `"`sheet'"'
    }

    if "`open'" != "" & `_has_xlsx' _tabtools_open_file "`xlsx'"

    restore

**# Return Results
    return matrix C = `_corr'
    capture return matrix P = `_pmat'
    capture return matrix N = `_nmat'
    if `_has_xlsx' {
        return local xlsx "`xlsx'"
        return local sheet "`sheet'"
    }
    if "`frame'" != "" return local frame "`frame'"

    local _method_type = cond("`spearman'" != "", "Spearman rank", "Pearson")
    local _methods "`_method_type' correlation coefficients are reported."
    if "`star'" != "" local _methods "`_methods' Significance levels: `_star_note'."
    local _methods "`_methods' Analysis performed in Stata `c(stata_version)' (StataCorp, College Station, TX)."
    return local methods "`_methods'"

} // end capture noisily
    local rc = _rc
    set varabbrev `_prev_varabbrev'
    if `rc' exit `rc'
end
