*! cdp Version 1.4.1  2026/07/03
*! Confirmed Disability Progression from baseline EDSS
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
Confirmed Disability Progression (CDP) Algorithm:

1. Baseline EDSS: First measurement within baselinewindow of diagnosis date
   (or earliest available if none within window)
2. Progression threshold (two-tier default; threetier for Lublin/Kappos rule):
   - two-tier:  ≥1.0 if baseline ≤5.5, ≥0.5 if baseline >5.5
   - threetier: ≥1.5 if baseline 0, ≥1.0 if 1.0-5.5, ≥0.5 if >5.5
3. Confirmation (confirmtype): sustained (min of all later EDSS, default) or
   visit (EDSS at the first measurement ≥confirmdays later)

Basic syntax:
  cdp idvar edssvar datevar, dxdate(varname) [options]

Required:
  dxdate(varname)      - Diagnosis date variable

Options:
  generate(name)       - Name for CDP date variable (default: cdp_date)
  confirmdays(#)       - Days for confirmation (default: 180 = 6 months)
  confirmtype(type)    - sustained (default) or visit
  baselinewindow(#)    - Days from diagnosis for baseline EDSS (default: 730 = 24 months)
  threetier            - Use the three-tier progression threshold (default two-tier)
  eventvar(name)       - Create a 0/1 stset-ready CDP event indicator
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
        THREEtier ///
        CONFIRMType(string) ///
        EVENTvar(name) ///
        EXIT(varname) ///
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

    // Confirmation type
    if "`confirmtype'" == "" {
        local confirmtype "sustained"
    }
    local confirmtype = lower("`confirmtype'")
    if !inlist("`confirmtype'", "sustained", "visit") {
        di as error "confirmtype() must be sustained or visit"
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

    // Check eventvar name (must be new and distinct from generate)
    if "`eventvar'" != "" {
        if "`eventvar'" == "`generate'" {
            di as error "eventvar() and generate() must specify different names"
            exit 198
        }
        capture confirm variable `eventvar'
        if _rc == 0 {
            di as error "variable `eventvar' already exists"
            exit 110
        }
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

    // Validate exit() study-exit date (used to censor post-exit events)
    local n_censored_exit = 0
    if "`exit'" != "" {
        capture confirm numeric variable `exit'
        if _rc {
            di as error "exit() must be a numeric Stata daily date variable"
            exit 109
        }
        local _cdp_exit_fmt : format `exit'
        if lower(substr("`_cdp_exit_fmt'", 1, 3)) != "%td" {
            di as error "exit() must be a Stata daily date variable with %td format"
            exit 109
        }
        qui count if `touse' & !missing(`exit') & `exit' != floor(`exit')
        if r(N) > 0 {
            di as error "exit() must contain whole-number Stata daily dates"
            exit 109
        }
    }

    // Check for valid observations
    qui count if `touse'
    if r(N) == 0 {
        di as error "no valid observations"
        exit 2000
    }

    // =========================================================================
    // MAIN ALGORITHM
    // NOTE: Baseline determination, progression threshold, and confirmation
    // are factored into shared helpers (_setools_cdp_baseline,
    // _setools_cdp_thresh, _setools_cdp_confirm, _setools_cdp_core) so cdp and
    // pira share one engine and cannot silently desync. The non-roving path
    // calls _setools_cdp_core; the roving path below reuses the thresh/confirm
    // helpers inline.
    // =========================================================================

    // Temporary variables
    tempvar baseline_edss baseline_date prog_thresh edss_change ///
            is_prog first_prog_dt confirm_edss confirmed obs_id ///
            current_baseline current_base_dt event_num ///
            in_window first_win_dt first_win_edss first_any_dt ///
            first_any_edss min_confirm sortorder

    // Preserve original data
    qui gen long `sortorder' = _n
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
    // (shared helper: _setools_cdp_baseline)
    // -------------------------------------------------------------------------
    _setools_cdp_baseline `idvar' `edssvar' `datevar', dxdate(`dxdate') ///
        baselinewindow(`baselinewindow') edssout(`baseline_edss') dateout(`baseline_date')

    // -------------------------------------------------------------------------
    // Step 2: Identify progression events
    // -------------------------------------------------------------------------

    if "`roving'" == "" {
        // Standard CDP: shared engine (threshold -> iterative confirmation),
        // factored into _setools_cdp_core so cdp and pira cannot silently
        // desync. Reduces data to one row per person carrying the CDP date.
        _setools_cdp_core `idvar' `edssvar' `datevar', ///
            baseedss(`baseline_edss') basedate(`baseline_date') ///
            confirmdays(`confirmdays') genname(`generate') ///
            `threetier' confirmtype("`confirmtype'")
        local cdp_converged  = r(converged)
        local cdp_iterations = r(iterations)

        // Event number (always 1 for non-roving)
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
        local roving_converged = 1

        while `keep_going' == 1 {
            if `event_counter' > `max_roving_iter' {
                di as error "Warning: roving baseline exceeded `max_roving_iter' iterations"
                local roving_converged = 0
                local keep_going = 0
                continue
            }
            qui use `working', clear

            // Recalculate progression threshold based on current baseline
            // (shared helper: two- or three-tier)
            _setools_cdp_thresh `baseline_edss', generate(`prog_thresh') `threetier'

            // Calculate change from current baseline
            qui gen double `edss_change' = `edssvar' - `baseline_edss'

            // Flag measurements that meet progression threshold (after baseline)
            qui gen byte `is_prog' = (`edss_change' >= `prog_thresh') & ///
                (`datevar' > `baseline_date')

            // Find first potential progression date per person
            qui egen long `first_prog_dt' = min(cond(`is_prog' == 1, `datevar', .)), by(`idvar')

            // Check for confirmation (sustained or visit; shared helper)
            _setools_cdp_confirm `idvar' `edssvar' `datevar', ///
                canddate(`first_prog_dt') confirmdays(`confirmdays') ///
                generate(`min_confirm') confirmtype("`confirmtype'")

            // Confirmed if confirmation EDSS still meets threshold
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

                // Update baseline for next iteration (first obs after event).
                // `edssvar' is a secondary sort key so same-day duplicate visits
                // deterministically re-baseline on the lower EDSS (the package-wide
                // tie convention; an unkeyed tie would be sort-order dependent).
                qui bysort `idvar' (`datevar' `edssvar'): replace `baseline_edss' = `edssvar'[1] ///
                    if !missing(`generate')
                qui bysort `idvar' (`datevar' `edssvar'): replace `baseline_date' = `datevar'[1] ///
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

        local cdp_converged  = `roving_converged'
        local cdp_iterations = `event_counter'

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
        // Keyed on `sortorder' so the retained covariate row per person is
        // deterministically the first row of the original data, not whichever
        // row Stata's non-stable sort happens to leave first.
        qui bysort `idvar' (`sortorder'): keep if _n == 1
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
    // exit() censoring: drop the CDP date when it falls after a person's
    // study-exit date (replaces hand-written post-exit clipping). Observations
    // are retained; eventvar() and the person/event counts reflect censoring.
    // Done before the sort-order restore so the by-person tag does not disturb
    // output order. In the default (one-row-per-person) layout `generate' is
    // constant within person; in allevents+roving it is event-level.
    if "`exit'" != "" {
        if "`allevents'" != "" & "`roving'" != "" {
            qui count if !missing(`generate') & !missing(`exit') & `generate' > `exit'
            local n_censored_exit = r(N)
            qui replace `generate' = . if !missing(`generate') & !missing(`exit') & `generate' > `exit'
            qui count if !missing(`generate')
            local n_events = r(N)
            tempvar _cdp_exit_tag
            qui bysort `idvar' (`generate'): gen byte `_cdp_exit_tag' = (_n == 1) & !missing(`generate')
            qui count if `_cdp_exit_tag'
            local n_persons = r(N)
            qui drop `_cdp_exit_tag'
        }
        else {
            tempvar _cdp_exit_tag
            qui bysort `idvar': gen byte `_cdp_exit_tag' = (_n == 1)
            qui count if `_cdp_exit_tag' & !missing(`generate') & !missing(`exit') & `generate' > `exit'
            local n_censored_exit = r(N)
            qui replace `generate' = . if !missing(`generate') & !missing(`exit') & `generate' > `exit'
            qui count if `_cdp_exit_tag' & !missing(`generate')
            local n_persons = r(N)
            local n_events = `n_persons'
            qui drop `_cdp_exit_tag'
        }
    }

    qui sort `sortorder'
    qui drop `sortorder'

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

    // stset-ready event indicator (0/1 within the analytic sample)
    if "`eventvar'" != "" {
        qui gen byte `eventvar' = !missing(`generate') if `touse'
        label var `eventvar' "CDP event (1 = confirmed progression)"
    }

    // =========================================================================
    // OUTPUT AND RETURN
    // =========================================================================

    if "`quietly'" == "" {
        di as text _n "Confirmed Disability Progression (CDP) complete"
        di as text "  Baseline window: `baselinewindow' days from diagnosis"
        di as text "  Confirmation period: `confirmdays' days"
        di as text "  Confirmation type: `confirmtype'"
        di as text "  Threshold rule: " cond("`threetier'" != "", "three-tier", "two-tier")
        di as text "  Roving baseline: " cond("`roving'" != "", "Yes", "No")
        di as text "  Persons with CDP: `n_persons'"
        if "`allevents'" != "" & "`roving'" != "" {
            di as text "  Total CDP events: `n_events'"
        }
        if "`exit'" != "" {
            di as text "  Events censored after study exit: `n_censored_exit'"
        }
        di as text "  Variable created: `generate'"
        if "`eventvar'" != "" {
            di as text "  Event indicator: `eventvar'"
        }
        if `cdp_converged' == 0 {
            di as text "  Note: confirmation did not converge (results may be approximate)"
        }
    }

    // Return values
    return scalar N_persons = `n_persons'
    return scalar N_events = `n_events'
    return scalar confirmdays = `confirmdays'
    return scalar baselinewindow = `baselinewindow'
    return scalar converged = `cdp_converged'
    return local varname "`generate'"
    return local confirmtype "`confirmtype'"
    return local threetier = cond("`threetier'" != "", "yes", "no")
    return local roving = cond("`roving'" != "", "yes", "no")
    if "`eventvar'" != "" {
        return local eventvar "`eventvar'"
    }
    if "`exit'" != "" {
        return local exit "`exit'"
        return scalar N_censored_exit = `n_censored_exit'
    }

    }
    local _rc = _rc
    capture drop `sortorder'
    set varabbrev `_varabbrev'
    if `_rc' exit `_rc'
end
