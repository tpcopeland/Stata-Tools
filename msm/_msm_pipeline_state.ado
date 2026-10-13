*! _msm_pipeline_state Version 2.0.0  2026/10/13
*! Compute current MSM pipeline stage and its artifacts
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

        * msm 2.0.0: downstream steps write no dataset state, so the next step
        * follows from the verified stage alone.
        local next_step "msm_prepare"
        if !`prepared' {
            local next_step "msm_prepare"
        }
        else if !`weighted' {
            local next_step "msm_weight"
        }
        else if !`fitted' {
            local next_step "msm_diagnose or msm_fit"
        }
        else if "`model'" == "logistic" & "`predict_disabled'" != "1" {
            local next_step "msm_predict"
        }
        else {
            local next_step "regtab (tabtools) or qba_confound (qba)"
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

    }
    local _rc = _rc

    set varabbrev `_orig_varabbrev'

    if `_rc' exit `_rc'
end
