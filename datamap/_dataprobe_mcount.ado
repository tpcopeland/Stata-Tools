*! _dataprobe_mcount Version 1.10.5  2026/10/21
*! Mask one count for display under maskrare
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// A count k with 1 <= k < m prints as "<m"; zero and counts of m or more
// print as the number.  m = 0 turns masking off.  With a total n (the rows
// the count is taken from, printed elsewhere), a count whose complement
// n - k is between 1 and m - 1 prints as "all but <m", because k beside n
// would recover the small cell.  r(num) is the printed number, or missing
// when the count was masked, so a caller never stores a masked value in a
// numeric column.  hide = 1 (a by() group whose size is withheld) prints a
// count of m or more as [suppressed] as well: the count is a lower bound on
// the withheld size, and N minus the shown groups minus it would give back
// the other withheld groups.
program define _dataprobe_mcount, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        args k m n hide
        if "`m'" == "" local m 0
        if "`n'" == "" local n = .
        if "`hide'" == "" local hide 0
        local masked = (`m' > 0 & `k' >= 1 & `k' < `m')
        local cmask = 0
        local hmask = (!`masked' & `m' > 0 & `hide' == 1 & `k' >= `m' & `k' < .)
        if !`masked' & `m' > 0 & `n' < . & `k' >= 1 {
            local cmask = ((`n' - `k') >= 1 & (`n' - `k') < `m')
        }
        if `masked' {
            local s "<`m'"
            local num = .
        }
        else if `hmask' {
            local s "[suppressed]"
            local num = .
            local masked = 1
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
