*! _drest_check_estimated Version 1.0.0  2026/03/15
*! Verify that drest_estimate has been run
*! Author: Timothy P Copeland

program define _drest_check_estimated
    version 16.0
    set varabbrev off
    set more off

    local estimated : char _dta[_drest_estimated]
    if "`estimated'" != "1" {
        display as error "drest_estimate has not been run"
        display as error ""
        display as error "Run {bf:drest_estimate} first to fit the doubly robust model."
        display as error "Example:"
        display as error "  {cmd:drest_estimate x1 x2, outcome(y) treatment(a)}"
        exit 198
    }
end
