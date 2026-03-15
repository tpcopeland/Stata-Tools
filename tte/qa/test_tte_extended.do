/*******************************************************************************
* test_tte_extended.do
*
* Extended functional tests for the tte (Target Trial Emulation) package.
* Covers all options, error handling, and code paths not exercised by
* test_tte.do or test_tte_audit_fixes.do.
*
* Sections:
*   A. tte_calibrate (15 tests)
*   B. tte_protocol extended (8 tests)
*   C. tte_plot extended (8 tests)
*   D. tte_validate all 10 checks (12 tests)
*   E. tte_weight advanced options (10 tests)
*   F. tte_fit & tte_predict advanced (9 tests)
*   G. tte_report & tte_diagnose advanced (7 tests)
*   H. Pipeline error handling (6 tests)
*   I. Return value completeness (5 tests)
*
* Run with: stata-mp -b do test_tte_extended.do
*******************************************************************************/

clear all
set more off
version 16.0

capture log close
log using "test_tte_extended.log", replace nomsg

display "EXTENDED FUNCTIONAL TESTS: tte (Target Trial Emulation)"
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
    cap program drop _tte_protocol_overview
    cap program drop _tte_calibrate_fit
    cap program drop _tte_cal_profile_ll
    cap program drop _tte_cal_weighted_mean

    run "`tte_dir'/_tte_check_prepared.ado"
    run "`tte_dir'/_tte_check_expanded.ado"
    run "`tte_dir'/_tte_check_weighted.ado"
    run "`tte_dir'/_tte_check_fitted.ado"
    run "`tte_dir'/_tte_get_settings.ado"
    run "`tte_dir'/_tte_memory_estimate.ado"
    run "`tte_dir'/_tte_display_header.ado"
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
}


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
display "RESULT: test_tte_extended tests=`test_count' pass=`pass_count' fail=`fail_count'"

log close
exit, clear
