/*  demo_cstat_surv.do - Generate screenshots for cstat_surv

    Produces 1 output type:
      1. Console output (C-statistic display) -> .smcl

    Demonstrates:
      - Basic usage after stcox
      - Custom confidence level with level()
      - Model comparison (simple vs complex)
      - Accessing stored results
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "cstat_surv/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
capture program drop cstat_surv
quietly run cstat_surv/cstat_surv.ado

* --- Setup: survival data ---
sysuse cancer, clear
stset studytime, failure(died)

* --- 1. Console output ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg

* Simple model: age only
quietly stcox age
cstat_surv
local c_simple = e(c)

* Complex model: age + drug + interaction
quietly stcox age i.drug c.age#i.drug
cstat_surv
local c_complex = e(c)

* Custom confidence level (90%)
quietly stcox age i.drug c.age#i.drug
cstat_surv, level(90)

* Compare discrimination
display as text "Model comparison:"
display as text "  Simple (age):     C = " %6.4f `c_simple'
display as text "  Complex (+ drug): C = " %6.4f `c_complex'

* Access stored results
display as text _n "Stored results from complex model:"
display as text "  Somers' D   = " %6.4f e(somers_d)
display as text "  SE          = " %6.4f e(se)
display as text "  Pairs       = " %8.0fc e(N_comparable)

log close demo

* --- Cleanup ---
clear
