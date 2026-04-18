*! _tabtools_table_spec Version 1.0.7  2026/04/18
*! Canonical table-spec helpers for tabtools
*! Author: Timothy P Copeland

capture program drop _tabtools_table_spec
program define _tabtools_table_spec, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        gettoken _tt_subcmd _tt_rest : 0, parse(",")
        local _tt_subcmd = lower(strtrim(subinstr("`_tt_subcmd'", ",", "", .)))

        if "`_tt_subcmd'" == "init" {
            _tabtools_table_spec_init `_tt_rest'
        }
        else if "`_tt_subcmd'" == "validate" {
            _tabtools_table_spec_validate
        }
        else {
            display as error "_tabtools_table_spec requires init or validate"
            exit 198
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _tabtools_table_spec_init
program define _tabtools_table_spec_init, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , [TITLE(string) HEADERStart(integer 2) HEADEREnd(integer 2) ///
            DATAStart(integer 3) LABELVar(string) NUMCOLS(integer -1) ///
            PCOLS(string) MERGEGroups(string) SECTIONRows(string) ///
            REFRows(string) FOOTnote(string) STARNOte(string) ///
            BOLDBEst(string) WIDTHMode(string) WIDTHS(string) ///
            EXPORTXlsx(string) EXPORTCsv(string) EXPORTFrame(string) ///
            EXPORTDisplay(string) TABLEStart(integer -1) DATAFONTStart(integer -1) ///
            CENTERStart(integer -1) BOTTOMStart(integer -1) HASTITLE(integer -1) ///
            SHEETREPLACE(integer -1) NFORMAT(string) ]

        local _ts_has_title = `hastitle'
        if `_ts_has_title' == -1 {
            capture confirm variable title
            local _ts_has_title = (_rc == 0)
        }

        local _ts_numcols = `numcols'
        if `_ts_numcols' == -1 {
            ds c*
            local _ts_numcols : word count `r(varlist)'
        }

        local _ts_table_start = `tablestart'
        if `_ts_table_start' == -1 {
            local _ts_table_start = 1 + `_ts_has_title'
        }

        local _ts_datafont_start = `datafontstart'
        if `_ts_datafont_start' == -1 local _ts_datafont_start = `_ts_table_start'

        local _ts_center_start = `centerstart'
        if `_ts_center_start' == -1 local _ts_center_start = `_ts_table_start'

        local _ts_bottom_start = `bottomstart'
        if `_ts_bottom_start' == -1 local _ts_bottom_start = `_ts_table_start'

        local _ts_sheetreplace = `sheetreplace'
        if `_ts_sheetreplace' == -1 local _ts_sheetreplace = 1

        local _ts_width_mode = lower(strtrim("`widthmode'"))
        if "`_ts_width_mode'" == "" local _ts_width_mode "none"

        c_local _ts_title `"`title'"'
        c_local _ts_header_start `headerstart'
        c_local _ts_header_end `headerend'
        c_local _ts_data_start `datastart'
        c_local _ts_label_var "`labelvar'"
        c_local _ts_num_data_cols `_ts_numcols'
        c_local _ts_pcols "`pcols'"
        c_local _ts_merge_groups "`mergegroups'"
        c_local _ts_section_rows "`sectionrows'"
        c_local _ts_ref_rows "`refrows'"
        c_local _ts_footnote `"`footnote'"'
        c_local _ts_star_note `"`starnote'"'
        c_local _ts_bold_best "`boldbest'"
        c_local _ts_col_width_mode "`_ts_width_mode'"
        c_local _ts_col_widths "`widths'"
        c_local _ts_export_xlsx `"`exportxlsx'"'
        c_local _ts_export_csv `"`exportcsv'"'
        c_local _ts_export_frame `"`exportframe'"'
        c_local _ts_export_display `"`exportdisplay'"'
        c_local _ts_table_start_col `_ts_table_start'
        c_local _ts_data_font_start_col `_ts_datafont_start'
        c_local _ts_center_start_col `_ts_center_start'
        c_local _ts_bottom_border_start_col `_ts_bottom_start'
        c_local _ts_has_title_col `_ts_has_title'
        c_local _ts_sheet_replace `_ts_sheetreplace'
        c_local _ts_nformat `"`nformat'"'

        global TABTS_TITLE `"`title'"'
        global TABTS_HS `headerstart'
        global TABTS_HE `headerend'
        global TABTS_DS `datastart'
        global TABTS_LV "`labelvar'"
        global TABTS_NC `_ts_numcols'
        global TABTS_PC "`pcols'"
        global TABTS_MG "`mergegroups'"
        global TABTS_SR "`sectionrows'"
        global TABTS_RR "`refrows'"
        global TABTS_FT `"`footnote'"'
        global TABTS_SN `"`starnote'"'
        global TABTS_BB "`boldbest'"
        global TABTS_WM "`_ts_width_mode'"
        global TABTS_WS "`widths'"
        global TABTS_EXX `"`exportxlsx'"'
        global TABTS_ECSV `"`exportcsv'"'
        global TABTS_EFR `"`exportframe'"'
        global TABTS_EDISP `"`exportdisplay'"'
        global TABTS_TSC `_ts_table_start'
        global TABTS_DFC `_ts_datafont_start'
        global TABTS_CSC `_ts_center_start'
        global TABTS_BSC `_ts_bottom_start'
        global TABTS_HT `_ts_has_title'
        global TABTS_SHR `_ts_sheetreplace'
        global TABTS_NF `"`nformat'"'

        _tabtools_table_spec_validate
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _tabtools_table_spec_validate
program define _tabtools_table_spec_validate, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        local _ts_num_data_cols "$TABTS_NC"
        local _ts_data_start "$TABTS_DS"
        local _ts_header_end "$TABTS_HE"
        local _ts_table_start_col "$TABTS_TSC"
        local _ts_center_start_col "$TABTS_CSC"
        local _ts_bottom_border_start_col "$TABTS_BSC"
        local _ts_pcols "$TABTS_PC"
        local _ts_merge_groups "$TABTS_MG"

        if "`_ts_num_data_cols'" == "" | real("`_ts_num_data_cols'") <= 0 {
            display as error "table-spec requires numcols() > 0"
            exit 198
        }
        if real("`_ts_data_start'") <= real("`_ts_header_end'") {
            display as error "table-spec requires datastart() > headerend()"
            exit 198
        }
        if real("`_ts_table_start_col'") <= 0 {
            display as error "table-spec table start column must be positive"
            exit 198
        }
        if real("`_ts_center_start_col'") <= 0 {
            display as error "table-spec center start column must be positive"
            exit 198
        }
        if real("`_ts_bottom_border_start_col'") <= 0 {
            display as error "table-spec bottom border start column must be positive"
            exit 198
        }

        foreach _tt_col of local _ts_pcols {
            capture confirm integer number `_tt_col'
            if _rc | `_tt_col' < 1 | `_tt_col' > `_ts_num_data_cols' {
                display as error "table-spec pcols() contains invalid column `_tt_col'"
                exit 198
            }
        }

        local _tt_prev_end = 0
        foreach _tt_group of local _ts_merge_groups {
            gettoken _tt_start _tt_end : _tt_group, parse(":")
            local _tt_end = subinstr("`_tt_end'", ":", "", 1)
            capture confirm integer number `_tt_start'
            if _rc exit 198
            capture confirm integer number `_tt_end'
            if _rc exit 198
            if `_tt_start' > `_tt_end' {
                display as error "table-spec mergegroups() has start > end in `_tt_group'"
                exit 198
            }
            if `_tt_start' <= `_tt_prev_end' {
                display as error "table-spec mergegroups() overlap at `_tt_group'"
                exit 198
            }
            local _tt_prev_end = `_tt_end'
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
