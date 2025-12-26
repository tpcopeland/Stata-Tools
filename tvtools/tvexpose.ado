*! tvexpose Version 1.3.0  2025/12/26
*! Create time-varying exposure variables for survival analysis
*! Author: Tim Copeland
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
                         Row expansion:
                           • days    → No row expansion; one row per original exposure period
                           • weeks   → 7-day bins starting at exposure start
                           • months  → calendar months
                           • quarters→ calendar quarters
                           • years   → calendar years
                         Example 1: continuousunit(years) expandunit(months) creates one row per 
                         calendar month and reports cumulative YEARS of exposure.
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
  generate(newvar)     - Name for output exposure variable (default: tv_exposure)
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
    set varabbrev off

    * Load Mata library for performance-critical operations (O(n log n) overlap detection)
    findfile _tvexpose_mata.ado
    quietly run "`r(fn)'"

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
        LABel(string)]
    
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
    
    * Validate variable name lengths (Stata silently truncates names >31 chars)
    foreach opt in id start stop exposure generate combine {
        if "``opt''" != "" {
            local len = strlen("``opt''")
            if `len' > 31 {
                noisily display as error "Variable name too long: ``opt'' (`len' characters)"
                noisily display as error "Stata variable names must be 31 characters or fewer"
                exit 198
            }
        }
    }

    * Lock sample in master dataset
    marksample touse
    quietly count if `touse'
    if r(N) == 0 {
        error 2000  // no observations
    }
    
    * Set default values
    * generate() defaults to "tv_exposure" unless user specifies alternate name
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
        * Set a flag indicating we should not create the main variable
        local skip_main_var = 1
    }
    else {
        * Without bytype, generate() is the name of the single output variable
        if "`generate'" == "" local generate "tv_exposure"
        local skip_main_var = 0
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
    
    * Default to layer if no overlap handling option specified
    if `n_overlap' == 0 {
        local layer "layer"
    }
    
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
    }
    restore
    
    * Capture original id variable type and format to restore at end
    quietly {
        local original_id_type : type `id'
        local original_id_format : format `id'
    }
    
    * Save original master dataset state
    * We save the master dataset to a tempfile so we can reload it later
    * The master dataset contains study entry/exit dates for each person
    tempfile _master_orig

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

	quietly replace `entry' = floor(`entry')
	quietly replace `exit' = ceil(`exit')
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
        noisily list id study_entry study_exit if study_exit < study_entry in 1/5, noobs
        exit 498
    }
    
    * Capture variable and value labels for keepvars and study dates
    * These will be restored after final merge to preserve user's labels
    local study_entry_varlab : variable label study_entry
    local study_exit_varlab : variable label study_exit
    local study_entry_vallab : value label study_entry
    local study_exit_vallab : value label study_exit
    
    * Save value label definitions for study dates if they exist
    if "`study_entry_vallab'" != "" {
        quietly label save `study_entry_vallab' using `c(tmpdir)'/label_study_entry.do, replace
    }
    if "`study_exit_vallab'" != "" {
        quietly label save `study_exit_vallab' using `c(tmpdir)'/label_study_exit.do, replace
    }
    
    if "`keepvars'" != "" {
        foreach var of local keepvars {
            * Capture variable label
            local varlab_`var' : variable label `var'
            
            * Check if variable has value labels and capture them
            local vallab_`var' : value label `var'
            if "`vallab_`var''" != "" {
                * Save the value label definition
                quietly label save `vallab_`var'' using `c(tmpdir)'/label_`var'.do, replace
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

	quietly replace `start' = floor(`start')
	quietly capture replace `stop' = ceil(`stop')
    
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
    
* Check for invalid exposure records AFTER all date processing
    * Drop periods where start > stop (data quality issue)
    * These cannot be meaningfully processed
    quietly count if exp_start > exp_stop
    if r(N) > 0 {
        local n_invalid = r(N)
        noisily display as error "Warning: `n_invalid' periods have start > stop; these will be dropped"
        * Show details of first 10 invalid records for debugging
        tempfile _invalid_records _temp_data
        quietly save `_temp_data'
        quietly keep if exp_start > exp_stop
        if _N > 0 {
            quietly save `_invalid_records', replace
            noisily display as text "First invalid records (id, start, stop):"
            local show_n = min(_N, 10)
            forvalues i = 1/`show_n' {
                local show_id = id[`i']
                local show_start = exp_start[`i']
                local show_stop = exp_stop[`i']
                noisily display as text "  ID `show_id': start=" as result %tdCCYY/NN/DD `show_start' as text " > stop=" as result %tdCCYY/NN/DD `show_stop'
            }
            if _N > 10 {
                local more = _N - 10
                noisily display as text "  ... and `more' more"
            }
        }
        quietly use `_temp_data', clear
        quietly drop if exp_start > exp_stop
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
    quietly drop if exp_stop < study_entry
    quietly drop if exp_start > study_exit
    
    * Apply lag period (delay before exposure becomes active)
    * Lag represents latency period before biological effect begins
    * For example: lag(30) means 30-day delay before chemotherapy starts damaging cells
    if `lag' > 0 {
        quietly replace exp_start = exp_start + `lag'
        * Remove periods that became invalid due to lag
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
        quietly replace exp_start = exp_start + `window_min'
        quietly replace exp_stop = min(exp_start + `window_max', exp_stop)
        quietly drop if exp_start > exp_stop
    }
    
    * Truncate all periods to study observation window
    * All exposure periods must fall within [entry, exit] for that person
    * This is final truncation after all transformations
    quietly replace exp_start = study_entry if exp_start < study_entry
    quietly replace exp_stop = study_exit if exp_stop > study_exit
    
    * Retain only essential variables for processing
    * Drop all other variables to reduce memory usage
    * Keep only: id, dates, exposure value, and user-specified keepvars
    if "`keepvars'" != "" {
        keep id exp_start exp_stop exp_value study_entry study_exit `keepvars'
    }
    else {
        keep id exp_start exp_stop exp_value study_entry study_exit
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

    * Report completion status
    if `iter' >= `max_merge_iter' {
        noisily display as error "Warning: merge iteration limit (`max_merge_iter') reached"
        noisily display as text "         Some periods may not have been fully merged"
        noisily display as text "         Consider increasing merge() parameter or simplifying exposure data"
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

    * Report if many iterations were needed
    if `iter' >= `max_contain_iter' {
        noisily display as error "Warning: containment check iteration limit reached"
    }
    else if `iter' > `progress_interval' {
        noisily display as text "  Containment check completed after `iter' iterations"
    }

    quietly drop contained

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
            quietly gen double __seg_dose = 0
            quietly gen double __seg_days = seg_stop - seg_start + 1

            tempfile segments
            quietly save `segments', replace
            restore

            * Step 4: Calculate dose contribution for each segment from each overlapping period
            * Use cross-join approach: for each segment, check all periods for that person
            quietly use `segments', clear
            quietly gen double __seg_id = _n

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
            quietly gen double __contrib = __seg_days * __orig_daily_rate

            * Sum contributions by segment
            collapse (sum) exp_value=__contrib (first) seg_start seg_stop study_entry study_exit, by(id __seg_id)

            rename (seg_start seg_stop) (exp_start exp_stop)
            drop __seg_id

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
    if "`exp_type'" != "dose" & "`split'" != "" {
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
        
        * Keep only boundaries that fall within period (not at edges)
        quietly keep if boundary > exp_start & boundary < exp_stop
        
        * If no splits needed, restore original
        quietly count
        if r(N) == 0 {
            quietly use `original_periods', clear
            drop __period_id
        }
        else {
            * Create split periods
            sort id __period_id boundary
            quietly by id __period_id: generate double new_start = cond(_n == 1, exp_start, boundary)
            quietly by id __period_id: generate double new_stop = cond(_n < _N, boundary - 1, exp_stop)
            
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
            
            * Mark which period IDs were split (appeared multiple times in split data)
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
        preserve
        keep id exp_value
        quietly keep if exp_value != `reference'
        quietly bysort id exp_value: keep if _n == 1
        keep id exp_value
        rename exp_value __all_exp_types
        tempfile all_person_exp_types
        quietly save `all_person_exp_types', replace
        restore
        
        * Also save original exposure type for each period before overlap resolution
        * This preserves the type-to-period mapping needed for bytype calculations
        preserve
        keep id exp_start exp_stop exp_value
        quietly keep if exp_value != `reference'
        tempfile period_exp_types
        quietly save `period_exp_types', replace
        restore
    }
    
    if "`exp_type'" != "dose" & "`combine'" != "" {
        * COMBINE OVERLAPPING: Creates combined exposure category for overlaps
        * Assigns new value to combinations (encodes as val1*100 + val2)
        * Allows analysis of synergistic or interactive effects
        sort id exp_start exp_stop exp_value
        
        * Detect true overlaps: next period starts before current ends
        quietly by id: gen double has_overlap = (exp_start[_n+1] <= exp_stop) if _n < _N & id == id[_n+1]
        
        * For overlapping periods with different exposure values, create combination
        * Example: exposure 1 overlapping with 2 = 1*100 + 2 = 102
        quietly gen double exp_combined = exp_value
        quietly by id: replace exp_combined = exp_value * 100 + exp_value[_n+1] ///
            if has_overlap == 1 & exp_value != exp_value[_n+1] & _n < _N & id == id[_n+1]
        
        * Also mark the overlapped period (second period) with same combined value
        quietly by id: replace exp_combined = exp_value[_n-1] * 100 + exp_value ///
            if _n > 1 & exp_start <= exp_stop[_n-1] & ///
            exp_value != exp_value[_n-1] & missing(has_overlap[_n-1]) & id == id[_n-1]
        
        * Create the named combined variable for user's analysis
        quietly gen double `combine' = exp_combined
        drop has_overlap exp_combined
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
            noisily display as text "  (List of IDs stored in r(overlap_ids))"
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

    * Adjust for overlapping different exposure types (simple truncation)
    * When different exposure types overlap, later one takes precedence
    * (Assumes data recording order reflects most recent exposure status)
    * Use iterative resolution to handle cascading overlaps
    * ONLY run when NOT in layer mode - layer mode handles overlaps with resumption
    if "`layer'" == "" {
        sort id exp_start exp_stop exp_value

        local iter = 0
        local max_iter = 10
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

        if `iter' >= `max_iter' {
            noisily display in re "Warning: Simple overlap resolution reached iteration limit; some overlaps may remain"
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
        local max_iter = 10
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
            _tvexpose_mata_overlaps id exp_start exp_stop priority_rank
            local n_overlaps = r(n_overlaps)

            if `n_overlaps' == 0 {
                local changed = 0
                capture quietly drop __overlaps_higher __first_overlap_row __adj_start __adj_stop __valid
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
        
        if `iter' >= `max_iter' {
            noisily display in re "Warning: Priority resolution reached iteration limit; some overlaps may remain"
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
    * Iteration is needed because splitting may create new overlaps to resolve
    * ===========================================================================
    **# Layer option: Sequential precedence with resumption
    if "`layer'" != "" {

        local changed = 1
        local iter = 0
        local max_iter = 10
        
        while `changed' == 1 & `iter' < `max_iter' {
            sort id exp_start exp_stop exp_value

            * Clean up any leftover temp variables from previous iteration
            capture drop __has_next_overlap __orig_row __next_start __next_stop __pre_stop __extends_beyond __post_start

            * Mark periods that overlap with next period (different exposure)
            quietly by id: gen double __has_next_overlap = ///
                (exp_start[_n+1] <= exp_stop & exp_value != exp_value[_n+1]) if _n < _N & id == id[_n+1]
            
            quietly count if __has_next_overlap == 1
            local n_overlaps = r(N)
            
            if `n_overlaps' == 0 {
                local changed = 0
                quietly drop __has_next_overlap
            }
            else {
                * For overlapping periods, split into: pre-overlap, overlap (handled by next), post-overlap
                quietly gen double __orig_row = _n
                quietly gen double __next_start = exp_start[_n+1] if __has_next_overlap == 1 & id == id[_n+1]
                quietly gen double __next_stop = exp_stop[_n+1] if __has_next_overlap == 1 & id == id[_n+1]
                
                * Create pre-overlap segment (current period up to next period start)
                quietly gen double __pre_stop = __next_start - 1 if __has_next_overlap == 1
                
                * Create post-overlap segment (current period after next period ends, if applicable)
                quietly gen double __extends_beyond = (exp_stop > __next_stop) if __has_next_overlap == 1
                quietly gen double __post_start = __next_stop + 1 if __extends_beyond == 1
                
                * Preserve original data
                tempfile pre_split
                quietly save `pre_split', replace

                * Keep non-overlapping periods as-is (includes last rows with missing values)
                quietly keep if __has_next_overlap != 1
                tempfile non_overlap
                quietly save `non_overlap', replace
                
                * Create pre-overlap segments
                quietly use `pre_split', clear
                quietly keep if __has_next_overlap == 1
                quietly replace exp_stop = __pre_stop
                if "`keepvars'" != "" {
                    quietly keep id exp_start exp_stop exp_value `keepvars'
                }
                else {
                    quietly keep id exp_start exp_stop exp_value
                }
                tempfile pre_segments
                quietly save `pre_segments', replace
                
                * Create post-overlap segments (resumption)
                quietly use `pre_split', clear
                quietly keep if __extends_beyond == 1
                quietly replace exp_start = __post_start
                * Keep original stop date for resumption segment
                if "`keepvars'" != "" {
                    quietly keep id exp_start exp_stop exp_value `keepvars'
                }
                else {
                    quietly keep id exp_start exp_stop exp_value
                }
                tempfile post_segments
                quietly save `post_segments', replace
                
                * Combine all segments
                quietly use `non_overlap', clear
                quietly append using `pre_segments'
                quietly append using `post_segments'
                
                * Remove any invalid periods
                quietly drop if exp_start > exp_stop | missing(exp_start) | missing(exp_stop)
                quietly duplicates drop id exp_start exp_stop exp_value, force
                
                sort id exp_start exp_stop exp_value
            }
            
            local iter = `iter' + 1
        }
        
        if `iter' >= `max_iter' {
            noisily display in re "Warning: Layer resolution reached iteration limit; some overlaps may remain"
        }

        * After layer resolution, merge overlapping same-type periods
        * Layer can create resumption segments that overlap with other same-type periods
        local merge_iter = 0
        local merge_max = 10
        local merge_changes = 1

        while `merge_changes' > 0 & `merge_iter' < `merge_max' {
            sort id exp_start exp_stop exp_value
            quietly gen double __merge_flag = 0

            * Identify adjacent/overlapping same-type periods
            quietly by id (exp_start exp_stop): replace __merge_flag = 1 if ///
                (exp_start[_n+1] - exp_stop <= `merge') & ///
                !missing(exp_start[_n+1]) & ///
                (exp_value == exp_value[_n+1]) & ///
                (_n < _N) & id == id[_n+1]

            * Extend stop date to encompass next period
            quietly by id: replace exp_stop = max(exp_stop, exp_stop[_n+1]) if __merge_flag == 1 & _n < _N & id == id[_n+1]

            * Mark subsumed periods for deletion
            quietly gen double __drop_merge = 0
            quietly by id: replace __drop_merge = 1 if _n > 1 & id == id[_n-1] & __merge_flag[_n-1] == 1 & exp_start >= exp_start[_n-1] & exp_stop <= exp_stop[_n-1]

            quietly count if __drop_merge == 1
            local merge_changes = r(N)

            if `merge_changes' > 0 {
                quietly drop if __drop_merge == 1
            }

            capture drop __merge_flag __drop_merge
            local merge_iter = `merge_iter' + 1
        }
    }
    } // End of if "`exp_type'" != "dose" block for overlap handling

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

    * Create gap periods only where gap exceeds grace period
    quietly generate double __gap_start = exp_stop + 1 if __gap_days > __grace_days & !missing(__gap_days)
    quietly generate double __gap_stop = 0
    quietly by id : replace __gap_stop = exp_start[_n+1] - 1 if __gap_days > __grace_days & ///
        !missing(__gap_days) & _n < _N & id == id[_n+1]
    
    * Extract and save gap periods
    tempfile pregap
    quietly save `pregap', replace
    quietly keep if !missing(__gap_start) & !missing(__gap_stop)
    
    * Apply carryforward logic if specified
    * Carryforward fills gaps with the previous exposure value for up to carryforward days
    if `carryforward' > 0 {
        * Save previous exposure value to carry forward into gap
        quietly generate double __prev_exp_value = exp_value
        
        * Calculate actual gap duration
        quietly generate double __actual_gap = __gap_stop - __gap_start + 1
        
        * For gaps <= carryforward days: fill entire gap with previous exposure
        * For gaps > carryforward days: split into carryforward period + reference period
        quietly generate double __carry_stop = min(__gap_start + `carryforward' - 1, __gap_stop)
        quietly generate double __ref_start = __carry_stop + 1
        
        * Create carryforward periods (always created, up to carryforward days)
        keep id __gap_start __carry_stop __prev_exp_value __actual_gap __gap_stop
        rename (__gap_start __carry_stop __prev_exp_value) (exp_start exp_stop exp_value)
        tempfile carryforward_gaps
        quietly save `carryforward_gaps', replace
        
        * Create reference periods for remaining gap (only if gap > carryforward)
        quietly keep if __actual_gap > `carryforward'
        quietly drop exp_start
        quietly generate double exp_start = exp_stop + 1
        quietly drop exp_stop
        rename __gap_stop exp_stop
        quietly replace exp_value = `reference'
        keep id exp_start exp_stop exp_value
        tempfile ref_gaps
        quietly save `ref_gaps', replace
        
        * Combine carryforward and reference gap periods
        quietly use `carryforward_gaps', clear
        keep id exp_start exp_stop exp_value
        capture confirm file `ref_gaps'
        if _rc == 0 {
            quietly append using `ref_gaps'
        }
        tempfile gaps
        quietly save `gaps', replace
    }
    else {
        * No carryforward: all gaps are reference periods
        keep id __gap_start __gap_stop
        rename (__gap_start __gap_stop) (exp_start exp_stop)
        quietly gen exp_value = `reference'
        tempfile gaps
        quietly save `gaps', replace
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
    capture confirm file `gaps'
    if _rc == 0 {
        quietly append using `gaps'
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
                capture do `c(tmpdir)'/label_`var'.do
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
    
    * Save original exposure categories for bytype processing
    * Must be saved before any exposure type transformations that change exp_value
    quietly gen __orig_exp_category = exp_value
    
    * For bytype processing, merge back the pre-overlap exposure types
    * This ensures we can identify which periods belonged to which exposure type
    * even if overlap resolution eliminated some types
    if "`bytype'" != "" {
        * Merge back original exposure types from before overlap resolution
        preserve
        quietly use `period_exp_types', clear
        isid id exp_start exp_stop exp_value
        restore
        quietly merge m:1 id exp_start exp_stop exp_value using `period_exp_types', ///
            nogen keep(1 3)
        
        * exp_value matched from using data represents the pre-overlap type
        * Use it as the original exposure category for bytype calculations
        quietly replace __orig_exp_category = exp_value
    }
    
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
            foreach exp_type_val of local exp_types {
                * Sanitize suffix for variable names (handles negative/decimal values)
                local suffix = subinstr("`exp_type_val'", "-", "neg", .)
                local suffix = subinstr("`suffix'", ".", "p", .)
                quietly gen double __first_exp_`suffix' = exp_start if __orig_exp_category == `exp_type_val'
                quietly bysort id (exp_start): egen double __first_any_`suffix' = min(__first_exp_`suffix')
                * Mark ALL rows as "ever treated" if they occur at or after first exposure to this type
                quietly replace `stub_name'`suffix' = 1 if exp_start >= __first_any_`suffix' & !missing(__first_any_`suffix')

                * Get label from original exposure variable for this type
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

                drop __first_exp_`suffix' __first_any_`suffix'
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
            
            * Define and apply value labels for binary ever-treated
            label define et_labels 0 "Never exposed" 1 "Ever exposed", replace
            label values exp_value et_labels
            
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
            label define cf_labels 0 "Never" 1 "Current" 2 "Former", replace
            label values exp_value cf_labels
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
                
                if "`expand_unit'" == "weeks" {
                    **#### Weekly expansion (7-day bins from exposure start)
                    * Create unique period identifier before expansion
                    quietly gen double __period_id = _n
                    * Calculate number of weeks in period
                    quietly gen double n_units = ceil((exp_stop - exp_start + 1) / 7)
                    * Expand to one row per week
                    quietly expand n_units
                    quietly bysort id __period_id: gen double unit_seq = _n
                    * Calculate unit boundaries using floor to ensure integer dates
                    quietly gen double unit_start = floor(exp_start + (unit_seq - 1) * 7)
                    quietly bysort id __period_id: gen double unit_stop = cond(unit_seq < n_units, floor(exp_start + unit_seq * 7) - 1, exp_stop)
                    * Drop original period boundaries
                    drop exp_start exp_stop __period_id
                    rename (unit_start unit_stop) (exp_start exp_stop)
                }
                else if "`expand_unit'" == "months" {
                    **#### Monthly expansion (fixed 30.4375-day bins from exposure start)
                    * Create unique period identifier before expansion
                    quietly gen double __period_id = _n
                    * Calculate number of months in period (using average month length)
                    quietly gen double n_units = ceil((exp_stop - exp_start + 1) / 30.4375)
                    * Expand to one row per month
                    quietly expand n_units
                    quietly bysort id __period_id: gen double unit_seq = _n
                    * Calculate unit boundaries using floor to ensure integer dates, no gaps
                    quietly gen double unit_start = floor(exp_start + (unit_seq - 1) * 30.4375)
                    quietly bysort id __period_id: gen double unit_stop = cond(unit_seq < n_units, floor(exp_start + unit_seq * 30.4375) - 1, exp_stop)
                    * Drop original period boundaries
                    drop exp_start exp_stop __period_id
                    rename (unit_start unit_stop) (exp_start exp_stop)
                }
                else if "`expand_unit'" == "quarters" {
                    **#### Quarterly expansion (fixed 91.3125-day bins from exposure start)
                    * Create unique period identifier before expansion
                    quietly gen double __period_id = _n
                    * Calculate number of quarters in period (using average quarter length)
                    quietly gen double n_units = ceil((exp_stop - exp_start + 1) / 91.3125)
                    * Expand to one row per quarter
                    quietly expand n_units
                    quietly bysort id __period_id: gen double unit_seq = _n
                    * Calculate unit boundaries using floor to ensure integer dates, no gaps
                    quietly gen double unit_start = floor(exp_start + (unit_seq - 1) * 91.3125)
                    quietly bysort id __period_id: gen double unit_stop = cond(unit_seq < n_units, floor(exp_start + unit_seq * 91.3125) - 1, exp_stop)
                    * Drop original period boundaries
                    drop exp_start exp_stop __period_id
                    rename (unit_start unit_stop) (exp_start exp_stop)
                }
                else if "`expand_unit'" == "years" {
                    **#### Yearly expansion (fixed 365.25-day bins from exposure start)
                    * Create unique period identifier before expansion
                    quietly gen double __period_id = _n
                    * Calculate number of years in period (using average year length)
                    quietly gen double n_units = ceil((exp_stop - exp_start + 1) / 365.25)
                    * Expand to one row per year
                    quietly expand n_units
                    quietly bysort id __period_id: gen double unit_seq = _n
                    * Calculate unit boundaries using floor to ensure integer dates, no gaps
                    quietly gen double unit_start = floor(exp_start + (unit_seq - 1) * 365.25)
                    quietly bysort id __period_id: gen double unit_stop = cond(unit_seq < n_units, floor(exp_start + unit_seq * 365.25) - 1, exp_stop)
                    * Drop original period boundaries
                    drop exp_start exp_stop __period_id
                    rename (unit_start unit_stop) (exp_start exp_stop)
                }
                
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
            tempvar __break __grp __ovl
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
        
        * IMPORTANT:
        * For continuous dose-like measures, report the cumulative total AT THE END
        * of each interval and carry forward during unexposed intervals.
        * This avoids repeated zeros across early short intervals and is typically
        * what users expect for a running cumulative "so far" measure.
        quietly bysort id (exp_start): gen cumul_days_end = sum(period_days)
        
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
                quietly gen period_days_`suffix' = period_days if __orig_exp_value == `exp_type_val'
                quietly replace period_days_`suffix' = 0 if missing(period_days_`suffix')

                * Calculate cumulative exposure for this type
                quietly bysort id (exp_start): gen cumul_days_`suffix' = sum(period_days_`suffix')
                quietly gen `stub_name'`suffix' = cumul_days_`suffix' / `unit_divisor'

                * Label the variable with value label and units from continuousunit
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
                quietly drop period_days_`suffix' cumul_days_`suffix'
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
            quietly gen exp_value_new = cumul_days_end / `unit_divisor'
            drop exp_value period_days cumul_days_end
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
                        local thresh_days = `thresh_units' * `unit_divisor'

                        * Generate threshold crossing date
                        * Date = start of period containing threshold + days needed to reach threshold
                        quietly by id: gen double __thresh_date_`suffix'_`i' = .

                        * Find period where cumulative crosses threshold
                        quietly by id: replace __thresh_date_`suffix'_`i' = ///
                            exp_start + ceil(`thresh_days' - (__cumul_days_`suffix' - __period_days_`suffix')) ///
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
                    quietly drop if exp_start > exp_stop | exp_start < 0 | exp_stop < 0
                    
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

                * Convert to units
                quietly gen double __cumul_units_start_`suffix' = __cumul_start_days_`suffix' / `unit_divisor'

                * Assign duration category based on cumulative exposure at period start
                * Use epsilon for floating-point comparison consistency
                local epsilon = 0.001
                quietly gen `stub_name'`suffix' = `reference'
                if `n_cuts' > 0 {
                    local first_cut = `1'
                    quietly replace `stub_name'`suffix' = 1 if __orig_exp_category == `exp_type_val' & ///
                        __cumul_units_start_`suffix' < (`first_cut' - `epsilon') & __cumul_units_start_`suffix' >= 0

                    local i = 2
                    while `i' <= `n_cuts' {
                        local prev_cut = ``=`i'-1''
                        local curr_cut = ``i''
                        quietly replace `stub_name'`suffix' = `i' if __orig_exp_category == `exp_type_val' & ///
                            __cumul_units_start_`suffix' >= (`prev_cut' - `epsilon') & __cumul_units_start_`suffix' < (`curr_cut' - `epsilon')
                        local i = `i' + 1
                    }

                    local last_cut = ``n_cuts''
                    quietly replace `stub_name'`suffix' = `n_cuts' + 1 if __orig_exp_category == `exp_type_val' & ///
                        __cumul_units_start_`suffix' >= (`last_cut' - `epsilon')
                }
                else {
                    quietly replace `stub_name'`suffix' = 1 if __orig_exp_category == `exp_type_val' & ///
                        __cumul_units_start_`suffix' >= 0
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
                quietly drop __period_days_`suffix' __cumul_days_`suffix' __cumul_start_days_`suffix' __cumul_units_start_`suffix'
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
            capture quietly rename __orig_exp_value exp_value
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
            
            * Convert to specified units
            quietly gen cumul_units_start = cumul_days_start / `unit_divisor'
            quietly gen cumul_units_end = cumul_days_end / `unit_divisor'
            
            * Step 2: Calculate exact threshold crossing dates
            tempfile threshold_dates
            if `n_cuts' > 0 {
                preserve
                
                * For each threshold, find exact crossing date
                forvalues i = 1/`n_cuts' {
                    local thresh_units = ``i''
                    local thresh_days = `thresh_units' * `unit_divisor'
                    
                    * Calculate threshold crossing date
                    quietly by id: gen double __thresh_date_`i' = ///
                        exp_start + floor(`thresh_days' - cumul_days_start) ///
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
                    quietly drop if exp_start > exp_stop | exp_start < 0 | exp_stop < 0
                    
                    tempfile split_periods
                    quietly save `split_periods', replace
                    
                    * Combine with non-split periods
                    quietly use `split_candidates', clear
                    quietly drop if __needs_split == 1
                    quietly drop __needs_split
                    forvalues i = 1/`n_cuts' {
                        capture quietly drop __thresh_date_`i'
                    }
                    quietly append using `split_periods'
                    sort id exp_start
                }
                else {
                    quietly drop __needs_split
                    forvalues i = 1/`n_cuts' {
                        capture quietly drop __thresh_date_`i'
                    }
                }
            }
            
            * Step 4: Recalculate cumulative exposure and assign duration categories

            drop period_days cumul_days_start cumul_days_end cumul_units_start cumul_units_end

            * Recalculate cumulative exposure after splitting
            sort id exp_start
            quietly generate double period_days = exp_stop - exp_start + 1 if __exp_now_dur
            quietly replace period_days = 0 if missing(period_days)
            quietly by id : gen cumul_days_end = sum(period_days)
            quietly by id : gen cumul_days_start = cumul_days_end[_n-1] if _n > 1 & id == id[_n-1]
            quietly replace cumul_days_start = 0 if missing(cumul_days_start)
            
            quietly gen cumul_units_start = cumul_days_start / `unit_divisor'
            quietly gen cumul_units_end = cumul_days_end / `unit_divisor'
            
            * Assign duration categories based on cumulative at period start
            quietly gen exp_duration = `reference'
            if `n_cuts' > 0 {
                local first_cut = `1'
                local epsilon = 0.001
                quietly replace exp_duration = 1 if __exp_now_dur & cumul_units_start < (`first_cut' - `epsilon') & cumul_units_start >= 0
                
                local i = 2
                while `i' <= `n_cuts' {
                    local prev_cut = ``=`i'-1''
                    local curr_cut = ``i''
                    quietly replace exp_duration = `i' if __exp_now_dur & ///
                        cumul_units_start >= (`prev_cut' - `epsilon') & cumul_units_start < (`curr_cut' - `epsilon')
                    local i = `i' + 1
                }
                
                local last_cut = ``n_cuts''
                quietly replace exp_duration = `n_cuts' + 1 if __exp_now_dur & cumul_units_start >= (`last_cut' - `epsilon')
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
            label define dur_labels `reference' "`referencelabel'", replace
            if `n_cuts' > 0 {
                local first_cut = `1'
                local first_cut_str = string(`first_cut', "%9.0f")
                local first_cut_str = trim("`first_cut_str'")
                label define dur_labels 1 "<`first_cut_str' `unit_name'", add
                local i = 2
                while `i' <= `n_cuts' {
                    local prev_cut = ``=`i'-1''
                    local curr_cut = ``i''
                    local prev_cut_str = string(`prev_cut', "%9.0f")
                    local curr_cut_str = string(`curr_cut', "%9.0f")
                    local prev_cut_str = trim("`prev_cut_str'")
                    local curr_cut_str = trim("`curr_cut_str'")
                    label define dur_labels `i' "`prev_cut_str'-<`curr_cut_str' `unit_name'", add
                    local i = `i' + 1
                }
                local last_cut = ``n_cuts''
                local last_cut_str = string(`last_cut', "%9.0f")
                local last_cut_str = trim("`last_cut_str'")
                label define dur_labels `=`n_cuts'+1' "`last_cut_str'+ `unit_name'", add
            }
            else {
                label define dur_labels 1 "Exposed", add
            }
            
            * Clear numbered macros
            if `n_cuts' > 0 {
                forvalues i = 1/`n_cuts' {
                    macro drop _`i'
                }
            }
            
            * Replace exposure variable with duration category
            drop exp_value __orig_exp_binary cumul_units_start cumul_units_end period_days cumul_days_start cumul_days_end
            rename exp_duration exp_value
            label values exp_value dur_labels
            
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
            label values exp_value dur_labels
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

        * exp_value now contains the per-segment dose from overlap handling
        * Calculate cumulative dose as running sum
        quietly by id: gen double __cumul_dose = sum(exp_value)

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
            label define dose_labels 0 "No dose", replace
            label define dose_labels 1 "<`1'", add

            local cat = 2
            forvalues i = 2/`n_cuts' {
                local prev = ``=`i'-1''
                local curr = ``i''
                label define dose_labels `cat' "`prev'-<`curr'", add
                local cat = `cat' + 1
            }
            label define dose_labels `=`n_cuts'+1' "``n_cuts''+", add

            * Replace exp_value with category
            drop exp_value
            rename exp_dose_cat exp_value
            label values exp_value dose_labels

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
            label values exp_value dose_labels
        }

        * Clean up
        capture drop __cumul_dose __same_dose __period_start
    }

    **# Recency (Time Since Last Exposure) Type
    * Research question: Is residual protection/risk dependent on recency?
    * Output: Categorical variable representing time since last exposure
    * Example: recency(30 90) creates: currently exposed, <30d since, 30-<90d since, 90+d since (up to 10x max)
    * Time-varying: Person moves through recency categories after exposure ends
    * After 10x the maximum cutpoint, reverts to reference (effectively "never exposed")
    else if "`exp_type'" == "recency" {
        if "`bytype'" != "" {
            * Create separate recency variables for each exposure type
            * FIXED: Use all exposure types saved BEFORE overlap resolution
            
            * Get complete list of exposure types from saved pre-overlap data
            preserve
            quietly use `all_person_exp_types', clear
            quietly levelsof __all_exp_types, local(exp_types)
            restore
            
            * Parse cutpoints once
            local n_cuts : word count `recency'
            tokenize `recency'
            local last_cut = ``n_cuts''
            local max_recency_window = `last_cut' * 10
            
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
                        __days_since_`suffix' < `max_recency_window' & !__exp_now_`suffix' & !missing(__days_since_`suffix')
                }

                * Get label from original exposure variable for this type
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
            
            * Create recency categories based on cutpoints (specified in days)
            local n_cuts : word count `recency'
            
            * Determine maximum recency window (10x the highest cutpoint)
            tokenize `recency'
            local last_cut = ``n_cuts''
            local max_recency_window = `last_cut' * 10
            
            quietly gen exp_recency = `reference'
            
            * Category 1: Currently exposed
            quietly replace exp_recency = 1 if __exp_now_rec == 1
            
            * Subsequent categories: Time since exposure bands
            if `n_cuts' > 0 {
                tokenize `recency'
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
                    __days_since < `max_recency_window' & !__exp_now_rec & !missing(__days_since)
            }
            
            * Define and apply value labels for recency categories
            label define rec_labels `reference' "Never exposed", replace
            label define rec_labels 1 "Currently exposed", add
            if `n_cuts' > 0 {
                tokenize `recency'
                local cat = 2
                if "`1'" != "" {
                    label define rec_labels `cat' "<`1' days since exposure", add
                    local cat = `cat' + 1
                }
                local i = 2
                while `i' <= `n_cuts' {
                    local prev = ``=`i'-1''
                    local curr = ``i''
                    label define rec_labels `cat' "`prev'-<`curr' days since exposure", add
                    local cat = `cat' + 1
                    local i = `i' + 1
                }
                label define rec_labels `cat' "`last_cut'+ days since exposure", add
            }
            
            * Replace exposure variable with recency category
            drop exp_value __orig_exp_binary __exp_now_rec __last_exp_end __last_exp_carried __days_since
            rename exp_recency exp_value
            label values exp_value rec_labels
            
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
            }
        }
        else {
            * No value label exists - create new one with reference category
            quietly levelsof exp_value, local(all_vals)
            label define tv_labels `reference' "`referencelabel'", replace
            foreach val of local all_vals {
                if `val' != `reference' {
                    label define tv_labels `val' "`val'", add
                }
            }
            label values exp_value tv_labels
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
    
    * Calculate summary statistics for output
    quietly count
    local N_periods = r(N)
    
    * Count unique persons
    egen double tag = tag(id)
    quietly count if tag
    local N_persons = r(N)
    drop tag
    
    * Calculate total person-time
    quietly gen time = stop - start + 1
    quietly sum time
    local total_time = r(sum)
    
    * Calculate exposed person-time
    * For duration/continuous/recency, use binary exposure logic
    * When bytype is used with evertreated, check if ANY ever variable = 1
    * For other bytype cases, use exp_value for this calculation

        * Calculate exposed person-time
    capture drop __final_binary

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

    quietly sum time if __final_binary
    if r(N) > 0 {
        local exposed_time = r(sum)
    }
    else {
        local exposed_time = 0
    }
    
    local unexposed_time = `total_time' - `exposed_time'
    if `total_time' > 0 {
        local pct_exposed = 100 * `exposed_time' / `total_time'
    }
    else {
        local pct_exposed = 0
    }
    
    drop time __final_binary
    
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
        * Calculate coverage metrics per person
        quietly generate double period_days = stop - start + 1
        quietly by id: egen double total_covered = total(period_days)
        quietly by id: generate double expected_days = study_exit[1] - study_entry[1] + 1
        quietly generate double pct_covered = 100 * total_covered / expected_days
        
        quietly by id: egen double n_periods = count(id)
        
        * Calculate number of gaps
        quietly by id (start): gen double __gap_ind = (start > stop[_n-1] + 1) if _n > 1 & id == id[_n-1]
        quietly by id: egen double n_gaps = total(__gap_ind)
        drop __gap_ind
        
        * Keep one row per person for display
        quietly by id: keep if _n == 1
        
        * Display sample of results (limit to actual number of observations)
        noisily list id pct_covered n_periods n_gaps in 1/`=min(_N,20)', clean noobs
        
        * Display summary statistics
        quietly sum pct_covered
        noisily display as text "{hline 70}"
        noisily display as text "Coverage Summary:"
        noisily display as text "  Mean coverage: " as result %5.1f r(mean) "%"
        noisily display as text "  Min coverage:  " as result %5.1f r(min) "%"
        noisily display as text "  Max coverage:  " as result %5.1f r(max) "%"
        
        quietly count if pct_covered < 100
        noisily display as text "  Persons with gaps: " as result r(N) " (" %4.1f 100*r(N)/_N "%)"
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
        sort id start
        * Identify gaps between consecutive periods
        quietly by id (start): gen double __gap_ind2 = (start > stop[_n-1] + 1) if _n > 1 & id == id[_n-1]
        quietly by id: gen gap_start = stop[_n-1] + 1 if __gap_ind2 == 1 & id == id[_n-1]
        quietly by id: gen gap_end = start - 1 if __gap_ind2 == 1
        quietly gen gap_days = gap_end - gap_start + 1 if !missing(gap_start)
        
        drop __gap_ind2
        capture quietly drop if gap_days <= 0
        quietly keep if !missing(gap_start) 
        
        if _N > 0 {
            format gap_start gap_end %tdCCYY/NN/DD
            noisily display as text "Showing first 20 gaps:"
            noisily list id gap_start gap_end gap_days in 1/`=min(_N,20)', noobs sepby(id)
            
            * Gap statistics
            quietly sum gap_days, detail
            noisily display as text ""
            noisily display as text "Gap Statistics:"
            noisily display as text "  Total gaps: " as result _N
            noisily display as text "  Mean gap: " as result %5.1f r(mean) " days"
            noisily display as text "  Median gap: " as result %5.0f r(p50) " days"
            noisily display as text "  Max gap: " as result %5.0f r(max) " days"
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
        if "`exp_type'" != "continuous" {
            noisily tab1 `generate'*, missing
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
        quietly gen period_length = stop - start + 1
        
        if "`exp_type'" != "continuous" {
            * When bytype is used, get explicit list of bytype variables to avoid ambiguous abbreviation
            if "`bytype'" != "" {
                quietly ds `stub_name'*
                local collapse_by_vars "`r(varlist)'"
            }
            else {
                local collapse_by_vars "`generate'"
            }
            
            quietly collapse (sum) cat_time = period_length (count) n_periods = period_length, ///
                by(`collapse_by_vars')
            quietly gen cat_pct = 100 * cat_time / `total_time'
            noisily list `collapse_by_vars' cat_time cat_pct, noobs separator(0)
            
            quietly use `_summarize_temp', clear
        }
    }
    
    **# Validation dataset creation (validate option)
    if "`validate'" != "" & "`bytype'" == "" {
        * Create comprehensive validation dataset with per-person metrics
        tempfile _validate_temp
        quietly save `_validate_temp'
        
        quietly generate double period_days = stop - start + 1
        quietly by id: egen double total_covered = total(period_days)
        quietly by id: generate double expected_days = study_exit[1] - study_entry[1] + 1
        quietly generate double pct_covered = 100 * total_covered / expected_days
        
        * Calculate exposed time
        quietly gen double __exposed_val = (`generate' != `reference')
        quietly generate double exp_days = period_days * __exposed_val
        quietly by id: egen double total_exposed_days = total(exp_days)
        quietly by id: egen double n_periods = count(id)
        
        * Calculate number of transitions
        quietly by id (start): gen double __trans_ind = (`generate' != `generate'[_n-1]) if _n > 1 & id == id[_n-1]
        quietly by id: egen double n_transitions = total(__trans_ind)
        drop __trans_ind
        
        * Calculate gaps
        quietly by id: gen double __gap_val = (start > stop[_n-1] + 1) if _n > 1 & id == id[_n-1]
        quietly by id: egen double any_gaps = max(__gap_val)
        quietly by id: egen double n_gaps = total(__gap_val)
        drop __gap_val
        
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
        * Drop any temporary variables with __ prefix that might remain
        capture drop __*

        * Drop other internal processing variables that shouldn't be in output
        capture drop has_overlap exp_combined
        capture drop unit_seq n_units
        capture drop _proportion
    }
    
    * Order variables properly (must be done before returns)
    
    * Detect bytype variables if bytype option was used
    local bytype_vars ""
    if "`bytype'" != "" {
        * Collect all bytype variables that exist in the dataset
        if "`exp_type'" == "evertreated" {
            quietly ds `stub_name'*
            local bytype_vars "`r(varlist)'"
        }
        else if "`exp_type'" == "currentformer" {
            quietly ds `stub_name'*
            local bytype_vars "`r(varlist)'"
        }
        else if "`exp_type'" == "duration" {
            quietly ds `stub_name'*
            local bytype_vars "`r(varlist)'"
        }
        else if "`exp_type'" == "continuous" {
            quietly ds `stub_name'*
            local bytype_vars "`r(varlist)'"
        }
        else if "`exp_type'" == "recency" {
            quietly ds `stub_name'*
            local bytype_vars "`r(varlist)'"
        }
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
                    capture confirm file "`c(tmpdir)'/label_study_entry.do"
                    if _rc == 0 {
                        quietly do "`c(tmpdir)'/label_study_entry.do"
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
                    capture confirm file "`c(tmpdir)'/label_study_exit.do"
                    if _rc == 0 {
                        quietly do "`c(tmpdir)'/label_study_exit.do"
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
                        capture confirm file "`c(tmpdir)'/label_`var'.do"
                        if _rc == 0 {
                            quietly do "`c(tmpdir)'/label_`var'.do"
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
	* Rename id back to original name if different
	if "`id'" != "id" {
		capture quietly rename id `id'
	}

	* Rename start/stop back to original names if different
	if "`start'" != "start" {
		capture quietly rename start `start'
	}
	if "`stop'" != "" & "`stop'" != "stop" {
		capture quietly rename stop `stop'
	}
    capture quietly label data "`using'"

    **# SAVE DATA IF REQUESTED
   
    * Save final dataset if requested
    if "`saveas'" != "" {
		capture quietly label data "`saveas'"
        if "`replace'" != "" {
            quietly save "`saveas'", replace
        }
        else {
            quietly save "`saveas'"
        }
    }

    * Return results only on successful completion
    return scalar N_persons = `N_persons'
    return scalar N_periods = `N_periods'
    return scalar total_time = `total_time'
    return scalar exposed_time = `exposed_time'
    return scalar unexposed_time = `unexposed_time'
    return scalar pct_exposed = `pct_exposed'

    * Note: overlap_ids already available via return local, no global needed

end
*
