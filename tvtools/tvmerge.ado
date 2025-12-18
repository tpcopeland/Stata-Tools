*! tvmerge Version 1.0.5  2025/12/18
*! Merge multiple time-varying exposure datasets
*! Author: Tim Copeland
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tvmerge dataset1 dataset2 [dataset3 ...], id(varname) ///
    start(varlist) stop(varlist) exposure(varlist) [options]

Required options:
  id(varname)        - Person identifier (same across all datasets)
  start(varlist)     - Start date variables (in order of datasets)
  stop(varlist)      - Stop date variables (in order of datasets)
  exposure(varlist)  - Exposure variables (in order of datasets)

Exposure type options:
  continuous(namelist) - Specify which exposures are continuous (rates per day)
                         Can use position numbers (1 2 3) or variable names

Output and naming options:
  generate(namelist) - New names for exposure variables (one per dataset)
  prefix(string)     - Prefix for all exposure variable names
  saveas(filename)   - Save merged dataset
  replace            - Overwrite existing file
  keep(varlist)      - Additional variables to keep from source datasets (note: suffixed with _ds#)
  startname(string)  - Name for start date variable in output (default: start)
  stopname(string)   - Name for stop date variable in output (default: stop)
  dateformat(fmt)    - Stata date format for output variables (default: %tdCCYY/NN/DD)

Diagnostic and validation options:
  check              - Display coverage diagnostics
  validatecoverage   - Verify all person-time accounted for (check for gaps)
  validateoverlap    - Verify overlapping periods make sense
  summarize          - Display summary statistics of start/stop dates

Performance options:
  batch(#)           - Process IDs in batches (default: 20 = 20% of IDs per batch)
                       Higher values = larger batches = potentially faster but more memory
                       Lower values = smaller batches = less memory but more I/O
                       Range: 1-100 (percentage of total IDs)
                       Recommended: 20-50 for most datasets

ID matching options:
  force              - Allow merging datasets with non-matching IDs (issues warning)
                       By default, tvmerge errors if IDs don't match across all datasets.
                       With force, mismatched IDs are dropped with a warning.
                       Useful when merging exposure data that is a subset of a cohort.

IMPORTANT: This program replaces the current dataset in memory with the merged result.
Use the saveas() option to save the result to a file, or load your original data
from a saved file before running if you need to preserve it.

EXPOSURE TYPES:
- Categorical (default): Creates cartesian product of all exposure combinations
- Continuous: Treats exposure as rate per day
*/

program define tvmerge, rclass

    version 16.0
    set varabbrev off

    **# SYNTAX DECLARATION
    
    syntax anything(name=datasets), ///
        id(name) ///
        STart(namelist) STOP(namelist) EXPosure(namelist) ///
        [GENerate(namelist) ///
         PREfix(string) ///
         STARTname(string) ///
         STOPname(string) ///
         DATEformat(string) ///
         SAVeas(string) ///
         REPlace ///
         KEEP(namelist) ///
         CONtinuous(namelist) ///
         Batch(integer 20) ///
         FORCE ///
         CHECK VALIDATEcoverage VALIDATEoverlap SUMmarize]
    
    **# INPUT VALIDATION AND SETUP
    
    * Check for by: usage - tvmerge cannot be used with by:
    if "`_byvars'" != "" {
        di as error "tvmerge cannot be used with by:"
        exit 190
    }
    
    * Parse and validate dataset count
    local numds: word count `datasets'
    if `numds' < 2 {
        di as error "tvmerge requires at least 2 datasets"
        exit 198
    }
    
    * Verify all dataset files exist and are valid Stata datasets
    * This prevents cryptic error messages from use command
    preserve
    local validation_error = 0
    local error_msg ""
    local error_code = 0

    foreach ds in `datasets' {
        * Handle .dta extension: add only if not already present
        local ds_file "`ds'"
        if substr("`ds'", -4, .) != ".dta" {
            local ds_file "`ds'.dta"
        }
        capture confirm file "`ds_file'"
        if _rc != 0 {
            local validation_error = 1
            local error_msg "Dataset file not found: `ds_file'"
            local error_code = 601
            continue, break
        }
        * Also verify it's a valid Stata dataset
        * Note: Don't use "in 1" - it fails on empty datasets
        capture use "`ds_file'", clear
        if _rc != 0 {
            local validation_error = 1
            local error_msg "`ds_file' is not a valid Stata dataset or cannot be read"
            local error_code = 610
            continue, break
        }
    }
    restore

    if `validation_error' {
        di as error "`error_msg'"
        exit `error_code'
    }
    
    * Check for conflicting naming options
    if "`prefix'" != "" & "`generate'" != "" {
        di as error "Specify either prefix() or generate(), not both"
        exit 198
    }
    
    * Validate prefix name format
    if "`prefix'" != "" {
        capture confirm name `prefix'dummy
        if _rc != 0 {
            di as error "prefix() contains invalid Stata name characters"
            exit 198
        }
    }
    
    * Validate generate() names and count
    if "`generate'" != "" {
        local ngen: word count `generate'
        if `ngen' != `numds' {
            di as error "generate() must contain exactly `numds' names (one per dataset)"
            exit 198
        }
        foreach gname in `generate' {
            capture confirm name `gname'
            if _rc != 0 {
                di as error "generate() contains invalid name: `gname'"
                exit 198
            }
        }
    }
    
    * Validate startname, stopname options if specified
    if "`startname'" != "" {
        capture confirm name `startname'
        if _rc != 0 {
            di as error "startname() contains invalid Stata name: `startname'"
            exit 198
        }
    }
    else {
        local startname "start"
    }
    
    if "`stopname'" != "" {
        capture confirm name `stopname'
        if _rc != 0 {
            di as error "stopname() contains invalid Stata name: `stopname'"
            exit 198
        }
    }
    else {
        local stopname "stop"
    }
    
    * Verify startname and stopname are different
    if "`startname'" == "`stopname'" {
        di as error "startname() and stopname() must be different variable names"
        exit 198
    }
    
    * Validate dateformat option if specified
    if "`dateformat'" == "" {
        local dateformat "%tdCCYY/NN/DD"
    }
    else {
        * Verify it's a valid Stata date format by attempting format on temp variable
        tempvar _testvar
        generate double `_testvar' = 22000
        capture format `_testvar' `dateformat'
        if _rc != 0 {
            di as error "Invalid date format specified: `dateformat'"
            exit 198
        }
        capture drop `_testvar'
    }

    * Validate batch option
    if `batch' < 1 | `batch' > 100 {
        di as error "batch() must be between 1 and 100 (percentage of IDs per batch)"
        exit 198
    }
    
    * Force multi-dataset syntax for all merges
    local numsv: word count `start'
    local numst: word count `stop'
    local numexp: word count `exposure'

    if `numsv' != `numds' {
        di as error "Number of start() variables (`numsv') must equal number of datasets (`numds')"
        exit 198
    }
    if `numst' != `numds' {
        di as error "Number of stop() variables (`numst') must equal number of datasets (`numds')"
        exit 198
    }
    if `numexp' < `numds' {
        di as error "Number of exposure() variables (`numexp') must be at least the number of datasets (`numds')"
        exit 198
    }

    local starts "`start'"
    local stops "`stop'"

    * Validate that startname/stopname don't conflict with internal variable names
    local reserved_names "start_k stop_k id new_start new_stop _valid _gap _overlap _same_exposures _tag _nper _per _per_max"
    local startname_conflict: list startname in reserved_names
    if `startname_conflict' {
        di as error "startname(`startname') conflicts with internal variable name"
        di as error "Please choose a different name for the output start variable"
        exit 198
    }
    local stopname_conflict: list stopname in reserved_names
    if `stopname_conflict' {
        di as error "stopname(`stopname') conflicts with internal variable name"
        di as error "Please choose a different name for the output stop variable"
        exit 198
    }
    
    * Check for duplicate exposure variable names in the specification
    local exposures_raw "`exposure'"
    local numexp_raw: word count `exposures_raw'

    * Check if user specified same variable name multiple times
    local seen_names ""
    local has_dup = 0
    local dup_name ""
    foreach exp_name in `exposures_raw' {
        local already_seen: list exp_name in seen_names
        if `already_seen' {
            local has_dup = 1
            local dup_name "`exp_name'"
            continue, break
        }
        local seen_names "`seen_names' `exp_name'"
    }

    if `has_dup' {
        di as error "Duplicate exposure variable name '`dup_name'' specified multiple times."
        di as error "Each position in exposure() must have a unique name."
        di as error "Use the generate() option to rename exposures if datasets have same variable names."
        exit 198
    }

    local exposures "`exposures_raw'"
    local numexp: word count `exposures'
    
    * Parse continuous exposure specification (names or positions)
    local continuous_positions ""
    local continuous_names ""
    if "`continuous'" != "" {
        foreach item in `continuous' {
            * Check if item is a number (position)
            capture confirm integer number `item'
            if _rc == 0 {
                * It's a number - treat as position
                if `item' < 1 | `item' > `numexp' {
                    di as error "continuous() position `item' out of range (1-`numexp')"
                    exit 198
                }
                local continuous_positions "`continuous_positions' `item'"
                local exp_at_pos: word `item' of `exposures'
                local continuous_names "`continuous_names' `exp_at_pos'"
            }
            else {
                * Not a number - treat as exposure name
                local found_exp = 0
                forvalues j = 1/`numexp' {
                    local exp_j: word `j' of `exposures'
                    if "`item'" == "`exp_j'" {
                        local continuous_positions "`continuous_positions' `j'"
                        local continuous_names "`continuous_names' `item'"
                        local found_exp = 1
                    }
                }
                if `found_exp' == 0 {
                    di as error "continuous() exposure `item' not found in exposure list"
                    exit 198
                }
            }
        }
    }

    * Count continuous and categorical exposures
    local n_continuous: word count `continuous_names'
    local n_categorical = `numexp' - `n_continuous'

    * Identify categorical exposures (those not in continuous list)
    local categorical_positions ""
    local categorical_names ""
    forvalues j = 1/`numexp' {
        local is_continuous = 0
        foreach cont_pos in `continuous_positions' {
            if `j' == `cont_pos' {
                local is_continuous = 1
            }
        }
        if `is_continuous' == 0 {
            local categorical_positions "`categorical_positions' `j'"
            local exp_j: word `j' of `exposures'
            local categorical_names "`categorical_names' `exp_j'"
        }
    }

    * Build final exposure list for output
    local continuous_exps ""
    local categorical_exps ""

    * Process by exposure variables to get final exposure names
    * Note: Loop through ALL exposure variables, not just dataset count
    forvalues j = 1/`numexp_raw' {
        local exp_j: word `j' of `exposures_raw'
        
        * Find position of this exposure in unique list
        local pos = 0
        forvalues k = 1/`numexp' {
            local exp_k: word `k' of `exposures'
            if "`exp_j'" == "`exp_k'" {
                local pos = `k'
            }
        }
        
        * Determine final name for this exposure
        if "`generate'" != "" {
            local exp_name: word `j' of `generate'
        }
        else if "`prefix'" != "" {
            local exp_name "`prefix'`exp_j'"
        }
        else {
            local exp_name "`exp_j'"
        }
        
        * Check if continuous
        local is_cont = 0
        foreach cont_pos in `continuous_positions' {
            if `pos' == `cont_pos' {
                local is_cont = 1
            }
        }
        
        if `is_cont' == 1 {
            local continuous_exps: list continuous_exps | exp_name
        }
        else {
            local categorical_exps: list categorical_exps | exp_name
        }
    }
    
    * Initialize tracking for keep() variables
    if "`keep'" != "" {
        local keep_vars_found ""
    }
    
    **# MAIN PROCESSING
    quietly {
        
        **# LOAD AND PREPARE FIRST DATASET
        * Process first dataset as base
        local first_ds: word 1 of `datasets'
        use "`first_ds'", clear
        
        * CRITICAL FIX: Ensure all new variables use double type
        capture confirm variable `id'
        if _rc != 0 {
            di as error "Variable `id' not found in `first_ds'"
            exit 111
        }
        
        local start1: word 1 of `starts'
        local stop1: word 1 of `stops'
        capture confirm variable `start1'
        if _rc != 0 {
            di as error "Variable `start1' not found in `first_ds'"
            exit 111
        }
        capture confirm variable `stop1'
        if _rc != 0 {
            di as error "Variable `stop1' not found in `first_ds'"
            exit 111
        }
        
        local exp1: word 1 of `exposures_raw'
        capture confirm variable `exp1'
        if _rc != 0 {
            di as error "Variable `exp1' not found in `first_ds'"
            exit 111
        }
        
        * Rename variables to standard names
        rename `id' id
        rename `start1' `startname'
        rename `stop1' `stopname'
        
        * Floor start dates and ceil stop dates to handle fractional date values
        replace `startname' = floor(`startname')
        replace `stopname' = ceil(`stopname')
        
        * Apply new exposure name if specified
        if "`generate'" != "" {
            local newname1: word 1 of `generate'
            rename `exp1' `newname1'
            local exp1 "`newname1'"
        }
        else if "`prefix'" != "" {
            rename `exp1' `prefix'`exp1'
            local exp1 "`prefix'`exp1'"
        }
        
        * Keep only necessary variables plus keep() list
        local keeplist "id `startname' `stopname' `exp1'"
        
        * Add intensity variable if exposure is continuous
        local exp1_orig: word 1 of `exposures_raw'
        local is_cont1 = 0
        foreach cont_name in `continuous_names' {
            if "`exp1_orig'" == "`cont_name'" {
                local is_cont1 = 1
            }
        }
        
        * Process keep() variables for dataset 1
        if "`keep'" != "" {
            foreach var in `keep' {
                capture confirm variable `var'
                if _rc == 0 {
                    * Track that this variable was found
                    local keep_vars_found: list keep_vars_found | var
                    * Rename with _ds1 suffix to avoid conflicts
                    tempvar temp_`var'
                    rename `var' `temp_`var''
                    rename `temp_`var'' `var'_ds1
                    local keeplist "`keeplist' `var'_ds1"
                }
            }
        }
        
        keep `keeplist'
        
        * Drop invalid periods where start > stop
        generate double _valid = (`startname' <= `stopname') & !missing(`startname', `stopname')
        quietly count if _valid == 0
        local invalid_ds1 = r(N)
        keep if _valid == 1
        drop _valid
        
        * Sort and save as tempfile
        sort id `startname' `stopname'

        * Check for overlapping intervals in first dataset
        tempvar _overlap_check
        by id: gen byte `_overlap_check' = (`startname' < `stopname'[_n-1]) if _n > 1
        quietly count if `_overlap_check' == 1
        local n_overlaps_ds1 = r(N)
        if `n_overlaps_ds1' > 0 {
            noisily di as text "Warning: Dataset 1 (`first_ds') contains `n_overlaps_ds1' overlapping interval(s) within persons."
            noisily di as text "         Overlapping input may produce unexpected results."
        }
        drop `_overlap_check'

        tempfile merged_data
        save `merged_data', replace

        * Track continuous exposures already in merged_data
        * These need to be re-proportioned when intervals are sliced in subsequent merges
        local merged_continuous_exps ""
        if `is_cont1' == 1 {
            local merged_continuous_exps "`exp1'"
        }

        **# PROCESS ADDITIONAL DATASETS AND MERGE
        * Process each additional dataset
        forvalues k = 2/`numds' {
            local ds_k: word `k' of `datasets'

            * Get variable names for this dataset BEFORE loading
            * This avoids any potential macro confusion from data in memory
            local start_k_varname: word `k' of `starts'
            local stop_k_varname: word `k' of `stops'
            local exp_k_raw: word `k' of `exposures_raw'

            * Validate that we got valid variable names
            if "`start_k_varname'" == "" {
                di as error "Could not extract start variable name for dataset `k' from start() option"
                di as error "start() option contains: `starts'"
                exit 198
            }
            if "`stop_k_varname'" == "" {
                di as error "Could not extract stop variable name for dataset `k' from stop() option"
                di as error "stop() option contains: `stops'"
                exit 198
            }
            if "`exp_k_raw'" == "" {
                di as error "Could not extract exposure variable name for dataset `k' from exposure() option"
                di as error "exposure() option contains: `exposures_raw'"
                exit 198
            }

            * Check if user's variable name conflicts with internal temp name
            * This would cause issues when we try to rename to start_k/stop_k
            capture confirm name start_k
            capture confirm name stop_k
            if "`start_k_varname'" == "start_k" | "`stop_k_varname'" == "stop_k" {
                * User specified a variable literally named start_k or stop_k
                * This is allowed but we should warn about potential confusion
                noisily di as text "Note: Variable name '`start_k_varname'' or '`stop_k_varname'' matches internal temp name"
            }

            * Now load the dataset
            use "`ds_k'", clear

            * Check which exposure variables exist in this dataset
            local exp_k_list ""
            foreach possible_exp in `exposures_raw' {
                capture confirm variable `possible_exp'
                if _rc == 0 {
                    local exp_k_list "`exp_k_list' `possible_exp'"
                }
            }

            if "`exp_k_list'" == "" {
                di as error "No exposure variables found in `ds_k'"
                exit 111
            }

            * Verify required variables exist - check for pre-existing start_k/stop_k conflict
            capture confirm variable start_k
            local has_start_k = (_rc == 0)
            capture confirm variable stop_k
            local has_stop_k = (_rc == 0)

            * If user's variable is NOT named start_k but dataset already has start_k,
            * we'll have a conflict during rename
            if `has_start_k' & "`start_k_varname'" != "start_k" {
                di as error "Dataset `ds_k' already contains a variable named 'start_k'"
                di as error "This conflicts with internal processing. Please rename this variable before using tvmerge."
                exit 110
            }
            if `has_stop_k' & "`stop_k_varname'" != "stop_k" {
                di as error "Dataset `ds_k' already contains a variable named 'stop_k'"
                di as error "This conflicts with internal processing. Please rename this variable before using tvmerge."
                exit 110
            }

            * Verify required variables exist
            capture confirm variable `id'
            if _rc != 0 {
                di as error "Variable `id' not found in `ds_k'"
                exit 111
            }
            capture confirm variable `start_k_varname'
            if _rc != 0 {
                di as error "Variable `start_k_varname' not found in `ds_k'"
                di as error "(This is variable `k' from start() option: `starts')"
                exit 111
            }
            capture confirm variable `stop_k_varname'
            if _rc != 0 {
                di as error "Variable `stop_k_varname' not found in `ds_k'"
                di as error "(This is variable `k' from stop() option: `stops')"
                exit 111
            }
            * Note: exp_k_raw (word k of exposure list) may not exist in this dataset
            * when exposure() has more variables than datasets. The exp_k_list
            * (built above) contains all exposures actually found in this dataset.
            * We only validate that at least one exposure was found (done at lines 528-531).

            * Rename to standard internal names for processing
            rename `id' id
            rename `start_k_varname' start_k
            rename `stop_k_varname' stop_k

            * Floor start dates and ceil stop dates to handle fractional date values
            replace start_k = floor(start_k)
            replace stop_k = ceil(stop_k)

            * Apply new exposure name if specified - only if exp_k_raw exists in this dataset
            local exp_k_raw_exists: list exp_k_raw in exp_k_list
            if `exp_k_raw_exists' {
                if "`generate'" != "" {
                    local newname_k: word `k' of `generate'
                    rename `exp_k_raw' `newname_k'
                    local exp_k "`newname_k'"
                }
                else if "`prefix'" != "" {
                    rename `exp_k_raw' `prefix'`exp_k_raw'
                    local exp_k "`prefix'`exp_k_raw'"
                }
                else {
                    local exp_k "`exp_k_raw'"
                }
            }
            else {
                * exp_k_raw not in this dataset - exposures will be renamed via exp_k_list loop below
                local exp_k ""
            }

            * Build complete list of exposures for this dataset with renamed variables
            local exp_k_list_final ""
            foreach found_exp in `exp_k_list' {
                if "`found_exp'" == "`exp_k_raw'" {
                    * This is the positional exposure, use the renamed version
                    local exp_k_list_final "`exp_k_list_final' `exp_k'"
                }
                else {
                    * Other exposure found in dataset, apply prefix if specified
                    if "`prefix'" != "" {
                        rename `found_exp' `prefix'`found_exp'
                        local exp_k_list_final "`exp_k_list_final' `prefix'`found_exp'"
                    }
                    else {
                        local exp_k_list_final "`exp_k_list_final' `found_exp'"
                    }
                }
            }

            * Update exp_k_list for later use (continuous interpolation)
            local exp_k_list "`exp_k_list_final'"

            * Keep only necessary variables (all exposures found in this dataset)
            local keeplist_k "id start_k stop_k `exp_k_list'"
            
            * Check if exposure is continuous
            local is_cont_k = 0
            foreach cont_name in `continuous_names' {
                if "`exp_k_raw'" == "`cont_name'" {
                    local is_cont_k = 1
                }
            }
            
            * Process keep() variables for dataset k
            if "`keep'" != "" {
                foreach var in `keep' {
                    capture confirm variable `var'
                    if _rc == 0 {
                        * Track that this variable was found
                        local keep_vars_found: list keep_vars_found | var
                        * Rename with _ds# suffix to avoid conflicts
                        tempvar temp_`var'
                        rename `var' `temp_`var''
                        rename `temp_`var'' `var'_ds`k'
                        local keeplist_k "`keeplist_k' `var'_ds`k'"
                    }
                }
            }
            
            keep `keeplist_k'
            
            * Drop invalid periods where start > stop
            generate double _valid = (start_k <= stop_k) & !missing(start_k, stop_k)
            quietly count if _valid == 0
            local invalid_ds`k' = r(N)
            keep if _valid == 1
            drop _valid
            
            * Sort for merge
            sort id start_k stop_k

            * Check for overlapping intervals in this dataset
            tempvar _overlap_check_k
            by id: gen byte `_overlap_check_k' = (start_k < stop_k[_n-1]) if _n > 1
            quietly count if `_overlap_check_k' == 1
            local n_overlaps_dsk = r(N)
            if `n_overlaps_dsk' > 0 {
                noisily di as text "Warning: Dataset `k' (`ds_k') contains `n_overlaps_dsk' overlapping interval(s) within persons."
                noisily di as text "         Overlapping input may produce unexpected results."
            }
            drop `_overlap_check_k'

            tempfile ds_k_clean
            save `ds_k_clean', replace
            
            * Load merged data
            use `merged_data', clear
            
            **# PERFORM CARTESIAN MERGE OF TIME INTERVALS
            * Create cartesian product of intervals
            tempfile cartesian
            
            * Pre-compute which exposures are continuous (optimization to avoid repeated checks)
            * FIX: Must handle renamed variables - compare original names to continuous_names,
            * then apply result to the renamed variable names in exp_k_list
            foreach exp_var in `exp_k_list' {
                local is_cont_`exp_var' = 0
            }
            * Set continuous flag for the primary exposure of this dataset
            * is_cont_k was computed earlier using original name (exp_k_raw) vs continuous_names
            * exp_k is the renamed version of exp_k_raw
            local is_cont_`exp_k' = `is_cont_k'

            * BATCH PROCESSING: Create numeric sequence for batching
            * This handles string IDs and avoids macro length limits
            use `merged_data', clear

            * VALIDATION: Check that IDs match between merged data and current dataset
            * This prevents silent data loss from joinby dropping mismatched IDs
            tempfile merged_ids ds_k_ids

            * Get unique IDs from merged data (datasets 1 through k-1)
            preserve
            keep id
            sort id
            quietly by id: keep if _n == 1
            save `merged_ids', replace
            restore

            * Get unique IDs from dataset k
            preserve
            use `ds_k_clean', clear
            keep id
            sort id
            quietly by id: keep if _n == 1
            save `ds_k_ids', replace
            restore

            * Check for ID mismatches
            use `merged_ids', clear
            merge 1:1 id using `ds_k_ids', generate(_merge_check)

            * Count mismatches
            quietly count if _merge_check == 1  // In merged_data but not ds_k
            local n_only_merged = r(N)
            quietly count if _merge_check == 2  // In ds_k but not merged_data
            local n_only_dsk = r(N)

            * If mismatches exist, report and either warn or error based on force option
            if `n_only_merged' > 0 | `n_only_dsk' > 0 {
                if "`force'" == "" {
                    * No force option - error out (strict mode)
                    noisily di as error _newline "ID mismatch detected between datasets!"

                    if `n_only_merged' > 0 {
                        noisily di as error "  `n_only_merged' IDs exist in datasets 1-`=`k'-1' but not in dataset `k' (`ds_k'):"
                        noisily list id if _merge_check == 1, noheader sep(0)
                    }

                    if `n_only_dsk' > 0 {
                        noisily di as error "  `n_only_dsk' IDs exist in dataset `k' (`ds_k') but not in datasets 1-`=`k'-1':"
                        noisily list id if _merge_check == 2, noheader sep(0)
                    }

                    noisily di as error _newline "All datasets must contain the same set of IDs."
                    noisily di as error "IDs that don't match across datasets will be silently dropped during merge."
                    noisily di as error "Use the force option to proceed anyway (mismatched IDs will be treated as having no exposure in the missing dataset)."
                    exit 459
                }
                else {
                    * Force option specified - warn and continue
                    noisily di as text _newline "Warning: ID mismatch detected between datasets (proceeding due to force option)"

                    if `n_only_merged' > 0 {
                        noisily di as text "  `n_only_merged' IDs exist in datasets 1-`=`k'-1' but not in dataset `k' (`ds_k')"
                        noisily di as text "  These IDs will be dropped from the merged result."
                    }

                    if `n_only_dsk' > 0 {
                        noisily di as text "  `n_only_dsk' IDs exist in dataset `k' (`ds_k') but not in datasets 1-`=`k'-1'"
                        noisily di as text "  These IDs will be dropped from the merged result."
                    }

                    noisily di as text "  Note: Only IDs present in ALL datasets will appear in the output."

                    * Filter merged_data to keep only IDs present in both datasets
                    keep if _merge_check == 3
                    keep id
                    tempfile valid_ids
                    save `valid_ids', replace

                    use `merged_data', clear
                    merge m:1 id using `valid_ids', keep(match) nogenerate
                    save `merged_data', replace
                }
            }

            * Validation passed - continue with merge
            use `merged_data', clear

            tempvar batch_seq
            egen long `batch_seq' = group(id)

            * Calculate batch parameters
            quietly summarize `batch_seq', meanonly
            local n_unique_ids = r(max)

            * Calculate batch size based on batch() option
            local batch_size = ceil(`n_unique_ids' * (`batch' / 100))
            local n_batches = ceil(`n_unique_ids' / `batch_size')

            noisily di as txt "Processing `n_unique_ids' unique IDs in `n_batches' batches (batch size: `batch_size' IDs = `batch'%)..."

            * Save dataset with the sequence variable for the loop
            save `merged_data', replace

            * Initialize empty result
            clear

            * Process IDs in batches
            forvalues b = 1/`n_batches' {
                local start_seq = ((`b' - 1) * `batch_size') + 1
                local end_seq = `b' * `batch_size'

                noisily di as txt "  Batch `b'/`n_batches'..."

                * 1. Load batch of merged data
                use `merged_data', clear
                quietly keep if `batch_seq' >= `start_seq' & `batch_seq' <= `end_seq'
                tempfile batch_merged
                save `batch_merged', replace

                * 2. Create ID filter list for this batch
                keep id
                sort id
                quietly by id: keep if _n == 1
                tempfile batch_filter
                save `batch_filter', replace

                * 3. Load and filter dataset k
                use `ds_k_clean', clear

                * Use merge to filter (works for string and numeric IDs, no argument limits)
                quietly merge m:1 id using `batch_filter', keep(match) keepusing(id) nogenerate

                tempfile batch_k
                save `batch_k', replace

                * 4. Perform joinby (cartesian product within each ID)
                use `batch_merged', clear

                * Drop the sequence variable so it doesn't interfere
                drop `batch_seq'

                * Save original merged_data interval boundaries before joinby
                * These are needed to correctly proportion continuous exposures from earlier datasets
                generate double _orig_start_merged = `startname'
                generate double _orig_stop_merged = `stopname'

                * Create cartesian product for entire batch
                joinby id using `batch_k'

                * 5. Calculate interval intersection
                generate double new_start = max(`startname', start_k)
                generate double new_stop = min(`stopname', stop_k)

                * Keep only valid intersections (where new_start <= new_stop)
                keep if new_start <= new_stop & !missing(new_start, new_stop)

                * Replace old interval with intersection
                replace `startname' = new_start
                replace `stopname' = new_stop
                drop new_start new_stop

                * 6. For continuous exposures, interpolate values based on overlap duration

                * 6a. First, proportion continuous exposures from EARLIER datasets
                * These exposures have already been proportioned to their current interval size,
                * so we re-proportion them based on how much the merged interval shrunk
                foreach merged_exp in `merged_continuous_exps' {
                    capture confirm variable `merged_exp'
                    if _rc == 0 {
                        * Calculate proportion based on how much the merged interval shrunk
                        * proportion = (new interval size) / (original merged interval size)
                        generate double _proportion = cond(_orig_stop_merged > _orig_start_merged, ///
                            (`stopname' - `startname' + 1) / (_orig_stop_merged - _orig_start_merged + 1), 1)

                        * Ensure proportion doesn't exceed 1 due to floating point rounding
                        replace _proportion = 1 if _proportion > 1 & !missing(_proportion)

                        replace `merged_exp' = `merged_exp' * _proportion
                        drop _proportion
                    }
                }

                * 6b. Then, proportion continuous exposures from dataset k
                foreach exp_var in `exp_k_list' {
                    * Use pre-computed continuous indicator (optimization)
                    if `is_cont_`exp_var'' == 1 {
                        * Calculate proportion as (overlap duration) / (original duration from dataset k)
                        * This correctly pro-rates the exposure value
                        generate double _proportion = cond(stop_k > start_k, (`stopname' - `startname' + 1) / (stop_k - start_k + 1), 1)

                        * Ensure proportion doesn't exceed 1 due to floating point rounding
                        replace _proportion = 1 if _proportion > 1 & !missing(_proportion)

                        replace `exp_var' = `exp_var' * _proportion
                        drop _proportion
                    }
                }

                drop start_k stop_k _orig_start_merged _orig_stop_merged

                * 7. Append batch results to overall results
                * Note: Skip saving if batch produced zero rows (e.g., disjoint time intervals)
                * Variable structure is preserved by keep command even when _N = 0
                * Empty cartesian file is handled by fallback code after batch loop
                if _N > 0 {
                    tempfile batch_result
                    save `batch_result', replace

                    capture confirm file `cartesian'
                    if _rc == 0 {
                        append using `cartesian'
                    }
                    save `cartesian', replace
                }
                else {
                    noisily di as txt "    (batch `b' produced no valid intersections)"
                }
            }

            * Fallback: If all batches produced zero rows (no valid intersections exist),
            * create empty dataset with proper structure
            capture confirm file `cartesian'
            if _rc != 0 {
                use `merged_data', clear
                keep if 1 == 0  // Keep structure but no observations
                generate double `exp_k' = .
                save `cartesian', replace
            }
            
            * Use cartesian result
            use `cartesian', clear

            * Save updated merged data
            save `merged_data', replace

            * Update tracking list: add this dataset's continuous exposure if applicable
            if `is_cont_k' == 1 {
                local merged_continuous_exps "`merged_continuous_exps' `exp_k'"
            }
        }

        * Validate that all keep() variables were found in at least one dataset
        if "`keep'" != "" {
            foreach var in `keep' {
                local var_found: list var in keep_vars_found
                if `var_found' == 0 {
                    di as error "Variable '`var'' specified in keep() was not found in any dataset"
                    exit 111
                }
            }
        }
        
        **# CLEAN UP FINAL DATASET
        
        * Create list of all final exposure variables for validation
        local final_exps ""
        foreach exp_name in `continuous_exps' `categorical_exps' {
            capture confirm variable `exp_name'
            if _rc == 0 {
                local final_exps "`final_exps' `exp_name'"
            }
        }
        
        * Drop exact duplicates (same id, start, stop, and all exposures)
        local dupvars "id `startname' `stopname' `final_exps'"
        quietly count
        local n_before_dedup = r(N)
        if `n_before_dedup' > 0 {
            duplicates drop `dupvars', force
            quietly count
            local n_after_dedup = r(N)
        }
        else {
            local n_after_dedup = 0
        }
        local n_dups = `n_before_dedup' - `n_after_dedup'

        * Sort final dataset
        if _N > 0 {
            sort id `startname' `stopname'
        }
        
        * Apply date format to start and stop
        format `startname' `stopname' `dateformat'
        
        **# CALCULATE DIAGNOSTICS

        * Count unique persons
        if _N > 0 {
            egen long _tag = tag(id)
            quietly count if _tag == 1
            local n_persons = r(N)
            drop _tag

            * Calculate average and max periods per person
            by id: generate long _nper = _N
            quietly summarize _nper, meanonly
            local avg_periods = r(mean)
            local max_periods = r(max)
            drop _nper
        }
        else {
            local n_persons = 0
            local avg_periods = 0
            local max_periods = 0
        }
        
        * Validate coverage if requested
        * This checks for gaps in coverage within each person's time span
        if "`validatecoverage'" != "" & _N > 0 {
            * Check for gaps between consecutive periods
            bysort id (`startname'): generate double _gap = `startname'[_n] - `stopname'[_n-1] if _n > 1
            
            * Store count of gaps > 1 day for display
            quietly count if _gap > 1 & !missing(_gap)
            local n_gaps = r(N)
            
            * Save gap records for later display if gaps found
            if `n_gaps' > 0 {
                tempfile gaps_data gaps_temp
                save `gaps_temp', replace
                keep if _gap > 1 & !missing(_gap)
                save `gaps_data', replace
                quietly use `gaps_temp', clear
            }
            drop _gap
        }
        
        * Validate overlaps if requested
        * Checks for unexpected overlapping periods within person
        * Note: In cartesian merges, overlaps are expected when exposure combinations differ
        * This diagnostic flags overlaps with IDENTICAL exposure values (likely errors)
        if "`validateoverlap'" != "" {
            * Check if any period starts before previous one ends
            by id (`startname'): generate double _overlap = `startname'[_n] < `stopname'[_n-1] if _n > 1
            
            * For overlaps, check if exposure values are identical (unexpected)
            * If exposure values differ, overlap is expected in cartesian merge
            generate double _same_exposures = 1 if _overlap == 1
            foreach exp_varname in `final_exps' {
                capture confirm variable `exp_varname'
                if _rc == 0 {
                    by id (`startname'): replace _same_exposures = 0 ///
                        if _overlap == 1 & `exp_varname'[_n] != `exp_varname'[_n-1]
                }
            }
            
            * Only flag overlaps with identical exposure values as unexpected
            replace _overlap = 0 if _overlap == 1 & _same_exposures == 0
            
            * Store count of unexpected overlaps for display
            quietly count if _overlap == 1
            local n_overlaps = r(N)
            
            * Save overlap records for later display if overlaps found
            if `n_overlaps' > 0 {
                tempfile overlap_data overlap_temp
                save `overlap_temp', replace
                keep if _overlap == 1
                save `overlap_data', replace
                quietly use `overlap_temp', clear
            }
            drop _overlap _same_exposures
        }
        
        * Display summary statistics if requested
        if "`summarize'" != "" {
            quietly summarize `startname' `stopname', detail format 
            local summary_display = 1
        }
        
        tempfile current
        * Save finalized merged dataset for use outside quietly block
        save `current', replace
        
        **# STORE RETURN RESULTS

        * Store scalar results
        return scalar N = _N

        if _N > 0 {
            * Count and store unique persons
            egen long _tag = tag(id)
            quietly count if _tag == 1
            return scalar N_persons = r(N)
            drop _tag

            * Calculate and store periods per person statistics
            by id: generate long _per = _n
            by id: generate long _per_max = _N
            quietly summarize _per, meanonly
            return scalar mean_periods = r(mean)
            quietly summarize _per_max, meanonly
            return scalar max_periods = r(max)
            drop _per _per_max
        }
        else {
            return scalar N_persons = 0
            return scalar mean_periods = 0
            return scalar max_periods = 0
        }

        * Store number of merged datasets
        return scalar N_datasets = `numds'
        
        * Store macro results
        return local datasets "`datasets'"
        return local exposure_vars "`final_exps'"
        return local startname "`startname'"
        return local stopname "`stopname'"
        return local dateformat "`dateformat'"
        
        * Store naming options if used
        if "`prefix'" != "" {
            return local prefix "`prefix'"
        }
        if "`generate'" != "" {
            return local generated_names "`generate'"
        }
        
        * Store continuous and categorical exposure information
        if "`continuous'" != "" {
            return local continuous_vars "`continuous_exps'"
            return scalar n_continuous = `n_continuous'
        }
        if `n_categorical' > 0 {
            return local categorical_vars "`categorical_exps'"
            return scalar n_categorical = `n_categorical'
        }
        
        * Save dataset if requested
        if "`saveas'" != "" {
            if "`replace'" == "" {
                quietly save "`saveas'"
                return local output_file "`saveas'"
            }
            else {
                quietly save "`saveas'", replace
                return local output_file "`saveas'"
            }
        }
    
    }
    
    **# DISPLAY SUMMARY OUTPUT
    * Print completion summary outside of quietly block
    
    * Ensure merged dataset is in memory for all display operations
    quietly use `current', clear
    
    * Display invalid period warnings if found
    if !missing("`invalid_ds1'") & `invalid_ds1' > 0 {
        di in re "Found `invalid_ds1' rows in `first_ds' where start > stop (will skip)"
    }
    forvalues k = 2/`numds' {
        if !missing("`invalid_ds`k''") & `invalid_ds`k'' > 0 {
            local ds_k: word `k' of `datasets'
            di in re "Found `invalid_ds`k'' rows in `ds_k' where start > stop (will skip)"
        }
    }
    
    * Display duplicates info if any were dropped
    if `n_dups' > 0 {
        di in re "Dropped `n_dups' duplicate interval+exposure combinations"
    }
    
    * Display coverage diagnostics if requested
    if "`check'" != "" {
        di _newline
        noisily display as text "{hline 50}"
        noisily di as txt "Coverage Diagnostics:"
        noisily di as txt "    Number of persons: `n_persons'"
        noisily di as txt "    Average periods per person: `=round(`avg_periods',0.01)'"
        noisily di as txt "    Max periods per person: `max_periods'"
        noisily di as txt "    Total merged intervals: `=return(N)'"
        noisily display as text "{hline 50}"
    }
    
    * Display coverage validation if requested
    if "`validatecoverage'" != "" {
        di _newline
        noisily display as text "{hline 50}"
        di as txt "{it:Validating coverage...}"
        if `n_gaps' > 0 {
            di in re "Found `n_gaps' gaps in coverage (>1 day gaps)"
            quietly use `gaps_data', clear
            noisily list id `startname' `stopname' _gap if _gap > 1 & !missing(_gap), sep(20)
            quietly use `current', clear
            noisily display as text "{hline 50}"
        }
        else {
            di as txt "No gaps >1 day found in coverage."
            noisily display as text "{hline 50}"
        }
    }

    * Display overlap validation if requested
    if "`validateoverlap'" != "" {
        di _newline
        noisily display as text "{hline 50}"
        di as txt "{it:Validating overlaps...}"
        if `n_overlaps' > 0 {
            di in re "Found `n_overlaps' unexpected overlapping periods (same interval, same exposures)"
            quietly use `overlap_data', clear
            noisily list id `startname' `stopname' if _overlap == 1, sep(20)
            quietly use `current', clear
            noisily display as text "{hline 50}"
        }
        else {
            di as txt "No unexpected overlaps found."
            noisily display as text "{hline 50}"
        }
    }
    
    * Display summary statistics if requested
    if "`summarize'" != "" {
        di _newline
        noisily display as text "{hline 50}"
        di as txt "Summary Statistics:"
        noisily summarize `startname' `stopname', detail format 
        noisily display as text "{hline 50}"
        di _newline
    }
    
    * Store return values in local macros for proper display
    local obs = return(N)
    local npersons = return(N_persons)
    local exp_vars = return(exposure_vars)
    
    di as result _newline "{bf:Merged time-varying dataset successfully created}"
    noisily display as text "{hline 50}"
    di as txt "    Observations: " as result %14.0fc `obs'
    di as txt "    Persons: " as result %14.0fc `npersons'
    di as txt "    Exposure variables: " as result "`exp_vars'"
    noisily display as text "{hline 50}"

end
