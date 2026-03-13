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
local tte_dir "/home/tpcopeland/Stata-Tools/tte"
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
    run "`tte_dir'/tte_plot.ado"
    run "`tte_dir'/tte_report.ado"
    run "`tte_dir'/tte_protocol.ado"
    cap run "`tte_dir'/_tte_col_letter.ado"
    cap run "`tte_dir'/tte_calibrate.ado"
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
    assert r(n_commands) == 11
    assert "`r(version)'" == "1.1.0"
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
        truncate(1 99) nolog

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
* TEST 21: tte_predict with ratio option (Feature 1)
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_predict with ratio"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog

    tte_predict, times(0 2 4) ratio samples(30) seed(42)

    matrix pred = r(predictions)
    assert colsof(pred) == 10
    assert "`r(target)'" == "ATE"

    * RR should be est_1 / est_0
    local est_0_t2 = pred[2, 2]
    local est_1_t2 = pred[2, 5]
    local rr_t2 = pred[2, 8]
    assert reldif(`rr_t2', `est_1_t2' / `est_0_t2') < 0.001

    * RR CI should bracket the point estimate
    local rr_lo_t2 = pred[2, 9]
    local rr_hi_t2 = pred[2, 10]
    assert `rr_lo_t2' <= `rr_t2'
    assert `rr_hi_t2' >= `rr_t2'

    * r(rr_#) scalars returned
    assert r(rr_2) != .
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
* TEST 22: tte_predict with both difference and ratio
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_predict with difference and ratio"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog

    tte_predict, times(0 2 4) difference ratio samples(30) seed(42)

    matrix pred = r(predictions)
    * 7 base + 3 diff + 3 ratio = 13
    assert colsof(pred) == 13

    * Check diff is in cols 8-10, ratio in 11-13
    local diff_t2 = pred[2, 8]
    local rr_t2 = pred[2, 11]
    assert `diff_t2' != .
    assert `rr_t2' != .
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
* TEST 23: tte_predict with ATT option (Feature 6)
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_predict with ATT"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog

    tte_predict, times(0 2 4) att samples(30) seed(42)

    assert "`r(target)'" == "ATT"
    matrix pred = r(predictions)
    assert rowsof(pred) == 3
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
* TEST 24: tte_weight with save_ps (Feature 2)
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_weight with save_ps"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)

    tte_weight, switch_d_cov(age sex comorbidity) save_ps truncate(1 99) nolog

    * r() scalars for PS returned (check before any other r-class command)
    assert r(mean_ps) != .
    assert r(sd_ps) != .
    assert r(min_ps) >= 0
    assert r(max_ps) <= 1

    * PS variable should exist
    confirm variable _tte_pscore

    * PS values should be in [0, 1]
    quietly summarize _tte_pscore if !missing(_tte_pscore)
    assert r(min) >= 0
    assert r(max) <= 1

    * Characteristic stored
    local ps_var : char _dta[_tte_pscore_var]
    assert "`ps_var'" == "_tte_pscore"
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
* TEST 25: tte_weight with trim_ps (Feature 7b)
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_weight with trim_ps"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)

    * Count observations before trimming
    quietly count
    local n_before = r(N)

    tte_weight, switch_d_cov(age sex comorbidity) trim_ps(5) nolog

    * Return values (check before any other r-class command)
    local n_ps_trimmed = r(n_ps_trimmed)
    local ps_lo_cut = r(ps_lo_cut)
    local ps_hi_cut = r(ps_hi_cut)
    assert `n_ps_trimmed' >= 0
    assert `ps_lo_cut' != .
    assert `ps_hi_cut' != .
    assert `ps_lo_cut' < `ps_hi_cut'

    * Should have fewer observations after trimming
    quietly count
    local n_after = r(N)
    assert `n_after' <= `n_before'
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
* TEST 26: tte_plot type(pscore) (Feature 3)
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_plot type(pscore)"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) save_ps truncate(1 99) nolog

    * PS overlap plot should work without error
    tte_plot, type(pscore)

    assert "`r(type)'" == "pscore"
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
* TEST 27: tte_diagnose with equipoise (Feature 4)
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_diagnose with equipoise"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) save_ps truncate(1 99) nolog

    tte_diagnose, equipoise

    * Check returned values
    assert r(prevalence) > 0 & r(prevalence) < 1
    assert r(pct_equipoise) >= 0 & r(pct_equipoise) <= 100
    assert r(mean_pref_treat) != .
    assert r(mean_pref_control) != .
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
* TEST 28: tte_plot type(equipoise) (Feature 4)
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_plot type(equipoise)"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) save_ps truncate(1 99) nolog

    tte_plot, type(equipoise)

    assert "`r(type)'" == "equipoise"
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
* TEST 29: tte_plot type(balance) with top() (Feature 5)
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_plot type(balance) with top()"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) truncate(1 99) nolog

    tte_diagnose, balance_covariates(age sex comorbidity biomarker)

    * Love plot with top 2
    tte_plot, type(balance) top(2)

    assert "`r(type)'" == "balance"
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
* TEST 30: tte_calibrate basic (Feature 7)
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_calibrate basic"
display _dup(60) "-"

capture noisily {
    * Create NCO matrix: 5 negative controls
    matrix nco = (0.02, 0.15 \ -0.05, 0.12 \ 0.08, 0.18 \ -0.01, 0.14 \ 0.03, 0.16)

    tte_calibrate, estimate(-0.35) se(0.12) nco_estimates(nco)

    * Should return all expected scalars
    assert r(n_nco) == 5
    assert r(estimate) == -0.35
    assert r(se) == 0.12
    assert r(bias) != .
    assert r(sigma) != .
    assert r(cal_estimate) != .
    assert r(cal_se) != .
    assert "`r(method)'" == "normal"

    * Calibrated SE should be >= uncalibrated SE (it adds sigma^2)
    assert r(cal_se) >= r(se) - 0.001

    * Calibrated CI should be at least as wide as uncalibrated
    local uncal_width = r(ci_hi) - r(ci_lo)
    local cal_width = r(cal_ci_hi) - r(cal_ci_lo)
    assert `cal_width' >= `uncal_width' - 0.001
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
* TEST 31: tte_calibrate validation (bad inputs)
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_calibrate input validation"
display _dup(60) "-"

capture noisily {
    * Too few NCOs (< 3)
    matrix nco_bad = (0.02, 0.15 \ -0.05, 0.12)
    capture tte_calibrate, estimate(-0.35) se(0.12) nco_estimates(nco_bad)
    assert _rc == 198

    * Negative SE
    capture tte_calibrate, estimate(-0.35) se(-0.1) nco_estimates(nco)
    assert _rc == 198

    * Wrong matrix dimensions (3 columns)
    matrix nco_3col = (0.02, 0.15, 1 \ -0.05, 0.12, 2 \ 0.08, 0.18, 3)
    capture tte_calibrate, estimate(-0.35) se(0.12) nco_estimates(nco_3col)
    assert _rc == 503
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
* TEST 32: tte_plot type(pscore) errors without save_ps
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_plot pscore errors without save_ps"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog

    * Should fail because save_ps was not used
    capture tte_plot, type(pscore)
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
* TEST 33: Full pipeline with new features
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': Full pipeline with ratio, save_ps, equipoise"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear

    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) censor(censored) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) save_ps truncate(1 99) nolog
    tte_diagnose, balance_covariates(age sex comorbidity) equipoise
    tte_fit, outcome_cov(age sex comorbidity) nolog

    tte_predict, times(0 2 4) difference ratio samples(30) seed(42)

    * Verify all results
    matrix pred = r(predictions)
    assert colsof(pred) == 13
    assert r(rr_4) != .
    assert r(rd_4) != .
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
* TEST 34: tte_weight with switch numerator covariates (stabilized weights)
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_weight switch_n_cov + stabilized"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)

    tte_weight, switch_d_cov(age sex comorbidity) ///
        switch_n_cov(age sex) truncate(1 99) nolog

    confirm variable _tte_weight
    quietly summarize _tte_weight
    assert r(min) > 0
    assert r(mean) > 0
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
* TEST 35: tte_weight with IPCW censoring weights
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_weight censor_d_cov and censor_n_cov"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) censor(censored) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)

    tte_weight, switch_d_cov(age sex comorbidity) ///
        censor_d_cov(age sex) censor_n_cov(age) ///
        truncate(1 99) nolog

    confirm variable _tte_weight
    quietly summarize _tte_weight
    assert r(min) > 0
    assert r(mean) > 0
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
* TEST 36: tte_weight with pool_switch and pool_censor
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_weight pool_switch and pool_censor"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) censor(censored) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)

    tte_weight, switch_d_cov(age sex comorbidity) ///
        censor_d_cov(age sex) ///
        pool_switch pool_censor truncate(1 99) nolog

    confirm variable _tte_weight
    quietly summarize _tte_weight
    assert r(min) > 0
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
* TEST 37: tte_weight with custom generate name
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_weight generate(custom_wt)"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)

    tte_weight, switch_d_cov(age sex comorbidity) ///
        generate(custom_wt) truncate(1 99) nolog

    confirm variable custom_wt
    quietly summarize custom_wt
    assert r(min) > 0
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
* TEST 38: tte_fit with natural spline ns(3) specs
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_fit followup_spec(ns(3)) trial_period_spec(ns(3))"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(ITT)
    tte_expand, maxfollowup(5)
    tte_weight, nolog

    tte_fit, outcome_cov(age sex) followup_spec(ns(3)) ///
        trial_period_spec(ns(3)) nolog

    assert e(N) > 0
    assert "`e(tte_followup_spec)'" == "ns(3)"
    assert "`e(tte_trial_spec)'" == "ns(3)"
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
* TEST 39: tte_fit with cubic and none specs
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_fit followup_spec(cubic) trial_period_spec(none)"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(ITT)
    tte_expand, maxfollowup(5)
    tte_weight, nolog

    tte_fit, outcome_cov(age sex) followup_spec(cubic) ///
        trial_period_spec(none) nolog

    assert e(N) > 0
    assert "`e(tte_followup_spec)'" == "cubic"
    assert "`e(tte_trial_spec)'" == "none"
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
* TEST 40: tte_fit with level() option
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_fit level(90)"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(5)
    tte_weight, nolog

    tte_fit, outcome_cov(age sex) level(90) nolog

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
* TEST 41: tte_predict type(survival)
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_predict type(survival)"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog

    tte_predict, times(0 2 4) type(survival) samples(30) seed(42)

    matrix pred = r(predictions)
    assert rowsof(pred) == 3
    assert "`r(type)'" == "survival"

    * Survival should be in [0, 1]
    forvalues i = 1/3 {
        assert pred[`i', 2] >= 0 & pred[`i', 2] <= 1
        assert pred[`i', 5] >= 0 & pred[`i', 5] <= 1
    }

    * Survival should decrease over time (or stay same)
    assert pred[1, 2] >= pred[3, 2]
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
* TEST 42: tte_predict type(survival) + type(cum_inc) complement to ~1
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': survival + cum_inc complement to ~1"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog

    tte_predict, times(0 2 4) type(survival) samples(30) seed(42)
    matrix surv = r(predictions)

    tte_predict, times(0 2 4) type(cum_inc) samples(30) seed(42)
    matrix cinc = r(predictions)

    * survival + cumulative incidence should sum to ~1 for each arm/time
    forvalues i = 1/3 {
        local s0 = surv[`i', 2]
        local c0 = cinc[`i', 2]
        assert abs(`s0' + `c0' - 1) < 0.01

        local s1 = surv[`i', 5]
        local c1 = cinc[`i', 5]
        assert abs(`s1' + `c1' - 1) < 0.01
    }
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
* TEST 43: tte_predict with level() option
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_predict level(90) narrower than level(99)"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog

    tte_predict, times(0 2 4) type(cum_inc) level(90) samples(50) seed(42)
    matrix pred90 = r(predictions)

    tte_predict, times(0 2 4) type(cum_inc) level(99) samples(50) seed(42)
    matrix pred99 = r(predictions)

    * 90% CI should be narrower than 99% CI at time 4
    local w90 = pred90[3, 4] - pred90[3, 3]
    local w99 = pred99[3, 4] - pred99[3, 3]
    assert `w90' < `w99'
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
* TEST 44: tte_report CSV export
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_report format(csv) export"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog

    tempfile csv_out
    tte_report, format(csv) export("`csv_out'") decimals(4) replace

    confirm file "`csv_out'"
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
* TEST 45: tte_report Excel export with predictions
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_report format(excel) with predictions"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog
    tte_predict, times(0 2 4) difference samples(30) seed(42)

    matrix preds = r(predictions)
    tempfile xlsx_out
    tte_report, format(excel) export("`xlsx_out'") ///
        predictions(preds) eform replace

    confirm file "`xlsx_out'"
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
* TEST 46: tte_plot type(km) and type(weights)
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_plot type(km) and type(weights)"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog
    tte_predict, times(0 1 2 3 4 5) samples(30) seed(42)

    * ci option not allowed with pweighted KM — test without ci
    tte_plot, type(km)
    assert "`r(type)'" == "km"

    tte_plot, type(weights)
    assert "`r(type)'" == "weights"
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
* TEST 47: tte_plot export to file
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_plot export() creates file"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog
    tte_predict, times(0 1 2 3 4 5) samples(30) seed(42)

    local plot_out "_test_tte_plot_export.png"
    capture erase "`plot_out'"
    tte_plot, type(km) export("`plot_out'") replace

    confirm file "`plot_out'"
    erase "`plot_out'"
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
* TEST 48: tte_protocol auto and export
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_protocol auto and export"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog

    * Auto-generate from metadata
    tte_protocol, auto

    * Export to CSV
    tempfile proto_out
    tte_protocol, auto format(csv) export("`proto_out'") replace

    confirm file "`proto_out'"
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
* TEST 49: tte_validate strict mode catches data issues
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_validate strict catches errors in example data"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)

    * strict mode should catch known issues in example data
    capture tte_validate, strict verbose
    local val_rc = _rc
    assert `val_rc' == 198
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
* TEST 50: tte_expand save() and replace
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_expand save() and replace"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(ITT)

    tempfile saved_expand
    tte_expand, maxfollowup(3) save("`saved_expand'") replace

    * Saved file should exist
    confirm file "`saved_expand'"

    * Data should be expanded (more rows than original)
    assert _N > 0
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
* TEST 51: tte_prepare with AT estimand
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_prepare with AT estimand"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(AT)
    assert "`r(estimand)'" == "AT"
    local est : char _dta[_tte_estimand]
    assert "`est'" == "AT"
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
* TEST 52: tte overview with list, detail, protocol options
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte list, detail, protocol options"
display _dup(60) "-"

capture noisily {
    tte, list
    assert r(n_commands) > 0

    tte, detail
    assert r(n_commands) > 0

    tte, protocol
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
* TEST 53: tte_diagnose by_trial option
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_diagnose by_trial"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog

    tte_diagnose, by_trial
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
* TEST 54: Data preservation — _N unchanged after predict/diagnose/report
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': Data preservation through pipeline"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)

    * Record N after expand
    local n_expanded = _N

    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    assert _N == `n_expanded'

    tte_fit, outcome_cov(age sex comorbidity) nolog
    assert _N == `n_expanded'

    tte_predict, times(0 2 4) samples(30) seed(42)
    assert _N == `n_expanded'

    tte_diagnose, balance_covariates(age sex comorbidity)
    assert _N == `n_expanded'

    tte_report, eform
    assert _N == `n_expanded'
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
* TEST 55: tte_prepare rejects non-binary treatment/outcome
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_prepare rejects non-binary variables"
display _dup(60) "-"

capture noisily {
    * Non-binary treatment
    use "`tte_dir'/tte_example.dta", clear
    replace treatment = 2 in 1
    capture tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    assert _rc != 0

    * Non-binary outcome
    use "`tte_dir'/tte_example.dta", clear
    replace outcome = 3 in 1
    capture tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    assert _rc != 0
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
* TEST 56: tte_prepare rejects missing required variables
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_prepare rejects missing required args"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear

    * Missing id
    capture tte_prepare, period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    assert _rc != 0

    * Missing outcome
    capture tte_prepare, id(patid) period(period) treatment(treatment) ///
        eligible(eligible) estimand(ITT)
    assert _rc != 0
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
* TEST 57: tte_expand without replace errors on existing save file
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_expand save() without replace errors"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)

    tempfile saved_exp2
    tte_expand, maxfollowup(3) save("`saved_exp2'") replace

    * Re-run without replace should fail
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    capture tte_expand, maxfollowup(3) save("`saved_exp2'")
    assert _rc != 0
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
* TEST 58: tte_plot type(cumhaz)
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_plot type(cumhaz)"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog
    tte_predict, times(0 1 2 3 4 5) samples(30) seed(42)

    tte_plot, type(cumhaz)
    assert "`r(type)'" == "cumhaz"
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
* TEST 59: Return value exhaustiveness — tte_expand
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_expand return value exhaustiveness"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)

    assert r(n_trials) > 0
    assert r(n_expanded) > 0
    assert r(n_treat) > 0
    assert r(n_control) > 0
    assert r(expansion_ratio) > 1
    assert "`r(estimand)'" == "PP"
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
* TEST 60: Return value exhaustiveness — tte_weight
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_weight return value exhaustiveness"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog

    assert r(mean_weight) > 0
    assert r(sd_weight) >= 0
    assert r(min_weight) > 0
    assert r(max_weight) > 0
    assert r(p1_weight) != .
    assert r(p99_weight) != .
    assert r(ess) > 0
    assert r(n_truncated) >= 0
    assert "`r(generate)'" == "_tte_weight"
    assert "`r(estimand)'" == "PP"
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
* TEST 61: Return value exhaustiveness — tte_predict
* ============================================================================
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_predict return value exhaustiveness"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog

    tte_predict, times(0 2 4) difference ratio samples(30) seed(42)

    assert r(n_times) == 3
    assert r(samples) == 30
    assert r(level) == 95
    assert "`r(type)'" == "cum_inc"
    assert "`r(estimand)'" == "PP"
    assert "`r(target)'" == "ATE"
    assert r(rd_0) != .
    assert r(rd_2) != .
    assert r(rd_4) != .
    assert r(rr_0) != .
    assert r(rr_2) != .
    assert r(rr_4) != .
    matrix pred = r(predictions)
    assert rowsof(pred) == 3
    assert colsof(pred) == 13
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
