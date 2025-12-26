*! _tvexpose_diagnose Version 1.0.0  2025/12/26
*! Diagnostic functions for tvexpose
*! Author: Tim Copeland
*! Program class: utility (called internally by tvexpose)

/*
This file contains diagnostic programs for tvexpose:
  - _tvexpose_check: Coverage diagnostics per person
  - _tvexpose_gaps: Gap analysis between periods
  - _tvexpose_overlaps: Overlap detection
  - _tvexpose_summarize: Exposure distribution summary
  - _tvexpose_validate: Create validation dataset with metrics

These programs are called internally by tvexpose and should not be called directly.
Each program expects the time-varying dataset to be in memory with standard variables:
  - id: Person identifier
  - start: Period start date
  - stop: Period end date
  - study_entry: Study entry date
  - study_exit: Study exit date
  - [exposure_var]: Exposure variable (name passed as argument)
*/

version 16.0

********************************************************************************
* COVERAGE DIAGNOSTICS (check option)
********************************************************************************

capture program drop _tvexpose_check
program define _tvexpose_check, rclass
    version 16.0
    syntax , [id(name) start(name) stop(name)]

    * Set defaults
    if "`id'" == "" local id "id"
    if "`start'" == "" local start "start"
    if "`stop'" == "" local stop "stop"

    display as text "{hline 70}"
    display as text "Coverage Diagnostics"
    display as text "{hline 70}"

    tempfile _check_temp
    quietly save `_check_temp'

    * Calculate coverage metrics per person
    quietly generate double __period_days = `stop' - `start' + 1
    quietly by `id': egen double __total_covered = total(__period_days)
    quietly by `id': generate double __expected_days = study_exit[1] - study_entry[1] + 1
    quietly generate double __pct_covered = 100 * __total_covered / __expected_days

    quietly by `id': egen double __n_periods = count(`id')

    * Calculate number of gaps
    quietly by `id' (`start'): gen double __gap_ind = (`start' > `stop'[_n-1] + 1) if _n > 1 & `id' == `id'[_n-1]
    quietly by `id': egen double __n_gaps = total(__gap_ind)

    * Keep one row per person for display
    quietly by `id': keep if _n == 1

    * Rename for display
    rename __pct_covered pct_covered
    rename __n_periods n_periods
    rename __n_gaps n_gaps

    * Display sample of results
    display as text "Showing first " min(_N, 20) " persons:"
    list `id' pct_covered n_periods n_gaps in 1/`=min(_N,20)', clean noobs

    * Display summary statistics
    quietly sum pct_covered
    display as text "{hline 70}"
    display as text "Coverage Summary:"
    display as text "  Mean coverage: " as result %5.1f r(mean) "%"
    display as text "  Min coverage:  " as result %5.1f r(min) "%"
    display as text "  Max coverage:  " as result %5.1f r(max) "%"

    quietly count if pct_covered < 100
    display as text "  Persons with gaps: " as result r(N) " (" %4.1f 100*r(N)/_N "%)"
    display as text "{hline 70}"

    * Return results
    return scalar mean_coverage = r(mean)
    return scalar n_with_gaps = r(N)

    quietly use `_check_temp', clear
end


********************************************************************************
* GAP ANALYSIS (gaps option)
********************************************************************************

capture program drop _tvexpose_gaps
program define _tvexpose_gaps, rclass
    version 16.0
    syntax , [id(name) start(name) stop(name)]

    * Set defaults
    if "`id'" == "" local id "id"
    if "`start'" == "" local start "start"
    if "`stop'" == "" local stop "stop"

    display as text ""
    display as text "Gaps in Coverage"
    display as text "{hline 60}"

    tempfile _gaps_temp
    quietly save `_gaps_temp'
    sort `id' `start'

    * Identify gaps between consecutive periods
    quietly by `id' (`start'): gen double __gap_ind = (`start' > `stop'[_n-1] + 1) if _n > 1 & `id' == `id'[_n-1]
    quietly by `id': gen gap_start = `stop'[_n-1] + 1 if __gap_ind == 1 & `id' == `id'[_n-1]
    quietly by `id': gen gap_end = `start' - 1 if __gap_ind == 1
    quietly gen gap_days = gap_end - gap_start + 1 if !missing(gap_start)

    drop __gap_ind
    capture quietly drop if gap_days <= 0
    quietly keep if !missing(gap_start)

    local n_gaps = _N

    if `n_gaps' > 0 {
        format gap_start gap_end %tdCCYY/NN/DD
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

        return scalar n_gaps = `n_gaps'
        return scalar mean_gap = r(mean)
        return scalar max_gap = r(max)
    }
    else {
        display as text "No gaps found in coverage"
        return scalar n_gaps = 0
    }

    quietly use `_gaps_temp', clear
end


********************************************************************************
* OVERLAP ANALYSIS (overlaps option)
********************************************************************************

capture program drop _tvexpose_overlaps
program define _tvexpose_overlaps, rclass
    version 16.0
    syntax , exposure(name) [id(name) start(name) stop(name) skip_main_var(integer 0)]

    * Set defaults
    if "`id'" == "" local id "id"
    if "`start'" == "" local start "start"
    if "`stop'" == "" local stop "stop"

    display as text ""
    display as text "Overlapping Periods"
    display as text "{hline 60}"

    tempfile _overlaps_temp
    quietly save `_overlaps_temp'
    sort `id' `start' `stop'

    * Identify overlapping periods (start before previous period ends)
    quietly by `id' (`start'): gen double __overlap = (`start' <= `stop'[_n-1]) if _n > 1 & `id' == `id'[_n-1]

    quietly keep if __overlap == 1

    if _N > 0 {
        * Count total overlaps
        local total_overlaps = _N

        * Count unique IDs with overlaps
        quietly by `id': gen double __first_overlap = (_n == 1)
        quietly count if __first_overlap == 1
        local n_ids = r(N)

        display as text "Total overlapping periods: " as result `total_overlaps'
        display as text "Number of IDs affected: " as result `n_ids'
        display as text ""
        display as text "Showing first 100 overlapping periods:"
        display as text ""

        * Show first 100 overlaps with better formatting
        local show_n = min(`total_overlaps', 100)
        forvalues i = 1/`show_n' {
            local show_id = `id'[`i']
            local show_start = `start'[`i']
            local show_stop = `stop'[`i']

            * Get exposure value
            if `skip_main_var' == 0 {
                local show_exp = `exposure'[`i']
            }
            else {
                capture local show_exp = exp_value[`i']
                if _rc != 0 local show_exp = "N/A"
            }
            local prev_stop = `stop'[`i'-1]

            * Only show if this is an overlap
            if `i' > 1 & `show_id' == `id'[`i'-1] {
                display as text "  ID " as result %6.0f `show_id' as text ///
                    ": " as result %td `show_start' as text " to " as result %td `show_stop' ///
                    as text " (exp=" as result "`show_exp'" as text ///
                    ", prev_stop=" as result %td `prev_stop' as text ")"
            }
        }

        if `total_overlaps' > 100 {
            local more = `total_overlaps' - 100
            display as text ""
            display as text "... and `more' more overlapping periods"
        }

        return scalar n_overlaps = `total_overlaps'
        return scalar n_ids_affected = `n_ids'
    }
    else {
        display as text "No overlapping periods found"
        return scalar n_overlaps = 0
        return scalar n_ids_affected = 0
    }

    quietly use `_overlaps_temp', clear
end


********************************************************************************
* EXPOSURE DISTRIBUTION SUMMARY (summarize option)
********************************************************************************

capture program drop _tvexpose_summarize
program define _tvexpose_summarize
    version 16.0
    syntax , exposure(name) total_time(real) [exp_type(string) bytype stub_name(name) start(name) stop(name)]

    * Set defaults
    if "`start'" == "" local start "start"
    if "`stop'" == "" local stop "stop"
    if "`exp_type'" == "" local exp_type "categorical"

    display as text ""
    display as text "Exposure Distribution"
    display as text "{hline 60}"

    * For categorical exposures, show distribution table
    if "`exp_type'" != "continuous" {
        tab1 `exposure'*, missing
    }
    else {
        * For continuous exposure, show descriptive statistics
        if "`bytype'" != "" {
            * When bytype is used with continuous, get list of bytype variables
            quietly ds `stub_name'*
            local bytype_varlist "`r(varlist)'"
            display as text "Continuous exposure (person-years) by type:"
            foreach bytype_var of local bytype_varlist {
                quietly sum `bytype_var', detail
                display as text ""
                display as text "`bytype_var':"
                display as text "  Min:    " as result %8.3f r(min)
                display as text "  Mean:   " as result %8.3f r(mean)
                display as text "  Median: " as result %8.3f r(p50)
                display as text "  Max:    " as result %8.3f r(max)
            }
        }
        else {
            * Without bytype, show stats for single variable
            quietly sum `exposure', detail
            display as text "Continuous exposure (person-years):"
            display as text "  Min:    " as result %8.3f r(min)
            display as text "  Mean:   " as result %8.3f r(mean)
            display as text "  Median: " as result %8.3f r(p50)
            display as text "  Max:    " as result %8.3f r(max)
        }
    }

    * Calculate person-time by exposure category (only for categorical)
    tempfile _summarize_temp
    quietly save `_summarize_temp'
    quietly gen __period_length = `stop' - `start' + 1

    if "`exp_type'" != "continuous" {
        * Get collapse by variables
        if "`bytype'" != "" {
            quietly ds `stub_name'*
            local collapse_by_vars "`r(varlist)'"
        }
        else {
            local collapse_by_vars "`exposure'"
        }

        quietly collapse (sum) cat_time = __period_length (count) n_periods = __period_length, ///
            by(`collapse_by_vars')
        quietly gen cat_pct = 100 * cat_time / `total_time'
        list `collapse_by_vars' cat_time cat_pct, noobs separator(0)

        quietly use `_summarize_temp', clear
    }
end


********************************************************************************
* VALIDATION DATASET CREATION (validate option)
********************************************************************************

capture program drop _tvexpose_validate
program define _tvexpose_validate, rclass
    version 16.0
    syntax , exposure(name) reference(numlist) [id(name) start(name) stop(name) saveas(string) replace]

    * Set defaults
    if "`id'" == "" local id "id"
    if "`start'" == "" local start "start"
    if "`stop'" == "" local stop "stop"

    * Create comprehensive validation dataset with per-person metrics
    tempfile _validate_temp
    quietly save `_validate_temp'

    quietly generate double __period_days = `stop' - `start' + 1
    quietly by `id': egen double total_covered = total(__period_days)
    quietly by `id': generate double expected_days = study_exit[1] - study_entry[1] + 1
    quietly generate double pct_covered = 100 * total_covered / expected_days

    * Calculate exposed time
    quietly gen double __exposed_val = (`exposure' != `reference')
    quietly generate double exp_days = __period_days * __exposed_val
    quietly by `id': egen double total_exposed_days = total(exp_days)
    quietly by `id': egen double n_periods = count(`id')

    * Calculate number of transitions
    quietly by `id' (`start'): gen double __trans_ind = (`exposure' != `exposure'[_n-1]) if _n > 1 & `id' == `id'[_n-1]
    quietly by `id': egen double n_transitions = total(__trans_ind)

    * Calculate gaps
    quietly by `id': gen double __gap_val = (`start' > `stop'[_n-1] + 1) if _n > 1 & `id' == `id'[_n-1]
    quietly by `id': egen double any_gaps = max(__gap_val)
    quietly by `id': egen double n_gaps = total(__gap_val)

    * First and last exposure dates
    quietly by `id': egen double __first_exp_val = min(`start') if __exposed_val
    quietly by `id': egen double __last_exp_val = max(`stop') if __exposed_val
    quietly by `id': egen double first_exposure = min(__first_exp_val)
    quietly by `id': egen double last_exposure = max(__last_exp_val)

    * Keep one row per person
    quietly by `id': keep if _n == 1
    keep `id' total_covered expected_days pct_covered total_exposed_days ///
        n_periods n_transitions any_gaps n_gaps first_exposure last_exposure

    * Add variable labels
    label var total_covered "Total days covered"
    label var expected_days "Expected days (entry to exit)"
    label var pct_covered "Percent of expected period covered"
    label var total_exposed_days "Total days exposed"
    label var n_periods "Number of periods"
    label var n_transitions "Number of transitions"
    label var any_gaps "Any gaps in coverage"
    label var n_gaps "Number of gaps"
    label var first_exposure "First exposure start date"
    label var last_exposure "Last exposure end date"

    format first_exposure last_exposure %tdCCYY/NN/DD

    * Save validation dataset
    local validation_file = "tv_validation.dta"
    if "`saveas'" != "" {
        local validation_file = subinstr("`saveas'", ".dta", "_validation.dta", .)
    }

    if "`replace'" != "" {
        quietly save "`validation_file'", replace
    }
    else {
        quietly save "`validation_file'"
    }

    display as text "Validation dataset saved as: " as result "`validation_file'"

    return local validation_file "`validation_file'"
    return scalar n_persons = _N

    quietly use `_validate_temp', clear
end
