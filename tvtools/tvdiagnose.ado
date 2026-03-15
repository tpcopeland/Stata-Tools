*! tvdiagnose Version 1.0.1  2026/02/23
*! Diagnostic tools for time-varying exposure datasets
*! Author: Tim Copeland
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tvdiagnose , id(varname) start(varname) stop(varname) [options]

Required options:
  id(varname)     - Person identifier
  start(varname)  - Period start date
  stop(varname)   - Period end date

Report options (choose one or more):
  coverage        - Coverage diagnostics (percent of follow-up covered)
  gaps            - Gap analysis (unexposed intervals)
  overlaps        - Overlap detection (overlapping periods)
  summarize       - Exposure distribution summary (requires exposure option)
  all             - Run all diagnostic reports

Additional options:
  exposure(varname)     - Exposure variable (required for summarize)
  entry(varname)        - Study entry date (required for coverage)
  exit(varname)         - Study exit date (required for coverage)
  threshold(#)          - Flag gaps > # days (default: 30)

Examples:
  * Basic coverage check
  tvdiagnose, id(id) start(start) stop(stop) entry(study_entry) exit(study_exit) coverage

  * All diagnostics
  tvdiagnose, id(id) start(start) stop(stop) exposure(tv_exposure) ///
      entry(study_entry) exit(study_exit) all

See help tvdiagnose for complete documentation
*/

program define tvdiagnose, rclass
    version 16.0
    local orig_varabbrev = c(varabbrev)
    local orig_more = c(more)
    set varabbrev off
    set more off

    capture noisily {

    syntax , ID(varname) START(varname) STOP(varname) ///
        [EXPosure(varname) ENTRY(varname) EXIT(varname) ///
         COVerage GAPS OVERlaps SUMmarize ALL ///
         THReshold(integer 30)]

    * If 'all' is specified, run all diagnostics
    if "`all'" != "" {
        local coverage "coverage"
        local gaps "gaps"
        local overlaps "overlaps"
        if "`exposure'" != "" {
            local summarize "summarize"
        }
    }

    * Validate options
    if "`coverage'" == "" & "`gaps'" == "" & "`overlaps'" == "" & "`summarize'" == "" {
        display as error "At least one report option required: coverage, gaps, overlaps, summarize, or all"
        exit 198
    }

    if "`coverage'" != "" {
        if "`entry'" == "" | "`exit'" == "" {
            display as error "coverage requires entry() and exit() options"
            exit 198
        }
    }

    if "`summarize'" != "" & "`exposure'" == "" {
        display as error "summarize requires exposure() option"
        exit 198
    }

    * Ensure data is sorted
    sort `id' `start' `stop'

    * Initialize return values
    local n_persons = 0
    local n_gaps = 0
    local n_overlaps = 0

    display as text "{hline 70}"
    display as text "{bf:Time-Varying Data Diagnostics}"
    display as text "{hline 70}"

    * Basic data summary
    quietly count
    local n_obs = r(N)
    tempvar _id_tag
    quietly egen byte `_id_tag' = tag(`id')
    quietly count if `_id_tag'
    local n_persons = r(N)

    display as text "Dataset summary:"
    display as text "  Observations: " as result %12.0fc `n_obs'
    display as text "  Persons: " as result %12.0fc `n_persons'
    display as text "  Periods/person: " as result %8.1f `n_obs'/`n_persons'

    **************************************************************************
    * COVERAGE DIAGNOSTICS
    **************************************************************************
    if "`coverage'" != "" {
        display as text ""
        display as text "{hline 70}"
        display as text "{bf:Coverage Diagnostics}"
        display as text "{hline 70}"

        * Work on a copy to avoid modifying original data
        preserve

        * Calculate coverage metrics per person using user's variable names
        tempvar _prd _tcov _expd _pctcov _nper _gind _ngap
        quietly generate double `_prd' = `stop' - `start' + 1
        quietly by `id': egen double `_tcov' = total(`_prd')
        quietly by `id': generate double `_expd' = `exit'[1] - `entry'[1] + 1
        quietly generate double `_pctcov' = 100 * `_tcov' / `_expd'

        quietly by `id': egen double `_nper' = count(`id')

        * Calculate number of gaps
        quietly by `id' (`start'): gen double `_gind' = (`start' > `stop'[_n-1] + 1) if _n > 1 & `id' == `id'[_n-1]
        quietly by `id': egen double `_ngap' = total(`_gind')

        * Keep one row per person for display
        quietly by `id': keep if _n == 1

        * Rename tempvars for display
        rename `_pctcov' pct_covered
        rename `_nper' n_periods
        rename `_ngap' n_gaps

        * Display sample of results
        display as text "Showing first " min(_N, 20) " persons:"
        list `id' pct_covered n_periods n_gaps in 1/`=min(_N,20)', clean noobs

        * Display summary statistics
        quietly sum pct_covered
        local mean_coverage = r(mean)
        local min_coverage = r(min)
        local max_coverage = r(max)

        display as text "{hline 70}"
        display as text "Coverage Summary:"
        display as text "  Mean coverage: " as result %5.1f `mean_coverage' "%"
        display as text "  Min coverage:  " as result %5.1f `min_coverage' "%"
        display as text "  Max coverage:  " as result %5.1f `max_coverage' "%"

        quietly count if pct_covered < 100
        local n_with_gaps = r(N)
        display as text "  Persons with gaps: " as result `n_with_gaps' " (" %4.1f 100*`n_with_gaps'/_N "%)"
        display as text "{hline 70}"

        * Store return values
        return scalar mean_coverage = `mean_coverage'
        return scalar n_with_gaps = `n_with_gaps'

        * Restore original data
        restore
    }

    **************************************************************************
    * GAP ANALYSIS
    **************************************************************************
    if "`gaps'" != "" {
        display as text ""
        display as text "{hline 70}"
        display as text "{bf:Gap Analysis}"
        display as text "{hline 70}"

        preserve
        sort `id' `start'

        * Identify gaps between consecutive periods
        tempvar _gi _gs _ge _gd
        quietly by `id' (`start'): gen double `_gi' = (`start' > `stop'[_n-1] + 1) if _n > 1 & `id' == `id'[_n-1]
        quietly by `id': gen double `_gs' = `stop'[_n-1] + 1 if `_gi' == 1 & `id' == `id'[_n-1]
        quietly by `id': gen double `_ge' = `start' - 1 if `_gi' == 1
        quietly gen double `_gd' = `_ge' - `_gs' + 1 if !missing(`_gs')

        capture quietly drop if `_gd' <= 0
        quietly keep if !missing(`_gs')

        local n_gaps = _N

        if `n_gaps' > 0 {
            format `_gs' `_ge' %tdCCYY/NN/DD
            rename `_gs' gap_start
            rename `_ge' gap_end
            rename `_gd' gap_days
            display as text "Showing first 20 gaps:"
            list `id' gap_start gap_end gap_days in 1/`=min(_N,20)', noobs sepby(`id')

            * Gap statistics - save to locals immediately (count overwrites r())
            quietly sum gap_days, detail
            local mean_gap = r(mean)
            local median_gap = r(p50)
            local max_gap = r(max)

            display as text ""
            display as text "Gap Statistics:"
            display as text "  Total gaps: " as result `n_gaps'
            display as text "  Mean gap: " as result %5.1f `mean_gap' " days"
            display as text "  Median gap: " as result %5.0f `median_gap' " days"
            display as text "  Max gap: " as result %5.0f `max_gap' " days"

            * Flag large gaps
            quietly count if gap_days > `threshold'
            local n_large_gaps = r(N)
            if `n_large_gaps' > 0 {
                display as text ""
                display as result "  Warning: " `n_large_gaps' " gaps exceed threshold of `threshold' days"
            }

            return scalar n_gaps = `n_gaps'
            return scalar mean_gap = `mean_gap'
            return scalar max_gap = `max_gap'
            return scalar n_large_gaps = `n_large_gaps'
        }
        else {
            display as text "No gaps found in coverage"
            return scalar n_gaps = 0
        }

        restore
    }

    **************************************************************************
    * OVERLAP ANALYSIS
    **************************************************************************
    if "`overlaps'" != "" {
        display as text ""
        display as text "{hline 70}"
        display as text "{bf:Overlap Analysis}"
        display as text "{hline 70}"

        preserve
        sort `id' `start' `stop'

        * Identify overlapping periods (start before previous period ends)
        tempvar _ovl
        quietly by `id' (`start'): gen double `_ovl' = (`start' <= `stop'[_n-1]) if _n > 1 & `id' == `id'[_n-1]

        quietly keep if `_ovl' == 1

        if _N > 0 {
            local n_overlaps = _N

            * Count unique IDs with overlaps
            tempvar _fov
            quietly by `id': gen double `_fov' = (_n == 1)
            quietly count if `_fov' == 1
            local n_ids_affected = r(N)

            display as text "Total overlapping periods: " as result `n_overlaps'
            display as text "Number of IDs affected: " as result `n_ids_affected'
            display as text ""
            display as text "Showing first 50 overlapping periods:"

            list `id' `start' `stop' in 1/`=min(_N,50)', noobs sepby(`id')

            return scalar n_overlaps = `n_overlaps'
            return scalar n_ids_affected = `n_ids_affected'
        }
        else {
            display as text "No overlapping periods found"
            return scalar n_overlaps = 0
            return scalar n_ids_affected = 0
        }

        restore
    }

    **************************************************************************
    * EXPOSURE SUMMARY
    **************************************************************************
    if "`summarize'" != "" {
        display as text ""
        display as text "{hline 70}"
        display as text "{bf:Exposure Distribution}"
        display as text "{hline 70}"

        * Check variable type
        capture confirm numeric variable `exposure'
        if _rc != 0 {
            display as error "Exposure variable must be numeric"
            exit 109
        }

        * Display frequency table
        tab `exposure', missing

        * Calculate person-time by exposure
        preserve

        tempvar _plen _ttime
        quietly gen double `_plen' = `stop' - `start' + 1
        quietly gen double `_ttime' = sum(`_plen')
        local total_time = `_ttime'[_N]

        quietly collapse (sum) person_days = `_plen' (count) n_periods = `_plen', ///
            by(`exposure')
        quietly gen double percent = 100 * person_days / `total_time'

        display as text ""
        display as text "Person-time by exposure:"
        list `exposure' person_days percent, noobs separator(0)

        display as text ""
        display as text "Total person-time: " as result %12.0fc `total_time' " days"

        return scalar total_person_time = `total_time'

        restore
    }

    **************************************************************************
    * FINAL SUMMARY
    **************************************************************************
    display as text ""
    display as text "{hline 70}"
    display as text "{bf:Diagnostic Complete}"
    display as text "{hline 70}"

    * Return general results
    return scalar n_persons = `n_persons'
    return scalar n_observations = `n_obs'
    return local id "`id'"
    return local start "`start'"
    return local stop "`stop'"

    } // end capture noisily
    local rc = _rc

    set varabbrev `orig_varabbrev'
    set more `orig_more'

    if `rc' {
        exit `rc'
    }
end
