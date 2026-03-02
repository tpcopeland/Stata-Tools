/*  demo_setools.do - Generate screenshots for setools

    Produces 1 output type:
      1. Console output (multiple command demos) -> .smcl
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "setools/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload commands ---
capture program drop setools
quietly run setools/setools.ado

capture program drop cci_se
quietly run setools/cci_se.ado

capture program drop dateparse
capture program drop dateparse_window
capture program drop dateparse_parse
capture program drop dateparse_validate
capture program drop dateparse_inwindow
capture program drop dateparse_filerange
quietly run setools/dateparse.ado

* --- 1. Console output: demonstrate key setools commands ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg

* Package overview
noisily setools, detail

* Charlson Comorbidity Index
use _data/diagnoses.dta, clear
noisily cci_se, id(id) icd(icd) date(visit_date) components noisily

* Date utilities
use _data/cohort.dta, clear
noisily dateparse validate, start("2006-01-01") end("2023-12-31")
noisily dateparse window study_entry, lookback(365) gen(lb_start lb_end)
noisily list id study_entry lb_start lb_end in 1/5

log close demo

* --- Cleanup ---
capture drop lb_start lb_end
clear
