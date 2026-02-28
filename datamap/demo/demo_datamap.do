/*  demo_datamap.do - Generate screenshots for datamap package

    Produces 1 output type:
      1. Console output (datadict markdown generation) -> .smcl
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "datamap/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload commands ---
capture program drop datadict
capture program drop WriteVariableRow
capture program drop FormatStatNumber
capture program drop GetCategoricalStats
capture program drop GetUnlabeledStats
capture program drop GetValueLabelString
capture program drop EscapeMarkdown
capture program drop ProcessOneDataset
capture program drop ProcessCombined
capture program drop ProcessSeparate
capture program drop CollectFromFilelistOption
capture program drop CollectFromDir
capture program drop RecursiveScan
capture program drop CountFiles
capture program drop CollectDatasetNames
capture program drop MakeAnchor
quietly run datamap/datadict.ado

* --- Setup: save sysuse auto as a .dta file for scanning ---
sysuse auto, clear
quietly save "`pkg_dir'/_demo_auto.dta", replace

* --- 1. Console output: datadict markdown report ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg
noisily datadict, single("`pkg_dir'/_demo_auto.dta") ///
    output("`pkg_dir'/_datadict_report.md") missing stats

* Report preview
noisily type "`pkg_dir'/_datadict_report.md"

log close demo

* --- Cleanup ---
capture erase "`pkg_dir'/_demo_auto.dta"
capture erase "`pkg_dir'/_datadict_report.md"
clear
