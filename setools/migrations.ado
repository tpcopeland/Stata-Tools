*! migrations Version 1.0.8  2026/03/11  Tim Copeland
*! Handle Swedish migration data for registry-based cohort studies
*! Part of the setools package

program define migrations, rclass
    version 16.0
    local vabbrev_save `c(varabbrev)'
    set varabbrev off
    set more off
    syntax , MIGfile(string) [IDvar(varname) STARTvar(varname) SAVEexclude(string) SAVEcensor(string) REPLACE VERBOSE]

    * Declare temporary variables
    tempvar last_out last_in exclude_emigrated exclude_abroad num total_migrations exclude_inmigration

    * Set defaults
    if "`idvar'" == "" local idvar "id"
    if "`startvar'" == "" local startvar "study_start"

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
        display as text "Note: No cohort members found in migration file"
        display as text "No exclusions or censoring dates applied"
        restore
        set varabbrev `vabbrev_save'
        return scalar N_excluded_emigrated = 0
        return scalar N_excluded_inmigration = 0
        return scalar N_excluded_abroad = 0
        return scalar N_excluded_total = 0
        return scalar N_censored = 0
        return scalar N_final = _N
        exit
    }
    
    * Reshape to long format
    if "`verbose'" != "" display as text "Reshaping migration data..."
    qui reshape long in_ out_, i(`idvar') j(num)
    qui drop if out_ == . & in_ == .
    
    * Calculate last emigration and immigration dates per person
    qui egen `last_out' = max(out_), by(`idvar')
    qui egen `last_in' = max(in_), by(`idvar')
    qui format `last_out' `last_in' %tdCCYY/NN/DD

    * EXCLUSION 1: Left Sweden before study_start and never returned
    qui gen `exclude_emigrated' = 0
    qui replace `exclude_emigrated' = 1 if `last_out' < `startvar' & (missing(`last_in') | `last_in' < `last_out')
    
    tempfile temp_migrations
    qui save `temp_migrations', replace
    
    * Save list of exclusions (type 1)
    qui keep if `exclude_emigrated' == 1
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
    qui drop if `exclude_emigrated' == 1
    qui drop `exclude_emigrated'

    * Check if any individuals remain after exclusion 1
    qui count
    local n_remaining = r(N)

    if `n_remaining' == 0 {
        * All matched individuals were excluded - create empty files
        local n_exclude2 = 0
        local n_exclude3 = 0
        local n_censor = 0

        * Create empty exclude2 and exclude3 files
        qui keep `idvar'
        tempfile exclude2
        qui save `exclude2', replace emptyok
        tempfile exclude3
        qui save `exclude3', replace emptyok

        * Create empty censor file
        qui gen long migration_out_dt = .
        qui label var migration_out_dt "Emigration censoring date"
        tempfile censor_data
        qui save `censor_data', replace emptyok
    }
    else {
        * Drop individuals who immigrated before study_start with no emigration record
        qui drop if `last_in' < `startvar' & `last_out' == .

        * EXCLUSION 3: Emigrated before study_start and returned after (abroad at baseline)
        qui gen `exclude_abroad' = 0
        qui replace `exclude_abroad' = 1 if out_ < `startvar' & in_ > `startvar' & in_ != .

        tempfile pre_exclude3
        qui save `pre_exclude3', replace

        * Save exclusions (type 3)
        qui keep if `exclude_abroad' == 1
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
        qui drop if `exclude_abroad' == 1
        qui drop `exclude_abroad'

        * Drop emigration records before study_start
        qui drop if out_ < `startvar'

        * Recalculate migration sequence
        qui drop num `last_out' `last_in'
        qui egen `last_out' = max(out_), by(`idvar')
        qui egen `last_in' = max(in_), by(`idvar')
        qui format `last_out' `last_in' %tdCCYY/NN/DD
        qui bysort `idvar' (out_ in_): gen `num' = _n
        qui egen `total_migrations' = max(`num'), by(`idvar')

        * Drop if only one migration and it's an immigration before study_start
        qui drop if `total_migrations' == 1 & `last_in' < `startvar'

        * EXCLUSION 2: Only migration is immigration after study_start (not in Sweden at baseline)
        qui gen `exclude_inmigration' = 0
        qui replace `exclude_inmigration' = 1 if in_ > `startvar' & out_ == . & `total_migrations' == 1 & in_ != .

        * Calculate emigration censoring date
        * Only permanent emigrations (no subsequent return) generate censoring dates
        tempvar is_perm_emig
        qui gen byte `is_perm_emig' = (`exclude_inmigration' == 0 & out_ != . & out_ > `startvar' & (in_ == . | in_ <= out_))

        * Earliest permanent emigration per person
        tempvar min_perm_out
        qui egen long `min_perm_out' = min(out_) if `is_perm_emig' == 1, by(`idvar')

        * Propagate to all rows for each person
        tempvar person_censor
        qui egen long `person_censor' = min(`min_perm_out'), by(`idvar')
        qui gen long migration_out_dt = `person_censor'
        qui format migration_out_dt %tdCCYY/NN/DD

        * Collapse to one row per person
        qui drop `total_migrations' `num'
        qui bysort `idvar' (out_ in_): gen `num' = _n
        qui drop if `num' > 1

        * Save current state before extracting exclusions type 2
        tempfile pre_exclude2
        qui save `pre_exclude2', replace

        * Save exclusions (type 2)
        qui keep if `exclude_inmigration' == 1
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
        qui keep if `exclude_inmigration' == 0
        qui keep `idvar' migration_out_dt
        if _N > 0 {
            qui duplicates drop `idvar', force
        }
        qui label var migration_out_dt "Emigration censoring date"

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

    * Combine exclusion files
    qui use `exclude1', clear
    qui append using `exclude2'
    qui append using `exclude3'
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
    cap drop migration_out_dt

    * Remove excluded individuals
    qui merge 1:1 `idvar' using `exclude_data', keep(1) nogen

    * Merge censoring dates
    qui merge 1:1 `idvar' using `censor_data', keep(1 3) nogen
    
    * Commit changes (don't restore to original)
    restore, not

    * Restore varabbrev setting
    set varabbrev `vabbrev_save'

    * Display summary
    display as text _n "Migration Processing Summary"
    display as text "{hline 55}"
    display as text "Excluded (emigrated before start, no return):    " as result `n_exclude1'
    display as text "Excluded (immigration after study start):        " as result `n_exclude2'
    display as text "Excluded (abroad at baseline, returned after):   " as result `n_exclude3'
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
    return scalar N_excluded_total = `n_exclude_total'
    return scalar N_censored = `n_censor'
    return scalar N_final = _N

end
