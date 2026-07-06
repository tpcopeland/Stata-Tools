clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "validation_tvexpose_statetime.log", replace nomsg

* Shared scaffold: test globals + helpers + sandboxed install bootstrap
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

* ---------------------------------------------------------------------------
* Known-answer regression suite for tvexpose, statetime.
*
* statetime builds per-id "state runs" (maximal blocks in the same exposure
* category) and returns state_time_years = cumulative days in the current run.
* The run partition is driven by a within-id state-change flag whose first-row
* marker is set with a PLAIN `replace ... if _n == 1` (tvexpose.ado ~L3930),
* i.e. the GLOBAL first observation, not each id's first row. The cumulative
* result survives this only because the state-group label is used purely as a
* `by id state_group` grouping key (its absolute value is irrelevant). This
* suite pins that behaviour so a future refactor of the _n==1 / by-id construct
* cannot silently corrupt statetime for any id other than the first.
*
* Prior coverage (validation_supplemental 6.2, test_integration 7.3) only
* checked "variable exists and > 0" with a SINGLE person -- exactly the case
* where the global _n==1 coincides with id #1's first row, so it never
* exercised a non-first id or a multi-row state run.
*
* Exact oracle (30-day intervals, period_days = stop - start + 1 = 30):
*   single 30-day run      -> 30/365.25 = .08213552
*   two adjacent same-drug -> 60/365.25 = .16427105  (cumulates)
*   next state change      -> resets to 30/365.25
* ---------------------------------------------------------------------------

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

local d30 = 30/365.25
local d60 = 60/365.25

display as result "tvtools QA: tvexpose statetime known-answer -- $S_DATE $S_TIME"

**# Test 1: exact cumulative values + reset (single person, multi-row runs)

local ++test_count
capture {
    tempfile cohort rx
    clear
    input long id double(study_entry study_exit)
        1 22006 22125
    end
    format %td study_entry study_exit
    save "`cohort'", replace

    * drug 1 across TWO adjacent 30-day intervals (one state run, cumulates),
    * then drug 2 (new run), then drug 1 again (new run). split keeps the two
    * adjacent same-drug intervals as separate rows so the cumulative path runs.
    clear
    input long id double(rx_start rx_stop) byte drug
        1 22006 22035 1
        1 22036 22065 1
        1 22066 22095 2
        1 22096 22125 1
    end
    format %td rx_start rx_stop
    save "`rx'", replace

    use "`cohort'", clear
    tvexpose using "`rx'", id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) statetime split

    confirm variable state_time_years
    sort id rx_start
    tempvar row
    by id: gen `row' = _n

    * Row 1: drug 1, first 30-day interval  -> 30/365.25
    assert abs(state_time_years[1] - `d30') < 1e-6
    * Row 2: drug 1, second adjacent interval -> cumulates to 60/365.25
    assert abs(state_time_years[2] - `d60') < 1e-6
    * Row 3: drug 2, new state run           -> resets to 30/365.25
    assert abs(state_time_years[3] - `d30') < 1e-6
    * Row 4: drug 1, new state run           -> 30/365.25
    assert abs(state_time_years[4] - `d30') < 1e-6
}
if _rc == 0 {
    display as result "  PASS 1: statetime cumulates within a run and resets across states"
    local ++pass_count
}
else {
    display as error "  FAIL 1: statetime exact values (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**# Test 2: multi-id symmetry -- a NON-first id must match id #1 exactly

local ++test_count
capture {
    tempfile cohort rx out id1
    clear
    input long id double(study_entry study_exit)
        1 22006 22125
        2 22006 22125
    end
    format %td study_entry study_exit
    save "`cohort'", replace

    * Two IDENTICAL persons -> by construction their statetime trajectories
    * must be identical. If the _n==1 marker corrupts non-first ids, id 2
    * (whose first row is NOT global obs 1) will diverge from id 1.
    clear
    input long id double(rx_start rx_stop) byte drug
        1 22006 22035 1
        1 22036 22065 1
        1 22066 22095 2
        1 22096 22125 1
        2 22006 22035 1
        2 22036 22065 1
        2 22066 22095 2
        2 22096 22125 1
    end
    format %td rx_start rx_stop
    save "`rx'", replace

    use "`cohort'", clear
    tvexpose using "`rx'", id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) statetime split

    confirm variable state_time_years
    sort id rx_start
    tempvar row
    by id: gen long `row' = _n
    save "`out'", replace

    * Extract id 1 trajectory keyed by within-id row.
    keep if id == 1
    keep `row' state_time_years
    rename state_time_years _st1
    save "`id1'", replace

    * Compare id 2 trajectory to id 1 row-for-row.
    use "`out'", clear
    keep if id == 2
    keep `row' state_time_years
    merge 1:1 `row' using "`id1'", assert(match) nogenerate
    gen double _diff = abs(state_time_years - _st1)
    quietly summarize _diff
    assert r(max) < 1e-9

    * And id 2 must ALSO satisfy the exact oracle (not just match id 1).
    sort `row'
    assert abs(state_time_years[1] - `d30') < 1e-6
    assert abs(state_time_years[2] - `d60') < 1e-6
    assert abs(state_time_years[3] - `d30') < 1e-6
    assert abs(state_time_years[4] - `d30') < 1e-6
}
if _rc == 0 {
    display as result "  PASS 2: statetime identical across identical persons (non-first id)"
    local ++pass_count
}
else {
    display as error "  FAIL 2: statetime multi-id symmetry (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# Summary

display as result _newline "tvtools QA tvexpose statetime Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: validation_tvexpose_statetime tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
