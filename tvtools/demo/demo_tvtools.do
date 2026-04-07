/*  demo_tvtools.do - Generate screenshots for tvtools

    Produces 2 output types:
      1. Console output (tvtools overview) -> .smcl
      2. Console output (tvexpose + tvdiagnose + tvweight workflow) -> .smcl
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

capture program drop tvexpose
quietly run tvtools/tvexpose.ado

capture program drop _tvexpose_mata
quietly run tvtools/_tvexpose_mata.ado

capture program drop _tvexpose_diagnose
quietly run tvtools/_tvexpose_diagnose.ado

capture program drop tvdiagnose
quietly run tvtools/tvdiagnose.ado

capture program drop tvweight
quietly run tvtools/tvweight.ado

* --- Generate synthetic cohort data ---
clear
set seed 20260325

* 200 patients with study entry/exit
set obs 200
gen long id = _n
gen int study_entry = mdy(1, 1, 2015) + int(runiform() * 365)
gen int study_exit  = study_entry + 365 + int(runiform() * 1460)
format study_entry study_exit %tdCCYY/NN/DD

* Baseline covariates
gen byte female = rbinomial(1, 0.55)
gen double age = 40 + int(runiform() * 30)

save "`pkg_dir'/_cohort_demo.dta", replace

* --- Generate exposure episodes ---
expand 1 + int(runiform() * 4)
bysort id: gen int seq = _n
bysort id: gen int duration = 60 + int(runiform() * 300)
bysort id: gen int rx_start = study_entry if seq == 1
bysort id: replace rx_start = rx_start[_n-1] + duration[_n-1] + int(runiform() * 60) if seq > 1
gen int rx_stop = rx_start + duration
format rx_start rx_stop %tdCCYY/NN/DD

* Exposure: 0=unexposed, 1=SSRI, 2=SNRI
gen double p_exposed = invlogit(-1 + 0.02 * age + 0.3 * female)
gen byte drug = 0
replace drug = 1 + int(runiform() * 2) if runiform() < p_exposed
label define drug_lbl 0 "Unexposed" 1 "SSRI" 2 "SNRI"
label values drug drug_lbl
drop p_exposed seq duration

keep id rx_start rx_stop drug
save "`pkg_dir'/_episodes_demo.dta", replace

* --- 1. Console output: tvtools overview ---
use "`pkg_dir'/_cohort_demo.dta", clear

log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg

noisily tvtools, detail

* --- 2. Workflow: tvexpose -> tvdiagnose -> tvweight ---
noisily tvexpose using "`pkg_dir'/_episodes_demo.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit)

noisily tvdiagnose, id(id) start(start) stop(stop) ///
    entry(study_entry) exit(study_exit) coverage gaps

gen byte any_drug = (tv_exposure != 0) if !missing(tv_exposure)

noisily tvweight any_drug, covariates(age female) ///
    generate(iptw) stabilized nolog

log close demo

* --- Cleanup temp data ---
capture erase "`pkg_dir'/_cohort_demo.dta"
capture erase "`pkg_dir'/_episodes_demo.dta"

clear
