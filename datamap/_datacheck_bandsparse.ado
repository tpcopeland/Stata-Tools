*! _datacheck_bandsparse Version 1.9.1  2026/10/04
*! Parse the contents of datacheck bands()
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// bands() holds the sanity-band gates of a call, written as datacheck
// options: expectn(), stat(), inrange(), coverage(), groupstat() (with
// band()), heaping() (with max()), and complete() (with min()).  Anything
// else is refused: an invariant family placed inside bands() would become
// a band and could be warned past under bandwarn.
program define _datacheck_bandsparse, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        local 0 `", `macval(0)'"'
        capture syntax [, EXPECTN(numlist integer max=2) STAT(string asis) ///
            INRANGE(string asis) COVERAGE(string asis) GROUPSTAT(string asis) ///
            HEAPING(string asis) COMPLETE(string asis)]
        if _rc {
            display as error "bands() accepts only expectn(), stat(), inrange(), coverage(), groupstat(), heaping(), and complete()"
            exit 198
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local expectn "`expectn'"
    foreach o in stat inrange coverage groupstat heaping complete {
        return local `o' `"`macval(`o')'"'
    }
end
