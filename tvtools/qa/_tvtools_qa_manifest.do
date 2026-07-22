*! _tvtools_qa_manifest.do
*! Curated tvtools QA lanes and pinned result counts.
*!
*! This file is included by run_all.do, so its locals are created in the
*! runner's scope. Keep manifest_suites, manifest_counts, and
*! manifest_allow_skips positionally aligned.
*! Install hygiene is owned by _tvtools_qa_common.do::_tvtools_qa_bootstrap.

**# Curated lanes

local quick_suites test_package_runner_contract ///
    test_tvage test_tvband test_tvsplit ///
    test_tvevent test_tvexpose test_tvmerge ///
    test_tvpanel test_tvweight test_tvdiagnose test_tvtools ///
    test_options test_integration test_edge_cases test_verbose ///
    test_frames_input test_default_naming test_package_state ///
    test_help_examples

local core_only_suites test_regressions test_tvm_point_engine ///
    validation_phase0_semantics validation_contracts ///
    validation_audit_tvexpose validation_audit_tvmerge ///
    validation_audit_tvevent validation_audit_tvpanel ///
    validation_audit_tvweight validation_audit_tvdiagnose ///
    validation_audit_tvsplit ///
    test_package_fixtures ///
    validation_known_answers validation_dgp_known_answers ///
    validation_dgp_known_answers2 ///
    validation_tvage validation_tvband validation_tvsplit ///
    validation_tvevent validation_tvexpose ///
    validation_tvexpose_statetime ///
    validation_tvmerge validation_tvpanel ///
    validation_tvweight validation_tvweight_balance ///
    validation_tvweight_recovery validation_tvweight_msm_recovery ///
    validation_tvdiagnose validation_flow ///
    validation_boundary validation_pipeline validation_supplemental ///
    crossval_tvmerge_mata crossval_tvexpose_expand crossval_tvtools

local external_suites crossval_tvsplit_lexis crossval_tvweight_ipcw ///
    crossval_tvevent_recurring test_tvm_overlap_drift_guard ///
    test_package_optional_integration

local core_suites `quick_suites' `core_only_suites'
local full_suites `core_suites' `external_suites'
local release_suites `full_suites' test_package_release
local release_delegated_suites test_dialogs_gui.do
local meta_suites test_package_runner_contract

**# Pinned result contracts

local manifest_suites test_package_runner_contract ///
    test_tvage test_tvband test_tvsplit test_tvevent test_tvexpose ///
    test_tvmerge test_tvpanel test_tvweight test_tvdiagnose test_tvtools ///
    test_options test_integration test_edge_cases test_verbose ///
    test_frames_input test_default_naming test_package_state ///
    test_help_examples ///
    test_regressions test_tvm_point_engine validation_phase0_semantics ///
    validation_contracts validation_audit_tvexpose validation_audit_tvmerge ///
    validation_audit_tvevent validation_audit_tvpanel ///
    validation_audit_tvweight validation_audit_tvdiagnose ///
    validation_audit_tvsplit ///
    test_package_fixtures validation_known_answers ///
    validation_dgp_known_answers validation_dgp_known_answers2 ///
    validation_tvage validation_tvband validation_tvsplit ///
    validation_tvevent validation_tvexpose validation_tvexpose_statetime ///
    validation_tvmerge validation_tvpanel validation_tvweight ///
    validation_tvweight_balance validation_tvweight_recovery ///
    validation_tvweight_msm_recovery validation_tvdiagnose validation_flow ///
    validation_boundary validation_pipeline validation_supplemental ///
    crossval_tvmerge_mata crossval_tvexpose_expand crossval_tvtools ///
    crossval_tvsplit_lexis crossval_tvweight_ipcw ///
    crossval_tvevent_recurring test_tvm_overlap_drift_guard ///
    test_package_optional_integration test_package_release

local manifest_counts 11 ///
    39 8 8 27 38 ///
    21 13 43 19 15 ///
    87 22 15 22 ///
    7 5 21 ///
    9 ///
    165 4 7 ///
    15 28 14 15 9 9 7 7 4 29 ///
    20 25 ///
    13 4 2 ///
    84 177 2 ///
    76 4 20 ///
    11 4 ///
    5 8 5 ///
    20 16 47 ///
    9 5 7 ///
    3 3 ///
    2 4 ///
    4 11

* Only external-oracle suites may report a dependency-absence skip, and only
* when the standalone external lane is requested. Full/release override these
* flags and require zero skips.
local manifest_allow_skips ""
forvalues i = 1/54 {
    local manifest_allow_skips "`manifest_allow_skips' 0"
}
local manifest_allow_skips "`manifest_allow_skips' 1 1 1 0 0 0"
