*! _aft_check_fitted Version 1.0.0  2026/03/14
*! Verify aft_fit has been run
*! Author: Timothy P Copeland

program define _aft_check_fitted
    version 16.0
    set varabbrev off
    set more off

    local fitted : char _dta[_aft_fitted]
    if "`fitted'" != "1" {
        display as error "aft_fit has not been run"
        display as error ""
        display as error "Run {bf:aft_fit} first to fit the AFT model."
        display as error "Example:"
        display as error "  {cmd:aft_fit x1 x2}"
        exit 198
    }
end
