/*******************************************************************************
* validation_tvtools_pipeline.do
*
* Purpose: End-to-end integration validation of the full tvtools pipeline
*          Verifies data integrity at each step from raw data to analysis-ready
*
* Pipeline: cohort → tvexpose → tvevent → tvdiagnose → tvbalance →
*           tvweight → stset → stcox
*
* Run: stata-mp -b do validation_tvtools_pipeline.do
*******************************************************************************/

clear all
set more off
version 16.0
set varabbrev off

* Install tvtools
local root_dir "`c(pwd)'"
capture net uninstall tvtools
quietly net install tvtools, from("`root_dir'/tvtools") replace

local pass_count = 0
local fail_count = 0

display as text _newline _dup(70) "="
display as text "TVTOOLS INTEGRATION PIPELINE VALIDATION"
display as text _dup(70) "="

* ============================================================================
* CREATE SIMULATED DATA
* ============================================================================

display as text _newline "Step 0: Creating simulated data"
display as text _dup(70) "-"

set seed 42

* Cohort: 100 persons, study period 2020-2023
clear
set obs 100
gen long id = _n
gen double study_entry = mdy(1, 1, 2020) + floor(runiform() * 90)
gen double study_exit = study_entry + 365 + floor(runiform() * 730)
format study_entry study_exit %tdCCYY/NN/DD

* Covariates for each person
gen double age = floor(40 + runiform() * 30)
gen byte sex = (runiform() > 0.5)

display as result "Created cohort: " _N " persons"

tempfile cohort_data
quietly save `cohort_data'

* Exposure data: ~60% of persons get treatment
clear
set obs 150
gen long id = ceil(runiform() * 100)
gen double rx_start = mdy(1, 1, 2020) + floor(runiform() * 365)
gen double rx_stop = rx_start + 30 + floor(runiform() * 90)
gen byte exp_type = 1
format rx_start rx_stop %tdCCYY/NN/DD
drop if id > 100

display as result "Created exposure data: " _N " records"

tempfile exposure_data
quietly save `exposure_data'

* Event data: outcome for ~15% of persons
use `cohort_data', clear
gen double event_date = study_entry + floor(runiform() * (study_exit - study_entry))
gen byte has_event = (runiform() < 0.15)
replace event_date = . if has_event == 0
format event_date %tdCCYY/NN/DD
keep id event_date
drop if missing(event_date)

display as result "Created event data: " _N " events"

tempfile event_data
quietly save `event_data'

* ============================================================================
* STEP 1: tvexpose
* ============================================================================

display as text _newline "Step 1: tvexpose"
display as text _dup(70) "-"

use `cohort_data', clear

tvexpose using `exposure_data', id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

* Test 1.1: All persons present
quietly tab id
local n_persons = r(r)
if `n_persons' == 100 {
    display as result "PASS 1.1: All 100 persons present"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL 1.1: " `n_persons' " persons (expected 100)"
    local fail_count = `fail_count' + 1
}

* Test 1.2: No overlapping intervals
sort id rx_start
by id: gen double _gap = rx_start - rx_stop[_n-1] if _n > 1
quietly count if _gap < 1 & !missing(_gap)
local n_overlaps = r(N)
if `n_overlaps' == 0 {
    display as result "PASS 1.2: No overlapping intervals"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL 1.2: " `n_overlaps' " overlapping intervals"
    local fail_count = `fail_count' + 1
}
drop _gap

* Test 1.3: Person-time conserved
preserve
gen double days = rx_stop - rx_start + 1
collapse (sum) total_days=days, by(id)
merge 1:1 id using `cohort_data', keepusing(study_entry study_exit) nogenerate
gen double expected_days = study_exit - study_entry + 1
gen double day_diff = abs(total_days - expected_days)
quietly summarize day_diff
local max_diff = r(max)
restore

if `max_diff' <= 1 {
    display as result "PASS 1.3: Person-time conserved (max diff = " `max_diff' ")"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL 1.3: Person-time not conserved (max diff = " `max_diff' ")"
    local fail_count = `fail_count' + 1
}

display as result "tvexpose output: " _N " rows"

tempfile tvexpose_result
quietly save `tvexpose_result'

* ============================================================================
* STEP 2: tvevent
* ============================================================================

display as text _newline "Step 2: tvevent"
display as text _dup(70) "-"

* tvevent expects: master = event data, using = time-varying intervals
use `event_data', clear
tvevent using `tvexpose_result', id(id) date(event_date) ///
    startvar(rx_start) stopvar(rx_stop) generate(tv_event)

* Test 2.1: Event flag is binary
quietly tab tv_event
local n_levels = r(r)
if `n_levels' <= 2 {
    display as result "PASS 2.1: Event flag has " `n_levels' " levels"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL 2.1: Event flag has " `n_levels' " levels"
    local fail_count = `fail_count' + 1
}

* Test 2.2: No overlapping intervals after split
sort id rx_start
by id: gen double _gap = rx_start - rx_stop[_n-1] if _n > 1
quietly count if _gap < 1 & !missing(_gap)
local n_overlaps = r(N)
if `n_overlaps' == 0 {
    display as result "PASS 2.2: No overlaps after tvevent"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL 2.2: " `n_overlaps' " overlaps after tvevent"
    local fail_count = `fail_count' + 1
}
drop _gap

display as result "tvevent output: " _N " rows"

tempfile tvevent_result
quietly save `tvevent_result'

* ============================================================================
* STEP 3: tvdiagnose
* ============================================================================

display as text _newline "Step 3: tvdiagnose"
display as text _dup(70) "-"

tvdiagnose, id(id) start(rx_start) stop(rx_stop) overlaps

* Test 3.1: No overlaps detected
local n_overlaps = r(n_overlaps)
if `n_overlaps' == 0 {
    display as result "PASS 3.1: tvdiagnose confirms no overlaps"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL 3.1: tvdiagnose found " `n_overlaps' " overlaps"
    local fail_count = `fail_count' + 1
}

* ============================================================================
* STEP 4: tvbalance
* ============================================================================

display as text _newline "Step 4: tvbalance"
display as text _dup(70) "-"

* Create binary exposure for balance check
gen byte exposed = (tv_exp > 0) if !missing(tv_exp)

* Merge age/sex covariates back for balance
merge m:1 id using `cohort_data', keepusing(age sex) nogenerate

* Test 4.1: tvbalance runs
capture tvbalance age sex, exposure(exposed)
if _rc == 0 {
    display as result "PASS 4.1: tvbalance completed"
    local pass_count = `pass_count' + 1

    * Test 4.2: Matrix exists
    matrix b = r(balance)
    local nrows = rowsof(b)
    if `nrows' == 2 {
        display as result "PASS 4.2: Balance matrix has 2 rows (age, sex)"
        local pass_count = `pass_count' + 1
    }
    else {
        display as error "FAIL 4.2: Balance matrix has " `nrows' " rows"
        local fail_count = `fail_count' + 1
    }
}
else {
    display as error "FAIL 4.1: tvbalance failed (rc=" _rc ")"
    local fail_count = `fail_count' + 1
}

* ============================================================================
* STEP 5: tvweight
* ============================================================================

display as text _newline "Step 5: tvweight"
display as text _dup(70) "-"

* Test 5.1: tvweight runs
tvweight exposed, covariates(age sex) generate(iptw) nolog

local ess = r(ess)
local n_obs = r(N)

display as result "PASS 5.1: tvweight completed"
local pass_count = `pass_count' + 1

* Test 5.2: All weights positive
quietly count if iptw <= 0 | missing(iptw)
local n_bad = r(N)
if `n_bad' == 0 {
    display as result "PASS 5.2: All weights positive"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL 5.2: " `n_bad' " non-positive or missing weights"
    local fail_count = `fail_count' + 1
}

* Test 5.3: ESS is reasonable
if `ess' > 0 & `ess' <= `n_obs' {
    display as result "PASS 5.3: ESS = " %7.1f `ess' " (of " `n_obs' ")"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL 5.3: ESS = " `ess' " out of range"
    local fail_count = `fail_count' + 1
}

* ============================================================================
* STEP 6: stset + stcox
* ============================================================================

display as text _newline "Step 6: stset + stcox"
display as text _dup(70) "-"

* stset for survival analysis
stset rx_stop, failure(tv_event) id(id) enter(rx_start) origin(rx_start)

* Test 6.1: Cox model converges
capture stcox tv_exp
if _rc == 0 {
    matrix b = e(b)
    local hr = exp(b[1,1])
    if `hr' > 0 & `hr' < . {
        display as result "PASS 6.1: Cox model converged (HR = " %7.3f `hr' ")"
        local pass_count = `pass_count' + 1
    }
    else {
        display as error "FAIL 6.1: HR not finite (" `hr' ")"
        local fail_count = `fail_count' + 1
    }
}
else {
    display as error "FAIL 6.1: stcox failed (rc=" _rc ")"
    local fail_count = `fail_count' + 1
}

* ============================================================================
* SUMMARY
* ============================================================================

display as text _newline _dup(70) "="
display as text "PIPELINE VALIDATION SUMMARY"
display as text _dup(70) "="
display as result `pass_count' " passed, " `fail_count' " failed"
display as text _dup(70) "="

if `fail_count' > 0 {
    exit 9
}
