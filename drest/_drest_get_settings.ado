*! _drest_get_settings Version 1.0.0  2026/03/15
*! Retrieve stored metadata from dataset characteristics
*! Author: Timothy P Copeland

* Returns via c_local: _drest_estimated, _drest_method, _drest_outcome,
*   _drest_treatment, _drest_omodel, _drest_ofamily, _drest_tmodel,
*   _drest_tfamily, _drest_estimand, _drest_ate, _drest_ate_se,
*   _drest_level, _drest_N, _drest_trimps_lo, _drest_trimps_hi,
*   _drest_n_trimmed, _drest_compared

program define _drest_get_settings
    version 16.0
    set varabbrev off
    set more off

    local estimated   : char _dta[_drest_estimated]
    local method      : char _dta[_drest_method]
    local outcome     : char _dta[_drest_outcome]
    local treatment   : char _dta[_drest_treatment]
    local omodel      : char _dta[_drest_omodel]
    local ofamily     : char _dta[_drest_ofamily]
    local tmodel      : char _dta[_drest_tmodel]
    local tfamily     : char _dta[_drest_tfamily]
    local estimand    : char _dta[_drest_estimand]
    local ate         : char _dta[_drest_ate]
    local ate_se      : char _dta[_drest_ate_se]
    local level       : char _dta[_drest_level]
    local N           : char _dta[_drest_N]
    local trimps_lo   : char _dta[_drest_trimps_lo]
    local trimps_hi   : char _dta[_drest_trimps_hi]
    local n_trimmed   : char _dta[_drest_n_trimmed]
    local compared    : char _dta[_drest_compared]
    local po1         : char _dta[_drest_po1]
    local po0         : char _dta[_drest_po0]

    c_local _drest_estimated  "`estimated'"
    c_local _drest_method     "`method'"
    c_local _drest_outcome    "`outcome'"
    c_local _drest_treatment  "`treatment'"
    c_local _drest_omodel     "`omodel'"
    c_local _drest_ofamily    "`ofamily'"
    c_local _drest_tmodel     "`tmodel'"
    c_local _drest_tfamily    "`tfamily'"
    c_local _drest_estimand   "`estimand'"
    c_local _drest_ate        "`ate'"
    c_local _drest_ate_se     "`ate_se'"
    c_local _drest_level      "`level'"
    c_local _drest_N          "`N'"
    c_local _drest_trimps_lo  "`trimps_lo'"
    c_local _drest_trimps_hi  "`trimps_hi'"
    c_local _drest_n_trimmed  "`n_trimmed'"
    c_local _drest_compared   "`compared'"
    c_local _drest_po1        "`po1'"
    c_local _drest_po0        "`po0'"
end
