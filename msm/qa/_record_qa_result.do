* _record_qa_result.do
*
* Child-suite handshake for run_all.do. A suite calls this only after all of
* its checks have run. The helper refuses impossible arithmetic and publishes
* the reconciled counts in globals that the parent runner verifies.

version 16.0
args suite tests passed failed skipped

if "`skipped'" == "" local skipped 0

foreach field in tests passed failed skipped {
    local n_`field' = real("``field''")
    if missing(`n_`field'') | `n_`field'' < 0 | ///
            `n_`field'' != floor(`n_`field'') {
        display as error "invalid QA `field' count: ``field''"
        exit 198
    }
}

if "`suite'" == "" {
    display as error "QA result is missing its suite name"
    exit 198
}
if `n_tests' != `n_passed' + `n_failed' + `n_skipped' {
    display as error "QA result arithmetic does not reconcile: " ///
        "tests=`n_tests' pass=`n_passed' fail=`n_failed' skip=`n_skipped'"
    exit 459
}

global msm_qa_result_name "`suite'"
global msm_qa_result_tests "`n_tests'"
global msm_qa_result_pass "`n_passed'"
global msm_qa_result_fail "`n_failed'"
global msm_qa_result_skip "`n_skipped'"
