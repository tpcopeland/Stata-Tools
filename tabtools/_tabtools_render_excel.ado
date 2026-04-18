*! _tabtools_render_excel Version 1.0.7  2026/04/18
*! Shared Excel renderer for tabtools
*! Author: Timothy P Copeland

capture program drop _tabtools_render_excel
program define _tabtools_render_excel, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , XLSX(string) [SHEET(string) REPLACE]

        local _ts_num_data_cols "$TABTS_NC"
        local _ts_sheet_replace "$TABTS_SHR"
        local _ts_table_start_col "$TABTS_TSC"
        local _ts_data_font_start_col "$TABTS_DFC"
        local _ts_center_start_col "$TABTS_CSC"
        local _ts_bottom_border_start_col "$TABTS_BSC"
        local _ts_header_start "$TABTS_HS"
        local _ts_header_end "$TABTS_HE"
        local _ts_data_start "$TABTS_DS"
        local _ts_bold_best "$TABTS_BB"
        local _ts_section_rows "$TABTS_SR"
        local _ts_star_note "$TABTS_SN"
        local _ts_footnote "$TABTS_FT"
        local _ts_col_width_mode "$TABTS_WM"
        local _ts_col_widths "$TABTS_WS"
        local _ts_nformat "$TABTS_NF"

        local _font "$TABTOOLS_RS_FONT"
        local _fontsize = real("$TABTOOLS_RS_FONTSIZE")
        local _hborder "$TABTOOLS_RS_HBORDER"
        local _headercolor "$TABTOOLS_RS_HEADERCOLOR"
        local _zebracolor "$TABTOOLS_RS_ZEBRACOLOR"
        local _headershade "$TABTOOLS_RS_HEADERSHADE"
        local _zebra "$TABTOOLS_RS_ZEBRA"

        _tabtools_table_spec_validate

        if "`sheet'" == "" local sheet "Table"
        _tabtools_validate_sheet "`sheet'" "sheet()"
        _tabtools_validate_path "`xlsx'" "xlsx()"

        local _font "$TABTOOLS_RS_FONT"
        local _fontsize = real("$TABTOOLS_RS_FONTSIZE")
        local _hborder "$TABTOOLS_RS_HBORDER"
        local _headercolor "$TABTOOLS_RS_HEADERCOLOR"
        local _zebracolor "$TABTOOLS_RS_ZEBRACOLOR"
        local _headershade "$TABTOOLS_RS_HEADERSHADE"
        local _zebra "$TABTOOLS_RS_ZEBRA"

        local _ts_header_start = real("$TABTS_HS")
        local _ts_header_end = real("$TABTS_HE")
        local _ts_data_start = real("$TABTS_DS")
        local _ts_num_data_cols = real("$TABTS_NC")
        local _ts_bold_best "$TABTS_BB"
        local _ts_section_rows "$TABTS_SR"
        local _ts_footnote `"$TABTS_FT"'
        local _ts_star_note `"$TABTS_SN"'
        local _ts_col_width_mode "$TABTS_WM"
        local _ts_col_widths "$TABTS_WS"
        local _ts_table_start_col = real("$TABTS_TSC")
        local _ts_data_font_start_col = real("$TABTS_DFC")
        local _ts_center_start_col = real("$TABTS_CSC")
        local _ts_bottom_border_start_col = real("$TABTS_BSC")
        local _ts_sheet_replace "$TABTS_SHR"
        local _ts_nformat `"$TABTS_NF"'

        capture confirm variable title
        local _has_title = (_rc == 0)

        local _num_display_cols = `_ts_num_data_cols'
        local _num_export_cols = `_num_display_cols' + `_has_title'

        local _order_vars ""
        if `_has_title' local _order_vars "title"
        forvalues _tt_i = 1/`_num_display_cols' {
            local _order_vars "`_order_vars' c`_tt_i'"
        }
        order `_order_vars'

        local _sheetreplace = ""
        if "`replace'" != "" | "`_ts_sheet_replace'" == "1" {
            local _sheetreplace "sheetreplace"
        }

        capture export excel using "`xlsx'", sheet("`sheet'") `_sheetreplace'
        if _rc {
            local _export_rc = _rc
            display as error "Failed to export to `xlsx'"
            display as error "Hint: ensure the xlsx file is not open in another application"
            exit `_export_rc'
        }

        _tabtools_build_col_letters `_num_export_cols'
        local _letters "`result'"
        local _lastcol : word `_num_export_cols' of `_letters'

        local _table_start_col = real("`_ts_table_start_col'")
        local _datafont_start_col = real("`_ts_data_font_start_col'")
        local _center_start_col = real("`_ts_center_start_col'")
        local _bottom_start_col = real("`_ts_bottom_border_start_col'")

        local _table_start : word `_table_start_col' of `_letters'
        local _datafont_start : word `_datafont_start_col' of `_letters'
        local _center_start : word `_center_start_col' of `_letters'
        local _bottom_start : word `_bottom_start_col' of `_letters'

        local _data_end = _N

        quietly putexcel set "`xlsx'", sheet("`sheet'") modify

        if `_has_title' {
            quietly putexcel (A1:`_lastcol'1), merge bold txtwrap left vcenter ///
                font("`_font'", `=`_fontsize' + 2')
        }

        if `_ts_header_start' <= `_ts_header_end' {
            quietly putexcel (`_table_start'`_ts_header_start':`_lastcol'`_ts_header_end'), ///
                bold hcenter font("`_font'", `_fontsize')
            quietly putexcel (`_table_start'`_ts_header_start':`_lastcol'`_ts_header_end'), txtwrap
            quietly putexcel (`_table_start'`_ts_header_start':`_lastcol'`_ts_header_start'), ///
                border(top, `_hborder')
            quietly putexcel (`_table_start'`_ts_header_end':`_lastcol'`_ts_header_end'), ///
                border(bottom, `_hborder')
            if "`_headershade'" != "" {
                quietly putexcel (`_table_start'`_ts_header_start':`_lastcol'`_ts_header_end'), ///
                    fpattern(solid, "`_headercolor'")
            }
        }

        if `_ts_data_start' <= `_data_end' {
            quietly putexcel (`_datafont_start'`_ts_data_start':`_lastcol'`_data_end'), ///
                font("`_font'", `_fontsize')
            if `_center_start_col' <= `_num_export_cols' {
                quietly putexcel (`_center_start'`_ts_data_start':`_lastcol'`_data_end'), hcenter
            }
        }

        if "`_zebra'" != "" & `_ts_data_start' <= `_data_end' {
            forvalues _tt_row = `=`_ts_data_start'+1'(2)`_data_end' {
                quietly putexcel (`_table_start'`_tt_row':`_lastcol'`_tt_row'), ///
                    fpattern(solid, "`_zebracolor'")
            }
        }

        foreach _tt_pair of local _ts_bold_best {
            gettoken _tt_row _tt_col : _tt_pair, parse(":")
            local _tt_col = subinstr("`_tt_col'", ":", "", 1)
            local _tt_abs_col = `_tt_col' + `_has_title'
            if `_tt_abs_col' >= 1 & `_tt_abs_col' <= `_num_export_cols' {
                local _tt_letter : word `_tt_abs_col' of `_letters'
                quietly putexcel `_tt_letter'`_tt_row', bold
            }
        }

        foreach _tt_row of local _ts_section_rows {
            if `_tt_row' >= `_ts_data_start' & `_tt_row' <= `_data_end' {
                quietly putexcel (`_table_start'`_tt_row':`_lastcol'`_tt_row'), border(top, `_hborder')
            }
        }

        if `_bottom_start_col' <= `_num_export_cols' & `_data_end' >= `_ts_header_end' {
            quietly putexcel (`_bottom_start'`_data_end':`_lastcol'`_data_end'), border(bottom, `_hborder')
        }

        local _foot_row = `_data_end'
        if `"`_ts_star_note'"' != "" {
            quietly _tabtools_footnote `"`_ts_star_note'"' "`_lastcol'" `_foot_row' "`_font'" `_fontsize'
            local _foot_row = `_foot_row' + 1
        }
        if `"`_ts_footnote'"' != "" {
            quietly _tabtools_footnote `"`_ts_footnote'"' "`_lastcol'" `_foot_row' "`_font'" `_fontsize'
        }

        quietly putexcel clear

        if "`_ts_col_width_mode'" == "fixed" {
            mata: b = xl()
            mata: b.load_book("`xlsx'")
            mata: b.set_sheet("`sheet'")

            local _nwidths : word count `_ts_col_widths'
            if `_nwidths' == 1 {
                local _w1 : word 1 of `_ts_col_widths'
                forvalues _tt_col = 1/`_num_export_cols' {
                    mata: b.set_column_width(`_tt_col', `_tt_col', `_w1')
                }
            }
            else if `_nwidths' == 2 {
                local _w1 : word 1 of `_ts_col_widths'
                local _w2 : word 2 of `_ts_col_widths'
                mata: b.set_column_width(1, 1, `_w1')
                if `_num_export_cols' >= 2 {
                    forvalues _tt_col = 2/`_num_export_cols' {
                        mata: b.set_column_width(`_tt_col', `_tt_col', `_w2')
                    }
                }
            }
            else if `_nwidths' == 3 {
                local _w1 : word 1 of `_ts_col_widths'
                local _w2 : word 2 of `_ts_col_widths'
                local _w3 : word 3 of `_ts_col_widths'
                mata: b.set_column_width(1, 1, `_w1')
                if `_num_export_cols' >= 2 {
                    mata: b.set_column_width(2, 2, `_w2')
                }
                if `_num_export_cols' >= 3 {
                    forvalues _tt_col = 3/`_num_export_cols' {
                        mata: b.set_column_width(`_tt_col', `_tt_col', `_w3')
                    }
                }
            }
            else if `_nwidths' == `_num_export_cols' {
                forvalues _tt_col = 1/`_num_export_cols' {
                    local _tt_width : word `_tt_col' of `_ts_col_widths'
                    mata: b.set_column_width(`_tt_col', `_tt_col', `_tt_width')
                }
            }

            mata: b.close_book()
        }

        capture mata: mata drop b

        capture confirm file "`xlsx'"
        if _rc {
            display as error "Export command succeeded but file not found"
            exit 601
        }

        c_local _tabtools_render_xlsx "`xlsx'"
        c_local _tabtools_render_sheet "`sheet'"
    }
    local rc = _rc
    capture putexcel clear
    capture mata: b.close_book()
    capture mata: mata drop b
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
