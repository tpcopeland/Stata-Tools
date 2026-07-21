* test_msm_expanded.do — Expanded functional tests for msm package
* Covers under-tested areas: protocol, report, table, predict options,
* sensitivity, diagnose, plot, fit options, weight options, validate options,
* main command options, and edge cases.
*
* Location: msm/qa/

version 16.0
clear all
set more off
set varabbrev off


* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

local tmp_dir "`qa_dir'/tmp_expanded"
capture mkdir "`tmp_dir'"

* Reusable pipeline setup
capture program drop _setup_pipeline
program define _setup_pipeline
    version 16.0
    syntax [, NOCENSOR NOLOG FIT PREDICT DIAGNOSE SENSITIVITY]

    local qa_dir "`c(pwd)'"
    local pkg_dir "`qa_dir'/.."
    use "`pkg_dir'/msm_example.dta", clear
    if "`nocensor'" != "" {
        msm_prepare, id(id) period(period) treatment(treatment) ///
            outcome(outcome) covariates(biomarker comorbidity) ///
            baseline_covariates(age sex)
    }
    else {
        msm_prepare, id(id) period(period) treatment(treatment) ///
            outcome(outcome) censor(censored) ///
            covariates(biomarker comorbidity) ///
            baseline_covariates(age sex)
    }

    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) truncate(1 99) nolog

    if "`fit'" != "" | "`predict'" != "" | "`sensitivity'" != "" {
        msm_fit, model(logistic) outcome_cov(age sex) nolog
    }
    if "`diagnose'" != "" {
        msm_diagnose, balance_covariates(biomarker comorbidity age sex)
    }
    if "`predict'" != "" {
        quietly summarize period
        local maxp = r(max)
        msm_predict, times(1 3 5) samples(20) seed(12345)
    }
    if "`sensitivity'" != "" {
        msm_sensitivity, evalue
    }
end

timer clear
timer on 99

* =============================================================================
* SECTION A: msm (main command) options
* =============================================================================

* --- A1: default display ---
local ++test_count
capture noisily {
    msm
    assert "`r(version)'" != ""
    assert r(n_commands) == 12
}
if _rc == 0 {
    display as result "  PASS A1: msm default display"
    local ++pass_count
}
else {
    display as error "  FAIL A1: msm default display (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A1"
}

* --- A2: list option ---
local ++test_count
capture noisily {
    msm, list
    assert "`r(commands)'" != ""
    local ncmds : word count `r(commands)'
    assert `ncmds' == 12
}
if _rc == 0 {
    display as result "  PASS A2: msm list option"
    local ++pass_count
}
else {
    display as error "  FAIL A2: msm list option (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A2"
}

* --- A3: detail option ---
local ++test_count
capture noisily {
    msm, detail
    assert "`r(version)'" != ""
}
if _rc == 0 {
    display as result "  PASS A3: msm detail option"
    local ++pass_count
}
else {
    display as error "  FAIL A3: msm detail option (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A3"
}

* --- A4: protocol option ---
local ++test_count
capture noisily {
    msm, protocol
    assert "`r(version)'" != ""
}
if _rc == 0 {
    display as result "  PASS A4: msm protocol option"
    local ++pass_count
}
else {
    display as error "  FAIL A4: msm protocol option (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A4"
}

* =============================================================================
* SECTION B: msm_validate options
* =============================================================================

* --- B1: strict option (clean data should pass) ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_validate, strict
    assert r(n_checks) == 10
    assert r(n_errors) == 0
    assert "`r(validation)'" == "passed"
}
if _rc == 0 {
    display as result "  PASS B1: msm_validate strict passes on clean data"
    local ++pass_count
}
else {
    display as error "  FAIL B1: msm_validate strict (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B1"
}

* --- B2: verbose option ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_validate, verbose
    assert r(n_checks) == 10
}
if _rc == 0 {
    display as result "  PASS B2: msm_validate verbose"
    local ++pass_count
}
else {
    display as error "  FAIL B2: msm_validate verbose (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B2"
}

* --- B3: strict + verbose ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_validate, strict verbose
    assert r(n_checks) == 10
    assert r(n_errors) == 0
}
if _rc == 0 {
    display as result "  PASS B3: msm_validate strict verbose"
    local ++pass_count
}
else {
    display as error "  FAIL B3: msm_validate strict verbose (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B3"
}

* --- B4: stored results completeness ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_validate
    assert r(n_checks) > 0
    assert r(n_errors) >= 0
    assert r(n_warnings) >= 0
    assert inlist("`r(validation)'", "passed", "failed")
}
if _rc == 0 {
    display as result "  PASS B4: msm_validate stored results complete"
    local ++pass_count
}
else {
    display as error "  FAIL B4: msm_validate stored results (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B4"
}

* =============================================================================
* SECTION C: msm_weight options
* =============================================================================

* --- C1: replace option ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) nolog
    * Run again with replace
    msm_weight, treat_d_cov(biomarker comorbidity age sex) nolog replace
    assert r(mean_weight) != .
}
if _rc == 0 {
    display as result "  PASS C1: msm_weight replace option"
    local ++pass_count
}
else {
    display as error "  FAIL C1: msm_weight replace (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C1"
}

* --- C2: error without replace when weights exist ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) nolog
    * Should fail without replace
    capture msm_weight, treat_d_cov(biomarker comorbidity age sex) nolog
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS C2: msm_weight errors without replace"
    local ++pass_count
}
else {
    display as error "  FAIL C2: msm_weight no-replace error (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C2"
}

* --- C3: nolog option ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) nolog
    confirm variable _msm_weight
}
if _rc == 0 {
    display as result "  PASS C3: msm_weight nolog"
    local ++pass_count
}
else {
    display as error "  FAIL C3: msm_weight nolog (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C3"
}

* --- C4: treat_n_cov option ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) nolog
    assert r(mean_weight) != .
}
if _rc == 0 {
    display as result "  PASS C4: msm_weight treat_n_cov"
    local ++pass_count
}
else {
    display as error "  FAIL C4: msm_weight treat_n_cov (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C4"
}

* --- C5: censor weights (IPCW) ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        censor_d_cov(biomarker age sex) nolog
    confirm variable _msm_cw_weight
    confirm variable _msm_weight
    assert r(mean_weight) != .
}
if _rc == 0 {
    display as result "  PASS C5: msm_weight with IPCW"
    local ++pass_count
}
else {
    display as error "  FAIL C5: msm_weight IPCW (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C5"
}

* --- C6: censor_n_cov + censor_d_cov ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        censor_d_cov(biomarker age sex) censor_n_cov(age sex) nolog
    confirm variable _msm_cw_weight
}
if _rc == 0 {
    display as result "  PASS C6: msm_weight censor_n_cov + censor_d_cov"
    local ++pass_count
}
else {
    display as error "  FAIL C6: msm_weight censor_n_cov (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C6"
}

* --- C7: error when censor_d_cov without censor variable ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    capture msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        censor_d_cov(biomarker age) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS C7: error censor_d_cov without censor var"
    local ++pass_count
}
else {
    display as error "  FAIL C7: censor_d_cov error (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C7"
}

* --- C8: error when censor_n_cov without censor_d_cov ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    capture msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        censor_n_cov(age) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS C8: error censor_n_cov without censor_d_cov"
    local ++pass_count
}
else {
    display as error "  FAIL C8: censor_n_cov error (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C8"
}

* --- C9: truncate option ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        truncate(5 95) nolog
    assert r(n_truncated) >= 0
    assert r(mean_weight) != .
}
if _rc == 0 {
    display as result "  PASS C9: msm_weight truncate(5 95)"
    local ++pass_count
}
else {
    display as error "  FAIL C9: msm_weight truncate (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C9"
}

* --- C10: stored results completeness ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) nolog
    assert r(mean_weight) != .
    assert r(sd_weight) != .
    assert r(min_weight) != .
    assert r(max_weight) != .
    assert r(p1_weight) != .
    assert r(median_weight) != .
    assert r(p99_weight) != .
    assert r(ess) != .
    assert r(n_truncated) >= 0
    assert "`r(weight_var)'" == "_msm_weight"
}
if _rc == 0 {
    display as result "  PASS C10: msm_weight stored results complete"
    local ++pass_count
}
else {
    display as error "  FAIL C10: msm_weight stored results (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C10"
}

* =============================================================================
* SECTION D: msm_fit options
* =============================================================================

* --- D1: model(logistic) default ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) nolog
    assert "`e(msm_model)'" == "logistic"
    assert "`e(msm_period_spec)'" == "quadratic"
}
if _rc == 0 {
    display as result "  PASS D1: msm_fit logistic default"
    local ++pass_count
}
else {
    display as error "  FAIL D1: msm_fit logistic default (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D1"
}

* --- D2: model(linear) ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(linear) nolog
    assert "`e(msm_model)'" == "linear"
}
if _rc == 0 {
    display as result "  PASS D2: msm_fit linear"
    local ++pass_count
}
else {
    display as error "  FAIL D2: msm_fit linear (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D2"
}

* --- D3: model(cox) ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(cox) nolog
    assert "`e(msm_model)'" == "cox"
}
if _rc == 0 {
    display as result "  PASS D3: msm_fit cox"
    local ++pass_count
}
else {
    display as error "  FAIL D3: msm_fit cox (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D3"
}

* --- D4: period_spec(linear) ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) period_spec(linear) nolog
    assert "`e(msm_period_spec)'" == "linear"
}
if _rc == 0 {
    display as result "  PASS D4: period_spec(linear)"
    local ++pass_count
}
else {
    display as error "  FAIL D4: period_spec linear (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D4"
}

* --- D5: period_spec(cubic) ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) period_spec(cubic) nolog
    assert "`e(msm_period_spec)'" == "cubic"
    confirm variable _msm_period_cu
}
if _rc == 0 {
    display as result "  PASS D5: period_spec(cubic)"
    local ++pass_count
}
else {
    display as error "  FAIL D5: period_spec cubic (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D5"
}

* --- D6: period_spec(none) ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) period_spec(none) nolog
    assert "`e(msm_period_spec)'" == "none"
}
if _rc == 0 {
    display as result "  PASS D6: period_spec(none)"
    local ++pass_count
}
else {
    display as error "  FAIL D6: period_spec none (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D6"
}

* --- D7: period_spec(ns(2)) ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) period_spec(ns(2)) nolog
    assert "`e(msm_period_spec)'" == "ns(2)"
    confirm variable _msm_per_ns1
    confirm variable _msm_per_ns2
}
if _rc == 0 {
    display as result "  PASS D7: period_spec(ns(2))"
    local ++pass_count
}
else {
    display as error "  FAIL D7: period_spec ns(2) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D7"
}

* --- D8: period_spec(ns(3)) ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) period_spec(ns(3)) nolog
    confirm variable _msm_per_ns1
    confirm variable _msm_per_ns2
    confirm variable _msm_per_ns3
}
if _rc == 0 {
    display as result "  PASS D8: period_spec(ns(3))"
    local ++pass_count
}
else {
    display as error "  FAIL D8: period_spec ns(3) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D8"
}

* --- D9: outcome_cov option ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) nolog
    assert _b[age] != .
    assert _b[sex] != .
}
if _rc == 0 {
    display as result "  PASS D9: msm_fit outcome_cov"
    local ++pass_count
}
else {
    display as error "  FAIL D9: msm_fit outcome_cov (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D9"
}

* --- D10: level option ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) level(90) nolog
    * Should run without error
    assert e(N) > 0
}
if _rc == 0 {
    display as result "  PASS D10: msm_fit level(90)"
    local ++pass_count
}
else {
    display as error "  FAIL D10: msm_fit level (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D10"
}

* --- D11: bootstrap error message ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    capture msm_fit, outcome_cov(age sex) bootstrap(100) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS D11: msm_fit bootstrap error"
    local ++pass_count
}
else {
    display as error "  FAIL D11: msm_fit bootstrap error (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D11"
}

* --- D12: invalid model type ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    capture msm_fit, outcome_cov(age sex) model(invalid) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS D12: msm_fit invalid model error"
    local ++pass_count
}
else {
    display as error "  FAIL D12: msm_fit invalid model (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D12"
}

* --- D13: e() results stored ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) nolog
    assert "`e(msm_cmd)'" == "msm_fit"
    assert "`e(msm_model)'" == "logistic"
    assert "`e(msm_treatment)'" == "treatment"
    assert "`e(msm_period_spec)'" == "quadratic"
    assert e(N) > 0
    * Verify saved matrices exist
    matrix list _msm_fit_b
    matrix list _msm_fit_V
}
if _rc == 0 {
    display as result "  PASS D13: msm_fit e() results stored"
    local ++pass_count
}
else {
    display as error "  FAIL D13: msm_fit e() results (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D13"
}

* --- D14: vce(robust) contract and robust SE metadata (audit A21) ---
* Person-period outcomes within an id are correlated, so vce(robust) is refused
* when any id contributes more than one fitted row, and is valid only on a
* one-record-per-id sample. Verify the refusal AND the robust metadata plumbing.
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    * repeated person-periods per id -> vce(robust) is refused (rc 198)
    capture msm_fit, model(linear) outcome_cov(age sex) period_spec(linear) ///
        vce(robust) nolog
    assert _rc == 198

    * one-record-per-id sample -> vce(robust) is valid and records its metadata
    keep if period == 0
    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        covariates(biomarker) baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker age sex) nolog
    msm_fit, model(linear) outcome_cov(age sex) period_spec(none) ///
        vce(robust) nolog
    assert "`e(msm_vce)'" == "robust"
    assert "`e(msm_cluster)'" == ""
    local stored_vce : char _dta[_msm_vce]
    assert "`stored_vce'" == "robust"
    assert e(msm_n_clusters) == e(N)
}
if _rc == 0 {
    display as result "  PASS D14: msm_fit vce(robust)"
    local ++pass_count
}
else {
    display as error "  FAIL D14: msm_fit vce(robust) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D14"
}

* --- D15: vce(cluster varname) sets cluster metadata ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, model(linear) outcome_cov(age sex) period_spec(linear) ///
        vce(cluster id) nolog
    assert "`e(msm_vce)'" == "cluster"
    assert "`e(msm_cluster)'" == "id"
    local stored_cluster : char _dta[_msm_cluster]
    assert "`stored_cluster'" == "id"
}
if _rc == 0 {
    display as result "  PASS D15: msm_fit vce(cluster)"
    local ++pass_count
}
else {
    display as error "  FAIL D15: msm_fit vce(cluster) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D15"
}

* --- D16: legacy cluster() remains supported ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, model(linear) outcome_cov(age sex) period_spec(linear) ///
        cluster(id) nolog
    assert "`e(msm_vce)'" == "cluster"
    assert "`e(msm_cluster)'" == "id"
}
if _rc == 0 {
    display as result "  PASS D16: msm_fit legacy cluster()"
    local ++pass_count
}
else {
    display as error "  FAIL D16: msm_fit legacy cluster() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D16"
}

* --- D17: cluster() and vce() cannot be combined ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    capture msm_fit, outcome_cov(age sex) model(linear) vce(robust) cluster(id) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS D17: msm_fit rejects cluster()/vce() conflict"
    local ++pass_count
}
else {
    display as error "  FAIL D17: msm_fit cluster()/vce() conflict (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D17"
}

* --- D18: strata() is Cox-only ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    capture msm_fit, outcome_cov(age sex) model(linear) strata(sex) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS D18: msm_fit rejects non-Cox strata()"
    local ++pass_count
}
else {
    display as error "  FAIL D18: msm_fit non-Cox strata() guard (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D18"
}

* --- D19: Cox strata() stores baseline hazard metadata ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, model(cox) outcome_cov(age sex) strata(sex) vce(cluster id) nolog
    assert "`e(msm_vce)'" == "cluster"
    assert "`e(msm_cluster)'" == "id"
    assert "`e(msm_strata)'" == "sex"
    local stored_strata : char _dta[_msm_strata]
    assert "`stored_strata'" == "sex"
}
if _rc == 0 {
    display as result "  PASS D19: msm_fit Cox strata() metadata"
    local ++pass_count
}
else {
    display as error "  FAIL D19: msm_fit Cox strata() metadata (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D19"
}

* =============================================================================
* SECTION E: msm_diagnose options
* =============================================================================

* --- E1: by_period option ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_diagnose, by_period
    assert r(mean_weight) != .
}
if _rc == 0 {
    display as result "  PASS E1: msm_diagnose by_period"
    local ++pass_count
}
else {
    display as error "  FAIL E1: msm_diagnose by_period (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' E1"
}

* --- E2: threshold option ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_diagnose, balance_covariates(biomarker comorbidity age sex) threshold(0.2)
    assert r(mean_weight) != .
    matrix list r(balance)
}
if _rc == 0 {
    display as result "  PASS E2: msm_diagnose threshold(0.2)"
    local ++pass_count
}
else {
    display as error "  FAIL E2: msm_diagnose threshold (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' E2"
}

* --- E3: balance_covariates option ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_diagnose, balance_covariates(biomarker age)
    assert r(mean_weight) != .
    * Balance matrix should have 2 rows (2 covariates)
    matrix list r(balance)
    assert rowsof(r(balance)) == 2
}
if _rc == 0 {
    display as result "  PASS E3: msm_diagnose balance_covariates"
    local ++pass_count
}
else {
    display as error "  FAIL E3: msm_diagnose balance_covariates (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' E3"
}

* --- E4: stored results completeness ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_diagnose, balance_covariates(biomarker comorbidity age sex)
    assert r(mean_weight) != .
    assert r(sd_weight) != .
    assert r(min_weight) != .
    assert r(max_weight) != .
    assert r(p1_weight) != .
    assert r(p99_weight) != .
    assert r(ess) != .
    assert r(ess_pct) != .
    assert r(n_extreme) >= 0
    * Balance matrix should have 4 rows, 3 cols
    assert rowsof(r(balance)) == 4
    assert colsof(r(balance)) == 3
}
if _rc == 0 {
    display as result "  PASS E4: msm_diagnose stored results complete"
    local ++pass_count
}
else {
    display as error "  FAIL E4: msm_diagnose stored results (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' E4"
}

* --- E5: default covariates from prepare ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    * No balance_covariates specified - should use mapped covariates
    msm_diagnose
    assert r(mean_weight) != .
}
if _rc == 0 {
    display as result "  PASS E5: msm_diagnose default covariates"
    local ++pass_count
}
else {
    display as error "  FAIL E5: msm_diagnose default covariates (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' E5"
}

* =============================================================================
* SECTION F: msm_predict options
* =============================================================================

* --- F1: strategy(always) ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    msm_predict, times(1 3 5) strategy(always) samples(20) seed(99)
    assert "`r(strategy)'" == "always"
    assert r(n_times) == 3
    matrix list r(predictions)
}
if _rc == 0 {
    display as result "  PASS F1: msm_predict strategy(always)"
    local ++pass_count
}
else {
    display as error "  FAIL F1: msm_predict always (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' F1"
}

* --- F2: strategy(never) ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    msm_predict, times(1 3 5) strategy(never) samples(20) seed(99)
    assert "`r(strategy)'" == "never"
    assert r(n_times) == 3
}
if _rc == 0 {
    display as result "  PASS F2: msm_predict strategy(never)"
    local ++pass_count
}
else {
    display as error "  FAIL F2: msm_predict never (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' F2"
}

* --- F3: type(survival) ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    msm_predict, times(1 3 5) type(survival) samples(20) seed(99)
    assert "`r(type)'" == "survival"
}
if _rc == 0 {
    display as result "  PASS F3: msm_predict type(survival)"
    local ++pass_count
}
else {
    display as error "  FAIL F3: msm_predict survival (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' F3"
}

* --- F4: difference option ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    msm_predict, times(1 3 5) difference samples(20) seed(99)
    assert r(rd_1) != .
    assert r(rd_3) != .
    assert r(rd_5) != .
    * Predictions matrix should have 10 columns with difference
    assert colsof(r(predictions)) == 10
}
if _rc == 0 {
    display as result "  PASS F4: msm_predict difference"
    local ++pass_count
}
else {
    display as error "  FAIL F4: msm_predict difference (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' F4"
}

* --- F5: seed reproducibility ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    msm_predict, times(1 3) samples(20) seed(42)
    tempname r1
    matrix `r1' = r(predictions)

    * Re-run pipeline and predict with same seed
    _setup_pipeline, nolog fit
    msm_predict, times(1 3) samples(20) seed(42)
    tempname r2
    matrix `r2' = r(predictions)

    * Point estimates and Monte Carlo CI columns should match exactly
    assert rowsof(`r1') == rowsof(`r2')
    assert colsof(`r1') == colsof(`r2')
    forvalues i = 1/`=rowsof(`r1')' {
        forvalues j = 1/`=colsof(`r1')' {
            assert abs(`r1'[`i',`j'] - `r2'[`i',`j']) < 1e-12
        }
    }
}
if _rc == 0 {
    display as result "  PASS F5: msm_predict seeded CI reproducibility"
    local ++pass_count
}
else {
    display as error "  FAIL F5: msm_predict seeded CI reproducibility (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' F5"
}

* --- F5b: no seed reports session RNG state and advances RNG ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    set seed 987654
    local seed_before `"`c(seed)'"'
    msm_predict, times(1 3) samples(10)
    local seed_after `"`c(seed)'"'

    assert "`r(seed_source)'" == "session_rng_state"
    assert `"`r(seed)'"' == `"`seed_before'"'
    assert `"`r(seed_state)'"' == `"`seed_before'"'
    assert `"`seed_after'"' != `"`seed_before'"'
}
if _rc == 0 {
    display as result "  PASS F5b: msm_predict no-seed RNG reporting"
    local ++pass_count
}
else {
    display as error "  FAIL F5b: msm_predict no-seed RNG reporting (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' F5b"
}

* --- F6: samples(10) minimum + level() controls reported CI level ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    msm_predict, times(1 3) samples(10) seed(99) level(90)
    assert r(samples) == 10
    assert r(level) == 90
}
if _rc == 0 {
    display as result "  PASS F6: msm_predict samples(10) + level(90)"
    local ++pass_count
}
else {
    display as error "  FAIL F6: msm_predict samples(10)/level(90) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' F6"
}

* --- F7: samples too small error ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    capture msm_predict, times(1 3) samples(5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS F7: msm_predict samples too small error"
    local ++pass_count
}
else {
    display as error "  FAIL F7: msm_predict samples error (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' F7"
}

* --- F8: stored results completeness ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    msm_predict, times(1 3 5) samples(20) seed(99)
    assert r(n_times) == 3
    assert r(n_ref) > 0
    assert r(samples) == 20
    assert r(level) == 95
    assert "`r(type)'" == "cum_inc"
    assert "`r(strategy)'" == "both"
    matrix list r(predictions)
    assert colsof(r(predictions)) == 7
    assert rowsof(r(predictions)) == 3
}
if _rc == 0 {
    display as result "  PASS F8: msm_predict stored results complete"
    local ++pass_count
}
else {
    display as error "  FAIL F8: msm_predict stored results (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' F8"
}

* --- F9: cox model error ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(cox) nolog
    capture msm_predict, times(1 3) samples(10)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS F9: msm_predict rejects cox model"
    local ++pass_count
}
else {
    display as error "  FAIL F9: msm_predict cox rejection (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' F9"
}

* =============================================================================
* SECTION G: msm_sensitivity options
* =============================================================================

* --- G1: evalue default ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    msm_sensitivity
    assert r(evalue_point) != .
    assert r(evalue_ci) != .
    assert r(effect) != .
    assert "`r(effect_label)'" == "OR"
}
if _rc == 0 {
    display as result "  PASS G1: msm_sensitivity evalue default"
    local ++pass_count
}
else {
    display as error "  FAIL G1: msm_sensitivity evalue (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' G1"
}

* --- G2: confounding_strength option ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    msm_sensitivity, confounding_strength(2 3)
    assert r(bias_factor) != .
    assert r(corrected_effect) != .
    assert r(rr_ud) == 2
    assert r(rr_uy) == 3
}
if _rc == 0 {
    display as result "  PASS G2: msm_sensitivity confounding_strength"
    local ++pass_count
}
else {
    display as error "  FAIL G2: msm_sensitivity confounding_strength (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' G2"
}

* --- G3: evalue + confounding_strength together ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    msm_sensitivity, evalue confounding_strength(2 3)
    assert r(evalue_point) != .
    assert r(bias_factor) != .
}
if _rc == 0 {
    display as result "  PASS G3: msm_sensitivity evalue + confounding_strength"
    local ++pass_count
}
else {
    display as error "  FAIL G3: msm_sensitivity combined (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' G3"
}

* --- G4: level option ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    msm_sensitivity, evalue level(90)
    assert r(effect_lo) != .
    assert r(effect_hi) != .
}
if _rc == 0 {
    display as result "  PASS G4: msm_sensitivity level(90)"
    local ++pass_count
}
else {
    display as error "  FAIL G4: msm_sensitivity level (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' G4"
}

* --- G5: with cox model ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(cox) nolog
    msm_sensitivity, evalue
    assert r(evalue_point) != .
    assert "`r(effect_label)'" == "HR"
}
if _rc == 0 {
    display as result "  PASS G5: msm_sensitivity with cox"
    local ++pass_count
}
else {
    display as error "  FAIL G5: msm_sensitivity cox (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' G5"
}

* --- G6: with linear model (E-value not available) ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_fit, outcome_cov(age sex) model(linear) nolog
    msm_sensitivity, evalue
    assert "`r(effect_label)'" == "Coef"
    assert r(effect) != .
}
if _rc == 0 {
    display as result "  PASS G6: msm_sensitivity with linear"
    local ++pass_count
}
else {
    display as error "  FAIL G6: msm_sensitivity linear (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' G6"
}

* --- G7: stored results completeness ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    msm_sensitivity, evalue confounding_strength(2 3)
    assert r(effect) != .
    assert r(effect_lo) != .
    assert r(effect_hi) != .
    assert r(evalue_point) != .
    assert r(evalue_ci) != .
    assert r(bias_factor) != .
    assert r(corrected_effect) != .
    assert r(rr_ud) == 2
    assert r(rr_uy) == 3
    assert "`r(effect_label)'" == "OR"
    assert "`r(model)'" == "logistic"
}
if _rc == 0 {
    display as result "  PASS G7: msm_sensitivity stored results complete"
    local ++pass_count
}
else {
    display as error "  FAIL G7: msm_sensitivity stored results (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' G7"
}

* =============================================================================
* SECTION H: msm_plot options
* =============================================================================

* --- H1: weights plot ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_plot, type(weights) saving("`tmp_dir'/plot_weights.gph") replace
    assert "`r(plot_type)'" == "weights"
    confirm file "`tmp_dir'/plot_weights.gph"
}
if _rc == 0 {
    display as result "  PASS H1: msm_plot weights"
    local ++pass_count
}
else {
    display as error "  FAIL H1: msm_plot weights (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H1"
}

* --- H2: balance plot (with custom SMD threshold reference line) ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_plot, type(balance) covariates(biomarker comorbidity age sex) ///
        threshold(0.15) saving("`tmp_dir'/plot_balance.gph") replace
    assert "`r(plot_type)'" == "balance"
}
if _rc == 0 {
    display as result "  PASS H2: msm_plot balance"
    local ++pass_count
}
else {
    display as error "  FAIL H2: msm_plot balance (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H2"
}

* --- H3: trajectory plot ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_plot, type(trajectory) n_sample(20) seed(42) ///
        saving("`tmp_dir'/plot_traj.gph") replace
    assert "`r(plot_type)'" == "trajectory"
}
if _rc == 0 {
    display as result "  PASS H3: msm_plot trajectory"
    local ++pass_count
}
else {
    display as error "  FAIL H3: msm_plot trajectory (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H3"
}

* --- H4: positivity plot ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_plot, type(positivity) saving("`tmp_dir'/plot_pos.gph") replace
    assert "`r(plot_type)'" == "positivity"
}
if _rc == 0 {
    display as result "  PASS H4: msm_plot positivity"
    local ++pass_count
}
else {
    display as error "  FAIL H4: msm_plot positivity (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H4"
}

* --- H5: survival plot ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    msm_plot, type(survival) times(1 3 5) samples(20) seed(99) ///
        saving("`tmp_dir'/plot_surv.gph") replace
    assert "`r(plot_type)'" == "survival"
}
if _rc == 0 {
    display as result "  PASS H5: msm_plot survival"
    local ++pass_count
}
else {
    display as error "  FAIL H5: msm_plot survival (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H5"
}

* --- H6: title option ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    msm_plot, type(weights) title("Custom Title") ///
        saving("`tmp_dir'/plot_title.gph") replace
    assert "`r(plot_type)'" == "weights"
}
if _rc == 0 {
    display as result "  PASS H6: msm_plot custom title"
    local ++pass_count
}
else {
    display as error "  FAIL H6: msm_plot title (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H6"
}

* --- H7: invalid type error ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    capture msm_plot, type(invalid)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS H7: msm_plot invalid type error"
    local ++pass_count
}
else {
    display as error "  FAIL H7: msm_plot invalid type (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H7"
}

* --- H8: survival without fit error ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog
    * Don't run msm_fit
    capture msm_plot, type(survival) times(1 3)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS H8: msm_plot survival without fit error"
    local ++pass_count
}
else {
    display as error "  FAIL H8: msm_plot survival no-fit (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H8"
}

* =============================================================================
* SECTION I: msm_protocol options
* =============================================================================

* --- I1: display format (default) ---
local ++test_count
capture noisily {
    msm_protocol, population("Adults 18+") treatment("Drug vs placebo") ///
        confounders("Age, sex, biomarker") outcome("All-cause mortality") ///
        causal_contrast("Always vs never treated") ///
        weight_spec("Stabilized IPTW, 1/99 truncation") ///
        analysis("Pooled logistic regression with robust SE")
    assert "`r(population)'" == "Adults 18+"
    assert "`r(treatment)'" == "Drug vs placebo"
    assert "`r(confounders)'" == "Age, sex, biomarker"
    assert "`r(outcome)'" == "All-cause mortality"
    assert "`r(format)'" == "display"
}
if _rc == 0 {
    display as result "  PASS I1: msm_protocol display format"
    local ++pass_count
}
else {
    display as error "  FAIL I1: msm_protocol display (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I1"
}

* --- I2: csv format ---
local ++test_count
capture noisily {
    msm_protocol, population("Adults 18+") treatment("Drug vs placebo") ///
        confounders("Age, sex") outcome("Mortality") ///
        causal_contrast("Always vs never") ///
        weight_spec("Stabilized IPTW") ///
        analysis("Pooled logistic") ///
        format(csv) export("`tmp_dir'/protocol.csv") replace
    assert "`r(format)'" == "csv"
    confirm file "`tmp_dir'/protocol.csv"
}
if _rc == 0 {
    display as result "  PASS I2: msm_protocol csv format"
    local ++pass_count
}
else {
    display as error "  FAIL I2: msm_protocol csv (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I2"
}

* --- I3: excel format ---
local ++test_count
capture noisily {
    msm_protocol, population("Adults 18+") treatment("Drug vs placebo") ///
        confounders("Age, sex") outcome("Mortality") ///
        causal_contrast("Always vs never") ///
        weight_spec("Stabilized IPTW") ///
        analysis("Pooled logistic") ///
        format(excel) export("`tmp_dir'/protocol.xlsx") replace
    assert "`r(format)'" == "excel"
    confirm file "`tmp_dir'/protocol.xlsx"
}
if _rc == 0 {
    display as result "  PASS I3: msm_protocol excel format"
    local ++pass_count
}
else {
    display as error "  FAIL I3: msm_protocol excel (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I3"
}

* --- I4: latex format ---
local ++test_count
capture noisily {
    msm_protocol, population("Adults 18+") treatment("Drug vs placebo") ///
        confounders("Age, sex") outcome("Mortality") ///
        causal_contrast("Always vs never") ///
        weight_spec("Stabilized IPTW") ///
        analysis("Pooled logistic") ///
        format(latex) export("`tmp_dir'/protocol.tex") replace
    assert "`r(format)'" == "latex"
    confirm file "`tmp_dir'/protocol.tex"
}
if _rc == 0 {
    display as result "  PASS I4: msm_protocol latex format"
    local ++pass_count
}
else {
    display as error "  FAIL I4: msm_protocol latex (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I4"
}

* --- I5: stored results completeness ---
local ++test_count
capture noisily {
    msm_protocol, population("Pop") treatment("Treat") ///
        confounders("Conf") outcome("Out") ///
        causal_contrast("Contrast") ///
        weight_spec("Weights") ///
        analysis("Analysis")
    assert "`r(population)'" == "Pop"
    assert "`r(treatment)'" == "Treat"
    assert "`r(confounders)'" == "Conf"
    assert "`r(outcome)'" == "Out"
    assert "`r(causal_contrast)'" == "Contrast"
    assert "`r(weight_spec)'" == "Weights"
    assert "`r(analysis)'" == "Analysis"
    assert "`r(format)'" == "display"
}
if _rc == 0 {
    display as result "  PASS I5: msm_protocol stored results complete"
    local ++pass_count
}
else {
    display as error "  FAIL I5: msm_protocol stored results (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I5"
}

* --- I6: csv without export error ---
local ++test_count
capture noisily {
    capture msm_protocol, population("Pop") treatment("T") ///
        confounders("C") outcome("O") ///
        causal_contrast("CC") weight_spec("W") ///
        analysis("A") format(csv)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS I6: msm_protocol csv without export error"
    local ++pass_count
}
else {
    display as error "  FAIL I6: msm_protocol csv no-export (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I6"
}

* --- I7: invalid format error ---
local ++test_count
capture noisily {
    capture msm_protocol, population("Pop") treatment("T") ///
        confounders("C") outcome("O") ///
        causal_contrast("CC") weight_spec("W") ///
        analysis("A") format(invalid)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS I7: msm_protocol invalid format error"
    local ++pass_count
}
else {
    display as error "  FAIL I7: msm_protocol invalid format (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I7"
}

* =============================================================================
* SECTION J: msm_report options
* =============================================================================

* --- J1: display format (default) ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    msm_report
    assert "`r(format)'" == "display"
}
if _rc == 0 {
    display as result "  PASS J1: msm_report display"
    local ++pass_count
}
else {
    display as error "  FAIL J1: msm_report display (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' J1"
}

* --- J2: eform option ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    msm_report, eform
    assert "`r(format)'" == "display"
}
if _rc == 0 {
    display as result "  PASS J2: msm_report eform"
    local ++pass_count
}
else {
    display as error "  FAIL J2: msm_report eform (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' J2"
}

* --- J3: decimals option ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    msm_report, decimals(2)
    assert "`r(format)'" == "display"
}
if _rc == 0 {
    display as result "  PASS J3: msm_report decimals(2)"
    local ++pass_count
}
else {
    display as error "  FAIL J3: msm_report decimals (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' J3"
}

* --- J4: csv format ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    msm_report, format(csv) export("`tmp_dir'/report.csv") replace
    assert "`r(format)'" == "csv"
    assert "`r(export)'" == "`tmp_dir'/report.csv"
    confirm file "`tmp_dir'/report.csv"
}
if _rc == 0 {
    display as result "  PASS J4: msm_report csv"
    local ++pass_count
}
else {
    display as error "  FAIL J4: msm_report csv (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' J4"
}

* --- J5: excel format ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    msm_report, format(excel) export("`tmp_dir'/report.xlsx") replace
    assert "`r(format)'" == "excel"
    confirm file "`tmp_dir'/report.xlsx"
}
if _rc == 0 {
    display as result "  PASS J5: msm_report excel"
    local ++pass_count
}
else {
    display as error "  FAIL J5: msm_report excel (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' J5"
}

* --- J6: csv without export error ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    capture msm_report, format(csv)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS J6: msm_report csv without export error"
    local ++pass_count
}
else {
    display as error "  FAIL J6: msm_report csv no-export (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' J6"
}

* --- J7: report before weight (prepare only) ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_report
    assert "`r(format)'" == "display"
}
if _rc == 0 {
    display as result "  PASS J7: msm_report before weight"
    local ++pass_count
}
else {
    display as error "  FAIL J7: msm_report before weight (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' J7"
}

* --- J8: csv with eform ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    msm_report, format(csv) export("`tmp_dir'/report_eform.csv") replace eform
    confirm file "`tmp_dir'/report_eform.csv"
}
if _rc == 0 {
    display as result "  PASS J8: msm_report csv + eform"
    local ++pass_count
}
else {
    display as error "  FAIL J8: msm_report csv+eform (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' J8"
}

* =============================================================================
* SECTION K: msm_table options
* =============================================================================

* --- K1: all tables (default after full pipeline) ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit diagnose predict sensitivity
    capture erase "`tmp_dir'/table_all.xlsx"
    msm_table, xlsx("`tmp_dir'/table_all.xlsx")
    confirm file "`tmp_dir'/table_all.xlsx"
}
if _rc == 0 {
    display as result "  PASS K1: msm_table all tables"
    local ++pass_count
}
else {
    display as error "  FAIL K1: msm_table all (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K1"
}

* --- K2: coefficients only ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    capture erase "`tmp_dir'/table_coef.xlsx"
    msm_table, xlsx("`tmp_dir'/table_coef.xlsx") coefficients
    confirm file "`tmp_dir'/table_coef.xlsx"
}
if _rc == 0 {
    display as result "  PASS K2: msm_table coefficients"
    local ++pass_count
}
else {
    display as error "  FAIL K2: msm_table coef (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K2"
}

* --- K3: eform option ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    capture erase "`tmp_dir'/table_eform.xlsx"
    msm_table, xlsx("`tmp_dir'/table_eform.xlsx") coefficients eform
    confirm file "`tmp_dir'/table_eform.xlsx"
}
if _rc == 0 {
    display as result "  PASS K3: msm_table eform"
    local ++pass_count
}
else {
    display as error "  FAIL K3: msm_table eform (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K3"
}

* --- K4: decimals option ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    capture erase "`tmp_dir'/table_dec.xlsx"
    msm_table, xlsx("`tmp_dir'/table_dec.xlsx") coefficients decimals(2)
    confirm file "`tmp_dir'/table_dec.xlsx"
}
if _rc == 0 {
    display as result "  PASS K4: msm_table decimals(2)"
    local ++pass_count
}
else {
    display as error "  FAIL K4: msm_table decimals (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K4"
}

* --- K5: title option ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    capture erase "`tmp_dir'/table_title.xlsx"
    msm_table, xlsx("`tmp_dir'/table_title.xlsx") coefficients ///
        title("My Custom Title")
    confirm file "`tmp_dir'/table_title.xlsx"
}
if _rc == 0 {
    display as result "  PASS K5: msm_table title"
    local ++pass_count
}
else {
    display as error "  FAIL K5: msm_table title (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K5"
}

* --- K6: sep option ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    capture erase "`tmp_dir'/table_sep.xlsx"
    msm_table, xlsx("`tmp_dir'/table_sep.xlsx") coefficients sep(" to ")
    confirm file "`tmp_dir'/table_sep.xlsx"
}
if _rc == 0 {
    display as result "  PASS K6: msm_table sep option"
    local ++pass_count
}
else {
    display as error "  FAIL K6: msm_table sep (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K6"
}

* --- K7: replace option ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    capture erase "`tmp_dir'/table_replace.xlsx"
    msm_table, xlsx("`tmp_dir'/table_replace.xlsx") coefficients
    * Run again with replace
    msm_table, xlsx("`tmp_dir'/table_replace.xlsx") coefficients replace
    confirm file "`tmp_dir'/table_replace.xlsx"
}
if _rc == 0 {
    display as result "  PASS K7: msm_table replace"
    local ++pass_count
}
else {
    display as error "  FAIL K7: msm_table replace (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K7"
}

* --- K8: xlsx extension validation ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    capture msm_table, xlsx("`tmp_dir'/table.csv") coefficients
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS K8: msm_table xlsx extension error"
    local ++pass_count
}
else {
    display as error "  FAIL K8: msm_table xlsx extension (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K8"
}

* --- K9: predictions without msm_predict error ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    * No predictions run
    capture msm_table, xlsx("`tmp_dir'/table_nopred.xlsx") predictions
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS K9: msm_table predictions without predict error"
    local ++pass_count
}
else {
    display as error "  FAIL K9: msm_table no-predict (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K9"
}

* --- K10: file already exists without replace error ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit
    capture erase "`tmp_dir'/table_exists.xlsx"
    msm_table, xlsx("`tmp_dir'/table_exists.xlsx") coefficients
    * Run again without replace
    capture msm_table, xlsx("`tmp_dir'/table_exists.xlsx") coefficients
    assert _rc == 602
}
if _rc == 0 {
    display as result "  PASS K10: msm_table file exists error"
    local ++pass_count
}
else {
    display as error "  FAIL K10: msm_table exists error (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K10"
}

* --- K11: weights table after diagnose ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog diagnose
    capture erase "`tmp_dir'/table_wt.xlsx"
    msm_table, xlsx("`tmp_dir'/table_wt.xlsx") weights
    confirm file "`tmp_dir'/table_wt.xlsx"
}
if _rc == 0 {
    display as result "  PASS K11: msm_table weights"
    local ++pass_count
}
else {
    display as error "  FAIL K11: msm_table weights (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K11"
}

* --- K12: balance table after diagnose ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog diagnose
    capture erase "`tmp_dir'/table_bal.xlsx"
    msm_table, xlsx("`tmp_dir'/table_bal.xlsx") balance
    confirm file "`tmp_dir'/table_bal.xlsx"
}
if _rc == 0 {
    display as result "  PASS K12: msm_table balance"
    local ++pass_count
}
else {
    display as error "  FAIL K12: msm_table balance (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K12"
}

* --- K13: sensitivity table ---
local ++test_count
capture noisily {
    _setup_pipeline, nolog fit sensitivity
    capture erase "`tmp_dir'/table_sens.xlsx"
    msm_table, xlsx("`tmp_dir'/table_sens.xlsx") sensitivity
    confirm file "`tmp_dir'/table_sens.xlsx"
}
if _rc == 0 {
    display as result "  PASS K13: msm_table sensitivity"
    local ++pass_count
}
else {
    display as error "  FAIL K13: msm_table sensitivity (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K13"
}

* =============================================================================
* SECTION L: Edge cases
* =============================================================================

* --- L1: empty dataset error ---
local ++test_count
capture noisily {
    clear
    set obs 0
    capture msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome)
    * Should fail because no obs or vars don't exist
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS L1: empty dataset error"
    local ++pass_count
}
else {
    display as error "  FAIL L1: empty dataset (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' L1"
}

* --- L2: non-binary treatment error ---
local ++test_count
capture noisily {
    clear
    set obs 100
    gen id = ceil(_n / 10)
    gen period = mod(_n - 1, 10)
    gen treatment = runiform()
    gen outcome = 0
    capture msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS L2: non-binary treatment error"
    local ++pass_count
}
else {
    display as error "  FAIL L2: non-binary treatment (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' L2"
}

* --- L3: non-integer period error ---
local ++test_count
capture noisily {
    clear
    set obs 100
    gen id = ceil(_n / 10)
    gen period = _n / 10
    gen treatment = mod(_n, 2)
    gen outcome = 0
    capture msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS L3: non-integer period error"
    local ++pass_count
}
else {
    display as error "  FAIL L3: non-integer period (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' L3"
}

* --- L4: duplicate id-period error ---
local ++test_count
capture noisily {
    clear
    set obs 100
    gen id = ceil(_n / 10)
    gen period = mod(_n - 1, 10)
    gen treatment = mod(_n, 2)
    gen outcome = 0
    * Create duplicate
    expand 2 in 1
    capture msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS L4: duplicate id-period error"
    local ++pass_count
}
else {
    display as error "  FAIL L4: duplicate id-period (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' L4"
}

* --- L5: varabbrev restored on prepare error ---
local ++test_count
capture noisily {
    set varabbrev on
    clear
    set obs 100
    gen id = ceil(_n / 10)
    gen period = _n / 10
    gen treatment = mod(_n, 2)
    gen outcome = 0
    capture msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome)
    * Should be restored regardless of error
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS L5: varabbrev restored on prepare error"
    local ++pass_count
}
else {
    display as error "  FAIL L5: varabbrev restore (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' L5"
    set varabbrev off
}

* --- L6: varabbrev restored on weight error ---
local ++test_count
capture noisily {
    set varabbrev on
    use "`pkg_dir'/msm_example.dta", clear
    * Don't run prepare → weight should fail
    capture msm_weight, treat_d_cov(biomarker age) nolog
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS L6: varabbrev restored on weight error"
    local ++pass_count
}
else {
    display as error "  FAIL L6: varabbrev weight error (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' L6"
    set varabbrev off
}

* --- L7: varabbrev restored on diagnose error ---
local ++test_count
capture noisily {
    set varabbrev on
    use "`pkg_dir'/msm_example.dta", clear
    * Not prepared → diagnose should fail
    capture msm_diagnose
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS L7: varabbrev restored on diagnose error"
    local ++pass_count
}
else {
    display as error "  FAIL L7: varabbrev diagnose error (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' L7"
    set varabbrev off
}

* --- L8: varabbrev restored on sensitivity error ---
local ++test_count
capture noisily {
    set varabbrev on
    use "`pkg_dir'/msm_example.dta", clear
    * Not prepared → sensitivity should fail
    capture msm_sensitivity
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS L8: varabbrev restored on sensitivity error"
    local ++pass_count
}
else {
    display as error "  FAIL L8: varabbrev sensitivity error (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' L8"
    set varabbrev off
}

* --- L9: varabbrev restored on predict error ---
local ++test_count
capture noisily {
    set varabbrev on
    use "`pkg_dir'/msm_example.dta", clear
    capture msm_predict, times(1 3) samples(10)
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS L9: varabbrev restored on predict error"
    local ++pass_count
}
else {
    display as error "  FAIL L9: varabbrev predict error (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' L9"
    set varabbrev off
}

* --- L10: varabbrev restored on report error ---
local ++test_count
capture noisily {
    set varabbrev on
    use "`pkg_dir'/msm_example.dta", clear
    capture msm_report
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS L10: varabbrev restored on report error"
    local ++pass_count
}
else {
    display as error "  FAIL L10: varabbrev report error (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' L10"
    set varabbrev off
}

* --- L11: msm_prepare stored results completeness ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    assert r(N) > 0
    assert r(n_ids) > 0
    assert r(n_periods) > 0
    assert r(n_events) >= 0
    assert r(n_treated) >= 0
    assert r(n_censored) >= 0
    assert "`r(id)'" == "id"
    assert "`r(period)'" == "period"
    assert "`r(treatment)'" == "treatment"
    assert "`r(outcome)'" == "outcome"
    assert "`r(censor)'" == "censored"
    assert "`r(covariates)'" == "biomarker comorbidity"
    assert "`r(baseline_covariates)'" == "age sex"
}
if _rc == 0 {
    display as result "  PASS L11: msm_prepare stored results complete"
    local ++pass_count
}
else {
    display as error "  FAIL L11: msm_prepare stored results (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' L11"
}

* --- L12: pipeline prerequisite checks ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    * msm_validate without prepare
    capture msm_validate
    assert _rc == 198
    * msm_weight without prepare
    capture msm_weight, treat_d_cov(biomarker age)
    assert _rc == 198
    * msm_fit without prepare
    capture msm_fit
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS L12: pipeline prerequisite checks"
    local ++pass_count
}
else {
    display as error "  FAIL L12: pipeline prerequisites (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' L12"
}

* --- L13: data preservation after pipeline ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    local N_before = _N
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    assert _N == `N_before'
    * Original variables should still exist
    confirm variable id period treatment outcome biomarker comorbidity age sex
}
if _rc == 0 {
    display as result "  PASS L13: data preservation after prepare"
    local ++pass_count
}
else {
    display as error "  FAIL L13: data preservation (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' L13"
}

* --- L14: package installation test ---
local ++test_count
capture noisily {
    which msm
    which msm_prepare
    which msm_validate
    which msm_weight
    which msm_fit
    which msm_predict
    which msm_diagnose
    which msm_plot
    which msm_sensitivity
    which msm_table
    which msm_report
    which msm_protocol
}
if _rc == 0 {
    display as result "  PASS L14: all commands discoverable via which"
    local ++pass_count
}
else {
    display as error "  FAIL L14: command discovery (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' L14"
}

* =============================================================================
* CLEANUP
* =============================================================================

* Remove temp directory files
capture erase "`tmp_dir'/plot_weights.gph"
capture erase "`tmp_dir'/plot_balance.gph"
capture erase "`tmp_dir'/plot_traj.gph"
capture erase "`tmp_dir'/plot_pos.gph"
capture erase "`tmp_dir'/plot_surv.gph"
capture erase "`tmp_dir'/plot_title.gph"
capture erase "`tmp_dir'/protocol.csv"
capture erase "`tmp_dir'/protocol.xlsx"
capture erase "`tmp_dir'/protocol.tex"
capture erase "`tmp_dir'/report.csv"
capture erase "`tmp_dir'/report.xlsx"
capture erase "`tmp_dir'/report_eform.csv"
capture erase "`tmp_dir'/table_all.xlsx"
capture erase "`tmp_dir'/table_coef.xlsx"
capture erase "`tmp_dir'/table_eform.xlsx"
capture erase "`tmp_dir'/table_dec.xlsx"
capture erase "`tmp_dir'/table_title.xlsx"
capture erase "`tmp_dir'/table_sep.xlsx"
capture erase "`tmp_dir'/table_replace.xlsx"
capture erase "`tmp_dir'/table_nopred.xlsx"
capture erase "`tmp_dir'/table_exists.xlsx"
capture erase "`tmp_dir'/table_wt.xlsx"
capture erase "`tmp_dir'/table_bal.xlsx"
capture erase "`tmp_dir'/table_sens.xlsx"
capture rmdir "`tmp_dir'"

* =============================================================================
* SUMMARY
* =============================================================================

timer off 99
quietly timer list 99

display as text ""
display as result "Expanded Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display as error "Failed:`failed_tests'"
}
else {
    display as result "ALL TESTS PASSED"
}

display ""
display "RESULT: TEST tests=`test_count' pass=`pass_count' fail=`fail_count' status=" cond(`fail_count' > 0, "FAIL", "PASS")

if `fail_count' > 0 {
    exit 1
}
