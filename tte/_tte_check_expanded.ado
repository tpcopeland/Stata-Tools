*! _tte_check_expanded Version 1.0.3  2026/03/01
*! Verify data has been through tte_expand
*! Author: Timothy P Copeland
*! Author: Tania F Reza

program define _tte_check_expanded
    version 16.0
    set varabbrev off
    set more off

    local expanded : char _dta[_tte_expanded]
    if "`expanded'" != "1" {
        display as error "data has not been expanded"
        display as error ""
        display as error "Run {bf:tte_expand} to create sequential emulated trials."
        display as error "This requires {bf:tte_prepare} to have been run first."
        display as error "Example:"
        display as error "  {cmd:tte_expand, maxfollowup(8)}"
        exit 198
    }
end
