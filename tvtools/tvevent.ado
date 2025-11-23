*! tvevent v1.0.0
*! Add event/failure flags to time-varying datasets
*! Author: Tim Copeland
*! Date: 2025-11-23
*!
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tvevent using filename, id(varname) date(varname) ///
    [generate(newvar) type(single|recurring) keepvars(varlist) ///
     continuous(varlist) timegen(newvar) timeunit(string) ///
     compete(varlist) eventlabel(string) replace]

Description:
  Integrates event data into tvexpose/tvmerge intervals.
  1. Identifies events occurring within intervals (start < date < stop).
  2. Resolves competing risks (earliest date wins).
  3. Splits intervals at the event date.
  4. Proportionally adjusts 'continuous' variables.
  5. Flags the event type (1=Primary, 2+=Competing).
*/

program define tvevent, rclass
    version 16.0

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
    
    capture confirm variable `id'
    if _rc {
        di as error "ID variable `id' not found in master dataset."
        exit 111
    }
    foreach v in start stop {
        capture confirm variable `v'
        if _rc {
            di as error "Variable '`v'' not found. tvevent requires output from tvexpose/tvmerge."
            exit 111
        }
    }
    
    if "`replace'" == "" {
        capture confirm variable `generate'
        if _rc == 0 {
            di as error "Variable `generate' already exists. Use replace option."
            exit 110
        }
        if "`timegen'" != "" {
            capture confirm variable `timegen'
            if _rc == 0 {
                di as error "Variable `timegen' already exists. Use replace option."
                exit 110
            }
        }
    }
    else {
        capture drop `generate'
        if "`timegen'" != "" capture drop `timegen'
    }
    
    if "`continuous'" != "" {
        foreach v of local continuous {
            capture confirm numeric variable `v'
            if _rc {
                di as error "Continuous variable `v' not found or is not numeric."
                exit 111
            }
        }
    }
    
    if "`keepvars'" != "" {
        local collision_vars ""
        foreach v of local keepvars {
            capture confirm variable `v'
            if _rc == 0 local collision_vars "`collision_vars' `v'"
        }
        if "`collision_vars'" != "" {
            di as error "The following variables in keepvars() already exist in master: `collision_vars'"
            di as error "Please rename them or remove them from keepvars()."
            exit 110
        }
    }

    quietly {
        
        **# 2. PREPARE DATASETS
        
        tempfile master
        save `master'

        * Load and process Event data
        preserve
        use "`using'", clear
        
        capture confirm variable `id'
        if _rc {
             di as error "ID variable `id' not found in event dataset `using'"
             exit 111
        }
        capture confirm variable `date'
        if _rc {
             di as error "Date variable `date' not found in event dataset `using'"
             exit 111
        }

        * -- COMPETING RISK LOGIC START --
        
        * 1. Capture labels for reporting later
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
        
        * 2. Determine Earliest Event per Person
        replace `date' = floor(`date')
        gen double _eff_date = `date'
        gen int _eff_type = 1 if !missing(`date')
        
        local k = 2
        foreach v of local compete {
             capture confirm variable `v'
             if _rc {
                 di as error "Competing variable `v' not found in using dataset."
                 exit 111
             }
             replace `v' = floor(`v')
             
             replace _eff_type = `k' if !missing(`v') & (`v' < _eff_date | missing(_eff_date))
             replace _eff_date = `v' if !missing(`v') & (`v' < _eff_date | missing(_eff_date))
             
             local k = `k' + 1
        }
        
        * 3. Clean up event file
        keep if !missing(_eff_date)
        
        drop `date'
        rename _eff_date `date'
        rename _eff_type _event_type
        
        keep `id' `date' _event_type `keepvars'
        duplicates drop `id' `date', force
        
        tempfile events
        save `events'
        restore

        **# 3. IDENTIFY SPLIT POINTS
        
        keep `id' start stop
        joinby `id' using `events'
        
        keep if `date' > start & `date' < stop
        
        keep `id' `date'
        duplicates drop `id' `date', force
        tempfile splits
        save `splits'
        
        count
        local n_splits = r(N)
        
        **# 4. EXECUTE SPLITS
        use `master', clear
        
        tempvar orig_dur new_dur ratio
        gen double `orig_dur' = stop - start
        
        if `n_splits' > 0 {
            noisily di as txt "Splitting intervals for `n_splits' internal events..."
            joinby `id' using `splits', unmatched(master)
            gen byte _needs_split = (`date' > start & `date' < stop)
            expand 2 if _needs_split, gen(_copy)
            replace stop = `date' if _needs_split & _copy == 0
            replace start = `date' if _needs_split & _copy == 1
            drop _needs_split _copy _merge
            sort `id' start stop
            duplicates drop `id' start stop, force
        }
        
        * Adjust Continuous Variables
        if "`continuous'" != "" {
            gen double `new_dur' = stop - start
            gen double `ratio' = `new_dur' / `orig_dur'
            replace `ratio' = 1 if `orig_dur' == 0
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
        frame `event_frame' {
            use `events'
            rename `date' `match_date'
        }
        
        frlink 1:1 `id' `match_date', frame(`event_frame')
        
        tempvar imported_type
        frget `imported_type' = _event_type, from(`event_frame')
        
        gen int `generate' = `imported_type'
        replace `generate' = 0 if missing(`generate')
        
        if "`keepvars'" != "" {
             frget `keepvars', from(`event_frame')
        }
        
        frame drop `event_frame'
        drop `match_date' `event_frame' `imported_type'
        
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
        
        format start stop %tdCCYY/NN/DD
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
