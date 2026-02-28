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

* --- Setup: load pre-processed time-varying data ---
use _data/tv_merged.dta, clear

* Merge in cohort covariates for balance assessment
merge m:1 id using _data/cohort.dta, ///
    keepusing(index_age female) nogen keep(match master)

* Encode female for numeric balance check
capture confirm numeric variable female
if _rc {
    encode female, gen(female_n)
    drop female
    rename female_n female
}

* Create binary exposure indicator (any drug use vs unexposed)
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
