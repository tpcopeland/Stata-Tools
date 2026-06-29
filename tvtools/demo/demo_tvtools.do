/*  demo_tvtools.do - Generate documentation output for tvtools

    Produces:
      1. Console output (frames-first pipeline)   -> .log -> .md via logdoc
      2. Console output (MSM weighting: IPCW)      -> .log -> .md via logdoc
      3. Console output (recurrent events PWP/AG)  -> .log -> .md via logdoc
      4. Console output (multi-group + age bands)  -> .log -> .md via logdoc
      5. Covariate-balance love plot               -> .png
      6. Exposure swimlane                         -> .png

    Highlights the v1.5.0 / v1.6.0 additions:
      - frames-first output: tvexpose/tvmerge frameout(); whole pipeline in memory
      - returned output-name macros (r(genvar), r(startname), r(generate))
      - IPCW censoring weights + combined MSM weight + positivity diagnostic
      - recurrent-event PWP/AG formatting (enum stratum + gap-time clock)
      - harmonized option names (tvage id/dob/entry/exit; tvevent start/stop)
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

* --- Graph scheme ---
capture ado uninstall tc_schemes
quietly net install tc_schemes, from("`c(pwd)'/tc_schemes") replace
set scheme plotplainblind

**# Synthetic data generation
clear
set seed 20260629

* Person-level cohort with follow-up window and baseline covariates
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

* Antidepressant exposure episodes (3 categories: Unexposed / SSRI / SNRI)
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

* Benzodiazepine exposure episodes (binary)
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

* Single-event data (outcome + competing death)
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

* Recurrent-event data (wide format: up to 3 hospitalizations per person)
use "`pkg_dir'/_cohort.dta", clear
forvalues k = 1/3 {
    gen int hosp`k' = .
}
gen int _prev = study_entry
forvalues k = 1/3 {
    gen double _u = runiform()
    replace hosp`k' = _prev + 60 + int(runiform() * 300) if _u < 0.45 & _prev + 60 < study_exit - 30
    replace _prev = hosp`k' if !missing(hosp`k')
    drop _u
}
forvalues k = 1/3 {
    format hosp`k' %tdCCYY/NN/DD
}
keep id study_entry study_exit hosp1 hosp2 hosp3
save "`pkg_dir'/_recur.dta", replace

* Longitudinal panel for the MSM weighting demo (treatment + informative censoring)
clear
set obs 400
gen long id = _n
gen double age = 40 + int(runiform() * 30)
gen byte female = rbinomial(1, 0.55)
expand 6
bysort id: gen int period = _n
gen double biomarker = rnormal() + 0.05 * period
gen double p_treat = invlogit(-0.5 + 0.4 * biomarker + 0.02 * (age - 55))
gen byte treat = runiform() < p_treat
gen double p_cens = invlogit(-2.4 + 0.5 * biomarker)
gen byte censored = runiform() < p_cens
bysort id (period): gen byte _cc = sum(censored)
drop if _cc > 1
drop _cc p_treat p_cens
label var treat "On treatment"
label var biomarker "Time-varying confounder"
save "`pkg_dir'/_panel.dta", replace

**# Frames-first pipeline (no save/use round-trips)
capture log close _all
log using "`pkg_dir'/console_pipeline.log", replace text name(pipe) nomsg

* # tvtools: Frames-First Time-Varying Pipeline

* ## Package overview
use "`pkg_dir'/_cohort.dta", clear
noisily tvtools

* ## Step 1: tvexpose -> frame (caller's data left intact)
* The exposure interval set is written to a frame; the cohort stays in memory.
* The generated variable name is returned in r(genvar).
use "`pkg_dir'/_cohort.dta", clear
noisily tvexpose using "`pkg_dir'/_episodes_antidep.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    keepvars(age female) keepdates frameout(f_antidep)
local gA = r(genvar)
noisily display "antidepressant exposure variable: " as result "`gA'"

quietly tvexpose using "`pkg_dir'/_episodes_benzo.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(benzo_use) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    keepvars(age female) keepdates frameout(f_benzo)
local gB = r(genvar)
noisily display "benzodiazepine exposure variable: " as result "`gB'"

* ## Step 2: tvdiagnose on the in-memory frame
noisily frame f_antidep: tvdiagnose, id(id) start(rx_start) stop(rx_stop) ///
    entry(study_entry) exit(study_exit) coverage gaps

* ## Step 3: tvmerge reads both frames, writes a merged frame
noisily tvmerge, frames(f_antidep f_benzo) id(id) ///
    start(rx_start rx_start) stop(rx_stop rx_stop) ///
    exposure(`gA' `gB') frameout(f_merged)
noisily display "merged interval vars: " as result "`r(startname)' / `r(stopname)'"

* ## Step 4: tvevent reads the merged frame, adds the outcome in memory
use "`pkg_dir'/_events.dta", clear
noisily tvevent, frame(f_merged) id(id) ///
    date(cv_event_date) compete(death_date) generate(outcome)
noisily display "event indicator: " as result "`r(generate)'" ///
    "   intervals: " as result "`r(startvar)'/`r(stopvar)'"

log close pipe

**# Marginal structural model weighting with IPCW
log using "`pkg_dir'/console_msm.log", replace text name(msm) nomsg

* # MSM Weighting: IPTW x IPCW + Positivity

* ## Combined treatment + censoring weights
* tvweight fits a propensity model and (with ipcw()) a censoring model, then
* forms the cumulative IPTW x IPCW weight that a marginal structural model needs.
* A positivity / overlap block reports near-violations and weight concentration.
use "`pkg_dir'/_panel.dta", clear
noisily tvweight treat, covariates(age female biomarker) ///
    id(id) time(period) ipcw(censored) censorcovariates(age biomarker) ///
    stabilized generate(iptw) balance nolog
noisily display "combined-weight ESS: " as result %6.1f r(ess_combined) ///
    "   positivity near-violations: " as result %4.1f r(pct_nonoverlap) "%"

log close msm

**# Recurrent-event PWP / AG formatting
log using "`pkg_dir'/console_recurrent.log", replace text name(rec) nomsg

* # Recurrent Events: PWP / Andersen-Gill Formatting

* ## tvevent type(recurring) with enum stratum + gap-time clock
* The base follow-up interval is split at each hospitalization; tvevent adds the
* event-sequence stratum (enum) and a gap-time clock that resets at each event,
* so the output feeds Andersen-Gill, PWP total-time, and PWP gap-time models.
use "`pkg_dir'/_recur.dta", clear
rename study_entry win_start
rename study_exit win_stop
keep id win_start win_stop
tempfile recint
save "`recint'"

use "`pkg_dir'/_recur.dta", clear
keep id hosp1 hosp2 hosp3
noisily tvevent using "`recint'", id(id) date(hosp) type(recurring) ///
    generate(hosp_ev) start(win_start) stop(win_stop) ///
    enum(stratum) gaptime gapstart(t0) gapstop(t) timegen(tstop) timeunit(days)
noisily display "stratum var: " as result "`r(enum)'" ///
    "   gap-time clock: " as result "`r(gapstart)'/`r(gapstop)'"

* ## A few persons with repeated events
noisily list id win_start win_stop hosp_ev stratum t0 t in 1/12, ///
    sepby(id) noobs abbreviate(12)

log close rec

**# Multi-group weighting + age bands
log using "`pkg_dir'/console_multigroup.log", replace text name(mg) nomsg

* # Multi-Group Weighting and Age Bands

* ## tvweight with multinomial logit (3 treatment categories)
use "`pkg_dir'/_cohort.dta", clear
quietly tvexpose using "`pkg_dir'/_episodes_antidep.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    keepvars(age female) keepdates
noisily tvweight tv_drug, covariates(age female) ///
    generate(iptw_mg) model(mlogit) stabilized truncate(1 99) nolog

* ## tvage with harmonized option names (id/dob/entry/exit)
use "`pkg_dir'/_cohort.dta", clear
noisily tvage, id(id) dob(dob) entry(study_entry) exit(study_exit) ///
    groupwidth(5) minage(40) maxage(80)

log close mg

**# Graphs
* Covariate-balance love plot from the MSM weighting step
use "`pkg_dir'/_panel.dta", clear
quietly tvweight treat, covariates(age female biomarker) ///
    id(id) time(period) ipcw(censored) censorcovariates(age biomarker) ///
    stabilized generate(iptw) balance loveplot nolog
graph export "`pkg_dir'/balance_loveplot.png", replace width(1400)
capture graph close _all

* Exposure swimlane for a sample of persons
use "`pkg_dir'/_cohort.dta", clear
quietly tvexpose using "`pkg_dir'/_episodes_antidep.dta", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) keepdates
quietly tvdiagnose, id(id) start(rx_start) stop(rx_stop) ///
    exposure(tv_drug) swimlane maxids(12)
graph export "`pkg_dir'/swimlane_plot.png", replace width(1400)
capture graph close _all

**# Convert console logs to markdown with logdoc
capture ado uninstall logdoc
quietly net install logdoc, from("`c(pwd)'/logdoc") replace

foreach lg in console_pipeline console_msm console_recurrent console_multigroup {
    logdoc using "`pkg_dir'/`lg'.log", ///
        output("`pkg_dir'/`lg'.md") ///
        nodots toc replace
}

* --- Cleanup temp data ---
foreach f in _cohort _episodes_antidep _episodes_benzo _events _recur _panel {
    capture erase "`pkg_dir'/`f'.dta"
}

clear
