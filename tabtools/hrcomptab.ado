*! hrcomptab Version 2.0.1  2026/08/28
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
        * return add runs on the error path too, and must: comptab posts its
        * analytical results before a failed export sets the return code, and
        * the package contract is that the payload still reaches the caller.
        * Pinned by "hrcomptab preserves r() after export failure" in
        * qa/test_package_adversarial.do.
        return add
        if `_sub_rc' exit `_sub_rc'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
