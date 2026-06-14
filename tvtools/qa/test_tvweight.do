clear all
set more off
set varabbrev off
version 16.0

capture log close
log using "test_tvweight.log", replace nomsg

* Shared scaffold: test globals + helpers + sandboxed install bootstrap
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""
local run_only = 0
local quiet = 0

* run_test/test_pass/test_fail harness counters (folded into the totals below)
global TVQA_PASS = 0
global TVQA_FAIL = 0
global TVQA_FAILED ""
global TVQA_CURRENT ""

display as result "tvtools QA: tvweight functional -- $S_DATE $S_TIME"


**# ===== merged from test_tvtools.do L7056-7506: SECTION 8 TVWEIGHT =====

* SECTION 8: TVWEIGHT - IPTW weight calculation

capture noisily {
* CREATE TEST DATA
if `quiet' == 0 {
    display as text _n "Creating test data..."
}

* Create a simple dataset with binary treatment and confounders
clear
set seed 12345
set obs 500

* Person ID
gen id = _n

* Time periods (simulate person-time data)
expand 4
bysort id: gen period = _n
bysort id: gen start = period * 90
bysort id: gen stop = start + 89

* Confounders
gen age = 40 + 20 * runiform()
gen sex = runiform() > 0.5
gen comorbidity = runiform() > 0.7

* Binary treatment influenced by confounders
gen ps_true = invlogit(-2 + 0.03*age + 0.5*sex + 0.8*comorbidity)
gen treatment = runiform() < ps_true

* Outcome (not needed for weight calculation, but useful)
gen outcome = runiform() < 0.1

tempfile testdata
save `testdata', replace

* Create categorical treatment version
use `testdata', clear
gen drug_type = 0
replace drug_type = 1 if treatment == 1 & runiform() < 0.6
replace drug_type = 2 if treatment == 1 & drug_type == 0

tempfile testdata_cat
save `testdata_cat', replace

if `quiet' == 0 {
    display as result "Test data created: 500 persons, 4 periods each"
}

* SECTION 1: BASIC FUNCTIONALITY
if `quiet' == 0 {
    display as text "{hline 70}"
}

* Test 1.1: Basic IPTW calculation
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    if `quiet' == 0 {
        display as text _n "Test 1.1: Basic IPTW calculation"
    }

    capture {
        use `testdata', clear
        tvweight treatment, covariates(age sex) nolog
        * Verify weight variable exists
        confirm variable iptw
        * Verify weights are positive
        assert iptw > 0
        * Verify return values exist
        assert r(N) > 0
        assert r(ess) > 0
    }
    if _rc == 0 {
        display as result "  PASS: Basic IPTW calculation works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Basic IPTW calculation (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 1.1"
    }
}

* Test 1.2: Custom variable name
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    if `quiet' == 0 {
        display as text _n "Test 1.2: Custom variable name"
    }

    capture {
        use `testdata', clear
        tvweight treatment, covariates(age sex) generate(myweights) nolog
        confirm variable myweights
        assert myweights > 0
    }
    if _rc == 0 {
        display as result "  PASS: Custom variable name works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Custom variable name (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 1.2"
    }
}

* Test 1.3: Multiple covariates
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    if `quiet' == 0 {
        display as text _n "Test 1.3: Multiple covariates"
    }

    capture {
        use `testdata', clear
        tvweight treatment, covariates(age sex comorbidity) nolog
        confirm variable iptw
        assert iptw > 0
    }
    if _rc == 0 {
        display as result "  PASS: Multiple covariates works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Multiple covariates (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 1.3"
    }
}

* SECTION 2: STABILIZED WEIGHTS
if `quiet' == 0 {
    display as text "{hline 70}"
}

* Test 2.1: Stabilized weights
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    if `quiet' == 0 {
        display as text _n "Test 2.1: Stabilized weights"
    }

    capture {
        use `testdata', clear
        tvweight treatment, covariates(age sex) stabilized nolog
        confirm variable iptw
        assert iptw > 0
        * Stabilized weights should have mean closer to 1
        sum iptw
        assert abs(r(mean) - 1) < 0.5
    }
    if _rc == 0 {
        display as result "  PASS: Stabilized weights works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Stabilized weights (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 2.1"
    }
}

* SECTION 3: TRUNCATION
if `quiet' == 0 {
    display as text "{hline 70}"
}

* Test 3.1: Truncation at percentiles
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    if `quiet' == 0 {
        display as text _n "Test 3.1: Truncation at percentiles"
    }

    capture {
        use `testdata', clear
        tvweight treatment, covariates(age sex) truncate(1 99) nolog
        confirm variable iptw
        assert iptw > 0
        * Verify truncation was applied
        assert r(n_truncated) != .
    }
    if _rc == 0 {
        display as result "  PASS: Truncation works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Truncation (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 3.1"
    }
}

* Test 3.2: Truncation with stabilized
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    if `quiet' == 0 {
        display as text _n "Test 3.2: Truncation with stabilized"
    }

    capture {
        use `testdata', clear
        tvweight treatment, covariates(age sex) stabilized truncate(5 95) nolog
        confirm variable iptw
        assert iptw > 0
    }
    if _rc == 0 {
        display as result "  PASS: Truncation with stabilized works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Truncation with stabilized (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 3.2"
    }
}

* SECTION 4: MULTINOMIAL TREATMENT
if `quiet' == 0 {
    display as text "{hline 70}"
}

* Test 4.1: Multinomial treatment (3 levels)
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
    if `quiet' == 0 {
        display as text _n "Test 4.1: Multinomial treatment"
    }

    capture {
        use `testdata_cat', clear
        tvweight drug_type, covariates(age sex) model(mlogit) nolog
        confirm variable iptw
        assert iptw > 0
        assert r(n_levels) == 3
    }
    if _rc == 0 {
        display as result "  PASS: Multinomial treatment works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Multinomial treatment (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 4.1"
    }
}

* SECTION 5: DENOMINATOR OUTPUT
if `quiet' == 0 {
    display as text "{hline 70}"
}

* Test 5.1: Propensity score output
local ++test_count
if `run_only' == 0 | `run_only' == 8 {
    if `quiet' == 0 {
        display as text _n "Test 5.1: Propensity score output"
    }

    capture {
        use `testdata', clear
        tvweight treatment, covariates(age sex) denominator(ps) nolog
        confirm variable iptw
        confirm variable ps
        * PS should be between 0 and 1
        assert ps > 0 & ps < 1
    }
    if _rc == 0 {
        display as result "  PASS: Propensity score output works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Propensity score output (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 5.1"
    }
}

* SECTION 6: REPLACE OPTION
if `quiet' == 0 {
    display as text "{hline 70}"
}

* Test 6.1: Replace existing variable
local ++test_count
if `run_only' == 0 | `run_only' == 9 {
    if `quiet' == 0 {
        display as text _n "Test 6.1: Replace existing variable"
    }

    capture {
        use `testdata', clear
        tvweight treatment, covariates(age) nolog
        * Run again with replace
        tvweight treatment, covariates(age sex) replace nolog
        confirm variable iptw
    }
    if _rc == 0 {
        display as result "  PASS: Replace option works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Replace option (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 6.1"
    }
}

* Test 6.2: Error without replace when variable exists
local ++test_count
if `run_only' == 0 | `run_only' == 10 {
    if `quiet' == 0 {
        display as text _n "Test 6.2: Error without replace"
    }

    capture {
        use `testdata', clear
        tvweight treatment, covariates(age) nolog
        * Should fail without replace
        capture tvweight treatment, covariates(age sex) nolog
        assert _rc == 110
    }
    if _rc == 0 {
        display as result "  PASS: Error without replace works"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Error without replace (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 6.2"
    }
}

* SECTION 7: ERROR HANDLING
if `quiet' == 0 {
    display as text "{hline 70}"
}

* Test 7.1: Missing covariates option
local ++test_count
if `run_only' == 0 | `run_only' == 11 {
    if `quiet' == 0 {
        display as text _n "Test 7.1: Missing covariates option"
    }

    capture {
        use `testdata', clear
        capture tvweight treatment
        assert _rc != 0
    }
    if _rc == 0 {
        display as result "  PASS: Missing covariates produces error"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Missing covariates not caught"
        local ++fail_count
        local failed_tests "`failed_tests' 7.1"
    }
}

* Test 7.2: Invalid truncation values
local ++test_count
if `run_only' == 0 | `run_only' == 12 {
    if `quiet' == 0 {
        display as text _n "Test 7.2: Invalid truncation values"
    }

    capture {
        use `testdata', clear
        capture tvweight treatment, covariates(age) truncate(99 1)
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: Invalid truncation produces error"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Invalid truncation not caught"
        local ++fail_count
        local failed_tests "`failed_tests' 7.2"
    }
}

* Test 7.3: Constant exposure (1 level)
local ++test_count
if `run_only' == 0 | `run_only' == 13 {
    if `quiet' == 0 {
        display as text _n "Test 7.3: Constant exposure"
    }

    capture {
        use `testdata', clear
        replace treatment = 1
        capture tvweight treatment, covariates(age) nolog
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: Constant exposure produces error"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Constant exposure not caught"
        local ++fail_count
        local failed_tests "`failed_tests' 7.3"
    }
}

* SECTION 8: RETURN VALUES
if `quiet' == 0 {
    display as text "{hline 70}"
}

* Test 8.1: All return values present
local ++test_count
if `run_only' == 0 | `run_only' == 14 {
    if `quiet' == 0 {
        display as text _n "Test 8.1: Return values"
    }

    capture {
        use `testdata', clear
        tvweight treatment, covariates(age sex) nolog
        * Check all expected return values
        assert r(N) > 0
        assert r(n_levels) == 2
        assert r(ess) > 0
        assert r(ess_pct) > 0 & r(ess_pct) <= 100
        assert r(w_mean) > 0
        assert r(w_sd) >= 0
        assert r(w_min) > 0
        assert r(w_max) > 0
        assert r(w_p50) > 0
        assert "`r(exposure)'" == "treatment"
        assert "`r(model)'" == "logit"
        assert "`r(generate)'" == "iptw"
    }
    if _rc == 0 {
        display as result "  PASS: All return values present"
        local ++pass_count
    }
    else {
        display as error "  FAIL: Return values (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' 8.1"
    }
}

}

**# ===== merged from test_tvtools.do L13615-14076: TVWEIGHT comprehensive =====

* SECTION 1: TVWEIGHT — comprehensive option and edge case tests

* Generate standard test data for tvweight
capture {
    clear
    set seed 54321
    set obs 500
    gen id = ceil(_n / 5)
    gen time = mod(_n - 1, 5) + 1
    gen age = 50 + 10 * rnormal()
    gen female = (runiform() < 0.5)
    gen comorbidity = (runiform() < 0.3)
    * Treatment depends on confounders
    gen pr_treat = invlogit(-1 + 0.02 * age + 0.5 * female + 0.3 * comorbidity)
    gen treatment = (runiform() < pr_treat)
    gen bp_change = 5 * rnormal()
    tempfile weight_data
    save `weight_data'
}

* TEST 1.1: Basic binary IPTW with all stored results
local ++test_count
capture noisily {
    use `weight_data', clear
    tvweight treatment, covariates(age female comorbidity) generate(w1) nolog
    * Check all required stored results
    assert r(N) == 500
    assert r(n_levels) == 2
    assert r(ess) > 0
    assert r(ess_pct) > 0 & r(ess_pct) <= 100
    assert !missing(r(w_mean))
    assert !missing(r(w_sd))
    assert r(w_min) > 0
    assert !missing(r(w_max))
    assert !missing(r(w_p1))
    assert !missing(r(w_p5))
    assert !missing(r(w_p25))
    assert !missing(r(w_p50))
    assert !missing(r(w_p75))
    assert !missing(r(w_p95))
    assert !missing(r(w_p99))
    assert "`r(exposure)'" == "treatment"
    assert "`r(covariates)'" == "age female comorbidity"
    assert "`r(model)'" == "logit"
    assert "`r(generate)'" == "w1"
    * Weight variable exists
    capture confirm variable w1
    assert _rc == 0
    * All weights positive
    assert w1 > 0 if !missing(w1)
}
if _rc == 0 {
    display as result "  PASS: Basic binary IPTW with all stored results"
    local ++pass_count
}
else {
    display as error "  FAIL: Basic binary IPTW with all stored results (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}

* TEST 1.2: Default generate name (iptw)
local ++test_count
capture noisily {
    use `weight_data', clear
    tvweight treatment, covariates(age female) nolog
    capture confirm variable iptw
    assert _rc == 0
    assert "`r(generate)'" == "iptw"
}
if _rc == 0 {
    display as result "  PASS: Default generate name is 'iptw'"
    local ++pass_count
}
else {
    display as error "  FAIL: Default generate name is 'iptw' (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
}

* TEST 1.3: Stabilized weights
local ++test_count
capture noisily {
    use `weight_data', clear
    tvweight treatment, covariates(age female) generate(sw) stabilized nolog
    assert "`r(stabilized)'" == "stabilized"
    * Stabilized weights should have mean closer to 1
    quietly sum sw
    assert abs(r(mean) - 1) < 0.5
}
if _rc == 0 {
    display as result "  PASS: Stabilized weights"
    local ++pass_count
}
else {
    display as error "  FAIL: Stabilized weights (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.3"
}

* TEST 1.4: Truncation at percentiles
local ++test_count
capture noisily {
    use `weight_data', clear
    tvweight treatment, covariates(age female) generate(tw) truncate(5 95) nolog
    assert r(n_truncated) >= 0
    assert r(trunc_lo) == 5
    assert r(trunc_hi) == 95
    * After truncation, range should be narrower
    quietly sum tw
    local trunc_min = r(min)
    local trunc_max = r(max)
}
if _rc == 0 {
    display as result "  PASS: Truncation at 5th/95th percentiles"
    local ++pass_count
}
else {
    display as error "  FAIL: Truncation at 5th/95th percentiles (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.4"
}

* TEST 1.5: Truncation bounds validation
local ++test_count
capture noisily {
    use `weight_data', clear
    * Lower >= upper should error
    capture tvweight treatment, covariates(age female) generate(bw) truncate(95 5) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Truncation lower >= upper returns error 198"
    local ++pass_count
}
else {
    display as error "  FAIL: Truncation lower >= upper returns error 198 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.5"
}

* TEST 1.6: Multinomial logit for 3+ categories
local ++test_count
capture noisily {
    use `weight_data', clear
    * Create 3-category treatment
    gen treat3 = cond(runiform() < 0.33, 0, cond(runiform() < 0.5, 1, 2))
    tvweight treat3, covariates(age female) generate(mw) nolog
    assert r(n_levels) == 3
    assert "`r(model)'" == "mlogit"
    capture confirm variable mw
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: Multinomial logit for 3+ categories"
    local ++pass_count
}
else {
    display as error "  FAIL: Multinomial logit for 3+ categories (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.6"
}

* TEST 1.7: Auto-switch logit to mlogit for >2 levels
local ++test_count
capture noisily {
    use `weight_data', clear
    gen treat3 = mod(_n, 3)
    tvweight treat3, covariates(age female) model(logit) generate(auto_w) nolog
    * Should auto-switch to mlogit
    assert "`r(model)'" == "mlogit"
}
if _rc == 0 {
    display as result "  PASS: Auto-switch logit to mlogit for >2 levels"
    local ++pass_count
}
else {
    display as error "  FAIL: Auto-switch logit to mlogit for >2 levels (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.7"
}

* TEST 1.8: Auto-switch mlogit to logit for binary
local ++test_count
capture noisily {
    use `weight_data', clear
    tvweight treatment, covariates(age female) model(mlogit) generate(ml_w) nolog
    assert "`r(model)'" == "logit"
}
if _rc == 0 {
    display as result "  PASS: Auto-switch mlogit to logit for binary exposure"
    local ++pass_count
}
else {
    display as error "  FAIL: Auto-switch mlogit to logit for binary exposure (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.8"
}

* TEST 1.9: Panel mode with id/time/tvcovariates
local ++test_count
capture noisily {
    use `weight_data', clear
    tvweight treatment, covariates(age female) tvcovariates(bp_change) ///
        id(id) time(time) generate(panel_w) nolog
    capture confirm variable panel_w
    assert _rc == 0
    assert r(N) == 500
}
if _rc == 0 {
    display as result "  PASS: Panel mode with id/time/tvcovariates"
    local ++pass_count
}
else {
    display as error "  FAIL: Panel mode with id/time/tvcovariates (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.9"
}

* TEST 1.10: tvcovariates without id/time — error 198
local ++test_count
capture noisily {
    use `weight_data', clear
    capture tvweight treatment, covariates(age female) tvcovariates(bp_change) ///
        generate(err_w) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvcovariates without id/time returns error 198"
    local ++pass_count
}
else {
    display as error "  FAIL: tvcovariates without id/time returns error 198 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.10"
}

* TEST 1.11: Denominator option
local ++test_count
capture noisily {
    use `weight_data', clear
    tvweight treatment, covariates(age female) generate(dw) denominator(ps_score) nolog
    capture confirm variable ps_score
    assert _rc == 0
    assert "`r(denominator)'" == "ps_score"
    * PS should be between 0 and 1
    assert ps_score >= 0 & ps_score <= 1 if !missing(ps_score)
}
if _rc == 0 {
    display as result "  PASS: Denominator option generates propensity score"
    local ++pass_count
}
else {
    display as error "  FAIL: Denominator option generates propensity score (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.11"
}

* TEST 1.12: Replace option
local ++test_count
capture noisily {
    use `weight_data', clear
    gen iptw = 1
    * Without replace, should error
    capture tvweight treatment, covariates(age female) nolog
    assert _rc == 110
    * With replace, should work
    tvweight treatment, covariates(age female) replace nolog
    capture confirm variable iptw
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: Replace option works correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Replace option works correctly (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.12"
}

* TEST 1.13: Single exposure level — error 198
local ++test_count
capture noisily {
    use `weight_data', clear
    gen single = 1
    capture tvweight single, covariates(age female) generate(fail_w) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Single exposure level returns error 198"
    local ++pass_count
}
else {
    display as error "  FAIL: Single exposure level returns error 198 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.13"
}

* TEST 1.14: Non-0/1 binary exposure — error 198
local ++test_count
capture noisily {
    use `weight_data', clear
    gen treat_12 = treatment + 1
    capture tvweight treat_12, covariates(age female) generate(fail_w) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Non-0/1 binary exposure returns error 198"
    local ++pass_count
}
else {
    display as error "  FAIL: Non-0/1 binary exposure returns error 198 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.14"
}

* TEST 1.15: No observations after if restriction — error 2000
local ++test_count
capture noisily {
    use `weight_data', clear
    capture tvweight treatment if age > 999, covariates(age female) generate(nw) nolog
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: No observations returns error 2000"
    local ++pass_count
}
else {
    display as error "  FAIL: No observations returns error 2000 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.15"
}

* TEST 1.16: Invalid model type — error 198
local ++test_count
capture noisily {
    use `weight_data', clear
    capture tvweight treatment, covariates(age female) model(probit) generate(nw) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Invalid model type returns error 198"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid model type returns error 198 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.16"
}

* TEST 1.17: if/in restriction
local ++test_count
capture noisily {
    use `weight_data', clear
    tvweight treatment if time == 1, covariates(age female) generate(ifw) nolog
    assert r(N) == 100
}
if _rc == 0 {
    display as result "  PASS: if restriction works correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: if restriction works correctly (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.17"
}

* TEST 1.18: Stabilized + truncated combined
local ++test_count
capture noisily {
    use `weight_data', clear
    tvweight treatment, covariates(age female) generate(stw) ///
        stabilized truncate(1 99) nolog
    assert "`r(stabilized)'" == "stabilized"
    assert r(n_truncated) >= 0
}
if _rc == 0 {
    display as result "  PASS: Stabilized + truncated combined"
    local ++pass_count
}
else {
    display as error "  FAIL: Stabilized + truncated combined (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.18"
}

* TEST 1.19: Varabbrev restore after tvweight
local ++test_count
capture noisily {
    use `weight_data', clear
    set varabbrev on
    tvweight treatment, covariates(age female) generate(va_w) nolog
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: Varabbrev restored after tvweight"
    local ++pass_count
}
else {
    display as error "  FAIL: Varabbrev restored after tvweight (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.19"
}

* TEST 1.20: Varabbrev restore after tvweight error
local ++test_count
capture noisily {
    use `weight_data', clear
    set varabbrev on
    capture tvweight treatment if age > 999, covariates(age female) generate(va_w) nolog
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: Varabbrev restored after tvweight error"
    local ++pass_count
}
else {
    display as error "  FAIL: Varabbrev restored after tvweight error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.20"
}

* TEST 1.21: nolog suppresses iteration output
local ++test_count
capture noisily {
    use `weight_data', clear
    tvweight treatment, covariates(age female) generate(nl_w) nolog
    capture confirm variable nl_w
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: nolog option works"
    local ++pass_count
}
else {
    display as error "  FAIL: nolog option works (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.21"
}

* TEST 1.22: Data preserved (N unchanged after tvweight)
local ++test_count
capture noisily {
    use `weight_data', clear
    local n_before = _N
    tvweight treatment, covariates(age female) generate(dp_w) nolog
    assert _N == `n_before'
}
if _rc == 0 {
    display as result "  PASS: Data preserved (N unchanged after tvweight)"
    local ++pass_count
}
else {
    display as error "  FAIL: Data preserved (N unchanged after tvweight) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.22"
}



* ===== Summary =====
* Fold the run_test/test_pass/test_fail harness counters into the totals.
local pass_count = `pass_count' + $TVQA_PASS
local fail_count = `fail_count' + $TVQA_FAIL
local failed_tests "`failed_tests' $TVQA_FAILED"
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA tvweight functional Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: test_tvweight tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"

