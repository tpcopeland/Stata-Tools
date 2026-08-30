* crossval_survival_neardate.do - rangematch parity with survival::neardate
*
* Public oracle: the official survival::neardate closest-laboratory-date
* example. The R companion computes the expected row indices at runtime; no
* expected match is copied from rangematch or hardcoded in this file.
clear all
version 16.1
set varabbrev off

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
local qa_dir "`r(qa_dir)'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# Oracle generation
tempfile ref_probe
local ref_dir "`ref_probe'_neardate"
mkdir "`ref_dir'"
local r_script "`qa_dir'/crossval_survival_neardate_r.R"

local ++test_count
capture noisily {
    confirm file "`r_script'"
    shell Rscript "`r_script'" "`ref_dir'"
    confirm file "`ref_dir'/R_OK"
    confirm file "`ref_dir'/neardate_master.csv"
    confirm file "`ref_dir'/neardate_using.csv"
    confirm file "`ref_dir'/neardate_expected.csv"
}
if _rc == 0 {
    display as result "PASS: survival::neardate public oracle generated"
    local ++pass_count
}
else {
    display as error "FAIL: Rscript with package survival is required"
    local ++fail_count
    local failed_tests "`failed_tests' oracle"
}

if `fail_count' > 0 {
    display "RESULT: crossval_survival_neardate tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

tempfile master using expected
import delimited using "`ref_dir'/neardate_master.csv", clear varnames(1)
generate double event_key = daily(event_date, "YMD")
format event_key %td
drop event_date
save "`master'", replace

import delimited using "`ref_dir'/neardate_using.csv", clear varnames(1)
generate double event_key = daily(event_date, "YMD")
format event_key %td
drop event_date
save "`using'", replace

import delimited using "`ref_dir'/neardate_expected.csv", clear varnames(1)
save "`expected'", replace

**# First observation on or after each index date
local ++test_count
capture noisily {
    use "`master'", clear
    rangematch event_key 0 . using "`using'", by(id) ///
        keepusing(using_id) nearest(after) ties(first) ///
        unmatched(master) distance(delta) stats
    local got_matches = r(N_matched_pairs)
    local got_unmatched = r(N_unmatched_master)
    assert r(N_pairs) == 10
    assert _N == 10

    merge 1:1 master_id using "`expected'", assert(match) nogenerate
    count if after_using_id < .
    local expected_matches = r(N)
    assert `got_matches' == `expected_matches'
    assert `got_unmatched' == 10 - `expected_matches'
    assert using_id == after_using_id if after_using_id < .
    assert missing(using_id) if missing(after_using_id)
    assert delta >= 0 & delta < . if after_using_id < .
    assert missing(delta) if missing(after_using_id)
}
if _rc == 0 {
    display as result "PASS: nearest(after) matches survival::neardate"
    local ++pass_count
}
else {
    display as error "FAIL: nearest(after) differs from survival::neardate"
    local ++fail_count
    local failed_tests "`failed_tests' after"
}

**# Last observation on or before each index date
local ++test_count
capture noisily {
    use "`master'", clear
    rangematch event_key . 0 using "`using'", by(id) ///
        keepusing(using_id) nearest(before) ties(first) ///
        unmatched(master) distance(delta) stats
    local got_matches = r(N_matched_pairs)
    local got_unmatched = r(N_unmatched_master)
    assert r(N_pairs) == 10
    assert _N == 10

    merge 1:1 master_id using "`expected'", assert(match) nogenerate
    count if prior_using_id < .
    local expected_matches = r(N)
    assert `got_matches' == `expected_matches'
    assert `got_unmatched' == 10 - `expected_matches'
    assert using_id == prior_using_id if prior_using_id < .
    assert missing(using_id) if missing(prior_using_id)
    assert delta <= 0 & delta < . if prior_using_id < .
    assert missing(delta) if missing(prior_using_id)
}
if _rc == 0 {
    display as result "PASS: nearest(before) matches survival::neardate"
    local ++pass_count
}
else {
    display as error "FAIL: nearest(before) differs from survival::neardate"
    local ++fail_count
    local failed_tests "`failed_tests' prior"
}

**# Prior observation constrained to the documented 21-day window
local ++test_count
capture noisily {
    use "`master'", clear
    rangematch event_key -21 0 using "`using'", by(id) ///
        keepusing(using_id) nearest(before) ties(first) ///
        unmatched(master) distance(delta) stats
    local got_matches = r(N_matched_pairs)
    local got_unmatched = r(N_unmatched_master)
    assert r(N_pairs) == 10
    assert _N == 10

    merge 1:1 master_id using "`expected'", assert(match) nogenerate
    count if prior21_using_id < .
    local expected_matches = r(N)
    assert `got_matches' == `expected_matches'
    assert `got_unmatched' == 10 - `expected_matches'
    assert using_id == prior21_using_id if prior21_using_id < .
    assert missing(using_id) if missing(prior21_using_id)
    assert inrange(delta, -21, 0) if prior21_using_id < .
    assert missing(delta) if missing(prior21_using_id)
}
if _rc == 0 {
    display as result "PASS: 21-day nearest(before) matches documented oracle"
    local ++pass_count
}
else {
    display as error "FAIL: 21-day nearest(before) differs from documented oracle"
    local ++fail_count
    local failed_tests "`failed_tests' prior21"
}

**# Summary
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
}
else {
    display as result "ALL SURVIVAL NEARDATE CROSS-VALIDATIONS PASSED"
}
display "RESULT: crossval_survival_neardate tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
