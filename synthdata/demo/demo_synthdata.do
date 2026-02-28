/*  demo_synthdata.do - Generate screenshots for synthdata

    Produces 1 output type:
      1. Console output (synthetic data generation summary) -> .smcl
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "synthdata/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
capture program drop synthdata
quietly run synthdata/synthdata.ado

* --- Setup: use auto dataset as source ---
sysuse auto, clear

* --- 1. Console output: generate synthetic data with comparison ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg
noisily synthdata price mpg weight length foreign rep78, ///
    n(200) seed(20260226) compare clear

log close demo

* --- Cleanup ---
clear
