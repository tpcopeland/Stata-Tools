*! _datacheck_mcount Version 1.8.0  2026/09/30
*! Mask one count for display under maskrare
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// A count k with 1 <= k < m prints as "<m"; zero and counts of m or more
// print as the number.  m = 0 turns masking off.  With a total n (the rows
// the count is taken from, printed elsewhere), a count whose complement
// n - k is between 1 and m - 1 prints as "all but <m", because k beside n
// would recover the small cell.  r(num) is the printed number, or missing
// when the count was masked, so a caller never stores a masked value in a
// numeric column.
program define _datacheck_mcount, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        args k m n
        if "`m'" == "" local m 0
        if "`n'" == "" local n = .
        local masked = (`m' > 0 & `k' >= 1 & `k' < `m')
        local cmask = 0
        if !`masked' & `m' > 0 & `n' < . & `k' >= 1 {
            local cmask = ((`n' - `k') >= 1 & (`n' - `k') < `m')
        }
        if `masked' {
            local s "<`m'"
            local num = .
        }
        else if `cmask' {
            local s "all but <`m'"
            local num = .
            local masked = 1
        }
        else {
            local s = strtrim(string(`k', "%20.0f"))
            local num = `k'
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local s "`s'"
    return scalar num = `num'
    return scalar masked = `masked'
end
