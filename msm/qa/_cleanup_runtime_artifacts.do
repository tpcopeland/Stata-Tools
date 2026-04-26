* _cleanup_runtime_artifacts.do
* Remove disposable QA logs and cross-validation byproducts from msm/qa.

version 16.0

local qa_dir "`c(pwd)'"

foreach f in ///
    _cleanup_runtime_artifacts.log ///
    run_all_validations.log ///
    test_export_surface.log ///
    test_msm.log ///
    test_msm_state_guards.log ///
    test_msm_status.log ///
    test_msm_weight_ergonomics.log ///
    test_msm_fit_guidance.log ///
    test_msm_cox_state.log ///
    test_msm_weight_failures.log ///
    test_msm_expanded.log ///
    validation_msm.log ///
    validation_msm_known_answers.log ///
    validation_msm_expanded.log ///
    validation_msm_sensitivity.log ///
    crossval_msm.log {
    capture erase "`qa_dir'/`f'"
}

local orphan_logs : dir "`qa_dir'" files "msm_*.log"
foreach f of local orphan_logs {
    capture erase "`qa_dir'/`f'"
}

foreach f in ///
    crossval_data/dgp1_panel.csv ///
    crossval_data/dgp1_panel.dta ///
    crossval_data/dgp2_point.csv ///
    crossval_data/dgp2_point.dta ///
    crossval_data/dgp3_true_counterfactual.csv ///
    crossval_data/dgp3_true_counterfactual.dta ///
    crossval_results/crossval_summary.csv ///
    crossval_results/py_output.log ///
    crossval_results/py_results.csv ///
    crossval_results/py_weights_dgp1.csv ///
    crossval_results/py_weights_dgp2.csv ///
    crossval_results/r_output.log ///
    crossval_results/r_results.csv ///
    crossval_results/r_weights_dgp1.csv ///
    crossval_results/r_weights_dgp2.csv ///
    crossval_results/stata_results_dgp1.csv ///
    crossval_results/stata_weights_dgp1.csv ///
    crossval_results/stata_weights_dgp2.csv {
    capture erase "`qa_dir'/`f'"
}
