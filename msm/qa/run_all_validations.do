* run_all_validations.do
*
* Master runner for the msm QA surface.
*
* Default scope: all Stata-side QA in this package
*   - test_msm.do
*   - test_msm_expanded.do
*   - test_msm_status.do
*   - test_msm_weight_ergonomics.do
*   - test_msm_fit_guidance.do
*   - test_msm_cox_state.do
*   - test_msm_continuous_exposure.do
*   - test_msm_weight_failures.do
*   - test_msm_weight_adversarial.do
*   - test_msm_prepare_validate_adversarial.do
*   - test_msm_state_guards.do
*   - test_export_surface.do
*   - test_msm_output_adversarial.do
*   - test_msm_abbrev_reload.do
*   - validation_msm.do
*   - validation_msm_known_answers.do
*   - validation_msm_expanded.do
*   - validation_msm_sensitivity.do
*   - validation_msm_recovery.do      (known-truth marginal log-OR recovery)
*   - validation_msm_dgp_recovery.do  (broad known-truth DGP recovery battery)
*
* Optional cross-language scope:
*   - crossval_msm.do
*   - crossval_external_models.do
*
* Usage:
*   stata-mp -b do run_all_validations.do              // full Stata-side QA (default)
*   stata-mp -b do run_all_validations.do stata        // same as default
*   stata-mp -b do run_all_validations.do tests        // Stata functional + export tests
*   stata-mp -b do run_all_validations.do validations  // Stata validation suites
*   stata-mp -b do run_all_validations.do crossval     // cross-language only
*   stata-mp -b do run_all_validations.do all          // Stata-side QA + cross-language

version 16.0
set more off
set varabbrev off

local qa_dir "`c(pwd)'"
local runner_log "`c(tmpdir)'/msm_run_all_validations.log"

capture log close _all
do "`qa_dir'/_cleanup_runtime_artifacts.do"
log using "`runner_log'", replace name(master)

local mode = lower(strtrim("`0'"))
if "`mode'" == "" local mode "stata"
if inlist("`mode'", "default", "stataside") local mode "stata"
if "`mode'" == "full" local mode "all"

local suite_list ""
if "`mode'" == "stata" {
    local suite_list "test_msm test_msm_expanded test_msm_status test_msm_weight_ergonomics test_msm_fit_guidance test_msm_cox_state test_msm_continuous_exposure test_msm_weight_failures test_msm_weight_adversarial test_msm_prepare_validate_adversarial test_msm_state_guards test_export_surface test_msm_diagtab test_msm_output_adversarial test_msm_abbrev_reload validation_msm validation_msm_known_answers validation_msm_expanded validation_msm_sensitivity validation_msm_recovery validation_msm_dgp_recovery"
}
else if "`mode'" == "tests" {
    local suite_list "test_msm test_msm_expanded test_msm_status test_msm_weight_ergonomics test_msm_fit_guidance test_msm_cox_state test_msm_continuous_exposure test_msm_weight_failures test_msm_weight_adversarial test_msm_prepare_validate_adversarial test_msm_state_guards test_export_surface test_msm_diagtab test_msm_output_adversarial test_msm_abbrev_reload"
}
else if "`mode'" == "validations" {
    local suite_list "validation_msm validation_msm_known_answers validation_msm_expanded validation_msm_sensitivity validation_msm_recovery validation_msm_dgp_recovery"
}
else if "`mode'" == "crossval" {
    local suite_list "crossval_msm crossval_external_models"
}
else if "`mode'" == "all" {
    local suite_list "test_msm test_msm_expanded test_msm_status test_msm_weight_ergonomics test_msm_fit_guidance test_msm_cox_state test_msm_continuous_exposure test_msm_weight_failures test_msm_weight_adversarial test_msm_prepare_validate_adversarial test_msm_state_guards test_export_surface test_msm_diagtab test_msm_output_adversarial test_msm_abbrev_reload validation_msm validation_msm_known_answers validation_msm_expanded validation_msm_sensitivity validation_msm_recovery validation_msm_dgp_recovery crossval_msm crossval_external_models"
}
else {
    display as error "Unknown run_all_validations mode: `mode'"
    display as error "Use one of: stata, tests, validations, crossval, all"
    log close master
    exit 198
}

display as text "msm QA runner mode: " as result "`mode'"
display as text "Working directory: " as result "`qa_dir'"
display as text ""

local pass_count = 0
local fail_count = 0
local suite_count = 0
local failed_suites ""

timer clear
timer on 99

foreach suite in `suite_list' {
    local ++suite_count
    display as text "========================================"
    display as text "Running `suite'.do"
    display as text "========================================"

    capture noisily do "`qa_dir'/`suite'.do"
    if _rc {
        display as error "FAILED: `suite'.do (rc=`=_rc')"
        local ++fail_count
        local failed_suites "`failed_suites' `suite'"
    }
    else {
        display as result "PASSED: `suite'.do"
        local ++pass_count
    }
    display as text ""
}

timer off 99
quietly timer list 99

display as text "========================================"
display as text "MSM QA RUNNER SUMMARY"
display as text "========================================"
display as text "Suites run: " as result `suite_count'
display as text "Passed:     " as result `pass_count'
display as text "Failed:     " as result `fail_count'
if `fail_count' > 0 {
    display as error "Failed suites:`failed_suites'"
}

capture log close master
do "`qa_dir'/_cleanup_runtime_artifacts.do"
capture erase "`runner_log'"

if `fail_count' > 0 exit 1
