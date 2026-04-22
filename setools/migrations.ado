*! migrations Version 1.0.1  2026/04/22
*! Handle Swedish migration data for registry-based cohort studies
*! Part of the setools package

program define migrations, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    syntax , MIGfile(string) [IDvar(varname) STARTvar(varname) MINresidence(integer 0) SAVEExclude(string) SAVECensor(string) REPLACE VERBose KEEPimmigrants]

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

    * Sanitize file path - prevent injection
    if regexm("`migfile'", "[;&|><\$\`]") {
        display as error "migfile() contains invalid characters"
        exit 198
    }

    * Validate migration file exists
    capture confirm file "`migfile'"
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

    * Sanitize save targets before processing.
    if "`saveexclude'" != "" {
        if regexm("`saveexclude'", "[;&|><\$\`]") {
            display as error "saveexclude() contains invalid characters"
            exit 198
        }
    }
    if "`savecensor'" != "" {
        if regexm("`savecensor'", "[;&|><\$\`]") {
            display as error "savecensor() contains invalid characters"
            exit 198
        }
    }
    local _migfile_lc = lower("`migfile'")
    if "`saveexclude'" != "" {
        local _saveexclude_lc = lower("`saveexclude'")
        if "`_saveexclude_lc'" == "`_migfile_lc'" {
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
        local _savecensor_lc = lower("`savecensor'")
        if "`_savecensor_lc'" == "`_migfile_lc'" {
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
        if "`_saveexclude_lc'" == "`_savecensor_lc'" {
            display as error "saveexclude() and savecensor() must specify different files"
            exit 198
        }
    }

    * Preserve master data
    preserve

    tempfile master exclude1 exclude2 exclude3 exclude4 exclude_data censor_data censor_export_data
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

        capture confirm string variable `mig_event_type_var'
        if _rc == 0 {
            qui gen str12 `_mig_event_type_str' = lower(trim(`mig_event_type_var'))
        }
        else {
            local _mig_event_vlab : value label `mig_event_type_var'
            if "`_mig_event_vlab'" == "" {
                display as error "`mig_event_type_var' must be string or labeled numeric with values like Inv/Utv"
                exit 109
            }
            qui decode `mig_event_type_var', gen(`_mig_event_type_str')
            qui replace `_mig_event_type_str' = lower(trim(`_mig_event_type_str'))
        }

        qui gen byte `_mig_is_in' = (`_mig_event_type_str' == "inv")
        qui gen byte `_mig_is_out' = (`_mig_event_type_str' == "utv")

        quietly count if missing(`mig_event_date_var')
        if r(N) > 0 {
            display as error "Long-format migration file has missing `mig_event_date_var' values"
            exit 198
        }

        quietly count if missing(`_mig_event_type_str') | !(`_mig_is_in' | `_mig_is_out')
        if r(N) > 0 {
            display as error "Long-format migration file has unsupported `mig_event_type_var' values"
            display as error "Supported values are Inv and Utv (case-insensitive)"
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
            qui keep if in_ != .
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
            qui keep if out_ != .
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
        qui drop if out_ == . & in_ == .
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
            qui drop if _mig_last_in < `startvar' & _mig_last_out == .

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

            * EXCLUSION 2: Immigration only after study_start (not in Sweden at baseline)
            * Use person-level state helpers so duplicate or repeated post-start
            * immigration records do not evade classification.
            qui gen _mig_excl_inmig = 0
            qui replace _mig_excl_inmig = 1 if missing(_mig_last_out) & ///
                missing(_mig_last_pre_in) & ///
                !missing(_mig_first_post_in)

            * Calculate emigration censoring date
            * Only permanent emigrations (no subsequent return) generate censoring dates
            * Note: use person-level _mig_last_in (latest immigration across all rows),
            * not row-level in_ — the in_/out_ at the same reshape index are independently
            * numbered sequences, not paired emigration-return events.
            qui gen byte _mig_perm_emig = (_mig_excl_inmig == 0 & out_ != . & out_ > `startvar' & (missing(_mig_last_in) | _mig_last_in <= out_))

            * Earliest permanent emigration per person
            * Note: avoid egen here — Stata's internal tempvar counter can be
            * corrupted by prior dataset switching (use/clear), causing egen to fail.
            qui gen long _mig_min_out = out_ if _mig_perm_emig == 1
            qui bysort `idvar' (_mig_min_out): replace _mig_min_out = _mig_min_out[1]

            * Propagate to all rows for each person
            qui gen long migration_out_dt = _mig_min_out
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
            qui count if migration_out_dt != .
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

    local _saveexclude_had_file = 0
    local _savecensor_had_file = 0
    tempfile _mig_saveexclude_backup _mig_savecensor_backup
    if "`saveexclude'" != "" {
        capture confirm file "`saveexclude'"
        if !_rc {
            local _saveexclude_had_file = 1
            qui copy "`saveexclude'" "`_mig_saveexclude_backup'", replace
        }
    }
    if "`savecensor'" != "" {
        capture confirm file "`savecensor'"
        if !_rc {
            local _savecensor_had_file = 1
            qui copy "`savecensor'" "`_mig_savecensor_backup'", replace
        }
    }

    * Save exclusions
    if "`saveexclude'" != "" {
        capture noisily {
            if "`replace'" != "" {
                qui save "`saveexclude'", replace
            }
            else {
                qui save "`saveexclude'"
            }
        }
        local _saveexclude_rc = _rc
        if `_saveexclude_rc' {
            if `_saveexclude_had_file' {
                capture copy "`_mig_saveexclude_backup'" "`saveexclude'", replace
            }
            restore
            exit `_saveexclude_rc'
        }
        if "`verbose'" != "" display as text "Exclusions saved to `saveexclude'"
    }
    
    qui save `exclude_data', replace

    if "`savecensor'" != "" {
        qui use `censor_export_data', clear
        capture noisily {
            if "`replace'" != "" {
                qui save "`savecensor'", replace
            }
            else {
                qui save "`savecensor'"
            }
        }
        local _savecensor_rc = _rc
        if `_savecensor_rc' {
            if "`saveexclude'" != "" {
                if `_saveexclude_had_file' {
                    capture copy "`_mig_saveexclude_backup'" "`saveexclude'", replace
                }
                else {
                    capture erase "`saveexclude'"
                }
            }
            if `_savecensor_had_file' {
                capture copy "`_mig_savecensor_backup'" "`savecensor'", replace
            }
            restore
            exit `_savecensor_rc'
        }
        if "`verbose'" != "" display as text "Censoring dates saved to `savecensor'"
    }

    * Restore master and merge results
    qui use `master', clear

    * Remove excluded individuals
    qui merge 1:1 `idvar' using `exclude_data', keep(1) nogen

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
    
    * Commit changes (don't restore to original)
    restore, not

    if `no_cohort_matches' {
        display as text "Note: No cohort members found in migration file"
        display as text "No exclusions or censoring dates applied"
        return scalar N_excluded_emigrated = 0
        return scalar N_excluded_inmigration = 0
        return scalar N_excluded_abroad = 0
        return scalar N_excluded_minresidence = 0
        return scalar N_excluded_total = 0
        return scalar N_censored = 0
        return scalar N_included_inmigration = 0
        return scalar N_final = _N
        exit
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
    display as text "Final sample size:                               " as result _N
    display as text "{hline 55}"

    if _N == 0 {
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
    return scalar N_final = _N

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
