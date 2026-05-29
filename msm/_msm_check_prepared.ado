*! _msm_check_prepared Version 1.0.4  2026/05/29
*! Verify data has been through msm_prepare
*! Author: Timothy P Copeland

program define _msm_check_prepared
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        local prepared : char _dta[_msm_prepared]
        if "`prepared'" != "1" {
            display as error "data has not been prepared"
            display as error ""
            display as error "Run {bf:msm_prepare} to map your variables and store metadata."
            display as error "Example:"
            display as error "  {cmd:msm_prepare, id(patid) period(period) treatment(treatment)}"
            display as error "  {cmd:  outcome(outcome) covariates(biomarker comorbidity)}"
            exit 198
        }

        local id : char _dta[_msm_id]
        local period : char _dta[_msm_period]
        local treatment : char _dta[_msm_treatment]
        local outcome : char _dta[_msm_outcome]
        local censor : char _dta[_msm_censor]
        local covariates : char _dta[_msm_covariates]
        local bl_covariates : char _dta[_msm_bl_covariates]

        foreach role in id period treatment outcome {
            local var "``role''"
            if "`var'" == "" {
                display as error "prepared MSM metadata is incomplete: missing `role' mapping"
                display as error "Re-run {bf:msm_prepare} to refresh the dataset metadata."
                exit 198
            }
            capture confirm variable `var'
            if _rc != 0 {
                display as error "prepared MSM `role' variable `var' not found"
                display as error "Re-run {bf:msm_prepare} after restoring or remapping variables."
                exit 111
            }
        }

        foreach var of local censor {
            capture confirm variable `var'
            if _rc != 0 {
                display as error "prepared MSM censoring variable `var' not found"
                display as error "Re-run {bf:msm_prepare} after restoring or remapping variables."
                exit 111
            }
        }

        foreach var of local covariates {
            capture confirm variable `var'
            if _rc != 0 {
                display as error "prepared MSM covariate `var' not found"
                display as error "Re-run {bf:msm_prepare} after restoring or remapping variables."
                exit 111
            }
        }

        foreach var of local bl_covariates {
            capture confirm variable `var'
            if _rc != 0 {
                display as error "prepared MSM baseline covariate `var' not found"
                display as error "Re-run {bf:msm_prepare} after restoring or remapping variables."
                exit 111
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
