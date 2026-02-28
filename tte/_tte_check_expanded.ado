*! _tte_check_expanded Version 1.0.2  2026/02/28
*! Verify data has been through tte_expand
*! Author: Timothy P Copeland

program define _tte_check_expanded
    version 16.0
    set varabbrev off
    set more off

    local expanded : char _dta[_tte_expanded]
    if "`expanded'" != "1" {
        display as error "data has not been expanded; run {bf:tte_expand} first"
        exit 198
    }
end
