*! tvpipeline Version 1.0.0  2025/12/29
*! Complete workflow for time-varying exposure analysis
*! Author: Tim Copeland
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tvpipeline using exposure_data, id(varname) start(varname) stop(varname) ///
      exposure(varname) entry(varname) exit(varname) [options]

Required:
  using exposure_data   - Dataset containing exposure records
  id(varname)           - Person identifier (in both datasets)
  start(varname)        - Exposure start date (in exposure data)
  stop(varname)         - Exposure stop date (in exposure data)
  exposure(varname)     - Exposure variable (in exposure data)
  entry(varname)        - Follow-up entry date (in cohort data)
  exit(varname)         - Follow-up exit date (in cohort data)

Options:
  reference(#)          - Reference level for exposure (default: 0)
  event(varname)        - Event date variable (for tvevent)
  compete(varname)      - Competing event date variable
  diagnose              - Run tvdiagnose after creation
  balance(varlist)      - Run tvbalance on specified covariates
  plot                  - Generate exposure swimlane plot
  saveas(filename)      - Save final dataset
  replace               - Replace existing file

Output:
  Time-varying exposure dataset ready for analysis
  Optional diagnostics, balance checks, and visualizations

Examples:
  * Basic pipeline
  use cohort, clear
  tvpipeline using medications, id(id) start(rx_start) stop(rx_stop) ///
      exposure(drug) entry(study_entry) exit(study_exit)

  * Complete workflow with diagnostics
  use cohort, clear
  tvpipeline using medications, id(id) start(rx_start) stop(rx_stop) ///
      exposure(drug) reference(0) entry(study_entry) exit(study_exit) ///
      event(outcome_date) diagnose balance(age sex) plot ///
      saveas(analysis_ready.dta) replace

See help tvpipeline for complete documentation
*/

program define tvpipeline, rclass
    version 16.0
    set varabbrev off

    * Parse syntax
    syntax using/, ID(varname) START(string) STOP(string) ///
        EXPosure(string) ENTry(varname) EXIT(varname) ///
        [REFerence(integer 0) EVENT(varname) COMPete(varname) ///
         DIAGnose BALance(varlist) PLOT SAVEas(string) REPLACE]

    * =========================================================================
    * INITIAL VALIDATION
    * =========================================================================

    * Store the exposure file path (remove quotes if present)
    local expfile `"`using'"'
    local expfile: subinstr local expfile `"""' "", all

    * Check exposure file exists
    capture confirm file "`expfile'"
    if _rc != 0 {
        display as error "exposure file not found: `expfile'"
        exit 601
    }

    * Validate current dataset has required variables
    capture confirm variable `id'
    if _rc != 0 {
        display as error "id variable `id' not found in current dataset"
        exit 111
    }

    capture confirm variable `entry'
    if _rc != 0 {
        display as error "entry variable `entry' not found in current dataset"
        exit 111
    }

    capture confirm variable `exit'
    if _rc != 0 {
        display as error "exit variable `exit' not found in current dataset"
        exit 111
    }

    if "`event'" != "" {
        capture confirm variable `event'
        if _rc != 0 {
            display as error "event variable `event' not found in current dataset"
            exit 111
        }
    }

    if "`compete'" != "" {
        capture confirm variable `compete'
        if _rc != 0 {
            display as error "compete variable `compete' not found in current dataset"
            exit 111
        }
    }

    * Validate balance variables if specified
    if "`balance'" != "" {
        foreach var of local balance {
            capture confirm variable `var'
            if _rc != 0 {
                display as error "balance variable `var' not found in current dataset"
                exit 111
            }
        }
    }

    * Check saveas file
    if "`saveas'" != "" & "`replace'" == "" {
        capture confirm file "`saveas'"
        if _rc == 0 {
            display as error "file `saveas' already exists; use replace option"
            exit 602
        }
    }

    * Count initial observations
    quietly count
    local n_cohort = r(N)
    quietly distinct `id'
    local n_ids = r(ndistinct)

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as text "{bf:TVPIPELINE: Complete Time-Varying Exposure Workflow}"
    display as text "{hline 70}"
    display as text ""
    display as text "Cohort data:"
    display as text "  Observations: " as result `n_cohort'
    display as text "  Unique IDs:   " as result `n_ids'
    display as text "  Entry var:    " as result "`entry'"
    display as text "  Exit var:     " as result "`exit'"
    display as text ""
    display as text "Exposure data:  " as result "`expfile'"
    display as text "  ID var:       " as result "`id'"
    display as text "  Start var:    " as result "`start'"
    display as text "  Stop var:     " as result "`stop'"
    display as text "  Exposure var: " as result "`exposure'"
    display as text "  Reference:    " as result "`reference'"
    display as text ""

    * =========================================================================
    * PRE-STEP: SAVE EVENT DATA BEFORE TVEXPOSE
    * =========================================================================
    * tvexpose doesn't preserve cohort variables, so save event data first

    tempfile cohort_vars
    local has_cohort_vars = 0

    * Save event and balance variables from cohort before tvexpose
    * (tvexpose doesn't preserve cohort variables)
    if "`event'" != "" | "`balance'" != "" {
        preserve
        * Build list of variables to keep
        local keepvars "`id'"
        if "`event'" != "" {
            local keepvars "`keepvars' `event'"
        }
        if "`compete'" != "" {
            local keepvars "`keepvars' `compete'"
        }
        if "`balance'" != "" {
            local keepvars "`keepvars' `balance'"
        }
        keep `keepvars'
        quietly bysort `id': keep if _n == 1
        quietly save `cohort_vars', replace
        restore
        local has_cohort_vars = 1
    }

    * =========================================================================
    * STEP 1: RUN TVEXPOSE
    * =========================================================================

    display as text "{hline 70}"
    display as text "{bf:Step 1: Creating time-varying exposure dataset (tvexpose)}"
    display as text "{hline 70}"
    display as text ""

    * Build tvexpose command
    local tvexpose_cmd `"tvexpose using "`expfile'", id(`id') start(`start') stop(`stop') exposure(`exposure') reference(`reference') entry(`entry') exit(`exit')"'

    * Run tvexpose
    capture noisily `tvexpose_cmd'
    if _rc != 0 {
        display as error "tvexpose failed with error `=_rc'"
        exit _rc
    }

    * Store tvexpose results
    local n_after_expose = _N
    quietly distinct `id'
    local n_ids_after = r(ndistinct)

    * Standardize variable names for pipeline
    * tvexpose preserves original variable names, but we need consistent names
    if "`start'" != "start" {
        capture confirm variable `start'
        if _rc == 0 {
            rename `start' start
        }
    }
    if "`stop'" != "stop" {
        capture confirm variable `stop'
        if _rc == 0 {
            rename `stop' stop
        }
    }

    display as text ""
    display as result "tvexpose completed successfully"
    display as text "  Observations: " as result `n_after_expose'
    display as text "  Unique IDs:   " as result `n_ids_after'
    display as text ""

    * =========================================================================
    * STEP 2: RUN TVEVENT (if event specified)
    * =========================================================================

    local n_events = 0
    local n_compete = 0

    if "`event'" != "" {
        display as text "{hline 70}"
        display as text "{bf:Step 2: Adding events to dataset (tvevent)}"
        display as text "{hline 70}"
        display as text ""

        * tvevent expects: event data in memory, interval data in using file
        * Event data was saved before tvexpose in PRE-STEP

        * Save interval data to tempfile
        tempfile interval_data
        quietly save `interval_data', replace

        * Load the saved cohort data (from PRE-STEP)
        use `cohort_vars', clear

        * Keep only those with non-missing events
        quietly drop if missing(`event')

        * Build tvevent command
        local tvevent_cmd `"tvevent using `interval_data', id(`id') date(`event') generate(_event)"'

        if "`compete'" != "" {
            local tvevent_cmd `"`tvevent_cmd' compete(`compete')"'
        }

        if "`balance'" != "" {
            local tvevent_cmd `"`tvevent_cmd' keepvars(`balance')"'
        }

        * Run tvevent
        capture noisily `tvevent_cmd'
        if _rc != 0 {
            display as error "tvevent failed with error `=_rc'"
            * Restore interval data if tvevent fails
            use `interval_data', clear
            exit _rc
        }

        * Count events and create _compete variable if needed
        capture confirm variable _event
        if _rc == 0 {
            quietly count if _event == 1
            local n_events = r(N)

            * tvevent encodes competing events as _event >= 2
            * Create _compete indicator for user convenience
            if "`compete'" != "" {
                quietly gen byte _compete = (_event >= 2) if !missing(_event)
                label var _compete "Competing event indicator"
                quietly count if _compete == 1
                local n_compete = r(N)
            }
        }

        display as text ""
        display as result "tvevent completed successfully"
        display as text "  Events:     " as result `n_events'
        if "`compete'" != "" {
            display as text "  Competing:  " as result `n_compete'
        }
        display as text ""
    }
    else {
        display as text "{hline 70}"
        display as text "{bf:Step 2: Skipped (no event variable specified)}"
        display as text "{hline 70}"
        display as text ""

        * If balance variables were saved but no event, merge them back now
        if `has_cohort_vars' == 1 & "`balance'" != "" {
            quietly merge m:1 `id' using `cohort_vars', nogenerate keep(master match)
        }
    }

    * =========================================================================
    * STEP 3: DIAGNOSTICS (if requested)
    * =========================================================================

    if "`diagnose'" != "" {
        display as text "{hline 70}"
        display as text "{bf:Step 3: Running diagnostics (tvdiagnose)}"
        display as text "{hline 70}"
        display as text ""

        * Run tvdiagnose
        capture noisily tvdiagnose, id(`id') start(start) stop(stop) exposure(tv_exposure)

        if _rc != 0 {
            display as error "tvdiagnose failed with error `=_rc'"
            display as text "Continuing with pipeline..."
        }
        else {
            display as text ""
            display as result "tvdiagnose completed successfully"
        }
        display as text ""
    }
    else {
        display as text "{hline 70}"
        display as text "{bf:Step 3: Diagnostics skipped (use diagnose option to enable)}"
        display as text "{hline 70}"
        display as text ""
    }

    * =========================================================================
    * STEP 4: BALANCE CHECK (if requested)
    * =========================================================================

    if "`balance'" != "" {
        display as text "{hline 70}"
        display as text "{bf:Step 4: Checking covariate balance (tvbalance)}"
        display as text "{hline 70}"
        display as text ""

        * Run tvbalance
        capture noisily tvbalance `balance', exposure(tv_exposure)

        if _rc != 0 {
            display as error "tvbalance failed with error `=_rc'"
            display as text "Continuing with pipeline..."
        }
        else {
            display as text ""
            display as result "tvbalance completed successfully"
        }
        display as text ""
    }
    else {
        display as text "{hline 70}"
        display as text "{bf:Step 4: Balance check skipped (use balance() to enable)}"
        display as text "{hline 70}"
        display as text ""
    }

    * =========================================================================
    * STEP 5: PLOT (if requested)
    * =========================================================================

    if "`plot'" != "" {
        display as text "{hline 70}"
        display as text "{bf:Step 5: Generating exposure plot (tvplot)}"
        display as text "{hline 70}"
        display as text ""

        * Run tvplot (swimlane for first 20 individuals)
        capture noisily tvplot, id(`id') start(start) stop(stop) exposure(tv_exposure) type(swimlane) nmax(20)

        if _rc != 0 {
            display as error "tvplot failed with error `=_rc'"
            display as text "Continuing with pipeline..."
        }
        else {
            display as text ""
            display as result "tvplot completed successfully"
        }
        display as text ""
    }
    else {
        display as text "{hline 70}"
        display as text "{bf:Step 5: Plot skipped (use plot option to enable)}"
        display as text "{hline 70}"
        display as text ""
    }

    * =========================================================================
    * STEP 6: SAVE (if requested)
    * =========================================================================

    if "`saveas'" != "" {
        display as text "{hline 70}"
        display as text "{bf:Step 6: Saving analysis-ready dataset}"
        display as text "{hline 70}"
        display as text ""

        if "`replace'" != "" {
            save "`saveas'", replace
        }
        else {
            save "`saveas'"
        }

        display as result "Dataset saved to: `saveas'"
        display as text ""
    }
    else {
        display as text "{hline 70}"
        display as text "{bf:Step 6: Save skipped (use saveas() to save dataset)}"
        display as text "{hline 70}"
        display as text ""
    }

    * =========================================================================
    * FINAL SUMMARY
    * =========================================================================

    display as text "{hline 70}"
    display as text "{bf:PIPELINE SUMMARY}"
    display as text "{hline 70}"
    display as text ""
    display as text "Input cohort:       " as result `n_cohort' " obs, " `n_ids' " individuals"
    display as text "Output dataset:     " as result _N " obs, " `n_ids_after' " individuals"

    if "`event'" != "" {
        display as text "Events:             " as result `n_events'
        if "`compete'" != "" {
            display as text "Competing events:   " as result `n_compete'
        }
    }

    display as text ""
    display as text "Key variables created:"
    display as text "  start          - Interval start date"
    display as text "  stop           - Interval stop date"
    display as text "  tv_exposure    - Time-varying exposure status"

    if "`event'" != "" {
        display as text "  _event         - Event indicator (1 = event in interval)"
        if "`compete'" != "" {
            display as text "  _compete       - Competing event indicator"
        }
    }

    display as text ""
    display as text "Steps completed:"
    display as text "  [1] tvexpose   - " as result "Done"
    if "`event'" != "" {
        display as text "  [2] tvevent    - " as result "Done"
    }
    else {
        display as text "  [2] tvevent    - Skipped"
    }
    if "`diagnose'" != "" {
        display as text "  [3] tvdiagnose - " as result "Done"
    }
    else {
        display as text "  [3] tvdiagnose - Skipped"
    }
    if "`balance'" != "" {
        display as text "  [4] tvbalance  - " as result "Done"
    }
    else {
        display as text "  [4] tvbalance  - Skipped"
    }
    if "`plot'" != "" {
        display as text "  [5] tvplot     - " as result "Done"
    }
    else {
        display as text "  [5] tvplot     - Skipped"
    }
    if "`saveas'" != "" {
        display as text "  [6] Save       - " as result "Done"
    }
    else {
        display as text "  [6] Save       - Skipped"
    }

    display as text ""
    display as result "Pipeline completed successfully!"
    display as text "{hline 70}"

    * =========================================================================
    * RETURN VALUES
    * =========================================================================

    return scalar n_cohort = `n_cohort'
    return scalar n_ids = `n_ids'
    return scalar n_output = _N
    return scalar n_ids_output = `n_ids_after'
    return scalar n_events = `n_events'
    return scalar n_compete = `n_compete'

    return local id "`id'"
    return local entry "`entry'"
    return local exit "`exit'"
    return local exposure "`exposure'"
    return local reference "`reference'"
    return local expfile "`expfile'"

    if "`event'" != "" {
        return local event "`event'"
    }
    if "`compete'" != "" {
        return local compete "`compete'"
    }
    if "`saveas'" != "" {
        return local saveas "`saveas'"
    }
end
