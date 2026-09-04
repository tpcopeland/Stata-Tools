*! _psdash_graph_export Version 1.7.1  2026/09/04
*! Shared graph export side effect
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass
*! Internal helper

program define _psdash_graph_export, nclass
    version 16.0
    local _vao = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , SAVing(string)

        noisily graph export "`saving'", replace
    }
    local rc = _rc
    set varabbrev `_vao'
    if `rc' == 0 return clear
    if `rc' exit `rc'
end
