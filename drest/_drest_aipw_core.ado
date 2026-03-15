*! _drest_aipw_core Version 1.0.0  2026/03/15
*! Core AIPW computation given nuisance predictions
*! Author: Timothy P Copeland

* Usage: _drest_aipw_core outcome treatment psvar mu1var mu0var touse estimand
* Computes AIPW pseudo-outcomes and treatment effect estimate
* Returns via c_local: _drest_tau, _drest_po1_mean, _drest_po0_mean

program define _drest_aipw_core
    version 16.0
    set varabbrev off
    set more off

    args outcome treatment psvar mu1var mu0var touse estimand ifvar

    if "`estimand'" == "" local estimand "ATE"
    local estimand = upper("`estimand'")

    quietly {
        if "`estimand'" == "ATE" {
            * AIPW pseudo-outcome for ATE
            * phi_i = (mu1 - mu0) + A*(Y - mu1)/e - (1-A)*(Y - mu0)/(1-e)
            replace `ifvar' = (`mu1var' - `mu0var') ///
                + `treatment' * (`outcome' - `mu1var') / `psvar' ///
                - (1 - `treatment') * (`outcome' - `mu0var') / (1 - `psvar') ///
                if `touse'

            * ATE = mean of pseudo-outcomes
            summarize `ifvar' if `touse', meanonly
            local tau = r(mean)
            local N = r(N)

            * Augmented potential outcome means
            tempvar aug1 aug0
            gen double `aug1' = `mu1var' + `treatment' * (`outcome' - `mu1var') / `psvar' if `touse'
            gen double `aug0' = `mu0var' + (1 - `treatment') * (`outcome' - `mu0var') / (1 - `psvar') if `touse'
            summarize `aug1' if `touse', meanonly
            local po1_mean = r(mean)
            summarize `aug0' if `touse', meanonly
            local po0_mean = r(mean)
        }
        else if "`estimand'" == "ATT" {
            * ATT: tau = (1/n1) * sum[ A*(Y - mu0) - (1-A)*e/(1-e)*(Y - mu0) ]
            count if `touse' & `treatment' == 1
            local n1 = r(N)

            replace `ifvar' = `treatment' * (`outcome' - `mu0var') ///
                - (1 - `treatment') * `psvar' / (1 - `psvar') * (`outcome' - `mu0var') ///
                if `touse'

            summarize `ifvar' if `touse', meanonly
            local tau = r(sum) / `n1'

            * Potential outcome means for ATT
            summarize `outcome' if `touse' & `treatment' == 1, meanonly
            local po1_mean = r(mean)
            local po0_mean = `po1_mean' - `tau'
        }
        else if "`estimand'" == "ATC" {
            * ATC: mirror of ATT swapping treatment arms
            count if `touse' & `treatment' == 0
            local n0 = r(N)

            replace `ifvar' = (1 - `treatment') * (`mu1var' - `outcome') ///
                + `treatment' * (1 - `psvar') / `psvar' * (`outcome' - `mu1var') ///
                if `touse'

            summarize `ifvar' if `touse', meanonly
            local tau = r(sum) / `n0'

            * Potential outcome means for ATC
            summarize `outcome' if `touse' & `treatment' == 0, meanonly
            local po0_mean = r(mean)
            local po1_mean = `po0_mean' + `tau'
        }
        else {
            display as error "estimand() must be ATE, ATT, or ATC"
            exit 198
        }
    }

    c_local _drest_tau      "`tau'"
    c_local _drest_po1_mean "`po1_mean'"
    c_local _drest_po0_mean "`po0_mean'"
end
