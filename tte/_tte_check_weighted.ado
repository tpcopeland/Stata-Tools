*! _tte_check_weighted Version 1.0.2  2026/02/28
*! Verify weight variable exists
*! Author: Timothy P Copeland

program define _tte_check_weighted
    version 16.0
    set varabbrev off
    set more off

    syntax [, weight(string)]

    if "`weight'" == "" local weight "_tte_weight"

    capture confirm variable `weight'
    if _rc != 0 {
        display as error "weight variable `weight' not found; run {bf:tte_weight} first"
        exit 111
    }
end
