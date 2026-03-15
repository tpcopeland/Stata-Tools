*! _aft_check_rpsftm Version 1.1.0  2026/03/15
*! Verify aft_rpsftm has been run
*! Author: Timothy P Copeland

program define _aft_check_rpsftm
    version 16.0
    set varabbrev off
    set more off

    local rpsftm : char _dta[_aft_rpsftm]
    if "`rpsftm'" != "1" {
        display as error "aft_rpsftm has not been run"
        display as error ""
        display as error "Run {bf:aft_rpsftm} first to estimate the acceleration factor."
        display as error "Example:"
        display as error "  {cmd:aft_rpsftm, randomization(arm) treatment(treated)}"
        exit 198
    }
end
