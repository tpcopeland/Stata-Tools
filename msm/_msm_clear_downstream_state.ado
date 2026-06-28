*! _msm_clear_downstream_state Version 1.2.1  2026/06/25
*! Clear downstream MSM pipeline artifacts after re-prepare
*! Author: Timothy P Copeland

program define _msm_clear_downstream_state
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        foreach _msm_var in ///
            _msm_weight ///
            _msm_tw_weight ///
            _msm_cw_weight ///
            _msm_ps ///
            _msm_esample ///
            _msm_period_sq ///
            _msm_period_cu ///
            _msm_per_ns* {
            capture drop `_msm_var'
        }

        foreach _msm_char in ///
            _msm_weighted ///
            _msm_fitted ///
            _msm_model ///
            _msm_period_spec ///
            _msm_outcome_cov ///
            _msm_exposure ///
            _msm_tvcov ///
            _msm_predict_disabled ///
            _msm_per_ns_knots ///
            _msm_per_ns_df ///
            _msm_cluster ///
            _msm_time_vars ///
            _msm_fit_level ///
            _msm_weight_var ///
            _msm_ps_var ///
            _msm_tw_var ///
            _msm_ps_covars ///
            _msm_estimand ///
            _msm_contract_version ///
            _msm_pred_saved ///
            _msm_pred_type ///
            _msm_pred_strategy ///
            _msm_pred_level ///
            _msm_bal_saved ///
            _msm_bal_threshold ///
            _msm_diag_saved ///
            _msm_diag_mean ///
            _msm_diag_sd ///
            _msm_diag_min ///
            _msm_diag_max ///
            _msm_diag_p1 ///
            _msm_diag_p50 ///
            _msm_diag_p99 ///
            _msm_diag_ess ///
            _msm_diag_ess_pct ///
            _msm_sens_saved ///
            _msm_sens_effect ///
            _msm_sens_effect_lo ///
            _msm_sens_effect_hi ///
            _msm_sens_effect_label ///
            _msm_sens_model ///
            _msm_sens_evalue_point ///
            _msm_sens_evalue_ci ///
            _msm_sens_level {
            char _dta[`_msm_char']
        }

        foreach _msm_matrix in _msm_fit_b _msm_fit_V _msm_pred_matrix _msm_bal_matrix {
            capture matrix drop `_msm_matrix'
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
