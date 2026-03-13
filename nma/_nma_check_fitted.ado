*! _nma_check_fitted Version 1.0.1  2026/02/28
*! Verify model has been fitted

program define _nma_check_fitted
    version 16.0
    set varabbrev off

    local fitted : char _dta[_nma_fitted]
    if "`fitted'" != "1" {
        display as error "no model has been fitted; run {bf:nma_fit} first"
        exit 198
    }
end
