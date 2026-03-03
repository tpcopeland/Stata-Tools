*! _msm_check_prepared Version 1.0.0  2026/03/03
*! Verify data has been through msm_prepare
*! Author: Timothy P Copeland

program define _msm_check_prepared
    version 16.0
    set varabbrev off
    set more off

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
end
