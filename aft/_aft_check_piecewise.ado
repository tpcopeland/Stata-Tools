*! _aft_check_piecewise Version 1.1.0  2026/03/15
*! Verify aft_split has been run
*! Author: Timothy P Copeland

program define _aft_check_piecewise
    version 16.0
    set varabbrev off
    set more off

    local pw : char _dta[_aft_piecewise]
    if "`pw'" != "1" {
        display as error "aft_split has not been run"
        display as error ""
        display as error "Run {bf:aft_split} first to fit piecewise AFT models."
        display as error "Example:"
        display as error "  {cmd:aft_split x1 x2, cutpoints(6 12)}"
        exit 198
    }
end
