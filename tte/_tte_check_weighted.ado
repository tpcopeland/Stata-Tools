*! _tte_check_weighted Version 1.0.3  2026/03/01
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
        display as error "weight variable `weight' not found"
        display as error ""
        display as error "Run {bf:tte_weight} to estimate inverse probability weights."
        display as error "Requires {bf:tte_expand} to have been run first."
        display as error "Example:"
        display as error "  {cmd:tte_weight, switch_d_cov(age sex comorbidity)}"
        display as error "  {cmd:  stabilized truncate(1 99) nolog}"
        exit 111
    }
end
