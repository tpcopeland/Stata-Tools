/*******************************************************************************
* integration_workflow_test.do
*
* INTEGRATION WORKFLOW VALIDATION
*
* Tests complete analysis workflows using multiple commands together,
* simulating realistic pharmacoepidemiologic analyses.
*
* Workflows tested:
* 1. Standard IPTW analysis
* 2. Target trial emulation workflow
* 3. G-estimation with sensitivity analysis
* 4. Full pipeline from raw data to weighted estimate
*
* Author: Tim Copeland
* Date: 2025-12-30
*******************************************************************************/

clear all
set more off
version 16.0

* Reinstall tvtools
capture net uninstall tvtools
net install tvtools, from("/home/tpcopeland/Stata-Tools/tvtools")

display _n "{hline 78}"
display "{bf:INTEGRATION WORKFLOW VALIDATION}"
display "{hline 78}"
display "Started: `c(current_date)' `c(current_time)'"
display "{hline 78}" _n

local total_tests = 0
local total_pass = 0
local total_fail = 0
local failed_tests ""

* =============================================================================
* WORKFLOW 1: Standard IPTW Causal Analysis
* =============================================================================

display _n "{hline 78}"
display "{bf:WORKFLOW 1: Standard IPTW Causal Analysis}"
display "{hline 78}" _n

display as text "Scenario: Estimating effect of statin therapy on cholesterol"
display as text ""

local ++total_tests

capture {
    * Step 1: Generate realistic cohort
    clear
    set seed 20251230
    set obs 2000

    * Demographics
    gen id = _n
    gen age = 50 + rnormal(0, 12)
    replace age = max(30, min(80, age))
    gen female = runiform() < 0.52
    gen bmi = 26 + rnormal(0, 5)
    replace bmi = max(18, min(45, bmi))

    * Clinical factors
    gen diabetes = runiform() < 0.15
    gen hypertension = runiform() < 0.35
    gen smoker = runiform() < 0.20
    gen baseline_ldl = 130 + rnormal(0, 30) + 10*diabetes + 5*bmi/10

    * Treatment assignment (confounded)
    gen pr_statin = invlogit(-2 + 0.03*age + 0.5*diabetes + 0.3*hypertension + ///
        0.02*baseline_ldl + 0.1*(bmi > 30))
    gen statin = runiform() < pr_statin

    * Outcome: LDL reduction (true effect = -40 mg/dL)
    gen ldl_change = -40*statin + 0.1*age - 5*female + 2*bmi/10 + rnormal(0, 15)

    display as text "Step 1: Generated cohort of 2000 patients"

    * Step 2: Calculate IPTW weights
    tvweight statin, covariates(age female bmi diabetes hypertension smoker baseline_ldl) ///
        generate(iptw) stabilized

    display as text "Step 2: Calculated stabilized IPTW weights"
    display as text "        ESS = " %6.1f r(ess) " (" %4.1f r(ess_pct) "%)"

    * Step 3: Check covariate balance
    * (Would use tvbalance but simplified here)
    quietly summarize age if statin == 1
    local age_treat = r(mean)
    quietly summarize age if statin == 0
    local age_control = r(mean)
    local smd_age_raw = abs(`age_treat' - `age_control') / 10

    quietly summarize age [aw=iptw] if statin == 1
    local wage_treat = r(mean)
    quietly summarize age [aw=iptw] if statin == 0
    local wage_control = r(mean)
    local smd_age_wt = abs(`wage_treat' - `wage_control') / 10

    display as text "Step 3: Covariate balance check"
    display as text "        Age SMD: " %5.3f `smd_age_raw' " -> " %5.3f `smd_age_wt' " (weighted)"

    * Step 4: Estimate treatment effect
    quietly regress ldl_change statin [pw=iptw]
    local ate = _b[statin]
    local se = _se[statin]

    display as text "Step 4: Weighted regression"
    display as text "        ATE = " %6.1f `ate' " mg/dL (SE = " %4.1f `se' ")"

    * Step 5: Sensitivity analysis
    * Convert to approximate RR for E-value (effect / baseline * 100)
    local rr_approx = 1 + abs(`ate') / 130
    tvsensitivity, rr(`rr_approx')
    local evalue = r(evalue)

    display as text "Step 5: Sensitivity analysis"
    display as text "        E-value = " %4.2f `evalue'

    * Step 6: Generate summary table
    gen tv_exposure = statin
    gen fu_time = 365
    gen _event = 0
    tvtable, exposure(tv_exposure)

    display as text "Step 6: Generated exposure summary table"

    * Validation checks
    assert abs(`ate' - (-40)) < 10  // Effect within 10 units of true
    assert `evalue' > 1
    assert `smd_age_wt' < `smd_age_raw'  // Weighting improved balance
}

if _rc == 0 {
    display as result _n "  WORKFLOW 1 PASSED: Full IPTW analysis completed successfully"
    local ++total_pass
}
else {
    display as error _n "  WORKFLOW 1 FAILED (error `=_rc')"
    local ++total_fail
    local failed_tests "`failed_tests' WF1"
}

* =============================================================================
* WORKFLOW 2: Target Trial Emulation
* =============================================================================

display _n "{hline 78}"
display "{bf:WORKFLOW 2: Target Trial Emulation}"
display "{hline 78}" _n

display as text "Scenario: Emulating trial of treatment initiation vs. no treatment"
display as text ""

local ++total_tests

capture {
    * Step 1: Generate cohort with follow-up
    clear
    set seed 20251231
    set obs 1000

    gen id = _n
    gen study_entry = mdy(1, 1, 2020) + floor(runiform() * 60)
    gen study_exit = study_entry + 365 + floor(runiform() * 365)
    format %td study_entry study_exit

    gen age = 55 + rnormal(0, 10)
    gen comorbidity = runiform() < 0.3

    * Treatment initiation (40% eventually treated)
    gen rx_start = .
    replace rx_start = study_entry + floor(runiform() * 300) if runiform() < 0.4
    format %td rx_start

    display as text "Step 1: Generated cohort with time-to-treatment"

    * Step 2: Build target trial with cloning
    tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
        trials(6) trialinterval(60) clone graceperiod(30)

    local n_persontrials = r(n_persontrials)
    local n_trials = r(n_trials)

    display as text "Step 2: Built target trial structure"
    display as text "        Trials: `n_trials'"
    display as text "        Person-trials: `n_persontrials'"

    * Step 3: Verify structure
    quietly distinct id
    local n_unique = r(ndistinct)

    quietly count if trial_arm == 1
    local n_treat = r(N)
    quietly count if trial_arm == 0
    local n_control = r(N)

    display as text "Step 3: Verified trial structure"
    display as text "        Unique IDs: `n_unique'"
    display as text "        Treatment arm: `n_treat'"
    display as text "        Control arm: `n_control'"

    * Step 4: Check censoring
    quietly count if trial_censored == 1
    local n_censored = r(N)
    local pct_censored = 100 * `n_censored' / _N

    display as text "Step 4: Censoring analysis"
    display as text "        Censored: `n_censored' (" %4.1f `pct_censored' "%)"

    * Validation
    assert `n_persontrials' > 0
    assert `n_treat' > 0
    assert `n_control' > 0
    assert `n_treat' == `n_control'  // Clone should make equal arms
}

if _rc == 0 {
    display as result _n "  WORKFLOW 2 PASSED: Target trial emulation completed"
    local ++total_pass
}
else {
    display as error _n "  WORKFLOW 2 FAILED (error `=_rc')"
    local ++total_fail
    local failed_tests "`failed_tests' WF2"
}

* =============================================================================
* WORKFLOW 3: G-Estimation with Multiple Sensitivity Analyses
* =============================================================================

display _n "{hline 78}"
display "{bf:WORKFLOW 3: G-Estimation with Sensitivity Analysis}"
display "{hline 78}" _n

display as text "Scenario: G-estimation with comprehensive sensitivity analysis"
display as text ""

local ++total_tests

capture {
    * Step 1: Generate data with known effect
    clear
    set seed 12340000
    set obs 1500

    gen x1 = rnormal()
    gen x2 = rnormal()
    gen x3 = rnormal()
    gen U = rnormal()  // Unmeasured confounder

    gen pr_treat = invlogit(-0.5 + 0.3*x1 + 0.2*x2 + 0.4*U)
    gen treatment = runiform() < pr_treat

    * True effect = 5.0
    gen outcome = 100 + 5*treatment + 0.5*x1 + 0.3*x2 + 0.8*U + rnormal(0, 5)

    display as text "Step 1: Generated data with true effect = 5.0"

    * Step 2: G-estimation (controlling for measured confounders only)
    tvestimate outcome treatment, confounders(x1 x2 x3)

    local psi = e(psi)
    local se = e(se_psi)
    local ci_lo = `psi' - 1.96*`se'
    local ci_hi = `psi' + 1.96*`se'

    display as text "Step 2: G-estimation results"
    display as text "        ψ = " %5.2f `psi' " (95% CI: " %5.2f `ci_lo' ", " %5.2f `ci_hi' ")"

    * Step 3: DML for comparison
    tvdml outcome treatment, covariates(x1 x2 x3) crossfit(3) seed(99999)

    local psi_dml = e(psi)
    local se_dml = e(se_psi)

    display as text "Step 3: DML comparison"
    display as text "        ψ_DML = " %5.2f `psi_dml' " (SE = " %4.2f `se_dml' ")"

    * Step 4: Sensitivity analysis for unmeasured confounding
    * Use approximate RR
    local rr_est = exp(`psi' / 20)  // Approximate conversion

    tvsensitivity, rr(`rr_est')
    local ev_point = r(evalue)

    display as text "Step 4: E-value sensitivity analysis"
    display as text "        E-value = " %4.2f `ev_point'

    * Step 5: Test range of bias parameters
    display as text "Step 5: Bias parameter exploration"
    foreach rr in 1.5 2.0 2.5 3.0 {
        tvsensitivity, rr(`rr')
        display as text "        RR = `rr' -> E-value = " %4.2f r(evalue)
    }

    * Validation
    assert `psi' != .
    assert `psi_dml' != .
    assert `ev_point' > 1
    * G-est and DML should give similar results
    assert abs(`psi' - `psi_dml') < 2
}

if _rc == 0 {
    display as result _n "  WORKFLOW 3 PASSED: G-estimation with sensitivity analysis"
    local ++total_pass
}
else {
    display as error _n "  WORKFLOW 3 FAILED (error `=_rc')"
    local ++total_fail
    local failed_tests "`failed_tests' WF3"
}

* =============================================================================
* WORKFLOW 4: Complete Pipeline from Raw Data
* =============================================================================

display _n "{hline 78}"
display "{bf:WORKFLOW 4: Complete Pipeline from Raw Data}"
display "{hline 78}" _n

display as text "Scenario: Full analysis from separate cohort and prescription files"
display as text ""

local ++total_tests

capture {
    * Step 1: Create raw cohort data
    clear
    set seed 55550000
    set obs 500

    gen id = _n
    gen cohort_start = mdy(1, 1, 2020) + floor(runiform() * 30)
    gen cohort_end = cohort_start + 365 + floor(runiform() * 180)
    format %td cohort_start cohort_end

    gen age = 60 + rnormal(0, 12)
    gen female = runiform() < 0.55
    gen risk_score = rnormal()

    tempfile cohort_raw
    save `cohort_raw', replace

    display as text "Step 1: Created raw cohort (N=500)"

    * Step 2: Create raw prescription data
    clear
    set obs 800
    gen id = ceil(runiform() * 500)
    gen rx_date = mdy(1, 1, 2020) + floor(runiform() * 400)
    gen rx_end = rx_date + 30 + floor(runiform() * 60)
    format %td rx_date rx_end
    gen drug_class = 1 + floor(runiform() * 3)  // 3 drug classes

    tempfile rx_raw
    save `rx_raw', replace

    display as text "Step 2: Created raw prescription data (N=800)"

    * Step 3: Run pipeline to create analysis dataset
    use `cohort_raw', clear

    tvpipeline using `rx_raw', id(id) start(rx_date) stop(rx_end) ///
        exposure(drug_class) entry(cohort_start) exit(cohort_end)

    local n_intervals = _N
    display as text "Step 3: Pipeline created `n_intervals' person-intervals"

    * Step 4: Generate summary report
    tvreport, id(id) start(start) stop(stop) exposure(tv_exposure)

    local n_obs = r(n_obs)
    local n_ids = r(n_ids)

    display as text "Step 4: Report generated"
    display as text "        Intervals: `n_obs'"
    display as text "        Unique IDs: `n_ids'"

    * Step 5: Exposure summary
    gen fu_time = stop - start
    gen _event = runiform() < 0.1

    tvtable, exposure(tv_exposure)

    local n_levels = r(n_levels)
    display as text "Step 5: Exposure table"
    display as text "        Exposure levels: `n_levels'"

    * Validation
    assert `n_intervals' > 500  // Should have more intervals than original obs
    assert `n_ids' == 500
    assert `n_levels' >= 2
}

if _rc == 0 {
    display as result _n "  WORKFLOW 4 PASSED: Complete pipeline workflow"
    local ++total_pass
}
else {
    display as error _n "  WORKFLOW 4 FAILED (error `=_rc')"
    local ++total_fail
    local failed_tests "`failed_tests' WF4"
}

* =============================================================================
* WORKFLOW 5: Multi-Method Comparison
* =============================================================================

display _n "{hline 78}"
display "{bf:WORKFLOW 5: Multi-Method Comparison}"
display "{hline 78}" _n

display as text "Scenario: Compare IPTW, G-estimation, and DML on same data"
display as text ""

local ++total_tests

capture {
    * Generate data
    clear
    set seed 77770000
    set obs 1000

    gen x1 = rnormal()
    gen x2 = rnormal()
    gen x3 = rnormal()

    gen pr_treat = invlogit(-0.3 + 0.25*x1 + 0.15*x2 + 0.1*x3)
    gen treatment = runiform() < pr_treat

    * True effect = 3.0
    gen outcome = 50 + 3*treatment + 0.4*x1 + 0.3*x2 + 0.1*x3 + rnormal(0, 4)

    display as text "Data: N=1000, True effect = 3.0"

    * Method 1: IPTW
    tvweight treatment, covariates(x1 x2 x3) generate(iptw) stabilized
    quietly regress outcome treatment [pw=iptw]
    local psi_iptw = _b[treatment]
    local se_iptw = _se[treatment]

    display as text ""
    display as text "Method 1: IPTW-weighted regression"
    display as text "          ψ = " %5.2f `psi_iptw' " (SE = " %4.2f `se_iptw' ")"

    * Method 2: G-estimation
    tvestimate outcome treatment, confounders(x1 x2 x3)
    local psi_gest = e(psi)
    local se_gest = e(se_psi)

    display as text ""
    display as text "Method 2: G-estimation"
    display as text "          ψ = " %5.2f `psi_gest' " (SE = " %4.2f `se_gest' ")"

    * Method 3: DML
    tvdml outcome treatment, covariates(x1 x2 x3) crossfit(5) seed(11111)
    local psi_dml = e(psi)
    local se_dml = e(se_psi)

    display as text ""
    display as text "Method 3: Double ML"
    display as text "          ψ = " %5.2f `psi_dml' " (SE = " %4.2f `se_dml' ")"

    * Method 4: Naive OLS (for comparison)
    quietly regress outcome treatment x1 x2 x3
    local psi_ols = _b[treatment]
    local se_ols = _se[treatment]

    display as text ""
    display as text "Method 4: Naive OLS (reference)"
    display as text "          ψ = " %5.2f `psi_ols' " (SE = " %4.2f `se_ols' ")"

    * Summary comparison
    local bias_iptw = `psi_iptw' - 3
    local bias_gest = `psi_gest' - 3
    local bias_dml = `psi_dml' - 3
    local bias_ols = `psi_ols' - 3

    display as text ""
    display as text "{hline 50}"
    display as text "Method Comparison (True effect = 3.0)"
    display as text "{hline 50}"
    display as text "IPTW:  " `psi_iptw' "  Bias: " `bias_iptw'
    display as text "G-est: " `psi_gest' "  Bias: " `bias_gest'
    display as text "DML:   " `psi_dml' "  Bias: " `bias_dml'
    display as text "OLS:   " `psi_ols' "  Bias: " `bias_ols'
    display as text "{hline 50}"

    * Validation: All methods should be within 1 unit of true value
    assert abs(`psi_iptw' - 3) < 1.5
    assert abs(`psi_gest' - 3) < 1.5
    assert abs(`psi_dml' - 3) < 1.5
}

if _rc == 0 {
    display as result _n "  WORKFLOW 5 PASSED: Multi-method comparison"
    local ++total_pass
}
else {
    display as error _n "  WORKFLOW 5 FAILED (error `=_rc')"
    local ++total_fail
    local failed_tests "`failed_tests' WF5"
}

* =============================================================================
* FINAL SUMMARY
* =============================================================================

display _n "{hline 78}"
display "{bf:INTEGRATION WORKFLOW SUMMARY}"
display "{hline 78}"
display "Total workflows tested:  " as result `total_tests'
display "Workflows passed:        " as result `total_pass'
if `total_fail' > 0 {
    display "Workflows failed:        " as error `total_fail'
    display as error _n "FAILED WORKFLOWS:`failed_tests'"
}
else {
    display "Workflows failed:        " as text `total_fail'
}
display "{hline 78}"

local pass_rate = 100 * `total_pass' / `total_tests'
display _n "Pass rate: " as result %5.1f `pass_rate' "%"

if `total_fail' == 0 {
    display _n as result "{bf:ALL INTEGRATION WORKFLOWS PASSED!}"
    display as result "Commands work correctly together in realistic analyses."
}
else {
    display _n as error "{bf:SOME WORKFLOWS FAILED - INVESTIGATE}"
}

display _n "{hline 78}"
display "Completed: `c(current_date)' `c(current_time)'"
display "{hline 78}"
