*! _iivw_get_settings Version 1.2.0  2026/05/24
*! Retrieve stored metadata from dataset characteristics
*! Author: Timothy P Copeland, Karolinska Institutet

program define _iivw_get_settings, rclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    local id         : char _dta[_iivw_id]
    local time       : char _dta[_iivw_time]
    local weighttype : char _dta[_iivw_weighttype]
    local weight_var : char _dta[_iivw_weight_var]
    local prefix     : char _dta[_iivw_prefix]
    local treat      : char _dta[_iivw_treat]
    local visit_covars : char _dta[_iivw_visit_covars]

    if "`prefix'" == "" local prefix "_iivw_"

    return local id "`id'"
    return local time "`time'"
    return local weighttype "`weighttype'"
    return local weight_var "`weight_var'"
    return local prefix "`prefix'"
    return local treat "`treat'"
    return local visit_covars "`visit_covars'"

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
