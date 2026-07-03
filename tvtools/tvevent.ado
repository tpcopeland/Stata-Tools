*! tvevent Version 1.6.8  2026/07/03
*! Add event/failure flags to time-varying datasets
*! Author: Timothy P Copeland, Karolinska Institutet
*!
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tvevent using intervals.dta, id(varname) date(varname) ///
    [generate(newvar) type(single|recurring) keepvars(varlist) ///
     continuous(varlist) timegen(newvar) timeunit(string) ///
     compete(varlist) eventlabel(string) validate replace]

Diagnostic options:
  validate           - Display validation diagnostics including:
                       • Events falling outside interval boundaries
                       • Multiple events per person when type(single)
                       • Competing events occurring on the same date

Data structure:
  Master (in memory): Event data with id(), date(), compete(), keepvars()
  Using:              Interval data from tvexpose/tvmerge with id, start, stop, continuous()

Description:
  Integrates event data (master) into tvexpose/tvmerge intervals (using).
  1. Identifies events occurring within intervals.
  2. Resolves competing risks (earliest date wins).
  3. Splits intervals at the event date (when start < date < stop).
  4. Proportionally adjusts 'continuous' variables.
  5. Flags the event type (1=Primary, 2+=Competing).

  Boundary behavior (inclusive [start, stop] intervals):
  - Events at start: Flagged. The interval is split into [start, start] and [start+1, stop],
    with the event marked on the first segment. The person is at risk on the start date.
  - Events strictly inside (start < date < stop): Split at the event date and flagged.
  - Events at stop: Flagged directly (no split needed, event matches the stop boundary).
  - Events outside [start, stop]: Not flagged.
*/

program define tvevent, rclass
    version 16.0
    local orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    syntax [using/] , ///
        id(varname) ///
        Date(name) ///
        [FRame(name) ///
         GENerate(name) ///
         Type(string) ///
         KEEPvars(namelist) ///
         CONtinuous(namelist) ///
         TIMEGen(name) ///
         TIMEUnit(string) ///
         COMpete(namelist) ///
         EVENTLabel(string asis) ///
         STARTVar(name) ///
         STOPVar(name) ///
         START(name) ///
         STOP(name) ///
         ENUM(name) ///
         GAPtime ///
         GAPSTART(name) ///
         GAPSTOP(name) ///
         VALidate ///
         FLOW ///
         REPlace]

    * Harmonized aliases: start()/stop() are the suite-standard names; the
    * legacy startvar()/stopvar() spellings remain accepted (capitalized
    * STARTVar/STOPVar so their abbreviation no longer collides). One spelling
    * per slot.
    if "`start'" != "" & "`startvar'" != "" {
        di as error "specify start() or startvar(), not both"
        exit 198
    }
    if "`start'" != "" local startvar "`start'"
    if "`stop'" != "" & "`stopvar'" != "" {
        di as error "specify stop() or stopvar(), not both"
        exit 198
    }
    if "`stop'" != "" local stopvar "`stop'"

    * Frames input: materialize the named frame to a tempfile and treat it as
    * the using source, so the rest of the command is unchanged.
    if "`frame'" != "" {
        if `"`using'"' != "" {
            di as error "specify either a using file or frame(), not both"
            exit 198
        }
        capture confirm frame `frame'
        if _rc {
            di as error "frame not found: `frame'"
            exit 111
        }
        tempfile _evframefile
        quietly frame `frame': save "`_evframefile'", replace
        local using "`_evframefile'"
    }
    else if `"`using'"' == "" {
        di as error "must specify a using file or frame()"
        exit 198
    }

    * Flow accounting: capture input persons/records from the interval (using)
    * data. Opt-in via flow; the master events stay in memory (preserved).
    if "`flow'" != "" {
        preserve
        quietly use `id' using "`using'", clear
        local _flow_rin = _N
        tempvar _flow_tag
        quietly egen byte `_flow_tag' = tag(`id')
        quietly count if `_flow_tag' == 1
        local _flow_pin = r(N)
        restore
    }

    * Row-id used as a reshape uniqueness key; a tempvar avoids colliding with a
    * user column that survives the keep below (previously a hardcoded _obs).
    tempvar obs

    **# 1. INPUT VALIDATION

    * Set defaults for options
    if "`generate'" == "" local generate "_failure"
    if "`startvar'" == "" local startvar "start"
    if "`stopvar'" == "" local stopvar "stop"

    * Validate variable name lengths (Stata allows up to 32 characters)
    foreach opt in id date generate timegen startvar stopvar {
        if "``opt''" != "" {
            local len = strlen("``opt''")
            if `len' > 32 {
                noisily display as error "Variable name too long: ``opt'' (`len' characters)"
                noisily display as error "Stata variable names must be 32 characters or fewer"
                exit 198
            }
        }
    }

    * Validate generate() doesn't collide with structural variable names
    if "`generate'" == "`startvar'" {
        noisily display as error "generate(`generate') conflicts with startvar(`startvar')"
        noisily display as error "Please choose a different name for the event indicator"
        exit 198
    }
    if "`generate'" == "`stopvar'" {
        noisily display as error "generate(`generate') conflicts with stopvar(`stopvar')"
        noisily display as error "Please choose a different name for the event indicator"
        exit 198
    }
    if "`generate'" == "`id'" {
        noisily display as error "generate(`generate') conflicts with id variable"
        exit 198
    }
    if "`generate'" == "`date'" {
        noisily display as error "generate(`generate') conflicts with date variable"
        exit 198
    }

    * Create truncated label name to stay within 32-char limit
    local _short_gen = substr("`generate'", 1, 28)
    local _ev_lbl_name "`_short_gen'_lbl"

    if "`type'" == "" local type "single"
    local type = lower("`type'")
    if !inlist("`type'", "single", "recurring") {
        di as error "type() must be either 'single' or 'recurring'"
        exit 198
    }

    * Recurrent-event (PWP/AG) formatting: event-sequence stratum + gap-time
    * clock. Only meaningful for repeated events, so it requires type(recurring).
    local do_recur_fmt = ("`enum'" != "" | "`gaptime'" != "" | ///
        "`gapstart'" != "" | "`gapstop'" != "")
    if `do_recur_fmt' {
        if "`type'" != "recurring" {
            di as error "enum()/gaptime require type(recurring)"
            exit 198
        }
        if "`enum'" == "" local enum "_enum"
        if "`gaptime'" != "" | "`gapstart'" != "" | "`gapstop'" != "" {
            local do_gaptime = 1
            if "`gapstart'" == "" local gapstart "_t0"
            if "`gapstop'" == "" local gapstop "_t"
        }
        else local do_gaptime = 0
    }
    else local do_gaptime = 0

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
    * strL ids cannot serve as merge keys; without this screen the internal
    * merge fails mid-run with a cryptic "key variable id is strL" r(106).
    local _tve_idtype : type `id'
    if "`_tve_idtype'" == "strL" {
        di as error "id() variable `id' is strL in the master (event) dataset; strL variables cannot be used as merge keys"
        di as error "recast it first, e.g. generate str20 `id'2 = `id'"
        exit 109
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
            local fmt : format `evar'
            if substr("`fmt'", 1, 3) == "%tc" | substr("`fmt'", 1, 3) == "%tC" {
                di as error "Event variable `evar' has datetime format (`fmt')."
                di as error "tvevent requires daily date variables."
                di as error "Convert with: gen daily_`evar' = dofc(`evar')"
                exit 120
            }
        }
    }
    else {
        * For single: validate date variable exists and is numeric
        capture confirm variable `date'
        if _rc {
            di as error "Date variable `date' not found in master (event) dataset."
            exit 111
        }
        capture confirm numeric variable `date'
        if _rc {
            di as error "Date variable `date' must be numeric (date format)."
            di as error "String dates must be converted first."
            exit 109
        }
        local fmt : format `date'
        if substr("`fmt'", 1, 3) == "%tc" | substr("`fmt'", 1, 3) == "%tC" {
            di as error "Date variable `date' has datetime format (`fmt')."
            di as error "tvevent requires daily date variables."
            di as error "Convert with: gen daily_`date' = dofc(`date')"
            exit 120
        }
    }

    if "`compete'" != "" {
        foreach v of local compete {
            capture confirm variable `v'
            if _rc {
                di as error "Competing event variable `v' not found in master (event) dataset."
                exit 111
            }
            capture confirm numeric variable `v'
            if _rc {
                di as error "Competing event variable `v' must be numeric (date format)."
                di as error "String dates must be converted first."
                exit 109
            }
            local fmt : format `v'
            if substr("`fmt'", 1, 3) == "%tc" | substr("`fmt'", 1, 3) == "%tC" {
                di as error "Competing event variable `v' has datetime format (`fmt')."
                di as error "tvevent requires daily date variables."
                di as error "Convert with: gen daily_`v' = dofc(`v')"
                exit 120
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

    **# 1b. VALIDATION DIAGNOSTICS (if requested)

    if "`validate'" != "" {
        * Store validation results for return
        local v_outside = 0
        local v_multiple = 0
        local v_same_date = 0

        noisily di _newline
        noisily di as txt "{hline 50}"
        noisily di as txt "{bf:Validation Diagnostics}"
        noisily di as txt "{hline 50}"

        * An empty event dataset has nothing to validate; the reshape/egen
        * machinery below errors on 0 observations, so short-circuit here.
        * The empty-master path later still produces the all-censored output.
        if _N == 0 {
            noisily di as txt "  Event dataset is empty: checks skipped"
            noisily di as txt "{hline 50}"
            noisily di ""
            return scalar v_outside_bounds = 0
            return scalar v_multiple_events = 0
            return scalar v_same_date_compete = 0
        }
        else {

        * Check 1: Multiple events per person when type(single)
        if "`type'" == "single" {
            preserve
            * Check primary event date only — competing dates in the same
            * row are expected and should not count as "multiple events"
            tempvar has_event total_events
            gen `has_event' = !missing(`date')
            bysort `id': egen long `total_events' = total(`has_event')
            quietly count if `total_events' > 1
            local v_multiple = r(N)
            restore

            if `v_multiple' > 0 {
                noisily di as txt "  Multiple events per person: " as result "`v_multiple' persons"
                noisily di as txt "    (type(single) expects at most one event per person)"
            }
            else {
                noisily di as txt "  Multiple events per person: " as result "None (OK)"
            }
        }

        * Check 2: Competing events on same date
        if "`compete'" != "" & "`type'" == "single" {
            preserve
            local v_same_date = 0

            * Check if primary event date equals any competing event date
            foreach cvar of local compete {
                quietly count if `date' == `cvar' & !missing(`date') & !missing(`cvar')
                local v_same_date = `v_same_date' + r(N)
            }
            restore

            if `v_same_date' > 0 {
                noisily di as txt "  Competing events on same date: " as result "`v_same_date' occurrences"
                noisily di as txt "    (earliest event wins; ties resolved by variable order)"
            }
            else {
                noisily di as txt "  Competing events on same date: " as result "None (OK)"
            }
        }

        * Check 3: Events outside interval boundaries
        * This requires loading the using (interval) dataset
        * (quietly: the reshape/save/merge here would otherwise leak tables)
        preserve
        quietly {
        tempfile master_events
        if "`type'" == "single" {
            keep `id' `date' `compete'
            * Stack primary + competing dates into one column
            gen long `obs' = _n
            local _all_dates "`date'"
            if "`compete'" != "" {
                local _all_dates "`date' `compete'"
            }
            local _j = 1
            foreach _dvar of local _all_dates {
                rename `_dvar' _edate_`_j'
                local ++_j
            }
            local _nj = `_j' - 1
            reshape long _edate_, i(`id' `obs') j(_eventnum)
            drop if missing(_edate_)
            rename _edate_ _event_date
            drop `obs' _eventnum
        }
        else {
            keep `id' `eventvars'
            * Reshape to long for checking
            gen long `obs' = _n
            reshape long `date', i(`id' `obs') j(_eventnum)
            drop if missing(`date')
            rename `date' _event_date
            drop `obs' _eventnum
        }
        save `master_events', replace

        * Load interval data
        use "`using'", clear

        * Get min/max interval times per person
        collapse (min) _min_start=`startvar' (max) _max_stop=`stopvar', by(`id')

        * Merge with events
        merge 1:m `id' using `master_events', keep(match) nogen

        * Check events outside boundaries
        count if _event_date < _min_start | _event_date > _max_stop
        local v_outside = r(N)
        }
        restore

        if `v_outside' > 0 {
            noisily di as txt "  Events outside interval bounds: " as result "`v_outside' events"
            noisily di as txt "    (these events will not be flagged in output)"
        }
        else {
            noisily di as txt "  Events outside interval bounds: " as result "None (OK)"
        }

        noisily di as txt "{hline 50}"
        noisily di ""

        * Store validation results
        return scalar v_outside_bounds = `v_outside'
        return scalar v_multiple_events = `v_multiple'
        return scalar v_same_date_compete = `v_same_date'
        } // end non-empty master validation checks
    }

    quietly {

        **# 2. PREPARE DATASETS

        * Handle empty event dataset (0 observations in master)
        local master_N = _N
        if `master_N' == 0 {
            noisily di as txt "Note: Event dataset is empty. All intervals will be marked as censored."
            _tvevent_empty_output, using("`using'") id(`id') startvar(`startvar') ///
                stopvar(`stopvar') generate(`generate') timeunit(`timeunit') ///
                timegen(`timegen') `replace'
            * Capture subroutine returns (incl. output-name macros) before exiting
            return add
            exit 0
        }

        * Save keepvars for ALL people before filtering to events-only
        if "`keepvars'" != "" {
            tempfile _all_keepvars
            preserve
            keep `id' `keepvars'
            duplicates drop `id', force
            save `_all_keepvars'
            restore
        }

        if "`type'" == "recurring" {
            * --- RECURRING EVENTS: Reshape wide to long ---

            * Capture label from first event variable
            local first_evar : word 1 of `eventvars'
            local orig_date_label : variable label `first_evar'
            local lab_1 "`orig_date_label'"
            if "`lab_1'" == "" local lab_1 "Event: `date'"

            * Note: competing risks not supported with recurring events
            if "`compete'" != "" {
                noisily di as txt "Note: compete() option ignored for recurring events."
                local compete ""
            }
            local num_compete = 0

            * Keep only needed variables for reshape
            keep `id' `eventvars'

            * Reshape wide event dates to long format
            * eventvars are: date1 date2 date3 ...
            * `obs' ensures uniqueness when duplicate IDs exist (warned but allowed)
            gen long `obs' = _n
            reshape long `date', i(`id' `obs') j(_eventnum)

            * Drop missing event dates and temporary variables
            drop if missing(`date')
            drop `obs' _eventnum

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
            local orig_date_label : variable label `date'
            local lab_1 "`orig_date_label'"
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
                noisily di as txt "Note: All event dates are missing. All intervals will be marked as censored."
                _tvevent_empty_output, using("`using'") id(`id') startvar(`startvar') ///
                    stopvar(`stopvar') generate(`generate') timeunit(`timeunit') ///
                    timegen(`timegen') `replace'
                return add
                exit 0
            }

            capture drop `date'
            rename _eff_date `date'
            rename _eff_type _event_type

            keep `id' `date' _event_type
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
        local _tve_uidtype : type `id'
        if "`_tve_uidtype'" == "strL" {
            noisily di as error "id() variable `id' is strL in the using (interval) dataset; strL variables cannot be used as merge keys"
            noisily di as error "recast it first, e.g. generate str20 `id'2 = `id'"
            exit 109
        }

        foreach v in `startvar' `stopvar' {
            capture confirm variable `v'
            if _rc {
                noisily di as error "Variable '`v'' not found in using (interval) dataset. tvevent requires output from tvexpose/tvmerge."
                noisily di as error "Use startvar() and stopvar() options to specify the variable names if different from 'start' and 'stop'."
                exit 111
            }
        }

        * Validate using dataset interval bounds are not datetime
        foreach v in `startvar' `stopvar' {
            local fmt : format `v'
            if substr("`fmt'", 1, 3) == "%tc" | substr("`fmt'", 1, 3) == "%tC" {
                noisily di as error "Interval variable `v' has datetime format (`fmt')."
                noisily di as error "tvevent requires daily date variables in the using dataset."
                noisily di as error "Convert with: gen daily_`v' = dofc(`v')"
                exit 120
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

        * Check replace option (generate/timegen/date will be created in interval data)
        if "`replace'" == "" {
            capture confirm variable `generate'
            if _rc == 0 {
                noisily di as error "Variable `generate' already exists in using dataset. Use replace option."
                exit 110
            }
            capture confirm variable `date'
            if _rc == 0 {
                noisily di as error "Variable `date' already exists in using dataset. Use replace option."
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
            capture drop `date'
            if "`timegen'" != "" capture drop `timegen'
        }

        * Warn if interval data has variables matching the date stub pattern
        local stub_collisions = 0
        forvalues i = 1/20 {
            capture confirm variable `date'`i'
            if _rc == 0 {
                local stub_collisions = `stub_collisions' + 1
            }
        }
        if `stub_collisions' > 0 {
            noisily di as error "Using dataset contains `stub_collisions' variable(s) matching '`date'1', '`date'2', etc."
            noisily di as error "These conflict with internal split processing. Rename these variables before running tvevent."
            exit 110
        }

        * Save interval data for later
        tempfile intervals
        save `intervals'

        **# 3. IDENTIFY SPLIT POINTS

        * intervals tempfile already has the using data loaded
        preserve
        keep `id' `startvar' `stopvar'
        duplicates drop

        * Split points are events strictly inside [start, stop): date >= start &
        * date < stop. Identify them with the shared half-open point-in-interval
        * engine instead of a joinby(`id')+filter Cartesian. The closed-left,
        * open-right rule is exactly the former filter (events at stop don't
        * split; they match by date == stop downstream).
        capture findfile _tvmerge_mata.ado
        if _rc == 0 {
            quietly run "`r(fn)'"
        }
        else {
            noisily display as error "_tvmerge_mata.ado not found; reinstall tvtools"
            exit 111
        }
        gen long __te_iobs = _n
        tempfile __te_ivl
        save `__te_ivl'

        * id -> contiguous gid crosswalk (interval ids; events keep(match) below
        * drops events for ids with no interval, matching the joinby inner join).
        keep `id'
        duplicates drop
        gen long __te_gid = _n
        tempfile __te_xw
        save `__te_xw'

        * master interval work frame: gid start stop obs
        use `__te_ivl', clear
        merge m:1 `id' using `__te_xw', keep(match) nogenerate
        capture frame drop __te_m
        frame put __te_gid `startvar' `stopvar' __te_iobs, into(__te_m)
        frame __te_m: order __te_gid `startvar' `stopvar' __te_iobs

        * using point work frame: gid date obs (events indexed by __te_eobs)
        use `events', clear
        gen long __te_eobs = _n
        tempfile __te_eidx
        save `__te_eidx'
        merge m:1 `id' using `__te_xw', keep(match) nogenerate
        capture frame drop __te_u
        frame put __te_gid `date' __te_eobs, into(__te_u)
        frame __te_u: order __te_gid `date' __te_eobs

        capture frame drop __te_out
        frame create __te_out
        _tvmerge_point_pairs __te_m __te_u __te_out
        tempfile __te_pairs
        frame __te_out: save `__te_pairs'
        capture frame drop __te_m
        capture frame drop __te_u
        capture frame drop __te_out

        * Distinct matched events -> their (id, date) split points.
        use `__te_pairs', clear
        keep __tvm_ui
        rename __tvm_ui __te_eobs
        if _N > 0 {
            duplicates drop
            merge m:1 __te_eobs using `__te_eidx', keep(match) nogenerate ///
                keepusing(`id' `date')
        }
        else {
            merge 1:1 __te_eobs using `__te_eidx', keep(match) nogenerate ///
                keepusing(`id' `date')
        }
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
        * Duration under [start, stop] inclusive convention = stop - start + 1
        gen double _orig_dur = `stopvar' - `startvar' + 1
        gen long _orig_interval_id = _n
        if `n_splits' > 0 {
            noisily di as txt "Splitting intervals for `n_splits' internal events..."

            * Join with split points - creates row per (interval, split_date) combination
            joinby `id' using `splits', unmatched(master)
            drop _merge

            * Mark valid splits (date falls at start or strictly within this interval)
            * Under [start, stop] inclusive convention, events at start need splitting too
            gen byte _valid_split = (`date' >= `startvar' & `date' < `stopvar') & !missing(`date')

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
            gen double _orig_dur = `stopvar' - `startvar' + 1

            * Merge in split dates
            merge 1:1 _orig_interval_id using `split_dates', keep(match) nogen

            * Count splits (number of date1, date2, ... variables from reshape)
            local max_splits = 0
            local _i = 1
            while 1 {
                capture confirm variable `date'`_i'
                if _rc continue, break
                local max_splits = `_i'
                local _i = `_i' + 1
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

            * Set segment boundaries using [start, stop] inclusive convention
            * Segment 1: [original_start, split1]
            * Segment 2: [split1 + 1, split2]
            * ...
            * Segment N: [split(N-1) + 1, original_stop]
            *
            * Under [start, stop] inclusive intervals, person-time = stop - start + 1.
            * Consecutive segments [S, D] and [D+1, E] do not overlap because
            * the first covers days S..D and the second covers days D+1..E.

            tempvar new_start new_stop
            gen double `new_start' = `startvar'
            gen double `new_stop' = `stopvar'

            * For each segment, set the correct boundaries
            forvalues i = 1/`max_splits' {
                capture confirm variable `date'`i'
                if _rc == 0 {
                    * Segment i ends at split point i (if it exists)
                    replace `new_stop' = `date'`i' if _seg_num == `i' & !missing(`date'`i')
                    * Segment i+1 starts at split point i + 1 ([start,stop] inclusive convention)
                    replace `new_start' = `date'`i' + 1 if _seg_num == `i' + 1 & !missing(`date'`i')
                }
            }

            replace `startvar' = `new_start'
            replace `stopvar' = `new_stop'

            * Clean up temporary variables
            drop `new_start' `new_stop' _n_segments _seg_num
            forvalues i = 1/`max_splits' {
                capture drop `date'`i'
            }

            save `needs_splits'

            * Combine intervals that didn't need splitting with those that did
            use `no_splits', clear
            append using `needs_splits'

            sort `id' `startvar' `stopvar'
            * Full-row dedup only: keying on (id, start, stop) with force
            * silently destroyed legitimate rows that share an interval but
            * differ on payload (e.g. per-stratum rows from tvexpose split).
            duplicates drop
        }

        * Adjust Continuous Variables
        if "`continuous'" != "" {
            tempvar new_dur ratio
            gen double `new_dur' = `stopvar' - `startvar' + 1
            gen double `ratio' = cond(_orig_dur == 0 | `new_dur' == 0, 1, `new_dur' / _orig_dur)
            foreach v of local continuous {
                replace `v' = `v' * `ratio'
            }
            drop `new_dur' `ratio'
        }
        drop _orig_dur _orig_interval_id

        **# 5. MERGE EVENT FLAGS

        * keepvars for all people already saved in _all_keepvars

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

            * Note: Boundary events (date == stop) are flagged but not split.
            * Splitting occurs when start <= date < stop (event at start or inside interval).
            * An event at the stop date ends that interval without needing to split it.

            * Import event date variable so it appears in output
            capture drop `date'
            quietly frget `date' = `match_date', from(`event_frame')
            if `"`orig_date_label'"' != "" {
                label var `date' `"`orig_date_label'"'
            }
            else {
                label var `date' "Event date"
            }
        }
        local frame_rc = _rc

        * Always clean up the frame
        capture frame drop `event_frame'
        local cleanup_rc = _rc

        * Exit if there was an error
        if `frame_rc' != 0 {
            exit `frame_rc'
        }

        drop `match_date' `imported_type'

        * Merge person-level covariates by id (not tied to event date)
        if "`keepvars'" != "" {
            foreach v of local keepvars {
                capture drop `v'
            }
            merge m:1 `id' using `_all_keepvars', keep(master match) nogen
        }

        **# 6. APPLY LABELS
        
        * A. Define Defaults (from Variable Labels)
        * Drop any same-named label loaded from the using file (e.g. when the
        * intervals are a prior tvevent output); label define has no replace-
        * from-scratch form and errors r(110) on an existing name.
        capture label drop `_ev_lbl_name'
        label define `_ev_lbl_name' 0 "Censored"
        label define `_ev_lbl_name' 1 "`lab_1'", add
        
        if "`compete'" != "" {
            local i = 1
            local label_idx = 2
            foreach v of local compete {
                local this_lab "`c_lab_`i''"
                label define `_ev_lbl_name' `label_idx' "`this_lab'", add
                local i = `i' + 1
                local label_idx = `label_idx' + 1
            }
        }
        
        * B. Apply User Overrides
        if `"`eventlabel'"' != "" {
            * Use 'modify' to overwrite specific values or add new ones
            capture label define `_ev_lbl_name' `eventlabel', modify
            if _rc {
                 noisily di as error "Error applying eventlabel(). Ensure syntax follows 'value \"Label\"' pairs."
                 exit 198
            }
        }
        
        label values `generate' `_ev_lbl_name'
        label var `generate' "Event Status"
        
        **# 7. APPLY TYPE-SPECIFIC LOGIC
        
        if "`type'" == "single" {
            bysort `id' (`stopvar'): gen long _event_rank = sum(`generate' > 0)

            tempvar censor_time
            gen double `censor_time' = `stopvar' if `generate' > 0 & _event_rank == 1
            bysort `id': egen double _first_fail = min(`censor_time')

            * Under [start, stop] inclusive convention, post-event intervals have
            * start > event_date. Keep the first event row itself (which may
            * have start == _first_fail for single-day intervals).
            drop if !missing(_first_fail) & `startvar' >= _first_fail ///
                & !(`generate' > 0 & _event_rank == 1)
            replace `generate' = 0 if _event_rank > 1

            drop _event_rank `censor_time' _first_fail
            noisily di as txt "Single event type: Censored person-time after first event."
        }
        else {
            noisily di as txt "Recurring event type: Retained all person-time."
        }

        **# 8. GENERATE TIME VARIABLE
        if "`timegen'" != "" {
            * Calculate cumulative time from person's first interval start to current stop
            tempvar first_start days_from_entry
            bysort `id' (`startvar'): gen double `first_start' = `startvar'[1]
            gen double `days_from_entry' = `stopvar' - `first_start'
            if "`timeunit'" == "days" {
                gen double `timegen' = `days_from_entry'
                label var `timegen' "Time since entry (days)"
            }
            else if "`timeunit'" == "months" {
                gen double `timegen' = `days_from_entry' / 30.4375
                label var `timegen' "Time since entry (months)"
            }
            else if "`timeunit'" == "years" {
                gen double `timegen' = `days_from_entry' / 365.25
                label var `timegen' "Time since entry (years)"
            }
            drop `first_start' `days_from_entry'
        }

        * Restore original date formats from using dataset
        format `startvar' `orig_start_fmt'
        format `stopvar' `orig_stop_fmt'
        sort `id' `startvar' `stopvar'

        * Recurrent-event formatting (PWP/AG): event-sequence stratum + gap-time
        * clock. The stratum enumerates the gaps a person passes through (1 until
        * the first event, 2 thereafter, ...); the gap-time clock resets to 0 at
        * the start of each new stratum. Andersen-Gill uses the calendar
        * (start, stop] with the event flag; PWP-CP adds the stratum to the
        * total-time clock (timegen); PWP-GT uses the stratum with gap time.
        if `do_recur_fmt' {
            foreach _nv in `enum' `gapstart' `gapstop' {
                capture confirm new variable `_nv'
                if _rc {
                    if "`replace'" != "" quietly drop `_nv'
                    else {
                        noisily di as error "variable `_nv' already exists; use replace option"
                        exit 110
                    }
                }
            }
            tempvar _evflag _cumev
            quietly {
                gen byte `_evflag' = (`generate' > 0) & !missing(`generate')
                by `id': gen long `_cumev' = sum(`_evflag')
                by `id': gen long `enum' = 1 + cond(_n==1, 0, `_cumev'[_n-1])
                drop `_evflag' `_cumev'
                if `do_gaptime' {
                    tempvar _newstr _origin
                    by `id': gen byte `_newstr' = (_n==1) | (`enum' != `enum'[_n-1])
                    by `id': gen double `_origin' = `startvar' if `_newstr'
                    by `id': replace `_origin' = `_origin'[_n-1] if !`_newstr'
                    gen double `gapstart' = `startvar' - `_origin'
                    gen double `gapstop' = `stopvar' - `_origin'
                    drop `_newstr' `_origin'
                    label var `gapstart' "Gap-time start (PWP-GT)"
                    label var `gapstop' "Gap-time stop (PWP-GT)"
                }
            }
            label var `enum' "Event sequence / PWP stratum"
            noisily di as txt "Recurrent formatting: stratum `enum'" ///
                cond(`do_gaptime', " + gap time (`gapstart',`gapstop')", "") " added."
        }

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
    quietly levelsof `generate', local(vals)
    foreach v of local vals {
        local l : label `lblname' `v'
        di as txt "    `v' = `l'"
    }
    di as txt "{hline 50}"

    * Flow accounting report (opt-in via flow option)
    if "`flow'" != "" {
        tempvar _flow_tago
        quietly egen byte `_flow_tago' = tag(`id')
        quietly count if `_flow_tago' == 1
        local _flow_pout = r(N)
        drop `_flow_tago'
        tempname _flowmat
        matrix `_flowmat' = J(2, 3, .)
        matrix `_flowmat'[1,1] = `_flow_pin'
        matrix `_flowmat'[1,2] = `_flow_pout'
        matrix `_flowmat'[1,3] = `_flow_pin' - `_flow_pout'
        matrix `_flowmat'[2,1] = `_flow_rin'
        matrix `_flowmat'[2,2] = `n_total'
        matrix `_flowmat'[2,3] = `_flow_rin' - `n_total'
        matrix rownames `_flowmat' = persons records
        matrix colnames `_flowmat' = in out dropped
        di as txt "{hline 60}"
        di as txt "Pipeline flow (tvevent)"
        di as txt %-12s "" %10s "in" %10s "out" %10s "dropped"
        di as txt %-12s "persons" %10.0f `_flow_pin' %10.0f `_flow_pout' ///
            %10.0f `=`_flow_pin' - `_flow_pout''
        di as txt %-12s "records" %10.0f `_flow_rin' %10.0f `n_total' ///
            %10.0f `=`_flow_rin' - `n_total''
        di as txt "(records dropped < 0 indicates interval splitting at events)"
        di as txt "{hline 60}"
        return matrix flow = `_flowmat'
    }

    * Output-name macros so downstream steps can read the chosen names
    return local generate "`generate'"
    return local startvar "`startvar'"
    return local stopvar  "`stopvar'"
    if "`timegen'" != "" return local timegen "`timegen'"
    if `do_recur_fmt' {
        return local enum "`enum'"
        if `do_gaptime' {
            return local gapstart "`gapstart'"
            return local gapstop  "`gapstop'"
        }
    }

    } // end capture noisily
    local rc = _rc

    set varabbrev `orig_varabbrev'

    if `rc' {
        exit `rc'
    }

end

// Subroutine: Handle empty event data (no events to flag)
// Loads interval data, creates censored outcome, optionally creates timegen
cap program drop _tvevent_empty_output
program define _tvevent_empty_output, rclass
    version 16.0
    syntax , using(string) id(name) STARTvar(name) STOPvar(name) ///
        GENerate(name) TIMEUnit(string) [TIMEGen(name) REPlace]

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
    if "`replace'" == "replace" {
        capture drop `generate'
        if "`timegen'" != "" capture drop `timegen'
    }
    gen byte `generate' = 0
    label var `generate' "Event outcome"
    local _short_gen = substr("`generate'", 1, 28)
    local _ev_lbl_name "`_short_gen'_lbl"
    * The using file may already carry this label (re-run over prior output)
    capture label drop `_ev_lbl_name'
    label define `_ev_lbl_name' 0 "Censored"
    label values `generate' `_ev_lbl_name'

    * Create timegen if requested (cumulative time from first start)
    if "`timegen'" != "" {
        tempvar first_start
        bysort `id' (`startvar'): gen double `first_start' = `startvar'[1]
        gen double `timegen' = `stopvar' - `first_start'
        if "`timeunit'" == "months" {
            replace `timegen' = `timegen' / 30.4375
            label var `timegen' "Time since entry (months)"
        }
        else if "`timeunit'" == "years" {
            replace `timegen' = `timegen' / 365.25
            label var `timegen' "Time since entry (years)"
        }
        else {
            label var `timegen' "Time since entry (days)"
        }
        drop `first_start'
    }

    sort `id' `startvar' `stopvar'

    quietly count
    local n_total = r(N)
    local n_failures = 0

    return scalar N = `n_total'
    return scalar N_events = `n_failures'
    return local generate "`generate'"
    return local startvar "`startvar'"
    return local stopvar  "`stopvar'"
    if "`timegen'" != "" return local timegen "`timegen'"

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
end
