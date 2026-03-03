/*******************************************************************************
* test_tte.do
*
* Functional tests for the tte (Target Trial Emulation) package
* Run with: stata-mp -b do test_tte.do
*******************************************************************************/

clear all
set more off
version 16.0

capture log close
log using "test_tte.log", replace nomsg

display _dup(70) "="
display "FUNCTIONAL TESTS: tte (Target Trial Emulation)"
display "Date: $S_DATE $S_TIME"
display _dup(70) "="

* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0

* Uninstall any installed version
capture ado uninstall tte

* Load programs from local directory
local tte_dir "/home/tpcopeland/Stata-Dev/tte"
quietly {
    cap program drop tte
    cap program drop tte_prepare
    cap program drop tte_validate
    cap program drop tte_expand
    cap program drop tte_weight
    cap program drop tte_fit
    cap program drop tte_predict
    cap program drop tte_diagnose
    cap program drop tte_plot
    cap program drop tte_report
    cap program drop tte_protocol
    cap program drop _tte_check_prepared
    cap program drop _tte_check_expanded
    cap program drop _tte_check_weighted
    cap program drop _tte_check_fitted
    cap program drop _tte_get_settings
    cap program drop _tte_memory_estimate
    cap program drop _tte_display_header
    cap program drop _tte_natural_spline
    cap program drop _tte_expand_censor
    cap program drop _tte_weight_switch_arm
    cap program drop _tte_weight_switch_pooled
    cap program drop _tte_weight_censor_arm
    cap program drop _tte_weight_censor_pooled
    cap program drop _tte_predict_xb
    cap program drop _tte_overview_detail

    run "`tte_dir'/_tte_check_prepared.ado"
    run "`tte_dir'/_tte_check_expanded.ado"
    run "`tte_dir'/_tte_check_weighted.ado"
    run "`tte_dir'/_tte_check_fitted.ado"
    run "`tte_dir'/_tte_get_settings.ado"
    run "`tte_dir'/_tte_memory_estimate.ado"
    run "`tte_dir'/_tte_display_header.ado"
    run "`tte_dir'/_tte_natural_spline.ado"
    run "`tte_dir'/tte.ado"
    run "`tte_dir'/tte_prepare.ado"
    run "`tte_dir'/tte_validate.ado"
    run "`tte_dir'/tte_expand.ado"
    run "`tte_dir'/tte_weight.ado"
    run "`tte_dir'/tte_fit.ado"
    run "`tte_dir'/tte_predict.ado"
    run "`tte_dir'/tte_diagnose.ado"
    run "`tte_dir'/tte_report.ado"
    run "`tte_dir'/tte_protocol.ado"
}

* ============================================================================
* TEST 1: tte command loads and displays overview
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte overview command"
display _dup(60) "-"

capture noisily {
    tte
    assert r(n_commands) == 10
    assert "`r(version)'" == "1.0.2"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ============================================================================
* TEST 2: tte_prepare with example data
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_prepare with example data"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) censor(censored) ///
        covariates(age sex comorbidity biomarker) ///
        baseline_covariates(age sex) estimand(PP)

    assert r(N) > 0
    assert r(n_ids) > 0
    assert r(n_eligible) > 0
    assert "`r(estimand)'" == "PP"
    assert "`r(id)'" == "patid"

    * Check characteristics stored
    local check_prep : char _dta[_tte_prepared]
    assert "`check_prep'" == "1"
    local check_id : char _dta[_tte_id]
    assert "`check_id'" == "patid"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ============================================================================
* TEST 3: tte_prepare rejects bad data
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_prepare rejects invalid estimand"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    capture tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(INVALID)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ============================================================================
* TEST 4: tte_validate passes on good data
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_validate on prepared data"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)
    tte_validate

    assert r(n_errors) == 0
    assert "`r(validation)'" == "passed"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ============================================================================
* TEST 5: tte_validate fails without prepare
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_validate without tte_prepare fails"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    capture tte_validate
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ============================================================================
* TEST 6: tte_expand PP estimand
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_expand with PP estimand"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)

    tte_expand, maxfollowup(5) grace(1)

    * Check created variables
    confirm variable _tte_trial
    confirm variable _tte_arm
    confirm variable _tte_followup
    confirm variable _tte_censored
    confirm variable _tte_outcome_obs

    * Check we have both arms
    quietly count if _tte_arm == 1
    assert r(N) > 0
    quietly count if _tte_arm == 0
    assert r(N) > 0

    * Check expansion happened
    assert r(n_trials) > 0
    assert r(n_expanded) > 0
    assert r(expansion_ratio) > 1

    * Check metadata
    local check_exp : char _dta[_tte_expanded]
    assert "`check_exp'" == "1"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ============================================================================
* TEST 7: tte_expand ITT estimand (no cloning)
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_expand with ITT estimand"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)

    tte_expand, maxfollowup(5)

    * ITT: no artificial censoring
    quietly count if _tte_censored == 1
    assert r(N) == 0

    assert r(n_trials) > 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ============================================================================
* TEST 8: tte_weight PP with switch weights
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_weight with PP estimand"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)

    tte_expand, maxfollowup(5) grace(1)

    tte_weight, switch_d_cov(age sex comorbidity) ///
        stabilized truncate(1 99) nolog

    * Check weight variable created
    confirm variable _tte_weight

    * Weights should be positive
    quietly summarize _tte_weight
    assert r(min) > 0
    assert r(mean) > 0

    * ESS should be positive
    assert r(ess) > 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ============================================================================
* TEST 9: tte_weight ITT (all weights = 1)
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_weight ITT (weights = 1)"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(5)
    tte_weight, nolog

    confirm variable _tte_weight
    quietly summarize _tte_weight
    assert r(mean) == 1
    assert r(sd) == 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ============================================================================
* TEST 10: tte_fit pooled logistic
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_fit pooled logistic"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog

    tte_fit, outcome_cov(age sex comorbidity) model(logistic) nolog

    * Check model was fitted
    assert e(N) > 0
    assert "`e(tte_model)'" == "logistic"
    assert "`e(tte_estimand)'" == "PP"

    * Treatment coefficient should exist
    local b_arm = _b[_tte_arm]
    assert !missing(`b_arm')

    * Metadata
    local check_fit : char _dta[_tte_fitted]
    assert "`check_fit'" == "1"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ============================================================================
* TEST 11: tte_predict cumulative incidence
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_predict cumulative incidence"
display _dup(60) "-"

capture noisily {
    * Using the already-fitted model from test 10
    * Need to re-run pipeline since data may have changed
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog

    tte_predict, times(0 2 4) type(cum_inc) difference samples(50) seed(12345)

    * Check predictions matrix
    matrix pred = r(predictions)
    assert rowsof(pred) == 3
    assert colsof(pred) == 10

    * Cumulative incidence should be between 0 and 1
    assert pred[1, 2] >= 0 & pred[1, 2] <= 1
    assert pred[3, 5] >= 0 & pred[3, 5] <= 1

    * CI should bracket estimate
    assert pred[3, 3] <= pred[3, 2]
    assert pred[3, 4] >= pred[3, 2]
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ============================================================================
* TEST 12: tte_diagnose weight diagnostics
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_diagnose with balance"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog

    tte_diagnose, balance_covariates(age sex comorbidity)

    assert r(ess) > 0
    assert r(max_smd_unwt) >= 0

    * Balance matrix should have 3 covariates
    matrix bal = r(balance)
    assert rowsof(bal) == 3
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ============================================================================
* TEST 13: tte_report displays results
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_report"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog

    tte_report, eform

    assert "`r(estimand)'" == "PP"
    assert r(n_events) > 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ============================================================================
* TEST 14: tte_protocol table
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_protocol"
display _dup(60) "-"

capture noisily {
    tte_protocol, eligibility("Age >= 18, no prior event") ///
        treatment("Initiate drug vs no drug") ///
        assignment("At each eligible period") ///
        followup_start("Start of eligible period") ///
        outcome("All-cause mortality") ///
        causal_contrast("Per-protocol effect") ///
        analysis("Pooled logistic with IPCW")

    assert "`r(eligibility)'" == "Age >= 18, no prior event"
    assert "`r(outcome)'" == "All-cause mortality"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ============================================================================
* TEST 15: Full ITT pipeline (end-to-end)
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': Full ITT pipeline"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear

    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(ITT)
    tte_validate
    tte_expand, maxfollowup(5)
    tte_weight, nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog
    tte_predict, times(0 2 4) samples(30) seed(42)

    * All steps completed
    matrix pred = r(predictions)
    assert rowsof(pred) == 3

    * Cumulative incidence should increase over time
    assert pred[1, 2] <= pred[3, 2]
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ============================================================================
* TEST 16: tte_fit Cox model
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_fit Cox model"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog

    tte_fit, outcome_cov(age sex comorbidity) model(cox) nolog

    assert e(N) > 0
    assert "`e(tte_model)'" == "cox"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ============================================================================
* TEST 17: tte_expand without tte_prepare fails
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_expand without prepare fails"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    capture tte_expand, maxfollowup(5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ============================================================================
* TEST 18: tte_prepare with ITT estimand
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_prepare with ITT estimand"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    assert "`r(estimand)'" == "ITT"
    local est : char _dta[_tte_estimand]
    assert "`est'" == "ITT"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ============================================================================
* TEST 19: Specific trial periods
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_expand with specific trial periods"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, trials(0 1 2) maxfollowup(3)

    * Should only have trials 0, 1, 2
    quietly levelsof _tte_trial, local(trial_vals)
    local n_trials: word count `trial_vals'
    assert `n_trials' <= 3
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ============================================================================
* TEST 20: tte_fit with linear followup spec
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_fit with linear followup spec"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(5)
    tte_weight, nolog

    tte_fit, outcome_cov(age sex) followup_spec(linear) ///
        trial_period_spec(linear) nolog

    assert e(N) > 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ============================================================================
* SUMMARY
* ============================================================================

display ""
display _dup(70) "="
display "TEST SUMMARY"
display _dup(70) "="
display "Tests run:    `test_count'"
display "Passed:       `pass_count'"
display "Failed:       `fail_count'"
display _dup(70) "="

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}

log close
exit, clear
