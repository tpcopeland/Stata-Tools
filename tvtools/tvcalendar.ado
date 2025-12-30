*! tvcalendar Version 1.0.0  2025/12/29
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

    syntax using/, DATEvar(varname) [MERGE(varlist) STARTvar(name) STOPvar(name)]

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
        * Range-based merge (more complex)
        display as error "Range-based merge not yet implemented"
        display as error "Use point-in-time merge with datevar()"
        exit 198
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
