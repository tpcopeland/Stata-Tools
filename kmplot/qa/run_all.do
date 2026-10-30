* run_all.do
* Curated kmplot QA lane runner
* Author: Timothy P Copeland, Karolinska Institutet

clear all
version 16.0

args mode extra
if "`extra'" != "" {
    display as error "run_all.do accepts at most one lane argument"
    exit 198
}
if "`mode'" == "" {
    local mode "full"
}
if !inlist("`mode'", "quick", "core", "full", "calibration") {
    display as error "mode must be quick, core, full, or calibration"
    exit 198
}

local quick_suites "test_kmplot.do test_kmplot_errors.do"
local core_suites "validation_fixture_truth.do test_fixture_domains.do `quick_suites' test_kmplot_v124.do test_kmplot_v125.do test_kmplot_v126.do test_kmplot_v127.do test_kmplot_v129.do test_kmplot_v1210.do test_kmplot_v130.do test_kmplot_v131.do test_kmplot_v140.do test_kmplot_v141.do test_kmplot_v142.do test_kmplot_v143.do test_kmplot_v101.do test_kmplot_output.do validation_kmplot_recovery.do validation_kmplot.do validation_kmplot_cif_oracle.do test_kmplot_compete_errors.do test_kmplot_riskweight_mask.do test_kmplot_axis_layout.do test_kmplot_timegrid.do test_kmplot_text_options.do test_kmplot_saved_files.do"
local full_suites "`core_suites' crossval_kmplot_sts.do crossval_kmplot_survfit.do crossval_kmplot_cif.do test_documentation_examples.do"
* Coverage simulations (R = 1000 each): KM survival, and the compete()
* cumulative incidence. Not in full: the bounds they calibrate are pinned
* exactly by validation_kmplot.do (closed form), crossval_kmplot_survfit.do
* (R survfit, all three transforms) and crossval_kmplot_cif.do (stcompet, all
* three transforms). Optional: run them when the interval code changes.
local calibration_suites "validation_kmplot_calibration.do validation_kmplot_cif_calibration.do"
local suites "``mode'_suites'"

local qa_dir "`c(pwd)'"
do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap

local suite_count = 0
local pass_count = 0
local fail_count = 0

foreach suite of local suites {
    local ++suite_count
    display as text "Running `suite'"
    capture noisily do "`suite'"
    local suite_rc = _rc
    if `suite_rc' == 0 {
        local ++pass_count
        display as result "  PASS: `suite'"
    }
    else {
        local ++fail_count
        display as error "  FAIL: `suite' (rc=`suite_rc')"
    }
}

display as text "kmplot QA suites: `pass_count'/`suite_count' passed"
display "RESULT: run_all tests=`suite_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 {
    exit 1
}
