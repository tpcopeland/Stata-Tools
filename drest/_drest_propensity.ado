*! _drest_propensity Version 1.0.0  2026/03/15
*! Fit treatment model and return propensity score predictions
*! Author: Timothy P Copeland

* Usage: _drest_propensity treatment tmodel tfamily touse psvar
* Fits: logit/probit of treatment on tmodel covariates
* Stores predictions in psvar

program define _drest_propensity
    version 16.0
    set varabbrev off
    set more off

    args treatment tmodel tfamily touse psvar

    * Default treatment model family
    if "`tfamily'" == "" local tfamily "logit"

    * Validate treatment family
    if !inlist("`tfamily'", "logit", "probit") {
        display as error "tfamily() must be logit or probit"
        exit 198
    }

    * Fit treatment model
    capture quietly `tfamily' `treatment' `tmodel' if `touse'
    local rc = _rc
    if `rc' {
        display as error "treatment model (`tfamily') failed to converge"
        display as error "check for perfect separation or insufficient variation in covariates"
        exit 498
    }

    * Store predictions (probability of treatment = 1)
    quietly predict double `psvar' if `touse', pr
end
