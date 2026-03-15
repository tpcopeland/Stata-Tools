*! _aft_check_selected Version 1.0.0  2026/03/14
*! Verify aft_select has been run
*! Author: Timothy P Copeland

program define _aft_check_selected
    version 16.0
    set varabbrev off
    set more off

    local selected : char _dta[_aft_selected]
    if "`selected'" != "1" {
        display as error "aft_select has not been run"
        display as error ""
        display as error "Run {bf:aft_select} first to compare distributions."
        display as error "Example:"
        display as error "  {cmd:aft_select x1 x2}"
        exit 198
    }
end
