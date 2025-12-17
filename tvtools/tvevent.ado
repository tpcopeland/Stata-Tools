*! tvevent Version 1.3.5  17dec2025
*! Add event/failure flags to time-varying datasets
*! Author: Tim Copeland
*!
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tvevent using intervals.dta, id(varname) date(varname) ///
    [generate(newvar) type(single|recurring) keepvars(varlist) ///
     continuous(varlist) timegen(newvar) timeunit(string) ///
     compete(varlist) eventlabel(string) replace]

Data structure:
  Master (in memory): Event data with id(), date(), compete(), keepvars()
  Using:              Interval data from tvexpose/tvmerge with id, start, stop, continuous()

Description:
  Integrates event data (master) into tvexpose/tvmerge intervals (using).
  1. Identifies events occurring within intervals (start < date < stop).
  2. Resolves competing risks (earliest date wins).
  3. Splits intervals at the event date.
  4. Proportionally adjusts 'continuous' variables.
  5. Flags the event type (1=Primary, 2+=Competing).
*/

program define tvevent, rclass
    version 16.0
    set varabbrev off

    syntax using/ , ///
        id(varname) ///
        Date(name) ///
        [GENerate(name) ///
         Type(string) ///
         KEEPvars(namelist) ///
         CONtinuous(namelist) ///
         TIMEGen(name) ///
         TIMEUnit(string) ///
         COMpete(namelist) ///
         EVENTLabel(string asis) ///
         STARTvar(name) ///
         STOPvar(name) ///
         REPlace]

    **# 1. INPUT VALIDATION

    * Set defaults for options
    if "`generate'" == "" local generate "_failure"
    if "`startvar'" == "" local startvar "start"
    if "`stopvar'" == "" local stopvar "stop"

    if "`type'" == "" local type "single"
    local type = lower("`type'")
    if !inlist("`type'", "single", "recurring") {
        di as error "type() must be either 'single' or 'recurring'"
        exit 198
    }

    * For recurring events, detect wide-format event variables (date1, date2, ...)
    local eventvars ""
    local n_eventvars = 0
    if "`type'" == "recurring" {
        local eventnum = 1
        while 1 {
            capture confirm variable `date'`eventnum'
            if _rc {
                continue, break
            }
            local eventvars "`eventvars' `date'`eventnum'"
            local eventnum = `eventnum' + 1
        }
        local eventvars = strtrim("`eventvars'")
        local n_eventvars : word count `eventvars'

        * Validation: error if no event variables found
        if `n_eventvars' == 0 {
            di as error "type(recurring) requires wide-format event variables."
            di as error "No variables found matching pattern `date'1, `date'2, ..."
            di as error "Ensure your event data has variables like `date'1, `date'2, `date'3, etc."
            exit 111
        }

        * Validation: warn if only one event variable
        if `n_eventvars' == 1 {
            di as txt "Note: Only one event variable (`date'1) found with type(recurring)."
            di as txt "      Consider type(single) if events do not recur."
        }

        di as txt "Recurring events: Found `n_eventvars' event variables (`eventvars')"
    }

    if "`timeunit'" == "" local timeunit "days"
    local timeunit = lower("`timeunit'")
    if !inlist("`timeunit'", "days", "months", "years") {
        di as error "timeunit() must be 'days', 'months', or 'years'"
        exit 198
    }
    
    * --- Validate MASTER dataset (event data, currently in memory) ---
    capture confirm variable `id'
    if _rc {
        di as error "ID variable `id' not found in master (event) dataset."
        exit 111
    }

    * Check for duplicate IDs in master (should be 1 row per person for event data)
    * Skip check if dataset is empty
    if _N > 0 {
        tempvar dup_check
        quietly bysort `id': gen `dup_check' = _N
        quietly count if `dup_check' > 1
        if r(N) > 0 {
            local dup_ids = r(N)
            di as txt "Warning: Master (event) dataset has multiple rows per `id' (`dup_ids' observations affected)."
            di as txt "         Event data should have one row per person with event dates in columns."
            if "`type'" == "recurring" {
                di as txt "         For recurring events, use wide format: `date'1, `date'2, etc."
            }
        }
        drop `dup_check'
    }

    * Validate date variable(s) based on event type
    if "`type'" == "recurring" {
        * For recurring: eventvars already validated above
        * Validate each event variable is numeric (date)
        foreach evar of local eventvars {
            capture confirm numeric variable `evar'
            if _rc {
                di as error "Event variable `evar' must be numeric (date format)."
                exit 109
            }
        }
    }
    else {
        * For single: validate date variable exists
        capture confirm variable `date'
        if _rc {
            di as error "Date variable `date' not found in master (event) dataset."
            exit 111
        }
    }

    if "`compete'" != "" {
        foreach v of local compete {
            capture confirm variable `v'
            if _rc {
                di as error "Competing event variable `v' not found in master (event) dataset."
                exit 111
            }
        }
    }
    
    * Default keepvars to all variables in master except id, date/eventvars, and compete
    if "`keepvars'" == "" {
        foreach v of varlist * {
            local is_excluded = 0
            * Exclude id
            if "`v'" == "`id'" local is_excluded = 1
            * Exclude date (for single) or eventvars (for recurring)
            if "`type'" == "recurring" {
                foreach evar of local eventvars {
                    if "`v'" == "`evar'" local is_excluded = 1
                }
            }
            else {
                if "`v'" == "`date'" local is_excluded = 1
            }
            * Exclude compete variables
            foreach c of local compete {
                if "`v'" == "`c'" local is_excluded = 1
            }
            if !`is_excluded' {
                local keepvars "`keepvars' `v'"
            }
        }
        local keepvars = strtrim("`keepvars'")
    }

    quietly {

        **# 2. PREPARE DATASETS

        * Handle empty event dataset (0 observations in master)
        local master_N = _N
        if `master_N' == 0 {
            * No events to process - load intervals and mark all as censored
            noisily di as txt "Note: Event dataset is empty. All intervals will be marked as censored."

            use "`using'", clear

            * Validate using dataset has required variables
            capture confirm variable `id'
            if _rc {
                noisily di as error "ID variable `id' not found in using (interval) dataset."
                exit 111
            }
            foreach v in `startvar' `stopvar' {
                capture confirm variable `v'
                if _rc {
                    noisily di as error "Variable '`v'' not found in using (interval) dataset."
                    exit 111
                }
            }

            * Create outcome variable (all censored = 0)
            if "`replace'" != "" {
                capture drop `generate'
                if "`timegen'" != "" capture drop `timegen'
            }
            gen byte `generate' = 0
            label var `generate' "Event outcome"
            label define `generate'_lbl 0 "Censored"
            label values `generate' `generate'_lbl

            * Create timegen if requested
            if "`timegen'" != "" {
                gen double `timegen' = `stopvar' - `startvar'
                if "`timeunit'" == "months" {
                    replace `timegen' = `timegen' / 30.4375
                    label var `timegen' "Time (months)"
                }
                else if "`timeunit'" == "years" {
                    replace `timegen' = `timegen' / 365.25
                    label var `timegen' "Time (years)"
                }
                else {
                    label var `timegen' "Time (days)"
                }
            }

            sort `id' `startvar' `stopvar'

            count
            local n_total = r(N)
            local n_failures = 0

            return scalar N = `n_total'
            return scalar N_events = `n_failures'

            noisily {
                di _newline
                di as txt "{hline 50}"
                di as txt "Event integration complete"
                di as txt "  Observations: " as result `n_total'
                di as txt "  Events flagged (`generate'): " as result `n_failures'
                di as txt "  Variable `generate' labels:"
                di as txt "    0 = Censored"
                di as txt "{hline 50}"
            }
            exit 0
        }

        if "`type'" == "recurring" {
            * --- RECURRING EVENTS: Reshape wide to long ---

            * Capture label from first event variable
            local first_evar : word 1 of `eventvars'
            local lab_1 : variable label `first_evar'
            if "`lab_1'" == "" local lab_1 "Event: `date'"

            * Note: competing risks not supported with recurring events
            if "`compete'" != "" {
                noisily di as txt "Note: compete() option ignored for recurring events."
                local compete ""
            }
            local num_compete = 0

            * Keep only needed variables for reshape
            keep `id' `eventvars' `keepvars'

            * Reshape wide event dates to long format
            * eventvars are: date1 date2 date3 ...
            * _obs ensures uniqueness when duplicate IDs exist (warned but allowed)
            gen long _obs = _n
            reshape long `date', i(`id' _obs) j(_eventnum)

            * Drop missing event dates and temporary variables
            drop if missing(`date')
            drop _obs _eventnum

            * Floor dates and set event type (all are type 1 for recurring)
            replace `date' = floor(`date')
            gen int _event_type = 1

            * Remove duplicate id-date combinations (same event on same date)
            duplicates drop `id' `date', force

            * Sort by id and date for proper processing
            sort `id' `date'

            tempfile events
            save `events'
        }
        else {
            * --- SINGLE EVENTS: Original logic with competing risks ---

            * Capture labels from master (event) dataset before processing
            local lab_1 : variable label `date'
            if "`lab_1'" == "" local lab_1 "Event: `date'"

            local num_compete : word count `compete'
            if `num_compete' > 0 {
                local i = 1
                foreach v of local compete {
                    local c_lab_`i' : variable label `v'
                    if "`c_lab_`i''" == "" local c_lab_`i' "Competing: `v'"
                    local i = `i' + 1
                }
            }

            * -- COMPETING RISK LOGIC: Determine earliest event per person --
            replace `date' = floor(`date')
            gen double _eff_date = `date'
            gen int _eff_type = 1 if !missing(`date')

            local k = 2
            foreach v of local compete {
                 replace `v' = floor(`v')
                 replace _eff_type = `k' if !missing(`v') & (`v' < _eff_date | missing(_eff_date))
                 replace _eff_date = `v' if !missing(`v') & (`v' < _eff_date | missing(_eff_date))
                 local k = `k' + 1
            }

            * Clean up event data
            keep if !missing(_eff_date)

            * Check if all event dates were missing
            if _N == 0 {
                * All dates were missing - treat like empty event dataset
                noisily di as txt "Note: All event dates are missing. All intervals will be marked as censored."

                use "`using'", clear

                * Validate using dataset has required variables
                capture confirm variable `id'
                if _rc {
                    noisily di as error "ID variable `id' not found in using (interval) dataset."
                    exit 111
                }
                foreach v in `startvar' `stopvar' {
                    capture confirm variable `v'
                    if _rc {
                        noisily di as error "Variable '`v'' not found in using (interval) dataset."
                        exit 111
                    }
                }

                * Create outcome variable (all censored = 0)
                if "`replace'" != "" {
                    capture drop `generate'
                    if "`timegen'" != "" capture drop `timegen'
                }
                gen byte `generate' = 0
                label var `generate' "Event outcome"
                label define `generate'_lbl 0 "Censored"
                label values `generate' `generate'_lbl

                * Create timegen if requested
                if "`timegen'" != "" {
                    gen double `timegen' = `stopvar' - `startvar'
                    if "`timeunit'" == "months" {
                        replace `timegen' = `timegen' / 30.4375
                        label var `timegen' "Time (months)"
                    }
                    else if "`timeunit'" == "years" {
                        replace `timegen' = `timegen' / 365.25
                        label var `timegen' "Time (years)"
                    }
                    else {
                        label var `timegen' "Time (days)"
                    }
                }

                sort `id' `startvar' `stopvar'

                count
                local n_total = r(N)
                local n_failures = 0

                return scalar N = `n_total'
                return scalar N_events = `n_failures'

                noisily {
                    di _newline
                    di as txt "{hline 50}"
                    di as txt "Event integration complete"
                    di as txt "  Observations: " as result `n_total'
                    di as txt "  Events flagged (`generate'): " as result `n_failures'
                    di as txt "  Variable `generate' labels:"
                    di as txt "    0 = Censored"
                    di as txt "{hline 50}"
                }
                exit 0
            }

            capture drop `date'
            rename _eff_date `date'
            rename _eff_type _event_type

            keep `id' `date' _event_type `keepvars'
            duplicates drop `id' `date', force

            tempfile events
            save `events'
        }

        * Load USING dataset (interval data from tvexpose/tvmerge)
        use "`using'", clear

        * Check for observations in using dataset
        quietly count
        if r(N) == 0 {
            noisily di as error "No observations in using (interval) dataset"
            exit 2000
        }

        * --- Validate USING dataset (interval data) ---
        capture confirm variable `id'
        if _rc {
             noisily di as error "ID variable `id' not found in using (interval) dataset."
             exit 111
        }

        foreach v in `startvar' `stopvar' {
            capture confirm variable `v'
            if _rc {
                noisily di as error "Variable '`v'' not found in using (interval) dataset. tvevent requires output from tvexpose/tvmerge."
                noisily di as error "Use startvar() and stopvar() options to specify the variable names if different from 'start' and 'stop'."
                exit 111
            }
        }

        * Capture original formats from using dataset to restore later
        local orig_start_fmt : format `startvar'
        local orig_stop_fmt : format `stopvar'

        if "`continuous'" != "" {
            foreach v of local continuous {
                capture confirm numeric variable `v'
                if _rc {
                    noisily di as error "Continuous variable `v' not found or is not numeric in using (interval) dataset."
                    exit 111
                }
            }
        }

        * Check for variable name collision with date variable from master
        capture confirm variable `date'
        if _rc == 0 {
            noisily di as error "Variable `date' exists in both master (event) and using (interval) datasets."
            noisily di as error "Rename the date variable in one dataset to avoid collision."
            exit 110
        }

        * Check replace option (generate/timegen will be created in interval data)
        if "`replace'" == "" {
            capture confirm variable `generate'
            if _rc == 0 {
                noisily di as error "Variable `generate' already exists in using dataset. Use replace option."
                exit 110
            }
            if "`timegen'" != "" {
                capture confirm variable `timegen'
                if _rc == 0 {
                    noisily di as error "Variable `timegen' already exists in using dataset. Use replace option."
                    exit 110
                }
            }
        }
        else {
            capture drop `generate'
            if "`timegen'" != "" capture drop `timegen'
        }

        * Save interval data for later
        tempfile intervals
        save `intervals'

        **# 3. IDENTIFY SPLIT POINTS

        * intervals tempfile already has the using data loaded
        preserve
        keep `id' `startvar' `stopvar'
        duplicates drop

        joinby `id' using `events'

        keep if `date' > `startvar' & `date' < `stopvar'

        keep `id' `date'
        if _N > 0 {
            duplicates drop `id' `date', force
        }
        tempfile splits
        save `splits'
        
        count
        local n_splits = r(N)
        restore
        
        **# 4. EXECUTE SPLITS
        * intervals data is still in memory

        * Use regular variable names (not tempvars) for values that must persist across file saves
        gen double _orig_dur = `stopvar' - `startvar'
        gen long _orig_interval_id = _n
        gen double _orig_stop = `stopvar'  // Track original stop to detect boundary events

        if `n_splits' > 0 {
            noisily di as txt "Splitting intervals for `n_splits' internal events..."

            * Join with split points - creates row per (interval, split_date) combination
            joinby `id' using `splits', unmatched(master)
            drop _merge

            * Mark valid splits (date falls strictly within this specific interval)
            gen byte _valid_split = (`date' > `startvar' & `date' < `stopvar') & !missing(`date')

            * For intervals with multiple split points, we need to:
            * 1. Collect all split points for each original interval
            * 2. Create sequential non-overlapping segments

            * Count valid splits per original interval
            bysort _orig_interval_id: egen long _n_splits_this = total(_valid_split)

            * Separate intervals that need splitting from those that don't
            tempfile no_splits needs_splits
            preserve
            keep if _n_splits_this == 0
            drop `date' _valid_split _n_splits_this
            * Remove duplicate rows created by joinby for intervals with no valid splits
            if _N > 0 {
                duplicates drop
            }
            save `no_splits'
            restore

            * Process intervals that need splitting
            keep if _n_splits_this > 0 & _valid_split == 1

            * For each original interval, number the split points in order
            bysort _orig_interval_id (`date'): gen long _split_rank = _n
            bysort _orig_interval_id: gen long _total_splits = _N

            * Reshape wide: one row per original interval with all split dates
            * First, save the split dates
            tempfile split_dates
            keep _orig_interval_id `date' _split_rank
            reshape wide `date', i(_orig_interval_id) j(_split_rank)
            save `split_dates'

            * Go back to get one row per original interval with all its data
            use `intervals', clear
            gen long _orig_interval_id = _n
            gen double _orig_dur = `stopvar' - `startvar'

            * Merge in split dates
            merge 1:1 _orig_interval_id using `split_dates', keep(match) nogen

            * Count splits (number of date* variables that exist)
            local max_splits = 0
            foreach v of varlist `date'* {
                local max_splits = `max_splits' + 1
            }

            * Calculate how many segments each interval needs
            gen long _n_segments = 0
            forvalues i = 1/`max_splits' {
                capture confirm variable `date'`i'
                if _rc == 0 {
                    replace _n_segments = _n_segments + 1 if !missing(`date'`i')
                }
            }
            replace _n_segments = _n_segments + 1  // splits + 1 = segments

            * Expand to create one row per segment
            expand _n_segments
            bysort _orig_interval_id: gen long _seg_num = _n

            * Set segment boundaries
            * Segment 1: [original_start, split1]
            * Segment 2: [split1, split2]
            * ...
            * Segment N: [split(N-1), original_stop]

            tempvar new_start new_stop
            gen double `new_start' = `startvar'
            gen double `new_stop' = `stopvar'

            * For each segment, set the correct boundaries
            forvalues i = 1/`max_splits' {
                capture confirm variable `date'`i'
                if _rc == 0 {
                    * Segment i ends at split point i (if it exists)
                    replace `new_stop' = `date'`i' if _seg_num == `i' & !missing(`date'`i')
                    * Segment i+1 starts at split point i (if segment i+1 exists)
                    replace `new_start' = `date'`i' if _seg_num == `i' + 1 & !missing(`date'`i')
                }
            }

            replace `startvar' = `new_start'
            replace `stopvar' = `new_stop'

            * Clean up temporary variables
            drop `new_start' `new_stop' _n_segments _seg_num
            capture drop `date'*

            save `needs_splits'

            * Combine intervals that didn't need splitting with those that did
            use `no_splits', clear
            append using `needs_splits'

            sort `id' `startvar' `stopvar'
            duplicates drop `id' `startvar' `stopvar', force
        }

        * Adjust Continuous Variables
        if "`continuous'" != "" {
            tempvar new_dur ratio
            gen double `new_dur' = `stopvar' - `startvar'
            gen double `ratio' = cond(_orig_dur == 0 | `new_dur' == 0, 1, `new_dur' / _orig_dur)
            foreach v of local continuous {
                replace `v' = `v' * `ratio'
            }
            drop `new_dur' `ratio'
        }
        drop _orig_dur _orig_interval_id

        **# 5. MERGE EVENT FLAGS
        
        tempvar match_date
        gen double `match_date' = `stopvar'
        
        tempname event_frame
        frame create `event_frame'

        * Use capture to ensure frame cleanup on error
        local frame_rc = 0
        capture noisily {
            frame `event_frame' {
                use `events'
                rename `date' `match_date'
            }

            * Use m:1 since multiple intervals can have same stop date (valid data)
            quietly frlink m:1 `id' `match_date', frame(`event_frame')

            tempvar imported_type
            quietly frget `imported_type' = _event_type, from(`event_frame')

            quietly gen long `generate' = `imported_type'
            quietly replace `generate' = 0 if missing(`generate')

            * Note: Events at interval boundaries (where stop == event date) ARE valid events.
            * Previous versions incorrectly filtered these out. Events should be flagged
            * whenever the event date matches the interval stop time, regardless of whether
            * the interval was split or retained its original boundaries.

            if "`keepvars'" != "" {
                * Drop existing keepvars to avoid collision
                foreach v of local keepvars {
                    capture drop `v'
                }
                quietly frget `keepvars', from(`event_frame')
            }
        }
        local frame_rc = _rc

        * Always clean up the frame
        capture frame drop `event_frame'

        * Exit if there was an error
        if `frame_rc' != 0 {
            exit `frame_rc'
        }

        drop `match_date' `imported_type' _orig_stop `event_frame'

        **# 6. APPLY LABELS
        
        * A. Define Defaults (from Variable Labels)
        label define `generate'_lbl 0 "Censored"
        label define `generate'_lbl 1 "`lab_1'", add
        
        if "`compete'" != "" {
            local i = 1
            local label_idx = 2
            foreach v of local compete {
                local this_lab "`c_lab_`i''"
                label define `generate'_lbl `label_idx' "`this_lab'", add
                local i = `i' + 1
                local label_idx = `label_idx' + 1
            }
        }
        
        * B. Apply User Overrides
        if `"`eventlabel'"' != "" {
            * Use 'modify' to overwrite specific values or add new ones
            capture label define `generate'_lbl `eventlabel', modify
            if _rc {
                 noisily di as error "Error applying eventlabel(). Ensure syntax follows 'value \"Label\"' pairs."
                 exit 198
            }
        }
        
        label values `generate' `generate'_lbl
        label var `generate' "Event Status"
        
        **# 7. APPLY TYPE-SPECIFIC LOGIC
        
        if "`type'" == "single" {
            bysort `id' (`stopvar'): gen long _event_rank = sum(`generate' > 0)

            tempvar censor_time
            gen double `censor_time' = `stopvar' if `generate' > 0 & _event_rank == 1
            bysort `id': egen double _first_fail = min(`censor_time')

            drop if !missing(_first_fail) & `startvar' >= _first_fail
            replace `generate' = 0 if _event_rank > 1

            drop _event_rank `censor_time' _first_fail
            noisily di as txt "Single event type: Censored person-time after first event."
        }
        else {
            noisily di as txt "Recurring event type: Retained all person-time."
        }

        **# 8. GENERATE TIME VARIABLE
        if "`timegen'" != "" {
            tempvar days_diff
            gen double `days_diff' = `stopvar' - `startvar'
            if "`timeunit'" == "days" {
                gen double `timegen' = `days_diff'
                label var `timegen' "Time (days)"
            }
            else if "`timeunit'" == "months" {
                gen double `timegen' = `days_diff' / 30.4375
                label var `timegen' "Time (months)"
            }
            else if "`timeunit'" == "years" {
                gen double `timegen' = `days_diff' / 365.25
                label var `timegen' "Time (years)"
            }
            drop `days_diff'
        }

        * Restore original date formats from using dataset
        format `startvar' `orig_start_fmt'
        format `stopvar' `orig_stop_fmt'
        sort `id' `startvar' `stopvar'
        
        count if `generate' > 0
        local n_failures = r(N)
        count
        local n_total = r(N)
        
        return scalar N = `n_total'
        return scalar N_events = `n_failures'
    }
    
    di _newline
    di as txt "{hline 50}"
    di as txt "Event integration complete"
    di as txt "  Observations: " as result `n_total'
    di as txt "  Events flagged (`generate'): " as result `n_failures'
    di as txt "  Variable `generate' labels:"
    
    * Display active labels for clarity
    local lblname : value label `generate'
    levelsof `generate', local(vals)
    foreach v of local vals {
        local l : label `lblname' `v'
        di as txt "    `v' = `l'"
    }
    di as txt "{hline 50}"

end
