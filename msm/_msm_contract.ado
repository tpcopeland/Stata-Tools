*! _msm_contract Version 1.2.3  2026/07/17
*! Build the canonical metadata contract for an MSM pipeline stage
*! Author: Timothy P Copeland
*! Program class: rclass (returns results in r())

/*
The data signature binds a stage to variable values. This companion contract
binds it to the exact metadata that says how those values were interpreted.
Keeping the field list here prevents production code, verification, and QA
fixtures from silently signing different surfaces.

Syntax:
  _msm_contract prepare|weight|fit

Returns:
  r(contract) - canonical key=value sequence for the requested stage
*/

program define _msm_contract, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        gettoken stage 0 : 0
        if !inlist("`stage'", "prepare", "weight", "fit") | strtrim("`0'") != "" {
            display as error "syntax is _msm_contract prepare|weight|fit"
            exit 198
        }

        if "`stage'" == "prepare" {
            local keys _msm_prepared _msm_id _msm_period _msm_treatment ///
                _msm_outcome _msm_censor _msm_covariates _msm_bl_covariates ///
                _msm_prefix _msm_prep_uuid _msm_prep_sig _msm_prep_sigvars
        }
        else if "`stage'" == "weight" {
            local keys _msm_weighted _msm_weight_var _msm_weight_uuid ///
                _msm_weight_dep _msm_weight_sig _msm_weight_sigvars ///
                _msm_wt_spec _msm_treat_d_cov _msm_treat_n_cov ///
                _msm_censor_d_cov _msm_censor_n_cov _msm_numer_covars ///
                _msm_weight_truncate _msm_weight_fitfailure ///
                _msm_probability_policy _msm_probability_clip ///
                _msm_probability_models ///
                _msm_ps_var _msm_tw_var _msm_ps_covars _msm_estimand ///
                _msm_contract_version
        }
        else {
            local keys _msm_fitted _msm_model _msm_period_spec ///
                _msm_outcome_cov _msm_exposure _msm_tvcov ///
                _msm_history_spec _msm_history_vars _msm_history_assumption ///
                _msm_predict_disabled _msm_per_ns_knots _msm_per_ns_df ///
                _msm_cluster _msm_vce _msm_strata _msm_time_vars ///
                _msm_fit_level _msm_fit_uuid _msm_fit_dep _msm_fit_sig ///
                _msm_fit_sigvars _msm_fit_effect_term ///
                _msm_fit_b_id _msm_fit_V_id
        }

        local contract "stage=`stage'"
        foreach key of local keys {
            local value : char _dta[`key']
            local contract `"`contract'|`key'=`value'"'
        }
        return local contract `"`contract'"'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
