*! _drest_outcome_model Version 1.0.0  2026/03/15
*! Fit outcome model separately by treatment arm, predict for all
*! Author: Timothy P Copeland

* Usage: _drest_outcome_model outcome treatment omodel ofamily touse mu1var mu0var
* Fits outcome model within each treatment arm
* Stores predicted potential outcomes in mu1var (treated) and mu0var (control)

program define _drest_outcome_model
    version 16.0
    set varabbrev off
    set more off

    args outcome treatment omodel ofamily touse mu1var mu0var

    * Determine outcome type and set defaults
    if "`ofamily'" == "" {
        * Check if binary (0/1)
        capture assert inlist(`outcome', 0, 1) if `touse'
        if _rc == 0 {
            local ofamily "logit"
        }
        else {
            local ofamily "regress"
        }
    }

    * Validate outcome family
    if !inlist("`ofamily'", "regress", "logit", "probit", "poisson") {
        display as error "ofamily() must be regress, logit, probit, or poisson"
        exit 198
    }

    * Set prediction option based on family
    if "`ofamily'" == "regress" {
        local predict_opt "xb"
    }
    else if inlist("`ofamily'", "logit", "probit") {
        local predict_opt "pr"
    }
    else if "`ofamily'" == "poisson" {
        local predict_opt "n"
    }

    * Fit outcome model among TREATED (A=1), predict for ALL
    capture quietly `ofamily' `outcome' `omodel' if `touse' & `treatment' == 1
    local rc = _rc
    if `rc' {
        display as error "outcome model (`ofamily') failed in treated arm"
        display as error "check for insufficient observations or collinearity"
        exit 498
    }
    quietly predict double `mu1var' if `touse', `predict_opt'

    * Fit outcome model among CONTROL (A=0), predict for ALL
    capture quietly `ofamily' `outcome' `omodel' if `touse' & `treatment' == 0
    local rc = _rc
    if `rc' {
        display as error "outcome model (`ofamily') failed in control arm"
        display as error "check for insufficient observations or collinearity"
        exit 498
    }
    quietly predict double `mu0var' if `touse', `predict_opt'
end
