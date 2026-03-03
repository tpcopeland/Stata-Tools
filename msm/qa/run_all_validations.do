/*******************************************************************************
* run_all_validations.do
*
* Master runner for msm package tests and validation exercises.
* Runs functional tests (T1-T2) and 8 validation suites (V1-V8).
*
* Usage:
*   stata-mp -b do run_all_validations.do              // runs all
*   stata-mp -b do run_all_validations.do 1 5 8        // runs T1/T2, V1, V5, V8
*   stata-mp -b do run_all_validations.do tests        // runs T1 + T2 only
*   stata-mp -b do run_all_validations.do validations   // runs V1-V8 only
*
* Tests:
*   T1. Functional tests (test_msm.do)
*   T2. Table export tests (test_msm_table.do)
*
* Validations:
*   V1. Known DGP with time-varying confounding (N=10,000, T=10)
*   V2. R ipw cross-validation (haartdat, HIV/HAART)
*   V3. NHEFS benchmarks (Ch12 point treatment + Ch17 person-period)
*   V4. Fewell RA/Methotrexate DGP (treatment-confounder feedback)
*   V5. Null effect & reproducibility (true effect = 0, 100 MC reps)
*   V6. IPCW / Informative censoring
*   V7. Diagnostics, reporting, sensitivity
*   V8. Pipeline guards & edge cases
*******************************************************************************/

version 16.0
set more off
set varabbrev off

local qa_dir "/home/tpcopeland/Stata-Dev/msm/qa"

capture log close _all
log using "`qa_dir'/run_all_validations.log", replace name(master)

display "MSM PACKAGE QA SUITE"
display "Date: $S_DATE $S_TIME"
display ""

timer clear
timer on 99

* --- Determine what to run ---
local run_list "`0'"

local do_tests = 0
local do_validations = 0

if "`run_list'" == "" {
    local do_tests = 1
    local do_validations = 1
    display "Running ALL tests and validations"
}
else if "`run_list'" == "tests" {
    local do_tests = 1
    display "Running functional tests only (T1-T2)"
}
else if "`run_list'" == "validations" {
    local do_validations = 1
    display "Running validation suites only (V1-V8)"
}
else {
    local do_tests = 1
    local do_validations = 1
    display "Running selective: `run_list'"
}
display ""

* --- Test file map ---
local tfile_1  "test_msm.do"
local tname_1  "Functional Tests"
local tfile_2  "test_msm_table.do"
local tname_2  "Table Export Tests"

* --- Validation file map ---
local vfile_1  "validate_known_dgp.do"
local vname_1  "Known DGP (Cole & Hernan)"
local vfile_2  "validate_haartdat_r.do"
local vname_2  "R ipw Cross-Validation (haartdat)"
local vfile_3  "validate_nhefs.do"
local vname_3  "NHEFS Benchmarks (Ch12 + Ch17)"
local vfile_4  "validate_fewell_ra.do"
local vname_4  "Fewell RA/Methotrexate DGP"
local vfile_5  "validate_null_repro.do"
local vname_5  "Null Effect & Reproducibility"
local vfile_6  "validate_ipcw.do"
local vname_6  "IPCW / Informative Censoring"
local vfile_7  "validate_diagnostics.do"
local vname_7  "Diagnostics, Reporting, Sensitivity"
local vfile_8  "validate_edge_cases.do"
local vname_8  "Pipeline Guards & Edge Cases"

* --- Run functional tests ---
if `do_tests' {
    forvalues t = 1/2 {
        display "Running Test `t': `tname_`t''..."
        timer on 1`t'
        do "`qa_dir'/`tfile_`t''"
        timer off 1`t'
        display ""
    }
}

* --- Run selected validations ---
if `do_validations' {
    if "`run_list'" == "" | "`run_list'" == "validations" {
        numlist "1/8"
        local vrun_list "`r(numlist)'"
    }
    else {
        local vrun_list "`run_list'"
    }

    foreach v of local vrun_list {
        if "`vfile_`v''" != "" {
            display "Running Validation `v': `vname_`v''..."
            timer on `v'
            do "`qa_dir'/`vfile_`v''"
            timer off `v'
            display ""
        }
        else {
            display as error "Unknown validation number: `v'"
        }
    }
}

timer off 99

* --- Summary ---
display ""
display "QA SUITE COMPLETE"
display ""
timer list

log close master
