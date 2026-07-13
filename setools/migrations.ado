*! migrations Version 1.5.0  2026/07/13
*! Handle Swedish migration data for registry-based cohort studies
*! Part of the setools package
*! Author: Timothy P Copeland, Karolinska Institutet

program define migrations, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _mig_preserved = 0
    local _saveexclude_attempted = 0
    local _savecensor_attempted = 0
    local _saveexclude_had_file = 0
    local _savecensor_had_file = 0
    tempfile _mig_saveexclude_backup _mig_savecensor_backup
    set varabbrev off

    capture noisily {

    syntax , MIGfile(string) [IDvar(varname) STARTvar(varname) MINresidence(integer 0) SAVEExclude(string) SAVECensor(string) REPLACE VERBose KEEPimmigrants INTYPE(string) OUTTYPE(string) FLAG]

    * Note: using _mig_* prefix (not tempvar) for working variables because
    * tempvars get lost on dataset switching (use/clear within program scope).
    * All _mig_* variables are cleaned up by keep/drop before restore.

    * Set defaults
    if "`idvar'" == "" local idvar "id"
    if "`startvar'" == "" local startvar "study_start"
    local mig_event_date_var "event_date"
    local mig_event_type_var "event_type"

    * Validate minresidence
    if `minresidence' < 0 {
        display as error "minresidence() must be non-negative"
        exit 198
    }
    local n_exclude4 = 0
    local n_included_inmig = 0

    * Normalize and validate user-supplied event-type code overrides.
    * These map custom long-format event_type codes onto immigration/emigration
    * and take precedence over the built-in recognition.
    local intype_lc  = lower(strtrim("`intype'"))
    local outtype_lc = lower(strtrim("`outtype'"))
    if "`intype_lc'" != "" & "`outtype_lc'" != "" {
        foreach _it of local intype_lc {
            foreach _ot of local outtype_lc {
                if "`_it'" == "`_ot'" {
                    display as error "intype() and outtype() share the value '`_it'' (must be disjoint)"
                    exit 198
                }
            }
        }
    }

    * Canonicalize the effective Stata dataset paths before any read, preserve,
    * or write. This appends .dta only when the basename has no suffix and
    * resolves relative, dot-segment, and existing-symlink aliases.
    _setools_dta_path, path(`"`migfile'"')
    local migfile `"`r(path)'"'
    if "`saveexclude'" != "" {
        _setools_dta_path, path(`"`saveexclude'"')
        local saveexclude `"`r(path)'"'
    }
    if "`savecensor'" != "" {
        _setools_dta_path, path(`"`savecensor'"')
        local savecensor `"`r(path)'"'
    }

    capture confirm file `"`migfile'"'
    if _rc {
        display as error "Migration file not found: `migfile'"
        exit 601
    }
    
    * Validate master data has required variables
    capture confirm variable `idvar'
    if _rc {
        display as error "ID variable '`idvar'' not found in master data"
        exit 111
    }
    
    capture confirm variable `startvar'
    if _rc {
        display as error "Study start variable '`startvar'' not found in master data"
        exit 111
    }
    
    * Check that startvar is a Stata daily date
    capture confirm numeric variable `startvar'
    if _rc {
        display as error "`startvar' must be numeric (Stata date format)"
        exit 109
    }
    local _mig_start_fmt : format `startvar'
    if lower(substr("`_mig_start_fmt'", 1, 3)) != "%td" {
        display as error "`startvar' must be a Stata daily date variable with %td format"
        exit 109
    }
    quietly count if !missing(`startvar') & `startvar' != floor(`startvar')
    if r(N) > 0 {
        display as error "`startvar' must contain whole-number Stata daily dates"
        exit 109
    }

    quietly count if missing(`startvar')
    if r(N) > 0 {
        local _mig_missing_start = r(N)
        display as error "Study start variable '`startvar'' has `_mig_missing_start' missing value(s) in master data"
        display as error "migrations requires nonmissing study start dates for all observations"
        exit 498
    }
    
    * Validate ID uniqueness in master data
    capture isid `idvar'
    if _rc {
        display as error "'`idvar'' does not uniquely identify observations in master data"
        display as error "migrations requires one row per person"
        exit 459
    }

    * Preflight output-variable collisions before any save side effects.
    capture confirm variable migration_out_dt
    if !_rc {
        display as error "Variable migration_out_dt already exists in master data"
        display as error "Drop or rename it before running migrations"
        exit 110
    }
    if "`keepimmigrants'" != "" {
        capture confirm variable migration_in_dt
        if !_rc {
            display as error "Variable migration_in_dt already exists in master data"
            display as error "Drop or rename it before running migrations"
            exit 110
        }
    }
    if "`flag'" != "" {
        foreach _fv in mig_excluded mig_exclude_reason {
            capture confirm variable `_fv'
            if !_rc {
                display as error "Variable `_fv' already exists in master data"
                display as error "Drop or rename it before running migrations with flag"
                exit 110
            }
        }
    }

    * Preflight the reserved internal working namespace. migrations creates
    * _mig_*/_neg_* working variables on the merged master (it cannot use
    * tempvars across dataset switching), so a user column in that namespace
    * would collide. Fail early with a clear message rather than a cryptic gen.
    capture ds _mig_* _neg_*
    if !_rc & "`r(varlist)'" != "" {
        display as error "Master data contains reserved internal variable(s): `r(varlist)'"
        display as error "Drop or rename _mig_*/_neg_* columns before running migrations"
        exit 110
    }

    * Compare canonical paths with platform-appropriate case semantics.
    local _migfile_cmp `"`migfile'"'
    if "`c(os)'" == "Windows" local _migfile_cmp = lower(`"`migfile'"')
    if "`saveexclude'" != "" {
        local _saveexclude_cmp `"`saveexclude'"'
        if "`c(os)'" == "Windows" local _saveexclude_cmp = lower(`"`saveexclude'"')
        if `"`_saveexclude_cmp'"' == `"`_migfile_cmp'"' {
            display as error "saveexclude() may not overwrite migfile()"
            exit 198
        }
        if "`replace'" == "" {
            capture confirm new file "`saveexclude'"
            if _rc {
                display as error "File already exists: `saveexclude'"
                display as error "Specify replace to overwrite it"
                exit 602
            }
        }
    }
    if "`savecensor'" != "" {
        local _savecensor_cmp `"`savecensor'"'
        if "`c(os)'" == "Windows" local _savecensor_cmp = lower(`"`savecensor'"')
        if `"`_savecensor_cmp'"' == `"`_migfile_cmp'"' {
            display as error "savecensor() may not overwrite migfile()"
            exit 198
        }
        if "`replace'" == "" {
            capture confirm new file "`savecensor'"
            if _rc {
                display as error "File already exists: `savecensor'"
                display as error "Specify replace to overwrite it"
                exit 602
            }
        }
    }
    if "`saveexclude'" != "" & "`savecensor'" != "" {
        if `"`_saveexclude_cmp'"' == `"`_savecensor_cmp'"' {
            display as error "saveexclude() and savecensor() must specify different files"
            exit 198
        }
    }

    * Starting cohort size (for the CONSORT-style exclusion-flow matrix)
    qui count
    local n_cohort_start = r(N)

    * Preserve master data
    preserve
    local _mig_preserved = 1

    tempfile master exclude1 exclude2 exclude3 exclude4 exclude_data ///
        censor_data censor_export_data final_data
    qui save `master', replace
    
    * Load migration data
    if "`verbose'" != "" display as text "Loading migration data from `migfile'..."
    qui use "`migfile'", clear
    
    * Validate migration file has required ID variable
    capture confirm variable `idvar'
    if _rc {
        display as error "ID variable '`idvar'' not found in migration file"
        display as error "Migration file must contain the same ID variable as master data"
        exit 111
    }
    
    * Detect migration file format.
    * Wide format is preserved as-is; long format is normalized into the
    * same in_#/out_# layout already used by existing wide migration files.
    capture confirm variable in_1
    local has_wide_in = (_rc == 0)
    capture confirm variable out_1
    local has_wide_out = (_rc == 0)
    capture confirm variable `mig_event_date_var'
    local has_long_date = (_rc == 0)
    capture confirm variable `mig_event_type_var'
    local has_long_type = (_rc == 0)

    if `has_wide_in' & `has_wide_out' {
        if "`verbose'" != "" display as text "Detected wide-format migration file"

        capture isid `idvar'
        if _rc {
            display as error "'`idvar'' is not unique in migration file"
            display as error "Migration file must have one row per person (wide format)"
            exit 459
        }

        unab _mig_wide_date_vars : in_* out_*
        foreach wide_date_var of local _mig_wide_date_vars {
            capture confirm numeric variable `wide_date_var'
            if _rc {
                display as error "Wide-format migration variable '`wide_date_var'' must be numeric"
                exit 109
            }
            local _mig_wide_date_fmt : format `wide_date_var'
            if lower(substr("`_mig_wide_date_fmt'", 1, 3)) != "%td" {
                display as error "Wide-format migration variable '`wide_date_var'' must be a Stata daily date variable with %td format"
                exit 109
            }
            quietly count if !missing(`wide_date_var') & `wide_date_var' != floor(`wide_date_var')
            if r(N) > 0 {
                display as error "Wide-format migration variable '`wide_date_var'' must contain whole-number Stata daily dates"
                exit 109
            }
            quietly replace `wide_date_var' = . if missing(`wide_date_var')
        }

        tempvar _mig_has_wide_event
        qui gen byte `_mig_has_wide_event' = 0
        foreach wide_date_var of local _mig_wide_date_vars {
            qui replace `_mig_has_wide_event' = 1 if !missing(`wide_date_var')
        }
        qui keep if `_mig_has_wide_event' == 1
    }
    else if `has_long_date' & `has_long_type' {
        if "`verbose'" != "" {
            display as text "Detected long-format migration file"
            display as text "Normalizing event_date/event_type into wide migration sequences..."
        }

        capture confirm numeric variable `mig_event_date_var'
        if _rc {
            display as error "`mig_event_date_var' must be numeric (Stata date format)"
            exit 109
        }
        local _mig_event_date_fmt : format `mig_event_date_var'
        if lower(substr("`_mig_event_date_fmt'", 1, 3)) != "%td" {
            display as error "`mig_event_date_var' must be a Stata daily date variable with %td format"
            exit 109
        }
        quietly count if !missing(`mig_event_date_var') & `mig_event_date_var' != floor(`mig_event_date_var')
        if r(N) > 0 {
            display as error "`mig_event_date_var' must contain whole-number Stata daily dates"
            exit 109
        }

        capture confirm variable in_
        if !_rc {
            display as error "Long-format migration file already contains variable 'in_'"
            display as error "Rename it or supply the existing wide-format file instead"
            exit 110
        }
        capture confirm variable out_
        if !_rc {
            display as error "Long-format migration file already contains variable 'out_'"
            display as error "Rename it or supply the existing wide-format file instead"
            exit 110
        }

        tempvar _mig_event_order _mig_event_type_str _mig_is_in _mig_is_out

        * Normalize the event-type field to a lowercased, trimmed string.
        * String types are used as-is; numeric coded types are decoded via
        * their value label; unlabeled numeric types are only supported when
        * intype()/outtype() map the raw codes (matched in their string form).
        capture confirm string variable `mig_event_type_var'
        if _rc == 0 {
            qui gen `_mig_event_type_str' = lower(strtrim(`mig_event_type_var'))
        }
        else {
            local _mig_event_vlab : value label `mig_event_type_var'
            if "`_mig_event_vlab'" != "" {
                qui decode `mig_event_type_var', gen(`_mig_event_type_str')
                qui replace `_mig_event_type_str' = lower(strtrim(`_mig_event_type_str'))
            }
            else if "`intype_lc'" != "" | "`outtype_lc'" != "" {
                qui gen `_mig_event_type_str' = lower(strtrim(strofreal(`mig_event_type_var', "%18.0g")))
            }
            else {
                display as error "`mig_event_type_var' must be string or labeled numeric"
                display as error "For unlabeled numeric codes, map them with intype() and outtype()"
                exit 109
            }
        }

        * Classify each event as immigration or emigration.
        qui gen byte `_mig_is_in'  = 0
        qui gen byte `_mig_is_out' = 0

        * 1) User-supplied overrides take precedence (exact, case-insensitive).
        if "`intype_lc'" != "" {
            foreach _it of local intype_lc {
                qui replace `_mig_is_in' = 1 if `_mig_event_type_str' == "`_it'"
            }
        }
        if "`outtype_lc'" != "" {
            foreach _ot of local outtype_lc {
                qui replace `_mig_is_out' = 1 if `_mig_event_type_str' == "`_ot'"
            }
        }

        * 2) Built-in recognition for rows the overrides did not classify.
        *    Covers Swedish (invandring/utvandring), English (immigration/
        *    emigration, in/out) and the historical Inv/Utv abbreviations.
        qui replace `_mig_is_in' = 1 if `_mig_is_in' == 0 & `_mig_is_out' == 0 & ///
            (substr(`_mig_event_type_str', 1, 3) == "inv" | ///
             substr(`_mig_event_type_str', 1, 3) == "imm" | ///
             inlist(`_mig_event_type_str', "in", "i"))
        qui replace `_mig_is_out' = 1 if `_mig_is_in' == 0 & `_mig_is_out' == 0 & ///
            (substr(`_mig_event_type_str', 1, 3) == "utv" | ///
             substr(`_mig_event_type_str', 1, 3) == "emi" | ///
             inlist(`_mig_event_type_str', "ut", "out", "u", "e"))

        quietly count if missing(`mig_event_date_var')
        if r(N) > 0 {
            display as error "Long-format migration file has missing `mig_event_date_var' values"
            exit 198
        }

        * Clear, actionable diagnostic listing the unrecognized codes.
        quietly count if missing(`_mig_event_type_str') | !(`_mig_is_in' | `_mig_is_out')
        if r(N) > 0 {
            local _mig_nbad = r(N)
            qui levelsof `_mig_event_type_str' if !(`_mig_is_in' | `_mig_is_out'), local(_mig_badvals) clean
            display as error "Long-format migration file has `_mig_nbad' row(s) with unrecognized `mig_event_type_var' values"
            display as error `"Unrecognized value(s): `_mig_badvals'"'
            display as error "Recognized immigration codes: Inv*, Imm*, in, i (case-insensitive)"
            display as error "Recognized emigration codes:  Utv*, Emi*, ut, out, u, e (case-insensitive)"
            display as error "Map other codes explicitly with intype() and outtype()"
            exit 198
        }

        if _N == 0 {
            qui keep `idvar'
            qui gen long in_1 = .
            qui gen long out_1 = .
            qui keep `idvar' in_1 out_1
        }
        else {
            tempvar _mig_first_date _mig_first_typex _mig_first_type _mig_count
            tempfile _mig_long_raw _mig_wide_base _mig_in_wide _mig_out_wide

            qui gen long `_mig_event_order' = _n
            qui gen long in_ = `mig_event_date_var' if `_mig_is_in'
            qui gen long out_ = `mig_event_date_var' if `_mig_is_out'

            * Match the historical long->wide construction used by
            * migrations_wide.dta: if the first observed event is an
            * emigration, immigration counts are offset by one slot.
            qui egen long `_mig_first_date' = min(`mig_event_date_var'), by(`idvar')
            qui egen byte `_mig_first_typex' = min(`_mig_is_in') if `mig_event_date_var' == `_mig_first_date', by(`idvar')
            qui egen byte `_mig_first_type' = min(`_mig_first_typex'), by(`idvar')
            qui save `_mig_long_raw', replace

            qui keep `idvar'
            qui duplicates drop `idvar', force
            qui save `_mig_wide_base', replace

            qui use `_mig_long_raw', clear
            qui keep if !missing(in_)
            qui count
            local has_long_in = (r(N) > 0)
            if `has_long_in' {
                qui bysort `idvar' (`mig_event_date_var' `_mig_event_order'): gen long `_mig_count' = _n
                qui replace `_mig_count' = `_mig_count' + 1 if `_mig_first_type' == 0
                qui keep `idvar' in_ `_mig_count'
                qui reshape wide in_, i(`idvar') j(`_mig_count')
                qui save `_mig_in_wide', replace
            }

            qui use `_mig_long_raw', clear
            qui keep if !missing(out_)
            qui count
            local has_long_out = (r(N) > 0)
            if `has_long_out' {
                qui bysort `idvar' (`mig_event_date_var' `_mig_event_order'): gen long `_mig_count' = _n
                qui keep `idvar' out_ `_mig_count'
                qui reshape wide out_, i(`idvar') j(`_mig_count')
                qui save `_mig_out_wide', replace
            }

            qui use `_mig_wide_base', clear
            if `has_long_in' {
                qui merge 1:1 `idvar' using `_mig_in_wide', keep(1 3) nogen
            }
            else {
                qui gen long in_1 = .
            }
            if `has_long_out' {
                qui merge 1:1 `idvar' using `_mig_out_wide', keep(1 3) nogen
            }
            else {
                qui gen long out_1 = .
            }
            qui order `idvar' in_1 out_1
            qui format in_* out_* %tdCCYY/NN/DD
        }
    }
    else {
        display as error "Migration file format not recognized"
        display as error "Expected either wide format with in_1/out_1, or long format with `idvar', event_date, and event_type"
        exit 111
    }

    * Internal representation must now be one-row-per-person wide data.
    capture isid `idvar'
    if _rc {
        display as error "'`idvar'' is not unique after migration data normalization"
        display as error "Migration file must resolve to one row per person"
        exit 459
    }

    capture confirm variable in_1
    if _rc {
        display as error "Variable 'in_1' not found after migration data normalization"
        exit 111
    }
    capture confirm variable out_1
    if _rc {
        display as error "Variable 'out_1' not found after migration data normalization"
        exit 111
    }

    * Keep only the migration columns before merging. Any other migfile column
    * that shares a name with a master column (e.g. a stray `startvar' copy)
    * would otherwise silently shadow the master values during exclusion and
    * censoring computation — the master is the using dataset in the merge
    * below, and memory values win for overlapping variables.
    qui keep `idvar' in_* out_*

    * Merge with master (keep only cohort members)
    qui merge 1:1 `idvar' using `master', nogen keep(3)

    local no_cohort_matches = 0

    * Check if any cohort members found in migration file
    if _N == 0 {
        local no_cohort_matches = 1
        local n_exclude1 = 0
        local n_exclude2 = 0
        local n_exclude3 = 0
        local n_censor = 0

        qui keep `idvar'
        qui gen str80 exclude_reason = ""
        qui save `exclude1', replace emptyok
        qui save `exclude2', replace emptyok
        qui save `exclude3', replace emptyok
        qui save `exclude4', replace emptyok

        qui drop exclude_reason
        qui gen long migration_out_dt = .
        qui label var migration_out_dt "Emigration censoring date"
        qui format migration_out_dt %tdCCYY/NN/DD
        qui save `censor_data', replace emptyok
    }
    else {
        * Reshape to long format
        if "`verbose'" != "" display as text "Reshaping migration data..."
        qui reshape long in_ out_, i(`idvar') j(_mig_num)
        qui drop if missing(out_) & missing(in_)
        qui duplicates drop `idvar' in_ out_, force

        qui count
        if r(N) == 0 {
            local n_exclude1 = 0
            local n_exclude2 = 0
            local n_exclude3 = 0
            local n_exclude4 = 0
            local n_censor = 0

            qui keep `idvar'
            qui gen str80 exclude_reason = ""
            qui save `exclude1', replace emptyok
            qui save `exclude2', replace emptyok
            qui save `exclude3', replace emptyok
            qui save `exclude4', replace emptyok

            qui drop exclude_reason
            qui gen long migration_out_dt = .
            qui label var migration_out_dt "Emigration censoring date"
            qui format migration_out_dt %tdCCYY/NN/DD
            qui save `censor_data', replace emptyok
        }
        else {

        * Calculate last emigration and immigration dates per person
        * Note: using bysort instead of egen — Stata's internal tempvar counter
        * can be corrupted by prior dataset switching (use/clear).
        * Note: negated sort keys are needed for max-by-group because Stata
        * sorts missing last — [_N] gives missing when ANY row has missing.
        * Negating puts the largest non-missing first at [1].
        qui gen long _neg_out = -out_
        qui bysort `idvar' (_neg_out): gen long _mig_last_out = out_[1] if !missing(out_[1])
        qui drop _neg_out
        qui gen long _neg_in = -in_
        qui bysort `idvar' (_neg_in): gen long _mig_last_in = in_[1] if !missing(in_[1])
        qui drop _neg_in
        qui format _mig_last_out _mig_last_in %tdCCYY/NN/DD

        * Baseline-state helpers used for broad format support. These do not
        * rely on in_/out_ being paired at the same reshape index.
        qui gen long _mig_pre_start_out = out_ if out_ < `startvar' & !missing(out_)
        qui gen long _neg_pre_out = -_mig_pre_start_out
        qui bysort `idvar' (_neg_pre_out): gen long _mig_last_pre_out = _mig_pre_start_out[1] if !missing(_mig_pre_start_out[1])
        qui drop _neg_pre_out _mig_pre_start_out

        qui gen long _mig_pre_start_in_all = in_ if in_ <= `startvar' & !missing(in_)
        qui gen long _neg_pre_in_all = -_mig_pre_start_in_all
        qui bysort `idvar' (_neg_pre_in_all): gen long _mig_last_pre_in = _mig_pre_start_in_all[1] if !missing(_mig_pre_start_in_all[1])
        qui drop _neg_pre_in_all _mig_pre_start_in_all

        qui gen long _mig_post_start_in = in_ if in_ > `startvar' & !missing(in_)
        qui bysort `idvar' (_mig_post_start_in): gen long _mig_first_post_in = _mig_post_start_in[1] if !missing(_mig_post_start_in[1])
        qui drop _mig_post_start_in
        qui format _mig_last_pre_out _mig_last_pre_in _mig_first_post_in %tdCCYY/NN/DD

        * Compute latest pre-start immigration per person (for minresidence check)
        * Persons born in Sweden with no immigration will have missing _mig_pre_start_in
        if `minresidence' > 0 {
            qui gen long _mig_pre_start_in = _mig_last_pre_in
            qui format _mig_pre_start_in %tdCCYY/NN/DD
        }

        * EXCLUSION 1: Left Sweden before study_start and never returned
        qui gen _mig_excl_emig = 0
        qui replace _mig_excl_emig = 1 if _mig_last_out < `startvar' & (missing(_mig_last_in) | _mig_last_in < _mig_last_out)

        tempfile temp_migrations
        qui save `temp_migrations', replace

        * Save list of exclusions (type 1)
        qui keep if _mig_excl_emig == 1
        qui keep `idvar'
        if _N > 0 {
            qui duplicates drop `idvar', force
        }
        qui gen str80 exclude_reason = ""
        if _N > 0 {
            qui replace exclude_reason = "Emigrated before study start, never returned"
        }

        qui save `exclude1', replace emptyok
        local n_exclude1 = _N

        * Continue with remaining individuals
        qui use `temp_migrations', clear
        qui drop if _mig_excl_emig == 1
        qui drop _mig_excl_emig

            * EXCLUSION 4: Insufficient residence before study_start
            * Must run before pre-filter drops immigration-only records
            if `minresidence' > 0 {
                qui gen _mig_excl_minres = 0
                qui replace _mig_excl_minres = 1 if !missing(_mig_pre_start_in) & (`startvar' - _mig_pre_start_in) < `minresidence'

            tempfile pre_exclude4
            qui save `pre_exclude4', replace

            qui keep if _mig_excl_minres == 1
            qui keep `idvar'
            if _N > 0 {
                qui duplicates drop `idvar', force
                qui gen exclude_reason = "Insufficient residence before study start (`minresidence' days required)"
            }

            qui save `exclude4', replace emptyok
            local n_exclude4 = _N

            qui use `pre_exclude4', clear
            qui drop if _mig_excl_minres == 1
            qui drop _mig_excl_minres
        }

        * Check if any individuals remain after exclusion 1
        qui count
        local n_remaining = r(N)

        if `n_remaining' == 0 {
            * All matched individuals were excluded - create empty files
            local n_exclude2 = 0
            local n_exclude3 = 0
            local n_censor = 0

            * Create empty exclusion files (exclude4 already set by minresidence block)
            qui keep `idvar'
            qui save `exclude2', replace emptyok
            qui save `exclude3', replace emptyok
            if `minresidence' == 0 {
                qui save `exclude4', replace emptyok
            }

            * Create empty censor file
            qui gen long migration_out_dt = .
            qui label var migration_out_dt "Emigration censoring date"
            qui format migration_out_dt %tdCCYY/NN/DD
            qui save `censor_data', replace emptyok
        }
        else {
            * Drop individuals who immigrated before study_start with no emigration record
            qui drop if _mig_last_in < `startvar' & missing(_mig_last_out)

            * Check if any individuals remain after pre-filtering
            qui count
            if r(N) == 0 {
                * No migration events to process — create empty result files
                local n_exclude2 = 0
                local n_exclude3 = 0
                local n_censor = 0
                qui keep `idvar'
                qui save `exclude2', replace emptyok
                qui save `exclude3', replace emptyok
                if `minresidence' == 0 {
                    qui save `exclude4', replace emptyok
                }
                qui gen long migration_out_dt = .
                qui label var migration_out_dt "Emigration censoring date"
                qui format migration_out_dt %tdCCYY/NN/DD
                qui save `censor_data', replace emptyok
            }
            else {

            * EXCLUSION 3: Emigrated before study_start and returned after
            * (abroad at baseline). This must work for both historical paired
            * wide files and long->wide normalized event sequences.
            qui gen _mig_excl_abroad = 0
            qui replace _mig_excl_abroad = 1 if !missing(_mig_last_pre_out) & ///
                !missing(_mig_first_post_in) & ///
                (missing(_mig_last_pre_in) | _mig_last_pre_in < _mig_last_pre_out)

            tempfile pre_exclude3
            qui save `pre_exclude3', replace

            * Save exclusions (type 3)
            qui keep if _mig_excl_abroad == 1
            qui keep `idvar'
            if _N > 0 {
                qui duplicates drop `idvar', force
                qui gen exclude_reason = "Abroad at baseline (emigrated before, returned after study start)"
            }

            qui save `exclude3', replace emptyok
            local n_exclude3 = _N

            * Continue with remaining individuals
            qui use `pre_exclude3', clear
            qui drop if _mig_excl_abroad == 1
            qui drop _mig_excl_abroad

            * Drop emigration records before study_start
            qui drop if out_ < `startvar'

            * Check if any rows remain for further processing
            qui count
            if r(N) == 0 {
                local n_exclude2 = 0
                local n_censor = 0
                qui keep `idvar'
                qui save `exclude2', replace emptyok
                qui gen long migration_out_dt = .
                qui label var migration_out_dt "Emigration censoring date"
                qui format migration_out_dt %tdCCYY/NN/DD
                qui save `censor_data', replace emptyok
            }
            else {

            * Recalculate migration sequence
            qui drop _mig_num _mig_last_out _mig_last_in
            capture drop _mig_pre_start_in
            qui gen long _neg_out = -out_
            qui bysort `idvar' (_neg_out): gen long _mig_last_out = out_[1] if !missing(out_[1])
            qui drop _neg_out
            qui gen long _neg_in = -in_
            qui bysort `idvar' (_neg_in): gen long _mig_last_in = in_[1] if !missing(in_[1])
            qui drop _neg_in
            qui format _mig_last_out _mig_last_in %tdCCYY/NN/DD
            qui bysort `idvar' (out_ in_): gen _mig_seq = _n
            qui bysort `idvar': gen _mig_total = _N

            * Drop if only one migration and it's an immigration before study_start
            qui drop if _mig_total == 1 & _mig_last_in < `startvar'

            * EXCLUSION 2: First-ever migration event is a post-start immigration
            * (no evidence of being in Sweden at baseline). Use person-level state
            * helpers so duplicate or repeated post-start immigration records do
            * not evade classification. The first post-start EMIGRATION date
            * discriminates the born-in-Sweden emigrant (out before in: present at
            * baseline) from the late arrival (in before out: abroad at baseline) —
            * a later emigration must not launder a post-start immigrant into the
            * baseline cohort. All surviving out_ rows are >= `startvar' here
            * (pre-start emigration rows were dropped above).
            qui gen long _mig_first_post_out = out_
            qui bysort `idvar' (_mig_first_post_out): replace _mig_first_post_out = _mig_first_post_out[1]
            qui gen _mig_excl_inmig = 0
            qui replace _mig_excl_inmig = 1 if missing(_mig_last_pre_in) & ///
                !missing(_mig_first_post_in) & ///
                (missing(_mig_first_post_out) | _mig_first_post_in < _mig_first_post_out)
            qui drop _mig_first_post_out

            * Calculate emigration censoring date
            * Only permanent emigrations (no subsequent return) generate censoring dates.
            * Computed for Type 2 persons too: under keepimmigrants they are retained
            * and must carry their permanent-emigration censoring date; in the default
            * path they are dropped before censor_data is built, so this is inert.
            * Note: use person-level _mig_last_in (latest immigration across all rows),
            * not row-level in_ — the in_/out_ at the same reshape index are independently
            * numbered sequences, not paired emigration-return events.
            tempvar _mig_perm_emig _mig_min_out
            qui gen byte `_mig_perm_emig' = (!missing(out_) & ///
                out_ > `startvar' & ///
                (missing(_mig_last_in) | _mig_last_in <= out_))

            * Earliest permanent emigration per person
            * Note: avoid egen here — Stata's internal tempvar counter can be
            * corrupted by prior dataset switching (use/clear), causing egen to fail.
            qui gen long `_mig_min_out' = out_ if `_mig_perm_emig' == 1
            qui bysort `idvar' (`_mig_min_out'): replace `_mig_min_out' = `_mig_min_out'[1]

            * Propagate to all rows for each person
            qui gen long migration_out_dt = `_mig_min_out'
            qui format migration_out_dt %tdCCYY/NN/DD

            * Collapse to one row per person
            qui drop _mig_total _mig_seq
            qui bysort `idvar' (out_ in_): gen _mig_seq = _n
            qui drop if _mig_seq > 1

            * Save current state before extracting exclusions type 2
            tempfile pre_exclude2
            qui save `pre_exclude2', replace

            if "`keepimmigrants'" != "" {
                * keepimmigrants: include Type 2 rather than exclude
                qui count if _mig_excl_inmig == 1
                local n_included_inmig = r(N)
                local n_exclude2 = 0

                * Record immigration date for included immigrants
                qui gen long migration_in_dt = _mig_first_post_in if _mig_excl_inmig == 1
                qui format migration_in_dt %tdCCYY/NN/DD
                qui label var migration_in_dt "Post-study-start immigration date"

                * Keep all individuals with dates
                qui keep `idvar' migration_out_dt migration_in_dt
                if _N > 0 {
                    qui duplicates drop `idvar', force
                }
                qui label var migration_out_dt "Emigration censoring date"

                * Create empty exclude2 file (keep only idvar to avoid
                * variable collision when exclude_data is merged before censor_data)
                tempfile _keepimm_data
                qui save `_keepimm_data', replace
                qui drop if 1
                qui keep `idvar'
                qui save `exclude2', replace emptyok
                qui use `_keepimm_data', clear
            }
            else {
                * Save exclusions (type 2)
                qui keep if _mig_excl_inmig == 1
                qui keep `idvar'
                if _N > 0 {
                    qui duplicates drop `idvar', force
                    qui gen exclude_reason = "Immigration after study start (not in Sweden at baseline)"
                }

                qui save `exclude2', replace emptyok
                local n_exclude2 = _N

                * Restore to pre-exclude2 state
                qui use `pre_exclude2', clear

                * Keep only non-excluded individuals
                qui keep if _mig_excl_inmig == 0
                qui keep `idvar' migration_out_dt
                if _N > 0 {
                    qui duplicates drop `idvar', force
                }
                qui label var migration_out_dt "Emigration censoring date"
            }

            * Count censoring dates
            qui count if !missing(migration_out_dt)
            local n_censor = r(N)

            qui save `censor_data', replace
            }
            }
        }
        }
    }

    * savecensor() exports only observations with nonmissing emigration censoring dates.
    qui use `censor_data', clear
    qui keep if !missing(migration_out_dt)
    qui keep `idvar' migration_out_dt
    if _N > 0 {
        qui duplicates drop `idvar', force
    }
    qui label var migration_out_dt "Emigration censoring date"
    qui format migration_out_dt %tdCCYY/NN/DD
    qui save `censor_export_data', replace emptyok

    * Combine exclusion files
    qui use `exclude1', clear
    qui append using `exclude2'
    qui append using `exclude3'
    if `minresidence' > 0 {
        qui append using `exclude4'
    }
    if _N > 0 {
        qui duplicates drop `idvar', force
    }
    local n_exclude_total = _N
    qui save `exclude_data', replace

    * Restore master and merge results
    qui use `master', clear

    if "`flag'" != "" {
        * flag mode: retain ALL cohort members and mark exclusions in
        * mig_excluded (0/1) + mig_exclude_reason instead of dropping rows.
        * Matches the saveexclude()+merge keep(1) workaround studies hand-write.
        qui merge 1:1 `idvar' using `exclude_data', keep(1 3) nogen keepusing(`idvar' exclude_reason)
        capture confirm variable exclude_reason
        if _rc {
            qui gen str80 exclude_reason = ""
        }
        qui replace exclude_reason = "" if missing(exclude_reason)
        qui gen byte mig_excluded = (trim(exclude_reason) != "")
        qui rename exclude_reason mig_exclude_reason
        qui label var mig_excluded "Excluded by migration criteria (1 = excluded)"
        qui label var mig_exclude_reason "Migration exclusion reason"
    }
    else {
        * Remove excluded individuals. keepusing(`idvar') brings no payload from
        * the exclude file (it carries exclude_reason for the saved file only),
        * so that column never leaks into the user's returned dataset.
        qui merge 1:1 `idvar' using `exclude_data', keep(1) nogen keepusing(`idvar')
    }

    * Merge censoring dates
    qui merge 1:1 `idvar' using `censor_data', keep(1 3) nogen

    * Ensure migration_in_dt exists when keepimmigrants specified
    if "`keepimmigrants'" != "" {
        capture confirm variable migration_in_dt
        if _rc {
            qui gen long migration_in_dt = .
        }
        qui format migration_in_dt %tdCCYY/NN/DD
        qui label var migration_in_dt "Post-study-start immigration date"
    }

    local n_returned = _N
    local n_analytic = `n_cohort_start' - `n_exclude_total'
    if "`flag'" == "" & `n_returned' != `n_analytic' {
        di as error "internal flow invariant failed: returned rows do not equal analytic cohort"
        exit 9
    }
    if "`flag'" != "" & `n_returned' != `n_cohort_start' {
        di as error "internal flow invariant failed: flag mode did not retain the cohort"
        exit 9
    }
    qui save `final_data', replace

    * Build and validate the public flow result before any external file is
    * touched. This keeps a late matrix-construction error inside the dataset
    * transaction and makes the two cohort populations explicit.
    tempname _mig_flow
    local _mig_rn "Cohort_start"
    matrix `_mig_flow' = (`n_cohort_start')
    matrix `_mig_flow' = `_mig_flow' \ (`n_exclude1')
    local _mig_rn "`_mig_rn' Excl_emigrated"
    if "`keepimmigrants'" != "" {
        matrix `_mig_flow' = `_mig_flow' \ (`n_included_inmig')
        local _mig_rn "`_mig_rn' Incl_inmigration"
    }
    else {
        matrix `_mig_flow' = `_mig_flow' \ (`n_exclude2')
        local _mig_rn "`_mig_rn' Excl_inmigration"
    }
    matrix `_mig_flow' = `_mig_flow' \ (`n_exclude3')
    local _mig_rn "`_mig_rn' Excl_abroad"
    if `minresidence' > 0 {
        matrix `_mig_flow' = `_mig_flow' \ (`n_exclude4')
        local _mig_rn "`_mig_rn' Excl_minresidence"
    }
    matrix `_mig_flow' = `_mig_flow' \ (`n_exclude_total')
    local _mig_rn "`_mig_rn' Excluded_total"
    matrix `_mig_flow' = `_mig_flow' \ (`n_censor')
    local _mig_rn "`_mig_rn' With_censoring_date"
    matrix `_mig_flow' = `_mig_flow' \ (`n_analytic')
    local _mig_rn "`_mig_rn' Analytic_cohort"
    matrix `_mig_flow' = `_mig_flow' \ (`n_returned')
    local _mig_rn "`_mig_rn' Returned_rows"
    matrix colnames `_mig_flow' = n
    matrix rownames `_mig_flow' = `_mig_rn'

    * Back up canonical targets, then stage both exports only after the full
    * analytic result exists. The outer error handler rolls back any attempted
    * write, including a partial second-file failure.
    if "`saveexclude'" != "" {
        capture confirm file "`saveexclude'"
        if !_rc {
            local _saveexclude_had_file = 1
            qui copy "`saveexclude'" "`_mig_saveexclude_backup'", replace
        }
        local _saveexclude_attempted = 1
        if "`replace'" != "" {
            qui copy "`exclude_data'" "`saveexclude'", replace
        }
        else {
            qui copy "`exclude_data'" "`saveexclude'"
        }
        if "`verbose'" != "" display as text "Exclusions saved to `saveexclude'"
    }
    if "`savecensor'" != "" {
        capture confirm file "`savecensor'"
        if !_rc {
            local _savecensor_had_file = 1
            qui copy "`savecensor'" "`_mig_savecensor_backup'", replace
        }
        local _savecensor_attempted = 1
        if "`replace'" != "" {
            qui copy "`censor_export_data'" "`savecensor'", replace
        }
        else {
            qui copy "`censor_export_data'" "`savecensor'"
        }
        if "`verbose'" != "" display as text "Censoring dates saved to `savecensor'"
    }
    * Commit only after both the dataset and requested files are ready.
    restore, not
    local _mig_preserved = 0

    if `no_cohort_matches' {
        display as text "Note: No cohort members found in migration file"
        display as text "No exclusions or censoring dates applied"
    }

    * Display summary
    display as text _n "Migration Processing Summary"
    display as text "{hline 55}"
    display as text "Excluded (emigrated before start, no return):    " as result `n_exclude1'
    if "`keepimmigrants'" != "" {
        display as text "Included (immigration after study start):        " as result `n_included_inmig'
    }
    else {
        display as text "Excluded (immigration after study start):        " as result `n_exclude2'
    }
    display as text "Excluded (abroad at baseline, returned after):   " as result `n_exclude3'
    if `minresidence' > 0 {
        display as text "Excluded (residence < `minresidence' days):       " as result `n_exclude4'
    }
    display as text "{hline 55}"
    display as text "Total excluded:                                  " as result `n_exclude_total'
    display as text "Individuals with emigration censoring date:      " as result `n_censor'
    display as text "Analytic cohort size:                           " as result `n_analytic'
    display as text "Rows returned:                                  " as result `n_returned'
    display as text "{hline 55}"
    if "`flag'" != "" {
        display as text "Flag mode: excluded individuals retained and marked in"
        display as text "  mig_excluded (0/1) and mig_exclude_reason"
    }

    if `n_analytic' == 0 {
        display as error "Warning: All observations were excluded by migration criteria"
    }

    * Return values
    return scalar N_excluded_emigrated = `n_exclude1'
    return scalar N_excluded_inmigration = `n_exclude2'
    return scalar N_excluded_abroad = `n_exclude3'
    return scalar N_excluded_minresidence = `n_exclude4'
    return scalar N_excluded_total = `n_exclude_total'
    return scalar N_censored = `n_censor'
    return scalar N_included_inmigration = `n_included_inmig'
    return scalar N_final = `n_analytic'
    return scalar N_analytic = `n_analytic'
    return scalar N_returned = `n_returned'
    return matrix flow = `_mig_flow'

    }
    local rc = _rc
    if `rc' {
        if `_saveexclude_attempted' & "`saveexclude'" != "" {
            if `_saveexclude_had_file' {
                capture copy "`_mig_saveexclude_backup'" "`saveexclude'", replace
                if _rc {
                    display as error "rollback failed restoring saveexclude(): `saveexclude'"
                }
            }
            else {
                capture erase "`saveexclude'"
            }
        }
        if `_savecensor_attempted' & "`savecensor'" != "" {
            if `_savecensor_had_file' {
                capture copy "`_mig_savecensor_backup'" "`savecensor'", replace
                if _rc {
                    display as error "rollback failed restoring savecensor(): `savecensor'"
                }
            }
            else {
                capture erase "`savecensor'"
            }
        }
        if `_mig_preserved' {
            capture restore
        }
    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
