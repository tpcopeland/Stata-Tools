*! tte_validate Version 1.0.1  2026/02/27
*! Data quality checks for target trial emulation
*! Author: Timothy P Copeland
*! Author: Tania F Reza
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Department of Global Public Health, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tte_validate [, strict verbose]

Description:
  Runs comprehensive data quality checks on prepared data.
  Must run tte_prepare first.

Options:
  strict   - Treat warnings as errors
  verbose  - Show detailed diagnostics

See help tte_validate for complete documentation
*/

program define tte_validate, rclass
    version 16.0
    set varabbrev off
    set more off

    syntax [, STRict VERbose]

    * Check data has been prepared
    _tte_check_prepared
    _tte_get_settings

    local id         "`_tte_id'"
    local period     "`_tte_period'"
    local treatment  "`_tte_treatment'"
    local outcome    "`_tte_outcome'"
    local eligible   "`_tte_eligible'"
    local censor     "`_tte_censor'"
    local covariates "`_tte_covariates'"
    local estimand   "`_tte_estimand'"

    local n_warnings = 0
    local n_errors = 0
    local n_checks = 0

    display as text ""
    display as text "{hline 70}"
    display as result "tte_validate" as text " - Data Quality Checks"
    display as text "{hline 70}"
    display as text ""

    * =========================================================================
    * CHECK 1: Person-period format (exactly one row per id-period)
    * =========================================================================
    local ++n_checks
    display as text "Check 1: Person-period format"

    tempvar _dup
    quietly bysort `id' `period': gen byte `_dup' = _N
    quietly count if `_dup' > 1
    if r(N) > 0 {
        display as error "  FAIL: " r(N) " duplicate (id, period) rows found"
        local ++n_errors
    }
    else {
        display as result "  PASS"
    }
    drop `_dup'

    * =========================================================================
    * CHECK 2: No gaps in period sequences within individuals
    * =========================================================================
    local ++n_checks
    display as text "Check 2: No gaps in period sequences"

    tempvar _pdiff _gap
    quietly bysort `id' (`period'): gen double `_pdiff' = `period' - `period'[_n-1] if _n > 1
    quietly gen byte `_gap' = (`_pdiff' > 1) & !missing(`_pdiff')
    quietly count if `_gap' == 1
    local n_gaps = r(N)
    if `n_gaps' > 0 {
        if "`strict'" != "" {
            display as error "  FAIL: `n_gaps' gaps in period sequences"
            local ++n_errors
        }
        else {
            display as text "  WARNING: `n_gaps' gaps in period sequences"
            local ++n_warnings
        }
        if "`verbose'" != "" {
            tempvar _gaptag
            quietly bysort `id': gen byte `_gaptag' = (_gap == 1)
            quietly count if `_gaptag'
            display as text "    Individuals with gaps: " r(N)
            drop `_gaptag'
        }
    }
    else {
        display as result "  PASS"
    }
    drop `_pdiff' `_gap'

    * =========================================================================
    * CHECK 3: Outcome is terminal
    * =========================================================================
    local ++n_checks
    display as text "Check 3: Outcome is terminal (no rows after event)"

    tempvar _ever_out _check_post
    quietly bysort `id' (`period'): gen byte `_ever_out' = sum(`outcome')
    * After outcome=1, there should be no more rows. Outcome row itself is fine.
    quietly bysort `id' (`period'): gen byte `_check_post' = (`_ever_out'[_n-1] >= 1) if _n > 1
    quietly count if `_check_post' == 1
    local n_post = r(N)
    drop `_ever_out' `_check_post'

    if `n_post' > 0 {
        if "`strict'" != "" {
            display as error "  FAIL: `n_post' rows found after outcome event"
            local ++n_errors
        }
        else {
            display as text "  WARNING: `n_post' rows found after outcome event"
            local ++n_warnings
        }
    }
    else {
        display as result "  PASS"
    }

    * =========================================================================
    * CHECK 4: Treatment consistency (for PP: absorbing state check)
    * =========================================================================
    local ++n_checks
    display as text "Check 4: Treatment consistency"

    if "`estimand'" == "PP" | "`estimand'" == "AT" {
        * Check if treatment is absorbing (once started, stays on)
        tempvar _prev_treat _switch_off
        quietly bysort `id' (`period'): gen byte `_prev_treat' = `treatment'[_n-1] if _n > 1
        quietly gen byte `_switch_off' = (`_prev_treat' == 1 & `treatment' == 0)
        quietly count if `_switch_off' == 1
        local n_switchoff = r(N)
        drop `_prev_treat' `_switch_off'

        if `n_switchoff' > 0 {
            display as text "  NOTE: `n_switchoff' treatment discontinuations found"
            display as text "    (expected for `estimand'; will be handled by censoring/weighting)"
        }
        else {
            display as result "  PASS (treatment is absorbing)"
        }
    }
    else {
        display as result "  PASS (ITT: treatment switching is allowed)"
    }

    * =========================================================================
    * CHECK 5: Missing data
    * =========================================================================
    local ++n_checks
    display as text "Check 5: Missing data"

    local any_missing = 0
    local miss_vars ""

    foreach var in `id' `period' `treatment' `outcome' `eligible' {
        quietly count if missing(`var')
        if r(N) > 0 {
            local any_missing = 1
            local miss_vars "`miss_vars' `var'"
            if "`verbose'" != "" {
                display as text "    `var': " r(N) " missing values"
            }
        }
    }

    if "`covariates'" != "" {
        foreach var of local covariates {
            quietly count if missing(`var')
            if r(N) > 0 {
                local any_missing = 1
                if "`verbose'" != "" {
                    display as text "    `var': " r(N) " missing values"
                }
            }
        }
    }

    if `any_missing' {
        local miss_vars = strtrim("`miss_vars'")
        if "`strict'" != "" {
            display as error "  FAIL: missing values in core variables: `miss_vars'"
            local ++n_errors
        }
        else {
            display as text "  WARNING: missing values found"
            local ++n_warnings
        }
    }
    else {
        display as result "  PASS (no missing values in core variables)"
    }

    * =========================================================================
    * CHECK 6: Eligibility consistency
    * =========================================================================
    local ++n_checks
    display as text "Check 6: Eligibility consistency"

    * Eligible observations should not have prior outcome
    tempvar _prior_out
    quietly bysort `id' (`period'): gen byte `_prior_out' = sum(`outcome'[_n-1]) if _n > 1
    quietly replace `_prior_out' = 0 if missing(`_prior_out')
    quietly count if `eligible' == 1 & `_prior_out' > 0
    local n_elig_post = r(N)
    drop `_prior_out'

    if `n_elig_post' > 0 {
        if "`strict'" != "" {
            display as error "  FAIL: `n_elig_post' eligible obs after prior outcome"
            local ++n_errors
        }
        else {
            display as text "  WARNING: `n_elig_post' eligible observations after prior outcome"
            local ++n_warnings
        }
    }
    else {
        display as result "  PASS"
    }

    * =========================================================================
    * CHECK 7: Sufficient eligible observations
    * =========================================================================
    local ++n_checks
    display as text "Check 7: Sufficient eligible observations per period"

    quietly count if `eligible' == 1
    local total_eligible = r(N)

    if `total_eligible' == 0 {
        display as error "  FAIL: no eligible observations"
        local ++n_errors
    }
    else {
        * Check per-period counts
        tempvar _elig_count
        quietly bysort `period': egen long `_elig_count' = total(`eligible')
        quietly summarize `_elig_count' if `eligible' == 1
        local min_elig = r(min)
        drop `_elig_count'

        if `min_elig' < 10 {
            display as text "  WARNING: some periods have fewer than 10 eligible individuals (min: `min_elig')"
            local ++n_warnings
        }
        else {
            display as result "  PASS (min eligible per period: `min_elig')"
        }
    }

    * =========================================================================
    * CHECK 8: Positivity (treatment variation)
    * =========================================================================
    local ++n_checks
    display as text "Check 8: Positivity (treatment variation among eligible)"

    * Check that both treatment values exist among eligible
    quietly count if `eligible' == 1 & `treatment' == 1
    local n_elig_treat = r(N)
    quietly count if `eligible' == 1 & `treatment' == 0
    local n_elig_untreat = r(N)

    if `n_elig_treat' == 0 | `n_elig_untreat' == 0 {
        display as error "  FAIL: no treatment variation among eligible (treated: `n_elig_treat', untreated: `n_elig_untreat')"
        local ++n_errors
    }
    else {
        local treat_pct = 100 * `n_elig_treat' / (`n_elig_treat' + `n_elig_untreat')
        display as result "  PASS" as text " (treatment prevalence among eligible: " ///
            as result %4.1f `treat_pct' "%" as text ")"
    }

    * =========================================================================
    * CHECK 9: Period numbering
    * =========================================================================
    local ++n_checks
    display as text "Check 9: Period numbering"

    quietly summarize `period'
    local p_min = r(min)
    local p_max = r(max)

    if `p_min' != 0 & `p_min' != 1 {
        display as text "  NOTE: period starts at `p_min' (expected 0 or 1)"
    }
    else {
        display as result "  PASS (period range: `p_min' to `p_max')"
    }

    * =========================================================================
    * CHECK 10: Event rate
    * =========================================================================
    local ++n_checks
    display as text "Check 10: Event rate"

    quietly count if `outcome' == 1
    local n_events = r(N)
    quietly count
    local n_total = r(N)
    local event_rate = 100 * `n_events' / `n_total'

    if `n_events' < 5 {
        display as text "  WARNING: very few events (`n_events'); estimates may be unreliable"
        local ++n_warnings
    }
    else {
        display as result "  PASS" as text " (`n_events' events, rate: " ///
            as result %5.2f `event_rate' "%" as text ")"
    }

    * =========================================================================
    * SUMMARY
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as text "Validation summary:"
    display as text "  Checks run:   " as result `n_checks'

    if `n_errors' > 0 {
        display as text "  Errors:       " as error `n_errors'
    }
    else {
        display as text "  Errors:       " as result "0"
    }

    if `n_warnings' > 0 {
        display as text "  Warnings:     " as text `n_warnings'
    }
    else {
        display as text "  Warnings:     " as result "0"
    }

    if `n_errors' > 0 {
        display as text ""
        display as error "Data validation failed. Fix errors before proceeding."
        display as text "{hline 70}"
        if "`strict'" != "" {
            exit 198
        }
    }
    else if `n_warnings' > 0 {
        display as text ""
        display as text "Data validation passed with warnings."
        display as text "Use {cmd:strict} option to treat warnings as errors."
        display as text "{hline 70}"
    }
    else {
        display as text ""
        display as result "All checks passed."
        display as text "Next step: {cmd:tte_expand}"
        display as text "{hline 70}"
    }

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return scalar n_checks = `n_checks'
    return scalar n_errors = `n_errors'
    return scalar n_warnings = `n_warnings'
    return scalar n_events = `n_events'
    return scalar event_rate = `event_rate'
    return local validation = cond(`n_errors' == 0, "passed", "failed")
end
