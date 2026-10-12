* gallery_tvtools_episodes.do - tvexpose turns raw dispensings into exposure episodes
* Run with the working directory set to the Stata-Tools repository root.
version 16.0
set linesize 120
set varabbrev off
set seed 20261012

local root "`c(pwd)'"
sysdir set PLUS "`c(tmpdir)'/gallery_plus"
sysdir set PERSONAL "`c(tmpdir)'/gallery_personal"
capture mkdir "`c(tmpdir)'/gallery_plus"
capture mkdir "`c(tmpdir)'/gallery_personal"
quietly net install tvtools, from("`root'/tvtools") replace
quietly net install swimlane, from("`root'/swimlane") replace
quietly net install tc_schemes, from("`root'/tc_schemes") replace
set scheme white_tableau
assert c(scheme) == "white_tableau"

* Raw dispensings -> one row per SSRI/SNRI dispensing with its covered days
tempfile rx
use "_data/prescriptions", clear
keep if inlist(drug_name, "citalopram", "escitalopram", "fluoxetine", "sertraline", "venlafaxine", "duloxetine")
gen byte drug_class = cond(inlist(drug_name, "venlafaxine", "duloxetine"), 2, 1)
gen long rx_start = disp_date
gen long rx_stop = disp_date + days_supply - 1
keep id drug_class rx_start rx_stop
save `rx'

* First three years of follow-up for every cohort member
use "_data/cohort", clear
gen long exit3 = min(study_exit, study_entry + 1095)
tvexpose using `rx', id(id) start(rx_start) stop(rx_stop) exposure(drug_class) reference(0) ///
    entry(study_entry) exit(exit3) grace(30) merge(31) generate(tv_class) frameout(f_ep) replace

frame f_ep {
    merge m:1 id using "_data/treatment", nogen keep(3)
    merge m:1 id using "_data/cohort", nogen keep(3) keepusing(study_entry)

    * Selection rule (no hand-picking): the first 6 people per arm, in id order,
    * whose 3-year history has 5 to 11 episode rows
    bysort id: gen int nrow = _N
    bysort id: gen byte first = _n == 1
    keep if inrange(nrow, 5, 11)
    sort treated id rx_start
    by treated: gen long rank = sum(first)
    keep if rank <= 6

    * Time since cohort entry (days)
    gen long t0 = rx_start - study_entry
    gen long t1 = rx_stop - study_entry + 1
    label define cls_lbl 0 "Unexposed" 1 "SSRI" 2 "SNRI", replace
    label values tv_class cls_lbl

    * Lane label: person letter, arm-ordered
    egen long lane = group(treated id)
    gen str8 who = "Person " + char(64 + lane)

    swimlane, id(lane) idlabel(who) start(t0) stop(t1) state(tv_class) stateorder("SSRI" "SNRI" "Unexposed") ///
        colors(sea vermillion gs13) sort(+lane) maxids(all) idlabels(all) ///
        barwidth(0.72) title("Dispensings become episodes", size(large)) ///
        xtitle("Years since cohort entry", size(medlarge)) ytitle("") yscale(noline) ///
        xlabel(0 "0" 365 "1" 730 "2" 1095 "3", labsize(medlarge) nogrid) ylabel(, labsize(medlarge) notick nogrid) ///
        legend(pos(6) rows(1) size(medlarge)) xsize(6) ysize(4) name(g_tvtools, replace) ///
        export("_resources/gallery/tvtools_episodes.png", replace width(1600))
}
