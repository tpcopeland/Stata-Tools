clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_edge_cases.log", replace nomsg

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

display as result "tvtools QA: edge cases and stress -- $S_DATE $S_TIME"


**# ===== merged from test_tvtools.do L9621-10107: EDGE CASES + ADDITIONAL STRESS TESTS =====


capture noisily {
*! Test file for tvtools review fixes (#1-#12)
*! Tests the specific issues identified and fixed in code review

clear

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
    test_pass
}
else {
    display as error "  FAILED - tvtools errored: _rc = `=_rc'"
    test_fail "edge-case assertion failed"
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
    test_pass
}
else {
    display as error "  FAILED - data changed: N=" `n_before' " -> " `n_after' ", rc=" _rc
    test_fail "edge-case assertion failed"
}

// Check no __ variables leaked
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test #10b: tvdiagnose no leaked __ variables}"
capture quietly ds __*
if _rc != 0 {
    display as result "  PASSED - no __ variables found in dataset"
    test_pass
}
else {
    display as error "  FAILED - leaked variables: `r(varlist)'"
    test_fail "edge-case assertion failed"
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
    test_pass
}
else {
    display as error "  FAILED - data changed or error: rc=" _rc
    test_fail "edge-case assertion failed"
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
    test_pass
}
else {
    display as error "  FAILED - data changed or error: rc=" _rc
    test_fail "edge-case assertion failed"
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
    test_pass
}
else {
    display as error "  FAILED - data changed or error: rc=" _rc
    test_fail "edge-case assertion failed"
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
    test_pass
}
else {
    display as error "  FAILED - data changed or error: rc=" _rc
    test_fail "edge-case assertion failed"
}

// =========================================================================
// =========================================================================

display as text _newline "{hline 70}"

}

capture noisily {
*! Test file for tvtools review fixes round 2
*! Tests: set more off, tvweight tempvars, tvevent subroutine,
*!        tvmerge capture cleanup

clear

local n_passed = 0
local n_failed = 0
local n_tests = 0

display as text _newline "{hline 70}"
display as text "{bf:TVTOOLS REVIEW FIXES ROUND 2 - TEST SUITE}"
display as text "{hline 70}" _newline

// =========================================================================
// TEST 1: tvweight binary IPTW (basic functionality)
// =========================================================================
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test 2a: tvweight binary IPTW}"

clear
set obs 500
gen byte treatment = (runiform() > 0.5)
gen double age = 40 + int(runiform() * 30)
gen double comorbidity = int(runiform() * 5)

capture noisily tvweight treatment, covariates(age comorbidity) generate(iptw) nolog
if _rc == 0 {
    quietly sum iptw
    if r(N) > 0 & r(min) > 0 {
        display as result "  PASSED - binary IPTW weights created (N=" r(N) ", min=" %5.3f r(min) ")"
        test_pass
    }
    else {
        display as error "  FAILED - invalid weights"
        test_fail "edge-case assertion failed"
    }
}
else {
    display as error "  FAILED - tvweight errored: _rc = `=_rc'"
    test_fail "edge-case assertion failed"
}

// =========================================================================
// TEST 2b: tvweight multinomial IPTW (counter-based tempvar fix)
// =========================================================================
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test 2b: tvweight multinomial IPTW (counter-based tempvars)}"

clear
set obs 600
gen double age = 40 + int(runiform() * 30)
gen double comorbidity = int(runiform() * 5)
// 3-level categorical exposure
gen byte drug = cond(runiform() < 0.33, 0, cond(runiform() < 0.5, 1, 2))

capture noisily tvweight drug, covariates(age comorbidity) generate(mw) nolog
if _rc == 0 {
    quietly sum mw
    if r(N) > 0 & r(min) > 0 {
        display as result "  PASSED - multinomial weights created (N=" r(N) ", min=" %5.3f r(min) ")"
        test_pass
    }
    else {
        display as error "  FAILED - invalid multinomial weights"
        test_fail "edge-case assertion failed"
    }
}
else {
    display as error "  FAILED - tvweight multinomial errored: _rc = `=_rc'"
    test_fail "edge-case assertion failed"
}

// =========================================================================
// TEST 2c: tvweight multinomial stabilized (no macro name collision)
// =========================================================================
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test 2c: tvweight multinomial stabilized}"

capture drop mw
capture noisily tvweight drug, covariates(age comorbidity) generate(mw) stabilized nolog
if _rc == 0 {
    quietly sum mw
    if r(N) > 0 & r(min) > 0 {
        display as result "  PASSED - stabilized multinomial weights (N=" r(N) ", mean=" %5.3f r(mean) ")"
        test_pass
    }
    else {
        display as error "  FAILED - invalid stabilized weights"
        test_fail "edge-case assertion failed"
    }
}
else {
    display as error "  FAILED - tvweight stabilized errored: _rc = `=_rc'"
    test_fail "edge-case assertion failed"
}

// =========================================================================
// TEST 2d: tvweight with denominator option
// =========================================================================
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test 2d: tvweight multinomial with denominator}"

capture drop mw
capture drop ps_score
capture noisily tvweight drug, covariates(age comorbidity) generate(mw) ///
    denominator(ps_score) nolog
if _rc == 0 {
    capture confirm variable ps_score
    if _rc == 0 {
        quietly sum ps_score
        if r(min) > 0 & r(max) <= 1 {
            display as result "  PASSED - denominator created (range " %5.3f r(min) " to " %5.3f r(max) ")"
            test_pass
        }
        else {
            display as error "  FAILED - denominator out of range"
            test_fail "edge-case assertion failed"
        }
    }
    else {
        display as error "  FAILED - denominator variable not created"
        test_fail "edge-case assertion failed"
    }
}
else {
    display as error "  FAILED - tvweight with denominator errored: _rc = `=_rc'"
    test_fail "edge-case assertion failed"
}

// =========================================================================
// TEST 3: tvevent _tvevent_empty_output subroutine
// =========================================================================
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test 3a: tvevent with events (normal path)}"

// Create cohort data
clear
set obs 100
gen int id = _n
gen double event_date = mdy(6, 15, 2020) if runiform() > 0.7
format event_date %td
tempfile event_data
save `event_data'

// Create interval data
clear
set obs 400
gen int id = ceil(_n / 4)
bysort id: gen int period = _n
gen double rx_start = mdy(1, 1, 2020) + (period - 1) * 90
gen double rx_stop = rx_start + 89
format rx_start rx_stop %td
gen byte tv_exposure = (runiform() > 0.5)
tempfile interval_data
save `interval_data'

// Load event data and run tvevent
use `event_data', clear
quietly drop if missing(event_date)
capture noisily tvevent using `interval_data', id(id) date(event_date) ///
    generate(_event) startvar(rx_start) stopvar(rx_stop)
if _rc == 0 {
    capture confirm variable _event
    if _rc == 0 {
        quietly count if _event == 1
        display as result "  PASSED - tvevent normal path works (events=" r(N) ")"
        test_pass
    }
    else {
        display as error "  FAILED - _event variable not created"
        test_fail "edge-case assertion failed"
    }
}
else {
    display as error "  FAILED - tvevent errored: _rc = `=_rc'"
    test_fail "edge-case assertion failed"
}

// =========================================================================
// TEST 3b: tvevent empty-output path (no matching events)
// =========================================================================
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test 3b: tvevent empty events path (subroutine)}"

// Create event data with IDs that DON'T match interval data
clear
set obs 10
gen int id = _n + 1000
gen double event_date = mdy(6, 15, 2020)
format event_date %td

capture noisily tvevent using `interval_data', id(id) date(event_date) ///
    generate(_event2) startvar(rx_start) stopvar(rx_stop)
if _rc == 0 {
    // Should load interval data and create censored _event2 = 0
    capture confirm variable _event2
    if _rc == 0 {
        quietly sum _event2
        if r(max) == 0 {
            display as result "  PASSED - empty path: all _event2 = 0 (censored)"
            test_pass
        }
        else {
            display as error "  FAILED - expected all _event2=0, got max=" r(max)
            test_fail "edge-case assertion failed"
        }
    }
    else {
        display as error "  FAILED - _event2 not created in empty path"
        test_fail "edge-case assertion failed"
    }
}
else {
    display as error "  FAILED - tvevent empty path errored: _rc = `=_rc'"
    test_fail "edge-case assertion failed"
}

// =========================================================================
// TEST 4: tvmerge loads without error (capture cleanup)
// =========================================================================
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test 4: tvmerge program loads correctly}"

capture program drop tvmerge
capture noisily quietly run "../tvmerge.ado"
if _rc == 0 {
    display as result "  PASSED - tvmerge loads without error"
    test_pass
}
else {
    display as error "  FAILED - tvmerge load error: _rc = `=_rc'"
    test_fail "edge-case assertion failed"
}


// =========================================================================
// TEST 6: All programs load without syntax errors
// =========================================================================
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test 5: All tvtools programs load without error}"

local load_fails = 0
// Drop subprograms that would cause "already defined" on reload
foreach sub in _tvtools_detail _tvevent_empty_output ///
    _tvexpose_check _tvexpose_gaps _tvexpose_overlaps ///
    _tvexpose_summarize _tvexpose_validate {
    capture program drop `sub'
}
foreach cmd in tvtools tvexpose tvmerge tvevent tvdiagnose ///
    tvage tvweight {
    capture program drop `cmd'
    capture noisily quietly run "../`cmd'.ado"
    if _rc != 0 {
        local ++load_fails
    }
}
if `load_fails' == 0 {
    display as result "  PASSED - all tvtools programs load without error"
    test_pass
}
else {
    display as error "  FAILED - `load_fails' programs failed to load"
    test_fail "edge-case assertion failed"
}

}

capture noisily {

* CREATE SHARED TEST DATA
display "SETUP: Creating test datasets"

* Cohort dataset (20 persons, 2-year study)
clear
set obs 20
set seed 42
gen id = _n
gen study_entry = mdy(1,1,2020)
gen study_exit  = study_entry + 365 + int(runiform() * 365)
gen event_date  = study_entry + int(runiform() * (study_exit - study_entry)) if runiform() < 0.4
gen death_date  = study_entry + int(runiform() * (study_exit - study_entry)) if runiform() < 0.1
gen age = 40 + int(runiform() * 20)
gen sex = (runiform() > 0.5)
format study_entry study_exit event_date death_date %td
save "/tmp/sec_cohort.dta", replace

* Exposure dataset (multiple drugs per person)
* Use "start"/"stop" as variable names so tvexpose output uses these names too
clear
set obs 50
gen id = ceil(_n / 2.5)   // ~2.5 exposures per person, ids 1-20
replace id = min(id, 20)
gen start = mdy(1,1,2020) + int(runiform() * 400)
gen stop  = start + 30 + int(runiform() * 90)
gen drug_type = 1 + int(runiform() * 2)  // drug 1 or 2
gen dose_amt = 100 + int(runiform() * 100)
format start stop %td
save "/tmp/sec_exposure.dta", replace

* Create time-varying exposure dataset (using tvexpose)
* tvexpose renames output time vars to match the start()/stop() option names
* So using start(start)/stop(stop) preserves "start" and "stop" variable names
use "/tmp/sec_cohort.dta", clear
capture noisily tvexpose using "/tmp/sec_exposure.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug_type) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(tv_exp)
if _rc == 0 {
    save "/tmp/sec_tve.dta", replace
    display as result "  PASS [setup.tvexpose]: time-varying dataset created (`=_N' rows)"
}

}


* ===== Summary =====
* Fold the run_test/test_pass/test_fail harness counters into the totals.
local pass_count = `pass_count' + $TVQA_PASS
local fail_count = `fail_count' + $TVQA_FAIL
local failed_tests "`failed_tests' $TVQA_FAILED"
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA edge cases and stress Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: test_edge_cases tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"

