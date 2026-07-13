/*  demo_tvtools.do - Generate documentation output for tvtools

    Produces:
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

* --- Transactional session setup ---
local demo_more = c(more)
local demo_varabbrev = c(varabbrev)
local demo_linesize = c(linesize)
local demo_scheme "`c(scheme)'"
local demo_frame "`c(frame)'"
local demo_preserved = 0
capture preserve
if _rc == 0 local demo_preserved = 1

set more off
set varabbrev off
set linesize 120

* Locate the demo output directory without assuming a repository location.
* The optional first argument is useful when the do-file is launched elsewhere.
args demo_dir
if `"`demo_dir'"' == "" {
    local launch_dir "`c(pwd)'"
    foreach candidate in "`launch_dir'" "`launch_dir'/demo" ///
        "`launch_dir'/../demo" "`launch_dir'/tvtools/demo" {
        if `"`demo_dir'"' == "" {
            capture confirm file "`candidate'/demo_tvtools.do"
            if _rc == 0 local demo_dir "`candidate'"
        }
    }
}

tempfile cohort episodes_antidep episodes_benzo events recur panel ///
    caller_love_graph caller_swim_graph
tempname f_antidep f_benzo f_merged demo_balance ///
    demo_love_graph demo_swim_graph
local demo_had_love_graph = 0
local demo_had_swim_graph = 0
local demo_graph_snapshot_rc = 0

* The commands use stable public graph names. Preserve any caller graphs with
* those names before the demo temporarily takes ownership of them.
capture graph describe tvw_loveplot
if _rc == 0 {
    capture quietly graph save tvw_loveplot "`caller_love_graph'", replace
    if _rc local demo_graph_snapshot_rc = _rc
    else {
        local demo_had_love_graph = 1
        capture graph drop tvw_loveplot
        if _rc local demo_graph_snapshot_rc = _rc
    }
}
capture graph describe tvd_swimlane
if _rc == 0 {
    capture quietly graph save tvd_swimlane "`caller_swim_graph'", replace
    if _rc local demo_graph_snapshot_rc = _rc
    else {
        local demo_had_swim_graph = 1
        capture graph drop tvd_swimlane
        if _rc local demo_graph_snapshot_rc = _rc
    }
}

capture noisily {
    if `demo_graph_snapshot_rc' {
        display as error "could not preserve caller graph state"
        exit `demo_graph_snapshot_rc'
    }
    if `"`demo_dir'"' == "" {
        display as error "could not locate demo_tvtools.do; pass its directory as the first argument"
        exit 601
    }
    which tvtools

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
gen int dob = mdy(month(study_entry), day(study_entry), ///
    year(study_entry) - age)
format dob %tdCCYY/NN/DD
save "`cohort'", replace

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
save "`episodes_antidep'", replace

* Benzodiazepine exposure episodes (binary)
use "`cohort'", clear
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
save "`episodes_benzo'", replace

* Single-event data (outcome + competing death)
use "`cohort'", clear
gen double p_event = invlogit(-3 + 0.01 * age)
gen byte has_event = runiform() < p_event
gen int cv_event_date = study_entry + int(runiform() * (study_exit - study_entry)) if has_event
format cv_event_date %tdCCYY/NN/DD
gen double p_death = invlogit(-4 + 0.015 * age)
gen byte has_death = runiform() < p_death & !has_event
gen int death_date = study_entry + int(runiform() * (study_exit - study_entry)) if has_death
format death_date %tdCCYY/NN/DD
keep id cv_event_date death_date
save "`events'", replace

* Recurrent-event data (wide format: up to 3 hospitalizations per person)
use "`cohort'", clear
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
save "`recur'", replace

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
save "`panel'", replace

**# Frames-first pipeline (no save/use round-trips)

* # tvtools: Frames-First Time-Varying Pipeline

* ## Package overview
use "`cohort'", clear
noisily tvtools

* ## Step 1: tvexpose -> frame (caller's data left intact)
* The exposure interval set is written to a frame; the cohort stays in memory.
* The generated variable name is returned in r(genvar).
use "`cohort'", clear
noisily tvexpose using "`episodes_antidep'", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    keepvars(age female) keepdates frameout(`f_antidep')
local gA = r(genvar)
noisily display "antidepressant exposure variable: " as result "`gA'"

quietly tvexpose using "`episodes_benzo'", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(benzo_use) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    keepvars(age female) keepdates frameout(`f_benzo')
local gB = r(genvar)
noisily display "benzodiazepine exposure variable: " as result "`gB'"

* ## Step 2: tvdiagnose on the in-memory frame
noisily frame `f_antidep': tvdiagnose, id(id) start(rx_start) stop(rx_stop) ///
    entry(study_entry) exit(study_exit) coverage gaps

* ## Step 3: tvmerge reads both frames, writes a merged frame
noisily tvmerge, frames(`f_antidep' `f_benzo') id(id) ///
    start(rx_start rx_start) stop(rx_stop rx_stop) ///
    exposure(`gA' `gB') frameout(`f_merged')
noisily display "merged interval vars: " as result "`r(startname)' / `r(stopname)'"

* ## Step 4: tvevent reads the merged frame, adds the outcome in memory
use "`events'", clear
noisily tvevent, frame(`f_merged') id(id) ///
    date(cv_event_date) compete(death_date) generate(outcome)
noisily display "event indicator: " as result "`r(generate)'" ///
    "   intervals: " as result "`r(startvar)'/`r(stopvar)'"


**# Marginal structural model weighting with IPCW

* # MSM Weighting: IPTW x IPCW + Positivity

* ## Combined treatment + censoring weights
* tvweight fits a propensity model and (with ipcw()) a censoring model, then
* forms the cumulative IPTW x IPCW weight that a marginal structural model needs.
* A positivity / overlap block reports near-violations and weight concentration.
use "`panel'", clear
noisily tvweight treat, covariates(age female biomarker) ///
    id(id) time(period) ipcw(censored) censorcovariates(age biomarker) ///
    stabilized generate(iptw) balance nolog
noisily display "combined-weight ESS: " as result %6.1f r(ess_combined) ///
    "   positivity near-violations: " as result %4.1f r(pct_nonoverlap) "%"


**# Recurrent-event PWP / AG formatting

* # Recurrent Events: PWP / Andersen-Gill Formatting

* ## tvevent type(recurring) with enum stratum + gap-time clock
* The base follow-up interval is split at each hospitalization; tvevent adds the
* event-sequence stratum (enum) and a gap-time clock that resets at each event,
* so the output feeds Andersen-Gill, PWP total-time, and PWP gap-time models.
use "`recur'", clear
rename study_entry win_start
rename study_exit win_stop
keep id win_start win_stop
tempfile recint
save "`recint'"

use "`recur'", clear
keep id hosp1 hosp2 hosp3
noisily tvevent using "`recint'", id(id) date(hosp) type(recurring) ///
    generate(hosp_ev) start(win_start) stop(win_stop) ///
    enum(stratum) gaptime gapstart(t0) gapstop(t) timegen(tstop) timeunit(days)
noisily display "stratum var: " as result "`r(enum)'" ///
    "   gap-time clock: " as result "`r(gapstart)'/`r(gapstop)'"

* ## A few persons with repeated events
noisily list id win_start win_stop hosp_ev stratum t0 t in 1/12, ///
    sepby(id) noobs abbreviate(12)


**# Multi-group weighting + age bands

* # Multi-Group Weighting and Age Bands

* ## tvweight with multinomial logit (3 treatment categories)
use "`cohort'", clear
quietly tvexpose using "`episodes_antidep'", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    keepvars(age female) keepdates
noisily tvweight tv_drug, covariates(age female) ///
    generate(iptw_mg) model(mlogit) stabilized truncate(1 99) nolog

* ## tvage with harmonized option names (id/dob/entry/exit)
use "`cohort'", clear
noisily tvage, id(id) dob(dob) entry(study_entry) exit(study_exit) ///
    groupwidth(5) minage(40) maxage(80)


**# Graphs
* Covariate-balance love plot from the MSM weighting step
use "`panel'", clear
quietly tvweight treat, covariates(age female biomarker) ///
    id(id) time(period) ipcw(censored) censorcovariates(age biomarker) ///
    stabilized generate(iptw) balance loveplot nolog
local demo_love_created = r(loveplot_created)
if `demo_love_created' {
    graph rename tvw_loveplot `demo_love_graph', replace
}
else {
    * psdash is optional.  Build the documentation asset from tvweight's
    * returned balance matrix when that package is not installed.
    matrix `demo_balance' = r(balance)
    local demo_terms : rownames `demo_balance'
    local demo_n = rowsof(`demo_balance')
    clear
    svmat double `demo_balance', names(demo_smd)
    generate int demo_order = _n
    local demo_ylabs ""
    forvalues j = 1/`demo_n' {
        local demo_term : word `j' of `demo_terms'
        local demo_ylabs `"`demo_ylabs' `j' "`demo_term'""'
    }
    twoway ///
        (scatter demo_order demo_smd1, msymbol(O) mcolor(navy)) ///
        (scatter demo_order demo_smd2, msymbol(D) mcolor(maroon)), ///
        yscale(reverse) ylabel(`demo_ylabs', angle(horizontal)) ///
        xline(-.1 .1, lpattern(dash) lcolor(gs8)) ///
        xtitle("Standardized mean difference") ytitle("") ///
        legend(order(1 "Unweighted" 2 "Weighted")) ///
        title("Covariate balance") name(`demo_love_graph', replace)
}
capture graph describe `demo_love_graph'
if _rc != 0 {
    display as error "tvweight loveplot did not leave an exportable graph"
    exit 498
}
graph display `demo_love_graph'
capture noisily graph export "`demo_dir'/balance_loveplot.png", ///
    replace width(1400)
if _rc != 0 {
    display as error "tvweight loveplot did not leave an exportable graph"
    exit 603
}
capture graph drop `demo_love_graph'

* Exposure swimlane for a sample of persons
use "`cohort'", clear
quietly tvexpose using "`episodes_antidep'", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) reference(0) ///
    entry(study_entry) exit(study_exit) keepdates
quietly tvdiagnose, id(id) start(rx_start) stop(rx_stop) ///
    exposure(tv_drug) swimlane maxids(12)
if r(graph_created) != 1 {
    display as error "tvdiagnose did not create the requested swimlane graph"
    exit 498
}
capture graph describe tvd_swimlane
if _rc != 0 {
    display as error "tvdiagnose did not leave the named swimlane graph"
    exit 498
}
graph rename tvd_swimlane `demo_swim_graph', replace
graph display `demo_swim_graph'
capture noisily graph export "`demo_dir'/swimlane_plot.png", ///
    replace width(1400)
if _rc != 0 {
    display as error "tvdiagnose swimlane did not leave an exportable graph"
    exit 603
}
capture graph drop `demo_swim_graph'
}
local demo_rc = _rc

* --- Unconditional cleanup and session restoration ---
capture graph drop tvw_loveplot
capture graph drop tvd_swimlane
capture graph drop `demo_love_graph'
capture graph drop `demo_swim_graph'
if `demo_had_love_graph' {
    capture graph use "`caller_love_graph'", ///
        name(tvw_loveplot, replace)
}
if `demo_had_swim_graph' {
    capture graph use "`caller_swim_graph'", ///
        name(tvd_swimlane, replace)
}
capture matrix drop `demo_balance'
capture frame change `demo_frame'
foreach frame_name in `f_antidep' `f_benzo' `f_merged' {
    capture frame drop `frame_name'
}
if `demo_preserved' capture restore
capture set more `demo_more'
capture set varabbrev `demo_varabbrev'
capture set linesize `demo_linesize'
capture set scheme `demo_scheme'
capture frame change `demo_frame'

if `demo_rc' exit `demo_rc'
