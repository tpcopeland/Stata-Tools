*! _psdash_contract_info Version 1.5.0  2026/07/22
*! Machine-readable producer compatibility matrix for psdash
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define _psdash_contract_info, rclass
    version 16.0
    gettoken source extra : 0
    local source = lower(strtrim("`source'"))
    if "`source'" == "" | strtrim("`extra'") != "" | ///
            !inlist("`source'", "iivw", "msm", "tte", "tmle", "ltmle") {
        display as error "producer must be one of: iivw msm tte tmle ltmle"
        exit 198
    }

    if "`source'" == "iivw" {
        local guard "_iivw_check_weighted"
        local version_field "_iivw_contract_version"
        local min_version "2"
        local max_version "2"
        local fields "_iivw_weighted _iivw_weighttype _iivw_treat _iivw_ps_var _iivw_tw_var _iivw_iw_var _iivw_weight_var _iivw_treat_covars _iivw_ps_estimand _iivw_contract_version"
    }
    else if "`source'" == "msm" {
        local guard "_msm_check_weighted"
        local version_field "_msm_contract_version"
        local min_version "1.0"
        local max_version "1.0"
        local fields "_msm_weighted _msm_treatment _msm_ps_var _msm_period _msm_id _msm_tw_var _msm_weight_var _msm_ps_covars _msm_covariates _msm_estimand _msm_contract_version"
    }
    else if "`source'" == "tte" {
        local guard "_tte_get_weight_state"
        local version_field "_tte_contract_version"
        local min_version "1.0"
        local max_version "1.0"
        local fields "_tte_weighted _tte_treatment _tte_pscore_var _tte_period _tte_id _tte_weight_var _tte_covariates _tte_estimand _tte_contract_version"
    }
    else if "`source'" == "tmle" {
        local guard "_tmle_get_context"
        local version_field "_tmle_contract_version"
        local min_version "1.0"
        local max_version "1.0"
        local fields "_tmle_treatment _tmle_ps_var _tmle_tmodel _tmle_method _tmle_weight_var _tmle_esample _tmle_estimand _tmle_covariates _tmle_contract_version"
    }
    else {
        local guard "_ltmle_get_context"
        local version_field "_ltmle_contract_version"
        local min_version "1.0"
        local max_version "1.0"
        local fields "_ltmle_treatment _ltmle_ps_var _ltmle_tmodel _ltmle_method _ltmle_regime _ltmle_weight_var _ltmle_esample _ltmle_id _ltmle_period _ltmle_estimand _ltmle_contract_version"
    }

    return local source "`source'"
    return local guard "`guard'"
    return local version_field "`version_field'"
    return local min_version "`min_version'"
    return local max_version "`max_version'"
    return local fields "`fields'"
end
