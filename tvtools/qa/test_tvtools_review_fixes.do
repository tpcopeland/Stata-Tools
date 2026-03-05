*! Test file for tvtools review fixes (#1-#12)
*! Tests the specific issues identified and fixed in code review
version 16.0
set more off
set varabbrev off

clear all

// Reload all modified programs
foreach cmd in tvtools tvdiagnose tvbalance tvcalendar tvtrial {
    capture program drop `cmd'
}
capture program drop _tvtools_detail
capture program drop _tvexpose_check
capture program drop _tvexpose_gaps
capture program drop _tvexpose_overlaps
capture program drop _tvexpose_summarize
capture program drop _tvexpose_validate

quietly run "tvtools/tvtools.ado"
quietly run "tvtools/tvdiagnose.ado"
quietly run "tvtools/tvbalance.ado"
quietly run "tvtools/tvcalendar.ado"
quietly run "tvtools/tvtrial.ado"

local n_passed = 0
local n_failed = 0
local n_tests = 0

display as text _newline "{hline 70}"
display as text "{bf:TVTOOLS REVIEW FIXES - TEST SUITE}"
display as text "{hline 70}" _newline

// =========================================================================
// CREATE TEST DATA
// =========================================================================

// Cohort-like time-varying dataset
clear
set obs 200
gen int id = ceil(_n / 4)
bysort id: gen int period = _n
gen double start = mdy(1, 1, 2020) + (period - 1) * 90
gen double stop = start + 89
format start stop %tdCCYY/NN/DD
gen byte tv_exposure = (runiform() > 0.6)
gen double age = 40 + int(runiform() * 30)
gen double comorbidity = int(runiform() * 5)
gen byte _event = (runiform() > 0.95)

// Entry/exit for some tests
bysort id: egen double study_entry = min(start)
bysort id: egen double study_exit = max(stop)
format study_entry study_exit %tdCCYY/NN/DD

// =========================================================================
// TEST #3: tvtools version date sync
// =========================================================================
local n_tests = `n_tests' + 1
display as text "{bf:Test #3: tvtools version date sync}"
capture noisily tvtools
if _rc == 0 {
    display as result "  PASSED - tvtools runs without error"
    local n_passed = `n_passed' + 1
}
else {
    display as error "  FAILED - tvtools errored: _rc = `=_rc'"
    local n_failed = `n_failed' + 1
}

// =========================================================================
// TEST #4: tvbalance with if/in
// =========================================================================
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test #9a: tvbalance with if condition}"
capture noisily tvbalance age comorbidity if id <= 25, exposure(tv_exposure)
if _rc == 0 {
    display as result "  PASSED - tvbalance with if/in works"
    display as text "  n_ref = " r(n_ref) ", n_exp = " r(n_exp)
    local n_passed = `n_passed' + 1
}
else {
    display as error "  FAILED - tvbalance errored: _rc = `=_rc'"
    local n_failed = `n_failed' + 1
}

// Verify the if condition actually restricts the sample
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test #9b: tvbalance if restriction is effective}"
capture noisily tvbalance age comorbidity, exposure(tv_exposure)
local full_n = r(n_ref) + r(n_exp)
capture noisily tvbalance age comorbidity if id <= 10, exposure(tv_exposure)
local sub_n = r(n_ref) + r(n_exp)
if `sub_n' < `full_n' {
    display as result "  PASSED - subset (" `sub_n' ") < full (" `full_n' ")"
    local n_passed = `n_passed' + 1
}
else {
    display as error "  FAILED - subset not smaller than full"
    local n_failed = `n_failed' + 1
}

// =========================================================================
// TEST #5: tvdiagnose tempvar cleanup
// =========================================================================
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test #10a: tvdiagnose coverage preserves data}"
quietly count
local n_before = r(N)
capture noisily tvdiagnose, id(id) start(start) stop(stop) ///
    entry(study_entry) exit(study_exit) coverage
quietly count
local n_after = r(N)
if _rc == 0 & `n_before' == `n_after' {
    display as result "  PASSED - data preserved (N=" `n_before' " -> " `n_after' ")"
    local n_passed = `n_passed' + 1
}
else {
    display as error "  FAILED - data changed: N=" `n_before' " -> " `n_after' ", rc=" _rc
    local n_failed = `n_failed' + 1
}

// Check no __ variables leaked
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test #10b: tvdiagnose no leaked __ variables}"
capture quietly ds __*
if _rc != 0 {
    display as result "  PASSED - no __ variables found in dataset"
    local n_passed = `n_passed' + 1
}
else {
    display as error "  FAILED - leaked variables: `r(varlist)'"
    local n_failed = `n_failed' + 1
}

// =========================================================================
// TEST #10c: tvdiagnose gaps
// =========================================================================
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test #10c: tvdiagnose gaps preserves data}"
quietly count
local n_before = r(N)
capture noisily tvdiagnose, id(id) start(start) stop(stop) gaps
quietly count
local n_after = r(N)
if _rc == 0 & `n_before' == `n_after' {
    display as result "  PASSED - gaps: data preserved (N=" `n_before' " -> " `n_after' ")"
    local n_passed = `n_passed' + 1
}
else {
    display as error "  FAILED - data changed or error: rc=" _rc
    local n_failed = `n_failed' + 1
}

// =========================================================================
// TEST #10d: tvdiagnose overlaps
// =========================================================================
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test #10d: tvdiagnose overlaps preserves data}"
quietly count
local n_before = r(N)
capture noisily tvdiagnose, id(id) start(start) stop(stop) overlaps
quietly count
local n_after = r(N)
if _rc == 0 & `n_before' == `n_after' {
    display as result "  PASSED - overlaps: data preserved (N=" `n_before' " -> " `n_after' ")"
    local n_passed = `n_passed' + 1
}
else {
    display as error "  FAILED - data changed or error: rc=" _rc
    local n_failed = `n_failed' + 1
}

// =========================================================================
// TEST #10e: tvdiagnose summarize
// =========================================================================
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test #10e: tvdiagnose summarize preserves data}"
quietly count
local n_before = r(N)
capture noisily tvdiagnose, id(id) start(start) stop(stop) exposure(tv_exposure) summarize
quietly count
local n_after = r(N)
if _rc == 0 & `n_before' == `n_after' {
    display as result "  PASSED - summarize: data preserved (N=" `n_before' " -> " `n_after' ")"
    local n_passed = `n_passed' + 1
}
else {
    display as error "  FAILED - data changed or error: rc=" _rc
    local n_failed = `n_failed' + 1
}

// =========================================================================
// TEST #10f: tvdiagnose all
// =========================================================================
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test #10f: tvdiagnose all preserves data}"
quietly count
local n_before = r(N)
capture noisily tvdiagnose, id(id) start(start) stop(stop) ///
    exposure(tv_exposure) entry(study_entry) exit(study_exit) all
quietly count
local n_after = r(N)
if _rc == 0 & `n_before' == `n_after' {
    display as result "  PASSED - all: data preserved (N=" `n_before' " -> " `n_after' ")"
    local n_passed = `n_passed' + 1
}
else {
    display as error "  FAILED - data changed or error: rc=" _rc
    local n_failed = `n_failed' + 1
}

// =========================================================================
// TEST #6: tvtrial dead code removed
// =========================================================================
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test #5: tvtrial runs without dead code}"

// Create simple trial data
preserve
clear
set obs 100
gen int id = _n
gen double study_entry = mdy(1, 1, 2020)
gen double study_exit = mdy(12, 31, 2021)
format study_entry study_exit %td
gen double rx_start = study_entry + int(runiform() * 365) if runiform() > 0.5
format rx_start %td

capture noisily tvtrial, id(id) entry(study_entry) exit(study_exit) ///
    treatstart(rx_start) trials(3) trialinterval(90)
if _rc == 0 {
    display as result "  PASSED - tvtrial runs correctly after dead code removal"
    local n_passed = `n_passed' + 1
}
else {
    display as error "  FAILED - tvtrial errored: _rc = `=_rc'"
    local n_failed = `n_failed' + 1
}
restore

// =========================================================================
// SUMMARY
// =========================================================================

display as text _newline "{hline 70}"
display as text "{bf:TEST SUMMARY}"
display as text "{hline 70}"
display as text "Total tests:  " as result `n_tests'
display as text "Passed:       " as result `n_passed'
display as text "Failed:       " as result `n_failed'
display as text "{hline 70}"

if `n_failed' == 0 {
    display as result _newline "ALL TESTS PASSED"
}
else {
    display as error _newline "`n_failed' TESTS FAILED"
    exit 9
}
