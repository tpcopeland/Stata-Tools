*! tvdiagnose Version 1.6.9  2026/07/10
*! Diagnostic tools for time-varying exposure datasets
*! Author: Timothy P Copeland, Karolinska Institutet
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
    local _preserved = 0
    set varabbrev off
    set more off

    capture noisily {

    syntax , ID(varname) START(varname) STOP(varname) ///
        [EXPosure(varname) ENTRY(varname) EXIT(varname) ///
         COVerage GAPS OVERlaps SUMmarize ALL ///
         SWIMlane MAXids(integer 50) ///
         THReshold(integer 30) VERBose]

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
    if "`coverage'" == "" & "`gaps'" == "" & "`overlaps'" == "" & ///
       "`summarize'" == "" & "`swimlane'" == "" {
        display as error "At least one report option required: coverage, gaps, overlaps, summarize, swimlane, or all"
        exit 198
    }

    if `maxids' < 1 {
        display as error "maxids() must be a positive integer"
        exit 198
    }
    if `threshold' < 0 {
        display as error "threshold() must be nonnegative"
        exit 198
    }

    foreach v in `start' `stop' {
        capture confirm numeric variable `v'
        if _rc {
            display as error "`v' must be a numeric interval variable"
            exit 109
        }
    }
    quietly count if missing(`id') | missing(`start') | missing(`stop')
    if r(N) > 0 {
        display as error "`r(N)' observation(s) have missing id/start/stop values"
        exit 416
    }
    quietly count if `stop' < `start'
    if r(N) > 0 {
        display as error "`r(N)' observation(s) have stop < start"
        exit 459
    }

    if "`coverage'" != "" {
        if "`entry'" == "" | "`exit'" == "" {
            display as error "coverage requires entry() and exit() options"
            exit 198
        }
        foreach v in `entry' `exit' {
            capture confirm numeric variable `v'
            if _rc {
                display as error "coverage requires numeric `v'() dates"
                exit 109
            }
        }
        quietly count if missing(`entry') | missing(`exit')
        if r(N) > 0 {
            display as error "`r(N)' observation(s) have missing entry/exit dates"
            exit 416
        }
        quietly count if `exit' < `entry'
        if r(N) > 0 {
            display as error "`r(N)' observation(s) have exit < entry"
            exit 459
        }
    }

    if "`summarize'" != "" & "`exposure'" == "" {
        display as error "summarize requires exposure() option"
        exit 198
    }
    if "`summarize'" != "" {
        capture confirm numeric variable `exposure'
        if _rc {
            display as error "exposure() must be numeric for summarize"
            exit 109
        }
    }

    * Stage a complete, scriptable return contract. A run flag distinguishes
    * an unrequested report from a requested report with zero findings.
    local coverage_run = 0
    local gaps_run = 0
    local overlaps_run = 0
    local summarize_run = 0
    local mean_coverage = 0
    local min_coverage = 0
    local max_coverage = 0
    local n_with_gaps = 0
    local n_incomplete_coverage = 0
    local n_coverage_gaps = 0
    local n_gaps = 0
    local n_gap_ids = 0
    local mean_gap = 0
    local median_gap = 0
    local max_gap = 0
    local n_large_gaps = 0
    local n_large_gap_ids = 0
    local n_overlaps = 0
    local n_overlap_ids = 0
    local n_ids_affected = 0
    local total_person_time = 0
    local raw_interval_person_time = 0
    local overlap_excess_person_time = 0
    local n_exposure_levels = 0
    local graph_requested = ("`swimlane'" != "")
    local graph_created = 0
    local graph_rc = 0
    local graph_ids_total = 0
    local graph_ids_plotted = 0
    local graph_truncated = 0
    local graph_name ""
    tempname exposure_summary

    display as text "{hline 70}"
    display as text "{bf:Time-Varying Data Diagnostics}"
    display as text "{hline 70}"

    * Basic data summary
    quietly count
    local n_obs = r(N)
    if `n_obs' == 0 {
        display as error "no observations in dataset"
        exit 2000
    }
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
        local coverage_run = 1
        display as text ""
        display as text "{hline 70}"
        display as text "{bf:Coverage Diagnostics}"
        display as text "{hline 70}"

        * Work on a copy to avoid modifying original data
        preserve
        local _preserved = 1
        sort `id' `start' `stop'

        * Entry/exit must be person-level constants. A changing window makes a
        * person-level coverage percentage undefined.
        tempvar _window_change
        quietly by `id': gen byte `_window_change' = ///
            (`entry' != `entry'[1] | `exit' != `exit'[1])
        quietly count if `_window_change'
        if r(N) > 0 {
            display as error "entry()/exit() must be constant within id()"
            exit 459
        }

        * Coverage is the UNION of intervals clipped to the study window. Raw
        * summation double-counts overlaps and can hide a genuine uncovered tail.
        tempvar _clip_start _clip_stop _valid _running_stop _covered _tcov ///
            _expd _pctcov _nper _component _ncomponent _minclip _maxclip _ngap
        quietly gen double `_clip_start' = max(`start', `entry')
        quietly gen double `_clip_stop' = min(`stop', `exit')
        quietly gen byte `_valid' = (`_clip_start' <= `_clip_stop')

        * Valid clipped intervals sort first. Invalid/outside rows remain so an
        * ID with no intersection is represented with zero coverage.
        quietly gsort `id' -`_valid' `_clip_start' `_clip_stop'
        quietly by `id': gen double `_running_stop' = `_clip_stop' ///
            if _n == 1 & `_valid'
        quietly by `id': replace `_running_stop' = ///
            max(`_running_stop'[_n-1], `_clip_stop') if _n > 1 & `_valid'
        quietly gen double `_covered' = 0
        quietly by `id': replace `_covered' = `_clip_stop' - `_clip_start' + 1 ///
            if _n == 1 & `_valid'
        quietly by `id': replace `_covered' = ///
            max(0, `_clip_stop' - max(`_clip_start', `_running_stop'[_n-1] + 1) + 1) ///
            if _n > 1 & `_valid'
        quietly by `id': egen double `_tcov' = total(`_covered')
        quietly by `id': gen double `_expd' = `exit'[1] - `entry'[1] + 1
        quietly gen double `_pctcov' = 100 * `_tcov' / `_expd'
        quietly by `id': egen double `_nper' = count(`id')

        * Count connected uncovered segments over the complete study window,
        * including leading/trailing gaps and a wholly uncovered window.
        quietly by `id': gen byte `_component' = `_valid' & ///
            (_n == 1 | `_clip_start' > `_running_stop'[_n-1] + 1)
        quietly by `id': egen double `_ncomponent' = total(`_component')
        quietly by `id': egen double `_minclip' = ///
            min(cond(`_valid', `_clip_start', .))
        quietly by `id': egen double `_maxclip' = ///
            max(cond(`_valid', `_clip_stop', .))
        quietly gen double `_ngap' = cond(`_ncomponent' == 0, 1, ///
            `_ncomponent' - 1 + (`_minclip' > `entry') + (`_maxclip' < `exit'))

        * Keep one row per person for display
        quietly by `id': keep if _n == 1

        * Rename tempvars for display; drop same-named user variables first
        * (this is a preserved working copy, the originals are untouched)
        foreach _v in pct_covered n_periods n_gaps {
            capture drop `_v'
        }
        rename `_pctcov' pct_covered
        rename `_nper' n_periods
        rename `_ngap' n_gaps

        * Display sample of results
        if "`verbose'" != "" {
            display as text "Showing first " min(_N, 20) " persons:"
            list `id' pct_covered n_periods n_gaps in 1/`=min(_N,20)', clean noobs
        }

        * Display summary statistics
        quietly sum pct_covered
        local mean_coverage = r(mean)
        local min_coverage = r(min)
        local max_coverage = r(max)
        quietly summarize n_gaps, meanonly
        local n_coverage_gaps = r(sum)

        display as text "{hline 70}"
        display as text "Coverage Summary:"
        display as text "  Mean coverage: " as result %5.1f `mean_coverage' "%"
        display as text "  Min coverage:  " as result %5.1f `min_coverage' "%"
        display as text "  Max coverage:  " as result %5.1f `max_coverage' "%"

        quietly count if pct_covered < 100
        local n_with_gaps = r(N)
        local n_incomplete_coverage = `n_with_gaps'
        display as text "  Persons with gaps: " as result `n_with_gaps' " (" %4.1f 100*`n_with_gaps'/_N "%)"
        if "`verbose'" == "" & `n_with_gaps' > 0 {
            display as text "  (specify verbose to list per-person details)"
        }
        display as text "{hline 70}"

        * Restore original data
        restore
        local _preserved = 0
    }

    **************************************************************************
    * GAP ANALYSIS
    **************************************************************************
    if "`gaps'" != "" {
        local gaps_run = 1
        display as text ""
        display as text "{hline 70}"
        display as text "{bf:Gap Analysis}"
        display as text "{hline 70}"

        preserve
        local _preserved = 1
        sort `id' `start'

        * Identify gaps between consecutive periods
        * Use running max of stop to handle nested intervals correctly
        tempvar _gi _gs _ge _gd _running_max_stop
        quietly by `id' (`start'): gen double `_running_max_stop' = `stop' if _n == 1
        quietly by `id' (`start'): replace `_running_max_stop' = max(`_running_max_stop'[_n-1], `stop') if _n > 1
        quietly by `id' (`start'): gen double `_gi' = (`start' > `_running_max_stop'[_n-1] + 1) if _n > 1 & `id' == `id'[_n-1]
        quietly by `id': gen double `_gs' = `_running_max_stop'[_n-1] + 1 if `_gi' == 1 & `id' == `id'[_n-1]
        quietly by `id': gen double `_ge' = `start' - 1 if `_gi' == 1
        quietly gen double `_gd' = `_ge' - `_gs' + 1 if !missing(`_gs')

        quietly drop if `_gd' <= 0
        quietly keep if !missing(`_gs')

        local n_gaps = _N

        if `n_gaps' > 0 {
            format `_gs' `_ge' %tdCCYY/NN/DD
            * Drop same-named user variables before the display renames
            * (preserved working copy, originals untouched)
            foreach _v in gap_start gap_end gap_days {
                capture drop `_v'
            }
            rename `_gs' gap_start
            rename `_ge' gap_end
            rename `_gd' gap_days
            if "`verbose'" != "" {
                display as text "Showing first 20 gaps:"
                list `id' gap_start gap_end gap_days in 1/`=min(_N,20)', noobs sepby(`id')
            }

            * Gap statistics - save to locals immediately (count overwrites r())
            quietly sum gap_days, detail
            local mean_gap = r(mean)
            local median_gap = r(p50)
            local max_gap = r(max)

            tempvar _gap_id_tag
            quietly egen byte `_gap_id_tag' = tag(`id')
            quietly count if `_gap_id_tag'
            local n_gap_ids = r(N)

            display as text ""
            display as text "Gap Statistics:"
            display as text "  Total gaps: " as result `n_gaps'
            display as text "  Mean gap: " as result %5.1f `mean_gap' " days"
            display as text "  Median gap: " as result %5.0f `median_gap' " days"
            display as text "  Max gap: " as result %5.0f `max_gap' " days"

            * Flag large gaps
            quietly count if gap_days > `threshold'
            local n_large_gaps = r(N)
            tempvar _large_gap _any_large _large_id_tag
            quietly gen byte `_large_gap' = (gap_days > `threshold')
            quietly bysort `id': egen byte `_any_large' = max(`_large_gap')
            quietly egen byte `_large_id_tag' = tag(`id')
            quietly count if `_large_id_tag' & `_any_large'
            local n_large_gap_ids = r(N)
            if `n_large_gaps' > 0 {
                display as text ""
                display as result "  Warning: " `n_large_gaps' " gaps exceed threshold of `threshold' days"
            }
            if "`verbose'" == "" {
                display as text "  (specify verbose to list affected IDs and dates)"
            }

        }
        else {
            display as text "No gaps found in coverage"
        }

        restore
        local _preserved = 0
    }

    **************************************************************************
    * OVERLAP ANALYSIS
    **************************************************************************
    if "`overlaps'" != "" {
        local overlaps_run = 1
        display as text ""
        display as text "{hline 70}"
        display as text "{bf:Overlap Analysis}"
        display as text "{hline 70}"

        preserve
        local _preserved = 1
        sort `id' `start' `stop'

        * Identify overlapping periods (start before running max of prior stops)
        * Using running max handles nested intervals that simple _n-1 comparison misses
        tempvar _ovl _running_max_stop2
        quietly by `id' (`start'): gen double `_running_max_stop2' = `stop' if _n == 1
        quietly by `id' (`start'): replace `_running_max_stop2' = max(`_running_max_stop2'[_n-1], `stop') if _n > 1
        quietly by `id' (`start'): gen double `_ovl' = (`start' <= `_running_max_stop2'[_n-1]) if _n > 1 & `id' == `id'[_n-1]

        quietly keep if `_ovl' == 1

        if _N > 0 {
            local n_overlaps = _N

            * Count unique IDs with overlaps
            tempvar _fov
            quietly by `id': gen double `_fov' = (_n == 1)
            quietly count if `_fov' == 1
            local n_ids_affected = r(N)
            local n_overlap_ids = `n_ids_affected'

            display as text "Total overlapping periods: " as result `n_overlaps'
            display as text "Number of IDs affected: " as result `n_ids_affected'

            if "`verbose'" != "" {
                display as text ""
                display as text "Showing first 50 overlapping periods:"
                list `id' `start' `stop' in 1/`=min(_N,50)', noobs sepby(`id')
            }
            else {
                display as text "  (specify verbose to list affected IDs and dates)"
            }

        }
        else {
            display as text "No overlapping periods found"
        }

        restore
        local _preserved = 0
    }

    **************************************************************************
    * EXPOSURE SUMMARY
    **************************************************************************
    if "`summarize'" != "" {
        local summarize_run = 1
        display as text ""
        display as text "{hline 70}"
        display as text "{bf:Exposure Distribution}"
        display as text "{hline 70}"

        * Display frequency table
        tab `exposure', missing

        * Calculate raw interval-days, the global interval union within ID,
        * and the interval union separately within ID x exposure.
        preserve
        local _preserved = 1

        tempvar _plen _run_all _union_all _run_exp _union_exp ///
            _exposure_group _raw_days _person_days _percent _n_periods
        quietly clonevar `_exposure_group' = `exposure'
        quietly gen double `_plen' = `stop' - `start' + 1
        quietly summarize `_plen', meanonly
        local raw_interval_person_time = r(sum)

        quietly sort `id' `start' `stop'
        quietly by `id': gen double `_run_all' = `stop' if _n == 1
        quietly by `id': replace `_run_all' = max(`_run_all'[_n-1], `stop') ///
            if _n > 1
        quietly by `id': gen double `_union_all' = `stop' - `start' + 1 ///
            if _n == 1
        quietly by `id': replace `_union_all' = ///
            max(0, `stop' - max(`start', `_run_all'[_n-1] + 1) + 1) if _n > 1
        quietly summarize `_union_all', meanonly
        local total_person_time = r(sum)
        local overlap_excess_person_time = ///
            `raw_interval_person_time' - `total_person_time'

        quietly sort `id' `_exposure_group' `start' `stop'
        quietly by `id' `_exposure_group': gen double `_run_exp' = ///
            `stop' if _n == 1
        quietly by `id' `_exposure_group': replace `_run_exp' = ///
            max(`_run_exp'[_n-1], `stop') if _n > 1
        quietly by `id' `_exposure_group': gen double `_union_exp' = ///
            `stop' - `start' + 1 if _n == 1
        quietly by `id' `_exposure_group': replace `_union_exp' = ///
            max(0, `stop' - max(`start', `_run_exp'[_n-1] + 1) + 1) if _n > 1

        quietly collapse (sum) `_raw_days' = `_plen' ///
            `_person_days' = `_union_exp' (count) `_n_periods' = `_plen', ///
            by(`_exposure_group')
        quietly gen double `_percent' = ///
            100 * `_person_days' / `total_person_time'
        rename `_exposure_group' exposure_level
        rename `_raw_days' raw_days
        rename `_person_days' person_days
        rename `_percent' percent
        rename `_n_periods' n_periods
        quietly order exposure_level raw_days person_days percent n_periods
        local n_exposure_levels = _N
        quietly mkmat exposure_level raw_days person_days percent n_periods, ///
            matrix(`exposure_summary') missing
        matrix colnames `exposure_summary' = ///
            exposure raw_days person_days percent n_periods

        display as text ""
        display as text "Person-time by exposure:"
        list exposure_level raw_days person_days percent n_periods, ///
            noobs separator(0)

        display as text ""
        display as text "Raw interval-time: " as result ///
            %12.0fc `raw_interval_person_time' " days"
        display as text "Union person-time: " as result ///
            %12.0fc `total_person_time' " days"

        restore
        local _preserved = 0
    }

    **************************************************************************
    * EXPOSURE SWIMLANE PLOT (optional)
    **************************************************************************
    * Horizontal [start, stop] interval bars per person, colored by exposure
    * level. Honors the active graph scheme. Capped at maxids() persons.
    if "`swimlane'" != "" {
        preserve
        local _preserved = 1
        tempvar _prow _graph_exposure
        tempname _swgraph
        quietly egen long `_prow' = group(`id')
        quietly summarize `_prow', meanonly
        local graph_ids_total = r(max)
        local graph_ids_plotted = min(`graph_ids_total', `maxids')
        local graph_truncated = (`graph_ids_total' > `maxids')
        if `graph_truncated' {
            quietly keep if `_prow' <= `maxids'
            display as text "Note: swimlane limited to first `maxids' of `graph_ids_total' persons (use maxids())"
        }

        local _plot ""
        local _leg ""
        local _i = 0
        if "`exposure'" != "" {
            capture confirm numeric variable `exposure'
            local _exposure_numeric = (_rc == 0)
            if `_exposure_numeric' {
                quietly clonevar `_graph_exposure' = `exposure'
            }
            else {
                quietly count if `exposure' != ""
                if r(N) == 0 {
                    quietly gen double `_graph_exposure' = .
                }
                else {
                    quietly encode `exposure', gen(`_graph_exposure')
                }
            }
            quietly levelsof `_graph_exposure', local(_elevs) missing
            foreach lv of local _elevs {
                local ++_i
                local _plot `"`_plot' (rspike `start' `stop' `_prow' if `_graph_exposure'==`lv', horizontal lwidth(medthick))"'
                if missing(`lv') {
                    local _level_label "Missing"
                }
                else {
                    local _level_label : label (`_graph_exposure') `lv'
                    if `"`_level_label'"' == "" {
                        if `_exposure_numeric' {
                            local _level_label "`exposure'=`lv'"
                        }
                        else {
                            local _level_label "Level `lv'"
                        }
                    }
                }
                local _leg `"`_leg' `_i' "`_level_label'""'
            }
            capture noisily twoway `_plot', ytitle("Person (grouped id)") ///
                xtitle("Date") title("Exposure swimlane") ///
                legend(order(`_leg')) name(`_swgraph', replace)
            local graph_rc = _rc
        }
        else {
            capture noisily twoway ///
                (rspike `start' `stop' `_prow', horizontal lwidth(medthick)), ///
                ytitle("Person (grouped id)") xtitle("Date") ///
                title("Exposure swimlane") name(`_swgraph', replace)
            local graph_rc = _rc
        }

        if `graph_rc' == 0 {
            capture graph rename `_swgraph' tvd_swimlane, replace
            local graph_rc = _rc
        }
        if `graph_rc' == 0 {
            local graph_created = 1
            local graph_name "tvd_swimlane"
        }
        else {
            capture graph drop `_swgraph'
        }
        restore
        local _preserved = 0
        if `graph_rc' {
            display as text "Note: swimlane could not be produced (rc=`graph_rc')"
        }
    }

    **************************************************************************
    * FINAL SUMMARY
    **************************************************************************
    display as text ""
    display as text "{hline 70}"
    display as text "{bf:Diagnostic Complete}"
    display as text "{hline 70}"

    * Return general results and exact report defaults.
    return scalar n_persons = `n_persons'
    return scalar n_observations = `n_obs'
    return scalar coverage_run = `coverage_run'
    return scalar gaps_run = `gaps_run'
    return scalar overlaps_run = `overlaps_run'
    return scalar summarize_run = `summarize_run'
    return scalar mean_coverage = `mean_coverage'
    return scalar min_coverage = `min_coverage'
    return scalar max_coverage = `max_coverage'
    return scalar n_with_gaps = `n_with_gaps'
    return scalar n_incomplete_coverage = `n_incomplete_coverage'
    return scalar n_coverage_gaps = `n_coverage_gaps'
    return scalar n_gaps = `n_gaps'
    return scalar n_gap_ids = `n_gap_ids'
    return scalar mean_gap = `mean_gap'
    return scalar median_gap = `median_gap'
    return scalar max_gap = `max_gap'
    return scalar n_large_gaps = `n_large_gaps'
    return scalar n_large_gap_ids = `n_large_gap_ids'
    return scalar n_overlaps = `n_overlaps'
    return scalar n_overlap_ids = `n_overlap_ids'
    return scalar n_ids_affected = `n_ids_affected'
    return scalar total_person_time = `total_person_time'
    return scalar raw_interval_person_time = `raw_interval_person_time'
    return scalar overlap_excess_person_time = `overlap_excess_person_time'
    return scalar n_exposure_levels = `n_exposure_levels'
    return scalar graph_requested = `graph_requested'
    return scalar graph_created = `graph_created'
    return scalar graph_rc = `graph_rc'
    return scalar graph_ids_total = `graph_ids_total'
    return scalar graph_ids_plotted = `graph_ids_plotted'
    return scalar graph_truncated = `graph_truncated'
    if `summarize_run' {
        return matrix exposure_summary = `exposure_summary'
    }
    return local id "`id'"
    return local start "`start'"
    return local stop "`stop'"
    return local graph_name "`graph_name'"

    } // end capture noisily
    local rc = _rc

    if `_preserved' {
        capture restore
    }

    set varabbrev `orig_varabbrev'
    set more `orig_more'

    if `rc' {
        exit `rc'
    }
end
