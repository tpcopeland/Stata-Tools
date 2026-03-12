/*******************************************************************************
* run_all_validations.do
*
* Master runner for all tte package validation exercises.
* Runs 20 independent validations and compiles a summary report.
*
* Usage:
*   stata-mp -b do run_all_validations.do           // runs all V1-V20
*   stata-mp -b do run_all_validations.do 1 5 13    // runs V1, V5, V13 only
*
* Validations:
*   1. R TrialEmulation cross-validation (trial_example.dta)
*   2. NHEFS smoking cessation & mortality
*   3. Clone-censor-weight / immortal-time bias (simulated)
*   4. G-formula / time-varying confounding (simulated HIV/ART)
*   5. Known DGP Monte Carlo (50 replications)
*   6. Null effect & reproducibility (true effect = 0, 100 MC reps)
*   7. IPCW / informative censoring
*   8. Grace period correctness
*   9. Edge cases & strict validation
*  10. As-treated (AT) estimand
*  11. Benchmarks (RCT comparison + teffects ipw)
*  12. Sensitivity sweep & stress tests
*  13. Cox model ground truth
*  14. tte_expand options
*  15. tte_predict options
*  16. tte_diagnose and tte_report
*  17. Pipeline guards (out-of-order execution)
*  18. Three-way cross-validation (tte vs emulate vs TrialEmulation)
*  19. Formal equivalence testing (TOST)
*  20. Cox PH gold-standard cross-validation
*******************************************************************************/

version 16.0
set more off
set varabbrev off

* --- Setup (assumes working directory is tte/qa/) ---
capture ado uninstall tte
adopath ++ ".."

capture log close _all
log using "run_all_validations.log", replace nomsg name(master)

display "TTE PACKAGE VALIDATION SUITE"
display "Date: $S_DATE $S_TIME"
display ""

timer clear
timer on 99

* --- Determine which validations to run ---
* Parse arguments: if `0' is empty, run all 1-17; otherwise run specified numbers
local run_list "`0'"

if "`run_list'" == "" {
    numlist "1/20"
    local run_list "`r(numlist)'"
    display "Running ALL validations (V1-V20)"
}
else {
    display "Running selective validations: `run_list'"
}
display ""

* --- Validation file map ---
local vfile_1  "validate_trialemulation.do"
local vname_1  "R TrialEmulation"
local vfile_2  "validate_nhefs.do"
local vname_2  "NHEFS"
local vfile_3  "validate_ccw_immortal.do"
local vname_3  "CCW / Immortal-Time Bias"
local vfile_4  "validate_gformula.do"
local vname_4  "G-Formula / Time-Varying Confounding"
local vfile_5  "validate_known_dgp.do"
local vname_5  "Known DGP Monte Carlo"
local vfile_6  "validate_null_and_repro.do"
local vname_6  "Null Effect & Reproducibility"
local vfile_7  "validate_ipcw.do"
local vname_7  "IPCW / Informative Censoring"
local vfile_8  "validate_grace_period.do"
local vname_8  "Grace Period Correctness"
local vfile_9  "validate_edge_cases.do"
local vname_9  "Edge Cases & Strict Validation"
local vfile_10 "validate_at_estimand.do"
local vname_10 "As-Treated (AT) Estimand"
local vfile_11 "validate_benchmarks.do"
local vname_11 "Benchmarks (RCT + teffects)"
local vfile_12 "validate_sensitivity_stress.do"
local vname_12 "Sensitivity Sweep & Stress Tests"
local vfile_13 "validate_cox_known_dgp.do"
local vname_13 "Cox Model Ground Truth"
local vfile_14 "validate_expand_options.do"
local vname_14 "tte_expand Options"
local vfile_15 "validate_predict_options.do"
local vname_15 "tte_predict Options"
local vfile_16 "validate_diagnose_report.do"
local vname_16 "tte_diagnose and tte_report"
local vfile_17 "validate_pipeline_guards.do"
local vname_17 "Pipeline Guards"
local vfile_18 "validate_three_way.do"
local vname_18 "Three-Way Cross-Validation"
local vfile_19 "validate_equivalence.do"
local vname_19 "Formal Equivalence (TOST)"
local vfile_20 "validate_cox_crossval.do"
local vname_20 "Cox PH Gold-Standard"

* --- Run selected validations ---
foreach v of local run_list {
    if "`vfile_`v''" != "" {
        display "Running Validation `v': `vname_`v''..."
        timer on `v'
        do "`vfile_`v''"
        timer off `v'
        display ""
    }
    else {
        display as error "Unknown validation number: `v'"
    }
}

timer off 99

* --- Summary ---
display ""
display "ALL VALIDATIONS COMPLETE"
display "Validations run: `run_list'"
display ""
timer list

log close master
