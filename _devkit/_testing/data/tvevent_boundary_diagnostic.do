/*******************************************************************************
* tvevent_boundary_diagnostic.do
*
* Purpose: Diagnose the boundary event issue in tvevent.ado
*          Compare original manual code vs tvevent behavior
*
* Issue: The original code from HRT_2025_12_15.do (lines 1392-1412) uses:
*        `inrange(event_dt, start, stop)` which is INCLUSIVE (start <= x <= stop)
*
*        tvevent uses `date > startvar & date < stopvar` which is STRICTLY INSIDE
*        plus line 659 filters out events at interval boundaries
*
* This test creates a minimal dataset to verify the discrepancy
*
* Author: Claude Code
* Date: 2025-12-17
*******************************************************************************/

clear all
set more off
version 16.0
set varabbrev off

* =============================================================================
* SETUP
* =============================================================================
* Try to detect path from current working directory
    capture confirm file "_testing"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            global STATA_TOOLS_PATH "/home/`c(username)'/Stata-Tools"
        }
    }
global DATA_DIR "${STATA_TOOLS_PATH}/_testing/data"

* Install tvtools from local
capture net uninstall tvtools
quietly net install tvtools, from("${STATA_TOOLS_PATH}/tvtools")

display _n "{hline 70}"
display "TVEVENT BOUNDARY EVENT DIAGNOSTIC"
display "{hline 70}"

* =============================================================================
* CREATE MINIMAL TEST DATA
* =============================================================================
* Scenario: 3 people with different event timing relative to intervals
*
* Person 1: Event INSIDE interval (should be flagged by both methods)
* Person 2: Event AT BOUNDARY of interval (stop == event_dt, should be flagged by original, may not by tvevent)
* Person 3: Event OUTSIDE intervals (should not be flagged)

display _n "Creating minimal test data..."

* Create cohort data (master for tvevent)
clear
input long id double(study_entry study_exit event_dt)
    1   21915  22280  22100   // Event at day 185 (inside interval)
    2   21915  22280  22200   // Event at day 285 (at potential boundary)
    3   21915  22280  22400   // Event at day 485 (after study_exit)
    4   21915  22280  .       // No event (missing)
    5   21915  22280  22280   // Event exactly at study_exit
end
format %td study_entry study_exit event_dt
save "${DATA_DIR}/_diag_cohort.dta", replace
display "  Cohort: 5 patients"
list

* Create interval data (using file for tvevent)
* Each person has 2 intervals created by a hypothetical exposure change
clear
input long id double(start stop) byte exposure
    1  21915  22100  0    // First interval ends at day 185
    1  22100  22280  1    // Second interval starts at day 185
    2  21915  22200  0    // First interval ends at day 285
    2  22200  22280  1    // Second interval starts at day 285
    3  21915  22150  0    // First interval
    3  22150  22280  1    // Second interval
    4  21915  22180  0    // First interval
    4  22180  22280  1    // Second interval
    5  21915  22180  0    // First interval
    5  22180  22280  1    // Second interval ends at 22280 = event_dt
end
format %td start stop
label var start "Interval start"
label var stop "Interval stop"
save "${DATA_DIR}/_diag_intervals.dta", replace
display _n "  Intervals: 10 rows (2 per patient)"
list

* =============================================================================
* METHOD 1: ORIGINAL CODE (from HRT_2025_12_15.do lines 1392-1412)
* =============================================================================
display _n "{hline 70}"
display "METHOD 1: ORIGINAL MANUAL CODE"
display "{hline 70}"

use "${DATA_DIR}/_diag_cohort.dta", clear
merge 1:m id using "${DATA_DIR}/_diag_intervals.dta", nogen keep(3)

* Original logic:
* 1. Replace study_exit with event_dt if event occurred before
replace study_exit = event_dt if event_dt < study_exit

* 2. Drop intervals that start after study_exit
drop if start > study_exit

* 3. Adjust stop date if event falls within interval (INCLUSIVE: inrange)
replace stop = event_dt if inrange(event_dt, start, stop)

* 4. Generate outcome flag
gen outcome = event_dt == stop
label var outcome "Event occurred"

* 5. Generate time variable
gen time = stop - start

display _n "Results after original manual method:"
sort id start
list id start stop event_dt outcome time, sepby(id)

* Count events
quietly count if outcome == 1
local manual_events = r(N)
display _n "Total events flagged (manual method): `manual_events'"

* Save for comparison
save "${DATA_DIR}/_diag_manual_result.dta", replace

* =============================================================================
* METHOD 2: TVEVENT COMMAND
* =============================================================================
display _n "{hline 70}"
display "METHOD 2: TVEVENT COMMAND"
display "{hline 70}"

use "${DATA_DIR}/_diag_cohort.dta", clear

tvevent using "${DATA_DIR}/_diag_intervals.dta", ///
    id(id) date(event_dt) ///
    startvar(start) stopvar(stop) ///
    type(single) ///
    generate(outcome) ///
    timegen(time) timeunit(days)

display _n "Results after tvevent:"
sort id start
list id start stop event_dt outcome time, sepby(id)

* Count events
quietly count if outcome == 1
local tvevent_events = r(N)
display _n "Total events flagged (tvevent): `tvevent_events'"

* Save for comparison
save "${DATA_DIR}/_diag_tvevent_result.dta", replace

* =============================================================================
* COMPARISON
* =============================================================================
display _n "{hline 70}"
display "COMPARISON"
display "{hline 70}"
display "Manual method events: `manual_events'"
display "tvevent events:       `tvevent_events'"

if `manual_events' != `tvevent_events' {
    display as error _n "DISCREPANCY DETECTED!"
    display as error "The methods produce different event counts."
    display as error "This confirms the boundary event bug."

    * Show the specific differences
    display _n "Checking person-by-person..."

    use "${DATA_DIR}/_diag_manual_result.dta", clear
    rename outcome outcome_manual
    rename time time_manual
    keep id start stop outcome_manual time_manual
    tempfile manual
    save `manual'

    use "${DATA_DIR}/_diag_tvevent_result.dta", clear
    rename outcome outcome_tvevent
    rename time time_tvevent
    merge 1:1 id start stop using `manual', nogen

    gen different = outcome_manual != outcome_tvevent
    list id start stop outcome_manual outcome_tvevent different if different == 1, sepby(id)
}
else {
    display as result _n "Both methods produce the same event count."
}

* =============================================================================
* CLEANUP
* =============================================================================
capture erase "${DATA_DIR}/_diag_cohort.dta"
capture erase "${DATA_DIR}/_diag_intervals.dta"
capture erase "${DATA_DIR}/_diag_manual_result.dta"
capture erase "${DATA_DIR}/_diag_tvevent_result.dta"

display _n "{hline 70}"
display "Diagnostic complete"
display "{hline 70}"
