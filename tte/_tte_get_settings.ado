*! _tte_get_settings Version 1.0.2  2026/02/28
*! Retrieve stored metadata from characteristics
*! Author: Timothy P Copeland
*! Author: Tania F Reza

* Returns via c_local: id, period, treatment, outcome, eligible, censor,
*   covariates, baseline_covariates, estimand, prefix

program define _tte_get_settings
    version 16.0
    set varabbrev off
    set more off

    local id         : char _dta[_tte_id]
    local period     : char _dta[_tte_period]
    local treatment  : char _dta[_tte_treatment]
    local outcome    : char _dta[_tte_outcome]
    local eligible   : char _dta[_tte_eligible]
    local censor     : char _dta[_tte_censor]
    local covariates : char _dta[_tte_covariates]
    local bl_covs    : char _dta[_tte_bl_covariates]
    local estimand   : char _dta[_tte_estimand]
    local prefix     : char _dta[_tte_prefix]

    if "`prefix'" == "" local prefix "_tte_"

    c_local _tte_id         "`id'"
    c_local _tte_period     "`period'"
    c_local _tte_treatment  "`treatment'"
    c_local _tte_outcome    "`outcome'"
    c_local _tte_eligible   "`eligible'"
    c_local _tte_censor     "`censor'"
    c_local _tte_covariates "`covariates'"
    c_local _tte_bl_covs    "`bl_covs'"
    c_local _tte_estimand   "`estimand'"
    c_local _tte_prefix     "`prefix'"
end
