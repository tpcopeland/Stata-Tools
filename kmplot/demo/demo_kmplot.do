/*  demo_kmplot.do - Demonstrate all features of kmplot

    Author: Timothy P Copeland, Karolinska Institutet

    Uses sysuse cancer to produce publication-ready Kaplan-Meier plots,
    then the repository's synthetic registry cohort (_data/) for a
    registry-scale panel and fixed-time landmark estimates.
    Each section showcases a different feature or combination.

    Outputs:
      1. Graphs (10 PNGs) -> .png
      2. Console output (landmark estimates) -> .log -> .md via logdoc
*/

version 16.0
set linesize 120

**# Paths
local start_dir "`c(pwd)'"
capture confirm file "`start_dir'/../kmplot.ado"
if _rc == 0 {
    local demo_dir "`start_dir'"
    local pkg_root "`start_dir'/.."
}
else {
    capture confirm file "`start_dir'/kmplot.ado"
    if _rc == 0 {
        local pkg_root "`start_dir'"
        local demo_dir "`start_dir'/demo"
    }
    else {
        capture confirm file "`start_dir'/kmplot/kmplot.ado"
        if _rc == 0 {
            local pkg_root "`start_dir'/kmplot"
            local demo_dir "`start_dir'/kmplot/demo"
        }
        else {
            display as error "demo_kmplot.do must be run from the kmplot demo, package, or repository directory"
            exit 601
        }
	    }
	}
local pkg_dir "`demo_dir'"
local data_dir "`pkg_root'/../_data"
capture confirm file "`data_dir'/cohort.dta"
if _rc {
    display as error "demo_kmplot.do needs the repository's _data/ directory beside kmplot/"
    exit 601
}

**# Scheme
* Gallery figures use white_tableau.  Resolve it explicitly and stop if it is
* missing, so the PNGs never fall back silently to another scheme.
local old_scheme "`c(scheme)'"
capture findfile scheme-white_tableau.scheme
if _rc {
    display as error "scheme white_tableau not found; install it (ssc install schemepack) before regenerating the gallery"
    exit 601
}
set scheme white_tableau
assert "`c(scheme)'" == "white_tableau"
capture log close _all

capture noisily {

**# Reload commands
* kmplot re-resolves its risk-table helper with findfile on every call, so
* running the checkout's copies is not enough: an installed copy earlier on
* the adopath would be loaded instead, pairing this kmplot.ado with a helper
* from another version.  Put the checkout first.
adopath ++ "`pkg_root'"
capture program drop kmplot
capture program drop _kmplot_risktable
quietly run "`pkg_root'/kmplot.ado"
quietly run "`pkg_root'/_kmplot_risktable.ado"

**# Setup data
sysuse cancer, clear
* cancer.dta labels drugs 2 and 3 "Other" and "NA"; its notes call them two
* alternative treatments, so name them that way instead of showing "NA"
label define type 2 "Drug A" 3 "Drug B", modify
stset studytime, failure(died)

**## 1. Basic KM curve (single group, no options)

kmplot, name(demo1, replace)
graph export "`pkg_dir'/km_basic.png", replace width(1200)
capture graph close _all

**## 2. Stratified KM by treatment group

kmplot, by(drug) name(demo2, replace)
graph export "`pkg_dir'/km_by_group.png", replace width(1200)
capture graph close _all

**## 3. CI bands with median lines and annotation

* Log-log CI (Stata default), shaded bands, median reference lines
kmplot, by(drug) ci median medianannotate name(demo3, replace)
graph export "`pkg_dir'/km_ci_median.png", replace width(1200)
capture graph close _all

**## 4. Cumulative failure mode with risk table

* Inverts S(t) to 1-S(t), adds number-at-risk table below
kmplot, by(drug) failure risktable ///
    timepoints(0 5 10 15 20 25 30 35) ///
    name(demo4, replace)
graph export "`pkg_dir'/km_failure_risktable.png", replace width(1200)
capture graph close _all

**## 5. Risk table with events + monochrome + censoring

* NEJM-style "N (events)" format, black numbers, censor marks
kmplot, by(drug) risktable riskevents riskmono ///
    censor censorthin(2) ///
    timepoints(0 5 10 15 20 25 30 35) ///
    name(demo5, replace)
graph export "`pkg_dir'/km_risk_censor.png", replace width(1200)
capture graph close _all

**## 6. Full publication figure with all features

* CI bands, risk table, median lines, p-value, censor marks
kmplot, by(drug) ci median medianannotate pvalue censor ///
    risktable riskevents ///
    timepoints(0 5 10 15 20 25 30 35) ///
    title("Overall Survival by Treatment") ///
    subtitle("Cancer Drug Trial") ///
    xtitle("Time (months)") ytitle("Survival probability") ///
    name(demo6, replace)

graph export "`pkg_dir'/km_publication.png", replace width(1200)
capture graph close _all

**## 7. Custom styling: colors, patterns, CI lines

* Three custom colors and dash patterns, with dashed CI lines instead of bands
* (p-value in the bottom-left corner; survival curves crowd the top-left).
* The legend sits below the plot so it cannot cover the upper CI lines, which
* are not legend entries; the note says what the thin dashed lines are.
* The note hard-codes 95% because level() is not set, so the default applies.
kmplot, by(drug) ci cistyle(line) citransform(log) ///
    colors(navy maroon dkorange) ///
    lpattern(solid dash dot) lwidth(thick) ///
    pvalue pvaluepos(bottomleft) ///
    xlabel(0(5)40) ///
    legend(order(1 "Placebo" 2 "Drug A" 3 "Drug B") rows(1) position(6) size(small)) ///
    note("Thin dashed lines are 95% confidence limits (log transform)") ///
    aspectratio(0.8) ///
    name(demo7, replace)
graph export "`pkg_dir'/km_custom_style.png", replace width(1200)
capture graph close _all

**## 8. Plain CI transform with high opacity bands

* Wald CIs (no transformation), high-opacity bands, p-value bottom-left
kmplot, by(drug) ci citransform(plain) ciopacity(30) ///
    pvalue pvaluepos(bottomleft) ///
    note("Note: Wald confidence intervals shown") ///
    name(demo8, replace)
graph export "`pkg_dir'/km_plain_ci.png", replace width(1200)
capture graph close _all

**## 9. Journal-style p-value label and custom CI level

* Custom p-value text + format, user-set 90% CI level, risk table
* (p-value in the bottom-left corner, clear of the top-right legend)
* pvaluetext("Log-rank P") is kept deliberately: this panel shows the option's
* journal-style capital-P label; the other panels use the default "Log-rank p"
kmplot, by(drug) ci level(90) risktable ///
    pvalue pvaluetext("Log-rank P") pvalueformat(%5.3f) pvaluepos(bottomleft) ///
    timepoints(0 5 10 15 20 25 30 35) ///
    title("Overall Survival by Treatment") ///
    xtitle("Time (months)") ///
    name(demo9, replace)
graph export "`pkg_dir'/km_pvalue_level.png", replace width(1200)
capture graph close _all

**## 10. Registry-scale cumulative incidence

* 15,000 synthetic SSRI and SNRI initiators from the repository's _data/;
* time to first cardiovascular event, p-value in its default position
use "`data_dir'/cohort.dta", clear
merge 1:1 id using "`data_dir'/treatment.dta", nogenerate
merge 1:1 id using "`data_dir'/outcomes.dta", nogenerate keepusing(cv_event_date)
generate byte cv = !missing(cv_event_date) & cv_event_date <= study_exit
generate double exit = cond(cv, cv_event_date, study_exit)
stset exit, failure(cv) origin(study_entry) scale(365.25)

* Cumulative failure stays below about 0.6, so the y axis is cut at 0.6
* (lower bound kept at 0) and the risk table stops at year 15 (follow-up ends at 17.99, so a year-18 column would be all zeros)
kmplot, by(treated) failure ci risktable pvalue ///
    ylabel(0(0.1)0.6, format(%3.1f) angle(0) nogrid) ///
    timepoints(0 3 6 9 12 15) ///
    title("First cardiovascular event") ///
    xtitle("Years since initiation") ///
    name(demo10, replace)
graph export "`pkg_dir'/km_registry_failure.png", replace width(1200)
capture graph close _all

**## 11. Fixed-time estimates with landmark()

log using "`pkg_dir'/console_landmarks.log", replace text name(demo) nomsg

* # Cumulative incidence at 1, 5, and 10 years

* Rows are indexed by group: 1, 2, ... in the order of r(group_labels)
kmplot, by(treated) failure ci landmark(1 5 10) name(demo11, replace)
display as text "Groups: " as result `"`r(group_labels)'"'
matrix list r(landmarks), format(%7.4f)

log close demo
capture graph close _all

**## Convert console log to markdown via logdoc
capture ado uninstall logdoc
quietly net install logdoc, from("`pkg_root'/../logdoc") replace
logdoc using "`pkg_dir'/console_landmarks.log", ///
    output("`pkg_dir'/console_landmarks.md") format(md) replace quiet

}
local rc = _rc

**# Cleanup
capture adopath - "`pkg_root'"
capture graph close _all
capture log close _all
capture set scheme `old_scheme'
capture clear
if `rc' exit `rc'
display as result "RESULT: demo_kmplot tests=11 pass=11 fail=0"
