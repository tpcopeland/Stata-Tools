*! pira Version 1.0.6  2026/02/28
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
  keepall               - Retain all observations
  quietly               - Suppress output messages

See help pira for complete documentation
*/

program define pira, rclass
    version 16.0
    set varabbrev off
    set more off

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

    // Mark sample (strok: allow string ID variables)
    marksample touse, strok
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

    tempfile master_data relapse_data relapse_collapsed

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

    // Save relapse data (long: one row per relapse per person)
    qui save `relapse_data', replace emptyok

    // Also create collapsed version (one row per person, max relapse date)
    // for rebaselinerelapse merge - avoids dataset switching later
    qui count
    if r(N) > 0 {
        qui collapse (max) _pira_last_rel = _relapse_dt, by(`idvar')
    }
    else {
        // Empty relapse file: create empty collapsed dataset with correct schema
        qui gen double _pira_last_rel = .
    }
    qui save `relapse_collapsed', replace emptyok

    // =========================================================================
    // STEP 1: RUN CDP ALGORITHM
    // NOTE: The CDP logic below mirrors cdp.ado. Changes to baseline
    // determination, progression threshold, or confirmation logic in
    // cdp.ado MUST be mirrored here, and vice versa.
    // =========================================================================

    qui use `master_data', clear

    // Run CDP to find all confirmed progression events
    // NOTE: Using _pira_* prefixed names (not tempvar) for all working
    // variables because tempvar counter corruption occurs when dataset
    // switching (use/clear) happens within the same program scope.
    // All _pira_* variables are cleaned up by keep/drop before restore.

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
    qui gen long _pira_obs_id = _n

    // -------------------------------------------------------------------------
    // Determine baseline EDSS
    // -------------------------------------------------------------------------

    qui gen double _pira_bl_edss = .
    qui gen long _pira_bl_date = .

    // First EDSS within baseline window of diagnosis
    // Use egen min() to find earliest date in window, then extract EDSS at that date
    qui gen byte _pira_in_win = (`datevar' >= `dxdate' & `datevar' <= `dxdate' + `baselinewindow')
    qui egen long _pira_1st_win = min(cond(_pira_in_win, `datevar', .)), by(`idvar')
    qui replace _pira_bl_edss = `edssvar' if `datevar' == _pira_1st_win & !missing(_pira_1st_win)
    qui replace _pira_bl_date = _pira_1st_win if !missing(_pira_1st_win)
    qui bysort `idvar' (`datevar'): replace _pira_bl_edss = _pira_bl_edss[1] ///
        if missing(_pira_bl_edss) & !missing(_pira_bl_edss[1])
    qui bysort `idvar' (`datevar'): replace _pira_bl_date = _pira_bl_date[1] ///
        if missing(_pira_bl_date) & !missing(_pira_bl_date[1])

    qui drop _pira_in_win _pira_1st_win

    // If no EDSS within window, use earliest available
    qui bysort `idvar' (`datevar'): replace _pira_bl_edss = `edssvar'[1] ///
        if missing(_pira_bl_edss)
    qui bysort `idvar' (`datevar'): replace _pira_bl_date = `datevar'[1] ///
        if missing(_pira_bl_date)

    // Propagate baseline
    qui bysort `idvar' (`datevar'): replace _pira_bl_edss = _pira_bl_edss[1]
    qui bysort `idvar' (`datevar'): replace _pira_bl_date = _pira_bl_date[1]

    // -------------------------------------------------------------------------
    // Re-baseline after relapse (if requested)
    // -------------------------------------------------------------------------

    if "`rebaselinerelapse'" != "" {
        // Merge pre-collapsed relapse data (one row per person, max date)
        // Collapsed file was created during relapse data preparation above
        qui merge m:1 `idvar' using `relapse_collapsed', nogen keep(1 3)

        // For each person, if there's a relapse after baseline,
        // use first EDSS after last relapse (within reason) as new baseline
        qui gen byte _pira_has_rel = !missing(_pira_last_rel) & _pira_last_rel > _pira_bl_date
        qui replace _pira_last_rel = . if !_pira_has_rel

        // Find first EDSS at least 30 days after last relapse (recovery period)
        qui gen byte _pira_post_rel = (`datevar' >= _pira_last_rel + 30) & !missing(_pira_last_rel)

        // Get earliest post-relapse date per person
        qui gen long _pira_new_bdt = `datevar' if _pira_post_rel
        qui bysort `idvar' (`datevar'): egen long _pira_new_bldt = min(_pira_new_bdt)

        // Get EDSS at that earliest post-relapse date (not min across all dates)
        qui gen double _pira_new_base = `edssvar' if `datevar' == _pira_new_bldt & _pira_post_rel
        qui bysort `idvar' (`datevar'): egen double _pira_new_bl = min(_pira_new_base)

        // Update baseline if post-relapse baseline exists
        qui replace _pira_bl_edss = _pira_new_bl if !missing(_pira_new_bl)
        qui replace _pira_bl_date = _pira_new_bldt if !missing(_pira_new_bldt)

        qui drop _pira_has_rel _pira_last_rel _pira_post_rel ///
            _pira_new_base _pira_new_bl _pira_new_bdt _pira_new_bldt
    }

    // -------------------------------------------------------------------------
    // Identify CDP events
    // -------------------------------------------------------------------------

    // Progression threshold
    qui gen double _pira_pthresh = cond(_pira_bl_edss <= 5.5, 1.0, 0.5)

    // Calculate change from baseline
    qui gen double _pira_edss_chg = `edssvar' - _pira_bl_edss

    // Flag measurements that meet progression threshold (after baseline)
    qui gen byte _pira_is_prog = (_pira_edss_chg >= _pira_pthresh) & (`datevar' > _pira_bl_date)

    // Find first potential progression date per person
    qui egen long _pira_1st_prog = min(cond(_pira_is_prog == 1, `datevar', .)), by(`idvar')

    // Check for confirmation (sustained-throughout definition):
    // The MINIMUM of all EDSS measurements at or after confirmdays must
    // still meet the progression threshold. This is more conservative
    // than "confirmed at next visit" - requires sustained progression
    // throughout entire follow-up. (Mirrors logic in cdp.ado)
    qui gen double _pira_conf_edss = .
    qui replace _pira_conf_edss = `edssvar' if `datevar' >= _pira_1st_prog + `confirmdays'
    qui egen double _pira_min_conf = min(_pira_conf_edss), by(`idvar')

    // Confirmed if minimum EDSS in post-confirmation period still meets threshold
    qui gen byte _pira_confirmed = (_pira_min_conf >= _pira_bl_edss + _pira_pthresh) & !missing(_pira_min_conf)
    qui drop _pira_min_conf

    // Keep confirmed CDP events
    qui gen long _pira_cdp_dt = _pira_1st_prog if _pira_confirmed == 1
    format _pira_cdp_dt %tdCCYY/NN/DD

    // =========================================================================
    // STEP 2: CLASSIFY AS PIRA OR RAW
    // =========================================================================

    // Rename working variable to keep name before keep
    qui rename _pira_bl_edss _pira_baseline

    // Keep one record per person with CDP
    qui keep `idvar' _pira_cdp_dt _pira_baseline
    qui duplicates drop `idvar', force
    qui drop if missing(_pira_cdp_dt)

    // Check if any CDP events exist before attempting relapse classification
    qui count
    local n_cdp = r(N)

    if `n_cdp' > 0 {
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
    }
    else {
        // No CDP events: create empty result variables
        qui gen long `generate' = .
        qui gen long `rawgenerate' = .
        format `generate' `rawgenerate' %tdCCYY/NN/DD
    }

    // Clean up internal variable
    capture qui drop _pira_baseline

    // Count results
    qui count if !missing(`generate')
    local n_pira = r(N)
    qui count if !missing(`rawgenerate')
    local n_raw = r(N)

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
