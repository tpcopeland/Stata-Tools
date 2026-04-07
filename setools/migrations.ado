*! migrations Version 1.0.0  2026/04/08
*! Handle Swedish migration data for registry-based cohort studies
*! Part of the setools package

program define migrations, rclass
    version 16.0
    local vabbrev_save `c(varabbrev)'
    set varabbrev off

    capture noisily {

    syntax , MIGfile(string) [IDvar(varname) STARTvar(varname) MINresidence(integer 0) SAVEExclude(string) SAVECensor(string) REPLACE VERBose KEEPimmigrants]

    * Note: using _mig_* prefix (not tempvar) for working variables because
    * tempvars get lost on dataset switching (use/clear within program scope).
    * All _mig_* variables are cleaned up by keep/drop before restore.

    * Set defaults
    if "`idvar'" == "" local idvar "id"
    if "`startvar'" == "" local startvar "study_start"

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
    
    * Check that startvar is a date (accept %t*, %d*, %tc, %tC formats)
    capture confirm numeric variable `startvar'
    if _rc {
        display as error "`startvar' must be numeric (Stata date format)"
        exit 109
    }
    
    * Validate ID uniqueness in master data
    capture isid `idvar'
    if _rc {
        display as error "'`idvar'' does not uniquely identify observations in master data"
        display as error "migrations requires one row per person"
        exit 459
    }

    * Preserve master data
    preserve

    tempfile master
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
    
    * Validate migration file has unique IDs
    capture isid `idvar'
    if _rc {
        display as error "'`idvar'' is not unique in migration file"
        display as error "Migration file must have one row per person (wide format)"
        exit 459
    }

    * Validate migration file has in_/out_ variables for reshape
    capture confirm variable in_1
    if _rc {
        display as error "Variable 'in_1' not found in migration file"
        display as error "Migration file must be in wide format with in_1, in_2, ... and out_1, out_2, ..."
        exit 111
    }
    capture confirm variable out_1
    if _rc {
        display as error "Variable 'out_1' not found in migration file"
        display as error "Migration file must be in wide format with in_1, in_2, ... and out_1, out_2, ..."
        exit 111
    }
    
    * Merge with master (keep only cohort members)
    qui merge 1:1 `idvar' using `master', nogen keep(3)
    
    * Check if any cohort members found in migration file
    if _N == 0 {
        restore
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
        qui gen long migration_out_dt = .
        qui label var migration_out_dt "Emigration censoring date"
        qui format migration_out_dt %tdCCYY/NN/DD
        if "`keepimmigrants'" != "" {
            qui gen long migration_in_dt = .
            qui label var migration_in_dt "Post-study-start immigration date"
            qui format migration_in_dt %tdCCYY/NN/DD
        }
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
    
    * Reshape to long format
    if "`verbose'" != "" display as text "Reshaping migration data..."
    qui reshape long in_ out_, i(`idvar') j(_mig_num)
    qui drop if out_ == . & in_ == .
    
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

    * Compute latest pre-start immigration per person (for minresidence check)
    * Persons born in Sweden with no immigration will have missing _mig_pre_start_in
    if `minresidence' > 0 {
        qui gen long _mig_pre_start_in = in_ if in_ <= `startvar' & !missing(in_)
        qui gen long _neg_pre_in = -_mig_pre_start_in
        qui bysort `idvar' (_neg_pre_in): replace _mig_pre_start_in = _mig_pre_start_in[1]
        qui drop _neg_pre_in
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
        qui gen exclude_reason = "Emigrated before study start, never returned"
    }

    tempfile exclude1
    qui save `exclude1', replace emptyok
    local n_exclude1 = _N

    * Continue with remaining individuals
    qui use `temp_migrations', clear
    qui drop if _mig_excl_emig == 1
    qui drop _mig_excl_emig

    * EXCLUSION 4: Insufficient residence before study_start
    * Must run before pre-filter (line 208) drops immigration-only records
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

        tempfile exclude4
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
        tempfile exclude2
        qui save `exclude2', replace emptyok
        tempfile exclude3
        qui save `exclude3', replace emptyok
        if `minresidence' == 0 {
            tempfile exclude4
            qui save `exclude4', replace emptyok
        }

        * Create empty censor file
        qui gen long migration_out_dt = .
        qui label var migration_out_dt "Emigration censoring date"
        tempfile censor_data
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
            tempfile exclude2
            qui save `exclude2', replace emptyok
            tempfile exclude3
            qui save `exclude3', replace emptyok
            if `minresidence' == 0 {
                tempfile exclude4
                qui save `exclude4', replace emptyok
            }
            qui gen long migration_out_dt = .
            qui label var migration_out_dt "Emigration censoring date"
            tempfile censor_data
            qui save `censor_data', replace emptyok
        }
        else {

        * EXCLUSION 3: Emigrated before study_start and returned after (abroad at baseline)
        qui gen _mig_excl_abroad = 0
        qui replace _mig_excl_abroad = 1 if out_ < `startvar' & in_ > `startvar' & in_ != .

        tempfile pre_exclude3
        qui save `pre_exclude3', replace

        * Save exclusions (type 3)
        qui keep if _mig_excl_abroad == 1
        qui keep `idvar'
        if _N > 0 {
            qui duplicates drop `idvar', force
            qui gen exclude_reason = "Abroad at baseline (emigrated before, returned after study start)"
        }

        tempfile exclude3
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
            tempfile exclude2
            qui save `exclude2', replace emptyok
            qui gen long migration_out_dt = .
            qui label var migration_out_dt "Emigration censoring date"
            tempfile censor_data
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

        * EXCLUSION 2: Only migration is immigration after study_start (not in Sweden at baseline)
        qui gen _mig_excl_inmig = 0
        qui replace _mig_excl_inmig = 1 if in_ > `startvar' & out_ == . & _mig_total == 1 & in_ != .

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
            qui gen long migration_in_dt = in_ if _mig_excl_inmig == 1
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
            tempfile exclude2
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

            tempfile exclude2
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

        * Save censoring data
        if "`savecensor'" != "" {
            // Sanitize file path
            if regexm("`savecensor'", "[;&|><\$\`]") {
                display as error "savecensor() contains invalid characters"
                exit 198
            }

            if "`replace'" != "" {
                qui save "`savecensor'", replace
            }
            else {
                qui save "`savecensor'"
            }
            if "`verbose'" != "" display as text "Censoring dates saved to `savecensor'"
        }

        tempfile censor_data
        qui save `censor_data', replace
        }
        }
    }

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
    
    * Save exclusions
    if "`saveexclude'" != "" {
        // Sanitize file path
        if regexm("`saveexclude'", "[;&|><\$\`]") {
            display as error "saveexclude() contains invalid characters"
            exit 198
        }

        if "`replace'" != "" {
            qui save "`saveexclude'", replace
        }
        else {
            qui save "`saveexclude'"
        }
        if "`verbose'" != "" display as text "Exclusions saved to `saveexclude'"
    }
    
    tempfile exclude_data
    qui save `exclude_data', replace
    
    * Restore master and merge results
    qui use `master', clear
    capture confirm variable migration_out_dt
    if !_rc {
        noisily display as error "Variable migration_out_dt already exists in master data"
        noisily display as error "Drop or rename it before running migrations"
        exit 110
    }
    if "`keepimmigrants'" != "" {
        capture confirm variable migration_in_dt
        if !_rc {
            noisily display as error "Variable migration_in_dt already exists in master data"
            noisily display as error "Drop or rename it before running migrations"
            exit 110
        }
    }

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
    local _rc = _rc
    set varabbrev `vabbrev_save'
    if `_rc' exit `_rc'
end
