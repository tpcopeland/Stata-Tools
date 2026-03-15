*! drest_bootstrap Version 1.0.0  2026/03/15
*! Bootstrap inference for doubly robust estimation
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: eclass (returns results in e())

/*
Basic syntax:
  drest_bootstrap [, reps(integer) seed(integer) level(cilevel) nolog]

Requires: drest_estimate has been run (reads settings from characteristics)

See help drest_bootstrap for complete documentation
*/

program define drest_bootstrap, eclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    syntax [, Reps(integer 1000) SEED(integer -1) Level(cilevel) noLOG]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================
    _drest_check_estimated
    _drest_get_settings

    local outcome    "`_drest_outcome'"
    local treatment  "`_drest_treatment'"
    local omodel     "`_drest_omodel'"
    local ofamily    "`_drest_ofamily'"
    local tmodel     "`_drest_tmodel'"
    local tfamily    "`_drest_tfamily'"
    local estimand   "`_drest_estimand'"
    local trim_lo    "`_drest_trimps_lo'"
    local trim_hi    "`_drest_trimps_hi'"

    * LTMLE requires person-level bootstrap; this command does cross-sectional AIPW
    if "`_drest_method'" == "ltmle" {
        set varabbrev `_vaset'
        display as error "drest_bootstrap is not compatible with LTMLE estimation"
        display as error "LTMLE requires person-level resampling; use Stata's {bf:bootstrap} prefix instead"
        exit 198
    }

    if "`level'" == "" local level = c(level)

    * =========================================================================
    * VALIDATE
    * =========================================================================
    if `reps' < 2 {
        set varabbrev `_vaset'
        display as error "reps() must be at least 2"
        exit 198
    }

    capture confirm variable _drest_esample
    if _rc {
        set varabbrev `_vaset'
        display as error "_drest_esample not found; re-run drest_estimate"
        exit 111
    }

    _drest_display_header "drest_bootstrap" "Bootstrap Inference"

    display as text "Bootstrap replications: " as result `reps'
    if `seed' >= 0 {
        display as text "Seed: " as result `seed'
    }
    display as text ""

    * Prediction option for outcome model
    local predict_opt ""
    if inlist("`ofamily'", "logit", "probit") local predict_opt "pr"
    else if "`ofamily'" == "poisson" local predict_opt "n"

    * =========================================================================
    * RUN BOOTSTRAP (manual loop with preserve/bsample/restore)
    * =========================================================================
    if `seed' >= 0 {
        set seed `seed'
    }

    if "`log'" == "" {
        display as text "Running bootstrap..." _continue
    }

    tempname bs_results
    matrix `bs_results' = J(`reps', 1, .)

    forvalues rep = 1/`reps' {
        quietly {
            preserve

            * Resample with replacement within estimation sample
            bsample if _drest_esample == 1

            * Fit PS
            capture `tfamily' `treatment' `tmodel'
            if _rc {
                restore
                continue
            }
            tempvar _bps
            predict double `_bps', pr
            replace `_bps' = max(`trim_lo', min(`trim_hi', `_bps'))

            * Fit outcome models
            capture `ofamily' `outcome' `omodel' if `treatment' == 1
            if _rc {
                restore
                continue
            }
            tempvar _bm1
            predict double `_bm1', `predict_opt'

            capture `ofamily' `outcome' `omodel' if `treatment' == 0
            if _rc {
                restore
                continue
            }
            tempvar _bm0
            predict double `_bm0', `predict_opt'

            * AIPW pseudo-outcome (estimand-specific)
            tempvar _bphi
            if "`estimand'" == "ATE" {
                gen double `_bphi' = (`_bm1' - `_bm0') ///
                    + `treatment' * (`outcome' - `_bm1') / `_bps' ///
                    - (1 - `treatment') * (`outcome' - `_bm0') / (1 - `_bps')
                summarize `_bphi', meanonly
                local rep_tau = r(mean)
            }
            else if "`estimand'" == "ATT" {
                gen double `_bphi' = `treatment' * (`outcome' - `_bm0') ///
                    - (1 - `treatment') * `_bps' / (1 - `_bps') * (`outcome' - `_bm0')
                count if `treatment' == 1
                local _bn1 = r(N)
                summarize `_bphi', meanonly
                local rep_tau = r(sum) / `_bn1'
            }
            else if "`estimand'" == "ATC" {
                gen double `_bphi' = (1 - `treatment') * (`_bm1' - `outcome') ///
                    + `treatment' * (1 - `_bps') / `_bps' * (`outcome' - `_bm1')
                count if `treatment' == 0
                local _bn0 = r(N)
                summarize `_bphi', meanonly
                local rep_tau = r(sum) / `_bn0'
            }

            restore

            matrix `bs_results'[`rep', 1] = `rep_tau'
        }
    }

    if "`log'" == "" {
        display as text " done"
    }

    * =========================================================================
    * COMPUTE BOOTSTRAP STATISTICS
    * =========================================================================
    * Count successful replications
    quietly {
        preserve
        clear
        svmat double `bs_results', names(tau)
        drop if tau1 == .
        local n_ok = _N

        summarize tau1, meanonly
        local bs_tau = r(mean)

        summarize tau1
        local bs_se = r(sd)
        restore
    }

    if `n_ok' < 2 {
        set varabbrev `_vaset'
        display as error "insufficient successful bootstrap replications (`n_ok')"
        exit 2000
    }

    if `bs_se' > 0 {
        local z_val  = `bs_tau' / `bs_se'
        local pvalue = 2 * normal(-abs(`z_val'))
    }
    else {
        local z_val  = .
        local pvalue = .
    }
    local z_crit = invnormal(1 - (100 - `level') / 200)
    local ci_lo  = `bs_tau' - `z_crit' * `bs_se'
    local ci_hi  = `bs_tau' + `z_crit' * `bs_se'

    * =========================================================================
    * DISPLAY
    * =========================================================================
    display as text ""
    display as text "{hline 70}"
    display as text %16s "`estimand'" as text " {c |}" ///
        as text %12s "Estimate" as text %12s "BS Std.Err." ///
        as text %10s "z" as text %10s "P>|z|" ///
        as text %24s "[`level'% Conf. Interval]"
    display as text "{hline 16}{c +}{hline 53}"
    display as text %16s "`estimand'" as text " {c |}" ///
        as result %12.4f `bs_tau' ///
        as result %12.4f `bs_se' ///
        as result %10.2f `z_val' ///
        as result %10.3f `pvalue' ///
        as result %12.4f `ci_lo' ///
        as result %12.4f `ci_hi'
    display as text "{hline 70}"

    if `n_ok' < `reps' {
        display as text "  (" `n_ok' " of " `reps' " replications successful)"
        if `n_ok' < `reps' * 0.8 {
            display as text "  {it:Warning: >" %3.0f 100 * (1 - `n_ok'/`reps') "% of replications failed; bootstrap SE may be unreliable}"
        }
    }

    * Original IF-based estimate for comparison
    local orig_tau "`_drest_ate'"
    local orig_se  "`_drest_ate_se'"

    display as text ""
    display as text "{bf:Comparison with IF-based inference:}"
    display as text "  IF estimate:  " as result %10.4f `orig_tau' ///
        as text "  (SE = " as result %8.4f `orig_se' as text ")"
    display as text "  BS estimate:  " as result %10.4f `bs_tau' ///
        as text "  (SE = " as result %8.4f `bs_se' as text ")"

    * =========================================================================
    * POST ECLASS RESULTS
    * =========================================================================
    tempname b V
    matrix `b' = (`bs_tau')
    matrix colnames `b' = `estimand'
    matrix `V' = (`bs_se'^2)
    matrix colnames `V' = `estimand'
    matrix rownames `V' = `estimand'

    quietly count if _drest_esample == 1
    local N = r(N)

    tempvar bs_esample
    quietly gen byte `bs_esample' = (_drest_esample == 1)
    ereturn post `b' `V', obs(`N') esample(`bs_esample')

    ereturn scalar tau = `bs_tau'
    ereturn scalar se = `bs_se'
    ereturn scalar z = `z_val'
    ereturn scalar p = `pvalue'
    ereturn scalar ci_lo = `ci_lo'
    ereturn scalar ci_hi = `ci_hi'
    ereturn scalar reps = `reps'
    ereturn scalar reps_ok = `n_ok'
    ereturn scalar level = `level'

    ereturn local cmd "drest_bootstrap"
    ereturn local method "aipw_bootstrap"
    ereturn local outcome "`outcome'"
    ereturn local treatment "`treatment'"
    ereturn local estimand "`estimand'"
    ereturn local title "Bootstrap AIPW doubly robust estimation"

    set varabbrev `_vaset'
end
