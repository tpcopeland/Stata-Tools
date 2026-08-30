*! table1_tc Version 2.0.3  2026/08/30 - Descriptive Statistics Table Generator
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
    * return add runs on the error path too, and must: desctab posts its
    * analytical results before a failed export sets the return code, and the
    * package contract is that the payload still reaches the caller. Pinned by
    * "table1_tc preserves r() after export failure" in
    * qa/test_package_adversarial.do.
    return add
    if `rc' exit `rc'
end
