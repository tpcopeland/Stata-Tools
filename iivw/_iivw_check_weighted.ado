*! _iivw_check_weighted Version 1.7.3  2026/06/26
*! Verify weight variable exists before fitting
*! Author: Timothy P Copeland, Karolinska Institutet

program define _iivw_check_weighted, rclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    local __iivw_smcl_lb = char(123)
    local __iivw_smcl_rb = char(125)
    capture noisily {

    local weighted : char _dta[_iivw_weighted]
    if "`weighted'" != "1" {
        display as error "data has not been weighted"
        display as error ""
        display as error "Run `__iivw_smcl_lb'bf:iivw_weight`__iivw_smcl_rb' to compute inverse intensity weights."
        display as error "Example:"
        display as error "  `__iivw_smcl_lb'cmd:iivw_weight, id(patid) time(visit_months)`__iivw_smcl_rb'"
        display as error "  `__iivw_smcl_lb'cmd:  visit_cov(edss relapse_recent) nolog`__iivw_smcl_rb'"
        exit 198
    }

    local wvar : char _dta[_iivw_weight_var]
    if "`wvar'" == "" local wvar "_iivw_weight"

    capture confirm variable `wvar'
    if _rc != 0 {
        display as error "weight variable `wvar' not found"
        display as error ""
        display as error "Run `__iivw_smcl_lb'bf:iivw_weight`__iivw_smcl_rb' to compute inverse intensity weights."
        exit 111
    }

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
