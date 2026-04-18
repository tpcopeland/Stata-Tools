*! _tabtools_guard Version 1.0.7  2026/04/18
*! Guard entry/exit and module auto-loading for tabtools
*! Author: Timothy P Copeland

program define _tabtools_guard, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _restore_varabbrev ""
    capture noisily {
        gettoken _tt_subcmd _tt_rest : 0, parse(",")
        local _tt_subcmd = lower(strtrim(subinstr("`_tt_subcmd'", ",", "", .)))

        if "`_tt_subcmd'" == "enter" {
            local 0 `"`_tt_rest'"'
            syntax [, SAVEDATA ]

            local _saved_varabbrev "$TABTOOLS_GUARD_VARABBREV"
            if "`_saved_varabbrev'" == "" local _saved_varabbrev "`_orig_varabbrev'"
            global TABTOOLS_GUARD_VARABBREV "`_saved_varabbrev'"
            local _restore_varabbrev "`_saved_varabbrev'"
            set varabbrev off

            capture program list _tabtools_validate_path
            if _rc {
                capture findfile _tabtools_common.ado
                if _rc == 0 run "`r(fn)'"
                else {
                    display as error "_tabtools_common.ado not found; reinstall tabtools"
                    exit 111
                }
            }

            foreach _tt_module in _tabtools_settings _tabtools_table_spec ///
                _tabtools_render_excel _tabtools_export _tabtools_collect_bridge {
                capture program list `_tt_module'
                if _rc {
                    capture findfile `_tt_module'.ado
                    if _rc == 0 run "`r(fn)'"
                    else {
                        display as error "`_tt_module'.ado not found; reinstall tabtools"
                        exit 111
                    }
                }
            }

            if "`savedata'" != "" {
                tempname _tt_guard_tag
                local _tt_guard_savedata `"`c(tmpdir)'/tabtools_guard_`_tt_guard_tag'.dta'"'
                quietly save "`_tt_guard_savedata'", replace
                global TABTOOLS_GUARD_DATAFILE "`_tt_guard_savedata'"
            }
            else {
                capture macro drop TABTOOLS_GUARD_DATAFILE
            }
        }
        else if "`_tt_subcmd'" == "exit" {
            local 0 `"`_tt_rest'"'
            syntax , RC(integer) [NOEXIT]
            local _restore_varabbrev "$TABTOOLS_GUARD_VARABBREV"
            if "`_restore_varabbrev'" == "" local _restore_varabbrev "`_orig_varabbrev'"

            capture putexcel clear
            capture mata: b.close_book()
            capture mata: mata drop b

            if "`_restore_varabbrev'" != "" {
                set varabbrev `_restore_varabbrev'
            }

            if "$TABTOOLS_GUARD_DATAFILE" != "" {
                capture erase "$TABTOOLS_GUARD_DATAFILE"
            }

            capture macro drop TABTOOLS_GUARD_VARABBREV
            capture macro drop TABTOOLS_GUARD_DATAFILE
            capture macro drop TABTOOLS_RS_FONT
            capture macro drop TABTOOLS_RS_FONTSIZE
            capture macro drop TABTOOLS_RS_BORDERSTYLE
            capture macro drop TABTOOLS_RS_HBORDER
            capture macro drop TABTOOLS_RS_HEADERCOLOR
            capture macro drop TABTOOLS_RS_ZEBRACOLOR
            capture macro drop TABTOOLS_RS_HEADERSHADE
            capture macro drop TABTOOLS_RS_ZEBRA
            capture macro drop TABTOOLS_RS_DIGITS
            capture macro drop TABTOOLS_RS_BOLDP
            capture macro drop TABTOOLS_RS_HIGHLIGHT
            capture macro drop TABTOOLS_RS_PDP
            capture macro drop TABTOOLS_RS_HIGHPDP
            capture macro drop TABTS_TITLE
            capture macro drop TABTS_HS
            capture macro drop TABTS_HE
            capture macro drop TABTS_DS
            capture macro drop TABTS_LV
            capture macro drop TABTS_NC
            capture macro drop TABTS_PC
            capture macro drop TABTS_MG
            capture macro drop TABTS_SR
            capture macro drop TABTS_RR
            capture macro drop TABTS_FT
            capture macro drop TABTS_SN
            capture macro drop TABTS_BB
            capture macro drop TABTS_WM
            capture macro drop TABTS_WS
            capture macro drop TABTS_EXX
            capture macro drop TABTS_ECSV
            capture macro drop TABTS_EFR
            capture macro drop TABTS_EDISP
            capture macro drop TABTS_TSC
            capture macro drop TABTS_DFC
            capture macro drop TABTS_CSC
            capture macro drop TABTS_BSC
            capture macro drop TABTS_HT
            capture macro drop TABTS_SHR
            capture macro drop TABTS_NF

            c_local _tabtools_guard_rc `rc'

            if `rc' > 0 & "`noexit'" == "" {
                exit `rc'
            }
        }
        else {
            display as error "_tabtools_guard requires subcommand enter or exit"
            exit 198
        }
    }
    local rc = _rc
    if `rc' & "`_restore_varabbrev'" != "" {
        set varabbrev `_restore_varabbrev'
    }
    if `rc' exit `rc'
end
