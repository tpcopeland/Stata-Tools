*! _tabtools_visible_vars Version 1.9.8  2026/07/13
*! Resolve visible table variables for CSV and Markdown exports
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

program define _tabtools_visible_vars
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax [, LABELVar(name)]

        quietly ds
        local _allvars `r(varlist)'
        if "`_allvars'" == "" {
            noisily display as error "No variables available for export"
            exit 111
        }

        local _vars ""
        if `"`labelvar'"' != "" {
            capture confirm variable `labelvar'
            if !_rc local _vars "`labelvar'"
        }

        local _cvars ""
        foreach _v of local _allvars {
            if regexm("`_v'", "^c[0-9]+$") local _cvars "`_cvars' `_v'"
        }

        if `"`_cvars'"' != "" {
            local _vars "`_vars' `_cvars'"
        }
        else {
            foreach _v of local _allvars {
                if regexm("`_v'", "(_length|_max)$") continue
                if regexm("`_v'", "^ref[0-9]+$") continue
                local _vars "`_vars' `_v'"
            }
        }

        local _vars : list uniq _vars
        local _vars : list _vars & _allvars
        local _vars : list clean _vars
        if "`_vars'" == "" {
            noisily display as error "No visible output columns available for export"
            exit 111
        }

        c_local _tabtools_visible_vars "`_vars'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
