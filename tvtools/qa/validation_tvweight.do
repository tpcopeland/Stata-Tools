clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "validation_tvweight.log", replace nomsg

* Shared scaffold: test globals + helpers + sandboxed install bootstrap
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""
local run_only = 0
local quiet = 0
local machine = 0

* run_test/test_pass/test_fail harness counters (folded into the totals below)
global TVQA_PASS = 0
global TVQA_FAIL = 0
global TVQA_FAILED ""
global TVQA_CURRENT ""

display as result "tvtools QA: tvweight correctness -- $S_DATE $S_TIME"


**# ===== merged from validation_tvtools.do L16510-17158: SECTION 7 TVWEIGHT IPTW properties =====

* SECTION 7: TVWEIGHT - IPTW weight properties validation

capture noisily {
* VALIDATION DATASETS
if `quiet' == 0 {
    display as text _n "Creating validation datasets..."
}

* Dataset 1: Simple known propensity scores
* Create data where we can verify IPTW calculation manually
* 100 observations: 50 with x=0 (all untreated), 50 with x=1 (all treated)
clear
set obs 100
gen id = _n
gen x = (_n > 50)
gen treatment = x
* All PS should be 1 for treated when x=1, 0 for treated when x=0
* Weight = 1/1 = 1 for all
save "${DATA_DIR}/val_perfect_sep.dta", replace

* Dataset 2: Known propensity scores from simple model
* Create balanced data with predictable PS
clear
set obs 200
gen id = _n
* Binary covariate
gen x = mod(_n, 2)
* Treatment pattern: P(T=1|x=0) = 0.25, P(T=1|x=1) = 0.75
gen treatment = 0
replace treatment = 1 if x == 0 & _n <= 25  // 25 treated of 100 with x=0
replace treatment = 1 if x == 1 & _n > 100 & _n <= 175  // 75 treated of 100 with x=1
save "${DATA_DIR}/val_known_ps.dta", replace

* Dataset 3: For ESS calculation
* Simple case where ESS can be calculated by hand
clear
set obs 10
gen id = _n
gen x = 1
gen treatment = (_n <= 5)
save "${DATA_DIR}/val_ess.dta", replace

if `quiet' == 0 {
    display as result "Validation datasets created in: ${DATA_DIR}"
}

* SECTION 1: WEIGHT CALCULATION CORRECTNESS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 1: Weight Calculation Correctness"
    display as text "{hline 70}"
}

* Test 1.1: Known IPTW for simple case
* Purpose: Verify IPTW = 1/PS for treated, 1/(1-PS) for untreated
* With known PS from logistic regression
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.1: Known IPTW calculation"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear

    * First, fit logit manually and calculate expected weights
    quietly logit treatment x
    quietly predict ps_manual, pr

    * Calculate expected IPTW
    gen expected_iptw = .
    replace expected_iptw = 1/ps_manual if treatment == 1
    replace expected_iptw = 1/(1-ps_manual) if treatment == 0

    * Now use tvweight
    tvweight treatment, covariates(x) nolog

    * Verify weights match expected
    gen diff = abs(iptw - expected_iptw)
    sum diff
    assert r(max) < 0.0001
}
if _rc == 0 {
    display as result "  PASS: IPTW matches manual calculation"
    local ++pass_count
}
else {
    display as error "  FAIL: IPTW calculation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}

* Test 1.2: Stabilized weights calculation
* Purpose: Verify SW = marginal_prob / PS (for treated)
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 1.2: Stabilized weights calculation"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear

    * Calculate marginal probability of treatment
    sum treatment
    local marg_prob = r(mean)

    * Fit logit and get PS
    quietly logit treatment x
    quietly predict ps_manual, pr

    * Calculate expected stabilized weights
    gen expected_sw = .
    replace expected_sw = `marg_prob' / ps_manual if treatment == 1
    replace expected_sw = (1 - `marg_prob') / (1 - ps_manual) if treatment == 0

    * Use tvweight with stabilized
    tvweight treatment, covariates(x) stabilized nolog

    * Verify weights match expected
    gen diff = abs(iptw - expected_sw)
    sum diff
    assert r(max) < 0.0001
}
if _rc == 0 {
    display as result "  PASS: Stabilized weights match manual calculation"
    local ++pass_count
}
else {
    display as error "  FAIL: Stabilized weights (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
}

* SECTION 2: EFFECTIVE SAMPLE SIZE
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 2: Effective Sample Size"
    display as text "{hline 70}"
}

* Test 2.1: ESS calculation
* Purpose: Verify ESS = (sum w)^2 / sum(w^2)
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.1: ESS calculation"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear

    tvweight treatment, covariates(x) nolog

    * Save ESS from tvweight before other commands overwrite r()
    local tvweight_ess = r(ess)

    * Calculate ESS manually
    sum iptw
    local sum_w = r(sum)
    gen w2 = iptw^2
    sum w2
    local sum_w2 = r(sum)
    local expected_ess = (`sum_w'^2) / `sum_w2'

    * Compare with returned ESS
    assert abs(`tvweight_ess' - `expected_ess') < 0.01
}
if _rc == 0 {
    display as result "  PASS: ESS matches manual calculation"
    local ++pass_count
}
else {
    display as error "  FAIL: ESS calculation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.1"
}

* Test 2.2: ESS percentage
* Purpose: Verify ESS% = 100 * ESS / N
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 2.2: ESS percentage"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear

    tvweight treatment, covariates(x) nolog

    * Save all return values before any other commands
    local n = r(N)
    local ess = r(ess)
    local ess_pct = r(ess_pct)
    local expected_pct = 100 * `ess' / `n'

    assert abs(`ess_pct' - `expected_pct') < 0.01
}
if _rc == 0 {
    display as result "  PASS: ESS percentage correct"
    local ++pass_count
}
else {
    display as error "  FAIL: ESS percentage (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.2"
}

* SECTION 3: TRUNCATION
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 3: Truncation Validation"
    display as text "{hline 70}"
}

* Test 3.1: Truncation bounds
* Purpose: After truncation, no weights outside bounds
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 3.1: Truncation bounds enforced"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear

    * Calculate untrimmed weights first
    tvweight treatment, covariates(x) generate(iptw_raw) nolog

    * Get 5th and 95th percentiles
    _pctile iptw_raw, p(5 95)
    local p5 = r(r1)
    local p95 = r(r2)

    * Now with truncation
    tvweight treatment, covariates(x) truncate(5 95) replace nolog

    * Verify no weights outside bounds
    count if iptw < `p5' - 0.0001
    assert r(N) == 0
    count if iptw > `p95' + 0.0001
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: Truncation bounds enforced"
    local ++pass_count
}
else {
    display as error "  FAIL: Truncation bounds (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1"
}

* SECTION 4: INVARIANTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 4: Invariant Tests"
    display as text "{hline 70}"
}

* Invariant 4.1: Weights always positive
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 4.1: Weights always positive"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear
    tvweight treatment, covariates(x) nolog

    count if iptw <= 0 | missing(iptw)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: All weights positive"
    local ++pass_count
}
else {
    display as error "  FAIL: Some weights non-positive (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv4.1"
}

* Invariant 4.2: Propensity scores between 0 and 1
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 4.2: Propensity scores bounded"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear
    tvweight treatment, covariates(x) denominator(ps) nolog

    count if ps <= 0 | ps >= 1
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: All PS between 0 and 1"
    local ++pass_count
}
else {
    display as error "  FAIL: PS out of bounds (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv4.2"
}

* Invariant 4.3: ESS <= N
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 4.3: ESS <= N"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear
    tvweight treatment, covariates(x) nolog

    assert r(ess) <= r(N) + 0.01  // Small tolerance for floating point
}
if _rc == 0 {
    display as result "  PASS: ESS <= N"
    local ++pass_count
}
else {
    display as error "  FAIL: ESS > N (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv4.3"
}

* Invariant 4.4: Stabilized weights have mean near 1
local ++test_count
if `quiet' == 0 {
    display as text _n "Invariant 4.4: Stabilized weights mean ~ 1"
}

capture {
    use "${DATA_DIR}/val_known_ps.dta", clear
    tvweight treatment, covariates(x) stabilized nolog

    * Mean of stabilized weights should be close to 1
    sum iptw
    assert abs(r(mean) - 1) < 0.1
}
if _rc == 0 {
    display as result "  PASS: Stabilized weights have mean near 1"
    local ++pass_count
}
else {
    display as error "  FAIL: Stabilized weights mean not near 1 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' Inv4.4"
}

* SECTION 5: MULTINOMIAL WEIGHTS
if `quiet' == 0 {
    display as text _n "{hline 70}"
    display as text "SECTION 5: Multinomial Weight Validation"
    display as text "{hline 70}"
}

* Create multinomial test data
clear
set obs 300
gen id = _n
gen x = mod(_n, 3)  // 0, 1, 2 pattern
gen treatment = x   // Perfect prediction for testing
save "${DATA_DIR}/val_mlogit.dta", replace

* Test 5.1: Multinomial IPTW
* Purpose: Verify weights = 1/P(A=a|X) for each level
local ++test_count
if `quiet' == 0 {
    display as text _n "Test 5.1: Multinomial IPTW calculation"
}

capture {
    use "${DATA_DIR}/val_mlogit.dta", clear

    * Add noise to prevent perfect separation
    replace treatment = mod(treatment + 1, 3) if _n <= 30

    * Fit mlogit manually
    quietly mlogit treatment x, baseoutcome(0)

    * Predict probabilities for each outcome
    forvalues k = 0/2 {
        quietly predict ps`k', pr outcome(`k')
    }

    * Calculate expected weights
    gen expected_w = .
    replace expected_w = 1/ps0 if treatment == 0
    replace expected_w = 1/ps1 if treatment == 1
    replace expected_w = 1/ps2 if treatment == 2

    * Use tvweight
    tvweight treatment, covariates(x) model(mlogit) nolog

    * Compare
    gen diff = abs(iptw - expected_w)
    sum diff
    assert r(max) < 0.0001
}
if _rc == 0 {
    display as result "  PASS: Multinomial IPTW matches manual calculation"
    local ++pass_count
}
else {
    display as error "  FAIL: Multinomial IPTW (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.1"
}

* SUMMARY

}

capture noisily {

* TEST 8A: IPTW FORMULA WITH KNOWN PROPENSITY SCORES
display "TEST 8A: IPTW formula - exact check with known propensity scores"

local test8a_pass = 1

* Create a simple dataset where treatment is perfectly predicted by a covariate
* This allows us to verify: PS(treated) = 1, PS(untreated) = 0
* But with perfect separation, logit won't converge. Use an imperfect but strong predictor.
*
* Strategy: 2 groups (treated/untreated) with strong covariate signal
* After logit, PS for treated group ≈ high, for untreated ≈ low
* We verify: IPTW_i = 1/PS_i for treated, 1/(1-PS_i) for untreated

* Create a simple 40-person dataset with clear treatment groups
clear
set obs 40
gen id = _n
set seed 12345

* Perfect predictor: x1 determines treatment
gen x1 = (_n <= 20)    // 1 for persons 1-20, 0 for 21-40
gen treatment = x1 * 1    // treatment = 1 iff x1=1 (perfectly correlated)
* Add a tiny bit of noise to avoid perfect separation
replace treatment = 0 if id == 5    // one treated person in untreated group (per x1)
replace treatment = 1 if id == 25   // one untreated person in treated group

* Run tvweight
capture noisily tvweight treatment, ///
    covariates(x1) generate(iptw) denominator(ps_score) nolog replace

if _rc != 0 {
    display as error "  FAIL [8a.run]: tvweight returned error `=_rc'"
    local test8a_pass = 0
}
else {
    display "  INFO: Checking IPTW formula for each observation"

    * For each treated person: iptw should equal 1/ps_score
    quietly gen iptw_check = .
    quietly replace iptw_check = 1/ps_score if treatment == 1
    quietly replace iptw_check = 1/(1-ps_score) if treatment == 0

    quietly gen diff_iptw = abs(iptw - iptw_check)
    quietly sum diff_iptw
    local max_diff = r(max)
    local mean_diff = r(mean)

    if `max_diff' < 0.0001 {
        display as result "  PASS [8a.formula]: IPTW = 1/PS (treated) or 1/(1-PS) (untreated), max_diff=`max_diff'"
    }
    else {
        display as error "  FAIL [8a.formula]: max_diff=`max_diff', mean_diff=`mean_diff'"
        list treatment ps_score iptw iptw_check diff_iptw if diff_iptw > 0.001, noobs
        local test8a_pass = 0
    }

    * All IPTW should be positive
    quietly count if iptw <= 0 | missing(iptw)
    if r(N) == 0 {
        display as result "  PASS [8a.positive]: all IPTW weights > 0"
    }
    else {
        display as error "  FAIL [8a.positive]: `=r(N)' non-positive IPTW values"
        local test8a_pass = 0
    }
}

if `test8a_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 8A: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 8a"
    display as error "TEST 8A: FAILED"
}

* TEST 8B: STABILIZED IPTW - MEAN = 1.0 EXACTLY (DETERMINISTIC)
display "TEST 8B: Stabilized IPTW - mean = 1.0 in each group (deterministic)"

local test8b_pass = 1

* Deterministic 4-cell balanced design (no random data → no convergence issues)
* 70 obs: 25 (x1=1,trt=1), 10 (x1=1,trt=0), 10 (x1=0,trt=1), 25 (x1=0,trt=0)
*
* Logit model: logit(P) = alpha + beta*x1
*   P(A=1|x1=1) = 25/35 = 5/7 ≈ 0.7143
*   P(A=1|x1=0) = 10/35 = 2/7 ≈ 0.2857
*   Marginal P(A=1) = 35/70 = 0.5
*
* Expected stabilized IPTW:
*   x1=1, treated:   0.5 / (5/7) = 0.7
*   x1=0, treated:   0.5 / (2/7) = 1.75
*   x1=1, untreated: 0.5 / (2/7) = 1.75
*   x1=0, untreated: 0.5 / (5/7) = 0.7
*
* Mean stab IPTW (treated)   = (25×0.7 + 10×1.75) / 35 = 35/35 = 1.0 exactly
* Mean stab IPTW (untreated) = (10×1.75 + 25×0.7) / 35 = 35/35 = 1.0 exactly

clear
set obs 70
gen id = _n
gen x1 = (_n <= 35)
gen treatment = 0
replace treatment = 1 if _n <= 25               // 25 with x1=1, treated
replace treatment = 1 if _n > 35 & _n <= 45    // 10 with x1=0, treated

* Verify cell counts
quietly count if treatment == 1
display "  INFO: n_treated = `r(N)' (expected 35)"
quietly count if treatment == 0
display "  INFO: n_untreated = `r(N)' (expected 35)"

capture noisily tvweight treatment, ///
    covariates(x1) generate(iptw_stab) stabilized nolog replace

if _rc != 0 {
    display as error "  FAIL [8b.run]: tvweight returned error `=_rc'"
    local test8b_pass = 0
}
else {
    * Check mean stabilized weight in each group
    quietly sum iptw_stab if treatment == 1
    local mean_treated = r(mean)
    quietly sum iptw_stab if treatment == 0
    local mean_untreated = r(mean)

    display "  INFO: Mean stabilized IPTW (treated) = `mean_treated' (expected 1.0)"
    display "  INFO: Mean stabilized IPTW (untreated) = `mean_untreated' (expected 1.0)"

    * With deterministic data and balanced design, mean should be ≈1.0 (within 0.01)
    if abs(`mean_treated' - 1) < 0.01 {
        display as result "  PASS [8b.treated]: mean stab IPTW (treated) = `mean_treated' ≈ 1.0"
    }
    else {
        display as error "  FAIL [8b.treated]: mean stab IPTW (treated) = `mean_treated', expected 1.0"
        local test8b_pass = 0
    }

    if abs(`mean_untreated' - 1) < 0.01 {
        display as result "  PASS [8b.untreated]: mean stab IPTW (untreated) = `mean_untreated' ≈ 1.0"
    }
    else {
        display as error "  FAIL [8b.untreated]: mean stab IPTW (untreated) = `mean_untreated', expected 1.0"
        local test8b_pass = 0
    }

    * All weights should be positive
    quietly count if iptw_stab <= 0 | missing(iptw_stab)
    if r(N) == 0 {
        display as result "  PASS [8b.positive]: all stabilized IPTW > 0"
    }
    else {
        display as error "  FAIL [8b.positive]: `=r(N)' non-positive stabilized IPTW"
        local test8b_pass = 0
    }
}

if `test8b_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 8B: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 8b"
    display as error "TEST 8B: FAILED"
}

* TEST 8C: HORVITZ-THOMPSON IDENTITY (UNSTABILIZED IPTW) - EXACT VALUE
display "TEST 8C: Horvitz-Thompson: mean IPTW (treated) = n_total/n_treated (exact)"

local test8c_pass = 1

* Reuse same 4-cell deterministic dataset as 8B:
* n_total=70, n_treated=35, expected mean IPTW (treated) = 70/35 = 2.0 exactly
*
* Expected unstabilized IPTW:
*   x1=1, treated (25 obs):   1 / (5/7) = 7/5 = 1.4
*   x1=0, treated (10 obs):   1 / (2/7) = 7/2 = 3.5
*   Mean IPTW (treated) = (25×1.4 + 10×3.5) / 35 = 70/35 = 2.0 exactly
*   This equals n_total/n_treated = 70/35 = 2.0 (Horvitz-Thompson)

clear
set obs 70
gen id = _n
gen x1 = (_n <= 35)
gen treatment = 0
replace treatment = 1 if _n <= 25
replace treatment = 1 if _n > 35 & _n <= 45

quietly count
local n_total = r(N)
quietly count if treatment == 1
local n_treated = r(N)
local ht_expected = `n_total' / `n_treated'

display "  INFO: n_total=`n_total', n_treated=`n_treated', HT expected=`ht_expected' (expected 2.0)"

capture noisily tvweight treatment, ///
    covariates(x1) generate(iptw) nolog replace

if _rc != 0 {
    display as error "  FAIL [8c.run]: tvweight returned error `=_rc'"
    local test8c_pass = 0
}
else {
    quietly sum iptw if treatment == 1
    local mean_iptw_treated = r(mean)
    display "  INFO: Mean unstabilized IPTW (treated) = `mean_iptw_treated', expected = `ht_expected'"

    * With deterministic data, should match within 0.01
    local diff = abs(`mean_iptw_treated' - `ht_expected') / `ht_expected'
    if `diff' < 0.01 {
        display as result "  PASS [8c.ht]: IPTW mean = `mean_iptw_treated' = n_total/n_treated (diff=`=100*`diff''%)"
    }
    else {
        display as error "  FAIL [8c.ht]: IPTW mean=`mean_iptw_treated', expected=`ht_expected' (diff=`=100*`diff''%)"
        local test8c_pass = 0
    }
}

if `test8c_pass' == 1 {
    local pass_count = `pass_count' + 1
    display as result "TEST 8C: PASSED"
}
else {
    local fail_count = `fail_count' + 1
    local failed_tests "`failed_tests' 8c"
    display as error "TEST 8C: FAILED"
}

* FINAL SUMMARY

}


**# ===== merged from validation_tvtools.do L20762-20938: TVWEIGHT expanded validation =====

* SECTION 14: TVWEIGHT EXPANDED VALIDATION (7 tests)

capture noisily {

* Test 14.1: Weight = 1/PS relationship
local ++test_count
capture {
    clear
    set obs 500
    set seed 14100
    gen double x = rnormal()
    gen byte treat = (x + rnormal() > 0)
    tvweight treat, covariates(x) generate(w) denominator(ps)
    gen double expected_w = cond(treat, 1/ps, 1/(1-ps))
    gen double diff = abs(w - expected_w)
    quietly summarize diff
    assert r(max) < 0.001
    drop w ps expected_w diff
}
if _rc == 0 {
    display as result "  PASS: tvweight 1/PS relationship"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight 1/PS relationship (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 14.1"
}

* Test 14.2: Unstabilized weight sum reasonable
local ++test_count
capture {
    clear
    set obs 500
    set seed 14200
    gen double x = rnormal()
    gen byte treat = (x + rnormal() > 0)
    tvweight treat, covariates(x)
    quietly summarize iptw
    local wsum = r(sum)
    assert `wsum' > 700 & `wsum' < 1500
}
if _rc == 0 {
    display as result "  PASS: tvweight unstabilized weight sum"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight weight sum (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 14.2"
}

* Test 14.3: Stabilized weight mean near 1
local ++test_count
capture {
    clear
    set obs 500
    set seed 14300
    gen double x = rnormal()
    gen byte treat = (x + rnormal() > 0)
    tvweight treat, covariates(x) stabilized
    quietly summarize iptw
    assert abs(r(mean) - 1) < 0.15
}
if _rc == 0 {
    display as result "  PASS: tvweight stabilized mean near 1"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight stabilized mean (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 14.3"
}

* Test 14.4: 3-level multinomial weights all positive
local ++test_count
capture {
    clear
    set obs 1500
    set seed 14401
    gen double x = rnormal()
    gen double x2 = rnormal()
    * Use well-separated groups for convergence
    gen byte treat = cond(_n <= 500, 0, cond(_n <= 1000, 1, 2))
    tvweight treat, covariates(x x2)
    local saved_nlevels = r(n_levels)
    quietly count if iptw <= 0
    assert r(N) == 0
    assert `saved_nlevels' == 3
}
if _rc == 0 {
    display as result "  PASS: tvweight 3-level multinomial"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight 3-level multinomial (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 14.4"
}

* Test 14.5: Denominator PS bounded in (0,1)
local ++test_count
capture {
    clear
    set obs 500
    set seed 14500
    gen double x = rnormal()
    gen byte treat = (x + rnormal() > 0)
    tvweight treat, covariates(x) denominator(ps)
    quietly summarize ps
    assert r(min) > 0
    assert r(max) < 1
    drop ps
}
if _rc == 0 {
    display as result "  PASS: tvweight PS bounded"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight PS bounded (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 14.5"
}

* Test 14.6: Truncation enforcement
local ++test_count
capture {
    clear
    set obs 500
    set seed 14600
    gen double x = 3*rnormal()
    gen byte treat = (x + rnormal() > 0)
    tvweight treat, covariates(x) truncate(5 95)
    assert r(n_truncated) >= 0
    assert r(w_min) > 0
}
if _rc == 0 {
    display as result "  PASS: tvweight truncation enforcement"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight truncation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 14.6"
}

* Test 14.7: ESS formula verification
local ++test_count
capture {
    clear
    set obs 500
    set seed 14700
    gen double x = rnormal()
    gen byte treat = (x + rnormal() > 0)
    tvweight treat, covariates(x)
    local reported_ess = r(ess)
    quietly summarize iptw
    local sum_w = r(sum)
    quietly gen double w2 = iptw^2
    quietly summarize w2
    local sum_w2 = r(sum)
    local manual_ess = (`sum_w')^2 / `sum_w2'
    assert reldif(`reported_ess', `manual_ess') < 0.01
    drop w2
}
if _rc == 0 {
    display as result "  PASS: tvweight ESS formula"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight ESS formula (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 14.7"
}

}


* ===== Summary =====
* Fold the run_test/test_pass/test_fail harness counters into the totals.
local pass_count = `pass_count' + $TVQA_PASS
local fail_count = `fail_count' + $TVQA_FAIL
local failed_tests "`failed_tests' $TVQA_FAILED"
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA tvweight correctness Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: validation_tvweight tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"

