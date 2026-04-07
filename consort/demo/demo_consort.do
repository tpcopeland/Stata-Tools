/*  demo_consort.do - Generate screenshots for consort

    Produces 3 output types:
      1. Console output (exclusion steps + summary) -> .smcl
      2. Graph (CONSORT flowchart, default style) -> .png
      3. Graph (CONSORT flowchart, shaded + high DPI) -> .png
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
capture program drop _consort_clear_state
capture program drop _consort_find_script
capture program drop _consort_update_final
quietly run consort/consort.ado

* =============================================================================
* EXAMPLE 1: Standard workflow with milestone labels
* =============================================================================
* Synthetic data: retrospective database cohort (45,892 patients)

clear
set obs 45892
gen double id = _n

* Create non-overlapping exclusion indicators
gen byte missing_labs    = (_n <= 3241)
gen byte age_lt18        = (_n >= 3242  & _n <= 4133)
gen byte prior_cancer    = (_n >= 4134  & _n <= 6238)
gen byte lost_followup   = (_n >= 6239  & _n <= 6805)
gen byte missing_outcome = (_n >= 6806  & _n <= 8698)

* Preserve data so it is restored after the CONSORT workflow
preserve

* Console output: show init, exclude steps, and save summary
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg

* Initialize diagram
noisily consort init, initial("Patients in database 2015-2023")

* Apply exclusions with milestone labels on key steps
noisily consort exclude if missing_labs == 1, ///
    label("Missing baseline labs")
noisily consort exclude if age_lt18 == 1, ///
    label("Age < 18 years") remaining("Adult cohort")
noisily consort exclude if prior_cancer == 1, ///
    label("Prior cancer diagnosis")
noisily consort exclude if lost_followup == 1, ///
    label("Lost to follow-up < 30 days") remaining("Minimum follow-up met")
noisily consort exclude if missing_outcome == 1, ///
    label("Missing outcome data")

log close demo

* Generate default-style flowchart
noisily consort save, output("`pkg_dir'/consort_flowchart.png") ///
    final("Final Analytic Cohort") dpi(150)

* Restore original data
restore

* =============================================================================
* EXAMPLE 2: Shaded flowchart with high DPI
* =============================================================================

preserve

consort init, initial("Patients in database 2015-2023")
consort exclude if missing_labs == 1, label("Missing baseline labs")
consort exclude if age_lt18 == 1, label("Age < 18 years")
consort exclude if prior_cancer == 1, label("Prior cancer diagnosis")
consort exclude if lost_followup == 1, label("Lost to follow-up < 30 days")
consort exclude if missing_outcome == 1, label("Missing outcome data")

* Shaded style with publication-quality DPI
consort save, output("`pkg_dir'/consort_shaded.png") ///
    final("Final Analytic Cohort") shading dpi(300)

restore

* --- Cleanup ---
clear
