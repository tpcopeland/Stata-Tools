*! table1_tc Version 2.1.0  2026/08/19 - Descriptive Statistics Table Generator
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Frontend for the consolidated desctab engine

program define table1_tc, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        desctab `0'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    return add
    if `rc' exit `rc'
end
