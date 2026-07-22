*! tvexpose Version 1.8.0  2026/07/22
*! Create time-varying exposure variables for survival analysis
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tvexpose using filename, id(varname) start(varname) ///
    exposure(varname) reference(#) entry(varname) exit(varname) ///
    [stop(varname) options]

Required core options:
  using filename       - Dataset containing exposure periods
  id(varname)          - Person identifier (links to master dataset)
  start(varname)       - Start date of exposure period
  stop(varname)        - End date of exposure period (optional if pointtime specified)
  exposure(varname)    - Exposure variable: categorical status OR dose amount (with dose option)
  reference(#)         - Value indicating unexposed/reference status (not allowed with dose)
  entry(varname)       - Study entry date (from master dataset in memory)
  exit(varname)        - Study exit date (from master dataset in memory)

Exposure definition options (choose one):
  (none)               - Time-varying exposure (default)
  evertreated          - Binary ever/never exposed (switches at first exposure)
  currentformer        - Trichotomous never/current/former (0=never, 1=current, 2=former)
  duration(numlist)    - Cumulative duration categories (cutpoints)
                         Calculation uses continuousunit() (defaults to years if not specified).
                         duration() recodes the continuous cumulative exposure into categories.
                         Example: duration(1 5) creates: unexposed, <1, 1-<5, 5+ 
  recency(numlist)     - Time since last exposure categories (cutpoints)
  dose                 - Cumulative dose tracking (exposure() contains dose amounts)
                         When periods overlap, dose is allocated proportionally
                         Example: Two 30-day prescriptions of 1g with 10-day overlap:
                         During overlap: ((10/30)*1) + ((10/30)*1) = 0.667g
  dosecuts(numlist)    - Cutpoints for dose categorization (use with dose)
                         Example: dose dosecuts(5 10 20) creates: 0, <5, 5-<10, 10-<20, 20+
  continuousunit(unit) - Cumulative exposure reporting unit (required for continuous exposure)
                         units are {days, weeks, months, quarters, years}
                         Reporting units: generated tv_exp_* variables report cumulative exposure
                         in the specified unit (e.g., days, months, years).
                         Example: continuousunit(years) reports cumulative YEARS of exposure.
                         When used with duration(), specifies the unit for cutpoints.
  expandunit(unit)     - Row expansion granularity for continuous exposure (optional)
                         units are {days, weeks, months, quarters, years}
                         Defaults to match continuousunit() if not specified.
                         Row expansion (fixed average-width bins anchored at
                         each episode start, NOT calendar boundaries):
                           • days    → No row expansion; one row per original exposure period
                           • weeks   → 7-day bins starting at exposure start
                           • months  → 30.4375-day bins from exposure start
                           • quarters→ 91.3125-day bins from exposure start
                           • years   → 365.25-day bins from exposure start
                         Example 1: continuousunit(years) expandunit(months) creates one row per
                         ~30.44-day bin and reports cumulative YEARS of exposure.
                         Example 2: continuousunit(days) expandunit(weeks) creates 7-day bins
                         and reports cumulative DAYS of exposure.
                         Unexposed periods are never expanded.

Additional exposure options:
  bytype               - Create separate variables for each exposure type
                         Works with: evertreated, currentformer, duration, continuous, recency
                         Without bytype: single variable tracks exposure across all types
                         With bytype: separate variables track each exposure type independently
                         Examples:
                           • evertreated bytype → ever1, ever2, ... (binary per type)
                           • currentformer bytype → cf1, cf2, ... (0/1/2 per type)
                           • duration() bytype → duration1, duration2, ... (categories per type)
                           • continuous bytype → tv_exp1, tv_exp2, ... (continuous per type)
                           • recency() bytype → recency1, recency2, ... (categories per type)

Data handling and cleaning options:
  grace(#)             - Days grace period to merge gaps (default: 0)
  grace(exp=# exp=...) - Different grace periods by exposure category
  merge(#)             - Days within which to merge same-type periods (default: 0)
  pointtime            - Data are point-in-time (start only, no stop date)
  fillgaps(#)          - Assume exposure continues # days beyond last record
  carryforward(#)      - Carry forward last exposure # days through gaps

Competing and overlapping exposure options:
  priority(numlist)    - Priority order when periods overlap (higher priority first)
  layer                - Later exposures take precedence; earlier resume after overlap
  split                - Split overlapping periods at all boundaries
  combine(newvar)      - Create combined exposure variable for overlapping periods

Lag and washout period options:
  lag(#)               - Days lag before exposure becomes active
  washout(#)           - Days exposure persists after stopping
  window(# #)          - Min and max days for acute exposure window

Exposure pattern and switching options:
  switching            - Create binary indicator for any exposure switching
  switchingdetail      - Create string variable showing switching pattern
  statetime            - Create cumulative time in current exposure state

Output and naming options:
  generate(newvar)     - Output name (default: tv_<exposure>; safe fallback tv_exposure)
  referencelabel(text) - Label for reference category (default: "Unexposed")
  saveas(filename)     - Save time-varying dataset to file
  replace              - Overwrite existing output file
  keepvars(varlist)    - Additional variables to keep from master dataset

Diagnostic and validation options:
  check                - Display coverage diagnostics by person
  gaps                 - Show persons with gaps in coverage
  overlaps             - Show overlapping exposure periods
  summarize            - Display exposure distribution summary
  validate             - Create validation dataset with coverage metrics

Additional output options:
  keepdates            - Keep Entry and Exit dates in output (dropped by default)

See help tvexpose for complete documentation with examples
*/

program define tvexpose, rclass
    version 16.0
    local orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _frameout_snap_taken = 0    // init before block for error-path restore
    local _caller_snapshot_ready = 0
    local _combo_n = 0                // combine() allocated-code count
    local _combo_map ""               // combine() code -> composition map
    local _bt_n = 0                   // bytype derived-variable count
    local _bt_map ""                  // bytype value -> variable map

    capture noisily {

    * Load helper libraries for modular architecture
    * - Mata library: O(n log n) overlap detection
    * - Diagnostic library: coverage, gaps, overlaps, summary, validation
    capture findfile _tvexpose_mata.ado
    if _rc == 0 {
        quietly run "`r(fn)'"
    }
    else {
        noisily display as error "_tvexpose_mata.ado not found; reinstall tvtools"
        exit 111
    }

    syntax using/ , ///
        id(name) ///
        start(name) ///
        exposure(name) ///
        entry(varname) ///
        exit(varname) ///
        [stop(name) ///
        reference(numlist max=1) ///
        generate(name) ///
        SAVEas(string) ///
        FRAMEOut(name) ///
        replace ///
        merge(integer 0) ///
        EVERtreated ///
        CURrentformer ///
        DURation(numlist ascending) ///
        DOse ///
        DOsecuts(numlist ascending) ///
        CONTINUOUSunit(string) ///
        EXPANDunit(string) ///
        BYtype ///
        RECency(numlist ascending) ///
        RECENCYunit(string) ///
        GRACE(string) ///
        LAG(integer 0) ///
        WASHout(integer 0) ///
        POINTtime ///
        FILLgaps(integer 0) ///
        CARRYforward(integer 0) ///
        KEEPvars(varlist) ///
        CHECK ///
        GAPS ///
        OVERlaps ///
        SUMmarize ///
        VALidate ///
        PRIority(numlist) ///
        SPLIT ///
        LAYer ///
        COMbine(name) ///
        WINdow(numlist min=2 max=2) ///
        SWitching ///
        SWitchingdetail ///
        STATEtime ///
        KEEPdates ///
        REFERENCElabel(string) ///
        LABel(string) ///
        FLOW ///
        DROPinvalid ///
        VERBose]
    
    * Check that stop() is provided OR pointtime is specified
    * If neither is provided, the command cannot proceed meaningfully
    if "`pointtime'" == "" & "`stop'" == "" {
        noisily display as error "stop(varname) required unless pointtime specified"
        exit 198
    }
    
    * Check for by: usage - tvexpose cannot be used with by:
    if "`_byvars'" != "" {
        di as error "tvexpose cannot be used with by:"
        exit 190
    }

    * Frames-first output: when frameout() is set, the time-varying result is
    * placed into the named frame and the caller's current data is left intact,
    * so the pipeline never has to round-trip through disk. The internal logic
    * still builds the result in the working frame; we snapshot the caller's
    * data first and reload it after copying the result into the target frame.
    if "`frameout'" != "" {
        if "`frameout'" == "`c(frame)'" {
            noisily display as error "frameout() must name a frame other than the current frame"
            exit 198
        }
        capture frame `frameout': describe
        if _rc == 0 & "`replace'" == "" {
            noisily display as error "frame `frameout' already exists; use replace option"
            exit 110
        }
    }

    * Success may replace the caller's master data with the constructed output;
    * a failed run must never do so, regardless of frameout().
    if c(k) > 0 {
        tempfile _tvx_caller_snap
        quietly save "`_tvx_caller_snap'", replace
        local _frameout_snap_taken = 1
    }
    local _caller_snapshot_ready = 1

    * Stable attrition and integrity returns are initialized for every path.
    local n_invalid_master = 0
    local n_invalid_master_id = 0
    local n_invalid_master_dates = 0
    local n_invalid_master_order = 0
    local n_invalid_exposure = 0
    local n_invalid_exposure_id = 0
    local n_invalid_exposure_dates = 0
    local n_invalid_exposure_order = 0
    local n_invalid_exposure_value = 0
    local n_unmatched_exposure = 0
    local n_outside_window = 0
    local n_lag_removed = 0
    local n_uncovered_days = 0
    local n_unresolved_overlaps = 0
    local _return_flow = ("`flow'" != "" | "`dropinvalid'" != "")

    * Handle reference() option
    * - For dose mode: reference defaults to 0 (the only valid value)
    * - For other modes: reference is required
    if "`dose'" != "" {
        * Dose mode: default to 0 if not specified, error if non-zero
        if "`reference'" == "" {
            local reference 0
        }
        else if `reference' != 0 {
            noisily display as error "reference() must be 0 when dose is specified"
            noisily display as error "For dose, 0 cumulative dose is the inherent reference"
            exit 198
        }
    }
    else {
        * Non-dose mode: reference is required
        if "`reference'" == "" {
            noisily display as error "reference() is required"
            noisily display as error "Specify the exposure value that represents the reference category"
            exit 198
        }
    }

    * Check that dosecuts() requires dose
    if "`dosecuts'" != "" & "`dose'" == "" {
        noisily display as error "dosecuts() requires the dose option"
        noisily display as error "Example: tvexpose ..., dose dosecuts(5 10 20)"
        exit 198
    }

    * recency() formerly had contradictory day/year contracts. Version 1.7
    * requires the unit and converts every cutpoint once to an integer day.
    if "`recency'" == "" & "`recencyunit'" != "" {
        noisily display as error "recencyunit() requires recency()"
        exit 198
    }
    if "`recency'" != "" {
        if "`recencyunit'" == "" {
            noisily display as error "recency() requires recencyunit(days|years)"
            noisily display as error "The unit is required because earlier releases documented years but computed days."
            exit 198
        }
        local recency_unit = lower(trim("`recencyunit'"))
        if !inlist("`recency_unit'", "days", "years") {
            noisily display as error "recencyunit() must be days or years"
            exit 198
        }

        local recency_cutdays ""
        local recency_previous = 0
        local recency_i = 0
        foreach recency_cut of numlist `recency' {
            local recency_i = `recency_i' + 1
            if `recency_cut' <= 0 {
                noisily display as error "recency() cutpoints must be positive"
                exit 198
            }
            if "`recency_unit'" == "days" {
                if `recency_cut' != floor(`recency_cut') {
                    noisily display as error "recency() day cutpoints must be whole numbers"
                    exit 198
                }
                local recency_days = `recency_cut'
            }
            else {
                local recency_days = round(365.25 * `recency_cut')
            }
            if `recency_days' <= `recency_previous' {
                noisily display as error "recency() cutpoints must convert to unique increasing whole-day boundaries"
                exit 198
            }
            local recency_cutday`recency_i' = `recency_days'
            local recency_cutdays "`recency_cutdays' `recency_days'"
            local recency_previous = `recency_days'
        }
        local recency_cutdays = trim("`recency_cutdays'")
    }
    
    * Validate variable name lengths (Stata allows up to 32 characters)
    foreach opt in id start stop exposure generate combine {
        if "``opt''" != "" {
            local len = strlen("``opt''")
            if `len' > 32 {
                noisily display as error "Variable name too long: ``opt'' (`len' characters)"
                noisily display as error "Stata variable names must be 32 characters or fewer"
                exit 198
            }
        }
    }

    * Validate generate() doesn't collide with output structural names
    if "`generate'" == "start" | "`generate'" == "stop" {
        noisily display as error "generate(`generate') conflicts with output variable name"
        noisily display as error "The output dataset uses 'start' and 'stop' as time variables"
        exit 198
    }
    if "`generate'" == "`id'" {
        noisily display as error "generate(`generate') conflicts with id variable name"
        exit 198
    }

    * Validate combine() doesn't collide with output structural names
    if "`combine'" != "" {
        if "`combine'" == "start" | "`combine'" == "stop" {
            noisily display as error "combine(`combine') conflicts with output variable name"
            noisily display as error "The output dataset uses 'start' and 'stop' as time variables"
            exit 198
        }
        if "`combine'" == "`id'" {
            noisily display as error "combine(`combine') conflicts with id variable name"
            exit 198
        }
        if "`combine'" == "`generate'" {
            noisily display as error "combine(`combine') conflicts with generate() variable name"
            exit 198
        }
    }

    * Lock sample in master dataset
    marksample touse
    quietly count if `touse'
    if r(N) == 0 {
        error 2000  // no observations
    }

    * Flow accounting: capture input persons/records (egen tag does not reorder)
    if `_return_flow' {
        quietly count if `touse'
        local _flow_rin = r(N)
        tempvar _flow_tag
        quietly egen byte `_flow_tag' = tag(`id') if `touse'
        quietly count if `_flow_tag' == 1
        local _flow_pin = r(N)
        drop `_flow_tag'
    }
    
    * Set default values. Without bytype, omitted generate() normally derives
    * tv_<exposure>; tv_exposure remains only the safe fallback documented below.
    * When bytype is specified, generate() becomes the stub name for bytype variables
    if "`bytype'" != "" {
        * With bytype, if generate() is specified, use it as stub; otherwise use defaults
        if "`generate'" == "" {
            * Use default stubs based on exposure type
            if "`evertreated'" != "" local stub_name "ever"
            else if "`currentformer'" != "" local stub_name "cf"
            else if "`duration'" != "" local stub_name "duration"
            else if "`continuousunit'" != "" local stub_name "tv_exp"
            else if "`recency'" != "" local stub_name "recency"
            else local stub_name "exp"
        }
        else {
            * User specified generate() with bytype - use it as stub
            local stub_name "`generate'"
        }
        * Validate stub length: derived names are {stub}{suffix} and
        * {stub}labels_{suffix}. The "labels_" infix adds 7 chars.
        * Suffix is at least 1 char, so stub must be <= 24.
        local stub_len = strlen("`stub_name'")
        if `stub_len' > 24 {
            noisily display as error "generate() stub '`stub_name'' is too long for bytype"
            noisily display as error "With bytype, derived names ({it:stub}labels_{it:N}) must fit in 32 characters"
            noisily display as error "Maximum stub length is 24 characters (yours is `stub_len')"
            exit 198
        }
        * Set a flag indicating we should not create the main variable
        local skip_main_var = 1
    }
    else {
        * Without bytype, generate() is the name of the single output variable.
        * When generate() is omitted, derive the output name from the exposure
        * varname (tv_<exposure>) so distinct exposures get distinct names and
        * tvmerge/tvevent chain without manual renames. Fall back to the
        * historical "tv_exposure" only when the derived name would be illegal,
        * too long (>32 chars), or collide with the id or combine() variable.
        if "`generate'" == "" {
            local _derived "tv_`exposure'"
            local _use_derived = 1
            if strlen("`_derived'") > 32                          local _use_derived = 0
            if "`_derived'" == "`id'"                             local _use_derived = 0
            if "`combine'" != "" & "`_derived'" == "`combine'"    local _use_derived = 0
            capture confirm name `_derived'
            if _rc                                                local _use_derived = 0
            if `_use_derived' {
                local generate "`_derived'"
                noisily display as text "Note: output exposure variable named {bf:`generate'} (from exposure(`exposure')); use generate() to override."
            }
            else {
                local generate "tv_exposure"
            }
        }
        local skip_main_var = 0
    }

    **# Output namespace preflight
    * Resolve every name the command will commit BEFORE any data are mutated,
    * and reject collisions here rather than discovering them at commit time.
    *
    * The final block renames the structural bounds back to the caller's
    * option names with a captured rename whose return code was never
    * inspected. start(rx_start) together with generate(rx_start) therefore
    * returned rc=0 having committed a dataset whose start bound was still
    * called "start" while "rx_start" held the exposure: a wrong schema with
    * no error. Resolving the full output name set up front makes that
    * unrepresentable, and the commit renames below are now checked.
    local _out_names "`id' `start'"
    if "`stop'" != ""     local _out_names "`_out_names' `stop'"
    if `skip_main_var' == 0 local _out_names "`_out_names' `generate'"
    if "`combine'" != ""  local _out_names "`_out_names' `combine'"
    if "`keepvars'" != "" local _out_names "`_out_names' `keepvars'"
    if "`keepdates'" != "" local _out_names "`_out_names' study_entry study_exit"

    local _out_dups : list dups _out_names
    if "`_out_dups'" != "" {
        noisily display as error "Output name collision: `_out_dups'"
        noisily display as error "id(), start(), stop(), generate(), combine(), keepvars(), and the"
        noisily display as error "kept study dates must all resolve to distinct output names."
        noisily display as error "No output was committed."
        exit 198
    }

    * The command builds its output under the reserved working names id,
    * start, stop, study_entry, and study_exit before renaming back. A
    * requested output name that equals a reserved name it is not entitled
    * to would be destroyed by that machinery, so reject it here.
    local _reserved "study_entry study_exit"
    local _claimed "`generate' `combine' `keepvars'"
    if "`keepdates'" != "" local _claimed ""
    foreach _nm of local _claimed {
        local _is_reserved : list _nm in _reserved
        if `_is_reserved' {
            noisily display as error "'`_nm'' is a reserved working name in tvexpose output"
            noisily display as error "Rename the variable, or specify keepdates to retain the study dates."
            exit 198
        }
    }

    * Set default reference label if not specified
    if "`referencelabel'" == "" local referencelabel "Unexposed"
    
    * Flag error if bytype with default or dose
    if (("`evertreated'" == "") & ("`currentformer'" == "") & ("`duration'" == "") & ///
        ("`continuousunit'" == "") & ("`recency'" == "") & ("`dose'" == "")) & ("`bytype'" != "") {
        noisily display as error "bytype may not be specified with the default time-varying option"
        exit 198
    }

    * Flag error if bytype with dose (dose does not support bytype)
    if "`dose'" != "" & "`bytype'" != "" {
        noisily display as error "bytype may not be specified with dose"
        noisily display as error "To analyze doses by drug type, run tvexpose separately for each type"
        exit 198
    }

    * Validate mutually exclusive exposure type options
    * User may specify only ONE of: evertreated, currentformer, duration(), continuous(unit), recency(), dose()
    * Note: duration() may be combined with continuousunit() to specify units
    * Specifying multiple would create ambiguous output, so we reject this
    local n_types = ("`evertreated'" != "") + ("`currentformer'" != "") + ("`duration'" != "") + ///
                    (("`continuousunit'" != "") & ("`duration'" == "")) + ("`recency'" != "") + ///
                    ("`dose'" != "")
    if `n_types' > 1 {
        noisily display as error "Only one exposure type can be specified: evertreated, currentformer, duration(), continuous(unit), recency(), or dose()"
        noisily display as error "Note: duration() may be combined with continuousunit() to specify units"
        exit 198
    }

    * Validate mutually exclusive overlap handling options
    * User may specify only ONE approach to handling overlapping exposures
    local n_overlap = ("`priority'" != "") + ("`split'" != "") + ///
                      ("`combine'" != "") + ("`layer'" != "")
    if `n_overlap' > 1 {
        noisily display as error "Only one overlap handling option can be specified: priority(), split, layer, or combine()"
        exit 198
    }
    
    * NOTE: Default to layer is set AFTER overlap detection/warning block
    * so the warning can fire when no overlap option is specified
    
    * Additional validation: split requires non-reference exposure categories
    if "`split'" != "" {
        noisily display as text "Note: split option will create separate periods at all exposure boundaries"
    }
    
    * Validate window option format
    * window() specifies min and max days for acute exposure effect window
    * Format: window(# #) where first number < second number
    if "`window'" != "" {
        tokenize `window'
        if `1' >= `2' {
            noisily display as error "window() must be specified as (min max) with min < max"
            exit 198
        }
        local window_min = `1'
        local window_max = `2'
        macro drop _1 _2
    }
    
    * Validate numeric parameters must be non-negative
    * These parameters control time adjustments and should not be negative
    if `merge' < 0 {
        noisily display as error "merge() cannot be negative"
        exit 198
    }
    if `lag' < 0 {
        noisily display as error "lag() cannot be negative"
        exit 198
    }
    if `washout' < 0 {
        noisily display as error "washout() cannot be negative"
        exit 198
    }
    if `fillgaps' < 0 {
        noisily display as error "fillgaps() cannot be negative"
        exit 198
    }
    if `carryforward' < 0 {
        noisily display as error "carryforward() cannot be negative"
        exit 198
    }
    local gap_carryforward = `carryforward'
    if "`pointtime'" != "" {
        * pointtime converts each observation to its effective persistence
        * interval once; the generic gap filler must not apply it again.
        local gap_carryforward = 0
    }
    
    * Determine primary exposure type for processing
    * This determines how the exposure variable will be transformed in later steps
    if "`evertreated'" != "" {
        local exp_type "evertreated"
    }
    else if "`currentformer'" != "" {
        local exp_type "currentformer"
    }
    else if "`duration'" != "" {
        local exp_type "duration"
        * Set default continuousunit for duration if not specified
        if "`continuousunit'" == "" {
            local continuousunit "years"
        }
        * Duration now uses continuousunit for calculation, then recodes to categories
        * Validate and normalize continuousunit
        local unit_lower = lower(trim("`continuousunit'"))
        if !inlist("`unit_lower'", "days", "weeks", "months", "quarters", "years") {
            noisily display as error "continuousunit(unit): unit must be days, weeks, months, quarters, or years"
            noisily display as error "You specified: `continuousunit'"
            exit 198
        }
    }
    else if "`continuousunit'" != "" {
        local exp_type "continuous"
        * Validate continuous unit (already confirmed non-empty by outer if)
        * Normalize to lowercase for comparison
        local unit_lower = lower(trim("`continuousunit'"))
        * Check if valid unit
        if !inlist("`unit_lower'", "days", "weeks", "months", "quarters", "years") {
            noisily display as error "continuousunit(unit): unit must be days, weeks, months, quarters, or years"
            noisily display as error "You specified: `continuousunit'"
            exit 198
        }
        * Store normalized unit for reporting
        local cont_unit "`unit_lower'"
        
        * Validate and parse expandunit option
        if "`expandunit'" != "" {
            * Normalize to lowercase for comparison
            local expand_lower = lower(trim("`expandunit'"))
            * Check if valid unit
            if !inlist("`expand_lower'", "days", "weeks", "months", "quarters", "years") {
                noisily display as error "expandunit(unit): unit must be days, weeks, months, quarters, or years"
                noisily display as error "You specified: `expandunit'"
                exit 198
            }
            * Store normalized unit for expansion
            local expand_unit "`expand_lower'"
        }
        else {
            * Default: expandunit matches continuousunit for backward compatibility
            local expand_unit "`cont_unit'"
        }
    }
    else if "`dose'" != "" {
        local exp_type "dose"
        * dose is a flag; dosecuts() provides optional cutpoints for categorization
        * If dosecuts is empty, output is continuous cumulative dose
        * If dosecuts has values, output is categorized like duration()
        local dose_cuts "`dosecuts'"
    }
    else if "`recency'" != "" {
        local exp_type "recency"
    }
    else {
        local exp_type "timevarying"
    }

    * Parse grace period specifications
    * Grace can be specified as:
    *   - Single number: grace(30) applies to all categories
    *   - Category-specific: grace(1=30 2=90) different grace by category
    * Grace period bridges small gaps between periods; gaps <= grace are merged
    local grace_default = 0
    local grace_bycategory = 0
    if "`grace'" != "" {
        * Check for category-specific format (contains "=")
        if strpos("`grace'", "=") > 0 {
            local grace_bycategory = 1
            * Parse each category=days pair
            local temp_grace = "`grace'"
            local i = 1
            foreach term in `temp_grace' {
                if strpos("`term'", "=") > 0 {
                    * Split by "=" to get category and days
                    local parts: subinstr local term "=" " ", all
                    gettoken cat days : parts
                    
                    * Validate category is numeric
                    capture confirm number `cat'
                    if _rc != 0 {
                        noisily display as error "grace() category must be numeric: `cat'"
                        exit 198
                    }
                    
                    * Validate days is numeric
                    capture confirm number `days'
                    if _rc != 0 {
                        noisily display as error "grace() days must be numeric: `days'"
                        exit 198
                    }
                    
                    * Validate days is non-negative
                    if `days' < 0 {
                        noisily display as error "grace() days cannot be negative: `days'"
                        exit 198
                    }
                    
                    local grace_cat`cat' = `days'
                }
                else {
                    noisily display as error "grace() with categories must use format: 1=30 2=90 ..."
                    exit 198
                }
            }
        }
        else {
            * Single grace period for all categories
            capture confirm number `grace'
            if _rc != 0 {
                noisily display as error "grace() value must be numeric: `grace'"
                exit 198
            }
            if `grace' < 0 {
                noisily display as error "grace() cannot be negative"
                exit 198
            }
            local grace_default = `grace'
        }
    }
    
    * Early validation: verify using dataset exists and contains required variables
    preserve
    quietly {
        capture use "`using'", clear
        if _rc {
            noisily display as error "Cannot open using dataset: `using'"
            restore
            exit 601
        }
        
        * Validate required variables exist in using dataset
        local missing_vars ""
        capture confirm variable `id', exact
        if _rc local missing_vars "`missing_vars' `id'"
        
        capture confirm variable `start', exact
        if _rc local missing_vars "`missing_vars' `start'"
        
        if "`pointtime'" == "" {
            capture confirm variable `stop', exact
            if _rc local missing_vars "`missing_vars' `stop'"
        }
        
        capture confirm variable `exposure', exact
        if _rc local missing_vars "`missing_vars' `exposure'"
        
        if "`missing_vars'" != "" {
            noisily display as error "Required variables not found in using dataset:`missing_vars'"
            restore
            exit 111
        }

        local _tvx_uidtype : type `id'
        if "`_tvx_uidtype'" == "strL" {
            noisily display as error "id() variable `id' is strL in the using dataset; strL variables cannot be used as merge keys"
            noisily display as error "recast it first, e.g. generate str20 `id'2 = `id'"
            restore
            exit 109
        }
    }
    restore
    
    * Capture original id variable type and format to restore at end
    quietly {
        local original_id_type : type `id'
        local original_id_format : format `id'
    }

    * strL ids cannot serve as merge keys; without this screen the internal
    * ID-mismatch merge fails mid-run with a cryptic "key variable id is strL"
    * r(106).
    if "`original_id_type'" == "strL" {
        noisily display as error "id() variable `id' is strL in the master data; strL variables cannot be used as merge keys"
        noisily display as error "recast it first, e.g. generate str20 `id'2 = `id'"
        exit 109
    }
    
    * Save original master dataset state
    * We save the master dataset to a tempfile so we can reload it later
    * The master dataset contains study entry/exit dates for each person
    tempfile _master_orig

    capture confirm numeric variable `entry'
    if _rc {
        noisily display as error "entry() variable `entry' must be numeric"
        exit 109
    }
    capture confirm numeric variable `exit'
    if _rc {
        noisily display as error "exit() variable `exit' must be numeric"
        exit 109
    }

    * STRICT check for datetime formats (%tc, %tC) - abort if detected
    * Stata datetimes are milliseconds (e.g., 1,600,000,000,000). Stata dates are days (e.g., 22,000).
    * If floor() is applied to a datetime, it keeps the millisecond value. When the code later
    * applies grace(30) (adding 30 to the value), it adds 30 milliseconds instead of 30 days.
    * This renders all lag, grace, and washout logic silent failures.
    local entry_fmt : format `entry'
    local exit_fmt : format `exit'
    if substr("`entry_fmt'", 1, 3) == "%tc" | substr("`entry_fmt'", 1, 3) == "%tC" {
        noisily display as error "CRITICAL ERROR: Entry variable `entry' is a datetime (%tc/%tC format)."
        noisily display as error "tvexpose requires daily dates (integer days). Using floor() on datetimes"
        noisily display as error "will result in values like 1.6 billion, breaking all lag/grace logic."
        noisily display as error "Please convert using: gen date_var = dofc(`entry')"
        exit 198
    }
    if substr("`exit_fmt'", 1, 3) == "%tc" | substr("`exit_fmt'", 1, 3) == "%tC" {
        noisily display as error "CRITICAL ERROR: Exit variable `exit' is a datetime (%tc/%tC format)."
        noisily display as error "tvexpose requires daily dates (integer days). Using floor() on datetimes"
        noisily display as error "will result in values like 1.6 billion, breaking all lag/grace logic."
        noisily display as error "Please convert using: gen date_var = dofc(`exit')"
        exit 198
    }

    tempvar _tvx_bad_mid _tvx_bad_mdate _tvx_bad_morder _tvx_bad_master
    quietly generate byte `_tvx_bad_mid' = missing(`id')
    quietly generate byte `_tvx_bad_mdate' = missing(`entry') | missing(`exit') | ///
        (!missing(`entry') & `entry' != floor(`entry')) | ///
        (!missing(`exit') & `exit' != floor(`exit'))
    quietly generate byte `_tvx_bad_morder' = !missing(`entry', `exit') & `entry' > `exit'
    quietly generate byte `_tvx_bad_master' = `_tvx_bad_mid' | `_tvx_bad_mdate' | `_tvx_bad_morder'

    quietly count if `_tvx_bad_mid'
    local n_invalid_master_id = r(N)
    quietly count if `_tvx_bad_mdate'
    local n_invalid_master_dates = r(N)
    quietly count if `_tvx_bad_morder'
    local n_invalid_master_order = r(N)
    quietly count if `_tvx_bad_master'
    local n_invalid_master = r(N)

    if `n_invalid_master' > 0 {
        if "`verbose'" != "" {
            noisily display as text "First invalid records:"
            preserve
            quietly keep if `_tvx_bad_master'
            noisily list `id' `entry' `exit' in 1/`=min(5, _N)', noobs
            restore
        }
        else {
            noisily display as text "  (specify verbose to list affected IDs and dates)"
        }
    }
    if `n_invalid_master' > 0 & "`dropinvalid'" == "" {
        noisily display as error "Malformed master input: `n_invalid_master' row(s)"
        noisily display as error "  missing ID: `n_invalid_master_id'; invalid daily dates: `n_invalid_master_dates'; entry after exit: `n_invalid_master_order'"
        noisily display as error "Correct the data or specify dropinvalid to remove those rows explicitly."
        exit 498
    }
    if `n_invalid_master' > 0 {
        quietly replace `touse' = 0 if `_tvx_bad_master'
        noisily display as text "dropinvalid: removed `n_invalid_master' malformed master row(s)"
    }
    drop `_tvx_bad_mid' `_tvx_bad_mdate' `_tvx_bad_morder' `_tvx_bad_master'
    quietly count if `touse'
    if r(N) == 0 {
        noisily display as error "No valid master observations remain"
        exit 2000
    }
    quietly save `_master_orig'
    
    **# DATA PREPARATION AND CLEANING
    
    quietly {
    * Extract and save entry/exit dates from master dataset
    * These define the study observation window for each person
    * Anyone entering the exposure dataset must have matching entry/exit dates
    tempfile master_dates
    
    * Build list of variables to keep, handling potential duplicates
    * Start with id, entry, exit
    local keep_list "`id' `entry' `exit'"
    
    * Add keepvars if specified, but avoid duplicates
    if "`keepvars'" != "" {
        foreach var of local keepvars {
            * Check if this var is not already in the list
            local already_there = 0
            if "`var'" == "`id'" | "`var'" == "`entry'" | "`var'" == "`exit'" {
                local already_there = 1
            }
            if `already_there' == 0 {
                local keep_list "`keep_list' `var'"
            }
        }
    }
    
    * Restrict to marked sample
    keep if `touse'
    
    * Keep the variables
    keep `keep_list'
    
    * Rename to standard internal names if needed
    if "`id'" != "id" {
        rename `id' id
    }
    if "`entry'" != "study_entry" {
        rename `entry' study_entry
    }
    if "`exit'" != "study_exit" {
        rename `exit' study_exit
    }
    
    * Now update keepvars macro to reflect renamed variables
    * This is needed so later code references the correct variable names
    if "`keepvars'" != "" {
        local keepvars_renamed ""
        foreach var of local keepvars {
            if "`var'" == "`id'" {
                * Skip - id is system variable, not in keepvars for later
            }
            else if "`var'" == "`entry'" {
                * Skip - study_entry is explicitly handled
            }
            else if "`var'" == "`exit'" {
                * Skip - study_exit is explicitly handled  
            }
            else {
                local keepvars_renamed "`keepvars_renamed' `var'"
            }
        }
        local keepvars "`keepvars_renamed'"
    }
    
    * Ensure entry dates are not after exit dates
    * This catches data quality issues where study dates are reversed
    count if study_exit < study_entry
    if r(N) > 0 {
        local n_invalid = r(N)
        noisily display as error "Error: found `n_invalid' persons with study_exit < study_entry"
        noisily display as error "Please verify entry(varname) and exit(varname) are correct"
        noisily display as error "First few cases:"
        noisily list id study_entry study_exit if study_exit < study_entry in 1/`=min(5, _N)', noobs
        exit 498
    }
    
    * Capture variable and value labels for keepvars and study dates
    * These will be restored after final merge to preserve user's labels
    local study_entry_varlab : variable label study_entry
    local study_exit_varlab : variable label study_exit
    local study_entry_vallab : value label study_entry
    local study_exit_vallab : value label study_exit
    
    * Namespace the label-restore scripts (F10e): a tempfile-derived stub keeps
    * two parallel tvexpose runs sharing a TMPDIR from cross-writing each other's
    * label_*.do files. The same stub local is reused at the restore sites below.
    tempfile _lbl_stub

    * Save value label definitions for study dates if they exist
    if "`study_entry_vallab'" != "" {
        quietly label save `study_entry_vallab' using "`_lbl_stub'_study_entry.do", replace
    }
    if "`study_exit_vallab'" != "" {
        quietly label save `study_exit_vallab' using "`_lbl_stub'_study_exit.do", replace
    }

    if "`keepvars'" != "" {
        foreach var of local keepvars {
            * Capture variable label
            local varlab_`var' : variable label `var'

            * Check if variable has value labels and capture them
            local vallab_`var' : value label `var'
            if "`vallab_`var''" != "" {
                * Save the value label definition
                quietly label save `vallab_`var'' using "`_lbl_stub'_label_`var'.do", replace
            }
        }
    }
    
    quietly save `master_dates', replace
    }
    
    * Load and validate exposure dataset
    * The exposure dataset contains the time periods each person was exposed
    * Must be merged with master dataset to align observation windows
    quietly use `_master_orig', clear
    tempfile _master_with_dates
    quietly save `_master_with_dates'
    quietly use "`using'", clear

    * Preserve the exposure file's input order before any validation, merge, or
    * chronological sort. overlap(layer) uses this stable source order to break
    * equal-start ties: the later source record takes precedence.
    tempvar _tvx_source_order
    quietly generate long `_tvx_source_order' = _n

    capture confirm numeric variable `start'
    if _rc {
        noisily display as error "start() variable `start' must be numeric"
        exit 109
    }
    if "`stop'" != "" {
        capture confirm numeric variable `stop'
        if _rc {
            noisily display as error "stop() variable `stop' must be numeric"
            exit 109
        }
    }

    * STRICT check for datetime formats on start/stop variables - abort if detected
    local start_fmt : format `start'
    if substr("`start_fmt'", 1, 3) == "%tc" | substr("`start_fmt'", 1, 3) == "%tC" {
        noisily display as error "CRITICAL ERROR: Start variable `start' is a datetime (%tc/%tC format)."
        noisily display as error "tvexpose requires daily dates (integer days). Using floor() on datetimes"
        noisily display as error "will result in values like 1.6 billion, breaking all lag/grace logic."
        noisily display as error "Please convert using: gen date_var = dofc(`start')"
        exit 198
    }
    if "`stop'" != "" {
        local stop_fmt : format `stop'
        if substr("`stop_fmt'", 1, 3) == "%tc" | substr("`stop_fmt'", 1, 3) == "%tC" {
            noisily display as error "CRITICAL ERROR: Stop variable `stop' is a datetime (%tc/%tC format)."
            noisily display as error "tvexpose requires daily dates (integer days). Using floor() on datetimes"
            noisily display as error "will result in values like 1.6 billion, breaking all lag/grace logic."
            noisily display as error "Please convert using: gen date_var = dofc(`stop')"
            exit 198
        }
    }

    quietly count
    if r(N) == 0 {
        noisily display as error "Dataset must contain observations"
        exit 198
    }

    * Verify exposure variable is numeric
    * Required because exposure categories are used in numeric comparisons throughout
    * If non-numeric, user should use encode or recode to create numeric categories
    quietly capture confirm numeric variable `exposure'
    if _rc != 0 {
        noisily display as error "Error: exposure variable `exposure' must be numeric"
        noisily display as error "Check variable name spelling to confirm it exists."
        noisily display as error "If it exists, use encode or recode to create numeric exposure categories."
        exit 109
    }

    * Required source fields are strict by default. dropinvalid is the only
    * opt-in path that removes malformed records.
    tempvar _tvx_bad_eid _tvx_bad_edate _tvx_bad_eorder _tvx_bad_eval _tvx_bad_exposure
    quietly generate byte `_tvx_bad_eid' = missing(`id')
    if "`stop'" != "" {
        quietly generate byte `_tvx_bad_edate' = missing(`start') | missing(`stop') | ///
            (!missing(`start') & `start' != floor(`start')) | ///
            (!missing(`stop') & `stop' != floor(`stop'))
        quietly generate byte `_tvx_bad_eorder' = !missing(`start', `stop') & `start' > `stop'
    }
    else {
        quietly generate byte `_tvx_bad_edate' = missing(`start') | ///
            (!missing(`start') & `start' != floor(`start'))
        quietly generate byte `_tvx_bad_eorder' = 0
    }
    quietly generate byte `_tvx_bad_eval' = missing(`exposure')
    quietly generate byte `_tvx_bad_exposure' = `_tvx_bad_eid' | `_tvx_bad_edate' | ///
        `_tvx_bad_eorder' | `_tvx_bad_eval'

    quietly count if `_tvx_bad_eid'
    local n_invalid_exposure_id = r(N)
    quietly count if `_tvx_bad_edate'
    local n_invalid_exposure_dates = r(N)
    quietly count if `_tvx_bad_eorder'
    local n_invalid_exposure_order = r(N)
    quietly count if `_tvx_bad_eval'
    local n_invalid_exposure_value = r(N)
    quietly count if `_tvx_bad_exposure'
    local n_invalid_exposure = r(N)

    if `n_invalid_exposure' > 0 {
        if "`verbose'" != "" {
            local _tvx_invalid_vars "`id' `start'"
            if "`stop'" != "" {
                local _tvx_invalid_vars "`_tvx_invalid_vars' `stop'"
            }
            local _tvx_invalid_vars "`_tvx_invalid_vars' `exposure'"
            noisily display as text "First invalid records:"
            preserve
            quietly keep if `_tvx_bad_exposure'
            noisily list `_tvx_invalid_vars' in 1/`=min(5, _N)', noobs
            restore
        }
        else {
            noisily display as text "  (specify verbose to list affected IDs and dates)"
        }
    }
    if `n_invalid_exposure' > 0 & "`dropinvalid'" == "" {
        noisily display as error "Malformed exposure input: `n_invalid_exposure' row(s)"
        noisily display as error "  missing ID: `n_invalid_exposure_id'; invalid daily dates: `n_invalid_exposure_dates'; reversed bounds: `n_invalid_exposure_order'; missing exposure: `n_invalid_exposure_value'"
        noisily display as error "Correct the data or specify dropinvalid to remove those rows explicitly."
        exit 498
    }
    if `n_invalid_exposure' > 0 {
        quietly drop if `_tvx_bad_exposure'
        noisily display as text "dropinvalid: removed `n_invalid_exposure' malformed exposure row(s)"
    }
    capture drop `_tvx_bad_eid' `_tvx_bad_edate' `_tvx_bad_eorder' ///
        `_tvx_bad_eval' `_tvx_bad_exposure'
    
    * Store original exposure variable label for later use
    if "`label'" != "" {
        local exp_label "`label'"
    }
    else {
        local exp_label : variable label `exposure'
        if "`exp_label'" == "" {
            local exp_label "Exposure variable"
        }
    }
    
    * Standardize exposure dataset variable names
    * Internal naming allows flexible variable names in user's data
    * stop() now optional; if missing with pointtime, exp_stop set to exp_start
    rename (`id' `start' `exposure') ///
           (id exp_start exp_value)
    
    * Capture the value label name attached to exp_value for later use in bytype
    local exp_value_label : value label exp_value
    if "`exp_value_label'" == "" {
        * If no value label attached, we'll use the numeric values
        local exp_value_label ""
    }
    
    * Handle stop variable: rename if provided, create from start if pointtime
    if "`stop'" != "" {
        rename `stop' exp_stop
    }
    else {
        * If no stop variable provided (pointtime option), create exp_stop = exp_start
        capture drop exp_stop
        quietly generate double exp_stop = exp_start
    }
    
    * Handle point-in-time data format
    * Point-in-time means exposure is measured at a single date (e.g., survey date)
    * User specifies how long to assume the exposure status persists (carryforward)
    if "`pointtime'" != "" {
        * For point-in-time assessments, stop = start initially (already set above)
        
        * Apply carryforward if specified
        * This extends each exposure period forward in time by carryforward days
        * Overlapping periods will be merged in the merge step later
        if `carryforward' > 0 {
            sort id exp_start
            quietly by id: replace exp_stop = exp_start + `carryforward' - 1
        }
    }
    
    * Apply fillgaps option
    * Extends last exposure period forward by fillgaps days
    * Useful for studies where last exposure recorded but time to event longer
    if `fillgaps' > 0 {
        sort id exp_start
        quietly by id: gen double is_last = (_n == _N)
        quietly replace exp_stop = exp_stop + `fillgaps' if is_last == 1
        drop is_last
    }
    
    * Merge exposure data with study entry/exit dates
    * This adds the observation window to each exposure record
    * Keep only matched records (exposure records with matching entry/exit)
    preserve
    quietly use `master_dates', clear
    isid id
    restore

    * Count exposure records before merge to track any dropped
    quietly count
    local n_exp_before = r(N)

    quietly merge m:1 id using `master_dates', generate(_merge_check)

    * Count and warn about exposure records with IDs not in master
    quietly count if _merge_check == 1
    local n_exp_only = r(N)
    local n_unmatched_exposure = `n_exp_only'
    if `n_exp_only' > 0 {
        quietly count if _merge_check == 1
        local n_ids_dropped = r(N)
        quietly egen long _tag_dropped = tag(id) if _merge_check == 1
        quietly count if _tag_dropped == 1
        local n_unique_ids_dropped = r(N)
        capture drop _tag_dropped
        noisily display as text "Note: `n_ids_dropped' exposure records excluded (`n_unique_ids_dropped' IDs not in master dataset)"
    }

    * Keep only matched records
    quietly keep if _merge_check == 3
    drop _merge_check
    
    * Remove exposures completely outside study observation window
    * If exposure ended before entry or started after exit, person never truly exposed
    quietly count if exp_stop < study_entry | exp_start > study_exit
    local n_outside_window = r(N)
    quietly drop if exp_stop < study_entry | exp_start > study_exit
    
    * Apply lag period (delay before exposure becomes active)
    * Lag represents latency period before biological effect begins
    * For example: lag(30) means 30-day delay before chemotherapy starts damaging cells
    if `lag' > 0 {
        quietly replace exp_start = exp_start + `lag'
        * Remove periods that became invalid due to lag
        quietly count if exp_start > exp_stop | exp_start > study_exit
        local n_lag_removed = r(N)
        quietly drop if exp_start > exp_stop
        quietly drop if exp_start > study_exit
    }
    
    * Apply washout period (persistence after exposure stops)
    * Washout represents residual effect after exposure ends
    * For example: washout(90) means protective immunity lasts 90 days after vaccination
    if `washout' > 0 {
        quietly replace exp_stop = exp_stop + `washout'
        * Ensure washout doesn't extend beyond study exit
        quietly replace exp_stop = study_exit if exp_stop > study_exit
    }
    
    * Apply window restriction for acute exposures
    * Restricts effect to specific time window around exposure
    * For example: window(1 7) measures days 1-7 after exposure (week-long window)
    if "`window'" != "" {
        quietly replace exp_stop = min(exp_start + `window_max', exp_stop)
        quietly replace exp_start = exp_start + `window_min'
        quietly drop if exp_start > exp_stop
    }
    
    * Truncate all periods to study observation window
    * All exposure periods must fall within [entry, exit] for that person
    * This is final truncation after all transformations
    quietly replace exp_start = study_entry if exp_start < study_entry
    quietly replace exp_stop = study_exit if exp_stop > study_exit
    
    * Retain only essential variables for processing
    * Drop all other variables to reduce memory usage
    * Keep only: id, dates, exposure value, stable source order, and
    * user-specified keepvars.
    if "`keepvars'" != "" {
        keep id exp_start exp_stop exp_value study_entry study_exit ///
            `_tvx_source_order' `keepvars'
    }
    else {
        keep id exp_start exp_stop exp_value study_entry study_exit ///
            `_tvx_source_order'
    }
    
    * Sort for sequential processing
    * Sorting is critical before by-group operations
    sort id exp_start exp_stop exp_value
    
    * Save cleaned exposure data for processing
    tempfile exp_cleaned
    quietly save `exp_cleaned', replace

    * Check if any exposures remain after filtering
    * If all exposures were outside study window, skip exposure processing
    * but still create baseline periods (all time is reference/unexposed)
    quietly count
    local exp_cleaned_n = r(N)

    **# EXPOSURE PERIOD PROCESSING

    * Skip exposure processing if no valid exposures remain
    if `exp_cleaned_n' > 0 {

    **# Step 1: Merge close periods of same exposure type
    * Rationale: Small gaps between same exposure type likely represent same episode
    * merge(120) means: if gap <= 120 days, treat as one continuous exposure
    * NOTE: Skip for dose type - overlapping prescriptions with the same dose amount
    *       must NOT be merged here; dose overlap handling (below) runs after this
    *       block and uses daily rates computed per original prescription. Merging
    *       first corrupts those rates and produces wrong cumulative doses.
    if "`exp_type'" != "dose" {
    quietly use `exp_cleaned', clear
    
    sort id exp_start exp_stop exp_value
    quietly gen double drop_flag = 0
    
    * ===========================================================================
    * ITERATIVE PERIOD MERGING ALGORITHM
    * ===========================================================================
    * Purpose: Merge exposure periods of the same type that are close in time
    *
    * Algorithm overview:
    *   1. Find consecutive periods with same exposure value within `merge' days
    *   2. Extend earlier period's stop date to cover later period
    *   3. Mark subsumed periods for deletion
    *   4. Repeat until no more mergeable periods exist
    *
    * Why iteration is needed:
    *   - Single pass may miss chains: A→B→C where A+B merge, then AB+C should merge
    *   - Example: periods [1-10], [12-20], [22-30] with merge(5)
    *     Pass 1: [1-10] merges with [12-20] → [1-20]
    *     Pass 2: [1-20] merges with [22-30] → [1-30]
    *
    * Performance considerations:
    *   - High limit (10000) handles fragmented administrative data (e.g., daily rx claims)
    *   - Most datasets converge in <10 iterations
    *   - Progress indicator shown every 100 iterations for long-running cases
    * ===========================================================================
    local changes = 1
    local iter = 0
    local max_merge_iter = 10000
    local progress_interval = 100

    while `changes' > 0 & `iter' < `max_merge_iter' {
        local changes = 0
        quietly replace drop_flag = 0

        * Progress indicator for long-running merges
        if `iter' > 0 & mod(`iter', `progress_interval') == 0 {
            noisily display as text "  Merge iteration `iter' of `max_merge_iter' (processing...)"
        }

        * Identify periods that can be merged (same type, close timing)
        * Merge condition: same ID, same exposure value, gap <= merge() days
        * The gap is calculated as: start[n+1] - stop[n], which is negative for overlaps
        quietly gen double can_merge = 0
        quietly by id (exp_start exp_stop): replace can_merge = 1 if ///
            (exp_start[_n+1] - exp_stop <= `merge') & ///
            !missing(exp_start[_n+1]) & ///
            (exp_value == exp_value[_n+1]) & ///
            (_n < _N) & id == id[_n+1]

        * Extend current period's stop date to encompass the next period
        * Uses max() to handle overlapping periods correctly
        quietly by id: replace exp_stop = max(exp_stop, exp_stop[_n+1]) if can_merge == 1 & _n < _N & id == id[_n+1]

        * Mark next period for deletion ONLY if it's completely subsumed
        * Subsumed = starts at or after previous start AND stops at or before previous stop
        * Critical: periods extending beyond the merged stop must be kept for next iteration
        quietly by id: replace drop_flag = 1 if _n > 1 & id == id[_n-1] & can_merge[_n-1] == 1 & exp_start >= exp_start[_n-1] & exp_stop <= exp_stop[_n-1]

        * Count changes to determine if another iteration needed
        quietly count if drop_flag == 1
        local changes = r(N)

        * Remove merged (subsumed) periods
        if `changes' > 0 {
            quietly drop if drop_flag == 1
        }

        quietly drop can_merge
        sort id exp_start exp_stop exp_value
        local iter = `iter' + 1
    }

    * Report completion status.
    *
    * Reaching the cap is not by itself a failure: the loop may have converged
    * on the final iteration. What must never happen is returning a plausible
    * partial dataset. So on cap exhaustion the postcondition is checked
    * explicitly -- no remaining same-value pair within merge() days -- and a
    * genuine violation is a transactional error, not a warning the caller can
    * miss. The caller's data is restored by the snapshot taken at entry.
    if `iter' >= `max_merge_iter' {
        quietly gen double __merge_left = 0
        quietly by id (exp_start exp_stop): replace __merge_left = 1 if ///
            (exp_start[_n+1] - exp_stop <= `merge') & ///
            !missing(exp_start[_n+1]) & ///
            (exp_value == exp_value[_n+1]) & ///
            (_n < _N) & id == id[_n+1]
        quietly count if __merge_left == 1
        local n_merge_left = r(N)
        quietly drop __merge_left
        if `n_merge_left' > 0 {
            noisily display as error "Merge did not converge: `n_merge_left' mergeable period pair(s) remain after `max_merge_iter' iterations"
            noisily display as error "The requested merge postcondition is not satisfied, so no output was committed."
            noisily display as error "Simplify the exposure data or reduce merge()/grace() and rerun."
            exit 498
        }
        noisily display as text "  Merge reached the iteration limit but the postcondition holds"
    }
    else if `iter' > `progress_interval' {
        noisily display as text "  Merge completed after `iter' iterations"
    }
    
    quietly drop drop_flag
    
    * Remove exact duplicate periods
    * Same ID, start, stop, and exposure value = redundant record
    sort id exp_start exp_stop exp_value
    quietly gen double is_dup = 0
    quietly by id: replace is_dup = 1 if (exp_start == exp_start[_n-1]) & ///
                              (exp_stop == exp_stop[_n-1]) & ///
                              (exp_value == exp_value[_n-1]) & _n > 1 & id == id[_n-1]
    quietly drop if is_dup == 1
    quietly drop is_dup
    
    * ===========================================================================
    * ITERATIVE CONTAINED PERIOD REMOVAL
    * ===========================================================================
    * Purpose: Remove redundant periods that are fully contained within another
    *          period of the same exposure type
    *
    * Definition of "contained":
    *   Period B is contained in Period A if:
    *   - Same person (id)
    *   - Same exposure value
    *   - B.start >= A.start AND B.stop <= A.stop
    *
    * Why iteration is needed:
    *   - Removing period B might reveal that period C is now contained in A
    *   - Example: A=[1-30], B=[5-25], C=[10-20] (all same exposure)
    *     Pass 1: C contained in B → remove C
    *     Pass 2: B contained in A → remove B
    *     (Without iteration, B might shadow C's containment in A)
    *
    * Performance: Progress indicator shown every 100 iterations
    * ===========================================================================
    quietly gen double contained = 0
    local iter = 0
    local done = 0
    local max_contain_iter = 10000
    local progress_interval = 100

    while `done' == 0 & `iter' < `max_contain_iter' {
        * Progress indicator for long-running containment checks
        if `iter' > 0 & mod(`iter', `progress_interval') == 0 {
            noisily display as text "  Containment check iteration `iter' of `max_contain_iter' (processing...)"
        }

        quietly count if contained == 1
        if r(N) > 0 {
            quietly drop if contained == 1
            sort id exp_start exp_stop exp_value
        }
        local iter = `iter' + 1

        * Mark periods that are fully within a previous period of same type
        * Check: current period's boundaries fall entirely within previous period
        quietly replace contained = 0
        quietly by id: replace contained = 1 if exp_stop <= exp_stop[_n-1] & ///
                                        exp_start >= exp_start[_n-1] & ///
                                        exp_value == exp_value[_n-1] & _n > 1 & id == id[_n-1]
        quietly count if contained == 1
        if r(N) == 0 local done = 1
    }

    * As with the merge loop, hitting the cap is only a failure if the
    * postcondition is actually violated. `contained' already holds the
    * current pass's marks, so it is the postcondition: any row still marked
    * means a contained period survived, and a partial result must not be
    * returned as if it were complete.
    if `iter' >= `max_contain_iter' {
        quietly count if contained == 1
        local n_contained_left = r(N)
        if `n_contained_left' > 0 {
            noisily display as error "Containment resolution did not converge: `n_contained_left' contained period(s) remain after `max_contain_iter' iterations"
            noisily display as error "The requested containment postcondition is not satisfied, so no output was committed."
            exit 498
        }
        noisily display as text "  Containment check reached the iteration limit but the postcondition holds"
    }
    else if `iter' > `progress_interval' {
        noisily display as text "  Containment check completed after `iter' iterations"
    }

    quietly drop contained

    } // end non-dose merge/containment block
    else {
        * For dose type, skip merge/containment and load cleaned exposures directly.
        * Dose overlap handling below will process prescriptions on original boundaries.
        quietly use `exp_cleaned', clear
    }

    **# Special overlap handling for dose option
    * For dose, overlapping periods require proportional dose allocation
    * Algorithm:
    *   1. Calculate daily_rate = exp_value / period_length for each period
    *   2. Split at all overlap boundaries
    *   3. For each segment: segment_dose = segment_days × Σ(active daily_rates)
    * This ensures correct dose accounting when prescriptions overlap
    if "`exp_type'" == "dose" {
        noisily display as text "Processing dose with proportional overlap handling..."

        * Step 1: Calculate daily dose rate for each period
        quietly gen double __period_length = exp_stop - exp_start + 1
        quietly gen double __daily_rate = exp_value / __period_length

        * Save original period info with unique ID
        quietly gen double __orig_period_id = _n
        quietly gen double __orig_start = exp_start
        quietly gen double __orig_stop = exp_stop
        quietly gen double __orig_daily_rate = __daily_rate
        quietly gen double __orig_dose = exp_value

        tempfile dose_periods
        quietly save `dose_periods', replace

        * Check if there are any overlaps that need handling
        sort id exp_start exp_stop
        quietly by id: gen double __has_overlap = (exp_start <= exp_stop[_n-1]) if _n > 1 & id == id[_n-1]
        quietly count if __has_overlap == 1
        local n_dose_overlaps = r(N)
        drop __has_overlap

        if `n_dose_overlaps' > 0 {
            noisily display as text "  Found `n_dose_overlaps' overlapping dose periods to resolve..."
            tempvar seg_days seg_id contrib

            * Step 2: Create all boundary points
            preserve
            keep id exp_start exp_stop

            * Collect start dates as boundaries
            quietly gen double boundary = exp_start
            keep id boundary
            tempfile boundaries_start
            quietly save `boundaries_start', replace
            restore

            preserve
            keep id exp_start exp_stop
            * Collect stop+1 dates as boundaries
            quietly gen double boundary = exp_stop + 1
            keep id boundary
            quietly append using `boundaries_start'
            quietly duplicates drop id boundary, force
            sort id boundary

            tempfile all_boundaries
            quietly save `all_boundaries', replace
            restore

            * Step 3: For each person, create segments between consecutive boundaries
            preserve
            quietly use `all_boundaries', clear
            sort id boundary
            quietly by id: gen double seg_start = boundary
            quietly by id: gen double seg_stop = boundary[_n+1] - 1 if _n < _N
            quietly drop if missing(seg_stop)
            keep id seg_start seg_stop

            * For each segment, find which original periods overlap and sum their daily rates
            quietly gen double `seg_days' = seg_stop - seg_start + 1

            tempfile segments
            quietly save `segments', replace
            restore

            * Step 4: Calculate dose contribution for each segment from each overlapping period
            * Use cross-join approach: for each segment, check all periods for that person
            quietly use `segments', clear
            quietly gen double `seg_id' = _n

            tempfile segments_with_id
            quietly save `segments_with_id', replace

            * Join segments with original periods
            quietly use `dose_periods', clear
            keep id __orig_period_id __orig_start __orig_stop __orig_daily_rate study_entry study_exit
            if "`keepvars'" != "" {
                quietly merge m:1 id using `master_dates', keepusing(`keepvars') nogen keep(1 3)
            }

            tempfile periods_for_join
            quietly save `periods_for_join', replace

            quietly use `segments_with_id', clear
            joinby id using `periods_for_join'

            * Keep only where segment overlaps with original period
            quietly keep if seg_start <= __orig_stop & seg_stop >= __orig_start

            * Calculate this period's contribution to this segment
            * Contribution = segment_days × daily_rate
            quietly gen double `contrib' = `seg_days' * __orig_daily_rate

            * Sum contributions by segment
            collapse (sum) exp_value=`contrib' (first) seg_start seg_stop study_entry study_exit, by(id `seg_id')

            rename (seg_start seg_stop) (exp_start exp_stop)
            drop `seg_id'

            * Add back keepvars if needed
            if "`keepvars'" != "" {
                quietly merge m:1 id using `master_dates', keepusing(`keepvars') nogen keep(1 3)
            }

            sort id exp_start exp_stop

            noisily display as text "  Dose overlap resolution complete."
        }
        else {
            * No overlaps - just clean up temp variables
            noisily display as text "  No overlapping dose periods found."
            drop __period_length __daily_rate __orig_period_id __orig_start __orig_stop __orig_daily_rate __orig_dose
        }

        * Clean up any remaining temp variables
        capture drop __period_length __daily_rate __orig_period_id __orig_start __orig_stop __orig_daily_rate __orig_dose

        * Save the dose-processed data
        quietly save `exp_cleaned', replace
    }

    **# Step 2: Handle overlapping exposures
    * Different exposure types may overlap; need to decide how to handle
    * Four strategies available:
    *   1. split: Create separate periods at all boundary points (every combination)
    *   2. combine: Encode overlaps as combined exposure value (val1*100 + val2)
    *   3. priority: Assign precedence order, truncate lower priority periods
    * Default (none specified): Later exposures take precedence (simple truncation)

    * Skip standard overlap handling for dose (already handled above)
    * Split logic runs for both split and combine options
    * For combine, splitting ensures proper interval boundaries before merging overlapping values
    if "`exp_type'" != "dose" & ("`split'" != "" | "`combine'" != "") {
        * SPLIT OVERLAPPING: Creates separate periods for each boundary
        * Useful when analyzing how different exposures interact
        * Result: Every exposure combination gets its own time period
        tempfile split_data
        quietly save `split_data', replace
        
        * Create dataset of all unique boundary points
        * Save current state to tempfile instead of nested preserve
        tempfile _split_temp
        quietly save `_split_temp', replace
        
        keep id exp_start exp_stop
        
        * Collect all start dates
        quietly generate double boundary = exp_start
        keep id boundary
        tempfile boundaries_start
        quietly save `boundaries_start', replace
        
        * Reload and collect stop dates
        quietly use `_split_temp', clear
        keep id exp_start exp_stop
        quietly generate double boundary = exp_stop + 1
        keep id boundary
        
        * Combine and deduplicate boundaries
        quietly append using `boundaries_start'
        quietly duplicates drop id boundary, force
        sort id boundary
        
        tempfile all_boundaries
        quietly save `all_boundaries', replace
        
        * Restore original data
        quietly use `_split_temp', clear
        
        * For each original period, split at internal boundaries
        quietly use `split_data', clear
        quietly gen double __period_id = _n

        tempfile original_periods
        quietly save `original_periods', replace

        * Merge boundaries for same person
        joinby id using `all_boundaries'

        * Keep boundaries that open a new segment inside this period.
        * Under the closed [start, stop] contract a cut at b yields
        * [start, b-1] and [b, stop], so b is admissible when
        * start < b <= stop. The old `b < stop` rule silently dropped the
        * case b == stop, which is exactly a shared inclusive boundary
        * (one episode ending on the day the next begins): the first
        * episode was left unsplit and the two sources stayed misaligned,
        * so combine() saw an unresolved overlap and coverage
        * double-counted the shared day.
        quietly keep if boundary > exp_start & boundary <= exp_stop

        * If no splits needed, restore original
        quietly count
        if r(N) == 0 {
            quietly use `original_periods', clear
            drop __period_id
        }
        else {
            * Add end-of-period marker (stop+1) for each period that has splits
            * This ensures we get N+1 segments from N internal boundaries
            preserve
            if "`keepvars'" != "" {
                keep __period_id id exp_start exp_stop exp_value `keepvars'
            }
            else {
                keep __period_id id exp_start exp_stop exp_value
            }
            quietly bysort __period_id: keep if _n == 1
            quietly gen double boundary = exp_stop + 1
            tempfile end_bounds
            quietly save `end_bounds', replace
            restore
            quietly append using `end_bounds'

            * Create segments from consecutive boundary pairs
            sort id __period_id boundary
            quietly by id __period_id: gen double new_start = cond(_n == 1, exp_start, boundary[_n-1])
            quietly gen double new_stop = boundary - 1

            * Keep valid splits and essential vars
            quietly keep if new_start <= new_stop
            if "`keepvars'" != "" {
                keep id new_start new_stop exp_value `keepvars' __period_id
            }
            else {
                keep id new_start new_stop exp_value __period_id
            }
            rename (new_start new_stop) (exp_start exp_stop)

            * Mark split periods
            quietly gen double __is_split = 1

            * Add back periods that had no internal boundaries
            quietly append using `original_periods'

            * Mark which period IDs were split
            quietly bysort __period_id: gen double __split_count = _N

            * Drop original unsplit versions of periods that were split
            quietly drop if __split_count > 1 & exp_start < . & exp_stop < . & ///
                    missing(__is_split)

            drop __period_id __split_count __is_split
            quietly duplicates drop id exp_start exp_stop exp_value, force
        }
        sort id exp_start exp_stop exp_value
    }

    **# Save all exposure types per person BEFORE overlap resolution
    * CRITICAL FIX: For bytype option, we need to know ALL exposure types each person
    * was ever exposed to, even if those exposure periods get eliminated during overlap
    * resolution. Save this information now before overlaps are resolved.
    if "`bytype'" != "" {
        **# bytype output-name preflight
        * Derived names are {stub}{suffix} and {stub}labels_{suffix}, where
        * suffix comes from the formatted exposure value. The early stub check
        * assumed a one-character suffix, so a perfectly valid category such as
        * 123456789 combined with a documented 24-character stub only failed
        * deep inside variable creation with a bare "invalid varname" (r(198)).
        * Every derived name is now built from the actual values and validated
        * for legality, length, and uniqueness BEFORE anything is created.
        preserve
        quietly keep if exp_value != `reference'
        quietly levelsof exp_value, local(_bt_vals)
        restore

        local _bt_names ""
        local _bt_map ""
        local _bt_n = 0
        foreach _bt_v of local _bt_vals {
            local _bt_sfx = subinstr("`_bt_v'", "-", "neg", .)
            local _bt_sfx = subinstr("`_bt_sfx'", ".", "p", .)
            local _bt_var "`stub_name'`_bt_sfx'"
            local _bt_lbl "`stub_name'labels_`_bt_sfx'"

            capture confirm name `_bt_var'
            if _rc {
                noisily display as error "bytype: exposure value `_bt_v' yields the illegal variable name '`_bt_var''"
                noisily display as error "Recode that exposure value, or supply a different generate() stub."
                noisily display as error "No output was committed."
                exit 198
            }
            if strlen("`_bt_var'") > 32 | strlen("`_bt_lbl'") > 32 {
                noisily display as error "bytype: exposure value `_bt_v' yields a name longer than 32 characters"
                noisily display as error "  variable: `_bt_var' (`=strlen("`_bt_var'")' chars); value label: `_bt_lbl' (`=strlen("`_bt_lbl'")' chars)"
                noisily display as error "Shorten the generate() stub to at most `=32 - strlen("labels_`_bt_sfx'")' characters, or recode the exposure value."
                noisily display as error "No output was committed."
                exit 198
            }
            local _bt_dup : list _bt_var in _bt_names
            if `_bt_dup' {
                noisily display as error "bytype: exposure value `_bt_v' collides on the derived name '`_bt_var''"
                noisily display as error "Two exposure values sanitize to the same variable name. Recode them."
                noisily display as error "No output was committed."
                exit 198
            }
            local _bt_names "`_bt_names' `_bt_var'"
            local ++_bt_n
            local _bt_map `"`_bt_map' `_bt_v'=`_bt_var'"'
        }
        local _bt_names = strtrim("`_bt_names'")
        local _bt_map = strtrim(`"`_bt_map'"')

        preserve
        keep id exp_value
        quietly keep if exp_value != `reference'
        quietly bysort id exp_value: keep if _n == 1
        keep id exp_value
        rename exp_value __all_exp_types
        tempfile all_person_exp_types
        quietly save `all_person_exp_types', replace
        restore

        * Save first exposure start date per person per type before overlap resolution
        * This ensures evertreated bytype can find the correct first exposure date
        * even if overlap resolution eliminates some exposure periods entirely
        preserve
        keep id exp_start exp_value
        quietly keep if exp_value != `reference'
        collapse (min) __pre_first_start = exp_start, by(id exp_value)
        tempfile first_exp_by_type
        quietly save `first_exp_by_type', replace
        restore
    }
    
    if "`exp_type'" != "dose" & "`combine'" != "" {
        * COMBINE OVERLAPPING: after the split block above, each sub-period in
        * an overlap region carries one row per simultaneously active exposure.
        * Collapse every sub-period to one row and give each distinct
        * simultaneous state its own code.
        *
        * The previous scheme encoded a pair arithmetically as val1*100 + val2.
        * That map is not injective over the value domain the command accepts:
        * the pair (-1, 2) encoded to -98, which is also a legal single
        * exposure code, and any pair (0, v) encoded to v itself. Both cases
        * returned rc=0 with two analytically distinct states sharing one
        * value. Codes are now allocated from a block that starts strictly
        * above every observed original value, so an original code and a
        * combination code can never coincide, and the composition of each
        * allocated code is recorded in a value label and in r(combine_map).

        sort id exp_start exp_stop exp_value

        * The same exposure recorded twice across one sub-period is a single
        * state, not a two-way overlap.
        quietly by id exp_start exp_stop exp_value: keep if _n == 1
        quietly by id exp_start exp_stop: gen double __n_vals = _N

        * Canonical, order-independent composition key per sub-period. The
        * by-group is sorted on exp_value, so the key does not depend on the
        * order the source episodes happened to arrive in.
        quietly gen str244 __combo_key = ""
        quietly by id exp_start exp_stop (exp_value): replace __combo_key = ///
            cond(_n == 1, strofreal(exp_value, "%18.0g"), ///
                 __combo_key[_n-1] + " + " + strofreal(exp_value, "%18.0g"))
        quietly by id exp_start exp_stop (exp_value): replace __combo_key = __combo_key[_N]

        * A truncated key would make two different states share a code, which
        * is the exact defect this allocator exists to prevent.
        quietly count if strlen(__combo_key) >= 244
        if r(N) > 0 {
            noisily display as error "combine(): a sub-period has too many simultaneous exposures to encode"
            noisily display as error "Reduce the number of overlapping exposure types, or use split instead."
            drop __n_vals __combo_key
            exit 198
        }

        * Allocate combination codes strictly above every original value.
        quietly summarize exp_value, meanonly
        local _combo_base = floor(r(max)) + 1

        quietly generate double `combine' = exp_value if __n_vals == 1
        tempvar _combo_grp
        quietly egen double `_combo_grp' = group(__combo_key) if __n_vals > 1
        quietly replace `combine' = `_combo_base' + `_combo_grp' - 1 if __n_vals > 1

        * Record the allocated code -> composition map for labels and returns.
        local _combo_n = 0
        local _combo_map ""
        preserve
        quietly keep if __n_vals > 1
        if _N > 0 {
            quietly bysort `combine' (__combo_key): keep if _n == 1
            sort `combine'
            forvalues _ci = 1/`=_N' {
                local ++_combo_n
                local _combo_code`_combo_n' = `combine'[`_ci']
                local _combo_text`_combo_n' = __combo_key[`_ci']
                local _combo_map `"`_combo_map' `_combo_code`_combo_n''="`_combo_text`_combo_n''""'
            }
        }
        restore
        local _combo_map = strtrim(`"`_combo_map'"')

        * Give the combine() variable its own label so the allocated codes are
        * readable without consulting r(combine_map).
        if `_combo_n' > 0 {
            _tvtools_new_vallabel, base(_tvcombo_`=substr("`combine'", 1, 20)')
            local _combo_lbl "`r(name)'"
            quietly levelsof `combine' if __n_vals == 1, local(_combo_singles)
            local _combo_lbl_defined = 0
            foreach _cv of local _combo_singles {
                if `_combo_lbl_defined' label define `_combo_lbl' `_cv' "`_cv'", add
                else {
                    label define `_combo_lbl' `_cv' "`_cv'", replace
                    local _combo_lbl_defined = 1
                }
            }
            forvalues _ci = 1/`_combo_n' {
                if `_combo_lbl_defined' ///
                    label define `_combo_lbl' `_combo_code`_ci'' `"`_combo_text`_ci''"', add
                else {
                    label define `_combo_lbl' `_combo_code`_ci'' `"`_combo_text`_ci''"', replace
                    local _combo_lbl_defined = 1
                }
            }
            label values `combine' `_combo_lbl'
        }
        label variable `combine' "Combined exposure state"

        * Update exp_value for overlap segments to the combined value
        quietly replace exp_value = `combine' if __n_vals > 1

        * Keep only one row per sub-period (collapse overlapping rows)
        sort id exp_start exp_stop exp_value
        quietly by id exp_start exp_stop: keep if _n == 1

        drop __n_vals __combo_key
    }
  
    **# Check for overlapping exposures and warn if no strategy specified
    * Skip for dose (already handled with proportional allocation above)
    if "`exp_type'" != "dose" {
    * Detect overlaps between different exposure categories
    sort id exp_start exp_stop exp_value
    quietly gen double __has_conflict = 0
    quietly by id: replace __has_conflict = 1 if (exp_start[_n+1] <= exp_stop & ///
        exp_value != exp_value[_n+1]) & _n < _N & id == id[_n+1]

    * Get list of IDs with conflicts (only if no overlap strategy specified)
    if "`priority'" == "" & "`split'" == "" & "`combine'" == "" & "`layer'" == "" {
        quietly levelsof id if __has_conflict == 1, local(conflict_ids) clean
        
        if "`conflict_ids'" != "" {
            * Count number of IDs with overlaps
            local n_overlap_ids: word count `conflict_ids'
            
            * Store list of IDs in return scalar for later reference
            return local overlap_ids "`conflict_ids'"
            
            noisily display as text ""
            noisily display as text "Warning! Overlapping exposure categories detected for `n_overlap_ids' IDs"
            if "`verbose'" != "" {
                noisily display as text "  (List of IDs stored in r(overlap_ids))"
            }
            else {
                noisily display as text "  (specify verbose to list affected IDs)"
            }
            noisily display as text ""
            noisily display as text "Default behavior: Later exposures take precedence (layer-style resolution)"
            noisily display as text "Consider using one of these options to resolve overlaps explicitly:"
            noisily display as text "  priority(numlist) - Specify precedence order for exposure types"
            noisily display as text "  layer - Later exposures take precedence, earlier resume after"
            noisily display as text "  split - Create separate periods at all boundaries"
            noisily display as text "  combine(newvar) - Encode overlaps as combined values"
        }
    }
    drop __has_conflict

    * Default to layer if no overlap handling option was specified
    * Set here (after warning block) so the warning can fire in the default case
    if "`priority'" == "" & "`split'" == "" & "`combine'" == "" & "`layer'" == "" {
        local layer "layer"
    }

    * Adjust for overlapping different exposure types (simple truncation)
    * When different exposure types overlap, later one takes precedence
    * (Assumes data recording order reflects most recent exposure status)
    * Use iterative resolution to handle cascading overlaps
    * ONLY run as fallback when no overlap strategy is specified
    * priority/split/combine/layer each handle overlaps in their own blocks
    if "`layer'" == "" & "`priority'" == "" & "`split'" == "" & "`combine'" == "" {
        sort id exp_start exp_stop exp_value

        local iter = 0
        local max_iter = _N + 1
        local has_overlaps = 1

        while `has_overlaps' == 1 & `iter' < `max_iter' {
            * Truncate earlier period when later period overlaps with different exposure
            * If next period starts before current ends, truncate current to end before next starts
            quietly by id: replace exp_stop = exp_start[_n+1] - 1 if exp_value != exp_value[_n+1] & ///
                                                              exp_start[_n+1] <= exp_stop & _n < _N & id == id[_n+1]

            * Drop periods that became invalid after adjustment
            quietly drop if exp_start > exp_stop

            * Re-sort after dropping periods
            sort id exp_start exp_stop exp_value

            * Check if any overlaps remain
            quietly gen double __still_overlap = 0
            quietly by id: replace __still_overlap = (exp_start[_n+1] <= exp_stop & ///
                exp_value != exp_value[_n+1]) if _n < _N & id == id[_n+1]
            quietly count if __still_overlap == 1
            if r(N) == 0 {
                local has_overlaps = 0
            }
            quietly drop __still_overlap

            local iter = `iter' + 1
        }

        if `has_overlaps' & `iter' >= `max_iter' {
            noisily display as text "Note: simple overlap resolution reached its safety bound; checking the final invariant"
        }
    }
    
    * Apply priority ordering if specified
    * When periods overlap, user specifies which exposure takes precedence
    * priority(3 2 1) means: type 3 highest priority, then 2, then 1
    * Higher priority periods take precedence; lower priority periods are truncated/removed
    if "`priority'" != "" {
        * Create ranking variable based on priority order
        quietly generate double priority_rank = 999
        local rank = 1
        foreach val of numlist `priority' {
            quietly replace priority_rank = `rank' if exp_value == `val'
            local rank = `rank' + 1
        }
        
        * Sort by person, priority (lower rank = higher priority), then start date
        sort id priority_rank exp_start exp_stop
        
        * Iteratively handle overlaps between different priority levels
        local iter = 0
        local max_iter = _N + 1
        local changed = 1
        
        while `changed' == 1 & `iter' < `max_iter' {
            sort id priority_rank exp_start exp_stop

            * ================================================================
            * MATA OPTIMIZATION: O(n log n) overlap detection and resolution
            * Replaces O(n²) nested forvalues loops with compiled Mata code
            * Performance: 10K obs <1s, 100K obs <10s, 1M obs <2min
            * ================================================================

            * Call Mata library for overlap detection and resolution
            * Creates: __overlaps_higher, __first_overlap_row, __adj_start, __adj_stop, __valid
            * Invoked `noisily' so the engine's >100k-row progress line surfaces on
            * a normal run yet stays suppressed under `quietly tvexpose'.
            noisily _tvexpose_mata_overlaps id exp_start exp_stop priority_rank
            local n_overlaps = r(n_overlaps)

            if `n_overlaps' == 0 {
                local changed = 0
                capture quietly drop __overlaps_higher __first_overlap_row __adj_start __adj_stop __valid
                local _overlap_drop_rc = _rc
            }
            else {
                * Apply Mata-computed adjustments to overlapping records
                * For non-overlapping: __adj_start == exp_start, __adj_stop == exp_stop
                * For overlapping: dates adjusted to resolve priority conflicts
                quietly replace exp_start = __adj_start
                quietly replace exp_stop = __adj_stop

                * Remove records completely covered by higher-priority periods
                quietly keep if __valid == 1

                * Clean up temp variables
                quietly drop __overlaps_higher __first_overlap_row __adj_start __adj_stop __valid
            }

            local iter = `iter' + 1
        }
        
        if `changed' & `iter' >= `max_iter' {
            noisily display as text "Note: priority resolution reached its safety bound; checking the final invariant"
        }
        
        drop priority_rank
    }
    
    * ===========================================================================
    * LAYER ALGORITHM: Sequential Precedence with Resumption
    * ===========================================================================
    * Purpose: Handle overlapping exposure periods with intuitive precedence
    *
    * Key concept - "Layering":
    *   When exposure B starts while exposure A is active:
    *   1. A is truncated to end just before B starts (pre-overlap segment)
    *   2. B takes full precedence during the overlap
    *   3. If A extended beyond B, A resumes after B ends (post-overlap segment)
    *
    * Visual example:
    *   Before:  A: |-------------------| (days 1-20, exposure type 1)
    *            B:      |-------|       (days 5-12, exposure type 2)
    *
    *   After:   A: |----|               (days 1-4, type 1 - pre-overlap)
    *            B:      |-------|       (days 5-12, type 2 - takes precedence)
    *            A:               |----| (days 13-20, type 1 - resumption)
    *
    * Why layer vs other strategies:
    *   - split: Creates separate periods for every combination (exponential growth)
    *   - priority: Static ordering, no resumption
    *   - combine: Merges overlaps into new combined type
    *   - layer: Preserves original types with natural chronological precedence
    *
    * ===========================================================================
    **# Layer option: Sequential precedence with resumption
    if "`layer'" != "" {
        tempvar _tvx_layer_group
        quietly egen long `_tvx_layer_group' = group(id)

        * Study bounds are needed immediately by baseline/post-exposure row
        * construction, before the later master-data refresh.
        local layer_payload "id study_entry study_exit"
        foreach payload_var of local keepvars {
            if "`payload_var'" != "id" {
                local layer_payload "`layer_payload' `payload_var'"
            }
        }

        tempfile layer_payload_data
        preserve
        quietly keep `_tvx_source_order' `layer_payload'
        quietly isid `_tvx_source_order'
        quietly save `layer_payload_data', replace
        restore

        quietly keep `_tvx_layer_group' exp_start exp_stop exp_value ///
            `_tvx_source_order'
        sort `_tvx_layer_group' exp_start `_tvx_source_order'
        quietly _tvexpose_mata_layer `_tvx_layer_group' exp_start exp_stop ///
            exp_value `_tvx_source_order'
        local n_layer_rows = r(n_layer)
        quietly keep in 1/`n_layer_rows'
        quietly merge m:1 `_tvx_source_order' using `layer_payload_data', ///
            keep(3) nogen
        drop `_tvx_layer_group'
        sort id exp_start exp_stop exp_value
    }

    * Never return success with unresolved different-class overlaps. split is
    * the explicit multi-row representation and therefore exempt.
    if "`split'" == "" {
        tempvar _tvx_conflict_id
        quietly egen long `_tvx_conflict_id' = group(id)
        sort `_tvx_conflict_id' exp_start exp_stop exp_value
        quietly _tvexpose_mata_conflicts `_tvx_conflict_id' exp_start exp_stop exp_value
        local n_unresolved_overlaps = r(n_conflicts)
        drop `_tvx_conflict_id'
        if `n_unresolved_overlaps' > 0 {
            noisily display as error "Overlap resolution left `n_unresolved_overlaps' conflicting row(s)"
            noisily display as error "No output was committed; choose an explicit overlap policy or inspect the source episodes."
            exit 498
        }
    }
    } // End of if "`exp_type'" != "dose" block for overlap handling

    capture drop `_tvx_source_order'

    * Save cleaned and overlap-adjusted exposures
    sort id exp_start exp_stop exp_value
    quietly save `exp_cleaned', replace
    } // End of if `exp_cleaned_n' > 0 block for exposure processing

    * Check if any exposures exist in the dataset
    quietly use `exp_cleaned', clear
    quietly count
    if r(N) == 0 {
        * No exposures after filtering - this is valid (all time will be reference)
        noisily display as text "Note: No valid exposure periods found after filtering"
        noisily display as text "      All person-time will be assigned reference category"
    }

    * ===========================================================================
    * STEP 3: GAP PERIOD CREATION (Reference/Unexposed Time)
    * ===========================================================================
    * Purpose: Fill gaps between exposure periods with reference (unexposed) time
    *
    * Why this matters for survival analysis:
    *   - Cox models require continuous person-time from entry to exit
    *   - Gaps in coverage would cause incorrect risk set calculations
    *   - This ensures every day from study entry to exit is accounted for
    *
    * Gap handling with grace periods:
    *   - Grace <= gap: periods are bridged (same episode)
    *   - Grace > gap: gap filled with reference (unexposed) period
    *   - Category-specific grace: different thresholds per exposure type
    *
    * Carryforward interaction:
    *   - If carryforward(#) specified, gaps <= # days get previous exposure value
    *   - Remaining gap time (if any) becomes reference category
    *
    * Complete person-time coverage requires three types of unexposed periods:
    *   1. Gap periods (this step) - time between exposures
    *   2. Baseline periods (Step 5) - time before first exposure
    *   3. Post-exposure periods (Step 6) - time after last exposure
    *
    * Together, these ensure: sum(period_days) = study_exit - study_entry + 1
    * ===========================================================================
    **# Step 3: Create gap periods (reference category for unexposed time)
    {
    quietly use `exp_cleaned', clear
    sort id exp_start
    
    * Calculate gap duration between consecutive exposure periods
    * gap_days = (start of next period) - (end of current period) - 1
    quietly generate double __gap_days = 0
    quietly by id : replace __gap_days = exp_start[_n+1] - exp_stop - 1 if _n < _N & id == id[_n+1]
    
    * Apply grace periods to gap calculation
    * Gap <= grace_days is ignored (periods merged); gap > grace_days creates reference period
    quietly generate double __grace_days = `grace_default'
    if `grace_bycategory' == 1 {
        * Apply category-specific grace periods
        * First validate that specified categories exist in the data
        quietly levelsof exp_value, local(__grace_cats)
        foreach c of local __grace_cats {
            if "`grace_cat`c''" != "" {
                quietly replace __grace_days = `grace_cat`c'' if exp_value == `c'
            }
        }
        
        * Warn if user specified grace for categories not present in data
        * (This is informational only, not an error)
        noisily display as text "Note: Grace periods applied for existing categories in data"
    }
    

    * NEW: Bridge small gaps within grace by extending previous period's stop
    * This ensures gaps <= grace are treated as the same episode (no uncovered days).
    * CRITICAL: Only apply grace within same exposure type to avoid incorrectly extending exposure labels
    * FIX: Added exp_value == exp_value[_n+1] condition to enforce same-type bridging
    quietly by id : replace exp_stop = exp_start[_n+1] - 1 if _n < _N & id == id[_n+1] & ///
        __gap_days <= __grace_days & !missing(__gap_days) & !missing(exp_start[_n+1]) & ///
        exp_stop < exp_start[_n+1] - 1 & exp_value == exp_value[_n+1]
    
    * Recompute gap duration after bridging so remaining gaps reflect true uncovered time
    quietly replace __gap_days = .
    quietly by id : replace __gap_days = exp_start[_n+1] - exp_stop - 1 if _n < _N & id == id[_n+1]

    * Grace bridges only same-class episodes. Every remaining positive gap,
    * including a sub-grace cross-class gap, is reference person-time.
    quietly generate double __gap_start = exp_stop + 1 if __gap_days > 0 & !missing(__gap_days)
    quietly generate double __gap_stop = 0
    quietly by id : replace __gap_stop = exp_start[_n+1] - 1 if __gap_days > 0 & ///
        !missing(__gap_days) & _n < _N & id == id[_n+1]
    
    * Extract and save gap periods
    tempfile pregap
    quietly save `pregap', replace
    quietly keep if !missing(__gap_start) & !missing(__gap_stop)
    
    * Apply carryforward logic if specified
    * Carryforward fills gaps with the previous exposure value for up to carryforward days
    if `gap_carryforward' > 0 {
        * Save previous exposure value to carry forward into gap
        quietly generate double __prev_exp_value = exp_value
        
        * Calculate actual gap duration
        quietly generate double __actual_gap = __gap_stop - __gap_start + 1
        
        * For gaps <= carryforward days: fill entire gap with previous exposure
        * For gaps > carryforward days: split into carryforward period + reference period
        quietly generate double __carry_stop = min(__gap_start + `gap_carryforward' - 1, __gap_stop)
        quietly generate double __ref_start = __carry_stop + 1
        
        * Create carryforward periods (always created, up to carryforward days)
        keep id __gap_start __carry_stop __prev_exp_value __actual_gap __gap_stop
        rename (__gap_start __carry_stop __prev_exp_value) (exp_start exp_stop exp_value)
        tempfile carryforward_gaps
        quietly save `carryforward_gaps', replace
        
        * Create reference periods for remaining gap (only if gap > carryforward)
        quietly keep if __actual_gap > `gap_carryforward'
        quietly drop exp_start
        quietly generate double exp_start = exp_stop + 1
        quietly drop exp_stop
        rename __gap_stop exp_stop
        quietly replace exp_value = `reference'
        keep id exp_start exp_stop exp_value
        tempfile ref_gaps
        quietly save `ref_gaps', replace
        
        * Combine carryforward and reference gap periods
        * (tempfile local is _gapsfile, NOT gaps: naming it `gaps' would fill
        * the `gaps' display-option local and force the diagnostic every run)
        quietly use `carryforward_gaps', clear
        keep id exp_start exp_stop exp_value
        capture confirm file `ref_gaps'
        if _rc == 0 {
            quietly append using `ref_gaps'
        }
        tempfile _gapsfile
        quietly save `_gapsfile', replace
    }
    else {
        * No carryforward: all gaps are reference periods
        keep id __gap_start __gap_stop
        rename (__gap_start __gap_stop) (exp_start exp_stop)
        quietly gen exp_value = `reference'
        tempfile _gapsfile
        quietly save `_gapsfile', replace
    }
    
    quietly use `pregap', clear
    
    drop __gap_days __grace_days __gap_start __gap_stop
    
    * CRITICAL: Save bridged data back to exp_cleaned so all subsequent steps use bridged version
    * Without this, grace bridges are lost when exp_cleaned is reloaded later
    quietly save `exp_cleaned', replace
    }
    * End of gap period creation
    
    **# Step 4: Identify earliest exposure per person
    * Used to create baseline period (pre-first exposure)
    * When there are no exposures, earliest will be empty and Step 5 handles it
    quietly use `exp_cleaned', clear
    quietly count
    if r(N) > 0 {
        * Find first exposure date for each person
        quietly bysort id (exp_start): gen double first = _n == 1
        quietly keep if first == 1
        keep id exp_start
        rename exp_start earliest_exp
    }
    else {
        * No exposures - create empty dataset with correct structure
        quietly keep id
        quietly gen double earliest_exp = .
        quietly drop if 1
    }

    tempfile earliest
    quietly save `earliest', replace
    
    **# Step 5: Create baseline period (pre-first exposure) 
    * 
    * For NEVER-EXPOSED persons:
    *   - Creates a single period from study_entry to study_exit with reference value
    *
    * For EVER-EXPOSED persons:
    *   - Creates period from study_entry to (first_exposure - 1) with reference value
    *   - Ensures complete coverage from study entry onward
    *
    * Combined with automatic gap and post-exposure period creation, baseline ensures
    * every person has continuous coverage from entry to exit with no missing time.
    *
    {
        quietly use `master_dates', clear
        quietly gen exp_value = `reference'
        
        * Merge with earliest exposure date
        preserve
        quietly use `earliest', clear
        isid id
        restore
        isid id
        quietly merge 1:1 id using `earliest', nogen keep(1 3)
        
        * Create baseline period from entry to day before first exposure (inclusive dates)
        quietly generate double exp_start = study_entry
        quietly generate double exp_stop = earliest_exp - 1 if !missing(earliest_exp)
        * If no exposure ever, baseline extends to exit
        quietly replace exp_stop = study_exit if missing(exp_stop)
        
        * Keep only valid baseline periods
        quietly keep if exp_stop >= exp_start
        quietly keep if exp_stop >= study_entry
        
        keep id exp_start exp_stop exp_value
        
        tempfile firstrow
        quietly save `firstrow', replace
    }
    
    **# Step 6: Create post-final exposure period (reference category)
    * Automatically creates UNEXPOSED (reference) period from last exposure end to study exit
    * This ensures no missing time at the end of follow-up for exposed persons
    * Combined with Step 3 (gaps) and Step 5 (baseline), provides complete coverage
    * Represents unexposed time at end of follow-up after all exposures have ended
    {
    quietly use `exp_cleaned', clear
    quietly count
    if r(N) > 0 {
        * Identify last exposure end date per person
        quietly by id : gen double last = _n == _N
        quietly keep if last == 1
        keep id exp_stop study_exit
        rename exp_stop last_exp_stop

        * Only create post-exposure period if gap exists between last exposure and exit
        quietly keep if last_exp_stop < study_exit

        quietly gen exp_value = `reference'
        quietly generate double exp_start = last_exp_stop + 1  // Start day after last exposure ends
        quietly generate double exp_stop = study_exit

        keep id exp_start exp_stop exp_value
    }
    else {
        * No exposures - keep empty dataset with just core columns
        keep id exp_start exp_stop exp_value
        quietly drop if 1
    }

    tempfile lastrow
    quietly save `lastrow', replace
    }
    * End of post-exposure period creation 
    
    **# Step 7: Combine all periods into complete time-varying dataset
    * Append: exposed periods + gap periods + baseline + post-final
    * Result: Complete person-time coverage from entry to exit
    quietly use `exp_cleaned', clear
    
    * Merge back master dataset variables if keepvars specified
    if "`keepvars'" != "" {
        preserve
        quietly use `master_dates', clear
        isid id
        restore
        quietly merge m:1 id using `master_dates', nogen keep(3)
    }
    
    * Append gap periods
    capture confirm file `_gapsfile'
    if _rc == 0 {
        quietly append using `_gapsfile'
    }
    
    * Append baseline period
    capture confirm file `firstrow'
    if _rc == 0 {
            quietly append using `firstrow'
    }
    
    * Append post-exposure period
    capture confirm file `lastrow'
    if _rc == 0 {
        quietly append using `lastrow'
    }
    
    * BUGFIX: Ensure exp_value exists and has reference value for any missing observations
    * This handles cases where appended datasets might have missing exp_value
    capture confirm variable exp_value
    if _rc != 0 {
        quietly gen exp_value = `reference'
    }
    else {
        quietly replace exp_value = `reference' if missing(exp_value)
    }
    
    * Clean up combined dataset
    * Remove exact duplicates
    sort id exp_start exp_stop exp_value
    quietly duplicates drop id exp_start exp_stop exp_value, force
    
    * Merge back study dates and keepvars for ALL rows
    * CRITICAL: This is needed because appended rows (gaps, baseline, post-exposure)
    * don't have study_entry/study_exit variables, which are required for final truncation
    * The update option fills missing values without overwriting existing non-missing values
    * This must happen regardless of whether keepvars was specified
    preserve
    quietly use `master_dates', clear
    isid id
    restore
    quietly merge m:1 id using `master_dates', update nogen keep(1 3 4)
    
    * Restore variable and value labels for keepvars and study dates
    * This ensures labels from master dataset are preserved in output
    if "`study_entry_varlab'" != "" {
        label variable study_entry "`study_entry_varlab'"
    }
    if "`study_exit_varlab'" != "" {
        label variable study_exit "`study_exit_varlab'"
    }
    
    if "`keepvars'" != "" {
        foreach var of local keepvars {
            * Restore variable label
            if "`varlab_`var''" != "" {
                label variable `var' "`varlab_`var''"
            }
            
            * Restore value labels if they existed
            if "`vallab_`var''" != "" {
                capture do "`_lbl_stub'_label_`var'.do"
                if _rc == 0 {
                    label values `var' `vallab_`var''
                }
            }
        }
    }
    
    * Final truncation to study window
    * Safety check: ensure all periods within [entry, exit]
    quietly drop if exp_stop < study_entry
    quietly drop if exp_start > study_exit
    quietly replace exp_start = study_entry if exp_start < study_entry
    quietly replace exp_stop = study_exit if exp_stop > study_exit
    
    * Final sort for processing
    sort id exp_start exp_stop exp_value
    
    * Cache original exposure status before transformations
    * Store binary exposed/unexposed status for later summary calculations
    * Needed because exposure value changes with type transformations below
    quietly gen double __orig_exp_binary = (exp_value != `reference')

    * Preserve the union of currently exposed person-time before cumulative
    * histories replace exp_value. This remains the meaning of exposed_time
    * for continuous and dose output, including split rows that overlap.
    local current_exposed_time = 0
    preserve
    quietly keep if __orig_exp_binary == 1
    quietly count
    if r(N) > 0 {
        tempvar _tvx_current_run _tvx_current_add
        sort id exp_start exp_stop
        quietly by id (exp_start exp_stop): generate double `_tvx_current_run' = exp_stop
        quietly by id (exp_start exp_stop): replace `_tvx_current_run' = ///
            max(`_tvx_current_run', `_tvx_current_run'[_n-1]) if _n > 1
        quietly by id (exp_start exp_stop): generate double `_tvx_current_add' = ///
            exp_stop - exp_start + 1 if _n == 1
        quietly by id (exp_start exp_stop): replace `_tvx_current_add' = ///
            max(exp_stop - max(exp_start - 1, `_tvx_current_run'[_n-1]), 0) ///
            if _n > 1
        quietly summarize `_tvx_current_add', meanonly
        local current_exposed_time = r(sum)
    }
    restore
    
    * Save original exposure categories for bytype processing
    * Must be saved before any exposure type transformations that change exp_value
    quietly gen double __orig_exp_category = exp_value
    
    * Note: For bytype evertreated processing, first exposure dates per type
    * are retrieved from `first_exp_by_type' (saved before overlap resolution)
    * rather than from __orig_exp_category, which only reflects surviving rows
    
    **# EXPOSURE TYPE TRANSFORMATIONS
    * Different exposure types require different transformations of the exposure variable
    * Each type creates different output suitable for different research questions
    *
    * NOTE: Baseline/gap/post-exposure period creation (lines ~1289-1566) has ALREADY
    * completed before this section. That default processing creates complete person-time
    * coverage with unexposed periods and works perfectly. It always runs first regardless
    * of which exposure type option is specified.
    *
    * PROCESSING ORDER: evertreated, continuous, duration, recency, timevarying
    * Duration comes AFTER continuous because duration() uses continuousunit() calculations.
    * This ordering ensures logical data flow and prevents start date sequencing issues.
    *
    * CRITICAL: For duration, continuous, and similar types, we calculate cumulative
    * values at the START of each period (using [_n-1]), not at the end. This ensures
    * that the exposure classification reflects history accumulated BEFORE the period
    * begins, which is appropriate for time-varying Cox models where the exposure
    * status at the start of an interval determines the hazard for that interval.
    
    **# Preserve original categorical exposure value for bytype processing
    * Already created above at line 1593
    
    **# Ever-Treated Exposure Type
    * Research question: Does any exposure history affect risk?
    * Output: Binary variable (0=never exposed, 1=ever exposed)
    * Time-varying: Person switches from 0 to 1 at first exposure, stays 1 thereafter
    if "`exp_type'" == "evertreated" {
        if "`bytype'" != "" {
            * Create separate ever-treated variables for each exposure type
            * Each type tracks independently: ever_type=1 from first exposure onward for ALL rows
            * FIXED: Use all exposure types saved BEFORE overlap resolution
            
            * Get complete list of exposure types from saved pre-overlap data
            preserve
            quietly use `all_person_exp_types', clear
            quietly levelsof __all_exp_types, local(exp_types)
            restore

            * Initialize all bytype variables to 0 (never exposed)
            foreach exp_type_val of local exp_types {
                * Sanitize suffix for variable names (handles negative/decimal values)
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                quietly gen double `stub_name'`suffix' = 0
            }

            * For each type, find first exposure date and mark all subsequent periods
            * Uses pre-overlap first exposure dates to capture types eliminated by overlap resolution
            foreach exp_type_val of local exp_types {
                * Sanitize suffix for variable names (handles negative/decimal values)
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)

                * Get first exposure date from pre-overlap saved data
                * This correctly captures the first exposure even if overlap resolution
                * eliminated that exposure type entirely
                preserve
                quietly use `first_exp_by_type', clear
                quietly keep if exp_value == `exp_type_val'
                keep id __pre_first_start
                tempfile __temp_first
                quietly save `__temp_first', replace
                restore
                quietly merge m:1 id using `__temp_first', nogen keep(1 3)

                * Mark ALL rows as "ever treated" if they occur at or after first exposure to this type
                quietly replace `stub_name'`suffix' = 1 if exp_start >= __pre_first_start & !missing(__pre_first_start)
                drop __pre_first_start

                * Get label from original exposure variable for this type
                local vallab ""
                if "`exp_value_label'" != "" {
                    local vallab : label `exp_value_label' `exp_type_val'
                }
                if "`vallab'" == "" local vallab "`exp_type_val'"
                if "`label'" != "" {
                    label var `stub_name'`suffix' "`label' (`vallab')"
                }
                else {
                    label var `stub_name'`suffix' "Ever exposed: `vallab'"
                }

                * Define and apply value labels
                label define `stub_name'labels_`suffix' 0 "Never `vallab'" 1 "Ever `vallab'", replace
                label values `stub_name'`suffix' `stub_name'labels_`suffix'
            }
            
            * Collapse consecutive periods with identical ever_X values
            * Must also check exp_value to distinguish exposed from unexposed periods
            sort id exp_start
            quietly by id: gen double __same_evers = 1 if _n == 1
            quietly by id: replace __same_evers = 1 if _n > 1
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                quietly by id: replace __same_evers = 0 if _n > 1 & `stub_name'`suffix' != `stub_name'`suffix'[_n-1]
            }
            * Also check if exposure category changed (prevents merging exposed and unexposed periods)
            quietly by id: replace __same_evers = 0 if _n > 1 & exp_value != exp_value[_n-1]
            quietly by id: gen double __period_start = 1 if _n == 1
            quietly by id : replace __period_start = 1 if __same_evers == 0 & _n > 1
            quietly by id: gen double __period_id = sum(__period_start)

            * Build collapse command with all ever variables
            local ever_vars ""
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                local ever_vars "`ever_vars' `stub_name'`suffix'"
            }

            * Store variable labels before collapse
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                local varlab_`suffix' : variable label `stub_name'`suffix'
            }

            if "`keepvars'" != "" {
                collapse (min) exp_start (max) exp_stop (first) exp_value `ever_vars' `keepvars' study_entry study_exit, by(id __period_id)
            }
            else {
                collapse (min) exp_start (max) exp_stop (first) exp_value `ever_vars' study_entry study_exit, by(id __period_id)
            }
            drop __period_id

            * Reapply value labels after collapse
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                label values `stub_name'`suffix' `stub_name'labels_`suffix'
                label variable `stub_name'`suffix' "`varlab_`suffix''"
            }

            * Keep original categorical exposure in exp_value
        }
        else {
            * Create time-varying ever-treated variable (not single row)
            * Person switches from never to ever at first exposure
            
            * Find first exposure start date per person
            quietly gen double __first_exp_temp = exp_start if __orig_exp_binary
            quietly by id : egen double __first_exp_any = min(__first_exp_temp)
            
            * Binary indicator: 0 before first exposure, 1 at/after first exposure
            quietly gen double exp_value_et = cond(exp_start < __first_exp_any | missing(__first_exp_any), 0, 1)
            
            * Replace original exposure variable
            drop exp_value __orig_exp_binary __first_exp_temp __first_exp_any
            rename exp_value_et exp_value
            
            * Collapse consecutive periods with same value
            quietly by id : gen double __new_et = (exp_value != exp_value[_n-1]) if _n > 1 & id == id[_n-1]
            quietly replace __new_et = 1 if _n == 1
            quietly by id: gen double __grp_et = sum(__new_et)

            * Collapse to create clean periods
            if "`keepvars'" != "" {
                collapse (min) exp_start (max) exp_stop (first) exp_value `keepvars' study_entry study_exit, ///
                    by(id __grp_et)
            }
            else {
                collapse (min) exp_start (max) exp_stop (first) exp_value study_entry study_exit, ///
                    by(id __grp_et)
            }
            drop __grp_et

            * Define and apply value labels for binary ever-treated AFTER the
            * collapse -- collapse drops value labels, so labeling before it left
            * the output unlabeled. Use a collision-safe name so a caller's
            * same-named label is never clobbered.
            _tvtools_new_vallabel, base(et_labels)
            local _et_lbl "`r(name)'"
            label define `_et_lbl' 0 "Never exposed" 1 "Ever exposed"
            label values exp_value `_et_lbl'
        }
    }
    

    **# Current/Former Exposure Type
    * Research question: Does current vs former exposure matter?
    * Output: Trichotomous variable (0=never, 1=current, 2=former)
    * Time-varying: Tracks whether currently exposed, formerly exposed, or never exposed
    * Optional: Create separate current/former variables per exposure type (bytype)
    else if "`exp_type'" == "currentformer" {
        if "`bytype'" != "" {
            * Create separate current/former variables for each exposure type
            * Each type tracks independently: 0=never, 1=current, 2=former
            
            * Get complete list of exposure types from saved pre-overlap data
            preserve
            quietly use `all_person_exp_types', clear
            quietly levelsof __all_exp_types, local(exp_types)
            restore
            
            * Initialize all bytype variables to 0 (never exposed)
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                quietly gen double `stub_name'`suffix' = 0
            }

            * For each type, determine current vs former status
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                * Mark current exposure (value = 1)
                quietly replace `stub_name'`suffix' = 1 if __orig_exp_category == `exp_type_val'

                * Find first and last exposure dates for this type
                quietly gen double __first_exp_`suffix' = exp_start if __orig_exp_category == `exp_type_val'
                quietly gen double __last_exp_`suffix' = exp_stop if __orig_exp_category == `exp_type_val'
                quietly bysort id (exp_start): egen double __first_any_`suffix' = min(__first_exp_`suffix')
                quietly bysort id (exp_start): egen double __last_any_`suffix' = max(__last_exp_`suffix')

                * Mark former exposure (value = 2): after last exposure to this type
                quietly replace `stub_name'`suffix' = 2 if exp_start >= __first_any_`suffix' & `stub_name'`suffix' != 1 & !missing(__first_any_`suffix')

                * Get label from original exposure variable for this type
                local vallab ""
                if "`exp_value_label'" != "" {
                    local vallab : label `exp_value_label' `exp_type_val'
                }
                if "`vallab'" == "" local vallab "`exp_type_val'"
                if "`label'" != "" {
                    label var `stub_name'`suffix' "`label' (`vallab')"
                }
                else {
                    label var `stub_name'`suffix' "`vallab'"
                }

                * Define and apply value labels
                label define `stub_name'labels_`suffix' 0 "Never" 1 "Current" 2 "Former", replace
                label values `stub_name'`suffix' `stub_name'labels_`suffix'

                drop __first_exp_`suffix' __last_exp_`suffix' __first_any_`suffix' __last_any_`suffix'
            }

            * Collapse consecutive periods with identical cf_X values
            sort id exp_start
            quietly by id: gen double __same_cf = 1 if _n == 1
            quietly by id: replace __same_cf = 1 if _n > 1
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                quietly by id: replace __same_cf = 0 if _n > 1 & `stub_name'`suffix' != `stub_name'`suffix'[_n-1]
            }
            * Also check if exposure category changed
            quietly by id: replace __same_cf = 0 if _n > 1 & exp_value != exp_value[_n-1]
            quietly by id: gen double __period_start = 1 if _n == 1
            quietly by id : replace __period_start = 1 if __same_cf == 0 & _n > 1
            quietly by id: gen double __period_id = sum(__period_start)

            * Build collapse command with all cf variables
            local cf_vars ""
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                local cf_vars "`cf_vars' `stub_name'`suffix'"
            }

            * Store variable labels before collapse
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                local varlab_`suffix' : variable label `stub_name'`suffix'
            }

            if "`keepvars'" != "" {
                    collapse (min) exp_start (max) exp_stop (first) exp_value `cf_vars' `keepvars' study_entry study_exit, by(id __period_id)
            }
            else {
                    collapse (min) exp_start (max) exp_stop (first) exp_value `cf_vars' study_entry study_exit, by(id __period_id)
            }
            drop __period_id

            * Reapply value labels after collapse
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                label values `stub_name'`suffix' `stub_name'labels_`suffix'
                label variable `stub_name'`suffix' "`varlab_`suffix''"
            }
        }
        else {
            * Create time-varying current/former variable across all exposure types
            * 0 = never exposed, 1 = currently exposed, 2 = formerly exposed
            
            * Find first and last exposure dates per person
            quietly gen double __first_exp_temp = exp_start if __orig_exp_binary
            quietly gen double __last_exp_temp = exp_stop if __orig_exp_binary
            quietly by id : egen double __first_exp_any = min(__first_exp_temp)
            quietly by id : egen double __last_exp_any = max(__last_exp_temp)
            
            * Trichotomous indicator: 0=never, 1=current, 2=former
            quietly gen double exp_value_cf = 0
            * Currently exposed
            quietly replace exp_value_cf = 1 if __orig_exp_binary
            * Formerly exposed (after last exposure but had exposure before)
            quietly replace exp_value_cf = 2 if exp_start >= __first_exp_any & exp_value_cf != 1 & !missing(__first_exp_any)
            
            * Replace original exposure variable
            drop exp_value __orig_exp_binary __first_exp_temp __last_exp_temp __first_exp_any __last_exp_any
            rename exp_value_cf exp_value
            
            * Collapse consecutive periods with same value
            quietly by id : gen double __new_cf = (exp_value != exp_value[_n-1]) if _n > 1 & id == id[_n-1]
            quietly replace __new_cf = 1 if _n == 1
            quietly by id: gen double __grp_cf = sum(__new_cf)
            
            * Collapse to create clean periods
            if "`keepvars'" != "" {
                collapse (min) exp_start (max) exp_stop (first) exp_value `keepvars' study_entry study_exit, ///
                    by(id __grp_cf)
            }
            else {
                collapse (min) exp_start (max) exp_stop (first) exp_value study_entry study_exit, ///
                    by(id __grp_cf)
            }
            drop __grp_cf
            
            * Define and apply value labels
            * (collision-safe name so a caller's same-named label is never clobbered)
            _tvtools_new_vallabel, base(cf_labels)
            local _cf_lbl "`r(name)'"
            label define `_cf_lbl' 0 "Never" 1 "Current" 2 "Former"
            label values exp_value `_cf_lbl'
        }
    }
    

    **# Continuous Duration Exposure Type
    * Research question: Is there dose-response for cumulative exposure?
    * Output: Continuous variable (person-years of exposure)
    * Time-varying: Increases monotonically with each day of exposure
    * Optional: Expand rows to unit-level granularity (weeks/months/quarters/years)
    * Optional: Create separate continuous variables per exposure type (bytype)
    else if "`exp_type'" == "continuous" {
        * Calculate cumulative exposure duration as continuous variable (person-years)
        sort id exp_start
        quietly gen double __exp_now_cont = __orig_exp_binary
        
        * Preserve original exposure value for bytype option
        if "`bytype'" != "" {
            quietly gen __orig_exp_value = exp_value
        }
        
        **## Handle continuous(unit) expansion with expandunit()
        * expandunit() specifies row expansion granularity (weeks/months/quarters/years)
        * continuousunit() specifies reporting units for cumulative exposure
        * If expandunit is days, no expansion (cumulative reported at end of each original period)
        * Unexposed periods remain as-is (not expanded)
        * Each expanded row reports cumulative exposure in the unit specified by continuousunit()
        
        if "`expand_unit'" != "" & "`expand_unit'" != "days" {
            * Mark exposed periods for expansion
            quietly gen double __needs_expansion = __exp_now_cont
            
            **### Expand exposed periods by unit
            tempfile pre_expansion
            quietly save `pre_expansion', replace
            
            * Process only exposed periods that need expansion
            quietly keep if __needs_expansion == 1
            
            if _N > 0 {
                * Generate unit boundaries for each exposed period
                * Strategy: Create multiple rows per period based on unit alignment
                
                **#### Fixed-length unit bins from the exposure start
                * weeks/months/quarters/years differ only by the average bin
                * length in days; one Mata pass computes the unit boundaries for
                * all four, bit-identically to the former per-unit blocks.
                if "`expand_unit'" == "weeks"         local __ulen 7
                else if "`expand_unit'" == "months"   local __ulen 30.4375
                else if "`expand_unit'" == "quarters" local __ulen 91.3125
                else if "`expand_unit'" == "years"    local __ulen 365.25

                * One identifier per pre-expansion period
                quietly gen double __period_id = _n
                * Number of unit bins spanning the period
                quietly gen double n_units = ceil((exp_stop - exp_start + 1) / `__ulen')
                * Expand to one row per unit bin
                quietly expand n_units
                quietly bysort id __period_id: gen double unit_seq = _n
                * Compute unit interval boundaries in Mata (floored to integer
                * dates so bins abut with no gaps; final bin clipped to exp_stop)
                quietly gen double unit_start = .
                quietly gen double unit_stop = .
                _tvexpose_expand_units exp_start exp_stop n_units unit_seq unit_start unit_stop, ulen(`__ulen')
                * Drop original period boundaries
                drop exp_start exp_stop __period_id
                rename (unit_start unit_stop) (exp_start exp_stop)
                
                * Save expanded exposed periods
                gen double __unitized = 1
                drop n_units __needs_expansion
                tempfile expanded_exposed
                quietly save `expanded_exposed', replace
            }
            
            * Restore full dataset and keep unexposed periods
            quietly use `pre_expansion', clear
            quietly keep if __needs_expansion == 0
            gen double __unitized = 0
            drop __needs_expansion
            
            * Append expanded exposed periods
            capture confirm file `expanded_exposed'
            if _rc == 0 {
                quietly append using `expanded_exposed'
            }
            
            * Re-sort after expansion
            sort id exp_start

            * NEW: Post-expansion cleanup — remove overlaps and merge abutting same-value periods
            quietly bysort id (exp_start): gen double __ovl = (exp_start <= exp_stop[_n-1]) if _n>1 & id==id[_n-1]
            quietly count if __ovl==1
            if r(N)>0 {
                noisily display as text "Note: Coalescing overlapping periods produced by expansion"
            }
            quietly bysort id (exp_start): gen double __break = (_n==1) | (exp_value != exp_value[_n-1]) | (exp_start > exp_stop[_n-1] + 1)
            quietly replace __break = 1 if "`expand_unit'" != "days" & __unitized == 1
            quietly by id: gen double __grp = sum(__break)
            if "`keepvars'" != "" {
                if "`bytype'" != "" {
                    collapse (min) exp_start (max) exp_stop (first) exp_value __orig_exp_value `keepvars' study_entry study_exit, by(id __grp)
                }
                else {
                    collapse (min) exp_start (max) exp_stop (first) exp_value `keepvars' study_entry study_exit, by(id __grp)
                }
            }
            else {
                if "`bytype'" != "" {
                    collapse (min) exp_start (max) exp_stop (first) exp_value __orig_exp_value study_entry study_exit, by(id __grp)
                }
                else {
                    collapse (min) exp_start (max) exp_stop (first) exp_value study_entry study_exit, by(id __grp)
                }
            }
            drop __grp
            sort id exp_start

        }
        
        **## Calculate cumulative exposure (in units specified by continuousunit)
        * This applies regardless of whether unit expansion was performed
        * Unit conversion: days to the specified unit
        
        * Set conversion factor based on continuousunit
        if "`cont_unit'" == "days" {
            local unit_divisor = 1
        }
        else if "`cont_unit'" == "weeks" {
            local unit_divisor = 7
        }
        else if "`cont_unit'" == "months" {
            local unit_divisor = 365.25 / 12
        }
        else if "`cont_unit'" == "quarters" {
            local unit_divisor = 365.25 / 4
        }
        else if "`cont_unit'" == "years" {
            local unit_divisor = 365.25
        }
        
        * Calculate days in each period (inclusive of both ends)
        quietly generate double period_days = exp_stop - exp_start + 1
        * Only count exposed time toward cumulative
        quietly replace period_days = 0 if exp_value == `reference'
        
        * A model-row history must contain only information known when that row
        * starts. Keep the endpoint total internally, then subtract the current
        * row's contribution to obtain the non-anticipating start history.
        quietly bysort id (exp_start): gen cumul_days_end = sum(period_days)
        quietly generate double cumul_days_start = cumul_days_end - period_days
        
        **## Generate separate continuous variables by exposure type (bytype option)
        * Create tv_exp_[value] for each non-reference exposure type
        * Each tracks cumulative exposure in specified units of that specific exposure type
        * When bytype is used, main exposure variable remains categorical
        if "`bytype'" != "" {
            * Get unique non-reference exposure values from preserved original
            * FIXED: Use all exposure types saved BEFORE overlap resolution
            preserve
            quietly use `all_person_exp_types', clear
            quietly levelsof __all_exp_types, local(exp_types)
            restore
            
            * For each exposure type, calculate cumulative exposure
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                * Calculate days exposed to this specific type
                quietly gen double period_days_`suffix' = period_days if __orig_exp_value == `exp_type_val'
                quietly replace period_days_`suffix' = 0 if missing(period_days_`suffix')

                * Calculate cumulative exposure for this type
                quietly bysort id (exp_start): gen cumul_days_`suffix'_end = sum(period_days_`suffix')
                quietly gen double `stub_name'`suffix' = ///
                    (cumul_days_`suffix'_end - period_days_`suffix') / `unit_divisor'

                * Label the variable with value label and units from continuousunit
                local vallab ""
                if "`exp_value_label'" != "" {
                    local vallab : label `exp_value_label' `exp_type_val'
                }
                if "`vallab'" == "" local vallab "`exp_type_val'"
                if "`label'" != "" {
                    label var `stub_name'`suffix' "`label' (`vallab')"
                }
                else {
                    label var `stub_name'`suffix' "Cumulative `vallab' exposure (`cont_unit')"
                }

                * Clean up intermediate variables
                quietly drop period_days_`suffix' cumul_days_`suffix'_end
            }

            * For bytype, keep exposure variable as categorical type
            * Replace with preserved original values
            quietly replace exp_value = __orig_exp_value
            quietly drop __orig_exp_value

            * Collapse consecutive periods with identical tv_exp_X values
            sort id exp_start
            quietly by id : gen double __same_cumuls = 1 if _n == 1
            quietly by id : replace __same_cumuls = 1 if _n > 1
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                quietly by id : replace __same_cumuls = 0 if _n > 1 & `stub_name'`suffix' != `stub_name'`suffix'[_n-1]
            }
            quietly by id: gen double __period_start = 1 if _n == 1
            quietly by id : replace __period_start = 1 if __same_cumuls == 0 & _n > 1
            quietly by id: gen double __period_id = sum(__period_start)

            * Build collapse command with all tv_exp variables
            local tvexp_vars ""
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                local tvexp_vars "`tvexp_vars' `stub_name'`suffix'"
            }

            * Store variable labels before collapse
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                local varlab_`suffix' : variable label `stub_name'`suffix'
            }

            if "`keepvars'" != "" {
                    collapse (min) exp_start (max) exp_stop (first) exp_value `tvexp_vars' `keepvars' study_entry study_exit, by(id __period_id)
                }
            else {
                    collapse (min) exp_start (max) exp_stop (first) exp_value `tvexp_vars' study_entry study_exit, by(id __period_id)
            }

            drop __period_id

            * Reapply value labels after collapse
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                label variable `stub_name'`suffix' "`varlab_`suffix''"
            }

        }
        else {
            * Standard continuous: convert main exposure variable to specified units
            quietly gen exp_value_new = cumul_days_start / `unit_divisor'
            drop exp_value period_days cumul_days_start cumul_days_end
            rename exp_value_new exp_value
        }
    }


    **# Duration Category Exposure Type
    * Research question: Does longer exposure history increase risk?
    * Output: Categorical variable representing cumulative exposure duration bands
    * Example: duration(1 5) with continuousunit(years) creates: unexposed, <1, 1-<5, 5+
    * Time-varying: Person moves through higher duration categories over time
    * REFACTORED: Now uses continuousunit() for calculation, then recodes to categories
    else if "`exp_type'" == "duration" {
        * Duration now implemented as a recoding of continuous exposure
        * Step 1: Calculate continuous cumulative exposure using continuousunit()
        * Step 2: Recode continuous values into duration categories
        
        * Parse cutpoints
        local n_cuts : word count `duration'
        tokenize `duration'
        
        * Set unit conversion factor based on continuousunit
        if "`unit_lower'" == "days" {
            local unit_divisor = 1
            local unit_name "days"
        }
        else if "`unit_lower'" == "weeks" {
            local unit_divisor = 7
            local unit_name "weeks"
        }
        else if "`unit_lower'" == "months" {
            local unit_divisor = 30.4375
            local unit_name "months"
        }
        else if "`unit_lower'" == "quarters" {
            local unit_divisor = 91.3125
            local unit_name "quarters"
        }
        else if "`unit_lower'" == "years" {
            local unit_divisor = 365.25
            local unit_name "years"
        }
        
        sort id exp_start exp_stop exp_value
        quietly gen double __exp_now_dur = __orig_exp_binary
        
        if "`bytype'" != "" {
            * NEW APPROACH: Pre-calculate threshold crossing dates, then split all periods
            * This eliminates floating-point errors and 1-day gaps
            
            * Preserve original exposure value for bytype option
            quietly gen __orig_exp_value = exp_value
            
            * Get complete list of exposure types from saved pre-overlap data
            preserve
            quietly use `all_person_exp_types', clear
            quietly levelsof __all_exp_types, local(exp_types)
            restore


            * Fix TRUE overlaps before cumulative calculations
            * Note: exp_start == exp_stop[_n-1] is ABUTTING (valid), not an overlap
            * Only fix when exp_start < exp_stop[_n-1] (actual overlap)
            sort id exp_start
            quietly by id (exp_start): replace exp_start = exp_stop[_n-1] + 1 if _n > 1 & exp_start < exp_stop[_n-1] & __exp_now_dur & exp_stop[_n-1] + 1 <= exp_stop

            * NEW APPROACH: Pre-calculate threshold crossing dates, then split all periods at those dates
            * This eliminates floating-point errors and 1-day gaps caused by floor() arithmetic
            
            * Step 1: Calculate cumulative exposure and identify threshold crossing dates
            noisily display as text "Calculating threshold crossing dates..."
            
            * Create dataset of all threshold dates per person per type
            tempfile threshold_dates
            preserve
            
            * Calculate cumulative exposure for each type
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                sort id exp_start
                quietly gen double __period_days_`suffix' = exp_stop - exp_start + 1 if __orig_exp_category == `exp_type_val'
                quietly replace __period_days_`suffix' = 0 if missing(__period_days_`suffix')
                quietly by id: gen double __cumul_days_`suffix' = sum(__period_days_`suffix')

                * For each threshold, find the exact date when person crosses it
                if `n_cuts' > 0 {
                    forvalues i = 1/`n_cuts' {
                        local thresh_units = ``i''
                        local thresh_days = round(`thresh_units' * `unit_divisor')

                        * Generate threshold crossing date
                        * Date = start of period containing threshold + days needed to reach threshold
                        quietly by id: gen double __thresh_date_`suffix'_`i' = .

                        * Find period where cumulative crosses threshold
                        quietly by id: replace __thresh_date_`suffix'_`i' = ///
                            exp_start + (`thresh_days' - (__cumul_days_`suffix' - __period_days_`suffix')) ///
                            if __orig_exp_category == `exp_type_val' & ///
                            (__cumul_days_`suffix' - __period_days_`suffix') < `thresh_days' & ///
                            __cumul_days_`suffix' >= `thresh_days'

                        * Ensure threshold date is within period bounds
                        quietly replace __thresh_date_`suffix'_`i' = . if __thresh_date_`suffix'_`i' > exp_stop
                    }
                }
            }

            * Collect all threshold dates - keep wide format (one row per ID)
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                if `n_cuts' > 0 {
                    forvalues i = 1/`n_cuts' {
                        quietly by id: egen double __max_thresh_`suffix'_`i' = max(__thresh_date_`suffix'_`i')
                        quietly drop __thresh_date_`suffix'_`i'
                        quietly rename __max_thresh_`suffix'_`i' __thresh_date_`suffix'_`i'
                    }
                }
            }
            
            quietly keep id __thresh_date_*
            quietly duplicates drop id, force
            
            quietly save `threshold_dates', replace
            
            * Calculate total threshold count
            local thresh_count = 0
            foreach exp_type_val of local exp_types {
                if `n_cuts' > 0 {
                    local thresh_count = `thresh_count' + `n_cuts'
                }
            }

            * If no thresholds, create empty dataset
            if `thresh_count' == 0 {
                clear
                quietly gen double id = .
                foreach exp_type_val of local exp_types {
                    local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                    local suffix = subinstr("`suffix'", ".", "p", .)
                    if `n_cuts' > 0 {
                        forvalues i = 1/`n_cuts' {
                            quietly gen double __thresh_date_`suffix'_`i' = .
                        }
                    }
                }
                quietly drop if !missing(id)
                quietly save `threshold_dates', replace
            }
            restore
            
            * Step 2: Split all periods at threshold dates
            if `thresh_count' > 0 {
                noisily display as text "Splitting periods at `thresh_count' threshold(s)..."
                
                * Merge threshold dates (m:1 - many exposure periods to one threshold row per ID)
                quietly merge m:1 id using `threshold_dates', keep(master match) nogenerate
                
                * Identify periods that need splitting by checking each threshold variable
                quietly gen double __needs_split = 0
                foreach exp_type_val of local exp_types {
                    local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                    local suffix = subinstr("`suffix'", ".", "p", .)
                    if `n_cuts' > 0 {
                        forvalues i = 1/`n_cuts' {
                            quietly replace __needs_split = 1 if !missing(__thresh_date_`suffix'_`i') & ///
                                __thresh_date_`suffix'_`i' > exp_start & __thresh_date_`suffix'_`i' <= exp_stop
                        }
                    }
                }
                
                quietly count if __needs_split == 1
                local n_to_split = r(N)
                
                if `n_to_split' > 0 {
                    * Create long-format split dates for periods that need splitting
                    tempfile split_candidates
                    quietly save `split_candidates', replace
                    
                    quietly keep if __needs_split == 1
                    
                    * Stack all threshold dates into split_date variable
                    quietly gen double __obs_id = _n
                    local split_vars ""
                    foreach exp_type_val of local exp_types {
                        local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                        local suffix = subinstr("`suffix'", ".", "p", .)
                        if `n_cuts' > 0 {
                            forvalues i = 1/`n_cuts' {
                                quietly gen __split_`suffix'_`i' = __thresh_date_`suffix'_`i'
                                local split_vars "`split_vars' __split_`suffix'_`i'"
                            }
                        }
                    }
                    
                    quietly reshape long __split_, i(__obs_id) j(__thresh_type) string
                    quietly rename __split_ split_date
                    quietly drop if missing(split_date)
                    
                    * Filter to splits within period bounds
                    quietly keep if split_date > exp_start & split_date <= exp_stop
                    quietly drop __thresh_type
                    
                    * Remove duplicate thresholds within same observation
                    quietly sort __obs_id split_date
                    quietly by __obs_id split_date: keep if _n == 1
                    
                    * Create sequential segments between threshold boundaries
                    * Boundaries are: exp_start, split1, split2, ..., splitN, exp_stop+1
                    * Segments are: [boundary[i], boundary[i+1]-1] for each i
                    
                    quietly gen double boundary = split_date
                    quietly gen double boundary_type = 2  // 2 = split threshold
                    
                    * Add start boundaries (exp_start)
                    preserve
                    quietly by __obs_id: keep if _n == 1
                    quietly replace boundary = exp_start
                    quietly replace boundary_type = 1  // 1 = period start
                    tempfile boundaries_start
                    quietly save `boundaries_start', replace
                    restore
                    
                    * Add end boundaries (exp_stop + 1)
                    preserve
                    quietly by __obs_id: keep if _n == 1
                    quietly replace boundary = exp_stop + 1
                    quietly replace boundary_type = 3  // 3 = period end + 1
                    tempfile boundaries_end
                    quietly save `boundaries_end', replace
                    restore
                    
                    * Combine all boundaries
                    quietly append using `boundaries_start'
                    quietly append using `boundaries_end'
                    quietly sort __obs_id boundary
                    
                    * Create segments between consecutive boundaries
                    quietly by __obs_id: gen double __new_start = boundary
                    quietly by __obs_id: gen double __new_stop = boundary[_n+1] - 1
                    
                    * Drop last row of each observation (has no next boundary)
                    quietly by __obs_id: drop if _n == _N
                    
                    * Clean up
                    quietly drop boundary boundary_type split_date __obs_id __needs_split
                    foreach exp_type_val of local exp_types {
                        local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                        local suffix = subinstr("`suffix'", ".", "p", .)
                        if `n_cuts' > 0 {
                            forvalues i = 1/`n_cuts' {
                                quietly drop __thresh_date_`suffix'_`i'
                            }
                        }
                    }
                    quietly drop exp_start exp_stop
                    quietly rename (__new_start __new_stop) (exp_start exp_stop)
                    * Reversed bounds are malformed; negative Stata dates (pre-01jan1960)
                    * are legitimate, so do NOT drop on exp_start<0/exp_stop<0 (F06).
                    quietly drop if exp_start > exp_stop
                    
                    tempfile split_periods
                    quietly save `split_periods', replace
                    
                    * Combine with non-split periods
                    quietly use `split_candidates', clear
                    quietly drop if __needs_split == 1
                    quietly drop __needs_split
                    foreach exp_type_val of local exp_types {
                        local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                        local suffix = subinstr("`suffix'", ".", "p", .)
                        if `n_cuts' > 0 {
                            forvalues i = 1/`n_cuts' {
                                quietly drop __thresh_date_`suffix'_`i'
                            }
                        }
                    }
                    quietly append using `split_periods'
                    sort id exp_start exp_stop
                }
                else {
                    quietly drop __needs_split
                    foreach exp_type_val of local exp_types {
                        local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                        local suffix = subinstr("`suffix'", ".", "p", .)
                        if `n_cuts' > 0 {
                            forvalues i = 1/`n_cuts' {
                                quietly drop __thresh_date_`suffix'_`i'
                            }
                        }
                    }
                }
            }
            
            * Step 3: Recalculate cumulative exposure and assign duration categories
            noisily display as text "Assigning duration categories..."
            
            * Mark first exposure period (any type) per person for carry-forward logic
            sort id exp_start exp_stop exp_value
            quietly bysort id (exp_start exp_stop): egen double __first_exp_any = min(cond(__orig_exp_binary == 1, _n, .))
            
            foreach exp_type_val of local exp_types {
                * Sanitize suffix for variable names (handles negative/decimal values)
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)

                * Recalculate cumulative exposure in days
                sort id exp_start
                quietly gen double __period_days_`suffix' = exp_stop - exp_start + 1 if __orig_exp_category == `exp_type_val'
                quietly replace __period_days_`suffix' = 0 if missing(__period_days_`suffix')
                quietly by id: gen double __cumul_days_`suffix' = sum(__period_days_`suffix')

                * Cumulative at period start
                quietly by id: gen double __cumul_start_days_`suffix' = __cumul_days_`suffix' - __period_days_`suffix'

                * Assign duration category based on cumulative exposure days at period start
                * Compare in integer days to avoid floating-point precision issues
                quietly gen `stub_name'`suffix' = `reference'
                if `n_cuts' > 0 {
                    local first_cut = `1'
                    local first_thresh_days = round(`first_cut' * `unit_divisor')
                    quietly replace `stub_name'`suffix' = 1 if __orig_exp_category == `exp_type_val' & ///
                        __cumul_start_days_`suffix' < `first_thresh_days' & __cumul_start_days_`suffix' >= 0

                    local i = 2
                    while `i' <= `n_cuts' {
                        local prev_cut = ``=`i'-1''
                        local curr_cut = ``i''
                        local prev_thresh_days = round(`prev_cut' * `unit_divisor')
                        local curr_thresh_days = round(`curr_cut' * `unit_divisor')
                        quietly replace `stub_name'`suffix' = `i' if __orig_exp_category == `exp_type_val' & ///
                            __cumul_start_days_`suffix' >= `prev_thresh_days' & __cumul_start_days_`suffix' < `curr_thresh_days'
                        local i = `i' + 1
                    }

                    local last_cut = ``n_cuts''
                    local last_thresh_days = round(`last_cut' * `unit_divisor')
                    quietly replace `stub_name'`suffix' = `n_cuts' + 1 if __orig_exp_category == `exp_type_val' & ///
                        __cumul_start_days_`suffix' >= `last_thresh_days'
                }
                else {
                    quietly replace `stub_name'`suffix' = 1 if __orig_exp_category == `exp_type_val' & ///
                        __cumul_start_days_`suffix' >= 0
                }

                * Carry forward duration to all periods after first exposure (cumulative exposure)
                local changes = 1
                while `changes' > 0 {
                    quietly bysort id (exp_start exp_stop): replace `stub_name'`suffix' = `stub_name'`suffix'[_n-1] if _n > 1 & ///
                        `stub_name'`suffix' == `reference' & `stub_name'`suffix'[_n-1] != `reference' & ///
                        _n > __first_exp_any
                    quietly count if `stub_name'`suffix' == `reference' & _n > 1 & _n > __first_exp_any
                    local remaining = r(N)
                    if `remaining' > 0 {
                        quietly bysort id (exp_start exp_stop): gen double __can_carry = (_n > 1 & `stub_name'`suffix' == `reference' & `stub_name'`suffix'[_n-1] != `reference' & _n > __first_exp_any)
                        quietly count if __can_carry == 1
                        local changes = r(N)
                        quietly drop __can_carry
                    }
                    else {
                        local changes = 0
                    }
                }

                * Enforce monotonicity within all periods after first exposure (cumulative exposure never decreases)
                quietly bysort id (exp_start exp_stop): replace `stub_name'`suffix' = max(`stub_name'`suffix', `stub_name'`suffix'[_n-1]) if _n > 1 & _n > __first_exp_any

                * Create value labels
                local vallab ""
                if "`exp_value_label'" != "" {
                    local vallab : label `exp_value_label' `exp_type_val'
                }
                if "`vallab'" == "" local vallab "`exp_type_val'"

                label define `stub_name'labels_`suffix' `reference' "`referencelabel'", replace
                if `n_cuts' > 0 {
                    local first_cut = `1'
                    local first_cut_str = string(`first_cut', "%9.0f")
                    local first_cut_str = trim("`first_cut_str'")
                    label define `stub_name'labels_`suffix' 1 "<`first_cut_str' `unit_name'", add
                    local i = 2
                    while `i' <= `n_cuts' {
                        local prev_cut = ``=`i'-1''
                        local curr_cut = ``i''
                        local prev_cut_str = string(`prev_cut', "%9.0f")
                        local curr_cut_str = string(`curr_cut', "%9.0f")
                        local prev_cut_str = trim("`prev_cut_str'")
                        local curr_cut_str = trim("`curr_cut_str'")
                        label define `stub_name'labels_`suffix' `i' "`prev_cut_str'-<`curr_cut_str' `unit_name'", add
                        local i = `i' + 1
                    }
                    local last_cut = ``n_cuts''
                    local last_cut_str = string(`last_cut', "%9.0f")
                    local last_cut_str = trim("`last_cut_str'")
                    label define `stub_name'labels_`suffix' `=`n_cuts'+1' "`last_cut_str'+ `unit_name'", add
                }
                else {
                    label define `stub_name'labels_`suffix' 1 "Exposed", add
                }

                label values `stub_name'`suffix' `stub_name'labels_`suffix'
                if "`label'" != "" {
                    label var `stub_name'`suffix' "`label' (`vallab')"
                }
                else {
                    label var `stub_name'`suffix' "`vallab' exposure duration"
                }

                * Clean up temporary variables for this type
                quietly drop __period_days_`suffix' __cumul_days_`suffix' __cumul_start_days_`suffix'
            }

            * Clear numbered macros
            if `n_cuts' > 0 {
                forvalues i = 1/`n_cuts' {
                    macro drop _`i'
                }
            }

            * Clean up carry-forward helper variable
            quietly drop __first_exp_any

            * Collapse consecutive periods with identical duration categories
            sort id exp_start exp_stop exp_value
            quietly by id : gen double __same_durs = 1 if _n == 1
            quietly by id : replace __same_durs = 1 if _n > 1
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                quietly by id : replace __same_durs = 0 if _n > 1 & `stub_name'`suffix' != `stub_name'`suffix'[_n-1]
            }
            quietly by id : gen double __is_sequential = (exp_start == exp_stop[_n-1] + 1) if _n > 1 & id == id[_n-1]
            quietly replace __is_sequential = 1 if missing(__is_sequential)
            quietly by id: gen double __period_start = 1 if _n == 1
            quietly by id : replace __period_start = 1 if (__same_durs == 0 | __is_sequential == 0) & _n > 1
            quietly by id: gen double __period_id = sum(__period_start)

            * Build collapse command with all duration variables
            local dur_vars ""
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                local dur_vars "`dur_vars' `stub_name'`suffix'"
            }

            * Store variable labels before collapse
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                local varlab_`suffix' : variable label `stub_name'`suffix'
            }

            if "`keepvars'" != "" {
                    collapse (min) exp_start (max) exp_stop (first) exp_value `dur_vars' `keepvars' study_entry study_exit, by(id __period_id)
                }
            else {
                    collapse (min) exp_start (max) exp_stop (first) exp_value `dur_vars' study_entry study_exit, by(id __period_id)
                }
            drop __period_id

            * Reapply value labels after collapse
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                label values `stub_name'`suffix' `stub_name'labels_`suffix'
                label variable `stub_name'`suffix' "`varlab_`suffix''"
            }

            * Keep original categorical exposure in exp_value AND the duration_<type> variables
            capture quietly drop __orig_exp_binary __exp_now_dur
            local _orig_drop_rc = _rc
            capture quietly rename __orig_exp_value exp_value
            local _orig_rename_rc = _rc
        }

        else {
            * Non-bytype duration: NEW APPROACH with threshold date calculation
            * This eliminates floating-point errors and 1-day gaps

            * Step 1: Calculate cumulative exposure and identify threshold crossing dates
            sort id exp_start
            quietly generate double period_days = exp_stop - exp_start + 1 if __exp_now_dur
            quietly replace period_days = 0 if missing(period_days)
            quietly by id : gen cumul_days_end = sum(period_days)
            quietly by id : gen cumul_days_start = cumul_days_end[_n-1] if _n > 1 & id == id[_n-1]
            quietly replace cumul_days_start = 0 if missing(cumul_days_start)
            
            * Step 2: Calculate exact threshold crossing dates
            tempfile threshold_dates
            if `n_cuts' > 0 {
                preserve
                
                * For each threshold, find exact crossing date
                forvalues i = 1/`n_cuts' {
                    local thresh_units = ``i''
                    local thresh_days = round(`thresh_units' * `unit_divisor')

                    * Calculate threshold crossing date
                    quietly by id: gen double __thresh_date_`i' = ///
                        exp_start + (`thresh_days' - cumul_days_start) ///
                        if __exp_now_dur & cumul_days_start < `thresh_days' & cumul_days_end >= `thresh_days'
                    
                    * Ensure threshold date is within period bounds
                    quietly replace __thresh_date_`i' = . if __thresh_date_`i' > exp_stop | __thresh_date_`i' < exp_start
                    
                    * Collapse to one value per person using egen max
                    quietly by id: egen double __max_thresh_`i' = max(__thresh_date_`i')
                    quietly drop __thresh_date_`i'
                    quietly rename __max_thresh_`i' __thresh_date_`i'
                }
                
                * Keep wide format - one row per ID with all threshold dates
                quietly keep id __thresh_date_*
                quietly duplicates drop id, force
                
                quietly save `threshold_dates', replace
                restore
            }
            else {
                * No thresholds - create empty dataset
                preserve
                clear
                quietly gen double id = .
                if `n_cuts' > 0 {
                    forvalues i = 1/`n_cuts' {
                        quietly gen double __thresh_date_`i' = .
                    }
                }
                quietly drop if !missing(id)
                quietly save `threshold_dates', replace
                restore
            }
            
            * Step 3: Split all periods at threshold dates
            if `n_cuts' > 0 {
                
                * Merge threshold dates (m:1 - many exposure periods to one threshold row per ID)
                quietly merge m:1 id using `threshold_dates', keep(master match) nogenerate
                
                * Identify periods that need splitting by checking each threshold variable
                quietly gen double __needs_split = 0
                forvalues i = 1/`n_cuts' {
                    quietly replace __needs_split = 1 if !missing(__thresh_date_`i') & ///
                        __thresh_date_`i' > exp_start & __thresh_date_`i' <= exp_stop
                }
                
                quietly count if __needs_split == 1
                local n_to_split = r(N)
                
                if `n_to_split' > 0 {
                    tempfile split_candidates
                    quietly save `split_candidates', replace
                    
                    * Process periods that need splitting
                    quietly keep if __needs_split == 1
                    
                    * Create unique observation ID before reshaping
                    quietly gen double __obs_id = _n
                    
                    * Reshape long to get all thresholds in one column
                    quietly reshape long __thresh_date_, i(__obs_id) j(__thresh_num)
                    quietly rename __thresh_date_ split_date
                    
                    * Keep only valid split dates within period bounds
                    quietly keep if !missing(split_date) & split_date > exp_start & split_date <= exp_stop
                    
                    * Sort thresholds within each observation
                    quietly sort __obs_id split_date
                    
                    * Add boundary dates (start and stop) to create complete segment list
                    * For each observation, we need: exp_start, threshold1, threshold2, ..., exp_stop
                    * Segments are: [exp_start, thresh1-1], [thresh1, thresh2-1], ..., [last_thresh, exp_stop]
                    
                    * Count splits per observation
                    quietly by __obs_id: gen double __n_splits = _N
                    quietly by __obs_id: gen double __split_seq = _n
                    
                    * Create segments between consecutive thresholds
                    * Segment n goes from threshold[n] to threshold[n+1]-1
                    * First segment starts at exp_start, last segment ends at exp_stop
                    
                    quietly gen double __seg_start = exp_start
                    quietly gen double __seg_stop = exp_stop
                    
                    * First segment: exp_start to first_threshold-1
                    quietly by __obs_id: replace __seg_start = exp_start if __split_seq == 1
                    quietly by __obs_id: replace __seg_stop = floor(split_date) - 1 if __split_seq == 1
                    
                    * Middle segments: threshold[n-1] to threshold[n]-1
                    quietly by __obs_id: replace __seg_start = floor(split_date[_n-1]) if __split_seq > 1 & __split_seq <= __n_splits
                    quietly by __obs_id: replace __seg_stop = floor(split_date) - 1 if __split_seq > 1 & __split_seq <= __n_splits
                    
                    * Add final segment: last_threshold to exp_stop
                    quietly expand 2 if __split_seq == __n_splits, generate(__is_final)
                    quietly sort __obs_id __split_seq __is_final
                    quietly by __obs_id: replace __split_seq = __n_splits + 1 if __is_final == 1
                    quietly replace __seg_start = floor(split_date) if __is_final == 1
                    quietly by __obs_id: replace __seg_stop = exp_stop[1] if __is_final == 1
                    
                    * Replace exp_start and exp_stop with segment boundaries
                    quietly drop exp_start exp_stop split_date
                    quietly rename (__seg_start __seg_stop) (exp_start exp_stop)
                    
                    * Clean up
                    quietly drop __obs_id __thresh_num __n_splits __split_seq __is_final __needs_split
                    * Reversed bounds are malformed; negative Stata dates (pre-01jan1960)
                    * are legitimate, so do NOT drop on exp_start<0/exp_stop<0 (F06).
                    quietly drop if exp_start > exp_stop
                    
                    tempfile split_periods
                    quietly save `split_periods', replace
                    
                    * Combine with non-split periods
                    quietly use `split_candidates', clear
                    quietly drop if __needs_split == 1
                    quietly drop __needs_split
                    forvalues i = 1/`n_cuts' {
                        capture quietly drop __thresh_date_`i'
                        local _thresh_drop_rc = _rc
                    }
                    quietly append using `split_periods'
                    sort id exp_start
                }
                else {
                    quietly drop __needs_split
                    forvalues i = 1/`n_cuts' {
                        capture quietly drop __thresh_date_`i'
                        local _thresh_drop_rc = _rc
                    }
                }
            }
            
            * Step 4: Recalculate cumulative exposure and assign duration categories

            drop period_days cumul_days_start cumul_days_end

            * Recalculate cumulative exposure after splitting
            sort id exp_start
            quietly generate double period_days = exp_stop - exp_start + 1 if __exp_now_dur
            quietly replace period_days = 0 if missing(period_days)
            quietly by id : gen cumul_days_end = sum(period_days)
            quietly by id : gen cumul_days_start = cumul_days_end[_n-1] if _n > 1 & id == id[_n-1]
            quietly replace cumul_days_start = 0 if missing(cumul_days_start)

            * Assign duration categories based on cumulative days at period start
            quietly gen exp_duration = `reference'
            if `n_cuts' > 0 {
                local first_cut = `1'
                local first_thresh_days = round(`first_cut' * `unit_divisor')
                quietly replace exp_duration = 1 if __exp_now_dur & cumul_days_start < `first_thresh_days' & cumul_days_start >= 0

                local i = 2
                while `i' <= `n_cuts' {
                    local prev_cut = ``=`i'-1''
                    local curr_cut = ``i''
                    local prev_thresh_days = round(`prev_cut' * `unit_divisor')
                    local curr_thresh_days = round(`curr_cut' * `unit_divisor')
                    quietly replace exp_duration = `i' if __exp_now_dur & ///
                        cumul_days_start >= `prev_thresh_days' & cumul_days_start < `curr_thresh_days'
                    local i = `i' + 1
                }

                local last_cut = ``n_cuts''
                local last_thresh_days = round(`last_cut' * `unit_divisor')
                quietly replace exp_duration = `n_cuts' + 1 if __exp_now_dur & cumul_days_start >= `last_thresh_days'
            }
            else {
                quietly replace exp_duration = 1 if __exp_now_dur
            }
            
            * Carry forward duration to unexposed periods after first exposure
            sort id exp_start exp_stop
            quietly bysort id (exp_start): egen double __first_exp = min(cond(__exp_now_dur == 1, _n, .))
            
            local changes = 1
            while `changes' > 0 {
                quietly bysort id (exp_start): replace exp_duration = exp_duration[_n-1] if _n > 1 & ///
                    exp_duration == `reference' & exp_duration[_n-1] != `reference' & _n > __first_exp
                quietly count if exp_duration == `reference' & _n > 1 & _n > __first_exp
                local remaining = r(N)
                if `remaining' > 0 {
                    quietly bysort id (exp_start): gen double __can_carry = (_n > 1 & exp_duration == `reference' & exp_duration[_n-1] != `reference' & _n > __first_exp)
                    quietly count if __can_carry == 1
                    local changes = r(N)
                    quietly drop __can_carry
                }
                else {
                    local changes = 0
                }
            }
            
            * Enforce monotonicity
            quietly bysort id (exp_start): replace exp_duration = max(exp_duration, exp_duration[_n-1]) if _n > 1 & _n > __first_exp
            
            quietly drop __first_exp
            
            * Create value labels
            * (collision-safe name so a caller's same-named label is never clobbered)
            _tvtools_new_vallabel, base(dur_labels)
            local _dur_lbl "`r(name)'"
            label define `_dur_lbl' `reference' "`referencelabel'"
            if `n_cuts' > 0 {
                local first_cut = `1'
                local first_cut_str = string(`first_cut', "%9.0f")
                local first_cut_str = trim("`first_cut_str'")
                label define `_dur_lbl' 1 "<`first_cut_str' `unit_name'", add
                local i = 2
                while `i' <= `n_cuts' {
                    local prev_cut = ``=`i'-1''
                    local curr_cut = ``i''
                    local prev_cut_str = string(`prev_cut', "%9.0f")
                    local curr_cut_str = string(`curr_cut', "%9.0f")
                    local prev_cut_str = trim("`prev_cut_str'")
                    local curr_cut_str = trim("`curr_cut_str'")
                    label define `_dur_lbl' `i' "`prev_cut_str'-<`curr_cut_str' `unit_name'", add
                    local i = `i' + 1
                }
                local last_cut = ``n_cuts''
                local last_cut_str = string(`last_cut', "%9.0f")
                local last_cut_str = trim("`last_cut_str'")
                label define `_dur_lbl' `=`n_cuts'+1' "`last_cut_str'+ `unit_name'", add
            }
            else {
                label define `_dur_lbl' 1 "Exposed", add
            }
            
            * Clear numbered macros
            if `n_cuts' > 0 {
                forvalues i = 1/`n_cuts' {
                    macro drop _`i'
                }
            }
            
            * Replace exposure variable with duration category
            drop exp_value __orig_exp_binary period_days cumul_days_start cumul_days_end
            rename exp_duration exp_value
            label values exp_value `_dur_lbl'
            
            * Collapse consecutive identical periods
            sort id exp_start exp_stop exp_value
            quietly by id : gen double __same_dur = (exp_value == exp_value[_n-1]) if _n > 1 & id == id[_n-1]
            quietly replace __same_dur = 0 if missing(__same_dur)
            quietly by id : gen double __is_sequential = (exp_start == exp_stop[_n-1] + 1) if _n > 1 & id == id[_n-1]
            quietly replace __is_sequential = 1 if missing(__is_sequential)
            quietly bysort id (exp_start): gen double __period_start = 1 if _n == 1
            quietly by id : replace __period_start = 1 if (__same_dur == 0 | __is_sequential == 0) & _n > 1
            quietly bysort id (exp_start): gen double __period_id = sum(__period_start)
            
            if "`keepvars'" != "" {
                collapse (min) exp_start (max) exp_stop (first) exp_value `keepvars' study_entry study_exit, by(id __period_id)
            }
            else {
                collapse (min) exp_start (max) exp_stop (first) exp_value study_entry study_exit, by(id __period_id)
            }
            drop __period_id
            label values exp_value `_dur_lbl'
        }
    }

    **# Dose Exposure Type
    * Research question: Is there dose-response relationship?
    * Output: Cumulative dose (continuous or categorized by cutpoints)
    * Time-varying: Increases with each dose period
    * Note: Overlap handling with proportional allocation is done earlier in the code
    else if "`exp_type'" == "dose" {
        noisily display as text "Calculating cumulative dose..."

        sort id exp_start

        * exp_value contains the amount attributed to the current segment.
        * Store cumulative dose at row start, not after the current segment.
        quietly by id: gen double __cumul_dose_end = sum(exp_value)
        quietly gen double __cumul_dose = __cumul_dose_end - exp_value

        if "`dose_cuts'" != "" {
            * Categorized dose output based on cutpoints
            local n_cuts : word count `dose_cuts'
            tokenize `dose_cuts'

            * Create dose category variable
            * Category 0: 0 cumulative dose (reference)
            * Category 1: >0 but < first cutpoint
            * Category 2..n: between cutpoints
            * Category n+1: >= last cutpoint
            quietly gen double exp_dose_cat = 0  // Reference: 0 cumulative dose

            * Category 1: >0 but < first cutpoint
            quietly replace exp_dose_cat = 1 if __cumul_dose > 0 & __cumul_dose < `1'

            * Middle categories
            local cat = 2
            forvalues i = 2/`n_cuts' {
                local prev = ``=`i'-1''
                local curr = ``i''
                quietly replace exp_dose_cat = `cat' if __cumul_dose >= `prev' & __cumul_dose < `curr'
                local cat = `cat' + 1
            }

            * Final category: >= last cutpoint
            quietly replace exp_dose_cat = `n_cuts' + 1 if __cumul_dose >= ``n_cuts''

            * Create value labels
            * (collision-safe name so a caller's same-named label is never clobbered)
            _tvtools_new_vallabel, base(dose_labels)
            local _dose_lbl "`r(name)'"
            label define `_dose_lbl' 0 "No dose"
            label define `_dose_lbl' 1 "<`1'", add

            local cat = 2
            forvalues i = 2/`n_cuts' {
                local prev = ``=`i'-1''
                local curr = ``i''
                label define `_dose_lbl' `cat' "`prev'-<`curr'", add
                local cat = `cat' + 1
            }
            label define `_dose_lbl' `=`n_cuts'+1' "``n_cuts''+", add

            * Replace exp_value with category
            drop exp_value
            rename exp_dose_cat exp_value
            label values exp_value `_dose_lbl'

            * Clean up tokenize macros
            forvalues i = 1/`n_cuts' {
                macro drop _`i'
            }

            noisily display as text "  Created `=`n_cuts'+2' dose categories."
        }
        else {
            * Continuous dose output
            drop exp_value
            rename __cumul_dose exp_value
            label variable exp_value "Cumulative dose"

            noisily display as text "  Created continuous cumulative dose variable."
        }

        * Collapse consecutive periods with same dose/category
        * For categorized dose, use exact comparison
        * For continuous dose, use tolerance-based comparison to handle floating point precision
        sort id exp_start
        if "`dose_cuts'" != "" {
            quietly by id: gen double __same_dose = (exp_value == exp_value[_n-1]) if _n > 1 & id == id[_n-1]
        }
        else {
            * Use relative tolerance of 1e-9 for floating point comparison
            quietly by id: gen double __same_dose = (reldif(exp_value, exp_value[_n-1]) < 1e-9) if _n > 1 & id == id[_n-1]
        }
        quietly replace __same_dose = 0 if missing(__same_dose)
        quietly by id: gen double __period_start = 1 if _n == 1
        quietly by id: replace __period_start = 1 if __same_dose == 0 & _n > 1
        quietly by id: gen double __period_id = sum(__period_start)

        if "`keepvars'" != "" {
            collapse (min) exp_start (max) exp_stop (first) exp_value `keepvars' study_entry study_exit, by(id __period_id)
        }
        else {
            collapse (min) exp_start (max) exp_stop (first) exp_value study_entry study_exit, by(id __period_id)
        }
        drop __period_id

        * Reapply value labels for categorized dose
        if "`dose_cuts'" != "" {
            label values exp_value `_dose_lbl'
        }

        * Clean up
        capture drop __cumul_dose __cumul_dose_end __same_dose __period_start
    }

    **# Recency (Time Since Last Exposure) Type
    * Research question: Is residual protection/risk dependent on recency?
    * Output: Categorical variable representing time since last exposure
    * Example: recency(30 90) creates current, <30d, 30-<90d, and 90+d
    * Time-varying: Person moves through recency categories after exposure ends
    * The final category is open ended; formerly exposed time never becomes never
    else if "`exp_type'" == "recency" {
        local n_cuts : word count `recency_cutdays'

        * Materialize every threshold crossing. This expands by cutpoints, not
        * by person-days, so long follow-up does not create a daily data blowup.
        if "`bytype'" != "" {
            preserve
            quietly use `all_person_exp_types', clear
            quietly levelsof __all_exp_types, local(exp_types)
            restore
        }

        sort id exp_start exp_stop
        quietly generate long __rec_row = _n
        local rec_last_vars ""
        if "`bytype'" != "" {
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                quietly generate double __rec_last_`suffix' = exp_stop ///
                    if __orig_exp_category == `exp_type_val'
                quietly by id (exp_start exp_stop): replace __rec_last_`suffix' = ///
                    __rec_last_`suffix'[_n-1] if _n > 1 & missing(__rec_last_`suffix')
                local rec_last_vars "`rec_last_vars' __rec_last_`suffix'"
            }
        }
        else {
            quietly generate double __rec_last = exp_stop if __orig_exp_binary == 1
            quietly by id (exp_start exp_stop): replace __rec_last = ///
                __rec_last[_n-1] if _n > 1 & missing(__rec_last)
            local rec_last_vars "__rec_last"
        }

        tempfile recency_base recency_boundaries
        quietly save `recency_base', replace
        preserve
        quietly keep if 0
        quietly save `recency_boundaries', replace
        restore

        forvalues rec_i = 1/`n_cuts' {
            local rec_days = `recency_cutday`rec_i''
            if "`bytype'" != "" {
                foreach exp_type_val of local exp_types {
                    local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                    local suffix = subinstr("`suffix'", ".", "p", .)
                    quietly use `recency_base', clear
                    quietly generate double __rec_boundary = __rec_last_`suffix' + `rec_days'
                    quietly keep if __orig_exp_category != `exp_type_val' & ///
                        !missing(__rec_last_`suffix') & ///
                        __rec_boundary > exp_start & __rec_boundary <= exp_stop
                    quietly replace exp_start = __rec_boundary
                    quietly drop __rec_boundary
                    quietly append using `recency_boundaries'
                    quietly save `recency_boundaries', replace
                }
            }
            else {
                quietly use `recency_base', clear
                quietly generate double __rec_boundary = __rec_last + `rec_days'
                quietly keep if __orig_exp_binary == 0 & !missing(__rec_last) & ///
                    __rec_boundary > exp_start & __rec_boundary <= exp_stop
                quietly replace exp_start = __rec_boundary
                quietly drop __rec_boundary
                quietly append using `recency_boundaries'
                quietly save `recency_boundaries', replace
            }
        }

        quietly use `recency_base', clear
        quietly append using `recency_boundaries'
        sort __rec_row exp_start
        quietly duplicates drop __rec_row exp_start, force
        quietly by __rec_row (exp_start): replace exp_stop = exp_start[_n+1] - 1 ///
            if _n < _N
        drop __rec_row `rec_last_vars'
        sort id exp_start exp_stop

        if "`bytype'" != "" {
            * Create separate recency variables for each exposure type
            * FIXED: Use all exposure types saved BEFORE overlap resolution
            
            * Get complete list of exposure types from saved pre-overlap data
            preserve
            quietly use `all_person_exp_types', clear
            quietly levelsof __all_exp_types, local(exp_types)
            restore
            
            * Parse the already validated whole-day boundaries once
            tokenize `recency_cutdays'
            local last_cut = ``n_cuts''
            
            foreach exp_type_val of local exp_types {
                * Sanitize suffix for variable names (handles negative/decimal values)
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)

                sort id exp_start
                quietly gen double __exp_now_`suffix' = (__orig_exp_category == `exp_type_val')
                quietly gen double __last_exp_end_`suffix' = exp_stop if __exp_now_`suffix'

                * Carry forward last exposure end date
                quietly bysort id (exp_start): gen double __last_carried_`suffix' = __last_exp_end_`suffix'[1] if _n == 1
                quietly bysort id (exp_start): replace __last_carried_`suffix' = __last_exp_end_`suffix' if __exp_now_`suffix' & _n > 1
                quietly bysort id (exp_start): replace __last_carried_`suffix' = __last_carried_`suffix'[_n-1] ///
                    if !__exp_now_`suffix' & _n > 1 & !missing(__last_carried_`suffix'[_n-1]) & id == id[_n-1]

                * Calculate days since last exposure to this type
                quietly gen double __days_since_`suffix' = exp_start - __last_carried_`suffix' ///
                    if !__exp_now_`suffix' & !missing(__last_carried_`suffix')

                * Create recency categories
                quietly gen `stub_name'`suffix' = `reference'
                quietly replace `stub_name'`suffix' = 1 if __exp_now_`suffix' == 1

                if `n_cuts' > 0 {
                    local cat = 2
                    if "`1'" != "" {
                        quietly replace `stub_name'`suffix' = `cat' if __days_since_`suffix' >= 0 & ///
                            __days_since_`suffix' < `1' & !__exp_now_`suffix' & !missing(__days_since_`suffix')
                        local cat = `cat' + 1
                    }

                    local i = 2
                    while `i' <= `n_cuts' {
                        local prev = ``=`i'-1''
                        local curr = ``i''
                        quietly replace `stub_name'`suffix' = `cat' if __days_since_`suffix' >= `prev' & ///
                            __days_since_`suffix' < `curr' & !__exp_now_`suffix' & !missing(__days_since_`suffix')
                        local cat = `cat' + 1
                        local i = `i' + 1
                    }

                    quietly replace `stub_name'`suffix' = `cat' if __days_since_`suffix' >= `last_cut' & ///
                        !__exp_now_`suffix' & !missing(__days_since_`suffix')
                }

                * Get label from original exposure variable for this type
                local vallab ""
                if "`exp_value_label'" != "" {
                    local vallab : label `exp_value_label' `exp_type_val'
                }
                if "`vallab'" == "" local vallab "`exp_type_val'"
                if "`label'" != "" {
                    label var `stub_name'`suffix' "`label' (`vallab')"
                }
                else {
                    label var `stub_name'`suffix' "Recency category: `vallab'"
                }

                * Define and apply value labels for recency categories
                label define `stub_name'labels_`suffix' `reference' "Never `vallab'", replace
                label define `stub_name'labels_`suffix' 1 "Current `vallab'", add
                if `n_cuts' > 0 {
                    local cat = 2
                    if "`1'" != "" {
                        label define `stub_name'labels_`suffix' `cat' "<`1'd since `vallab'", add
                        local cat = `cat' + 1
                    }
                    local i = 2
                    while `i' <= `n_cuts' {
                        local prev = ``=`i'-1''
                        local curr = ``i''
                        label define `stub_name'labels_`suffix' `cat' "`prev'-<`curr'd since `vallab'", add
                        local cat = `cat' + 1
                        local i = `i' + 1
                    }
                    label define `stub_name'labels_`suffix' `cat' "`last_cut'+ d since `vallab'", add
                }
                label values `stub_name'`suffix' `stub_name'labels_`suffix'

                drop __exp_now_`suffix' __last_exp_end_`suffix' __last_carried_`suffix' __days_since_`suffix'
            }
            * Clear numbered macros from tokenize
            if `n_cuts' > 0 {
                forvalues i = 1/`n_cuts' {
                    macro drop _`i'
                }
            }

            * Collapse consecutive periods with identical recency_X values
            * Must also check exp_value to distinguish exposed from unexposed periods
            sort id exp_start
            quietly by id : gen double __same_recencies = 1 if _n == 1
            quietly by id : replace __same_recencies = 1 if _n > 1
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                quietly by id : replace __same_recencies = 0 if _n > 1 & `stub_name'`suffix' != `stub_name'`suffix'[_n-1]
            }
            * Also check if exposure category changed (prevents merging exposed and unexposed periods)
            quietly by id : replace __same_recencies = 0 if _n > 1 & exp_value != exp_value[_n-1]
            quietly by id: gen double __period_start = 1 if _n == 1
            quietly by id : replace __period_start = 1 if __same_recencies == 0 & _n > 1
            quietly by id: gen double __period_id = sum(__period_start)

            * Build collapse command with all recency variables
            local rec_vars ""
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                local rec_vars "`rec_vars' `stub_name'`suffix'"
            }

            * Store variable labels before collapse
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                local varlab_`suffix' : variable label `stub_name'`suffix'
            }

            if "`keepvars'" != "" {
                    collapse (min) exp_start (max) exp_stop (first) exp_value `rec_vars' `keepvars' study_entry study_exit, by(id __period_id)
            }
            else {
                    collapse (min) exp_start (max) exp_stop (first) exp_value `rec_vars' study_entry study_exit, by(id __period_id)
            }
            drop __period_id

            * Reapply value labels after collapse
            foreach exp_type_val of local exp_types {
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                label values `stub_name'`suffix' `stub_name'labels_`suffix'
                label variable `stub_name'`suffix' "`varlab_`suffix''"
            }

            * Keep original categorical exposure in exp_value
        }
        else {
            * Calculate time since last exposure with proper carry-forward
            sort id exp_start
            quietly gen double __exp_now_rec = __orig_exp_binary
            
            * Record the end date of each exposure period
            quietly gen double __last_exp_end = exp_stop if __exp_now_rec
            
            * Carry forward the last exposure end date through unexposed periods
            quietly bysort id (exp_start): gen double __last_exp_carried = __last_exp_end[1] if _n == 1
            quietly bysort id (exp_start): replace __last_exp_carried = __last_exp_end if __exp_now_rec & _n > 1
            quietly bysort id (exp_start): replace __last_exp_carried = __last_exp_carried[_n-1] ///
                if !__exp_now_rec & _n > 1 & !missing(__last_exp_carried[_n-1]) & id == id[_n-1]
            
            * Calculate days since last exposure (only in unexposed periods)
            quietly gen double __days_since = exp_start - __last_exp_carried ///
                if !__exp_now_rec & !missing(__last_exp_carried)
            
            * Create recency categories from validated whole-day boundaries.
            local n_cuts : word count `recency_cutdays'
            tokenize `recency_cutdays'
            local last_cut = ``n_cuts''
            
            quietly gen exp_recency = `reference'
            
            * Category 1: Currently exposed
            quietly replace exp_recency = 1 if __exp_now_rec == 1
            
            * Subsequent categories: Time since exposure bands
            if `n_cuts' > 0 {
                tokenize `recency_cutdays'
                local cat = 2
                
                if "`1'" != "" {
                    quietly replace exp_recency = `cat' if __days_since >= 0 & ///
                        __days_since < `1' & !__exp_now_rec & !missing(__days_since)
                    local cat = `cat' + 1
                }
                
                local i = 2
                while `i' <= `n_cuts' {
                    local prev = ``=`i'-1''
                    local curr = ``i''
                    quietly replace exp_recency = `cat' if __days_since >= `prev' & ///
                        __days_since < `curr' & !__exp_now_rec & !missing(__days_since)
                    local cat = `cat' + 1
                    local i = `i' + 1
                }
                
                quietly replace exp_recency = `cat' if __days_since >= `last_cut' & ///
                    !__exp_now_rec & !missing(__days_since)
            }
            
            * Define and apply value labels for recency categories
            * (collision-safe name so a caller's same-named label is never clobbered)
            _tvtools_new_vallabel, base(rec_labels)
            local _rec_lbl "`r(name)'"
            label define `_rec_lbl' `reference' "Never exposed"
            label define `_rec_lbl' 1 "Currently exposed", add
            if `n_cuts' > 0 {
                tokenize `recency_cutdays'
                local cat = 2
                if "`1'" != "" {
                    label define `_rec_lbl' `cat' "<`1' days since exposure", add
                    local cat = `cat' + 1
                }
                local i = 2
                while `i' <= `n_cuts' {
                    local prev = ``=`i'-1''
                    local curr = ``i''
                    label define `_rec_lbl' `cat' "`prev'-<`curr' days since exposure", add
                    local cat = `cat' + 1
                    local i = `i' + 1
                }
                label define `_rec_lbl' `cat' "`last_cut'+ days since exposure", add
            }

            * Replace exposure variable with recency category
            drop exp_value __orig_exp_binary __exp_now_rec __last_exp_end __last_exp_carried __days_since
            rename exp_recency exp_value
            label values exp_value `_rec_lbl'
            
            * Clear numbered macros from tokenize
            if `n_cuts' > 0 {
                forvalues i = 1/`n_cuts' {
                    macro drop _`i'
                }
            }
            
            * Collapse consecutive identical periods
            sort id exp_start
            quietly by id : gen double __same_rec = (exp_value == exp_value[_n-1]) if _n > 1 & id == id[_n-1]
            quietly replace __same_rec = 0 if missing(__same_rec)
            quietly by id: gen double __period_start = 1 if _n == 1
            quietly by id: replace __period_start = 1 if __same_rec == 0 & _n > 1
            quietly by id: gen double __period_id = sum(__period_start)
            
            if "`keepvars'" != "" {
                    collapse (min) exp_start (max) exp_stop (first) exp_value `keepvars' study_entry study_exit, by(id __period_id)
                }
            else {
                    collapse (min) exp_start (max) exp_stop (first) exp_value study_entry study_exit, by(id __period_id)
                }
            drop __period_id

            * Reapply value labels after collapse (collapse drops value labels).
            label values exp_value `_rec_lbl'
        }
    }


    **# Time-Varying (Keep Original Categories)
    * Default: no transformation; keeps original exposure categories
    * Allows analysis of multiple exposure types simultaneously
    else {
        * For standard time-varying, keep original exposure categories
            drop __orig_exp_binary
            drop __orig_exp_category
    }
    
    * Handle additional exposure features
    * These options create supplementary variables tracking exposure patterns
    
    if "`switching'" != "" {
        * Create binary indicator for any exposure switching
        * Identifies persons who ever changed exposure category
        sort id exp_start
        quietly by id: gen double __switched = (exp_value != exp_value[_n-1]) if _n > 1 & id == id[_n-1]
        quietly by id: egen double ever_switched = max(__switched)
        quietly replace ever_switched = 0 if missing(ever_switched)
        drop __switched
    }
    
    if "`switchingdetail'" != "" {
        * Create detailed switching pattern string
        * Shows sequence of exposures for each person
        * Example: "0 to 1 to 0 to 1"
        sort id exp_start
        quietly by id: gen switching_pattern = string(exp_value) if _n == 1
        quietly by id: replace switching_pattern = switching_pattern[_n-1] + " to " + ///
            string(exp_value) if _n > 1 & exp_value != exp_value[_n-1] & id == id[_n-1]
        quietly by id: replace switching_pattern = switching_pattern[_n-1] if _n > 1 & ///
            exp_value == exp_value[_n-1] & id == id[_n-1]
    }
    
    if "`statetime'" != "" {
        * Calculate cumulative time in current exposure state
        * Correct calculation using state groups with running sum
        * Measures how long person has been in current exposure state
        sort id exp_start
        quietly generate double period_days = exp_stop - exp_start + 1
        quietly by id: gen double __state_change = (exp_value != exp_value[_n-1]) if _n > 1 & id == id[_n-1]
        quietly replace __state_change = 1 if _n == 1
        quietly by id: gen double __state_group = sum(__state_change)

        * Calculate running cumulative days within each state group
        * Use gen with sum() for running cumulative, not egen which gives total
        sort id __state_group exp_start
        quietly by id __state_group: gen double cumul_state_days = sum(period_days)
        quietly gen state_time_years = cumul_state_days / 365.25

        drop period_days __state_change __state_group cumul_state_days
    }
    
    * Clean up temporary category preservation variable
    capture drop __orig_exp_category
    
    **# FINALIZATION AND OUTPUT
    
    * Time-varying format finalization
    * Final dataset preparation
    * Sort by person and time
    sort id exp_start exp_stop exp_value
    
    * Apply reference label for default time-varying exposure type
    if "`exp_type'" == "timevarying" & `skip_main_var' == 0 {
        * Get the value label name currently attached to exp_value
        local exp_vallabel : value label exp_value
        
        if "`exp_vallabel'" != "" {
            * Value label exists - add or modify the reference category
            capture label define `exp_vallabel' `reference' "`referencelabel'", modify
            if _rc != 0 {
                * modify failed, try add
                capture label define `exp_vallabel' `reference' "`referencelabel'", add
                local _ref_label_add_rc = _rc
            }
        }
        else {
            * No value label exists - create new one with reference category
            * Use dynamic label name to avoid collision with user's existing labels
            local _short_gen = substr("`generate'", 1, 25)
            local _tv_lbl_name "_tvlbl_`_short_gen'"
            quietly levelsof exp_value, local(all_vals)
            label define `_tv_lbl_name' `reference' "`referencelabel'", replace
            * Codes allocated by combine() are labelled with the composition
            * they stand for, not with the bare allocated number.
            foreach val of local all_vals {
                if `val' != `reference' {
                    local _val_is_combo = 0
                    local _val_combo_text ""
                    forvalues _ci = 1/`_combo_n' {
                        if `val' == `_combo_code`_ci'' {
                            local _val_is_combo = 1
                            local _val_combo_text `"`_combo_text`_ci''"'
                        }
                    }
                    if `_val_is_combo' ///
                        label define `_tv_lbl_name' `val' `"`_val_combo_text'"', add
                    else label define `_tv_lbl_name' `val' "`val'", add
                }
            }
            label values exp_value `_tv_lbl_name'
        }
    }
    
    * Rename variables to output names
    * When bytype is used, keep exp_value as-is and don't create the main variable
    * When bytype is NOT used, rename exp_value to the specified generate() name
    if `skip_main_var' == 0 {
        rename (exp_start exp_stop exp_value) (start stop `generate')
    }
    else {
        rename (exp_start exp_stop) (start stop)
    }

    * Quantity metadata lets downstream pipeline commands validate the algebra
    * instead of inferring it from a variable name.
    if "`exp_type'" == "continuous" {
        if `skip_main_var' == 0 {
            char `generate'[tvtools_quantity] "cumulative"
            char `generate'[tvtools_history_point] "start"
            char `generate'[tvtools_quantity_unit] "`cont_unit'"
        }
        else {
            quietly ds `stub_name'*
            foreach quantity_var of varlist `r(varlist)' {
                char `quantity_var'[tvtools_quantity] "cumulative"
                char `quantity_var'[tvtools_history_point] "start"
                char `quantity_var'[tvtools_quantity_unit] "`cont_unit'"
            }
        }
    }
    if "`exp_type'" == "dose" & "`dose_cuts'" == "" & `skip_main_var' == 0 {
        char `generate'[tvtools_quantity] "cumulative"
        char `generate'[tvtools_history_point] "start"
        char `generate'[tvtools_quantity_unit] "dose"
    }

    * Keep necessary variables for output
    if `skip_main_var' == 0 {
        local keep_list "id start stop `generate' study_entry study_exit"
    }
    else {
        * When bytype is used, temporarily keep exp_value for calculations
        * It will be dropped later before final output
        local keep_list "id start stop exp_value study_entry study_exit"
    }
    
    * Add optional variables if they exist
    capture confirm variable ever_switched
    if _rc == 0 local keep_list "`keep_list' ever_switched"
    
    capture confirm variable switching_pattern
    if _rc == 0 local keep_list "`keep_list' switching_pattern"
    
    capture confirm variable state_time_years
    if _rc == 0 local keep_list "`keep_list' state_time_years"
    
    capture confirm variable `generate'
    if _rc == 0 local keep_list "`keep_list' `generate'"
    
    capture confirm variable ps_match_quality
    if _rc == 0 local keep_list "`keep_list' ps_match_quality"
    
    * Keep combined variable if it exists
    if "`combine'" != "" {
        local keep_list "`keep_list' `combine'"
    }
    
    * Keep bytype variables if bytype option was used
    if "`bytype'" != "" {
        if "`exp_type'" == "evertreated" {
            local keep_list "`keep_list' `stub_name'*"
        }
        else if "`exp_type'" == "currentformer" {
            local keep_list "`keep_list' `stub_name'*"
        }
        else if "`exp_type'" == "duration" {
            local keep_list "`keep_list' `stub_name'*"
        }
        else if "`exp_type'" == "continuous" {
            local keep_list "`keep_list' `stub_name'*"
        }
        else if "`exp_type'" == "recency" {
            local keep_list "`keep_list' `stub_name'*"
        }
    }
    
    * Add user-specified keepvars
    if "`keepvars'" != "" {
        local keep_list "`keep_list' `keepvars'"
    }
    
    * Apply keep list
    keep `keep_list'

    * Final union-coverage invariant. It works for ordinary tiled output and
    * for split output with intentional duplicate time rows.
    sort id start stop
    tempvar _tvx_run_stop _tvx_uncovered _tvx_outside
    quietly by id (start stop): generate double `_tvx_run_stop' = stop
    quietly by id (start stop): replace `_tvx_run_stop' = ///
        max(`_tvx_run_stop', `_tvx_run_stop'[_n-1]) if _n > 1
    quietly by id (start stop): generate double `_tvx_uncovered' = ///
        max(start - study_entry, 0) if _n == 1
    quietly by id (start stop): replace `_tvx_uncovered' = ///
        max(start - `_tvx_run_stop'[_n-1] - 1, 0) if _n > 1
    quietly by id (start stop): replace `_tvx_uncovered' = ///
        `_tvx_uncovered' + max(study_exit - `_tvx_run_stop', 0) if _n == _N
    quietly summarize `_tvx_uncovered', meanonly
    local n_uncovered_days = r(sum)
    quietly generate byte `_tvx_outside' = start < study_entry | ///
        stop > study_exit | start > stop
    quietly count if `_tvx_outside'
    local n_bad_output_bounds = r(N)
    drop `_tvx_run_stop' `_tvx_uncovered' `_tvx_outside'
    if `n_uncovered_days' > 0 | `n_bad_output_bounds' > 0 {
        noisily display as error "Internal tiling invariant failed: `n_uncovered_days' uncovered day(s), `n_bad_output_bounds' invalid bound row(s)"
        noisily display as error "No output was committed."
        exit 498
    }
    
    * Calculate summary statistics for output
    quietly count
    local N_periods = r(N)
    
    * Count unique persons and exact study-window person-time. Summing output
    * row lengths would double-count intentional split rows and would conceal
    * accidental same-value overlaps in ordinary output.
    tempvar _ptag _ptime _expected_time
    quietly egen double `_ptag' = tag(id)
    quietly count if `_ptag'
    local N_persons = r(N)
    quietly generate double `_expected_time' = study_exit - study_entry + 1 ///
        if `_ptag'
    quietly summarize `_expected_time', meanonly
    local total_time = r(sum)
    
    * Ordinary output must be a true tiling. With full union coverage already
    * established, excess summed row-time is exact evidence of overlap.
    quietly gen double `_ptime' = stop - start + 1
    quietly summarize `_ptime', meanonly
    local row_time = r(sum)
    if "`split'" == "" & `row_time' != `total_time' {
        noisily display as error "Internal tiling invariant failed: output row-time is `row_time' days but the study windows contain `total_time' days"
        noisily display as error "No output was committed."
        exit 498
    }
    drop `_ptag' `_expected_time'

    * Calculate exposed person-time
    * Continuous and dose retain the source-period current-exposure meaning.
    * Other definitions use their final binary/current status.
    * When bytype is used with evertreated, check if ANY ever variable = 1
    * For other bytype cases, use exp_value for this calculation

    * Case 1: main single output variable exists (no bytype)
    if `skip_main_var' == 0 {
        if "`exp_type'" == "currentformer" {
            quietly gen double __final_binary = (`generate' == 1)
        }
        else if "`exp_type'" == "recency" {
            quietly gen double __final_binary = (`generate' == 1)
        }
        else {
            quietly gen double __final_binary = (`generate' != `reference')
        }
    }

    * Case 2: bytype run (use per-type vars with stub_name)
    else if "`bytype'" != "" {
        quietly gen double __final_binary = 0
        quietly ds `stub_name'*
        local __byvars "`r(varlist)'"

        * Fallback if bytype vars are missing
        if "`__byvars'" == "" {
            quietly drop __final_binary
            quietly gen double __final_binary = (exp_value != `reference')
        }
        else if "`exp_type'" == "evertreated" {
            foreach v of local __byvars {
                quietly replace __final_binary = 1 if `v' == 1
            }
        }
        else if "`exp_type'" == "currentformer" {
            * Count CURRENT only
            foreach v of local __byvars {
                quietly replace __final_binary = 1 if `v' == 1
            }
        }
        else if "`exp_type'" == "recency" {
            * Count CURRENT only
            foreach v of local __byvars {
                quietly replace __final_binary = 1 if `v' == 1
            }
        }
        else if inlist("`exp_type'","duration","continuous","dose") {
            * Ever-exposed for these types
            foreach v of local __byvars {
                quietly replace __final_binary = 1 if `v' > 0
            }
        }
        else {
            quietly drop __final_binary
            quietly gen double __final_binary = (exp_value != `reference')
        }
    }

    * Case 3: no bytype, no generated main var (safety)
    else {
        if inlist("`exp_type'","currentformer","recency") {
            quietly gen double __final_binary = (exp_value == 1)
        }
        else if "`exp_type'" == "dose" {
            quietly gen double __final_binary = (exp_value > 0)
        }
        else {
            quietly gen double __final_binary = (exp_value != `reference')
        }
    }

    if inlist("`exp_type'", "continuous", "dose") {
        local exposed_time = `current_exposed_time'
    }
    else {
        local exposed_time = 0
        preserve
        quietly keep if __final_binary == 1
        quietly count
        if r(N) > 0 {
            tempvar _tvx_exposed_run _tvx_exposed_add
            sort id start stop
            quietly by id (start stop): generate double `_tvx_exposed_run' = stop
            quietly by id (start stop): replace `_tvx_exposed_run' = ///
                max(`_tvx_exposed_run', `_tvx_exposed_run'[_n-1]) if _n > 1
            quietly by id (start stop): generate double `_tvx_exposed_add' = ///
                stop - start + 1 if _n == 1
            quietly by id (start stop): replace `_tvx_exposed_add' = ///
                max(stop - max(start - 1, `_tvx_exposed_run'[_n-1]), 0) ///
                if _n > 1
            quietly summarize `_tvx_exposed_add', meanonly
            local exposed_time = r(sum)
        }
        restore
    }
    
    local unexposed_time = `total_time' - `exposed_time'
    if `total_time' > 0 {
        local pct_exposed = 100 * `exposed_time' / `total_time'
    }
    else {
        local pct_exposed = 0
    }
    
    drop `_ptime' __final_binary
    
    * Drop exp_value after calculations when bytype is used
    if `skip_main_var' == 1 {
        capture drop exp_value
    }
    
    * Add variable labels
    label variable start "Period start date"
    label variable stop "Period stop date"
    if `skip_main_var' == 0 {
        if "`exp_type'" == "currentformer" & "`label'" == "" {
            label variable `generate' "Never/current/former exposure"
        }
        else if "`exp_type'" == "dose" & "`label'" == "" {
            if "`dose_cuts'" != "" {
                label variable `generate' "Cumulative dose category"
            }
            else {
                label variable `generate' "Cumulative dose"
            }
        }
        else {
            label variable `generate' "`exp_label'"
        }
    }
    * Note: When bytype is used (skip_main_var == 1), exp_value has been dropped
    * so we don't label it
    
    capture confirm variable ever_switched
    if _rc == 0 label variable ever_switched "Ever switched exposure category"
    
    capture confirm variable switching_pattern
    if _rc == 0 label variable switching_pattern "Detailed switching pattern"
    
    capture confirm variable state_time_years
    if _rc == 0 label variable state_time_years "Time in current exposure state (years)"

    * Format all date variables with CCYY/NN/DD format
    format start stop %tdCCYY/NN/DD
    capture confirm variable study_entry
    if _rc == 0 {
        capture confirm variable study_exit
        if _rc == 0 {
            format study_entry study_exit %tdCCYY/NN/DD
        }
    }
    
    * Final sort and compression
    sort id start stop
    quietly compress
   
    **# DIAGNOSTIC OPTIONS AND VALIDATION
    
    **# Coverage diagnostics (check option)
    if "`check'" != "" {
        noisily display as text "{hline 70}"
        noisily display as text "Coverage Diagnostics"
        noisily display as text "{hline 70}"
        
        tempfile _check_temp
        quietly save `_check_temp'
        * Coverage is the interval UNION clipped to the study window, never
        * the sum of row lengths. Summing rows double-counts the days that
        * split output deliberately represents more than once, which is how
        * this report came to claim 105% coverage of a window the data cover
        * exactly. Gaps come from the same engine, so the two figures can no
        * longer disagree, and nesting no longer reads as a fresh segment.
        _tvtools_interval_union, id(id) start(start) stop(stop) ///
            cliplow(study_entry) cliphigh(study_exit) ///
            uniondays(total_covered) ngaps(n_gaps)

        sort id start stop
        quietly by id: generate double expected_days = study_exit[1] - study_entry[1] + 1
        quietly generate double pct_covered = 100 * total_covered / expected_days
        quietly by id: egen double n_periods = count(id)

        * Keep one row per person for display
        quietly by id: keep if _n == 1
        
        * Display sample of results (limit to actual number of observations)
        if "`verbose'" != "" {
            noisily list id pct_covered n_periods n_gaps in 1/`=min(_N,20)', clean noobs
        }

        * Display summary statistics
        quietly sum pct_covered
        noisily display as text "{hline 70}"
        noisily display as text "Coverage Summary:"
        noisily display as text "  Mean coverage: " as result %5.1f r(mean) "%"
        noisily display as text "  Min coverage:  " as result %5.1f r(min) "%"
        noisily display as text "  Max coverage:  " as result %5.1f r(max) "%"

        quietly count if pct_covered < 100
        noisily display as text "  Persons with gaps: " as result r(N) " (" %4.1f 100*r(N)/_N "%)"
        if "`verbose'" == "" & r(N) > 0 {
            noisily display as text "  (specify verbose to list per-person details)"
        }
        noisily display as text "{hline 70}"
        
        quietly use `_check_temp', clear
    }
    
    **# Gap analysis (gaps option)
    if "`gaps'" != "" {
        noisily display as text ""
        noisily display as text "Gaps in Coverage"
        noisily display as text "{hline 60}"
        
        tempfile _gaps_temp
        quietly save `_gaps_temp'
        sort id start stop
        * A gap opens against the running maximum stop seen so far, not
        * against the immediate predecessor. With nested or split rows the
        * predecessor can end long before an earlier row does, so the old
        * rule invented gaps inside days that were in fact covered.
        quietly by id (start stop): gen double __rmax = stop if _n == 1
        quietly by id (start stop): replace __rmax = max(__rmax[_n-1], stop) if _n > 1
        quietly by id (start stop): gen double __prevmax = __rmax[_n-1] if _n > 1
        quietly gen gap_start = __prevmax + 1 if !missing(__prevmax) & start > __prevmax + 1
        quietly gen gap_end = start - 1 if !missing(gap_start)
        quietly gen gap_days = gap_end - gap_start + 1 if !missing(gap_start)

        drop __rmax __prevmax
        quietly drop if gap_days <= 0
        quietly keep if !missing(gap_start) 
        
        if _N > 0 {
            format gap_start gap_end %tdCCYY/NN/DD
            if "`verbose'" != "" {
                noisily display as text "Showing first 20 gaps:"
                noisily list id gap_start gap_end gap_days in 1/`=min(_N,20)', noobs sepby(id)
            }

            * Gap statistics
            quietly sum gap_days, detail
            noisily display as text ""
            noisily display as text "Gap Statistics:"
            noisily display as text "  Total gaps: " as result _N
            noisily display as text "  Mean gap: " as result %5.1f r(mean) " days"
            noisily display as text "  Median gap: " as result %5.0f r(p50) " days"
            noisily display as text "  Max gap: " as result %5.0f r(max) " days"
            if "`verbose'" == "" {
                noisily display as text "  (specify verbose to list affected IDs and dates)"
            }
        }
        else {
            noisily display as text "No gaps found in coverage"
        }
        quietly use `_gaps_temp', clear
    }

    **# Overlap analysis (overlaps option)
    if "`overlaps'" != "" {
        noisily display as text ""
        noisily display as text "Overlapping Periods"
        noisily display as text "{hline 60}"
        
        tempfile _overlaps_temp
        quietly save `_overlaps_temp'
        sort id start stop
        * Identify overlapping periods (start before previous period ends)
        quietly by id (start): gen double __overlap = (start <= stop[_n-1]) if _n > 1 & id == id[_n-1]
        
        quietly keep if __overlap == 1
        
        if _N > 0 {
            * Count total overlaps
            local total_overlaps = _N
            
            * Count unique IDs with overlaps
            quietly by id: gen double __first_overlap = (_n == 1)
            quietly count if __first_overlap == 1
            local n_ids = r(N)
            
            noisily display as text "Total overlapping periods: " as result `total_overlaps'
            noisily display as text "Number of IDs affected: " as result `n_ids'

            if "`verbose'" != "" {
                noisily display as text ""
                noisily display as text "Showing first 100 overlapping periods:"
                noisily display as text ""

                * Show first 100 overlaps with better formatting
                local show_n = min(`total_overlaps', 100)
                forvalues i = 1/`show_n' {
                    local show_id = id[`i']
                    local show_start = start[`i']
                    local show_stop = stop[`i']
                    * Get exposure value - use generate var if exists, else use exp_value
                    if `skip_main_var' == 0 {
                        local show_exp = `generate'[`i']
                    }
                    else {
                        capture local show_exp = exp_value[`i']
                        if _rc != 0 local show_exp = "N/A"
                    }
                    local prev_stop = stop[`i'-1]
                    * Only show if this is an overlap (defensive check)
                    if `i' > 1 & `show_id' == id[`i'-1] {
                        noisily display as text "  ID " as result %6.0f `show_id' as text ///
                            ": " as result %td `show_start' as text " to " as result %td `show_stop' ///
                            as text " (exp=" as result "`show_exp'" as text ///
                            ", prev_stop=" as result %td `prev_stop' as text ")"
                    }
                }

                if `total_overlaps' > 100 {
                    local more = `total_overlaps' - 100
                    noisily display as text ""
                    noisily display as text "... and `more' more overlapping periods"
                }
            }
            else {
                noisily display as text "  (specify verbose to list affected IDs and dates)"
            }
        }
        else {
            noisily display as text "No overlapping periods found"
        }
        quietly use `_overlaps_temp', clear
    }
    
    **# Exposure distribution summary (summarize option)
    if "`summarize'" != "" {
        noisily display as text ""
        noisily display as text "Exposure Distribution"
        noisily display as text "{hline 60}"
        
        * For categorical exposures, show distribution table
        * With bytype, tabulate the per-type variables; otherwise the single
        * output variable. (A bare `generate'* wildcard tabulated EVERY
        * variable — id, dates — when bytype left generate() empty.)
        if "`exp_type'" != "continuous" {
            if "`bytype'" != "" {
                quietly ds `stub_name'*
                if "`r(varlist)'" != "" {
                    noisily tab1 `r(varlist)', missing
                }
            }
            else {
                noisily tab1 `generate', missing
            }
        }
        else {
            * For continuous exposure, show descriptive statistics
            if "`bytype'" != "" {
                * When bytype is used with continuous, get list of bytype variables and show stats for each
                quietly ds `stub_name'*
                local bytype_varlist "`r(varlist)'"
                noisily display as text "Continuous exposure (person-years) by type:"
                foreach bytype_var of local bytype_varlist {
                    quietly sum `bytype_var', detail
                    noisily display as text ""
                    noisily display as text "`bytype_var':"
                    noisily display as text "  Min:    " as result %8.3f r(min)
                    noisily display as text "  Mean:   " as result %8.3f r(mean)
                    noisily display as text "  Median: " as result %8.3f r(p50)
                    noisily display as text "  Max:    " as result %8.3f r(max)
                }
            }
            else {
                * Without bytype, show stats for single variable
                quietly sum `generate', detail
                noisily display as text "Continuous exposure (person-years):"
                noisily display as text "  Min:    " as result %8.3f r(min)
                noisily display as text "  Mean:   " as result %8.3f r(mean)
                noisily display as text "  Median: " as result %8.3f r(p50)
                noisily display as text "  Max:    " as result %8.3f r(max)
            }
        }
        
        * Calculate person-time by exposure category (only for categorical)
        tempfile _summarize_temp
        quietly save `_summarize_temp'
        quietly gen double period_length = stop - start + 1
        
        if "`exp_type'" != "continuous" {
            * When bytype is used, get explicit list of bytype variables to avoid ambiguous abbreviation
            if "`bytype'" != "" {
                quietly ds `stub_name'*
                local collapse_by_vars "`r(varlist)'"
            }
            else {
                local collapse_by_vars "`generate'"
            }
            
            * Category time is the UNION of that category's own intervals per
            * person, so a category whose rows overlap each other is not
            * counted twice. The denominator is the study-window person-time.
            tempvar _catgrp _catdays
            quietly egen long `_catgrp' = group(id `collapse_by_vars')
            _tvtools_interval_union, id(`_catgrp') start(start) stop(stop) ///
                uniondays(`_catdays')
            sort `_catgrp'
            quietly by `_catgrp': keep if _n == 1

            quietly collapse (sum) cat_time = `_catdays', by(`collapse_by_vars')
            quietly gen double cat_pct = cond(`total_time' > 0, 100 * cat_time / `total_time', .)
            noisily list `collapse_by_vars' cat_time cat_pct, noobs separator(0)

            * Overlapping categories are multi-membership by construction, so
            * say so rather than presenting shares that look mutually
            * exclusive but sum past 100.
            quietly summarize cat_time, meanonly
            local _cat_total = r(sum)
            if `total_time' > 0 & `_cat_total' > `total_time' + 1e-6 {
                noisily display as text "  Note: categories overlap in time, so a day can belong to more"
                noisily display as text "  than one category. Shares are multi-membership and sum above 100%."
            }

            quietly use `_summarize_temp', clear
        }
    }
    
    **# Validation dataset creation (validate option)
    * Per-person exposure metrics need the single output variable, so validate
    * is unavailable with bytype; say so rather than silently skipping.
    if "`validate'" != "" & "`bytype'" != "" {
        noisily display as text "Note: validate is not available with bytype; validation dataset not created."
    }
    if "`validate'" != "" & "`bytype'" == "" {
        * Create comprehensive validation dataset with per-person metrics
        tempfile _validate_temp
        quietly save `_validate_temp'
        
        * Covered days use the same clipped union engine as check, so the
        * validation dataset and the coverage report cannot disagree.
        _tvtools_interval_union, id(id) start(start) stop(stop) ///
            cliplow(study_entry) cliphigh(study_exit) ///
            uniondays(total_covered)

        sort id start stop
        quietly generate double period_days = stop - start + 1
        quietly by id: generate double expected_days = study_exit[1] - study_entry[1] + 1
        quietly generate double pct_covered = 100 * total_covered / expected_days

        * Exposed time is the union of the exposed rows only.
        quietly gen double __exposed_val = (`generate' != `reference')
        tempvar _expgrp
        quietly egen long `_expgrp' = group(id __exposed_val)
        _tvtools_interval_union, id(`_expgrp') start(start) stop(stop) ///
            uniondays(__exp_union_days)
        sort id start stop
        quietly gen double exp_days = cond(__exposed_val, __exp_union_days, 0)
        quietly by id: egen double total_exposed_days = max(exp_days)
        drop __exp_union_days
        quietly by id: egen double n_periods = count(id)
        
        * Calculate number of transitions
        quietly by id (start): gen double __trans_ind = (`generate' != `generate'[_n-1]) if _n > 1 & id == id[_n-1]
        quietly by id: egen double n_transitions = total(__trans_ind)
        drop __trans_ind
        
        * Gaps use the running maximum stop, matching check and gaps above.
        quietly by id (start stop): gen double __rmaxv = stop if _n == 1
        quietly by id (start stop): replace __rmaxv = max(__rmaxv[_n-1], stop) if _n > 1
        quietly by id (start stop): gen double __gap_val = ///
            (start > __rmaxv[_n-1] + 1) if _n > 1
        quietly by id: egen double any_gaps = max(__gap_val)
        quietly by id: egen double n_gaps = total(__gap_val)
        drop __gap_val __rmaxv
        
        * First and last exposure dates
        quietly by id: egen double __first_exp_val = min(start) if __exposed_val
        quietly by id: egen double __last_exp_val = max(stop) if __exposed_val
        quietly by id: egen double first_exposure = min(__first_exp_val)
        quietly by id: egen double last_exposure = max(__last_exp_val)
        
        * Keep one row per person
        quietly by id: keep if _n == 1
        keep id total_covered expected_days pct_covered total_exposed_days ///
            n_periods n_transitions any_gaps n_gaps first_exposure last_exposure
        
        * Add variable labels
        label var total_covered "Total days covered"
        label var expected_days "Expected days (entry to exit)"
        label var pct_covered "Percent of expected period covered"
        label var total_exposed_days "Total days exposed"
        label var n_periods "Number of periods"
        label var n_transitions "Number of transitions"
        label var any_gaps "Any gaps in coverage"
        label var n_gaps "Number of gaps"
        label var first_exposure "First exposure start date"
        label var last_exposure "Last exposure end date"
        
        format first_exposure last_exposure %tdCCYY/NN/DD
        
        * Save validation dataset
        local validation_file = "tv_validation.dta"
        if "`saveas'" != "" {
            local validation_file = subinstr("`saveas'", ".dta", "_validation.dta", .)
            * saveas() without a .dta extension: subinstr changes nothing and
            * the validation file would silently collide with the main output
            if "`validation_file'" == "`saveas'" {
                local validation_file "`saveas'_validation.dta"
            }
        }
        
        if "`replace'" != "" {
            quietly save "`validation_file'", replace
        }
        else {
            quietly save "`validation_file'"
        }
        
        noisily display as text "Validation dataset saved as: " as result "`validation_file'"
        
        quietly use `_validate_temp', clear
    }
    
    **# DISPLAY RESULTS
    
    * Display summary results
    noisily display as text ""
    noisily display as text "{bf:Time-varying exposure dataset created}"
    noisily display as text "{bf:Exposure Operationalization:} {it:`exp_type'}"
    noisily display as text "{hline 50}"
    noisily display as text "    Persons: " as result %14.0fc `N_persons'
    noisily display as text "    Time-varying periods: " as result %14.0fc `N_periods'
    noisily display as text "    Total person-time (days): " as result %14.0fc `total_time'
    noisily display as text "    Exposed person-time: " as result %14.0fc `exposed_time' " (" %4.1f `pct_exposed' "%)"
    noisily display as text "    Unexposed person-time: " as result %14.0fc `unexposed_time'
    
    * Display applied options
    if `lag' > 0 {
        noisily display as text "    Lag period: " as result `lag' " days"
    }
    if `washout' > 0 {
        noisily display as text "    Washout period: " as result `washout' " days"
    }
    if "`grace'" != "" {
        noisily display as text "    Grace period: " as result "`grace'"
    }
    if "`priority'" != "" {
        noisily display as text "    Priority order: " as result "`priority'"
    }
    if "`window'" != "" {
        noisily display as text "    Exposure window: " as result "`window'" " days"
    }
    
    noisily display as text "    {it:Note: Baseline periods included (complete person-time coverage)}"
    
    noisily display as text "{hline 50}"
    
    if "`saveas'" != "" {
        noisily display as text "Dataset saved as: " as result "`saveas'"
    }
    
    * Clean up any remaining temporary variables before final output
    quietly {
        * Drop internal __ prefixed variables, but protect user keepvars
        * Check if any keepvars start with __ before wildcard drop
        local safe_to_wildcard = 1
        if "`keepvars'" != "" {
            foreach var of local keepvars {
                if substr("`var'", 1, 2) == "__" {
                    local safe_to_wildcard = 0
                }
            }
        }
        if `safe_to_wildcard' {
            capture drop __*
        }
        else {
            * Selective drop of known internal variables
            foreach __internal in __orig_exp_binary __orig_exp_category ///
                __orig_exp_value __exp_now_cont __exp_now_dur __exp_now_rec ///
                __final_binary __period_id __period_start __same_evers ///
                __same_cf __same_cumuls __same_durs __same_dur __same_rec ///
                __same_recencies __same_dose __grp __grp_et __grp_cf ///
                __new_et __new_cf __unitized __ovl __break ///
                __first_exp __first_exp_any __first_exp_temp ///
                __last_exp_temp __last_exp_any __state_change __state_group ///
                __switched __needs_expansion __needs_split ///
                __has_conflict __has_next_overlap __still_overlap {
                capture drop `__internal'
            }
        }

        * Drop other internal processing variables that shouldn't be in output
        capture drop has_overlap exp_combined
        capture drop unit_seq n_units
        capture drop _proportion
    }
    
    * Order variables properly (must be done before returns)
    
    * Detect bytype variables if bytype option was used
    local bytype_vars ""
    if "`bytype'" != "" {
        quietly ds `stub_name'*
        local bytype_vars "`r(varlist)'"
    }
    
    * Time-varying format: id start stop exposure [bytype vars] [keepvars] [entry exit if keepdates]
    
    * Determine the main exposure variable name
    if `skip_main_var' == 0 {
        local main_exp_var "`generate'"
    }
    else {
        local main_exp_var ""
    }
    
    if "`keepdates'" == "" {
        * Drop study dates by default
        capture drop study_entry study_exit
        if "`keepvars'" != "" {
            if "`main_exp_var'" != "" {
                order id start stop `main_exp_var' `bytype_vars' `keepvars'
            }
            else {
                order id start stop `bytype_vars' `keepvars'
            }
        }
        else {
            if "`main_exp_var'" != "" {
                order id start stop `main_exp_var' `bytype_vars'
            }
            else {
                order id start stop `bytype_vars'
            }
        }
    }
    else {
        * Keep study dates and order them last
        if "`keepvars'" != "" {
            if "`main_exp_var'" != "" {
                order id start stop `main_exp_var' `bytype_vars' `keepvars' study_entry study_exit
            }
            else {
                order id start stop `bytype_vars' `keepvars' study_entry study_exit
            }
        }
        else {
            if "`main_exp_var'" != "" {
                order id start stop `main_exp_var' `bytype_vars' study_entry study_exit
            }
            else {
                order id start stop `bytype_vars' study_entry study_exit
            }
        }
    }
    
    * Restore variable and value labels for keepvars and study dates
    quietly {
        * Restore study_entry and study_exit labels if keepdates specified
        if "`keepdates'" != "" {
            capture confirm variable study_entry
            if _rc == 0 {
                if "`study_entry_varlab'" != "" {
                    label variable study_entry "`study_entry_varlab'"
                }
                if "`study_entry_vallab'" != "" {
                    capture confirm file "`_lbl_stub'_study_entry.do"
                    if _rc == 0 {
                        quietly do "`_lbl_stub'_study_entry.do"
                        label values study_entry `study_entry_vallab'
                    }
                }
            }
            capture confirm variable study_exit
            if _rc == 0 {
                if "`study_exit_varlab'" != "" {
                    label variable study_exit "`study_exit_varlab'"
                }
                if "`study_exit_vallab'" != "" {
                    capture confirm file "`_lbl_stub'_study_exit.do"
                    if _rc == 0 {
                        quietly do "`_lbl_stub'_study_exit.do"
                        label values study_exit `study_exit_vallab'
                    }
                }
            }
        }
        
        * Restore keepvars labels
        if "`keepvars'" != "" {
            foreach var of local keepvars {
                * Restore variable label
                capture confirm variable `var'
                if _rc == 0 {
                    if "`varlab_`var''" != "" {
                        label variable `var' "`varlab_`var''"
                    }
                    
                    * Restore value labels if they were saved
                    if "`vallab_`var''" != "" {
                        capture confirm file "`_lbl_stub'_label_`var'.do"
                        if _rc == 0 {
                            quietly do "`_lbl_stub'_label_`var'.do"
                            label values `var' `vallab_`var''
                        }
                    }
                }
            }
        }
    }
    
    * Restore original id variable type and format to match unaltered data
    quietly {
        capture confirm numeric variable id
        local current_is_numeric = (_rc == 0)
        
        * Check if original was numeric
        local original_is_numeric = (substr("`original_id_type'", 1, 3) != "str")
        
        * If types differ, convert back to original type
        if `current_is_numeric' != `original_is_numeric' {
            if `original_is_numeric' {
                * Convert string back to numeric
                tempvar id_temp
                destring id, generate(`id_temp') force
                drop id
                rename `id_temp' id
            }
            else {
                * Convert numeric back to string
                tempvar id_temp
                tostring id, generate(`id_temp')
                drop id
                rename `id_temp' id
            }
        }
        
        * Restore original format
        format id `original_id_format'
    }
    
    sort id start stop
    * Commit the structural names. A failed rename here means the committed
    * schema does not match the one the caller asked for, so it is an error,
    * not something to swallow. The preflight above should already have
    * rejected every reachable collision; this gate exists so that a case it
    * does not anticipate fails loudly instead of shipping a wrong schema.
    if "`id'" != "id" {
        capture quietly rename id `id'
        local _id_rename_rc = _rc
        if `_id_rename_rc' {
            noisily display as error "Could not name the id variable '`id'' in the output (rc=`_id_rename_rc')"
            noisily display as error "No output was committed."
            exit 198
        }
    }

    if "`start'" != "start" {
        capture quietly rename start `start'
        local _start_rename_rc = _rc
        if `_start_rename_rc' {
            noisily display as error "Could not name the start bound '`start'' in the output (rc=`_start_rename_rc')"
            noisily display as error "No output was committed."
            exit 198
        }
    }
    if "`stop'" != "" & "`stop'" != "stop" {
        capture quietly rename stop `stop'
        local _stop_rename_rc = _rc
        if `_stop_rename_rc' {
            noisily display as error "Could not name the stop bound '`stop'' in the output (rc=`_stop_rename_rc')"
            noisily display as error "No output was committed."
            exit 198
        }
    }
    capture quietly label data "`using'"
    local _label_data_rc = _rc

    **# SAVE DATA IF REQUESTED
   
    * Save final dataset if requested
    if "`saveas'" != "" {
			capture quietly label data "`saveas'"
            local _save_label_rc = _rc
        if "`replace'" != "" {
            quietly save "`saveas'", replace
        }
        else {
            quietly save "`saveas'"
        }
    }

    * Frames-first output: copy the finished result into the named frame and
    * reload the caller's data so their working frame is untouched.
    if "`frameout'" != "" {
        _tvexpose_frame_commit, target(`frameout') `replace'
        if `_frameout_snap_taken' quietly use "`_tvx_caller_snap'", clear
        else quietly clear
        noisily display as text "Result placed in frame: " as result "`frameout'"
        return local frameout "`frameout'"
    }

    * Return results only on successful completion
    return scalar N_persons = `N_persons'
    return scalar N_periods = `N_periods'
    return scalar total_time = `total_time'
    return scalar exposed_time = `exposed_time'
    return scalar unexposed_time = `unexposed_time'
    return scalar pct_exposed = `pct_exposed'
    return scalar n_invalid_master = `n_invalid_master'
    return scalar n_invalid_master_id = `n_invalid_master_id'
    return scalar n_invalid_master_dates = `n_invalid_master_dates'
    return scalar n_invalid_master_order = `n_invalid_master_order'
    return scalar n_invalid_exposure = `n_invalid_exposure'
    return scalar n_invalid_exposure_id = `n_invalid_exposure_id'
    return scalar n_invalid_exposure_dates = `n_invalid_exposure_dates'
    return scalar n_invalid_exposure_order = `n_invalid_exposure_order'
    return scalar n_invalid_exposure_value = `n_invalid_exposure_value'
    return scalar n_unmatched_exposure = `n_unmatched_exposure'
    return scalar n_outside_window = `n_outside_window'
    return scalar n_lag_removed = `n_lag_removed'
    return scalar n_uncovered_days = `n_uncovered_days'
    return scalar n_unresolved_overlaps = `n_unresolved_overlaps'

    if "`window'" != "" {
        return scalar window_min = `window_min'
        return scalar window_max = `window_max'
    }
    if "`recency'" != "" {
        return local recency_unit "`recency_unit'"
        return local recency_cutdays "`recency_cutdays'"
    }

    * Name of the generated exposure variable (or the bytype stub), so callers
    * and downstream tvmerge/tvevent steps can read the chosen output name.
    if `skip_main_var' == 0  return local genvar "`generate'"
    else                     return local genvar "`stub_name'"

    * combine() allocates codes for simultaneous exposure states. Report the
    * allocated code -> composition map so a caller never has to reconstruct
    * it from the value label.
    return scalar n_combined_states = `_combo_n'
    return local combine_map `"`_combo_map'"'

    * bytype derives one variable per exposure value. Report the
    * value -> variable map so a caller never has to reconstruct the
    * suffix-sanitization rule.
    return scalar n_bytype_vars = `_bt_n'
    return local bytype_map `"`_bt_map'"'

    * Note: overlap_ids already available via return local, no global needed

    * Flow accounting report (opt-in via flow option)
    if `_return_flow' {
        tempname _flowmat
        matrix `_flowmat' = J(2, 3, .)
        matrix `_flowmat'[1,1] = `_flow_pin'
        matrix `_flowmat'[1,2] = `N_persons'
        matrix `_flowmat'[1,3] = `_flow_pin' - `N_persons'
        matrix `_flowmat'[2,1] = `_flow_rin'
        matrix `_flowmat'[2,2] = `N_periods'
        matrix `_flowmat'[2,3] = `_flow_rin' - `N_periods'
        matrix rownames `_flowmat' = persons records
        matrix colnames `_flowmat' = in out dropped
        display as text "{hline 60}"
        display as text "Pipeline flow (tvexpose)"
        display as text %-12s "" %10s "in" %10s "out" %10s "dropped"
        display as text %-12s "persons" %10.0f `_flow_pin' %10.0f `N_persons' ///
            %10.0f `=`_flow_pin' - `N_persons''
        display as text %-12s "records" %10.0f `_flow_rin' %10.0f `N_periods' ///
            %10.0f `=`_flow_rin' - `N_periods''
        display as text "(records dropped < 0 indicates net interval expansion)"
        display as text "{hline 60}"
        return matrix flow = `_flowmat'
    }

    } // end capture noisily
    local rc = _rc

    * Unwind any interrupted inner preserve, then restore the caller snapshot.
    if `rc' & `_caller_snapshot_ready' {
        capture restore
        if `_frameout_snap_taken' capture quietly use "`_tvx_caller_snap'", clear
        else capture quietly clear
        local _tvx_drc = _rc    // best-effort restore; do not mask `rc'
    }

    set varabbrev `orig_varabbrev'

    if `rc' {
        exit `rc'
    }

end
*
