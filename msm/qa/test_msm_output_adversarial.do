* test_msm_output_adversarial.do
* Adversarial QA for output-command error paths and dataset restoration.

version 16.0
clear all
set more off
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

capture program drop _outadv_setup_pipeline
program define _outadv_setup_pipeline
    version 16.0

    local qa_dir "`c(pwd)'"
    local pkg_dir "`qa_dir'/.."

    use "`pkg_dir'/msm_example.dta", clear
    gen long _row_before = _n

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) truncate(1 99) nolog
    msm_fit, model(logistic) outcome_cov(age sex) period_spec(linear) nolog
    msm_predict, times(1 3 5) difference samples(20) seed(24601)
    msm_diagnose, balance_covariates(biomarker comorbidity age sex) threshold(0.1)
    msm_sensitivity, evalue
end

capture program drop _outadv_assert_pipeline_intact
program define _outadv_assert_pipeline_intact
    version 16.0

    assert _N == 4586
    confirm variable id
    confirm variable period
    confirm variable treatment
    confirm variable outcome
    confirm variable biomarker
    confirm variable _row_before
    assert _row_before == _n
    assert "`: char _dta[_msm_prepared]'" == "1"
    assert "`: char _dta[_msm_weighted]'" == "1"
    assert "`: char _dta[_msm_fitted]'" == "1"
    confirm variable _msm_weight
    confirm matrix _msm_fit_b
end

display as text ""
display as text "{hline 72}"
display as result "msm output adversarial QA"
display as text "{hline 72}"

* --- OUTADV1: msm_protocol restores data after failed Excel export ---
local ++test_count
capture noisily {
    _outadv_setup_pipeline
    set varabbrev on

    capture msm_protocol, ///
        population("Adults") ///
        treatment("Always vs never") ///
        confounders("Biomarker, comorbidity, age, sex") ///
        outcome("Clinical endpoint") ///
        causal_contrast("Risk difference") ///
        weight_spec("Stabilized IPTW") ///
        analysis("Pooled logistic MSM") ///
        export("/tmp/msm_missing_dir/protocol.xlsx") format(excel) replace
    local protocol_rc = _rc

    assert `protocol_rc' != 0
    assert c(varabbrev) == "on"
    _outadv_assert_pipeline_intact
    set varabbrev off
}
if _rc == 0 {
    display as result "PASS OUTADV1: msm_protocol failed export restores dataset"
    local ++pass_count
}
else {
    display as error "FAIL OUTADV1: msm_protocol failed export restoration (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' OUTADV1"
    set varabbrev off
}

* --- OUTADV2: msm_report restores data after failed Excel export ---
local ++test_count
capture noisily {
    _outadv_setup_pipeline
    set varabbrev on
    local k_before = c(k)

    capture msm_report, export("/tmp/msm_missing_dir/report.xlsx") ///
        format(excel) eform replace
    local report_rc = _rc

    assert `report_rc' != 0
    assert c(varabbrev) == "on"
    assert c(k) == `k_before'
    _outadv_assert_pipeline_intact
    set varabbrev off
}
if _rc == 0 {
    display as result "PASS OUTADV2: msm_report failed export restores dataset"
    local ++pass_count
}
else {
    display as error "FAIL OUTADV2: msm_report failed export restoration (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' OUTADV2"
    set varabbrev off
}

* --- OUTADV3: msm_plot restores data after failed graph save ---
local ++test_count
capture noisily {
    _outadv_setup_pipeline
    set varabbrev on

    capture msm_plot, type(balance) covariates(biomarker comorbidity age sex) ///
        saving("/tmp/msm_missing_dir/balance.gph") replace
    local plot_rc = _rc

    assert `plot_rc' != 0
    assert c(varabbrev) == "on"
    _outadv_assert_pipeline_intact
    set varabbrev off
}
if _rc == 0 {
    display as result "PASS OUTADV3: msm_plot failed save restores dataset"
    local ++pass_count
}
else {
    display as error "FAIL OUTADV3: msm_plot failed save restoration (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' OUTADV3"
    set varabbrev off
}

* --- OUTADV4: msm_table restores data after failed Excel export ---
local ++test_count
capture noisily {
    _outadv_setup_pipeline
    set varabbrev on

    capture msm_table, xlsx("/tmp/msm_missing_dir/table.xlsx") all replace
    local table_rc = _rc

    assert `table_rc' != 0
    assert c(varabbrev) == "on"
    _outadv_assert_pipeline_intact
    assert "`: char _dta[_msm_pred_saved]'" == "1"
    assert "`: char _dta[_msm_bal_saved]'" == "1"
    assert "`: char _dta[_msm_diag_saved]'" == "1"
    assert "`: char _dta[_msm_sens_saved]'" == "1"
    set varabbrev off
}
if _rc == 0 {
    display as result "PASS OUTADV4: msm_table failed export restores dataset"
    local ++pass_count
}
else {
    display as error "FAIL OUTADV4: msm_table failed export restoration (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' OUTADV4"
    set varabbrev off
}

* --- OUTADV5: msm_report propagates numeric-cell writer failures ---
* Regression: the Summary and Coefficients numeric-conversion blocks used to
* close their xl() objects but swallow the original helper rc. A later styling
* block could then succeed and make a partially written workbook look valid.
capture program drop _msm_xlsx_put_number
program define _msm_xlsx_put_number, nclass
    version 16.0
    exit 459
end

local ++test_count
capture noisily {
    _outadv_setup_pipeline
    set varabbrev on
    local k_before = c(k)
    tempfile poisoned_report
    local poisoned_xlsx "`poisoned_report'.xlsx"

    capture noisily msm_report, export("`poisoned_xlsx'") ///
        format(excel) eform replace
    local report_rc = _rc

    assert `report_rc' == 459
    assert c(varabbrev) == "on"
    assert c(k) == `k_before'
    _outadv_assert_pipeline_intact
    set varabbrev off
    capture erase "`poisoned_xlsx'"
}
local outadv5_rc = _rc
capture program drop _msm_xlsx_put_number
if `outadv5_rc' == 0 {
    display as result "PASS OUTADV5: msm_report propagates numeric writer rc"
    local ++pass_count
}
else {
    display as error "FAIL OUTADV5: msm_report swallowed numeric writer rc (rc=`outadv5_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' OUTADV5"
    set varabbrev off
}

display as text ""
display as text "{hline 72}"
display as text "Tests run: " as result `test_count'
display as text "Passed:    " as result `pass_count'
display as text "Failed:    " as result `fail_count'
display as text "RESULT: test_msm_output_adversarial tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    display as text "{hline 72}"
    exit 459
}
display as result "All msm output adversarial tests passed"
display as text "{hline 72}"
