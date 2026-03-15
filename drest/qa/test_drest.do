* test_drest.do
* Functional test suite for drest package v3.0.0
* Tests: dispatcher, estimate, diagnose, compare, predict, report, sensitivity,
*   crossfit, TMLE, LTMLE, bootstrap, plot, error paths, edge cases
* Author: Timothy P Copeland
* Date: 2026-03-15

clear all
set more off

local pass = 0
local fail = 0
local test_num = 0

capture log close _all

* ============================================================================
* SETUP: Uninstall any existing drest, install from local
* ============================================================================
capture ado uninstall drest
net install drest, from("/home/tpcopeland/Stata-Dev/drest") replace

* ============================================================================
* GENERATE TEST DATA
* ============================================================================
* Simulate data with known treatment effect for validation
clear
set seed 20260315
set obs 500

* Covariates
gen double x1 = rnormal(0, 1)
gen double x2 = rnormal(0, 1)
gen double x3 = rnormal(0, 1)

* Treatment assignment (PS depends on x1 and x2)
gen double ps_true = invlogit(0.5 * x1 + 0.3 * x2)
gen byte treat = runiform() < ps_true

* Potential outcomes (true ATE = 2.0)
gen double y0 = 1 + 0.5 * x1 + 0.3 * x2 + 0.2 * x3 + rnormal(0, 1)
gen double y1 = y0 + 2.0
gen double y = cond(treat == 1, y1, y0)

* ============================================================================
* TEST 1: Dispatcher - basic
* ============================================================================
local ++test_num
capture noisily drest
if _rc == 0 & "`r(version)'" == "3.0.0" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - drest dispatcher basic"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - drest dispatcher basic"
}

* ============================================================================
* TEST 2: Dispatcher - list mode
* ============================================================================
local ++test_num
capture noisily drest, list
if _rc == 0 & r(n_commands) == 11 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - drest dispatcher list"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - drest dispatcher list"
}

* ============================================================================
* TEST 3: Dispatcher - detail mode
* ============================================================================
local ++test_num
capture noisily drest, detail
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - drest dispatcher detail"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - drest dispatcher detail"
}

* ============================================================================
* TEST 4: Estimate - basic with shared covariates
* ============================================================================
local ++test_num
capture noisily drest_estimate x1 x2, outcome(y) treatment(treat)
if _rc == 0 & "`e(cmd)'" == "drest_estimate" & "`e(method)'" == "aipw" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - drest_estimate basic"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - drest_estimate basic (rc=`=_rc')"
}

* ============================================================================
* TEST 5: Estimate - eclass results stored
* ============================================================================
local ++test_num
local est_ok = 1
if "`e(outcome)'" != "y" local est_ok = 0
if "`e(treatment)'" != "treat" local est_ok = 0
if "`e(estimand)'" != "ATE" local est_ok = 0
if e(N) != 500 local est_ok = 0
if e(se) <= 0 local est_ok = 0

if `est_ok' {
    local ++pass
    display "RESULT: Test `test_num' PASSED - eclass results correct"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - eclass results"
}

* ============================================================================
* TEST 6: Estimate - ATE recovery (should be near 2.0)
* ============================================================================
local ++test_num
local ate_est = e(tau)
if abs(`ate_est' - 2.0) < 0.5 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - ATE near true value (est=" %5.3f `ate_est' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - ATE=" %5.3f `ate_est' " (expected ~2.0)"
}

* ============================================================================
* TEST 7: Generated variables exist
* ============================================================================
local ++test_num
local vars_ok = 1
foreach v in _drest_ps _drest_mu1 _drest_mu0 _drest_if _drest_esample {
    capture confirm variable `v'
    if _rc local vars_ok = 0
}
if `vars_ok' {
    local ++pass
    display "RESULT: Test `test_num' PASSED - generated variables exist"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - missing generated variables"
}

* ============================================================================
* TEST 8: Dataset characteristics stored
* ============================================================================
local ++test_num
local chars_ok = 1
local est_char : char _dta[_drest_estimated]
local method_char : char _dta[_drest_method]
if "`est_char'" != "1" local chars_ok = 0
if "`method_char'" != "aipw" local chars_ok = 0
if `chars_ok' {
    local ++pass
    display "RESULT: Test `test_num' PASSED - dataset characteristics stored"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - dataset characteristics"
}

* ============================================================================
* TEST 9: Estimate - separate model specs
* ============================================================================
local ++test_num
capture noisily drest_estimate, outcome(y) treatment(treat) ///
    omodel(x1 x2 x3) tmodel(x1 x2) nolog
if _rc == 0 & "`e(omodel)'" == "x1 x2 x3" & "`e(tmodel)'" == "x1 x2" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - separate model specs"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - separate model specs (rc=`=_rc')"
}

* ============================================================================
* TEST 10: Estimate - ATT estimand
* ============================================================================
local ++test_num
capture noisily drest_estimate x1 x2, outcome(y) treatment(treat) estimand(ATT) nolog
if _rc == 0 & "`e(estimand)'" == "ATT" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - ATT estimand"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - ATT estimand"
}

* ============================================================================
* TEST 11: Estimate - ATC estimand
* ============================================================================
local ++test_num
capture noisily drest_estimate x1 x2, outcome(y) treatment(treat) estimand(ATC) nolog
if _rc == 0 & "`e(estimand)'" == "ATC" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - ATC estimand"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - ATC estimand"
}

* ============================================================================
* TEST 12: Estimate - probit treatment model
* ============================================================================
local ++test_num
capture noisily drest_estimate x1 x2, outcome(y) treatment(treat) tfamily(probit) nolog
if _rc == 0 & "`e(tfamily)'" == "probit" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - probit treatment model"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - probit treatment model"
}

* ============================================================================
* TEST 13: Estimate - no trimming
* ============================================================================
local ++test_num
capture noisily drest_estimate x1 x2, outcome(y) treatment(treat) trimps(0) nolog
if _rc == 0 & e(n_trimmed) == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - no PS trimming"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - no PS trimming"
}

* ============================================================================
* TEST 14: Estimate - custom CI level
* ============================================================================
local ++test_num
capture noisily drest_estimate x1 x2, outcome(y) treatment(treat) level(90) nolog
if _rc == 0 & e(level) == 90 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - custom CI level"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - custom CI level"
}

* ============================================================================
* TEST 15: Estimate - binary outcome
* ============================================================================
local ++test_num
gen byte y_bin = (y > 3)
capture noisily drest_estimate x1 x2, outcome(y_bin) treatment(treat) nolog
if _rc == 0 & "`e(ofamily)'" == "logit" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - binary outcome auto-detection"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - binary outcome (rc=`=_rc')"
}
drop y_bin

* Re-run standard estimate for remaining tests
quietly drest_estimate x1 x2, outcome(y) treatment(treat) nolog

* ============================================================================
* TEST 16: Diagnose - all diagnostics
* ============================================================================
local ++test_num
capture noisily drest_diagnose, all
if _rc == 0 & r(ess) > 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - drest_diagnose all"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - drest_diagnose all (rc=`=_rc')"
}

* ============================================================================
* TEST 17: Diagnose - propensity only
* ============================================================================
local ++test_num
capture noisily drest_diagnose, propensity
if _rc == 0 & r(ps_mean) > 0 & r(ps_mean) < 1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - diagnose propensity"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - diagnose propensity"
}

* ============================================================================
* TEST 18: Diagnose - influence only
* ============================================================================
local ++test_num
capture noisily drest_diagnose, influence
if _rc == 0 & r(if_sd) > 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - diagnose influence"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - diagnose influence"
}

* ============================================================================
* TEST 19: Diagnose - balance only
* ============================================================================
local ++test_num
capture noisily drest_diagnose, balance
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - diagnose balance"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - diagnose balance (rc=`=_rc')"
}

* ============================================================================
* TEST 20: Compare - all three methods
* ============================================================================
local ++test_num
capture noisily drest_compare x1 x2, outcome(y) treatment(treat)
if _rc == 0 & r(N) == 500 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - drest_compare all methods"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - drest_compare (rc=`=_rc')"
}

* ============================================================================
* TEST 21: Compare - subset of methods
* ============================================================================
local ++test_num
capture noisily drest_compare x1 x2, outcome(y) treatment(treat) methods(iptw aipw)
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - compare subset methods"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - compare subset methods"
}

* ============================================================================
* TEST 22: Compare - matrix returned
* ============================================================================
local ++test_num
capture noisily drest_compare x1 x2, outcome(y) treatment(treat)
capture matrix list r(comparison)
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - comparison matrix returned"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - comparison matrix"
}

* ============================================================================
* TEST 23: Predict - all predictions
* ============================================================================
local ++test_num
quietly drest_estimate x1 x2, outcome(y) treatment(treat) nolog
capture noisily drest_predict, mu1(y1hat) mu0(y0hat) ite(tau_i) ps(pscore)
local pred_ok = 1
foreach v in y1hat y0hat tau_i pscore {
    capture confirm variable `v'
    if _rc local pred_ok = 0
}
if _rc == 0 & `pred_ok' {
    local ++pass
    display "RESULT: Test `test_num' PASSED - predict all"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - predict all"
}
capture drop y1hat y0hat tau_i pscore

* ============================================================================
* TEST 24: Predict - replace option
* ============================================================================
local ++test_num
capture noisily drest_predict, mu1(y1hat)
capture noisily drest_predict, mu1(y1hat) replace
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - predict replace"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - predict replace"
}
capture drop y1hat

* ============================================================================
* TEST 25: Report - display
* ============================================================================
local ++test_num
capture noisily drest_report
if _rc == 0 & r(N) == 500 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - report display"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - report display"
}

* ============================================================================
* TEST 26: Report - detail
* ============================================================================
local ++test_num
capture noisily drest_report, detail
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - report detail"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - report detail"
}

* ============================================================================
* TEST 27: Report - Excel export
* ============================================================================
local ++test_num
tempfile xlout
capture noisily drest_report, excel("`xlout'.xlsx") replace
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - report Excel export"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - report Excel (rc=`=_rc')"
}

* ============================================================================
* TEST 28: Sensitivity - E-value
* ============================================================================
local ++test_num
capture noisily drest_sensitivity, evalue
if _rc == 0 & r(evalue) > 1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - sensitivity E-value"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - sensitivity E-value (rc=`=_rc')"
}

* ============================================================================
* TEST 29: Sensitivity - with detail
* ============================================================================
local ++test_num
capture noisily drest_sensitivity, evalue detail
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - sensitivity detail"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - sensitivity detail"
}

* ============================================================================
* ERROR HANDLING TESTS
* ============================================================================

* TEST 30: Error - no covariates
local ++test_num
capture noisily drest_estimate, outcome(y) treatment(treat)
if _rc != 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - error: no covariates"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - should error without covariates"
}

* TEST 31: Error - non-binary treatment
local ++test_num
gen double fake_treat = rnormal()
capture noisily drest_estimate x1 x2, outcome(y) treatment(fake_treat)
if _rc != 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - error: non-binary treatment"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - should error with continuous treatment"
}
drop fake_treat

* TEST 32: Error - invalid estimand
local ++test_num
capture noisily drest_estimate x1 x2, outcome(y) treatment(treat) estimand(INVALID)
if _rc != 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - error: invalid estimand"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - should error with invalid estimand"
}

* TEST 33: Error - diagnose before estimate
local ++test_num
preserve
clear
set obs 10
gen x1 = rnormal()
capture noisily drest_diagnose
if _rc != 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - error: diagnose before estimate"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - should error without prior estimate"
}
restore

* TEST 34: Error - invalid ofamily
local ++test_num
capture noisily drest_estimate x1 x2, outcome(y) treatment(treat) ofamily(gamma)
if _rc != 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - error: invalid ofamily"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - should error with invalid ofamily"
}

* TEST 35: Error - invalid tfamily
local ++test_num
capture noisily drest_estimate x1 x2, outcome(y) treatment(treat) tfamily(poisson)
if _rc != 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - error: invalid tfamily"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - should error with invalid tfamily"
}

* ============================================================================
* TEST 36: if/in subset
* ============================================================================
local ++test_num
capture noisily drest_estimate x1 x2 if x3 > 0, outcome(y) treatment(treat) nolog
if _rc == 0 & e(N) < 500 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - if condition (N=" e(N) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - if condition"
}

* ============================================================================
* TEST 37: Poisson outcome model
* ============================================================================
local ++test_num
gen double y_count = max(0, round(exp(0.5 + 0.2*x1 + 0.3*treat + rnormal(0,0.5))))
capture noisily drest_estimate x1 x2, outcome(y_count) treatment(treat) ofamily(poisson) nolog
if _rc == 0 & "`e(ofamily)'" == "poisson" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - poisson outcome model"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - poisson outcome (rc=`=_rc')"
}
drop y_count

* ============================================================================
* TEST 38: e(b) and e(V) matrices
* ============================================================================
local ++test_num
quietly drest_estimate x1 x2, outcome(y) treatment(treat) nolog
capture matrix list e(b)
local rc1 = _rc
capture matrix list e(V)
local rc2 = _rc
if `rc1' == 0 & `rc2' == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - e(b) and e(V) matrices"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - e(b)/e(V) matrices"
}

* ============================================================================
* TEST 39: Compare - separate model specs
* ============================================================================
local ++test_num
capture noisily drest_compare, outcome(y) treatment(treat) omodel(x1 x2 x3) tmodel(x1 x2)
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - compare separate specs"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - compare separate specs (rc=`=_rc')"
}

* ============================================================================
* TEST 40: Predict - no options shows help
* ============================================================================
local ++test_num
quietly drest_estimate x1 x2, outcome(y) treatment(treat) nolog
capture noisily drest_predict
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - predict no options"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - predict no options"
}

* ============================================================================
* PHASE 2: CROSSFIT TESTS
* ============================================================================

* TEST 41: Crossfit - basic
local ++test_num
capture noisily drest_crossfit x1 x2, outcome(y) treatment(treat) folds(5) seed(42) nolog
if _rc == 0 & "`e(cmd)'" == "drest_crossfit" & "`e(method)'" == "aipw_crossfit" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - crossfit basic"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - crossfit basic (rc=`=_rc')"
}

* TEST 42: Crossfit - eclass results
local ++test_num
local cf_ok = 1
if e(folds) != 5 local cf_ok = 0
if e(N) != 500 local cf_ok = 0
if e(se) <= 0 local cf_ok = 0
if "`e(estimand)'" != "ATE" local cf_ok = 0
if `cf_ok' {
    local ++pass
    display "RESULT: Test `test_num' PASSED - crossfit eclass"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - crossfit eclass"
}

* TEST 43: Crossfit - seed reproducibility
local ++test_num
drest_crossfit x1 x2, outcome(y) treatment(treat) folds(3) seed(999) nolog
local cf1 = e(tau)
drest_crossfit x1 x2, outcome(y) treatment(treat) folds(3) seed(999) nolog
local cf2 = e(tau)
if `cf1' == `cf2' {
    local ++pass
    display "RESULT: Test `test_num' PASSED - crossfit seed reproducibility"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - crossfit seed repro (" %8.6f `cf1' " vs " %8.6f `cf2' ")"
}

* TEST 44: Crossfit - fold variable created
local ++test_num
capture confirm variable _drest_fold
if _rc == 0 {
    quietly summarize _drest_fold if _drest_esample == 1
    if r(min) >= 1 & r(max) <= 3 {
        local ++pass
        display "RESULT: Test `test_num' PASSED - fold variable created (range 1-3)"
    }
    else {
        local ++fail
        display "RESULT: Test `test_num' FAILED - fold range [" r(min) "," r(max) "]"
    }
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - _drest_fold missing"
}

* TEST 45: Crossfit - ATT estimand
local ++test_num
capture noisily drest_crossfit x1 x2, outcome(y) treatment(treat) estimand(ATT) folds(3) seed(42) nolog
if _rc == 0 & "`e(estimand)'" == "ATT" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - crossfit ATT"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - crossfit ATT"
}

* TEST 46: Crossfit - folds(2) minimum
local ++test_num
capture noisily drest_crossfit x1 x2, outcome(y) treatment(treat) folds(2) seed(42) nolog
if _rc == 0 & e(folds) == 2 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - crossfit folds(2)"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - crossfit folds(2)"
}

* TEST 47: Crossfit - error folds(1)
local ++test_num
capture noisily drest_crossfit x1 x2, outcome(y) treatment(treat) folds(1) nolog
if _rc != 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - error: folds(1)"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - should error with folds(1)"
}

* TEST 48: Crossfit - post-estimation works
local ++test_num
drest_crossfit x1 x2, outcome(y) treatment(treat) folds(3) seed(42) nolog
capture noisily drest_diagnose, propensity
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - diagnose after crossfit"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - diagnose after crossfit"
}

* ============================================================================
* PHASE 3: TMLE TESTS
* ============================================================================

* TEST 49: TMLE - basic continuous
local ++test_num
capture noisily drest_tmle x1 x2, outcome(y) treatment(treat) nolog
if _rc == 0 & "`e(cmd)'" == "drest_tmle" & "`e(method)'" == "tmle" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - TMLE basic continuous"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - TMLE basic (rc=`=_rc')"
}

* TEST 50: TMLE - converged
local ++test_num
if e(converged) == 1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - TMLE converged"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - TMLE not converged"
}

* TEST 51: TMLE - eclass results
local ++test_num
local tmle_ok = 1
if e(N) != 500 local tmle_ok = 0
if e(se) <= 0 local tmle_ok = 0
if e(n_iter) < 1 local tmle_ok = 0
if `tmle_ok' {
    local ++pass
    display "RESULT: Test `test_num' PASSED - TMLE eclass results"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - TMLE eclass"
}

* TEST 52: TMLE - binary outcome
local ++test_num
gen byte y_bin2 = (y > 3)
capture noisily drest_tmle x1 x2, outcome(y_bin2) treatment(treat) nolog
if _rc == 0 & e(converged) == 1 & e(po1) > 0 & e(po1) < 1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - TMLE binary (n_iter=" e(n_iter) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - TMLE binary"
}
drop y_bin2

* TEST 53: TMLE - crossfit suboption
local ++test_num
capture noisily drest_tmle x1 x2, outcome(y) treatment(treat) crossfit folds(3) seed(42) nolog
if _rc == 0 & "`e(method)'" == "tmle_crossfit" & e(folds) == 3 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - TMLE crossfit"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - TMLE crossfit"
}

* TEST 54: TMLE - error ATT
local ++test_num
capture noisily drest_tmle x1 x2, outcome(y) treatment(treat) estimand(ATT) nolog
if _rc == 198 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - error: TMLE ATT not supported"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - TMLE ATT should error (rc=`=_rc')"
}

* TEST 55: TMLE - custom iterate and tolerance
local ++test_num
capture noisily drest_tmle x1 x2, outcome(y) treatment(treat) iterate(50) tolerance(1e-8) nolog
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - TMLE custom iterate/tolerance"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - TMLE iterate/tolerance"
}

* TEST 56: TMLE - post-estimation works
local ++test_num
drest_tmle x1 x2, outcome(y) treatment(treat) nolog
capture noisily drest_sensitivity, evalue
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - sensitivity after TMLE"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - sensitivity after TMLE"
}

* TEST 57: TMLE - separate model specs
local ++test_num
capture noisily drest_tmle, outcome(y) treatment(treat) omodel(x1 x2 x3) tmodel(x1 x2) nolog
if _rc == 0 & "`e(omodel)'" == "x1 x2 x3" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - TMLE separate model specs"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - TMLE separate specs"
}

* TEST 58: Crossfit - binary outcome
local ++test_num
gen byte yb = (y > 3)
capture noisily drest_crossfit x1 x2, outcome(yb) treatment(treat) folds(3) seed(42) nolog
if _rc == 0 & "`e(ofamily)'" == "logit" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - crossfit binary outcome"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - crossfit binary"
}
drop yb

* TEST 59: TMLE crossfit binary outcome
local ++test_num
gen byte yb2 = (y > 3)
capture noisily drest_tmle x1 x2, outcome(yb2) treatment(treat) crossfit folds(3) seed(42) nolog
if _rc == 0 & e(converged) == 1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - TMLE crossfit binary"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - TMLE crossfit binary"
}
drop yb2

* ============================================================================
* PHASE 4: LTMLE TESTS
* ============================================================================

* Generate longitudinal data
preserve
clear
set seed 20260315
set obs 1000
gen int id = ceil(_n / 4)
bysort id: gen int t = _n
gen double x1 = rnormal()
bysort id (t): gen double age = rnormal(50, 10) if _n == 1
bysort id (t): replace age = age[1]
gen byte a = runiform() < invlogit(-0.5 + 0.3*x1)
bysort id (t): gen double cum_a = sum(a)
gen byte y = runiform() < invlogit(-2 + 0.01*age + 0.2*x1 + 0.5*cum_a)
drop cum_a

* TEST 60: LTMLE - basic
local ++test_num
capture noisily drest_ltmle, id(id) period(t) outcome(y) treatment(a) covariates(x1) baseline(age) nolog
if _rc == 0 & "`e(cmd)'" == "drest_ltmle" & "`e(method)'" == "ltmle" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - LTMLE basic (tau=" %6.4f e(tau) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - LTMLE basic (rc=`=_rc')"
}

* TEST 61: LTMLE - eclass results
local ++test_num
local lt_ok = 1
if e(N_id) != 250 local lt_ok = 0
if e(T) != 4 local lt_ok = 0
if e(se) <= 0 local lt_ok = 0
if `lt_ok' {
    local ++pass
    display "RESULT: Test `test_num' PASSED - LTMLE eclass (N_id=" e(N_id) " T=" e(T) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - LTMLE eclass"
}

* TEST 62: LTMLE - PO probabilities in (0,1)
local ++test_num
if e(po_always) > 0 & e(po_always) < 1 & e(po_never) > 0 & e(po_never) < 1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - LTMLE POs in (0,1)"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - LTMLE PO out of bounds"
}

* TEST 63: LTMLE - regime(always)
local ++test_num
capture noisily drest_ltmle, id(id) period(t) outcome(y) treatment(a) covariates(x1) baseline(age) regime(always) nolog
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - LTMLE regime(always)"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - LTMLE regime(always)"
}

* TEST 64: LTMLE - with censoring
local ++test_num
gen byte c = runiform() < 0.03
capture noisily drest_ltmle, id(id) period(t) outcome(y) treatment(a) covariates(x1) baseline(age) censor(c) nolog
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - LTMLE with censoring"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - LTMLE censoring (rc=`=_rc')"
}
drop c

* TEST 65: LTMLE - error continuous outcome
local ++test_num
gen double y_cont = rnormal()
capture noisily drest_ltmle, id(id) period(t) outcome(y_cont) treatment(a) covariates(x1) nolog
if _rc == 198 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - error: LTMLE continuous outcome"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - should error with continuous (rc=`=_rc')"
}
drop y_cont

* TEST 66: LTMLE - error single period (skip preserve — tested in validation)
local ++test_num
capture noisily drest_ltmle, id(id) period(t) outcome(y) treatment(a) ///
    covariates(x1) regime(INVALID) nolog
if _rc == 198 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - error: invalid regime"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - invalid regime (rc=`=_rc')"
}

* TEST 67: Dispatcher shows 11 commands
local ++test_num
restore
drest
if r(n_commands) == 11 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - dispatcher shows 11 commands"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - n_commands=" r(n_commands)
}

* ============================================================================
* GAP-FILLING TESTS: options, error paths, edge cases
* (merged from test_drest_gaps.do)
* ============================================================================

* Generate binary outcome for gap tests
gen byte ybin = runiform() < invlogit(-1 + 0.5*x1 + 0.8*treat)

* ============================================================================
* G1: `in` RANGE SUBSETTING
* ============================================================================

local ++test_num
drest_estimate x1 x2 in 1/300, outcome(y) treatment(treat) nolog
if e(N) == 300 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G1 in range (N=300)"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G1 in range N=" e(N)
}

* ============================================================================
* G2: `level()` OPTION ACROSS COMMANDS
* ============================================================================

* G2.1: estimate level(99)
local ++test_num
drest_estimate x1 x2, outcome(y) treatment(treat) level(99) nolog
local ci99_width = e(ci_hi) - e(ci_lo)
drest_estimate x1 x2, outcome(y) treatment(treat) level(90) nolog
local ci90_width = e(ci_hi) - e(ci_lo)
if `ci99_width' > `ci90_width' & e(level) == 90 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G2.1 level(99) wider than level(90)"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G2.1 CI widths"
}

* G2.2: crossfit level(90)
local ++test_num
drest_crossfit x1 x2, outcome(y) treatment(treat) folds(3) seed(1) level(90) nolog
if e(level) == 90 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G2.2 crossfit level(90)"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G2.2 crossfit level"
}

* G2.3: tmle level(90)
local ++test_num
drest_tmle x1 x2, outcome(y) treatment(treat) level(90) nolog
if e(level) == 90 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G2.3 tmle level(90)"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G2.3 tmle level"
}

* G2.4: bootstrap level(90)
local ++test_num
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
drest_bootstrap, reps(50) seed(1) level(90) nolog
if e(level) == 90 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G2.4 bootstrap level(90)"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G2.4 bootstrap level"
}

* ============================================================================
* G3: drest_plot — ALL OPTIONS
* ============================================================================
drest_estimate x1 x2, outcome(y) treatment(treat) nolog

* G3.1: plot default (all)
local ++test_num
capture noisily drest_plot
if _rc == 0 & r(n_plots) == 3 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G3.1 plot default (3 plots)"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G3.1 plot default (rc=`=_rc')"
}
capture graph close _all

* G3.2: plot overlap only
local ++test_num
capture noisily drest_plot, overlap
if _rc == 0 & r(n_plots) == 1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G3.2 plot overlap only"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G3.2 overlap only"
}
capture graph close _all

* G3.3: plot influence only
local ++test_num
capture noisily drest_plot, influence
if _rc == 0 & r(n_plots) == 1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G3.3 plot influence only"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G3.3 influence only"
}
capture graph close _all

* G3.4: plot ite only
local ++test_num
capture noisily drest_plot, ite
if _rc == 0 & r(n_plots) == 1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G3.4 plot ite only"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G3.4 ite only"
}
capture graph close _all

* G3.5: plot with custom scheme and name
local ++test_num
capture noisily drest_plot, overlap scheme(s2color) name(test_graph)
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G3.5 plot scheme+name"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G3.5 scheme+name (rc=`=_rc')"
}
capture graph close _all

* G3.6: plot saving
local ++test_num
tempfile gph
capture noisily drest_plot, overlap saving("`gph'")
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G3.6 plot saving"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G3.6 saving"
}
capture graph close _all

* ============================================================================
* G4: drest_sensitivity — UNTESTED OPTIONS AND PATHS
* ============================================================================

* G4.1: rare option (binary outcome)
local ++test_num
drest_estimate x1 x2, outcome(ybin) treatment(treat) nolog
capture noisily drest_sensitivity, evalue rare
if _rc == 0 & r(evalue) > 1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G4.1 sensitivity rare option"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G4.1 rare (rc=`=_rc')"
}

* G4.2: continuous outcome E-value (Cohen's d path)
local ++test_num
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
capture noisily drest_sensitivity, evalue detail
if _rc == 0 & r(rr) > 1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G4.2 continuous E-value (RR=" %5.3f r(rr) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G4.2 continuous E-value"
}

* G4.3: negative treatment effect → RR < 1
local ++test_num
gen double y_neg = 1 + 0.5*x1 - 2.0*treat + rnormal()
drest_estimate x1 x2, outcome(y_neg) treatment(treat) nolog
capture noisily drest_sensitivity, evalue
local neg_rc = _rc
local neg_rr = r(rr)
local neg_ev = r(evalue)
if `neg_rc' == 0 & `neg_rr' < 1 & `neg_ev' > 1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G4.3 negative effect E-value (RR=" %5.3f `neg_rr' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G4.3 negative (rc=" `neg_rc' " rr=" %5.3f `neg_rr' " ev=" %5.3f `neg_ev' ")"
}
drop y_neg

* ============================================================================
* G5: ERROR PATH TESTS
* ============================================================================

* G5.1: bootstrap reps < 2
local ++test_num
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
capture noisily drest_bootstrap, reps(1)
if _rc == 198 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G5.1 bootstrap reps(1) error"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G5.1 reps(1) rc=`=_rc'"
}

* G5.2: report excel file exists without replace
local ++test_num
tempfile xltest
quietly drest_report, excel("`xltest'.xlsx") replace
capture noisily drest_report, excel("`xltest'.xlsx")
if _rc == 602 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G5.2 report file exists error"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G5.2 file exists rc=`=_rc'"
}

* G5.3: predict variable exists without replace
local ++test_num
capture drop test_mu1
drest_predict, mu1(test_mu1)
capture noisily drest_predict, mu1(test_mu1)
if _rc == 110 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G5.3 predict var exists error"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G5.3 predict exists rc=`=_rc'"
}
capture drop test_mu1

* G5.4: invalid trimps bounds
local ++test_num
capture noisily drest_estimate x1 x2, outcome(y) treatment(treat) trimps(0.9 0.1)
if _rc == 198 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G5.4 invalid trimps error"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G5.4 trimps rc=`=_rc'"
}

* G5.5: both treatment groups missing (only treated)
local ++test_num
preserve
drop if treat == 0
capture noisily drest_estimate x1 x2, outcome(y) treatment(treat)
if _rc == 198 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G5.5 single group error"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G5.5 single group rc=`=_rc'"
}
restore

* G5.6: LTMLE non-binary treatment
local ++test_num
preserve
clear
set obs 200
gen int id = ceil(_n/4)
bysort id: gen int t = _n
gen double x1 = rnormal()
gen double a_cont = rnormal()
gen byte y = runiform() < 0.3
capture noisily drest_ltmle, id(id) period(t) outcome(y) treatment(a_cont) covariates(x1) nolog
if _rc == 198 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G5.6 LTMLE non-binary treat error"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G5.6 rc=`=_rc'"
}
restore

* G5.7: LTMLE < 2 periods
local ++test_num
preserve
clear
set obs 100
gen int id = _n
gen int t = 1
gen double x1 = rnormal()
gen byte treat = runiform() < 0.5
gen byte y = runiform() < 0.3
capture noisily drest_ltmle, id(id) period(t) outcome(y) treatment(treat) covariates(x1) nolog
if _rc == 198 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G5.7 LTMLE single period error"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G5.7 rc=`=_rc'"
}
restore

* ============================================================================
* G6: CROSS-METHOD WORKFLOWS
* ============================================================================

* G6.1: Full pipeline: estimate → diagnose → compare → plot → report → sensitivity
local ++test_num
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
capture noisily drest_diagnose, all
local rc1 = _rc
capture noisily drest_compare x1 x2, outcome(y) treatment(treat)
local rc2 = _rc
capture noisily drest_plot, all
local rc3 = _rc
capture noisily drest_report
local rc4 = _rc
capture noisily drest_sensitivity, evalue
local rc5 = _rc
capture graph close _all
if `rc1' == 0 & `rc2' == 0 & `rc3' == 0 & `rc4' == 0 & `rc5' == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G6.1 full pipeline after estimate"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G6.1 pipeline rc=" `rc1' "/" `rc2' "/" `rc3' "/" `rc4' "/" `rc5'
}

* G6.2: Post-estimation after crossfit
local ++test_num
drest_crossfit x1 x2, outcome(y) treatment(treat) folds(3) seed(1) nolog
capture noisily drest_diagnose, propensity overlap
local rc1 = _rc
capture noisily drest_predict, mu1(cf_mu1) mu0(cf_mu0) replace
local rc2 = _rc
capture noisily drest_sensitivity, evalue
local rc3 = _rc
if `rc1' == 0 & `rc2' == 0 & `rc3' == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G6.2 post-estimation after crossfit"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G6.2 after crossfit rc=" `rc1' "/" `rc2' "/" `rc3'
}
capture drop cf_mu1 cf_mu0

* G6.3: Post-estimation after TMLE
local ++test_num
drest_tmle x1 x2, outcome(y) treatment(treat) nolog
capture noisily drest_diagnose, balance
local rc1 = _rc
capture noisily drest_report, detail
local rc2 = _rc
capture noisily drest_plot, overlap
local rc3 = _rc
capture graph close _all
if `rc1' == 0 & `rc2' == 0 & `rc3' == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G6.3 post-estimation after TMLE"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G6.3 after TMLE rc=" `rc1' "/" `rc2' "/" `rc3'
}

* ============================================================================
* G7: CROSSFIT UNTESTED OPTIONS
* ============================================================================

* G7.1: crossfit with separate omodel/tmodel
local ++test_num
capture noisily drest_crossfit, outcome(y) treatment(treat) ///
    omodel(x1 x2) tmodel(x1) folds(3) seed(1) nolog
if _rc == 0 & "`e(omodel)'" == "x1 x2" & "`e(tmodel)'" == "x1" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G7.1 crossfit separate model specs"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G7.1 crossfit specs"
}

* G7.2: crossfit with probit tfamily
local ++test_num
capture noisily drest_crossfit x1 x2, outcome(y) treatment(treat) ///
    tfamily(probit) folds(3) seed(1) nolog
if _rc == 0 & "`e(tfamily)'" == "probit" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G7.2 crossfit probit"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G7.2 crossfit probit"
}

* G7.3: crossfit with custom trimps
local ++test_num
capture noisily drest_crossfit x1 x2, outcome(y) treatment(treat) ///
    trimps(0.05 0.95) folds(3) seed(1) nolog
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G7.3 crossfit trimps"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G7.3 crossfit trimps"
}

* G7.4: crossfit ATC estimand
local ++test_num
capture noisily drest_crossfit x1 x2, outcome(y) treatment(treat) ///
    estimand(ATC) folds(3) seed(1) nolog
if _rc == 0 & "`e(estimand)'" == "ATC" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G7.4 crossfit ATC"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G7.4 crossfit ATC"
}

* G7.5: crossfit if condition
local ++test_num
capture noisily drest_crossfit x1 x2 if x1 > -1, outcome(y) treatment(treat) ///
    folds(3) seed(1) nolog
if _rc == 0 & e(N) < 500 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G7.5 crossfit if (N=" e(N) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G7.5 crossfit if"
}

* ============================================================================
* G8: TMLE UNTESTED OPTIONS
* ============================================================================

* G8.1: TMLE with probit tfamily
local ++test_num
capture noisily drest_tmle x1 x2, outcome(y) treatment(treat) ///
    tfamily(probit) nolog
if _rc == 0 & "`e(tfamily)'" == "probit" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G8.1 TMLE probit"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G8.1 TMLE probit"
}

* G8.2: TMLE if condition
local ++test_num
capture noisily drest_tmle x1 x2 if x1 > -1, outcome(y) treatment(treat) nolog
if _rc == 0 & e(N) < 500 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G8.2 TMLE if (N=" e(N) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G8.2 TMLE if"
}

* G8.3: TMLE crossfit without explicit folds (default=5)
local ++test_num
capture noisily drest_tmle x1 x2, outcome(y) treatment(treat) crossfit seed(42) nolog
if _rc == 0 & e(folds) == 5 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G8.3 TMLE crossfit default folds"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G8.3 folds=" e(folds)
}

* ============================================================================
* G9: LTMLE UNTESTED OPTIONS
* ============================================================================

preserve
clear
set seed 11223
set obs 800
gen int id = ceil(_n/4)
bysort id: gen int t = _n
gen double x1 = rnormal()
gen byte treat = runiform() < invlogit(0.3*x1)
bysort id (t): gen double cum_a = sum(treat)
gen byte y = runiform() < invlogit(-2 + 0.2*x1 + 0.5*cum_a)
drop cum_a

* G9.1: LTMLE regime(never) standalone
local ++test_num
capture noisily drest_ltmle, id(id) period(t) outcome(y) treatment(treat) ///
    covariates(x1) regime(never) nolog
if _rc == 0 & e(tau) > 0 & e(tau) < 1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G9.1 LTMLE regime(never) P=" %6.4f e(tau)
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G9.1 regime(never)"
}

* G9.2: LTMLE custom trimps
local ++test_num
capture noisily drest_ltmle, id(id) period(t) outcome(y) treatment(treat) ///
    covariates(x1) trimps(0.05 0.95) nolog
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G9.2 LTMLE trimps"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G9.2 LTMLE trimps"
}

* G9.3: LTMLE non-consecutive periods (was a critical bug, now fixed)
local ++test_num
replace t = t * 3
capture noisily drest_ltmle, id(id) period(t) outcome(y) treatment(treat) ///
    covariates(x1) nolog
if _rc == 0 & e(T) == 4 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G9.3 LTMLE non-consecutive (T=" e(T) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G9.3 non-consecutive T=" e(T)
}

* G9.4: LTMLE non-binary censor error
local ++test_num
gen double c_cont = rnormal()
capture noisily drest_ltmle, id(id) period(t) outcome(y) treatment(treat) ///
    covariates(x1) censor(c_cont) nolog
if _rc == 198 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G9.4 LTMLE non-binary censor error"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G9.4 censor error rc=`=_rc'"
}
drop c_cont

restore

* ============================================================================
* G10: COMPARE UNTESTED OPTIONS
* ============================================================================

* G10.1: compare ATT estimand should error (ATE only)
local ++test_num
capture noisily drest_compare x1 x2, outcome(y) treatment(treat) estimand(ATT)
if _rc == 198 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G10.1 compare ATT correctly rejected"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G10.1 compare ATT rc=`=_rc' (expected 198)"
}

* G10.2: compare single method
local ++test_num
capture noisily drest_compare x1 x2, outcome(y) treatment(treat) methods(aipw)
if _rc == 0 {
    matrix comp = r(comparison)
    if rowsof(comp) == 1 {
        local ++pass
        display "RESULT: Test `test_num' PASSED - G10.2 compare single method"
    }
    else {
        local ++fail
        display "RESULT: Test `test_num' FAILED - G10.2 matrix rows=" rowsof(comp)
    }
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G10.2 rc=`=_rc'"
}

* G10.3: compare custom level
local ++test_num
capture noisily drest_compare x1 x2, outcome(y) treatment(treat) level(90)
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G10.3 compare level(90)"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G10.3 compare level"
}

* G10.4: compare binary outcome
local ++test_num
capture noisily drest_compare x1 x2, outcome(ybin) treatment(treat)
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G10.4 compare binary"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G10.4 compare binary"
}

* ============================================================================
* G11: DATA PRESERVATION ACROSS ALL COMMANDS
* ============================================================================

local ++test_num
local N_orig = _N
quietly summarize y
local y_mean = r(mean)
quietly summarize treat
local treat_mean = r(mean)

drest_estimate x1 x2, outcome(y) treatment(treat) nolog
drest_diagnose, all
drest_compare x1 x2, outcome(y) treatment(treat)
drest_predict, mu1(g11_m1) mu0(g11_m0) replace
capture noisily drest_plot, all
capture graph close _all
drest_report
drest_sensitivity, evalue
drest_crossfit x1 x2, outcome(y) treatment(treat) folds(3) seed(1) nolog
drest_tmle x1 x2, outcome(y) treatment(treat) nolog
drest_bootstrap, reps(20) seed(1) nolog

local ok = 1
if _N != `N_orig' local ok = 0
quietly summarize y
if abs(r(mean) - `y_mean') > 1e-10 local ok = 0
quietly summarize treat
if abs(r(mean) - `treat_mean') > 1e-10 local ok = 0
capture assert inlist(treat, 0, 1)
if _rc local ok = 0

if `ok' {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G11 data intact after full pipeline"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G11 data corrupted"
}
capture drop g11_m1 g11_m0

* ============================================================================
* G12: DIAGNOSE GRAPH OPTIONS
* ============================================================================
drest_estimate x1 x2, outcome(y) treatment(treat) nolog

* G12.1: diagnose with graph
local ++test_num
capture noisily drest_diagnose, overlap influence graph
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G12.1 diagnose graph"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G12.1 diagnose graph rc=`=_rc'"
}
capture graph close _all

* G12.2: diagnose graph with name prefix
local ++test_num
capture noisily drest_diagnose, overlap graph name(diag_test)
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G12.2 diagnose graph name"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G12.2 graph name"
}
capture graph close _all

* ============================================================================
* G13: POISSON ACROSS COMMANDS
* ============================================================================
gen double y_count = max(0, round(exp(0.5 + 0.2*x1 + 0.3*treat + rnormal(0,0.5))))

* G13.1: crossfit with poisson
local ++test_num
capture noisily drest_crossfit x1 x2, outcome(y_count) treatment(treat) ///
    ofamily(poisson) folds(3) seed(1) nolog
if _rc == 0 & "`e(ofamily)'" == "poisson" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G13.1 crossfit poisson"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G13.1 crossfit poisson"
}

* G13.2: compare with poisson
local ++test_num
capture noisily drest_compare x1 x2, outcome(y_count) treatment(treat) ofamily(poisson)
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G13.2 compare poisson"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G13.2 compare poisson"
}
drop y_count

* ============================================================================
* G14: VARABBREV RESTORE ON ERROR PATHS (reviewer fixes)
* ============================================================================

* G14.1: drest_predict varabbrev restored on variable-exists error
local ++test_num
set varabbrev on
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
drest_predict, mu1(g14_test)
capture noisily drest_predict, mu1(g14_test)
local va_after = c(varabbrev)
if "`va_after'" == "on" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G14.1 predict varabbrev restored on error"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G14.1 varabbrev = `va_after'"
    set varabbrev on
}
capture drop g14_test

* G14.2: drest_compare varabbrev restored on invalid ofamily
local ++test_num
set varabbrev on
capture noisily drest_compare x1 x2, outcome(y) treatment(treat) ofamily(gamma)
local va_after = c(varabbrev)
if "`va_after'" == "on" & _rc == 198 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G14.2 compare varabbrev restored on invalid ofamily"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G14.2 varabbrev = `va_after' rc = `=_rc'"
    set varabbrev on
}

* G14.3: drest_compare varabbrev restored on invalid tfamily
local ++test_num
set varabbrev on
capture noisily drest_compare x1 x2, outcome(y) treatment(treat) tfamily(poisson)
local va_after = c(varabbrev)
if "`va_after'" == "on" & _rc == 198 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G14.3 compare varabbrev restored on invalid tfamily"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G14.3 varabbrev = `va_after' rc = `=_rc'"
    set varabbrev on
}

* G14.4: drest_predict varabbrev restored for all 4 prediction types
local ++test_num
set varabbrev on
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
drest_predict, mu0(g14_m0)
capture noisily drest_predict, mu0(g14_m0)
local va1 = c(varabbrev)
capture drop g14_m0
drest_predict, ite(g14_ite)
capture noisily drest_predict, ite(g14_ite)
local va2 = c(varabbrev)
capture drop g14_ite
drest_predict, ps(g14_ps)
capture noisily drest_predict, ps(g14_ps)
local va3 = c(varabbrev)
capture drop g14_ps
if "`va1'" == "on" & "`va2'" == "on" & "`va3'" == "on" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G14.4 predict varabbrev all 4 types"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G14.4 mu0=`va1' ite=`va2' ps=`va3'"
    set varabbrev on
}

* G14.5: drest_ltmle sort order preserved
local ++test_num
preserve
clear
set seed 88990
set obs 400
gen int id = ceil(_n/4)
bysort id: gen int t = _n
gen double x1 = rnormal()
gen byte treat = runiform() < 0.5
bysort id (t): gen double cum_a = sum(treat)
gen byte y = runiform() < invlogit(-2 + 0.2*x1 + 0.5*cum_a)
drop cum_a
* Scramble sort order deliberately
gen double rnd = runiform()
sort rnd
gen long orig_order = _n
drest_ltmle, id(id) period(t) outcome(y) treatment(treat) covariates(x1) nolog
* Check if original order is preserved
capture assert orig_order == _n
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G14.5 LTMLE sort order preserved"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G14.5 LTMLE sort order changed"
}
restore

* ============================================================================
* G15: e(sample) POPULATED AFTER ECLASS COMMANDS
* ============================================================================

* G15.1: e(sample) after drest_estimate
local ++test_num
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
quietly count if e(sample)
local n_esample = r(N)
quietly count if _drest_esample == 1
local n_esvar = r(N)
if `n_esample' == `n_esvar' & `n_esample' > 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G15.1 e(sample) after estimate (N=`n_esample')"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G15.1 e(sample)=`n_esample' esvar=`n_esvar'"
}

* G15.2: e(sample) after drest_crossfit
local ++test_num
drest_crossfit x1 x2, outcome(y) treatment(treat) folds(3) seed(1) nolog
quietly count if e(sample)
local n_esample = r(N)
if `n_esample' > 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G15.2 e(sample) after crossfit (N=`n_esample')"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G15.2 e(sample)=`n_esample'"
}

* G15.3: e(sample) after drest_tmle
local ++test_num
drest_tmle x1 x2, outcome(y) treatment(treat) nolog
quietly count if e(sample)
local n_esample = r(N)
if `n_esample' > 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G15.3 e(sample) after tmle (N=`n_esample')"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G15.3 e(sample)=`n_esample'"
}

* G15.4: e(sample) after drest_bootstrap
local ++test_num
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
drest_bootstrap, reps(10) seed(1) nolog
quietly count if e(sample)
local n_esample = r(N)
if `n_esample' > 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G15.4 e(sample) after bootstrap (N=`n_esample')"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G15.4 e(sample)=`n_esample'"
}

* ============================================================================
* G16: REPORT VARABBREV RESTORE ON FILE-EXISTS ERROR
* ============================================================================
local ++test_num
set varabbrev on
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
* Create a temp file to trigger file-exists error
tempfile tmpxlsx
quietly export excel using "`tmpxlsx'", replace
capture noisily drest_report, excel("`tmpxlsx'")
local va_after = c(varabbrev)
if "`va_after'" == "on" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G16 report varabbrev restored on file-exists"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G16 varabbrev=`va_after'"
    set varabbrev on
}

* ============================================================================
* G17: LTMLE TREATMENT VARIABLE NOT CORRUPTED
* ============================================================================
local ++test_num
preserve
clear
set seed 88991
set obs 400
gen int id = ceil(_n/4)
bysort id: gen int t = _n
gen double x1 = rnormal()
gen byte treat = runiform() < 0.5
gen byte y = runiform() < invlogit(-2 + 0.2*x1 + 0.5*treat)
* Record original treatment values
gen byte treat_orig = treat
drest_ltmle, id(id) period(t) outcome(y) treatment(treat) covariates(x1) nolog
* Check treatment variable is unchanged
capture assert treat == treat_orig
if _rc == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G17 LTMLE treatment not corrupted"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G17 treatment variable modified by LTMLE"
}
restore

* ============================================================================
* G18: SENSITIVITY/REPORT GUARDS WHEN _drest_esample MISSING
* ============================================================================

* G18.1: sensitivity fails gracefully without esample variable
local ++test_num
preserve
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
drop _drest_esample
capture noisily drest_sensitivity
if _rc == 111 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G18.1 sensitivity guard on missing esample"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G18.1 rc=`=_rc' (expected 111)"
}
restore

* G18.2: report fails gracefully without esample variable
local ++test_num
preserve
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
drop _drest_esample
capture noisily drest_report
if _rc == 111 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G18.2 report guard on missing esample"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G18.2 rc=`=_rc' (expected 111)"
}
restore

* ============================================================================
* G19: e(sample) AFTER LTMLE
* ============================================================================
local ++test_num
preserve
clear
set seed 88992
set obs 400
gen int id = ceil(_n/4)
bysort id: gen int t = _n
gen double x1 = rnormal()
gen byte treat = runiform() < 0.5
gen byte y = runiform() < invlogit(-2 + 0.2*x1 + 0.5*treat)
drest_ltmle, id(id) period(t) outcome(y) treatment(treat) covariates(x1) nolog
quietly count if e(sample)
local n_esample = r(N)
if `n_esample' > 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - G19 e(sample) after ltmle (N=`n_esample')"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - G19 e(sample)=`n_esample'"
}
restore

* ============================================================================
* SUMMARY
* ============================================================================
display ""
display as text "Total tests: " as result `test_num'
display as text "Passed:      " as result `pass'
display as text "Failed:      " as result `fail'

if `fail' > 0 {
    display as error "`fail' test(s) FAILED"
    exit 1
}
else {
    display as result "All tests passed."
}
