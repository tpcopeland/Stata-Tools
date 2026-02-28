*! _tte_check_prepared Version 1.0.2  2026/02/28
*! Verify data has been through tte_prepare
*! Author: Timothy P Copeland

program define _tte_check_prepared
    version 16.0
    set varabbrev off
    set more off

    local prepared : char _dta[_tte_prepared]
    if "`prepared'" != "1" {
        display as error "data has not been prepared; run {bf:tte_prepare} first"
        exit 198
    }
end
