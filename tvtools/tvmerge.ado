*! tvmerge v1.0.0
*! Merge multiple time-varying exposure datasets
*! Author: Tim Copeland
*! Date: 2025-11-17
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

IMPORTANT: This program replaces the current dataset in memory with the merged result.
Use the saveas() option to save the result to a file, or load your original data
from a saved file before running if you need to preserve it.

EXPOSURE TYPES:
- Categorical (default): Creates cartesian product of all exposure combinations
- Continuous: Treats exposure as rate per day
*/

program define tvmerge, rclass

    version 16.0
    
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
    foreach ds in `datasets' {
        capture confirm file "`ds'.dta"
        if _rc != 0 {
            di as error "Dataset file not found: `ds'.dta"
            exit 601
        }
        * Also verify it's a valid Stata dataset
        capture use "`ds'.dta" in 1, clear
        if _rc != 0 {
            di as error "`ds'.dta is not a valid Stata dataset or cannot be read"
            exit 610
        }
    }
    restore
    
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

    if `numsv' != `numds' | `numst' != `numds' {
        di as error "Number of start() and stop() variables must equal number of datasets"
        exit 198
    }

    local starts "`start'"
    local stops "`stop'"
    
    * Get unique exposure variable names (handles duplicates across datasets)
    local exposures_raw "`exposure'"
    local exposures: list uniq exposures_raw
    local numexp: word count `exposures'
    
    * Check for duplicate exposure variable names
    local numexp_raw: word count `exposures_raw'
    if `numexp' < `numexp_raw' {
        di as error "Duplicate exposure variable names detected across datasets."
        di as error "Each dataset must have a unique exposure variable name."
        di as error "Use the generate() option to specify unique names for each exposure variable."
        exit 198
    }
    
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

    * Process by datasets to get final exposure names
    forvalues j = 1/`numds' {
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
        tempfile merged_data
        save `merged_data', replace
        
        **# PROCESS ADDITIONAL DATASETS AND MERGE
        * Process each additional dataset
        forvalues k = 2/`numds' {
            local ds_k: word `k' of `datasets'
            use "`ds_k'", clear

            * Get variable names for this dataset
            local start_k: word `k' of `starts'
            local stop_k: word `k' of `stops'
            local exp_k_raw: word `k' of `exposures_raw'
            
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
            
            * Verify required variables exist
            capture confirm variable `id'
            if _rc != 0 {
                di as error "Variable `id' not found in `ds_k'"
                exit 111
            }
            capture confirm variable `start_k'
            if _rc != 0 {
                di as error "Variable `start_k' not found in `ds_k'"
                exit 111
            }
            capture confirm variable `stop_k'
            if _rc != 0 {
                di as error "Variable `stop_k' not found in `ds_k'"
                exit 111
            }
            capture confirm variable `exp_k_raw'
            if _rc != 0 {
                di as error "Variable `exp_k_raw' not found in `ds_k'"
                exit 111
            }
            
            * Rename to standard names
            rename `id' id
            rename `start_k' start_k
            rename `stop_k' stop_k
            
            * Floor start dates and ceil stop dates to handle fractional date values
            replace start_k = floor(start_k)
            replace stop_k = ceil(stop_k)
            
            * Apply new exposure name if specified
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
            
            * Keep only necessary variables
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
            tempfile ds_k_clean
            save `ds_k_clean', replace
            
            * Load merged data
            use `merged_data', clear
            
            **# PERFORM CARTESIAN MERGE OF TIME INTERVALS
            * Create cartesian product of intervals
            tempfile cartesian
            
            * Pre-compute which exposures are continuous (optimization to avoid repeated checks)
            foreach exp_var in `exp_k_list' {
                local is_cont_`exp_var' = 0
                foreach cont_name in `continuous_names' {
                    if "`exp_var'" == "`cont_name'" {
                        local is_cont_`exp_var' = 1
                    }
                }
            }

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
            generate byte _in_merged = 1
            merge 1:1 id using `ds_k_ids', generate(_merge_check)

            * Count mismatches
            quietly count if _merge_check == 1  // In merged_data but not ds_k
            local n_only_merged = r(N)
            quietly count if _merge_check == 2  // In ds_k but not merged_data
            local n_only_dsk = r(N)

            * If mismatches exist, report and error out
            if `n_only_merged' > 0 | `n_only_dsk' > 0 {
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
                noisily di as error "Please ensure all datasets contain the same person IDs before merging."
                exit 459  // "variable not found or ambiguous abbreviation" - close to ID mismatch concept
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

                * 6. For continuous exposures, interpolate values based on time elapsed
                foreach exp_var in `exp_k_list' {
                    * Use pre-computed continuous indicator (optimization)
                    if `is_cont_`exp_var'' == 1 {
                        * Calculate cumulative proportion (progress to date)
                        * Uses (Current_End_Date - Original_Start_Date) / Total_Original_Duration
                        generate double _proportion = cond(stop_k > start_k, (`stopname' - start_k) / (stop_k - start_k), 1)

                        * Ensure proportion doesn't exceed 1 due to floating point rounding
                        replace _proportion = 1 if _proportion > 1 & !missing(_proportion)

                        replace `exp_var' = `exp_var' * _proportion
                        drop _proportion
                    }
                }

                drop start_k stop_k

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
        duplicates drop `dupvars', force
        quietly count
        local n_after_dedup = r(N)
        local n_dups = _N - `n_after_dedup'
        
        * Sort final dataset
        sort id `startname' `stopname'
        
        * Apply date format to start and stop
        format `startname' `stopname' `dateformat'
        
        **# CALCULATE DIAGNOSTICS
        
        * Count unique persons
        egen double _tag = tag(id)
        quietly count if _tag == 1
        local n_persons = r(N)
        drop _tag
        
        * Calculate average and max periods per person
        by id: generate double _nper = _N
        quietly summarize _nper, meanonly
        local avg_periods = r(mean)
        local max_periods = r(max)
        drop _nper
        
        * Validate coverage if requested
        * This checks for gaps in coverage within each person's time span
        if "`validatecoverage'" != "" {
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
        
        * Count and store unique persons
        egen double _tag = tag(id)
        quietly count if _tag == 1
        return scalar N_persons = r(N)
        drop _tag
        
        * Calculate and store periods per person statistics
        by id: generate double _per = _n
        by id: generate double _per_max = _N
        quietly summarize _per, meanonly
        return scalar mean_periods = r(mean)
        quietly summarize _per_max, meanonly
        return scalar max_periods = r(max)
        drop _per _per_max
        
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
            noisily list `id' `startname' `stopname' _gap if _gap > 1 & !missing(_gap), sep(20)
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
            noisily list `id' `startname' `stopname' if _overlap == 1, sep(20)
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
