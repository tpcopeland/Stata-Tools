/*******************************************************************************
* validation_cstat_surv.do
*
* Validation tests for cstat_surv: known-answer, invariants, boundary tests
* Self-contained: all data generated inline
*
* Author: Timothy P Copeland
* Date: 2026-03-19
*******************************************************************************/

clear all
set more off
version 16.0

* Install from local directory

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

capture ado uninstall cstat_surv
capture program drop cstat_surv
adopath ++ "`pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0

display as text _n "{hline 70}"
display as text "CSTAT_SURV VALIDATION TESTS"
display as text "{hline 70}"

* =============================================================================
* SECTION 1: PERFECT PREDICTION
* =============================================================================
display as text _n "Section 1: Perfect Prediction"
display as text "{hline 50}"

* Test 1: Perfect concordance — higher x = higher risk = shorter survival
local ++test_count
capture noisily {
    clear
    input double time byte event double x
        1 1 5
        2 1 4
        3 1 3
        4 1 2
        5 0 1
    end
    stset time, failure(event)
    stcox x
    cstat_surv
    * Cox learns that higher x = higher risk, so C should be very high
    assert e(c) > 0.9
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Perfect prediction (C > 0.9)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Perfect prediction (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 2: RANDOM PREDICTION
* =============================================================================
display as text _n "Section 2: Random Prediction"
display as text "{hline 50}"

* Test 2: Random predictor — C near 0.5
local ++test_count
capture noisily {
    clear
    set seed 54321
    set obs 200
    gen double time = runiform() * 10
    gen byte event = runiform() > 0.3
    gen double x = runiform()

    stset time, failure(event)
    stcox x
    cstat_surv
    * Random predictor: C should be around 0.5
    assert e(c) > 0.3 & e(c) < 0.7
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Random predictor (C near 0.5)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Random predictor (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 3: KNOWN-ANSWER TEST
* =============================================================================
display as text _n "Section 3: Known-Answer Tests"
display as text "{hline 50}"

* Test 3: Hand-calculated concordance
* 4 obs: 3 events, 1 censored. All distinct times, no ties.
* Higher x = higher risk. Cox should learn this perfectly.
* Comparable pairs: (1,2) (1,3) (1,4) (2,3) (2,4) (3,4) = 6 pairs
* After Cox fits, predicted HR should order correctly → all concordant → C ≈ 1
local ++test_count
capture noisily {
    clear
    input double time byte event double x
        1 1 4.0
        2 1 3.0
        3 1 2.0
        4 0 1.0
    end
    stset time, failure(event)
    stcox x
    cstat_surv
    assert e(c) > 0.95
    * 6 comparable pairs total
    assert e(N_comparable) == 6
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Hand-calculated known-answer"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Hand-calculated known-answer (rc=`=_rc')"
    local ++fail_count
}

* Test 4: Somers' D consistency with C
* D = (concordant - discordant) / comparable = 2C - 1
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv

    * Verify D = 2C - 1 within tolerance
    local c_val = e(c)
    local d_val = e(somers_d)
    local expected = 2 * `c_val' - 1
    assert abs(`d_val' - `expected') < 0.0001

    * Verify D = (conc - disc) / comparable
    local d_formula = (e(N_concordant) - e(N_discordant)) / e(N_comparable)
    assert abs(`d_val' - `d_formula') < 0.0001
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Somers' D consistency"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Somers' D consistency (rc=`=_rc')"
    local ++fail_count
}

* Test 5: C = (concordant + 0.5*tied) / comparable
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv

    local c_formula = (e(N_concordant) + 0.5 * e(N_tied)) / e(N_comparable)
    assert abs(e(c) - `c_formula') < 0.0001
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — C formula verification"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — C formula verification (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 4: INVARIANT TESTS
* =============================================================================
display as text _n "Section 4: Invariant Tests"
display as text "{hline 50}"

* Test 6: C in [0, 1]
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    assert e(c) >= 0 & e(c) <= 1
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — C in [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — C in [0,1] (rc=`=_rc')"
    local ++fail_count
}

* Test 7: SE >= 0
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    assert e(se) >= 0
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — SE >= 0"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — SE >= 0 (rc=`=_rc')"
    local ++fail_count
}

* Test 8: CI contains C-statistic
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    assert e(c) >= e(ci_lo)
    assert e(c) <= e(ci_hi)
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — CI contains C"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — CI contains C (rc=`=_rc')"
    local ++fail_count
}

* Test 9: df_r = N - 1
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    assert e(df_r) == e(N) - 1
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — df_r = N - 1"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — df_r = N - 1 (rc=`=_rc')"
    local ++fail_count
}

* Test 10: V matrix = se^2
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    local v_val = el(e(V), 1, 1)
    assert abs(`v_val' - e(se)^2) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — V matrix = se^2"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — V matrix = se^2 (rc=`=_rc')"
    local ++fail_count
}

* Test 11: Invariant across multiple datasets — C always in [0,1], SE >= 0
local ++test_count
capture noisily {
    * Dataset A: large synthetic
    clear
    set seed 99999
    set obs 500
    gen double time = rexponential(5)
    gen byte event = runiform() > 0.4
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    stset time, failure(event)
    stcox x1 x2
    cstat_surv
    assert e(c) >= 0 & e(c) <= 1
    assert e(se) >= 0
    assert e(ci_lo) >= 0
    assert e(ci_hi) <= 1

    * Dataset B: small synthetic
    clear
    set seed 11111
    set obs 20
    gen double time = rexponential(3)
    gen byte event = runiform() > 0.5
    replace event = 1 in 1/5
    gen double x = rnormal()
    stset time, failure(event)
    stcox x
    cstat_surv
    assert e(c) >= 0 & e(c) <= 1
    assert e(se) >= 0
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Invariants across datasets"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Invariants across datasets (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 5: REPRODUCIBILITY AND INVARIANTS
* =============================================================================
display as text _n "Section 5: Reproducibility and Invariants"
display as text "{hline 50}"

* Test 12: Reproducibility — same data, same result
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    local c1 = e(c)
    local se1 = e(se)
    local conc1 = e(N_concordant)
    local disc1 = e(N_discordant)
    local tied1 = e(N_tied)

    * Run again on same data (stcox unchanged)
    stcox age drug
    cstat_surv
    assert abs(e(c) - `c1') < 1e-12
    assert abs(e(se) - `se1') < 1e-12
    assert abs(e(N_concordant) - `conc1') < 1e-10
    assert abs(e(N_discordant) - `disc1') < 1e-10
    assert abs(e(N_tied) - `tied1') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Reproducibility"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Reproducibility (rc=`=_rc')"
    local ++fail_count
}

* Test 13: Sort invariance — shuffled data, same result
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    local c_orig = e(c)
    local se_orig = e(se)

    * Shuffle and re-run
    set seed 13013
    gen double _sort_rand = runiform()
    sort _sort_rand
    drop _sort_rand
    stcox age drug
    cstat_surv
    assert abs(e(c) - `c_orig') < 1e-10
    assert abs(e(se) - `se_orig') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Sort invariance"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Sort invariance (rc=`=_rc')"
    local ++fail_count
}

* Test 14: Monotonicity — stronger predictor yields higher C
local ++test_count
capture noisily {
    clear
    set seed 14014
    set obs 200
    gen double x_strong = rnormal()
    * Survival time strongly determined by x_strong
    gen double time = exp(-1.5 * x_strong + rnormal() * 0.3)
    gen byte event = runiform() > 0.2
    replace event = 1 in 1/40
    gen double x_weak = rnormal()
    stset time, failure(event)

    * Strong predictor
    stcox x_strong
    cstat_surv
    local c_strong = e(c)

    * Weak (random) predictor
    stcox x_weak
    cstat_surv
    local c_weak = e(c)

    * Strong predictor should give higher C
    assert `c_strong' > `c_weak'
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Monotonicity (strong > weak predictor)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Monotonicity (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 6: BOUNDARY TESTS
* =============================================================================
display as text _n "Section 6: Boundary Tests"
display as text "{hline 50}"

* Test 15: Boundary — 2 observations (1 event, 1 censored)
* Hand calculation: 1 comparable pair (event at t=1, censored at t=2)
* If HR predicts higher risk for event obs → concordant → C = 1
* If HR predicts lower risk → discordant → C = 0
local ++test_count
capture noisily {
    clear
    input double time byte event double x
        1 1 10
        2 0 1
    end
    stset time, failure(event)
    stcox x
    cstat_surv
    assert !missing(e(c))
    assert e(N) == 2
    assert e(N_comparable) == 1
    * C must be 0 or 1 with single pair (or 0.5 if tied)
    assert e(c) == 0 | e(c) == 0.5 | e(c) == 1
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Boundary: 2 obs (1 event, 1 censored)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Boundary: 2 obs (rc=`=_rc')"
    local ++fail_count
}

* Test 16: All tied times with events — known pair count
* 4 obs, all time=5, all event=1. All pairs have tied times + both events.
* Comparable pairs: C(4,2) = 6
* Each pair: both events + tied time → 0.5 concordant, 0.5 discordant
* C = (sum of concordant contributions) / comparable
local ++test_count
capture noisily {
    clear
    input double time byte event double x
        5 1 1
        5 1 2
        5 1 3
        5 1 4
    end
    stset time, failure(event)
    stcox x
    cstat_surv
    assert !missing(e(c))
    * 6 comparable pairs = C(4,2)
    assert e(N_comparable) == 6
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — All tied times with events"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — All tied times (rc=`=_rc')"
    local ++fail_count
}

* Test 17: C formula verified on synthetic dataset
local ++test_count
capture noisily {
    clear
    set seed 17017
    set obs 80
    gen double time = rexponential(3)
    gen byte event = runiform() > 0.35
    replace event = 1 in 1/15
    gen double x = rnormal()
    stset time, failure(event)
    stcox x
    cstat_surv
    local c_formula = (e(N_concordant) + 0.5 * e(N_tied)) / e(N_comparable)
    assert abs(e(c) - `c_formula') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — C formula on synthetic data"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — C formula on synthetic (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SECTION 7: STATISTICAL PROPERTIES
* =============================================================================
display as text _n "Section 7: Statistical Properties"
display as text "{hline 50}"

* Test 18: SE decreases with larger N
local ++test_count
capture noisily {
    * Small dataset
    clear
    set seed 18018
    set obs 30
    gen double x = rnormal()
    gen double time = exp(-0.5 * x + rnormal())
    gen byte event = runiform() > 0.3
    replace event = 1 in 1/8
    stset time, failure(event)
    stcox x
    cstat_surv
    local se_small = e(se)

    * Large dataset (same DGP)
    clear
    set seed 18018
    set obs 500
    gen double x = rnormal()
    gen double time = exp(-0.5 * x + rnormal())
    gen byte event = runiform() > 0.3
    replace event = 1 in 1/100
    stset time, failure(event)
    stcox x
    cstat_surv
    local se_large = e(se)

    * SE should be smaller with more data
    assert `se_large' < `se_small'
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — SE decreases with larger N"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — SE decreases with N (rc=`=_rc')"
    local ++fail_count
}

* Test 19: CI width decreases with larger N
local ++test_count
capture noisily {
    * Small dataset
    clear
    set seed 19019
    set obs 25
    gen double x = rnormal()
    gen double time = exp(-0.5 * x + rnormal())
    gen byte event = runiform() > 0.3
    replace event = 1 in 1/6
    stset time, failure(event)
    stcox x
    cstat_surv
    local width_small = e(ci_hi) - e(ci_lo)

    * Large dataset
    clear
    set seed 19019
    set obs 400
    gen double x = rnormal()
    gen double time = exp(-0.5 * x + rnormal())
    gen byte event = runiform() > 0.3
    replace event = 1 in 1/80
    stset time, failure(event)
    stcox x
    cstat_surv
    local width_large = e(ci_hi) - e(ci_lo)

    assert `width_large' < `width_small'
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — CI width decreases with larger N"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — CI width decreases with N (rc=`=_rc')"
    local ++fail_count
}

* Test 20: Somers' D = 2C - 1 across multiple datasets
local ++test_count
capture noisily {
    forvalues ds = 1/3 {
        clear
        set seed `=20020 + `ds''
        set obs 60
        gen double time = rexponential(4)
        gen byte event = runiform() > 0.4
        replace event = 1 in 1/10
        gen double x = rnormal()
        stset time, failure(event)
        stcox x
        cstat_surv
        local expected_d = 2 * e(c) - 1
        assert abs(e(somers_d) - `expected_d') < 1e-10
    }
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Somers' D = 2C-1 across datasets"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Somers' D consistency (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "CSTAT_SURV VALIDATION SUMMARY"
display as text "{hline 70}"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
}
else {
    display as text "Failed:       `fail_count'"
}
display as text "{hline 70}"

if `fail_count' > 0 {
    display as error "RESULT: FAIL"
    exit 1
}
else {
    display as result "RESULT: PASS"
}
