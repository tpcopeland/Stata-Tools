*! _aft_get_settings Version 1.1.0  2026/03/15
*! Retrieve stored metadata from dataset characteristics
*! Author: Timothy P Copeland

* Returns via c_local: _aft_selected, _aft_best_dist, _aft_varlist,
*   _aft_n_obs, _aft_n_fail, _aft_strata, _aft_frailty, _aft_shared,
*   _aft_vce, _aft_ancov, _aft_fitted, _aft_fit_dist

program define _aft_get_settings
    version 16.0
    set varabbrev off
    set more off

    local selected  : char _dta[_aft_selected]
    local best_dist : char _dta[_aft_best_dist]
    local varlist   : char _dta[_aft_varlist]
    local n_obs     : char _dta[_aft_n_obs]
    local n_fail    : char _dta[_aft_n_fail]
    local strata    : char _dta[_aft_strata]
    local frailty   : char _dta[_aft_frailty]
    local shared    : char _dta[_aft_shared]
    local vce       : char _dta[_aft_vce]
    local ancov     : char _dta[_aft_ancov]
    local fitted    : char _dta[_aft_fitted]
    local fit_dist  : char _dta[_aft_fit_dist]

    * Piecewise AFT settings
    local piecewise   : char _dta[_aft_piecewise]
    local pw_n_pieces : char _dta[_aft_pw_n_pieces]
    local pw_cuts     : char _dta[_aft_pw_cutpoints]
    local pw_dist     : char _dta[_aft_pw_dist]
    local pw_varlist  : char _dta[_aft_pw_varlist]

    * RPSFTM settings
    local rpsftm      : char _dta[_aft_rpsftm]
    local rpsftm_psi  : char _dta[_aft_rpsftm_psi]
    local rpsftm_af   : char _dta[_aft_rpsftm_af]
    local rpsftm_rand : char _dta[_aft_rpsftm_rand]
    local rpsftm_treat: char _dta[_aft_rpsftm_treat]

    c_local _aft_selected  "`selected'"
    c_local _aft_best_dist "`best_dist'"
    c_local _aft_varlist   "`varlist'"
    c_local _aft_n_obs     "`n_obs'"
    c_local _aft_n_fail    "`n_fail'"
    c_local _aft_strata    "`strata'"
    c_local _aft_frailty   "`frailty'"
    c_local _aft_shared    "`shared'"
    c_local _aft_vce       "`vce'"
    c_local _aft_ancov     "`ancov'"
    c_local _aft_fitted    "`fitted'"
    c_local _aft_fit_dist  "`fit_dist'"
    c_local _aft_piecewise    "`piecewise'"
    c_local _aft_pw_n_pieces  "`pw_n_pieces'"
    c_local _aft_pw_cutpoints "`pw_cuts'"
    c_local _aft_pw_dist      "`pw_dist'"
    c_local _aft_pw_varlist   "`pw_varlist'"
    c_local _aft_rpsftm       "`rpsftm'"
    c_local _aft_rpsftm_psi   "`rpsftm_psi'"
    c_local _aft_rpsftm_af    "`rpsftm_af'"
    c_local _aft_rpsftm_rand  "`rpsftm_rand'"
    c_local _aft_rpsftm_treat "`rpsftm_treat'"
end
