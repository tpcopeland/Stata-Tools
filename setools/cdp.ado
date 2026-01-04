*! cdp Version 1.0.0  2025/12/17
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
  allevent             - Track all CDP events, not just first
  keepall              - Retain all observations (default: keep only those with CDP)
  quietly              - Suppress output messages

See help cdp for complete documentation
*/

program define cdp, rclass
    version 16.0
    set varabbrev off

    syntax varlist(min=3 max=3) [if] [in], ///
        DXdate(varname) ///
        [ ///
        GENerate(string) ///
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
    capture confirm numeric variable `dxdate'
    if _rc {
        di as error "`dxdate' must be numeric (Stata date format)"
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

    // Mark sample
    marksample touse
    markout `touse' `dxdate'

    // Check for valid observations
    qui count if `touse'
    if r(N) == 0 {
        di as error "no valid observations"
        exit 2000
    }

    // =========================================================================
    // MAIN ALGORITHM
    // =========================================================================

    // Temporary variables
    tempvar baseline_edss baseline_date prog_thresh edss_change ///
            is_prog first_prog_dt confirm_edss confirmed obs_id ///
            current_baseline current_base_dt event_num

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
    qui bysort `idvar' (`datevar'): gen double _temp_base = `edssvar' ///
        if `datevar' >= `dxdate' & `datevar' <= `dxdate' + `baselinewindow'
    qui bysort `idvar' (`datevar'): replace `baseline_edss' = _temp_base[1] ///
        if !missing(_temp_base[1])
    qui bysort `idvar' (`datevar'): gen long _temp_basedt = `datevar' ///
        if `datevar' >= `dxdate' & `datevar' <= `dxdate' + `baselinewindow'
    qui bysort `idvar' (`datevar'): replace `baseline_date' = _temp_basedt[1] ///
        if !missing(_temp_basedt[1])
    qui drop _temp_base _temp_basedt

    // If no EDSS within window, use earliest available
    qui bysort `idvar' (`datevar'): replace `baseline_edss' = `edssvar'[1] ///
        if missing(`baseline_edss')
    qui bysort `idvar' (`datevar'): replace `baseline_date' = `datevar'[1] ///
        if missing(`baseline_date')

    // Propagate baseline to all rows
    qui bysort `idvar' (`datevar'): replace `baseline_edss' = `baseline_edss'[1]
    qui bysort `idvar' (`datevar'): replace `baseline_date' = `baseline_date'[1]

    // -------------------------------------------------------------------------
    // Step 2: Calculate progression threshold based on baseline
    // -------------------------------------------------------------------------

    // Threshold: ≥1.0 if baseline ≤5.5, ≥0.5 if baseline >5.5
    qui gen double `prog_thresh' = cond(`baseline_edss' <= 5.5, 1.0, 0.5)

    // -------------------------------------------------------------------------
    // Step 3: Identify progression events
    // -------------------------------------------------------------------------

    if "`roving'" == "" {
        // Standard CDP: compare all measurements to initial baseline

        // Calculate change from baseline
        qui gen double `edss_change' = `edssvar' - `baseline_edss'

        // Flag measurements that meet progression threshold (after baseline)
        qui gen byte `is_prog' = (`edss_change' >= `prog_thresh') & ///
            (`datevar' > `baseline_date')

        // Find first potential progression date per person
        qui egen long `first_prog_dt' = min(cond(`is_prog' == 1, `datevar', .)), by(`idvar')

        // Check for confirmation: any EDSS at or above progression level
        // at least confirmdays after the progression date
        qui gen double `confirm_edss' = .
        qui replace `confirm_edss' = `edssvar' if `datevar' >= `first_prog_dt' + `confirmdays'
        qui egen double _min_confirm = min(`confirm_edss'), by(`idvar')

        // Confirmed if minimum EDSS in confirmation period still meets threshold
        qui gen byte `confirmed' = (_min_confirm >= `baseline_edss' + `prog_thresh') & ///
            !missing(_min_confirm)
        qui drop _min_confirm

        // CDP date is first progression date if confirmed
        tempvar cdp_dt
        qui gen long `cdp_dt' = `first_prog_dt' if `confirmed' == 1
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

        // Initialize results file
        clear
        qui gen long `idvar' = .
        qui gen long `generate' = .
        qui gen byte `event_num' = .
        qui gen double baseline_edss_at_event = .
        qui save `results_all', replace emptyok

        local event_counter = 1
        local keep_going = 1

        while `keep_going' == 1 {
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
            qui egen double _min_confirm = min(`confirm_edss'), by(`idvar')

            // Confirmed if minimum EDSS in confirmation period still meets threshold
            qui gen byte `confirmed' = (_min_confirm >= `baseline_edss' + `prog_thresh') & ///
                !missing(_min_confirm)
            qui drop _min_confirm

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

                if "`allevent'" == "" {
                    // Only tracking first event, stop after first round
                    local keep_going = 0
                }
            }
        }

        // Load results
        qui use `results_all', clear

        if "`allevent'" == "" {
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

    if "`allevent'" != "" & "`roving'" != "" {
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

    if "`keepall'" == "" {
        // Default: keep only patients with CDP
        qui merge m:1 `idvar' using `results', nogen keep(3)
    }
    else {
        // keepall: retain all original observations
        qui merge m:1 `idvar' using `results', nogen
    }

    // Label variable
    label var `generate' "Confirmed disability progression date"

    if "`allevent'" != "" & "`roving'" != "" {
        capture confirm variable `event_num'
        if !_rc label var `event_num' "CDP event number"
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
        if "`allevent'" != "" & "`roving'" != "" {
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

end
