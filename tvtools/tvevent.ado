*! tvevent Version 1.8.0  2026/07/22
*! Add event/failure flags to time-varying datasets
*! Author: Timothy P Copeland, Karolinska Institutet
*!
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tvevent using intervals.dta, id(varname) date(varname) ///
    [generate(newvar) type(single|recurring) keepvars(varlist) ///
     rate(varlist) total(varlist) cumulative(varlist) ///
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
  3. Splits intervals at the event date (when start <= date < stop).
  4. Carries rates/cumulative histories and apportions interval totals.
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
    tempname _te_master_frame _te_using_frame _te_output_frame
    local _caller_snap_taken = 0
    local _caller_zero_var_obs = 0
    local _caller_snapshot_ready = 0
    local n_invalid_master = 0
    local n_invalid_master_id = 0
    local n_invalid_master_dates = 0
    local n_invalid_intervals = 0
    local n_invalid_interval_id = 0
    local n_invalid_interval_dates = 0
    local n_invalid_interval_order = 0
    local n_invalid_quantity = 0

    capture noisily {

    syntax [using/] , ///
        id(varname) ///
        Date(name) ///
        [FRame(name) ///
         GENerate(name) ///
         Type(string) ///
         KEEPvars(namelist) ///
         CONtinuous(namelist) ///
         RAte(namelist) ///
         TOTal(namelist) ///
         CUMulative(namelist) ///
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
         DROPInvalid ///
         VERBose ///
         REPlace]

    local keepvars_explicit = ("`keepvars'" != "")
    local auto_keep_excluded ""
    local _return_flow = ("`flow'" != "" | "`dropinvalid'" != "")

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

    * Success replaces the event data in memory with interval output. Failure
    * must not: snapshot the caller before the first use/clear mutation.
    if c(k) > 0 {
        tempfile _tve_caller_snap
        quietly save "`_tve_caller_snap'", replace
        local _caller_snap_taken = 1
    }
    else if _N > 0 {
        * Stata cannot save observations-only data. Its restorable state is the
        * observation count, just as in tvmerge's caller transaction.
        local _caller_zero_var_obs = _N
    }
    local _caller_snapshot_ready = 1

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

    * Create a truncated base for the output value label. The collision-safe
    * concrete name is chosen after the interval dataset is loaded.
    local _short_gen = substr("`generate'", 1, 28)
    local _ev_lbl_base "`_short_gen'_lbl"

    if "`type'" == "" local type "single"
    local type = lower("`type'")
    if !inlist("`type'", "single", "recurring") {
        di as error "type() must be either 'single' or 'recurring'"
        exit 198
    }
    if "`type'" == "recurring" & "`compete'" != "" {
        di as error "compete() is not supported with type(recurring)"
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

    * Three quantity algebras are explicit. The released continuous() behavior
    * apportioned values by duration, so it remains a warned alias for total().
    local continuous_vars "`continuous'"
    if "`continuous'" != "" {
        noisily display as text ///
            "Warning: continuous() is deprecated; use total() for interval totals."
        local total "`total' `continuous'"
    }
    foreach quantity in rate total cumulative continuous_vars {
        local quantity_dups : list dups `quantity'
        if "`quantity_dups'" != "" {
            local option_name = subinstr("`quantity'", "_vars", "", .)
            display as error "`option_name'() contains duplicate variable name(s):`quantity_dups'"
            exit 198
        }
        local `quantity' : list uniq `quantity'
    }
    local all_quantity "`rate' `total' `cumulative'"
    local all_quantity : list uniq all_quantity
    foreach qvar of local all_quantity {
        local n_assignments = 0
        foreach quantity in rate total cumulative {
            local in_quantity : list qvar in `quantity'
            if `in_quantity' local ++n_assignments
        }
        if `n_assignments' > 1 {
            display as error "Variable `qvar' appears in more than one of rate(), total(), and cumulative()"
            exit 198
        }
    }
    local n_rate_quantity : word count `rate'
    local n_total_quantity : word count `total'
    local n_cumulative_quantity : word count `cumulative'
    local n_continuous_quantity : word count `continuous_vars'

    local output_names "`id' `startvar' `stopvar' `generate' `date'"
    if "`timegen'" != "" local output_names "`output_names' `timegen'"
    if `do_recur_fmt' local output_names "`output_names' `enum'"
    if `do_gaptime' local output_names "`output_names' `gapstart' `gapstop'"
    local output_dups : list dups output_names
    if "`output_dups'" != "" {
        display as error "id/date/time/output variable names must be distinct; duplicate(s): `output_dups'"
        exit 198
    }

    * For recurring events, detect the entire wide stub before processing.
    * A gap such as date1/date3 must error: stopping at the first missing suffix
    * silently discards later events while returning success.
    local eventvars ""
    local n_eventvars = 0
    if "`type'" == "recurring" {
        local _event_max = 0
        capture ds `date'*
        if _rc == 0 local _event_candidates "`r(varlist)'"
        foreach evar of local _event_candidates {
            local _event_suffix = substr("`evar'", strlen("`date'") + 1, .)
            if "`_event_suffix'" != "" & ///
                regexm("`_event_suffix'", "^[0-9]+$") {
                local _event_index = real("`_event_suffix'")
                local _event_canonical "`date'`_event_index'"
                if `_event_index' < 1 | "`evar'" != "`_event_canonical'" {
                    di as error ///
                        "Recurring event variable `evar' is not a canonical positive-numbered `date'# variable"
                    exit 198
                }
                if `_event_index' > `_event_max' {
                    local _event_max = `_event_index'
                }
            }
        }

        if `_event_max' > 0 {
            forvalues eventnum = 1/`_event_max' {
            capture confirm variable `date'`eventnum'
            if _rc {
                    di as error ///
                        "Recurring event variables must be contiguous; `date'`eventnum' is missing"
                    exit 111
                }
                local eventvars "`eventvars' `date'`eventnum'"
            }
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

    * Required event-source fields are strict by default. A missing event date
    * is a legitimate censored record; a nonmissing fractional daily date is
    * malformed. dropinvalid removes the whole offending event-source row.
    local master_date_vars "`date' `compete'"
    if "`type'" == "recurring" local master_date_vars "`eventvars'"
    tempvar _tve_bad_mid _tve_bad_mdate _tve_bad_master
    quietly generate byte `_tve_bad_mid' = missing(`id')
    quietly generate byte `_tve_bad_mdate' = 0
    foreach dvar of local master_date_vars {
        quietly replace `_tve_bad_mdate' = 1 if ///
            !missing(`dvar') & `dvar' != floor(`dvar')
    }
    quietly generate byte `_tve_bad_master' = ///
        `_tve_bad_mid' | `_tve_bad_mdate'
    quietly count if `_tve_bad_mid'
    local n_invalid_master_id = r(N)
    quietly count if `_tve_bad_mdate'
    local n_invalid_master_dates = r(N)
    quietly count if `_tve_bad_master'
    local n_invalid_master = r(N)

    if `n_invalid_master' > 0 & "`dropinvalid'" == "" {
        noisily display as error "Malformed event input: `n_invalid_master' row(s)"
        noisily display as error ///
            "  missing ID: `n_invalid_master_id'; invalid daily event dates: `n_invalid_master_dates'"
        if "`verbose'" != "" {
            preserve
            quietly keep if `_tve_bad_master'
            noisily list `id' `master_date_vars' in 1/`=min(5, _N)', noobs
            restore
        }
        noisily display as error ///
            "Correct the event data or specify dropinvalid."
        exit 498
    }
    if `n_invalid_master' > 0 {
        quietly drop if `_tve_bad_master'
        noisily display as text ///
            "dropinvalid: removed `n_invalid_master' malformed event row(s)"
    }
    drop `_tve_bad_mid' `_tve_bad_mdate' `_tve_bad_master'

    * Duplicate event rows are supported, but diagnostics count affected IDs
    * exactly once. Person-level keepvars must be constant within ID.
    if _N > 0 {
        tempvar dup_check dup_tag
        quietly bysort `id': generate long `dup_check' = _N
        quietly egen byte `dup_tag' = tag(`id')
        quietly count if `dup_tag' & `dup_check' > 1
        local dup_ids = r(N)
        if `dup_ids' > 0 {
            di as txt "Warning: Master (event) dataset has multiple rows for `dup_ids' person(s)."
            di as txt "         Event data normally use one row per person with event dates in columns."
            if "`type'" == "recurring" {
                di as txt "         For recurring events, use wide format: `date'1, `date'2, etc."
            }
        }
        drop `dup_check' `dup_tag'
    }
    
    * Preserve backward-compatible automatic keepvars, but only for names that
    * cannot be confused with structural or generated output fields. Explicit
    * keepvars() requests remain strict and error on every collision.
    if !`keepvars_explicit' {
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
            * Exclude protected output names from automatic selection
            local is_output : list v in output_names
            if `is_output' & !`is_excluded' {
                local is_excluded = 1
                local auto_keep_excluded "`auto_keep_excluded' `v'"
            }
            if !`is_excluded' {
                local keepvars "`keepvars' `v'"
            }
        }
        local keepvars = strtrim("`keepvars'")
    }

    foreach v of local keepvars {
        capture confirm variable `v'
        if _rc {
            display as error "keepvars() variable `v' not found in the event dataset"
            exit 111
        }
        local keep_output_collision : list v in output_names
        if `keep_output_collision' {
            if `keepvars_explicit' {
                display as error ///
                    "keepvars() variable `v' conflicts with a structural or generated output name"
                exit 198
            }
            local keepvars : list keepvars - v
            local auto_keep_excluded "`auto_keep_excluded' `v'"
        }
    }

    * Validate and stage the interval source once. All later diagnostics and
    * processing consume this clean tempfile, so strict/dropinvalid semantics
    * cannot diverge between the empty-event and ordinary paths.
    local using_display `"`using'"'
    tempfile _tve_clean_using
    preserve
    capture quietly use "`using'", clear
    if _rc {
        local _tve_use_rc = _rc
        noisily display as error ///
            "Interval dataset could not be opened: `using_display'"
        exit `_tve_use_rc'
    }
    quietly count
    if r(N) == 0 {
        noisily display as error "No observations in using (interval) dataset"
        exit 2000
    }
    capture confirm variable `id'
    if _rc {
        noisily display as error ///
            "ID variable `id' not found in using (interval) dataset."
        exit 111
    }
    local _tve_uidtype : type `id'
    if "`_tve_uidtype'" == "strL" {
        noisily display as error ///
            "id() variable `id' is strL in the using dataset; recast it to str# first"
        exit 109
    }
    foreach v in `startvar' `stopvar' {
        capture confirm numeric variable `v'
        if _rc {
            noisily display as error ///
                "Interval variable `v' not found or not numeric in the using dataset"
            exit 109
        }
        local fmt : format `v'
        if substr("`fmt'", 1, 3) == "%tc" | substr("`fmt'", 1, 3) == "%tC" {
            noisily display as error ///
                "Interval variable `v' has datetime format (`fmt'); daily dates are required"
            exit 120
        }
    }

    ds
    local interval_schema "`r(varlist)'"
    foreach v of local keepvars {
        local keep_source_collision : list v in interval_schema
        if `keep_source_collision' {
            if `keepvars_explicit' {
                noisily display as error ///
                    "keepvars() variable `v' already exists in the interval dataset"
                exit 198
            }
            local keepvars : list keepvars - v
            local auto_keep_excluded "`auto_keep_excluded' `v'"
        }
    }

    * Metadata is an executable contract. Every tagged quantity must be named
    * in the matching option, and cumulative histories must be row-start values.
    foreach sourcevar of local interval_schema {
        local source_quantity : char `sourcevar'[tvtools_quantity]
        if "`source_quantity'" != "" {
            if !inlist("`source_quantity'", "rate", "total", "cumulative") {
                noisily display as error ///
                    "Unknown [tvtools_quantity] metadata on `sourcevar': `source_quantity'"
                exit 498
            }
            local declared_quantity ""
            foreach quantity in rate total cumulative {
                local is_declared : list sourcevar in `quantity'
                if `is_declared' local declared_quantity "`quantity'"
            }
            if "`declared_quantity'" == "" {
                noisily display as error ///
                    "Quantity variable `sourcevar' requires explicit `source_quantity'()"
                exit 498
            }
            if "`declared_quantity'" != "`source_quantity'" {
                noisily display as error ///
                    "Quantity metadata conflict for `sourcevar': source is `source_quantity', option declares `declared_quantity'"
                exit 498
            }
        }
    }
    foreach qvar of local all_quantity {
        capture confirm numeric variable `qvar'
        if _rc {
            noisily display as error ///
                "Quantity variable `qvar' not found or not numeric in the interval dataset"
            exit 111
        }
        local quantity_collision : list qvar in output_names
        if `quantity_collision' {
            noisily display as error ///
                "Quantity variable `qvar' conflicts with a structural, generated, time, or recurrence output name"
            exit 198
        }
        local is_cumulative : list qvar in cumulative
        if `is_cumulative' {
            local history_point : char `qvar'[tvtools_history_point]
            if "`history_point'" != "start" {
                noisily display as error ///
                    "Cumulative variable `qvar' requires [tvtools_history_point] = start"
                exit 498
            }
        }
    }

    * Raw interval counts feed the stable 2x3 pipeline flow matrix.
    local _flow_rin = _N
    tempvar _flow_tag
    quietly egen byte `_flow_tag' = tag(`id') if !missing(`id')
    quietly count if `_flow_tag' == 1
    local _flow_pin = r(N)
    drop `_flow_tag'

    tempvar _tve_bad_iid _tve_bad_idate _tve_bad_iorder ///
        _tve_bad_quantity _tve_bad_interval
    quietly generate byte `_tve_bad_iid' = missing(`id')
    quietly generate byte `_tve_bad_idate' = ///
        missing(`startvar') | missing(`stopvar') | ///
        (!missing(`startvar') & `startvar' != floor(`startvar')) | ///
        (!missing(`stopvar') & `stopvar' != floor(`stopvar'))
    quietly generate byte `_tve_bad_iorder' = ///
        !missing(`startvar', `stopvar') & `startvar' > `stopvar'
    quietly generate byte `_tve_bad_quantity' = 0
    foreach qvar of local all_quantity {
        quietly replace `_tve_bad_quantity' = 1 if missing(`qvar')
    }
    quietly generate byte `_tve_bad_interval' = ///
        `_tve_bad_iid' | `_tve_bad_idate' | `_tve_bad_iorder' | ///
        `_tve_bad_quantity'
    quietly count if `_tve_bad_iid'
    local n_invalid_interval_id = r(N)
    quietly count if `_tve_bad_idate'
    local n_invalid_interval_dates = r(N)
    quietly count if `_tve_bad_iorder'
    local n_invalid_interval_order = r(N)
    quietly count if `_tve_bad_quantity'
    local n_invalid_quantity = r(N)
    quietly count if `_tve_bad_interval'
    local n_invalid_intervals = r(N)

    if `n_invalid_intervals' > 0 & "`dropinvalid'" == "" {
        noisily display as error ///
            "Malformed interval input: `n_invalid_intervals' row(s)"
        noisily display as error ///
            "  missing ID: `n_invalid_interval_id'; invalid daily bounds: `n_invalid_interval_dates'; reversed bounds: `n_invalid_interval_order'; missing quantity: `n_invalid_quantity'"
        if "`verbose'" != "" {
            tempvar _tve_stage_order
            quietly generate long `_tve_stage_order' = _n
            quietly gsort -`_tve_bad_interval' `_tve_stage_order'
            noisily list `id' `startvar' `stopvar' `all_quantity' ///
                in 1/`=min(5, _N)', noobs
            quietly sort `_tve_stage_order'
            drop `_tve_stage_order'
        }
        noisily display as error ///
            "Correct the interval data or specify dropinvalid."
        exit 498
    }
    if `n_invalid_intervals' > 0 {
        quietly drop if `_tve_bad_interval'
        noisily display as text ///
            "dropinvalid: removed `n_invalid_intervals' malformed interval row(s)"
    }
    drop `_tve_bad_iid' `_tve_bad_idate' `_tve_bad_iorder' ///
        `_tve_bad_quantity' `_tve_bad_interval'
    quietly count
    if r(N) == 0 {
        noisily display as error "No valid interval rows remain after dropinvalid"
        exit 2000
    }
    quietly save "`_tve_clean_using'", replace
    restore
    local using "`_tve_clean_using'"

    * Interval-side names are known only after staging, so enforce the
    * person-level contract after automatic collision filtering is final.
    local keepvars = strtrim("`keepvars'")
    local auto_keep_excluded : list uniq auto_keep_excluded
    local auto_keep_excluded = strtrim("`auto_keep_excluded'")
    if !`keepvars_explicit' {
        if "`keepvars'" != "" {
            noisily display as text "Auto keepvars preserved: `keepvars'"
        }
        if "`auto_keep_excluded'" != "" {
            noisily display as text ///
                "Auto keepvars excluded (protected output/interval names): `auto_keep_excluded'"
        }
    }
    foreach v of local keepvars {
        if _N > 0 {
            tempvar _tve_kv_diff
            quietly bysort `id': generate byte `_tve_kv_diff' = (`v' != `v'[1])
            quietly count if `_tve_kv_diff'
            if r(N) > 0 {
                display as error ///
                    "keepvars() variable `v' is not uniquely defined within `id'"
                exit 459
            }
            drop `_tve_kv_diff'
        }
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
            tempvar has_event total_events multiple_tag
            gen `has_event' = !missing(`date')
            bysort `id': egen long `total_events' = total(`has_event')
            quietly egen byte `multiple_tag' = tag(`id')
            quietly count if `multiple_tag' & `total_events' > 1
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
        tempvar _tve_event_obs
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
        quietly count
        if r(N) == 0 {
            * A nonempty master with only missing event dates is a legitimate
            * all-censored input. There are no points to send to the matching
            * engine, so the outside-union diagnostic is exactly zero.
            local v_outside = 0
        }
        else {
        generate long `_tve_event_obs' = _n
        save `master_events', replace

        * Match points against the actual union of closed interval rows. The
        * shared half-open engine receives [start, stop+1), which is exactly the
        * closed daily interval [start, stop]. An event is outside when its row
        * identifier has no match in any interval, including internal gaps.
        use "`using'", clear
        keep `id' `startvar' `stopvar'
        duplicates drop
        tempvar _tve_viobs _tve_vgid _tve_vhi
        generate long `_tve_viobs' = _n
        tempfile _tve_val_intervals _tve_val_xwalk _tve_val_matched
        save `_tve_val_intervals', replace
        keep `id'
        duplicates drop
        generate long `_tve_vgid' = _n
        save `_tve_val_xwalk', replace

        use `_tve_val_intervals', clear
        merge m:1 `id' using `_tve_val_xwalk', keep(match) nogenerate
        generate double `_tve_vhi' = `stopvar' + 1
        frame put `_tve_vgid' `startvar' `_tve_vhi' `_tve_viobs', ///
            into(`_te_master_frame')
        frame `_te_master_frame': order `_tve_vgid' `startvar' `_tve_vhi' `_tve_viobs'

        use `master_events', clear
        merge m:1 `id' using `_tve_val_xwalk', keep(match) nogenerate
        frame put `_tve_vgid' _event_date `_tve_event_obs', ///
            into(`_te_using_frame')
        frame `_te_using_frame': order `_tve_vgid' _event_date `_tve_event_obs'

        capture findfile _tvmerge_mata.ado
        if _rc == 0 run "`r(fn)'"
        else exit 111
        frame create `_te_output_frame'
        _tvmerge_point_pairs `_te_master_frame' `_te_using_frame' `_te_output_frame'
        frame `_te_output_frame': keep __tvm_ui
        frame `_te_output_frame': rename __tvm_ui `_tve_event_obs'
        frame `_te_output_frame': duplicates drop
        frame `_te_output_frame': generate byte _tve_matched = 1
        frame `_te_output_frame': save `_tve_val_matched', replace
        frame drop `_te_master_frame'
        frame drop `_te_using_frame'
        frame drop `_te_output_frame'

        use `master_events', clear
        merge 1:1 `_tve_event_obs' using `_tve_val_matched', nogenerate
        count if missing(_tve_matched)
        local v_outside = r(N)
        } // end one-or-more nonmissing validation events
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

        local master_N = _N
        tempfile events

        * Save keepvars for ALL people before filtering to events-only
        if "`keepvars'" != "" {
            tempfile _all_keepvars
            preserve
            keep `id' `keepvars'
            bysort `id': keep if _n == 1
            save `_all_keepvars'
            restore
        }

        * Capture labels before event rows are reshaped or filtered away.
        if "`type'" == "recurring" {
            local first_evar : word 1 of `eventvars'
            local orig_date_label : variable label `first_evar'
            local lab_1 "`orig_date_label'"
            if "`lab_1'" == "" local lab_1 "Event: `date'"
            local num_compete = 0
        }
        else {
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
        }

        * Empty and all-missing event inputs now enter the ordinary interval
        * pipeline with a typed zero-row event table. This guarantees the same
        * generate/time/recurrence schema and r() contract on every path.
        if `master_N' == 0 {
            noisily di as txt ///
                "Note: Event dataset is empty. All intervals will be marked as censored."
            keep `id'
            generate double `date' = .
            generate int _event_type = .
            save `events', replace
            local n_event_rows = 0
        }
        else if "`type'" == "recurring" {
            * --- RECURRING EVENTS: Reshape wide to long ---

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

            * An all-missing recurring master follows the same typed empty
            * event-table path as an empty master and an all-missing single
            * master. Do not call duplicates on a zero-observation reshape.
            if _N == 0 {
                noisily di as txt ///
                    "Note: All recurring event dates are missing. All intervals will be marked as censored."
                keep `id'
                capture drop `date'
                generate double `date' = .
                generate int _event_type = .
                save `events', replace
                local n_event_rows = 0
            }
            else {
                * Floor dates and set event type (all are type 1 for recurring)
                replace `date' = floor(`date')
                gen int _event_type = 1

                * Same-person/same-day event multiplicity is rejected, not
                * dropped. The daily axis carries at most one event flag per
                * person-day, so two recurring events recorded on one day
                * cannot both be represented. Force-dropping them reported
                * "Found N event variables" and then silently returned fewer
                * events than the master documented -- a lost outcome at
                * rc=0. The caller must resolve the multiplicity explicitly.
                tempvar _dup_ev
                quietly duplicates tag `id' `date', gen(`_dup_ev')
                quietly count if `_dup_ev' > 0
                if r(N) > 0 {
                    local n_dup_ev = r(N)
                    quietly levelsof `id' if `_dup_ev' > 0, local(_dup_ev_ids) clean
                    noisily display as error "`n_dup_ev' recurring event row(s) share a person-day with another event"
                    noisily display as error "The daily time axis records at most one event per person per day."
                    noisily display as error "Affected id(s): `_dup_ev_ids'"
                    noisily display as error "Collapse the same-day events to one, or move them to distinct days."
                    exit 459
                }
                drop `_dup_ev'

                * Sort by id and date for proper processing
                sort `id' `date'
                quietly count
                local n_event_rows = r(N)
                save `events', replace
            }
        }
        else {
            * --- SINGLE EVENTS: Original logic with competing risks ---

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

            * All-missing dates produce the same typed empty event table.
            if _N == 0 {
                noisily di as txt "Note: All event dates are missing. All intervals will be marked as censored."
                keep `id'
                capture drop `date'
                generate double `date' = .
                generate int _event_type = .
                save `events', replace
                local n_event_rows = 0
            }
            else {
                capture drop `date'
                rename _eff_date `date'
                rename _eff_type _event_type
                keep `id' `date' _event_type
                * Rows that agree on id, date, and resolved type carry no
                * extra information and collapse safely. Rows that agree on
                * (id, date) but disagree on type are a genuine ambiguity:
                * force-dropping them let row order pick the event type.
                duplicates drop `id' `date' _event_type, force
                tempvar _dup_ty
                quietly duplicates tag `id' `date', gen(`_dup_ty')
                quietly count if `_dup_ty' > 0
                if r(N) > 0 {
                    local n_dup_ty = r(N)
                    quietly levelsof `id' if `_dup_ty' > 0, local(_dup_ty_ids) clean
                    noisily display as error "`n_dup_ty' record(s) give one person conflicting event types on the same day"
                    noisily display as error "Affected id(s): `_dup_ty_ids'"
                    noisily display as error "Resolve the competing-risk type for those person-days before calling tvevent."
                    exit 459
                }
                drop `_dup_ty'
                quietly count
                local n_event_rows = r(N)
                save `events', replace
            }
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

        * Check replace policy for every variable created in interval data.
        local created_outputs "`generate' `date'"
        if "`timegen'" != "" local created_outputs "`created_outputs' `timegen'"
        if `do_recur_fmt' local created_outputs "`created_outputs' `enum'"
        if `do_gaptime' local created_outputs "`created_outputs' `gapstart' `gapstop'"
        if "`replace'" == "" {
            foreach outvar of local created_outputs {
                capture confirm variable `outvar'
                if _rc == 0 {
                    noisily di as error ///
                        "Variable `outvar' already exists in using dataset. Use replace option."
                    exit 110
                }
            }
        }
        else {
            foreach outvar of local created_outputs {
                capture drop `outvar'
            }
        }

        _tvtools_new_vallabel, base(`_ev_lbl_base')
        local _ev_lbl_name "`r(name)'"

        * Warn if interval data has variables matching the date stub pattern.
        * Scan the full `date'* namespace (not a fixed 1..20 window) so a stub
        * like `date'25 on an interval needing >20 splits is still caught with a
        * curated message instead of reshape's raw r(110) (F10b). Same
        * canonical-suffix filter as the recurring-event scan above.
        local stub_collisions = 0
        capture ds `date'*
        if _rc == 0 local _stub_cands "`r(varlist)'"
        foreach _cand of local _stub_cands {
            local _sfx = substr("`_cand'", strlen("`date'") + 1, .)
            if "`_sfx'" != "" & regexm("`_sfx'", "^[0-9]+$") {
                local _idx = real("`_sfx'")
                if `_idx' >= 1 & "`_cand'" == "`date'`_idx'" {
                    local stub_collisions = `stub_collisions' + 1
                }
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
        tempfile splits

        if `n_event_rows' == 0 {
            use `events', clear
            keep `id' `date'
            save `splits', replace
            local n_splits = 0
        }
        else {

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
        tempvar te_iobs te_gid te_eobs
        gen long `te_iobs' = _n
        tempfile __te_ivl
        save `__te_ivl'

        * id -> contiguous gid crosswalk (interval ids; events keep(match) below
        * drops events for ids with no interval, matching the joinby inner join).
        keep `id'
        duplicates drop
        gen long `te_gid' = _n
        tempfile __te_xw
        save `__te_xw'

        * master interval work frame: gid start stop obs
        use `__te_ivl', clear
        merge m:1 `id' using `__te_xw', keep(match) nogenerate
        frame put `te_gid' `startvar' `stopvar' `te_iobs', into(`_te_master_frame')
        frame `_te_master_frame': order `te_gid' `startvar' `stopvar' `te_iobs'

        * using point work frame: gid date obs (events indexed by `te_eobs')
        use `events', clear
        gen long `te_eobs' = _n
        tempfile __te_eidx
        save `__te_eidx'
        merge m:1 `id' using `__te_xw', keep(match) nogenerate
        frame put `te_gid' `date' `te_eobs', into(`_te_using_frame')
        frame `_te_using_frame': order `te_gid' `date' `te_eobs'

        frame create `_te_output_frame'
        _tvmerge_point_pairs `_te_master_frame' `_te_using_frame' `_te_output_frame'
        tempfile __te_pairs
        frame `_te_output_frame': save `__te_pairs'
        frame drop `_te_master_frame'
        frame drop `_te_using_frame'
        frame drop `_te_output_frame'

        * Distinct matched events -> their (id, date) split points.
        use `__te_pairs', clear
        keep __tvm_ui
        rename __tvm_ui `te_eobs'
        if _N > 0 {
            duplicates drop
            merge m:1 `te_eobs' using `__te_eidx', keep(match) nogenerate ///
                keepusing(`id' `date')
        }
        else {
            merge 1:1 `te_eobs' using `__te_eidx', keep(match) nogenerate ///
                keepusing(`id' `date')
        }
        keep `id' `date'
        if _N > 0 {
            duplicates drop `id' `date', force
        }
        save `splits', replace

        count
        local n_splits = r(N)
        }
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

        * Interval totals are the only algebra adjusted by a split. Rates and
        * row-start cumulative histories are invariant across the new rows.
        if "`total'" != "" {
            tempvar new_dur ratio
            gen double `new_dur' = `stopvar' - `startvar' + 1
            gen double `ratio' = cond(_orig_dur == 0 | `new_dur' == 0, 1, `new_dur' / _orig_dur)
            foreach v of local total {
                replace `v' = `v' * `ratio'
            }
            drop `new_dur' `ratio'
        }
        drop _orig_dur _orig_interval_id
        foreach v of local rate {
            char `v'[tvtools_quantity] "rate"
        }
        foreach v of local total {
            char `v'[tvtools_quantity] "total"
        }
        foreach v of local cumulative {
            char `v'[tvtools_quantity] "cumulative"
            char `v'[tvtools_history_point] "start"
        }

        **# 5. MERGE EVENT FLAGS

        * keepvars for all people already saved in _all_keepvars

        if `n_event_rows' == 0 {
            generate long `generate' = 0
            generate double `date' = .
            if `"`orig_date_label'"' != "" {
                label variable `date' `"`orig_date_label'"'
            }
            else label variable `date' "Event date"
        }
        else {
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

                * Boundary events (date == stop) are flagged but not split.
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

            if `frame_rc' != 0 {
                exit `frame_rc'
            }

            drop `match_date' `imported_type'
        }

        * Merge person-level covariates by id (not tied to event date)
        if "`keepvars'" != "" {
            merge m:1 `id' using `_all_keepvars', keep(master match) nogen
        }

        **# 6. APPLY LABELS
        
        * A. Define Defaults (from Variable Labels)
        * Drop any same-named label loaded from the using file (e.g. when the
        * intervals are a prior tvevent output); label define has no replace-
        * from-scratch form and errors r(110) on an existing name.
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
            * The first event is defined by its DATE, not by row position.
            * The previous rule ranked rows (sum of generate>0 in sort order)
            * and kept only rank 1. When a person legitimately has several
            * rows sharing one (id, start, stop) -- the per-stratum rows that
            * tvexpose, split produces -- those rows describe one event seen
            * in different strata of the same person-time, not a sequence of
            * events. Ranking rows kept the failure on whichever tied row
            * happened to sort first, so reversing two otherwise identical
            * input rows moved the failure to a different stratum at rc=0.
            tempvar ev_date
            gen double `ev_date' = `stopvar' if `generate' > 0
            bysort `id': egen double _first_fail = min(`ev_date')

            * Events after the first are censored; ties on the first date are
            * all retained, because they are the same event.
            replace `generate' = 0 if `generate' > 0 & ///
                !missing(_first_fail) & `stopvar' > _first_fail

            * An event belongs to exactly one person-time cell. Rows sharing
            * (id, start, stop) are one cell observed in several strata, so
            * they all keep the flag. Flagged rows drawn from two DIFFERENT
            * cells mean the input intervals overlap, and which cell the
            * event fell in is then genuinely ambiguous: refuse rather than
            * let row order decide, and never double-count one event.
            tempvar cellkey celltag ncells
            quietly egen long `cellkey' = group(`startvar' `stopvar') ///
                if `generate' > 0
            quietly bysort `id' `cellkey': generate byte `celltag' = ///
                (_n == 1) & `generate' > 0
            quietly bysort `id': egen long `ncells' = total(`celltag')
            quietly count if `ncells' > 1
            if r(N) > 0 {
                quietly levelsof `id' if `ncells' > 1, local(_amb_ids) clean
                noisily display as error "Ambiguous event placement: overlapping intervals both contain the first event"
                noisily display as error "Affected id(s): `_amb_ids'"
                noisily display as error "Under the closed [start, stop] contract an interval that ends on day d"
                noisily display as error "and one that begins on day d share day d. Abutting intervals must begin"
                noisily display as error "on prior_stop + 1. Correct the intervals, or use type(recurring)."
                exit 459
            }
            drop `cellkey' `celltag' `ncells'

            * Under [start, stop] inclusive convention, post-event intervals
            * have start > event_date. Keep every row carrying the first
            * event (which may have start == _first_fail for one-day rows).
            drop if !missing(_first_fail) & `startvar' >= _first_fail ///
                & !(`generate' > 0)

            drop `ev_date' _first_fail
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

    * Flow is returned whenever requested or whenever dropinvalid authorizes
    * attrition. It remains a 2x3 interval-pipeline matrix for API stability.
    if `_return_flow' {
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

    return scalar n_invalid = `n_invalid_master' + `n_invalid_intervals'
    return scalar n_invalid_master = `n_invalid_master'
    return scalar n_invalid_master_id = `n_invalid_master_id'
    return scalar n_invalid_master_dates = `n_invalid_master_dates'
    return scalar n_invalid_intervals = `n_invalid_intervals'
    return scalar n_invalid_interval_id = `n_invalid_interval_id'
    return scalar n_invalid_interval_dates = `n_invalid_interval_dates'
    return scalar n_invalid_interval_order = `n_invalid_interval_order'
    return scalar n_invalid_quantity = `n_invalid_quantity'
    return scalar n_rate = `n_rate_quantity'
    return scalar n_total = `n_total_quantity'
    return scalar n_cumulative = `n_cumulative_quantity'
    return scalar n_continuous = `n_continuous_quantity'
    return local rate_vars "`rate'"
    return local total_vars "`total'"
    return local cumulative_vars "`cumulative'"
    return local continuous_vars "`continuous_vars'"

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

    * Remove private engine frames if an error interrupted the normal cleanup.
    capture frame drop `_te_master_frame'
    local _te_cleanup_rc = _rc
    capture frame drop `_te_using_frame'
    local _te_cleanup_rc = _rc
    capture frame drop `_te_output_frame'
    local _te_cleanup_rc = _rc

    if `rc' & `_caller_snapshot_ready' {
        capture restore
        if `_caller_snap_taken' capture quietly use "`_tve_caller_snap'", clear
        else {
            capture quietly clear
            if `_caller_zero_var_obs' > 0 capture quietly set obs `_caller_zero_var_obs'
        }
        local _te_cleanup_rc = _rc
    }

    set varabbrev `orig_varabbrev'

    if `rc' {
        exit `rc'
    }

end
