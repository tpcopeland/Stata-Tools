/*  demo_tvtools.do - Generate documentation output for tvtools

    Produces:
      1. Console output (binary treatment pipeline) -> .log -> .md via logdoc
      2. Console output (multi-group treatment)     -> .log -> .md via logdoc

    Sections:
      Binary:      tvtools index, tvexpose, tvdiagnose, tvmerge, tvevent,
                   tvweight (binary), tvage
      Multi-group: tvexpose (3 categories), tvweight (mlogit, stabilized,
                   truncated)
*/

version 16.0
set varabbrev off
set linesize 120

* --- Paths ---
local pkg_dir "tvtools/demo"
capture mkdir "`pkg_dir'"

* --- Install from local source ---
capture ado uninstall tvtools
quietly net install tvtools, from("`c(pwd)'/tvtools") replace

* --- Generate synthetic cohort ---
clear
set seed 20260408

set obs 200
gen long id = _n
gen int study_entry = mdy(1, 1, 2015) + int(runiform() * 365)
gen int study_exit  = study_entry + 365 + int(runiform() * 1460)
format study_entry study_exit %tdCCYY/NN/DD
gen byte female = rbinomial(1, 0.55)
gen double age = 40 + int(runiform() * 30)
gen int dob = study_entry - int(age * 365.25)
format dob %tdCCYY/NN/DD
save "`pkg_dir'/_cohort.dta", replace

* --- Generate antidepressant exposure episodes ---
expand 1 + int(runiform() * 4)
bysort id: gen int seq = _n
bysort id: gen int duration = 60 + int(runiform() * 300)
bysort id: gen int rx_start = study_entry if seq == 1
bysort id: replace rx_start = rx_start[_n-1] + duration[_n-1] + int(runiform() * 60) if seq > 1
gen int rx_stop = rx_start + duration
format rx_start rx_stop %tdCCYY/NN/DD
gen double p_exposed = invlogit(-1 + 0.02 * age + 0.3 * female)
gen byte drug = 0
replace drug = 1 + int(runiform() * 2) if runiform() < p_exposed
label define drug_lbl 0 "Unexposed" 1 "SSRI" 2 "SNRI"
label values drug drug_lbl
drop p_exposed seq duration
keep id rx_start rx_stop drug
save "`pkg_dir'/_episodes_antidep.dta", replace

* --- Generate benzodiazepine exposure episodes ---
use "`pkg_dir'/_cohort.dta", clear
expand 1 + int(runiform() * 2)
bysort id: gen int seq = _n
bysort id: gen int duration = 30 + int(runiform() * 120)
bysort id: gen int rx_start = study_entry + int(runiform() * 180) if seq == 1
bysort id: replace rx_start = rx_start[_n-1] + duration[_n-1] + int(runiform() * 90) if seq > 1
gen int rx_stop = rx_start + duration
format rx_start rx_stop %tdCCYY/NN/DD
gen byte benzo_use = runiform() < 0.35
label define benzo_lbl 0 "No benzo" 1 "Benzo"
label values benzo_use benzo_lbl
drop seq duration
keep id rx_start rx_stop benzo_use
save "`pkg_dir'/_episodes_benzo.dta", replace

* --- Generate event data ---
use "`pkg_dir'/_cohort.dta", clear
gen double p_event = invlogit(-3 + 0.01 * age)
gen byte has_event = runiform() < p_event
gen int cv_event_date = study_entry + int(runiform() * (study_exit - study_entry)) if has_event
format cv_event_date %tdCCYY/NN/DD
gen double p_death = invlogit(-4 + 0.015 * age)
gen byte has_death = runiform() < p_death & !has_event
gen int death_date = study_entry + int(runiform() * (study_exit - study_entry)) if has_death
format death_date %tdCCYY/NN/DD
keep id cv_event_date death_date
save "`pkg_dir'/_events.dta", replace

**# Binary treatment pipeline
capture log close _all
log using "`pkg_dir'/console_output.log", replace text name(demo) nomsg

* # tvtools: Time-Varying Exposure Analysis

* ## Package overview
use "`pkg_dir'/_cohort.dta", clear
noisily tvtools

* ## Step 1: Create exposure intervals with tvexpose
use "`pkg_dir'/_cohort.dta", clear
noisily tvexpose using "`pkg_dir'/_episodes_antidep.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    keepvars(age female) keepdates
save "`pkg_dir'/_tv_antidep.dta", replace

* ## Step 2: Diagnose the interval dataset
noisily tvdiagnose, id(id) start(rx_start) stop(rx_stop) ///
    entry(study_entry) exit(study_exit) all

* ## Step 3: Merge two exposure streams
use "`pkg_dir'/_cohort.dta", clear
quietly tvexpose using "`pkg_dir'/_episodes_benzo.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(benzo_use) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    keepvars(age female) keepdates
save "`pkg_dir'/_tv_benzo.dta", replace

noisily tvmerge "`pkg_dir'/_tv_antidep.dta" "`pkg_dir'/_tv_benzo.dta", ///
    id(id) ///
    start(rx_start rx_start) stop(rx_stop rx_stop) ///
    exposure(tv_exposure tv_exposure) ///
    generate(antidep benzo) ///
    keep(age female)

* ## Step 4: Add events and competing risks
use "`pkg_dir'/_events.dta", clear
noisily tvevent using "`pkg_dir'/_tv_antidep.dta", id(id) ///
    date(cv_event_date) compete(death_date) ///
    generate(outcome) startvar(rx_start) stopvar(rx_stop)

* ## Step 5: Estimate IPTW weights (binary)
use "`pkg_dir'/_tv_antidep.dta", clear
gen byte any_drug = (tv_exposure != 0) if !missing(tv_exposure)
noisily tvweight any_drug, covariates(age female) ///
    generate(iptw) stabilized nolog

* ## Step 6: Create age-band intervals
use "`pkg_dir'/_cohort.dta", clear
noisily tvage, idvar(id) dobvar(dob) entryvar(study_entry) exitvar(study_exit) ///
    groupwidth(5) minage(40) maxage(80) ///
    saveas("`pkg_dir'/_age_tv.dta") replace

log close demo

**# Multi-group treatment weighting
log using "`pkg_dir'/console_multigroup.log", replace text name(mg) nomsg

* # Multi-Group Treatment Weighting

* ## Step 1: tvexpose with 3 treatment categories
use "`pkg_dir'/_cohort.dta", clear
noisily tvexpose using "`pkg_dir'/_episodes_antidep.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    keepvars(age female) keepdates

* ## Step 2: tvweight with multinomial logit
noisily tvweight tv_exposure, covariates(age female) ///
    generate(iptw_mg) model(mlogit) stabilized truncate(1 99) nolog

log close mg

* --- Convert to Markdown with logdoc ---
capture ado uninstall logdoc
quietly net install logdoc, from("`c(pwd)'/logdoc") replace

logdoc using "`pkg_dir'/console_output.log", ///
    output("`pkg_dir'/console_output.md") ///
    nodots toc replace

logdoc using "`pkg_dir'/console_multigroup.log", ///
    output("`pkg_dir'/console_multigroup.md") ///
    nodots toc replace

* --- Cleanup temp data ---
foreach f in _cohort _episodes_antidep _episodes_benzo _events _tv_antidep _tv_benzo _age_tv {
    capture erase "`pkg_dir'/`f'.dta"
}

clear
