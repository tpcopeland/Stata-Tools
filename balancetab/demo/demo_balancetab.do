/*  demo_balancetab.do - Generate screenshots for balancetab package

    Produces three output types:
      1. Console output (SMD display) -> .smcl -> .png
      2. Love plot (graph) -> .png
      3. Balance table (Excel) -> .xlsx -> .png
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "balancetab/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
capture program drop balancetab
quietly run balancetab/balancetab.ado

* --- Setup: create example data with treatment imbalance ---
clear
set seed 20260225
set obs 500

* Treatment assignment (biased toward younger, male)
gen double age = rnormal(50, 12)
gen byte male = rbinomial(1, 0.45)
gen double bmi = rnormal(27, 5)
gen double sbp = rnormal(130, 18)
gen double creatinine = rnormal(1.1, 0.3)

* Treatment probability depends on covariates (creates imbalance)
gen double _ps = invlogit(-2 + 0.03 * age - 0.5 * male + 0.02 * bmi)
gen byte treated = rbinomial(1, _ps)

* Generate IPTW weights to fix the imbalance
quietly logit treated age male bmi sbp creatinine
quietly predict double ps, pr
gen double ipw = cond(treated == 1, 1/ps, 1/(1-ps))

* Label variables for nicer display
label variable age "Age (years)"
label variable male "Male sex"
label variable bmi "Body mass index"
label variable sbp "Systolic BP"
label variable creatinine "Creatinine"
label variable treated "Treatment"

drop _ps ps

* --- 1. Console output: SMD display with weights ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg
noisily balancetab age male bmi sbp creatinine, treatment(treated) ///
    wvar(ipw) threshold(0.1) title("IPTW Balance Assessment")
log close demo

* --- 2. Love plot ---
balancetab age male bmi sbp creatinine, treatment(treated) ///
    wvar(ipw) loveplot saving("`pkg_dir'/love_plot.png") ///
    graphoptions(scheme(plotplainblind) legend(pos(6) rows(1))) ///
    title("IPTW Balance Assessment")

* Graph already exported by saving() option - close any open graph
capture graph close _all

* --- 3. Excel balance table ---
balancetab age male bmi sbp creatinine, treatment(treated) ///
    wvar(ipw) xlsx("`pkg_dir'/balance_table.xlsx") ///
    title("IPTW Balance Assessment")

* --- Cleanup ---
clear
