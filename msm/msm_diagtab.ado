*! msm_diagtab Version 1.2.0  2026/06/17
*! Export an accumulated cross-contrast MSM weight-diagnostics frame to Excel
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: nclass

/*
Syntax:
  msm_diagtab , frame(name) xlsx(string) [options]

Description:
  Writes a frame accumulated by msm_diagnose, accumulate() to a single styled
  Excel sheet: one row per contrast with ESS, weight extremes, and residual
  imbalance.  Reuses the shared _msm_xlsx_* styling helpers.

See help msm_diagtab for complete documentation
*/

program define msm_diagtab, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _restore_needed = 0
    set varabbrev off

    capture noisily {

    syntax , FRAME(name) XLSX(string) [SHEET(string) TITle(string) ///
        FOOTnote(string) DECimals(integer 3) THReshold(real 0.1) ///
        Font(string) FONTSize(integer 10) BORDERstyle(string) ///
        ZEBRA OPEN REPLACE]

    * Defaults
    if `"`sheet'"' == "" local sheet "Weight Diagnostics"
    if `"`title'"' == "" {
        local title "Per-contrast IP-weight diagnostics (ESS, weights, balance)"
    }
    if "`font'" == "" local font "Arial"
    if "`borderstyle'" == "" local borderstyle "thin"

    * Validate options
    if `decimals' < 0 | `decimals' > 10 {
        display as error "decimals() must be between 0 and 10"
        exit 198
    }
    if !inlist("`borderstyle'", "thin", "medium", "academic") {
        display as error "borderstyle() must be thin, medium, or academic"
        exit 198
    }
    if `fontsize' < 6 | `fontsize' > 72 {
        display as error "fontsize() must be between 6 and 72"
        exit 198
    }
    if !regexm("`xlsx'", "\.xlsx$") {
        display as error "xlsx() must specify a .xlsx file"
        exit 198
    }

    local _hborder = "`borderstyle'"
    if "`borderstyle'" == "academic" local _hborder "medium"

    * Validate the source frame
    capture frame `frame': describe
    if _rc {
        display as error "frame `frame' not found"
        exit 111
    }
    quietly frame `frame': count
    local n_contrasts = r(N)
    if `n_contrasts' == 0 {
        display as error "frame `frame' has no rows"
        exit 459
    }

    * File-existence handling. With replace, the writer uses sheetreplace and
    * preserves unrelated sheets in an existing workbook.
    if "`replace'" == "" {
        capture confirm new file "`xlsx'"
        if _rc {
            display as error "file {bf:`xlsx'} already exists; use {bf:replace} option"
            exit 602
        }
    }

    * Number formats
    local fmt "%9.`decimals'f"
    local _decfmt "0"
    if `decimals' > 0 {
        local _decfmt "0."
        forvalues _d = 1/`decimals' {
            local _decfmt "`_decfmt'0"
        }
    }

    * Read the frame contents into locals (row-major)
    forvalues _i = 1/`n_contrasts' {
        frame `frame': local _c_`_i'    = contrast[`_i']
        frame `frame': local _o_`_i'    = outcome[`_i']
        frame `frame': local _nobs_`_i' = n_obs[`_i']
        frame `frame': local _ess_`_i'  = ess[`_i']
        frame `frame': local _esp_`_i'  = ess_pct[`_i']
        frame `frame': local _maxw_`_i' = max_weight[`_i']
        frame `frame': local _p99_`_i'  = p99_weight[`_i']
        frame `frame': local _next_`_i' = n_extreme[`_i']
        frame `frame': local _nimb_`_i' = n_imbalanced[`_i']
        frame `frame': local _mabs_`_i' = max_abs_smd[`_i']
    }

    * Rows: title + header + one row per contrast
    local total_rows = `n_contrasts' + 2
    local last_data = `total_rows'
    local footnote_row = `total_rows' + 1
    local n_cols = 10

    local _has_footnote = (`"`footnote'"' != "")
    if !`_has_footnote' {
        local footnote `"ESS% = effective sample size as a percentage of person-periods. N imbalanced = covariates with |weighted SMD| > `threshold'; balance columns blank when balance was not assessed."'
        local _has_footnote = 1
    }

    preserve
    local _restore_needed = 1
    quietly {
        clear
        set obs `total_rows'

        gen str80 A = ""
        gen str40 B = ""
        gen str20 C = ""
        gen str20 D = ""
        gen str20 E = ""
        gen str20 F = ""
        gen str20 G = ""
        gen str20 H = ""
        gen str20 I = ""
        gen str20 J = ""

        * Row 1: title
        replace A = "`title'" in 1

        * Row 2: header
        replace A = "Contrast"     in 2
        replace B = "Outcome"      in 2
        replace C = "N (pp)"       in 2
        replace D = "ESS"          in 2
        replace E = "ESS (%)"      in 2
        replace F = "Max weight"   in 2
        replace G = "P99 weight"   in 2
        replace H = "N extreme"    in 2
        replace I = "N imbalanced" in 2
        replace J = "Max |SMD|"    in 2

        * Data rows
        forvalues _i = 1/`n_contrasts' {
            local _row = `_i' + 2
            replace A = `"`_c_`_i''"' in `_row'
            replace B = `"`_o_`_i''"' in `_row'
            replace C = strtrim(string(`_nobs_`_i'', "%9.0f")) in `_row'
            replace D = strtrim(string(`_ess_`_i'',  "%9.0f")) in `_row'
            replace E = strtrim(string(`_esp_`_i'',  "%5.1f")) + "%" in `_row'
            replace F = strtrim(string(`_maxw_`_i'', "`fmt'")) in `_row'
            replace G = strtrim(string(`_p99_`_i'',  "`fmt'")) in `_row'
            replace H = strtrim(string(`_next_`_i'', "%9.0f")) in `_row'

            if `_nimb_`_i'' >= . {
                replace I = "n/a" in `_row'
            }
            else {
                replace I = strtrim(string(`_nimb_`_i'', "%9.0f")) in `_row'
            }
            if `_mabs_`_i'' >= . {
                replace J = "n/a" in `_row'
            }
            else {
                replace J = strtrim(string(`_mabs_`_i'', "`fmt'")) in `_row'
            }
        }

        * Dynamic column widths
        local _col_idx = 0
        foreach _var of varlist * {
            local ++_col_idx
            gen _len_`_col_idx' = length(`_var')
            summarize _len_`_col_idx', meanonly
            local _maxlen_`_col_idx' = r(max)
            drop _len_`_col_idx'
        }
        local _w_1 = ceil(`_maxlen_1' * 0.90)
        if `_w_1' < 16 local _w_1 = 16
        if `_w_1' > 50 local _w_1 = 50
        local _w_2 = ceil(`_maxlen_2' * 0.90)
        if `_w_2' < 12 local _w_2 = 12
        if `_w_2' > 40 local _w_2 = 40
        forvalues _ci = 3/`_col_idx' {
            local _w_`_ci' = ceil(`_maxlen_`_ci'' * 0.95)
            if `_w_`_ci'' < 11 local _w_`_ci' = 11
            if `_w_`_ci'' > 24 local _w_`_ci' = 24
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

        * Convert numeric cells. Columns: C=n_obs(int) D=ess(int) F=max_w(dec)
        * G=p99(dec) H=n_extreme(int) I=n_imbalanced(int) J=max_abs_smd(dec).
        * Skip A,B (strings) and E (ESS% carries a trailing percent sign).
        forvalues _r = 3/`last_data' {
            foreach _spec in "C 3 i" "D 4 i" "F 6 d" "G 7 d" "H 8 i" "I 9 i" "J 10 d" {
                tokenize "`_spec'"
                local _cl "`1'"
                local _cn "`2'"
                local _ty "`3'"
                local _cellstr = `_cl'[`_r']
                if `"`_cellstr'"' == "" | `"`_cellstr'"' == "." continue
                if `"`_cellstr'"' == "n/a" continue
                local _cellclean = subinstr(`"`_cellstr'"', ",", "", .)
                local _cellnum = real("`_cellclean'")
                if `_cellnum' != . {
                    local _nf = cond("`_ty'" == "i", "0", "`_decfmt'")
                    _msm_xlsx_put_number, object(_msm_xl) row(`_r') ///
                        col(`_cn') value(`_cellnum') nformat("`_nf'")
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
            nrows(`total_rows') ncols(`n_cols') font("`font'") ///
            fontsize(`fontsize') headerrow(2) hborder("`_hborder'") ///
            borderstyle("`borderstyle'")

        if "`borderstyle'" != "academic" {
            mata: b.set_left_border((2,`last_data'), `n_cols', "`borderstyle'")
        }

        if `last_data' >= 3 {
            mata: b.set_horizontal_align((3,`last_data'), (3,`n_cols'), "center")
        }
        mata: b.set_bottom_border(`last_data', (1,`n_cols'), "`_hborder'")

        if "`zebra'" != "" {
            _msm_xlsx_zebra, object(b) startrow(3) ///
                lastrow(`last_data') ncols(`n_cols')
        }

        if `_has_footnote' {
            local _fn_fontsize = max(`fontsize' - 2, 6)
            _msm_xlsx_footnote, object(b) sheet("`sheet'") ///
                row(`footnote_row') ncols(`n_cols') footnote(`"`footnote'"') ///
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

    display as text ""
    display as result "`n_contrasts'" as text " contrast(s) exported to " ///
        as result "`xlsx'" as text " (sheet: " as result "`sheet'" as text ")"

    if "`open'" != "" {
        _msm_post_export_open, file(`"`xlsx'"')
    }

    * msm_diagtab is nclass; clear any stray r() from helper cleanup.
    quietly version

    } /* end capture noisily */
    local _rc = _rc
    if `_restore_needed' {
        capture restore
    }
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end
