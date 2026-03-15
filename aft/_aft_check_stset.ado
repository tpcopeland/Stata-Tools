*! _aft_check_stset Version 1.0.0  2026/03/14
*! Verify data has been stset; error with guidance if not
*! Author: Timothy P Copeland

program define _aft_check_stset
    version 16.0
    set varabbrev off
    set more off

    capture st_is 2 analysis
    if _rc {
        display as error "data not stset"
        display as error ""
        display as error "You must {bf:stset} your data before using aft commands."
        display as error "Example:"
        display as error "  {cmd:stset time, failure(died)}"
        exit 119
    }
end
