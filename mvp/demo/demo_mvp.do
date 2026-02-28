/*  demo_mvp.do - Generate screenshots for mvp (missing value patterns)

    Produces 2 output types:
      1. Console output (missing value patterns) -> .smcl
      2. Graph (bar chart of missingness) -> .png
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "mvp/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
capture program drop mvp
quietly run mvp/mvp.ado

* --- Setup: create data with interesting missing patterns ---
clear
set seed 20260226
set obs 500

gen double age = rnormal(50, 12)
gen byte female = rbinomial(1, 0.48)
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

* --- 1. Console output: missing value patterns ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg
noisily mvp age female bmi sbp ldl hba1c, percent sort
log close demo

* --- 2. Graph: missingness bar chart ---
mvp age female bmi sbp ldl hba1c, graph(bar) sort ///
    scheme(plotplainblind) ///
    title("Missing Value Patterns")
graph export "`pkg_dir'/missingness_bar.png", replace width(1200)
capture graph close _all

* --- Cleanup ---
clear
