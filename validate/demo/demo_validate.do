/*  demo_validate.do - Generate screenshots for validate

    Produces 2 output types:
      1. Console output (validation report) -> .smcl
      2. Excel report (validation results) -> .xlsx
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "validate/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
capture program drop validate
quietly run validate/validate.ado

* --- Setup data ---
sysuse auto, clear

* --- 1. Console output: range validation with report ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg
noisily validate price, range(0 50000) nomiss report
noisily validate mpg, range(5 60) nomiss report
noisily validate rep78, values(1 2 3 4 5) report
noisily validate foreign, values(0 1) nomiss report

log close demo

* --- 2. Excel report ---
validate price mpg weight, nomiss report ///
    xlsx("`pkg_dir'/validation_report.xlsx") ///
    title("Auto Dataset Validation")

* --- Cleanup ---
clear
