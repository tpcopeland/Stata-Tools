/*  demo_mvp.do - Demo output for mvp

    Produces:
      1. Console output (pattern analysis + monotone + correlation) -> .log -> .md
      2. Bar chart of missingness by variable -> .png
      3. Pattern frequency chart -> .png
      4. Matrix heatmap -> .png
      5. Correlation heatmap -> .png
      6. Stratified bar chart by sex -> .png
      7. Stacked bar chart -> .png
      8. Multi-group bar chart (3 treatment arms, gby) -> .png
      9. Multi-group overlay chart (3 treatment arms, over) -> .png
     10. Multi-group pattern chart (3 treatment arms, gby) -> .png
     11. Multi-group console output -> .log -> .md

    Run from the Stata-Tools repository root:
      stata-mp -b do mvp/demo/demo_mvp.do
*/

version 16.0
set more off
set varabbrev off
set linesize 120

**# Paths
local repo_dir = regexr("`c(pwd)'", "/+$", "")
local pkg_dir "mvp/demo"
capture mkdir "`pkg_dir'"

**# Graph scheme
capture ado uninstall tc_schemes
quietly net install tc_schemes, from("`repo_dir'/tc_schemes") replace
set scheme plotplainblind

**# Install package from local source
capture ado uninstall mvp
quietly net install mvp, from("`repo_dir'/mvp") replace

**# Create clinical trial dataset with realistic missingness
clear
set seed 20260226
set obs 500

gen double age = rnormal(50, 12)
gen byte female = rbinomial(1, 0.48)
label define sexlbl 0 "Male" 1 "Female"
label values female sexlbl
gen double bmi = rnormal(27, 5)
gen double sbp = rnormal(130, 18)
gen double ldl = rnormal(3.5, 1.1)
gen double hba1c = rnormal(5.8, 0.9)

label variable age "Age (years)"
label variable female "Female sex"
label variable bmi "Body mass index"
label variable sbp "Systolic BP"
label variable ldl "LDL cholesterol"
label variable hba1c "HbA1c"

* Introduce realistic missingness patterns
replace bmi = . if runiform() < 0.08
replace sbp = . if runiform() < 0.05
replace ldl = . if runiform() < 0.15
replace hba1c = . if runiform() < 0.20
* Correlated missingness: if ldl missing, hba1c more likely missing
replace hba1c = . if missing(ldl) & runiform() < 0.4

**# Console output: full analysis
capture log close _all
log using "`pkg_dir'/console_output.log", replace text name(demo) nomsg

noisily mvp age female bmi sbp ldl hba1c, ///
    percent sort monotone correlate

log close demo

**# Bar chart: % missing by variable
mvp bmi sbp ldl hba1c, graph(bar) sort ///
    title("Missing Values by Variable")
graph export "`pkg_dir'/missingness_bar.png", replace width(1200)
capture graph close _all

**# Pattern frequency chart
mvp bmi sbp ldl hba1c, graph(patterns) top(10) ///
    title("Top 10 Missing Value Patterns")
graph export "`pkg_dir'/pattern_freq.png", replace width(1200)
capture graph close _all

**# Matrix heatmap
mvp bmi sbp ldl hba1c, graph(matrix, sample(200) sort) ///
    title("Missingness Heatmap")
graph export "`pkg_dir'/matrix_heatmap.png", replace width(1200)
capture graph close _all

**# Correlation heatmap
mvp bmi sbp ldl hba1c, graph(correlation) textlabels ///
    title("Missingness Correlations")
graph export "`pkg_dir'/correlation_heatmap.png", replace width(1200)
capture graph close _all

**# Stratified bar chart by sex (2 groups)
mvp bmi sbp ldl hba1c, graph(bar) gby(female)
graph export "`pkg_dir'/bar_by_sex.png", replace width(1200)
capture graph close _all

**# Stacked bar chart
mvp bmi sbp ldl hba1c, graph(bar) stacked ///
    title("Missingness Contribution by Variable")
graph export "`pkg_dir'/stacked_bar.png", replace width(1200)
capture graph close _all

**# Multi-group analysis (3 treatment arms)
* Add a 3-arm treatment variable with differential missingness
gen byte arm = cond(_n <= 167, 0, cond(_n <= 334, 1, 2))
label define armlbl 0 "Placebo" 1 "Low dose" 2 "High dose"
label values arm armlbl
label variable arm "Treatment arm"

* High dose arm has more lab dropouts
replace ldl = . if arm == 2 & runiform() < 0.10
replace hba1c = . if arm == 2 & runiform() < 0.12

**## Multi-group console output (per-arm pattern analysis)
log using "`pkg_dir'/console_multigroup.log", replace text name(mg) nomsg

noisily display as text "--- Placebo ---"
noisily mvp bmi sbp ldl hba1c if arm == 0, percent sort
noisily display as text ""
noisily display as text "--- Low dose ---"
noisily mvp bmi sbp ldl hba1c if arm == 1, percent sort
noisily display as text ""
noisily display as text "--- High dose ---"
noisily mvp bmi sbp ldl hba1c if arm == 2, percent sort

log close mg

**## Multi-group bar chart (gby — faceted by treatment arm)
mvp bmi sbp ldl hba1c, graph(bar) gby(arm) sort ///
    title("Missing Values by Treatment Arm")
graph export "`pkg_dir'/mg_bar_gby.png", replace width(1200)
capture graph close _all

**## Multi-group overlay chart (over — grouped bars side by side)
mvp bmi sbp ldl hba1c, graph(bar) over(arm) sort ///
    title("Missing Values: Treatment Arms Compared")
graph export "`pkg_dir'/mg_bar_over.png", replace width(1200)
capture graph close _all

**## Multi-group pattern chart (gby — faceted patterns)
mvp bmi sbp ldl hba1c, graph(patterns) gby(arm) top(5) ///
    title("Missing Value Patterns by Treatment Arm")
graph export "`pkg_dir'/mg_patterns_gby.png", replace width(1200)
capture graph close _all

**# Convert console logs to markdown via logdoc
capture ado uninstall logdoc
quietly net install logdoc, from("`repo_dir'/logdoc") replace

logdoc using "`pkg_dir'/console_output.log", ///
    output("`pkg_dir'/console_output.md") ///
    format(md) replace quiet

logdoc using "`pkg_dir'/console_multigroup.log", ///
    output("`pkg_dir'/console_multigroup.md") ///
    format(md) replace quiet

**# Cleanup
clear
