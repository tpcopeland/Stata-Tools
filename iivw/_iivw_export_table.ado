*! _iivw_export_table Version 1.3.0  2026/05/27
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
        [XLSX(string asis) EXCEL(string asis) SHEET(string asis) ///
         REPLACE OPEN TITLE(string asis) FOOTNOTE(string asis) ///
         DECimals(integer 4)]

    local __iivw_dq = char(34)
    foreach __iivw_opt in xlsx excel sheet title footnote {
        local __iivw_tmp `"``__iivw_opt''"'
        local __iivw_tmp = strtrim(`"`__iivw_tmp'"')
        local __iivw_tmp = subinstr(`"`__iivw_tmp'"', `"`__iivw_dq'"', "", .)
        local `__iivw_opt' `"`__iivw_tmp'"'
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
    if `__iivw_return_cols' > 26 {
        display as error "iivw Excel export currently supports at most 26 columns"
        error 498
    }

    local __iivw_xlsx `"`xlsx'"'
    if `"`excel'"' != "" {
        if `"`__iivw_xlsx'"' != "" & `"`__iivw_xlsx'"' != `"`excel'"' {
            display as error "xlsx() and excel() specify different files"
            error 198
        }
        local __iivw_xlsx `"`excel'"'
    }
    if `"`__iivw_xlsx'"' == "" {
        display as error "xlsx() or excel() is required for reporting export"
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
        display as error "xlsx()/excel() must name a .xlsx file"
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

    capture confirm file `"`__iivw_xlsx'"'
    local __iivw_xlsx_exists = (_rc == 0)
    if `__iivw_xlsx_exists' {
        quietly putexcel set `"`__iivw_xlsx'"', modify sheet(`"`sheet'"', replace)
    }
    else {
        quietly putexcel set `"`__iivw_xlsx'"', replace sheet(`"`sheet'"')
    }
    local __iivw_putexcel_open = 1

    local __iivw_header_row = 3
    local __iivw_first_data = `__iivw_header_row' + 1
    local __iivw_last_col = char(64 + `__iivw_return_cols')
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
capture mata: mata drop _iivw_xlsx_style()
local __iivw_mata_drop_rc = _rc

mata:
mata set matastrict on

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

end
