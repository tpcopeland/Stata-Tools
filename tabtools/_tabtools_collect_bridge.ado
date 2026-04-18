*! _tabtools_collect_bridge Version 1.0.7  2026/04/18
*! Collect export/import normalization bridge for tabtools
*! Author: Timothy P Copeland

capture program drop _tabtools_collect_bridge
program define _tabtools_collect_bridge, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        _tabtools_collect_export `0'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _tabtools_collect_export
program define _tabtools_collect_export, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [, HEADERRows(integer 0) ]

        capture quietly collect query row
        if _rc {
            noisily display as error "No active collect table found"
            noisily display as error "Run table or collect commands with {bf:collect:} prefix first"
            exit 119
        }

        collect style column, dups(center)

        tempfile _tt_collect_export_base
        local _tt_collect_export "`_tt_collect_export_base'.xlsx"
        capture collect export "`_tt_collect_export'", sheet("temp", replace)
        if _rc {
            display as error "Failed to export collect table"
            exit _rc
        }

        capture import excel "`_tt_collect_export'", sheet("temp") clear allstring
        local _import_rc = _rc
        capture erase "`_tt_collect_export'"
        if `_import_rc' {
            display as error "Failed to import temporary collect export"
            exit `_import_rc'
        }

        if _N == 0 | c(k) == 0 {
            display as error "Collect table is empty"
            exit 2000
        }

        local _tt_numcols = c(k)
        local _tt_col = 0
        foreach _tt_var of varlist * {
            local ++_tt_col
            local _tt_new = "c`_tt_col'"
            if "`_tt_var'" != "`_tt_new'" {
                rename `_tt_var' `_tt_new'
            }
        }

        local _tt_headerrows = `headerrows'
        if `_tt_headerrows' == 0 {
            local _tt_headerrows = 1
            if _N >= 2 {
                local _tt_numeric = 0
                forvalues _tt_col = 1/`_tt_numcols' {
                    local _tt_cell = c`_tt_col'[2]
                    local _tt_clean = subinstr(`"`_tt_cell'"', ",", "", .)
                    local _tt_num = real(`"`_tt_clean'"')
                    if !missing(`_tt_num') local ++_tt_numeric
                }
                if `_tt_numeric' < ceil(`_tt_numcols' / 2) {
                    local _tt_headerrows = min(2, _N)
                }
            }
        }

        c_local _tabtools_collect_rows `_N'
        c_local _tabtools_collect_cols `c(k)'
        c_local _tabtools_collect_headerrows `_tt_headerrows'
        c_local _cb_header_rows `_tt_headerrows'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
