*! _iivw_export_table Version 1.7.4  2026/06/26
*! Internal styled Excel sheet writer for iivw reporting commands
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _iivw_export_table, rclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off

    local __iivw_putexcel_open = 0
    local __iivw_return_xlsx ""
    local __iivw_return_sheet ""
    local __iivw_return_rows = .
    local __iivw_return_cols = .
    local __iivw_return_decimals = .

    capture noisily {

    syntax , TABLEFRAME(name) ///
        [XLSX(string asis) SHEET(string asis) ///
         REPLACE OPEN TITLE(string asis) FOOTNOTE(string asis) ///
         DECimals(integer 4) LAYout(string) VALUESPANFROM(integer 0) ///
         BORDERstyle(string) HEADERShade THEme(string) ///
         HEADERColor(string) ZEBRAColor(string) ZEBra]

    local __iivw_dq = char(34)
    foreach __iivw_opt in xlsx sheet title footnote {
        local __iivw_tmp `"``__iivw_opt''"'
        local __iivw_tmp = strtrim(`"`__iivw_tmp'"')
        local __iivw_tmp = subinstr(`"`__iivw_tmp'"', `"`__iivw_dq'"', "", .)
        local `__iivw_opt' `"`__iivw_tmp'"'
    }
    local layout = lower(strtrim(`"`layout'"'))
    if `"`layout'"' == "" local layout "standard"
    if `"`layout'"' == "regtab" local layout "tabtools"
    if !inlist(`"`layout'"', "standard", "tabtools") {
        display as error "layout() must be standard or tabtools"
        error 198
    }
    if `valuespanfrom' < 0 {
        display as error "valuespanfrom() must be a non-negative row index"
        error 198
    }

    * ---- Resolve styling options (tabtools-parity, self-contained) ----
    * Defaults match the tabtools house style: thin framed grid (frame plus
    * group separators, no full interior grid), no header shade.
    local borderstyle = lower(strtrim(subinstr(`"`borderstyle'"', `"`__iivw_dq'"', "", .)))
    local theme = lower(strtrim(subinstr(`"`theme'"', `"`__iivw_dq'"', "", .)))
    local __iivw_font "Arial"
    local __iivw_fontsize = 10
    if "`theme'" != "" {
        local __iivw_t_border ""
        local __iivw_t_shade = 0
        local __iivw_t_zebra = 0
        if "`theme'" == "lancet" {
            local __iivw_font "Arial"
            local __iivw_fontsize = 9
            local __iivw_t_border "academic"
        }
        else if "`theme'" == "nejm" {
            local __iivw_font "Arial"
            local __iivw_fontsize = 9
            local __iivw_t_border "academic"
            local __iivw_t_zebra = 1
        }
        else if "`theme'" == "bmj" {
            local __iivw_font "Arial"
            local __iivw_fontsize = 10
            local __iivw_t_border "academic"
        }
        else if "`theme'" == "apa" {
            local __iivw_font "Times New Roman"
            local __iivw_fontsize = 12
            local __iivw_t_border "academic"
        }
        else if "`theme'" == "jama" {
            local __iivw_font "Arial"
            local __iivw_fontsize = 10
            local __iivw_t_border "academic"
        }
        else if "`theme'" == "plos" {
            local __iivw_font "Arial"
            local __iivw_fontsize = 10
            local __iivw_t_border "thin"
        }
        else if "`theme'" == "nature" {
            local __iivw_font "Arial"
            local __iivw_fontsize = 7
            local __iivw_t_border "academic"
        }
        else if "`theme'" == "cell" {
            local __iivw_font "Arial"
            local __iivw_fontsize = 8
            local __iivw_t_border "academic"
        }
        else if "`theme'" == "annals" {
            local __iivw_font "Arial"
            local __iivw_fontsize = 10
            local __iivw_t_border "academic"
        }
        else {
            display as error ///
                "theme() must be one of: lancet, nejm, bmj, apa, jama, plos, nature, cell, annals"
            error 198
        }
        * Explicit options override the theme; theme only fills the gaps.
        if "`borderstyle'" == "" local borderstyle "`__iivw_t_border'"
        if "`headershade'" == "" & `__iivw_t_shade' local headershade "headershade"
        if "`zebra'" == "" & `__iivw_t_zebra' local zebra "zebra"
    }

    if "`borderstyle'" == "" local borderstyle "thin"
    if !inlist("`borderstyle'", "default", "thin", "medium", "academic") {
        display as error "borderstyle() must be: default, thin, medium, or academic"
        error 198
    }
    if "`borderstyle'" == "default" local borderstyle "thin"
    local __iivw_bcode = 1
    if "`borderstyle'" == "medium"   local __iivw_bcode = 2
    if "`borderstyle'" == "academic" local __iivw_bcode = 3

    local __iivw_headershade_flag = ("`headershade'" != "")
    local __iivw_zebra_flag = ("`zebra'" != "")

    local __iivw_headercolor "219 229 241"
    local headercolor = strtrim(subinstr(`"`headercolor'"', `"`__iivw_dq'"', "", .))
    if `"`headercolor'"' != "" {
        local __iivw_nrgb : word count `headercolor'
        if `__iivw_nrgb' != 3 {
            display as error "headercolor() must be three integers: R G B (each 0-255)"
            error 198
        }
        foreach __iivw_rgb of local headercolor {
            capture confirm integer number `__iivw_rgb'
            if _rc {
                display as error "headercolor() values must be integers between 0 and 255"
                error 198
            }
            if `__iivw_rgb' < 0 | `__iivw_rgb' > 255 {
                display as error "headercolor() values must be integers between 0 and 255"
                error 198
            }
        }
        local __iivw_headercolor `"`headercolor'"'
    }
    local __iivw_zebracolor "237 242 249"
    local zebracolor = strtrim(subinstr(`"`zebracolor'"', `"`__iivw_dq'"', "", .))
    if `"`zebracolor'"' != "" {
        local __iivw_nrgb : word count `zebracolor'
        if `__iivw_nrgb' != 3 {
            display as error "zebracolor() must be three integers: R G B (each 0-255)"
            error 198
        }
        foreach __iivw_rgb of local zebracolor {
            capture confirm integer number `__iivw_rgb'
            if _rc {
                display as error "zebracolor() values must be integers between 0 and 255"
                error 198
            }
            if `__iivw_rgb' < 0 | `__iivw_rgb' > 255 {
                display as error "zebracolor() values must be integers between 0 and 255"
                error 198
            }
        }
        local __iivw_zebracolor `"`zebracolor'"'
    }

    capture frame `tableframe': count
    if _rc {
        display as error "internal export frame `tableframe' not found"
        error 111
    }
    local __iivw_return_rows = r(N)
    if `__iivw_return_rows' == 0 {
        display as error "internal export frame has no rows"
        error 2000
    }

    quietly frame `tableframe': ds
    local __iivw_vars "`r(varlist)'"
    local __iivw_return_cols : word count `__iivw_vars'
    if `__iivw_return_cols' == 0 {
        display as error "internal export frame has no variables"
        error 498
    }
    if "`layout'" == "standard" & `__iivw_return_cols' > 26 {
        display as error "iivw Excel export currently supports at most 26 columns"
        error 498
    }

    local __iivw_xlsx `"`xlsx'"'
    if `"`__iivw_xlsx'"' == "" {
        display as error "xlsx() is required for reporting export"
        error 198
    }

    if `decimals' < 0 | `decimals' > 6 {
        display as error "decimals() must be between 0 and 6"
        error 198
    }
    local __iivw_return_decimals = `decimals'

    local __iivw_xlsx_len = strlen(`"`__iivw_xlsx'"')
    if `__iivw_xlsx_len' < 6 | ///
        lower(substr(`"`__iivw_xlsx'"', `__iivw_xlsx_len' - 4, 5)) != ".xlsx" {
        display as error "xlsx() must name a .xlsx file"
        error 198
    }

    if `"`sheet'"' == "" local sheet "Sheet1"
    if strlen(`"`sheet'"') > 31 {
        display as error "sheet() must be 31 characters or fewer"
        error 198
    }
    foreach bad in "[" "]" ":" "*" "?" "/" {
        if strpos(`"`sheet'"', `"`bad'"') > 0 {
            display as error "sheet() contains an invalid Excel worksheet character"
            error 198
        }
    }

    if `"`title'"' == "" local title `"`sheet'"'

    local __iivw_xlsx_exists = 0
    local __iivw_sheet_exists = 0
    capture confirm file `"`__iivw_xlsx'"'
    local __iivw_xlsx_exists = (_rc == 0)
    if `__iivw_xlsx_exists' {
        mata: st_local("__iivw_sheet_exists", ///
            strofreal(_iivw_xlsx_sheet_exists(`"`__iivw_xlsx'"', `"`sheet'"')))
        if `__iivw_sheet_exists' & "`replace'" == "" {
            display as error "sheet `sheet' already exists in `__iivw_xlsx'; use replace to overwrite it"
            error 602
        }
    }

    if "`layout'" == "tabtools" {
        local __iivw_note_row = 0
        if `"`footnote'"' != "" {
            local __iivw_note_row = `__iivw_return_rows'
        }

        local __iivw_widths ""
        forvalues __iivw_j = 1/`__iivw_return_cols' {
            local __iivw_v : word `__iivw_j' of `__iivw_vars'
            local __iivw_width = 8
            if `__iivw_j' == 1 local __iivw_width = 1
            forvalues __iivw_i = 1/`__iivw_return_rows' {
                if `__iivw_note_row' > 0 & ///
                    `__iivw_i' == `__iivw_note_row' & `__iivw_j' == 2 {
                    continue
                }
                frame `tableframe': local __iivw_scell = `__iivw_v'[`__iivw_i']
                local __iivw_slen = strlen(`"`__iivw_scell'"') + 2
                if `__iivw_slen' > `__iivw_width' {
                    local __iivw_width = `__iivw_slen'
                }
            }
            if `__iivw_j' == 1 {
                local __iivw_width = 1
            }
            else if `__iivw_j' == 2 {
                local __iivw_width = max(18, min(42, `__iivw_width'))
            }
            else {
                local __iivw_width = max(7, min(18, `__iivw_width'))
            }
            local __iivw_widths "`__iivw_widths' `__iivw_width'"
        }

        frame `tableframe': mata: _iivw_xlsx_write_tabtools( ///
            `"`__iivw_xlsx'"', `"`sheet'"', `"`__iivw_vars'"', ///
            `__iivw_return_rows', `__iivw_return_cols', ///
            `__iivw_note_row', `"`__iivw_widths'"', ///
            `"`__iivw_font'"', `__iivw_fontsize', `__iivw_bcode', ///
            `__iivw_headershade_flag', `__iivw_zebra_flag', ///
            `"`__iivw_headercolor'"', `"`__iivw_zebracolor'"', ///
            `valuespanfrom')

        local __iivw_return_xlsx `"`__iivw_xlsx'"'
        local __iivw_return_sheet `"`sheet'"'

        if "`open'" != "" {
            capture noisily shell xdg-open `"`__iivw_xlsx'"' >/dev/null 2>&1 &
            if _rc {
                display as text "note: Excel file was written but could not be opened automatically"
            }
        }
    }
    else {
    if `__iivw_xlsx_exists' {
        quietly putexcel set `"`__iivw_xlsx'"', modify sheet(`"`sheet'"', replace)
    }
    else {
        quietly putexcel set `"`__iivw_xlsx'"', replace sheet(`"`sheet'"')
    }
    local __iivw_putexcel_open = 1

    local __iivw_header_row = 3
    local __iivw_first_data = `__iivw_header_row' + 1
    quietly putexcel A1 = (`"`title'"')

    local __iivw_decimal_format "0"
    if `decimals' > 0 {
        local __iivw_decimal_format "0.`=substr("000000", 1, `decimals')'"
    }

    local __iivw_widths ""
    forvalues __iivw_j = 1/`__iivw_return_cols' {
        local __iivw_v : word `__iivw_j' of `__iivw_vars'
        local __iivw_col = char(64 + `__iivw_j')
        local __iivw_header "`__iivw_v'"
        capture frame `tableframe': local __iivw_label : variable label `__iivw_v'
        if _rc == 0 & `"`__iivw_label'"' != "" {
            local __iivw_header `"`__iivw_label'"'
        }
        quietly putexcel `__iivw_col'`__iivw_header_row' = (`"`__iivw_header'"')

        local __iivw_width = strlen(`"`__iivw_header'"') + 2
        capture frame `tableframe': confirm string variable `__iivw_v'
        if _rc == 0 {
            forvalues __iivw_i = 1/`__iivw_return_rows' {
                frame `tableframe': local __iivw_scell = `__iivw_v'[`__iivw_i']
                local __iivw_slen = strlen(`"`__iivw_scell'"') + 2
                if `__iivw_slen' > `__iivw_width' {
                    local __iivw_width = `__iivw_slen'
                }
            }
        }
        else {
            if inlist("`__iivw_v'", "N", "n_missing", "modeled") {
                local __iivw_width = max(`__iivw_width', 10)
            }
            else {
                local __iivw_width = max(`__iivw_width', `decimals' + 9)
            }
        }
        local __iivw_width = max(8, min(36, `__iivw_width'))
        local __iivw_widths "`__iivw_widths' `__iivw_width'"
    }

    forvalues __iivw_i = 1/`__iivw_return_rows' {
        local __iivw_excel_row = `__iivw_first_data' + `__iivw_i' - 1
        forvalues __iivw_j = 1/`__iivw_return_cols' {
            local __iivw_v : word `__iivw_j' of `__iivw_vars'
            local __iivw_col = char(64 + `__iivw_j')
            capture frame `tableframe': confirm numeric variable `__iivw_v'
            if _rc == 0 {
                frame `tableframe': local __iivw_cell = `__iivw_v'[`__iivw_i']
                if `__iivw_cell' < . {
                    if inlist("`__iivw_v'", "N", "n_missing", "modeled") {
                        quietly putexcel `__iivw_col'`__iivw_excel_row' = ///
                            (`__iivw_cell'), nformat("0")
                    }
                    else {
                        quietly putexcel `__iivw_col'`__iivw_excel_row' = ///
                            (`__iivw_cell'), nformat("`__iivw_decimal_format'")
                    }
                }
                else {
                    quietly putexcel `__iivw_col'`__iivw_excel_row' = ("")
                }
            }
            else {
                frame `tableframe': local __iivw_cell = `__iivw_v'[`__iivw_i']
                quietly putexcel `__iivw_col'`__iivw_excel_row' = ///
                    (`"`__iivw_cell'"')
            }
        }
    }

    local __iivw_note_row = 0
    if `"`footnote'"' != "" {
        local __iivw_note_row = `__iivw_first_data' + `__iivw_return_rows' + 1
        quietly putexcel A`__iivw_note_row' = (`"`footnote'"')
    }

    quietly putexcel clear
    local __iivw_putexcel_open = 0

    mata: _iivw_xlsx_style(`"`__iivw_xlsx'"', `"`sheet'"', ///
        `__iivw_return_rows', `__iivw_return_cols', `__iivw_header_row', ///
        `__iivw_note_row', `"`__iivw_widths'"', `"`title'"', `"`footnote'"')

    local __iivw_return_xlsx `"`__iivw_xlsx'"'
    local __iivw_return_sheet `"`sheet'"'

    if "`open'" != "" {
        capture noisily shell xdg-open `"`__iivw_xlsx'"' >/dev/null 2>&1 &
        if _rc {
            display as text "note: Excel file was written but could not be opened automatically"
        }
    }
    }

    }
    local rc = _rc
    if `__iivw_putexcel_open' {
        capture putexcel clear
        local __iivw_putexcel_clear_rc = _rc
    }
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'

    return scalar decimals = `__iivw_return_decimals'
    return scalar N_cols = `__iivw_return_cols'
    return scalar N_rows = `__iivw_return_rows'
    return local xlsx `"`__iivw_return_xlsx'"'
    return local sheet `"`__iivw_return_sheet'"'
end

version 16.0
capture mata: mata drop _iivw_xlsx_sheet_exists()
local __iivw_mata_drop_rc = _rc
capture mata: mata drop _iivw_xlsx_style()
local __iivw_mata_drop_rc = _rc
capture mata: mata drop _iivw_xlsx_write_tabtools()
local __iivw_mata_drop_rc = _rc
capture mata: mata drop _iivw_xlsx_style_tabtools()
local __iivw_mata_drop_rc = _rc
capture mata: mata drop _iivw_xlsx_cur_strmat()
local __iivw_mata_drop_rc = _rc

mata:
mata set matastrict on

real scalar _iivw_xlsx_sheet_exists(string scalar filepath, string scalar sheet)
{
    class xl scalar b
    string rowvector sheets
    real scalar i, found

    if (!fileexists(filepath)) return(0)

    b = xl()
    b.load_book(filepath)
    sheets = b.get_sheets()
    found = 0
    for (i = 1; i <= length(sheets); i++) {
        if (sheets[i] == sheet) {
            found = 1
            break
        }
    }
    b.close_book()
    return(found)
}

void _iivw_xlsx_style(
    string scalar filepath,
    string scalar sheet,
    real scalar n_rows,
    real scalar n_cols,
    real scalar header_row,
    real scalar note_row,
    string scalar widths,
    string scalar title,
    string scalar footnote)
{
    class xl scalar b
    real rowvector w
    real scalar data_first, data_last, j

    b = xl()
    b.load_book(filepath)
    b.set_sheet(sheet)
    b.set_mode("open")

    data_first = header_row + 1
    data_last = header_row + n_rows

    b.put_string(1, 1, J(1, 1, title))
    b.set_sheet_merge(sheet, (1, 1), (1, n_cols))
    b.set_font((1, 1), (1, n_cols), "Arial", 14, "255 255 255")
    b.set_font_bold((1, 1), (1, n_cols), "on")
    b.set_fill_pattern((1, 1), (1, n_cols), "solid", "31 78 121")
    b.set_horizontal_align((1, 1), (1, n_cols), "center")
    b.set_vertical_align((1, 1), (1, n_cols), "center")
    b.set_row_height(1, 1, 24)

    b.set_font((header_row, header_row), (1, n_cols), "Arial", 10)
    b.set_font_bold((header_row, header_row), (1, n_cols), "on")
    b.set_text_wrap((header_row, header_row), (1, n_cols), "on")
    b.set_fill_pattern((header_row, header_row), (1, n_cols),
        "solid", "221 235 247")
    b.set_top_border((header_row, header_row), (1, n_cols), "thin")
    b.set_bottom_border((header_row, header_row), (1, n_cols), "medium")
    b.set_horizontal_align((header_row, header_row), (1, n_cols), "center")
    b.set_vertical_align((header_row, header_row), (1, n_cols), "center")
    b.set_row_height(header_row, header_row, 28)

    if (n_rows > 0) {
        b.set_font((data_first, data_last), (1, n_cols), "Arial", 10)
        b.set_vertical_align((data_first, data_last), (1, n_cols), "center")
        b.set_bottom_border((data_first, data_last), (1, n_cols), "thin")
        b.set_text_wrap((data_first, data_last), (1, n_cols), "on")
        if (n_cols > 1) {
            b.set_horizontal_align((data_first, data_last), (2, n_cols), "right")
        }
    }

    if (note_row > 0) {
        b.put_string(note_row, 1, J(1, 1, footnote))
        b.set_sheet_merge(sheet, (note_row, note_row), (1, n_cols))
        b.set_font((note_row, note_row), (1, n_cols), "Arial", 9)
        b.set_font_italic((note_row, note_row), (1, n_cols), "on")
        b.set_text_wrap((note_row, note_row), (1, n_cols), "on")
        b.set_fill_pattern((note_row, note_row), (1, n_cols),
            "solid", "242 242 242")
        b.set_row_height(note_row, note_row, 34)
    }

    w = strtoreal(tokens(widths))
    for (j = 1; j <= min((cols(w), n_cols)); j++) {
        if (w[j] < . & w[j] > 0) b.set_column_width(j, j, w[j])
    }

    b.close_book()
}

void _iivw_xlsx_write_tabtools(
    string scalar filepath,
    string scalar sheet,
    string scalar varlist,
    real scalar n_rows,
    real scalar n_cols,
    real scalar note_row,
    string scalar widths,
    string scalar font,
    real scalar fontsize,
    real scalar bcode,
    real scalar headershade,
    real scalar zebra,
    string scalar headercolor,
    string scalar zebracolor,
    real scalar valuespanfrom)
{
    class xl scalar b
    string rowvector sheets
    string matrix table
    real scalar i, found

    b = xl()

    if (!fileexists(filepath)) {
        b.create_book(filepath, sheet, "xlsx")
    }
    else {
        b.load_book(filepath)
        sheets = b.get_sheets()
        found = 0
        for (i = 1; i <= length(sheets); i++) {
            if (sheets[i] == sheet) {
                found = 1
                break
            }
        }
        if (found) {
            b.clear_sheet(sheet)
        }
        else {
            b.add_sheet(sheet)
        }
        b.set_sheet(sheet)
    }

    b.set_mode("open")
    table = _iivw_xlsx_cur_strmat(varlist)
    b.put_string(1, 1, table)

    _iivw_xlsx_style_tabtools(b, sheet, n_rows, n_cols, note_row, widths,
        font, fontsize, bcode, headershade, zebra, headercolor, zebracolor,
        valuespanfrom)
    b.close_book()
}

void _iivw_xlsx_style_tabtools(
    class xl scalar b,
    string scalar sheet,
    real scalar n_rows,
    real scalar n_cols,
    real scalar note_row,
    string scalar widths,
    string scalar font,
    real scalar fontsize,
    real scalar bcode,
    real scalar headershade,
    real scalar zebra,
    string scalar headercolor,
    string scalar zebracolor,
    real scalar valuespanfrom)
{
    real rowvector w
    real scalar data_last, j, cend, i, title_size, foot_size
    string scalar gridstyle

    if (n_rows < 1 | n_cols < 1) return

    data_last = n_rows
    if (note_row > 0) data_last = note_row - 1

    title_size = fontsize + 2
    foot_size = fontsize - 2
    if (foot_size < 6) foot_size = 6

    b.set_font((1, n_rows), (1, n_cols), font, fontsize)
    b.set_vertical_align((1, n_rows), (1, n_cols), "bottom")

    // Title row 1 (merged, no fill: house style keeps the title above the grid).
    b.set_font((1, 1), (1, n_cols), font, title_size)
    b.set_font_bold((1, 1), (1, n_cols), "on")
    b.set_sheet_merge(sheet, (1, 1), (1, n_cols))
    b.set_horizontal_align((1, 1), (1, 1), "left")
    b.set_vertical_align((1, 1), (1, 1), "center")
    b.set_text_wrap((1, 1), (1, 1), "on")
    b.set_row_height(1, 1, 30)

    if (n_cols >= 1) b.set_column_width(1, 1, 1)

    // Super-header row 2 (group spanners).
    if (n_rows >= 2 & n_cols >= 2) {
        b.set_font_bold((2, 2), (2, n_cols), "on")
        b.set_vertical_align((2, 2), (2, n_cols), "center")
        if (n_cols >= 3) {
            b.set_horizontal_align((2, 2), (3, n_cols), "center")
            b.set_text_wrap((2, 2), (3, n_cols), "on")
        }
        b.set_row_height(2, 2, 24)
    }

    // Column-header row 3.
    if (n_rows >= 3 & n_cols >= 2) {
        b.set_font_bold((3, 3), (2, n_cols), "on")
        b.set_vertical_align((3, 3), (2, n_cols), "center")
        if (n_cols >= 3) {
            b.set_horizontal_align((3, 3), (3, n_cols), "center")
        }
    }

    // Data rows.
    if (data_last >= 4 & n_cols >= 2) {
        b.set_horizontal_align((4, data_last), (2, 2), "left")
        b.set_vertical_align((4, data_last), (2, n_cols), "center")
        if (n_cols >= 3) {
            b.set_horizontal_align((4, data_last), (3, n_cols), "center")
        }
    }

    // Single-value diagnostic block (iivw_diagnose only).  When valuespanfrom
    // marks a divider row, bracket it with full-width horizontal rules and bold
    // its label -- no merging.  Diagnostic values below stay plainly in column
    // C with no merge, matching the regtab house style.  Default 0 leaves the
    // generic exogeneity/gap callers untouched.
    if (valuespanfrom > 0 & n_cols >= 3 & valuespanfrom <= data_last) {
        b.set_font_bold((valuespanfrom, valuespanfrom), (3, 3), "on")
        b.set_horizontal_align((valuespanfrom, valuespanfrom), (3, 3), "left")
        b.set_top_border((valuespanfrom, valuespanfrom), (2, n_cols), "medium")
        b.set_bottom_border((valuespanfrom, valuespanfrom), (2, n_cols), "medium")
    }

    // Group merges in the super-header (3-column blocks from column 3).
    if (n_cols >= 3) {
        for (j = 3; j <= n_cols; j = j + 3) {
            cend = min((j + 2, n_cols))
            if (n_rows >= 2 & cend > j) {
                b.set_sheet_merge(sheet, (2, 2), (j, cend))
                b.set_horizontal_align((2, 2), (j, cend), "center")
            }
        }
    }

    // Borders: framed grid (frame + group separators) for thin/medium,
    // three-rule book layout for academic.
    if (n_cols >= 2 & data_last >= 2) {
        if (bcode == 3) {
            b.set_top_border((2, 2), (2, n_cols), "medium")
            if (n_rows >= 3) {
                b.set_bottom_border((2, 2), (2, n_cols), "thin")
                b.set_bottom_border((3, 3), (2, n_cols), "medium")
            }
            b.set_bottom_border((data_last, data_last), (2, n_cols), "medium")
        }
        else {
            gridstyle = (bcode == 2 ? "medium" : "thin")
            // Regtab house style (Tables 1-3): outer frame plus vertical
            // separators after the label column and between 3-column model
            // groups, with horizontal rules only in the header band -- not a
            // full interior grid.
            b.set_top_border((2, 2), (2, n_cols), "medium")
            if (n_rows >= 3) {
                b.set_bottom_border((2, 2), (2, n_cols), "thin")
                b.set_bottom_border((3, 3), (2, n_cols), "medium")
            }
            b.set_bottom_border((data_last, data_last), (2, n_cols), "medium")
            b.set_left_border((2, data_last), (2, 2), gridstyle)
            b.set_right_border((2, data_last), (2, 2), gridstyle)
            for (j = 5; j <= n_cols; j = j + 3) {
                b.set_right_border((2, data_last), (j, j), gridstyle)
            }
            b.set_right_border((2, data_last), (n_cols, n_cols), gridstyle)
        }
    }

    // Header shading (off in the house style; on for headershade/theme).
    if (headershade == 1 & n_cols >= 2) {
        if (n_rows >= 2) {
            b.set_fill_pattern((2, 2), (2, n_cols), "solid", headercolor)
        }
        if (n_rows >= 3) {
            b.set_fill_pattern((3, 3), (2, n_cols), "solid", headercolor)
        }
    }

    // Zebra striping on alternating data rows.
    if (zebra == 1 & n_cols >= 2 & data_last >= 4) {
        for (i = 4; i <= data_last; i++) {
            if (mod(i - 4, 2) == 1) {
                b.set_fill_pattern((i, i), (2, n_cols), "solid", zebracolor)
            }
        }
    }

    // Footnote row.
    if (note_row > 0 & note_row <= n_rows & n_cols >= 2) {
        b.set_sheet_merge(sheet, (note_row, note_row), (2, n_cols))
        b.set_font((note_row, note_row), (2, n_cols), font, foot_size)
        b.set_font_italic((note_row, note_row), (2, n_cols), "on")
        b.set_text_wrap((note_row, note_row), (2, n_cols), "on")
        b.set_horizontal_align((note_row, note_row), (2, 2), "left")
        b.set_vertical_align((note_row, note_row), (2, 2), "center")
        b.set_row_height(note_row, note_row, 38)
    }

    w = strtoreal(tokens(widths))
    for (j = 1; j <= min((cols(w), n_cols)); j++) {
        if (w[j] < . & w[j] > 0) b.set_column_width(j, j, w[j])
    }
}

string matrix _iivw_xlsx_cur_strmat(string scalar varlist)
{
    string rowvector vars
    string matrix out
    string colvector scol
    real colvector ncol
    string scalar fmt
    real scalar i, j, N, K

    vars = tokens(varlist)
    N = st_nobs()
    K = cols(vars)
    out = J(N, K, "")

    for (j = 1; j <= K; j++) {
        if (st_isstrvar(vars[j])) {
            out[, j] = st_sdata(., vars[j])
        }
        else {
            ncol = st_data(., vars[j])
            scol = J(N, 1, "")
            fmt = st_varformat(vars[j])
            for (i = 1; i <= N; i++) {
                if (ncol[i] < .) {
                    scol[i] = strtrim(strofreal(ncol[i], fmt))
                }
            }
            out[, j] = scol
        }
    }

    return(out)
}

end
