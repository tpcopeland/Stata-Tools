*! msm_validate Version 1.0.1  2026/03/14
*! Data quality checks for marginal structural models
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  msm_validate [, strict verbose]

Description:
  Runs comprehensive data quality checks on prepared data.
  Must run msm_prepare first.

Options:
  strict   - Treat warnings as errors
  verbose  - Show detailed diagnostics

See help msm_validate for complete documentation
*/

program define msm_validate, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    set varabbrev off
    set more off

    capture noisily {

    syntax [, STRict VERbose]

    * Check data has been prepared
    _msm_check_prepared
    _msm_get_settings

    local id         "`_msm_id'"
    local period     "`_msm_period'"
    local treatment  "`_msm_treatment'"
    local outcome    "`_msm_outcome'"
    local censor     "`_msm_censor'"
    local covariates "`_msm_covariates'"
    local bl_covs    "`_msm_bl_covs'"

    local n_warnings = 0
    local n_errors = 0
    local n_checks = 0

    display as text ""
    display as text "{hline 70}"
    display as result "msm_validate" as text " - Data Quality Checks"
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
            quietly bysort `id': egen byte `_gaptag' = max(`_gap')
            quietly count if `_gaptag' == 1
            local n_gap_ids = r(N)
            * Count unique individuals with gaps
            tempvar _gtag2
            quietly bysort `id': gen byte `_gtag2' = (_n == 1) & `_gaptag'
            quietly count if `_gtag2'
            display as text "    Individuals with gaps: " r(N)
            drop `_gaptag' `_gtag2'
        }
    }
    else {
        display as result "  PASS"
    }
    drop `_pdiff' `_gap'

    * =========================================================================
    * CHECK 3: Outcome is terminal (no rows after event)
    * =========================================================================
    local ++n_checks
    display as text "Check 3: Outcome is terminal (no rows after event)"

    tempvar _ever_out _check_post
    quietly bysort `id' (`period'): gen byte `_ever_out' = sum(`outcome')
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
    * CHECK 4: Treatment variation (both values exist)
    * =========================================================================
    local ++n_checks
    display as text "Check 4: Treatment variation"

    quietly count if `treatment' == 1
    local n_treat1 = r(N)
    quietly count if `treatment' == 0
    local n_treat0 = r(N)

    if `n_treat1' == 0 | `n_treat0' == 0 {
        display as error "  FAIL: no treatment variation (treated: `n_treat1', untreated: `n_treat0')"
        local ++n_errors
    }
    else {
        * Report treatment switching patterns
        tempvar _prev_treat _switch_on _switch_off
        quietly bysort `id' (`period'): gen byte `_prev_treat' = `treatment'[_n-1] if _n > 1
        quietly gen byte `_switch_on' = (`_prev_treat' == 0 & `treatment' == 1)
        quietly gen byte `_switch_off' = (`_prev_treat' == 1 & `treatment' == 0)
        quietly count if `_switch_on' == 1
        local n_on = r(N)
        quietly count if `_switch_off' == 1
        local n_off = r(N)
        drop `_prev_treat' `_switch_on' `_switch_off'

        local treat_pct = 100 * `n_treat1' / (`n_treat1' + `n_treat0')
        display as result "  PASS" as text " (treated: " as result %4.1f `treat_pct' "%" as text ///
            ", switches on: `n_on', off: `n_off')"
    }

    * =========================================================================
    * CHECK 5: Missing data
    * =========================================================================
    local ++n_checks
    display as text "Check 5: Missing data"

    local any_missing = 0
    local miss_vars ""

    foreach var in `id' `period' `treatment' `outcome' {
        quietly count if missing(`var')
        if r(N) > 0 {
            local any_missing = 1
            local miss_vars "`miss_vars' `var'"
            if "`verbose'" != "" {
                display as text "    `var': " r(N) " missing values"
            }
        }
    }

    if "`censor'" != "" {
        quietly count if missing(`censor')
        if r(N) > 0 {
            local any_missing = 1
            local miss_vars "`miss_vars' `censor'"
            if "`verbose'" != "" {
                display as text "    `censor': " r(N) " missing values"
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

    if "`bl_covs'" != "" {
        foreach var of local bl_covs {
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
            display as error "  FAIL: missing values found"
            local ++n_errors
        }
        else {
            display as text "  WARNING: missing values found"
            local ++n_warnings
        }
    }
    else {
        display as result "  PASS (no missing values)"
    }

    * =========================================================================
    * CHECK 6: Sufficient observations per period
    * =========================================================================
    local ++n_checks
    display as text "Check 6: Sufficient observations per period"

    tempvar _per_count
    quietly bysort `period': gen long `_per_count' = _N
    tempvar _per_tag
    quietly bysort `period': gen byte `_per_tag' = (_n == 1)
    quietly summarize `_per_count' if `_per_tag'
    local min_per_n = r(min)
    local max_per_n = r(max)
    drop `_per_count' `_per_tag'

    if `min_per_n' < 10 {
        display as text "  WARNING: some periods have fewer than 10 observations (min: `min_per_n')"
        local ++n_warnings
    }
    else {
        display as result "  PASS" as text " (min per period: `min_per_n', max: `max_per_n')"
    }

    * =========================================================================
    * CHECK 7: Covariate completeness
    * =========================================================================
    local ++n_checks
    display as text "Check 7: Covariate completeness"

    local cov_issues = 0
    local all_covs "`covariates' `bl_covs'"
    if "`all_covs'" != "" {
        foreach var of local all_covs {
            quietly summarize `var'
            if r(N) == 0 {
                display as error "  FAIL: covariate `var' has no non-missing values"
                local ++n_errors
                local cov_issues = 1
            }
            else if r(sd) == 0 {
                display as text "  WARNING: covariate `var' has no variation"
                local ++n_warnings
                local cov_issues = 1
            }
        }
        if `cov_issues' == 0 {
            local n_covs : word count `all_covs'
            display as result "  PASS" as text " (`n_covs' covariates all have variation)"
        }
    }
    else {
        display as text "  NOTE: no covariates specified"
    }

    * =========================================================================
    * CHECK 8: Treatment history patterns
    * =========================================================================
    local ++n_checks
    display as text "Check 8: Treatment history patterns"

    * Classify individuals: always treated, never treated, switchers
    tempvar _ever_treat _always_treat _id_tag
    quietly bysort `id': egen byte `_ever_treat' = max(`treatment')
    quietly bysort `id': egen byte `_always_treat' = min(`treatment')
    quietly bysort `id': gen byte `_id_tag' = (_n == 1)

    quietly count if `_id_tag' & `_always_treat' == 1
    local n_always = r(N)
    quietly count if `_id_tag' & `_ever_treat' == 0
    local n_never = r(N)
    quietly count if `_id_tag' & `_ever_treat' == 1 & `_always_treat' == 0
    local n_switchers = r(N)
    quietly count if `_id_tag'
    local n_total_ids = r(N)
    drop `_ever_treat' `_always_treat' `_id_tag'

    display as result "  PASS"
    display as text "    Always treated: `n_always' (" ///
        as result %4.1f 100*`n_always'/`n_total_ids' "%" as text ")"
    display as text "    Never treated:  `n_never' (" ///
        as result %4.1f 100*`n_never'/`n_total_ids' "%" as text ")"
    display as text "    Switchers:      `n_switchers' (" ///
        as result %4.1f 100*`n_switchers'/`n_total_ids' "%" as text ")"

    * =========================================================================
    * CHECK 9: Censoring patterns
    * =========================================================================
    local ++n_checks
    display as text "Check 9: Censoring patterns"

    if "`censor'" != "" {
        quietly count if `censor' == 1
        local n_censored = r(N)
        quietly count
        local n_total = r(N)
        local cens_pct = 100 * `n_censored' / `n_total'

        * Check that censoring is terminal
        tempvar _post_cens
        quietly bysort `id' (`period'): gen byte `_post_cens' = (sum(`censor'[_n-1]) >= 1) if _n > 1
        quietly count if `_post_cens' == 1
        local n_post_cens = r(N)
        drop `_post_cens'

        if `n_post_cens' > 0 {
            if "`strict'" != "" {
                display as error "  FAIL: `n_post_cens' rows found after censoring"
                local ++n_errors
            }
            else {
                display as text "  WARNING: `n_post_cens' rows found after censoring"
                local ++n_warnings
            }
        }
        else {
            display as result "  PASS" as text " (censored: `n_censored' obs, " ///
                as result %4.1f `cens_pct' "%" as text ")"
        }
    }
    else {
        display as text "  NOTE: no censoring variable specified"
    }

    * =========================================================================
    * CHECK 10: Positivity by period
    * =========================================================================
    local ++n_checks
    display as text "Check 10: Positivity by period"

    * Check that both treatment values exist in each period
    tempvar _p_tag _p_t1 _p_t0
    quietly bysort `period': egen long `_p_t1' = total(`treatment')
    quietly bysort `period': gen long `_p_t0' = _N - `_p_t1'
    quietly bysort `period': gen byte `_p_tag' = (_n == 1)

    quietly count if `_p_tag' & (`_p_t1' == 0 | `_p_t0' == 0)
    local n_no_pos = r(N)

    if `n_no_pos' > 0 {
        if "`strict'" != "" {
            display as error "  FAIL: `n_no_pos' periods with no treatment variation (positivity violation)"
            local ++n_errors
        }
        else {
            display as text "  WARNING: `n_no_pos' periods with no treatment variation"
            local ++n_warnings
        }
        if "`verbose'" != "" {
            * Show which periods
            quietly levelsof `period' if `_p_tag' & (`_p_t1' == 0 | `_p_t0' == 0), local(bad_periods)
            display as text "    Affected periods: `bad_periods'"
        }
    }
    else {
        * Show treatment prevalence range across periods
        tempvar _p_pct
        quietly bysort `period': gen double `_p_pct' = 100 * `_p_t1' / _N if `_p_tag'
        quietly summarize `_p_pct' if `_p_tag'
        local min_prev = r(min)
        local max_prev = r(max)
        drop `_p_pct'

        display as result "  PASS" as text " (treatment prevalence range: " ///
            as result %4.1f `min_prev' "%" as text " - " ///
            as result %4.1f `max_prev' "%" as text ")"
    }
    drop `_p_tag' `_p_t1' `_p_t0'

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
        display as text "Next step: {cmd:msm_weight}"
        display as text "{hline 70}"
    }

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return scalar n_checks = `n_checks'
    return scalar n_errors = `n_errors'
    return scalar n_warnings = `n_warnings'
    return local validation = cond(`n_errors' == 0, "passed", "failed")

    } /* end capture noisily */
    local _rc = _rc

    set varabbrev `_varabbrev'
    set more `_more'

    if `_rc' exit `_rc'
end
