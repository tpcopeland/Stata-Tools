* run_all.do — runs complete QA suite for psdash
* Usage: cd psdash/qa && stata-mp -b do run_all.do [quick|external|full]

local qa_dir "`c(pwd)'"
args mode extra
local mode = lower(strtrim("`mode'"))
if "`mode'" == "" local mode "full"
if "`extra'" != "" | !inlist("`mode'", "quick", "external", "full") {
    display as error "run_all.do accepts one lane: quick, external, or full"
    exit 198
}
local pass = 0
local fail = 0
local skip = 0

local suites_quick test_psdash.do validation_psdash.do validation_known_answers.do ///
    validation_multigroup_longitudinal.do ///
    test_refactor_qa_bootstrap_contract.do test_refactor_install_autoload.do ///
    test_refactor_doc_contract.do test_refactor_display_contracts.do ///
    test_refactor_option_abbrev_contract.do ///
    test_refactor_return_contracts.do test_refactor_graph_export_failures.do ///
    test_saving_format_contract.do ///
    test_qa_contract_gaps.do ///
    test_tmle_ltmle_contract.do ///
    test_msm_tte_contract.do ///
    test_iivw_contract.do ///
    test_multigroup_detect.do test_multigroup_overlap_support.do ///
    test_multigroup_balance_weights.do ///
    test_adversarial.do test_detect_dispatch_adversarial.do ///
    test_binary_balance_weights_adversarial.do ///
    test_overlap_support_multigroup_adversarial.do ///
    test_multigroup_psvars_regression.do ///
    test_v130_features.do test_v140_features.do test_v141_features.do ///
    test_rb01_verdict.do test_rb02_gps_positivity.do ///
    test_rb03_factor_expansion.do test_rb0405_teffects_sample.do ///
    test_rb06_estimand.do ///
    test_rb08_vr_count.do test_rb09_weight_thresholds.do ///
    test_rb10_longitudinal.do test_rb11_trim_guard.do ///
    test_remaining_audit_regressions.do test_producer_contracts.do ///
    test_real_producer_integrations.do ///
    test_excel_fidelity.do test_return_surface_remaining.do

local suites_external crossval_psdash.do crossval_python_psdash.do ///
    crossval_external_references.do

if "`mode'" == "quick" local suite_files "`suites_quick'"
else if "`mode'" == "external" local suite_files "`suites_external'"
else local suite_files "`suites_quick' `suites_external'"

display as text "psdash QA lane: `mode'"

foreach f of local suite_files {
    capture noisily do "`qa_dir'/`f'"
    local rc = _rc
    if `rc' == 77 {
        local ++skip
        display as text "SKIPPED: `f' (dependency unavailable)"
    }
    else if `rc' {
        local ++fail
        display as error "FAILED: `f' (rc=`rc')"
    }
    else {
        local ++pass
        display as result "PASSED: `f'"
    }
}

display ""
display as text "=== QA Summary: `pass' passed, `fail' failed, `skip' skipped ==="
if `fail' > 0 exit 1
if `skip' > 0 exit 77
