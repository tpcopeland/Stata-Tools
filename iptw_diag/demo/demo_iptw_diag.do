/*  demo_iptw_diag.do - Generate screenshots for iptw_diag

    Produces 2 output types:
      1. Console output (weight diagnostics) -> .smcl
      2. Graph (weight distribution histogram) -> .png
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "iptw_diag/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
capture program drop iptw_diag
quietly run iptw_diag/iptw_diag.ado

* --- Setup: create treatment data with IPTW weights ---
clear
set seed 20260226
set obs 1000

gen double age = rnormal(55, 12)
gen byte female = rbinomial(1, 0.45)
gen double bmi = rnormal(27, 5)
gen double sbp = rnormal(130, 18)

* Treatment assignment depends on covariates (creates imbalance)
gen double _ps = invlogit(-1.5 + 0.02 * age - 0.4 * female + 0.01 * bmi)
gen byte treated = rbinomial(1, _ps)

* Generate IPTW weights
quietly logit treated age female bmi sbp
quietly predict double ps, pr
gen double ipw = cond(treated == 1, 1/ps, 1/(1-ps))

label variable ipw "IPTW Weight"
label variable treated "Treatment"

drop _ps ps

* --- 1. Console output: weight diagnostics with detail ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg
noisily iptw_diag ipw, treatment(treated) detail
log close demo

* --- 2. Graph: weight distribution ---
iptw_diag ipw, treatment(treated) graph scheme(plotplainblind)
graph export "`pkg_dir'/weight_distribution.png", replace width(1200)
capture graph close _all

* --- Cleanup ---
clear
