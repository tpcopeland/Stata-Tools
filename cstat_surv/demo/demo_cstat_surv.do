/*  demo_cstat_surv.do - Generate screenshots for cstat_surv

    Produces 1 output type:
      1. Console output (C-statistic display) -> .smcl
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

* --- Fit Cox model ---
quietly stcox age i.drug

* --- 1. Console output: C-statistic ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg
noisily cstat_surv
log close demo

* --- Cleanup ---
clear
