*! sustainedss Version 1.0.0  2026/04/08
*! Compute sustained EDSS progression date
*! Part of the setools package

program define sustainedss, rclass
    version 16.0
    local _varabbrev `c(varabbrev)'
    set varabbrev off

    capture noisily {

    syntax varlist(min=3 max=3) [if] [in], ///
        THreshold(real) ///
        [ ///
        GENerate(name) ///
        CONFirmwindow(integer 182) ///
        BASElinethreshold(real -1) ///
        KEEPall ///
        Quietly ///
        ]
    
    // Parse varlist: id edss edss_dt
    tokenize `varlist'
    local idvar `1'
    local edssvar `2'
    local datevar `3'
    
    // Validate variable types
    capture confirm numeric variable `edssvar'
    if _rc {
        di as error "`edssvar' must be numeric"
        exit 109
    }
    capture confirm numeric variable `datevar'
    if _rc {
        di as error "`datevar' must be numeric (Stata date format)"
        exit 109
    }
    
    // Check threshold value
    if `threshold' <= 0 {
        di as error "threshold() must be positive"
        exit 198
    }

    // Check confirmwindow value
    if `confirmwindow' <= 0 {
        di as error "confirmwindow() must be positive"
        exit 198
    }

    // Default baselinethreshold to threshold if not specified
    if `baselinethreshold' == -1 {
        local baselinethreshold = `threshold'
    }
    else if `baselinethreshold' < 0 {
        di as error "baselinethreshold() must be non-negative"
        exit 198
    }

    // Default generate name
    if "`generate'" == "" {
        if `threshold' == int(`threshold') {
            local generate "sustained`=int(`threshold')'_dt"
        }
        else {
            local generate "sustained`=subinstr(strtrim(strofreal(`threshold', "%9.1f")),".","_",.)'_dt"
        }
    }

    // Check if generate variable already exists
    capture confirm variable `generate'
    if _rc == 0 {
        di as error "variable `generate' already exists"
        exit 110
    }
    
    // Mark sample (strok: allow string ID variables)
    marksample touse, strok

    // Check for valid observations BEFORE preserve
    qui count if `touse'
    if r(N) == 0 {
        di as error "no valid observations"
        exit 2000
    }
    qui count
    local n_original = r(N)

    // Declare temporary variables
    tempvar edss_work obs_id first_dt lowest_after lastdt_window last_window not_sustained sustained_dt sortorder neg_dt

    // Save original sort order
    qui gen long `sortorder' = _n

    // Preserve original data
    preserve

    // Keep only relevant observations
    qui keep if `touse'
    qui keep `idvar' `edssvar' `datevar'

    // Drop missing values
    qui drop if missing(`edssvar') | missing(`datevar')

    // Check for valid observations (redundant but safe)
    qui count
    if r(N) == 0 {
        di as error "no valid observations after dropping missing values"
        restore
        exit 2000
    }

    // Create working edss variable (will be modified)
    qui gen double `edss_work' = `edssvar'

    // Sort data
    qui sort `idvar' `datevar' `edssvar'

    // Generate observation ID for merging
    qui gen long `obs_id' = _n
    
    // Save working dataset
    tempfile working
    qui save `working', replace
    
    // Iterative algorithm
    local keep_going = 1
    local iteration = 1
    local converged = 1

    local max_iterations = 1000
    while `keep_going' == 1 {
        if `iteration' > `max_iterations' {
            di as error "Warning: sustainedss reached `max_iterations' iterations without converging"
            local converged = 0
            local iteration = `iteration' - 1
            local keep_going = 0
            continue
        }
        qui use `working', clear

        // Find first date when EDSS >= threshold for each person
        // Note: avoid egen here — Stata's internal tempvar counter can be
        // corrupted by prior dataset switching (use/clear), causing egen to fail.
        qui gen long `first_dt' = `datevar' if `edss_work' >= `threshold'
        qui bysort `idvar' (`first_dt'): replace `first_dt' = `first_dt'[1]

        // Find lowest EDSS in confirmation window (1 to `confirmwindow' days after first date)
        qui gen double `lowest_after' = `edss_work' if inrange(`datevar', `first_dt' + 1, `first_dt' + `confirmwindow')
        qui bysort `idvar' (`lowest_after'): replace `lowest_after' = `lowest_after'[1]

        // Find last date in confirmation window (max via negated sort key)
        qui gen long `lastdt_window' = `datevar' if inrange(`datevar', `first_dt' + 1, `first_dt' + `confirmwindow')
        qui gen long `neg_dt' = -`lastdt_window'
        qui bysort `idvar' (`neg_dt'): replace `lastdt_window' = `lastdt_window'[1]
        qui drop `neg_dt'

        // Find EDSS at last date in window (min: conservative with same-date duplicates)
        qui gen double `last_window' = `edss_work' if `datevar' == `lastdt_window'
        qui bysort `idvar' (`last_window'): replace `last_window' = `last_window'[1]

        // Identify not sustained: lowest < baseline threshold AND last in window < threshold
        qui gen byte `not_sustained' = (`lowest_after' < `baselinethreshold' & ///
            !missing(`lowest_after') & ///
            `last_window' < `threshold' & ///
            !missing(`last_window'))

        // Keep only the records at the first threshold date that are not sustained
        tempfile notsustained
        qui keep if `datevar' == `first_dt' & `not_sustained' == 1
        
        qui count
        local n_rejected = r(N)
        
        if `n_rejected' == 0 {
            local keep_going = 0
        }
        else {
            if "`quietly'" == "" {
                di as text "Iteration `iteration': `n_rejected' events not confirmed as sustained"
            }

            // Save the records to update
            qui keep `obs_id' `last_window'
            qui save `notsustained', replace

            // Merge back and update working EDSS
            qui use `working', clear
            qui merge 1:1 `obs_id' using `notsustained', nogen keep(1 3)
            qui replace `edss_work' = `last_window' if !missing(`last_window')
            qui drop `last_window'

            qui save `working', replace
            local iteration = `iteration' + 1
        }
    }

    // Final computation of sustained date
    qui use `working', clear
    qui gen long `sustained_dt' = `datevar' if `edss_work' >= `threshold'
    qui bysort `idvar' (`sustained_dt'): replace `sustained_dt' = `sustained_dt'[1]
    qui format `sustained_dt' %tdCCYY/NN/DD

    // Keep one record per person with sustained date
    qui keep `idvar' `sustained_dt'
    qui duplicates drop `idvar', force
    qui drop if missing(`sustained_dt')
    qui rename `sustained_dt' `generate'
    
    // Count results
    qui count
    local n_events = r(N)
    
    tempfile results
    qui save `results', replace
    
    restore
    
    // Merge results back
    if "`keepall'" == "" {
        // Default: keep only patients with sustained events
        qui merge m:1 `idvar' using `results', nogen keep(3)
    }
    else {
        // keepall: retain all original observations
        qui merge m:1 `idvar' using `results', nogen
    }
    
    // Restore original sort order
    sort `sortorder'
    qui drop `sortorder'

    // Label variable
    label var `generate' "Sustained EDSS >= `threshold' date"
    
    // Count retained observations
    qui count
    local n_retained = r(N)

    // Display results
    if "`quietly'" == "" {
        di as text _n "Sustained EDSS >= `threshold' computation complete"
        di as text "  Confirmation window: `confirmwindow' days"
        di as text "  Baseline threshold: `baselinethreshold'"
        di as text "  Events identified: `n_events'"
        if `converged' {
            di as text "  Iterations required: `iteration'"
        }
        else {
            di as text "  Iterations required: `iteration' (limit reached, results may be approximate)"
        }
        di as text "  Variable created: `generate'"
        if "`keepall'" == "" & `n_retained' < `n_original' {
            di as text "  Observations: `n_retained' of `n_original' retained" ///
                " (use {bf:keepall} to keep all)"
        }
    }
    
    // Return values
    return scalar N_events = `n_events'
    return scalar iterations = `iteration'
    return scalar converged = `converged'
    return scalar threshold = `threshold'
    return scalar confirmwindow = `confirmwindow'
    return local varname "`generate'"

    }
    local _rc = _rc
    set varabbrev `_varabbrev'
    if `_rc' exit `_rc'
end
