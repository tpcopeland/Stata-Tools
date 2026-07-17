*! _msm_verify Version 1.2.3  2026/07/17
*! Verify that a claimed MSM stage artifact is complete, current, and this dataset's
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())

/*
Syntax:
  _msm_verify prepare
  _msm_verify weight
  _msm_verify fit [, NOHYDrate]

The single authority on whether a claimed stage artifact may be used. Never
errors on a bad artifact: it reports. Callers decide what to do.
  - _msm_check_prepared / _msm_check_weighted / _msm_check_fitted error on it
  - _msm_pipeline_state (msm, status) reports it without erroring

Existence is not validity. The guards this replaces asked only "is the flag set
and does the matrix exist", which is true in every one of the audit's
contamination scenarios. This program asks four further questions:

  complete - is the whole artifact present (b AND V, with names and dims that
             agree)?                                            [audit A01]
  mine     - does the artifact belong to THIS dataset, rather than to whatever
             was fitted most recently in the session?           [audit A01]
  current  - do the data still hash to what the stage consumed? [audit A02]
  fresh    - has an upstream stage been replaced since?         [audit A03]

For `fit`, the coefficient matrices are rehydrated from dataset
characteristics into _msm_fit_b / _msm_fit_V, so downstream code that reads
those matrix names keeps working while the artifact itself now travels with the
.dta. NOHYDrate suppresses the rehydration for callers that only want a verdict.

Returns:
  r(ok)  - 1 if the stage artifact may be used
  r(why) - reason token when r(ok)==0:
             notprepared | notweighted | notfitted - stage never claimed
             mapping   - a mapped variable is gone
             nomatrix  - claimed fitted but no coefficients are stored
             partial   - b or V present without the other
             dims      - b/V dimensions or names disagree
             stale     - an upstream stage was replaced after this one
             edited    - the data no longer hash to what the stage consumed
*/

program define _msm_verify, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        gettoken _sub 0 : 0, parse(" ,")
        if !inlist("`_sub'", "prepare", "weight", "fit") {
            display as error "invalid _msm_verify stage: `_sub'"
            exit 198
        }
        syntax [, NOHYDrate]

        local _ok = 0
        local _why ""

        **# ---------------------------------------------------------- prepare
        if "`_sub'" == "prepare" {
            local _flag : char _dta[_msm_prepared]
            if "`_flag'" != "1" {
                local _why "notprepared"
            }
            else {
                local _uuid : char _dta[_msm_prep_uuid]
                local _id : char _dta[_msm_id]
                local _period : char _dta[_msm_period]
                local _treatment : char _dta[_msm_treatment]
                local _outcome : char _dta[_msm_outcome]
                local _sigvars : char _dta[_msm_prep_sigvars]
                local _stored : char _dta[_msm_prep_sig]
                local _stored_contract : char _dta[_msm_prep_contract]

                if "`_uuid'" == "" | "`_stored'" == "" | ///
                    "`_sigvars'" == "" | "`_stored_contract'" == "" {
                    local _why "partial"
                }
                else if "`_id'" == "" | "`_period'" == "" | ///
                    "`_treatment'" == "" | "`_outcome'" == "" {
                    local _why "mapping"
                }
                else {
                    local _missing = 0
                    foreach _v of local _sigvars {
                        capture confirm variable `_v'
                        if _rc local _missing = 1
                    }
                    if `_missing' {
                        local _why "mapping"
                    }
                    else {
                        capture _msm_contract prepare
                        if _rc | `"`r(contract)'"' != `"`_stored_contract'"' {
                            local _why "edited"
                        }
                        else {
                            capture _msm_signature `_sigvars'
                            if _rc | "`r(sig)'" != "`_stored'" {
                                local _why "edited"
                            }
                            else local _ok = 1
                        }
                    }
                }
            }
        }

        **# ----------------------------------------------------------- weight
        else if "`_sub'" == "weight" {
            local _flag : char _dta[_msm_weighted]
            if "`_flag'" != "1" {
                local _why "notweighted"
            }
            else {
                local _uuid : char _dta[_msm_weight_uuid]
                local _dep : char _dta[_msm_weight_dep]
                local _prep_uuid : char _dta[_msm_prep_uuid]
                local _stored : char _dta[_msm_weight_sig]
                local _sigvars : char _dta[_msm_weight_sigvars]
                local _stored_contract : char _dta[_msm_weight_contract]

                if "`_uuid'" == "" | "`_stored'" == "" | ///
                    "`_sigvars'" == "" | "`_stored_contract'" == "" {
                    local _why "partial"
                }
                else if "`_dep'" == "" | "`_dep'" != "`_prep_uuid'" {
                    local _why "stale"
                }
                else {
                    local _missing = 0
                    foreach _v of local _sigvars {
                        capture confirm variable `_v'
                        if _rc local _missing = 1
                    }
                    foreach _v in _msm_weight _msm_tw_weight _msm_ps ///
                        _msm_treat_den_raw _msm_treat_den_p ///
                        _msm_treat_num_raw _msm_treat_num_p ///
                        _msm_decision_risk {
                        capture confirm variable `_v'
                        if _rc local _missing = 1
                        else {
                            local _owner : char `_v'[_msm_owner]
                            if "`_owner'" != "`_uuid'" local _missing = 1
                        }
                    }
                    local _censor_d : char _dta[_msm_censor_d_cov]
                    if "`_censor_d'" != "" {
                        foreach _v in _msm_cw_weight _msm_cens_den_raw ///
                            _msm_cens_den_p _msm_cens_num_raw _msm_cens_num_p {
                            capture confirm variable `_v'
                            if _rc local _missing = 1
                            else {
                                local _owner : char `_v'[_msm_owner]
                                if "`_owner'" != "`_uuid'" local _missing = 1
                            }
                        }
                    }
                    if `_missing' {
                        local _why "mapping"
                    }
                    else {
                        capture _msm_contract weight
                        if _rc | `"`r(contract)'"' != `"`_stored_contract'"' {
                            local _why "edited"
                        }
                        else {
                            capture _msm_signature `_sigvars'
                            if _rc | "`r(sig)'" != "`_stored'" {
                                local _why "edited"
                            }
                            else local _ok = 1
                        }
                    }
                }
            }
        }

        **# -------------------------------------------------------------- fit
        else {
            local _flag : char _dta[_msm_fitted]
            if "`_flag'" != "1" {
                local _why "notfitted"
            }
            else {
                local _uuid : char _dta[_msm_fit_uuid]
                local _bid : char _dta[_msm_fit_b_id]
                local _vid : char _dta[_msm_fit_V_id]
                local _dep : char _dta[_msm_fit_dep]
                local _w_uuid : char _dta[_msm_weight_uuid]
                local _stored : char _dta[_msm_fit_sig]
                local _sigvars : char _dta[_msm_fit_sigvars]
                local _stored_contract : char _dta[_msm_fit_contract]

                tempname _b _V
                local _b_ok = 0
                local _v_ok = 0
                local _b_why ""
                local _v_why ""

                capture _msm_mat_load `_b', key(_msm_fit_b)
                if _rc == 0 {
                    local _b_ok = r(ok)
                    local _b_why "`r(why)'"
                }
                else local _b_why "payload"

                capture _msm_mat_load `_V', key(_msm_fit_V)
                if _rc == 0 {
                    local _v_ok = r(ok)
                    local _v_why "`r(why)'"
                }
                else local _v_why "payload"

                if "`_uuid'" == "" | "`_bid'" == "" | "`_vid'" == "" | ///
                    "`_stored'" == "" | "`_sigvars'" == "" | ///
                    "`_stored_contract'" == "" {
                    local _why "partial"
                }
                else if "`_bid'" != "`_uuid'" | "`_vid'" != "`_uuid'" {
                    local _why "partial"
                }
                else if `_b_ok' == 0 & `_v_ok' == 0 {
                    if "`_b_why'" == "none" & "`_v_why'" == "none" ///
                        local _why "nomatrix"
                    else local _why "partial"
                }
                else if `_b_ok' == 0 | `_v_ok' == 0 {
                    local _why "partial"
                }
                else {
                    local _br = rowsof(`_b')
                    local _k = colsof(`_b')
                    local _vr = rowsof(`_V')
                    local _vc = colsof(`_V')
                    local _bn : colnames `_b'
                    local _bce : coleq `_b'
                    local _vrn : rownames `_V'
                    local _vn : colnames `_V'
                    local _vre : roweq `_V'
                    local _vce : coleq `_V'
                    local _effect : char _dta[_msm_fit_effect_term]
                    local _effect_present : list _effect in _bn

                    if `_br' != 1 | `_vr' != `_k' | `_vc' != `_k' | ///
                        "`_bn'" != "`_vn'" | "`_bn'" != "`_vrn'" | ///
                        "`_bce'" != "`_vce'" | "`_bce'" != "`_vre'" | ///
                        "`_effect'" == "" | !`_effect_present' {
                        local _why "dims"
                    }
                    else if "`_dep'" == "" | "`_dep'" != "`_w_uuid'" {
                        local _why "stale"
                    }
                    else {
                        local _missing = 0
                        foreach _v of local _sigvars {
                            capture confirm variable `_v'
                            if _rc local _missing = 1
                        }
                        capture confirm variable _msm_esample
                        if _rc local _missing = 1
                        else {
                            local _owner : char _msm_esample[_msm_owner]
                            if "`_owner'" != "`_uuid'" local _missing = 1
                        }
                        if `_missing' {
                            local _why "mapping"
                        }
                        else {
                            capture _msm_contract fit
                            if _rc | `"`r(contract)'"' != `"`_stored_contract'"' {
                                local _why "edited"
                            }
                            else {
                                capture _msm_signature `_sigvars'
                                if _rc | "`r(sig)'" != "`_stored'" {
                                    local _why "edited"
                                }
                                else local _ok = 1
                            }
                        }
                    }
                }

                * Publish only coefficients proven to belong to this dataset.
                if "`nohydrate'" == "" {
                    capture matrix drop _msm_fit_b
                    capture matrix drop _msm_fit_V
                    if `_ok' == 1 {
                        matrix _msm_fit_b = `_b'
                        matrix _msm_fit_V = `_V'
                    }
                }
            }
        }

        return scalar ok = `_ok'
        return local why "`_why'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
