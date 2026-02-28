/*  demo_tabtools.do - Generate screenshots for tabtools

    Produces 2 output types:
      1. Console output (table1 display) -> .smcl
      2. Excel table (table1_tc output) -> .xlsx
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "tabtools/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload commands ---
capture program drop table1_tc
quietly run tabtools/table1_tc.ado
capture program drop tablex
quietly run tabtools/tablex.ado
capture program drop _tabtools_common
capture quietly run tabtools/_tabtools_common.ado

* --- Setup data ---
sysuse auto, clear

* Label foreign for nicer table display
label define origin_lbl 0 "Domestic" 1 "Foreign", replace
label values foreign origin_lbl

* --- 1. Console output: table1_tc descriptive table ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg

noisily table1_tc, by(foreign) ///
    vars(price contn %9.0fc \ mpg contn %5.1f \ weight contn %9.0fc \ ///
         length contn %5.1f \ rep78 cat)

log close demo

* --- 2. Excel: table1_tc export ---
table1_tc, by(foreign) ///
    vars(price contn %9.0fc \ mpg contn %5.1f \ weight contn %9.0fc \ ///
         length contn %5.1f \ rep78 cat) ///
    title("Table 1. Characteristics by Vehicle Origin") ///
    excel("`pkg_dir'/table1.xlsx") sheet("Table 1")

* --- Cleanup ---
clear
