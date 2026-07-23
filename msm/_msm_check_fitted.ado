*! _msm_check_fitted Version 1.2.4  2026/07/23
*! Require a complete, current, dataset-owned fitted model
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

/*
Syntax:
  _msm_check_fitted

Errors unless the fitted artifact may be used. On success, the verified
coefficients are published as _msm_fit_b / _msm_fit_V, rebuilt from THIS
dataset's characteristics.

The verdict comes from _msm_verify, which is also what msm_prepare/status
consult, so a command and the status display can never disagree about whether a
fit is usable.

This guard previously checked only that char _dta[_msm_fitted] was "1" and that
a matrix named _msm_fit_b existed somewhere in the session. Both were true when
dataset A silently used dataset B's coefficients, and when a variance matrix was
missing entirely (audit A01).
*/

program define _msm_check_fitted
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        _msm_verify fit
        local _ok = r(ok)
        local _why "`r(why)'"

        if `_ok' != 1 {
            if "`_why'" == "notfitted" {
                display as error "no model has been fitted"
                display as error ""
                display as error "Run {bf:msm_fit} to fit the weighted outcome model."
                display as error "Requires {bf:msm_weight} to have been run first."
                display as error "Example:"
                display as error "  {cmd:msm_fit, model(logistic) outcome_cov(age sex) nolog}"
                exit 198
            }
            else if "`_why'" == "stale" {
                display as error "the fitted model is out of date"
                display as error ""
                display as error "The weights were re-estimated after this model was fitted, so the"
                display as error "saved coefficients no longer correspond to the weights in memory."
                display as error "Re-run {bf:msm_fit} to fit the model to the current weights."
                exit 459
            }
            else if "`_why'" == "edited" {
                display as error "the data have changed since the model was fitted"
                display as error ""
                display as error "The variables the model was fitted on no longer match the data in"
                display as error "memory: they were edited, or observations were added or dropped."
                display as error "Re-run {bf:msm_weight} and {bf:msm_fit} on the current data."
                exit 459
            }
            else if "`_why'" == "mapping" {
                display as error "a variable the fitted model needs is no longer in the data"
                display as error "Re-run {bf:msm_prepare}, {bf:msm_weight}, and {bf:msm_fit}."
                exit 111
            }
            else if inlist("`_why'", "partial", "dims") {
                display as error "the saved model is incomplete"
                display as error ""
                display as error "The stored coefficients and variance matrix do not form a usable"
                display as error "model. Re-run {bf:msm_fit} to refresh the fitted model."
                exit 459
            }
            else {
                * nomatrix, header, payload
                display as error "saved model coefficients not found"
                display as error ""
                display as error "This dataset is flagged as fitted but carries no coefficients."
                display as error "Re-run {bf:msm_fit} to refresh the fitted model."
                exit 301
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
