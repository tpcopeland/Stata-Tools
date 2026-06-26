/*  demo_kmplot.do - Demonstrate all features of kmplot

    Uses sysuse cancer to produce publication-ready Kaplan-Meier plots.
    Each section showcases a different feature or combination.

    Outputs:
      1. Graphs (9 PNGs) -> .png
*/

version 16.0
set varabbrev off

* --- Paths ---
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

* --- Scheme ---
local old_scheme "`c(scheme)'"
capture set scheme plotplainblind
if _rc {
    set scheme `old_scheme'
}
capture log close _all

* --- Reload commands ---
capture ado uninstall kmplot
capture program drop kmplot
capture program drop _kmplot_risktable
quietly run "`pkg_root'/kmplot.ado"
quietly run "`pkg_root'/_kmplot_risktable.ado"

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
* 4. Cumulative failure mode with risk table
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
kmplot, by(drug) ci median medianannotate pvalue censor ///
    risktable riskevents ///
    timepoints(0 5 10 15 20 25 30 35) ///
    title("Overall Survival by Treatment") ///
    subtitle("Cancer Drug Trial") ///
    xtitle("Time (months)") ytitle("Survival probability") ///
    name(demo6, replace)

graph export "`pkg_dir'/km_publication.png", replace width(1200)
capture graph close _all

* ============================================================
* 7. Custom styling: colors, patterns, CI lines
* ============================================================

* Two-color scheme with dashed CI lines instead of bands
* (p-value in the bottom-left corner; survival curves crowd the top-left)
kmplot, by(drug) ci cistyle(line) citransform(log) ///
    colors(navy maroon dkorange) ///
    lpattern(solid dash dot) lwidth(thick) ///
    pvalue pvaluepos(bottomleft) ///
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

* ============================================================
* 9. Journal-style p-value label and custom CI level (v1.2.0)
* ============================================================

* Custom p-value text + format, user-set 90% CI level, risk table
* (p-value in the bottom-left corner, clear of the top-right legend)
kmplot, by(drug) ci level(90) risktable ///
    pvalue pvaluetext("Log-rank P") pvalueformat(%5.3f) pvaluepos(bottomleft) ///
    timepoints(0 5 10 15 20 25 30 35) ///
    title("Overall Survival by Treatment") ///
    xtitle("Time (months)") ///
    name(demo9, replace)
graph export "`pkg_dir'/km_pvalue_level.png", replace width(1200)
capture graph close _all

* --- Cleanup ---
display as result "RESULT: demo_kmplot tests=9 pass=9 fail=0"
capture log close _all
capture set scheme `old_scheme'
clear
