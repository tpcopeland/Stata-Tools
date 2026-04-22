/*  demo_kmplot.do - Demonstrate all features of kmplot

    Uses sysuse cancer to produce publication-ready Kaplan-Meier plots.
    Each section showcases a different feature or combination.

    Outputs:
      1. Console output (summary) -> .smcl
      2. Graphs (8 PNGs) -> .png
*/

version 16.0
set varabbrev off

* --- Paths ---
local pkg_dir "`c(pwd)'"

* --- Scheme ---
capture net install tc_schemes, from("~/Stata-Tools/tc_schemes") replace
set scheme plotplainblind, permanently

* --- Reload commands ---
capture ado uninstall kmplot
capture program drop kmplot
capture program drop _kmplot_risktable
quietly run "`pkg_dir'/../kmplot.ado"
quietly run "`pkg_dir'/../_kmplot_risktable.ado"

* --- Setup data ---
sysuse cancer, clear
stset studytime, failure(died)

* ============================================================
* 1. Basic KM curve (single group, no options)
* ============================================================

kmplot, name(demo1, replace)
graph export "`pkg_dir'/km_basic.png", replace width(1200)
capture graph close _all

* ============================================================
* 2. Stratified KM by treatment group
* ============================================================

kmplot, by(drug) name(demo2, replace)
graph export "`pkg_dir'/km_by_group.png", replace width(1200)
capture graph close _all

* ============================================================
* 3. CI bands with median lines and annotation
* ============================================================

* Log-log CI (Stata default), shaded bands, median reference lines
kmplot, by(drug) ci median medianannotate name(demo3, replace)
graph export "`pkg_dir'/km_ci_median.png", replace width(1200)
capture graph close _all

* ============================================================
* 4. Cumulative incidence (failure mode) with risk table
* ============================================================

* Inverts S(t) to 1-S(t), adds number-at-risk table below
kmplot, by(drug) failure risktable ///
    timepoints(0 5 10 15 20 25 30 35) ///
    name(demo4, replace)
graph export "`pkg_dir'/km_failure_risktable.png", replace width(1200)
capture graph close _all

* ============================================================
* 5. Risk table with events + monochrome + censoring
* ============================================================

* NEJM-style "N (events)" format, black numbers, censor marks
kmplot, by(drug) risktable riskevents riskmono ///
    censor censorthin(2) ///
    timepoints(0 5 10 15 20 25 30 35) ///
    name(demo5, replace)
graph export "`pkg_dir'/km_risk_censor.png", replace width(1200)
capture graph close _all

* ============================================================
* 6. Full publication figure with all features
* ============================================================

* CI bands, risk table, median lines, p-value, censor marks
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo)

kmplot, by(drug) ci median medianannotate pvalue censor ///
    risktable riskevents ///
    timepoints(0 5 10 15 20 25 30 35) ///
    title("Overall Survival by Treatment") ///
    subtitle("Cancer Drug Trial") ///
    xtitle("Time (months)") ytitle("Survival probability") ///
    name(demo6, replace)

log close demo

graph export "`pkg_dir'/km_publication.png", replace width(1200)
capture graph close _all

* ============================================================
* 7. Custom styling: colors, patterns, CI lines
* ============================================================

* Two-color scheme with dashed CI lines instead of bands
kmplot, by(drug) ci cistyle(line) citransform(log) ///
    colors(navy maroon dkorange) ///
    lpattern(solid dash dot) lwidth(thick) ///
    pvalue pvaluepos(topleft) ///
    xlabel(0(5)40) ylabel(0(0.2)1) ///
    aspectratio(0.8) ///
    name(demo7, replace)
graph export "`pkg_dir'/km_custom_style.png", replace width(1200)
capture graph close _all

* ============================================================
* 8. Plain CI transform with high opacity bands
* ============================================================

* Wald CIs (no transformation), high-opacity bands, p-value bottom-left
kmplot, by(drug) ci citransform(plain) ciopacity(30) ///
    pvalue pvaluepos(bottomleft) ///
    note("Note: Wald confidence intervals shown") ///
    name(demo8, replace)
graph export "`pkg_dir'/km_plain_ci.png", replace width(1200)
capture graph close _all

* --- Cleanup ---
clear
