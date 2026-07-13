/*******************************************************************************
* validation_audit_tvdiagnose.do
*
* Audit-closure known-answer checks for person-specific coverage windows,
* scriptable diagnostics, union person-time, and swimlane graph outcomes.
*
* Author: Timothy P Copeland, Karolinska Institutet
* Date: 2026-07-13
*******************************************************************************/

clear all
set varabbrev off
version 16.0

capture log close _all
quietly log using "validation_audit_tvdiagnose.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

display as result "tvtools QA: audit closure for tvdiagnose -- $S_DATE $S_TIME"

**# 1. each person is clipped to that person's own study window
local ++test_count
capture noisily {
    clear
    input byte id double(start stop entry exit_d)
        1   1  10   1  10
        2 101 110 101 110
    end
    tvdiagnose, id(id) start(start) stop(stop) ///
        entry(entry) exit(exit_d) coverage
    assert r(coverage_run) == 1
    assert r(mean_coverage) == 100
    assert r(min_coverage) == 100
    assert r(max_coverage) == 100
    assert r(n_with_gaps) == 0
    assert r(n_incomplete_coverage) == 0
    assert r(n_coverage_gaps) == 0

    clear
    input byte id double(start stop entry exit_d)
        1 1 3 1 6
        1 4 6 2 6
    end
    datasignature set
    local varabbrev_before = c(varabbrev)
    capture tvdiagnose, id(id) start(start) stop(stop) ///
        entry(entry) exit(exit_d) coverage
    local cmdrc = _rc
    assert `cmdrc' == 459
    datasignature confirm
    assert "`c(varabbrev)'" == "`varabbrev_before'"
}
if _rc == 0 {
    display as result "  PASS: person-specific windows both report complete coverage"
    local ++pass_count
}
else {
    display as error "  FAIL: person-specific coverage clipping (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' person_windows"
}

**# 2. clipped-union coverage is exact per ID and order invariant
local ++test_count
capture noisily {
    clear
    input byte id double(start stop entry exit_d)
        1   0   3   1  10
        1   5  12   1  10
        2  90 105 101 110
        2 105 120 101 110
        3 100 150 201 205
        3 250 260 201 205
    end
    set seed 7731
    generate double shuffle = runiform()
    sort shuffle
    drop shuffle

    tvdiagnose, id(id) start(start) stop(stop) ///
        entry(entry) exit(exit_d) coverage
    local shuffled_mean = r(mean_coverage)
    local shuffled_min = r(min_coverage)
    local shuffled_max = r(max_coverage)
    local shuffled_incomplete = r(n_incomplete_coverage)
    local shuffled_gaps = r(n_coverage_gaps)
    assert abs(`shuffled_mean' - 190/3) < 1e-10
    assert `shuffled_min' == 0 & `shuffled_max' == 100
    assert `shuffled_incomplete' == 2
    assert `shuffled_gaps' == 2

    sort id start stop
    tvdiagnose, id(id) start(start) stop(stop) ///
        entry(entry) exit(exit_d) coverage
    assert abs(r(mean_coverage) - `shuffled_mean') < 1e-12
    assert r(min_coverage) == `shuffled_min'
    assert r(max_coverage) == `shuffled_max'
    assert r(n_incomplete_coverage) == `shuffled_incomplete'
    assert r(n_coverage_gaps) == `shuffled_gaps'

    forvalues j = 1/3 {
        preserve
        keep if id == `j'
        tvdiagnose, id(id) start(start) stop(stop) ///
            entry(entry) exit(exit_d) coverage
        local expected_pct = cond(`j' == 1, 90, cond(`j' == 2, 100, 0))
        local expected_gap = (`j' != 2)
        assert abs(r(mean_coverage) - `expected_pct') < 1e-12
        assert r(min_coverage) == `expected_pct'
        assert r(max_coverage) == `expected_pct'
        assert r(n_coverage_gaps) == `expected_gap'
        restore
    }
}
if _rc == 0 {
    display as result "  PASS: clipped union, outside intervals, and ordering have exact coverage"
    local ++pass_count
}
else {
    display as error "  FAIL: clipped-union coverage oracle (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' coverage_union"
}

**# 3. summary returns global and per-exposure union person-time
local ++test_count
capture noisily {
    clear
    input byte id double(start stop) byte exposure
        1 1 10 0
        1 3  5 0
        2 1  4 1
        2 3  7 1
        3 1  5 0
        3 3  7 1
    end
    tvdiagnose, id(id) start(start) stop(stop) exposure(exposure) summarize
    matrix S = r(exposure_summary)
    local snames : colnames S
    assert r(summarize_run) == 1
    assert r(total_person_time) == 24
    assert r(raw_interval_person_time) == 32
    assert r(overlap_excess_person_time) == 8
    assert r(n_exposure_levels) == 2
    assert rowsof(S) == 2 & colsof(S) == 5
    assert "`snames'" == "exposure raw_days person_days percent n_periods"
    assert S[1,1] == 0 & S[1,2] == 18 & S[1,3] == 15
    assert abs(S[1,4] - 62.5) < 1e-12 & S[1,5] == 3
    assert S[2,1] == 1 & S[2,2] == 14 & S[2,3] == 12
    assert abs(S[2,4] - 50) < 1e-12 & S[2,5] == 3
    assert S[1,3] + S[2,3] > r(total_person_time)

    generate double raw_days = 901
    generate double person_days = 902
    generate double percent = 903
    generate double n_periods = 904
    datasignature set
    tvdiagnose, id(id) start(start) stop(stop) exposure(exposure) summarize
    matrix C = r(exposure_summary)
    assert mreldif(C, S) == 0
    assert raw_days == 901 & person_days == 902
    assert percent == 903 & n_periods == 904
    datasignature confirm

    drop raw_days person_days percent n_periods
    rename exposure raw_days
    datasignature set, reset
    tvdiagnose, id(id) start(start) stop(stop) exposure(raw_days) summarize
    matrix A = r(exposure_summary)
    assert mreldif(A, S) == 0
    datasignature confirm

    clear
    input byte id double(start stop exposure)
        1 1 2 0
        1 3 4 .
    end
    tvdiagnose, id(id) start(start) stop(stop) exposure(exposure) summarize
    matrix M = r(exposure_summary)
    assert r(n_exposure_levels) == 2
    assert M[1,1] == 0 & missing(M[2,1])
    assert M[1,2] == 2 & M[2,2] == 2
    assert M[1,3] == 2 & M[2,3] == 2
    assert M[1,4] == 50 & M[2,4] == 50
}
if _rc == 0 {
    display as result "  PASS: raw, global-union, and exposure-union person-time are distinct"
    local ++pass_count
}
else {
    display as error "  FAIL: union person-time summary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' union_person_time"
}

**# 4. selected reports return exact zeros when there are no findings
local ++test_count
capture noisily {
    clear
    input byte id double(start stop entry exit_d exposure)
        1 1  5 1 10 0
        1 6 10 1 10 0
        2 1 10 1 10 0
    end
    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_d) ///
        exposure(exposure) all
    assert r(coverage_run) == 1 & r(gaps_run) == 1
    assert r(overlaps_run) == 1 & r(summarize_run) == 1
    assert r(mean_coverage) == 100 & r(n_coverage_gaps) == 0
    assert r(n_gaps) == 0 & r(n_gap_ids) == 0
    assert r(mean_gap) == 0 & r(median_gap) == 0 & r(max_gap) == 0
    assert r(n_large_gaps) == 0 & r(n_large_gap_ids) == 0
    assert r(n_overlaps) == 0 & r(n_overlap_ids) == 0
    assert r(n_ids_affected) == 0
    assert r(total_person_time) == 20
    assert r(raw_interval_person_time) == 20
    assert r(overlap_excess_person_time) == 0
    assert r(graph_requested) == 0 & r(graph_created) == 0
    assert r(graph_rc) == 0
}
if _rc == 0 {
    display as result "  PASS: no-finding reports expose exact machine-readable zeros"
    local ++pass_count
}
else {
    display as error "  FAIL: zero-result return contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' zero_returns"
}

**# 5. swimlane uses value labels and handles an all-missing exposure
local ++test_count
capture noisily {
    clear
    input byte id double(start stop) byte exposure
        1 1 3 0
        1 4 6 1
        2 1 2 0
        2 3 6 1
    end
    label define exposure_lbl 0 "No exposure" 1 "Current treatment"
    label values exposure exposure_lbl
    capture graph drop tvd_swimlane
    tvdiagnose, id(id) start(start) stop(stop) exposure(exposure) swimlane
    assert r(graph_requested) == 1 & r(graph_created) == 1
    assert r(graph_rc) == 0
    assert r(graph_ids_total) == 2 & r(graph_ids_plotted) == 2
    assert r(graph_truncated) == 0
    assert "`r(graph_name)'" == "tvd_swimlane"
    graph describe tvd_swimlane
    local labeled_command `"`r(command)'"'
    assert strpos(`"`labeled_command'"', "No exposure") > 0
    assert strpos(`"`labeled_command'"', "Current treatment") > 0
    assert strpos(`"`labeled_command'"', "exposure=0") == 0

    replace exposure = .
    capture graph drop tvd_swimlane
    tvdiagnose, id(id) start(start) stop(stop) exposure(exposure) swimlane
    assert r(graph_requested) == 1 & r(graph_created) == 1
    assert r(graph_rc) == 0
    graph describe tvd_swimlane
    local missing_command `"`r(command)'"'
    assert strpos(`"`missing_command'"', "Missing") > 0

    clear
    input byte id double(start stop) str12 exposure_text
        1 1 3 "Group A"
        1 4 6 "Group B"
        2 1 6 "Group A"
    end
    capture graph drop tvd_swimlane
    tvdiagnose, id(id) start(start) stop(stop) ///
        exposure(exposure_text) swimlane
    assert r(graph_requested) == 1 & r(graph_created) == 1
    assert r(graph_rc) == 0
    graph describe tvd_swimlane
    local string_command `"`r(command)'"'
    assert strpos(`"`string_command'"', "Group A") > 0
    assert strpos(`"`string_command'"', "Group B") > 0

    clear
    input byte id double(start stop) byte exposure
        1 1 3 0
        1 4 6 1
        2 1 6 0
    end
    capture graph drop tvd_swimlane
    tvdiagnose, id(id) start(start) stop(stop) ///
        exposure(exposure) swimlane maxids(1)
    assert r(graph_created) == 1 & r(graph_rc) == 0
    assert r(graph_ids_total) == 2 & r(graph_ids_plotted) == 1
    assert r(graph_truncated) == 1
    graph describe tvd_swimlane
    local fallback_command `"`r(command)'"'
    assert strpos(`"`fallback_command'"', "exposure=0") > 0
    assert strpos(`"`fallback_command'"', "exposure=1") > 0
}
if _rc == 0 {
    display as result "  PASS: labeled and missing exposure levels produce scriptable swimlanes"
    local ++pass_count
}
else {
    display as error "  FAIL: swimlane labels/missing levels (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' swimlane_labels"
}

**# 6. graph failure is returned without corrupting data or an existing graph
local ++test_count
capture noisily {
    clear
    input byte id double(start stop)
        1 1 3
        1 4 6
        2 1 6
    end
    twoway scatter stop start, name(tvd_swimlane, replace)
    graph describe tvd_swimlane
    local graph_before `"`r(command)'"'
    datasignature set

    capture program drop twoway
    program define twoway
        exit 777
    end
    tvdiagnose, id(id) start(start) stop(stop) swimlane
    assert r(graph_requested) == 1 & r(graph_created) == 0
    assert r(graph_rc) == 777
    assert r(graph_ids_total) == 2 & r(graph_ids_plotted) == 2
    datasignature confirm
    graph describe tvd_swimlane
    local graph_after `"`r(command)'"'
    assert `"`graph_after'"' == `"`graph_before'"'
    program drop twoway
    discard
}
if _rc == 0 {
    display as result "  PASS: swimlane failure is explicit and analytically nonfatal"
    local ++pass_count
}
else {
    capture program drop twoway
    discard
    display as error "  FAIL: swimlane failure transaction (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' swimlane_failure"
}

**# 7. positive gap/overlap reports return event and affected-ID counts
local ++test_count
capture noisily {
    clear
    input byte id double(start stop)
        1  1 2
        1  5 5
        1 20 20
        2  1 3
        2  5 5
    end
    tvdiagnose, id(id) start(start) stop(stop) gaps threshold(5)
    assert r(gaps_run) == 1
    assert r(n_gaps) == 3 & r(n_gap_ids) == 2
    assert abs(r(mean_gap) - 17/3) < 1e-12
    assert r(median_gap) == 2 & r(max_gap) == 14
    assert r(n_large_gaps) == 1 & r(n_large_gap_ids) == 1

    clear
    input byte id double(start stop)
        1 1 5
        1 3 4
        1 6 7
        2 1 2
        2 2 3
    end
    tvdiagnose, id(id) start(start) stop(stop) overlaps
    assert r(overlaps_run) == 1
    assert r(n_overlaps) == 2
    assert r(n_overlap_ids) == 2
    assert r(n_ids_affected) == 2
}
if _rc == 0 {
    display as result "  PASS: diagnostic event and affected-person counts are distinct"
    local ++pass_count
}
else {
    display as error "  FAIL: gap/overlap affected-ID returns (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' affected_ids"
}

display "RESULT: validation_audit_tvdiagnose tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}

capture graph drop _all
capture log close _all
