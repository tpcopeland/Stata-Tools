*! _tvexpose_fast_data Version 1.17.0  2026/08/28
*! Test whether cleaned episodes satisfy the fast constructor's data contract
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

program define _tvexpose_fast_data, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        syntax , REFerence(string) [MERGEdays(integer 0)]

        foreach v in id exp_start exp_stop exp_value {
            confirm variable `v', exact
        }

        local _eligible = 1
        local _reason ""
        if _N > 0 {
            tempvar _bad _ovl _mergeable
            * Leave a deterministic order even when the verdict is negative.
            * The post-clean dispatch may hand the same in-memory data back to
            * the retained constructor, whose by-group scans require this key.
            sort id exp_start exp_stop exp_value
            quietly generate byte `_bad' = missing(exp_value) | ///
                exp_value != floor(exp_value) | exp_value == `reference'
            quietly count if `_bad'
            if r(N) > 0 {
                local _eligible = 0
                local _reason "noninteger, missing, or reference-coded episode"
            }
            if `_eligible' {
                quietly by id: generate byte `_ovl' = ///
                    _n < _N & exp_start[_n+1] <= exp_stop
                quietly count if `_ovl'
                if r(N) > 0 {
                    local _eligible = 0
                    local _reason "overlapping episode"
                }
            }
            if `_eligible' & `mergedays' > 0 {
                quietly by id: generate byte `_mergeable' = _n < _N & ///
                    exp_value == exp_value[_n+1] & ///
                    exp_start[_n+1] - exp_stop <= `mergedays'
                quietly count if `_mergeable'
                if r(N) > 0 {
                    local _eligible = 0
                    local _reason "mergeable same-category episode"
                }
            }
        }

        return local reason "`_reason'"
        return scalar eligible = `_eligible'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
