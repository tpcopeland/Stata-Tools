*! _iivw_get_settings Version 1.9.7  2026/07/13
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
    local baseevent  : char _dta[_iivw_baseevent]
    local stabcov    : char _dta[_iivw_stabcov]
    local truncate   : char _dta[_iivw_truncate]
    local efron      : char _dta[_iivw_efron]
    local entry      : char _dta[_iivw_entry]
    local censor_mode : char _dta[_iivw_censor_mode]
    local censor_var  : char _dta[_iivw_censor_var]
    local maxfu       : char _dta[_iivw_maxfu]
    local lagvars     : char _dta[_iivw_lagvars]
    local nonconverged : char _dta[_iivw_nonconverged]
    local fit_nonconverged : char _dta[_iivw_fit_nonconverged]

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
    return local baseevent "`baseevent'"
    return local stabcov "`stabcov'"
    return local truncate "`truncate'"
    return local efron "`efron'"
    return local entry "`entry'"

    * The risk-set specification. Any consumer that refits the visit-intensity
    * model must replay this, or it describes a different estimator than the one
    * that produced the weights it is reporting on.
    return local censor_mode "`censor_mode'"
    return local censor_var "`censor_var'"
    return local maxfu "`maxfu'"

    * Source variables behind the generated lag columns. Needed to give a
    * rebuilt censoring row the covariate value it actually had at the last
    * visit; see the note where iivw_weight writes this characteristic.
    return local lagvars "`lagvars'"

    * A nuisance model (visit-intensity, stabilization, or treatment) that the
    * user accepted nonconverged via allownonconverged. The weights it produced
    * do not solve their estimating equation, so a diagnostic must not issue a
    * verdict on them. Kept separate from the outcome-model stamp: the two taint
    * different things and a converged outcome fit must not clear a bad weight.
    return local nonconverged "`nonconverged'"
    return local fit_nonconverged "`fit_nonconverged'"

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
