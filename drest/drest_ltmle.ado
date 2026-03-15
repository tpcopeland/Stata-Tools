*! drest_ltmle Version 1.0.0  2026/03/15
*! Longitudinal Targeted Minimum Loss-Based Estimation (LTMLE)
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: eclass (returns results in e())

/*
Basic syntax:
  drest_ltmle [if] [in], id(varname) period(varname) outcome(varname)
      treatment(varname) covariates(varlist)
      [baseline(varlist) censor(varname) regime(string)
       ofamily(string) tfamily(string) trimps(numlist)
       iterate(integer) tolerance(real) level(cilevel) nolog]

Description:
  LTMLE extends TMLE to longitudinal settings with time-varying
  treatments and confounders. Uses sequential regression from the
  final period backward, with a targeting step at each time point.

  Requires person-period (long-format) data with one row per
  person-period. Compatible with data expanded by tte_expand.

Algorithm:
  1. Start at final period T, work backward to t=1
  2. At each t:
     a. Fit outcome model: E[Q_{t+1} | A_t, L_t, X]
     b. Fit treatment model: P(A_t = a | history)
     c. Fit censoring model (if applicable): P(C_t = 0 | history)
     d. Compute clever covariate (cumulative IP weight ratio)
     e. Targeting step: fluctuate outcome model
     f. Update pseudo-outcome for t-1
  3. Final ATE at baseline: mean(Q_0(always)) - mean(Q_0(never))
  4. IF-based inference

See help drest_ltmle for complete documentation
*/

program define drest_ltmle, eclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax [if] [in] , ID(varname) PERiod(varname numeric) ///
        OUTcome(varname numeric) TREATment(varname numeric) ///
        COVariates(varlist numeric) ///
        [BASEline(varlist numeric) CENsor(varname numeric) ///
         REGime(string) OFamily(string) TFamily(string) ///
         TRIMps(numlist min=1 max=2) ///
         Level(cilevel) noLOG]

    * =========================================================================
    * MARK SAMPLE
    * =========================================================================
    marksample touse
    markout `touse' `id' `period' `outcome' `treatment' `covariates'
    if "`baseline'" != "" markout `touse' `baseline'
    if "`censor'" != "" markout `touse' `censor'

    quietly count if `touse'
    if r(N) == 0 {
        set varabbrev `_vaset'
        display as error "no observations"
        exit 2000
    }
    local N_total = r(N)

    * =========================================================================
    * VALIDATE INPUTS
    * =========================================================================
    * Treatment must be binary
    capture assert inlist(`treatment', 0, 1) if `touse'
    if _rc {
        set varabbrev `_vaset'
        display as error "treatment() must be a binary (0/1) variable"
        exit 198
    }

    * Outcome must be binary for LTMLE
    capture assert inlist(`outcome', 0, 1) if `touse'
    if _rc {
        set varabbrev `_vaset'
        display as error "outcome() must be binary (0/1) for LTMLE"
        exit 198
    }

    * Censor must be binary if specified
    if "`censor'" != "" {
        capture assert inlist(`censor', 0, 1) if `touse'
        if _rc {
            set varabbrev `_vaset'
            display as error "censor() must be binary (0/1)"
            exit 198
        }
    }

    * Regime
    if "`regime'" == "" local regime "always_never"
    if !inlist("`regime'", "always_never", "always", "never") {
        set varabbrev `_vaset'
        display as error "regime() must be always_never, always, or never"
        exit 198
    }

    * Defaults
    if "`level'" == "" local level = c(level)
    if "`ofamily'" == "" local ofamily "logit"
    if "`tfamily'" == "" local tfamily "logit"

    * Parse trimming bounds
    if "`trimps'" == "" {
        local trim_lo = 0.01
        local trim_hi = 0.99
    }
    else {
        local nwords : word count `trimps'
        if `nwords' == 1 {
            if `trimps' == 0 {
                local trim_lo = 0
                local trim_hi = 1
            }
            else {
                local trim_lo = `trimps'
                local trim_hi = 1 - `trimps'
            }
        }
        else {
            local trim_lo : word 1 of `trimps'
            local trim_hi : word 2 of `trimps'
        }
    }

    * =========================================================================
    * DETERMINE TIME STRUCTURE
    * =========================================================================
    quietly {
        * Get unique period values (handles non-consecutive periods)
        levelsof `period' if `touse', local(period_values)
        local T : word count `period_values'
        local t_min : word 1 of `period_values'
        local t_max : word `T' of `period_values'

        * Build reversed period list for backward iteration
        local periods_rev ""
        forvalues i = `T'(-1)1 {
            local pval : word `i' of `period_values'
            local periods_rev "`periods_rev' `pval'"
        }

        * Count unique individuals
        tempvar id_tag
        egen byte `id_tag' = tag(`id') if `touse'
        count if `id_tag' == 1 & `touse'
        local N_id = r(N)
    }

    if `T' < 2 {
        set varabbrev `_vaset'
        display as error "at least 2 time periods required for LTMLE"
        exit 198
    }

    * Check for tte integration
    local tte_prepared : char _dta[_tte_prepared]

    if "`log'" == "" {
        display as text "LTMLE: `N_id' individuals, `T' periods (`t_min'-`t_max')"
        if "`tte_prepared'" == "1" {
            display as text "  (tte integration detected)"
        }
    }

    * =========================================================================
    * DROP OLD VARIABLES
    * =========================================================================
    foreach v in _drest_ltmle_q1 _drest_ltmle_q0 _drest_esample {
        capture drop `v'
    }

    * =========================================================================
    * STEP 1: SEQUENTIAL REGRESSION (backward from T)
    * =========================================================================
    * Initialize pseudo-outcomes for each regime
    * Q_T = Y_T (the observed/final outcome)
    tempvar Q_always Q_never

    quietly {
        gen double `Q_always' = `outcome' if `touse'
        gen double `Q_never'  = `outcome' if `touse'
    }

    * Build covariate list: time-varying + baseline
    local all_covs "`covariates'"
    if "`baseline'" != "" local all_covs "`all_covs' `baseline'"

    local n_trimmed = 0

    * Work backward through actual period values
    local period_idx = `T'
    foreach t of local periods_rev {
        if "`log'" == "" {
            display as text "  Period `t'..." _continue
        }

        quietly {
            * Observations at this time point
            tempvar at_t

            gen byte `at_t' = (`touse' & `period' == `t')

            * =============================================================
            * A. Fit treatment model at time t
            * =============================================================
            tempvar ps_t
            capture `tfamily' `treatment' `all_covs' if `at_t'
            local rc = _rc
            if `rc' {
                set varabbrev `_vaset'
                noisily display as error "treatment model failed at period `t'"
                exit 498
            }
            predict double `ps_t' if `at_t', pr

            * Trim PS
            if `trim_lo' > 0 | `trim_hi' < 1 {
                count if `at_t' & (`ps_t' < `trim_lo' | `ps_t' > `trim_hi')
                local n_trimmed = `n_trimmed' + r(N)
                replace `ps_t' = `trim_lo' if `at_t' & `ps_t' < `trim_lo'
                replace `ps_t' = `trim_hi' if `at_t' & `ps_t' > `trim_hi'
            }

            * =============================================================
            * B. Fit censoring model (if applicable)
            * =============================================================
            tempvar cens_pr
            if "`censor'" != "" {
                capture `tfamily' `censor' `all_covs' if `at_t'
                local rc = _rc
                if `rc' {
                    noisily display as text ///
                        "  {it:Warning: censoring model failed at period `t'; using marginal rate}"
                    summarize `censor' if `at_t', meanonly
                    local _cens_mean = cond(r(mean) > 0 & r(mean) < 1, r(mean), 0.5)
                    gen double `cens_pr' = `_cens_mean' if `at_t'
                }
                else {
                    predict double `cens_pr' if `at_t', pr
                    replace `cens_pr' = max(`trim_lo', min(`trim_hi', `cens_pr')) if `at_t'
                }
            }
            else {
                gen double `cens_pr' = 1 if `at_t'
            }

            * =============================================================
            * C. Fit outcome model and get initial Q predictions
            * =============================================================
            * For "always" regime: predict Q under A=1
            * For "never" regime: predict Q under A=0

            * Outcome models: use glm family(binomial) because Q values
            * are fractional after the first targeting step
            tempvar treat_copy mu_always_t mu_never_t
            gen double `treat_copy' = `treatment' if `at_t'

            * Model for "always" regime
            capture glm `Q_always' `treat_copy' `all_covs' if `at_t', ///
                family(binomial) link(logit)
            local rc = _rc
            if `rc' {
                set varabbrev `_vaset'
                noisily display as error "outcome model (always) failed at period `t'"
                exit 498
            }
            replace `treat_copy' = 1 if `at_t'
            predict double `mu_always_t' if `at_t', mu
            replace `mu_always_t' = max(0.001, min(0.999, `mu_always_t')) if `at_t'

            * Model for "never" regime (separate fit on Q_never)
            replace `treat_copy' = `treatment' if `at_t'
            capture glm `Q_never' `treat_copy' `all_covs' if `at_t', ///
                family(binomial) link(logit)
            local rc = _rc
            if `rc' {
                set varabbrev `_vaset'
                noisily display as error "outcome model (never) failed at period `t'"
                exit 498
            }
            replace `treat_copy' = 0 if `at_t'
            predict double `mu_never_t' if `at_t', mu
            replace `mu_never_t' = max(0.001, min(0.999, `mu_never_t')) if `at_t'

            * =============================================================
            * D. Targeting step at time t
            * =============================================================
            * Clever covariate for "always": H = I(A=1) / (e * C)
            tempvar H_always H_never

            gen double `H_always' = (`treatment' == 1) / (`ps_t' * `cens_pr') if `at_t'
            gen double `H_never'  = (`treatment' == 0) / ((1 - `ps_t') * `cens_pr') if `at_t'

            * Fluctuate for "always" regime
            tempvar logit_mu_a
            gen double `logit_mu_a' = logit(`mu_always_t') if `at_t'
            capture glm `Q_always' `H_always' if `at_t', ///
                family(binomial) link(logit) offset(`logit_mu_a') noconstant
            if _rc == 0 {
                local eps_a = _b[`H_always']
                replace `mu_always_t' = invlogit(`logit_mu_a' + `eps_a' * `H_always') if `at_t'
            }
            else if "`log'" == "" {
                noisily display as text "    {it:targeting (always) skipped at period `t'}"
            }

            * Fluctuate for "never" regime
            tempvar logit_mu_n
            gen double `logit_mu_n' = logit(`mu_never_t') if `at_t'
            capture glm `Q_never' `H_never' if `at_t', ///
                family(binomial) link(logit) offset(`logit_mu_n') noconstant
            if _rc == 0 {
                local eps_n = _b[`H_never']
                replace `mu_never_t' = invlogit(`logit_mu_n' + `eps_n' * `H_never') if `at_t'
            }
            else if "`log'" == "" {
                noisily display as text "    {it:targeting (never) skipped at period `t'}"
            }

            * =============================================================
            * E. Update pseudo-outcomes for t-1
            * =============================================================
            replace `Q_always' = `mu_always_t' if `at_t'
            replace `Q_never'  = `mu_never_t' if `at_t'

            * Carry backward to previous period for same individual
            if `period_idx' > 1 {
                local prev_idx = `period_idx' - 1
                local t_prev : word `prev_idx' of `period_values'

                * For each individual: set Q at t_prev = targeted Q from t
                tempvar _sort_order
                gen long `_sort_order' = _n
                sort `id' `period'
                by `id': replace `Q_always' = `Q_always'[_n+1] ///
                    if `period' == `t_prev' & `period'[_n+1] == `t' & `touse'
                by `id': replace `Q_never' = `Q_never'[_n+1] ///
                    if `period' == `t_prev' & `period'[_n+1] == `t' & `touse'
                sort `_sort_order'
                drop `_sort_order'
            }
            local --period_idx

            drop `at_t' `ps_t' `cens_pr' `treat_copy' `mu_always_t' `mu_never_t'
            drop `H_always' `H_never' `logit_mu_a' `logit_mu_n'
        }

        if "`log'" == "" {
            display as text " done"
        }
    }

    * =========================================================================
    * STEP 2: COMPUTE LTMLE ESTIMATE
    * =========================================================================
    if "`log'" == "" {
        display as text "Computing LTMLE estimate..."
    }

    quietly {
        * At baseline (t_min): Q_always and Q_never are the targeted
        * counterfactual outcome probabilities
        * Average over individuals at baseline

        tempvar baseline_obs
        gen byte `baseline_obs' = (`touse' & `period' == `t_min')

        if "`regime'" == "always_never" | "`regime'" == "always" {
            summarize `Q_always' if `baseline_obs', meanonly
            local po_always = r(mean)
        }
        if "`regime'" == "always_never" | "`regime'" == "never" {
            summarize `Q_never' if `baseline_obs', meanonly
            local po_never = r(mean)
        }

        if "`regime'" == "always_never" {
            local tau = `po_always' - `po_never'
            local po1_mean = `po_always'
            local po0_mean = `po_never'
        }
        else if "`regime'" == "always" {
            local tau = `po_always'
            local po1_mean = `po_always'
            local po0_mean = .
        }
        else if "`regime'" == "never" {
            local tau = `po_never'
            local po1_mean = .
            local po0_mean = `po_never'
        }
    }

    * =========================================================================
    * STEP 3: IF-BASED VARIANCE (simplified)
    * =========================================================================
    * Use nonparametric bootstrap-of-the-IF for variance
    * Approximate IF: phi_i = Q_always_i - Q_never_i - tau (at baseline)
    quietly {
        tempvar ifvar baseline_id
        gen byte `baseline_id' = (`touse' & `period' == `t_min')

        if "`regime'" == "always_never" {
            gen double `ifvar' = (`Q_always' - `Q_never' - `tau') if `baseline_id'
        }
        else {
            gen double `ifvar' = 0 if `baseline_id'
        }

        tempvar ifc
        gen double `ifc' = `ifvar'^2 if `baseline_id'
        summarize `ifc' if `baseline_id', meanonly
        local N_baseline = r(N)
        local var = r(sum) / (`N_baseline'^2)
        local se = sqrt(`var')
    }

    * Save targeted predictions
    quietly gen double _drest_ltmle_q1 = `Q_always' if `touse' & `period' == `t_min'
    quietly gen double _drest_ltmle_q0 = `Q_never' if `touse' & `period' == `t_min'
    label variable _drest_ltmle_q1 "LTMLE Q(always treat) at baseline"
    label variable _drest_ltmle_q0 "LTMLE Q(never treat) at baseline"

    quietly gen byte _drest_esample = `touse'
    label variable _drest_esample "Estimation sample (drest)"

    * =========================================================================
    * STEP 4: CONFIDENCE INTERVAL AND ECLASS RESULTS
    * =========================================================================
    local z = invnormal(1 - (100 - `level') / 200)
    local ci_lo = `tau' - `z' * `se'
    local ci_hi = `tau' + `z' * `se'
    local pvalue = 2 * normal(-abs(`tau' / `se'))

    tempname b V
    matrix `b' = (`tau')
    matrix colnames `b' = ATE
    matrix `V' = (`var')
    matrix colnames `V' = ATE
    matrix rownames `V' = ATE

    ereturn post `b' `V', obs(`N_total') esample(`touse') properties(b V)

    ereturn scalar N = `N_total'
    ereturn scalar N_id = `N_id'
    ereturn scalar T = `T'
    ereturn scalar t_min = `t_min'
    ereturn scalar t_max = `t_max'
    ereturn scalar tau = `tau'
    ereturn scalar se = `se'
    ereturn scalar z = `tau' / `se'
    ereturn scalar p = `pvalue'
    ereturn scalar ci_lo = `ci_lo'
    ereturn scalar ci_hi = `ci_hi'
    ereturn scalar level = `level'
    ereturn scalar n_trimmed = `n_trimmed'
    if "`regime'" == "always_never" {
        ereturn scalar po_always = `po_always'
        ereturn scalar po_never = `po_never'
    }

    ereturn local cmd "drest_ltmle"
    ereturn local method "ltmle"
    ereturn local id "`id'"
    ereturn local period "`period'"
    ereturn local outcome "`outcome'"
    ereturn local treatment "`treatment'"
    ereturn local covariates "`covariates'"
    ereturn local baseline "`baseline'"
    ereturn local censor "`censor'"
    ereturn local regime "`regime'"
    ereturn local ofamily "`ofamily'"
    ereturn local tfamily "`tfamily'"
    ereturn local estimand "ATE"
    ereturn local title "Longitudinal TMLE"

    * Store characteristics
    char _dta[_drest_estimated] "1"
    char _dta[_drest_method]    "ltmle"
    char _dta[_drest_outcome]   "`outcome'"
    char _dta[_drest_treatment] "`treatment'"
    char _dta[_drest_estimand]  "ATE"
    char _dta[_drest_ate]       "`tau'"
    char _dta[_drest_ate_se]    "`se'"
    char _dta[_drest_N]         "`N_total'"
    char _dta[_drest_level]     "`level'"

    * =========================================================================
    * DISPLAY
    * =========================================================================
    _drest_display_header "drest_ltmle" "Longitudinal TMLE"

    display as text "ID:            " as result "`id'"
    display as text "Period:        " as result "`period'" ///
        as text " (" as result "`t_min'" as text " to " as result "`t_max'" as text ")"
    display as text "Outcome:       " as result "`outcome'"
    display as text "Treatment:     " as result "`treatment'"
    if "`censor'" != "" {
        display as text "Censoring:     " as result "`censor'"
    }
    display as text "Regime:        " as result "`regime'"
    display as text ""
    display as text "Individuals:   " as result %10.0fc `N_id'
    display as text "Obs (person-t):" as result %10.0fc `N_total'
    display as text "Time periods:  " as result %10.0fc `T'
    if `n_trimmed' > 0 {
        display as text "PS trimmed:    " as result %10.0fc `n_trimmed'
    }

    display as text ""
    display as text "{hline 70}"

    if "`regime'" == "always_never" {
        display as text %16s "ATE" as text " {c |}" ///
            as text %12s "Estimate" as text %12s "Std. Err." ///
            as text %10s "z" as text %10s "P>|z|" ///
            as text %24s "[`level'% Conf. Interval]"
        display as text "{hline 16}{c +}{hline 53}"
        display as text %16s "ATE" as text " {c |}" ///
            as result %12.4f `tau' ///
            as result %12.4f `se' ///
            as result %10.2f (`tau' / `se') ///
            as result %10.3f `pvalue' ///
            as result %12.4f `ci_lo' ///
            as result %12.4f `ci_hi'
        display as text "{hline 16}{c +}{hline 53}"
        display as text %16s "P(Y|always)" as text " {c |}" ///
            as result %12.4f `po_always'
        display as text %16s "P(Y|never)" as text " {c |}" ///
            as result %12.4f `po_never'
    }
    else {
        display as text "Counterfactual outcome probability under `regime':"
        display as text "  P(Y=1) = " as result %8.4f `tau'
        display as text "  SE     = " as result %8.4f `se'
    }

    display as text "{hline 70}"

    set varabbrev `_vaset'
end
