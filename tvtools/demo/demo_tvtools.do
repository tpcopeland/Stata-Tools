/*  demo_tvtools.do - Generate screenshots for tvtools

    Produces 3 output types:
      1. Console output (tvtools overview + tvbalance) -> .smcl
      2. Graph (tvplot swimlane) -> .png
      3. Graph (tvplot person-time) -> .png
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "tvtools/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload commands ---
capture program drop tvtools
quietly run tvtools/tvtools.ado

capture program drop tvbalance
quietly run tvtools/tvbalance.ado

capture program drop tvplot
quietly run tvtools/tvplot.ado

* --- Generate synthetic time-varying exposure data ---
* 200 patients, each with 3-8 time periods of varying drug exposure
clear
set seed 20260301

* Step 1: Create patient-level covariates
set obs 200
gen int id = _n
gen byte female = rbinomial(1, 0.55)
gen double index_age = 40 + int(runiform() * 30)
gen int base_date = mdy(1, 1, 2015) + int(runiform() * 365)
format base_date %td
gen int n_periods = 3 + int(runiform() * 6)

* Step 2: Expand to person-period panel
expand n_periods
bysort id: gen int period = _n

* Step 3: Create non-overlapping intervals with varying duration
bysort id: gen int duration = 30 + int(runiform() * 150)
bysort id: gen double start = base_date if period == 1
bysort id: replace start = start[_n-1] + duration[_n-1] if period > 1
gen double stop = start + duration
format start stop %td
drop base_date n_periods duration

* Step 4: Assign drug classes (0=unexposed, 1-3=different drugs)
* Higher-age patients more likely to be exposed
gen double p_exposed = invlogit(-1.5 + 0.02 * index_age + 0.3 * female)
gen byte drug_class = 0
replace drug_class = 1 + int(runiform() * 3) if runiform() < p_exposed
label define drug_lbl 0 "Unexposed" 1 "SSRI" 2 "SNRI" 3 "TCA"
label values drug_class drug_lbl
drop p_exposed period

* Step 5: Create binary exposure indicator
gen byte any_drug = (drug_class != 0) if !missing(drug_class)

* --- 1. Console output: tvtools overview + balance diagnostics ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg
noisily tvtools, detail
noisily tvbalance index_age female, exposure(any_drug)

log close demo

* --- 2. Graph: swimlane plot ---
tvplot, id(id) start(start) stop(stop) exposure(drug_class) ///
    swimlane sample(25) ///
    title("Antidepressant Treatment Timelines") ///
    saving("`pkg_dir'/swimlane_plot.png") replace ///
    scheme(plotplainblind)
capture graph close _all

* --- 3. Graph: person-time bar chart ---
tvplot, id(id) start(start) stop(stop) exposure(drug_class) ///
    persontime ///
    title("Person-Time by Drug Class") ///
    saving("`pkg_dir'/persontime_plot.png") replace ///
    scheme(plotplainblind)
capture graph close _all

* --- Cleanup ---
clear
