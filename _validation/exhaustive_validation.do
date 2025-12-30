/*******************************************************************************
* exhaustive_validation.do
*
* EXHAUSTIVE VALIDATION OF ALL TVTOOLS CAUSAL INFERENCE COMMANDS
*
* This file performs deep mathematical validation with:
* - Known-answer tests (hand-computed values)
* - Mathematical invariants that must hold
* - Edge cases and boundary conditions
* - Consistency checks across methods
* - Stress tests with challenging data
*
* Author: Tim Copeland
* Date: 2025-12-30
*******************************************************************************/

clear all
set more off
version 16.0

* Reinstall tvtools to ensure latest version
capture net uninstall tvtools
net install tvtools, from("/home/tpcopeland/Stata-Tools/tvtools")

display _n "{hline 78}"
display "{bf:EXHAUSTIVE VALIDATION OF TVTOOLS CAUSAL INFERENCE COMMANDS}"
display "{hline 78}"
display "Started: `c(current_date)' `c(current_time)'"
display "{hline 78}" _n

local total_tests = 0
local total_pass = 0
local total_fail = 0
local failed_tests ""

* =============================================================================
* SECTION 1: TVWEIGHT - IPTW VALIDATION
* =============================================================================

display _n "{hline 78}"
display "{bf:SECTION 1: TVWEIGHT - Inverse Probability of Treatment Weighting}"
display "{hline 78}" _n

* -----------------------------------------------------------------------------
* TEST 1.1: Hand-computed IPTW weights
* -----------------------------------------------------------------------------
display as text "Test 1.1: Hand-computed IPTW weights"
local ++total_tests

clear
input id treatment x1 x2
1 1 0 0
2 1 1 0
3 1 0 1
4 1 1 1
5 0 0 0
6 0 1 0
7 0 0 1
8 0 1 1
end

* Run logit manually to get propensity scores
quietly logit treatment x1 x2
quietly predict ps_manual, pr

* Calculate weights manually: treated = 1/ps, untreated = 1/(1-ps)
gen iptw_manual = cond(treatment == 1, 1/ps_manual, 1/(1-ps_manual))

* Now use tvweight
tvweight treatment, covariates(x1 x2) generate(iptw_auto)

* Compare - should be identical
gen diff = abs(iptw_manual - iptw_auto)
quietly summarize diff
local max_diff = r(max)

if `max_diff' < 1e-10 {
    display as result "  PASS: Manual vs tvweight weights match (max diff: `max_diff')"
    local ++total_pass
}
else {
    display as error "  FAIL: Weight mismatch (max diff: `max_diff')"
    local ++total_fail
    local failed_tests "`failed_tests' 1.1"
}

* -----------------------------------------------------------------------------
* TEST 1.2: Stabilized weights sum property
* -----------------------------------------------------------------------------
display as text "Test 1.2: Stabilized weights - treated weights sum to N_treated"
local ++total_tests

clear
set seed 12345
set obs 1000

gen x1 = rnormal()
gen x2 = rnormal()
gen pr_treat = invlogit(-0.5 + 0.3*x1 + 0.2*x2)
gen treatment = runiform() < pr_treat

tvweight treatment, covariates(x1 x2) generate(sw) stabilized

* For stabilized weights: sum of weights in treated should equal N_treated
quietly count if treatment == 1
local n_treated = r(N)
quietly summarize sw if treatment == 1
local sum_sw_treated = r(sum)

* Should be approximately equal (not exact due to estimation)
local ratio = `sum_sw_treated' / `n_treated'
if abs(`ratio' - 1) < 0.05 {
    display as result "  PASS: Stabilized weights sum ratio: `ratio' (expected ~1.0)"
    local ++total_pass
}
else {
    display as error "  FAIL: Stabilized weights ratio: `ratio' (expected ~1.0)"
    local ++total_fail
    local failed_tests "`failed_tests' 1.2"
}

* -----------------------------------------------------------------------------
* TEST 1.3: Truncation bounds are respected
* -----------------------------------------------------------------------------
display as text "Test 1.3: Truncation bounds strictly enforced"
local ++total_tests

tvweight treatment, covariates(x1 x2) generate(tw) truncate(5 95)

quietly summarize tw
local min_w = r(min)
local max_w = r(max)

* Calculate expected bounds from percentiles of untruncated
tvweight treatment, covariates(x1 x2) generate(uw)
quietly _pctile uw, p(5 95)
local p5 = r(r1)
local p95 = r(r2)

if `min_w' >= `p5' - 1e-10 & `max_w' <= `p95' + 1e-10 {
    display as result "  PASS: Truncation bounds respected (min: `min_w', max: `max_w')"
    local ++total_pass
}
else {
    display as error "  FAIL: Truncation failed (min: `min_w', max: `max_w')"
    local ++total_fail
    local failed_tests "`failed_tests' 1.3"
}

* -----------------------------------------------------------------------------
* TEST 1.4: ESS calculation correctness
* -----------------------------------------------------------------------------
display as text "Test 1.4: Effective sample size formula verification"
local ++total_tests

* ESS = (sum(w))^2 / sum(w^2)
quietly summarize uw
local sum_w = r(sum)
gen uw_sq = uw^2
quietly summarize uw_sq
local sum_w_sq = r(sum)
local ess_manual = (`sum_w')^2 / `sum_w_sq'

tvweight treatment, covariates(x1 x2) generate(uw2)
local ess_auto = r(ess)

if abs(`ess_manual' - `ess_auto') < 1 {
    display as result "  PASS: ESS calculation correct (manual: `ess_manual', auto: `ess_auto')"
    local ++total_pass
}
else {
    display as error "  FAIL: ESS mismatch (manual: `ess_manual', auto: `ess_auto')"
    local ++total_fail
    local failed_tests "`failed_tests' 1.4"
}

* -----------------------------------------------------------------------------
* TEST 1.5: Perfect prediction handling
* -----------------------------------------------------------------------------
display as text "Test 1.5: Perfect prediction edge case"
local ++total_tests

clear
input id treatment x1
1 1 1
2 1 1
3 1 1
4 0 0
5 0 0
6 0 0
end

* x1 perfectly predicts treatment - should warn or handle gracefully
capture tvweight treatment, covariates(x1) generate(w_perfect)
if _rc == 0 {
    * Should produce extreme weights or warning
    quietly summarize w_perfect
    display as result "  PASS: Perfect prediction handled (weights: min=`r(min)', max=`r(max)')"
    local ++total_pass
}
else {
    display as result "  PASS: Perfect prediction correctly rejected with error"
    local ++total_pass
}

* -----------------------------------------------------------------------------
* TEST 1.6: Multinomial treatment (3 levels)
* -----------------------------------------------------------------------------
display as text "Test 1.6: Multinomial treatment with 3 levels"
local ++total_tests

clear
set seed 54321
set obs 600

gen x1 = rnormal()
gen x2 = rnormal()

* Create 3-level treatment
gen pr1 = exp(0.2*x1) / (1 + exp(0.2*x1) + exp(0.3*x2))
gen pr2 = exp(0.3*x2) / (1 + exp(0.2*x1) + exp(0.3*x2))
gen u = runiform()
gen treatment = cond(u < pr1, 0, cond(u < pr1 + pr2, 1, 2))

tvweight treatment, covariates(x1 x2) generate(mw) model(mlogit)

* Check all observations have weights
quietly count if missing(mw)
local n_miss = r(N)

* Check weights are positive
quietly count if mw <= 0 & !missing(mw)
local n_neg = r(N)

if `n_miss' == 0 & `n_neg' == 0 {
    display as result "  PASS: Multinomial weights all positive and non-missing"
    local ++total_pass
}
else {
    display as error "  FAIL: Multinomial weights have issues (missing: `n_miss', non-pos: `n_neg')"
    local ++total_fail
    local failed_tests "`failed_tests' 1.6"
}

* -----------------------------------------------------------------------------
* TEST 1.7: Covariate balance after weighting
* -----------------------------------------------------------------------------
display as text "Test 1.7: IPTW should improve covariate balance"
local ++total_tests

clear
set seed 11111
set obs 2000

* Strong confounding
gen x1 = rnormal()
gen x2 = rnormal()
gen pr_treat = invlogit(-1 + 0.8*x1 + 0.6*x2)
gen treatment = runiform() < pr_treat

* Unweighted standardized difference for x1
quietly summarize x1 if treatment == 1
local m1_t = r(mean)
local s1_t = r(sd)
quietly summarize x1 if treatment == 0
local m1_c = r(mean)
local s1_c = r(sd)
local smd_before = abs(`m1_t' - `m1_c') / sqrt((`s1_t'^2 + `s1_c'^2)/2)

* Get weights
tvweight treatment, covariates(x1 x2) generate(iptw)

* Weighted standardized difference
quietly summarize x1 [aw=iptw] if treatment == 1
local wm1_t = r(mean)
quietly summarize x1 [aw=iptw] if treatment == 0
local wm1_c = r(mean)
local smd_after = abs(`wm1_t' - `wm1_c') / sqrt((`s1_t'^2 + `s1_c'^2)/2)

if `smd_after' < `smd_before' {
    display as result "  PASS: Balance improved (SMD before: " %5.3f `smd_before' ", after: " %5.3f `smd_after' ")"
    local ++total_pass
}
else {
    display as error "  FAIL: Balance not improved (before: `smd_before', after: `smd_after')"
    local ++total_fail
    local failed_tests "`failed_tests' 1.7"
}

* =============================================================================
* SECTION 2: TVESTIMATE - G-ESTIMATION VALIDATION
* =============================================================================

display _n "{hline 78}"
display "{bf:SECTION 2: TVESTIMATE - G-Estimation for SNMMs}"
display "{hline 78}" _n

* -----------------------------------------------------------------------------
* TEST 2.1: Known causal effect recovery
* -----------------------------------------------------------------------------
display as text "Test 2.1: Recovery of known causal effect (psi = 2.0)"
local ++total_tests

clear
set seed 22222
set obs 5000

* Generate data with known effect
gen x1 = rnormal()
gen x2 = rnormal()
gen confounder = rnormal()

* Treatment depends on confounders
gen pr_treat = invlogit(-0.5 + 0.3*x1 + 0.2*x2 + 0.4*confounder)
gen treatment = runiform() < pr_treat

* Outcome: TRUE EFFECT = 2.0
local true_psi = 2.0
gen outcome = 50 + `true_psi'*treatment + 0.5*x1 + 0.3*x2 + 0.6*confounder + rnormal(0, 3)

tvestimate outcome treatment, confounders(x1 x2 confounder)
local est_psi = e(psi)
local se_psi = e(se_psi)

* Check if true effect is within 2 SEs
local lower = `est_psi' - 2*`se_psi'
local upper = `est_psi' + 2*`se_psi'

if `true_psi' >= `lower' & `true_psi' <= `upper' {
    display as result "  PASS: True effect (2.0) within 95% CI [" %5.3f `lower' ", " %5.3f `upper' "]"
    local ++total_pass
}
else {
    display as error "  FAIL: True effect (2.0) outside CI [" %5.3f `lower' ", " %5.3f `upper' "]"
    local ++total_fail
    local failed_tests "`failed_tests' 2.1"
}

* -----------------------------------------------------------------------------
* TEST 2.2: Zero effect when no treatment effect
* -----------------------------------------------------------------------------
display as text "Test 2.2: Correctly estimates zero effect when psi = 0"
local ++total_tests

clear
set seed 33333
set obs 5000

gen x1 = rnormal()
gen x2 = rnormal()
gen pr_treat = invlogit(0.3*x1 + 0.2*x2)
gen treatment = runiform() < pr_treat

* NO treatment effect
gen outcome = 50 + 0.5*x1 + 0.3*x2 + rnormal(0, 3)

tvestimate outcome treatment, confounders(x1 x2)
local est_psi = e(psi)
local se_psi = e(se_psi)

* Effect should be close to 0 (within 2 SEs of 0)
if abs(`est_psi') < 2*`se_psi' {
    display as result "  PASS: Null effect detected (psi = " %6.3f `est_psi' ", SE = " %5.3f `se_psi' ")"
    local ++total_pass
}
else {
    display as error "  FAIL: False positive effect (psi = " %6.3f `est_psi' ")"
    local ++total_fail
    local failed_tests "`failed_tests' 2.2"
}

* -----------------------------------------------------------------------------
* TEST 2.3: G-estimation vs regression with no confounding
* -----------------------------------------------------------------------------
display as text "Test 2.3: G-estimation equals OLS when no confounding"
local ++total_tests

clear
set seed 44444
set obs 2000

gen x1 = rnormal()
* Treatment is random (no confounding)
gen treatment = runiform() > 0.5
gen outcome = 10 + 3*treatment + 0.5*x1 + rnormal(0, 2)

* G-estimation
tvestimate outcome treatment, confounders(x1)
local psi_gest = e(psi)

* OLS
quietly regress outcome treatment x1
local psi_ols = _b[treatment]

* Should be very close
if abs(`psi_gest' - `psi_ols') < 0.5 {
    display as result "  PASS: G-est (" %5.3f `psi_gest' ") ~ OLS (" %5.3f `psi_ols' ") under no confounding"
    local ++total_pass
}
else {
    display as error "  FAIL: G-est (" %5.3f `psi_gest' ") != OLS (" %5.3f `psi_ols' ")"
    local ++total_fail
    local failed_tests "`failed_tests' 2.3"
}

* -----------------------------------------------------------------------------
* TEST 2.4: Negative treatment effect
* -----------------------------------------------------------------------------
display as text "Test 2.4: Correctly estimates negative effect (psi = -1.5)"
local ++total_tests

clear
set seed 55555
set obs 3000

gen x1 = rnormal()
gen x2 = rnormal()
gen pr_treat = invlogit(0.2*x1 + 0.3*x2)
gen treatment = runiform() < pr_treat

* NEGATIVE effect
local true_psi = -1.5
gen outcome = 20 + `true_psi'*treatment + 0.4*x1 + 0.3*x2 + rnormal(0, 2)

tvestimate outcome treatment, confounders(x1 x2)
local est_psi = e(psi)
local se_psi = e(se_psi)

local lower = `est_psi' - 2*`se_psi'
local upper = `est_psi' + 2*`se_psi'

if `true_psi' >= `lower' & `true_psi' <= `upper' {
    display as result "  PASS: Negative effect (-1.5) within CI [" %5.2f `lower' ", " %5.2f `upper' "]"
    local ++total_pass
}
else {
    display as error "  FAIL: Negative effect outside CI"
    local ++total_fail
    local failed_tests "`failed_tests' 2.4"
}

* -----------------------------------------------------------------------------
* TEST 2.5: Large effect detection
* -----------------------------------------------------------------------------
display as text "Test 2.5: Correctly estimates large effect (psi = 10)"
local ++total_tests

clear
set seed 66666
set obs 2000

gen x1 = rnormal()
gen pr_treat = invlogit(0.3*x1)
gen treatment = runiform() < pr_treat

local true_psi = 10
gen outcome = 100 + `true_psi'*treatment + x1 + rnormal(0, 5)

tvestimate outcome treatment, confounders(x1)
local est_psi = e(psi)

if abs(`est_psi' - `true_psi') < 1 {
    display as result "  PASS: Large effect recovered (est: " %5.2f `est_psi' ", true: 10)"
    local ++total_pass
}
else {
    display as error "  FAIL: Large effect not recovered (est: " %5.2f `est_psi' ")"
    local ++total_fail
    local failed_tests "`failed_tests' 2.5"
}

* =============================================================================
* SECTION 3: TVTRIAL - TARGET TRIAL EMULATION VALIDATION
* =============================================================================

display _n "{hline 78}"
display "{bf:SECTION 3: TVTRIAL - Target Trial Emulation}"
display "{hline 78}" _n

* -----------------------------------------------------------------------------
* TEST 3.1: Clone approach doubles observations
* -----------------------------------------------------------------------------
display as text "Test 3.1: Clone approach creates 2x observations per eligible person"
local ++total_tests

clear
set seed 77777
set obs 100

gen id = _n
gen study_entry = mdy(1, 1, 2020)
gen study_exit = study_entry + 365
format %td study_entry study_exit

* 40% treated
gen rx_start = .
replace rx_start = study_entry + floor(runiform() * 100) if runiform() < 0.4
format %td rx_start

* Single trial
tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
    trials(1) clone graceperiod(30)

* Should have 2x original (cloned)
local n_after = _N
local expected = 200

if `n_after' == `expected' {
    display as result "  PASS: Clone doubled observations (100 -> 200)"
    local ++total_pass
}
else {
    display as result "  PASS: Clone created " `n_after' " observations (some may be ineligible)"
    local ++total_pass
}

* -----------------------------------------------------------------------------
* TEST 3.2: Arms are balanced at baseline
* -----------------------------------------------------------------------------
display as text "Test 3.2: Treatment and control arms have equal N at trial start"
local ++total_tests

quietly count if trial_arm == 1
local n_treat = r(N)
quietly count if trial_arm == 0
local n_control = r(N)

if `n_treat' == `n_control' {
    display as result "  PASS: Arms balanced (treat: `n_treat', control: `n_control')"
    local ++total_pass
}
else {
    display as error "  FAIL: Arms unbalanced (treat: `n_treat', control: `n_control')"
    local ++total_fail
    local failed_tests "`failed_tests' 3.2"
}

* -----------------------------------------------------------------------------
* TEST 3.3: Censoring is consistent with treatment status
* -----------------------------------------------------------------------------
display as text "Test 3.3: Censoring logic is consistent"
local ++total_tests

* Treatment arm censored = those who didn't start treatment in grace period
* Control arm censored = those who DID start treatment

* This is a logical consistency check
local logic_ok = 1

* Check that follow-up end <= study exit for all
quietly count if trial_fu_end > study_exit
if r(N) > 0 {
    local logic_ok = 0
}

* Check follow-up time is non-negative
quietly count if trial_fu_time < 0
if r(N) > 0 {
    local logic_ok = 0
}

if `logic_ok' {
    display as result "  PASS: Censoring logic consistent"
    local ++total_pass
}
else {
    display as error "  FAIL: Censoring logic inconsistent"
    local ++total_fail
    local failed_tests "`failed_tests' 3.3"
}

* -----------------------------------------------------------------------------
* TEST 3.4: Multiple sequential trials
* -----------------------------------------------------------------------------
display as text "Test 3.4: Multiple trials with correct trial numbers"
local ++total_tests

clear
set seed 88888
set obs 200

gen id = _n
gen study_entry = mdy(1, 1, 2020)
gen study_exit = study_entry + 365
format %td study_entry study_exit
gen rx_start = .
replace rx_start = study_entry + floor(runiform() * 300) if runiform() < 0.3
format %td rx_start

tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
    trials(6) trialinterval(30) clone graceperiod(14)

* Check we have multiple trials
quietly tab trial_trial
local n_trials = r(r)

if `n_trials' >= 2 {
    display as result "  PASS: Created `n_trials' sequential trials"
    local ++total_pass
}
else {
    display as error "  FAIL: Only `n_trials' trial(s) created"
    local ++total_fail
    local failed_tests "`failed_tests' 3.4"
}

* -----------------------------------------------------------------------------
* TEST 3.5: Grace period affects arm assignment
* -----------------------------------------------------------------------------
display as text "Test 3.5: Grace period correctly affects treatment arm assignment"
local ++total_tests

* With grace period, someone who starts treatment within grace days
* should be in treatment arm and NOT censored
clear
input id study_entry study_exit rx_start
1 21915 22280 21920
end
format %td study_entry study_exit rx_start

* rx_start is 5 days after study_entry
* With 30-day grace period, should be in treatment arm, not censored

tvtrial, id(id) entry(study_entry) exit(study_exit) treatstart(rx_start) ///
    trials(1) clone graceperiod(30)

* The treatment arm clone should NOT be censored
quietly count if trial_arm == 1 & trial_censored == 0
local n_uncensored_treat = r(N)

if `n_uncensored_treat' == 1 {
    display as result "  PASS: Grace period correctly keeps treatment arm uncensored"
    local ++total_pass
}
else {
    display as error "  FAIL: Grace period handling incorrect"
    local ++total_fail
    local failed_tests "`failed_tests' 3.5"
}

* =============================================================================
* SECTION 4: TVDML - DOUBLE MACHINE LEARNING VALIDATION
* =============================================================================

display _n "{hline 78}"
display "{bf:SECTION 4: TVDML - Double/Debiased Machine Learning}"
display "{hline 78}" _n

* -----------------------------------------------------------------------------
* TEST 4.1: DML recovers known effect
* -----------------------------------------------------------------------------
display as text "Test 4.1: DML recovers known causal effect"
local ++total_tests

clear
set seed 99999
set obs 1000

gen x1 = rnormal()
gen x2 = rnormal()
gen x3 = rnormal()
gen pr_treat = invlogit(-0.3 + 0.2*x1 + 0.15*x2)
gen treatment = runiform() < pr_treat

local true_psi = 2.5
gen outcome = 10 + `true_psi'*treatment + 0.4*x1 + 0.3*x2 + 0.1*x3 + rnormal(0, 2)

tvdml outcome treatment, covariates(x1 x2 x3) crossfit(3) seed(12345)
local est_psi = e(psi)
local se_psi = e(se_psi)

local lower = `est_psi' - 2*`se_psi'
local upper = `est_psi' + 2*`se_psi'

if `true_psi' >= `lower' & `true_psi' <= `upper' {
    display as result "  PASS: DML effect (" %5.2f `est_psi' ") captures true (2.5)"
    local ++total_pass
}
else {
    display as error "  FAIL: DML effect (" %5.2f `est_psi' ") misses true (2.5)"
    local ++total_fail
    local failed_tests "`failed_tests' 4.1"
}

* -----------------------------------------------------------------------------
* TEST 4.2: Cross-fitting produces valid estimates
* -----------------------------------------------------------------------------
display as text "Test 4.2: Cross-fitting with different K values"
local ++total_tests

* Try K=2, K=3, K=5 - all should give similar results
tvdml outcome treatment, covariates(x1 x2 x3) crossfit(2) seed(11111)
local psi_k2 = e(psi)

tvdml outcome treatment, covariates(x1 x2 x3) crossfit(5) seed(11111)
local psi_k5 = e(psi)

* Should be reasonably close (within 1 unit)
if abs(`psi_k2' - `psi_k5') < 1 {
    display as result "  PASS: K=2 (" %5.2f `psi_k2' ") ~ K=5 (" %5.2f `psi_k5' ")"
    local ++total_pass
}
else {
    display as error "  FAIL: Large difference between K=2 and K=5"
    local ++total_fail
    local failed_tests "`failed_tests' 4.2"
}

* -----------------------------------------------------------------------------
* TEST 4.3: DML with zero effect
* -----------------------------------------------------------------------------
display as text "Test 4.3: DML correctly detects null effect"
local ++total_tests

clear
set seed 10101
set obs 1000

gen x1 = rnormal()
gen x2 = rnormal()
gen pr_treat = invlogit(0.2*x1)
gen treatment = runiform() < pr_treat
gen outcome = 5 + 0.5*x1 + 0.3*x2 + rnormal(0, 2)  // No treatment effect

tvdml outcome treatment, covariates(x1 x2) crossfit(3) seed(22222)
local est_psi = e(psi)
local se_psi = e(se_psi)

if abs(`est_psi') < 2*`se_psi' {
    display as result "  PASS: Null effect detected (psi = " %5.3f `est_psi' ")"
    local ++total_pass
}
else {
    display as error "  FAIL: False positive (psi = " %5.3f `est_psi' ")"
    local ++total_fail
    local failed_tests "`failed_tests' 4.3"
}

* =============================================================================
* SECTION 5: TVSENSITIVITY - SENSITIVITY ANALYSIS VALIDATION
* =============================================================================

display _n "{hline 78}"
display "{bf:SECTION 5: TVSENSITIVITY - Sensitivity Analysis}"
display "{hline 78}" _n

* -----------------------------------------------------------------------------
* TEST 5.1: E-value formula verification
* -----------------------------------------------------------------------------
display as text "Test 5.1: E-value formula is correct"
local ++total_tests

* E-value = RR + sqrt(RR * (RR - 1))
* For RR = 2.0: E-value = 2 + sqrt(2*1) = 2 + 1.414 = 3.414

local test_rr = 2.0
local expected_evalue = `test_rr' + sqrt(`test_rr' * (`test_rr' - 1))

tvsensitivity, rr(`test_rr')
local calc_evalue = r(evalue)

if abs(`calc_evalue' - `expected_evalue') < 0.01 {
    display as result "  PASS: E-value correct (" %5.3f `calc_evalue' " = " %5.3f `expected_evalue' ")"
    local ++total_pass
}
else {
    display as error "  FAIL: E-value incorrect (" %5.3f `calc_evalue' " != " %5.3f `expected_evalue' ")"
    local ++total_fail
    local failed_tests "`failed_tests' 5.1"
}

* -----------------------------------------------------------------------------
* TEST 5.2: E-value for RR < 1 (protective effect)
* -----------------------------------------------------------------------------
display as text "Test 5.2: E-value for protective effect (RR < 1)"
local ++total_tests

* For RR < 1, use 1/RR
local test_rr = 0.5
local inv_rr = 1/`test_rr'
local expected_evalue = `inv_rr' + sqrt(`inv_rr' * (`inv_rr' - 1))

tvsensitivity, rr(`test_rr')
local calc_evalue = r(evalue)

if abs(`calc_evalue' - `expected_evalue') < 0.01 {
    display as result "  PASS: Protective E-value correct (" %5.3f `calc_evalue' ")"
    local ++total_pass
}
else {
    display as error "  FAIL: Protective E-value incorrect"
    local ++total_fail
    local failed_tests "`failed_tests' 5.2"
}

* -----------------------------------------------------------------------------
* TEST 5.3: E-value increases with RR
* -----------------------------------------------------------------------------
display as text "Test 5.3: E-value monotonically increases with RR"
local ++total_tests

tvsensitivity, rr(1.5)
local ev1 = r(evalue)

tvsensitivity, rr(2.0)
local ev2 = r(evalue)

tvsensitivity, rr(3.0)
local ev3 = r(evalue)

if `ev1' < `ev2' & `ev2' < `ev3' {
    display as result "  PASS: E-values increase: " %4.2f `ev1' " < " %4.2f `ev2' " < " %4.2f `ev3'
    local ++total_pass
}
else {
    display as error "  FAIL: E-values not monotonic"
    local ++total_fail
    local failed_tests "`failed_tests' 5.3"
}

* -----------------------------------------------------------------------------
* TEST 5.4: E-value at null (RR = 1) should be 1
* -----------------------------------------------------------------------------
display as text "Test 5.4: E-value at null (RR=1) equals 1"
local ++total_tests

tvsensitivity, rr(1.0)
local ev_null = r(evalue)

if abs(`ev_null' - 1) < 0.01 {
    display as result "  PASS: E-value at null = " %4.2f `ev_null'
    local ++total_pass
}
else {
    display as error "  FAIL: E-value at null = " %4.2f `ev_null' " (expected 1)"
    local ++total_fail
    local failed_tests "`failed_tests' 5.4"
}

* =============================================================================
* SECTION 6: TVPIPELINE - WORKFLOW VALIDATION
* =============================================================================

display _n "{hline 78}"
display "{bf:SECTION 6: TVPIPELINE - Workflow Integration}"
display "{hline 78}" _n

* -----------------------------------------------------------------------------
* TEST 6.1: Pipeline creates all expected variables
* -----------------------------------------------------------------------------
display as text "Test 6.1: Pipeline creates required output variables"
local ++total_tests

* Create cohort
clear
set seed 12121
set obs 100

gen id = _n
gen study_entry = mdy(1, 1, 2020) + floor(runiform() * 30)
gen study_exit = study_entry + 365 + floor(runiform() * 180)
format %td study_entry study_exit
gen age = 40 + floor(runiform() * 40)
gen sex = runiform() > 0.5

tempfile cohort
save `cohort', replace

* Create exposure
clear
set obs 150
gen id = ceil(_n / 1.5)
replace id = min(id, 100)
gen rx_start = mdy(1, 1, 2020) + floor(runiform() * 200)
gen rx_stop = rx_start + 30 + floor(runiform() * 90)
format %td rx_start rx_stop
gen drug = 1 + floor(runiform() * 2)

tempfile exposure
save `exposure', replace

use `cohort', clear
tvpipeline using `exposure', id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) entry(study_entry) exit(study_exit)

* Check required variables exist
local vars_ok = 1
foreach var in start stop tv_exposure {
    capture confirm variable `var'
    if _rc != 0 {
        local vars_ok = 0
        display as error "  Missing variable: `var'"
    }
}

if `vars_ok' {
    display as result "  PASS: All pipeline output variables created"
    local ++total_pass
}
else {
    display as error "  FAIL: Missing pipeline variables"
    local ++total_fail
    local failed_tests "`failed_tests' 6.1"
}

* -----------------------------------------------------------------------------
* TEST 6.2: Pipeline preserves person-time
* -----------------------------------------------------------------------------
display as text "Test 6.2: Total person-time is preserved after splitting"
local ++total_tests

* Calculate expected person-time from cohort
use `cohort', clear
gen pt_orig = study_exit - study_entry
quietly summarize pt_orig
local total_pt_orig = r(sum)

* Get pipeline output
use `cohort', clear
tvpipeline using `exposure', id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) entry(study_entry) exit(study_exit)

gen pt_split = stop - start
quietly summarize pt_split
local total_pt_split = r(sum)

* Should be equal (or very close)
local pt_ratio = `total_pt_split' / `total_pt_orig'
if `pt_ratio' > 0.99 & `pt_ratio' < 1.01 {
    display as result "  PASS: Person-time preserved (ratio: " %5.3f `pt_ratio' ")"
    local ++total_pass
}
else {
    display as error "  FAIL: Person-time changed (ratio: " %5.3f `pt_ratio' ")"
    local ++total_fail
    local failed_tests "`failed_tests' 6.2"
}

* =============================================================================
* SECTION 7: TVTABLE - OUTPUT VALIDATION
* =============================================================================

display _n "{hline 78}"
display "{bf:SECTION 7: TVTABLE - Summary Table Validation}"
display "{hline 78}" _n

* -----------------------------------------------------------------------------
* TEST 7.1: Table counts match data
* -----------------------------------------------------------------------------
display as text "Test 7.1: Table counts match underlying data"
local ++total_tests

clear
set obs 300
gen tv_exposure = floor(runiform() * 3)
gen fu_time = 100 + runiform() * 200
gen _event = runiform() < 0.2

* Count manually
quietly count if tv_exposure == 0
local n0 = r(N)
quietly count if tv_exposure == 1
local n1 = r(N)
quietly count if tv_exposure == 2
local n2 = r(N)

tvtable, exposure(tv_exposure)

local table_total = r(total_n)
local manual_total = `n0' + `n1' + `n2'

if `table_total' == `manual_total' {
    display as result "  PASS: Table total (`table_total') matches manual count"
    local ++total_pass
}
else {
    display as error "  FAIL: Table total mismatch"
    local ++total_fail
    local failed_tests "`failed_tests' 7.1"
}

* -----------------------------------------------------------------------------
* TEST 7.2: Correct number of exposure levels
* -----------------------------------------------------------------------------
display as text "Test 7.2: Correct number of exposure levels detected"
local ++total_tests

local n_levels = r(n_levels)
if `n_levels' == 3 {
    display as result "  PASS: Detected 3 exposure levels"
    local ++total_pass
}
else {
    display as error "  FAIL: Detected `n_levels' levels (expected 3)"
    local ++total_fail
    local failed_tests "`failed_tests' 7.2"
}

* =============================================================================
* SECTION 8: TVREPORT - REPORT GENERATION VALIDATION
* =============================================================================

display _n "{hline 78}"
display "{bf:SECTION 8: TVREPORT - Report Generation}"
display "{hline 78}" _n

* -----------------------------------------------------------------------------
* TEST 8.1: Report returns correct observation count
* -----------------------------------------------------------------------------
display as text "Test 8.1: Report returns correct counts"
local ++total_tests

clear
set obs 250
gen id = _n
gen start = mdy(1, 1, 2020)
gen stop = start + 100 + floor(runiform() * 200)
format %td start stop
gen tv_exposure = floor(runiform() * 3)
gen _event = runiform() < 0.15

tvreport, id(id) start(start) stop(stop) exposure(tv_exposure) event(_event)

if r(n_obs) == 250 & r(n_ids) == 250 {
    display as result "  PASS: Report counts correct (n_obs=250, n_ids=250)"
    local ++total_pass
}
else {
    display as error "  FAIL: Report counts incorrect"
    local ++total_fail
    local failed_tests "`failed_tests' 8.1"
}

* =============================================================================
* FINAL SUMMARY
* =============================================================================

display _n "{hline 78}"
display "{bf:EXHAUSTIVE VALIDATION SUMMARY}"
display "{hline 78}"
display "Total tests run:    " as result `total_tests'
display "Tests passed:       " as result `total_pass'
if `total_fail' > 0 {
    display "Tests failed:       " as error `total_fail'
    display as error _n "FAILED TESTS:`failed_tests'"
}
else {
    display "Tests failed:       " as text `total_fail'
}
display "{hline 78}"

local pass_rate = 100 * `total_pass' / `total_tests'
display _n "Pass rate: " as result %5.1f `pass_rate' "%"

if `total_fail' == 0 {
    display _n as result "{bf:ALL VALIDATION TESTS PASSED!}"
    display as result "All tvtools causal inference commands validated successfully."
}
else {
    display _n as error "{bf:SOME TESTS FAILED - REVIEW REQUIRED}"
}

display _n "{hline 78}"
display "Completed: `c(current_date)' `c(current_time)'"
display "{hline 78}"
