*! _mlearn_auto_detect Version 1.0.0  2026/03/15
*! Auto-detect task type from outcome variable
*! Author: Timothy P Copeland

program define _mlearn_auto_detect
    version 16.0
    set varabbrev off
    set more off

    args outcome touse

    * Check if binary 0/1
    capture assert inlist(`outcome', 0, 1) if `touse'
    if _rc == 0 {
        c_local _mlearn_detected_task "classification"
        exit
    }

    * Count unique values
    tempvar tag
    quietly egen `tag' = tag(`outcome') if `touse'
    quietly count if `tag' == 1 & `touse'
    local n_unique = r(N)

    if `n_unique' <= 10 {
        * Check if all values are integers
        capture assert `outcome' == round(`outcome') if `touse'
        if _rc == 0 {
            c_local _mlearn_detected_task "multiclass"
            exit
        }
    }

    c_local _mlearn_detected_task "regression"
end
