/*  demo_consort.do - Demo output for consort

    Produces:
      1. Graph (CONSORT flowchart, default style) -> consort_flowchart.png
      2. Graph (CONSORT flowchart, shaded + high DPI) -> consort_shaded.png
      3. Machine-readable data export (resolved one-row-per-node table)
         -> flow.csv + flow.xlsx   [v1.1.0 feature]

    Run from the Stata-Tools repo root:
      stata-mp -b do consort/demo/demo_consort.do
*/

version 16.0
set more off
set varabbrev off
set linesize 120

* --- Paths ---
local pkg_dir "consort/demo"
capture mkdir "`pkg_dir'"

* --- Install package from local source ---
capture ado uninstall consort
quietly net install consort, from("`c(pwd)'/consort") replace

**# Example 1: Standard workflow with milestone labels
* Synthetic retrospective database cohort (45,892 patients)
clear
set obs 45892
gen double id = _n

* Non-overlapping exclusion indicators
gen byte missing_labs    = (_n <= 3241)
gen byte age_lt18        = (_n >= 3242 & _n <= 4133)
gen byte prior_cancer    = (_n >= 4134 & _n <= 6238)
gen byte lost_followup   = (_n >= 6239 & _n <= 6805)
gen byte missing_outcome = (_n >= 6806 & _n <= 8698)

preserve

consort init, initial("Patients in database 2015-2023")
consort exclude if missing_labs == 1, label("Missing baseline labs")
consort exclude if age_lt18 == 1, ///
    label("Age < 18 years") remaining("Adult cohort")
consort exclude if prior_cancer == 1, label("Prior cancer diagnosis")
consort exclude if lost_followup == 1, ///
    label("Lost to follow-up < 30 days") remaining("Minimum follow-up met")
consort exclude if missing_outcome == 1, label("Missing outcome data")

consort save, output("`pkg_dir'/consort_flowchart.png") ///
    final("Final Analytic Cohort") dpi(150)

restore

**# Example 2: Shaded flowchart with publication-quality DPI
preserve

consort init, initial("Patients in database 2015-2023")
consort exclude if missing_labs == 1, label("Missing baseline labs")
consort exclude if age_lt18 == 1, label("Age < 18 years")
consort exclude if prior_cancer == 1, label("Prior cancer diagnosis")
consort exclude if lost_followup == 1, label("Lost to follow-up < 30 days")
consort exclude if missing_outcome == 1, label("Missing outcome data")

consort save, output("`pkg_dir'/consort_shaded.png") ///
    final("Final Analytic Cohort") shading dpi(300)

restore

**# Example 3: Machine-readable data export (v1.1.0)
* csv()/xlsx() write a resolved, one-row-per-node table that mirrors the figure
* exactly, so the flowchart can be read without parsing the image. Uses the
* built-in auto data so the exported table matches the README example.
sysuse auto, clear
preserve

consort init, initial("Cars in auto.dta")
consort exclude if missing(rep78), ///
    label("Missing repair record") remaining("Cars with repair data")
consort exclude if foreign, label("Foreign cars")
consort save, output("`pkg_dir'/consort_export.png") ///
    final("Domestic sample") ///
    csv("`pkg_dir'/flow.csv") xlsx("`pkg_dir'/flow.xlsx")

restore

* --- Cleanup ---
clear
