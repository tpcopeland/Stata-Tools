clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "validation_tvdiagnose.log", replace nomsg

* Shared scaffold: test globals + helpers + sandboxed install bootstrap
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""
local run_only = 0
local quiet = 0
local machine = 0

* run_test/test_pass/test_fail harness counters (folded into the totals below)
global TVQA_PASS = 0
global TVQA_FAIL = 0
global TVQA_FAILED ""
global TVQA_CURRENT ""

display as result "tvtools QA: tvdiagnose correctness -- $S_DATE $S_TIME"


**# ===== merged from validation_tvtools.do L20307-20542: TVDIAGNOSE deep validation =====

* SECTION 10: TVDIAGNOSE DEEP VALIDATION (8 tests)

capture noisily {

* Test 10.1: 100% coverage
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop s_entry s_exit)
    1 "2020-01-01" "2020-12-31" "2020-01-01" "2020-12-31"
    2 "2020-01-01" "2020-12-31" "2020-01-01" "2020-12-31"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    gen double entry = date(s_entry, "YMD")
    gen double exit_ = date(s_exit, "YMD")
    format %td start stop entry exit_
    drop s_*
    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_) coverage
    assert r(mean_coverage) == 100
    assert r(n_with_gaps) == 0
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose 100% coverage"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose 100% coverage (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10.1"
}

* Test 10.2: ~50% known gap
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop s_entry s_exit)
    1 "2020-01-01" "2020-07-01" "2020-01-01" "2021-01-01"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    gen double entry = date(s_entry, "YMD")
    gen double exit_ = date(s_exit, "YMD")
    format %td start stop entry exit_
    drop s_*
    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_) coverage
    assert r(mean_coverage) > 45 & r(mean_coverage) < 55
    assert r(n_with_gaps) == 1
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose ~50% coverage"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose ~50% coverage (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10.2"
}

* Test 10.3: Gap size precision
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop s_entry s_exit)
    1 "2020-01-01" "2020-03-31" "2020-01-01" "2020-12-31"
    1 "2020-05-01" "2020-12-31" "2020-01-01" "2020-12-31"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    gen double entry = date(s_entry, "YMD")
    gen double exit_ = date(s_exit, "YMD")
    format %td start stop entry exit_
    drop s_*
    * Gap: Apr 1 to Apr 30 = ~31 days
    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_) gaps
    assert r(n_gaps) == 1
    assert r(mean_gap) >= 28 & r(mean_gap) <= 35
    assert r(max_gap) >= 28 & r(max_gap) <= 35
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose gap size precision"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose gap size precision (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10.3"
}

* Test 10.4: threshold() filtering
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop s_entry s_exit)
    1 "2020-01-01" "2020-02-28" "2020-01-01" "2020-12-31"
    1 "2020-03-05" "2020-05-31" "2020-01-01" "2020-12-31"
    1 "2020-08-01" "2020-12-31" "2020-01-01" "2020-12-31"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    gen double entry = date(s_entry, "YMD")
    gen double exit_ = date(s_exit, "YMD")
    format %td start stop entry exit_
    drop s_*
    * Gap 1: Mar 1-4 = ~5 days (small), Gap 2: Jun 1-Jul 31 = ~61 days (large)
    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_) gaps threshold(30)
    assert r(n_large_gaps) == 1
    assert r(n_gaps) == 2
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose threshold() filtering"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose threshold() filtering (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10.4"
}

* Test 10.5: Overlap count
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop)
    1 "2020-01-01" "2020-06-30"
    1 "2020-04-01" "2020-12-31"
    2 "2020-01-01" "2020-12-31"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    format %td start stop
    drop s_*
    tvdiagnose, id(id) start(start) stop(stop) overlaps
    assert r(n_overlaps) >= 1
    assert r(n_ids_affected) == 1
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose overlap count"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose overlap count (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10.5"
}

* Test 10.6: Person-time by exposure
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop)
    1 "2020-01-01" "2020-12-31"
    2 "2020-01-01" "2020-12-31"
    3 "2020-01-01" "2020-12-31"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    format %td start stop
    drop s_*
    gen byte exp = 1
    tvdiagnose, id(id) start(start) stop(stop) exposure(exp) summarize
    assert r(total_person_time) >= 1090 & r(total_person_time) <= 1100
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose person-time"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose person-time (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10.6"
}

* Test 10.7: all option populates all returns
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop s_entry s_exit)
    1 "2020-01-01" "2020-06-30" "2020-01-01" "2020-12-31"
    1 "2020-07-01" "2020-12-31" "2020-01-01" "2020-12-31"
    2 "2020-01-01" "2020-12-31" "2020-01-01" "2020-12-31"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    gen double entry = date(s_entry, "YMD")
    gen double exit_ = date(s_exit, "YMD")
    format %td start stop entry exit_
    drop s_*
    gen byte exp = 1
    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_) exposure(exp) all
    assert !missing(r(mean_coverage))
    assert !missing(r(n_gaps))
    assert !missing(r(n_overlaps))
    assert !missing(r(total_person_time))
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose all option"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose all option (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10.7"
}

* Test 10.8: Multi-person n_persons
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop)
    1 "2020-01-01" "2020-06-30"
    2 "2020-01-01" "2020-06-30"
    3 "2020-01-01" "2020-06-30"
    4 "2020-01-01" "2020-06-30"
    5 "2020-01-01" "2020-06-30"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    format %td start stop
    drop s_*
    tvdiagnose, id(id) start(start) stop(stop) overlaps
    assert r(n_persons) == 5
    assert r(n_observations) == 5
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose n_persons"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose n_persons (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10.8"
}

}


* ===== Summary =====
* Fold the run_test/test_pass/test_fail harness counters into the totals.
local pass_count = `pass_count' + $TVQA_PASS
local fail_count = `fail_count' + $TVQA_FAIL
local failed_tests "`failed_tests' $TVQA_FAILED"
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA tvdiagnose correctness Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: validation_tvdiagnose tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"

