*! _msm_check_weighted Version 1.0.3  2026/05/06
*! Verify weight variable exists
*! Author: Timothy P Copeland

program define _msm_check_weighted
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        local weighted : char _dta[_msm_weighted]
        if "`weighted'" != "1" {
            display as error "data has not been weighted"
            display as error ""
            display as error "Run {bf:msm_weight} to estimate inverse probability weights."
            display as error "Example:"
            display as error "  {cmd:msm_weight, treat_d_cov(age sex biomarker comorbidity)}"
            display as error "  {cmd:  treat_n_cov(age sex) truncate(1 99) nolog}"
            exit 198
        }

        capture confirm variable _msm_weight
        if _rc != 0 {
            display as error "weight variable _msm_weight not found"
            display as error ""
            display as error "Run {bf:msm_weight} to estimate inverse probability weights."
            exit 111
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
