/*  demo_mvp.do - Generate screenshots for mvp v1.2.0

    Produces:
      1. Console output (pattern analysis with options) -> .smcl
      2. Bar chart of missingness -> .png
      3. Pattern frequency chart -> .png
      4. Matrix heatmap -> .png
      5. Correlation heatmap -> .png
      6. Stratified bar chart (gby) -> .png
      7. Stacked bar chart -> .png
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "mvp/demo"
capture mkdir "`pkg_dir'"

* --- Load command ---
capture program drop mvp
quietly run mvp/mvp.ado

* --- Create clinical trial dataset with realistic missingness ---
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

* --- 1. Console output: full analysis ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg

noisily mvp age female bmi sbp ldl hba1c, ///
    percent sort monotone correlate

log close demo

* --- 2. Bar chart: % missing by variable ---
mvp bmi sbp ldl hba1c, graph(bar) sort ///
    scheme(plotplainblind) ///
    title("Missing Values by Variable")
graph export "`pkg_dir'/missingness_bar.png", replace width(1200)
capture graph close _all

* --- 3. Pattern frequency chart ---
mvp bmi sbp ldl hba1c, graph(patterns) top(10) ///
    scheme(plotplainblind) ///
    title("Top 10 Missing Value Patterns")
graph export "`pkg_dir'/pattern_freq.png", replace width(1200)
capture graph close _all

* --- 4. Matrix heatmap ---
mvp bmi sbp ldl hba1c, graph(matrix, sample(200) sort) ///
    scheme(plotplainblind) ///
    title("Missingness Heatmap")
graph export "`pkg_dir'/matrix_heatmap.png", replace width(1200)
capture graph close _all

* --- 5. Correlation heatmap ---
mvp bmi sbp ldl hba1c, graph(correlation) textlabels ///
    scheme(plotplainblind) ///
    title("Missingness Correlations")
graph export "`pkg_dir'/correlation_heatmap.png", replace width(1200)
capture graph close _all

* --- 6. Stratified bar chart by sex ---
mvp bmi sbp ldl hba1c, graph(bar) gby(female) ///
    scheme(plotplainblind)
graph export "`pkg_dir'/bar_by_sex.png", replace width(1200)
capture graph close _all

* --- 7. Stacked bar chart ---
mvp bmi sbp ldl hba1c, graph(bar) stacked ///
    scheme(plotplainblind) ///
    title("Missingness Contribution by Variable")
graph export "`pkg_dir'/stacked_bar.png", replace width(1200)
capture graph close _all

* --- Cleanup ---
clear
