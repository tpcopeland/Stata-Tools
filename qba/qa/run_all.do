* run_all.do -- curated qba QA lanes
* Usage: cd qba/qa && stata-mp -b do run_all.do [quick|core|full|crossval]

clear all
version 16.0

args mode extra
local mode = lower(strtrim("`mode'"))
if "`mode'" == "" local mode "full"
if "`extra'" != "" {
    display as error "run_all.do accepts one lane argument"
    exit 198
}
if !inlist("`mode'", "quick", "core", "full", "crossval") {
    display as error "unknown lane `mode'; choose quick, core, full, or crossval"
    exit 198
}

do "_qba_qa_common.do"

local qa_dir "`c(pwd)'"
_qba_qa_isolate
local _orig_plus `"`r(orig_plus)'"'
local _orig_personal `"`r(orig_personal)'"'
local _qba_plus `"`r(plusdir)'"'
local _qba_personal `"`r(personaldir)'"'

local quick_suites test_qba test_qba_v110 test_qba_v111 test_qba_v112 ///
    test_qba_fml2023 ///
    test_qba_contract_detect ///
    test_qba_qa_common_bootstrap test_qba_qa_assert_helpers ///
    test_qba_qa_text_assertions test_qba_qa_manifest_sync ///
    test_refactor_distribution_loader_install ///
    test_refactor_distribution_autoload ///
    test_refactor_distribution_parser_contracts ///
    test_refactor_mc_return_contracts test_refactor_mc_known_answer ///
    test_refactor_rng_contracts ///
    test_refactor_saving_parser_adversarial ///
    test_refactor_save_failure_contracts test_refactor_saved_schema ///
    test_refactor_qba_plot_cell_contracts test_refactor_qba_plot_contracts ///
    test_refactor_qba_plot_parser_adversarial ///
    test_refactor_qba_plot_install_smoke test_refactor_qba_plot_sideeffects

local validation_suites validation_qba validation_qba_boundaries ///
    validation_qba_known_misclass validation_qba_known_selection ///
    validation_qba_known_confound validation_qba_known_multi ///
    validation_qba_known_plot

local adversarial_suites test_qba_adversarial_misclass ///
    test_qba_adversarial_misclass_deep ///
    test_qba_adversarial_selection_confound test_qba_adversarial_selection_deep ///
    test_qba_adversarial_confound_deep ///
    test_qba_adversarial_multi_plot test_qba_adversarial_multi_deep

local release_suites test_qba_docs test_qba_plot_release_deep
local crossval_suites crossval_python_qba crossval_external_qba ///
    crossval_fml_totalerror
local core_suites `quick_suites' `validation_suites' ///
    `adversarial_suites' `release_suites'

if "`mode'" == "quick" local suites `quick_suites'
else if "`mode'" == "core" local suites `core_suites'
else if "`mode'" == "crossval" local suites `crossval_suites'
else local suites `core_suites' `crossval_suites'

local pass = 0
local fail = 0
local skip = 0

foreach f of local suites {
    capture noisily do "`qa_dir'/`f'.do"
    local rc = _rc
    capture sysdir set PLUS "`_qba_plus'"
    capture sysdir set PERSONAL "`_qba_personal'"
    capture ado uninstall qba
    if `rc' == 77 {
        local ++skip
        display as text "SKIPPED: `f'.do (optional dependency)"
    }
    else if `rc' {
        local ++fail
        display as error "FAILED: `f'.do (error `rc')"
    }
    else {
        local ++pass
        display as result "PASSED: `f'.do"
    }
}

capture sysdir set PLUS "`_orig_plus'"
capture sysdir set PERSONAL "`_orig_personal'"
capture shell rm -rf "`_qba_plus'" "`_qba_personal'"

display as text ""
display as result "=== `mode' QA Summary: `pass' passed, `fail' failed, `skip' skipped ==="
local tests = `pass' + `fail' + `skip'
local skip_is_failure = (`skip' > 0 & inlist("`mode'", "full", "crossval"))
if `fail' > 0 | `skip_is_failure' {
    display "RESULT: run_all tests=`tests' pass=`pass' fail=`fail' skip=`skip'"
    exit 1
}
display "RESULT: run_all tests=`tests' pass=`pass' fail=`fail' skip=`skip'"
