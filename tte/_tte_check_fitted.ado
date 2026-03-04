*! _tte_check_fitted Version 1.0.3  2026/03/01
*! Verify model has been fitted
*! Author: Timothy P Copeland
*! Author: Tania F Reza

program define _tte_check_fitted
    version 16.0
    set varabbrev off
    set more off

    local fitted : char _dta[_tte_fitted]
    if "`fitted'" != "1" {
        display as error "no model has been fitted"
        display as error ""
        display as error "Run {bf:tte_fit} to fit the outcome model."
        display as error "Requires {bf:tte_expand} (and optionally {bf:tte_weight}) first."
        display as error "Example:"
        display as error "  {cmd:tte_fit, outcome_cov(age sex comorbidity) nolog}"
        exit 198
    }
end
