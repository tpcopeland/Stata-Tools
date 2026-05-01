*! _iivw_get_settings Version 1.0.3  2026/04/30
*! Retrieve stored metadata from dataset characteristics
*! Author: Timothy P Copeland

* Returns via c_local: id, time, weighttype, weight_var, prefix

program define _iivw_get_settings
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

    if "`prefix'" == "" local prefix "_iivw_"

    c_local _iivw_id         "`id'"
    c_local _iivw_time       "`time'"
    c_local _iivw_weighttype "`weighttype'"
    c_local _iivw_weight_var "`weight_var'"
    c_local _iivw_prefix     "`prefix'"
    c_local _iivw_treat      "`treat'"

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
