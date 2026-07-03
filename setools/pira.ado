*! pira Version 1.4.1  2026/07/03
*! Progression Independent of Relapse Activity
*! Author: Timothy P Copeland, Karolinska Institutet
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
  confirmtype(type)     - sustained (default) or visit
  baselinewindow(#)     - Days from diagnosis for baseline EDSS (default: 730)
  threetier             - Use the three-tier progression threshold (default two-tier)
  eventvar(name)        - Create a 0/1 stset-ready PIRA event indicator
  rebaselinerelapse     - Reset baseline EDSS after each relapse
  keepall               - Retain all observations
  quietly               - Suppress output messages

See help pira for complete documentation
*/

program define pira, rclass
    version 16.0
    local _varabbrev `c(varabbrev)'
    tempvar _pira_sortorder
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
        THREEtier ///
        CONFIRMType(string) ///
        EVENTvar(name) ///
        EXIT(varname) ///
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

    // Confirmation type
    if "`confirmtype'" == "" {
        local confirmtype "sustained"
    }
    local confirmtype = lower("`confirmtype'")
    if !inlist("`confirmtype'", "sustained", "visit") {
        di as error "confirmtype() must be sustained or visit"
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
    foreach _pira_out in `generate' `rawgenerate' `eventvar' {
        if substr(lower("`_pira_out'"), 1, 6) == "_pira_" | ///
            substr(lower("`_pira_out'"), 1, 9) == "_setools_" | ///
            lower("`_pira_out'") == "_relapse_dt" {
            di as error "generate(), rawgenerate(), and eventvar() may not use reserved internal names"
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

    // Check eventvar name (must be new and distinct from generate/rawgenerate)
    if "`eventvar'" != "" {
        if "`eventvar'" == "`generate'" | "`eventvar'" == "`rawgenerate'" {
            di as error "eventvar() must differ from generate() and rawgenerate()"
            exit 198
        }
        capture confirm variable `eventvar'
        if _rc == 0 {
            di as error "variable `eventvar' already exists"
            exit 110
        }
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
    qui gen long `_pira_sortorder' = _n
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

    // Validate exit() study-exit date (used to censor post-exit events)
    local n_censored_exit = 0
    if "`exit'" != "" {
        capture confirm numeric variable `exit'
        if _rc {
            di as error "exit() must be a numeric Stata daily date variable"
            exit 109
        }
        local _pira_exit_fmt : format `exit'
        if lower(substr("`_pira_exit_fmt'", 1, 3)) != "%td" {
            di as error "exit() must be a Stata daily date variable with %td format"
            exit 109
        }
        qui count if `touse' & !missing(`exit') & `exit' != floor(`exit')
        if r(N) > 0 {
            di as error "exit() must contain whole-number Stata daily dates"
            exit 109
        }
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
    // Baseline, threshold, and confirmation come from the shared helpers
    // (_setools_cdp_baseline, _setools_cdp_thresh, _setools_cdp_confirm,
    // _setools_cdp_core) — the same engine cdp uses, so the two cannot desync.
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
    // Determine baseline EDSS (shared helper: _setools_cdp_baseline)
    // -------------------------------------------------------------------------
    _setools_cdp_baseline `idvar' `edssvar' `datevar', dxdate(`dxdate') ///
        baselinewindow(`baselinewindow') edssout(_pira_bl_edss) dateout(_pira_bl_date)

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
    // Identify CDP events via the shared engine (_setools_cdp_core)
    // Reduces data to one row per person carrying the confirmed CDP date.
    // -------------------------------------------------------------------------
    _setools_cdp_core `idvar' `edssvar' `datevar', ///
        baseedss(_pira_bl_edss) basedate(_pira_bl_date) ///
        confirmdays(`confirmdays') genname(_pira_cdp_dt) ///
        `threetier' confirmtype("`confirmtype'")
    local pira_converged  = r(converged)
    local pira_iterations = r(iterations)

    // =========================================================================
    // STEP 2: CLASSIFY AS PIRA OR RAW
    // =========================================================================

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
        qui keep `idvar' `generate' `rawgenerate'
        qui duplicates drop `idvar', force
    }
    else {
        // No CDP events: create empty result variables
        qui gen long `generate' = .
        qui gen long `rawgenerate' = .
        format `generate' `rawgenerate' %tdCCYY/NN/DD
    }

    // Clean up internal variables
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
    // exit() censoring: drop PIRA and RAW dates that fall after a person's
    // study-exit date (replaces hand-written post-exit clipping). Observations
    // are retained; eventvar() and the event counts reflect censoring. Both
    // dates are person-constant after the m:1 merge, so a by-person tag counts
    // persons; done before the sort-order restore so the tag does not disturb
    // output order.
    if "`exit'" != "" {
        tempvar _pira_exit_tag
        qui bysort `idvar': gen byte `_pira_exit_tag' = (_n == 1)
        qui count if `_pira_exit_tag' & !missing(`exit') & ///
            ((!missing(`generate') & `generate' > `exit') | ///
             (!missing(`rawgenerate') & `rawgenerate' > `exit'))
        local n_censored_exit = r(N)
        qui replace `generate' = . if !missing(`generate') & !missing(`exit') & `generate' > `exit'
        qui replace `rawgenerate' = . if !missing(`rawgenerate') & !missing(`exit') & `rawgenerate' > `exit'
        qui count if `_pira_exit_tag' & !missing(`generate')
        local n_pira = r(N)
        qui count if `_pira_exit_tag' & !missing(`rawgenerate')
        local n_raw = r(N)
        qui drop `_pira_exit_tag'
    }

    qui sort `_pira_sortorder'
    qui drop `_pira_sortorder'

    // Label variables
    label var `generate' "PIRA date (progression independent of relapse)"
    label var `rawgenerate' "RAW date (relapse-associated worsening)"

    // stset-ready event indicator (1 = PIRA event, matches generate())
    if "`eventvar'" != "" {
        qui gen byte `eventvar' = !missing(`generate') if `touse'
        label var `eventvar' "PIRA event (1 = progression independent of relapse)"
    }

    // =========================================================================
    // OUTPUT AND RETURN
    // =========================================================================

    if "`quietly'" == "" {
        di as text _n "Progression Independent of Relapse Activity (PIRA) complete"
        di as text "  Relapse window: `windowbefore' days before to `windowafter' days after"
        di as text "  Baseline window: `baselinewindow' days from diagnosis"
        di as text "  Confirmation period: `confirmdays' days"
        di as text "  Confirmation type: `confirmtype'"
        di as text "  Threshold rule: " cond("`threetier'" != "", "three-tier", "two-tier")
        di as text "  Re-baseline after relapse: " cond("`rebaselinerelapse'" != "", "Yes", "No")
        di as text _n "Results:"
        di as text "  Total CDP events: `n_cdp'"
        di as text "  PIRA events: `n_pira'"
        di as text "  RAW events: `n_raw'"
        if "`exit'" != "" {
            di as text "  Events censored after study exit: `n_censored_exit'"
        }
        di as text _n "  Variables created: `generate', `rawgenerate'"
        if "`eventvar'" != "" {
            di as text "  Event indicator: `eventvar'"
        }
        if `pira_converged' == 0 {
            di as text "  Note: confirmation did not converge (results may be approximate)"
        }
    }

    // Return values
    return scalar N_cdp = `n_cdp'
    return scalar N_pira = `n_pira'
    return scalar N_raw = `n_raw'
    return scalar windowbefore = `windowbefore'
    return scalar windowafter = `windowafter'
    return scalar confirmdays = `confirmdays'
    return scalar baselinewindow = `baselinewindow'
    return scalar converged = `pira_converged'
    return local pira_varname "`generate'"
    return local raw_varname "`rawgenerate'"
    return local confirmtype "`confirmtype'"
    return local threetier = cond("`threetier'" != "", "yes", "no")
    return local rebaselinerelapse = cond("`rebaselinerelapse'" != "", "yes", "no")
    if "`eventvar'" != "" {
        return local eventvar "`eventvar'"
    }
    if "`exit'" != "" {
        return local exit "`exit'"
        return scalar N_censored_exit = `n_censored_exit'
    }

    }
    local _rc = _rc
    capture drop `_pira_sortorder'
    set varabbrev `_varabbrev'
    if `_rc' exit `_rc'
end
