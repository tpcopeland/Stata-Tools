*! pira Version 1.0.1  2025/12/31
*! Progression Independent of Relapse Activity
*! Author: Tim Copeland
*! Program class: rclass

/*
Progression Independent of Relapse Activity (PIRA) Algorithm:

PIRA identifies confirmed disability progression (CDP) events that occur
OUTSIDE of a window around relapses, indicating progression not attributable
to acute relapse activity.

1. Runs CDP algorithm to identify confirmed progression events
2. For each CDP event, checks if it falls within the relapse window
3. Events outside the relapse window are classified as PIRA
4. Events within the relapse window are classified as RAW (Relapse-Associated Worsening)

Basic syntax:
  pira idvar edssvar datevar, dxdate(varname) relapses(filename) [options]

Required:
  dxdate(varname)       - Diagnosis date variable
  relapses(filename)    - Path to relapse dataset (must contain id and relapse_date)

Options:
  relapseidvar(varname) - ID variable in relapse file (default: same as idvar)
  relapsedatevar(varname) - Relapse date variable (default: relapse_date)
  windowbefore(#)       - Days before relapse to exclude (default: 90)
  windowafter(#)        - Days after relapse to exclude (default: 30)
  generate(name)        - Name for PIRA date variable (default: pira_date)
  rawgenerate(name)     - Name for RAW date variable (default: raw_date)
  confirmdays(#)        - Days for CDP confirmation (default: 180)
  baselinewindow(#)     - Days from diagnosis for baseline EDSS (default: 730)
  rebaselinerelapse     - Reset baseline EDSS after each relapse
  roving                - Use roving baseline after each progression
  allevents             - Track all events, not just first
  keepall               - Retain all observations
  quietly               - Suppress output messages

See help pira for complete documentation
*/

program define pira, rclass
    version 16.0
    set varabbrev off

    syntax varlist(min=3 max=3) [if] [in], ///
        DXdate(varname) ///
        RELapses(string) ///
        [ ///
        RELapseidvar(string) ///
        RELapsedatevar(string) ///
        WINDOWBefore(integer 90) ///
        WINDOWAfter(integer 30) ///
        GENerate(string) ///
        RAWgenerate(string) ///
        CONFirmdays(integer 180) ///
        BASElinewindow(integer 730) ///
        REBASElinerelapse ///
        ROVING ///
        ALLevents ///
        KEEPall ///
        Quietly ///
        ]

    // =========================================================================
    // PARSE AND VALIDATE
    // =========================================================================

    // Parse varlist: id edss date
    tokenize `varlist'
    local idvar `1'
    local edssvar `2'
    local datevar `3'

    // Default relapse file variables
    if "`relapseidvar'" == "" {
        local relapseidvar "`idvar'"
    }
    if "`relapsedatevar'" == "" {
        local relapsedatevar "relapse_date"
    }

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
    capture confirm numeric variable `dxdate'
    if _rc {
        di as error "`dxdate' must be numeric (Stata date format)"
        exit 109
    }

    // Check relapse file exists
    capture confirm file "`relapses'"
    if _rc {
        di as error "relapse file not found: `relapses'"
        exit 601
    }

    // Validate window options
    if `windowbefore' < 0 {
        di as error "windowbefore() must be non-negative"
        exit 198
    }
    if `windowafter' < 0 {
        di as error "windowafter() must be non-negative"
        exit 198
    }
    if `confirmdays' <= 0 {
        di as error "confirmdays() must be positive"
        exit 198
    }
    if `baselinewindow' <= 0 {
        di as error "baselinewindow() must be positive"
        exit 198
    }

    // Default generate names
    if "`generate'" == "" {
        local generate "pira_date"
    }
    if "`rawgenerate'" == "" {
        local rawgenerate "raw_date"
    }

    // Check if generate variables already exist
    capture confirm variable `generate'
    if _rc == 0 {
        di as error "variable `generate' already exists"
        exit 110
    }
    capture confirm variable `rawgenerate'
    if _rc == 0 {
        di as error "variable `rawgenerate' already exists"
        exit 110
    }

    // Mark sample
    marksample touse
    markout `touse' `dxdate'

    // Check for valid observations
    qui count if `touse'
    if r(N) == 0 {
        di as error "no valid observations"
        exit 2000
    }

    // =========================================================================
    // LOAD AND PREPARE RELAPSE DATA
    // =========================================================================

    tempfile master_data relapse_data

    preserve

    // Save master data
    qui keep if `touse'
    qui save `master_data', replace

    // Load relapse data
    qui use "`relapses'", clear

    // Validate relapse file has required variables
    capture confirm variable `relapseidvar'
    if _rc {
        di as error "relapse file must contain variable `relapseidvar'"
        restore
        exit 111
    }
    capture confirm variable `relapsedatevar'
    if _rc {
        di as error "relapse file must contain variable `relapsedatevar'"
        restore
        exit 111
    }

    // Keep only id and relapse date
    qui keep `relapseidvar' `relapsedatevar'
    qui rename `relapseidvar' `idvar'
    qui rename `relapsedatevar' _relapse_dt
    qui drop if missing(_relapse_dt)

    // Save relapse data
    qui save `relapse_data', replace

    // =========================================================================
    // STEP 1: RUN CDP ALGORITHM
    // =========================================================================

    qui use `master_data', clear

    // Run CDP to find all confirmed progression events
    // We need to track all events internally even if user only wants first
    tempvar baseline_edss baseline_date prog_thresh edss_change ///
            is_prog first_prog_dt confirm_edss confirmed obs_id ///
            current_baseline current_base_dt

    // Keep only relevant variables
    qui keep `idvar' `edssvar' `datevar' `dxdate'

    // Drop missing EDSS or date values
    qui drop if missing(`edssvar') | missing(`datevar')

    // Check for valid observations
    qui count
    if r(N) == 0 {
        di as error "no valid observations after dropping missing values"
        restore
        exit 2000
    }

    // Sort data
    qui sort `idvar' `datevar' `edssvar'

    // Generate observation ID
    qui gen long `obs_id' = _n

    // -------------------------------------------------------------------------
    // Determine baseline EDSS
    // -------------------------------------------------------------------------

    qui gen double `baseline_edss' = .
    qui gen long `baseline_date' = .

    // First EDSS within baseline window of diagnosis
    qui bysort `idvar' (`datevar'): gen double _temp_base = `edssvar' ///
        if `datevar' >= `dxdate' & `datevar' <= `dxdate' + `baselinewindow'
    qui bysort `idvar' (`datevar'): replace `baseline_edss' = _temp_base[1] ///
        if !missing(_temp_base[1])
    qui bysort `idvar' (`datevar'): gen long _temp_basedt = `datevar' ///
        if `datevar' >= `dxdate' & `datevar' <= `dxdate' + `baselinewindow'
    qui bysort `idvar' (`datevar'): replace `baseline_date' = _temp_basedt[1] ///
        if !missing(_temp_basedt[1])
    qui drop _temp_base _temp_basedt

    // If no EDSS within window, use earliest available
    qui bysort `idvar' (`datevar'): replace `baseline_edss' = `edssvar'[1] ///
        if missing(`baseline_edss')
    qui bysort `idvar' (`datevar'): replace `baseline_date' = `datevar'[1] ///
        if missing(`baseline_date')

    // Propagate baseline
    qui bysort `idvar' (`datevar'): replace `baseline_edss' = `baseline_edss'[1]
    qui bysort `idvar' (`datevar'): replace `baseline_date' = `baseline_date'[1]

    // -------------------------------------------------------------------------
    // Re-baseline after relapse (if requested)
    // -------------------------------------------------------------------------

    if "`rebaselinerelapse'" != "" {
        // Merge relapse dates
        qui merge m:m `idvar' using `relapse_data', nogen keep(1 3)

        // For each person, if there's a relapse after baseline,
        // use first EDSS after last relapse (within reason) as new baseline
        qui gen byte _has_relapse = !missing(_relapse_dt) & _relapse_dt > `baseline_date'
        qui egen long _last_relapse = max(cond(_has_relapse, _relapse_dt, .)), by(`idvar')

        // Find first EDSS at least 30 days after last relapse (recovery period)
        qui gen byte _post_relapse = (`datevar' >= _last_relapse + 30) & !missing(_last_relapse)
        qui bysort `idvar' (`datevar'): gen double _new_base = `edssvar' if _post_relapse
        qui bysort `idvar' (`datevar'): egen double _new_baseline = min(_new_base)
        qui bysort `idvar' (`datevar'): gen long _new_basedt = `datevar' if _post_relapse
        qui bysort `idvar' (`datevar'): egen long _new_baseline_dt = min(_new_basedt)

        // Update baseline if post-relapse baseline exists
        qui replace `baseline_edss' = _new_baseline if !missing(_new_baseline)
        qui replace `baseline_date' = _new_baseline_dt if !missing(_new_baseline_dt)

        qui drop _has_relapse _last_relapse _post_relapse _new_base _new_baseline _new_basedt _new_baseline_dt _relapse_dt
    }

    // -------------------------------------------------------------------------
    // Identify CDP events
    // -------------------------------------------------------------------------

    // Progression threshold
    qui gen double `prog_thresh' = cond(`baseline_edss' <= 5.5, 1.0, 0.5)

    // Calculate change from baseline
    qui gen double `edss_change' = `edssvar' - `baseline_edss'

    // Flag measurements that meet progression threshold (after baseline)
    qui gen byte `is_prog' = (`edss_change' >= `prog_thresh') & (`datevar' > `baseline_date')

    // Find first potential progression date per person
    qui egen long `first_prog_dt' = min(cond(`is_prog' == 1, `datevar', .)), by(`idvar')

    // Check for confirmation
    qui gen double `confirm_edss' = .
    qui replace `confirm_edss' = `edssvar' if `datevar' >= `first_prog_dt' + `confirmdays'
    qui egen double _min_confirm = min(`confirm_edss'), by(`idvar')

    // Confirmed if minimum EDSS in confirmation period still meets threshold
    qui gen byte `confirmed' = (_min_confirm >= `baseline_edss' + `prog_thresh') & !missing(_min_confirm)
    qui drop _min_confirm

    // Keep confirmed CDP events
    tempvar cdp_dt
    qui gen long `cdp_dt' = `first_prog_dt' if `confirmed' == 1
    format `cdp_dt' %tdCCYY/NN/DD

    // =========================================================================
    // STEP 2: CLASSIFY AS PIRA OR RAW
    // =========================================================================

    // Rename tempvars to regular names before keep (tempvars can be lost across operations)
    qui rename `cdp_dt' _pira_cdp_dt
    qui rename `baseline_edss' _pira_baseline

    // Keep one record per person with CDP
    qui keep `idvar' _pira_cdp_dt _pira_baseline
    qui duplicates drop `idvar', force
    qui drop if missing(_pira_cdp_dt)

    // Merge with relapse data to check proximity
    qui merge 1:m `idvar' using `relapse_data', nogen keep(1 3)

    // Check if CDP date falls within relapse window
    // Window: [relapse_date - windowbefore, relapse_date + windowafter]
    qui gen byte _in_relapse_window = inrange(_pira_cdp_dt, _relapse_dt - `windowbefore', ///
        _relapse_dt + `windowafter') if !missing(_relapse_dt)

    // Collapse: any relapse within window makes it RAW
    qui egen byte _any_relapse_window = max(_in_relapse_window), by(`idvar')
    qui replace _any_relapse_window = 0 if missing(_any_relapse_window)

    // Classify
    qui gen long `generate' = _pira_cdp_dt if _any_relapse_window == 0
    qui gen long `rawgenerate' = _pira_cdp_dt if _any_relapse_window == 1
    format `generate' `rawgenerate' %tdCCYY/NN/DD

    // Keep one record per person
    qui keep `idvar' `generate' `rawgenerate' _pira_baseline
    qui duplicates drop `idvar', force

    // Clean up internal variable
    qui drop _pira_baseline

    // Count results
    qui count if !missing(`generate')
    local n_pira = r(N)
    qui count if !missing(`rawgenerate')
    local n_raw = r(N)
    qui count
    local n_cdp = r(N)

    // Save results
    tempfile results
    qui save `results', replace

    restore

    // =========================================================================
    // MERGE RESULTS BACK
    // =========================================================================

    if "`keepall'" == "" {
        // Default: keep only patients with any CDP (PIRA or RAW)
        qui merge m:1 `idvar' using `results', nogen keep(3)
    }
    else {
        // keepall: retain all original observations
        qui merge m:1 `idvar' using `results', nogen
    }

    // Label variables
    label var `generate' "PIRA date (progression independent of relapse)"
    label var `rawgenerate' "RAW date (relapse-associated worsening)"

    // =========================================================================
    // OUTPUT AND RETURN
    // =========================================================================

    if "`quietly'" == "" {
        di as text _n "Progression Independent of Relapse Activity (PIRA) complete"
        di as text "  Relapse window: `windowbefore' days before to `windowafter' days after"
        di as text "  Baseline window: `baselinewindow' days from diagnosis"
        di as text "  Confirmation period: `confirmdays' days"
        di as text "  Re-baseline after relapse: " cond("`rebaselinerelapse'" != "", "Yes", "No")
        di as text _n "Results:"
        di as text "  Total CDP events: `n_cdp'"
        di as text "  PIRA events: `n_pira'"
        di as text "  RAW events: `n_raw'"
        di as text _n "  Variables created: `generate', `rawgenerate'"
    }

    // Return values
    return scalar N_cdp = `n_cdp'
    return scalar N_pira = `n_pira'
    return scalar N_raw = `n_raw'
    return scalar windowbefore = `windowbefore'
    return scalar windowafter = `windowafter'
    return scalar confirmdays = `confirmdays'
    return scalar baselinewindow = `baselinewindow'
    return local pira_varname "`generate'"
    return local raw_varname "`rawgenerate'"
    return local rebaselinerelapse = cond("`rebaselinerelapse'" != "", "yes", "no")

end
