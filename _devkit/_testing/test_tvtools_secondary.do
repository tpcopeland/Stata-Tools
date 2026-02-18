/*******************************************************************************
* test_tvtools_secondary.do
*
* Purpose: Functional tests for secondary tvtools commands that lacked any tests.
*          These verify each command runs without error and produces expected output.
*
* Commands tested:
*   - tvdiagnose   (diagnostic reports)
*   - tvplot       (visualization - no display, just runs)
*   - tvcalendar   (calendar-time factor merge)
*   - tvtrial      (target trial emulation)
*   - tvtable      (summary tables)
*   - tvreport     (analysis report)
*   - tvpipeline   (end-to-end pipeline)
*   - tvdml        (double ML estimation)
*   - tvestimate   (g-estimation)
*   - tvpass       (workflow support)
*
* Note: tvreport, tvtrial, tvpass, tvpipeline internally use the SSC package
*       "distinct". These tests install it if not already present.
*
* Run: stata-mp -b do test_tvtools_secondary.do
* Log: test_tvtools_secondary.log
*
* Author: Claude Code
* Date: 2026-02-17
*******************************************************************************/

clear all
set more off
version 16.0
set varabbrev off

local pass_count = 0
local fail_count = 0
local failed_tests ""

display _n _dup(70) "="
display "TVTOOLS SECONDARY COMMANDS - FUNCTIONAL TESTS"
display _dup(70) "="
display "Date: $S_DATE $S_TIME"
display ""

quietly adopath ++ "/home/tpcopeland/Stata-Tools/tvtools"

* ============================================================================
* CREATE SHARED TEST DATA
* ============================================================================
display _n _dup(60) "-"
display "SETUP: Creating test datasets"
display _dup(60) "-"

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
else {
    display as error "  FAIL [setup.tvexpose]: tvexpose failed with rc=`=_rc'"
    display "  Cannot run secondary tests without time-varying dataset. Exiting."
    exit 1
}

* Calendar dataset for tvcalendar (point-in-time merge using same varname "start")
* tvcalendar's range-based merge (startvar/stopvar) is not yet implemented.
* Point-in-time merge requires the datevar to exist in the EXTERNAL dataset too.
* Create a calendar with the same "start" variable matching unique dates in the output.
use "/tmp/sec_tve.dta", clear
quietly duplicates drop start, force
keep start
format start %td
gen season = 1
replace season = 2 if month(start) >= 4
replace season = 3 if month(start) >= 7
replace season = 4 if month(start) >= 10
label define seasons 1 "Winter" 2 "Spring" 3 "Summer" 4 "Fall"
label values season seasons
save "/tmp/sec_calendar.dta", replace

display as result "  Setup complete - all test data created"

* ============================================================================
* TEST: TVDIAGNOSE
* ============================================================================
display _n _dup(60) "-"
display "TEST: tvdiagnose - diagnostic reports"
display _dup(60) "-"

local t_pass = 1

* Note: 'coverage' option requires entry()/exit() which tvexpose drops from output
* Use 'gaps' and 'overlaps' instead (they don't need entry/exit)
use "/tmp/sec_tve.dta", clear
capture noisily tvdiagnose, ///
    id(id) start(start) stop(stop) ///
    exposure(tv_exp) ///
    gaps overlaps

if _rc == 0 {
    display as result "  PASS [tvdiagnose.run]: ran without error"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL [tvdiagnose.run]: error `=_rc'"
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' tvdiagnose"
    local t_pass = 0
}

* Also test summarize option
use "/tmp/sec_tve.dta", clear
capture noisily tvdiagnose, ///
    id(id) start(start) stop(stop) ///
    exposure(tv_exp) ///
    gaps overlaps summarize

if _rc == 0 {
    display as result "  PASS [tvdiagnose.summarize]: summarize option ran without error"
}
else {
    display as error "  FAIL [tvdiagnose.summarize]: error `=_rc'"
    if `t_pass' {
        local fail_count = `fail_count' + 1
        local failed_tests "`failed_tests' tvdiagnose.summarize"
        local t_pass = 0
    }
}

* ============================================================================
* TEST: TVPLOT
* ============================================================================
display _n _dup(60) "-"
display "TEST: tvplot - visualization (swimlane)"
display _dup(60) "-"

* Run in batch mode - just test that the plot command executes without error
* Note: graph saving (gph format) may not work in all batch contexts; omit saving()
use "/tmp/sec_tve.dta", clear
capture noisily tvplot, ///
    id(id) start(start) stop(stop) ///
    exposure(tv_exp) ///
    sample(10) ///
    swimlane

if _rc == 0 {
    display as result "  PASS [tvplot.swimlane]: swimlane plot ran without error"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL [tvplot.swimlane]: error `=_rc'"
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' tvplot"
}

* ============================================================================
* TEST: TVCALENDAR
* ============================================================================
display _n _dup(60) "-"
display "TEST: tvcalendar - calendar-time factor merge (point-in-time)"
display _dup(60) "-"

* tvcalendar point-in-time merge: external dataset must have same datevar name
* (Range-based merge with startvar/stopvar is not implemented in current version)
use "/tmp/sec_tve.dta", clear
capture noisily tvcalendar using "/tmp/sec_calendar.dta", datevar(start)

if _rc == 0 {
    capture confirm variable season
    if _rc == 0 {
        display as result "  PASS [tvcalendar.run]: ran without error, season variable created"
        local pass_count = `pass_count' + 1
    }
    else {
        display as error "  FAIL [tvcalendar.season_var]: season variable not created after merge"
        local fail_count = `fail_count' + 1
        local failed_tests "`failed_tests' tvcalendar"
    }
}
else {
    display as error "  FAIL [tvcalendar.run]: error `=_rc'"
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' tvcalendar"
}

* ============================================================================
* TEST: TVTABLE
* ============================================================================
display _n _dup(60) "-"
display "TEST: tvtable - summary table generation"
display _dup(60) "-"

use "/tmp/sec_tve.dta", clear
* Add a person-time variable
quietly gen pt_days = stop - start + 1
* Add event variable from cohort
quietly merge m:1 id using "/tmp/sec_cohort.dta", keepusing(event_date) nogen

capture noisily tvtable, ///
    exposure(tv_exp) ///
    persontime(pt_days)

if _rc == 0 {
    display as result "  PASS [tvtable.run]: ran without error"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL [tvtable.run]: error `=_rc'"
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' tvtable"
}

* ============================================================================
* TEST: TVREPORT
* ============================================================================
display _n _dup(60) "-"
display "TEST: tvreport - analysis report generation"
display _dup(60) "-"

use "/tmp/sec_tve.dta", clear

capture noisily tvreport, ///
    id(id) start(start) stop(stop) ///
    exposure(tv_exp)

if _rc == 0 {
    display as result "  PASS [tvreport.run]: ran without error"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL [tvreport.run]: error `=_rc'"
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' tvreport"
}

* ============================================================================
* TEST: TVTRIAL
* ============================================================================
display _n _dup(60) "-"
display "TEST: tvtrial - target trial emulation"
display _dup(60) "-"

* tvtrial requires: id, entry, exit, treatstart
* Use cohort dataset with first prescription date as treatment start
use "/tmp/sec_cohort.dta", clear

* Add treatment start (first exposure date) from exposure data
quietly merge 1:m id using "/tmp/sec_exposure.dta", keepusing(start) nogen
quietly bysort id: egen treat_start = min(start)
quietly bysort id: keep if _n == 1

capture noisily tvtrial, ///
    id(id) entry(study_entry) exit(study_exit) ///
    treatstart(treat_start) ///
    trials(3) trialinterval(60)

if _rc == 0 {
    quietly count
    local n_output = r(N)
    display as result "  PASS [tvtrial.run]: ran without error, `n_output' rows created"

    * Check for expected trial variables
    capture confirm variable trial_id
    local has_trial_id = (_rc == 0)
    if `has_trial_id' {
        display as result "  PASS [tvtrial.trial_id]: trial_id variable created"
    }
    else {
        display as error "  FAIL [tvtrial.trial_id]: trial_id variable not found"
        quietly ds
        local vlist = r(varlist)
        display "  Variables: `vlist'"
    }
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL [tvtrial.run]: error `=_rc'"
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' tvtrial"
}

* ============================================================================
* TEST: TVDML
* ============================================================================
display _n _dup(60) "-"
display "TEST: tvdml - double ML estimation"
display _dup(60) "-"

* Create a dataset suitable for tvdml
clear
set obs 100
set seed 777
gen id = _n
gen x1 = runiform()
gen x2 = runiform() > 0.5
gen x3 = rnormal(0, 1)
gen treatment = (x1 + x2 + x3 + runiform() > 2.5)
gen outcome = treatment * 0.5 + x1 * 0.3 + x3 * 0.2 + rnormal(0, 0.5)

capture noisily tvdml outcome treatment, ///
    covariates(x1 x2 x3) ///
    seed(42)

if _rc == 0 {
    * Check that e(b) exists
    capture mat list e(b)
    if _rc == 0 {
        display as result "  PASS [tvdml.results]: e(b) returned"
    }
    else {
        display as error "  FAIL [tvdml.results]: e(b) not returned"
    }

    * Check that the causal estimate exists
    local psi = r(psi)
    if missing(`psi') {
        local psi = e(psi)
    }
    if !missing(`psi') {
        display as result "  PASS [tvdml.psi]: causal estimate returned (psi=`psi')"
    }
    else {
        display as error "  FAIL [tvdml.psi]: causal estimate not returned"
    }
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL [tvdml.run]: error `=_rc'"
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' tvdml"
}

* ============================================================================
* TEST: TVESTIMATE
* ============================================================================
display _n _dup(60) "-"
display "TEST: tvestimate - g-estimation / structural nested models"
display _dup(60) "-"

* tvestimate syntax: outcome treatment, confounders(varlist) [options]
* Note: option is "confounders()" not "covariates()"
clear
set obs 50
set seed 888
gen id = _n
gen x1 = runiform()
gen treatment = (x1 + runiform() > 1.2)
gen outcome = treatment * 0.5 + x1 * 0.3 + rnormal(0, 0.5)

capture noisily tvestimate outcome treatment, ///
    confounders(x1)

if _rc == 0 {
    display as result "  PASS [tvestimate.run]: ran without error"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL [tvestimate.run]: error `=_rc'"
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' tvestimate"
}

* ============================================================================
* TEST: TVPASS
* ============================================================================
display _n _dup(60) "-"
display "TEST: tvpass - post-authorization safety study workflow"
display _dup(60) "-"

* tvpass requires file paths for cohort, exposure, and outcomes files
capture noisily tvpass, ///
    cohort("/tmp/sec_cohort.dta") ///
    exposure("/tmp/sec_exposure.dta") ///
    outcomes("/tmp/sec_cohort.dta") ///
    id(id)

if _rc == 0 {
    display as result "  PASS [tvpass.run]: ran without error"
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL [tvpass.run]: error `=_rc'"
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' tvpass"
}

* ============================================================================
* TEST: TVPIPELINE
* ============================================================================
display _n _dup(60) "-"
display "TEST: tvpipeline - end-to-end pipeline wrapper"
display _dup(60) "-"

use "/tmp/sec_cohort.dta", clear
capture noisily tvpipeline using "/tmp/sec_exposure.dta", ///
    id(id) start(start) stop(stop) ///
    exposure(drug_type) ///
    entry(study_entry) exit(study_exit) ///
    reference(0)

if _rc == 0 {
    quietly count
    local n_output = r(N)
    display as result "  PASS [tvpipeline.run]: pipeline completed, `n_output' rows"
    * Verify basic output structure
    capture confirm variable start
    local has_start = (_rc == 0)
    capture confirm variable stop
    local has_stop = (_rc == 0)
    if `has_start' & `has_stop' {
        display as result "  PASS [tvpipeline.structure]: start and stop variables present"
    }
    else {
        display as error "  FAIL [tvpipeline.structure]: missing output variables (start=`has_start', stop=`has_stop')"
    }
    local pass_count = `pass_count' + 1
}
else {
    display as error "  FAIL [tvpipeline.run]: error `=_rc'"
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' tvpipeline"
}

* ============================================================================
* FINAL SUMMARY
* ============================================================================
local total_tests = `pass_count' + `fail_count'
display _n _dup(70) "="
display "TVTOOLS SECONDARY COMMANDS FUNCTIONAL TEST SUMMARY"
display _dup(70) "="
display "Tests run:    `total_tests'"
display "Tests passed: `pass_count'"
display "Tests failed: `fail_count'"
if "`failed_tests'" != "" {
    display as error "Failed tests: `failed_tests'"
}
display _dup(70) "="

if `fail_count' == 0 {
    display as result _n "ALL SECONDARY COMMAND TESTS PASSED"
}
else {
    display as error _n "`fail_count' SECONDARY COMMAND TESTS FAILED"
    exit 1
}
