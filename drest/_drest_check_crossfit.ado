*! _drest_check_crossfit Version 1.0.0  2026/03/15
*! Verify that drest_crossfit has been run
*! Author: Timothy P Copeland

program define _drest_check_crossfit
    version 16.0
    set varabbrev off
    set more off

    local crossfit : char _dta[_drest_crossfit]
    if "`crossfit'" != "1" {
        display as error "drest_crossfit has not been run"
        display as error ""
        display as error "Run {bf:drest_crossfit} first to fit the cross-fitted estimator."
        display as error "Example:"
        display as error "  {cmd:drest_crossfit x1 x2, outcome(y) treatment(a) folds(5)}"
        exit 198
    }
end
