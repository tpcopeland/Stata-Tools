*! _tvexpose_diagnostics Version 1.12.1  2026/08/02
*! Report-only tvexpose diagnostics: check, gaps, overlaps, summarize, validate
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: none (display and optional file output only)

* Report-only diagnostic block lifted verbatim out of tvexpose.ado.
*
* Why it lives in its own file: a single Stata program may hold at most 3500
* statements. Loading one that holds more fails at `run' time with r(1000) and
* the command simply does not exist afterwards -- there is no partial load and
* no message that names the cause. At 1.9.1 tvexpose.ado sat two statements
* under that ceiling, so any change that added a brace pair to it made the
* whole command fail to load. Moving this span out bought the headroom back.
* qa/test_program_limits.do measures the remaining margin for every shipped
* program so the ceiling is hit by a failing test, not by a released package.
*
* Behaviour is unchanged: every branch runs on the finished dataset already in
* memory, prints, and restores that dataset from its own tempfile. Nothing
* here feeds the committed schema, and no local set here is read by tvexpose
* afterwards -- which is what made the span safe to move.
*
* The caller passes the option macros the span reads; it owns no parsing.

program define _tvexpose_diagnostics
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    syntax , EXPtype(string) TOTALtime(string) SKIPMainvar(integer) ///
        [CHECK GAPS OVERLAPS SUMmarize VALidate VERBose ///
         BYtype GENerate(string) STUBname(string) REFerence(string) ///
         SAVeas(string) REPlace]

    * saveas() is declared string, not `string asis', on purpose. The validate
    * branch tests "`saveas'" != "" and then subinstr()s it. Under asis the
    * option value keeps its own quotes, so an absent saveas() arrives as the
    * two-character string `""' -- nonempty, and subinstr() on it produced
    * invalid '"'_validation.dta' with r(198).

    * Re-establish the exact macro names the lifted span reads, so the body
    * below stays byte-identical to the released tvexpose text.
    local stub_name    "`stubname'"
    local exp_type     "`exptype'"
    local total_time   "`totaltime'"
    local skip_main_var = `skipmainvar'

    
    **# Coverage diagnostics (check option)
    if "`check'" != "" {
        noisily display as text "{hline 70}"
        noisily display as text "Coverage Diagnostics"
        noisily display as text "{hline 70}"
        
        tempfile _check_temp
        quietly save `_check_temp'
        * Coverage is the interval UNION clipped to the study window, never
        * the sum of row lengths. Summing rows double-counts the days that
        * split output deliberately represents more than once, which is how
        * this report came to claim 105% coverage of a window the data cover
        * exactly. Gaps come from the same engine, so the two figures can no
        * longer disagree, and nesting no longer reads as a fresh segment.
        _tvtools_interval_union, id(id) start(start) stop(stop) ///
            cliplow(study_entry) cliphigh(study_exit) ///
            uniondays(total_covered) ngaps(n_gaps)

        sort id start stop
        quietly by id: generate double expected_days = study_exit[1] - study_entry[1] + 1
        quietly generate double pct_covered = 100 * total_covered / expected_days
        quietly by id: egen double n_periods = count(id)

        * Keep one row per person for display
        quietly by id: keep if _n == 1
        
        * Display sample of results (limit to actual number of observations)
        if "`verbose'" != "" {
            noisily list id pct_covered n_periods n_gaps in 1/`=min(_N,20)', clean noobs
        }

        * Display summary statistics
        quietly sum pct_covered
        noisily display as text "{hline 70}"
        noisily display as text "Coverage Summary:"
        noisily display as text "  Mean coverage: " as result %5.1f r(mean) "%"
        noisily display as text "  Min coverage:  " as result %5.1f r(min) "%"
        noisily display as text "  Max coverage:  " as result %5.1f r(max) "%"

        quietly count if pct_covered < 100
        noisily display as text "  Persons with gaps: " as result r(N) " (" %4.1f 100*r(N)/_N "%)"
        if "`verbose'" == "" & r(N) > 0 {
            noisily display as text "  (specify verbose to list per-person details)"
        }
        noisily display as text "{hline 70}"
        
        quietly use `_check_temp', clear
    }
    
    **# Gap analysis (gaps option)
    if "`gaps'" != "" {
        noisily display as text ""
        noisily display as text "Gaps in Coverage"
        noisily display as text "{hline 60}"
        
        tempfile _gaps_temp
        quietly save `_gaps_temp'
        sort id start stop
        * A gap opens against the running maximum stop seen so far, not
        * against the immediate predecessor. With nested or split rows the
        * predecessor can end long before an earlier row does, so the old
        * rule invented gaps inside days that were in fact covered.
        quietly by id (start stop): gen double __rmax = stop if _n == 1
        quietly by id (start stop): replace __rmax = max(__rmax[_n-1], stop) if _n > 1
        quietly by id (start stop): gen double __prevmax = __rmax[_n-1] if _n > 1
        quietly gen gap_start = __prevmax + 1 if !missing(__prevmax) & start > __prevmax + 1
        quietly gen gap_end = start - 1 if !missing(gap_start)
        quietly gen gap_days = gap_end - gap_start + 1 if !missing(gap_start)

        drop __rmax __prevmax
        quietly drop if gap_days <= 0
        quietly keep if !missing(gap_start) 
        
        if _N > 0 {
            format gap_start gap_end %tdCCYY/NN/DD
            if "`verbose'" != "" {
                noisily display as text "Showing first 20 gaps:"
                noisily list id gap_start gap_end gap_days in 1/`=min(_N,20)', noobs sepby(id)
            }

            * Gap statistics
            quietly sum gap_days, detail
            noisily display as text ""
            noisily display as text "Gap Statistics:"
            noisily display as text "  Total gaps: " as result _N
            noisily display as text "  Mean gap: " as result %5.1f r(mean) " days"
            noisily display as text "  Median gap: " as result %5.0f r(p50) " days"
            noisily display as text "  Max gap: " as result %5.0f r(max) " days"
            if "`verbose'" == "" {
                noisily display as text "  (specify verbose to list affected IDs and dates)"
            }
        }
        else {
            noisily display as text "No gaps found in coverage"
        }
        quietly use `_gaps_temp', clear
    }

    **# Overlap analysis (overlaps option)
    if "`overlaps'" != "" {
        noisily display as text ""
        noisily display as text "Overlapping Periods"
        noisily display as text "{hline 60}"
        
        tempfile _overlaps_temp
        quietly save `_overlaps_temp'
        sort id start stop
        * Identify overlapping periods (start before previous period ends)
        quietly by id (start): gen double __overlap = (start <= stop[_n-1]) if _n > 1 & id == id[_n-1]
        
        quietly keep if __overlap == 1
        
        if _N > 0 {
            * Count total overlaps
            local total_overlaps = _N
            
            * Count unique IDs with overlaps
            quietly by id: gen double __first_overlap = (_n == 1)
            quietly count if __first_overlap == 1
            local n_ids = r(N)
            
            noisily display as text "Total overlapping periods: " as result `total_overlaps'
            noisily display as text "Number of IDs affected: " as result `n_ids'

            if "`verbose'" != "" {
                noisily display as text ""
                noisily display as text "Showing first 100 overlapping periods:"
                noisily display as text ""

                * Show first 100 overlaps with better formatting
                local show_n = min(`total_overlaps', 100)
                forvalues i = 1/`show_n' {
                    local show_id = id[`i']
                    local show_start = start[`i']
                    local show_stop = stop[`i']
                    * Get exposure value - use generate var if exists, else use exp_value
                    if `skip_main_var' == 0 {
                        local show_exp = `generate'[`i']
                    }
                    else {
                        capture local show_exp = exp_value[`i']
                        if _rc != 0 local show_exp = "N/A"
                    }
                    local prev_stop = stop[`i'-1]
                    * Only show if this is an overlap (defensive check)
                    if `i' > 1 & `show_id' == id[`i'-1] {
                        noisily display as text "  ID " as result %6.0f `show_id' as text ///
                            ": " as result %td `show_start' as text " to " as result %td `show_stop' ///
                            as text " (exp=" as result "`show_exp'" as text ///
                            ", prev_stop=" as result %td `prev_stop' as text ")"
                    }
                }

                if `total_overlaps' > 100 {
                    local more = `total_overlaps' - 100
                    noisily display as text ""
                    noisily display as text "... and `more' more overlapping periods"
                }
            }
            else {
                noisily display as text "  (specify verbose to list affected IDs and dates)"
            }
        }
        else {
            noisily display as text "No overlapping periods found"
        }
        quietly use `_overlaps_temp', clear
    }
    
    **# Exposure distribution summary (summarize option)
    if "`summarize'" != "" {
        noisily display as text ""
        noisily display as text "Exposure Distribution"
        noisily display as text "{hline 60}"
        
        * For categorical exposures, show distribution table
        * With bytype, tabulate the per-type variables; otherwise the single
        * output variable. (A bare `generate'* wildcard tabulated EVERY
        * variable — id, dates — when bytype left generate() empty.)
        if "`exp_type'" != "continuous" {
            if "`bytype'" != "" {
                quietly ds `stub_name'*
                if "`r(varlist)'" != "" {
                    noisily tab1 `r(varlist)', missing
                }
            }
            else {
                noisily tab1 `generate', missing
            }
        }
        else {
            * For continuous exposure, show descriptive statistics
            if "`bytype'" != "" {
                * When bytype is used with continuous, get list of bytype variables and show stats for each
                quietly ds `stub_name'*
                local bytype_varlist "`r(varlist)'"
                noisily display as text "Continuous exposure (person-years) by type:"
                foreach bytype_var of local bytype_varlist {
                    quietly sum `bytype_var', detail
                    noisily display as text ""
                    noisily display as text "`bytype_var':"
                    noisily display as text "  Min:    " as result %8.3f r(min)
                    noisily display as text "  Mean:   " as result %8.3f r(mean)
                    noisily display as text "  Median: " as result %8.3f r(p50)
                    noisily display as text "  Max:    " as result %8.3f r(max)
                }
            }
            else {
                * Without bytype, show stats for single variable
                quietly sum `generate', detail
                noisily display as text "Continuous exposure (person-years):"
                noisily display as text "  Min:    " as result %8.3f r(min)
                noisily display as text "  Mean:   " as result %8.3f r(mean)
                noisily display as text "  Median: " as result %8.3f r(p50)
                noisily display as text "  Max:    " as result %8.3f r(max)
            }
        }
        
        * Calculate person-time by exposure category (only for categorical)
        tempfile _summarize_temp
        quietly save `_summarize_temp'

        if "`exp_type'" != "continuous" {
            * When bytype is used, get explicit list of bytype variables to avoid ambiguous abbreviation
            if "`bytype'" != "" {
                quietly ds `stub_name'*
                local collapse_by_vars "`r(varlist)'"
            }
            else {
                local collapse_by_vars "`generate'"
            }
            
            * Category time is the UNION of that category's own intervals per
            * person, so a category whose rows overlap each other is not
            * counted twice. The denominator is the study-window person-time.
            tempvar _catgrp _catdays
            quietly egen long `_catgrp' = group(id `collapse_by_vars')
            _tvtools_interval_union, id(`_catgrp') start(start) stop(stop) ///
                uniondays(`_catdays')
            sort `_catgrp'
            quietly by `_catgrp': keep if _n == 1

            quietly collapse (sum) cat_time = `_catdays', by(`collapse_by_vars')
            quietly gen double cat_pct = cond(`total_time' > 0, 100 * cat_time / `total_time', .)
            noisily list `collapse_by_vars' cat_time cat_pct, noobs separator(0)

            * Overlapping categories are multi-membership by construction, so
            * say so rather than presenting shares that look mutually
            * exclusive but sum past 100.
            quietly summarize cat_time, meanonly
            local _cat_total = r(sum)
            if `total_time' > 0 & `_cat_total' > `total_time' + 1e-6 {
                noisily display as text "  Note: categories overlap in time, so a day can belong to more"
                noisily display as text "  than one category. Shares are multi-membership and sum above 100%."
            }
        }

        * Restore unconditionally. summarize is report-only, but the restore
        * used to sit INSIDE the categorical branch, so a continuous-unit call
        * (exp_type=="continuous") returned to the caller with an undocumented
        * period_length column welded onto the committed schema -- a display
        * option silently changing the data it was asked to describe. The
        * column was never read by either branch; the generate that created it
        * is gone with it.
        quietly use `_summarize_temp', clear
    }
    
    **# Validation dataset creation (validate option)
    * Per-person exposure metrics need the single output variable, so validate
    * is unavailable with bytype; say so rather than silently skipping.
    if "`validate'" != "" & "`bytype'" != "" {
        noisily display as text "Note: validate is not available with bytype; validation dataset not created."
    }
    if "`validate'" != "" & "`bytype'" == "" {
        * Create comprehensive validation dataset with per-person metrics
        tempfile _validate_temp
        quietly save `_validate_temp'
        
        * Covered days use the same clipped union engine as check, so the
        * validation dataset and the coverage report cannot disagree.
        _tvtools_interval_union, id(id) start(start) stop(stop) ///
            cliplow(study_entry) cliphigh(study_exit) ///
            uniondays(total_covered)

        sort id start stop
        quietly generate double period_days = stop - start + 1
        quietly by id: generate double expected_days = study_exit[1] - study_entry[1] + 1
        quietly generate double pct_covered = 100 * total_covered / expected_days

        * Exposed time is the union of the exposed rows only.
        quietly gen double __exposed_val = (`generate' != `reference')
        tempvar _expgrp
        quietly egen long `_expgrp' = group(id __exposed_val)
        _tvtools_interval_union, id(`_expgrp') start(start) stop(stop) ///
            uniondays(__exp_union_days)
        sort id start stop
        quietly gen double exp_days = cond(__exposed_val, __exp_union_days, 0)
        quietly by id: egen double total_exposed_days = max(exp_days)
        drop __exp_union_days
        quietly by id: egen double n_periods = count(id)
        
        * Calculate number of transitions
        quietly by id (start): gen double __trans_ind = (`generate' != `generate'[_n-1]) if _n > 1 & id == id[_n-1]
        quietly by id: egen double n_transitions = total(__trans_ind)
        drop __trans_ind
        
        * Gaps use the running maximum stop, matching check and gaps above.
        quietly by id (start stop): gen double __rmaxv = stop if _n == 1
        quietly by id (start stop): replace __rmaxv = max(__rmaxv[_n-1], stop) if _n > 1
        quietly by id (start stop): gen double __gap_val = ///
            (start > __rmaxv[_n-1] + 1) if _n > 1
        quietly by id: egen double any_gaps = max(__gap_val)
        quietly by id: egen double n_gaps = total(__gap_val)
        drop __gap_val __rmaxv
        
        * First and last exposure dates
        quietly by id: egen double __first_exp_val = min(start) if __exposed_val
        quietly by id: egen double __last_exp_val = max(stop) if __exposed_val
        quietly by id: egen double first_exposure = min(__first_exp_val)
        quietly by id: egen double last_exposure = max(__last_exp_val)
        
        * Keep one row per person
        quietly by id: keep if _n == 1
        keep id total_covered expected_days pct_covered total_exposed_days ///
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
            * saveas() without a .dta extension: subinstr changes nothing and
            * the validation file would silently collide with the main output
            if "`validation_file'" == "`saveas'" {
                local validation_file "`saveas'_validation.dta"
            }
        }
        
        if "`replace'" != "" {
            quietly save "`validation_file'", replace
        }
        else {
            quietly save "`validation_file'"
        }
        
        noisily display as text "Validation dataset saved as: " as result "`validation_file'"
        
        quietly use `_validate_temp', clear
    }

    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
