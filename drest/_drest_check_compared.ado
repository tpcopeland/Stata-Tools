*! _drest_check_compared Version 1.0.0  2026/03/15
*! Verify that drest_compare has been run
*! Author: Timothy P Copeland

program define _drest_check_compared
    version 16.0
    set varabbrev off
    set more off

    local compared : char _dta[_drest_compared]
    if "`compared'" != "1" {
        display as error "drest_compare has not been run"
        display as error ""
        display as error "Run {bf:drest_compare} first to compare estimators."
        display as error "Example:"
        display as error "  {cmd:drest_compare x1 x2, outcome(y) treatment(a)}"
        exit 198
    }
end
