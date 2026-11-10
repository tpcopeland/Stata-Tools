*! _dataprobe_snapshot Version 2.0.0  2026/11/10
*! dataprobe snapshot(): the profile rows, and the key they were taken with, in a frame
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// 2.0.0 (F6).  Frame `name' gets the rows saving() writes (the 27 saving()
// columns plus varname and dc_class, from frame `cur'), and the
// characteristics diff() reads:
//   _dta[dataprobe_key]      the key: key() (the call's id() or isid()),
//                            else the first profiled variable, in order,
//                            with no missing value and a censored or
//                            full distinct count that -isid- confirms (at
//                            most 10 tried, integer and string types
//                            first); "" when none
//   _dta[dataprobe_keyuniq]  1 when the key identifies the rows, 0 when not
//   _dta[dataprobe_N]        the rows profiled
// The data in memory is the working sample; its row order is unchanged.
program define _dataprobe_snapshot, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local key ""
    local ku = .
    capture noisily {
        syntax, CUR(name) NAME(name) NOBS(integer) [REPLACE KEY(string)]
        if "`key'" != "" {
            capture isid `key', missok
            local ku = (_rc == 0)
        }
        else {
            // candidates: no missing value, a censored or a full count
            local c1 ""
            local c2 ""
            frame `cur' {
                forvalues i = 1/`=_N' {
                    if missing[`i'] != 0 continue
                    if !(unique_capped[`i'] == 1 | unique[`i'] == N[`i']) continue
                    local t = storage_type[`i']
                    if "`t'" == "strL" continue
                    local v = variable[`i']
                    if inlist("`t'", "byte", "int", "long") | substr("`t'", 1, 3) == "str" {
                        local c1 "`c1' `v'"
                    }
                    else local c2 "`c2' `v'"
                }
            }
            local tries = 0
            foreach v in `c1' `c2' {
                if `tries' >= 10 continue, break
                local ++tries
                capture isid `v', missok
                if !_rc {
                    local key "`v'"
                    local ku = 1
                    continue, break
                }
            }
        }
        if "`replace'" != "" capture frame drop `name'
        frame copy `cur' `name'
        frame `name' {
            quietly generate str32 varname = variable
            quietly generate str20 dc_class = class
            char _dta[dataprobe_key] "`key'"
            if "`key'" != "" char _dta[dataprobe_keyuniq] "`ku'"
            char _dta[dataprobe_N] "`nobs'"
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
    return local key "`key'"
    return scalar key_unique = `ku'
end
