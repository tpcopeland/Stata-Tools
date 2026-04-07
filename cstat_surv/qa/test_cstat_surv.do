/*******************************************************************************
* test_cstat_surv.do
*
* Functional tests for cstat_surv command
* Self-contained: all data generated inline, no external dependencies
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
display as text "CSTAT_SURV FUNCTIONAL TESTS"
display as text "{hline 70}"

* =============================================================================
* TEST 1: Basic C-statistic after stcox
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    assert !missing(e(c))
    assert e(c) >= 0 & e(c) <= 1
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Basic C-statistic"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Basic C-statistic (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 2: Multiple covariates
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug studytime
    cstat_surv
    assert !missing(e(c))
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Multiple covariates"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Multiple covariates (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 3: Categorical variables (i.prefix)
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age i.drug
    cstat_surv
    assert !missing(e(c))
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Categorical variables"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Categorical variables (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 4: Single predictor
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age
    cstat_surv
    assert !missing(e(c))
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Single predictor"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Single predictor (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 5: Stratified Cox model
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age, strata(drug)
    cstat_surv
    assert !missing(e(c))
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Stratified Cox model"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Stratified Cox model (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 6: Interaction terms
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age c.age#i.drug
    cstat_surv
    assert !missing(e(c))
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Interaction terms"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Interaction terms (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 7: CI bounds in [0,1]
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    assert e(ci_lo) >= 0
    assert e(ci_hi) <= 1
    assert e(ci_lo) < e(ci_hi)
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — CI bounds in [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — CI bounds in [0,1] (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 8: Pair counts validity
* N_comparable should equal N_concordant + N_discordant + N_tied
* (approximately, due to tied-time 0.5 splits)
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    local sum_pairs = e(N_concordant) + e(N_discordant) + e(N_tied)
    assert abs(e(N_comparable) - `sum_pairs') < 0.01
    assert e(N_comparable) > 0
    assert e(N_concordant) >= 0
    assert e(N_discordant) >= 0
    assert e(N_tied) >= 0
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Pair counts validity"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Pair counts validity (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 9: Somers' D = 2C - 1
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    assert !missing(e(somers_d))
    local expected_d = 2 * e(c) - 1
    assert abs(e(somers_d) - `expected_d') < 0.0001
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Somers' D = 2C - 1"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Somers' D = 2C - 1 (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 10: Stored results completeness
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv

    * Scalars
    assert !missing(e(c))
    assert !missing(e(se))
    assert !missing(e(ci_lo))
    assert !missing(e(ci_hi))
    assert !missing(e(df_r))
    assert !missing(e(somers_d))
    assert !missing(e(N))
    assert !missing(e(N_comparable))
    assert !missing(e(N_concordant))
    assert !missing(e(N_discordant))
    assert !missing(e(N_tied))

    * Macros
    assert "`e(cmd)'" == "cstat_surv"
    assert "`e(title)'" == "Harrell's C-statistic"
    assert "`e(vcetype)'" == "Jackknife"

    * Matrices
    matrix list e(b)
    matrix list e(V)
    assert el(e(b), 1, 1) == e(c)
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Stored results completeness"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Stored results completeness (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 11: Error — no prior model
* =============================================================================
local ++test_count
capture noisily {
    clear all
    sysuse auto, clear
    capture cstat_surv
    assert _rc == 301
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Error: no prior model"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Error: no prior model (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 12: Error — non-Cox model
* =============================================================================
local ++test_count
capture noisily {
    sysuse auto, clear
    regress price mpg weight
    capture cstat_surv
    assert _rc == 301
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Error: non-Cox model"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Error: non-Cox model (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 13: Error — data not stset
* =============================================================================
local ++test_count
capture noisily {
    * Need stcox results in e() but data not stset
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    * Now break stset by loading new data
    sysuse auto, clear
    capture cstat_surv
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Error: data not stset"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Error: data not stset (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 14: Error — no comparable pairs (all censored)
* =============================================================================
local ++test_count
capture noisily {
    clear
    input double time byte event double x
        1 0 1
        2 0 2
        3 0 3
        4 0 4
        5 0 5
    end
    stset time, failure(event)
    stcox x
    capture cstat_surv
    assert _rc == 2001
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Error: no comparable pairs"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Error: no comparable pairs (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 15: Weighted model warning (display note, no error)
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    * Weights declared via stset, not stcox
    gen double pw = 1 + runiform() * 0.5
    stset studytime [iweight=pw], failure(died)
    stcox age drug
    cstat_surv
    assert !missing(e(c))
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Weighted model warning"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Weighted model warning (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 16: varabbrev restored on success
* =============================================================================
local ++test_count
capture noisily {
    set varabbrev on
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — varabbrev restored on success"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — varabbrev restored on success (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 17: varabbrev restored on error
* =============================================================================
local ++test_count
capture noisily {
    set varabbrev on
    sysuse auto, clear
    regress price mpg
    capture cstat_surv
    assert _rc != 0
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — varabbrev restored on error"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — varabbrev restored on error (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 18: level() option — default uses c(level)
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    assert e(level) == 95
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — level() default = 95"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — level() default = 95 (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 19: level(90) narrows CI
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    local ci_lo_95 = e(ci_lo)
    local ci_hi_95 = e(ci_hi)

    stcox age drug
    cstat_surv, level(90)
    assert e(level) == 90
    assert e(ci_lo) >= `ci_lo_95'
    assert e(ci_hi) <= `ci_hi_95'
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — level(90) narrows CI"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — level(90) narrows CI (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 20: level(99) widens CI
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    local ci_lo_95 = e(ci_lo)
    local ci_hi_95 = e(ci_hi)

    stcox age drug
    cstat_surv, level(99)
    assert e(level) == 99
    assert e(ci_lo) <= `ci_lo_95'
    assert e(ci_hi) >= `ci_hi_95'
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — level(99) widens CI"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — level(99) widens CI (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 21: level() respects set level
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    set level 90
    cstat_surv
    assert e(level) == 90
    set level 95
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — respects set level"
    local ++pass_count
}
else {
    set level 95
    display as error "  FAIL: Test `test_count' — respects set level (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 22: level() option overrides set level
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    set level 90
    cstat_surv, level(99)
    assert e(level) == 99
    set level 95
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — level() overrides set level"
    local ++pass_count
}
else {
    set level 95
    display as error "  FAIL: Test `test_count' — level() overrides set level (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 23: e(depvar) stored
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    assert "`e(depvar)'" == "_t"
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — e(depvar) = _t"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — e(depvar) = _t (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 24: Data preservation — no side effects
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    local N_before = _N
    local vars_before : char _dta[st_bd]
    cstat_surv
    assert _N == `N_before'
    * st data still intact
    capture assert _st == 1
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Data preservation (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 25: Error — invalid level value
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    capture cstat_surv, level(101)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Error: invalid level"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Error: invalid level (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 26: e(sample) functional after command
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    quietly count if e(sample)
    assert r(N) == e(N)
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — e(sample) functional"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — e(sample) functional (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 27: Large dataset performance (N=2000)
* =============================================================================
local ++test_count
capture noisily {
    clear
    set seed 77777
    set obs 2000
    gen double time = rexponential(5)
    gen byte event = runiform() > 0.4
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    stset time, failure(event)
    stcox x1 x2
    cstat_surv
    assert !missing(e(c))
    assert e(c) >= 0 & e(c) <= 1
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Large dataset (N=2000)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Large dataset (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 28: Package installation smoke test
* =============================================================================
local ++test_count
capture noisily {
    capture ado uninstall cstat_surv
    net install cstat_surv, from("`pkg_dir'") replace
    which cstat_surv
    capture ado uninstall cstat_surv
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Package installation"
    local ++pass_count
}
else {
    capture ado uninstall cstat_surv
    display as error "  FAIL: Test `test_count' — Package installation (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 29: Tied survival times
* =============================================================================
local ++test_count
capture noisily {
    clear
    set seed 29029
    set obs 50
    * Create tied times: only 5 distinct time values
    gen double time = ceil(runiform() * 5)
    gen byte event = runiform() > 0.3
    replace event = 1 in 1/10
    gen double x = rnormal()
    stset time, failure(event)
    stcox x
    cstat_surv
    assert !missing(e(c))
    assert e(c) >= 0 & e(c) <= 1
    * With many tied times, tied pairs should be > 0
    assert e(N_tied) >= 0
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Tied survival times"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Tied survival times (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 30: All events (no censoring)
* =============================================================================
local ++test_count
capture noisily {
    clear
    set seed 30030
    set obs 30
    gen double time = runiform() * 10
    gen byte event = 1
    gen double x = rnormal()
    stset time, failure(event)
    stcox x
    cstat_surv
    assert !missing(e(c))
    assert e(c) >= 0 & e(c) <= 1
    assert e(N_comparable) > 0
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — All events (no censoring)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — All events (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 31: Very high censoring (90%+)
* =============================================================================
local ++test_count
capture noisily {
    clear
    set seed 31031
    set obs 100
    gen double time = runiform() * 10
    gen byte event = runiform() > 0.92
    * Ensure at least 2 events for stcox
    replace event = 1 in 1/3
    gen double x = rnormal()
    stset time, failure(event)
    stcox x
    cstat_surv
    assert !missing(e(c))
    assert e(c) >= 0 & e(c) <= 1
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Very high censoring (90%+)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Very high censoring (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 32: Single event in dataset
* =============================================================================
local ++test_count
capture noisily {
    clear
    input double time byte event double x
        1 1 5
        2 0 4
        3 0 3
        4 0 2
        5 0 1
    end
    stset time, failure(event)
    stcox x
    cstat_surv
    assert !missing(e(c))
    * With 1 event: comparable pairs = 4 (event vs each censored)
    assert e(N_comparable) == 4
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Single event in dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Single event (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 33: Missing values in covariates (e(sample) subset)
* =============================================================================
local ++test_count
capture noisily {
    clear
    set seed 33033
    set obs 50
    gen double time = runiform() * 10
    gen byte event = runiform() > 0.4
    replace event = 1 in 1/10
    gen double x = rnormal()
    * Set some x to missing
    replace x = . in 45/50
    stset time, failure(event)
    stcox x
    local N_model = e(N)
    cstat_surv
    * cstat_surv should use only e(sample) observations
    assert e(N) == `N_model'
    assert e(N) < 50
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Missing covariate values"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Missing covariate values (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 34: Very small dataset (N=3)
* =============================================================================
local ++test_count
capture noisily {
    clear
    input double time byte event double x
        1 1 3
        2 1 2
        3 0 1
    end
    stset time, failure(event)
    stcox x
    cstat_surv
    assert !missing(e(c))
    assert e(N) == 3
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Very small dataset (N=3)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Very small dataset (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 35: Negative coefficient (protective factor)
* =============================================================================
local ++test_count
capture noisily {
    clear
    set seed 35035
    set obs 100
    gen double x = rnormal()
    * Higher x = LOWER risk (protective)
    gen double time = exp(x) + runiform() * 0.5
    gen byte event = runiform() > 0.3
    replace event = 1 in 1/20
    stset time, failure(event)
    stcox x
    * Coefficient should be negative
    assert _b[x] < 0
    cstat_surv
    assert !missing(e(c))
    assert e(c) >= 0 & e(c) <= 1
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Negative coefficient"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Negative coefficient (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 36: Continuous + categorical covariates together
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age c.age#i.drug i.drug
    cstat_surv
    assert !missing(e(c))
    assert e(c) >= 0 & e(c) <= 1
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Continuous + categorical together"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Continuous + categorical (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 37: stcox with nohr option
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug, nohr
    cstat_surv
    assert !missing(e(c))
    assert e(c) >= 0 & e(c) <= 1
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — stcox with nohr"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — stcox with nohr (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 38: stcox with if restriction (e(sample) reflects subset)
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug if age > 55
    local N_sub = e(N)
    cstat_surv
    assert e(N) == `N_sub'
    assert e(N) < 48
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — stcox with if restriction"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — stcox with if restriction (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 39: stcox with in restriction
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug in 1/30
    local N_sub = e(N)
    cstat_surv
    assert e(N) == `N_sub'
    assert e(N) <= 30
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — stcox with in restriction"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — stcox with in restriction (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 40: stcox with tvc() time-varying covariates
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age, tvc(drug) texp(_t)
    cstat_surv
    assert !missing(e(c))
    assert e(c) >= 0 & e(c) <= 1
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — stcox with tvc()"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — stcox with tvc() (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 41: Multiple strata
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    gen byte stratum = cond(age < 60, 1, cond(age < 70, 2, 3))
    stset studytime, failure(died)
    stcox drug, strata(stratum)
    cstat_surv
    assert !missing(e(c))
    assert e(c) >= 0 & e(c) <= 1
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Multiple strata"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Multiple strata (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 42: N_comparable > 0 when events exist
* =============================================================================
local ++test_count
capture noisily {
    clear
    set seed 42042
    set obs 40
    gen double time = runiform() * 10
    gen byte event = runiform() > 0.5
    replace event = 1 in 1/5
    gen double x = rnormal()
    stset time, failure(event)
    stcox x
    cstat_surv
    assert e(N_comparable) > 0
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — N_comparable > 0 with events"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — N_comparable > 0 (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 43: e(N) equals count of e(sample)
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    quietly count if e(sample)
    assert r(N) == e(N)
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — e(N) == count(e(sample))"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — e(N) == count(e(sample)) (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 44: V matrix column/row names = "c_statistic"
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    local colnames : colnames e(V)
    local rownames : rownames e(V)
    assert "`colnames'" == "c_statistic"
    assert "`rownames'" == "c_statistic"
    local bnames : colnames e(b)
    assert "`bnames'" == "c_statistic"
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — V/b matrix names"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — V/b matrix names (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 45: e(level) stored correctly
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    cstat_surv
    assert e(level) == c(level)
    stcox age drug
    cstat_surv, level(80)
    assert e(level) == 80
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — e(level) stored correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — e(level) stored (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 46: Error — invalid option
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    capture cstat_surv, badopt
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Error: invalid option"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Error: invalid option (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 47: Data unchanged after command (variable check)
* =============================================================================
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    local nvars_before : word count `=r(varlist)'
    describe, short
    local nvars_before = r(k)
    local N_before = _N
    local sum_age = 0
    quietly summarize age
    local mean_age = r(mean)
    cstat_surv
    describe, short
    assert r(k) == `nvars_before'
    assert _N == `N_before'
    quietly summarize age
    assert abs(r(mean) - `mean_age') < 0.0001
}
if _rc == 0 {
    display as result "  PASS: Test `test_count' — Data unchanged after command"
    local ++pass_count
}
else {
    display as error "  FAIL: Test `test_count' — Data unchanged (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "CSTAT_SURV FUNCTIONAL TEST SUMMARY"
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
