*! _iivw_check_weighted Version 1.0.0  2026/03/06
*! Verify weight variable exists before fitting
*! Author: Timothy P Copeland

program define _iivw_check_weighted
    version 16.0
    set varabbrev off
    set more off

    local weighted : char _dta[_iivw_weighted]
    if "`weighted'" != "1" {
        display as error "data has not been weighted"
        display as error ""
        display as error "Run {bf:iivw_weight} to compute inverse intensity weights."
        display as error "Example:"
        display as error "  {cmd:iivw_weight, id(patid) time(visit_months)}"
        display as error "  {cmd:  visit_cov(edss relapse_recent) nolog}"
        exit 198
    }

    local wvar : char _dta[_iivw_weight_var]
    if "`wvar'" == "" local wvar "_iivw_weight"

    capture confirm variable `wvar'
    if _rc != 0 {
        display as error "weight variable `wvar' not found"
        display as error ""
        display as error "Run {bf:iivw_weight} to compute inverse intensity weights."
        exit 111
    }
end
