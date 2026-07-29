* _cleanup_runtime_artifacts.do
* Remove disposable QA logs and cross-validation byproducts from msm/qa.

version 16.0

local qa_dir "`c(pwd)'"

* Concern-based globs keep cleanup synchronized when a suite is added or
* renamed. They are deliberately scoped to this qa/ directory.
foreach pattern in "test_*.log" "validation_*.log" "crossval_*.log" "msm_*.log" {
    local logs : dir "`qa_dir'" files "`pattern'"
    foreach f of local logs {
        capture erase "`qa_dir'/`f'"
    }
}
capture erase "`qa_dir'/_cleanup_runtime_artifacts.log"
capture erase "`qa_dir'/run_all_runner.log"

* Deliberately do not erase run_all.log or the compatibility
* run_all_validations.log here. In batch mode Stata opens that file before this
* do-file starts; erasing it unlinks the only log that survives child suites'
* `log close _all` calls (audit finding N06).

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
