clear all
set more off
set varabbrev off
version 16.0

capture log close
log using "test_tvdiagnose.log", replace nomsg

* Shared scaffold: test globals + helpers + sandboxed install bootstrap
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""
local run_only = 0
local quiet = 0

* run_test/test_pass/test_fail harness counters (folded into the totals below)
global TVQA_PASS = 0
global TVQA_FAIL = 0
global TVQA_FAILED ""
global TVQA_CURRENT ""

display as result "tvtools QA: tvdiagnose functional -- $S_DATE $S_TIME"


**# ===== merged from test_tvtools.do L12670-12996: TVDIAGNOSE expanded =====

* SECTION 4: TVDIAGNOSE — expanded tests

* Create standard test data for tvdiagnose
capture {
    clear
    set obs 20
    gen id = ceil(_n / 4)
    bysort id: gen spell = _n
    gen start = mdy(1,1,2020) + (spell - 1) * 30
    gen stop = start + 29
    gen exposure = mod(spell, 2)
    gen entry = mdy(1,1,2020)
    gen exit_date = mdy(12,31,2020)
    format start stop entry exit_date %td
    tempfile diag_data
    save `diag_data'
}

* TEST 4.1: Coverage report only
local ++test_count
capture noisily {
    use `diag_data', clear
    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_date) coverage
    assert r(n_persons) == 5
    assert r(n_observations) == 20
    assert !missing(r(mean_coverage))
    assert !missing(r(n_with_gaps))
}
if _rc == 0 {
    display as result "  PASS: Coverage report returns expected stored results"
    local ++pass_count
}
else {
    display as error "  FAIL: Coverage report returns expected stored results (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.1"
}

* TEST 4.2: Gaps report only
local ++test_count
capture noisily {
    * Create data with explicit gaps
    clear
    set obs 6
    gen id = ceil(_n / 3)
    bysort id: gen spell = _n
    gen start = mdy(1,1,2020) + (spell - 1) * 60
    gen stop = start + 29
    format start stop %td

    tvdiagnose, id(id) start(start) stop(stop) gaps
    assert r(n_persons) == 2
    * Each person has 3 periods with 30-day gaps between them
    assert r(n_gaps) > 0
    assert r(mean_gap) > 0
    assert r(max_gap) > 0
}
if _rc == 0 {
    display as result "  PASS: Gaps report detects gaps correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Gaps report detects gaps correctly (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.2"
}

* TEST 4.3: Overlaps report only
local ++test_count
capture noisily {
    * Create data with overlapping periods
    clear
    set obs 6
    gen id = ceil(_n / 3)
    bysort id: gen spell = _n
    gen start = mdy(1,1,2020) + (spell - 1) * 20
    gen stop = start + 29
    format start stop %td
    * Periods overlap by 10 days

    tvdiagnose, id(id) start(start) stop(stop) overlaps
    assert r(n_overlaps) > 0
    assert r(n_ids_affected) > 0
}
if _rc == 0 {
    display as result "  PASS: Overlaps report detects overlaps correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Overlaps report detects overlaps correctly (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.3"
}

* TEST 4.4: Summarize report only
local ++test_count
capture noisily {
    use `diag_data', clear
    tvdiagnose, id(id) start(start) stop(stop) exposure(exposure) summarize
    assert r(total_person_time) > 0
}
if _rc == 0 {
    display as result "  PASS: Summarize report returns total_person_time"
    local ++pass_count
}
else {
    display as error "  FAIL: Summarize report returns total_person_time (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.4"
}

* TEST 4.5: All diagnostics
local ++test_count
capture noisily {
    use `diag_data', clear
    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_date) ///
        exposure(exposure) all
    assert r(n_persons) == 5
    assert !missing(r(mean_coverage))
    assert !missing(r(total_person_time))
}
if _rc == 0 {
    display as result "  PASS: all option runs all diagnostic reports"
    local ++pass_count
}
else {
    display as error "  FAIL: all option runs all diagnostic reports (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.5"
}

* TEST 4.6: No report option — error 198
local ++test_count
capture noisily {
    use `diag_data', clear
    capture tvdiagnose, id(id) start(start) stop(stop)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: No report option returns error 198"
    local ++pass_count
}
else {
    display as error "  FAIL: No report option returns error 198 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.6"
}

* TEST 4.7: Coverage without entry/exit — error 198
local ++test_count
capture noisily {
    use `diag_data', clear
    capture tvdiagnose, id(id) start(start) stop(stop) coverage
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Coverage without entry/exit returns error 198"
    local ++pass_count
}
else {
    display as error "  FAIL: Coverage without entry/exit returns error 198 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.7"
}

* TEST 4.8: Summarize without exposure — error 198
local ++test_count
capture noisily {
    use `diag_data', clear
    capture tvdiagnose, id(id) start(start) stop(stop) summarize
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Summarize without exposure returns error 198"
    local ++pass_count
}
else {
    display as error "  FAIL: Summarize without exposure returns error 198 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.8"
}

* TEST 4.9: No gaps in data
local ++test_count
capture noisily {
    clear
    set obs 10
    gen id = ceil(_n / 5)
    bysort id: gen spell = _n
    gen start = mdy(1,1,2020) + (spell - 1) * 30
    gen stop = start + 29
    format start stop %td

    tvdiagnose, id(id) start(start) stop(stop) gaps
    assert r(n_gaps) == 0
}
if _rc == 0 {
    display as result "  PASS: No gaps reported when data has no gaps"
    local ++pass_count
}
else {
    display as error "  FAIL: No gaps reported when data has no gaps (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.9"
}

* TEST 4.10: No overlaps in data
local ++test_count
capture noisily {
    clear
    set obs 10
    gen id = ceil(_n / 5)
    bysort id: gen spell = _n
    gen start = mdy(1,1,2020) + (spell - 1) * 30
    gen stop = start + 29
    format start stop %td

    tvdiagnose, id(id) start(start) stop(stop) overlaps
    assert r(n_overlaps) == 0
    assert r(n_ids_affected) == 0
}
if _rc == 0 {
    display as result "  PASS: No overlaps reported when data has no overlaps"
    local ++pass_count
}
else {
    display as error "  FAIL: No overlaps reported when data has no overlaps (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.10"
}

* TEST 4.11: Empty dataset — error 2000
local ++test_count
capture noisily {
    clear
    set obs 1
    gen id = 1
    gen start = mdy(1,1,2020)
    gen stop = mdy(1,31,2020)
    format start stop %td
    drop in 1
    capture tvdiagnose, id(id) start(start) stop(stop) gaps
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: Empty dataset returns error 2000"
    local ++pass_count
}
else {
    display as error "  FAIL: Empty dataset returns error 2000 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.11"
}

* TEST 4.12: Threshold option for gap analysis
local ++test_count
capture noisily {
    * Create data with gaps of varying size
    clear
    set obs 4
    gen id = 1
    gen spell = _n
    gen start = mdy(1,1,2020) if spell == 1
    replace start = mdy(2,15,2020) if spell == 2
    replace start = mdy(6,1,2020) if spell == 3
    replace start = mdy(12,1,2020) if spell == 4
    gen stop = start + 29
    format start stop %td

    tvdiagnose, id(id) start(start) stop(stop) gaps threshold(60)
    * Only gaps > 60 days should be flagged as large
    assert r(n_gaps) > 0
    assert !missing(r(n_large_gaps))
}
if _rc == 0 {
    display as result "  PASS: Threshold option filters large gaps"
    local ++pass_count
}
else {
    display as error "  FAIL: Threshold option filters large gaps (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.12"
}

* TEST 4.13: Data preservation after tvdiagnose
local ++test_count
capture noisily {
    use `diag_data', clear
    local n_before = _N
    datasignature
    local sig_before = r(datasignature)
    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_date) ///
        exposure(exposure) all
    assert _N == `n_before'
    datasignature
    assert r(datasignature) == "`sig_before'"
}
if _rc == 0 {
    display as result "  PASS: Data preserved after tvdiagnose"
    local ++pass_count
}
else {
    display as error "  FAIL: Data preserved after tvdiagnose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.13"
}

* TEST 4.14: Varabbrev restore after tvdiagnose
local ++test_count
capture noisily {
    use `diag_data', clear
    set varabbrev on
    tvdiagnose, id(id) start(start) stop(stop) gaps
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: Varabbrev restored after tvdiagnose"
    local ++pass_count
}
else {
    display as error "  FAIL: Varabbrev restored after tvdiagnose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.14"
}



* ===== Summary =====
* Fold the run_test/test_pass/test_fail harness counters into the totals.
local pass_count = `pass_count' + $TVQA_PASS
local fail_count = `fail_count' + $TVQA_FAIL
local failed_tests "`failed_tests' $TVQA_FAILED"
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA tvdiagnose functional Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: test_tvdiagnose tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"

