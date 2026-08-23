* test_msm_documentation_examples.do -- literal shared help workflow

clear all
version 16.0
set varabbrev off
local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0

* These setup lines are printed in five shipped help files; retain the URL verbatim.
local ++test_count
capture noisily {
    capture confirm file msm_example.dta
    if _rc net get msm, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/msm") replace
    use msm_example.dta, clear
    msm_protocol,
    msm_prepare, id(id) period(period) treatment(treatment)
    msm_validate, strict verbose
    msm_weight, treat_d_cov(biomarker comorbidity age sex)
    msm_diagnose, balance_covariates(biomarker comorbidity age sex)
    msm_fit, model(logistic) outcome_cov(age sex) nolog
    msm_predict, times(3 5 7 9) difference seed(12345)
    matrix list r(predictions)
    msm_sensitivity, evalue
    msm_report, eform
    msm, status
    assert r(fitted) == 1
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Plot and export examples use the same documented pipeline.
local ++test_count
capture noisily {
    msm_plot, type(weights)
    assert "`r(plot_type)'" == "weights"
    msm_plot, type(balance) threshold(0.1)
    assert "`r(plot_type)'" == "balance"
    msm_report, export(results.xlsx) format(excel) eform zebra replace
    confirm file results.xlsx
    msm_table, xlsx(tables.xlsx) predictions balance replace
    confirm file tables.xlsx
}
if _rc == 0 local ++pass_count
else local ++fail_count

capture erase results.xlsx
capture erase tables.xlsx
capture graph close _all
do "`qa_dir'/_record_qa_result.do" test_msm_documentation_examples ///
    `test_count' `pass_count' `fail_count' 0
display "RESULT: test_msm_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 exit 1
