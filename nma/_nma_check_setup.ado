*! _nma_check_setup Version 1.0.1  2026/02/28
*! Verify data has been through nma_setup or nma_import

program define _nma_check_setup
    version 16.0
    set varabbrev off

    local setup : char _dta[_nma_setup]
    if "`setup'" != "1" {
        display as error "data has not been set up; run {bf:nma_setup} or {bf:nma_import} first"
        exit 198
    }
end
