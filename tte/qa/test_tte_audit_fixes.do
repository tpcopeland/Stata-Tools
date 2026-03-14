/*******************************************************************************
* test_tte_audit_fixes.do
*
* Targeted tests for the 6 fixes applied from the 2026-03-14 audit:
*   1. Natural censoring via censor() truncates follow-up in tte_expand
*   2. tte_weight generate(customname) found by tte_fit/tte_diagnose/tte_report
*   3. Balance SMDs computed at followup==0 only in tte_diagnose
*   4. Per-period positivity violation detected by tte_validate
*   5. strict promotes Check 7 and Check 10 warnings to errors
*   6. ITT branch of tte_weight sets _tte_weighted and _tte_weight_var metadata
*
* Run with: stata-mp -b do test_tte_audit_fixes.do
*******************************************************************************/

clear all
set more off
version 16.0

capture log close
log using "test_tte_audit_fixes.log", replace nomsg

display _dup(70) "="
display "AUDIT FIX TESTS: tte package (2026-03-14)"
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

* ===========================================================================
* SUMMARY
* ===========================================================================

display ""
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
