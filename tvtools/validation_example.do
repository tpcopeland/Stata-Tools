********************************************************************************
* TVTOOLS VALIDATION EXAMPLE
*
* Purpose: Provide a minimal, hand-verifiable example for study reproducibility
*
* This do-file creates a tiny synthetic cohort (3 persons) with known exposure
* patterns and events. Each step includes expected results that can be verified
* by hand calculation. Include this or its output in study supplementary materials.
*
* Author: Tim Copeland
* Date: 2025-12-26
********************************************************************************

clear all
version 16.0
set more off

* Ensure tvtools commands are available (adjust path if needed)
quietly adopath + "`c(pwd)'"

display as text ""
display as text _dup(70) "="
display as text "TVTOOLS VALIDATION EXAMPLE - Hand-Verifiable Results"
display as text _dup(70) "="
display as text ""

********************************************************************************
* STEP 1: CREATE MINIMAL COHORT
********************************************************************************
/*
COHORT DESIGN (3 persons, all follow 2020-01-01 to 2020-03-31 = 91 days each)

Person 1: Never exposed
  - Follow-up: 2020-01-01 to 2020-03-31 (91 days)
  - Exposure: None
  - Event: None
  - Expected: 1 row, unexposed, 91 days person-time

Person 2: Exposed continuously from day 31-60 (Feb 1-29)
  - Follow-up: 2020-01-01 to 2020-03-31 (91 days)
  - Exposure: Drug A, 2020-02-01 to 2020-02-29 (29 days)
  - Event: None
  - Expected: 3 rows (unexposed Jan, exposed Feb, unexposed Mar)
    - 2020-01-01 to 2020-01-31: 31 days unexposed
    - 2020-02-01 to 2020-02-29: 29 days exposed
    - 2020-03-01 to 2020-03-31: 31 days unexposed
  - Total: 91 days (31 + 29 + 31)

Person 3: Exposed, with event during exposure
  - Follow-up: 2020-01-01 to 2020-03-31 (91 days)
  - Exposure: Drug B, 2020-02-01 to 2020-03-31 (60 days)
  - Event: 2020-02-15 (dies)
  - Expected after tvexpose: 2 rows
    - 2020-01-01 to 2020-01-31: 31 days unexposed
    - 2020-02-01 to 2020-03-31: 60 days exposed
  - Expected after tvevent: 2 rows, truncated at event
    - 2020-01-01 to 2020-01-31: 31 days unexposed, censored
    - 2020-02-01 to 2020-02-15: 15 days exposed, event=1
  - Total person-time after event: 46 days (31 + 15)

SUMMARY EXPECTED RESULTS:
  Total cohort person-time before events: 273 days (91 * 3)
  Total cohort person-time after events: 228 days (91 + 91 + 46)
  Total exposed person-time before events: 89 days (29 + 60)
  Total exposed person-time after events: 44 days (29 + 15)
  Total events: 1 (Person 3)
*/

display as text "STEP 1: Creating minimal cohort (3 persons)"
display as text _dup(50) "-"

* Create cohort
clear
input int id str10 study_entry_str str10 study_exit_str str10 event_date_str
1 "2020-01-01" "2020-03-31" ""
2 "2020-01-01" "2020-03-31" ""
3 "2020-01-01" "2020-03-31" "2020-02-15"
end

gen study_entry = date(study_entry_str, "YMD")
gen study_exit = date(study_exit_str, "YMD")
gen event_date = date(event_date_str, "YMD")
format study_entry study_exit event_date %tdCCYY-NN-DD
drop *_str

display as text ""
display as text "  Cohort (3 persons, 2020-01-01 to 2020-03-31):"
list, noobs sep(0)

save "/tmp/validation_cohort.dta", replace

********************************************************************************
* STEP 2: CREATE EXPOSURE DATA
********************************************************************************

display as text ""
display as text "STEP 2: Creating exposure periods"
display as text _dup(50) "-"

clear
input int id int drug str10 rx_start_str str10 rx_stop_str
2 1 "2020-02-01" "2020-02-29"
3 2 "2020-02-01" "2020-03-31"
end

gen rx_start = date(rx_start_str, "YMD")
gen rx_stop = date(rx_stop_str, "YMD")
format rx_start rx_stop %tdCCYY-NN-DD
drop *_str

label define drug_lbl 0 "Unexposed" 1 "Drug_A" 2 "Drug_B"
label values drug drug_lbl

display as text ""
display as text "  Exposure periods:"
display as text "  - Person 2: Drug A, Feb 1-29 (29 days)"
display as text "  - Person 3: Drug B, Feb 1 - Mar 31 (60 days)"
list, noobs sep(0)

save "/tmp/validation_exposure.dta", replace

********************************************************************************
* STEP 3: RUN TVEXPOSE AND VERIFY
********************************************************************************

display as text ""
display as text "STEP 3: Running tvexpose"
display as text _dup(50) "-"

use "/tmp/validation_cohort.dta", clear

tvexpose using "/tmp/validation_exposure.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    generate(tv_drug)

* Calculate person-time for each row
gen pt_days = rx_stop - rx_start + 1
format pt_days %9.0f

display as text ""
display as text "  tvexpose output:"
list id rx_start rx_stop tv_drug pt_days, noobs sep(3)

* Verify expected results
display as text ""
display as text "  VERIFICATION:"

* Count rows
qui count
local n_rows = r(N)
display as text "  - Row count: `n_rows' (expected: 6)"
assert `n_rows' == 6

* Total person-time
qui sum pt_days
local total_pt = r(sum)
display as text "  - Total person-time: `total_pt' days (expected: 273)"
assert `total_pt' == 273

* Exposed person-time
qui sum pt_days if tv_drug != 0
local exposed_pt = r(sum)
display as text "  - Exposed person-time: `exposed_pt' days (expected: 89)"
assert `exposed_pt' == 89

* Unexposed person-time
qui sum pt_days if tv_drug == 0
local unexposed_pt = r(sum)
display as text "  - Unexposed person-time: `unexposed_pt' days (expected: 184)"
assert `unexposed_pt' == 184

display as result "  PASS: All tvexpose assertions verified"

save "/tmp/validation_tvexpose.dta", replace

********************************************************************************
* STEP 4: RUN TVEVENT AND VERIFY
********************************************************************************

display as text ""
display as text "STEP 4: Running tvevent (add event, truncate at event)"
display as text _dup(50) "-"

* First, prepare interval data with correct variable names
use "/tmp/validation_tvexpose.dta", clear
rename rx_start start
rename rx_stop stop
save "/tmp/validation_intervals.dta", replace

* Load event data (cohort with event dates) into memory
* tvevent expects: master = event data, using = interval data
use "/tmp/validation_cohort.dta", clear

tvevent using "/tmp/validation_intervals.dta", ///
    id(id) date(event_date) ///
    generate(outcome) type(single)

* Recalculate person-time
replace pt_days = stop - start + 1

display as text ""
display as text "  tvevent output (truncated at event):"
list id start stop tv_drug outcome pt_days, noobs sep(3)

display as text ""
display as text "  VERIFICATION:"

* Count rows (Person 3's second row should be split/truncated)
qui count
local n_rows = r(N)
display as text "  - Row count: `n_rows' (expected: 6 - some may be shorter)"

* Total person-time after event truncation
qui sum pt_days
local total_pt = r(sum)
display as text "  - Total person-time: `total_pt' days (expected: 228)"
assert `total_pt' == 228

* Exposed person-time after event truncation
qui sum pt_days if tv_drug != 0
local exposed_pt = r(sum)
display as text "  - Exposed person-time: `exposed_pt' days (expected: 44)"
assert `exposed_pt' == 44

* Count events
qui count if outcome == 1
local n_events = r(N)
display as text "  - Events: `n_events' (expected: 1)"
assert `n_events' == 1

* Verify event is on correct person
qui sum id if outcome == 1
local event_id = r(mean)
display as text "  - Event on person: `event_id' (expected: 3)"
assert `event_id' == 3

display as result "  PASS: All tvevent assertions verified"

********************************************************************************
* STEP 5: SUMMARY TABLE FOR METHODS SECTION
********************************************************************************

display as text ""
display as text _dup(70) "="
display as text "SUMMARY FOR SUPPLEMENTARY MATERIALS"
display as text _dup(70) "="
display as text ""

display as text "Validation Dataset Summary:"
display as text "  Cohort: 3 persons, follow-up 2020-01-01 to 2020-03-31"
display as text "  Exposure: Binary (unexposed vs Drug A/B)"
display as text "  Events: 1 event (Person 3, date 2020-02-15)"
display as text ""
display as text "Hand-Calculated Expected Values:"
display as text "  +---------------------+------------+----------+"
display as text "  | Metric              | Pre-Event  | Post-Event |"
display as text "  +---------------------+------------+----------+"
display as text "  | Total person-days   |    273     |    228     |"
display as text "  | Exposed person-days |     89     |     44     |"
display as text "  | Rows in dataset     |      6     |      6     |"
display as text "  | Events              |     --     |      1     |"
display as text "  +---------------------+------------+----------+"
display as text ""

display as result "ALL VALIDATION TESTS PASSED"
display as text ""

* Clean up temp files
capture erase "/tmp/validation_cohort.dta"
capture erase "/tmp/validation_exposure.dta"
capture erase "/tmp/validation_tvexpose.dta"
capture erase "/tmp/validation_intervals.dta"

********************************************************************************
* END OF VALIDATION EXAMPLE
********************************************************************************
