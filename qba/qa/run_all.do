* run_all.do -- runs the active qba QA suite
* Usage: cd qba/qa && stata-mp -b do run_all.do

clear all

do "_qba_qa_common.do"

local qa_dir "`c(pwd)'"
_qba_qa_isolate
local _orig_plus `"`r(orig_plus)'"'
local _orig_personal `"`r(orig_personal)'"'
local _qba_plus `"`r(plusdir)'"'
local _qba_personal `"`r(personaldir)'"'

local pass = 0
local fail = 0
local skip = 0

* Active suite.
foreach f in test_qba test_qba_v110 test_qba_v111 test_qba_v112 ///
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
    test_refactor_qba_plot_install_smoke test_refactor_qba_plot_sideeffects ///
    validation_qba validation_qba_boundaries ///
    validation_qba_known_misclass validation_qba_known_selection ///
    validation_qba_known_confound validation_qba_known_multi ///
    validation_qba_known_plot ///
    test_qba_docs test_qba_plot_release_deep ///
    crossval_python_qba crossval_external_qba ///
    test_qba_adversarial_misclass test_qba_adversarial_misclass_deep ///
    test_qba_adversarial_selection_confound test_qba_adversarial_selection_deep ///
    test_qba_adversarial_confound_deep ///
    test_qba_adversarial_multi_plot test_qba_adversarial_multi_deep {
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
display as result "=== QA Summary: `pass' passed, `fail' failed, `skip' skipped ==="
if `fail' > 0 exit 1
