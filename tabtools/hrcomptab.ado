*! hrcomptab Version 2.0.0  2026/08/19
*! Compatibility wrapper for comptab rate-frame composition
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define hrcomptab, rclass
    version 17.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax anything(name=rateframe), *
        capture noisily comptab, rateframe(`rateframe') `options'
        local _sub_rc = _rc
        return add
        if `_sub_rc' exit `_sub_rc'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
