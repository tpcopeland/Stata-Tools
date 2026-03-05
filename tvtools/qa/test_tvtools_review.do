/*
    Test file: test_tvtools_review.do
    Purpose: Validate all modified tvtools commands after code review fixes
    Date: 2026-02-23
*/

clear all
set more off
version 16.0
set varabbrev off

* Track test results
local n_pass = 0
local n_fail = 0
local failures ""

capture log close _test
log using "../../_devkit/_testing/test_tvtools_review.log", replace nomsg name(_test)

display as text _dup(70) "="
display as result "tvtools Review Fix Validation Tests"
display as text _dup(70) "="
display as text ""

* =========================================================================
* SETUP: Create test data
* =========================================================================

display as text "{bf:SETUP: Creating test datasets}"
display as text _dup(40) "-"

* Cohort data (100 people)
clear
set seed 12345
set obs 100
gen int id = _n
gen double study_entry = td(01jan2020) + floor(runiform() * 365)
gen double study_exit = study_entry + 365 + floor(runiform() * 730)
format %td study_entry study_exit
gen double age = 40 + floor(runiform() * 40)
gen byte sex = runiform() > 0.5
gen byte comorbidity = runiform() > 0.7
gen double outcome_date = study_entry + floor(runiform() * (study_exit - study_entry)) if runiform() > 0.85
format %td outcome_date

tempfile cohort_data
save `cohort_data', replace

display as text "  Cohort: 100 individuals created"

* Exposure data (prescriptions for ~60 people)
clear
set obs 200
gen int id = ceil(runiform() * 60)
gen double rx_start = td(01jan2020) + floor(runiform() * 500)
gen double rx_stop = rx_start + 30 + floor(runiform() * 150)
format %td rx_start rx_stop
gen byte drug = (runiform() > 0.5)
gen double dose = round(10 + runiform() * 90, 5)

tempfile exposure_data
save `exposure_data', replace

display as text "  Exposure: 200 records created"

* Calendar data (quarterly periods)
clear
set obs 8
gen double cal_start = td(01jan2020) + (_n - 1) * 91
gen double cal_stop = cal_start + 90
format %td cal_start cal_stop
gen byte season = mod(_n - 1, 4) + 1
gen double policy_index = 1 + (_n - 1) * 0.1

tempfile calendar_data
save `calendar_data', replace

display as text "  Calendar: 8 quarterly periods created"
display as text ""

* =========================================================================
* TEST 1: tvtools (main command)
* =========================================================================

display as text _dup(70) "="
display as text "{bf:TEST 1: tvtools}"
display as text _dup(70) "="

capture {
    cap program drop tvtools
    cap program drop _tvtools_detail
    run tvtools/tvtools.ado

    tvtools
    assert r(n_commands) == 11
    assert "`r(version)'" == "1.5.0"

    tvtools, list category(prep)
    assert r(n_commands) == 5

    tvtools, detail category(diag)
    assert r(n_commands) == 3
}
if _rc == 0 {
    display as result "  PASS: tvtools command"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvtools command (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvtools"
}

* =========================================================================
* TEST 2: tvbalance (with if/in, marksample)
* =========================================================================

display as text _dup(70) "="
display as text "{bf:TEST 2: tvbalance}"
display as text _dup(70) "="

* Create balance test data
clear
set obs 500
gen int id = _n
gen byte exposure = (runiform() > 0.5)
gen double age = 50 + (exposure * 5) + rnormal(0, 10)
gen double bmi = 25 + (exposure * 2) + rnormal(0, 3)
gen byte female = runiform() > (0.5 + exposure * 0.1)
gen double iptw = 1 + runiform()
gen byte subset = (_n <= 300)

cap program drop tvbalance
run tvtools/tvbalance.ado

* Test 2a: Basic usage
capture {
    tvbalance age bmi female, exposure(exposure)
    assert r(n_covariates) == 3
    assert r(n_ref) > 0
    assert r(n_exp) > 0
    matrix B = r(balance)
    assert rowsof(B) == 3
    assert colsof(B) == 4
}
if _rc == 0 {
    display as result "  PASS: tvbalance basic"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvbalance basic (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvbalance_basic"
}

* Test 2b: With if condition
capture {
    tvbalance age bmi if subset == 1, exposure(exposure)
    assert r(n_ref) + r(n_exp) <= 300
}
if _rc == 0 {
    display as result "  PASS: tvbalance with if"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvbalance with if (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvbalance_if"
}

* Test 2c: With in range
capture {
    tvbalance age bmi in 1/200, exposure(exposure)
    assert r(n_ref) + r(n_exp) <= 200
}
if _rc == 0 {
    display as result "  PASS: tvbalance with in"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvbalance with in (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvbalance_in"
}

* Test 2d: With weights
capture {
    tvbalance age bmi female, exposure(exposure) weights(iptw)
    assert r(n_imbalanced_wt) >= 0
    assert r(ess_ref) > 0
}
if _rc == 0 {
    display as result "  PASS: tvbalance with weights"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvbalance with weights (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvbalance_weights"
}

* Test 2e: No observations error
capture noisily tvbalance age bmi if exposure > 5, exposure(exposure)
if _rc == 2000 {
    display as result "  PASS: tvbalance no-obs error"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvbalance should error 2000 for no obs (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvbalance_noobs"
}

* =========================================================================
* TEST 3: tvdiagnose (preserve/restore, tempvars)
* =========================================================================

display as text _dup(70) "="
display as text "{bf:TEST 3: tvdiagnose}"
display as text _dup(70) "="

* Create interval data
clear
set obs 300
gen int id = ceil(_n / 3)
bysort id: gen int period = _n
gen double start = td(01jan2020) + (period - 1) * 90
gen double stop = start + 85
format %td start stop
gen byte exposure = (runiform() > 0.5)
gen double entry = td(01jan2020)
gen double exit = td(31dec2021)
format %td entry exit

* Add some gaps (for a few IDs, shift the second period start)
replace start = start + 10 if id <= 10 & period == 2

local n_before = _N
local vars_before : char _dta[__obs]

cap program drop tvdiagnose
run tvtools/tvdiagnose.ado

* Test 3a: Coverage
capture {
    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit) coverage
    assert r(n_persons) == 100
    assert r(n_observations) == 300
    assert r(mean_coverage) > 0
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose coverage"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvdiagnose coverage (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvdiagnose_coverage"
}

* Verify data is restored (preserve/restore working)
capture {
    assert _N == `n_before'
    confirm variable id start stop exposure entry exit
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose data preserved after coverage"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvdiagnose data NOT preserved (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvdiagnose_preserve_coverage"
}

* Test 3b: Gaps
capture {
    tvdiagnose, id(id) start(start) stop(stop) gaps
    assert r(n_gaps) >= 0
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose gaps"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvdiagnose gaps (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvdiagnose_gaps"
}

* Verify restore after gaps
capture {
    assert _N == `n_before'
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose data preserved after gaps"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvdiagnose data NOT preserved after gaps (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvdiagnose_preserve_gaps"
}

* Test 3c: Overlaps
capture {
    tvdiagnose, id(id) start(start) stop(stop) overlaps
    assert r(n_overlaps) >= 0
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose overlaps"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvdiagnose overlaps (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvdiagnose_overlaps"
}

* Test 3d: Summarize
capture {
    tvdiagnose, id(id) start(start) stop(stop) exposure(exposure) summarize
    assert r(total_person_time) > 0
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose summarize"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvdiagnose summarize (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvdiagnose_summarize"
}

* Test 3e: All diagnostics
capture {
    tvdiagnose, id(id) start(start) stop(stop) exposure(exposure) entry(entry) exit(exit) all
    assert r(n_persons) == 100
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose all"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvdiagnose all (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvdiagnose_all"
}

* Final preservation check
capture {
    assert _N == `n_before'
    confirm variable id start stop exposure entry exit
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose full preservation after all"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvdiagnose data NOT preserved after all (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvdiagnose_preserve_all"
}

* =========================================================================
* TEST 4: tvcalendar (range merge, tempvar fix)
* =========================================================================

display as text _dup(70) "="
display as text "{bf:TEST 7: tvcalendar}"
display as text _dup(70) "="

* Create master data with dates
clear
set obs 200
gen int id = _n
gen double date = td(01jan2020) + floor(runiform() * 700)
format %td date
gen double value = rnormal(100, 15)

cap program drop tvcalendar
run tvtools/tvcalendar.ado

* Test 7a: Range merge
capture {
    tvcalendar using `calendar_data', datevar(date) startvar(cal_start) stopvar(cal_stop)
    assert r(n_master) == 200
    confirm variable season
    confirm variable policy_index
}
if _rc == 0 {
    display as result "  PASS: tvcalendar range merge"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvcalendar range merge (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvcalendar_range"
}

* Test 7b: Verify no hardcoded variable names leaked
capture {
    confirm variable __match_seq
    local has_hardcoded = 1
}
if _rc != 0 {
    display as result "  PASS: tvcalendar no hardcoded vars"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvcalendar leaked __match_seq variable"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvcalendar_hardcoded"
}

* =========================================================================
* TEST 8: tvtrial (tempvar drop, linear append)
* =========================================================================

display as text _dup(70) "="
display as text "{bf:TEST 8: tvtrial}"
display as text _dup(70) "="

use `cohort_data', clear

cap program drop tvtrial
run tvtools/tvtrial.ado

* Test 8a: Basic target trial (no cloning)
capture {
    tvtrial, id(id) entry(study_entry) exit(study_exit) ///
        treatstart(outcome_date) trials(6) trialinterval(60)
    assert r(n_orig) == 100
    assert r(n_trials) > 0
    assert r(n_treat) >= 0
    assert r(n_control) >= 0
    confirm variable trial_trial
    confirm variable trial_arm
    confirm variable trial_fu_time
}
if _rc == 0 {
    display as result "  PASS: tvtrial basic"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvtrial basic (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvtrial_basic"
}

* Test 8b: With cloning
use `cohort_data', clear
capture {
    tvtrial, id(id) entry(study_entry) exit(study_exit) ///
        treatstart(outcome_date) trials(4) trialinterval(90) clone
    assert r(n_persontrials) > 0
    assert r(n_treat) > 0
    assert r(n_control) > 0
}
if _rc == 0 {
    display as result "  PASS: tvtrial with clone"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvtrial with clone (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvtrial_clone"
}

* Test 8c: With clone + IPC weights
use `cohort_data', clear
capture {
    tvtrial, id(id) entry(study_entry) exit(study_exit) ///
        treatstart(outcome_date) trials(4) trialinterval(90) clone ipcweight
    confirm variable trial_ipcw
}
if _rc == 0 {
    display as result "  PASS: tvtrial with clone+ipcweight"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvtrial clone+ipcweight (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvtrial_ipcw"
}

* =========================================================================
* TEST 9: tvplot (tempvar fix - verify no __ vars)
* =========================================================================

display as text _dup(70) "="
display as text "{bf:TEST 9: tvplot (tempvar verification)}"
display as text _dup(70) "="

* Create plot test data
clear
set obs 300
gen int id = ceil(_n / 3)
bysort id: gen int period = _n
gen double start = td(01jan2020) + (period - 1) * 90
gen double stop = start + 85
format %td start stop
gen byte tv_exposure = (runiform() > 0.5)
local n_before_plot = _N

cap program drop tvplot
cap program drop _tvplot_swimlane
cap program drop _tvplot_persontime
run tvtools/tvplot.ado

* Test 9a: Swimlane plot (verify no __ vars leak to data)
capture {
    set graphics off
    tvplot, id(id) start(start) stop(stop) exposure(tv_exposure) swimlane sample(10)
    set graphics on
}
if _rc == 0 {
    display as result "  PASS: tvplot swimlane runs"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvplot swimlane (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvplot_swimlane"
    capture set graphics on
}

* Test 9b: Data preserved after plot
capture {
    assert _N == `n_before_plot'
    confirm variable id start stop tv_exposure
}
if _rc == 0 {
    display as result "  PASS: tvplot data preserved"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvplot data NOT preserved (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvplot_preserve"
}

* Test 9c: Verify no __ hardcoded vars in dataset
local leaked_vars ""
foreach v in __sortval __first __ypos __ypos_upper __exp_num __days __person_days __person_years {
    capture confirm variable `v'
    if _rc == 0 {
        local leaked_vars "`leaked_vars' `v'"
    }
}
if "`leaked_vars'" == "" {
    display as result "  PASS: tvplot no hardcoded vars leaked"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvplot leaked vars:`leaked_vars'"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvplot_leakedvars"
}

* Test 9d: Persontime plot
capture {
    set graphics off
    tvplot, id(id) start(start) stop(stop) exposure(tv_exposure) persontime
    set graphics on
}
if _rc == 0 {
    display as result "  PASS: tvplot persontime runs"
    local n_pass = `n_pass' + 1
}
else {
    display as error "  FAIL: tvplot persontime (rc=`=_rc')"
    local n_fail = `n_fail' + 1
    local failures "`failures' tvplot_persontime"
    capture set graphics on
}

* =========================================================================
* SUMMARY
* =========================================================================

display as text ""
display as text _dup(70) "="
display as result "TEST SUMMARY"
display as text _dup(70) "="
display as text ""
display as result "  Passed: `n_pass'"
if `n_fail' > 0 {
    display as error "  Failed: `n_fail'"
    display as error "  Failures: `failures'"
}
else {
    display as text "  Failed: 0"
}
display as text ""
display as text "  Total:  " as result `=`n_pass' + `n_fail''
display as text ""

if `n_fail' == 0 {
    display as result "ALL TESTS PASSED"
}
else {
    display as error "`n_fail' TESTS FAILED"
}

display as text _dup(70) "="

log close _test
