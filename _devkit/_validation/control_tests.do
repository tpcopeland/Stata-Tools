/*******************************************************************************
* control_tests.do
*
* NEGATIVE AND POSITIVE CONTROL TESTS
*
* Tests using scenarios where we KNOW the correct answer:
* - Negative controls: No confounding → OLS = causal effect
* - Positive controls: Known DGP → exact effect recovery
* - Null controls: No effect → estimate should be ~0
*
* Author: Tim Copeland
* Date: 2025-12-30
*******************************************************************************/

clear all
set more off
version 16.0

capture net uninstall tvtools
net install tvtools, from("/home/tpcopeland/Stata-Tools/tvtools")

display _n "{hline 78}"
display "{bf:NEGATIVE AND POSITIVE CONTROL TESTS}"
display "{hline 78}"
display "Started: `c(current_date)' `c(current_time)'"
display "{hline 78}" _n

local total_tests = 0
local total_pass = 0
local total_fail = 0
local failed_tests ""

* =============================================================================
* NEGATIVE CONTROL 1: Randomized Treatment (No Confounding)
* =============================================================================

display _n "{hline 78}"
display "{bf:NEGATIVE CONTROL 1: Randomized Treatment}"
display "{hline 78}" _n

display as text "When treatment is randomized, G-estimation = OLS"
display as text ""

local ++total_tests

clear
set seed 11111
set obs 2000

* Covariates
gen x1 = rnormal()
gen x2 = rnormal()

* RANDOMIZED treatment - no confounding!
gen treatment = runiform() > 0.5

* Outcome with true effect = 5.0
local true_effect = 5.0
gen outcome = 100 + `true_effect'*treatment + 0.5*x1 + 0.3*x2 + rnormal(0, 5)

* OLS (valid under randomization)
quietly regress outcome treatment x1 x2
local ols_effect = _b[treatment]

* G-estimation
tvestimate outcome treatment, confounders(x1 x2)
local gest_effect = e(psi)

display as text "True effect:     " as result %6.3f `true_effect'
display as text "OLS estimate:    " as result %6.3f `ols_effect'
display as text "G-est estimate:  " as result %6.3f `gest_effect'
display as text "Difference:      " as result %6.3f abs(`ols_effect' - `gest_effect')

* Under randomization, both should be close
if abs(`ols_effect' - `gest_effect') < 0.5 & abs(`gest_effect' - `true_effect') < 1 {
    display as result _n "  PASS: G-est ≈ OLS under randomization"
    local ++total_pass
}
else {
    display as error _n "  FAIL: G-est and OLS diverge unexpectedly"
    local ++total_fail
    local failed_tests "`failed_tests' NC1"
}

* =============================================================================
* NEGATIVE CONTROL 2: No Outcome-Covariate Relationship
* =============================================================================

display _n "{hline 78}"
display "{bf:NEGATIVE CONTROL 2: Covariates Don't Affect Outcome}"
display "{hline 78}" _n

display as text "When covariates don't affect outcome, adjustment shouldn't matter"
display as text ""

local ++total_tests

clear
set seed 22222
set obs 1000

gen x1 = rnormal()
gen x2 = rnormal()

* Treatment depends on covariates
gen pr_treat = invlogit(0.5*x1 + 0.3*x2)
gen treatment = runiform() < pr_treat

* Outcome: covariates have NO effect
local true_effect = 3.0
gen outcome = 50 + `true_effect'*treatment + rnormal(0, 5)

* Unadjusted regression
quietly regress outcome treatment
local unadj_effect = _b[treatment]

* G-estimation with unnecessary adjustment
tvestimate outcome treatment, confounders(x1 x2)
local gest_effect = e(psi)

display as text "True effect:       " as result %6.3f `true_effect'
display as text "Unadjusted:        " as result %6.3f `unadj_effect'
display as text "G-est (adjusted):  " as result %6.3f `gest_effect'

* Both should recover true effect
if abs(`unadj_effect' - `true_effect') < 0.5 & abs(`gest_effect' - `true_effect') < 0.5 {
    display as result _n "  PASS: Both methods recover true effect"
    local ++total_pass
}
else {
    display as error _n "  FAIL: Effect estimates are biased"
    local ++total_fail
    local failed_tests "`failed_tests' NC2"
}

* =============================================================================
* POSITIVE CONTROL 1: Known Confounding Structure
* =============================================================================

display _n "{hline 78}"
display "{bf:POSITIVE CONTROL 1: Known Confounding Structure}"
display "{hline 78}" _n

display as text "With known confounding, G-est should recover causal effect"
display as text ""

local ++total_tests

clear
set seed 33333
set obs 2000

* Confounder
gen confounder = rnormal()

* Treatment depends on confounder
gen pr_treat = invlogit(-0.5 + 0.8*confounder)
gen treatment = runiform() < pr_treat

* Outcome depends on treatment AND confounder
local true_effect = 4.0
gen outcome = 20 + `true_effect'*treatment + 2*confounder + rnormal(0, 3)

* Naive OLS (biased due to confounding)
quietly regress outcome treatment
local naive_effect = _b[treatment]

* OLS with adjustment (valid)
quietly regress outcome treatment confounder
local adj_effect = _b[treatment]

* G-estimation (should also be valid)
tvestimate outcome treatment, confounders(confounder)
local gest_effect = e(psi)

display as text "True effect:          " as result %6.3f `true_effect'
display as text "Naive OLS (biased):   " as result %6.3f `naive_effect'
display as text "Adjusted OLS:         " as result %6.3f `adj_effect'
display as text "G-estimation:         " as result %6.3f `gest_effect'

* Naive should be biased, adjusted methods should recover true effect
local naive_bias = abs(`naive_effect' - `true_effect')
local gest_bias = abs(`gest_effect' - `true_effect')

if `naive_bias' > 0.5 & `gest_bias' < 0.5 {
    display as result _n "  PASS: G-est corrects confounding bias"
    local ++total_pass
}
else {
    display as error _n "  FAIL: Confounding not properly handled"
    local ++total_fail
    local failed_tests "`failed_tests' PC1"
}

* =============================================================================
* POSITIVE CONTROL 2: Perfect Balance After Weighting
* =============================================================================

display _n "{hline 78}"
display "{bf:POSITIVE CONTROL 2: IPTW Achieves Balance}"
display "{hline 78}" _n

display as text "IPTW should achieve covariate balance between groups"
display as text ""

local ++total_tests

clear
set seed 44444
set obs 2000

* Strong imbalance in covariates
gen x1 = rnormal()
gen x2 = rnormal()

* Treatment heavily depends on covariates
gen pr_treat = invlogit(-1 + 1.0*x1 + 0.8*x2)
gen treatment = runiform() < pr_treat

* Check imbalance before weighting
quietly summarize x1 if treatment == 1
local x1_treat = r(mean)
quietly summarize x1 if treatment == 0
local x1_control = r(mean)
local smd_before = abs(`x1_treat' - `x1_control') / 1  // SD ≈ 1

* Get IPTW weights
tvweight treatment, covariates(x1 x2) generate(iptw)

* Check balance after weighting
quietly summarize x1 [aw=iptw] if treatment == 1
local wx1_treat = r(mean)
quietly summarize x1 [aw=iptw] if treatment == 0
local wx1_control = r(mean)
local smd_after = abs(`wx1_treat' - `wx1_control') / 1

display as text "SMD before weighting: " as result %6.3f `smd_before'
display as text "SMD after weighting:  " as result %6.3f `smd_after'

if `smd_after' < `smd_before' & `smd_after' < 0.1 {
    display as result _n "  PASS: IPTW achieves good balance"
    local ++total_pass
}
else {
    display as error _n "  FAIL: IPTW does not achieve balance"
    local ++total_fail
    local failed_tests "`failed_tests' PC2"
}

* =============================================================================
* NULL CONTROL 1: Zero Treatment Effect
* =============================================================================

display _n "{hline 78}"
display "{bf:NULL CONTROL 1: Zero Treatment Effect}"
display "{hline 78}" _n

display as text "When true effect = 0, estimate should be near 0"
display as text ""

local ++total_tests

clear
set seed 55555
set obs 1500

gen x1 = rnormal()
gen x2 = rnormal()

gen pr_treat = invlogit(0.3*x1 + 0.2*x2)
gen treatment = runiform() < pr_treat

* NO treatment effect
gen outcome = 50 + 0.5*x1 + 0.3*x2 + rnormal(0, 5)

tvestimate outcome treatment, confounders(x1 x2)
local est_effect = e(psi)
local se_effect = e(se_psi)

display as text "True effect:      " as result "0.000"
display as text "Estimated effect: " as result %6.3f `est_effect'
display as text "SE:               " as result %6.3f `se_effect'
display as text "z-statistic:      " as result %6.3f `est_effect'/`se_effect'

* Effect should not be significantly different from 0
if abs(`est_effect') < 2*`se_effect' {
    display as result _n "  PASS: Null effect correctly identified"
    local ++total_pass
}
else {
    display as error _n "  FAIL: False positive detected"
    local ++total_fail
    local failed_tests "`failed_tests' NULL1"
}

* =============================================================================
* NULL CONTROL 2: Placebo Outcome
* =============================================================================

display _n "{hline 78}"
display "{bf:NULL CONTROL 2: Placebo Outcome}"
display "{hline 78}" _n

display as text "Pre-treatment outcome should show no effect"
display as text ""

local ++total_tests

clear
set seed 66666
set obs 1000

* Pre-treatment variables
gen baseline_outcome = 100 + rnormal(0, 10)
gen x1 = rnormal()

* Treatment assigned AFTER baseline outcome
gen treatment = runiform() < invlogit(0.1*baseline_outcome/10 + 0.3*x1)

* Post-treatment outcome with real effect
gen post_outcome = baseline_outcome + 5*treatment + rnormal(0, 5)

* Test on placebo (baseline) - should find NO effect
tvestimate baseline_outcome treatment, confounders(x1)
local placebo_effect = e(psi)
local placebo_se = e(se_psi)

* Test on real outcome - should find effect
tvestimate post_outcome treatment, confounders(x1 baseline_outcome)
local real_effect = e(psi)

display as text "Placebo effect (baseline): " as result %6.3f `placebo_effect' " (SE: " %4.2f `placebo_se' ")"
display as text "Real effect (post):        " as result %6.3f `real_effect'

* Placebo should be null, real should be significant
if abs(`placebo_effect') < 2*`placebo_se' & abs(`real_effect' - 5) < 1 {
    display as result _n "  PASS: Placebo null, real effect detected"
    local ++total_pass
}
else {
    display as error _n "  FAIL: Placebo test failed"
    local ++total_fail
    local failed_tests "`failed_tests' NULL2"
}

* =============================================================================
* POSITIVE CONTROL 3: E-value Known Values
* =============================================================================

display _n "{hline 78}"
display "{bf:POSITIVE CONTROL 3: E-value Known Values}"
display "{hline 78}" _n

display as text "Testing E-value against hand-calculated values"
display as text ""

local ++total_tests

* E-value formula: E = RR + sqrt(RR * (RR - 1)) for RR > 1

* Test case 1: RR = 2.0
* E = 2 + sqrt(2*1) = 2 + 1.414 = 3.414
local rr1 = 2.0
local expected1 = `rr1' + sqrt(`rr1' * (`rr1' - 1))

tvsensitivity, rr(`rr1')
local calc1 = r(evalue)

* Test case 2: RR = 3.0
* E = 3 + sqrt(3*2) = 3 + 2.449 = 5.449
local rr2 = 3.0
local expected2 = `rr2' + sqrt(`rr2' * (`rr2' - 1))

tvsensitivity, rr(`rr2')
local calc2 = r(evalue)

* Test case 3: RR = 1.5
* E = 1.5 + sqrt(1.5*0.5) = 1.5 + 0.866 = 2.366
local rr3 = 1.5
local expected3 = `rr3' + sqrt(`rr3' * (`rr3' - 1))

tvsensitivity, rr(`rr3')
local calc3 = r(evalue)

display as text "RR=2.0: Expected " %5.3f `expected1' ", Got " %5.3f `calc1'
display as text "RR=3.0: Expected " %5.3f `expected2' ", Got " %5.3f `calc2'
display as text "RR=1.5: Expected " %5.3f `expected3' ", Got " %5.3f `calc3'

if abs(`calc1' - `expected1') < 0.001 & abs(`calc2' - `expected2') < 0.001 & abs(`calc3' - `expected3') < 0.001 {
    display as result _n "  PASS: All E-values match hand calculations"
    local ++total_pass
}
else {
    display as error _n "  FAIL: E-value calculation error"
    local ++total_fail
    local failed_tests "`failed_tests' PC3"
}

* =============================================================================
* POSITIVE CONTROL 4: DML Matches OLS with Linear DGP
* =============================================================================

display _n "{hline 78}"
display "{bf:POSITIVE CONTROL 4: DML ≈ OLS with Linear Models}"
display "{hline 78}" _n

display as text "With truly linear models, DML should match OLS"
display as text ""

local ++total_tests

clear
set seed 77777
set obs 1000

* Truly linear DGP
gen x1 = rnormal()
gen x2 = rnormal()

* Linear propensity
gen pr_treat = invlogit(0.3*x1 + 0.2*x2)
gen treatment = runiform() < pr_treat

* Linear outcome
local true_effect = 2.5
gen outcome = 10 + `true_effect'*treatment + 0.5*x1 + 0.3*x2 + rnormal(0, 2)

* OLS
quietly regress outcome treatment x1 x2
local ols_est = _b[treatment]

* DML
tvdml outcome treatment, covariates(x1 x2) crossfit(5) seed(12345)
local dml_est = e(psi)

display as text "True effect:  " as result %6.3f `true_effect'
display as text "OLS:          " as result %6.3f `ols_est'
display as text "DML:          " as result %6.3f `dml_est'
display as text "Difference:   " as result %6.3f abs(`ols_est' - `dml_est')

if abs(`ols_est' - `dml_est') < 0.5 {
    display as result _n "  PASS: DML ≈ OLS with linear DGP"
    local ++total_pass
}
else {
    display as error _n "  FAIL: DML and OLS diverge with linear DGP"
    local ++total_fail
    local failed_tests "`failed_tests' PC4"
}

* =============================================================================
* POSITIVE CONTROL 5: Target Trial Preserves Person-Time
* =============================================================================

display _n "{hline 78}"
display "{bf:POSITIVE CONTROL 5: Target Trial Properties}"
display "{hline 78}" _n

display as text "Clone approach should create balanced arms"
display as text ""

local ++total_tests

clear
set seed 88888
set obs 200

gen id = _n
gen study_entry = mdy(1, 1, 2020)
gen study_exit = study_entry + 365
format %td study_entry study_exit
gen rx_start = .
replace rx_start = study_entry + floor(runiform() * 200) if runiform() < 0.4
format %td rx_start

tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
    trials(1) clone graceperiod(30)

* Arms should be balanced
quietly count if trial_arm == 1
local n_treat = r(N)
quietly count if trial_arm == 0
local n_control = r(N)

display as text "Treatment arm:  " as result `n_treat'
display as text "Control arm:    " as result `n_control'

if `n_treat' == `n_control' {
    display as result _n "  PASS: Arms perfectly balanced by cloning"
    local ++total_pass
}
else {
    display as error _n "  FAIL: Arms not balanced"
    local ++total_fail
    local failed_tests "`failed_tests' PC5"
}

* =============================================================================
* FINAL SUMMARY
* =============================================================================

display _n "{hline 78}"
display "{bf:CONTROL TEST SUMMARY}"
display "{hline 78}"
display "Total tests:   " as result `total_tests'
display "Passed:        " as result `total_pass'
if `total_fail' > 0 {
    display "Failed:        " as error `total_fail'
    display as error _n "FAILED:`failed_tests'"
}
else {
    display "Failed:        " as text `total_fail'
}
display "{hline 78}"

local pass_rate = 100 * `total_pass' / `total_tests'
display _n "Pass rate: " as result %5.1f `pass_rate' "%"

if `total_fail' == 0 {
    display _n as result "{bf:ALL CONTROL TESTS PASSED!}"
    display as result "Commands behave correctly in known scenarios."
}

display _n "{hline 78}"
display "Completed: `c(current_date)' `c(current_time)'"
display "{hline 78}"
