*! pira Version 1.2.0  2026/04/24
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
    local _varabbrev `c(varabbrev)'
    set varabbrev off

    capture noisily {

    syntax varlist(min=3 max=3) [if] [in], ///
        DXdate(varname) ///
        RELapses(string) ///
        [ ///
        RELAPSEIdvar(string) ///
        RELAPSEDatevar(string) ///
        WINDOWBefore(integer 90) ///
        WINDOWAfter(integer 30) ///
        GENerate(name) ///
        RAWgenerate(name) ///
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
    local _pira_date_fmt : format `datevar'
    if lower(substr("`_pira_date_fmt'", 1, 3)) != "%td" {
        di as error "`datevar' must be a Stata daily date variable with %td format"
        exit 109
    }
    capture confirm numeric variable `dxdate'
    if _rc {
        di as error "`dxdate' must be numeric (Stata date format)"
        exit 109
    }
    local _pira_dx_fmt : format `dxdate'
    if lower(substr("`_pira_dx_fmt'", 1, 3)) != "%td" {
        di as error "`dxdate' must be a Stata daily date variable with %td format"
        exit 109
    }
    local id_is_str = 0
    capture confirm string variable `idvar'
    if !_rc local id_is_str = 1

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
    if lower("`generate'") == lower("`rawgenerate'") {
        di as error "generate() and rawgenerate() must specify different variable names"
        exit 198
    }
    foreach _pira_out in `generate' `rawgenerate' {
        if substr(lower("`_pira_out'"), 1, 6) == "_pira_" | ///
            lower("`_pira_out'") == "_relapse_dt" {
            di as error "generate() and rawgenerate() may not use reserved internal names"
            exit 198
        }
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
    if `id_is_str' {
        quietly replace `touse' = 0 if trim(`idvar') == "" & `touse'
    }
    else {
        markout `touse' `idvar'
    }
    markout `touse' `dxdate'

    // Check for valid observations
    qui count if `touse'
    if r(N) == 0 {
        di as error "no valid observations"
        exit 2000
    }
    qui count if `touse' & !missing(`datevar') & `datevar' != floor(`datevar')
    if r(N) > 0 {
        di as error "`datevar' must contain whole-number Stata daily dates"
        exit 109
    }
    qui count if `touse' & !missing(`dxdate') & `dxdate' != floor(`dxdate')
    if r(N) > 0 {
        di as error "`dxdate' must contain whole-number Stata daily dates"
        exit 109
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
    capture confirm numeric variable `relapsedatevar'
    if _rc {
        di as error "`relapsedatevar' in relapse file must be numeric (Stata date format)"
        restore
        exit 109
    }
    local _pira_rel_fmt : format `relapsedatevar'
    if lower(substr("`_pira_rel_fmt'", 1, 3)) != "%td" {
        di as error "`relapsedatevar' in relapse file must be a Stata daily date variable with %td format"
        restore
        exit 109
    }

    // Validate ID type matches master data
    local rel_id_is_str = 0
    capture confirm string variable `relapseidvar'
    if !_rc local rel_id_is_str = 1
    if `id_is_str' != `rel_id_is_str' {
        di as error "`relapseidvar' type mismatch: " ///
            cond(`id_is_str', "string in master, numeric in relapse file", ///
            "numeric in master, string in relapse file")
        restore
        exit 109
    }

    // Keep only id and relapse date
    qui keep `relapseidvar' `relapsedatevar'
    qui rename `relapseidvar' `idvar'
    qui rename `relapsedatevar' _relapse_dt
    if `rel_id_is_str' {
        qui drop if trim(`idvar') == ""
    }
    else {
        qui drop if missing(`idvar')
    }
    qui drop if missing(_relapse_dt)
    qui count if _relapse_dt != floor(_relapse_dt)
    if r(N) > 0 {
        di as error "`relapsedatevar' in relapse file must contain whole-number Stata daily dates"
        restore
        exit 109
    }

    // Save relapse data (long: one row per relapse per person)
    qui save `relapse_data', replace emptyok

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
    qui bysort `idvar' (`datevar' `edssvar'): replace _pira_bl_edss = _pira_bl_edss[1] ///
        if missing(_pira_bl_edss) & !missing(_pira_bl_edss[1])
    qui bysort `idvar' (`datevar' `edssvar'): replace _pira_bl_date = _pira_bl_date[1] ///
        if missing(_pira_bl_date) & !missing(_pira_bl_date[1])

    qui drop _pira_in_win _pira_1st_win

    // If no EDSS within window, use earliest available (lowest EDSS on ties)
    qui bysort `idvar' (`datevar' `edssvar'): replace _pira_bl_edss = `edssvar'[1] ///
        if missing(_pira_bl_edss)
    qui bysort `idvar' (`datevar' `edssvar'): replace _pira_bl_date = `datevar'[1] ///
        if missing(_pira_bl_date)

    // Propagate baseline
    qui bysort `idvar' (`datevar' `edssvar'): replace _pira_bl_edss = _pira_bl_edss[1]
    qui bysort `idvar' (`datevar' `edssvar'): replace _pira_bl_date = _pira_bl_date[1]

    // -------------------------------------------------------------------------
    // Re-baseline after relapse (if requested)
    // -------------------------------------------------------------------------

    if "`rebaselinerelapse'" != "" {
        tempfile pira_visits pira_relapse_events pira_baseline_by_id

        // Walk forward through visit and relapse events so only relapses
        // observed up to each visit can trigger a baseline reset.
        qui save `pira_visits', replace

        qui keep `idvar' _pira_bl_edss _pira_bl_date
        qui duplicates drop `idvar', force
        qui save `pira_baseline_by_id', replace

        qui use `pira_visits', clear
        qui gen byte _pira_is_visit = 1
        qui save `pira_visits', replace

        qui use `relapse_data', clear
        qui rename _relapse_dt `datevar'
        qui gen double `edssvar' = .
        qui gen long _pira_obs_id = .
        qui gen byte _pira_is_visit = 0
        qui merge m:1 `idvar' using `pira_baseline_by_id', nogen keep(3)
        qui save `pira_relapse_events', replace emptyok

        qui use `pira_visits', clear
        qui append using `pira_relapse_events'
        qui sort `idvar' `datevar' _pira_is_visit `edssvar' _pira_obs_id

        qui bysort `idvar' (`datevar' _pira_is_visit `edssvar' _pira_obs_id): ///
            gen byte _pira_newid = _n == 1
        qui gen double _pira_cur_bl_edss = .
        qui gen long _pira_cur_bl_date = .
        qui gen long _pira_pending_rel = .

        qui count
        local n_rebase_rows = r(N)
        forvalues i = 1/`n_rebase_rows' {
            if _pira_newid[`i'] {
                qui replace _pira_cur_bl_edss = _pira_bl_edss in `i'
                qui replace _pira_cur_bl_date = _pira_bl_date in `i'
                qui replace _pira_pending_rel = . in `i'
            }
            else {
                local j = `i' - 1
                qui replace _pira_cur_bl_edss = _pira_cur_bl_edss[`j'] in `i'
                qui replace _pira_cur_bl_date = _pira_cur_bl_date[`j'] in `i'
                qui replace _pira_pending_rel = _pira_pending_rel[`j'] in `i'
            }

            if _pira_is_visit[`i'] == 0 {
                if !missing(`datevar'[`i']) & `datevar'[`i'] > _pira_cur_bl_date[`i'] {
                    qui replace _pira_pending_rel = `datevar' in `i'
                }
            }
            else {
                if !missing(_pira_pending_rel[`i']) & `datevar'[`i'] >= _pira_pending_rel[`i'] + 30 {
                    qui replace _pira_cur_bl_edss = `edssvar' in `i'
                    qui replace _pira_cur_bl_date = `datevar' in `i'
                    qui replace _pira_pending_rel = . in `i'
                }
                qui replace _pira_bl_edss = _pira_cur_bl_edss[`i'] in `i'
                qui replace _pira_bl_date = _pira_cur_bl_date[`i'] in `i'
            }
        }

        qui keep if _pira_is_visit == 1
        qui sort `idvar' `datevar' `edssvar'
        qui drop _pira_is_visit _pira_newid _pira_cur_bl_edss ///
            _pira_cur_bl_date _pira_pending_rel
    }

    // -------------------------------------------------------------------------
    // Identify CDP events (iterative confirmation)
    // -------------------------------------------------------------------------
    // If the first candidate progression date fails confirmation, exclude it
    // and try the next candidate. Mirrors logic in cdp.ado.

    // Progression threshold
    qui gen double _pira_pthresh = cond(_pira_bl_edss <= 5.5, 1.0, 0.5)

    // Calculate change from baseline
    qui gen double _pira_edss_chg = `edssvar' - _pira_bl_edss

    // Flag measurements that meet progression threshold (after baseline)
    qui gen byte _pira_is_prog = (_pira_edss_chg >= _pira_pthresh) & (`datevar' > _pira_bl_date)

    // Iterative confirmation: try each candidate progression date in order
    qui gen byte _pira_candidate_ok = 0

    local max_cdp_iter = 100
    local cdp_iter = 1
    local cdp_found = 0
    while `cdp_found' == 0 & `cdp_iter' <= `max_cdp_iter' {
        // Find earliest remaining candidate progression date per person
        capture drop _pira_1st_prog
        qui egen long _pira_1st_prog = min(cond(_pira_is_prog == 1, `datevar', .)), by(`idvar')

        // Check if any candidates remain
        qui count if !missing(_pira_1st_prog)
        if r(N) == 0 {
            continue, break
        }

        // Check for confirmation (sustained-throughout definition)
        capture drop _pira_conf_edss
        capture drop _pira_min_conf
        qui gen double _pira_conf_edss = .
        qui replace _pira_conf_edss = `edssvar' if `datevar' >= _pira_1st_prog + `confirmdays'
        qui egen double _pira_min_conf = min(_pira_conf_edss), by(`idvar')

        // Check if confirmed for each person
        capture drop _pira_candidate_ok
        qui gen byte _pira_candidate_ok = (_pira_min_conf >= _pira_bl_edss + _pira_pthresh) & !missing(_pira_min_conf)

        // For persons whose candidate failed: exclude that date and retry
        qui count if _pira_candidate_ok == 0 & !missing(_pira_1st_prog) & `datevar' == _pira_1st_prog
        local n_failed = r(N)

        if `n_failed' == 0 {
            local cdp_found = 1
        }
        else {
            qui replace _pira_is_prog = 0 if _pira_candidate_ok == 0 & `datevar' == _pira_1st_prog
            local cdp_iter = `cdp_iter' + 1
        }

        qui drop _pira_min_conf
    }

    // CDP date is the confirmed candidate date
    qui gen long _pira_cdp_dt = _pira_1st_prog if _pira_candidate_ok == 1
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

    // Clean up internal variables (drop separately so one missing doesn't block the other)
    capture qui drop _pira_baseline
    capture qui drop _pira_cdp_dt

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

    }
    local _rc = _rc
    set varabbrev `_varabbrev'
    if `_rc' exit `_rc'
end
