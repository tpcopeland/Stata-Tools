*! _datacheck_mshare Version 1.8.2  2026/10/01
*! Mask a count and its share of a known total for display under maskrare
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// k of n.  Under a mask m > 0 a count with 1 <= k < m prints as "<m" and
// its percentage as ".".  When the complement n - k is the small cell, k
// itself would reveal it next to a published n, so k prints as
// "all but <m" and the percentage as "." as well.  A zero count prints as 0
// with its share: it reveals nothing about the total.  r(pcttxt) is the
// share ready to print: "12.3%", "[masked]" when masked, or "n/a" when n is
// 0; a caller prints it instead of appending "%" to r(pct).
program define _datacheck_mshare, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        args k n m
        if "`m'" == "" local m 0
        local masked = 0
        local num = `k'
        local cnt = strtrim(string(`k', "%20.0f"))
        local pct "."
        if `n' > 0 & `n' < . local pct = strtrim(string(100 * `k' / `n', "%9.1f"))
        if `m' > 0 & `k' >= 1 & `k' < `m' {
            local masked = 1
            local cnt "<`m'"
            local pct "."
            local num = .
        }
        else if `m' > 0 & `k' >= 1 & (`n' - `k') >= 1 & (`n' - `k') < `m' {
            local masked = 1
            local cnt "all but <`m'"
            local pct "."
            local num = .
        }
        local pcttxt = cond(`masked', "[masked]", cond("`pct'" == ".", "n/a", "`pct'%"))
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local cnt "`cnt'"
    return local pct "`pct'"
    return local pcttxt "`pcttxt'"
    return scalar num = `num'
    return scalar masked = `masked'
end
