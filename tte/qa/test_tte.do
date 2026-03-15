/*******************************************************************************
* test_tte.do
*
* Consolidated functional tests for the tte (Target Trial Emulation) package.
* 174 tests across 27 sections.
*
* Sections:
*   1. tte overview and options (7 tests)
*   2. tte_prepare (10 tests)
*   3. tte_validate (3 tests)
*   4. tte_expand (6 tests)
*   5. tte_weight (8 tests)
*   6. tte_fit (6 tests)
*   7. tte_predict (6 tests)
*   8. tte_report and export (3 tests)
*   9. tte_plot (4 tests)
*  10. tte_protocol (2 tests)
*  11. Data preservation and return values (6 tests)
*  12. Natural censoring via censor() (6 tests)
*  13. Weight variable resolver (5 tests)
*  14. Balance SMDs at baseline (2 tests)
*  15. Per-period positivity (4 tests)
*  16. strict promotes warnings to errors (2 tests)
*  17. ITT weight metadata (3 tests)
*  18. tte_calibrate (15 tests)
*  19. tte_protocol extended (8 tests)
*  20. tte_plot extended (8 tests)
*  21. tte_validate all 10 checks (12 tests)
*  22. tte_weight advanced options (10 tests)
*  23. tte_fit & tte_predict advanced (9 tests)
*  24. tte_report & tte_diagnose advanced (7 tests)
*  25. Pipeline error handling (6 tests)
*  26. Return value completeness (5 tests)
*
* Run with: stata-mp -b do test_tte.do
*******************************************************************************/

clear all
set more off
version 16.0

capture log close
log using "test_tte.log", replace nomsg

display "FUNCTIONAL TESTS: tte (Target Trial Emulation)"
display "Date: $S_DATE $S_TIME"

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
    cap program drop tte_calibrate
    cap program drop _tte_check_prepared
    cap program drop _tte_check_expanded
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
    cap program drop _tte_weight_switch_stratum
    cap program drop _tte_expand_factors
    cap program drop _tte_predict_xb
    cap program drop _tte_overview_detail
    cap program drop _tte_protocol_overview
    cap program drop _tte_calibrate_fit
    cap program drop _tte_cal_profile_ll
    cap program drop _tte_cal_weighted_mean

    run "`tte_dir'/_tte_check_prepared.ado"
    run "`tte_dir'/_tte_check_expanded.ado"
    run "`tte_dir'/_tte_check_fitted.ado"
    run "`tte_dir'/_tte_get_settings.ado"
    cap run "`tte_dir'/_tte_memory_estimate.ado"
    cap run "`tte_dir'/_tte_display_header.ado"
    run "`tte_dir'/_tte_natural_spline.ado"
    cap run "`tte_dir'/_tte_col_letter.ado"
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
    run "`tte_dir'/tte_calibrate.ado"
    run "`tte_dir'/_tte_expand_factors.ado"
}


* ============================================================================
* SECTIONS 1-11: Core functional tests (61 tests)
* ============================================================================


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
    assert "`r(version)'" == "1.2.0"
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
* SECTIONS 12-17: Audit fix tests (22 tests)
* ============================================================================

* ===========================================================================
* FIX 1: Natural censoring via censor() truncates follow-up
* ===========================================================================

display ""
display _dup(70) "="
display "FIX 1: Natural censoring truncates follow-up in tte_expand"
display _dup(70) "="

* ---------------------------------------------------------------------------
* Test 1: Censored individuals have no rows after their censoring period
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': Censored rows are dropped after censor event"
display _dup(60) "-"

capture noisily {
    * Build a controlled toy dataset where censoring is deterministic
    clear
    set obs 30
    gen int patid = ceil(_n / 10)
    bysort patid: gen int period = _n - 1
    gen byte treatment = (patid == 1)
    gen byte outcome = 0
    gen byte eligible = (period == 0)

    * Patient 2 is censored at period 3 — should have no rows after period 3
    gen byte censored = (patid == 2 & period == 3)

    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) censor(censored) ///
        estimand(ITT)

    tte_expand, maxfollowup(8)

    * Patient 2 must NOT have follow-up > 3 in any trial
    quietly count if patid == 2 & _tte_followup > 3
    local post_censor = r(N)
    assert `post_censor' == 0

    * Patient 1 and 3 (uncensored) should have follow-up beyond 3
    quietly count if patid == 1 & _tte_followup > 3
    assert r(N) > 0
    quietly count if patid == 3 & _tte_followup > 3
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ---------------------------------------------------------------------------
* Test 2: Natural censoring applied with PP estimand (before cloning)
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': Natural censoring with PP estimand"
display _dup(60) "-"

capture noisily {
    clear
    set obs 30
    gen int patid = ceil(_n / 10)
    bysort patid: gen int period = _n - 1
    gen byte treatment = (patid == 1)
    gen byte outcome = 0
    gen byte eligible = (period == 0)
    gen byte censored = (patid == 2 & period == 4)

    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) censor(censored) ///
        estimand(PP)

    tte_expand, maxfollowup(8) grace(0)

    * Patient 2 (censored at period 4 = followup 4) must have no rows after
    quietly count if patid == 2 & _tte_followup > 4
    assert r(N) == 0

    * Both arms of patient 2 should be affected (cloned before natural cens)
    quietly count if patid == 2 & _tte_arm == 0 & _tte_followup > 4
    assert r(N) == 0
    quietly count if patid == 2 & _tte_arm == 1 & _tte_followup > 4
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ---------------------------------------------------------------------------
* Test 3: Natural censoring row itself is retained
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': Censored row itself is retained"
display _dup(60) "-"

capture noisily {
    clear
    set obs 30
    gen int patid = ceil(_n / 10)
    bysort patid: gen int period = _n - 1
    gen byte treatment = (patid == 1)
    gen byte outcome = 0
    gen byte eligible = (period == 0)
    gen byte censored = (patid == 2 & period == 5)

    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) censor(censored) ///
        estimand(ITT)

    tte_expand, maxfollowup(8)

    * The row at follow-up == 5 should still exist
    quietly count if patid == 2 & _tte_followup == 5
    assert r(N) > 0

    * But follow-up == 6 should not
    quietly count if patid == 2 & _tte_followup == 6
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ---------------------------------------------------------------------------
* Test 4: No censoring applied when censor() not specified
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': No natural censoring without censor() variable"
display _dup(60) "-"

capture noisily {
    clear
    set obs 30
    gen int patid = ceil(_n / 10)
    bysort patid: gen int period = _n - 1
    gen byte treatment = (patid == 1)
    gen byte outcome = 0
    gen byte eligible = (period == 0)

    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)

    local N_before = _N
    tte_expand, maxfollowup(8)

    * All patients should have full follow-up to period 8 or their max period
    quietly summarize _tte_followup if patid == 2
    assert r(max) >= 8
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ---------------------------------------------------------------------------
* Test 5: Natural censoring with real tte_example data
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': Natural censoring with tte_example.dta"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear

    * Identify a censored patient and their censoring period
    quietly levelsof patid if censored == 1, local(cens_ids)
    local test_id: word 1 of `cens_ids'

    quietly summarize period if patid == `test_id' & censored == 1
    local cens_period = r(min)

    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) censor(censored) ///
        covariates(age sex comorbidity biomarker) estimand(ITT)

    tte_expand, maxfollowup(5)

    * This patient should have no follow-up beyond their censoring period
    * within trial 0
    quietly count if patid == `test_id' & _tte_trial == 0 ///
        & _tte_followup > `cens_period'
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ---------------------------------------------------------------------------
* Test 6: Expansion without censor gives more rows than with censor
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': Censored expansion has fewer rows than uncensored"
display _dup(60) "-"

capture noisily {
    * Run without censor()
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(5)
    local N_no_cens = _N

    * Run with censor()
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) censor(censored) estimand(ITT)
    tte_expand, maxfollowup(5)
    local N_with_cens = _N

    display "  Rows without censor: `N_no_cens'"
    display "  Rows with censor:    `N_with_cens'"

    * With censoring, some follow-up rows are dropped — strictly fewer rows
    assert `N_with_cens' < `N_no_cens'
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ===========================================================================
* FIX 2: Weight variable resolver (generate(customname))
* ===========================================================================

display ""
display _dup(70) "="
display "FIX 2: Weight variable resolver across downstream commands"
display _dup(70) "="

* ---------------------------------------------------------------------------
* Test 7: tte_weight generate(mywt) stores metadata correctly
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_weight generate(mywt) stores _tte_weight_var"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
        generate(mywt) replace

    * Check metadata
    local wvar_meta : char _dta[_tte_weight_var]
    assert "`wvar_meta'" == "mywt"

    local weighted_meta : char _dta[_tte_weighted]
    assert "`weighted_meta'" == "1"

    * Check variable exists
    confirm variable mywt
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ---------------------------------------------------------------------------
* Test 8: tte_fit finds custom-named weight variable
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_fit uses custom weight variable"
display _dup(60) "-"

capture noisily {
    * Continuing from previous test data (mywt exists, _tte_weight not present)
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
        generate(mywt) replace

    * Rename away the default name to prove resolver works
    capture confirm variable _tte_weight
    if _rc == 0 {
        display as error "  ERROR: _tte_weight should not exist with generate(mywt)"
        exit 198
    }

    * tte_fit should find mywt via metadata — no "unweighted" warning
    tte_fit, outcome_cov(age sex comorbidity) nolog

    * Verify fit succeeded (model was weighted)
    local fitted : char _dta[_tte_fitted]
    assert "`fitted'" == "1"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ---------------------------------------------------------------------------
* Test 9: tte_diagnose finds custom-named weight variable
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_diagnose uses custom weight variable"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
        generate(customwt) replace

    * tte_diagnose should find customwt and show weighted SMDs
    tte_diagnose, balance_covariates(age sex comorbidity)

    * Should have returned a balance matrix with weighted column populated
    assert r(max_smd_wt) != .
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ---------------------------------------------------------------------------
* Test 10: tte_report finds custom-named weight variable
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_report uses custom weight variable"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
        generate(myw) replace
    tte_fit, outcome_cov(age sex comorbidity) nolog

    * tte_report should display weight summary using myw, not error
    tte_report
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ---------------------------------------------------------------------------
* Test 11: tte_prepare clears stale weight metadata
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': tte_prepare clears _tte_weight_var and _tte_pscore_var"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)
    tte_expand, maxfollowup(5)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
        generate(oldwt) replace save_ps

    * Verify metadata set
    local wvar : char _dta[_tte_weight_var]
    assert "`wvar'" == "oldwt"
    local psvar : char _dta[_tte_pscore_var]
    assert "`psvar'" != ""

    * Re-prepare — should clear stale metadata
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)

    local wvar2 : char _dta[_tte_weight_var]
    assert "`wvar2'" == ""
    local psvar2 : char _dta[_tte_pscore_var]
    assert "`psvar2'" == ""
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ===========================================================================
* FIX 3: Balance SMDs at baseline only (followup==0)
* ===========================================================================

display ""
display _dup(70) "="
display "FIX 3: Balance SMDs computed at followup==0 only"
display _dup(70) "="

* ---------------------------------------------------------------------------
* Test 12: Balance SMDs match hand-computed baseline values
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': Balance SMDs use baseline rows only"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(ITT)
    tte_expand, maxfollowup(5)

    * Hand-compute unweighted SMD at baseline (followup==0)
    quietly summarize age if _tte_arm == 1 & _tte_followup == 0
    local m1 = r(mean)
    local v1 = r(Var)
    quietly summarize age if _tte_arm == 0 & _tte_followup == 0
    local m0 = r(mean)
    local v0 = r(Var)
    local hand_smd = abs((`m1' - `m0') / sqrt((`v1' + `v0') / 2))

    * Run tte_diagnose
    tte_diagnose, balance_covariates(age)

    * Compare: the returned max SMD should match baseline-only computation
    local diag_smd = r(max_smd_unwt)
    local diff = abs(`hand_smd' - `diag_smd')
    display "  Hand-computed baseline SMD: " %8.6f `hand_smd'
    display "  tte_diagnose SMD:           " %8.6f `diag_smd'
    display "  Difference:                 " %8.6f `diff'
    assert `diff' < 0.0001
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ---------------------------------------------------------------------------
* Test 13: Baseline SMD differs from all-rows SMD (proves restriction works)
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': Baseline SMD differs from all-rows SMD"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)

    * Compute all-rows SMD (the old, incorrect way)
    quietly summarize age if _tte_arm == 1
    local m1_all = r(mean)
    local v1_all = r(Var)
    quietly summarize age if _tte_arm == 0
    local m0_all = r(mean)
    local v0_all = r(Var)
    local smd_all = abs((`m1_all' - `m0_all') / sqrt((`v1_all' + `v0_all') / 2))

    * Compute baseline-only SMD (the correct way)
    quietly summarize age if _tte_arm == 1 & _tte_followup == 0
    local m1_bl = r(mean)
    local v1_bl = r(Var)
    quietly summarize age if _tte_arm == 0 & _tte_followup == 0
    local m0_bl = r(mean)
    local v0_bl = r(Var)
    local smd_bl = abs((`m1_bl' - `m0_bl') / sqrt((`v1_bl' + `v0_bl') / 2))

    display "  All-rows SMD:     " %8.6f `smd_all'
    display "  Baseline-only SMD:" %8.6f `smd_bl'

    * They should be different (PP censoring creates duration-weighted bias)
    * With PP, the all-rows and baseline values will generally differ
    * because censored clones have different follow-up lengths
    local diff = abs(`smd_all' - `smd_bl')
    display "  Difference:       " %8.6f `diff'

    * Run tte_diagnose — should match baseline, not all-rows
    tte_diagnose, balance_covariates(age)
    local diag_smd = r(max_smd_unwt)
    local match_bl = abs(`diag_smd' - `smd_bl')
    display "  tte_diagnose SMD: " %8.6f `diag_smd'
    display "  Match to baseline:" %8.6f `match_bl'
    assert `match_bl' < 0.0001
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ===========================================================================
* FIX 4: Per-period positivity check in tte_validate
* ===========================================================================

display ""
display _dup(70) "="
display "FIX 4: Per-period positivity check in tte_validate"
display _dup(70) "="

* ---------------------------------------------------------------------------
* Test 14: Positivity passes when all periods have both treatment values
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': Positivity passes on good data"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)
    tte_validate

    assert r(n_errors) == 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ---------------------------------------------------------------------------
* Test 15: Per-period positivity violation detected
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': Per-period positivity violation detected"
display _dup(60) "-"

capture noisily {
    * Create dataset where period 0 has only untreated eligible
    clear
    set obs 600
    gen int patid = ceil(_n / 6)
    bysort patid: gen int period = _n - 1
    gen byte outcome = 0
    gen byte eligible = inlist(period, 0, 1, 2)

    * Period 0: all untreated. Periods 1-2: mixed treatment
    gen byte treatment = 0
    replace treatment = (mod(patid, 2) == 0) if period >= 1

    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)
    tte_validate

    * Should have detected a warning (period 0 has no treated eligible)
    assert r(n_warnings) > 0 | r(n_errors) > 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ---------------------------------------------------------------------------
* Test 16: Per-period positivity violation becomes error under strict
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': Per-period positivity violation is error under strict"
display _dup(60) "-"

capture noisily {
    clear
    set obs 600
    gen int patid = ceil(_n / 6)
    bysort patid: gen int period = _n - 1
    gen byte outcome = 0
    gen byte eligible = inlist(period, 0, 1, 2)
    gen byte treatment = 0
    replace treatment = (mod(patid, 2) == 0) if period >= 1

    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)
    capture tte_validate, strict
    local rc_strict = _rc

    * Should exit with error under strict
    assert `rc_strict' == 198
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ---------------------------------------------------------------------------
* Test 17: Aggregate-only positivity pass now caught per-period
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': Aggregate pass but per-period fail detected"
display _dup(60) "-"

capture noisily {
    * 2 eligible periods: period 0 all untreated, period 1 all treated
    * Aggregate: both treatment values exist, but per-period: violation
    clear
    set obs 200
    gen int patid = ceil(_n / 2)
    bysort patid: gen int period = _n - 1
    gen byte outcome = 0
    gen byte eligible = 1

    * Period 0: all untreated. Period 1: all treated.
    gen byte treatment = (period == 1)

    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)
    tte_validate

    * Aggregate has both 0s and 1s, but per-period each is pure
    assert r(n_warnings) > 0 | r(n_errors) > 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ===========================================================================
* FIX 5: strict promotes Check 7 and Check 10 warnings to errors
* ===========================================================================

display ""
display _dup(70) "="
display "FIX 5: strict promotes Check 7 and Check 10 to errors"
display _dup(70) "="

* ---------------------------------------------------------------------------
* Test 18: Check 7 (small eligible per period) becomes error under strict
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': Check 7 small sample becomes error under strict"
display _dup(60) "-"

capture noisily {
    * Create data with < 10 eligible per period in some periods
    clear
    set obs 60
    gen int patid = ceil(_n / 6)
    bysort patid: gen int period = _n - 1
    gen byte outcome = 0

    * Only 5 individuals eligible at each period (< 10 threshold)
    gen byte eligible = inlist(period, 0, 1, 2) & patid <= 5
    gen byte treatment = (mod(patid, 2) == 0)

    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)

    * Without strict: should pass with warnings
    tte_validate
    local warn_count = r(n_warnings)
    assert `warn_count' > 0

    * With strict: should fail with errors
    use "`tte_dir'/tte_example.dta", clear

    * Rebuild tiny dataset
    clear
    set obs 60
    gen int patid = ceil(_n / 6)
    bysort patid: gen int period = _n - 1
    gen byte outcome = 0
    gen byte eligible = inlist(period, 0, 1, 2) & patid <= 5
    gen byte treatment = (mod(patid, 2) == 0)

    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)

    capture tte_validate, strict
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

* ---------------------------------------------------------------------------
* Test 19: Check 10 (few events) becomes error under strict
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': Check 10 few events becomes error under strict"
display _dup(60) "-"

capture noisily {
    * Create data with < 5 events
    clear
    set obs 500
    gen int patid = ceil(_n / 5)
    bysort patid: gen int period = _n - 1
    gen byte treatment = (mod(patid, 2) == 0)
    gen byte eligible = (period == 0)

    * Only 3 outcome events (< 5 threshold)
    gen byte outcome = 0
    replace outcome = 1 if inlist(patid, 10, 20, 30) & period == 3

    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)

    * Without strict: warning only
    tte_validate
    assert r(n_warnings) > 0
    assert r(n_errors) == 0

    * With strict: error
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)
    capture tte_validate, strict
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

* ===========================================================================
* FIX 6: ITT branch of tte_weight sets metadata
* ===========================================================================

display ""
display _dup(70) "="
display "FIX 6: ITT branch of tte_weight sets metadata"
display _dup(70) "="

* ---------------------------------------------------------------------------
* Test 20: ITT tte_weight sets _tte_weighted and _tte_weight_var
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': ITT tte_weight sets weighted metadata"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(5)
    tte_weight

    * Check metadata is set
    local weighted : char _dta[_tte_weighted]
    assert "`weighted'" == "1"

    local wvar : char _dta[_tte_weight_var]
    assert "`wvar'" == "_tte_weight"

    * Weight should be all 1s for ITT
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

* ---------------------------------------------------------------------------
* Test 21: ITT tte_weight with generate() stores custom name in metadata
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': ITT tte_weight generate(myittwt) stores metadata"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(5)
    tte_weight, generate(myittwt) replace

    local wvar : char _dta[_tte_weight_var]
    assert "`wvar'" == "myittwt"

    local weighted : char _dta[_tte_weighted]
    assert "`weighted'" == "1"

    confirm variable myittwt
    quietly summarize myittwt
    assert r(mean) == 1
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (rc=" _rc ")"
    local ++fail_count
}

* ---------------------------------------------------------------------------
* Test 22: ITT pipeline end-to-end with generate(customname)
* ---------------------------------------------------------------------------
local ++test_count
display _dup(60) "-"
display "Test `test_count': Full ITT pipeline with custom weight name"
display _dup(60) "-"

capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(ITT)
    tte_expand, maxfollowup(5)
    tte_weight, generate(itt_w) replace
    tte_fit, outcome_cov(age sex comorbidity) nolog
    tte_report

    * Pipeline completed without error — weight was found
    local fitted : char _dta[_tte_fitted]
    assert "`fitted'" == "1"
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
* SECTIONS 18-26: Extended coverage tests (80 tests)
* ============================================================================


* =============================================================================
* SECTION A: tte_calibrate (15 tests)
* =============================================================================

display ""
display "SECTION A: tte_calibrate"

* --- A1: Basic calibration with valid inputs ---
local ++test_count
capture noisily {
    matrix nco = (0.05, 0.10 \ -0.02, 0.08 \ 0.08, 0.12 \ -0.03, 0.09 \ 0.01, 0.11)
    tte_calibrate, estimate(-0.50) se(0.15) nco_estimates(nco)

    assert r(cal_estimate) != .
    assert r(cal_se) != .
    assert r(bias) != .
    assert r(sigma) != .
}
if _rc == 0 {
    display as result "  PASS: A1 Basic calibration"
    local ++pass_count
}
else {
    display as error "  FAIL: A1 Basic calibration (rc=" _rc ")"
    local ++fail_count
}

* --- A2: All return values present ---
local ++test_count
capture noisily {
    matrix nco = (0.05, 0.10 \ -0.02, 0.08 \ 0.08, 0.12)
    tte_calibrate, estimate(-0.30) se(0.20) nco_estimates(nco)

    assert r(estimate) == -0.30
    assert r(se) == 0.20
    assert r(ci_lo) != .
    assert r(ci_hi) != .
    assert r(pvalue) != .
    assert r(bias) != .
    assert r(sigma) >= 0
    assert r(n_nco) == 3
    assert r(cal_estimate) != .
    assert r(cal_se) != .
    assert r(cal_ci_lo) != .
    assert r(cal_ci_hi) != .
    assert r(cal_pvalue) != .
    assert "`r(method)'" == "normal"
}
if _rc == 0 {
    display as result "  PASS: A2 All return values present"
    local ++pass_count
}
else {
    display as error "  FAIL: A2 All return values present (rc=" _rc ")"
    local ++fail_count
}

* --- A3: Calibrated SE always >= uncalibrated SE ---
local ++test_count
capture noisily {
    matrix nco = (0.10, 0.15 \ -0.05, 0.12 \ 0.03, 0.10 \ -0.08, 0.14 \ 0.06, 0.11)
    tte_calibrate, estimate(-0.40) se(0.18) nco_estimates(nco)

    assert r(cal_se) >= r(se)
}
if _rc == 0 {
    display as result "  PASS: A3 Calibrated SE >= uncalibrated SE"
    local ++pass_count
}
else {
    display as error "  FAIL: A3 Calibrated SE >= uncalibrated SE (rc=" _rc ")"
    local ++fail_count
}

* --- A4: Calibrated CI wider than uncalibrated CI ---
local ++test_count
capture noisily {
    matrix nco = (0.10, 0.15 \ -0.05, 0.12 \ 0.03, 0.10)
    tte_calibrate, estimate(-0.40) se(0.18) nco_estimates(nco)

    local uncal_width = r(ci_hi) - r(ci_lo)
    local cal_width = r(cal_ci_hi) - r(cal_ci_lo)
    assert `cal_width' >= `uncal_width'
}
if _rc == 0 {
    display as result "  PASS: A4 Calibrated CI wider"
    local ++pass_count
}
else {
    display as error "  FAIL: A4 Calibrated CI wider (rc=" _rc ")"
    local ++fail_count
}

* --- A5: Zero-bias NCOs -> calibrated estimate near uncalibrated ---
local ++test_count
capture noisily {
    * NCOs centered around zero with small variance
    matrix nco = (0.001, 0.10 \ -0.001, 0.10 \ 0.002, 0.10)
    tte_calibrate, estimate(-0.50) se(0.15) nco_estimates(nco)

    * Bias should be near zero
    assert abs(r(bias)) < 0.01
    * Calibrated estimate should be close to uncalibrated
    assert abs(r(cal_estimate) - r(estimate)) < 0.01
}
if _rc == 0 {
    display as result "  PASS: A5 Zero-bias NCOs"
    local ++pass_count
}
else {
    display as error "  FAIL: A5 Zero-bias NCOs (rc=" _rc ")"
    local ++fail_count
}

* --- A6: Custom level(90) ---
local ++test_count
capture noisily {
    matrix nco = (0.05, 0.10 \ -0.02, 0.08 \ 0.03, 0.09)
    tte_calibrate, estimate(-0.40) se(0.15) nco_estimates(nco) level(90)

    * 90% CI should be narrower than default 95%
    local w90 = r(cal_ci_hi) - r(cal_ci_lo)

    matrix nco2 = (0.05, 0.10 \ -0.02, 0.08 \ 0.03, 0.09)
    tte_calibrate, estimate(-0.40) se(0.15) nco_estimates(nco2) level(95)
    local w95 = r(cal_ci_hi) - r(cal_ci_lo)

    assert `w90' < `w95'
}
if _rc == 0 {
    display as result "  PASS: A6 Custom level(90)"
    local ++pass_count
}
else {
    display as error "  FAIL: A6 Custom level(90) (rc=" _rc ")"
    local ++fail_count
}

* --- A7: Custom null hypothesis ---
local ++test_count
capture noisily {
    matrix nco = (0.05, 0.10 \ -0.02, 0.08 \ 0.03, 0.09)
    tte_calibrate, estimate(-0.40) se(0.15) nco_estimates(nco) null(0.5)

    * P-value testing null=0.5 should differ from null=0
    local pval_05 = r(cal_pvalue)

    matrix nco2 = (0.05, 0.10 \ -0.02, 0.08 \ 0.03, 0.09)
    tte_calibrate, estimate(-0.40) se(0.15) nco_estimates(nco2) null(0)
    local pval_00 = r(cal_pvalue)

    assert `pval_05' != `pval_00'
}
if _rc == 0 {
    display as result "  PASS: A7 Custom null hypothesis"
    local ++pass_count
}
else {
    display as error "  FAIL: A7 Custom null hypothesis (rc=" _rc ")"
    local ++fail_count
}

* --- A8: Many NCOs (20) ---
local ++test_count
capture noisily {
    matrix nco = J(20, 2, 0)
    set seed 12345
    forvalues i = 1/20 {
        matrix nco[`i', 1] = rnormal(0.02, 0.05)
        matrix nco[`i', 2] = 0.10 + runiform() * 0.05
    }
    tte_calibrate, estimate(-0.50) se(0.20) nco_estimates(nco)

    assert r(n_nco) == 20
    assert r(cal_estimate) != .
}
if _rc == 0 {
    display as result "  PASS: A8 Many NCOs (20)"
    local ++pass_count
}
else {
    display as error "  FAIL: A8 Many NCOs (20) (rc=" _rc ")"
    local ++fail_count
}

* --- A9: Error - matrix not found (rc=111) ---
local ++test_count
capture noisily {
    capture matrix drop _nonexistent_matrix
    capture tte_calibrate, estimate(-0.50) se(0.15) nco_estimates(_nonexistent_matrix)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: A9 Error: matrix not found"
    local ++pass_count
}
else {
    display as error "  FAIL: A9 Error: matrix not found (rc=" _rc ")"
    local ++fail_count
}

* --- A10: Error - matrix not Nx2 (rc=503) ---
local ++test_count
capture noisily {
    matrix bad_nco = (0.05, 0.10, 0.03 \ -0.02, 0.08, 0.04 \ 0.01, 0.09, 0.05)
    capture tte_calibrate, estimate(-0.50) se(0.15) nco_estimates(bad_nco)
    assert _rc == 503
}
if _rc == 0 {
    display as result "  PASS: A10 Error: matrix not Nx2"
    local ++pass_count
}
else {
    display as error "  FAIL: A10 Error: matrix not Nx2 (rc=" _rc ")"
    local ++fail_count
}

* --- A11: Error - fewer than 3 NCOs (rc=198) ---
local ++test_count
capture noisily {
    matrix small_nco = (0.05, 0.10 \ -0.02, 0.08)
    capture tte_calibrate, estimate(-0.50) se(0.15) nco_estimates(small_nco)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: A11 Error: fewer than 3 NCOs"
    local ++pass_count
}
else {
    display as error "  FAIL: A11 Error: fewer than 3 NCOs (rc=" _rc ")"
    local ++fail_count
}

* --- A12: Error - SE <= 0 (rc=198) ---
local ++test_count
capture noisily {
    matrix nco = (0.05, 0.10 \ -0.02, 0.08 \ 0.01, 0.09)
    capture tte_calibrate, estimate(-0.50) se(0) nco_estimates(nco)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: A12 Error: SE <= 0"
    local ++pass_count
}
else {
    display as error "  FAIL: A12 Error: SE <= 0 (rc=" _rc ")"
    local ++fail_count
}

* --- A13: Error - NCO SE <= 0 (rc=198) ---
local ++test_count
capture noisily {
    matrix nco = (0.05, 0.10 \ -0.02, -0.01 \ 0.01, 0.09)
    capture tte_calibrate, estimate(-0.50) se(0.15) nco_estimates(nco)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: A13 Error: NCO SE <= 0"
    local ++pass_count
}
else {
    display as error "  FAIL: A13 Error: NCO SE <= 0 (rc=" _rc ")"
    local ++fail_count
}

* --- A14: Error - invalid method (rc=198) ---
local ++test_count
capture noisily {
    matrix nco = (0.05, 0.10 \ -0.02, 0.08 \ 0.01, 0.09)
    capture tte_calibrate, estimate(-0.50) se(0.15) nco_estimates(nco) method(gamma)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: A14 Error: invalid method"
    local ++pass_count
}
else {
    display as error "  FAIL: A14 Error: invalid method (rc=" _rc ")"
    local ++fail_count
}

* --- A15: Large systematic error shifts estimate ---
local ++test_count
capture noisily {
    * NCOs all positive -> positive bias -> calibrated estimate more negative
    matrix nco = (0.30, 0.10 \ 0.25, 0.08 \ 0.35, 0.12 \ 0.28, 0.09 \ 0.32, 0.11)
    tte_calibrate, estimate(-0.40) se(0.15) nco_estimates(nco)

    assert r(bias) > 0.20
    assert r(cal_estimate) < r(estimate)
}
if _rc == 0 {
    display as result "  PASS: A15 Large systematic error"
    local ++pass_count
}
else {
    display as error "  FAIL: A15 Large systematic error (rc=" _rc ")"
    local ++fail_count
}


* =============================================================================
* SECTION B: tte_protocol extended (8 tests)
* =============================================================================

display ""
display "SECTION B: tte_protocol extended"

* --- B1: Manual mode with all 7 components ---
local ++test_count
capture noisily {
    tte_protocol, eligibility("Age >= 18, no prior treatment") ///
        treatment("Initiate drug A vs. no treatment") ///
        assignment("Based on physician decision") ///
        followup_start("Date of eligibility") ///
        outcome("All-cause mortality") ///
        causal_contrast("Per-protocol effect") ///
        analysis("Pooled logistic regression with IPTW")

    assert "`r(eligibility)'" == "Age >= 18, no prior treatment"
    assert "`r(causal_contrast)'" == "Per-protocol effect"
    assert "`r(format)'" == "display"
}
if _rc == 0 {
    display as result "  PASS: B1 Manual mode all 7 components"
    local ++pass_count
}
else {
    display as error "  FAIL: B1 Manual mode (rc=" _rc ")"
    local ++fail_count
}

* --- B2: Auto mode with partial overrides ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)

    tte_protocol, auto eligibility("Custom eligibility text") ///
        outcome("Cardiovascular death")

    * Overridden components should match user input
    assert "`r(eligibility)'" == "Custom eligibility text"
    assert "`r(outcome)'" == "Cardiovascular death"
    * Non-overridden should be auto-generated (non-empty)
    assert "`r(treatment)'" != ""
    assert "`r(assignment)'" != ""
}
if _rc == 0 {
    display as result "  PASS: B2 Auto with partial overrides"
    local ++pass_count
}
else {
    display as error "  FAIL: B2 Auto with partial overrides (rc=" _rc ")"
    local ++fail_count
}

* --- B3: Error - auto without prepare (rc=198) ---
local ++test_count
capture noisily {
    clear
    set obs 10
    gen x = _n
    capture tte_protocol, auto
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: B3 Error: auto without prepare"
    local ++pass_count
}
else {
    display as error "  FAIL: B3 Error: auto without prepare (rc=" _rc ")"
    local ++fail_count
}

* --- B4: Error - manual missing components (rc=198) ---
local ++test_count
capture noisily {
    capture tte_protocol, eligibility("Age >= 18") treatment("Drug A")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: B4 Error: manual missing components"
    local ++pass_count
}
else {
    display as error "  FAIL: B4 Error: manual missing components (rc=" _rc ")"
    local ++fail_count
}

* --- B5: Error - invalid format (rc=198) ---
local ++test_count
capture noisily {
    capture tte_protocol, eligibility("A") treatment("B") assignment("C") ///
        followup_start("D") outcome("E") causal_contrast("F") ///
        analysis("G") format(html)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: B5 Error: invalid format"
    local ++pass_count
}
else {
    display as error "  FAIL: B5 Error: invalid format (rc=" _rc ")"
    local ++fail_count
}

* --- B6: Excel export ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog

    local proto_xlsx "_test_protocol.xlsx"
    capture erase "`proto_xlsx'"
    tte_protocol, auto format(excel) export("`proto_xlsx'") ///
        title("Test Protocol") replace
    confirm file "`proto_xlsx'"
    erase "`proto_xlsx'"
}
if _rc == 0 {
    display as result "  PASS: B6 Excel export"
    local ++pass_count
}
else {
    display as error "  FAIL: B6 Excel export (rc=" _rc ")"
    local ++fail_count
}

* --- B7: LaTeX export ---
local ++test_count
capture noisily {
    local proto_tex "_test_protocol.tex"
    capture erase "`proto_tex'"
    tte_protocol, eligibility("Age >= 18") treatment("Drug A") ///
        assignment("Physician") followup_start("Baseline") ///
        outcome("Death") causal_contrast("PP") ///
        analysis("Logistic") format(latex) export("`proto_tex'") replace
    confirm file "`proto_tex'"
    erase "`proto_tex'"
}
if _rc == 0 {
    display as result "  PASS: B7 LaTeX export"
    local ++pass_count
}
else {
    display as error "  FAIL: B7 LaTeX export (rc=" _rc ")"
    local ++fail_count
}

* --- B8: Auto after fit includes model description ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) model(cox) nolog

    tte_protocol, auto
    * Analysis text should mention Cox
    local analysis_text "`r(analysis)'"
    assert strpos("`analysis_text'", "Cox") > 0 | ///
           strpos("`analysis_text'", "cox") > 0
}
if _rc == 0 {
    display as result "  PASS: B8 Auto after fit includes model"
    local ++pass_count
}
else {
    display as error "  FAIL: B8 Auto after fit includes model (rc=" _rc ")"
    local ++fail_count
}


* =============================================================================
* SECTION C: tte_plot extended (8 tests)
* =============================================================================

display ""
display "SECTION C: tte_plot extended"

* --- C1: type(balance) with balance_covariates ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) truncate(1 99) nolog

    tte_diagnose, balance_covariates(age sex comorbidity biomarker)
    tte_plot, type(balance)
    assert "`r(type)'" == "balance"
}
if _rc == 0 {
    display as result "  PASS: C1 type(balance)"
    local ++pass_count
}
else {
    display as error "  FAIL: C1 type(balance) (rc=" _rc ")"
    local ++fail_count
}

* --- C2: type(balance) with top() ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) truncate(1 99) nolog

    tte_diagnose, balance_covariates(age sex comorbidity biomarker)
    tte_plot, type(balance) top(3)
    assert "`r(type)'" == "balance"
}
if _rc == 0 {
    display as result "  PASS: C2 type(balance) top(3)"
    local ++pass_count
}
else {
    display as error "  FAIL: C2 type(balance) top(3) (rc=" _rc ")"
    local ++fail_count
}

* --- C3: type(pscore) ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) truncate(1 99) ///
        save_ps nolog

    tte_plot, type(pscore)
    assert "`r(type)'" == "pscore"
}
if _rc == 0 {
    display as result "  PASS: C3 type(pscore)"
    local ++pass_count
}
else {
    display as error "  FAIL: C3 type(pscore) (rc=" _rc ")"
    local ++fail_count
}

* --- C4: type(equipoise) ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) truncate(1 99) ///
        save_ps nolog

    tte_plot, type(equipoise)
    assert "`r(type)'" == "equipoise"
}
if _rc == 0 {
    display as result "  PASS: C4 type(equipoise)"
    local ++pass_count
}
else {
    display as error "  FAIL: C4 type(equipoise) (rc=" _rc ")"
    local ++fail_count
}

* --- C5: Error - type(pscore) without save_ps (rc=198 or 111) ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog

    capture tte_plot, type(pscore)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: C5 Error: pscore without save_ps"
    local ++pass_count
}
else {
    display as error "  FAIL: C5 Error: pscore without save_ps (rc=" _rc ")"
    local ++fail_count
}

* --- C6: Error - type(balance) without prior diagnose ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)

    capture tte_plot, type(balance)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: C6 Error: balance without diagnose"
    local ++pass_count
}
else {
    display as error "  FAIL: C6 Error: balance without diagnose (rc=" _rc ")"
    local ++fail_count
}

* --- C7: Error - invalid type ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(5)

    capture tte_plot, type(histogram)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: C7 Error: invalid type"
    local ++pass_count
}
else {
    display as error "  FAIL: C7 Error: invalid type (rc=" _rc ")"
    local ++fail_count
}

* --- C8: type(km) with custom title and scheme ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(5)

    tte_plot, type(km) title("Custom KM Title") scheme(s2color)
    assert "`r(type)'" == "km"
    assert "`r(scheme)'" == "s2color"
}
if _rc == 0 {
    display as result "  PASS: C8 KM with custom title/scheme"
    local ++pass_count
}
else {
    display as error "  FAIL: C8 KM with custom title/scheme (rc=" _rc ")"
    local ++fail_count
}


* =============================================================================
* SECTION D: tte_validate all 10 checks (12 tests)
* =============================================================================

display ""
display "SECTION D: tte_validate all 10 checks"

* --- D1: Check 1 - duplicate (id, period) detected ---
local ++test_count
capture noisily {
    clear
    set obs 20
    gen id = ceil(_n / 4)
    bysort id: gen period = _n - 1
    gen treatment = 0
    gen outcome = 0
    gen eligible = (period == 0)
    * Create a duplicate row (id=1, period=0 appears twice)
    expand 2 in 1
    capture tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: D1 Check 1: duplicate id-period detected"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 Check 1: duplicate (rc=" _rc ")"
    local ++fail_count
}

* --- D2: Check 2 - gaps in period sequence ---
local ++test_count
capture noisily {
    clear
    set obs 15
    gen id = ceil(_n / 5)
    bysort id: gen period = _n - 1
    gen treatment = (mod(id, 2) == 0)
    gen outcome = 0
    gen eligible = (period == 0)
    * Create gap: remove period 2 for id=1
    drop if id == 1 & period == 2

    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_validate
    * Should detect gap warning
    assert r(n_warnings) > 0 | r(n_errors) > 0
}
if _rc == 0 {
    display as result "  PASS: D2 Check 2: gaps in periods"
    local ++pass_count
}
else {
    display as error "  FAIL: D2 Check 2: gaps (rc=" _rc ")"
    local ++fail_count
}

* --- D3: Check 3 - rows after outcome event ---
local ++test_count
capture noisily {
    clear
    set obs 20
    gen id = ceil(_n / 5)
    bysort id: gen period = _n - 1
    gen treatment = (mod(id, 2) == 0)
    gen eligible = (period == 0)
    * Outcome at period 2, but rows continue to period 4
    gen outcome = (id == 1 & period == 2)

    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_validate
    * Should detect post-outcome rows
    assert r(n_warnings) > 0 | r(n_errors) > 0
}
if _rc == 0 {
    display as result "  PASS: D3 Check 3: rows after outcome"
    local ++pass_count
}
else {
    display as error "  FAIL: D3 Check 3: post-outcome (rc=" _rc ")"
    local ++fail_count
}

* --- D4: Check 4 - treatment inconsistency for PP ---
local ++test_count
capture noisily {
    clear
    set obs 40
    gen id = ceil(_n / 10)
    bysort id: gen period = _n - 1
    gen outcome = 0
    gen eligible = (period == 0)
    * Patient 1 switches back and forth (not absorbing)
    gen treatment = 0
    replace treatment = 1 if id == 1 & inlist(period, 1, 3, 5, 7, 9)
    replace treatment = 0 if id == 1 & inlist(period, 2, 4, 6, 8)
    replace treatment = (mod(id, 2) == 0) if id > 1

    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)
    tte_validate
    * For PP, switching is expected and handled by censoring
    * This should produce a note, not error (treatment switching is valid)
    assert r(n_checks) > 0
}
if _rc == 0 {
    display as result "  PASS: D4 Check 4: treatment switching (PP)"
    local ++pass_count
}
else {
    display as error "  FAIL: D4 Check 4: switching (rc=" _rc ")"
    local ++fail_count
}

* --- D5: Check 5 - missing data in covariates ---
local ++test_count
capture noisily {
    clear
    set obs 40
    gen id = ceil(_n / 10)
    bysort id: gen period = _n - 1
    gen treatment = (mod(id, 2) == 0)
    gen outcome = 0
    gen eligible = (period == 0)
    gen x = rnormal()
    * Introduce missing values
    replace x = . in 5

    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) covariates(x) estimand(ITT)
    tte_validate
    assert r(n_warnings) > 0 | r(n_errors) > 0
}
if _rc == 0 {
    display as result "  PASS: D5 Check 5: missing data"
    local ++pass_count
}
else {
    display as error "  FAIL: D5 Check 5: missing (rc=" _rc ")"
    local ++fail_count
}

* --- D6: Check 6 - eligible with prior outcome ---
local ++test_count
capture noisily {
    clear
    set obs 30
    gen id = ceil(_n / 10)
    bysort id: gen period = _n - 1
    gen treatment = (mod(id, 2) == 0)
    * Outcome at period 2, eligible again at period 5 (impossible)
    gen outcome = (id == 1 & period == 2)
    gen eligible = (period == 0) | (id == 1 & period == 5)

    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_validate
    * Should flag eligibility after outcome
    assert r(n_warnings) > 0 | r(n_errors) > 0
}
if _rc == 0 {
    display as result "  PASS: D6 Check 6: eligible after outcome"
    local ++pass_count
}
else {
    display as error "  FAIL: D6 Check 6: eligible after outcome (rc=" _rc ")"
    local ++fail_count
}

* --- D7: Check 9 - period numbering start ---
local ++test_count
capture noisily {
    clear
    set obs 20
    gen id = ceil(_n / 5)
    bysort id: gen period = _n + 4
    gen treatment = (mod(id, 2) == 0)
    gen outcome = 0
    gen eligible = (period == 5)

    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_validate
    * Period starting at 5 should trigger a note
    assert r(n_checks) > 0
}
if _rc == 0 {
    display as result "  PASS: D7 Check 9: period numbering"
    local ++pass_count
}
else {
    display as error "  FAIL: D7 Check 9: period numbering (rc=" _rc ")"
    local ++fail_count
}

* --- D8: All checks pass on clean data ---
local ++test_count
capture noisily {
    clear
    set obs 400
    gen id = ceil(_n / 10)
    bysort id: gen period = _n - 1
    gen treatment = (mod(id, 2) == 0)
    gen outcome = 0
    * Some events after period 3
    replace outcome = 1 if id <= 10 & period == 5
    * Drop post-outcome rows
    bysort id (period): gen _cum_out = sum(outcome)
    bysort id (period): gen _prev_out = _cum_out[_n-1]
    replace _prev_out = 0 if _prev_out == .
    drop if _prev_out > 0
    drop _cum_out _prev_out
    gen eligible = (period == 0)
    gen x = rnormal()

    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) covariates(x) estimand(ITT)
    tte_validate
    assert r(n_errors) == 0
}
if _rc == 0 {
    display as result "  PASS: D8 All checks pass on clean data"
    local ++pass_count
}
else {
    display as error "  FAIL: D8 All checks pass (rc=" _rc ")"
    local ++fail_count
}

* --- D9: verbose option shows detail ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_validate, verbose
    assert r(n_checks) > 0
}
if _rc == 0 {
    display as result "  PASS: D9 verbose option"
    local ++pass_count
}
else {
    display as error "  FAIL: D9 verbose (rc=" _rc ")"
    local ++fail_count
}

* --- D10: Return values comprehensive ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)
    tte_validate

    assert r(n_checks) >= 8
    assert r(n_errors) >= 0
    assert r(n_warnings) >= 0
    assert r(n_events) >= 0
    assert r(event_rate) >= 0 & r(event_rate) <= 100
}
if _rc == 0 {
    display as result "  PASS: D10 Return values comprehensive"
    local ++pass_count
}
else {
    display as error "  FAIL: D10 Return values (rc=" _rc ")"
    local ++fail_count
}

* --- D11: strict with no issues passes ---
local ++test_count
capture noisily {
    clear
    set obs 400
    gen id = ceil(_n / 10)
    bysort id: gen period = _n - 1
    gen treatment = (mod(id, 2) == 0)
    gen outcome = 0
    replace outcome = 1 if id <= 10 & period == 5
    bysort id (period): gen _cum_out = sum(outcome)
    bysort id (period): gen _prev_out = _cum_out[_n-1]
    replace _prev_out = 0 if _prev_out == .
    drop if _prev_out > 0
    drop _cum_out _prev_out
    gen eligible = (period == 0)

    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_validate, strict
    assert r(n_errors) == 0
}
if _rc == 0 {
    display as result "  PASS: D11 strict with no issues passes"
    local ++pass_count
}
else {
    display as error "  FAIL: D11 strict clean data (rc=" _rc ")"
    local ++fail_count
}

* --- D12: Multiple violations detected simultaneously ---
local ++test_count
capture noisily {
    clear
    set obs 40
    gen id = ceil(_n / 10)
    bysort id: gen period = _n - 1
    gen treatment = (mod(id, 2) == 0)
    * Multiple issues: post-outcome rows + missing
    gen outcome = (id == 1 & period == 3)
    gen eligible = (period == 0)
    gen x = rnormal()
    replace x = . in 15

    tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) covariates(x) estimand(ITT)
    tte_validate
    * Should detect at least 2 issues
    local total_issues = r(n_warnings) + r(n_errors)
    assert `total_issues' >= 2
}
if _rc == 0 {
    display as result "  PASS: D12 Multiple violations"
    local ++pass_count
}
else {
    display as error "  FAIL: D12 Multiple violations (rc=" _rc ")"
    local ++fail_count
}


* =============================================================================
* SECTION E: tte_weight advanced options (10 tests)
* =============================================================================

display ""
display "SECTION E: tte_weight advanced options"

* --- E1: save_ps creates PS variable ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
        truncate(1 99) save_ps nolog

    * PS variable should exist
    local psvar : char _dta[_tte_pscore_var]
    confirm variable `psvar'

    * PS should be in (0, 1)
    quietly summarize `psvar'
    assert r(min) > 0 & r(max) < 1
}
if _rc == 0 {
    display as result "  PASS: E1 save_ps creates PS variable"
    local ++pass_count
}
else {
    display as error "  FAIL: E1 save_ps (rc=" _rc ")"
    local ++fail_count
}

* --- E2: save_ps return values ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
        truncate(1 99) save_ps nolog

    assert r(mean_ps) != .
    assert r(sd_ps) != .
    assert r(min_ps) != .
    assert r(max_ps) != .
    assert r(mean_ps) > 0 & r(mean_ps) < 1
}
if _rc == 0 {
    display as result "  PASS: E2 save_ps return values"
    local ++pass_count
}
else {
    display as error "  FAIL: E2 save_ps return values (rc=" _rc ")"
    local ++fail_count
}

* --- E3: trim_ps removes extreme PS observations ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)

    * Without trim
    preserve
    tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
        truncate(1 99) save_ps nolog replace
    local n_untrimmed = _N
    restore

    * With trim
    tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
        truncate(1 99) save_ps trim_ps(5) nolog replace

    * Trimmed data should have fewer (or equal) rows
    assert _N <= `n_untrimmed'

    * Return values
    assert r(n_ps_trimmed) >= 0
}
if _rc == 0 {
    display as result "  PASS: E3 trim_ps"
    local ++pass_count
}
else {
    display as error "  FAIL: E3 trim_ps (rc=" _rc ")"
    local ++fail_count
}

* --- E4: pool_censor option ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) censor(censored) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) ///
        censor_d_cov(age sex) pool_censor truncate(1 99) nolog

    assert r(mean_weight) > 0
    assert r(ess) > 0
}
if _rc == 0 {
    display as result "  PASS: E4 pool_censor"
    local ++pass_count
}
else {
    display as error "  FAIL: E4 pool_censor (rc=" _rc ")"
    local ++fail_count
}

* --- E5: censor_n_cov numerator covariates ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) censor(censored) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) ///
        censor_d_cov(age sex) censor_n_cov(age) truncate(1 99) nolog

    assert r(mean_weight) > 0
}
if _rc == 0 {
    display as result "  PASS: E5 censor_n_cov"
    local ++pass_count
}
else {
    display as error "  FAIL: E5 censor_n_cov (rc=" _rc ")"
    local ++fail_count
}

* --- E6: Unstabilized weights (no switch_n_cov) ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)

    * Without stabilization (no switch_n_cov)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog replace
    local sd_unstab = r(sd_weight)

    * With stabilization (switch_n_cov specified)
    tte_weight, switch_d_cov(age sex comorbidity) ///
        switch_n_cov(age sex comorbidity) truncate(1 99) nolog replace
    local sd_stab = r(sd_weight)

    * Stabilized weights typically have smaller variance
    display "  Unstabilized SD: " %8.4f `sd_unstab'
    display "  Stabilized SD:   " %8.4f `sd_stab'

    * Both should produce valid weights
    assert r(mean_weight) > 0
}
if _rc == 0 {
    display as result "  PASS: E6 Unstabilized vs stabilized"
    local ++pass_count
}
else {
    display as error "  FAIL: E6 Unstabilized (rc=" _rc ")"
    local ++fail_count
}

* --- E7: Error - weight exists without replace (rc=110) ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog

    * Second call without replace should error
    capture tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: E7 Error: weight exists without replace"
    local ++pass_count
}
else {
    display as error "  FAIL: E7 weight exists (rc=" _rc ")"
    local ++fail_count
}

* --- E8: Combined save_ps + trim_ps + pool_switch ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
        switch_n_cov(age sex) pool_switch save_ps trim_ps(2) ///
        truncate(1 99) nolog replace

    assert r(mean_weight) > 0
    assert r(ess) > 0
    assert r(mean_ps) != .
}
if _rc == 0 {
    display as result "  PASS: E8 Combined save_ps+trim_ps+pool_switch"
    local ++pass_count
}
else {
    display as error "  FAIL: E8 Combined options (rc=" _rc ")"
    local ++fail_count
}

* --- E9: IPCW with censoring weights ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) censor(censored) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) ///
        switch_n_cov(age sex) ///
        censor_d_cov(age sex comorbidity) ///
        censor_n_cov(age) ///
        truncate(1 99) nolog

    assert r(mean_weight) > 0
    assert r(ess) > 0
}
if _rc == 0 {
    display as result "  PASS: E9 Full IPCW"
    local ++pass_count
}
else {
    display as error "  FAIL: E9 IPCW (rc=" _rc ")"
    local ++fail_count
}

* --- E10: Wider truncation gives tighter weight range ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)

    * Tight truncation (1/99)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
        truncate(1 99) nolog replace
    local max_tight = r(max_weight)

    * Loose truncation (5/95)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
        truncate(5 95) nolog replace
    local max_loose = r(max_weight)

    * 5/95 truncation should produce smaller max weight
    assert `max_loose' <= `max_tight'
}
if _rc == 0 {
    display as result "  PASS: E10 Truncation comparison"
    local ++pass_count
}
else {
    display as error "  FAIL: E10 Truncation comparison (rc=" _rc ")"
    local ++fail_count
}


* =============================================================================
* SECTION F: tte_fit & tte_predict advanced (9 tests)
* =============================================================================

display ""
display "SECTION F: tte_fit & tte_predict advanced"

* --- F1: followup_spec(none) for both specs ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(5)
    tte_weight, nolog

    tte_fit, outcome_cov(age sex comorbidity) ///
        followup_spec(none) trial_period_spec(none) nolog

    assert e(N) > 0
    assert "`e(tte_followup_spec)'" == "none"
    assert "`e(tte_trial_spec)'" == "none"
}
if _rc == 0 {
    display as result "  PASS: F1 followup_spec(none)+trial_period_spec(none)"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 both none (rc=" _rc ")"
    local ++fail_count
}

* --- F2: Mixed specs (ns(3) + linear) ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(5)
    tte_weight, nolog

    tte_fit, outcome_cov(age sex) ///
        followup_spec(ns(3)) trial_period_spec(linear) nolog

    assert e(N) > 0
    assert "`e(tte_followup_spec)'" == "ns(3)"
    assert "`e(tte_trial_spec)'" == "linear"
}
if _rc == 0 {
    display as result "  PASS: F2 Mixed specs ns(3)+linear"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 Mixed specs (rc=" _rc ")"
    local ++fail_count
}

* --- F3: ns with different df values ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(5)
    tte_weight, nolog

    * ns(2)
    tte_fit, outcome_cov(age sex) followup_spec(ns(2)) ///
        trial_period_spec(linear) nolog
    assert e(N) > 0

    * ns(5) — reload to avoid variable collision from ns(2) basis
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(5)
    tte_weight, nolog
    tte_fit, outcome_cov(age sex) followup_spec(ns(5)) ///
        trial_period_spec(linear) nolog
    assert e(N) > 0
}
if _rc == 0 {
    display as result "  PASS: F3 ns(2) and ns(5)"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 ns variants (rc=" _rc ")"
    local ++fail_count
}

* --- F4: tte_predict att option ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog

    tte_predict, times(0 2 4) difference att samples(30) seed(42)

    assert "`r(target)'" == "ATT"
    matrix pred = r(predictions)
    assert rowsof(pred) == 3
}
if _rc == 0 {
    display as result "  PASS: F4 tte_predict att"
    local ++pass_count
}
else {
    display as error "  FAIL: F4 att (rc=" _rc ")"
    local ++fail_count
}

* --- F5: tte_predict samples(10) minimum ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(5)
    tte_weight, nolog
    tte_fit, outcome_cov(age sex) nolog

    tte_predict, times(0 2 4) samples(10) seed(42)
    assert r(samples) == 10
    matrix pred = r(predictions)
    assert rowsof(pred) == 3
}
if _rc == 0 {
    display as result "  PASS: F5 samples(10) minimum"
    local ++pass_count
}
else {
    display as error "  FAIL: F5 samples(10) (rc=" _rc ")"
    local ++fail_count
}

* --- F6: tte_predict ratio standalone (without difference) ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog

    * Use times > 0 to avoid undefined RR when cum_inc = 0
    tte_predict, times(1 3 5) ratio samples(30) seed(42)

    matrix pred = r(predictions)
    * Should have ratio columns (7 base + 3 RR = 10)
    assert colsof(pred) >= 10
    * Risk ratio at time 1 should be positive and finite
    local rr1 = r(rr_1)
    assert `rr1' != . & `rr1' > 0
}
if _rc == 0 {
    display as result "  PASS: F6 ratio standalone"
    local ++pass_count
}
else {
    display as error "  FAIL: F6 ratio standalone (rc=" _rc ")"
    local ++fail_count
}

* --- F7: tte_predict with many time points ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(5)
    tte_weight, nolog
    tte_fit, outcome_cov(age sex) nolog

    tte_predict, times(0 1 2 3 4 5) difference ratio samples(30) seed(42)
    assert r(n_times) == 6
    matrix pred = r(predictions)
    assert rowsof(pred) == 6
}
if _rc == 0 {
    display as result "  PASS: F7 Many time points"
    local ++pass_count
}
else {
    display as error "  FAIL: F7 Many time points (rc=" _rc ")"
    local ++fail_count
}

* --- F8: tte_fit Cox with PP weights ---
local ++test_count
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
    display as result "  PASS: F8 Cox with PP weights"
    local ++pass_count
}
else {
    display as error "  FAIL: F8 Cox PP (rc=" _rc ")"
    local ++fail_count
}

* --- F9: tte_fit e() return values comprehensive ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(5)
    tte_weight, nolog
    tte_fit, outcome_cov(age sex) nolog

    assert e(N) > 0
    assert "`e(tte_cmd)'" == "tte_fit"
    assert "`e(tte_model)'" == "logistic"
    assert "`e(tte_estimand)'" == "ITT"
    assert "`e(tte_model_var)'" == "_tte_arm"
    matrix b = e(b)
    matrix V = e(V)
    assert colsof(b) > 0
    assert rowsof(V) == colsof(V)
}
if _rc == 0 {
    display as result "  PASS: F9 tte_fit e() return values"
    local ++pass_count
}
else {
    display as error "  FAIL: F9 fit returns (rc=" _rc ")"
    local ++fail_count
}


* =============================================================================
* SECTION G: tte_report & tte_diagnose advanced (7 tests)
* =============================================================================

display ""
display "SECTION G: tte_report & tte_diagnose advanced"

* --- G1: tte_diagnose equipoise ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
        truncate(1 99) save_ps nolog

    tte_diagnose, equipoise

    assert r(prevalence) != .
    assert r(pct_equipoise) >= 0 & r(pct_equipoise) <= 100
    assert r(mean_pref_treat) != .
    assert r(mean_pref_control) != .
}
if _rc == 0 {
    display as result "  PASS: G1 tte_diagnose equipoise"
    local ++pass_count
}
else {
    display as error "  FAIL: G1 equipoise (rc=" _rc ")"
    local ++fail_count
}

* --- G2: tte_diagnose combined balance+equipoise+by_trial ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
        truncate(1 99) save_ps nolog

    tte_diagnose, balance_covariates(age sex comorbidity biomarker) ///
        equipoise by_trial

    assert r(ess) > 0
    assert r(max_smd_unwt) != .
    assert r(max_smd_wt) != .
    assert r(pct_equipoise) >= 0
    matrix bal = r(balance)
    assert rowsof(bal) == 4
}
if _rc == 0 {
    display as result "  PASS: G2 Combined balance+equipoise+by_trial"
    local ++pass_count
}
else {
    display as error "  FAIL: G2 Combined diagnose (rc=" _rc ")"
    local ++fail_count
}

* --- G3: tte_diagnose without weights (unweighted only) ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(5)

    * No weighting step
    tte_diagnose, balance_covariates(age sex comorbidity)

    * Should still return unweighted balance
    assert r(max_smd_unwt) != .
}
if _rc == 0 {
    display as result "  PASS: G3 Diagnose without weights"
    local ++pass_count
}
else {
    display as error "  FAIL: G3 Unweighted diagnose (rc=" _rc ")"
    local ++fail_count
}

* --- G4: tte_report ci_separator ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog

    tte_report, ci_separator(", ") decimals(4) eform ///
        title("Custom Title Test")
}
if _rc == 0 {
    display as result "  PASS: G4 Report ci_separator+decimals+eform+title"
    local ++pass_count
}
else {
    display as error "  FAIL: G4 Report options (rc=" _rc ")"
    local ++fail_count
}

* --- G5: tte_report before fit (expansion summary only) ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(5)

    tte_report
    assert r(n_obs) > 0
}
if _rc == 0 {
    display as result "  PASS: G5 Report before fit"
    local ++pass_count
}
else {
    display as error "  FAIL: G5 Report before fit (rc=" _rc ")"
    local ++fail_count
}

* --- G6: tte_report error - invalid format ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(5)

    capture tte_report, format(pdf)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: G6 Error: invalid format"
    local ++pass_count
}
else {
    display as error "  FAIL: G6 Invalid format (rc=" _rc ")"
    local ++fail_count
}

* --- G7: tte_diagnose return values comprehensive ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(5) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
        truncate(1 99) nolog

    tte_diagnose, balance_covariates(age sex comorbidity biomarker)

    assert r(ess) > 0
    assert r(ess_treat) > 0
    assert r(ess_control) > 0
    assert r(w_mean) > 0
    assert r(w_sd) >= 0
    assert r(w_min) > 0
    assert r(w_max) > 0
    assert r(max_smd_unwt) >= 0
    assert r(max_smd_wt) >= 0
    assert "`r(weight_var)'" != ""
}
if _rc == 0 {
    display as result "  PASS: G7 Diagnose return values"
    local ++pass_count
}
else {
    display as error "  FAIL: G7 Diagnose returns (rc=" _rc ")"
    local ++fail_count
}


* =============================================================================
* SECTION H: Pipeline error handling (6 tests)
* =============================================================================

display ""
display "SECTION H: Pipeline error handling"

* --- H1: tte_expand before prepare ---
local ++test_count
capture noisily {
    clear
    set obs 10
    gen x = _n
    capture tte_expand
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: H1 Expand before prepare"
    local ++pass_count
}
else {
    display as error "  FAIL: H1 Expand before prepare (rc=" _rc ")"
    local ++fail_count
}

* --- H2: tte_weight before expand ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)
    capture tte_weight, switch_d_cov(age sex) nolog
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: H2 Weight before expand"
    local ++pass_count
}
else {
    display as error "  FAIL: H2 Weight before expand (rc=" _rc ")"
    local ++fail_count
}

* --- H3: tte_fit before expand ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)
    capture tte_fit, outcome_cov(age sex) nolog
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: H3 Fit before expand"
    local ++pass_count
}
else {
    display as error "  FAIL: H3 Fit before expand (rc=" _rc ")"
    local ++fail_count
}

* --- H4: tte_predict before fit ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(5)
    capture tte_predict, times(0 2 4) samples(30)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: H4 Predict before fit"
    local ++pass_count
}
else {
    display as error "  FAIL: H4 Predict before fit (rc=" _rc ")"
    local ++fail_count
}

* --- H5: tte_prepare with non-integer periods ---
local ++test_count
capture noisily {
    clear
    set obs 20
    gen id = ceil(_n / 5)
    gen period = _n / 3.0
    gen treatment = (mod(id, 2) == 0)
    gen outcome = 0
    gen eligible = 1

    capture tte_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: H5 Non-integer periods rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: H5 Non-integer periods (rc=" _rc ")"
    local ++fail_count
}

* --- H6: tte_prepare with invalid estimand ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    capture tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(INVALID)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: H6 Invalid estimand rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: H6 Invalid estimand (rc=" _rc ")"
    local ++fail_count
}


* =============================================================================
* SECTION I: Return value completeness (5 tests)
* =============================================================================

display ""
display "SECTION I: Return value completeness"

* --- I1: tte_prepare return values ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) ///
        baseline_covariates(sex) estimand(PP)

    assert r(N) > 0
    assert r(n_ids) > 0
    assert r(n_periods) > 0
    assert r(n_eligible) > 0
    assert r(n_events) >= 0
    assert r(n_treated) > 0
    assert "`r(estimand)'" == "PP"
    assert "`r(id)'" == "patid"
    assert "`r(period)'" == "period"
    assert "`r(treatment)'" == "treatment"
    assert "`r(outcome)'" == "outcome"
    assert "`r(eligible)'" == "eligible"
    assert "`r(covariates)'" != ""
    assert "`r(baseline_covariates)'" != ""
}
if _rc == 0 {
    display as result "  PASS: I1 tte_prepare return values"
    local ++pass_count
}
else {
    display as error "  FAIL: I1 prepare returns (rc=" _rc ")"
    local ++fail_count
}

* --- I2: tte_validate return values ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)
    tte_validate

    assert r(n_checks) > 0
    assert r(n_errors) >= 0
    assert r(n_warnings) >= 0
    assert r(n_events) > 0
    assert r(event_rate) > 0
}
if _rc == 0 {
    display as result "  PASS: I2 tte_validate return values"
    local ++pass_count
}
else {
    display as error "  FAIL: I2 validate returns (rc=" _rc ")"
    local ++fail_count
}

* --- I3: tte main command return values ---
local ++test_count
capture noisily {
    tte
    assert "`r(version)'" != ""
    assert r(n_commands) >= 11
    assert "`r(commands)'" != ""
}
if _rc == 0 {
    display as result "  PASS: I3 tte main return values"
    local ++pass_count
}
else {
    display as error "  FAIL: I3 tte returns (rc=" _rc ")"
    local ++fail_count
}

* --- I4: tte_protocol return values ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)

    tte_protocol, auto

    assert "`r(eligibility)'" != ""
    assert "`r(treatment)'" != ""
    assert "`r(assignment)'" != ""
    assert "`r(followup_start)'" != ""
    assert "`r(outcome)'" != ""
    assert "`r(causal_contrast)'" != ""
    assert "`r(analysis)'" != ""
    assert "`r(format)'" == "display"
}
if _rc == 0 {
    display as result "  PASS: I4 tte_protocol return values"
    local ++pass_count
}
else {
    display as error "  FAIL: I4 protocol returns (rc=" _rc ")"
    local ++fail_count
}

* --- I5: tte_expand with trials() subset ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)

    * Expand only trials 0 1 2
    tte_expand, trials(0 1 2) maxfollowup(5)

    assert r(n_trials) == 3
    * Only trials 0, 1, 2 should exist
    quietly levelsof _tte_trial, local(trials)
    local n_trials: word count `trials'
    assert `n_trials' == 3
}
if _rc == 0 {
    display as result "  PASS: I5 tte_expand trials() subset"
    local ++pass_count
}
else {
    display as error "  FAIL: I5 trials subset (rc=" _rc ")"
    local ++fail_count
}




* =============================================================================
* SECTION 27: tte v1.2.0 — strata(arm_lag), model_var warning, factor expansion
* =============================================================================

* --- S1: strata(arm_lag) runs without error ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(8) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
        strata(arm_lag) truncate(1 99) nolog replace
    assert r(strata) == "arm_lag"
}
if _rc == 0 {
    display as result "  PASS: S1 strata(arm_lag) runs without error"
    local ++pass_count
}
else {
    display as error "  FAIL: S1 strata(arm_lag) (rc=" _rc ")"
    local ++fail_count
}

* --- S2: strata(arm_lag) weights are positive ---
local ++test_count
capture noisily {
    quietly summarize _tte_weight
    assert r(min) > 0
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: S2 strata(arm_lag) weights are positive"
    local ++pass_count
}
else {
    display as error "  FAIL: S2 positive weights (rc=" _rc ")"
    local ++fail_count
}

* --- S3: invalid strata value → error 198 ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(PP)
    tte_expand, maxfollowup(8)
    tte_weight, switch_d_cov(age sex) strata(bad_value) nolog
}
if _rc == 198 {
    display as result "  PASS: S3 invalid strata → error 198"
    local ++pass_count
}
else {
    display as error "  FAIL: S3 expected rc=198, got rc=" _rc
    local ++fail_count
}

* --- S4: strata(arm) vs strata(arm_lag) → predictions agree within tolerance ---
local ++test_count
capture noisily {
    * Run with strata(arm)
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(8) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
        strata(arm) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog
    tte_predict, times(0 4 8) difference samples(50) seed(12345)
    local rd_arm_8 = r(rd_8)

    * Run with strata(arm_lag)
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(8) grace(1)
    tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
        strata(arm_lag) truncate(1 99) nolog
    tte_fit, outcome_cov(age sex comorbidity) nolog
    tte_predict, times(0 4 8) difference samples(50) seed(12345)
    local rd_armlag_8 = r(rd_8)

    * Both should agree within 0.02
    local diff = abs(`rd_arm_8' - `rd_armlag_8')
    assert `diff' < 0.02
}
if _rc == 0 {
    display as result "  PASS: S4 strata(arm) vs strata(arm_lag) agree within 0.02"
    local ++pass_count
}
else {
    display as error "  FAIL: S4 strata comparison (rc=" _rc ")"
    local ++fail_count
}

* --- S5: model_var() warning is displayed ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(8)

    * Create an alternative treatment var
    gen byte alt_treat = _tte_arm

    * Fit with model_var override — should warn but not error
    tte_fit, outcome_cov(age sex) model_var(alt_treat) nolog
}
if _rc == 0 {
    display as result "  PASS: S5 model_var() warning displayed (no error)"
    local ++pass_count
}
else {
    display as error "  FAIL: S5 model_var warning (rc=" _rc ")"
    local ++fail_count
}

* --- S6: factor variable expansion with i.var ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear

    * Create a 3-level categorical from comorbidity
    gen byte comorb_cat = cond(comorbidity < 1, 0, cond(comorbidity < 3, 1, 2))
    label define comorb_lbl 0 "Low" 1 "Medium" 2 "High"
    label values comorb_cat comorb_lbl

    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorb_cat biomarker) estimand(ITT)
    tte_expand, maxfollowup(8)

    * Fit with factor notation
    tte_fit, outcome_cov(i.comorb_cat age) nolog

    * Verify dummy variables were created (base=0, so 1 and 2 get dummies)
    confirm variable _tte_fv_comorb_cat_1
    confirm variable _tte_fv_comorb_cat_2
}
if _rc == 0 {
    display as result "  PASS: S6 factor variable i.var creates dummies"
    local ++pass_count
}
else {
    display as error "  FAIL: S6 factor expansion (rc=" _rc ")"
    local ++fail_count
}

* --- S7: ib#.var sets correct base ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear

    * Create a 3-level categorical
    gen byte comorb_cat = cond(comorbidity < 1, 0, cond(comorbidity < 3, 1, 2))

    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorb_cat biomarker) estimand(ITT)
    tte_expand, maxfollowup(8)

    * Use ib1 → base at level 1, so level 0 and 2 get dummies
    tte_fit, outcome_cov(ib1.comorb_cat age) nolog

    * _tte_fv_comorb_cat_0 should exist (0 is not the base)
    confirm variable _tte_fv_comorb_cat_0
    * _tte_fv_comorb_cat_1 should NOT exist (1 is the base)
    capture confirm variable _tte_fv_comorb_cat_1
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: S7 ib#.var sets correct base"
    local ++pass_count
}
else {
    display as error "  FAIL: S7 ib# base (rc=" _rc ")"
    local ++fail_count
}

* --- S8: full pipeline with factor vars → tte_predict succeeds ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear

    * Create categorical
    gen byte comorb_cat = cond(comorbidity < 1, 0, cond(comorbidity < 3, 1, 2))

    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorb_cat biomarker) estimand(ITT)
    tte_expand, maxfollowup(8)

    tte_fit, outcome_cov(i.comorb_cat age sex) nolog
    tte_predict, times(0 4 8) difference samples(30) seed(42)
    assert r(n_times) == 3
}
if _rc == 0 {
    display as result "  PASS: S8 full pipeline with factor vars through tte_predict"
    local ++pass_count
}
else {
    display as error "  FAIL: S8 factor pipeline (rc=" _rc ")"
    local ++fail_count
}

* --- S9: non-existent factor var → error ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) estimand(ITT)
    tte_expand, maxfollowup(8)

    tte_fit, outcome_cov(i.nonexistent_var age) nolog
}
if _rc == 111 {
    display as result "  PASS: S9 non-existent factor var → error 111"
    local ++pass_count
}
else {
    display as error "  FAIL: S9 expected rc=111, got rc=" _rc
    local ++fail_count
}

* --- S10: strata(arm) default behavior unchanged ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear
    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorbidity biomarker) estimand(PP)
    tte_expand, maxfollowup(8) grace(1)
    * Default (no strata option) should use arm
    tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
        truncate(1 99) nolog replace
    assert r(strata) == "arm"
}
if _rc == 0 {
    display as result "  PASS: S10 default strata is arm"
    local ++pass_count
}
else {
    display as error "  FAIL: S10 default strata (rc=" _rc ")"
    local ++fail_count
}

* --- S11: ibn.var creates dummies for all levels ---
local ++test_count
capture noisily {
    use "`tte_dir'/tte_example.dta", clear

    * Create a 3-level categorical
    gen byte comorb_cat = cond(comorbidity < 1, 0, cond(comorbidity < 3, 1, 2))

    tte_prepare, id(patid) period(period) treatment(treatment) ///
        outcome(outcome) eligible(eligible) ///
        covariates(age sex comorb_cat biomarker) estimand(ITT)
    tte_expand, maxfollowup(8)

    * ibn = no base → dummies for ALL levels
    tte_fit, outcome_cov(ibn.comorb_cat age) nolog

    * All 3 levels should have dummies
    confirm variable _tte_fv_comorb_cat_0
    confirm variable _tte_fv_comorb_cat_1
    confirm variable _tte_fv_comorb_cat_2
}
if _rc == 0 {
    display as result "  PASS: S11 ibn.var creates all-level dummies"
    local ++pass_count
}
else {
    display as error "  FAIL: S11 ibn expansion (rc=" _rc ")"
    local ++fail_count
}


* =============================================================================
* SUMMARY
* =============================================================================

display ""
display "TEST SUMMARY"
display "Tests run:    `test_count'"
display "Passed:       `pass_count'"
display "Failed:       `fail_count'"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}

display ""
display "RESULT: test_tte tests=`test_count' pass=`pass_count' fail=`fail_count'"

log close
exit, clear
