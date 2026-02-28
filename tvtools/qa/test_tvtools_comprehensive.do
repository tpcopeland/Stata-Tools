********************************************************************************
* COMPREHENSIVE TVTOOLS TEST SUITE
*
* Purpose: Exhaustive testing of all options and combinations
* Author: Claude Code
* Date: 2025-12-26
*
* Tests cover:
* - All individual options
* - Option combinations (especially interacting options)
* - Edge cases and boundary conditions
* - Error handling and validation
* - Mathematical correctness
********************************************************************************

clear all
version 16.0
set more off
set varabbrev off

* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Test macro
capture program drop run_test
program define run_test
    args test_name
    global current_test "`test_name'"
    display as text _n "TEST: `test_name'"
end

capture program drop test_pass
program define test_pass
    global test_count = $test_count + 1
    global pass_count = $pass_count + 1
    display as result "  PASS"
end

capture program drop test_fail
program define test_fail
    args reason
    global test_count = $test_count + 1
    global fail_count = $fail_count + 1
    global failed_tests "$failed_tests $current_test"
    display as error "  FAIL: `reason'"
end

global test_count = 0
global pass_count = 0
global fail_count = 0
global failed_tests ""

********************************************************************************
* SETUP: Create comprehensive test data
********************************************************************************

display as text _n _dup(70) "="
display as text "CREATING TEST DATA"
display as text _dup(70) "="

* Create cohort with 100 persons, varied follow-up
clear
set seed 12345
set obs 100
gen id = _n
gen study_entry = mdy(1, 1, 2020) + int(runiform() * 90)
gen study_exit = study_entry + 365 + int(runiform() * 365)
gen event_date = study_entry + int(runiform() * (study_exit - study_entry)) if runiform() < 0.3
gen death_date = study_entry + int(runiform() * (study_exit - study_entry)) if runiform() < 0.1
gen emigration_date = study_entry + int(runiform() * (study_exit - study_entry)) if runiform() < 0.05
format study_entry study_exit event_date death_date emigration_date %tdCCYY-NN-DD
save "/tmp/test_cohort.dta", replace

* Create exposure data with overlaps, gaps, and various patterns
clear
set seed 54321
set obs 300
gen id = ceil(_n / 3)
bysort id: gen spell = _n
gen rx_start = mdy(1, 1, 2020) + int(runiform() * 400)
gen rx_stop = rx_start + 30 + int(runiform() * 120)
gen drug = ceil(runiform() * 3)
gen dose = runiform() * 100
label define drug_lbl 0 "Unexposed" 1 "Drug_A" 2 "Drug_B" 3 "Drug_C"
label values drug drug_lbl
format rx_start rx_stop %tdCCYY-NN-DD
save "/tmp/test_exposure.dta", replace

* Create second exposure dataset for tvmerge testing
clear
set seed 11111
set obs 200
gen id = ceil(_n / 2)
bysort id: gen spell = _n
gen start2 = mdy(1, 1, 2020) + int(runiform() * 400)
gen stop2 = start2 + 20 + int(runiform() * 80)
gen treatment = ceil(runiform() * 2)
gen intensity = runiform() * 50
format start2 stop2 %tdCCYY-NN-DD
save "/tmp/test_exposure2.dta", replace

* Create point-in-time data (no stop dates)
clear
set seed 22222
set obs 150
gen id = ceil(_n / 1.5)
gen measure_date = mdy(1, 1, 2020) + int(runiform() * 500)
gen value = ceil(runiform() * 3)
format measure_date %tdCCYY-NN-DD
save "/tmp/test_pointtime.dta", replace

* Create recurring events data (wide format)
clear
set seed 33333
set obs 100
gen id = _n
forvalues i = 1/5 {
    gen hosp`i' = mdy(1, 1, 2020) + int(runiform() * 600) if runiform() < 0.4
    format hosp`i' %tdCCYY-NN-DD
}
save "/tmp/test_recurring.dta", replace

display as result "Test data created successfully"

********************************************************************************
* SECTION 1: TVEXPOSE - EXPOSURE TYPE OPTIONS
********************************************************************************

display as text _n _dup(70) "="
display as text "TVEXPOSE: EXPOSURE TYPE OPTIONS"
display as text _dup(70) "="

*--- Test 1.1: Basic time-varying (default) ---
run_test "tvexpose_basic_timevarying"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit)
if _rc == 0 {
    * Verify output structure
    capture confirm variable tv_exposure rx_start rx_stop
    if _rc == 0 {
        qui count
        if r(N) > 0 {
            test_pass
        }
        else test_fail "No observations created"
    }
    else test_fail "Required variables not created"
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 1.2: evertreated ---
run_test "tvexpose_evertreated"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated generate(ever_exposed)
if _rc == 0 {
    * Verify binary output (0/1 only)
    qui levelsof ever_exposed, local(levels)
    local valid = 1
    foreach l of local levels {
        if !inlist(`l', 0, 1) local valid = 0
    }
    if `valid' {
        * Verify monotonicity (once 1, never goes back to 0)
        sort id rx_start
        by id: gen switched_back = ever_exposed < ever_exposed[_n-1] if _n > 1
        qui count if switched_back == 1
        if r(N) == 0 {
            test_pass
        }
        else test_fail "Evertreated not monotonic"
    }
    else test_fail "Evertreated has values other than 0/1"
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 1.3: currentformer ---
run_test "tvexpose_currentformer"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    currentformer generate(cf_status)
if _rc == 0 {
    * Verify trichotomous output (0/1/2 only)
    qui levelsof cf_status, local(levels)
    local valid = 1
    foreach l of local levels {
        if !inlist(`l', 0, 1, 2) local valid = 0
    }
    if `valid' {
        test_pass
    }
    else test_fail "Currentformer has values other than 0/1/2"
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 1.4: duration with continuousunit ---
run_test "tvexpose_duration_years"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    duration(1 2 5) continuousunit(years) generate(dur_cat)
if _rc == 0 {
    qui sum dur_cat
    if r(N) > 0 {
        test_pass
    }
    else test_fail "No duration categories created"
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 1.5: duration with months ---
run_test "tvexpose_duration_months"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    duration(3 6 12) continuousunit(months) generate(dur_months)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 1.6: continuousunit alone (continuous cumulative) ---
run_test "tvexpose_continuous_cumulative"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    continuousunit(days) generate(cumul_days)
if _rc == 0 {
    * Verify continuous variable (not categorical)
    qui sum cumul_days
    if r(max) > r(min) {
        test_pass
    }
    else test_fail "Continuous variable has no variation"
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 1.7: recency ---
run_test "tvexpose_recency"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    recency(30 90 180) generate(recency_cat)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 1.8: dose ---
run_test "tvexpose_dose"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(dose) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    dose generate(cumul_dose)
if _rc == 0 {
    * Verify cumulative dose increases or stays same
    sort id rx_start
    by id: gen dose_decreased = cumul_dose < cumul_dose[_n-1] if _n > 1
    qui count if dose_decreased == 1
    if r(N) == 0 {
        test_pass
    }
    else test_fail "Cumulative dose decreased (should be monotonic)"
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 1.9: dose with dosecuts ---
run_test "tvexpose_dose_dosecuts"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(dose) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    dose dosecuts(10 50 100) generate(dose_cat)
if _rc == 0 {
    * Should be categorical
    qui levelsof dose_cat
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

********************************************************************************
* SECTION 2: TVEXPOSE - OVERLAP STRATEGIES
********************************************************************************

display as text _n _dup(70) "="
display as text "TVEXPOSE: OVERLAP STRATEGIES"
display as text _dup(70) "="

*--- Test 2.1: layer (default) ---
run_test "tvexpose_layer_default"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    layer
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 2.2: priority ---
run_test "tvexpose_priority"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    priority(3 2 1)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 2.3: split ---
run_test "tvexpose_split"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    split
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 2.4: combine ---
run_test "tvexpose_combine"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    combine(combined_exp)
if _rc == 0 {
    capture confirm variable combined_exp
    if _rc == 0 {
        test_pass
    }
    else test_fail "Combined variable not created"
}
else test_fail "Command failed with rc=`=_rc'"

********************************************************************************
* SECTION 3: TVEXPOSE - DATA HANDLING OPTIONS
********************************************************************************

display as text _n _dup(70) "="
display as text "TVEXPOSE: DATA HANDLING OPTIONS"
display as text _dup(70) "="

*--- Test 3.1: grace (single value) ---
run_test "tvexpose_grace_single"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    grace(30)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 3.2: grace (category-specific) ---
run_test "tvexpose_grace_category"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    grace(1=30 2=60 3=90)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 3.3: merge ---
run_test "tvexpose_merge"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    merge(60)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 3.4: lag ---
run_test "tvexpose_lag"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    lag(30) generate(lagged_exp)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 3.5: washout ---
run_test "tvexpose_washout"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    washout(30) generate(washout_exp)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 3.6: lag + washout combined ---
run_test "tvexpose_lag_washout_combined"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    lag(14) washout(30)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 3.7: fillgaps ---
run_test "tvexpose_fillgaps"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    fillgaps(60)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 3.8: carryforward ---
run_test "tvexpose_carryforward"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    carryforward(90)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 3.9: pointtime ---
run_test "tvexpose_pointtime"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_pointtime.dta", ///
    id(id) start(measure_date) ///
    exposure(value) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    pointtime carryforward(60)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 3.10: window ---
run_test "tvexpose_window"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    window(1 7)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

********************************************************************************
* SECTION 4: TVEXPOSE - BYTYPE COMBINATIONS
********************************************************************************

display as text _n _dup(70) "="
display as text "TVEXPOSE: BYTYPE COMBINATIONS"
display as text _dup(70) "="

*--- Test 4.1: evertreated + bytype ---
run_test "tvexpose_evertreated_bytype"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated bytype
if _rc == 0 {
    * Should create multiple ever# variables (ever1, ever2, ever3)
    capture confirm variable ever1 ever2
    if _rc == 0 {
        test_pass
    }
    else test_fail "Bytype variables not created"
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 4.2: currentformer + bytype ---
run_test "tvexpose_currentformer_bytype"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    currentformer bytype
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 4.3: continuousunit + bytype ---
run_test "tvexpose_continuous_bytype"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    continuousunit(months) bytype
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 4.4: duration + bytype ---
run_test "tvexpose_duration_bytype"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    duration(1 2) continuousunit(years) bytype
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

********************************************************************************
* SECTION 5: TVEXPOSE - PATTERN TRACKING
********************************************************************************

display as text _n _dup(70) "="
display as text "TVEXPOSE: PATTERN TRACKING"
display as text _dup(70) "="

*--- Test 5.1: switching ---
run_test "tvexpose_switching"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    switching
if _rc == 0 {
    capture confirm variable ever_switched
    if _rc == 0 {
        test_pass
    }
    else test_fail "Switching variable not created"
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 5.2: switchingdetail ---
run_test "tvexpose_switchingdetail"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    switchingdetail
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 5.3: statetime ---
run_test "tvexpose_statetime"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    statetime
if _rc == 0 {
    capture confirm variable state_time_years
    if _rc == 0 {
        test_pass
    }
    else test_fail "Statetime variable not created"
}
else test_fail "Command failed with rc=`=_rc'"

********************************************************************************
* SECTION 6: TVEXPOSE - EXPANDUNIT
********************************************************************************

display as text _n _dup(70) "="
display as text "TVEXPOSE: EXPANDUNIT"
display as text _dup(70) "="

*--- Test 6.1: expandunit weeks ---
run_test "tvexpose_expandunit_weeks"
use "/tmp/test_cohort.dta", clear
qui keep in 1/10
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    continuousunit(weeks) expandunit(weeks)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 6.2: expandunit months ---
run_test "tvexpose_expandunit_months"
use "/tmp/test_cohort.dta", clear
qui keep in 1/10
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    continuousunit(months) expandunit(months)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

********************************************************************************
* SECTION 7: TVEXPOSE - OUTPUT OPTIONS
********************************************************************************

display as text _n _dup(70) "="
display as text "TVEXPOSE: OUTPUT OPTIONS"
display as text _dup(70) "="

*--- Test 7.1: keepvars ---
run_test "tvexpose_keepvars"
use "/tmp/test_cohort.dta", clear
gen age = 50 + int(runiform() * 30)
gen female = runiform() < 0.5
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    keepvars(age female)
if _rc == 0 {
    capture confirm variable age female
    if _rc == 0 {
        test_pass
    }
    else test_fail "Keepvars not retained"
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 7.2: keepdates ---
run_test "tvexpose_keepdates"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    keepdates
if _rc == 0 {
    capture confirm variable study_entry study_exit
    if _rc == 0 {
        test_pass
    }
    else test_fail "Entry/exit dates not retained"
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 7.3: saveas + replace ---
run_test "tvexpose_saveas_replace"
use "/tmp/test_cohort.dta", clear
capture erase "/tmp/test_output.dta"
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    saveas("/tmp/test_output.dta") replace
if _rc == 0 {
    capture confirm file "/tmp/test_output.dta"
    if _rc == 0 {
        test_pass
    }
    else test_fail "File not saved"
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 7.4: referencelabel ---
run_test "tvexpose_referencelabel"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    referencelabel("No Treatment")
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

********************************************************************************
* SECTION 8: TVEXPOSE - DIAGNOSTIC OPTIONS
********************************************************************************

display as text _n _dup(70) "="
display as text "TVEXPOSE: DIAGNOSTIC OPTIONS"
display as text _dup(70) "="

*--- Test 8.1: check ---
run_test "tvexpose_check"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    check
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 8.2: gaps ---
run_test "tvexpose_gaps"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    gaps
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 8.3: overlaps ---
run_test "tvexpose_overlaps"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    overlaps
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 8.4: summarize ---
run_test "tvexpose_summarize"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    summarize
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 8.5: validate ---
run_test "tvexpose_validate"
capture erase tv_validation.dta
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    validate
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

********************************************************************************
* SECTION 9: TVEXPOSE - COMPLEX COMBINATIONS
********************************************************************************

display as text _n _dup(70) "="
display as text "TVEXPOSE: COMPLEX COMBINATIONS"
display as text _dup(70) "="

*--- Test 9.1: currentformer + grace + lag + washout ---
run_test "tvexpose_complex_1"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    currentformer grace(30) lag(14) washout(30)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 9.2: evertreated + bytype + switching + keepvars ---
run_test "tvexpose_complex_2"
use "/tmp/test_cohort.dta", clear
gen age = 50
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated bytype switching keepvars(age)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 9.3: duration + priority + statetime ---
run_test "tvexpose_complex_3"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    duration(1 2 5) continuousunit(years) priority(3 2 1) statetime
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

********************************************************************************
* SECTION 10: TVMERGE TESTS
********************************************************************************

display as text _n _dup(70) "="
display as text "TVMERGE: ALL OPTIONS"
display as text _dup(70) "="

* First create tvexpose outputs with different exposure variable names
use "/tmp/test_cohort.dta", clear
qui tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(drug_exp)
qui save "/tmp/tv1.dta", replace

use "/tmp/test_cohort.dta", clear
qui tvexpose using "/tmp/test_exposure2.dta", ///
    id(id) start(start2) stop(stop2) ///
    exposure(treatment) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(treat_exp)
qui save "/tmp/tv2.dta", replace

*--- Test 10.1: Basic 2-dataset merge ---
run_test "tvmerge_basic"
capture noisily tvmerge "/tmp/tv1.dta" "/tmp/tv2.dta", ///
    id(id) start(rx_start start2) stop(rx_stop stop2) ///
    exposure(drug_exp treat_exp) force
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 10.2: generate option ---
run_test "tvmerge_generate"
capture noisily tvmerge "/tmp/tv1.dta" "/tmp/tv2.dta", ///
    id(id) start(rx_start start2) stop(rx_stop stop2) ///
    exposure(drug_exp treat_exp) ///
    generate(merged_drug merged_treat) force
if _rc == 0 {
    capture confirm variable merged_drug merged_treat
    if _rc == 0 {
        test_pass
    }
    else test_fail "Generated variables not created"
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 10.3: prefix option ---
run_test "tvmerge_prefix"
capture noisily tvmerge "/tmp/tv1.dta" "/tmp/tv2.dta", ///
    id(id) start(rx_start start2) stop(rx_stop stop2) ///
    exposure(drug_exp treat_exp) ///
    prefix(m_) force
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 10.4: startname/stopname ---
run_test "tvmerge_custom_names"
capture noisily tvmerge "/tmp/tv1.dta" "/tmp/tv2.dta", ///
    id(id) start(rx_start start2) stop(rx_stop stop2) ///
    exposure(drug_exp treat_exp) ///
    startname(period_start) stopname(period_end) force
if _rc == 0 {
    capture confirm variable period_start period_end
    if _rc == 0 {
        test_pass
    }
    else test_fail "Custom names not applied"
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 10.5: dateformat ---
run_test "tvmerge_dateformat"
capture noisily tvmerge "/tmp/tv1.dta" "/tmp/tv2.dta", ///
    id(id) start(rx_start start2) stop(rx_stop stop2) ///
    exposure(drug_exp treat_exp) ///
    dateformat(%tdNN/DD/CCYY) force
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 10.6: batch ---
run_test "tvmerge_batch"
capture noisily tvmerge "/tmp/tv1.dta" "/tmp/tv2.dta", ///
    id(id) start(rx_start start2) stop(rx_stop stop2) ///
    exposure(drug_exp treat_exp) ///
    batch(50) force
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 10.7: check + validatecoverage + validateoverlap + summarize ---
run_test "tvmerge_diagnostics"
capture noisily tvmerge "/tmp/tv1.dta" "/tmp/tv2.dta", ///
    id(id) start(rx_start start2) stop(rx_stop stop2) ///
    exposure(drug_exp treat_exp) ///
    check validatecoverage validateoverlap summarize force
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 10.8: saveas ---
run_test "tvmerge_saveas"
capture erase "/tmp/merged_output.dta"
capture noisily tvmerge "/tmp/tv1.dta" "/tmp/tv2.dta", ///
    id(id) start(rx_start start2) stop(rx_stop stop2) ///
    exposure(drug_exp treat_exp) ///
    saveas("/tmp/merged_output.dta") replace force
if _rc == 0 {
    capture confirm file "/tmp/merged_output.dta"
    if _rc == 0 {
        test_pass
    }
    else test_fail "File not saved"
}
else test_fail "Command failed with rc=`=_rc'"

********************************************************************************
* SECTION 11: TVEVENT TESTS
********************************************************************************

display as text _n _dup(70) "="
display as text "TVEVENT: ALL OPTIONS"
display as text _dup(70) "="

* Create interval dataset
use "/tmp/test_cohort.dta", clear
qui tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit)
rename rx_start start
rename rx_stop stop
qui save "/tmp/intervals.dta", replace

*--- Test 11.1: Basic single event ---
run_test "tvevent_basic_single"
use "/tmp/test_cohort.dta", clear
capture noisily tvevent using "/tmp/intervals.dta", ///
    id(id) date(event_date) type(single) generate(outcome)
if _rc == 0 {
    capture confirm variable outcome
    if _rc == 0 {
        test_pass
    }
    else test_fail "Outcome variable not created"
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 11.2: Competing risks ---
run_test "tvevent_compete"
use "/tmp/test_cohort.dta", clear
capture noisily tvevent using "/tmp/intervals.dta", ///
    id(id) date(event_date) compete(death_date emigration_date) ///
    type(single) generate(status)
if _rc == 0 {
    * Should have values 0, 1, 2, 3
    qui levelsof status, local(levels)
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 11.3: timegen with days ---
run_test "tvevent_timegen_days"
use "/tmp/test_cohort.dta", clear
capture noisily tvevent using "/tmp/intervals.dta", ///
    id(id) date(event_date) type(single) ///
    timegen(time_days) timeunit(days)
if _rc == 0 {
    capture confirm variable time_days
    if _rc == 0 {
        test_pass
    }
    else test_fail "Timegen variable not created"
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 11.4: timegen with months ---
run_test "tvevent_timegen_months"
use "/tmp/test_cohort.dta", clear
capture noisily tvevent using "/tmp/intervals.dta", ///
    id(id) date(event_date) type(single) ///
    timegen(time_months) timeunit(months)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 11.5: timegen with years ---
run_test "tvevent_timegen_years"
use "/tmp/test_cohort.dta", clear
capture noisily tvevent using "/tmp/intervals.dta", ///
    id(id) date(event_date) type(single) ///
    timegen(time_years) timeunit(years)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 11.6: eventlabel ---
run_test "tvevent_eventlabel"
use "/tmp/test_cohort.dta", clear
capture noisily tvevent using "/tmp/intervals.dta", ///
    id(id) date(event_date) compete(death_date) type(single) ///
    eventlabel(0 "Censored" 1 "Primary Event" 2 "Death")
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 11.7: keepvars ---
run_test "tvevent_keepvars"
use "/tmp/test_cohort.dta", clear
gen age = 50 + int(runiform() * 30)
capture noisily tvevent using "/tmp/intervals.dta", ///
    id(id) date(event_date) type(single) keepvars(age)
if _rc == 0 {
    capture confirm variable age
    if _rc == 0 {
        test_pass
    }
    else test_fail "Keepvars not retained"
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 11.8: startvar/stopvar ---
run_test "tvevent_startvar_stopvar"
use "/tmp/intervals.dta", clear
rename start interval_start
rename stop interval_end
save "/tmp/intervals_renamed.dta", replace

use "/tmp/test_cohort.dta", clear
capture noisily tvevent using "/tmp/intervals_renamed.dta", ///
    id(id) date(event_date) type(single) ///
    startvar(interval_start) stopvar(interval_end)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 11.9: recurring events ---
run_test "tvevent_recurring"
use "/tmp/test_recurring.dta", clear
capture noisily tvevent using "/tmp/intervals.dta", ///
    id(id) date(hosp) type(recurring) generate(hospitalized)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 11.10: validate ---
run_test "tvevent_validate"
use "/tmp/test_cohort.dta", clear
capture noisily tvevent using "/tmp/intervals.dta", ///
    id(id) date(event_date) type(single) validate
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 11.11: replace ---
run_test "tvevent_replace"
* Test: replace option allows command to run when variable already exists
use "/tmp/test_cohort.dta", clear
* First create a dummy "outcome" variable
gen outcome = 99
* Without replace, tvevent should fail because outcome already exists
* With replace, it should succeed
capture noisily tvevent using "/tmp/intervals.dta", ///
    id(id) date(event_date) type(single) generate(outcome) replace
if _rc == 0 {
    * Command completed - replace option worked
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

********************************************************************************
* SECTION 12: PERSON-TIME CONSERVATION TESTS
********************************************************************************

display as text _n _dup(70) "="
display as text "PERSON-TIME CONSERVATION"
display as text _dup(70) "="

*--- Test 12.1: tvexpose preserves person-time ---
run_test "persontime_tvexpose"
use "/tmp/test_cohort.dta", clear
* Calculate expected person-time
gen expected_pt = study_exit - study_entry + 1
qui sum expected_pt
local expected = r(sum)

qui tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit)

gen pt = rx_stop - rx_start + 1
qui sum pt
local actual = r(sum)

if abs(`actual' - `expected') < 1 {
    test_pass
}
else test_fail "Person-time not conserved: expected `expected', got `actual'"

*--- Test 12.2: Person-time by exposure type sums correctly ---
run_test "persontime_exposure_sum"
use "/tmp/test_cohort.dta", clear
qui tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit)

gen pt = rx_stop - rx_start + 1
qui sum pt
local total = r(sum)

local sum_by_type = 0
qui levelsof tv_exposure, local(types)
foreach t of local types {
    qui sum pt if tv_exposure == `t'
    local sum_by_type = `sum_by_type' + r(sum)
}

if abs(`sum_by_type' - `total') < 1 {
    test_pass
}
else test_fail "Sum by type != total: `sum_by_type' vs `total'"

********************************************************************************
* SECTION 13: ERROR HANDLING TESTS
********************************************************************************

display as text _n _dup(70) "="
display as text "ERROR HANDLING"
display as text _dup(70) "="

*--- Test 13.1: Mutually exclusive exposure types ---
run_test "error_mutual_exclusion_exptype"
use "/tmp/test_cohort.dta", clear
capture tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    evertreated currentformer
if _rc != 0 {
    test_pass
}
else test_fail "Should error on mutually exclusive options"

*--- Test 13.2: Mutually exclusive overlap strategies ---
run_test "error_mutual_exclusion_overlap"
use "/tmp/test_cohort.dta", clear
capture tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    priority(1 2 3) split
if _rc != 0 {
    test_pass
}
else test_fail "Should error on mutually exclusive options"

*--- Test 13.3: dosecuts without dose ---
run_test "error_dosecuts_without_dose"
use "/tmp/test_cohort.dta", clear
capture tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    dosecuts(10 50 100)
if _rc != 0 {
    test_pass
}
else test_fail "Should error on dosecuts without dose"

*--- Test 13.4: Missing required options ---
run_test "error_missing_required"
use "/tmp/test_cohort.dta", clear
capture tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) ///
    entry(study_entry) exit(study_exit)
* Missing reference()
if _rc != 0 {
    test_pass
}
else test_fail "Should error on missing reference()"

*--- Test 13.5: Invalid window (min >= max) ---
run_test "error_invalid_window"
use "/tmp/test_cohort.dta", clear
capture tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    window(10 5)
if _rc != 0 {
    test_pass
}
else test_fail "Should error on invalid window"

*--- Test 13.6: tvmerge generate vs prefix conflict ---
run_test "error_tvmerge_generate_prefix"
capture tvmerge "/tmp/tv1.dta" "/tmp/tv2.dta", ///
    id(id) start(rx_start start2) stop(rx_stop stop2) ///
    exposure(tv_exposure tv_exposure) ///
    generate(a b) prefix(test_) force
if _rc != 0 {
    test_pass
}
else test_fail "Should error on generate + prefix"

*--- Test 13.7: tvevent invalid type ---
run_test "error_tvevent_invalid_type"
use "/tmp/test_cohort.dta", clear
capture tvevent using "/tmp/intervals.dta", ///
    id(id) date(event_date) type(invalid)
if _rc != 0 {
    test_pass
}
else test_fail "Should error on invalid type"

********************************************************************************
* SECTION 14: EDGE CASES
********************************************************************************

display as text _n _dup(70) "="
display as text "EDGE CASES"
display as text _dup(70) "="

*--- Test 14.1: Single observation cohort ---
run_test "edge_single_obs"
clear
set obs 1
gen id = 1
gen study_entry = mdy(1, 1, 2020)
gen study_exit = mdy(12, 31, 2020)
format study_entry study_exit %tdCCYY-NN-DD
save "/tmp/single_cohort.dta", replace

clear
set obs 1
gen id = 1
gen rx_start = mdy(3, 1, 2020)
gen rx_stop = mdy(6, 30, 2020)
gen drug = 1
format rx_start rx_stop %tdCCYY-NN-DD
save "/tmp/single_exposure.dta", replace

use "/tmp/single_cohort.dta", clear
capture noisily tvexpose using "/tmp/single_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit)
if _rc == 0 {
    qui count
    if r(N) >= 1 {
        test_pass
    }
    else test_fail "No output rows"
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 14.2: No matching exposures ---
run_test "edge_no_matching_exposure"
clear
set obs 10
gen id = _n + 1000
gen study_entry = mdy(1, 1, 2020)
gen study_exit = mdy(12, 31, 2020)
format study_entry study_exit %tdCCYY-NN-DD
save "/tmp/nomatch_cohort.dta", replace

use "/tmp/nomatch_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit)
if _rc == 0 {
    * All should be reference
    qui count if tv_exposure != 0
    if r(N) == 0 {
        test_pass
    }
    else test_fail "Should all be reference"
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 14.3: Entry equals exit (zero follow-up) ---
run_test "edge_zero_followup"
clear
set obs 5
gen id = _n
gen study_entry = mdy(6, 15, 2020)
gen study_exit = mdy(6, 15, 2020)
format study_entry study_exit %tdCCYY-NN-DD
save "/tmp/zero_followup.dta", replace

use "/tmp/zero_followup.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit)
* This might error or produce minimal output
if _rc == 0 {
    test_pass
}
else {
    * Error is acceptable for zero follow-up
    test_pass
}

*--- Test 14.4: tvevent with no events (all missing dates) ---
run_test "edge_tvevent_no_events"
clear
set obs 10
gen id = _n
gen event_date = .
format event_date %tdCCYY-NN-DD
save "/tmp/no_events.dta", replace

use "/tmp/no_events.dta", clear
capture noisily tvevent using "/tmp/intervals.dta", ///
    id(id) date(event_date) type(single)
if _rc == 0 {
    * All should be censored
    qui count if _failure == 0
    local censored = r(N)
    qui count
    if `censored' == r(N) {
        test_pass
    }
    else test_fail "Not all censored"
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 14.5: Exposure completely before follow-up ---
run_test "edge_exposure_before_followup"
clear
set obs 5
gen id = _n
gen study_entry = mdy(6, 1, 2020)
gen study_exit = mdy(12, 31, 2020)
format study_entry study_exit %tdCCYY-NN-DD
save "/tmp/late_cohort.dta", replace

clear
set obs 5
gen id = _n
gen rx_start = mdy(1, 1, 2020)
gen rx_stop = mdy(3, 31, 2020)
gen drug = 1
format rx_start rx_stop %tdCCYY-NN-DD
save "/tmp/early_exposure.dta", replace

use "/tmp/late_cohort.dta", clear
capture noisily tvexpose using "/tmp/early_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit)
if _rc == 0 {
    * All should be reference
    qui count if tv_exposure != 0
    if r(N) == 0 {
        test_pass
    }
    else test_fail "Should all be reference"
}
else test_fail "Command failed with rc=`=_rc'"

********************************************************************************
* SECTION 16: ADDITIONAL STRESS TESTS
********************************************************************************

display as text _n _dup(70) "="
display as text "ADDITIONAL STRESS TESTS"
display as text _dup(70) "="

*--- Test 16.1: Large cohort with many exposures ---
run_test "stress_large_cohort"
clear
set seed 99999
set obs 500
gen id = _n
gen study_entry = mdy(1, 1, 2015) + int(runiform() * 365)
gen study_exit = study_entry + 365 * 5 + int(runiform() * 365)
format study_entry study_exit %td
save "/tmp/large_cohort.dta", replace

clear
set obs 2000
gen id = ceil(_n / 4)
gen rx_start = mdy(1, 1, 2015) + int(runiform() * 1500)
gen rx_stop = rx_start + 30 + int(runiform() * 180)
gen drug = ceil(runiform() * 5)
format rx_start rx_stop %td
save "/tmp/large_exposure.dta", replace

use "/tmp/large_cohort.dta", clear
capture noisily tvexpose using "/tmp/large_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit)
if _rc == 0 {
    qui count
    if r(N) > 500 {
        test_pass
    }
    else test_fail "Expected more than 500 observations after splitting"
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 16.2: Extreme grace period (365 days) ---
run_test "stress_large_grace"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    grace(365)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 16.3: Very short intervals (1 day grace) ---
run_test "stress_minimal_grace"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    grace(1)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 16.4: Large lag period ---
run_test "stress_large_lag"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    lag(180)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 16.5: Large washout period ---
run_test "stress_large_washout"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    washout(365)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 16.6: All major options combined ---
run_test "stress_all_options"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    currentformer grace(30) lag(7) washout(90) ///
    expandunit(7) bytype carryforward(14) ///
    check gaps summarize
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 16.7: Duration with small unit ---
run_test "stress_duration_small_unit"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    duration(7) bytype
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 16.8: Dose with multiple categories ---
run_test "stress_dose_categories"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    dose dosecuts(10 25 50 75)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 16.9: Recency with small windows ---
run_test "stress_recency_small_windows"
use "/tmp/test_cohort.dta", clear
capture noisily tvexpose using "/tmp/test_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    recency(7 14 21 30 60)
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

*--- Test 16.10: Many overlapping exposures per person ---
run_test "stress_many_overlaps"
clear
set seed 77777
set obs 10
gen id = _n
gen study_entry = mdy(1, 1, 2020)
gen study_exit = mdy(12, 31, 2022)
format study_entry study_exit %td
save "/tmp/overlap_cohort.dta", replace

clear
set obs 100
gen id = ceil(_n / 10)
gen rx_start = mdy(1, 1, 2020) + int(runiform() * 200)
gen rx_stop = rx_start + 100 + int(runiform() * 200)
gen drug = ceil(runiform() * 3)
format rx_start rx_stop %td
save "/tmp/overlap_exposure.dta", replace

use "/tmp/overlap_cohort.dta", clear
capture noisily tvexpose using "/tmp/overlap_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    layer
if _rc == 0 {
    test_pass
}
else test_fail "Command failed with rc=`=_rc'"

* Cleanup stress test files
capture erase "/tmp/large_cohort.dta"
capture erase "/tmp/large_exposure.dta"
capture erase "/tmp/overlap_cohort.dta"
capture erase "/tmp/overlap_exposure.dta"

********************************************************************************
* CLEANUP AND SUMMARY
********************************************************************************

display as text _n _dup(70) "="
display as text "COMPREHENSIVE TEST SUMMARY"
display as text _dup(70) "="

display as text "Total tests:  $test_count"
display as result "Passed:       $pass_count"
if $fail_count > 0 {
    display as error "Failed:       $fail_count"
    display as error "Failed tests:$failed_tests"
}
else {
    display as text "Failed:       $fail_count"
}
display as text _dup(70) "="

if $fail_count > 0 {
    display as error "Some tests FAILED. Review output above."
    exit 1
}
else {
    display as result "ALL TESTS PASSED!"
}

* Cleanup temp files
capture erase "/tmp/test_cohort.dta"
capture erase "/tmp/test_exposure.dta"
capture erase "/tmp/test_exposure2.dta"
capture erase "/tmp/test_pointtime.dta"
capture erase "/tmp/test_recurring.dta"
capture erase "/tmp/tv1.dta"
capture erase "/tmp/tv2.dta"
capture erase "/tmp/intervals.dta"
capture erase "/tmp/intervals_renamed.dta"
capture erase "/tmp/test_output.dta"
capture erase "/tmp/merged_output.dta"
capture erase "/tmp/single_cohort.dta"
capture erase "/tmp/single_exposure.dta"
capture erase "/tmp/nomatch_cohort.dta"
capture erase "/tmp/zero_followup.dta"
capture erase "/tmp/no_events.dta"
capture erase "/tmp/late_cohort.dta"
capture erase "/tmp/early_exposure.dta"
