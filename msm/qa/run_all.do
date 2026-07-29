* run_all.do
*
* Master runner for the msm QA surface.
*
* Curated scope (see qa/README.md for the named inventory):
*   - quick:       30 functional/regression suites
*   - validations:  7 known-answer/recovery suites
*   - crossval:     2 R/Python parity suites
*   - full:        all 39 suites (default)
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
    local suite_list "test_qa_harness test_msm test_msm_table test_msm_options test_msm_expanded test_msm_status test_msm_weight_ergonomics test_msm_period_basis test_msm_fit_guidance test_msm_cox_state test_msm_continuous_exposure test_msm_weight_failures test_msm_weight_adversarial test_msm_prepare_validate_adversarial test_msm_state_guards test_msm_state_identity test_msm_transaction_regressions test_msm_history_positivity_regressions test_msm_risk_process_regressions test_msm_fit_prediction_regressions test_msm_diagnostics_output_regressions test_msm_release_option_regressions test_package_release test_demo_contract test_msm_psdash_contract test_export_surface test_msm_diagtab test_msm_output_adversarial test_msm_diagnostic_contracts test_msm_abbrev_reload validation_msm validation_msm_known_answers validation_msm_expanded validation_msm_sensitivity validation_msm_recovery validation_msm_dgp_recovery validation_msm_history_recovery"
}
else if "`mode'" == "quick" {
    local suite_list "test_qa_harness test_msm test_msm_table test_msm_options test_msm_expanded test_msm_status test_msm_weight_ergonomics test_msm_period_basis test_msm_fit_guidance test_msm_cox_state test_msm_continuous_exposure test_msm_weight_failures test_msm_weight_adversarial test_msm_prepare_validate_adversarial test_msm_state_guards test_msm_state_identity test_msm_transaction_regressions test_msm_history_positivity_regressions test_msm_risk_process_regressions test_msm_fit_prediction_regressions test_msm_diagnostics_output_regressions test_msm_release_option_regressions test_package_release test_demo_contract test_msm_psdash_contract test_export_surface test_msm_diagtab test_msm_output_adversarial test_msm_diagnostic_contracts test_msm_abbrev_reload"
}
else if "`mode'" == "validations" {
    local suite_list "validation_msm validation_msm_known_answers validation_msm_expanded validation_msm_sensitivity validation_msm_recovery validation_msm_dgp_recovery validation_msm_history_recovery"
}
else if "`mode'" == "crossval" {
    local suite_list "crossval_msm crossval_external_models"
}
else if "`mode'" == "full" {
    local suite_list "test_qa_harness test_msm test_msm_table test_msm_options test_msm_expanded test_msm_status test_msm_weight_ergonomics test_msm_period_basis test_msm_fit_guidance test_msm_cox_state test_msm_continuous_exposure test_msm_weight_failures test_msm_weight_adversarial test_msm_prepare_validate_adversarial test_msm_state_guards test_msm_state_identity test_msm_transaction_regressions test_msm_history_positivity_regressions test_msm_risk_process_regressions test_msm_fit_prediction_regressions test_msm_diagnostics_output_regressions test_msm_release_option_regressions test_package_release test_demo_contract test_msm_psdash_contract test_export_surface test_msm_diagtab test_msm_output_adversarial test_msm_diagnostic_contracts test_msm_abbrev_reload validation_msm validation_msm_known_answers validation_msm_expanded validation_msm_sensitivity validation_msm_recovery validation_msm_dgp_recovery validation_msm_history_recovery crossval_msm crossval_external_models"
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

* Fail if a curated lane silently omits or names a suite. Explicit lists remain
* readable, while this inventory check prevents a newly added file from becoming
* an unrun orphan.
local discovered ""
if inlist("`mode'", "quick", "core", "full") {
    local found : dir "`qa_dir'" files "test_*.do"
    foreach f of local found {
        local stem = substr("`f'", 1, strlen("`f'") - 3)
        local discovered "`discovered' `stem'"
    }
}
if inlist("`mode'", "validations", "core", "full") {
    local found : dir "`qa_dir'" files "validation_*.do"
    foreach f of local found {
        local stem = substr("`f'", 1, strlen("`f'") - 3)
        local discovered "`discovered' `stem'"
    }
}
if inlist("`mode'", "crossval", "full") {
    local found : dir "`qa_dir'" files "crossval_*.do"
    foreach f of local found {
        local stem = substr("`f'", 1, strlen("`f'") - 3)
        local discovered "`discovered' `stem'"
    }
}
local omitted : list discovered - suite_list
local stale   : list suite_list - discovered
if "`omitted'" != "" | "`stale'" != "" {
    display as error "QA lane inventory mismatch"
    if "`omitted'" != "" display as error "  omitted:`omitted'"
    if "`stale'"   != "" display as error "  missing files:`stale'"
    log close master
    sysdir set PLUS "`original_plus'"
    sysdir set PERSONAL "`original_personal'"
    macro drop msm_qa_plus_dir msm_qa_personal_dir
    exit 459
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

    capture macro drop msm_qa_result_name msm_qa_result_tests ///
        msm_qa_result_pass msm_qa_result_fail msm_qa_result_skip
    capture noisily do "`qa_dir'/`suite'.do"
    local suite_rc = _rc
    local child_tests = real("${msm_qa_result_tests}")
    local child_pass  = real("${msm_qa_result_pass}")
    local child_fail  = real("${msm_qa_result_fail}")
    local child_skip  = real("${msm_qa_result_skip}")

    if `suite_rc' == 0 {
        if "${msm_qa_result_name}" != "`suite'" | ///
                missing(`child_tests', `child_pass', `child_fail', `child_skip') | ///
                `child_tests' != `child_pass' + `child_fail' + `child_skip' | ///
                `child_fail' != 0 {
            display as error "FAILED: `suite'.do did not publish a clean, reconciled QA result"
            display as error "  name=${msm_qa_result_name} tests=`child_tests' pass=`child_pass' fail=`child_fail' skip=`child_skip'"
            local suite_rc = 459
        }
    }

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
    file write `status_fh' "suite=`suite' rc=`suite_rc' tests=`child_tests' pass=`child_pass' fail=`child_fail' skip=`child_skip'" _n
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

display as text "RESULT: run_all tests=`suite_count' pass=`pass_count' fail=`fail_count' skip=0"

sysdir set PLUS "`original_plus'"
sysdir set PERSONAL "`original_personal'"
macro drop msm_qa_plus_dir msm_qa_personal_dir

if `fail_count' > 0 exit 1
