*! tte_expand Version 1.0.3  2026/03/01
*! Sequential trial expansion (clone-censor-weight) for target trial emulation
*! Author: Timothy P Copeland
*! Author: Tania F Reza
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Department of Global Public Health, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tte_expand [, trials(numlist) maxfollowup(#) grace(#)
      save(string) replace]

Description:
  Expands person-period data into a sequence of emulated trials using
  the clone-censor-weight approach. Each eligible period becomes a
  trial start, and individuals are cloned into treatment/control arms
  with artificial censoring for protocol deviations.

  For ITT:   No censoring for treatment switching
  For PP:    Censor when deviating from assigned strategy
  For AT:    Censor when switching treatment groups

Requires:
  Data must have been prepared with tte_prepare first.

See help tte_expand for complete documentation
*/

program define tte_expand, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax [, TRIALs(numlist integer >=0) MAXfollowup(integer 0) ///
        GRACE(integer 0) ///
        SAve(string) REPLACE]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================

    _tte_check_prepared
    _tte_get_settings

    local id         "`_tte_id'"
    local period     "`_tte_period'"
    local treatment  "`_tte_treatment'"
    local outcome    "`_tte_outcome'"
    local eligible   "`_tte_eligible'"
    local censor_var "`_tte_censor'"
    local covariates "`_tte_covariates'"
    local bl_covs    "`_tte_bl_covs'"
    local estimand   "`_tte_estimand'"
    local prefix     "`_tte_prefix'"

    * =========================================================================
    * VALIDATION
    * =========================================================================

    if `grace' < 0 {
        display as error "grace() must be non-negative"
        exit 198
    }

    if `maxfollowup' < 0 {
        display as error "maxfollowup() must be non-negative"
        exit 198
    }

    if "`save'" != "" {
        if "`replace'" == "" {
            capture confirm new file "`save'"
            if _rc != 0 {
                display as error "file `save' already exists; use replace option"
                exit 602
            }
        }
    }

    * Determine which trial periods to use
    quietly summarize `period' if `eligible' == 1
    local min_trial = r(min)
    local max_trial = r(max)

    if "`trials'" == "" {
        * Use all eligible periods
        quietly levelsof `period' if `eligible' == 1, local(trial_periods)
    }
    else {
        local trial_periods "`trials'"
    }

    local n_trial_periods: word count `trial_periods'

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as result "tte_expand" as text " - Sequential Trial Expansion"
    display as text "{hline 70}"
    display as text ""
    display as text "Estimand:        " as result "`estimand'"
    display as text "Trial periods:   " as result "`n_trial_periods'"
    if `maxfollowup' > 0 {
        display as text "Max follow-up:   " as result "`maxfollowup' periods"
    }
    else {
        display as text "Max follow-up:   " as result "unlimited"
    }
    if "`estimand'" != "ITT" {
        display as text "Grace period:    " as result "`grace' periods"
    }
    display as text ""

    * =========================================================================
    * PRESERVE AND PROCESS
    * =========================================================================

    preserve

    * Save original data
    tempfile orig_data
    quietly save `orig_data', replace

    * Sort for efficiency
    sort `id' `period'

    * =========================================================================
    * BUILD SEQUENTIAL TRIALS
    * =========================================================================

    display as text "Expanding trials... " _continue

    local n_saved = 0
    local total_expanded = 0
    local total_censored = 0
    local trial_count = 0

    foreach t of local trial_periods {
        * Load original data for this trial
        use `orig_data', clear

        * Identify eligible individuals at trial period t
        * Eligible = eligible==1 at this period
        quietly count if `period' == `t' & `eligible' == 1
        local n_elig_t = r(N)

        if `n_elig_t' == 0 continue

        local ++trial_count

        * Get list of eligible IDs at period t
        * We need the baseline treatment assignment at period t
        tempvar _elig_at_t _baseline_treat
        quietly gen byte `_elig_at_t' = (`period' == `t' & `eligible' == 1)

        * For each eligible ID, capture their treatment at period t
        quietly bysort `id': egen byte `_baseline_treat' = max(`treatment' * (`period' == `t'))

        * Keep only observations for eligible individuals from period t onward
        tempvar _is_elig_id
        quietly bysort `id': egen byte `_is_elig_id' = max(`_elig_at_t')
        quietly keep if `_is_elig_id' == 1 & `period' >= `t'
        drop `_elig_at_t' `_is_elig_id'

        * Freeze covariates at baseline (trial-entry) values
        * Per Hernán & Robins: MSM conditions on L₀ only; IP weights handle L_t
        if "`covariates'" != "" {
            foreach var of local covariates {
                tempvar _bl_val
                quietly bysort `id' (`period'): gen double `_bl_val' = `var'[1]
                quietly replace `var' = `_bl_val'
                drop `_bl_val'
            }
        }
        if "`bl_covs'" != "" {
            foreach var of local bl_covs {
                tempvar _bl_val
                quietly bysort `id' (`period'): gen double `_bl_val' = `var'[1]
                quietly replace `var' = `_bl_val'
                drop `_bl_val'
            }
        }

        * Create follow-up time (relative to trial start)
        gen int `prefix'followup = `period' - `t'

        * Apply max follow-up
        if `maxfollowup' > 0 {
            quietly drop if `prefix'followup > `maxfollowup'
        }

        * Trial identifier
        gen int `prefix'trial = `t'

        * =====================================================================
        * CLONE-CENSOR based on estimand
        * =====================================================================

        if "`estimand'" == "ITT" {
            * ITT: No cloning, use actual treatment. No artificial censoring.
            gen byte `prefix'arm = `_baseline_treat'
            gen byte `prefix'censored = 0
            gen byte `prefix'outcome_obs = `outcome'

            local total_expanded = `total_expanded' + _N
        }
        else {
            * PP or AT: Clone each individual into two arms
            * Save for cloning
            tempfile _before_clone
            quietly save `_before_clone', replace

            * --- Treatment arm (arm=1) ---
            gen byte `prefix'arm = 1

            * Assigned treatment at baseline
            gen byte `prefix'assigned = 1

            * Track censoring: treatment arm censored if stops treatment
            * (after grace period)
            _tte_expand_censor, id(`id') treatment(`treatment') ///
                outcome(`outcome') arm(1) grace(`grace') ///
                estimand(`estimand') prefix(`prefix') ///
                followup(`prefix'followup)

            tempfile _arm1
            quietly save `_arm1', replace

            * --- Control arm (arm=0) ---
            use `_before_clone', clear
            gen byte `prefix'arm = 0
            gen byte `prefix'assigned = 0

            * Control arm censored if starts treatment (after grace period)
            _tte_expand_censor, id(`id') treatment(`treatment') ///
                outcome(`outcome') arm(0) grace(`grace') ///
                estimand(`estimand') prefix(`prefix') ///
                followup(`prefix'followup)

            * Append treatment arm
            quietly append using `_arm1'

            * Count
            quietly count if `prefix'censored == 1
            local total_censored = `total_censored' + r(N)
            local total_expanded = `total_expanded' + _N

            drop `prefix'assigned
        }

        drop `_baseline_treat'

        * Save this trial's expanded data
        local ++n_saved
        tempfile _tf`n_saved'
        quietly save `_tf`n_saved'', replace

        * Progress display
        display as text _char(13) "Expanding trials... " ///
            string(round(`trial_count'/`n_trial_periods'*100), "%3.0f") "%" _continue
    }

    display as text _char(13) "Expanding trials... done" _newline

    if `n_saved' == 0 {
        display as error "no trials produced; check eligibility criteria"
        restore
        exit 2000
    }

    * Count original observations before combining
    use `orig_data', clear
    quietly count
    local n_orig = r(N)

    * =========================================================================
    * COMBINE ALL TRIALS
    * =========================================================================

    display as text "Combining `n_saved' trial datasets..."

    use `_tf1', clear
    forvalues i = 2/`n_saved' {
        quietly append using `_tf`i''
    }

    * Sort final dataset
    sort `prefix'trial `prefix'arm `id' `prefix'followup

    * Label variables
    label variable `prefix'trial "Emulated trial period"
    label variable `prefix'arm "Treatment arm (1=treated, 0=control)"
    label variable `prefix'followup "Follow-up time within trial"
    label variable `prefix'censored "Artificially censored (0/1)"
    label variable `prefix'outcome_obs "Observed outcome at this follow-up"

    * =========================================================================
    * STORE METADATA
    * =========================================================================

    char _dta[_tte_prepared] "1"
    char _dta[_tte_expanded] "1"
    char _dta[_tte_id] "`id'"
    char _dta[_tte_period] "`period'"
    char _dta[_tte_treatment] "`treatment'"
    char _dta[_tte_outcome] "`outcome'"
    char _dta[_tte_eligible] "`eligible'"
    char _dta[_tte_censor] "`censor_var'"
    char _dta[_tte_covariates] "`covariates'"
    char _dta[_tte_bl_covariates] "`bl_covs'"
    char _dta[_tte_estimand] "`estimand'"
    char _dta[_tte_prefix] "`prefix'"

    * =========================================================================
    * SAVE OR REPLACE
    * =========================================================================

    if "`save'" != "" {
        quietly save "`save'", replace
        display as text "Expanded data saved to: " as result "`save'"
    }

    * Count final statistics
    quietly count
    local n_expanded = r(N)
    quietly count if `prefix'arm == 1
    local n_treat = r(N)
    quietly count if `prefix'arm == 0
    local n_control = r(N)
    quietly count if `prefix'censored == 1
    local n_cens_final = r(N)
    quietly count if `prefix'outcome_obs == 1
    local n_events = r(N)

    local expansion_ratio = `n_expanded' / `n_orig'

    * Replace original data with expanded
    restore, not

    * =========================================================================
    * DISPLAY SUMMARY
    * =========================================================================

    display as text ""
    display as text "Expansion complete:"
    display as text "  Original obs:     " as result %10.0fc `n_orig'
    display as text "  Expanded obs:     " as result %10.0fc `n_expanded'
    display as text "  Expansion ratio:  " as result %10.1f `expansion_ratio' "x"
    display as text "  Trials created:   " as result `trial_count'
    display as text "  Treatment arm:    " as result %10.0fc `n_treat'
    display as text "  Control arm:      " as result %10.0fc `n_control'
    display as text "  Censored:         " as result %10.0fc `n_cens_final'
    display as text "  Events:           " as result %10.0fc `n_events'
    display as text ""
    display as text "Variables created: " as result ///
        "`prefix'trial `prefix'arm `prefix'followup `prefix'censored `prefix'outcome_obs"
    display as text ""
    if "`estimand'" != "ITT" {
        display as text "Next step: {cmd:tte_weight}"
    }
    else {
        display as text "Next step: {cmd:tte_fit}"
    }
    display as text "{hline 70}"

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return scalar n_trials = `trial_count'
    return scalar n_expanded = `n_expanded'
    return scalar n_treat = `n_treat'
    return scalar n_control = `n_control'
    return scalar n_censored = `n_cens_final'
    return scalar n_events = `n_events'
    return scalar expansion_ratio = `expansion_ratio'
    return local method "memory"
    return local estimand "`estimand'"

    set varabbrev `_vaset'
end

* =========================================================================
* _tte_expand_censor: Apply artificial censoring within a trial arm
*   For PP: treatment arm censored if stops treatment after grace
*           control arm censored if starts treatment after grace
*   For AT: same logic (as-treated = censor at switching)
* =========================================================================
program define _tte_expand_censor
    version 16.0
    set varabbrev off
    set more off

    syntax , id(varname) treatment(varname) outcome(varname) ///
        arm(integer) grace(integer) estimand(string) ///
        prefix(string) followup(varname)

    * Create censored indicator
    gen byte `prefix'censored = 0
    gen byte `prefix'outcome_obs = 0

    quietly {
        if `arm' == 1 {
            * Treatment arm: censored when STOPS treatment
            * After grace period, if treatment == 0, censor
            tempvar _deviated _first_dev _cens_time _min_cens
            gen byte `_deviated' = (`treatment' == 0 & `followup' >= `grace')

            * Find first deviation time per individual
            bysort `id' (`followup'): gen byte `_first_dev' = (`_deviated' == 1 & `_deviated'[_n-1] == 0) | ///
                (`_deviated' == 1 & _n == 1)

            * Mark censoring at first deviation
            bysort `id' (`followup'): gen int `_cens_time' = `followup' if `_first_dev' == 1
            bysort `id': egen int `_min_cens' = min(`_cens_time')

            * Censor at and after first deviation
            replace `prefix'censored = 1 if `followup' == `_min_cens' & !missing(`_min_cens')

            * Drop rows after censoring
            drop if `followup' > `_min_cens' & !missing(`_min_cens')

            * Outcome is only observed if not censored at this time
            replace `prefix'outcome_obs = `outcome' if `prefix'censored == 0

            drop `_deviated' `_first_dev' `_cens_time' `_min_cens'
        }
        else {
            * Control arm: censored when STARTS treatment
            * After grace period, if treatment == 1, censor
            tempvar _deviated _first_dev _cens_time _min_cens
            gen byte `_deviated' = (`treatment' == 1 & `followup' >= `grace')

            * Find first deviation time per individual
            bysort `id' (`followup'): gen byte `_first_dev' = (`_deviated' == 1 & `_deviated'[_n-1] == 0) | ///
                (`_deviated' == 1 & _n == 1)

            bysort `id' (`followup'): gen int `_cens_time' = `followup' if `_first_dev' == 1
            bysort `id': egen int `_min_cens' = min(`_cens_time')

            replace `prefix'censored = 1 if `followup' == `_min_cens' & !missing(`_min_cens')
            drop if `followup' > `_min_cens' & !missing(`_min_cens')
            replace `prefix'outcome_obs = `outcome' if `prefix'censored == 0

            drop `_deviated' `_first_dev' `_cens_time' `_min_cens'
        }
    }
end
