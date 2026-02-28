*! _tte_check_fitted Version 1.0.2  2026/02/28
*! Verify model has been fitted
*! Author: Timothy P Copeland

program define _tte_check_fitted
    version 16.0
    set varabbrev off
    set more off

    local fitted : char _dta[_tte_fitted]
    if "`fitted'" != "1" {
        display as error "no model has been fitted; run {bf:tte_fit} first"
        exit 198
    }
end
