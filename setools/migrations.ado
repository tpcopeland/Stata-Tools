*! migrations Version 1.0.1  03dec2025  Tim Copeland
*! Handle Swedish migration data for registry-based cohort studies
*! Part of the setools package

program define migrations, rclass
    version 16.0
    set varabbrev off
    syntax , MIGfile(string) [IDvar(varname) STARTvar(varname) SAVEexclude(string) SAVEcensor(string) REPLACE VERBOSE]

    * Declare temporary variables
    tempvar last_out last_in exclude_emigrated num total_migrations exclude_inmigration

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
    
    * Check that startvar is a date
    local fmt : format `startvar'
    if !regexm("`fmt'", "%t") & !regexm("`fmt'", "%d") {
        display as error "`startvar' does not appear to be a date variable"
        exit 198
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
        return scalar N_excluded_emigrated = 0
        return scalar N_excluded_inmigration = 0
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
    qui replace `exclude_emigrated' = 1 if `last_out' < `startvar' & `last_in' < `last_out'
    
    tempfile temp_migrations
    qui save `temp_migrations', replace
    
    * Save list of exclusions (type 1)
    qui keep if `exclude_emigrated' == 1
    qui keep `idvar'
    qui duplicates drop `idvar', force
    qui gen exclude_reason = "Emigrated before study start, never returned"

    tempfile exclude1
    qui save `exclude1', replace
    local n_exclude1 = _N

    * Continue with remaining individuals
    qui use `temp_migrations', clear
    qui drop if `exclude_emigrated' == 1
    qui drop `exclude_emigrated'

    * Drop individuals who immigrated before study_start with no emigration record
    qui drop if `last_in' < `startvar' & `last_out' == .

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
    qui replace `exclude_inmigration' = 1 if in_ > `startvar' & `total_migrations' == 1 & in_ != .

    * Calculate emigration censoring date
    * Use last emigration after study_start as initial censoring date
    qui gen migration_out_dt = `last_out' if `startvar' < `last_out' & `last_out' != .
    
    * Handle complex migration patterns:
    * - Drop records where immigration occurred after the censoring emigration
    qui drop if in_ > migration_out_dt & in_ != .
    * - Drop immigration records after study_start except the first (handles re-entries)
    qui drop if in_ > `startvar' & `num' != 1
    * - Drop if last immigration was before study_start with no emigration (already in Sweden)
    qui drop if `last_in' < `startvar' & `last_out' == .

    qui format migration_out_dt %tdCCYY/NN/DD
    qui drop `total_migrations' `num'
    qui bysort `idvar' (out_ in_): gen `num' = _n
    qui egen `total_migrations' = max(`num'), by(`idvar')
    * Clear pre-study immigrations (not relevant for censoring)
    qui replace in_ = . if in_ < `startvar'
    * Update censoring date to earliest emigration if multiple exist
    qui replace migration_out_dt = out_ if `exclude_inmigration' == 0 & out_ < migration_out_dt

    * Save exclusions (type 2)
    preserve
    qui keep if `exclude_inmigration' == 1
    qui keep `idvar'
    qui duplicates drop `idvar', force
    qui gen exclude_reason = "Immigration after study start (not in Sweden at baseline)"

    tempfile exclude2
    qui save `exclude2', replace
    local n_exclude2 = _N
    restore

    * Keep only non-excluded individuals
    qui keep if `exclude_inmigration' == 0
    qui keep `idvar' migration_out_dt
    qui duplicates drop `idvar', force
    qui label var migration_out_dt "Emigration censoring date"
    
    * Count censoring dates
    qui count if migration_out_dt != .
    local n_censor = r(N)
    local n_total = _N
    
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
    
    * Combine exclusion files
    qui use `exclude1', clear
    qui append using `exclude2'
    qui duplicates drop `idvar', force
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
    
    * Remove excluded individuals
    qui merge 1:1 `idvar' using `exclude_data', keep(1) nogen
    
    * Merge censoring dates
    qui merge 1:1 `idvar' using `censor_data', keep(1 3) nogen
    
    * Commit changes (don't restore to original)
    restore, not
    
    * Display summary
    display as text _n "Migration Processing Summary"
    display as text "{hline 50}"
    display as text "Excluded (emigrated before start, no return): " as result `n_exclude1'
    display as text "Excluded (immigration after study start):      " as result `n_exclude2'
    display as text "{hline 50}"
    display as text "Total excluded:                                " as result `n_exclude_total'
    display as text "Individuals with emigration censoring date:    " as result `n_censor'
    display as text "Final sample size:                             " as result _N
    display as text "{hline 50}"
    
    if _N == 0 {
        display as error "Warning: All observations were excluded by migration criteria"
    }
    
    * Return values
    return scalar N_excluded_emigrated = `n_exclude1'
    return scalar N_excluded_inmigration = `n_exclude2'
    return scalar N_excluded_total = `n_exclude_total'
    return scalar N_censored = `n_censor'
    return scalar N_final = _N
    
end
