*! tte_prepare Version 1.1.0  2026/03/15
*! Data preparation and variable mapping for target trial emulation
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tte_prepare, id(varname) period(varname) treatment(varname)
      outcome(varname) eligible(varname) [options]

Required:
  id(varname)         - Patient identifier
  period(varname)     - Time period variable (integer-valued)
  treatment(varname)  - Binary treatment indicator (0/1)
  outcome(varname)    - Binary outcome indicator (0/1)
  eligible(varname)   - Binary eligibility indicator (0/1)

Optional:
  censor(varname)         - Binary censoring indicator (0/1)
  covariates(varlist)     - Time-varying covariates
  baseline_covariates(varlist) - Baseline-only covariates
  estimand(string)        - ITT | PP | AT (default: PP)
  generate(string)        - Variable prefix (default: _tte_)

See help tte_prepare for complete documentation
*/

program define tte_prepare, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax , ID(varname) PERiod(varname numeric) ///
        TREATment(varname numeric) OUTcome(varname numeric) ///
        ELIGible(varname numeric) ///
        [CENsor(varname numeric) ///
         COVariates(varlist numeric) ///
         BASEline_covariates(varlist numeric) ///
         ESTIMand(string) GENerate(string)]

    * =========================================================================
    * DEFAULTS
    * =========================================================================

    if "`estimand'" == "" local estimand "PP"
    if "`generate'" == "" local generate "_tte_"

    * Validate estimand
    local estimand = upper("`estimand'")
    if !inlist("`estimand'", "ITT", "PP", "AT") {
        display as error "estimand() must be ITT, PP, or AT"
        exit 198
    }

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
    foreach var in `treatment' `outcome' `eligible' {
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
    quietly count if `eligible' == 1
    local n_eligible = r(N)

    quietly count if `outcome' == 1
    local n_events = r(N)

    local n_censored = 0
    if "`censor'" != "" {
        quietly count if `censor' == 1
        local n_censored = r(N)
    }

    quietly count if `treatment' == 1
    local n_treated = r(N)

    * =========================================================================
    * STORE METADATA IN DATASET CHARACTERISTICS
    * =========================================================================

    char _dta[_tte_prepared] "1"
    char _dta[_tte_id] "`id'"
    char _dta[_tte_period] "`period'"
    char _dta[_tte_treatment] "`treatment'"
    char _dta[_tte_outcome] "`outcome'"
    char _dta[_tte_eligible] "`eligible'"
    char _dta[_tte_censor] "`censor'"
    char _dta[_tte_covariates] "`covariates'"
    char _dta[_tte_bl_covariates] "`baseline_covariates'"
    char _dta[_tte_estimand] "`estimand'"
    char _dta[_tte_prefix] "`generate'"

    * Clear any expansion/weight/fit flags from prior runs
    char _dta[_tte_expanded]
    char _dta[_tte_weighted]
    char _dta[_tte_fitted]
    char _dta[_tte_weight_var]
    char _dta[_tte_pscore_var]

    * =========================================================================
    * DISPLAY
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as result "tte_prepare" as text " - Data Preparation"
    display as text "{hline 70}"
    display as text ""
    display as text "Variable mapping:"
    display as text "  ID:          " as result "`id'"
    display as text "  Period:      " as result "`period'" as text " (range: `min_period' to `max_period')"
    display as text "  Treatment:   " as result "`treatment'"
    display as text "  Outcome:     " as result "`outcome'"
    display as text "  Eligible:    " as result "`eligible'"
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
    display as text "Estimand:      " as result "`estimand'"
    display as text ""
    display as text "Data summary:"
    display as text "  Observations:     " as result %10.0fc `N'
    display as text "  Individuals:      " as result %10.0fc `n_ids'
    display as text "  Period range:     " as result "`min_period' - `max_period'"
    display as text "  Eligible obs:     " as result %10.0fc `n_eligible'
    display as text "  Treated obs:      " as result %10.0fc `n_treated'
    display as text "  Outcome events:   " as result %10.0fc `n_events'
    if "`censor'" != "" {
        display as text "  Censored obs:     " as result %10.0fc `n_censored'
    }
    display as text ""
    display as text "Metadata stored. Next step: {cmd:tte_validate} or {cmd:tte_expand}"
    display as text "{hline 70}"

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return scalar N = `N'
    return scalar n_ids = `n_ids'
    return scalar n_periods = `n_periods'
    return scalar n_eligible = `n_eligible'
    return scalar n_events = `n_events'
    return scalar n_censored = `n_censored'
    return scalar n_treated = `n_treated'

    return local estimand "`estimand'"
    return local id "`id'"
    return local period "`period'"
    return local treatment "`treatment'"
    return local outcome "`outcome'"
    return local eligible "`eligible'"
    return local censor "`censor'"
    return local covariates "`covariates'"
    return local baseline_covariates "`baseline_covariates'"
    return local prefix "`generate'"

    set varabbrev `_vaset'
end
