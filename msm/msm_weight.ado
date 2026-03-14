*! msm_weight Version 1.0.1  2026/03/14
*! Inverse probability of treatment weights for marginal structural models
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  msm_weight, treat_d_cov(varlist) [options]

Description:
  Calculates stabilized inverse probability of treatment weights (IPTW)
  and optionally inverse probability of censoring weights (IPCW) for
  marginal structural model estimation.

  For each person-period, fits logistic models for treatment:
    Denominator: P(A_t | A_{t-1}, L_t, V)  (full history + confounders)
    Numerator:   P(A_t | A_{t-1}, V)        (baseline only, for stability)

  Period-specific weight ratios are accumulated via cumulative product
  within individuals using log-sum for numerical stability.

Options:
  treat_d_cov(varlist)   - Covariates for treatment denominator model (required)
  treat_n_cov(varlist)   - Covariates for treatment numerator model (stabilized)
  censor_d_cov(varlist)  - Covariates for censoring denominator model
  censor_n_cov(varlist)  - Covariates for censoring numerator model
  truncate(# #)          - Truncate at percentiles (e.g., truncate(1 99))
  replace                - Replace existing weight variables
  nolog                  - Suppress model iteration log

See help msm_weight for complete documentation
*/

program define msm_weight, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    set varabbrev off
    set more off

    capture noisily {

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax , TREAT_d_cov(varlist numeric) ///
        [TREAT_n_cov(varlist numeric) ///
         CENsor_d_cov(varlist numeric) CENsor_n_cov(varlist numeric) ///
         TRUNCate(numlist min=2 max=2) ///
         REPLACE noLOG]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================

    _msm_check_prepared
    _msm_get_settings

    local id         "`_msm_id'"
    local period     "`_msm_period'"
    local treatment  "`_msm_treatment'"
    local outcome    "`_msm_outcome'"
    local censor     "`_msm_censor'"

    * =========================================================================
    * VALIDATE OPTIONS
    * =========================================================================

    * Validate truncation
    if "`truncate'" != "" {
        local trunc_lo: word 1 of `truncate'
        local trunc_hi: word 2 of `truncate'
        if `trunc_lo' >= `trunc_hi' {
            display as error "truncate() lower bound must be less than upper bound"
            exit 198
        }
    }

    * Check weight variables
    foreach wvar in _msm_weight _msm_tw_weight _msm_cw_weight {
        capture confirm variable `wvar'
        if _rc == 0 {
            if "`replace'" == "" {
                display as error "variable `wvar' already exists; use replace option"
                exit 110
            }
            quietly drop `wvar'
        }
    }

    * IPCW requested but no censor variable?
    if "`censor_d_cov'" != "" & "`censor'" == "" {
        display as error "censor_d_cov() specified but no censoring variable was mapped in msm_prepare"
        display as error "Re-run {bf:msm_prepare} with the {bf:censor()} option."
        exit 198
    }

    * censor_n_cov without censor_d_cov is a misspecification
    if "`censor_n_cov'" != "" & "`censor_d_cov'" == "" {
        display as error "censor_n_cov() requires censor_d_cov()"
        display as error "The censoring numerator model only applies when a denominator model is also specified."
        exit 198
    }

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as result "msm_weight" as text " - Inverse Probability Weights"
    display as text "{hline 70}"
    display as text ""
    display as text "Treatment denom:  " as result "`treat_d_cov'"
    if "`treat_n_cov'" != "" {
        display as text "Treatment numer:  " as result "`treat_n_cov'"
    }
    else {
        display as text "Treatment numer:  " as result "(intercept + lagged treatment only)"
    }
    if "`censor_d_cov'" != "" {
        display as text "Censoring denom:  " as result "`censor_d_cov'"
        if "`censor_n_cov'" != "" {
            display as text "Censoring numer:  " as result "`censor_n_cov'"
        }
    }
    display as text "Stabilized:       " as result "Yes"
    if "`truncate'" != "" {
        display as text "Truncation:       " as result "`trunc_lo'th - `trunc_hi'th percentile"
    }
    display as text ""

    local log_opt ""
    if "`log'" == "nolog" local log_opt "nolog"

    * =========================================================================
    * TREATMENT WEIGHTS (IPTW)
    * =========================================================================

    display as text "Fitting treatment models..."

    _msm_weight_treatment, id(`id') period(`period') ///
        treatment(`treatment') outcome(`outcome') ///
        censor(`censor') ///
        d_cov(`treat_d_cov') n_cov(`treat_n_cov') `log_opt'

    * _msm_tw_weight now exists (cumulative treatment weight)

    * =========================================================================
    * CENSORING WEIGHTS (IPCW) - optional
    * =========================================================================

    if "`censor_d_cov'" != "" & "`censor'" != "" {
        display as text ""
        display as text "Fitting censoring models..."

        _msm_weight_censor, id(`id') period(`period') ///
            treatment(`treatment') censor(`censor') ///
            outcome(`outcome') ///
            d_cov(`censor_d_cov') n_cov(`censor_n_cov') `log_opt'

        * _msm_cw_weight now exists (cumulative censoring weight)
    }

    * =========================================================================
    * COMBINE WEIGHTS
    * =========================================================================

    quietly {
        * Combined weight = treatment weight * censoring weight
        capture confirm variable _msm_cw_weight
        if _rc == 0 {
            gen double _msm_weight = _msm_tw_weight * _msm_cw_weight
        }
        else {
            gen double _msm_weight = _msm_tw_weight
        }
    }

    * =========================================================================
    * TRUNCATION
    * =========================================================================

    local n_truncated = 0
    if "`truncate'" != "" {
        display as text ""
        display as text "Truncating weights at `trunc_lo'th and `trunc_hi'th percentiles..."

        quietly {
            _pctile _msm_weight if !missing(_msm_weight), ///
                percentiles(`trunc_lo' `trunc_hi')
            local lo_val = r(r1)
            local hi_val = r(r2)

            count if _msm_weight < `lo_val' & !missing(_msm_weight)
            local n_lo = r(N)
            count if _msm_weight > `hi_val' & !missing(_msm_weight)
            local n_hi = r(N)
            local n_truncated = `n_lo' + `n_hi'

            replace _msm_weight = `lo_val' if _msm_weight < `lo_val' & !missing(_msm_weight)
            replace _msm_weight = `hi_val' if _msm_weight > `hi_val' & !missing(_msm_weight)
        }

        display as text "  Truncated `n_truncated' observations (`n_lo' low, `n_hi' high)"
    }

    * =========================================================================
    * DIAGNOSTICS
    * =========================================================================

    quietly summarize _msm_weight, detail
    local w_mean = r(mean)
    local w_sd   = r(sd)
    local w_min  = r(min)
    local w_max  = r(max)
    local w_p1   = r(p1)
    local w_p50  = r(p50)
    local w_p99  = r(p99)

    * Effective sample size: (sum w)^2 / (sum w^2)
    quietly {
        summarize _msm_weight
        local sum_w = r(sum)
        tempvar _w2
        gen double `_w2' = _msm_weight^2
        summarize `_w2'
        local sum_w2 = r(sum)
        drop `_w2'
    }
    local ess = (`sum_w'^2) / `sum_w2'

    label variable _msm_weight "MSM cumulative IP weight"
    label variable _msm_tw_weight "MSM treatment weight (cumulative)"
    capture label variable _msm_cw_weight "MSM censoring weight (cumulative)"

    * Store metadata
    char _dta[_msm_weighted] "1"
    char _dta[_msm_weight_var] "_msm_weight"

    * =========================================================================
    * DISPLAY RESULTS
    * =========================================================================

    display as text ""
    display as text "Weight distribution:"
    display as text "  Mean:     " as result %9.4f `w_mean'
    display as text "  SD:       " as result %9.4f `w_sd'
    display as text "  Min:      " as result %9.4f `w_min'
    display as text "  Median:   " as result %9.4f `w_p50'
    display as text "  Max:      " as result %9.4f `w_max'
    display as text "  P1:       " as result %9.4f `w_p1'
    display as text "  P99:      " as result %9.4f `w_p99'
    display as text ""
    display as text "Effective sample size: " as result %9.1f `ess' ///
        as text " (of " as result _N as text ")"

    * Check mean ~1 for stabilized weights
    if abs(`w_mean' - 1) > 0.1 {
        display as text ""
        display as text "Note: stabilized weight mean is " as result %5.3f `w_mean'
        display as text "  Expected ~1.0 for correctly specified models."
        display as text "  Check treatment model specification."
    }

    display as text ""
    display as text "Variables created: " as result "_msm_weight _msm_tw_weight" ///
        cond("`censor_d_cov'" != "", " _msm_cw_weight", "")
    display as text "Next step: {cmd:msm_diagnose} or {cmd:msm_fit}"
    display as text "{hline 70}"

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return scalar mean_weight = `w_mean'
    return scalar sd_weight = `w_sd'
    return scalar min_weight = `w_min'
    return scalar max_weight = `w_max'
    return scalar p1_weight = `w_p1'
    return scalar median_weight = `w_p50'
    return scalar p99_weight = `w_p99'
    return scalar ess = `ess'
    return scalar n_truncated = `n_truncated'

    return local weight_var "_msm_weight"

    } /* end capture noisily */
    local _rc = _rc

    set varabbrev `_varabbrev'
    set more `_more'

    if `_rc' exit `_rc'
end

* =========================================================================
* _msm_weight_treatment: Fit treatment weight models and compute
*   cumulative stabilized IPTW
* =========================================================================
program define _msm_weight_treatment
    version 16.0
    set varabbrev off
    set more off

    syntax , id(varname) period(varname) ///
        treatment(varname) outcome(varname) ///
        [censor(varname)] ///
        d_cov(varlist) [n_cov(varlist) nolog]

    local log_opt ""
    if "`nolog'" != "" local log_opt "nolog"

    * Probability truncation bounds for numerical stability
    local _pr_lo = 0.001
    local _pr_hi = 0.999

    quietly {
        * Create analysis sample marker: not yet had outcome or been censored
        * At each period t, we model treatment among those still at risk
        tempvar _at_risk _lag_treat

        * Cumulative prior outcome (excluding current period)
        tempvar _cum_out
        bysort `id' (`period'): gen byte `_cum_out' = sum(`outcome'[_n-1]) if _n > 1
        replace `_cum_out' = 0 if missing(`_cum_out')

        * Cumulative prior censoring
        if "`censor'" != "" {
            tempvar _cum_cens
            bysort `id' (`period'): gen byte `_cum_cens' = sum(`censor'[_n-1]) if _n > 1
            replace `_cum_cens' = 0 if missing(`_cum_cens')
            gen byte `_at_risk' = (`_cum_out' == 0 & `_cum_cens' == 0)
            drop `_cum_cens'
        }
        else {
            gen byte `_at_risk' = (`_cum_out' == 0)
        }
        drop `_cum_out'

        * Lagged treatment
        bysort `id' (`period'): gen byte `_lag_treat' = `treatment'[_n-1]
        * First period has no lag - handle separately

        * ---------------------------------------------------------------
        * DENOMINATOR MODEL: P(A_t | A_{t-1}, L_t, V)
        * Full model with all time-varying and baseline covariates
        * ---------------------------------------------------------------
        tempvar _denom_pr

        noisily display as text "  Denominator model: `treatment' ~ `lag_treat' `d_cov' `period'"
        capture logit `treatment' `_lag_treat' `d_cov' `period' ///
            if `_at_risk' & !missing(`_lag_treat'), `log_opt'
        if _rc != 0 {
            noisily display as text "  Warning: denominator model failed; using marginal probability"
            * Fallback: marginal probability
            summarize `treatment' if `_at_risk' & !missing(`_lag_treat')
            gen double `_denom_pr' = r(mean) if `_at_risk' & !missing(`_lag_treat')
        }
        else {
            predict double `_denom_pr' if `_at_risk' & !missing(`_lag_treat'), pr
        }

        * For first period (no lag), use a separate simpler model
        tempvar _denom_pr0
        capture logit `treatment' `d_cov' if `_at_risk' & missing(`_lag_treat'), `log_opt'
        if _rc != 0 {
            summarize `treatment' if `_at_risk' & missing(`_lag_treat')
            gen double `_denom_pr0' = r(mean) if `_at_risk' & missing(`_lag_treat')
        }
        else {
            predict double `_denom_pr0' if `_at_risk' & missing(`_lag_treat'), pr
        }
        replace `_denom_pr' = `_denom_pr0' if missing(`_denom_pr') & `_at_risk' & missing(`_lag_treat')
        drop `_denom_pr0'

        * ---------------------------------------------------------------
        * NUMERATOR MODEL: P(A_t | A_{t-1}, V)
        * Baseline-only model (or simpler model) for stabilization
        * ---------------------------------------------------------------
        tempvar _numer_pr

        if "`n_cov'" != "" {
            noisily display as text "  Numerator model:   `treatment' ~ `lag_treat' `n_cov'"
            capture logit `treatment' `_lag_treat' `n_cov' ///
                if `_at_risk' & !missing(`_lag_treat'), `log_opt'
        }
        else {
            noisily display as text "  Numerator model:   `treatment' ~ `lag_treat'"
            capture logit `treatment' `_lag_treat' ///
                if `_at_risk' & !missing(`_lag_treat'), `log_opt'
        }
        if _rc != 0 {
            summarize `treatment' if `_at_risk' & !missing(`_lag_treat')
            gen double `_numer_pr' = r(mean) if `_at_risk' & !missing(`_lag_treat')
        }
        else {
            predict double `_numer_pr' if `_at_risk' & !missing(`_lag_treat'), pr
        }

        * First period numerator
        tempvar _numer_pr0
        if "`n_cov'" != "" {
            capture logit `treatment' `n_cov' if `_at_risk' & missing(`_lag_treat'), `log_opt'
        }
        else {
            capture logit `treatment' if `_at_risk' & missing(`_lag_treat'), `log_opt'
        }
        if _rc != 0 {
            summarize `treatment' if `_at_risk' & missing(`_lag_treat')
            gen double `_numer_pr0' = r(mean) if `_at_risk' & missing(`_lag_treat')
        }
        else {
            predict double `_numer_pr0' if `_at_risk' & missing(`_lag_treat'), pr
        }
        replace `_numer_pr' = `_numer_pr0' if missing(`_numer_pr') & `_at_risk' & missing(`_lag_treat')
        drop `_numer_pr0'

        * ---------------------------------------------------------------
        * COMPUTE PERIOD-SPECIFIC WEIGHT RATIOS
        * ---------------------------------------------------------------
        tempvar _tw_t

        * Truncate extreme probabilities to avoid division by zero
        * and ensure all at-risk observations get proper weights
        count if (`_denom_pr' < `_pr_lo' | `_denom_pr' > `_pr_hi') & `_at_risk' & !missing(`_denom_pr')
        local _n_extreme_d = r(N)
        replace `_denom_pr' = max(`_denom_pr', `_pr_lo') if `_at_risk' & !missing(`_denom_pr')
        replace `_denom_pr' = min(`_denom_pr', `_pr_hi') if `_at_risk' & !missing(`_denom_pr')
        replace `_numer_pr' = max(`_numer_pr', `_pr_lo') if `_at_risk' & !missing(`_numer_pr')
        replace `_numer_pr' = min(`_numer_pr', `_pr_hi') if `_at_risk' & !missing(`_numer_pr')

        if `_n_extreme_d' > 0 {
            noisily display as text "  Warning: " as result `_n_extreme_d' as text ///
                " obs with near-deterministic treatment probability (truncated)"
        }

        * w_t = numer / denom if treated, (1-numer)/(1-denom) if untreated
        gen double `_tw_t' = 1

        * Treated observations
        replace `_tw_t' = `_numer_pr' / `_denom_pr' ///
            if `treatment' == 1 & `_at_risk' & !missing(`_denom_pr')

        * Untreated observations
        replace `_tw_t' = (1 - `_numer_pr') / (1 - `_denom_pr') ///
            if `treatment' == 0 & `_at_risk' & !missing(`_denom_pr')

        * ---------------------------------------------------------------
        * CUMULATIVE PRODUCT VIA LOG-SUM
        * ---------------------------------------------------------------
        tempvar _log_tw _cum_log_tw

        gen double `_log_tw' = ln(`_tw_t') if `_at_risk' & !missing(`_tw_t') & `_tw_t' > 0
        * Set weight = 1 (log = 0) for non-at-risk observations
        replace `_log_tw' = 0 if !`_at_risk' | missing(`_log_tw')

        bysort `id' (`period'): gen double `_cum_log_tw' = sum(`_log_tw')

        gen double _msm_tw_weight = exp(`_cum_log_tw')

        * Clean up
        drop `_at_risk' `_lag_treat' `_denom_pr' `_numer_pr' `_tw_t' `_log_tw' `_cum_log_tw'
    }
end

* =========================================================================
* _msm_weight_censor: Fit censoring weight models and compute
*   cumulative stabilized IPCW
* =========================================================================
program define _msm_weight_censor
    version 16.0
    set varabbrev off
    set more off

    syntax , id(varname) period(varname) ///
        treatment(varname) censor(varname) outcome(varname) ///
        d_cov(varlist) [n_cov(varlist) nolog]

    local log_opt ""
    if "`nolog'" != "" local log_opt "nolog"

    * Probability truncation bounds for numerical stability
    local _pr_lo = 0.001
    local _pr_hi = 0.999

    quietly {
        * At-risk: not yet had outcome or been censored (prior periods)
        tempvar _cum_out _cum_cens _at_risk
        bysort `id' (`period'): gen byte `_cum_out' = sum(`outcome'[_n-1]) if _n > 1
        replace `_cum_out' = 0 if missing(`_cum_out')
        bysort `id' (`period'): gen byte `_cum_cens' = sum(`censor'[_n-1]) if _n > 1
        replace `_cum_cens' = 0 if missing(`_cum_cens')
        gen byte `_at_risk' = (`_cum_out' == 0 & `_cum_cens' == 0)
        drop `_cum_out' `_cum_cens'

        * ---------------------------------------------------------------
        * DENOMINATOR MODEL: P(C_t = 0 | L_t, A_t)
        * We model P(uncensored) so weight = P_num(uncens) / P_den(uncens)
        * ---------------------------------------------------------------
        tempvar _denom_pr

        noisily display as text "  Denominator model: `censor' ~ `treatment' `d_cov' `period'"
        capture logit `censor' `treatment' `d_cov' `period' ///
            if `_at_risk' & `outcome' == 0, `log_opt'
        if _rc != 0 {
            noisily display as text "  Warning: censoring denominator model failed; using marginal"
            summarize `censor' if `_at_risk' & `outcome' == 0
            gen double `_denom_pr' = r(mean) if `_at_risk' & `outcome' == 0
        }
        else {
            predict double `_denom_pr' if `_at_risk' & `outcome' == 0, pr
        }

        * ---------------------------------------------------------------
        * NUMERATOR MODEL: P(C_t = 0 | A_t) or simpler
        * ---------------------------------------------------------------
        tempvar _numer_pr

        if "`n_cov'" != "" {
            noisily display as text "  Numerator model:   `censor' ~ `treatment' `n_cov'"
            capture logit `censor' `treatment' `n_cov' ///
                if `_at_risk' & `outcome' == 0, `log_opt'
        }
        else {
            noisily display as text "  Numerator model:   `censor' ~ `treatment'"
            capture logit `censor' `treatment' ///
                if `_at_risk' & `outcome' == 0, `log_opt'
        }
        if _rc != 0 {
            summarize `censor' if `_at_risk' & `outcome' == 0
            gen double `_numer_pr' = r(mean) if `_at_risk' & `outcome' == 0
        }
        else {
            predict double `_numer_pr' if `_at_risk' & `outcome' == 0, pr
        }

        * ---------------------------------------------------------------
        * WEIGHT: P(uncensored|num) / P(uncensored|den)
        *       = (1 - P_num(cens)) / (1 - P_den(cens))
        * ---------------------------------------------------------------
        tempvar _cw_t

        * Truncate extreme censoring probabilities
        replace `_denom_pr' = max(`_denom_pr', `_pr_lo') if `_at_risk' & `outcome' == 0 & !missing(`_denom_pr')
        replace `_denom_pr' = min(`_denom_pr', `_pr_hi') if `_at_risk' & `outcome' == 0 & !missing(`_denom_pr')
        replace `_numer_pr' = max(`_numer_pr', `_pr_lo') if `_at_risk' & `outcome' == 0 & !missing(`_numer_pr')
        replace `_numer_pr' = min(`_numer_pr', `_pr_hi') if `_at_risk' & `outcome' == 0 & !missing(`_numer_pr')

        gen double `_cw_t' = 1
        replace `_cw_t' = (1 - `_numer_pr') / (1 - `_denom_pr') ///
            if `_at_risk' & `outcome' == 0 & !missing(`_denom_pr')

        * Cumulative product
        tempvar _log_cw _cum_log_cw
        gen double `_log_cw' = ln(`_cw_t') if !missing(`_cw_t') & `_cw_t' > 0
        replace `_log_cw' = 0 if missing(`_log_cw')

        bysort `id' (`period'): gen double `_cum_log_cw' = sum(`_log_cw')
        gen double _msm_cw_weight = exp(`_cum_log_cw')

        drop `_at_risk' `_denom_pr' `_numer_pr' `_cw_t' `_log_cw' `_cum_log_cw'
    }
end
