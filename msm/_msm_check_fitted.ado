*! _msm_check_fitted Version 1.0.1  2026/03/14
*! Verify model has been fitted
*! Author: Timothy P Copeland

program define _msm_check_fitted
    version 16.0
    set varabbrev off
    set more off

    local fitted : char _dta[_msm_fitted]
    if "`fitted'" != "1" {
        display as error "no model has been fitted"
        display as error ""
        display as error "Run {bf:msm_fit} to fit the weighted outcome model."
        display as error "Requires {bf:msm_weight} to have been run first."
        display as error "Example:"
        display as error "  {cmd:msm_fit, model(logistic) outcome_cov(age sex) nolog}"
        exit 198
    }

    * Verify saved coefficient matrices exist
    capture matrix list _msm_fit_b
    if _rc {
        display as error "saved model coefficients not found"
        display as error "Re-run {bf:msm_fit} to refresh the fitted model."
        exit 301
    }
end
