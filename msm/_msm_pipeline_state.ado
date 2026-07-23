*! _msm_pipeline_state Version 1.2.4  2026/07/23
*! Compute current MSM pipeline stage and saved-artifact state
*! Author: Timothy P Copeland, Karolinska Institutet

program define _msm_pipeline_state
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        local prepared_flag : char _dta[_msm_prepared]
        local id : char _dta[_msm_id]
        local period : char _dta[_msm_period]
        local treatment : char _dta[_msm_treatment]
        local outcome : char _dta[_msm_outcome]
        local censor : char _dta[_msm_censor]
        local covariates : char _dta[_msm_covariates]
        local bl_covariates : char _dta[_msm_bl_covariates]

        local weighted_flag : char _dta[_msm_weighted]
        local weight_var : char _dta[_msm_weight_var]

        local fitted_flag : char _dta[_msm_fitted]
        local model : char _dta[_msm_model]
        local fit_level : char _dta[_msm_fit_level]
        local period_spec : char _dta[_msm_period_spec]
        local outcome_cov : char _dta[_msm_outcome_cov]
        local exposure : char _dta[_msm_exposure]
        local tvcov : char _dta[_msm_tvcov]
        local predict_disabled : char _dta[_msm_predict_disabled]

        local pred_flag : char _dta[_msm_pred_saved]
        local pred_type : char _dta[_msm_pred_type]
        local pred_strategy : char _dta[_msm_pred_strategy]
        local pred_level : char _dta[_msm_pred_level]

        local bal_flag : char _dta[_msm_bal_saved]
        local bal_threshold : char _dta[_msm_bal_threshold]

        local diag_flag : char _dta[_msm_diag_saved]
        local diag_mean : char _dta[_msm_diag_mean]
        local diag_p50 : char _dta[_msm_diag_p50]
        local diag_ess : char _dta[_msm_diag_ess]

        local sens_flag : char _dta[_msm_sens_saved]
        local sens_effect : char _dta[_msm_sens_effect]
        local sens_effect_lo : char _dta[_msm_sens_effect_lo]
        local sens_effect_hi : char _dta[_msm_sens_effect_hi]
        local sens_effect_label : char _dta[_msm_sens_effect_label]
        local sens_level : char _dta[_msm_sens_level]

        * Stage validity comes from _msm_verify, the same authority the guards
        * use, so `msm, status' can never advertise a stage that the next
        * command will refuse -- or hide one it would accept. Verification is
        * read-only here (nohydrate): a status display must not mutate session
        * matrices.
        *
        * These flags used to be existence checks (is the char set, do the
        * variables still exist, does a matrix by that name exist). Every one
        * of the audit's contamination cases satisfied them.
        _msm_verify prepare
        local prepared = r(ok)
        local prepared_why "`r(why)'"

        local weight_vars ""
        foreach var in _msm_weight _msm_tw_weight _msm_cw_weight {
            capture confirm variable `var'
            if _rc == 0 {
                local weight_vars "`weight_vars' `var'"
            }
        }
        local weight_vars : list retokenize weight_vars

        local weighted = 0
        local weighted_why ""
        if `prepared' {
            _msm_verify weight
            local weighted = r(ok)
            local weighted_why "`r(why)'"
        }
        else if "`weighted_flag'" == "1" {
            local weighted_why "stale"
        }

        local fitted = 0
        local fitted_why ""
        if `weighted' {
            _msm_verify fit, nohydrate
            local fitted = r(ok)
            local fitted_why "`r(why)'"
        }
        else if "`fitted_flag'" == "1" {
            local fitted_why "stale"
        }

        * Report the artifacts that actually exist, whether or not the stage
        * verifies. This list is descriptive (what is in the dataset), while
        * `fitted' above is the verdict (whether it may be used). Keeping them
        * separate is what lets status say "coefficients are present but do not
        * belong to these data" instead of silently claiming a usable fit.
        local fit_artifacts ""
        capture confirm matrix _msm_fit_b
        if _rc == 0 {
            local fit_artifacts "`fit_artifacts' _msm_fit_b"
        }
        capture confirm matrix _msm_fit_V
        if _rc == 0 {
            local fit_artifacts "`fit_artifacts' _msm_fit_V"
        }
        capture confirm variable _msm_esample
        if _rc == 0 {
            local fit_artifacts "`fit_artifacts' _msm_esample"
        }
        local fit_artifacts : list retokenize fit_artifacts

        * Stages below the fit cannot be usable when the fit itself is not:
        * they were computed from coefficients that no longer verify. The
        * dependency is enforced here as well as in _msm_invalidate, because
        * invalidation only runs on OUR commit paths -- a dataset arriving from
        * elsewhere has never been through one.
        capture confirm matrix _msm_pred_matrix
        local has_pred_matrix = cond(_rc == 0, 1, 0)
        local pred_saved = 0
        if "`pred_flag'" == "1" & `has_pred_matrix' & `fitted' {
            local pred_saved = 1
        }

        capture confirm matrix _msm_bal_matrix
        local has_bal_matrix = cond(_rc == 0, 1, 0)
        local bal_saved = 0
        if "`bal_flag'" == "1" & `has_bal_matrix' & `weighted' {
            local bal_saved = 1
        }

        local diag_saved = 0
        if "`diag_flag'" == "1" & "`diag_mean'" != "" & `weighted' {
            local diag_saved = 1
        }

        local sens_saved = 0
        if "`sens_flag'" == "1" & "`sens_effect'" != "" & `fitted' {
            local sens_saved = 1
        }

        if !`prepared' {
            local id ""
            local period ""
            local treatment ""
            local outcome ""
            local censor ""
            local covariates ""
            local bl_covariates ""
            local weight_var ""
            local weight_vars ""
            local fit_artifacts ""
            local model ""
            local fit_level ""
            local period_spec ""
            local outcome_cov ""
            local exposure ""
            local tvcov ""
            local predict_disabled ""
            local pred_saved = 0
            local bal_saved = 0
            local diag_saved = 0
            local sens_saved = 0
            local weighted = 0
            local fitted = 0
        }

        local stage "not_prepared"
        local stage_label "Not prepared"
        if `prepared' {
            local stage "prepared"
            local stage_label "Prepared"
        }
        if `weighted' {
            local stage "weighted"
            local stage_label "Weighted"
        }
        if `fitted' {
            local stage "fitted"
            local stage_label "Fitted"
        }

        local next_step "msm_prepare"
        if !`prepared' {
            local next_step "msm_prepare"
        }
        else if !`weighted' {
            local next_step "msm_validate or msm_weight"
        }
        else if !`fitted' {
            if !`diag_saved' | !`bal_saved' {
                local next_step "msm_diagnose or msm_fit"
            }
            else {
                local next_step "msm_fit"
            }
        }
        else if "`model'" == "logistic" & "`predict_disabled'" != "1" {
            if !`pred_saved' {
                local next_step "msm_predict"
            }
            else if !`sens_saved' {
                local next_step "msm_sensitivity"
            }
            else {
                local next_step "msm_report or msm_table"
            }
        }
        else if "`model'" == "cox" | ("`model'" == "logistic" & "`predict_disabled'" == "1") {
            if !`sens_saved' {
                local next_step "msm_sensitivity"
            }
            else {
                local next_step "msm_report or msm_table"
            }
        }
        else {
            local next_step "msm_report or msm_table"
        }

        if "`weight_var'" == "" & `weighted' {
            local weight_var "_msm_weight"
        }

        c_local _msm_state_stage "`stage'"
        c_local _msm_state_stage_label "`stage_label'"
        c_local _msm_state_next_step "`next_step'"

        c_local _msm_state_prepared "`prepared'"
        c_local _msm_state_weighted "`weighted'"
        c_local _msm_state_fitted "`fitted'"

        * Why a claimed stage did not verify: "" when the stage is usable or
        * was never claimed. Tokens: mapping, stale, edited, nomatrix, partial,
        * dims (see _msm_verify).
        c_local _msm_state_prepared_why "`prepared_why'"
        c_local _msm_state_weighted_why "`weighted_why'"
        c_local _msm_state_fitted_why "`fitted_why'"
        c_local _msm_state_pred_saved "`pred_saved'"
        c_local _msm_state_bal_saved "`bal_saved'"
        c_local _msm_state_diag_saved "`diag_saved'"
        c_local _msm_state_sens_saved "`sens_saved'"

        c_local _msm_state_id "`id'"
        c_local _msm_state_period "`period'"
        c_local _msm_state_treatment "`treatment'"
        c_local _msm_state_outcome "`outcome'"
        c_local _msm_state_censor "`censor'"
        c_local _msm_state_covariates "`covariates'"
        c_local _msm_state_bl_covariates "`bl_covariates'"

        c_local _msm_state_weight_var "`weight_var'"
        c_local _msm_state_weight_vars "`weight_vars'"
        c_local _msm_state_fit_artifacts "`fit_artifacts'"
        c_local _msm_state_model "`model'"
        c_local _msm_state_fit_level "`fit_level'"
        c_local _msm_state_period_spec "`period_spec'"
        c_local _msm_state_outcome_cov "`outcome_cov'"
        c_local _msm_state_exposure "`exposure'"
        c_local _msm_state_tvcov "`tvcov'"
        c_local _msm_state_predict_disabled "`predict_disabled'"

        c_local _msm_state_pred_type "`pred_type'"
        c_local _msm_state_pred_strategy "`pred_strategy'"
        c_local _msm_state_pred_level "`pred_level'"

        c_local _msm_state_bal_threshold "`bal_threshold'"

        c_local _msm_state_diag_mean "`diag_mean'"
        c_local _msm_state_diag_p50 "`diag_p50'"
        c_local _msm_state_diag_ess "`diag_ess'"

        c_local _msm_state_sens_effect "`sens_effect'"
        c_local _msm_state_sens_effect_lo "`sens_effect_lo'"
        c_local _msm_state_sens_effect_hi "`sens_effect_hi'"
        c_local _msm_state_sens_effect_label "`sens_effect_label'"
        c_local _msm_state_sens_level "`sens_level'"
    }
    local _rc = _rc

    set varabbrev `_orig_varabbrev'

    if `_rc' exit `_rc'
end
