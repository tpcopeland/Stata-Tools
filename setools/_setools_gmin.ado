*! _setools_gmin Version 1.5.6  2026/08/28
*! setools internal: sort-free in-place group minimum
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

program define _setools_gmin, nclass
    version 16.0
    local _varabbrev `c(varabbrev)'
    set varabbrev off

    capture noisily {
        syntax varname(numeric), BY(varname)

        quietly by `by': replace `varlist' = ///
            min(`varlist', `varlist'[_n - 1]) if _n > 1
        quietly by `by': replace `varlist' = `varlist'[_N]
    }
    local rc = _rc
    set varabbrev `_varabbrev'
    if `rc' exit `rc'
end
