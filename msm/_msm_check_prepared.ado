*! _msm_check_prepared Version 1.2.3  2026/07/17
*! Require a complete, current preparation artifact
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

/*
Syntax:
  _msm_check_prepared

Errors unless the preparation artifact may be used. The verdict comes from
_msm_verify.

This guard previously confirmed that each mapped variable still existed by
name. That passes even when the treatment, outcome, or covariate values have
been replaced wholesale, or when observations have been added or dropped since
msm_prepare ran (audit A02).
*/

program define _msm_check_prepared
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        _msm_verify prepare
        local _ok = r(ok)
        local _why "`r(why)'"

        if `_ok' != 1 {
            if "`_why'" == "notprepared" {
                display as error "data has not been prepared"
                display as error ""
                display as error "Run {bf:msm_prepare} to map your variables and store metadata."
                display as error "Example:"
                display as error "  {cmd:msm_prepare, id(patid) period(period) treatment(treatment)}"
                display as error "  {cmd:  outcome(outcome) covariates(biomarker comorbidity)}"
                exit 198
            }
            else if "`_why'" == "mapping" {
                display as error "a variable mapped by msm_prepare is missing or incomplete"
                display as error ""
                display as error "Re-run {bf:msm_prepare} after restoring or remapping variables."
                exit 111
            }
            else {
                display as error "the data have changed since {bf:msm_prepare} ran"
                display as error ""
                display as error "The mapped variables no longer match the data in memory: they were"
                display as error "edited, or observations were added or dropped. Every later stage"
                display as error "would be computed from data that did not produce it."
                display as error "Re-run {bf:msm_prepare} on the current data."
                exit 459
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
