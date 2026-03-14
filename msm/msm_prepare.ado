*! msm_prepare Version 1.0.1  2026/03/14
*! Data preparation and variable mapping for marginal structural models
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  msm_prepare, id(varname) period(varname) treatment(varname)
      outcome(varname) [options]

Required:
  id(varname)         - Individual identifier
  period(varname)     - Time period variable (integer-valued)
  treatment(varname)  - Binary treatment indicator (0/1)
  outcome(varname)    - Binary outcome indicator (0/1)

Optional:
  censor(varname)            - Binary censoring indicator (0/1)
  covariates(varlist)        - Time-varying covariates
  baseline_covariates(varlist) - Baseline-only covariates
  generate(string)           - Variable prefix (default: _msm_)

See help msm_prepare for complete documentation
*/

program define msm_prepare, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    set varabbrev off
    set more off

    capture noisily {

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax , ID(varname) PERiod(varname numeric) ///
        TREATment(varname numeric) OUTcome(varname numeric) ///
        [CENsor(varname numeric) ///
         COVariates(varlist numeric) ///
         BASEline_covariates(varlist numeric) ///
         GENerate(string)]

    * =========================================================================
    * DEFAULTS
    * =========================================================================

    if "`generate'" == "" local generate "_msm_"

    * =========================================================================
    * VARIABLE VALIDATION
    * =========================================================================

    * Check period is integer-valued
    tempvar _frac
    gen double `_frac' = `period' - floor(`period')
    quietly summarize `_frac'
    if r(max) > 0 {
        display as error "period variable `period' must be integer-valued"
        drop `_frac'
        exit 198
    }
    drop `_frac'

    * Check binary variables are 0/1
    foreach var in `treatment' `outcome' {
        quietly summarize `var'
        if r(min) < 0 | r(max) > 1 {
            display as error "`var' must be binary (0/1)"
            exit 198
        }
        quietly count if !inlist(`var', 0, 1) & !missing(`var')
        if r(N) > 0 {
            display as error "`var' must be binary (0/1); found non-integer values"
            exit 198
        }
    }

    if "`censor'" != "" {
        quietly summarize `censor'
        if r(min) < 0 | r(max) > 1 {
            display as error "`censor' must be binary (0/1)"
            exit 198
        }
        quietly count if !inlist(`censor', 0, 1) & !missing(`censor')
        if r(N) > 0 {
            display as error "`censor' must be binary (0/1); found non-integer values"
            exit 198
        }
    }

    * =========================================================================
    * DATA STRUCTURE VALIDATION
    * =========================================================================

    * Check for observations
    quietly count
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    * Check person-period: one row per (id, period)
    tempvar _dup
    quietly bysort `id' `period': gen byte `_dup' = _N
    quietly count if `_dup' > 1
    if r(N) > 0 {
        local n_dups = r(N)
        display as error "data is not in person-period format: `n_dups' duplicate (id, period) combinations"
        drop `_dup'
        exit 198
    }
    drop `_dup'

    * Count unique individuals
    tempvar _tag
    quietly bysort `id': gen byte `_tag' = (_n == 1)
    quietly count if `_tag'
    local n_ids = r(N)
    drop `_tag'

    * Period range
    quietly summarize `period'
    local min_period = r(min)
    local max_period = r(max)
    local n_periods = `max_period' - `min_period' + 1

    * Count key quantities
    quietly count if `outcome' == 1
    local n_events = r(N)

    quietly count if `treatment' == 1
    local n_treated = r(N)

    local n_censored = 0
    if "`censor'" != "" {
        quietly count if `censor' == 1
        local n_censored = r(N)
    }

    * =========================================================================
    * STORE METADATA IN DATASET CHARACTERISTICS
    * =========================================================================

    char _dta[_msm_prepared] "1"
    char _dta[_msm_id] "`id'"
    char _dta[_msm_period] "`period'"
    char _dta[_msm_treatment] "`treatment'"
    char _dta[_msm_outcome] "`outcome'"
    char _dta[_msm_censor] "`censor'"
    char _dta[_msm_covariates] "`covariates'"
    char _dta[_msm_bl_covariates] "`baseline_covariates'"
    char _dta[_msm_prefix] "`generate'"

    * Clear all downstream artifacts from prior runs
    char _dta[_msm_weighted]
    char _dta[_msm_fitted]
    char _dta[_msm_model]
    char _dta[_msm_period_spec]
    char _dta[_msm_outcome_cov]
    char _dta[_msm_per_ns_knots]
    char _dta[_msm_per_ns_df]
    char _dta[_msm_cluster]
    char _dta[_msm_time_vars]
    char _dta[_msm_fit_level]
    char _dta[_msm_weight_var]
    char _dta[_msm_pred_saved]
    char _dta[_msm_pred_type]
    char _dta[_msm_pred_strategy]
    char _dta[_msm_pred_level]
    char _dta[_msm_bal_saved]
    char _dta[_msm_bal_threshold]
    char _dta[_msm_diag_saved]
    char _dta[_msm_diag_mean]
    char _dta[_msm_diag_sd]
    char _dta[_msm_diag_min]
    char _dta[_msm_diag_max]
    char _dta[_msm_diag_p1]
    char _dta[_msm_diag_p50]
    char _dta[_msm_diag_p99]
    char _dta[_msm_diag_ess]
    char _dta[_msm_diag_ess_pct]
    char _dta[_msm_sens_saved]
    char _dta[_msm_sens_effect]
    char _dta[_msm_sens_effect_lo]
    char _dta[_msm_sens_effect_hi]
    char _dta[_msm_sens_effect_label]
    char _dta[_msm_sens_model]
    char _dta[_msm_sens_evalue_point]
    char _dta[_msm_sens_evalue_ci]
    char _dta[_msm_sens_level]
    capture matrix drop _msm_fit_b
    capture matrix drop _msm_fit_V
    capture matrix drop _msm_pred_matrix
    capture matrix drop _msm_bal_matrix

    * =========================================================================
    * DISPLAY
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as result "msm_prepare" as text " - Data Preparation"
    display as text "{hline 70}"
    display as text ""
    display as text "Variable mapping:"
    display as text "  ID:          " as result "`id'"
    display as text "  Period:      " as result "`period'" as text " (range: `min_period' to `max_period')"
    display as text "  Treatment:   " as result "`treatment'"
    display as text "  Outcome:     " as result "`outcome'"
    if "`censor'" != "" {
        display as text "  Censoring:   " as result "`censor'"
    }
    if "`covariates'" != "" {
        display as text "  Covariates:  " as result "`covariates'"
    }
    if "`baseline_covariates'" != "" {
        display as text "  Baseline:    " as result "`baseline_covariates'"
    }
    display as text ""
    display as text "Data summary:"
    display as text "  Observations:     " as result %10.0fc `N'
    display as text "  Individuals:      " as result %10.0fc `n_ids'
    display as text "  Period range:     " as result "`min_period' - `max_period'"
    display as text "  Treated obs:      " as result %10.0fc `n_treated'
    display as text "  Outcome events:   " as result %10.0fc `n_events'
    if "`censor'" != "" {
        display as text "  Censored obs:     " as result %10.0fc `n_censored'
    }
    display as text ""
    display as text "Metadata stored. Next step: {cmd:msm_validate} or {cmd:msm_weight}"
    display as text "{hline 70}"

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return scalar N = `N'
    return scalar n_ids = `n_ids'
    return scalar n_periods = `n_periods'
    return scalar n_events = `n_events'
    return scalar n_treated = `n_treated'
    return scalar n_censored = `n_censored'

    return local id "`id'"
    return local period "`period'"
    return local treatment "`treatment'"
    return local outcome "`outcome'"
    return local censor "`censor'"
    return local covariates "`covariates'"
    return local baseline_covariates "`baseline_covariates'"
    return local prefix "`generate'"

    } /* end capture noisily */
    local _rc = _rc

    set varabbrev `_varabbrev'
    set more `_more'

    if `_rc' exit `_rc'
end
