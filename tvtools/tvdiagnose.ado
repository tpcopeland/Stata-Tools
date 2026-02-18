*! tvdiagnose Version 1.0.0  2025/12/26
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
    set varabbrev off

    syntax , ID(varname) START(varname) STOP(varname) ///
        [EXPosure(varname) ENTRY(varname) EXIT(varname) ///
         COVerage GAPS OVERlaps SUMmarize ALL ///
         THReshold(integer 30)]

    * Load helper library
    findfile _tvexpose_diagnose.ado
    quietly run "`r(fn)'"

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
    quietly levelsof `id'
    local n_persons = r(numlevels)

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

        * Temporarily rename variables for helper program
        tempfile _original
        quietly save `_original'

        * Standardize variable names
        if "`id'" != "id" {
            quietly rename `id' id
        }
        if "`start'" != "start" {
            quietly rename `start' start
        }
        if "`stop'" != "stop" {
            quietly rename `stop' stop
        }
        if "`entry'" != "study_entry" {
            quietly rename `entry' study_entry
        }
        if "`exit'" != "study_exit" {
            quietly rename `exit' study_exit
        }

        * Calculate coverage metrics per person
        quietly generate double __period_days = stop - start + 1
        quietly by id: egen double __total_covered = total(__period_days)
        quietly by id: generate double __expected_days = study_exit[1] - study_entry[1] + 1
        quietly generate double __pct_covered = 100 * __total_covered / __expected_days

        quietly by id: egen double __n_periods = count(id)

        * Calculate number of gaps
        quietly by id (start): gen double __gap_ind = (start > stop[_n-1] + 1) if _n > 1 & id == id[_n-1]
        quietly by id: egen double __n_gaps = total(__gap_ind)

        * Keep one row per person for display
        quietly by id: keep if _n == 1

        * Display sample of results
        display as text "Showing first " min(_N, 20) " persons:"
        rename __pct_covered pct_covered
        rename __n_periods n_periods
        rename __n_gaps n_gaps
        list id pct_covered n_periods n_gaps in 1/`=min(_N,20)', clean noobs

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
        quietly use `_original', clear
    }

    **************************************************************************
    * GAP ANALYSIS
    **************************************************************************
    if "`gaps'" != "" {
        display as text ""
        display as text "{hline 70}"
        display as text "{bf:Gap Analysis}"
        display as text "{hline 70}"

        tempfile _gaps_temp
        quietly save `_gaps_temp'
        sort `id' `start'

        * Identify gaps between consecutive periods
        quietly by `id' (`start'): gen double __gap_ind = (`start' > `stop'[_n-1] + 1) if _n > 1 & `id' == `id'[_n-1]
        quietly by `id': gen __gap_start = `stop'[_n-1] + 1 if __gap_ind == 1 & `id' == `id'[_n-1]
        quietly by `id': gen __gap_end = `start' - 1 if __gap_ind == 1
        quietly gen __gap_days = __gap_end - __gap_start + 1 if !missing(__gap_start)

        drop __gap_ind
        capture quietly drop if __gap_days <= 0
        quietly keep if !missing(__gap_start)

        local n_gaps = _N

        if `n_gaps' > 0 {
            format __gap_start __gap_end %tdCCYY/NN/DD
            rename __gap_start gap_start
            rename __gap_end gap_end
            rename __gap_days gap_days
            display as text "Showing first 20 gaps:"
            list `id' gap_start gap_end gap_days in 1/`=min(_N,20)', noobs sepby(`id')

            * Gap statistics
            quietly sum gap_days, detail
            display as text ""
            display as text "Gap Statistics:"
            display as text "  Total gaps: " as result `n_gaps'
            display as text "  Mean gap: " as result %5.1f r(mean) " days"
            display as text "  Median gap: " as result %5.0f r(p50) " days"
            display as text "  Max gap: " as result %5.0f r(max) " days"

            * Flag large gaps
            quietly count if gap_days > `threshold'
            local n_large_gaps = r(N)
            if `n_large_gaps' > 0 {
                display as text ""
                display as result "  Warning: " `n_large_gaps' " gaps exceed threshold of `threshold' days"
            }

            return scalar n_gaps = `n_gaps'
            return scalar mean_gap = r(mean)
            return scalar max_gap = r(max)
            return scalar n_large_gaps = `n_large_gaps'
        }
        else {
            display as text "No gaps found in coverage"
            return scalar n_gaps = 0
        }

        quietly use `_gaps_temp', clear
    }

    **************************************************************************
    * OVERLAP ANALYSIS
    **************************************************************************
    if "`overlaps'" != "" {
        display as text ""
        display as text "{hline 70}"
        display as text "{bf:Overlap Analysis}"
        display as text "{hline 70}"

        tempfile _overlaps_temp
        quietly save `_overlaps_temp'
        sort `id' `start' `stop'

        * Identify overlapping periods (start before previous period ends)
        quietly by `id' (`start'): gen double __overlap = (`start' <= `stop'[_n-1]) if _n > 1 & `id' == `id'[_n-1]

        quietly keep if __overlap == 1

        if _N > 0 {
            local n_overlaps = _N

            * Count unique IDs with overlaps
            quietly by `id': gen double __first_overlap = (_n == 1)
            quietly count if __first_overlap == 1
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

        quietly use `_overlaps_temp', clear
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
        tempfile _summarize_temp
        quietly save `_summarize_temp'

        quietly gen double __period_length = `stop' - `start' + 1
        quietly gen double __total_time = sum(__period_length)
        local total_time = __total_time[_N]

        quietly collapse (sum) person_days = __period_length (count) n_periods = __period_length, ///
            by(`exposure')
        quietly gen pct = 100 * person_days / `total_time'

        display as text ""
        display as text "Person-time by exposure:"
        rename pct percent
        list `exposure' person_days percent, noobs separator(0)

        display as text ""
        display as text "Total person-time: " as result %12.0fc `total_time' " days"

        return scalar total_person_time = `total_time'

        quietly use `_summarize_temp', clear
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

end
