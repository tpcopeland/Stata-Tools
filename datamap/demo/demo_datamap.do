/*  demo_datamap.do - Generate screenshots for datamap package

    Produces 2 output types:
      1. Console output (datamap text documentation) -> .smcl
      2. Console output (datadict markdown dictionary) -> .smcl
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "datamap/demo"
capture mkdir "`pkg_dir'"

* --- Setup: save sysuse auto as a .dta file for scanning ---
sysuse auto, clear
label data "1978 Automobile Data"
quietly save "`pkg_dir'/_demo_auto.dta", replace

* =========================================================================
* 1. datamap — privacy-safe text documentation with autodetect + quality
* =========================================================================
capture program drop datamap
capture program drop CollectFromFilelistOption
capture program drop CollectFromDir
capture program drop RecursiveScan
capture program drop ProcessCombined
capture program drop ProcessSeparate
capture program drop ProcessDataset
capture program drop ProcessVariables
capture program drop ProcessCategorical
capture program drop ProcessContinuous
capture program drop ProcessDate
capture program drop ProcessString
capture program drop ProcessExcluded
capture program drop ProcessValueLabels
capture program drop ProcessBinary
capture program drop ProcessQuality
capture program drop ProcessSamples
capture program drop DetectPanel
capture program drop DetectSurvival
capture program drop DetectSurvey
capture program drop DetectCommon
capture program drop SummarizeMissing
capture program drop GenerateDatasetSummary
quietly run datamap/datamap.ado

log using "`pkg_dir'/console_datamap.smcl", replace smcl name(dm) nomsg
noisily datamap, single("`pkg_dir'/_demo_auto.dta") ///
    output("`pkg_dir'/_datamap_output.txt") ///
    exclude(make) datesafe autodetect quality
log close dm

* =========================================================================
* 2. datadict — markdown data dictionary with stats and missing
* =========================================================================
* Drop all programs (shared names between the two .ado files)
capture program drop datamap
capture program drop datadict
capture program drop CollectFromFilelistOption
capture program drop CollectFromDir
capture program drop RecursiveScan
capture program drop ProcessCombined
capture program drop ProcessSeparate
capture program drop ProcessDataset
capture program drop ProcessVariables
capture program drop ProcessCategorical
capture program drop ProcessContinuous
capture program drop ProcessDate
capture program drop ProcessString
capture program drop ProcessExcluded
capture program drop ProcessValueLabels
capture program drop ProcessBinary
capture program drop ProcessQuality
capture program drop ProcessSamples
capture program drop DetectPanel
capture program drop DetectSurvival
capture program drop DetectSurvey
capture program drop DetectCommon
capture program drop SummarizeMissing
capture program drop GenerateDatasetSummary
capture program drop WriteVariableRow
capture program drop FormatStatNumber
capture program drop GetCategoricalStats
capture program drop GetUnlabeledStats
capture program drop GetValueLabelString
capture program drop EscapeMarkdown
capture program drop ProcessOneDataset
capture program drop CountFiles
capture program drop CollectDatasetNames
capture program drop MakeAnchor
quietly run datamap/datadict.ado

log using "`pkg_dir'/console_datadict.smcl", replace smcl name(dd) nomsg
noisily datadict, single("`pkg_dir'/_demo_auto.dta") ///
    output("`pkg_dir'/_datadict_report.md") missing stats

* Preview the generated markdown
noisily type "`pkg_dir'/_datadict_report.md"
log close dd

* --- Cleanup ---
capture erase "`pkg_dir'/_demo_auto.dta"
capture erase "`pkg_dir'/_datamap_output.txt"
capture erase "`pkg_dir'/_datadict_report.md"
clear
