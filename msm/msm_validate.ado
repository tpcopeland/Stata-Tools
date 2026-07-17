*! msm_validate Version 1.2.2  2026/07/02
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

    tempvar _msm_orig_order

    capture noisily {

    quietly gen long `_msm_orig_order' = _n

    syntax [, STRict VERbose]

    * Check data has been prepared.
    *
    * msm_validate exists to FIND problems in the prepared data, and the checks
    * below are explicitly written to run "in case the data changed after
    * msm_prepare". A stale signature is therefore one of its FINDINGS, not a
    * reason to refuse to run: hard-failing on it would make the command
    * useless for its own purpose. Every other stage does hard-fail (audit
    * A02); this one reports.
    _msm_verify prepare
    local _prep_ok = r(ok)
    local _prep_why "`r(why)'"
    if `_prep_ok' == 0 & "`_prep_why'" != "edited" {
        * Not prepared at all, or a mapped variable is gone: there is nothing
        * to validate. _msm_check_prepared re-derives the verdict and emits the
        * appropriate message and return code.
        _msm_check_prepared
    }
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

    * Note a stale preparation. Downstream stages refuse to run against it, so
    * the user is better told here than at msm_fit (audit A02).
    *
    * Deliberately a NOTE, not a check/warning/error: msm_validate's public
    * contract is r(n_checks)/r(n_warnings)/r(n_errors), and changing those
    * counts is a documented-behaviour change that belongs to the
    * documentation and QA phases, not to the state rework. Phase 1's only
    * obligation here is not to break this command.
    if "`_prep_why'" == "edited" {
        display as text "  Note: the data have changed since {bf:msm_prepare} ran."
        display as text "        Mapped variables were edited, or observations were"
        display as text "        added or dropped. {bf:msm_weight} and {bf:msm_fit} will"
        display as text "        refuse to run until {bf:msm_prepare} is re-run."
        display as text ""
    }

    * Re-check binary mappings in case the data changed after msm_prepare.
    foreach var in `treatment' `outcome' {
        quietly count if !missing(`var') & !inlist(`var', 0, 1)
        if r(N) > 0 {
            display as error "  FAIL: `var' must be binary (0/1); found " ///
                r(N) " non-binary values"
            local ++n_errors
        }
    }
    if "`censor'" != "" {
        quietly count if !missing(`censor') & !inlist(`censor', 0, 1)
        if r(N) > 0 {
            display as error "  FAIL: `censor' must be binary (0/1); found " ///
                r(N) " non-binary values"
            local ++n_errors
        }
    }

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
    quietly bysort `id' (`period'): gen int `_ever_out' = sum(`outcome')
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
        if "`strict'" != "" {
            display as error "  FAIL: some periods have fewer than 10 observations (min: `min_per_n')"
            local ++n_errors
        }
        else {
            display as text "  WARNING: some periods have fewer than 10 observations (min: `min_per_n')"
            local ++n_warnings
        }
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
                if "`strict'" != "" {
                    display as error "  FAIL: covariate `var' has no variation"
                    local ++n_errors
                }
                else {
                    display as text "  WARNING: covariate `var' has no variation"
                    local ++n_warnings
                }
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
    * CHECK 10: Treatment support by period (audit A25)
    * =========================================================================
    local ++n_checks
    display as text "Check 10: Treatment support by period"

    * Count treated and untreated SEPARATELY among nonmissing rows. The old
    * check computed untreated as _N - total(treatment), which counts a missing
    * treatment as untreated, so a period with no genuine untreated subject
    * passed whenever missing rows padded the count. Missing treatment leaves
    * support indeterminate and is reported as its own failure.
    tempvar _p_tag _p_n1 _p_n0 _p_nm _p_nn
    quietly bysort `period': egen long `_p_n1' = total(`treatment' == 1)
    quietly bysort `period': egen long `_p_n0' = total(`treatment' == 0)
    quietly bysort `period': egen long `_p_nm' = total(missing(`treatment'))
    quietly bysort `period': gen long `_p_nn' = `_p_n1' + `_p_n0'
    quietly bysort `period': gen byte `_p_tag' = (_n == 1)

    quietly count if `_p_tag' & (`_p_n1' == 0 | `_p_n0' == 0)
    local n_no_pos = r(N)
    quietly count if `_p_tag' & `_p_nm' > 0
    local n_indet = r(N)

    if `n_no_pos' > 0 {
        if "`strict'" != "" {
            display as error "  FAIL: `n_no_pos' period(s) with no treated or no untreated subject (support violation)"
            local ++n_errors
        }
        else {
            display as text "  WARNING: `n_no_pos' period(s) with no treated or no untreated subject"
            local ++n_warnings
        }
        if "`verbose'" != "" {
            quietly levelsof `period' if `_p_tag' & (`_p_n1' == 0 | `_p_n0' == 0), local(bad_periods)
            display as text "    Affected periods: `bad_periods'"
        }
    }
    if `n_indet' > 0 {
        if "`strict'" != "" {
            display as error "  FAIL: `n_indet' period(s) with missing treatment (support indeterminate)"
            local ++n_errors
        }
        else {
            display as text "  WARNING: `n_indet' period(s) with missing treatment (support indeterminate)"
            local ++n_warnings
        }
        if "`verbose'" != "" {
            quietly levelsof `period' if `_p_tag' & `_p_nm' > 0, local(miss_periods)
            display as text "    Periods with missing treatment: `miss_periods'"
        }
    }
    if `n_no_pos' == 0 & `n_indet' == 0 {
        * Treatment prevalence range across periods, over nonmissing rows.
        tempvar _p_pct
        quietly bysort `period': gen double `_p_pct' = 100 * `_p_n1' / `_p_nn' if `_p_tag' & `_p_nn' > 0
        quietly summarize `_p_pct' if `_p_tag'
        local min_prev = r(min)
        local max_prev = r(max)
        drop `_p_pct'

        display as result "  PASS" as text " (treatment prevalence range: " ///
            as result %4.1f `min_prev' "%" as text " - " ///
            as result %4.1f `max_prev' "%" as text ")"
    }
    drop `_p_tag' `_p_n1' `_p_n0' `_p_nm' `_p_nn'

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

    * Restore caller's physical observation order before returning.
    sort `_msm_orig_order'
    drop `_msm_orig_order'

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return scalar n_checks = `n_checks'
    return scalar n_errors = `n_errors'
    return scalar n_warnings = `n_warnings'
    return local validation = cond(`n_errors' == 0, "passed", "failed")

    if `n_errors' > 0 {
        exit 198
    }
    if "`strict'" != "" & `n_warnings' > 0 {
        exit 198
    }

    } /* end capture noisily */
    local _rc = _rc

    capture _msm_restore_order `_msm_orig_order'
    local _order_rc = _rc
    if `_rc' == 0 & `_order_rc' != 0 local _rc = `_order_rc'

    set varabbrev `_varabbrev'
    set more `_more'

    if `_rc' exit `_rc'
end
