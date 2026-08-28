*! _msm_check_artifact Version 1.4.7  2026/08/28
*! Verify and optionally hydrate downstream MSM artifacts
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Syntax:
  _msm_check_artifact prediction|balance|diagnostics|sensitivity
      [, NOHYDrate REQUIRE]

Downstream matrices and scalar-characteristic bundles must belong to the
dataset in memory and to its current upstream fit/weight artifact. This helper
is the single verifier used by msm_table and msm, status. With require it emits
an actionable error; otherwise it reports r(ok) and r(why).
*/

program define _msm_check_artifact, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        gettoken stage 0 : 0, parse(" ,")
        if !inlist("`stage'", "prediction", "balance", ///
            "diagnostics", "sensitivity") {
            display as error "invalid downstream MSM artifact: `stage'"
            exit 198
        }
        syntax [, NOHYDrate REQUIRE]

        local ok = 0
        local why ""

        if "`stage'" == "prediction" {
            local flag : char _dta[_msm_pred_saved]
            if "`flag'" != "1" {
                local why "notprediction"
            }
            else {
                _msm_verify fit, nohydrate
                local upstream_ok = r(ok)
                local upstream_why "`r(why)'"
                if !`upstream_ok' {
                    local why = cond(inlist("`upstream_why'", ///
                        "notfitted", "notweighted", "notprepared"), ///
                        "stale", "`upstream_why'")
                }
                else {
                    local uuid : char _dta[_msm_pred_uuid]
                    local dep : char _dta[_msm_pred_dep]
                    local fit_uuid : char _dta[_msm_fit_uuid]
                    local matrix_id : char _dta[_msm_pred_mat_id]
                    local type : char _dta[_msm_pred_type]
                    local strategy : char _dta[_msm_pred_strategy]
                    local level : char _dta[_msm_pred_level]

                    tempname artifact
                    capture _msm_mat_load `artifact', key(_msm_pred_mat)
                    local load_rc = _rc
                    local matrix_ok = 0
                    local matrix_why "payload"
                    if `load_rc' == 0 {
                        local matrix_ok = r(ok)
                        local matrix_why "`r(why)'"
                    }

                    if "`uuid'" == "" | "`dep'" == "" | ///
                        "`type'" == "" | "`strategy'" == "" | ///
                        "`level'" == "" {
                        local why "partial"
                    }
                    else if "`dep'" != "`fit_uuid'" {
                        local why "stale"
                    }
                    else if "`matrix_id'" == "" | "`matrix_id'" != "`uuid'" {
                        local why "partial"
                    }
                    else if !`matrix_ok' {
                        local why = cond("`matrix_why'" == "none", ///
                            "nomatrix", "`matrix_why'")
                    }
                    else {
                        local cols : colnames `artifact'
                        local expected7 "period est_never ci_lo_never ci_hi_never est_always ci_lo_always ci_hi_always"
                        local expected10 "`expected7' diff diff_lo diff_hi"
                        if rowsof(`artifact') < 1 | ///
                            !inlist(colsof(`artifact'), 7, 10) | ///
                            !("`cols'" == "`expected7'" | "`cols'" == "`expected10'") {
                            local why "dims"
                        }
                        else {
                            local ok = 1
                            if "`nohydrate'" == "" {
                                capture matrix drop _msm_pred_matrix
                                matrix _msm_pred_matrix = `artifact'
                            }
                        }
                    }
                }
            }
        }
        else if "`stage'" == "balance" {
            local flag : char _dta[_msm_bal_saved]
            if "`flag'" != "1" {
                local why "notbalance"
            }
            else {
                _msm_verify weight, nohydrate
                local upstream_ok = r(ok)
                local upstream_why "`r(why)'"
                if !`upstream_ok' {
                    local why = cond(inlist("`upstream_why'", ///
                        "notweighted", "notprepared"), "stale", "`upstream_why'")
                }
                else {
                    local uuid : char _dta[_msm_bal_uuid]
                    local dep : char _dta[_msm_bal_dep]
                    local weight_uuid : char _dta[_msm_weight_uuid]
                    local matrix_id : char _dta[_msm_bal_mat_id]
                    local threshold : char _dta[_msm_bal_threshold]

                    tempname artifact
                    capture _msm_mat_load `artifact', key(_msm_bal_mat)
                    local load_rc = _rc
                    local matrix_ok = 0
                    local matrix_why "payload"
                    if `load_rc' == 0 {
                        local matrix_ok = r(ok)
                        local matrix_why "`r(why)'"
                    }

                    if "`uuid'" == "" | "`dep'" == "" | "`threshold'" == "" {
                        local why "partial"
                    }
                    else if "`dep'" != "`weight_uuid'" {
                        local why "stale"
                    }
                    else if "`matrix_id'" == "" | "`matrix_id'" != "`uuid'" {
                        local why "partial"
                    }
                    else if !`matrix_ok' {
                        local why = cond("`matrix_why'" == "none", ///
                            "nomatrix", "`matrix_why'")
                    }
                    else {
                        local cols : colnames `artifact'
                        if rowsof(`artifact') < 1 | colsof(`artifact') != 3 | ///
                            "`cols'" != "raw_smd weighted_smd pct_change" {
                            local why "dims"
                        }
                        else {
                            local ok = 1
                            if "`nohydrate'" == "" {
                                capture matrix drop _msm_bal_matrix
                                matrix _msm_bal_matrix = `artifact'
                            }
                        }
                    }
                }
            }
        }
        else if "`stage'" == "diagnostics" {
            local flag : char _dta[_msm_diag_saved]
            if "`flag'" != "1" {
                local why "notdiagnostics"
            }
            else {
                _msm_verify weight, nohydrate
                local upstream_ok = r(ok)
                local upstream_why "`r(why)'"
                if !`upstream_ok' {
                    local why = cond(inlist("`upstream_why'", ///
                        "notweighted", "notprepared"), "stale", "`upstream_why'")
                }
                else {
                    local uuid : char _dta[_msm_diag_uuid]
                    local dep : char _dta[_msm_diag_dep]
                    local weight_uuid : char _dta[_msm_weight_uuid]
                    local partial = ("`uuid'" == "" | "`dep'" == "")
                    foreach key in mean sd min max p1 p50 p99 ess ess_pct {
                        local value : char _dta[_msm_diag_`key']
                        if "`value'" == "" local partial = 1
                    }
                    if `partial' {
                        local why "partial"
                    }
                    else if "`dep'" != "`weight_uuid'" {
                        local why "stale"
                    }
                    else local ok = 1
                }
            }
        }
        else {
            local flag : char _dta[_msm_sens_saved]
            if "`flag'" != "1" {
                local why "notsensitivity"
            }
            else {
                _msm_verify fit, nohydrate
                local upstream_ok = r(ok)
                local upstream_why "`r(why)'"
                if !`upstream_ok' {
                    local why = cond(inlist("`upstream_why'", ///
                        "notfitted", "notweighted", "notprepared"), ///
                        "stale", "`upstream_why'")
                }
                else {
                    local uuid : char _dta[_msm_sens_uuid]
                    local dep : char _dta[_msm_sens_dep]
                    local fit_uuid : char _dta[_msm_fit_uuid]
                    local effect : char _dta[_msm_sens_effect]
                    local effect_lo : char _dta[_msm_sens_effect_lo]
                    local effect_hi : char _dta[_msm_sens_effect_hi]
                    local effect_label : char _dta[_msm_sens_effect_label]
                    local model : char _dta[_msm_sens_model]
                    local level : char _dta[_msm_sens_level]
                    local evalue_point : char _dta[_msm_sens_evalue_point]
                    local evalue_ci : char _dta[_msm_sens_evalue_ci]
                    local bias_factor : char _dta[_msm_sens_bias_factor]
                    local bound : char _dta[_msm_sens_bound]
                    local rr_ud : char _dta[_msm_sens_rr_ud]
                    local rr_uy : char _dta[_msm_sens_rr_uy]
                    local has_evalue = ("`evalue_point'" != "" & "`evalue_ci'" != "")
                    local has_bound = ("`bias_factor'" != "" & "`bound'" != "" & ///
                        "`rr_ud'" != "" & "`rr_uy'" != "")

                    if "`uuid'" == "" | "`dep'" == "" | ///
                        "`effect'" == "" | "`effect_lo'" == "" | ///
                        "`effect_hi'" == "" | "`effect_label'" == "" | ///
                        "`model'" == "" | "`level'" == "" | ///
                        (!`has_evalue' & !`has_bound') {
                        local why "partial"
                    }
                    else if "`dep'" != "`fit_uuid'" {
                        local why "stale"
                    }
                    else local ok = 1
                }
            }
        }

        if "`require'" != "" & !`ok' {
            display as error "saved MSM `stage' artifact is not usable (`why')"
            if "`stage'" == "prediction" {
                display as error "Re-run {bf:msm_predict} on the current fitted model."
            }
            else if inlist("`stage'", "balance", "diagnostics") {
                display as error "Re-run {bf:msm_diagnose} on the current weights."
            }
            else {
                display as error "Re-run {bf:msm_sensitivity} on the current fitted model."
            }
            if strpos("`why'", "not") == 1 exit 198
            if "`why'" == "mapping" exit 111
            exit 459
        }

        return scalar ok = `ok'
        return local why "`why'"
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
