*! _tabtools_export Version 1.0.7  2026/04/18
*! Shared export dispatcher for tabtools
*! Author: Timothy P Copeland

capture program drop _tabtools_export
program define _tabtools_export, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [, XLSX(string) SHEET(string) CSV(string) ///
            FRAME(string) DISplay OPEN REPLACE ]

        local _ts_title "$TABTS_TITLE"
        local _ts_header_start "$TABTS_HS"
        local _ts_data_start "$TABTS_DS"
        local _ts_num_data_cols "$TABTS_NC"
        local _ts_star_note "$TABTS_SN"
        local _ts_footnote "$TABTS_FT"

        _tabtools_table_spec_validate

        local _ts_title `"$TABTS_TITLE"'
        local _ts_header_start = real("$TABTS_HS")
        local _ts_data_start = real("$TABTS_DS")
        local _ts_num_data_cols = real("$TABTS_NC")
        local _ts_star_note `"$TABTS_SN"'
        local _ts_footnote `"$TABTS_FT"'

        local _has_xlsx = (`"`xlsx'"' != "")
        local _show_console = (`_has_xlsx' == 0 | "`display'" != "")

        if `_show_console' {
            noisily _tabtools_console_display `_ts_num_data_cols' `"`_ts_title'"', ///
                datastart(`_ts_data_start') headerstart(`_ts_header_start')
            if `"`_ts_star_note'"' != "" {
                noisily display as text `"`_ts_star_note'"'
            }
            if `"`_ts_footnote'"' != "" {
                noisily display as text `"`_ts_footnote'"'
            }
            noisily display as text ""
        }

        if `"`csv'"' != "" {
            _tabtools_validate_path "`csv'" "csv()"
            export delimited using "`csv'", replace
            capture confirm file "`csv'"
            if _rc {
                display as error "CSV export completed but file was not created"
                exit 601
            }
            c_local _tabtools_export_csv "`csv'"
        }

        if `"`frame'"' != "" {
            _tabtools_frame_put `"`frame'"'
            c_local _tabtools_export_frame "`_frame_name'"
        }

        if `_has_xlsx' {
            _tabtools_render_excel, xlsx(`"`xlsx'"') sheet(`"`sheet'"') `replace'
            noisily display as text "Exported to " as result `"`xlsx'"' ///
                as text ", sheet " as result `"`sheet'"'
            c_local _tabtools_export_xlsx "`xlsx'"
            c_local _tabtools_export_sheet "`sheet'"
        }

        if "`open'" != "" & `_has_xlsx' {
            _tabtools_open_file "`xlsx'"
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
