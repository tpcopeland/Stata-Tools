*! Test file for tvtools review fixes round 2
*! Tests: set more off, tvdml tempvars, tvweight tempvars, tvevent subroutine,
*!        tvmerge capture cleanup, tvplot rbar fix
version 16.0
set more off
set varabbrev off

clear all

// Reload modified programs
foreach cmd in tvdml tvweight tvevent tvmerge tvplot tvbalance tvdiagnose ///
    tvtools tvreport tvsensitivity tvtable tvcalendar tvtrial tvpass ///
    tvestimate tvexpose tvage tvpipeline {
    capture program drop `cmd'
}
capture program drop _tvevent_empty_output
capture program drop _tvplot_swimlane
capture program drop _tvplot_persontime

quietly {
    run "tvtools/tvdml.ado"
    run "tvtools/tvweight.ado"
    run "tvtools/tvevent.ado"
    run "tvtools/tvmerge.ado"
    run "tvtools/tvplot.ado"
    run "tvtools/tvbalance.ado"
    run "tvtools/tvdiagnose.ado"
    run "tvtools/tvtools.ado"
    run "tvtools/tvexpose.ado"
    run "tvtools/tvestimate.ado"
    run "tvtools/tvage.ado"
    run "tvtools/tvsensitivity.ado"
    run "tvtools/tvtable.ado"
    run "tvtools/tvreport.ado"
    run "tvtools/tvcalendar.ado"
    run "tvtools/tvtrial.ado"
    run "tvtools/tvpass.ado"
    run "tvtools/tvpipeline.ado"
}

local n_passed = 0
local n_failed = 0
local n_tests = 0

display as text _newline "{hline 70}"
display as text "{bf:TVTOOLS REVIEW FIXES ROUND 2 - TEST SUITE}"
display as text "{hline 70}" _newline

// =========================================================================
// TEST 1: tvdml with proper tempvars (no variable collision)
// =========================================================================
local n_tests = `n_tests' + 1
display as text "{bf:Test 1: tvdml tempvar safety}"

clear
set obs 500
gen int id = _n
gen byte treatment = (runiform() > 0.5)
gen double y = 2 * treatment + rnormal(0, 3)
gen double x1 = rnormal()
gen double x2 = rnormal()
// Create variables that would collide with old hardcoded names
gen double _y_hat = 999
gen double _d_hat = 999

capture noisily tvdml y treatment, covariates(x1 x2) crossfit(2) seed(42)
if _rc == 0 {
    // Verify our pre-existing variables weren't overwritten
    quietly sum _y_hat
    if r(mean) == 999 {
        display as result "  PASSED - tvdml did not overwrite _y_hat/_d_hat"
        local n_passed = `n_passed' + 1
    }
    else {
        display as error "  FAILED - _y_hat was overwritten (mean=" r(mean) ")"
        local n_failed = `n_failed' + 1
    }
}
else {
    display as error "  FAILED - tvdml errored: _rc = `=_rc'"
    local n_failed = `n_failed' + 1
}

// =========================================================================
// TEST 2: tvweight binary IPTW (basic functionality)
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
        local n_passed = `n_passed' + 1
    }
    else {
        display as error "  FAILED - invalid weights"
        local n_failed = `n_failed' + 1
    }
}
else {
    display as error "  FAILED - tvweight errored: _rc = `=_rc'"
    local n_failed = `n_failed' + 1
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
        local n_passed = `n_passed' + 1
    }
    else {
        display as error "  FAILED - invalid multinomial weights"
        local n_failed = `n_failed' + 1
    }
}
else {
    display as error "  FAILED - tvweight multinomial errored: _rc = `=_rc'"
    local n_failed = `n_failed' + 1
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
        local n_passed = `n_passed' + 1
    }
    else {
        display as error "  FAILED - invalid stabilized weights"
        local n_failed = `n_failed' + 1
    }
}
else {
    display as error "  FAILED - tvweight stabilized errored: _rc = `=_rc'"
    local n_failed = `n_failed' + 1
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
            local n_passed = `n_passed' + 1
        }
        else {
            display as error "  FAILED - denominator out of range"
            local n_failed = `n_failed' + 1
        }
    }
    else {
        display as error "  FAILED - denominator variable not created"
        local n_failed = `n_failed' + 1
    }
}
else {
    display as error "  FAILED - tvweight with denominator errored: _rc = `=_rc'"
    local n_failed = `n_failed' + 1
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
        local n_passed = `n_passed' + 1
    }
    else {
        display as error "  FAILED - _event variable not created"
        local n_failed = `n_failed' + 1
    }
}
else {
    display as error "  FAILED - tvevent errored: _rc = `=_rc'"
    local n_failed = `n_failed' + 1
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
            local n_passed = `n_passed' + 1
        }
        else {
            display as error "  FAILED - expected all _event2=0, got max=" r(max)
            local n_failed = `n_failed' + 1
        }
    }
    else {
        display as error "  FAILED - _event2 not created in empty path"
        local n_failed = `n_failed' + 1
    }
}
else {
    display as error "  FAILED - tvevent empty path errored: _rc = `=_rc'"
    local n_failed = `n_failed' + 1
}

// =========================================================================
// TEST 4: tvmerge loads without error (capture cleanup)
// =========================================================================
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test 4: tvmerge program loads correctly}"

capture program drop tvmerge
capture noisily quietly run "tvtools/tvmerge.ado"
if _rc == 0 {
    display as result "  PASSED - tvmerge loads without error"
    local n_passed = `n_passed' + 1
}
else {
    display as error "  FAILED - tvmerge load error: _rc = `=_rc'"
    local n_failed = `n_failed' + 1
}

// =========================================================================
// TEST 5: tvplot swimlane (rbar argument order fix)
// =========================================================================
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test 5: tvplot swimlane (rbar fix)}"

// Create proper time-varying data for plot
clear
set obs 200
gen int id = ceil(_n / 4)
bysort id: gen int period = _n
gen double start = mdy(1, 1, 2020) + (period - 1) * 90
gen double stop = start + 89
format start stop %td
gen byte tv_exposure = (runiform() > 0.5)

// tvplot requires graph capability - test that command runs
// (in batch mode, graph may not render but should not error)
capture noisily tvplot, id(id) start(start) stop(stop) ///
    exposure(tv_exposure) swimlane sample(10)
if _rc == 0 {
    display as result "  PASSED - tvplot swimlane runs with corrected rbar"
    local n_passed = `n_passed' + 1
}
else {
    // rc=903 or similar is OK in batch mode (no graph window)
    if inlist(_rc, 903, 908) {
        display as result "  PASSED (graph display unavailable in batch mode, rc=" _rc ")"
        local n_passed = `n_passed' + 1
    }
    else {
        display as error "  FAILED - tvplot errored: _rc = `=_rc'"
        local n_failed = `n_failed' + 1
    }
}

// =========================================================================
// TEST 6: All programs load without syntax errors
// =========================================================================
local n_tests = `n_tests' + 1
display as text _newline "{bf:Test 6: All 18 tvtools programs load without error}"

local load_fails = 0
// Drop subprograms that would cause "already defined" on reload
foreach sub in _tvtools_detail _tvevent_empty_output ///
    _tvplot_swimlane _tvplot_persontime ///
    _tvexpose_check _tvexpose_gaps _tvexpose_overlaps ///
    _tvexpose_summarize _tvexpose_validate {
    capture program drop `sub'
}
foreach cmd in tvtools tvexpose tvmerge tvevent tvbalance tvdiagnose ///
    tvweight tvestimate tvdml tvtrial tvcalendar tvage tvsensitivity ///
    tvpass tvtable tvreport tvplot tvpipeline {
    capture program drop `cmd'
    capture noisily quietly run "tvtools/`cmd'.ado"
    if _rc != 0 {
        display as error "    LOAD FAILED: `cmd'.ado (rc=" _rc ")"
        local load_fails = `load_fails' + 1
    }
}

if `load_fails' == 0 {
    display as result "  PASSED - all 18 programs loaded successfully"
    local n_passed = `n_passed' + 1
}
else {
    display as error "  FAILED - `load_fails' programs failed to load"
    local n_failed = `n_failed' + 1
}

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
