/*  demo_tvtools.do - Generate documentation output for tvtools (v1.13.1)

    Console assets produced (.log -> .md via logdoc):
      1. Frames-first primitives                   -> console_primitives.{log,md}
      2. tvbuild, the same route as one call       -> console_tvbuild.{log,md}
      3. MSM weighting: IPTW x IPCW + positivity   -> console_msm.{log,md}
      4. Recurrent-event PWP / AG formatting       -> console_recurrent.{log,md}
      5. Multi-group weighting + age bands         -> console_multigroup.{log,md}

    Graph assets produced:
      1. Covariate-balance love plot               -> balance_loveplot.png
      2. Exposure swimlane                         -> swimlane_plot.png

    Every command in the suite is shown the same way: a heading, the call as
    the user types it, and the command's own console report. tvbuild is one of
    those sections rather than an appendix -- it is demonstrated on the same
    cohort and the same raw episode files the primitive route consumes, in
    both its one-source shortcut form and its multi-source specification form,
    and the two routes are compared with cf.

    The demo walks the whole suite end to end:
      - frames-first output: tvexpose/tvmerge frameout(); whole workflow in memory
      - returned output-name macros (r(genvar), r(startname), r(generate))
      - the same construction as one tvbuild call, verified equal to the
        primitive route with cf rather than asserted in prose
      - IPCW censoring weights + combined MSM weight + positivity diagnostic
      - recurrent-event PWP/AG formatting (enum stratum + gap-time clock)
      - harmonized option names (tvage id/dob/entry/exit; tvevent start/stop)

    Graph styling: the demo saves and restores c(scheme) but never sets one,
    so the plots render in whatever scheme the caller selected beforehand.
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

tempfile cohort events recur panel ///
    primitive_out prim_cmp build_cmp caller_love_graph caller_swim_graph

* The two raw episode extracts are NAMED files in the working directory rather
* than tempfiles. tvbuild's plan display and tvspec list both echo the source
* locator they were handed, and a tempfile's locator is a PID-stamped /tmp
* path -- so with tempfiles the published console assets carried seven absolute
* paths that differed on every machine and every run, and console_tvbuild.md
* re-diffed on every regeneration for no semantic reason. A relative name is
* echoed verbatim and is the same string everywhere.
*
* Named files lose tempfile's auto-erase, so they take the same discipline as
* the literal frames below: refuse to start if one already exists, and erase
* them in the unconditional cleanup, gated on having created them.
local episodes_antidep "tvdemo_episodes_antidep.dta"
local episodes_benzo   "tvdemo_episodes_benzo.dta"
local demo_files "`episodes_antidep' `episodes_benzo'"
* f_cmp stays a tempname: it holds the comparison copy and never appears in any
* published console asset. Every frame the demo does show the reader is a
* readable literal instead, so the reports quote names a user could retype.
tempname f_cmp demo_balance demo_love_graph demo_swim_graph
local demo_had_love_graph = 0
local demo_had_swim_graph = 0
local demo_graph_snapshot_rc = 0

* Literal frame names lose tempname's auto-drop, so the demo has to prove it
* owns each one before it writes to it. The tvdemo_ prefix keeps the namespace
* implausible for a caller to already hold, but implausible is not empty: if any
* of them exists the demo refuses to start rather than replacing a frame it did
* not create. demo_owns_frames gates the cleanup drop for exactly this case --
* aborting on a clash and then dropping the caller's frames in cleanup would
* destroy the data the check exists to protect.
local demo_frames tvdemo_antidep tvdemo_benzo tvdemo_merged ///
    tvdemo_full tvdemo_full_manifest ///
    tvdemo_analysis tvdemo_analysis_manifest tvdemo_spec
local demo_frame_clash ""
foreach demo_fr of local demo_frames {
    capture confirm frame `demo_fr'
    if _rc == 0 local demo_frame_clash "`demo_frame_clash' `demo_fr'"
}
local demo_owns_frames = ("`demo_frame_clash'" == "")

* Same rule for the two named extracts, for the same reason: the demo writes
* into the caller's working directory, and silently overwriting a file already
* sitting there is the disk equivalent of clobbering their frame.
local demo_file_clash ""
foreach demo_fl of local demo_files {
    capture confirm file "`demo_fl'"
    if _rc == 0 local demo_file_clash "`demo_file_clash' `demo_fl'"
}
local demo_owns_files = ("`demo_file_clash'" == "")

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
    if !`demo_owns_frames' {
        display as error ///
            "these frames already exist and the demo will not replace them:`demo_frame_clash'"
        display as error ///
            "drop or rename them, then re-run the demo"
        exit 110
    }
    if !`demo_owns_files' {
        display as error ///
            "these files already exist in `c(pwd)' and the demo will not replace them:`demo_file_clash'"
        display as error ///
            "move or delete them, then re-run the demo"
        exit 602
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

* Antidepressant exposure episodes (2 dispensed classes: SSRI / SNRI)
* These are raw dispensing records, the shape a real extract has: one row per
* dispensed episode, none of them coded to the unexposed reference category,
* and never two overlapping records for the same person -- consecutive starts
* are separated by at least one day. tvexpose and tvbuild both read this file
* as it stands, so Steps 1-4 and Step 5 consume identical input.
expand 1 + int(runiform() * 4)
bysort id: gen int seq = _n
bysort id: gen int duration = 60 + int(runiform() * 300)
bysort id: gen int rx_start = study_entry if seq == 1
bysort id: replace rx_start = rx_start[_n-1] + duration[_n-1] + 1 + int(runiform() * 60) if seq > 1
gen int rx_stop = rx_start + duration
format rx_start rx_stop %tdCCYY/NN/DD
gen double p_exposed = invlogit(-1 + 0.02 * age + 0.3 * female)
gen byte drug = 0
replace drug = 1 + int(runiform() * 2) if runiform() < p_exposed
label define drug_lbl 0 "Unexposed" 1 "SSRI" 2 "SNRI"
label values drug drug_lbl
drop if drug == 0
drop p_exposed seq duration
keep id rx_start rx_stop drug
save "`episodes_antidep'", replace


* Benzodiazepine exposure episodes (binary)
use "`cohort'", clear
expand 1 + int(runiform() * 2)
bysort id: gen int seq = _n
bysort id: gen int duration = 30 + int(runiform() * 120)
bysort id: gen int rx_start = study_entry + int(runiform() * 180) if seq == 1
bysort id: replace rx_start = rx_start[_n-1] + duration[_n-1] + 1 + int(runiform() * 90) if seq > 1
gen int rx_stop = rx_start + duration
format rx_start rx_stop %tdCCYY/NN/DD
gen byte benzo_use = runiform() < 0.35
label define benzo_lbl 0 "No benzo" 1 "Benzo"
label values benzo_use benzo_lbl
drop if benzo_use == 0
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

**# Frames-first primitives (no save/use round-trips)
capture log close _all
log using "`demo_dir'/console_primitives.log", replace text name(prim) nomsg

* # tvtools: Frames-First Time-Varying Primitives

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
    keepvars(age female) keepdates frameout(tvdemo_antidep)
local gA = r(genvar)
noisily display "antidepressant exposure variable: " as result "`gA'"

quietly tvexpose using "`episodes_benzo'", ///
    id(id) start(rx_start) stop(rx_stop) ///
    exposure(benzo_use) reference(0) ///
    entry(study_entry) exit(study_exit) ///
    keepvars(age female) keepdates frameout(tvdemo_benzo)
local gB = r(genvar)
noisily display "benzodiazepine exposure variable: " as result "`gB'"

* ## Step 2: tvdiagnose on the in-memory frame
noisily frame tvdemo_antidep: tvdiagnose, id(id) start(rx_start) stop(rx_stop) ///
    entry(study_entry) exit(study_exit) coverage gaps

* ## Step 3: tvmerge reads both frames, writes a merged frame
noisily tvmerge, frames(tvdemo_antidep tvdemo_benzo) id(id) ///
    start(rx_start rx_start) stop(rx_stop rx_stop) ///
    exposure(`gA' `gB') frameout(tvdemo_merged)
noisily display "merged interval vars: " as result "`r(startname)' / `r(stopname)'"

* ## Step 4: tvevent reads the merged frame, adds the outcome in memory
use "`events'", clear
noisily tvevent, frame(tvdemo_merged) id(id) ///
    date(cv_event_date) compete(death_date) generate(outcome)
noisily display "event indicator: " as result "`r(generate)'" ///
    "   intervals: " as result "`r(startvar)'/`r(stopvar)'"

* Keep the four-call result so the tvbuild section can be checked against it
* rather than merely described as equivalent.
local prim_periods = c(N)
quietly save "`primitive_out'", replace
log close prim


**# tvbuild: the same construction as one call
log using "`demo_dir'/console_tvbuild.log", replace text name(build) nomsg

* # tvbuild: The Whole Route as One Call

* ## The one-source shortcut
* The smallest useful tvbuild call. It reads the raw dispensing extract as it
* stands -- one row per dispensed episode, nothing coded to the unexposed
* reference category -- tiles it against each person's follow-up window, and
* commits a named analysis frame plus a provenance manifest as one transaction.
* No specification frame, no intermediate save/use, and the caller's cohort in
* memory is read and never written.
* manifestframe() is not given: since 1.12.0 tvbuild derives it from frameout(),
* so the provenance record arrives with the result rather than only on request.
use "`cohort'", clear
noisily tvbuild, sourceusing("`episodes_antidep'") ///
    id(id) entry(study_entry) exit(study_exit) ///
    start(rx_start) stop(rx_stop) exposure(drug) reference(0) ///
    referencelabel("Unexposed") label("Antidepressant class") ///
    generate(tv_drug) keepvars(age female) ///
    frameout(tvdemo_analysis) replace
noisily display "committed frame rows: " as result r(N_periods) ///
    as text "   persons: " as result r(N_persons) ///
    as text "   bounds: " as result "`r(startvar)'/`r(stopvar)'" ///
    as text "   exposure vars: " as result "`r(exposure_vars)'"

* ## What the shortcut committed
noisily frame tvdemo_analysis: list id start stop tv_drug age female in 1/10, ///
    noobs abbreviate(12)

* ## Its provenance manifest
noisily frame tvdemo_analysis_manifest: list stage source_name n_input n_output n_persons, ///
    noobs

* ## The multi-source specification: one tvspec call per source
* Describing two sources used to take twelve generate statements across nine
* typed columns, which is why this block used to be built with the log closed.
* tvspec writes the same columns, so it can be shown where it belongs.
noisily tvspec create tvdemo_spec, replace
noisily tvspec add tvdemo_spec, name(antidep) using("`episodes_antidep'") ///
    start(rx_start) stop(rx_stop) exposure(drug) reference(0) ///
    generate(`gA') referencelabel("Unexposed") label("Antidepressant class")
noisily tvspec add tvdemo_spec, name(benzo) using("`episodes_benzo'") ///
    start(rx_start) stop(rx_stop) exposure(benzo_use) reference(0) ///
    generate(`gB') referencelabel("No benzo") label("Benzodiazepine use")

* ## The specification tvbuild will read
noisily tvspec list tvdemo_spec

* tvbuild reads the same two raw episode files Steps 1-4 consumed and
* coordinates the same tvexpose, tvmerge, and tvevent engines rather than
* reimplementing interval semantics: it tiles each episode source, aligns them,
* places the events, and commits the output frame and its provenance manifest
* as a single transaction.

* ## The plan, validated against the data, changing nothing
* dryrun is not a syntax check: it runs the same parser, normalizer, name
* planner, data validators, and destination preflight the real run uses.
use "`cohort'", clear
noisily tvbuild, specframe(tvdemo_spec) ///
    id(id) entry(study_entry) exit(study_exit) keepvars(age female) ///
    eventusing("`events'") eventdate(cv_event_date) compete(death_date) ///
    eventgenerate(outcome) ///
    frameout(tvdemo_full) manifestframe(tvdemo_full_manifest) replace dryrun

* ## The committed run
use "`cohort'", clear
noisily tvbuild, specframe(tvdemo_spec) ///
    id(id) entry(study_entry) exit(study_exit) keepvars(age female) ///
    eventusing("`events'") eventdate(cv_event_date) compete(death_date) ///
    eventgenerate(outcome) ///
    frameout(tvdemo_full) manifestframe(tvdemo_full_manifest) replace
local build_periods = r(N_periods)
noisily display "committed periods: " as result r(N_periods) ///
    "   signature: " as result "`r(datasignature)'"
noisily matrix list r(stage_counts)

* ## Provenance manifest: one row per stage, in execution order
noisily frame tvdemo_full_manifest: list stage source_name n_input n_output n_persons, noobs

* ## Same inputs, same engines, same records
* The four-call route and the single call are compared on the columns they
* share, after an identical sort. cf is the right test here and datasignature
* is not: tvbuild keeps the master's id storage type and commits its bounds as
* doubles, so the two routes carry identical values under different storage
* types, which datasignature folds into its checksum.
* The keep/sort/save bookkeeping below is closed out of the log: it prepares
* the comparison, it is not part of what tvbuild does.
log close build
local cmp_vars "id start stop `gA' `gB' outcome"

use "`primitive_out'", clear
keep `cmp_vars'
order `cmp_vars'
sort id start stop
quietly save "`prim_cmp'", replace

frame copy tvdemo_full `f_cmp', replace
frame change `f_cmp'
keep `cmp_vars'
order `cmp_vars'
sort id start stop
quietly save "`build_cmp'", replace
frame change `demo_frame'
capture frame drop `f_cmp'

use "`build_cmp'", clear
log using "`demo_dir'/console_tvbuild.log", append text name(build) nomsg
noisily cf _all using "`prim_cmp'", verbose
local cmp_diffs = r(Nsum)
assert `cmp_diffs' == 0
noisily display "tvexpose x2 + tvmerge + tvevent: " as result `prim_periods' as text " periods"
noisily display "one tvbuild call:                " as result `build_periods' as text " periods"
noisily display "cf mismatching values:           " as result `cmp_diffs'
log close build


**# Marginal structural model weighting with IPCW
log using "`demo_dir'/console_msm.log", replace text name(msm) nomsg

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
log close msm


**# Recurrent-event PWP / AG formatting
log using "`demo_dir'/console_recurrent.log", replace text name(rec) nomsg

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
* quietly: a bare save echoes the tempfile's PID-stamped /tmp path into the
* published console asset, which makes the .md differ on every machine and run.
quietly save "`recint'"

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
log close rec


**# Multi-group weighting + age bands
log using "`demo_dir'/console_multigroup.log", replace text name(mg) nomsg

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
log close mg


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


**# Convert the console logs to markdown with logdoc
* logdoc is an optional companion package. When it is not on the adopath the
* demo tries the sibling checkout next to tvtools before giving up; the .log
* files are complete either way, only the .md rendering is skipped.
capture which logdoc
if _rc != 0 {
    capture quietly net install logdoc, from("`demo_dir'/../../logdoc") replace
    capture which logdoc
}
if _rc != 0 {
    display as text "logdoc not available; console .log files written, .md skipped"
}
else {
    local demo_logs "primitives tvbuild msm recurrent multigroup"
    local demo_titles `""tvtools: Frames-First Primitives""'
    local demo_titles `"`demo_titles' "tvbuild: The Whole Route as One Call""'
    local demo_titles `"`demo_titles' "tvtools: MSM Weighting with IPCW""'
    local demo_titles `"`demo_titles' "tvtools: Recurrent-Event Formatting""'
    local demo_titles `"`demo_titles' "tvtools: Multi-Group Weighting and Age Bands""'
    local demo_j = 0
    foreach lg of local demo_logs {
        local demo_j = `demo_j' + 1
        local demo_title : word `demo_j' of `demo_titles'
        logdoc using "`demo_dir'/console_`lg'.log", ///
            output("`demo_dir'/console_`lg'.md") ///
            format(md) title("`demo_title'") nodots replace quiet
        capture confirm file "`demo_dir'/console_`lg'.md"
        if _rc != 0 {
            display as error "logdoc did not write console_`lg'.md"
            exit 601
        }
    }
}
}
local demo_rc = _rc

* --- Unconditional cleanup and session restoration ---
capture log close prim
capture log close build
capture log close msm
capture log close rec
capture log close mg
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
capture frame drop `f_cmp'
* Drop the literal frames only when the pre-flight check proved the demo owned
* them. On a clash the demo created none of them, and dropping them here would
* destroy exactly the caller data the check refused to overwrite.
if `demo_owns_frames' {
    foreach frame_name of local demo_frames {
        capture frame drop `frame_name'
    }
}
* Same gate for the named extracts: on a clash the demo wrote neither of them,
* and erasing here would delete the caller's file the check refused to replace.
if `demo_owns_files' {
    foreach file_name of local demo_files {
        capture erase "`file_name'"
    }
}
if `demo_preserved' capture restore
capture set more `demo_more'
capture set varabbrev `demo_varabbrev'
capture set linesize `demo_linesize'
capture set scheme `demo_scheme'
capture frame change `demo_frame'

if `demo_rc' exit `demo_rc'
