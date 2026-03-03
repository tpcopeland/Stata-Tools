* validate_diagnostics.do — V7: Diagnostics, Reporting, Sensitivity
* Tests msm_diagnose, msm_report, msm_protocol, msm_sensitivity, msm_plot
* Uses msm_example.dta after full pipeline

version 16.0
set more off
set varabbrev off

local qa_dir "/home/tpcopeland/Stata-Dev/msm/qa"
adopath ++ "/home/tpcopeland/Stata-Dev/msm"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display "V7: DIAGNOSTICS, REPORTING, SENSITIVITY"
display "Date: $S_DATE $S_TIME"
display ""

* =========================================================================
* Setup: Run full pipeline on msm_example.dta
* =========================================================================
display "Setting up pipeline on msm_example.dta..."
use "/home/tpcopeland/Stata-Dev/msm/msm_example.dta", clear
msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) censor(censored) ///
    covariates(biomarker comorbidity) ///
    baseline_covariates(age sex)

msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
    treat_n_cov(age sex) truncate(1 99) nolog

msm_fit, model(logistic) outcome_cov(age sex) ///
    period_spec(quadratic) nolog

display ""

* =========================================================================
* Test 7.1: msm_diagnose returns all scalars
* =========================================================================
local ++test_count
capture {
    msm_diagnose, balance_covariates(biomarker comorbidity age sex) threshold(0.1)

    * Check key return scalars exist
    assert r(mean_weight) != .
    assert r(sd_weight) != .
    assert r(ess) != .
    assert r(ess_pct) != .
    assert r(min_weight) != .
    assert r(max_weight) != .
    display "  ESS: " %9.1f r(ess) " (" %5.1f r(ess_pct) "%)"
}
if _rc == 0 {
    display as result "  PASS 7.1: msm_diagnose returns all scalars"
    local ++pass_count
}
else {
    display as error "  FAIL 7.1: msm_diagnose scalars missing (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.1"
}

* =========================================================================
* Test 7.2: msm_diagnose by_period works
* =========================================================================
local ++test_count
capture {
    msm_diagnose, by_period
    * Should not error
    assert r(ess) > 0
}
if _rc == 0 {
    display as result "  PASS 7.2: msm_diagnose by_period works"
    local ++pass_count
}
else {
    display as error "  FAIL 7.2: msm_diagnose by_period failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.2"
}

* =========================================================================
* Test 7.3: Balance improves with weighting
* =========================================================================
local ++test_count
capture {
    msm_diagnose, balance_covariates(biomarker comorbidity age sex) threshold(0.1)
    tempname bal
    matrix `bal' = r(balance)

    * Check that at least one covariate has reduced SMD
    local n_improved = 0
    local n_covs = rowsof(`bal')
    forvalues i = 1/`n_covs' {
        if abs(`bal'[`i', 2]) < abs(`bal'[`i', 1]) {
            local ++n_improved
        }
    }
    display "  Covariates with improved balance: `n_improved' of `n_covs'"
    assert `n_improved' > 0
}
if _rc == 0 {
    display as result "  PASS 7.3: Weighting improves balance"
    local ++pass_count
}
else {
    display as error "  FAIL 7.3: Balance not improved (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.3"
}

* =========================================================================
* Test 7.4: msm_report display mode
* =========================================================================
local ++test_count
capture {
    msm_report, eform
}
if _rc == 0 {
    display as result "  PASS 7.4: msm_report display works"
    local ++pass_count
}
else {
    display as error "  FAIL 7.4: msm_report display failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.4"
}

* =========================================================================
* Test 7.5: msm_report CSV export
* =========================================================================
local ++test_count
capture {
    local csv_file "`qa_dir'/_test_report.csv"
    msm_report, export("`csv_file'") format(csv) eform replace
    confirm file "`csv_file'"
    erase "`csv_file'"
}
if _rc == 0 {
    display as result "  PASS 7.5: msm_report CSV export works"
    local ++pass_count
}
else {
    display as error "  FAIL 7.5: msm_report CSV failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.5"
}

* =========================================================================
* Test 7.6: msm_protocol with all 7 fields
* =========================================================================
local ++test_count
capture {
    msm_protocol, ///
        population("HIV+ adults on ART") ///
        treatment("HAART initiation vs. no HAART") ///
        confounders("CD4 count, viral load, age, sex") ///
        outcome("AIDS-defining illness or death") ///
        causal_contrast("Always vs. never treated") ///
        weight_spec("Stabilized IPTW, truncated at 1st/99th") ///
        analysis("Pooled logistic MSM with quadratic period")
}
if _rc == 0 {
    display as result "  PASS 7.6: msm_protocol with all 7 fields"
    local ++pass_count
}
else {
    display as error "  FAIL 7.6: msm_protocol failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.6"
}

* =========================================================================
* Test 7.7: msm_sensitivity evalue > 1
* =========================================================================
local ++test_count
capture {
    msm_sensitivity, evalue

    local ev = r(evalue_point)
    display "  E-value: " %7.4f `ev'
    assert `ev' > 1
}
if _rc == 0 {
    display as result "  PASS 7.7: E-value > 1"
    local ++pass_count
}
else {
    display as error "  FAIL 7.7: E-value should be > 1 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.7"
}

* =========================================================================
* Test 7.8: msm_sensitivity confounding_strength runs
* =========================================================================
local ++test_count
capture {
    msm_sensitivity, confounding_strength(1.5 2.0)
    assert r(bias_factor) > 0
    assert r(corrected_effect) > 0
    display "  Bias factor: " %7.4f r(bias_factor)
}
if _rc == 0 {
    display as result "  PASS 7.8: confounding_strength runs"
    local ++pass_count
}
else {
    display as error "  FAIL 7.8: confounding_strength failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.8"
}

* =========================================================================
* Test 7.9: msm_plot weights
* =========================================================================
local ++test_count
capture {
    msm_plot, type(weights)
    graph close _all
}
if _rc == 0 {
    display as result "  PASS 7.9: msm_plot weights runs"
    local ++pass_count
}
else {
    display as error "  FAIL 7.9: msm_plot weights failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.9"
}

* =========================================================================
* Test 7.10: msm_plot positivity
* =========================================================================
local ++test_count
capture {
    msm_plot, type(positivity)
    graph close _all
}
if _rc == 0 {
    display as result "  PASS 7.10: msm_plot positivity runs"
    local ++pass_count
}
else {
    display as error "  FAIL 7.10: msm_plot positivity failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.10"
}

* =========================================================================
* SUMMARY
* =========================================================================
display ""
display "V7: DIAGNOSTICS SUMMARY"
display "Total tests:  `test_count'"
display "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
    display as error "Failed tests:`failed_tests'"
}
else {
    display "Failed:       `fail_count'"
}

local v_status = cond(`fail_count' > 0, "FAIL", "PASS")
display ""
display "RESULT: V7 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"
display ""
display "Completed: $S_DATE $S_TIME"

if `fail_count' > 0 {
    exit 1
}
