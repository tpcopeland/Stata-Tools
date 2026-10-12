/*  demo_compress_tc.do - Generate example output for compress_tc

    Produces 1 output type:
      1. Console output (compression report) -> .smcl
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "compress_tc/demo"
capture mkdir "`pkg_dir'"

* --- Install package from local source ---
* net install copies the main ado and its helpers (_compress_tc_bytes,
* _compress_tc_human), so the demo runs what a user installs.
capture program drop compress_tc
capture program drop _compress_tc_bytes
capture program drop _compress_tc_human
quietly net install compress_tc, from("`c(pwd)'/compress_tc") replace

* --- Setup data ---
sysuse auto, clear

* --- 1. Console output: detailed compression report ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg
noisily compress_tc, detail varsavings
log close demo

* --- Cleanup ---
clear
