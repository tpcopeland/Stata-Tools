*! _tabtools_csv_write Version 1.9.8  2026/07/13
*! Write visible table columns as CSV without Stata variable names
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

program define _tabtools_csv_write
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax using/ [, LABELVar(name)]

        capture program list _tabtools_validate_path
        if _rc {
            capture findfile _tabtools_common.ado
            if _rc == 0 {
                run "`r(fn)'"
            }
            else {
                noisily display as error "_tabtools_common.ado not found; reinstall tabtools"
                exit 111
            }
        }

        _tabtools_validate_path `"`using'"' "csv()"

        local _visible_opts ""
        if `"`labelvar'"' != "" local _visible_opts "labelvar(`labelvar')"
        _tabtools_visible_vars, `_visible_opts'
        local _vars "`_tabtools_visible_vars'"

        export delimited `_vars' using `"`using'"', replace novarnames
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
