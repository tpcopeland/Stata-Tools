*! _drest_tmle_fluctuate Version 1.0.0  2026/03/15
*! TMLE targeting step: fluctuate initial outcome model estimates
*! Author: Timothy P Copeland

* Usage: _drest_tmle_fluctuate outcome treatment psvar mu1var mu0var touse
*        is_binary iterate tolerance
* Updates mu1var and mu0var in-place with targeted predictions
* Returns via c_local: _drest_converged, _drest_n_iter, _drest_epsilon

program define _drest_tmle_fluctuate
    version 16.0
    set varabbrev off
    set more off

    args outcome treatment psvar mu1var mu0var touse is_binary iterate tolerance

    if "`iterate'" == "" local iterate = 100
    if "`tolerance'" == "" local tolerance = 1e-5

    quietly {
        if "`is_binary'" == "1" {
            * =============================================================
            * BINARY OUTCOME: logistic fluctuation with offset
            * =============================================================
            * Clever covariate: H1 = A/e, H0 = -(1-A)/(1-e)
            tempvar H1 H0 logit_mu

            gen double `H1' = `treatment' / `psvar' if `touse'
            gen double `H0' = -(1 - `treatment') / (1 - `psvar') if `touse'

            * Combined clever covariate for targeting
            tempvar H_combined
            gen double `H_combined' = `H1' + `H0' if `touse'

            * Current logit of initial predictions (for offset)
            gen double `logit_mu' = logit(`mu1var' * `treatment' ///
                + `mu0var' * (1 - `treatment')) if `touse'

            * Bound predictions away from 0/1 for logit transform
            replace `logit_mu' = logit(0.001) if `touse' & `logit_mu' < logit(0.001)
            replace `logit_mu' = logit(0.999) if `touse' & `logit_mu' > logit(0.999)

            * Iterative targeting
            local converged = 0
            local iter = 0
            local epsilon = .

            forvalues i = 1/`iterate' {
                local ++iter

                * Fit fluctuation model: logit(Y) = epsilon*H + offset(logit(mu_init))
                capture glm `outcome' `H_combined' if `touse', ///
                    family(binomial) link(logit) offset(`logit_mu') noconstant
                local rc = _rc
                if `rc' {
                    * If GLM fails, try with smaller step
                    local converged = 0
                    continue, break
                }

                local epsilon = _b[`H_combined']

                * Check convergence
                if abs(`epsilon') < `tolerance' {
                    local converged = 1
                    continue, break
                }

                * Update predictions
                * mu1_star = invlogit(logit(mu1) + epsilon/e)
                * mu0_star = invlogit(logit(mu0) - epsilon/(1-e))
                tempvar logit_mu1 logit_mu0
                gen double `logit_mu1' = logit(max(0.001, min(0.999, `mu1var'))) if `touse'
                gen double `logit_mu0' = logit(max(0.001, min(0.999, `mu0var'))) if `touse'

                replace `mu1var' = invlogit(`logit_mu1' + `epsilon' / `psvar') if `touse'
                replace `mu0var' = invlogit(`logit_mu0' - `epsilon' / (1 - `psvar')) if `touse'

                * Update offset for next iteration
                drop `logit_mu'
                gen double `logit_mu' = logit(`mu1var' * `treatment' ///
                    + `mu0var' * (1 - `treatment')) if `touse'
                replace `logit_mu' = logit(0.001) if `touse' & `logit_mu' < logit(0.001)
                replace `logit_mu' = logit(0.999) if `touse' & `logit_mu' > logit(0.999)

                drop `logit_mu1' `logit_mu0'
            }

            * (convergence status already set inside the loop)
        }
        else {
            * =============================================================
            * CONTINUOUS OUTCOME: linear fluctuation
            * =============================================================
            * For continuous Y, use linear fluctuation (simpler, one-step)
            * Clever covariate: H = A/e - (1-A)/(1-e)
            tempvar H_ate mu_init resid

            gen double `H_ate' = `treatment' / `psvar' ///
                - (1 - `treatment') / (1 - `psvar') if `touse'

            * Initial combined prediction
            gen double `mu_init' = `mu1var' * `treatment' ///
                + `mu0var' * (1 - `treatment') if `touse'

            * Residual from initial fit
            tempvar resid_y
            gen double `resid_y' = `outcome' - `mu_init' if `touse'

            * Fit fluctuation: (Y - mu_init) = epsilon*H (no constant)
            capture regress `resid_y' `H_ate' if `touse', noconstant
            local rc = _rc
            if `rc' {
                local converged = 0
                local iter = 1
                local epsilon = 0
            }
            else {
                local epsilon = _b[`H_ate']
                local converged = 1
                local iter = 1

                * Update targeted predictions
                * mu1_star = mu1 + epsilon * (1/e)
                * mu0_star = mu0 + epsilon * (-1/(1-e))
                replace `mu1var' = `mu1var' + `epsilon' / `psvar' if `touse'
                replace `mu0var' = `mu0var' - `epsilon' / (1 - `psvar') if `touse'
            }
        }
    }

    c_local _drest_converged "`converged'"
    c_local _drest_n_iter    "`iter'"
    c_local _drest_epsilon   "`epsilon'"
end
