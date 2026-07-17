*! _msm_invalidate Version 1.2.3  2026/07/17
*! Invalidate MSM pipeline artifacts downstream of a replaced stage
*! Author: Timothy P Copeland
*! Program class: nclass

/*
Syntax:
  _msm_invalidate , FROM(string)

Clears every artifact that depends on the named stage. FROM() names the stage
that was just (re)built; everything STRICTLY DOWNSTREAM of it is invalidated.

Dependency graph (audit finding A03):

    prepare
    +- weight
       +- diagnose/balance
       +- fit
          +- predict
          +- sensitivity

  from(prepare) -> weight, diagnose, balance, fit, predict, sensitivity
  from(weight)  -> diagnose, balance, fit, predict, sensitivity
  from(fit)     -> predict, sensitivity
  from(all)     -> every stage including prepare

This replaces _msm_clear_downstream_state, which had two defects the audit
flagged: it was all-or-nothing (a reweight did not clear the fit at all, so old
coefficients stayed authorized against new weights), and it deleted variables
unconditionally, including identically-named user variables it never created.

Variable deletion here goes through _msm_own, so only package-created variables
are dropped. The wildcard `_msm_per_ns*` deletion is gone: spline columns are
resolved from the ownership inventory, never by name pattern.

Call this only as part of a successful commit. Invalidating before the work
succeeds is what let a failed re-run masquerade as the previous success.
*/

program define _msm_invalidate
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        syntax , FROM(string)

        if !inlist("`from'", "prepare", "weight", "fit", "predict", "all") {
            display as error "invalid _msm_invalidate stage: `from'"
            exit 198
        }

        local _do_weight = 0
        local _do_diagbal = 0
        local _do_fit = 0
        local _do_pred = 0
        local _do_sens = 0
        local _do_prepare = 0

        if "`from'" == "all" {
            local _do_prepare = 1
            local _do_weight = 1
            local _do_diagbal = 1
            local _do_fit = 1
            local _do_pred = 1
            local _do_sens = 1
        }
        else if "`from'" == "prepare" {
            local _do_weight = 1
            local _do_diagbal = 1
            local _do_fit = 1
            local _do_pred = 1
            local _do_sens = 1
        }
        else if "`from'" == "weight" {
            local _do_diagbal = 1
            local _do_fit = 1
            local _do_pred = 1
            local _do_sens = 1
        }
        else if "`from'" == "fit" {
            local _do_pred = 1
            local _do_sens = 1
        }

        **# Sensitivity layer
        if `_do_sens' {
            foreach _c in _msm_sens_saved _msm_sens_effect _msm_sens_effect_lo ///
                _msm_sens_effect_hi _msm_sens_effect_label _msm_sens_model ///
                _msm_sens_evalue_point _msm_sens_evalue_ci _msm_sens_level ///
                _msm_sens_uuid _msm_sens_dep {
                char _dta[`_c']
            }
        }

        **# Prediction layer
        if `_do_pred' {
            foreach _c in _msm_pred_saved _msm_pred_type _msm_pred_strategy ///
                _msm_pred_level _msm_pred_uuid _msm_pred_dep {
                char _dta[`_c']
            }
            capture matrix drop _msm_pred_matrix
            _msm_mat_clear, key(_msm_pred_mat)
        }

        **# Diagnostics / balance layer
        if `_do_diagbal' {
            foreach _c in _msm_bal_saved _msm_bal_threshold _msm_bal_uuid ///
                _msm_bal_dep _msm_diag_saved _msm_diag_mean _msm_diag_sd ///
                _msm_diag_min _msm_diag_max _msm_diag_p1 _msm_diag_p50 ///
                _msm_diag_p99 _msm_diag_ess _msm_diag_ess_pct _msm_diag_uuid ///
                _msm_diag_dep {
                char _dta[`_c']
            }
            capture matrix drop _msm_bal_matrix
            capture matrix drop _msm_tbal_matrix
            capture matrix drop _msm_cbal_matrix
            capture matrix drop _msm_support_matrix
            _msm_mat_clear, key(_msm_bal_mat)
        }

        **# Fit layer
        if `_do_fit' {
            * Resolve and remove owned variables while the old fit UUID is still
            * live. Clearing the UUID first would make every legitimate token
            * unverifiable and turn cleanup into a no-op.
            local _spline_owned ""
            _msm_own inventory
            local _inv "`r(vars)'"
            foreach _v of local _inv {
                if strpos("`_v'", "_msm_per_ns") == 1 {
                    local _spline_owned "`_spline_owned' `_v'"
                }
            }
            _msm_own dropowned _msm_esample _msm_period_sq _msm_period_cu ///
                _msm_hist_lag1 _msm_hist_cum _msm_hist_dur _msm_hist_int ///
                `_spline_owned'

            foreach _c in _msm_fitted _msm_model _msm_period_spec ///
                _msm_outcome_cov _msm_exposure _msm_tvcov ///
                _msm_history_spec _msm_history_vars _msm_history_assumption ///
                _msm_predict_disabled _msm_per_ns_knots _msm_per_ns_df ///
                _msm_cluster _msm_vce _msm_strata _msm_time_vars ///
                _msm_fit_level _msm_fit_uuid _msm_fit_dep _msm_fit_sig ///
                _msm_fit_sigvars _msm_fit_effect_term _msm_fit_contract {
                char _dta[`_c']
            }

            capture matrix drop _msm_fit_b
            capture matrix drop _msm_fit_V
            _msm_mat_clear, key(_msm_fit_b)
            _msm_mat_clear, key(_msm_fit_V)

        }

        **# Weight layer
        if `_do_weight' {
            * As above, delete variables before clearing their authorizing UUID.
            _msm_own dropowned _msm_weight _msm_tw_weight _msm_cw_weight _msm_ps ///
                _msm_treat_den_raw _msm_treat_den_p ///
                _msm_treat_num_raw _msm_treat_num_p ///
                _msm_cens_den_raw _msm_cens_den_p ///
                _msm_cens_num_raw _msm_cens_num_p _msm_decision_risk

            foreach _c in _msm_weighted _msm_weight_var _msm_ps_var ///
                _msm_tw_var _msm_ps_covars _msm_estimand ///
                _msm_contract_version _msm_weight_uuid _msm_weight_dep ///
                _msm_weight_sig _msm_weight_sigvars _msm_wt_spec ///
                _msm_treat_d_cov _msm_treat_n_cov _msm_censor_d_cov ///
                _msm_censor_n_cov _msm_numer_covars _msm_historymsm ///
                _msm_weight_truncate _msm_weight_fitfailure ///
                _msm_probability_policy _msm_probability_clip ///
                _msm_probability_models ///
                _msm_weight_contract {
                char _dta[`_c']
            }
            capture matrix drop _msm_probability_repairs
        }

        **# Preparation layer
        if `_do_prepare' {
            foreach _c in _msm_prepared _msm_id _msm_period _msm_treatment ///
                _msm_outcome _msm_censor _msm_covariates _msm_bl_covariates ///
                _msm_prefix _msm_prep_uuid _msm_prep_sig _msm_prep_sigvars ///
                _msm_prep_contract {
                char _dta[`_c']
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
