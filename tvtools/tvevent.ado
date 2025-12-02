*! tvevent Version 1.0.0  2025/12/02
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
        Date(varname) ///
        [GENerate(name) ///
         Type(string) ///
         KEEPvars(namelist) ///
         CONtinuous(varlist) ///
         TIMEGen(name) ///
         TIMEUnit(string) ///
         COMpete(namelist) ///
         EVENTLabel(string asis) ///
         REPlace]

    **# 1. INPUT VALIDATION
    
    * Set defaults for options
    if "`generate'" == "" local generate "_failure"
    
    if "`type'" == "" local type "single"
    local type = lower("`type'")
    if !inlist("`type'", "single", "recurring") {
        di as error "type() must be either 'single' or 'recurring'"
        exit 198
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

    capture confirm variable `date'
    if _rc {
        di as error "Date variable `date' not found in master (event) dataset."
        exit 111
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
    
    * Default keepvars to all variables in master except id and date/compete
    if "`keepvars'" == "" {
        foreach v of varlist * {
            if "`v'" != "`id'" & "`v'" != "`date'" {
                local is_compete = 0
                foreach c of local compete {
                    if "`v'" == "`c'" local is_compete = 1
                }
                if !`is_compete' {
                    local keepvars "`keepvars' `v'"
                }
            }
        }
        local keepvars = strtrim("`keepvars'")
    }

    quietly {

        **# 2. PREPARE DATASETS

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
        capture drop `date'
        rename _eff_date `date'
        rename _eff_type _event_type
        
        keep `id' `date' _event_type `keepvars'
        duplicates drop `id' `date', force
        
        tempfile events
        save `events'

        * Load USING dataset (interval data from tvexpose/tvmerge)
        use "`using'", clear

        * --- Validate USING dataset (interval data) ---
        capture confirm variable `id'
        if _rc {
             di as error "ID variable `id' not found in using (interval) dataset."
             exit 111
        }

        foreach v in start stop {
            capture confirm variable `v'
            if _rc {
                di as error "Variable '`v'' not found in using (interval) dataset. tvevent requires output from tvexpose/tvmerge."
                exit 111
            }
        }

        if "`continuous'" != "" {
            foreach v of local continuous {
                capture confirm numeric variable `v'
                if _rc {
                    di as error "Continuous variable `v' not found or is not numeric in using (interval) dataset."
                    exit 111
                }
            }
        }

        * Check replace option (generate/timegen will be created in interval data)
        if "`replace'" == "" {
            capture confirm variable `generate'
            if _rc == 0 {
                di as error "Variable `generate' already exists in using dataset. Use replace option."
                exit 110
            }
            if "`timegen'" != "" {
                capture confirm variable `timegen'
                if _rc == 0 {
                    di as error "Variable `timegen' already exists in using dataset. Use replace option."
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
        keep `id' start stop
        duplicates drop
        
        joinby `id' using `events'
        
        keep if `date' > start & `date' < stop
        
        keep `id' `date'
        duplicates drop `id' `date', force
        tempfile splits
        save `splits'
        
        count
        local n_splits = r(N)
        restore
        
        **# 4. EXECUTE SPLITS
        * intervals data is still in memory
        
        tempvar orig_dur new_dur ratio
        gen double `orig_dur' = stop - start
        
        if `n_splits' > 0 {
            noisily di as txt "Splitting intervals for `n_splits' internal events..."
            joinby `id' using `splits', unmatched(master)
            gen long _needs_split = (`date' > start & `date' < stop)
            expand 2 if _needs_split, gen(_copy)
            replace stop = `date' if _needs_split & _copy == 0
            replace start = `date' if _needs_split & _copy == 1
            drop _needs_split _copy
            * Note: joinby does not create _merge (unlike merge command)
            sort `id' start stop
            duplicates drop `id' start stop, force
        }
        
        * Adjust Continuous Variables
        if "`continuous'" != "" {
            gen double `new_dur' = stop - start
            gen double `ratio' = cond(`orig_dur' == 0 | `new_dur' == 0, 1, `new_dur' / `orig_dur')
            foreach v of local continuous {
                replace `v' = `v' * `ratio'
            }
            drop `new_dur' `ratio'
        }
        drop `orig_dur'

        **# 5. MERGE EVENT FLAGS
        
        tempvar match_date
        gen double `match_date' = stop
        
        tempname event_frame
        frame create `event_frame'

        * Use capture to ensure frame cleanup on error
        local frame_rc = 0
        capture noisily {
            frame `event_frame' {
                use `events'
                rename `date' `match_date'
            }

            frlink 1:1 `id' `match_date', frame(`event_frame')

            tempvar imported_type
            frget `imported_type' = _event_type, from(`event_frame')

            gen long `generate' = `imported_type'
            replace `generate' = 0 if missing(`generate')

            if "`keepvars'" != "" {
                 frget `keepvars', from(`event_frame')
            }
        }
        local frame_rc = _rc

        * Always clean up the frame
        capture frame drop `event_frame'

        * Exit if there was an error
        if `frame_rc' != 0 {
            exit `frame_rc'
        }

        drop `match_date' `imported_type'
        
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
                 di as error "Error applying eventlabel(). Ensure syntax follows 'value \"Label\"' pairs."
                 exit 198
            }
        }
        
        label values `generate' `generate'_lbl
        label var `generate' "Event Status"
        
        **# 7. APPLY TYPE-SPECIFIC LOGIC
        
        if "`type'" == "single" {
            bysort `id' (stop): gen long _event_rank = sum(`generate' > 0)
            
            tempvar censor_time
            gen double `censor_time' = stop if `generate' > 0 & _event_rank == 1
            bysort `id': egen double _first_fail = min(`censor_time')
            
            drop if !missing(_first_fail) & start >= _first_fail
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
            gen double `days_diff' = stop - start
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

        * Apply date format only if not already formatted as date
        local start_fmt : format start
        if substr("`start_fmt'", 1, 2) != "%t" {
            format start stop %tdCCYY/NN/DD
        }
        sort `id' start stop
        
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
