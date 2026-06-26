*! _iivw_get_settings Version 1.7.4  2026/06/26
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
    local iw_var     : char _dta[_iivw_iw_var]
    local tw_var     : char _dta[_iivw_tw_var]
    local ps_var     : char _dta[_iivw_ps_var]
    local treat      : char _dta[_iivw_treat]
    local treat_covars : char _dta[_iivw_treat_covars]
    local ps_estimand : char _dta[_iivw_ps_estimand]
    local contract_version : char _dta[_iivw_contract_version]
    local visit_covars : char _dta[_iivw_visit_covars]

    if "`prefix'" == "" local prefix "_iivw_"

    return local id "`id'"
    return local time "`time'"
    return local weighttype "`weighttype'"
    return local weight_var "`weight_var'"
    return local prefix "`prefix'"
    return local iw_var "`iw_var'"
    return local tw_var "`tw_var'"
    return local ps_var "`ps_var'"
    return local treat "`treat'"
    return local treat_covars "`treat_covars'"
    return local ps_estimand "`ps_estimand'"
    return local contract_version "`contract_version'"
    return local visit_covars "`visit_covars'"

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
