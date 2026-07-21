* run_all.do
*
* Master runner for the msm QA surface.
*
* Default scope: full Stata and cross-language QA in this package
*   - test_msm.do            (core functional, T1)
*   - test_msm_table.do      (msm_table workbook export, T2)
*   - test_msm_options.do    (per-command option-path coverage, T3)
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
*   - test_msm_state_identity.do
*   - test_msm_independent_review.do
*   - test_msm_phase3.do
*   - test_msm_phase2.do
*   - test_msm_phase4.do
*   - test_msm_phase5.do
*   - test_msm_psdash_contract.do
*   - test_export_surface.do
*   - test_msm_diagtab.do
*   - test_msm_output_adversarial.do
*   - test_msm_abbrev_reload.do
*   - validation_msm.do
*   - validation_msm_known_answers.do
*   - validation_msm_expanded.do
*   - validation_msm_sensitivity.do
*   - validation_msm_recovery.do      (known-truth marginal log-OR recovery)
*   - validation_msm_dgp_recovery.do  (broad known-truth DGP recovery battery)
*   - validation_msm_phase3_recovery.do (treatment-history regime recovery)
*
* Optional cross-language scope:
*   - crossval_msm.do
*   - crossval_external_models.do
*
* Usage:
*   stata-mp -b do run_all.do              // full release gate (default)
*   stata-mp -b do run_all.do quick        // functional and export tests
*   stata-mp -b do run_all.do core         // all Stata-side QA
*   stata-mp -b do run_all.do validations  // Stata validation suites
*   stata-mp -b do run_all.do crossval     // cross-language only
* Legacy aliases: tests=quick, stata=core, all=full.

version 16.0
set more off
set varabbrev off

local qa_dir "`c(pwd)'"
local runner_log "`qa_dir'/run_all_runner.log"
local status_file "`qa_dir'/run_all_status.txt"
local original_plus "`c(sysdir_plus)'"
local original_personal "`c(sysdir_personal)'"

* Process-unique install sandbox inherited by every child suite.
tempfile plus_anchor personal_anchor
global msm_qa_plus_dir "`plus_anchor'_plus"
global msm_qa_personal_dir "`personal_anchor'_personal"
capture mkdir "${msm_qa_plus_dir}"
capture mkdir "${msm_qa_personal_dir}"
sysdir set PLUS "${msm_qa_plus_dir}"
sysdir set PERSONAL "${msm_qa_personal_dir}"

capture log close _all
do "`qa_dir'/_cleanup_runtime_artifacts.do"
log using "`runner_log'", replace name(master)

local mode = lower(strtrim("`0'"))
if "`mode'" == "" local mode "full"
if "`mode'" == "default" local mode "full"
if inlist("`mode'", "stataside", "stata") local mode "core"
if "`mode'" == "tests" local mode "quick"
if "`mode'" == "all" local mode "full"

local suite_list ""
if "`mode'" == "core" {
    local suite_list "test_msm test_msm_table test_msm_options test_msm_expanded test_msm_status test_msm_weight_ergonomics test_msm_fit_guidance test_msm_cox_state test_msm_continuous_exposure test_msm_weight_failures test_msm_weight_adversarial test_msm_prepare_validate_adversarial test_msm_state_guards test_msm_state_identity test_msm_independent_review test_msm_phase3 test_msm_phase2 test_msm_phase4 test_msm_phase5 test_msm_phase6 test_package_release test_demo_contract test_msm_psdash_contract test_export_surface test_msm_diagtab test_msm_output_adversarial test_msm_abbrev_reload validation_msm validation_msm_known_answers validation_msm_expanded validation_msm_sensitivity validation_msm_recovery validation_msm_dgp_recovery validation_msm_phase3_recovery"
}
else if "`mode'" == "quick" {
    local suite_list "test_msm test_msm_table test_msm_options test_msm_expanded test_msm_status test_msm_weight_ergonomics test_msm_fit_guidance test_msm_cox_state test_msm_continuous_exposure test_msm_weight_failures test_msm_weight_adversarial test_msm_prepare_validate_adversarial test_msm_state_guards test_msm_state_identity test_msm_independent_review test_msm_phase3 test_msm_phase2 test_msm_phase4 test_msm_phase5 test_msm_phase6 test_package_release test_demo_contract test_msm_psdash_contract test_export_surface test_msm_diagtab test_msm_output_adversarial test_msm_abbrev_reload"
}
else if "`mode'" == "validations" {
    local suite_list "validation_msm validation_msm_known_answers validation_msm_expanded validation_msm_sensitivity validation_msm_recovery validation_msm_dgp_recovery validation_msm_phase3_recovery"
}
else if "`mode'" == "crossval" {
    local suite_list "crossval_msm crossval_external_models"
}
else if "`mode'" == "full" {
    local suite_list "test_msm test_msm_table test_msm_options test_msm_expanded test_msm_status test_msm_weight_ergonomics test_msm_fit_guidance test_msm_cox_state test_msm_continuous_exposure test_msm_weight_failures test_msm_weight_adversarial test_msm_prepare_validate_adversarial test_msm_state_guards test_msm_state_identity test_msm_independent_review test_msm_phase3 test_msm_phase2 test_msm_phase4 test_msm_phase5 test_msm_phase6 test_package_release test_demo_contract test_msm_psdash_contract test_export_surface test_msm_diagtab test_msm_output_adversarial test_msm_abbrev_reload validation_msm validation_msm_known_answers validation_msm_expanded validation_msm_sensitivity validation_msm_recovery validation_msm_dgp_recovery validation_msm_phase3_recovery crossval_msm crossval_external_models"
}
else {
    display as error "Unknown run_all mode: `mode'"
    display as error "Use one of: quick, core, validations, crossval, full"
    log close master
    sysdir set PLUS "`original_plus'"
    sysdir set PERSONAL "`original_personal'"
    macro drop msm_qa_plus_dir msm_qa_personal_dir
    exit 198
}

tempname status_fh
file open `status_fh' using "`status_file'", write text replace
file write `status_fh' "mode=`mode'" _n
file close `status_fh'

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
    local suite_rc = _rc

    * A child may close every named log. Reopen the runner log before recording
    * its disposition so the summary is durable regardless of child hygiene.
    capture log close master
    quietly log using "`runner_log'", append name(master)

    if `suite_rc' {
        display as error "FAILED: `suite'.do (rc=`suite_rc')"
        local ++fail_count
        local failed_suites "`failed_suites' `suite'"
    }
    else {
        display as result "PASSED: `suite'.do"
        local ++pass_count
    }

    file open `status_fh' using "`status_file'", write text append
    file write `status_fh' "suite=`suite' rc=`suite_rc'" _n
    file close `status_fh'
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

file open `status_fh' using "`status_file'", write text append
file write `status_fh' "suites=`suite_count' passed=`pass_count' failed=`fail_count'" _n
file write `status_fh' "failed_suites=`failed_suites'" _n
file close `status_fh'

sysdir set PLUS "`original_plus'"
sysdir set PERSONAL "`original_personal'"
macro drop msm_qa_plus_dir msm_qa_personal_dir

if `fail_count' > 0 exit 1
