/*  demo_consort.do - Generate screenshots for consort

    Produces 2 output types:
      1. Console output (exclusion steps) -> .smcl
      2. Graph (CONSORT flowchart) -> .png
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "consort/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
capture program drop consort
capture program drop _consort_init
capture program drop _consort_exclude
capture program drop _consort_save
capture program drop _consort_clear
capture program drop _consort_update_final
quietly run consort/consort.ado

* --- Setup: retrospective database cohort (45,892 patients) ---
* Exclusion counts chosen to match preferred flowchart:
*   Missing baseline labs:       3,241
*   Age < 18 years:                892
*   Prior cancer diagnosis:      2,105
*   Lost to follow-up < 30 days:  567
*   Missing outcome data:        1,893
*   Final Analytic Cohort:      37,194

clear
set obs 45892

gen double id = _n

* Create non-overlapping exclusion indicators by observation ranges
gen byte missing_labs    = (_n <= 3241)
gen byte age_lt18        = (_n >= 3242  & _n <= 4133)
gen byte prior_cancer    = (_n >= 4134  & _n <= 6238)
gen byte lost_followup   = (_n >= 6239  & _n <= 6805)
gen byte missing_outcome = (_n >= 6806  & _n <= 8698)

* --- 1. Console output: exclusion steps ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg

noisily consort init, initial("Patients in database 2015-2023")
noisily consort exclude if missing_labs == 1, label("Missing baseline labs")
noisily consort exclude if age_lt18 == 1, label("Age < 18 years")
noisily consort exclude if prior_cancer == 1, label("Prior cancer diagnosis")
noisily consort exclude if lost_followup == 1, label("Lost to follow-up < 30 days")
noisily consort exclude if missing_outcome == 1, label("Missing outcome data")

log close demo

* --- 2. Graph: CONSORT flowchart ---
consort save, output("`pkg_dir'/consort_flowchart.png") ///
    final("Final Analytic Cohort") python(python3) dpi(150)

consort clear

* --- Cleanup ---
clear
