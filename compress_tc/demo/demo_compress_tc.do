/*  demo_compress_tc.do - Generate screenshots for compress_tc

    Produces 1 output type:
      1. Console output (compression report) -> .smcl
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "compress_tc/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
capture program drop compress_tc
quietly run compress_tc/compress_tc.ado

* --- Setup data ---
sysuse auto, clear

* --- 1. Console output: detailed compression report ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg
noisily compress_tc, detail varsavings
log close demo

* --- Cleanup ---
clear
