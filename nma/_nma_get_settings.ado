*! _nma_get_settings Version 1.0.1  2026/02/28
*! Retrieve stored metadata from _dta[] characteristics

program define _nma_get_settings
    version 16.0
    set varabbrev off
    set more off

    c_local _nma_format       `: char _dta[_nma_format]'
    c_local _nma_measure      `: char _dta[_nma_measure]'
    c_local _nma_studyvar     `: char _dta[_nma_studyvar]'
    c_local _nma_trtvar       `: char _dta[_nma_trtvar]'
    c_local _nma_ref          `: char _dta[_nma_ref]'
    c_local _nma_treatments   `: char _dta[_nma_treatments]'
    c_local _nma_n_treatments `: char _dta[_nma_n_treatments]'
    c_local _nma_n_studies    `: char _dta[_nma_n_studies]'
    c_local _nma_n_comparisons `: char _dta[_nma_n_comparisons]'
    c_local _nma_outcome_type `: char _dta[_nma_outcome_type]'
    c_local _nma_n_direct     `: char _dta[_nma_n_direct]'
    c_local _nma_n_indirect   `: char _dta[_nma_n_indirect]'
    c_local _nma_n_mixed      `: char _dta[_nma_n_mixed]'
end
