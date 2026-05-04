*! cdp Version 1.2.2  2026/05/04
*! Confirmed Disability Progression from baseline EDSS
*! Author: Tim Copeland
*! Program class: rclass

/*
Confirmed Disability Progression (CDP) Algorithm:

1. Baseline EDSS: First measurement within baselinewindow of diagnosis date
   (or earliest available if none within window)
2. Progression threshold:
   - If baseline EDSS ≤5.5: requires ≥1.0 point increase
   - If baseline EDSS >5.5: requires ≥0.5 point increase
3. Confirmation: Must be sustained at subsequent measurement ≥confirmdays later

Basic syntax:
  cdp idvar edssvar datevar, dxdate(varname) [options]

Required:
  dxdate(varname)      - Diagnosis date variable

Options:
  generate(name)       - Name for CDP date variable (default: cdp_date)
  confirmdays(#)       - Days for confirmation (default: 180 = 6 months)
  baselinewindow(#)    - Days from diagnosis for baseline EDSS (default: 730 = 24 months)
  roving               - Use roving baseline (reset after each confirmed progression)
  allevents            - Track all CDP events, not just first
  keepall              - Retain all observations (default: keep only those with CDP)
  quietly              - Suppress output messages

See help cdp for complete documentation
*/

program define cdp, rclass
    version 16.0
    local _varabbrev `c(varabbrev)'
    set varabbrev off

    capture noisily {

    syntax varlist(min=3 max=3) [if] [in], ///
        DXdate(varname) ///
        [ ///
        GENerate(name) ///
        CONFirmdays(integer 180) ///
        BASElinewindow(integer 730) ///
        ROVING ///
        ALLevents ///
        KEEPall ///
        Quietly ///
        ]

    // =========================================================================
    // PARSE AND VALIDATE
    // =========================================================================

    // Parse varlist: id edss date
    tokenize `varlist'
    local idvar `1'
    local edssvar `2'
    local datevar `3'

    // Validate variable types
    capture confirm numeric variable `edssvar'
    if _rc {
        di as error "`edssvar' must be numeric"
        exit 109
    }
    capture confirm numeric variable `datevar'
    if _rc {
        di as error "`datevar' must be numeric (Stata date format)"
        exit 109
    }
    local _cdp_date_fmt : format `datevar'
    if lower(substr("`_cdp_date_fmt'", 1, 3)) != "%td" {
        di as error "`datevar' must be a Stata daily date variable with %td format"
        exit 109
    }
    capture confirm numeric variable `dxdate'
    if _rc {
        di as error "`dxdate' must be numeric (Stata date format)"
        exit 109
    }
    local _cdp_dx_fmt : format `dxdate'
    if lower(substr("`_cdp_dx_fmt'", 1, 3)) != "%td" {
        di as error "`dxdate' must be a Stata daily date variable with %td format"
        exit 109
    }

    // Validate options
    if `confirmdays' <= 0 {
        di as error "confirmdays() must be positive"
        exit 198
    }
    if `baselinewindow' <= 0 {
        di as error "baselinewindow() must be positive"
        exit 198
    }

    // Warn if allevents without roving (has no effect)
    if "`allevents'" != "" & "`roving'" == "" {
        di as text "Note: allevents has no effect without roving"
    }

    // Default generate name
    if "`generate'" == "" {
        local generate "cdp_date"
    }

    // Check if generate variable already exists
    capture confirm variable `generate'
    if _rc == 0 {
        di as error "variable `generate' already exists"
        exit 110
    }

    // Mark sample (strok: allow string ID variables)
    marksample touse, strok
    markout `touse' `dxdate'
    qui count if `touse' & !missing(`datevar') & `datevar' != floor(`datevar')
    if r(N) > 0 {
        di as error "`datevar' must contain whole-number Stata daily dates"
        exit 109
    }
    qui count if `touse' & !missing(`dxdate') & `dxdate' != floor(`dxdate')
    if r(N) > 0 {
        di as error "`dxdate' must contain whole-number Stata daily dates"
        exit 109
    }

    // Check for valid observations
    qui count if `touse'
    if r(N) == 0 {
        di as error "no valid observations"
        exit 2000
    }

    // =========================================================================
    // MAIN ALGORITHM
    // NOTE: The CDP algorithm below is also implemented in pira.ado (lines
    // ~200-314). Changes to the baseline determination, progression threshold,
    // or confirmation logic here MUST be mirrored in pira.ado.
    // =========================================================================

    // Temporary variables
    tempvar baseline_edss baseline_date prog_thresh edss_change ///
            is_prog first_prog_dt confirm_edss confirmed obs_id ///
            current_baseline current_base_dt event_num ///
            in_window first_win_dt min_confirm

    // Preserve original data
    preserve

    // Keep only relevant observations
    qui keep if `touse'
    qui keep `idvar' `edssvar' `datevar' `dxdate'

    // Drop missing EDSS or date values
    qui drop if missing(`edssvar') | missing(`datevar')

    // Check for valid observations
    qui count
    if r(N) == 0 {
        di as error "no valid observations after dropping missing values"
        restore
        exit 2000
    }

    // Sort data
    qui sort `idvar' `datevar' `edssvar'

    // Generate observation ID for tracking
    qui gen long `obs_id' = _n

    // -------------------------------------------------------------------------
    // Step 1: Determine baseline EDSS for each person
    // -------------------------------------------------------------------------

    // First, try to find EDSS within baseline window of diagnosis
    qui gen double `baseline_edss' = .
    qui gen long `baseline_date' = .

    // For each person, find first EDSS within window
    // Use egen min() to find earliest date in window, then extract EDSS at that date
    qui gen byte `in_window' = (`datevar' >= `dxdate' & `datevar' <= `dxdate' + `baselinewindow')
    qui egen long `first_win_dt' = min(cond(`in_window', `datevar', .)), by(`idvar')
    qui replace `baseline_edss' = `edssvar' if `datevar' == `first_win_dt' & !missing(`first_win_dt')
    qui replace `baseline_date' = `first_win_dt' if !missing(`first_win_dt')
    qui bysort `idvar' (`datevar'): replace `baseline_edss' = `baseline_edss'[1] ///
        if missing(`baseline_edss') & !missing(`baseline_edss'[1])
    qui bysort `idvar' (`datevar'): replace `baseline_date' = `baseline_date'[1] ///
        if missing(`baseline_date') & !missing(`baseline_date'[1])
    qui drop `in_window' `first_win_dt'

    // If no EDSS within window, use earliest available
    qui bysort `idvar' (`datevar'): replace `baseline_edss' = `edssvar'[1] ///
        if missing(`baseline_edss')
    qui bysort `idvar' (`datevar'): replace `baseline_date' = `datevar'[1] ///
        if missing(`baseline_date')

    // Propagate baseline to all rows
    qui bysort `idvar' (`datevar'): replace `baseline_edss' = `baseline_edss'[1]
    qui bysort `idvar' (`datevar'): replace `baseline_date' = `baseline_date'[1]

    // -------------------------------------------------------------------------
    // Step 2: Identify progression events
    // -------------------------------------------------------------------------

    if "`roving'" == "" {
        // Standard CDP: compare all measurements to initial baseline
        // Uses iterative approach: if the first candidate progression date
        // fails confirmation, exclude it and try the next candidate.

        // Progression threshold: ≥1.0 if baseline ≤5.5, ≥0.5 if baseline >5.5
        qui gen double `prog_thresh' = cond(`baseline_edss' <= 5.5, 1.0, 0.5)

        // Calculate change from baseline
        qui gen double `edss_change' = `edssvar' - `baseline_edss'

        // Flag measurements that meet progression threshold (after baseline)
        qui gen byte `is_prog' = (`edss_change' >= `prog_thresh') & ///
            (`datevar' > `baseline_date')

        // Iterative confirmation: try each candidate progression date in order
        // until one is confirmed or none remain
        tempvar candidate_dt confirm_edss min_confirm candidate_ok
        qui gen byte `candidate_ok' = 0

        local max_cdp_iter = 100
        local cdp_iter = 1
        local cdp_found = 0
        while `cdp_found' == 0 & `cdp_iter' <= `max_cdp_iter' {
            // Find earliest remaining candidate progression date per person
            capture drop `candidate_dt'
            qui egen long `candidate_dt' = min(cond(`is_prog' == 1, `datevar', .)), by(`idvar')

            // Check if any candidates remain
            qui count if !missing(`candidate_dt')
            if r(N) == 0 {
                continue, break
            }

            // Check for confirmation (sustained-throughout definition):
            // The MINIMUM of all EDSS measurements at or after confirmdays must
            // still meet the progression threshold.
            capture drop `confirm_edss'
            capture drop `min_confirm'
            qui gen double `confirm_edss' = .
            qui replace `confirm_edss' = `edssvar' if `datevar' >= `candidate_dt' + `confirmdays'
            qui egen double `min_confirm' = min(`confirm_edss'), by(`idvar')

            // Check if confirmed for each person
            capture drop `candidate_ok'
            qui gen byte `candidate_ok' = (`min_confirm' >= `baseline_edss' + `prog_thresh') & ///
                !missing(`min_confirm')

            // Check if ANY person has a confirmed event
            qui count if `candidate_ok' == 1 & `datevar' == `candidate_dt'
            local n_confirmed = r(N)

            // For persons whose candidate failed: exclude that date and retry
            // For persons whose candidate succeeded: mark as found
            qui count if `candidate_ok' == 0 & !missing(`candidate_dt') & `datevar' == `candidate_dt'
            local n_failed = r(N)

            if `n_failed' == 0 {
                // All remaining candidates are confirmed (or no candidates)
                local cdp_found = 1
            }
            else {
                // Exclude failed candidate dates from future consideration
                qui replace `is_prog' = 0 if `candidate_ok' == 0 & `datevar' == `candidate_dt'
                local cdp_iter = `cdp_iter' + 1
            }

            qui drop `min_confirm'
        }

        // CDP date is the confirmed candidate date
        tempvar cdp_dt
        qui gen long `cdp_dt' = `candidate_dt' if `candidate_ok' == 1
        format `cdp_dt' %tdCCYY/NN/DD

        // Keep one record per person
        qui keep `idvar' `cdp_dt' `baseline_edss' `prog_thresh'
        qui duplicates drop `idvar', force
        qui drop if missing(`cdp_dt')
        qui rename `cdp_dt' `generate'

        // Generate event number (always 1 for non-roving)
        qui gen byte `event_num' = 1
    }
    else {
        // Roving baseline: reset baseline after each confirmed progression
        // This is more complex - implement iterative approach

        tempfile working results_all
        qui save `working', replace

        // Detect ID variable type before clearing data
        local id_is_str = 0
        capture confirm string variable `idvar'
        if !_rc local id_is_str = 1

        // Initialize results file
        clear
        if `id_is_str' {
            qui gen `idvar' = ""
        }
        else {
            qui gen long `idvar' = .
        }
        qui gen long `generate' = .
        qui gen byte `event_num' = .
        qui gen double baseline_edss_at_event = .
        qui save `results_all', replace emptyok

        local event_counter = 1
        local keep_going = 1
        local max_roving_iter = 100

        while `keep_going' == 1 {
            if `event_counter' > `max_roving_iter' {
                di as error "Warning: roving baseline exceeded `max_roving_iter' iterations"
                local keep_going = 0
                continue
            }
            qui use `working', clear

            // Recalculate progression threshold based on current baseline
            qui gen double `prog_thresh' = cond(`baseline_edss' <= 5.5, 1.0, 0.5)

            // Calculate change from current baseline
            qui gen double `edss_change' = `edssvar' - `baseline_edss'

            // Flag measurements that meet progression threshold (after baseline)
            qui gen byte `is_prog' = (`edss_change' >= `prog_thresh') & ///
                (`datevar' > `baseline_date')

            // Find first potential progression date per person
            qui egen long `first_prog_dt' = min(cond(`is_prog' == 1, `datevar', .)), by(`idvar')

            // Check for confirmation
            qui gen double `confirm_edss' = .
            qui replace `confirm_edss' = `edssvar' if `datevar' >= `first_prog_dt' + `confirmdays'
            qui egen double `min_confirm' = min(`confirm_edss'), by(`idvar')

            // Confirmed if minimum EDSS in confirmation period still meets threshold
            qui gen byte `confirmed' = (`min_confirm' >= `baseline_edss' + `prog_thresh') & ///
                !missing(`min_confirm')
            qui drop `min_confirm'

            // Count confirmed events
            qui count if `confirmed' == 1 & `datevar' == `first_prog_dt'
            local n_new = r(N)

            if `n_new' == 0 {
                local keep_going = 0
            }
            else {
                // Save confirmed events
                tempfile new_events
                qui keep if `confirmed' == 1 & `datevar' == `first_prog_dt'
                qui keep `idvar' `first_prog_dt' `baseline_edss'
                qui duplicates drop `idvar', force
                qui gen byte `event_num' = `event_counter'
                qui rename `first_prog_dt' `generate'
                qui rename `baseline_edss' baseline_edss_at_event
                qui save `new_events', replace

                // Append to results
                qui use `results_all', clear
                qui append using `new_events'
                qui save `results_all', replace

                // Update working dataset: remove events, update baseline
                qui use `working', clear
                qui merge m:1 `idvar' using `new_events', nogen keep(1 3)

                // For those with events, drop observations up to and including event
                // and reset baseline
                qui drop if !missing(`generate') & `datevar' <= `generate'

                // Update baseline for next iteration (first obs after event)
                qui bysort `idvar' (`datevar'): replace `baseline_edss' = `edssvar'[1] ///
                    if !missing(`generate')
                qui bysort `idvar' (`datevar'): replace `baseline_date' = `datevar'[1] ///
                    if !missing(`generate')

                qui drop `generate' baseline_edss_at_event `event_num'
                qui save `working', replace

                local event_counter = `event_counter' + 1

                if "`allevents'" == "" {
                    // Only tracking first event, stop after first round
                    local keep_going = 0
                }
            }
        }

        // Load results
        qui use `results_all', clear

        if "`allevents'" == "" {
            // Keep only first event per person
            qui bysort `idvar' (`event_num'): keep if _n == 1
            qui drop `event_num' baseline_edss_at_event
        }
    }

    // Format date
    format `generate' %tdCCYY/NN/DD

    // Count results
    qui count
    local n_events = r(N)

    if "`allevents'" != "" & "`roving'" != "" {
        qui duplicates report `idvar'
        local n_persons = r(unique_value)
    }
    else {
        local n_persons = `n_events'
    }

    // Save results
    tempfile results
    qui save `results', replace

    restore

    // =========================================================================
    // MERGE RESULTS BACK
    // =========================================================================

    if "`allevents'" != "" & "`roving'" != "" {
        // Event-level output: one row per CDP event per person
        // Reduce master to unique persons for 1:m merge (preserve all variables)
        if "`quietly'" == "" {
            di as text "Note: allevents reshapes data to event-level (one row per CDP event)"
        }
        qui bysort `idvar': keep if _n == 1
        if "`keepall'" == "" {
            qui merge 1:m `idvar' using `results', nogen keep(3)
        }
        else {
            qui merge 1:m `idvar' using `results', nogen
        }
    }
    else {
        if "`keepall'" == "" {
            // Default: keep only patients with CDP
            qui merge m:1 `idvar' using `results', nogen keep(3)
        }
        else {
            // keepall: retain all original observations
            qui merge m:1 `idvar' using `results', nogen
        }
    }

    // Label variable
    label var `generate' "Confirmed disability progression date"

    if "`allevents'" != "" & "`roving'" != "" {
        // Rename tempvar to user-visible name
        capture confirm variable `event_num'
        if !_rc {
            rename `event_num' event_num
            label var event_num "CDP event number"
        }
        capture confirm variable baseline_edss_at_event
        if !_rc label var baseline_edss_at_event "Baseline EDSS at CDP event"
    }

    // =========================================================================
    // OUTPUT AND RETURN
    // =========================================================================

    if "`quietly'" == "" {
        di as text _n "Confirmed Disability Progression (CDP) complete"
        di as text "  Baseline window: `baselinewindow' days from diagnosis"
        di as text "  Confirmation period: `confirmdays' days"
        di as text "  Roving baseline: " cond("`roving'" != "", "Yes", "No")
        di as text "  Persons with CDP: `n_persons'"
        if "`allevents'" != "" & "`roving'" != "" {
            di as text "  Total CDP events: `n_events'"
        }
        di as text "  Variable created: `generate'"
    }

    // Return values
    return scalar N_persons = `n_persons'
    return scalar N_events = `n_events'
    return scalar confirmdays = `confirmdays'
    return scalar baselinewindow = `baselinewindow'
    return local varname "`generate'"
    return local roving = cond("`roving'" != "", "yes", "no")

    }
    local _rc = _rc
    set varabbrev `_varabbrev'
    if `_rc' exit `_rc'
end
