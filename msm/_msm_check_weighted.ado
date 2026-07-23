*! _msm_check_weighted Version 1.2.4  2026/07/23
*! Require a complete, current weighting artifact
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

/*
Syntax:
  _msm_check_weighted

Errors unless the weighting artifact may be used. The verdict comes from
_msm_verify.

This guard previously checked only that char _dta[_msm_weighted] was "1" and
that a variable named _msm_weight existed. Both remain true after the weights
themselves have been edited, after the data behind them have changed, and after
msm_prepare has been re-run with a different mapping (audit A02, A03).
*/

program define _msm_check_weighted
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        _msm_verify weight
        local _ok = r(ok)
        local _why "`r(why)'"

        if `_ok' != 1 {
            if "`_why'" == "notweighted" {
                display as error "data has not been weighted"
                display as error ""
                display as error "Run {bf:msm_weight} to estimate inverse probability weights."
                display as error "Example:"
                display as error "  {cmd:msm_weight, treat_d_cov(age sex biomarker comorbidity)}"
                display as error "  {cmd:  treat_n_cov(age sex) truncate(1 99) nolog}"
                exit 198
            }
            else if "`_why'" == "mapping" {
                display as error "weight variable _msm_weight not found"
                display as error ""
                display as error "Run {bf:msm_weight} to estimate inverse probability weights."
                exit 111
            }
            else if "`_why'" == "stale" {
                display as error "the weights are out of date"
                display as error ""
                display as error "{bf:msm_prepare} was re-run after these weights were estimated, so"
                display as error "they no longer correspond to the current variable mapping."
                display as error "Re-run {bf:msm_weight} on the current preparation."
                exit 459
            }
            else {
                display as error "the data have changed since the weights were estimated"
                display as error ""
                display as error "The variables the weight models used no longer match the data in"
                display as error "memory: they were edited, or observations were added or dropped."
                display as error "Re-run {bf:msm_weight} on the current data."
                exit 459
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
