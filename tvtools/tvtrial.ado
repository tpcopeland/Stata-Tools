*! tvtrial Version 1.0.0  2025/12/29
*! Target trial emulation for observational data
*! Author: Tim Copeland
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tvtrial, id(varname) entry(varname) exit(varname) ///
      treatstart(varname) [options]

Required:
  id(varname)         - Person identifier
  entry(varname)      - Study entry date
  exit(varname)       - Study exit date
  treatstart(varname) - Treatment initiation date (. if never treated)

Optional:
  eligstart(varname)  - Eligibility start (default: entry)
  eligend(varname)    - Eligibility end (default: exit)
  graceperiod(#)      - Grace period in days (default: 0)
  trials(#)           - Number of sequential trials (default: auto)
  trialinterval(#)    - Days between trial starts (default: 30)
  maxfollowup(#)      - Maximum follow-up days per trial (default: all)
  clone               - Clone approach (each person assigned to both arms)
  ipcweight           - Calculate inverse probability of censoring weights
  generate(prefix)    - Variable prefix (default: trial_)

Description:
  Implements target trial emulation for observational data using
  the sequential trial design with cloning and artificial censoring.

  The approach:
  1. At each trial start time, identify eligible individuals
  2. Clone eligible individuals and assign to treatment/no treatment
  3. Censor clones when they deviate from assigned strategy
  4. Optionally weight for artificial censoring

Output:
  Expanded dataset with trial_id, trial_arm, and censoring indicators

Examples:
  * Basic target trial emulation
  tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start)

  * With grace period and specified trials
  tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
      graceperiod(30) trials(12) trialinterval(30)

  * Clone-censor-weight approach
  tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
      clone ipcweight

See help tvtrial for complete documentation
*/

program define tvtrial, rclass
    version 16.0
    set varabbrev off

    * Parse syntax
    syntax , ID(varname) ENTry(varname) EXIT(varname) ///
        TREATstart(varname) ///
        [ELIGstart(varname) ELIGend(varname) ///
         GRACEperiod(integer 0) TRIALs(integer 0) ///
         TRIALInterval(integer 30) MAXfollowup(integer 0) ///
         CLONE IPCWeight GENerate(string)]

    * =========================================================================
    * INPUT VALIDATION
    * =========================================================================

    * Check required variables exist
    foreach var in `id' `entry' `exit' `treatstart' {
        capture confirm variable `var'
        if _rc != 0 {
            display as error "variable `var' not found"
            exit 111
        }
    }

    * Set defaults
    if "`eligstart'" == "" local eligstart "`entry'"
    if "`eligend'" == "" local eligend "`exit'"
    if "`generate'" == "" local generate "trial_"

    * Validate grace period
    if `graceperiod' < 0 {
        display as error "graceperiod() must be non-negative"
        exit 198
    }

    * Validate trial interval
    if `trialinterval' < 1 {
        display as error "trialinterval() must be at least 1"
        exit 198
    }

    * Count initial observations
    quietly count
    local n_orig = r(N)
    if `n_orig' == 0 {
        display as error "no observations"
        exit 2000
    }

    * Count unique individuals
    tempvar tag_id
    quietly bysort `id': gen `tag_id' = (_n == 1)
    quietly count if `tag_id'
    local n_ids = r(N)
    drop `tag_id'

    * =========================================================================
    * DETERMINE TRIAL TIMES
    * =========================================================================

    * Find date range
    quietly summarize `eligstart'
    local min_date = r(min)
    quietly summarize `eligend'
    local max_date = r(max)

    * Determine number of trials if not specified
    if `trials' == 0 {
        local trials = floor((`max_date' - `min_date') / `trialinterval') + 1
    }

    * Cap at reasonable maximum
    if `trials' > 365 {
        display as text "Note: Limiting to 365 trials"
        local trials = 365
    }

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as text "{bf:TARGET TRIAL EMULATION}"
    display as text "{hline 70}"
    display as text ""
    display as text "Input data:"
    display as text "  Observations:     " as result `n_orig'
    display as text "  Individuals:      " as result `n_ids'
    display as text ""
    display as text "Trial specification:"
    display as text "  Number of trials: " as result `trials'
    display as text "  Trial interval:   " as result `trialinterval' " days"
    display as text "  Grace period:     " as result `graceperiod' " days"
    if `maxfollowup' > 0 {
        display as text "  Max follow-up:    " as result `maxfollowup' " days"
    }
    else {
        display as text "  Max follow-up:    " as result "unlimited"
    }
    display as text "  Clone approach:   " as result cond("`clone'" != "", "Yes", "No")
    display as text "  IPC weighting:    " as result cond("`ipcweight'" != "", "Yes", "No")
    display as text ""

    * =========================================================================
    * PRESERVE AND PROCESS
    * =========================================================================

    preserve

    * Save original data
    tempfile orig_data
    quietly save `orig_data', replace

    * Create empty dataset for results
    clear
    local varlist = "`id' `entry' `exit' `treatstart' `eligstart' `eligend'"
    quietly save `orig_data'_empty, replace emptyok

    * =========================================================================
    * BUILD SEQUENTIAL TRIALS
    * =========================================================================

    display as text "{bf:Step 1: Building sequential trials}"

    local total_eligible = 0
    local total_clones = 0

    tempfile trial_data

    forvalues t = 1/`trials' {
        * Calculate trial start date
        local trial_date = `min_date' + (`t' - 1) * `trialinterval'

        * Load original data
        use `orig_data', clear

        * Check eligibility at trial start
        * Eligible if:
        * 1. Trial date is within eligibility window
        * 2. Not yet treated (or within grace period)
        * 3. Still at risk (not yet exited)

        quietly gen byte `generate'eligible = ///
            (`trial_date' >= `eligstart') & ///
            (`trial_date' <= `eligend') & ///
            (`trial_date' <= `exit') & ///
            (missing(`treatstart') | `treatstart' >= `trial_date')

        * Count eligible
        quietly count if `generate'eligible
        local n_elig = r(N)
        local total_eligible = `total_eligible' + `n_elig'

        if `n_elig' == 0 {
            drop `generate'eligible
            continue
        }

        * Keep only eligible individuals
        quietly keep if `generate'eligible
        drop `generate'eligible

        * Add trial identifiers
        gen int `generate'trial = `t'
        gen double `generate'start = `trial_date'
        format %td `generate'start

        if "`clone'" != "" {
            * Clone approach: duplicate each person for both arms

            * Determine actual treatment status
            quietly gen byte `generate'actual_arm = ///
                (!missing(`treatstart') & ///
                 `treatstart' >= `trial_date' & ///
                 `treatstart' <= `trial_date' + `graceperiod')

            * Save for cloning
            tempfile before_clone
            quietly save `before_clone', replace

            * Treatment arm (arm = 1)
            gen byte `generate'arm = 1

            * Calculate censoring for treatment arm
            * Censored if: didn't actually start treatment within grace period
            gen byte `generate'censored = (`generate'actual_arm == 0)

            * Follow-up end for this arm
            gen double `generate'fu_start = `trial_date'
            gen double `generate'fu_end = `exit'

            * If censored, censor at end of grace period
            replace `generate'fu_end = min(`generate'fu_end, `trial_date' + `graceperiod') ///
                if `generate'censored

            * Apply max follow-up
            if `maxfollowup' > 0 {
                replace `generate'fu_end = min(`generate'fu_end, `generate'fu_start + `maxfollowup')
            }

            format %td `generate'fu_start `generate'fu_end

            tempfile arm1
            quietly save `arm1', replace

            * Control arm (arm = 0)
            use `before_clone', clear
            gen byte `generate'arm = 0

            * Censored if: actually started treatment within grace period
            gen byte `generate'censored = (`generate'actual_arm == 1)

            gen double `generate'fu_start = `trial_date'
            gen double `generate'fu_end = `exit'

            * If censored (started treatment), censor at treatment start
            replace `generate'fu_end = min(`generate'fu_end, `treatstart') ///
                if `generate'censored & !missing(`treatstart')

            * Apply max follow-up
            if `maxfollowup' > 0 {
                replace `generate'fu_end = min(`generate'fu_end, `generate'fu_start + `maxfollowup')
            }

            format %td `generate'fu_start `generate'fu_end

            * Append treatment arm
            quietly append using `arm1'

            drop `generate'actual_arm
            local total_clones = `total_clones' + 2 * `n_elig'
        }
        else {
            * No cloning - assign based on actual treatment
            gen byte `generate'arm = ///
                (!missing(`treatstart') & ///
                 `treatstart' >= `trial_date' & ///
                 `treatstart' <= `trial_date' + `graceperiod')

            gen byte `generate'censored = 0

            gen double `generate'fu_start = `trial_date'
            gen double `generate'fu_end = `exit'

            if `maxfollowup' > 0 {
                replace `generate'fu_end = min(`generate'fu_end, `generate'fu_start + `maxfollowup')
            }

            format %td `generate'fu_start `generate'fu_end

            local total_clones = `total_clones' + `n_elig'
        }

        * Calculate follow-up time
        gen double `generate'fu_time = `generate'fu_end - `generate'fu_start

        * First trial - save as base
        if `t' == 1 {
            quietly save `trial_data', replace
        }
        else {
            * Append to existing trials
            quietly append using `trial_data'
            quietly save `trial_data', replace
        }
    }

    display as text "  Total person-trials: " as result `total_clones'
    display as text ""

    * =========================================================================
    * LOAD TRIAL DATA AND ADD WEIGHTS
    * =========================================================================

    use `trial_data', clear

    if "`ipcweight'" != "" {
        display as text "{bf:Step 2: Calculating inverse probability of censoring weights}"

        * For simplicity, use stabilized weights based on censoring probability
        * In practice, this would be modeled properly

        * Crude weight: 1 / P(not censored)
        quietly summarize `generate'censored
        local p_censor = r(mean)

        if `p_censor' < 1 {
            gen double `generate'ipcw = 1 / (1 - `p_censor') if `generate'censored == 0
            replace `generate'ipcw = 0 if `generate'censored == 1
        }
        else {
            gen double `generate'ipcw = 1
        }

        display as text "  Censoring rate: " as result %5.1f `p_censor' * 100 "%"
        display as text "  Note: Simplified weights used. For proper IPCW, model censoring."
        display as text ""
    }

    * =========================================================================
    * SUMMARY STATISTICS
    * =========================================================================

    display as text "{bf:Step 3: Summary statistics}"
    display as text ""

    * Count by arm
    quietly count if `generate'arm == 1
    local n_treat = r(N)
    quietly count if `generate'arm == 0
    local n_control = r(N)

    display as text "  Treatment arm:    " as result `n_treat'
    display as text "  Control arm:      " as result `n_control'

    * Censoring by arm
    if "`clone'" != "" {
        quietly count if `generate'arm == 1 & `generate'censored == 1
        local n_censor_treat = r(N)
        quietly count if `generate'arm == 0 & `generate'censored == 1
        local n_censor_control = r(N)

        display as text ""
        display as text "  Censored (treatment):   " as result `n_censor_treat' ///
            as text " (" as result %4.1f 100*`n_censor_treat'/`n_treat' as text "%)"
        display as text "  Censored (control):     " as result `n_censor_control' ///
            as text " (" as result %4.1f 100*`n_censor_control'/`n_control' as text "%)"
    }

    * Follow-up time
    quietly summarize `generate'fu_time
    local mean_fu = r(mean)
    local total_fu = r(sum)

    display as text ""
    display as text "  Mean follow-up:   " as result %6.1f `mean_fu' " days"
    display as text "  Total follow-up:  " as result %10.0fc `total_fu' " person-days"

    * Count actual trials with participants
    quietly levelsof `generate'trial
    local actual_trials = r(numlevels)

    display as text ""
    display as text "  Trials with participants: " as result `actual_trials'
    display as text ""

    * =========================================================================
    * RESTORE AND REPLACE
    * =========================================================================

    restore, not

    * =========================================================================
    * FINAL DISPLAY
    * =========================================================================

    display as text "{hline 70}"
    display as text "{bf:Target trial emulation complete}"
    display as text "{hline 70}"
    display as text ""
    display as text "Variables created:"
    display as text "  `generate'trial     - Trial number"
    display as text "  `generate'start     - Trial start date"
    display as text "  `generate'arm       - Treatment arm (1=treat, 0=control)"
    display as text "  `generate'censored  - Artificial censoring indicator"
    display as text "  `generate'fu_start  - Follow-up start"
    display as text "  `generate'fu_end    - Follow-up end"
    display as text "  `generate'fu_time   - Follow-up time (days)"
    if "`ipcweight'" != "" {
        display as text "  `generate'ipcw      - Inverse probability of censoring weight"
    }
    display as text ""
    display as text "For analysis, use:"
    display as text "  stset `generate'fu_time, failure(outcome) id(`id')"
    display as text "  stcox `generate'arm"
    if "`ipcweight'" != "" {
        display as text "  * Or with weights: stcox `generate'arm [pweight=`generate'ipcw]"
    }
    display as text ""

    * =========================================================================
    * RETURN VALUES
    * =========================================================================

    return scalar n_orig = `n_orig'
    return scalar n_ids = `n_ids'
    return scalar n_trials = `actual_trials'
    return scalar n_eligible = `total_eligible'
    return scalar n_persontrials = `total_clones'
    return scalar n_treat = `n_treat'
    return scalar n_control = `n_control'
    return scalar mean_fu = `mean_fu'
    return scalar total_fu = `total_fu'

    return local id "`id'"
    return local entry "`entry'"
    return local exit "`exit'"
    return local treatstart "`treatstart'"
    return local prefix "`generate'"

end
