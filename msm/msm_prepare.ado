*! msm_prepare Version 1.2.2  2026/07/02
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
See help msm_prepare for complete documentation
*/

program define msm_prepare, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    local _prep_preserved = 0
    set varabbrev off
    set more off

    tempvar _msm_orig_order

    capture noisily {

    quietly gen long `_msm_orig_order' = _n

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax , ID(varname) PERiod(varname numeric) ///
        TREATment(varname numeric) OUTcome(varname numeric) ///
        [CENsor(varname numeric) ///
         COVariates(varlist numeric) ///
         BASEline_covariates(varlist numeric)]

    * =========================================================================
    * STRUCTURAL ROLE VALIDATION (audit A07)
    * =========================================================================

    * No variable may fill two structural roles, and no covariate may be a
    * structural variable. Overlapping roles leak the outcome into a model or
    * fit a causally meaningless specification that still returns rc 0.
    _msm_role_check, id(`id') period(`period') treatment(`treatment') ///
        outcome(`outcome') censor(`censor') ///
        predictors(`covariates' `baseline_covariates')

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

    * -------------------------------------------------------------------------
    * Missing structural keys (audit A08)
    *
    * A missing id or period has no safe interpretation: bysort groups every
    * missing id into a single spurious panel, and a missing period cannot be
    * ordered within a history. Hard-error rather than silently mis-group.
    * -------------------------------------------------------------------------
    quietly count if missing(`id')
    if r(N) > 0 {
        display as error "`id' (id) has " as result r(N) as error ///
            " missing value(s); id must be nonmissing"
        exit 198
    }
    quietly count if missing(`period')
    if r(N) > 0 {
        display as error "`period' (period) has " as result r(N) as error ///
            " missing value(s); period must be nonmissing"
        exit 198
    }

    * -------------------------------------------------------------------------
    * Event/censor ties (audit A08)
    *
    * An observation that is both an event (outcome==1) and censored
    * (censor==1) in the same period has no defined precedence: msm_fit keeps
    * only censor==0 rows, so a tied event would be silently dropped and its
    * event lost. Reject the tie and require the user to declare precedence by
    * editing the data.
    * -------------------------------------------------------------------------
    if "`censor'" != "" {
        quietly count if `outcome' == 1 & `censor' == 1
        if r(N) > 0 {
            display as error as result r(N) as error ///
                " observation(s) have outcome==1 and `censor'==1 in the same period."
            display as error ///
                "Event/censor ties have no safe precedence: resolve the tie in the data " ///
                "(an event at period t implies the subject was uncensored through t)."
            exit 198
        }
    }

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
    local period_span = `max_period' - `min_period' + 1

    * -------------------------------------------------------------------------
    * Distinct period count (audit A34)
    *
    * r(n_periods) is documented as the number of distinct periods, not the
    * span. With gaps these differ; report both. period_span is retained for
    * preparation diagnostics.
    * -------------------------------------------------------------------------
    * A within-id period gap corrupts the cumulative weight (audit A09) and is a
    * hard error in msm_weight; msm_validate reports it as a diagnostic. It is
    * not rejected here so that preparation and validation can still describe
    * gapped data. n_periods therefore counts distinct present values, which may
    * be fewer than the span.
    tempvar _ptag
    quietly bysort `period': gen byte `_ptag' = (_n == 1)
    quietly count if `_ptag'
    local n_periods = r(N)
    drop `_ptag'

    * Baseline covariates must be constant within individual
    if "`baseline_covariates'" != "" {
        _msm_timefixed `baseline_covariates', id(`id')
        if "`r(varying)'" != "" {
            display as error ///
                "baseline_covariates() variable(s) vary within `id': `r(varying)'"
            exit 198
        }
    }

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

    * Every validation above has passed, so the new preparation state may be
    * committed. Nothing before this point writes state: a failed msm_prepare
    * must leave the previous preparation exactly as it was.
    preserve
    local _prep_preserved = 1

    _msm_uuid
    local _prep_uuid "`r(uuid)'"

    char _dta[_msm_prepared] "1"
    char _dta[_msm_id] "`id'"
    char _dta[_msm_period] "`period'"
    char _dta[_msm_treatment] "`treatment'"
    char _dta[_msm_outcome] "`outcome'"
    char _dta[_msm_censor] "`censor'"
    char _dta[_msm_covariates] "`covariates'"
    char _dta[_msm_bl_covariates] "`baseline_covariates'"
    char _dta[_msm_prefix] "_msm_"
    char _dta[_msm_prep_uuid] "`_prep_uuid'"

    * Re-preparing invalidates every later stage: the mapping they were built
    * on has just been replaced. Only package-created variables are removed;
    * a user variable that happens to share a reserved name is left alone.
    _msm_invalidate, from(prepare)

    * Record what the preparation consumed, so a later stage can prove the data
    * are still the data that produced it rather than merely that the variable
    * names still exist.
    local _sigvars "`id' `period' `treatment' `outcome' `censor' `covariates' `baseline_covariates'"
    local _sigvars : list retokenize _sigvars
    _msm_signature `_sigvars'
    char _dta[_msm_prep_sig] "`r(sig)'"
    char _dta[_msm_prep_sigvars] "`_sigvars'"

    * Bind the mapping, identity, and data signature into one metadata contract.
    _msm_contract prepare
    char _dta[_msm_prep_contract] `"`r(contract)'"'

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

    * Restore caller's physical observation order before returning.
    sort `_msm_orig_order'
    drop `_msm_orig_order'

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return scalar N = `N'
    return scalar n_ids = `n_ids'
    return scalar n_periods = `n_periods'
    return scalar period_span = `period_span'
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

    restore, not
    local _prep_preserved = 0

    } /* end capture noisily */
    local _rc = _rc

    if `_prep_preserved' {
        capture restore
    }

    capture _msm_restore_order `_msm_orig_order'
    local _order_rc = _rc
    if `_rc' == 0 & `_order_rc' != 0 local _rc = `_order_rc'

    set varabbrev `_varabbrev'
    set more `_more'

    if `_rc' exit `_rc'
end
