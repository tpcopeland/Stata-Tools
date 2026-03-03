*! _msm_get_settings Version 1.0.0  2026/03/03
*! Retrieve stored metadata from characteristics
*! Author: Timothy P Copeland

* Returns via c_local: id, period, treatment, outcome, censor,
*   covariates, baseline_covariates, prefix

program define _msm_get_settings
    version 16.0
    set varabbrev off
    set more off

    local id         : char _dta[_msm_id]
    local period     : char _dta[_msm_period]
    local treatment  : char _dta[_msm_treatment]
    local outcome    : char _dta[_msm_outcome]
    local censor     : char _dta[_msm_censor]
    local covariates : char _dta[_msm_covariates]
    local bl_covs    : char _dta[_msm_bl_covariates]
    local prefix     : char _dta[_msm_prefix]

    if "`prefix'" == "" local prefix "_msm_"

    c_local _msm_id         "`id'"
    c_local _msm_period     "`period'"
    c_local _msm_treatment  "`treatment'"
    c_local _msm_outcome    "`outcome'"
    c_local _msm_censor     "`censor'"
    c_local _msm_covariates "`covariates'"
    c_local _msm_bl_covs    "`bl_covs'"
    c_local _msm_prefix     "`prefix'"
end
