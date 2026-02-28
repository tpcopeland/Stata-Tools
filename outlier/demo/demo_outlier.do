/*  demo_outlier.do - Generate screenshots for outlier

    Produces 2 output types:
      1. Console output (outlier detection report) -> .smcl
      2. Excel report (outlier table) -> .xlsx
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "outlier/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload command ---
capture program drop outlier
quietly run outlier/outlier.ado

* --- Setup data ---
sysuse auto, clear

* --- 1. Console output: IQR-based outlier detection with report ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg
noisily outlier price mpg weight, report
log close demo

* --- 2. Excel report ---
outlier price mpg weight, report xlsx("`pkg_dir'/outlier_report.xlsx")

* --- Cleanup ---
clear
