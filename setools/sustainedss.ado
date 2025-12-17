*! sustainedss Version 1.0.1  03dec2025  Tim Copeland
*! Compute sustained EDSS progression date
*! Part of the setools package

program define sustainedss, rclass
    version 16.0
    set varabbrev off

    syntax varlist(min=3 max=3) [if] [in], ///
        THreshold(real) ///
        [ ///
        GENerate(string) ///
        CONFirmwindow(integer 182) ///
        BASElinethreshold(real 4) ///
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
    
    // Default generate name
    if "`generate'" == "" {
        local generate "sustained`=subinstr(string(`threshold'),".","_",.)'_dt"
    }
    
    // Check if generate variable already exists
    capture confirm variable `generate'
    if _rc == 0 {
        di as error "variable `generate' already exists"
        exit 110
    }
    
    // Mark sample
    marksample touse

    // Check for valid observations BEFORE preserve
    qui count if `touse'
    if r(N) == 0 {
        di as error "no valid observations"
        exit 2000
    }

    // Declare temporary variables
    tempvar edss_work obs_id first_dt lowest_after lastdt_window last_window not_sustained sustained_dt

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
    
    while `keep_going' == 1 {
        qui use `working', clear

        // Find first date when EDSS >= threshold for each person
        qui egen long `first_dt' = min(cond(`edss_work' >= `threshold', `datevar', .)), by(`idvar')

        // Find lowest EDSS in confirmation window (1 to `confirmwindow' days after first date)
        qui egen double `lowest_after' = min(cond( ///
            inrange(`datevar', `first_dt' + 1, `first_dt' + `confirmwindow'), ///
            `edss_work', .)), by(`idvar')

        // Find last date in confirmation window
        qui egen long `lastdt_window' = max(cond( ///
            inrange(`datevar', `first_dt' + 1, `first_dt' + `confirmwindow'), ///
            `datevar', .)), by(`idvar')

        // Find EDSS at last date in window
        qui egen double `last_window' = max(cond( ///
            `datevar' == `lastdt_window', ///
            `edss_work', .)), by(`idvar')

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
    qui egen long `sustained_dt' = min(cond(`edss_work' >= `threshold', `datevar', .)), by(`idvar')
    format `sustained_dt' %tdCCYY/NN/DD

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
    
    // Label variable
    label var `generate' "Sustained EDSS >= `threshold' date"
    
    // Display results
    if "`quietly'" == "" {
        di as text _n "Sustained EDSS >= `threshold' computation complete"
        di as text "  Confirmation window: `confirmwindow' days"
        di as text "  Baseline threshold: `baselinethreshold'"
        di as text "  Events identified: `n_events'"
        di as text "  Iterations required: `iteration'"
        di as text "  Variable created: `generate'"
    }
    
    // Return values
    return scalar N_events = `n_events'
    return scalar iterations = `iteration'
    return scalar threshold = `threshold'
    return scalar confirmwindow = `confirmwindow'
    return local varname "`generate'"
    
end
