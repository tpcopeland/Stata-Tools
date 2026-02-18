*! tvcalendar Version 1.1.0  2026/02/18
*! Merge calendar-time external factors into time-varying data
*! Author: Tim Copeland
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tvcalendar using external.dta, datevar(varname) [merge(varlist)]

Required:
  using           - Dataset with calendar-time factors
  datevar(varname) - Date variable in master data

Optional:
  merge(varlist)  - Variables to merge from external dataset
  start(varname)  - Period start in external data
  stop(varname)   - Period stop in external data

Description:
  Merges calendar-time external factors (policy periods, seasonal
  indicators, environmental exposures) into person-time data.

See help tvcalendar for complete documentation
*/

program define tvcalendar, rclass
    version 16.0
    set varabbrev off

    syntax using/, DATEvar(varname) [MERGE(string) STARTvar(name) STOPvar(name)]

    * =========================================================================
    * VALIDATE INPUT
    * =========================================================================

    capture confirm variable `datevar'
    if _rc != 0 {
        display as error "date variable `datevar' not found"
        exit 111
    }

    * Check using file exists
    capture confirm file `"`using'"'
    if _rc != 0 {
        display as error "using file not found: `using'"
        exit 601
    }

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as text "{bf:TVCALENDAR: Merge Calendar-Time Factors}"
    display as text "{hline 70}"
    display as text ""

    * Store master info
    quietly count
    local n_master = r(N)

    * =========================================================================
    * LOAD AND VALIDATE EXTERNAL DATA
    * =========================================================================

    display as text "Loading external data..."

    preserve

    * Load external data to check structure
    use `"`using'"', clear
    quietly count
    local n_ext = r(N)

    display as text "  External observations: " as result `n_ext'

    * Determine merge variables
    if "`merge'" == "" {
        * Use all numeric variables except date vars
        ds, has(type numeric)
        local merge "`r(varlist)'"
    }

    display as text "  Variables to merge: " as result "`merge'"

    restore

    * =========================================================================
    * PERFORM MERGE
    * =========================================================================

    display as text ""
    display as text "Merging calendar factors..."

    * For date-based merge, use joinby or range merge
    * Simplified approach: merge on date

    if "`startvar'" == "" & "`stopvar'" == "" {
        * Point-in-time merge
        quietly merge m:1 `datevar' using `"`using'"', keep(master match) nogenerate
    }
    else {
        * Range-based merge: match master dates to external periods
        * Each master observation is matched to the external period containing its date

        if "`startvar'" == "" | "`stopvar'" == "" {
            display as error "both startvar() and stopvar() are required for range-based merge"
            exit 198
        }

        * Validate startvar/stopvar exist in external data
        preserve
        use `"`using'"', clear

        capture confirm variable `startvar'
        if _rc != 0 {
            restore
            display as error "start variable `startvar' not found in external data"
            exit 111
        }
        capture confirm variable `stopvar'
        if _rc != 0 {
            restore
            display as error "stop variable `stopvar' not found in external data"
            exit 111
        }

        * Exclude period boundary vars from merge variable list
        local range_merge ""
        foreach v of local merge {
            if "`v'" != "`startvar'" & "`v'" != "`stopvar'" {
                local range_merge "`range_merge' `v'"
            }
        }
        local merge "`range_merge'"

        keep `startvar' `stopvar' `merge'
        local n_periods = _N
        tempfile ext_periods
        quietly save `ext_periods', replace
        restore

        display as text "  Range merge: `n_periods' external period(s)"

        * Add observation ID for tracking matches
        tempvar _obs_id
        quietly gen double `_obs_id' = _n

        * Cross join master with all external periods, then filter
        preserve

        quietly cross using `ext_periods'

        * Keep only where datevar falls within [startvar, stopvar]
        quietly keep if `datevar' >= `startvar' & `datevar' <= `stopvar'

        * Handle multiple period matches per observation: keep earliest
        quietly bysort `_obs_id' (`startvar'): gen double __match_seq = _n
        quietly count if __match_seq > 1
        local n_multi = r(N)
        if `n_multi' > 0 {
            display as text "  Note: `n_multi' obs matched multiple periods; keeping earliest"
            quietly keep if __match_seq == 1
        }
        quietly drop __match_seq

        * Keep only observation ID and merge variables
        keep `_obs_id' `merge'
        local n_matched = _N

        tempfile matched_data
        quietly save `matched_data', replace

        restore

        * Merge matched results back to master
        quietly merge 1:1 `_obs_id' using `matched_data', nogenerate
        sort `_obs_id'
        quietly drop `_obs_id'

        local n_unmatched = `n_master' - `n_matched'
        if `n_unmatched' > 0 {
            display as text "  Matched: `n_matched' of `n_master' obs"
            display as text "  Unmatched: `n_unmatched' (kept with missing values)"
        }
        else {
            display as text "  All `n_master' observations matched"
        }
    }

    quietly count
    local n_after = r(N)

    * =========================================================================
    * SUMMARY
    * =========================================================================

    display as text ""
    display as text "{bf:Merge Summary}"
    display as text "{hline 40}"
    display as text "Master observations:  " as result `n_master'
    display as text "After merge:          " as result `n_after'
    display as text ""
    display as text "{hline 70}"

    * =========================================================================
    * RETURN VALUES
    * =========================================================================

    return scalar n_master = `n_master'
    return scalar n_merged = `n_after'
    return local datevar "`datevar'"
    return local merge "`merge'"

end
