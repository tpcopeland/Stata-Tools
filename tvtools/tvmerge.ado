*! tvmerge Version 1.7.0  2026/07/13
*! Merge multiple time-varying exposure datasets
*! Author: Timothy P Copeland, Karolinska Institutet
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
  rate(namelist)       - Rates per day; values are unchanged when intervals split
  total(namelist)      - Interval totals; values are apportioned when intervals split
  cumulative(namelist) - Row-start cumulative histories; values are carried unchanged
  continuous(namelist) - Deprecated alias for total()
                         Quantity options accept positions or variable names

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
  batch(#)           - Deprecated compatibility option; accepted and ignored

ID matching options:
  force              - Allow merging datasets with non-matching IDs (issues warning)
                       By default, tvmerge errors if IDs don't match across all datasets.
                       With force, mismatched IDs are dropped with a warning.
                       Useful when merging exposure data that is a subset of a cohort.

IMPORTANT: By default this program replaces the current dataset in memory with
the merged result. frameout() instead places the result in a named frame and
leaves the current data intact. saveas() additionally writes the result to disk.

EXPOSURE TYPES:
- Categorical (default): Creates cartesian product of all exposure combinations
- Rate: unchanged when an interval is sliced
- Total: apportioned by inclusive overlap duration
- Cumulative: row-start history carried unchanged
*/

program define tvmerge, rclass

    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _frameout_snap_taken = 0    // init before block for error-path restore
    local _caller_zero_var_obs = 0
    local _caller_snapshot_ready = 0
    local _tvm_diag_master ""
    local _tvm_diag_using ""
    local _tvm_diag_out ""
    local _tvm_work_master ""
    local _tvm_work_using ""
    local _tvm_work_out ""

    capture noisily {

    * Load the compiled interval-overlap engine (Mata sweep for the merge core)
    capture findfile _tvmerge_mata.ado
    if _rc == 0 {
        quietly run "`r(fn)'"
    }
    else {
        noisily display as error "_tvmerge_mata.ado not found; reinstall tvtools"
        exit 111
    }

    **# SYNTAX DECLARATION

    syntax [anything(name=datasets)], ///
        id(name) ///
        STart(namelist) STOP(namelist) EXPosure(namelist) ///
        [FRames(namelist) ///
         GENerate(namelist) ///
         PREfix(string) ///
         STARTname(string) ///
         STOPname(string) ///
         DATEformat(string) ///
         SAVeas(string) ///
         FRAMEOut(name) ///
         REPlace ///
         KEEP(namelist) ///
         CONtinuous(string asis) ///
         RAte(string asis) ///
         TOTal(string asis) ///
         CUMulative(string asis) ///
         DROPInvalid ///
         Batch(integer -1) ///
         FORCE ///
         CHECK VALIDATEcoverage VALIDATEoverlap SUMmarize ///
         FLOW ///
         VERBose]
    
    **# INPUT VALIDATION AND SETUP
    
    * Check for by: usage - tvmerge cannot be used with by:
    if "`_byvars'" != "" {
        di as error "tvmerge cannot be used with by:"
        exit 190
    }

    * Frames input: materialize each named frame to a tempfile and feed the
    * existing file-based pipeline unchanged. This removes the save/use/rename
    * round-trip when inputs are already held in memory as frames.
    if "`frames'" != "" {
        if `"`datasets'"' != "" {
            di as error "specify either file paths or frames(), not both"
            exit 198
        }
        foreach fr of local frames {
            capture confirm frame `fr'
            if _rc {
                di as error "frame not found: `fr'"
                exit 111
            }
            tempfile _frfile
            quietly frame `fr': save "`_frfile'", replace
            local datasets "`datasets' `_frfile'"
        }
    }

    * Frames-first output: when frameout() is set, the merged result is placed
    * into the named frame and the caller's current data is left intact. Snapshot
    * the caller's data now (before any preserve/restore work) and reload it after
    * copying the result into the target frame.
    if "`frameout'" != "" {
        capture frame `frameout': describe
        if _rc == 0 & "`replace'" == "" {
            di as error "frame `frameout' already exists; use replace option"
            exit 110
        }
    }

    * Success replaces the data in memory unless frameout() is requested;
    * failure must leave the caller's pre-command data untouched in both modes.
    if c(k) > 0 {
        tempfile _tvm_caller_snap
        quietly save "`_tvm_caller_snap'", replace
        local _frameout_snap_taken = 1
    }
    else if _N > 0 {
        * Stata cannot save a dataset that has observations but zero variables.
        * Its complete restorable state is therefore just the observation count.
        local _caller_zero_var_obs = _N
    }
    local _caller_snapshot_ready = 1

    * Parse and validate dataset count
    local numds: word count `datasets'
    if `numds' < 2 {
        di as error "tvmerge requires at least 2 datasets"
        exit 198
    }
    
    * Validate variable name lengths (Stata allows up to 32 characters)
    * Check single-value options
    foreach opt in id startname stopname prefix {
        if "``opt''" != "" {
            local len = strlen("``opt''")
            if `len' > 32 {
                noisily display as error "Variable name too long: ``opt'' (`len' characters)"
                noisily display as error "Stata variable names must be 32 characters or fewer"
                exit 198
            }
        }
    }
    * Check list-value options
    foreach opt in start stop exposure generate {
        foreach v of local `opt' {
            local len = strlen("`v'")
            if `len' > 32 {
                noisily display as error "Variable name too long: `v' (`len' characters)"
                noisily display as error "Stata variable names must be 32 characters or fewer"
                exit 198
            }
        }
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
    
    * Internal variable names used during merge processing
    local reserved_names "start_k stop_k id new_start new_stop _valid _gap _overlap _same_exposures _tag _nper _per _per_max _first _orig_start_merged _orig_stop_merged"
    local reserved_names "`reserved_names' __tvm_gid __tvm_mobs __tvm_uobs __tvm_mi __tvm_ui"
    local reserved_names "`reserved_names' __tvm_mpattern __tvm_mid __tvm_mstart __tvm_mstop __tvm_upattern __tvm_uid __tvm_ustart __tvm_ustop"

    * Validate generate() names and count
    if "`generate'" != "" {
        local ngen: word count `generate'
        if `ngen' != `numds' {
            di as error "generate() must contain exactly `numds' names (one per dataset)"
            exit 198
        }
        local duplicate_generate : list dups generate
        if "`duplicate_generate'" != "" {
            di as error "generate() contains duplicate output name(s):`duplicate_generate'"
            exit 198
        }
        foreach gname in `generate' {
            capture confirm name `gname'
            if _rc != 0 {
                di as error "generate() contains invalid name: `gname'"
                exit 198
            }
            local gen_conflict: list gname in reserved_names
            if `gen_conflict' {
                di as error "generate() name '`gname'' conflicts with internal variable name"
                di as error "Please choose a different name"
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

    * batch() is deprecated and ignored. The Mata interval-overlap engine
    * intersects intervals directly without materialising the within-person
    * Cartesian product, so batched I/O is no longer needed. The option is still
    * accepted (no-op) so existing scripts do not break.
    if `batch' != -1 {
        noisily di as text "Note: batch() is deprecated and ignored (the Mata merge engine no longer batches)."
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
    * Skip this check when generate() is provided, since generate() renames the variables
    local exposures_raw "`exposure'"
    local numexp_raw: word count `exposures_raw'

    * Structural roles must be distinct within each positional source. The ID
    * exists in every source; a bound or exposure with the same name would be
    * consumed by an earlier rename and fail only after the file was opened.
    forvalues ds_index = 1/`numds' {
        local role_start : word `ds_index' of `starts'
        local role_stop : word `ds_index' of `stops'
        local role_exposure : word `ds_index' of `exposures_raw'
        local role_names "`id' `role_start' `role_stop' `role_exposure'"
        local duplicate_roles : list dups role_names
        if "`duplicate_roles'" != "" {
            di as error "Dataset `ds_index' reuses a variable across id(), start(), stop(), or exposure():`duplicate_roles'"
            exit 198
        }
    }

    if "`generate'" == "" {
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
            * Auto-suffix duplicate exposure output names by position instead of
            * erroring. This covers inputs that deliberately share an exposure
            * name (including tvexpose's safe fallback name). Only applies in the
            * standard one-exposure-per-dataset case (numexp == numds); the
            * advanced multi-exposure case still requires explicit generate().
            if `numexp_raw' == `numds' {
                local generate ""
                local pos = 0
                foreach exp_name in `exposures_raw' {
                    local ++pos
                    local nocc = 0
                    foreach e2 in `exposures_raw' {
                        if "`e2'" == "`exp_name'" local ++nocc
                    }
                    local output_base "`exp_name'"
                    if "`prefix'" != "" local output_base "`prefix'`exp_name'"
                    if `nocc' > 1 {
                        local generate "`generate' `output_base'_`pos'"
                    }
                    else {
                        local generate "`generate' `output_base'"
                    }
                }
                * Guard the synthesized names against internal reserved names
                foreach gname in `generate' {
                    local gen_conflict: list gname in reserved_names
                    if `gen_conflict' {
                        di as error "auto-suffixed name '`gname'' conflicts with internal variable name"
                        di as error "Use the generate() option to choose distinct names"
                        exit 198
                    }
                }
                display as text "Note: duplicate exposure name(s) auto-suffixed by position: `generate'"
            }
            else {
                di as error "Duplicate exposure variable name '`dup_name'' specified multiple times."
                di as error "Each position in exposure() must have a unique name."
                di as error "Use the generate() option to rename exposures if datasets have same variable names."
                exit 198
            }
        }
    }

    * Preflight every final exposure name before any source data are loaded.
    * Structural bounds, the ID, and keep()'s deterministic _ds# outputs are
    * protected: accepting any collision would overwrite or silently lose data.
    local final_name_candidates ""
    if "`generate'" != "" {
        local final_name_candidates "`generate'"
    }
    else if "`prefix'" != "" {
        foreach exp_name of local exposures_raw {
            local final_name_candidates "`final_name_candidates' `prefix'`exp_name'"
        }
    }
    else {
        local final_name_candidates "`exposures_raw'"
    }

    local duplicate_final_names : list dups final_name_candidates
    if "`duplicate_final_names'" != "" {
        di as error "Exposure output names are not unique:`duplicate_final_names'"
        di as error "Use generate() to choose distinct output names."
        exit 198
    }

    * keep() variables are copied as <name>_ds#. Validate both the source role
    * and every derived output name now, before opening any source dataset.
    * Structural variables cannot also be payload because the merge renames or
    * consumes them internally.
    local structural_input_names "`id' `starts' `stops' `exposures_raw'"
    local structural_input_names : list uniq structural_input_names
    local keep_output_names ""
    if "`keep'" != "" {
        foreach keepvar of local keep {
            local keep_is_structural : list keepvar in structural_input_names
            if `keep_is_structural' {
                di as error "keep() variable '`keepvar'' is an ID, bound, or exposure variable"
                exit 198
            }
            forvalues ds_index = 1/`numds' {
                local keep_output "`keepvar'_ds`ds_index'"
                capture confirm name `keep_output'
                if _rc != 0 | strlen("`keep_output'") > 32 {
                    di as error "keep() produces invalid or overlength output name: `keep_output'"
                    exit 198
                }
                local keep_internal_collision : list keep_output in reserved_names
                if `keep_internal_collision' {
                    di as error "keep() output name '`keep_output'' conflicts with an internal variable"
                    exit 198
                }
                local keep_structural_outputs "id `startname' `stopname'"
                local keep_structural_collision : list keep_output in keep_structural_outputs
                if `keep_structural_collision' {
                    di as error "keep() output name '`keep_output'' conflicts with an output ID or bound"
                    exit 198
                }
                local keep_output_names "`keep_output_names' `keep_output'"
            }
        }
    }
    local duplicate_keep_names : list dups keep_output_names
    if "`duplicate_keep_names'" != "" {
        di as error "keep() produces duplicate output name(s):`duplicate_keep_names'"
        exit 198
    }

    local protected_output_names "id `id' `startname' `stopname' `keep_output_names'"
    local protected_output_names : list uniq protected_output_names

    foreach out_name of local final_name_candidates {
        capture confirm name `out_name'
        if _rc != 0 | strlen("`out_name'") > 32 {
            di as error "Invalid or overlength exposure output name: `out_name'"
            exit 198
        }
        local output_collision : list out_name in protected_output_names
        if `output_collision' {
            di as error "Exposure output name '`out_name'' conflicts with a protected output variable"
            exit 198
        }
        local internal_collision : list out_name in reserved_names
        if `internal_collision' {
            di as error "Exposure output name '`out_name'' conflicts with an internal variable"
            exit 198
        }
    }

    local exposures "`exposures_raw'"
    local numexp: word count `exposures'
    
    * Quantity algebra is explicit. continuous() remains a compatibility alias
    * for the historical proportional-allocation behavior, now named total().
    if "`continuous'" != "" {
        noisily display as text ///
            "Warning: continuous() is deprecated; use total() for interval totals."
        local total "`total' `continuous'"
    }

    foreach quantity in rate total cumulative {
        local `quantity'_positions ""
        local `quantity'_names ""
        foreach item of local `quantity' {
            capture confirm integer number `item'
            if _rc == 0 {
                if `item' < 1 | `item' > `numexp' {
                    di as error "`quantity'() position `item' out of range (1-`numexp')"
                    exit 198
                }
                local `quantity'_positions "``quantity'_positions' `item'"
                local exp_at_pos : word `item' of `exposures'
                local `quantity'_names "``quantity'_names' `exp_at_pos'"
            }
            else {
                local found_exp = 0
                forvalues j = 1/`numexp' {
                    local exp_j : word `j' of `exposures'
                    if "`item'" == "`exp_j'" {
                        local `quantity'_positions "``quantity'_positions' `j'"
                        local `quantity'_names "``quantity'_names' `item'"
                        local found_exp = 1
                    }
                }
                if `found_exp' == 0 {
                    di as error "`quantity'() exposure `item' not found in exposure()"
                    exit 198
                }
            }
        }
        local `quantity'_positions : list uniq `quantity'_positions
        local `quantity'_names : list uniq `quantity'_names
    }

    * Preserve the legacy alias subset separately for truthful compatibility
    * returns when total() and continuous() are supplied together.
    local continuous_positions ""
    foreach item of local continuous {
        capture confirm integer number `item'
        if _rc == 0 {
            local continuous_positions "`continuous_positions' `item'"
        }
        else {
            forvalues j = 1/`numexp' {
                local exp_j : word `j' of `exposures'
                if "`item'" == "`exp_j'" {
                    local continuous_positions "`continuous_positions' `j'"
                }
            }
        }
    }
    local continuous_positions : list uniq continuous_positions

    * A variable has one algebra only. Check by exposure position so duplicate
    * source variable names (which are auto-suffixed) remain unambiguous.
    forvalues j = 1/`numexp' {
        local n_quantity_assignments = 0
        foreach quantity in rate total cumulative {
            local in_quantity : list j in `quantity'_positions
            if `in_quantity' local ++n_quantity_assignments
        }
        if `n_quantity_assignments' > 1 {
            local exp_j : word `j' of `exposures'
            di as error "Exposure `j' (`exp_j') appears in more than one of rate(), total(), and cumulative()"
            exit 198
        }
    }

    * The legacy downstream names refer only to totals, because those are the
    * quantities that must be apportioned when an interval is sliced.
    local n_rate : word count `rate_positions'
    local n_total : word count `total_positions'
    local n_cumulative : word count `cumulative_positions'
    local n_continuous : word count `continuous_positions'
    local n_categorical = `numexp' - `n_rate' - `n_total' - `n_cumulative'

    * Build final exposure lists by quantity type.
    local rate_exps ""
    local total_exps ""
    local cumulative_exps ""
    local continuous_exps ""
    local categorical_exps ""

    * Process by exposure variables to get final exposure names
    * Note: Loop through ALL exposure variables, not just dataset count
    forvalues j = 1/`numexp_raw' {
        local exp_j: word `j' of `exposures_raw'
        
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
        
        local is_rate : list j in rate_positions
        local is_total : list j in total_positions
        local is_cumulative : list j in cumulative_positions
        local is_continuous_alias : list j in continuous_positions

        if `is_rate' {
            local rate_exps: list rate_exps | exp_name
        }
        else if `is_total' {
            local total_exps: list total_exps | exp_name
            if `is_continuous_alias' {
                local continuous_exps: list continuous_exps | exp_name
            }
        }
        else if `is_cumulative' {
            local cumulative_exps: list cumulative_exps | exp_name
        }
        else {
            local categorical_exps: list categorical_exps | exp_name
        }
    }
    
    * Initialize tracking for keep() variables
    if "`keep'" != "" {
        local keep_vars_found ""
    }

    * Aggregate malformed-input accounting across all source datasets.
    local n_invalid = 0
    local n_invalid_id = 0
    local n_invalid_dates = 0
    local n_invalid_order = 0
    local n_invalid_exposure = 0
    local n_forced_id_drops = 0

    * All option, naming, and quantity checks above are source-independent.
    * Only after they pass do we touch the input files, so a malformed request
    * cannot be masked by (or incur) an unrelated file-access failure.
    preserve
    local validation_error = 0
    local error_msg ""
    local error_code = 0

    foreach ds in `datasets' {
        * Try the supplied path first (including tempfile paths without .dta),
        * then the conventional .dta suffix.
        local ds_file "`ds'"
        capture confirm file "`ds_file'"
        if _rc != 0 {
            if substr("`ds'", -4, .) != ".dta" {
                local ds_file "`ds'.dta"
                capture confirm file "`ds_file'"
            }
            if _rc != 0 {
                local validation_error = 1
                local error_msg "Dataset file not found: `ds'"
                local error_code = 601
                continue, break
            }
        }
        capture use "`ds_file'", clear
        if _rc != 0 {
            local validation_error = 1
            local error_msg "`ds_file' is not a valid Stata dataset or cannot be read"
            local error_code = 610
            continue, break
        }
        * strL IDs cannot be merge keys. Existence is checked here so flow
        * accounting below cannot fail with a cryptic use-varlist error.
        capture confirm variable `id'
        if _rc != 0 {
            local validation_error = 1
            local error_msg "id() variable `id' not found in `ds'"
            local error_code = 111
            continue, break
        }
        local _tvm_idtype : type `id'
        if "`_tvm_idtype'" == "strL" {
            local validation_error = 1
            local error_msg "id() variable `id' is strL in `ds'; strL variables cannot be used as merge keys -- recast to str# first"
            local error_code = 109
            continue, break
        }
    }
    restore

    if `validation_error' {
        di as error "`error_msg'"
        exit `error_code'
    }

    * Flow accounting is collected up front. It is returned on request and
    * mandatorily whenever dropinvalid or force removes input records/persons.
    preserve
        local _flow_rin = 0
        tempfile _flow_ids
        local _flow_first = 1
        foreach ds in `datasets' {
            local _dsf "`ds'"
            capture confirm file "`_dsf'"
            if _rc & substr("`ds'", -4, .) != ".dta" local _dsf "`ds'.dta"
            quietly use `id' using "`_dsf'", clear
            local _flow_rin = `_flow_rin' + _N
            if `_flow_first' {
                quietly save "`_flow_ids'", replace
                local _flow_first = 0
            }
            else {
                quietly append using "`_flow_ids'"
                quietly save "`_flow_ids'", replace
            }
        }
        quietly use "`_flow_ids'", clear
        tempvar _flow_t
        quietly egen byte `_flow_t' = tag(`id') if !missing(`id')
        quietly count if `_flow_t' == 1
        local _flow_pin = r(N)
    restore
    
    **# MAIN PROCESSING
    quietly {
        
        **# LOAD AND PREPARE FIRST DATASET
        * Process first dataset as base
        local first_ds: word 1 of `datasets'
        use "`first_ds'", clear
        
        * CRITICAL FIX: Ensure all new variables use double type
        capture confirm variable `id'
        if _rc != 0 {
            noisily di as error "Variable `id' not found in `first_ds'"
            exit 111
        }
        
        local start1: word 1 of `starts'
        local stop1: word 1 of `stops'
        capture confirm variable `start1'
        if _rc != 0 {
            noisily di as error "Variable `start1' not found in `first_ds'"
            exit 111
        }
        capture confirm variable `stop1'
        if _rc != 0 {
            noisily di as error "Variable `stop1' not found in `first_ds'"
            exit 111
        }
        capture confirm numeric variable `start1'
        if _rc != 0 {
            noisily di as error "start() variable `start1' in dataset 1 must be numeric daily dates"
            exit 109
        }
        capture confirm numeric variable `stop1'
        if _rc != 0 {
            noisily di as error "stop() variable `stop1' in dataset 1 must be numeric daily dates"
            exit 109
        }
        
        local exp1: word 1 of `exposures_raw'
        capture confirm variable `exp1'
        if _rc != 0 {
            noisily di as error "Variable `exp1' not found in `first_ds'"
            exit 111
        }
        local exp1_is_quantity = 0
        local _position_one "1"
        foreach quantity_positions in rate_positions total_positions cumulative_positions {
            local first_in_quantity : list _position_one in `quantity_positions'
            if `first_in_quantity' local exp1_is_quantity = 1
        }
        if `exp1_is_quantity' {
            capture confirm numeric variable `exp1'
            if _rc != 0 {
                noisily di as error "Quantity variable `exp1' in dataset 1 must be numeric"
                exit 109
            }
        }
        local declared_quantity1 ""
        foreach quantity in rate total cumulative {
            local first_in_quantity : list _position_one in `quantity'_positions
            if `first_in_quantity' local declared_quantity1 "`quantity'"
        }
        local source_quantity1 : char `exp1'[tvtools_quantity]
        if "`source_quantity1'" != "" {
            if !inlist("`source_quantity1'", "rate", "total", "cumulative") {
                noisily di as error "Unknown tvtools_quantity metadata for `exp1': `source_quantity1'"
                exit 498
            }
            if "`declared_quantity1'" == "" {
                noisily di as error "Quantity metadata for `exp1' is `source_quantity1'; declare the matching `source_quantity1'() option"
                exit 498
            }
            if "`declared_quantity1'" != "`source_quantity1'" {
                noisily di as error "Quantity metadata conflict for `exp1': source is `source_quantity1', option declares `declared_quantity1'"
                exit 498
            }
        }
        if "`declared_quantity1'" == "cumulative" {
            local source_history1 : char `exp1'[tvtools_history_point]
            if "`source_history1'" != "start" {
                noisily di as error "Cumulative variable `exp1' must declare char tvtools_history_point start"
                exit 498
            }
        }

        * Non-positional exposures are only read from datasets 2+; warn if the
        * user placed extra exposure() variables in dataset 1, where they are
        * silently dropped by the keep below.
        local _ds1_extra ""
        foreach _possible_exp in `exposures_raw' {
            if "`_possible_exp'" != "`exp1'" {
                capture confirm variable `_possible_exp'
                if _rc == 0 {
                    local _ds1_extra "`_ds1_extra' `_possible_exp'"
                }
            }
        }
        local _ds1_extra: list uniq _ds1_extra
        if "`_ds1_extra'" != "" {
            noisily di as text "Warning: exposure variable(s)`_ds1_extra' found in dataset 1 are ignored."
            noisily di as text "         Non-positional exposure() variables are read from datasets 2 onward."
        }

        * Rename variables to standard names
        rename `id' id
        rename `start1' `startname'
        rename `stop1' `stopname'
        
        * Check for datetime formats (%tc, %tC) - these will silently corrupt results
        local _start_fmt : format `startname'
        local _stop_fmt : format `stopname'
        if substr("`_start_fmt'", 1, 3) == "%tc" | substr("`_start_fmt'", 1, 3) == "%tC" {
            noisily display as error "CRITICAL ERROR: Start variable `start1' is a datetime (%tc/%tC format)."
            noisily display as error "tvmerge requires daily dates (integer days). Datetimes are milliseconds"
            noisily display as error "and will break all interval logic. Convert using: gen date_var = dofc(`start1')"
            exit 198
        }
        if substr("`_stop_fmt'", 1, 3) == "%tc" | substr("`_stop_fmt'", 1, 3) == "%tC" {
            noisily display as error "CRITICAL ERROR: Stop variable `stop1' is a datetime (%tc/%tC format)."
            noisily display as error "tvmerge requires daily dates (integer days). Datetimes are milliseconds"
            noisily display as error "and will break all interval logic. Convert using: gen date_var = dofc(`stop1')"
            exit 198
        }

        * Required rows are strict by default. Fractional dates are not silently
        * rounded because they violate the suite's whole-day interval contract.
        tempvar _bad_id1 _bad_date1 _bad_order1 _bad_exp1 _bad_row1
        generate byte `_bad_id1' = missing(id)
        generate byte `_bad_date1' = missing(`startname') | missing(`stopname') | ///
            (!missing(`startname') & `startname' != floor(`startname')) | ///
            (!missing(`stopname') & `stopname' != floor(`stopname'))
        generate byte `_bad_order1' = !missing(`startname', `stopname') & ///
            `startname' > `stopname'
        generate byte `_bad_exp1' = missing(`exp1')
        generate byte `_bad_row1' = `_bad_id1' | `_bad_date1' | ///
            `_bad_order1' | `_bad_exp1'

        quietly count if `_bad_id1'
        local invalid_id_ds1 = r(N)
        quietly count if `_bad_date1'
        local invalid_dates_ds1 = r(N)
        quietly count if `_bad_order1'
        local invalid_order_ds1 = r(N)
        quietly count if `_bad_exp1'
        local invalid_exposure_ds1 = r(N)
        quietly count if `_bad_row1'
        local invalid_ds1 = r(N)

        local n_invalid = `n_invalid' + `invalid_ds1'
        local n_invalid_id = `n_invalid_id' + `invalid_id_ds1'
        local n_invalid_dates = `n_invalid_dates' + `invalid_dates_ds1'
        local n_invalid_order = `n_invalid_order' + `invalid_order_ds1'
        local n_invalid_exposure = `n_invalid_exposure' + `invalid_exposure_ds1'

        if `invalid_ds1' > 0 & "`dropinvalid'" == "" {
            noisily display as error "Malformed input in dataset 1: `invalid_ds1' row(s)"
            noisily display as error ///
                "  missing ID: `invalid_id_ds1'; invalid daily dates: `invalid_dates_ds1'; reversed bounds: `invalid_order_ds1'; missing exposure: `invalid_exposure_ds1'"
            if "`verbose'" != "" {
                preserve
                keep if `_bad_row1'
                noisily list id `startname' `stopname' `exp1' ///
                    in 1/`=min(5, _N)', noobs
                restore
            }
            noisily display as error "Correct the source data or specify dropinvalid."
            exit 498
        }
        if `invalid_ds1' > 0 {
            drop if `_bad_row1'
            noisily display as text ///
                "dropinvalid: removed `invalid_ds1' malformed row(s) from dataset 1"
        }
        drop `_bad_id1' `_bad_date1' `_bad_order1' `_bad_exp1' `_bad_row1'
        if _N == 0 {
            noisily display as error "No valid observations remain in dataset 1"
            exit 2000
        }
        
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
        
        * Totals are tracked by exposure position, never by raw variable name.
        * This is essential when multiple source datasets use the same name.
        local _position_one "1"
        local is_cont1 : list _position_one in total_positions
        
        * Process keep() variables for dataset 1
        if "`keep'" != "" {
            foreach var in `keep' {
                capture confirm variable `var'
                if _rc == 0 {
                    * Track that this variable was found
                    local keep_vars_found: list keep_vars_found | var
                    * Rename with _ds1 suffix to avoid conflicts
                    tempvar _keep_tmp
                    rename `var' `_keep_tmp'
                    rename `_keep_tmp' `var'_ds1
                    local keeplist "`keeplist' `var'_ds1"
                }
            }
        }
        
        keep `keeplist'
        
        * Sort and save as tempfile
        sort id `startname' `stopname'

        * Check against the running prior maximum, so nested intervals do not
        * hide later overlaps behind a shorter immediate predecessor.
        tempvar _overlap_check _overlap_maxstop
        by id: gen double `_overlap_maxstop' = `stopname'
        by id: replace `_overlap_maxstop' = max(`_overlap_maxstop'[_n-1], `stopname') if _n > 1
        by id: gen byte `_overlap_check' = ///
            (`startname' <= `_overlap_maxstop'[_n-1]) if _n > 1
        quietly count if `_overlap_check' == 1
        local n_overlaps_ds1 = r(N)
        if `n_overlaps_ds1' > 0 {
            noisily di as text "Warning: Dataset 1 (`first_ds') contains `n_overlaps_ds1' overlapping interval(s) within persons."
            noisily di as text "         Overlapping input may produce unexpected results."
            if `n_total' > 0 {
                noisily di as error "Interval totals cannot be conserved when a source dataset contains overlapping rows."
                noisily di as error "Resolve source overlaps before using total() or continuous()."
                exit 459
            }
        }
        drop `_overlap_check' `_overlap_maxstop'

        tempfile merged_data
        save `merged_data', replace

        * Track interval totals already in merged_data. These must be
        * re-apportioned when later merge boundaries slice their current rows.
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
                noisily di as error "Could not extract start variable name for dataset `k' from start() option"
                noisily di as error "start() option contains: `starts'"
                exit 198
            }
            if "`stop_k_varname'" == "" {
                noisily di as error "Could not extract stop variable name for dataset `k' from stop() option"
                noisily di as error "stop() option contains: `stops'"
                exit 198
            }
            if "`exp_k_raw'" == "" {
                noisily di as error "Could not extract exposure variable name for dataset `k' from exposure() option"
                noisily di as error "exposure() option contains: `exposures_raw'"
                exit 198
            }

            * Check if user's variable name conflicts with internal temp name
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
            local exp_k_list : list uniq exp_k_list

            if "`exp_k_list'" == "" {
                noisily di as error "No exposure variables found in `ds_k'"
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
                noisily di as error "Dataset `ds_k' already contains a variable named 'start_k'"
                noisily di as error "This conflicts with internal processing. Please rename this variable before using tvmerge."
                exit 110
            }
            if `has_stop_k' & "`stop_k_varname'" != "stop_k" {
                noisily di as error "Dataset `ds_k' already contains a variable named 'stop_k'"
                noisily di as error "This conflicts with internal processing. Please rename this variable before using tvmerge."
                exit 110
            }

            * Verify required variables exist
            capture confirm variable `id'
            if _rc != 0 {
                noisily di as error "Variable `id' not found in `ds_k'"
                exit 111
            }
            capture confirm variable `start_k_varname'
            if _rc != 0 {
                noisily di as error "Variable `start_k_varname' not found in `ds_k'"
                noisily di as error "(This is variable `k' from start() option: `starts')"
                exit 111
            }
            capture confirm variable `stop_k_varname'
            if _rc != 0 {
                noisily di as error "Variable `stop_k_varname' not found in `ds_k'"
                noisily di as error "(This is variable `k' from stop() option: `stops')"
                exit 111
            }
            capture confirm numeric variable `start_k_varname'
            if _rc != 0 {
                noisily di as error "start() variable `start_k_varname' in dataset `k' must be numeric daily dates"
                exit 109
            }
            capture confirm numeric variable `stop_k_varname'
            if _rc != 0 {
                noisily di as error "stop() variable `stop_k_varname' in dataset `k' must be numeric daily dates"
                exit 109
            }
            foreach found_exp of local exp_k_list {
                local found_is_quantity = 0
                local declared_quantity ""
                local _position_k "`k'"
                if "`found_exp'" == "`exp_k_raw'" {
                    foreach quantity in rate total cumulative {
                        local in_quantity : list _position_k in `quantity'_positions
                        if `in_quantity' {
                            local found_is_quantity = 1
                            local declared_quantity "`quantity'"
                        }
                    }
                }
                else {
                    foreach quantity in rate total cumulative {
                        local in_quantity : list found_exp in `quantity'_names
                        if `in_quantity' {
                            local found_is_quantity = 1
                            local declared_quantity "`quantity'"
                        }
                    }
                }
                if `found_is_quantity' {
                    capture confirm numeric variable `found_exp'
                    if _rc != 0 {
                        noisily di as error "Quantity variable `found_exp' in dataset `k' must be numeric"
                        exit 109
                    }
                }
                local source_quantity : char `found_exp'[tvtools_quantity]
                if "`source_quantity'" != "" {
                    if !inlist("`source_quantity'", "rate", "total", "cumulative") {
                        noisily di as error "Unknown tvtools_quantity metadata for `found_exp' in dataset `k': `source_quantity'"
                        exit 498
                    }
                    if "`declared_quantity'" == "" {
                        noisily di as error "Quantity metadata for `found_exp' in dataset `k' is `source_quantity'; declare the matching `source_quantity'() option"
                        exit 498
                    }
                    if "`declared_quantity'" != "`source_quantity'" {
                        noisily di as error "Quantity metadata conflict for `found_exp' in dataset `k': source is `source_quantity', option declares `declared_quantity'"
                        exit 498
                    }
                }
                if "`declared_quantity'" == "cumulative" {
                    local source_history : char `found_exp'[tvtools_history_point]
                    if "`source_history'" != "start" {
                        noisily di as error "Cumulative variable `found_exp' in dataset `k' must declare char tvtools_history_point start"
                        exit 498
                    }
                }
            }
            * Note: exp_k_raw (word k of exposure list) may not exist in this dataset
            * when exposure() has more variables than datasets. The exp_k_list
            * (built above) contains all exposures actually found in this dataset.
            * We only validate that at least one exposure was found (done at lines 528-531).

            * Rename to standard internal names for processing
            rename `id' id
            rename `start_k_varname' start_k
            rename `stop_k_varname' stop_k

            * Check for datetime formats (%tc, %tC)
            local _start_k_fmt : format start_k
            local _stop_k_fmt : format stop_k
            if substr("`_start_k_fmt'", 1, 3) == "%tc" | substr("`_start_k_fmt'", 1, 3) == "%tC" {
                noisily display as error "CRITICAL ERROR: Start variable `start_k_varname' in dataset `k' is a datetime (%tc/%tC format)."
                noisily display as error "tvmerge requires daily dates. Convert using: gen date_var = dofc(`start_k_varname')"
                exit 198
            }
            if substr("`_stop_k_fmt'", 1, 3) == "%tc" | substr("`_stop_k_fmt'", 1, 3) == "%tC" {
                noisily display as error "CRITICAL ERROR: Stop variable `stop_k_varname' in dataset `k' is a datetime (%tc/%tC format)."
                noisily display as error "tvmerge requires daily dates. Convert using: gen date_var = dofc(`stop_k_varname')"
                exit 198
            }

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
            * Also track which of them are continuous (by ORIGINAL name, since
            * continuous_names holds pre-rename names), so non-positional
            * exposures in the advanced numexp > numds case are proportioned
            * exactly like the positional one.
            local exp_k_list_final ""
            local exp_k_cont_list ""
            foreach found_exp in `exp_k_list' {
                if "`found_exp'" == "`exp_k_raw'" {
                    * This is the positional exposure, use the renamed version
                    local _renamed_exp "`exp_k'"
                    local _position_k "`k'"
                    local _found_is_cont : list _position_k in total_positions
                }
                else {
                    * Other exposure found in dataset, apply prefix if specified
                    local _found_is_cont : list found_exp in total_names
                    if "`prefix'" != "" {
                        rename `found_exp' `prefix'`found_exp'
                        local _renamed_exp "`prefix'`found_exp'"
                    }
                    else {
                        local _renamed_exp "`found_exp'"
                    }
                }
                local exp_k_list_final "`exp_k_list_final' `_renamed_exp'"
                if `_found_is_cont' {
                    local exp_k_cont_list "`exp_k_cont_list' `_renamed_exp'"
                }
            }

            * Update exp_k_list for later interval-total allocation.
            local exp_k_list_final : list uniq exp_k_list_final
            local exp_k_cont_list : list uniq exp_k_cont_list
            local exp_k_list "`exp_k_list_final'"

            * Strict required-row validation before any interval processing.
            tempvar _bad_idk _bad_datek _bad_orderk _bad_expk _bad_rowk
            generate byte `_bad_idk' = missing(id)
            generate byte `_bad_datek' = missing(start_k) | missing(stop_k) | ///
                (!missing(start_k) & start_k != floor(start_k)) | ///
                (!missing(stop_k) & stop_k != floor(stop_k))
            generate byte `_bad_orderk' = !missing(start_k, stop_k) & start_k > stop_k
            generate byte `_bad_expk' = 0
            foreach exp_var of local exp_k_list {
                replace `_bad_expk' = 1 if missing(`exp_var')
            }
            generate byte `_bad_rowk' = `_bad_idk' | `_bad_datek' | ///
                `_bad_orderk' | `_bad_expk'

            quietly count if `_bad_idk'
            local invalid_id_ds`k' = r(N)
            quietly count if `_bad_datek'
            local invalid_dates_ds`k' = r(N)
            quietly count if `_bad_orderk'
            local invalid_order_ds`k' = r(N)
            quietly count if `_bad_expk'
            local invalid_exposure_ds`k' = r(N)
            quietly count if `_bad_rowk'
            local invalid_ds`k' = r(N)

            local n_invalid = `n_invalid' + `invalid_ds`k''
            local n_invalid_id = `n_invalid_id' + `invalid_id_ds`k''
            local n_invalid_dates = `n_invalid_dates' + `invalid_dates_ds`k''
            local n_invalid_order = `n_invalid_order' + `invalid_order_ds`k''
            local n_invalid_exposure = `n_invalid_exposure' + `invalid_exposure_ds`k''

            if `invalid_ds`k'' > 0 & "`dropinvalid'" == "" {
                noisily display as error ///
                    "Malformed input in dataset `k': `invalid_ds`k'' row(s)"
                noisily display as error ///
                    "  missing ID: `invalid_id_ds`k''; invalid daily dates: `invalid_dates_ds`k''; reversed bounds: `invalid_order_ds`k''; missing exposure: `invalid_exposure_ds`k''"
                if "`verbose'" != "" {
                    preserve
                    keep if `_bad_rowk'
                    noisily list id start_k stop_k `exp_k_list' ///
                        in 1/`=min(5, _N)', noobs
                    restore
                }
                noisily display as error "Correct the source data or specify dropinvalid."
                exit 498
            }
            if `invalid_ds`k'' > 0 {
                drop if `_bad_rowk'
                noisily display as text ///
                    "dropinvalid: removed `invalid_ds`k'' malformed row(s) from dataset `k'"
            }
            drop `_bad_idk' `_bad_datek' `_bad_orderk' `_bad_expk' `_bad_rowk'
            if _N == 0 {
                noisily display as error "No valid observations remain in dataset `k'"
                exit 2000
            }

            * Keep only necessary variables (all exposures found in this dataset)
            local keeplist_k "id start_k stop_k `exp_k_list'"
            
            * Process keep() variables for dataset k
            if "`keep'" != "" {
                foreach var in `keep' {
                    capture confirm variable `var'
                    if _rc == 0 {
                        * Track that this variable was found
                        local keep_vars_found: list keep_vars_found | var
                        * Rename with _ds# suffix to avoid conflicts
                        tempvar _keep_tmp
                        rename `var' `_keep_tmp'
                        rename `_keep_tmp' `var'_ds`k'
                        local keeplist_k "`keeplist_k' `var'_ds`k'"
                    }
                }
            }
            
            keep `keeplist_k'
            
            * Sort for merge
            sort id start_k stop_k

            * Running-maximum overlap screen (nested intervals included).
            tempvar _overlap_check_k _overlap_maxstop_k
            by id: gen double `_overlap_maxstop_k' = stop_k
            by id: replace `_overlap_maxstop_k' = ///
                max(`_overlap_maxstop_k'[_n-1], stop_k) if _n > 1
            by id: gen byte `_overlap_check_k' = ///
                (start_k <= `_overlap_maxstop_k'[_n-1]) if _n > 1
            quietly count if `_overlap_check_k' == 1
            local n_overlaps_ds`k' = r(N)
            if `n_overlaps_ds`k'' > 0 {
                noisily di as text "Warning: Dataset `k' (`ds_k') contains `n_overlaps_ds`k'' overlapping interval(s) within persons."
                noisily di as text "         Overlapping input may produce unexpected results."
                if `n_total' > 0 {
                    noisily di as error "Interval totals cannot be conserved when a source dataset contains overlapping rows."
                    noisily di as error "Resolve source overlaps before using total() or continuous()."
                    exit 459
                }
            }
            drop `_overlap_check_k' `_overlap_maxstop_k'

            tempfile ds_k_clean
            save `ds_k_clean', replace
            
            * Load merged data
            use `merged_data', clear

            **# INTERSECT TIME INTERVALS (Mata sweep)

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
                * Sort so _merge_check==1 rows first, then ==2, for correct in/if listing
                sort _merge_check id

                if "`force'" == "" {
                    * No force option - error out (strict mode)
                    noisily di as error _newline "ID mismatch detected between datasets!"

                    if `n_only_merged' > 0 {
                        noisily di as error "  `n_only_merged' IDs exist in datasets 1-`=`k'-1' but not in dataset `k' (`ds_k'):"
                        local n_show = min(20, `n_only_merged')
                        noisily list id if _merge_check == 1 in 1/`n_show', noheader sep(0)
                        if `n_only_merged' > 20 {
                            noisily di as error "  ... and `=`n_only_merged'-20' more"
                        }
                    }

                    if `n_only_dsk' > 0 {
                        noisily di as error "  `n_only_dsk' IDs exist in dataset `k' (`ds_k') but not in datasets 1-`=`k'-1':"
                        local n_show = min(20, `n_only_dsk')
                        * ==2 rows sit after the ==1 block in the sorted data,
                        * so the in-range must be offset by n_only_merged
                        noisily list id if _merge_check == 2 ///
                            in `=`n_only_merged'+1'/`=`n_only_merged'+`n_show'', noheader sep(0)
                        if `n_only_dsk' > 20 {
                            noisily di as error "  ... and `=`n_only_dsk'-20' more"
                        }
                    }

                    noisily di as error _newline "All datasets must contain the same set of IDs."
                    noisily di as error "IDs that don't match across datasets will be silently dropped during merge."
                    noisily di as error "Use the force option to proceed anyway (mismatched IDs will be dropped from the merged result)."
                    exit 459
                }
                else {
                    * Force option specified - warn and continue
                    noisily di as text _newline "Warning: ID mismatch detected between datasets (proceeding due to force option)"

                    if `n_only_merged' > 0 {
                        noisily di as text "  `n_only_merged' IDs exist in datasets 1-`=`k'-1' but not in dataset `k' (`ds_k')"
                        noisily di as text "  These IDs will be dropped from the merged result."
                        * Show sample of dropped IDs (up to 10)
                        noisily di as text "  Sample of dropped IDs:"
                        quietly count if _merge_check == 1
                        local n_show = min(10, r(N))
                        noisily list id if _merge_check == 1 in 1/`n_show', noheader sep(0)
                        if `n_only_merged' > 10 {
                            noisily di as text "  ... and `=`n_only_merged'-10' more"
                        }
                    }

                    if `n_only_dsk' > 0 {
                        noisily di as text "  `n_only_dsk' IDs exist in dataset `k' (`ds_k') but not in datasets 1-`=`k'-1'"
                        noisily di as text "  These IDs will be dropped from the merged result."
                        * Show sample of dropped IDs (up to 10)
                        noisily di as text "  Sample of dropped IDs:"
                        quietly count if _merge_check == 2
                        local n_show = min(10, r(N))
                        * ==2 rows sit after the ==1 block in the sorted data,
                        * so the in-range must be offset by n_only_merged
                        noisily list id if _merge_check == 2 ///
                            in `=`n_only_merged'+1'/`=`n_only_merged'+`n_show'', noheader sep(0)
                        if `n_only_dsk' > 10 {
                            noisily di as text "  ... and `=`n_only_dsk'-10' more"
                        }
                    }

                    noisily di as text "  Note: Only IDs present in ALL datasets will appear in the output."

                    * Filter to keep only IDs present in both datasets
                    * (current data has _merge_check from ID comparison)
                    keep if _merge_check == 3
                    keep id
                    tempfile valid_ids
                    save `valid_ids', replace

                    * Count observations before filtering
                    use `merged_data', clear
                    quietly count
                    local n_obs_before = r(N)

                    * Apply ID filter to merged_data
                    merge m:1 id using `valid_ids', keep(match) nogenerate

                    * Report observation impact
                    quietly count
                    local n_obs_after = r(N)
                    local n_obs_dropped = `n_obs_before' - `n_obs_after'
                    local total_ids_dropped = `n_only_merged' + `n_only_dsk'
                    local n_forced_id_drops = `n_forced_id_drops' + `total_ids_dropped'

                    noisily di as text _newline "  Summary: Dropped `total_ids_dropped' IDs (`n_obs_dropped' observations)"
                    noisily di as text "           Retained `n_obs_after' observations from matching IDs"

                    save `merged_data', replace
                }
            }

            * Validation passed - continue with merge using the compiled Mata
            * interval-overlap sweep. This emits only the overlapping master x
            * dataset-k interval pairs directly (inner join, inclusive [start,stop]
            * boundaries), which is exactly equivalent to the former
            *   joinby id ; new_start=max ; new_stop=min ; keep if new_start<=new_stop
            * approach, but never materialises the within-person Cartesian product.

            * 1. Tag merged-data row order and snapshot its payload
            use `merged_data', clear
            quietly generate long __tvm_mobs = _n
            tempfile __tvm_merged __tvm_dsk __tvm_xwalk __tvm_pairs
            quietly save `__tvm_merged', replace

            * 2. Build a shared integer group key (gid) over the UNION of IDs in
            *    both datasets, so the sweep matches within person regardless of
            *    string vs numeric IDs. IDs present in only one dataset receive a
            *    gid but produce no pairs (inner join), matching the old joinby.
            quietly keep id
            quietly append using `ds_k_clean', keep(id)
            quietly duplicates drop id, force
            sort id
            quietly generate long __tvm_gid = _n
            quietly save `__tvm_xwalk', replace

            * 3. dataset k -> tag row order; snapshot its payload (everything but
            *    id, to avoid a key clash when materialising) then attach gid and
            *    push the interval matrix to a frame.
            use `ds_k_clean', clear
            quietly generate long __tvm_uobs = _n
            preserve
                drop id
                quietly save `__tvm_dsk', replace
            restore
            quietly merge m:1 id using `__tvm_xwalk', keep(match) nogenerate
            tempname _merge_master_frame _merge_using_frame _merge_out_frame
            local _tvm_work_master "`_merge_master_frame'"
            local _tvm_work_using "`_merge_using_frame'"
            local _tvm_work_out "`_merge_out_frame'"
            frame put __tvm_gid start_k stop_k __tvm_uobs, ///
                into(`_merge_using_frame')
            frame `_merge_using_frame': order __tvm_gid start_k stop_k __tvm_uobs

            * 4. merged data -> attach gid, push interval matrix to a frame
            use `__tvm_merged', clear
            quietly merge m:1 id using `__tvm_xwalk', keep(match) nogenerate
            frame put __tvm_gid `startname' `stopname' __tvm_mobs, ///
                into(`_merge_master_frame')
            frame `_merge_master_frame': order ///
                __tvm_gid `startname' `stopname' __tvm_mobs

            * 5. Run the sweep -> (__tvm_mi, __tvm_ui) overlap pairs.
            *    The engine self-gates a one-line matching-progress indicator at
            *    >100k master rows. It is invoked `noisily' so the indicator
            *    surfaces through tvmerge's internal `quietly' wrapper on a normal
            *    run, yet is still suppressed when the user runs `quietly tvmerge'
            *    (same visibility class as the warnings and the summary).
            local __tvm_progress = 1
            frame create `_merge_out_frame'
            noisily _tvmerge_overlap_pairs `_merge_master_frame' ///
                `_merge_using_frame' `_merge_out_frame', ///
                progress(`__tvm_progress')

            * 6. Pull the pairs into memory and release the work frames
            frame `_merge_out_frame': save `__tvm_pairs', replace
            use `__tvm_pairs', clear
            capture frame drop `_merge_master_frame'
            capture frame drop `_merge_using_frame'
            capture frame drop `_merge_out_frame'
            local _tvm_drc = _rc
            local _tvm_work_master ""
            local _tvm_work_using ""
            local _tvm_work_out ""

            quietly count
            if r(N) > 0 {
                * 7. Materialise paired rows: carry merged-row vars by __tvm_mobs
                *    and dataset-k vars by __tvm_uobs (merge proportional to the
                *    matched output, never the full Cartesian product).
                rename __tvm_mi __tvm_mobs
                rename __tvm_ui __tvm_uobs
                quietly merge m:1 __tvm_mobs using `__tvm_merged', keep(match) nogenerate
                quietly merge m:1 __tvm_uobs using `__tvm_dsk', keep(match) nogenerate

                * Snapshot the merged interval boundaries before intersection
                * (needed to re-apportion interval totals from earlier datasets)
                generate double _orig_start_merged = `startname'
                generate double _orig_stop_merged = `stopname'

                * Interval intersection
                generate double new_start = max(`startname', start_k)
                generate double new_stop = min(`stopname', stop_k)
                * All pairs already overlap; guard kept for exact parity with old logic
                keep if new_start <= new_stop & !missing(new_start, new_stop)
                replace `startname' = new_start
                replace `stopname' = new_stop
                drop new_start new_stop

                * Allocate interval totals based on inclusive overlap duration.

                * 6a. First, re-apportion totals from EARLIER datasets. Each has
                * already been allocated to its current row, so allocate again
                * by the fraction retained after this new intersection.
                foreach merged_exp in `merged_continuous_exps' {
                    capture confirm variable `merged_exp'
                    if _rc == 0 {
                        * Calculate proportion based on how much the merged interval shrunk
                        * proportion = (new interval size) / (original merged interval size)
                        tempvar _prop
                        generate double `_prop' = cond(_orig_stop_merged > _orig_start_merged, ///
                            (`stopname' - `startname' + 1) / (_orig_stop_merged - _orig_start_merged + 1), 1)

                        * Ensure proportion doesn't exceed 1 due to floating point rounding
                        replace `_prop' = 1 if `_prop' > 1 & !missing(`_prop')

                        replace `merged_exp' = `merged_exp' * `_prop'
                        drop `_prop'
                    }
                }

                * 6b. Then, apportion interval totals from dataset k.
                foreach exp_var in `exp_k_list' {
                    local exp_is_total : list exp_var in exp_k_cont_list
                    if `exp_is_total' {
                        * Calculate proportion as (overlap duration) / (original duration from dataset k)
                        * This correctly pro-rates the exposure value
                        tempvar _prop
                        generate double `_prop' = cond(stop_k > start_k, (`stopname' - `startname' + 1) / (stop_k - start_k + 1), 1)

                        * Ensure proportion doesn't exceed 1 due to floating point rounding
                        replace `_prop' = 1 if `_prop' > 1 & !missing(`_prop')

                        replace `exp_var' = `exp_var' * `_prop'
                        drop `_prop'
                    }
                }

                drop start_k stop_k _orig_start_merged _orig_stop_merged __tvm_mobs __tvm_uobs
            }
            else {
                * No overlapping intervals: build empty dataset with proper structure
                use `__tvm_merged', clear
                keep if 1 == 0  // Keep structure but no observations
                capture drop __tvm_mobs
                foreach _fallback_exp in `exp_k_list' {
                    capture confirm variable `_fallback_exp'
                    if _rc != 0 {
                        generate double `_fallback_exp' = .
                    }
                }
            }

            * Save updated merged data
            save `merged_data', replace

            * Update tracking list: add ALL of this dataset's interval-total
            * exposures (positional and non-positional) so later merges
            * re-proportion them when intervals shrink further.
            if "`exp_k_cont_list'" != "" {
                local merged_continuous_exps "`merged_continuous_exps' `exp_k_cont_list'"
            }
        }

        * Validate that all keep() variables were found in at least one dataset
        if "`keep'" != "" {
            foreach var in `keep' {
                local var_found: list var in keep_vars_found
                if `var_found' == 0 {
                    noisily di as error "Variable '`var'' specified in keep() was not found in any dataset"
                    exit 111
                }
            }
        }
        
        **# CLEAN UP FINAL DATASET
        
        * Create list of all final exposure variables for validation
        local final_exps ""
        foreach exp_name in `rate_exps' `total_exps' `cumulative_exps' `categorical_exps' {
            capture confirm variable `exp_name'
            if _rc == 0 {
                local final_exps "`final_exps' `exp_name'"
            }
        }
        
        * Drop only full-row duplicates. Requested keep() payload is part of the
        * output contract and must never be discarded merely because interval
        * bounds and exposures match.
        quietly count
        local n_before_dedup = r(N)
        if `n_before_dedup' > 0 {
            duplicates drop
            quietly count
            local n_after_dedup = r(N)
        }
        else {
            local n_after_dedup = 0
        }
        local n_dups = `n_before_dedup' - `n_after_dedup'

        local n_input_overlaps = 0
        forvalues ds_index = 1/`numds' {
            local n_input_overlaps = `n_input_overlaps' + `n_overlaps_ds`ds_index''
        }

        * Sort final dataset
        if _N > 0 {
            sort id `startname' `stopname'
        }
        
        * Apply date format to start and stop
        format `startname' `stopname' `dateformat'

        * Persist the algebra as variable metadata for downstream validation.
        foreach quantity_var of local rate_exps {
            capture confirm variable `quantity_var'
            if _rc == 0 char `quantity_var'[tvtools_quantity] "rate"
        }
        foreach quantity_var of local total_exps {
            capture confirm variable `quantity_var'
            if _rc == 0 char `quantity_var'[tvtools_quantity] "total"
        }
        foreach quantity_var of local cumulative_exps {
            capture confirm variable `quantity_var'
            if _rc == 0 {
                char `quantity_var'[tvtools_quantity] "cumulative"
                char `quantity_var'[tvtools_history_point] "start"
            }
        }
        
        **# CALCULATE DIAGNOSTICS

        * Count unique persons
        if _N > 0 {
            egen long _tag = tag(id)
            quietly count if _tag == 1
            local n_persons = r(N)

            * Calculate average and max periods per person
            by id: generate long _nper = _N
            quietly summarize _nper if _tag == 1, meanonly
            local avg_periods = r(mean)
            local max_periods = r(max)
            drop _tag _nper
        }
        else {
            local n_persons = 0
            local avg_periods = 0
            local max_periods = 0
        }
        
        * Validate coverage if requested
        * This checks for gaps in coverage within each person's time span
        * (initialize counts so the display blocks below are safe when _N == 0)
        local n_gaps = 0
        local n_overlaps = 0
        if "`validatecoverage'" != "" & _N > 0 {
            * Compare each start with the running maximum prior stop. Immediate-
            * predecessor logic falsely reports gaps after a nested short row.
            tempvar _coverage_max
            bysort id (`startname' `stopname'): generate double `_coverage_max' = `stopname'
            by id: replace `_coverage_max' = max(`_coverage_max'[_n-1], `stopname') if _n > 1
            by id: generate double _gap = `startname' - `_coverage_max'[_n-1] if _n > 1
            
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
            drop _gap `_coverage_max'
        }
        
        * Validate overlaps if requested
        * Checks for unexpected overlapping periods within person
        * Note: In cartesian merges, overlaps are expected when exposure combinations differ
        * This diagnostic flags overlaps with IDENTICAL exposure values (likely errors)
        if "`validateoverlap'" != "" & _N > 0 {
            * Reuse the compiled interval sweep against the output itself. The
            * sweep emits every active pair; mi<ui removes self and symmetric
            * duplicates, then an egen pattern compares the complete exposure
            * vector (numeric, string, labelled, and missing values alike).
            tempvar _diag_obs _diag_gid _diag_pattern
            quietly generate long `_diag_obs' = _n
            quietly egen long `_diag_gid' = group(id)
            quietly egen long `_diag_pattern' = group(`final_exps'), missing

            tempfile _diag_master_lookup _diag_using_lookup _diag_pairs
            preserve
                keep `_diag_obs' `_diag_pattern' id `startname' `stopname'
                rename (`_diag_obs' `_diag_pattern' id `startname' `stopname') ///
                    (__tvm_mi __tvm_mpattern __tvm_mid __tvm_mstart __tvm_mstop)
                quietly save `_diag_master_lookup', replace
            restore
            preserve
                keep `_diag_obs' `_diag_pattern' id `startname' `stopname'
                rename (`_diag_obs' `_diag_pattern' id `startname' `stopname') ///
                    (__tvm_ui __tvm_upattern __tvm_uid __tvm_ustart __tvm_ustop)
                quietly save `_diag_using_lookup', replace
            restore

            tempname _diag_master_frame _diag_using_frame _diag_out_frame
            local _tvm_diag_master "`_diag_master_frame'"
            local _tvm_diag_using "`_diag_using_frame'"
            local _tvm_diag_out "`_diag_out_frame'"
            frame put `_diag_gid' `startname' `stopname' `_diag_obs', ///
                into(`_diag_master_frame')
            frame put `_diag_gid' `startname' `stopname' `_diag_obs', ///
                into(`_diag_using_frame')
            frame create `_diag_out_frame'
            _tvmerge_overlap_pairs `_diag_master_frame' `_diag_using_frame' ///
                `_diag_out_frame'
            quietly frame `_diag_out_frame': save `_diag_pairs', replace

            capture frame drop `_diag_master_frame'
            local _tvm_drc = _rc
            capture frame drop `_diag_using_frame'
            local _tvm_drc = _rc
            capture frame drop `_diag_out_frame'
            local _tvm_drc = _rc
            local _tvm_diag_master ""
            local _tvm_diag_using ""
            local _tvm_diag_out ""

            preserve
                quietly use `_diag_pairs', clear
                quietly keep if __tvm_mi < __tvm_ui
                quietly merge m:1 __tvm_mi using `_diag_master_lookup', ///
                    keep(match) nogenerate
                quietly merge m:1 __tvm_ui using `_diag_using_lookup', ///
                    keep(match) nogenerate
                quietly keep if __tvm_mpattern == __tvm_upattern
                quietly count
                local n_overlaps = r(N)
                if `n_overlaps' > 0 {
                    tempfile overlap_data
                    rename (__tvm_uid __tvm_ustart __tvm_ustop) ///
                        (id `startname' `stopname')
                    keep id `startname' `stopname'
                    quietly save `overlap_data', replace
                }
            restore
            drop `_diag_obs' `_diag_gid' `_diag_pattern'
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
        local _flow_rout = _N
        local _flow_pout = 0

        if _N > 0 {
            * Count and store unique persons
            egen long _tag = tag(id)
            quietly count if _tag == 1
            return scalar N_persons = r(N)
            local _flow_pout = r(N)
            drop _tag

            * Calculate and store periods per person statistics
            by id: generate long _per_max = _N
            by id: generate byte _first = (_n == 1)
            quietly summarize _per_max if _first == 1, meanonly
            return scalar mean_periods = r(mean)
            return scalar max_periods = r(max)
            drop _per_max _first
        }
        else {
            return scalar N_persons = 0
            return scalar mean_periods = 0
            return scalar max_periods = 0
        }

        * Flow accounting report: opt-in normally, mandatory after explicit
        * row/ID removal so attrition can never be silent.
        if "`flow'" != "" | `n_invalid' > 0 | `n_forced_id_drops' > 0 {
            tempname _flowmat
            matrix `_flowmat' = J(2, 3, .)
            matrix `_flowmat'[1,1] = `_flow_pin'
            matrix `_flowmat'[1,2] = `_flow_pout'
            matrix `_flowmat'[1,3] = `_flow_pin' - `_flow_pout'
            matrix `_flowmat'[2,1] = `_flow_rin'
            matrix `_flowmat'[2,2] = `_flow_rout'
            matrix `_flowmat'[2,3] = `_flow_rin' - `_flow_rout'
            matrix rownames `_flowmat' = persons records
            matrix colnames `_flowmat' = in out dropped
            noisily display as text "{hline 60}"
            noisily display as text "Pipeline flow (tvmerge)"
            noisily display as text %-12s "" %10s "in" %10s "out" %10s "dropped"
            noisily display as text %-12s "persons" %10.0f `_flow_pin' %10.0f `_flow_pout' ///
                %10.0f `=`_flow_pin' - `_flow_pout''
            noisily display as text %-12s "records" %10.0f `_flow_rin' %10.0f `_flow_rout' ///
                %10.0f `=`_flow_rin' - `_flow_rout''
            noisily display as text "(persons in = union of distinct ids across inputs)"
            noisily display as text "{hline 60}"
            return matrix flow = `_flowmat'
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
        
        * Store explicit quantity algebra and the deprecated alias result.
        return local rate_vars "`rate_exps'"
        return local total_vars "`total_exps'"
        return local cumulative_vars "`cumulative_exps'"
        return scalar n_rate = `n_rate'
        return scalar n_total = `n_total'
        return scalar n_cumulative = `n_cumulative'
        if "`continuous'" != "" {
            return local continuous_vars "`continuous_exps'"
            return scalar n_continuous = `n_continuous'
        }
        return local categorical_vars "`categorical_exps'"
        return scalar n_categorical = `n_categorical'

        return scalar n_invalid = `n_invalid'
        return scalar n_invalid_id = `n_invalid_id'
        return scalar n_invalid_dates = `n_invalid_dates'
        return scalar n_invalid_order = `n_invalid_order'
        return scalar n_invalid_exposure = `n_invalid_exposure'
        return scalar n_gaps = `n_gaps'
        return scalar n_overlaps = `n_overlaps'
        return scalar n_input_overlaps = `n_input_overlaps'
        return scalar n_duplicates_dropped = `n_dups'
        forvalues ds_index = 1/`numds' {
            return scalar n_invalid_ds`ds_index' = `invalid_ds`ds_index''
            return scalar n_input_overlaps_ds`ds_index' = `n_overlaps_ds`ds_index''
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
        di as text "dropinvalid removed `invalid_ds1' malformed row(s) from `first_ds'"
    }
    forvalues k = 2/`numds' {
        if !missing("`invalid_ds`k''") & `invalid_ds`k'' > 0 {
            local ds_k: word `k' of `datasets'
            di as text "dropinvalid removed `invalid_ds`k'' malformed row(s) from `ds_k'"
        }
    }
    
    * Display duplicates info if any were dropped
    if `n_dups' > 0 {
        di as error "Dropped `n_dups' duplicate interval+exposure combinations"
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
            di as error "Found `n_gaps' gaps in coverage (>1 day gaps)"
            if "`verbose'" != "" {
                quietly use `gaps_data', clear
                noisily list id `startname' `stopname' _gap if _gap > 1 & !missing(_gap), sep(20)
                quietly use `current', clear
            }
            else {
                di as text "  (specify verbose to list affected IDs and dates)"
            }
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
            di as error "Found `n_overlaps' unexpected overlapping periods (same interval, same exposures)"
            if "`verbose'" != "" {
                quietly use `overlap_data', clear
                noisily list id `startname' `stopname', sep(20)
                quietly use `current', clear
            }
            else {
                di as text "  (specify verbose to list affected IDs and dates)"
            }
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

    * Frames-first output: copy the merged result into the named frame and reload
    * the caller's data so their working frame is untouched.
    if "`frameout'" != "" {
        _tvexpose_frame_commit, target(`frameout') `replace'
        if `_frameout_snap_taken' quietly use "`_tvm_caller_snap'", clear
        else {
            quietly clear
            if `_caller_zero_var_obs' > 0 quietly set obs `_caller_zero_var_obs'
        }
        noisily display as text "Result placed in frame: " as result "`frameout'"
        return local frameout "`frameout'"
    }

    } // end capture noisily
    local rc = _rc

    * Defensive cleanup for diagnostic work frames if an error interrupted the
    * self-overlap sweep before its normal cleanup block.
    if "`_tvm_diag_master'" != "" capture frame drop `_tvm_diag_master'
    if "`_tvm_diag_using'" != "" capture frame drop `_tvm_diag_using'
    if "`_tvm_diag_out'" != "" capture frame drop `_tvm_diag_out'
    if "`_tvm_work_master'" != "" capture frame drop `_tvm_work_master'
    if "`_tvm_work_using'" != "" capture frame drop `_tvm_work_using'
    if "`_tvm_work_out'" != "" capture frame drop `_tvm_work_out'
    local _tvm_drc = _rc

    * Restore the caller dataset after any failure. Work frames use tempnames and
    * were cleaned above, so caller-owned frames can never be dropped here.
    if `rc' {
        capture restore
        if `_caller_snapshot_ready' {
            if `_frameout_snap_taken' capture quietly use "`_tvm_caller_snap'", clear
            else {
                capture quietly clear
                if `_caller_zero_var_obs' > 0 capture quietly set obs `_caller_zero_var_obs'
            }
            local _tvm_drc = _rc    // best-effort restore; do not mask `rc'
        }
    }
    set varabbrev `_orig_varabbrev'

    if `rc' exit `rc'

end
