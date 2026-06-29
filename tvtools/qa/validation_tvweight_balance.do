clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "validation_tvweight_balance.log", replace nomsg

* Shared scaffold: sandboxed install bootstrap
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as result "tvtools QA: tvweight balance/wtype/cumulative validation -- $S_DATE $S_TIME"

* -------------------------------------------------------------------------
* Fixed dataset used across the closed-form checks
* -------------------------------------------------------------------------
capture program drop _mk_data
program define _mk_data
    clear
    set seed 90210
    set obs 4000
    gen x1 = rnormal()
    gen x2 = rnormal()
    gen byte a = runiform() < invlogit(0.3 + 0.7*x1 - 0.5*x2)
end

* -------------------------------------------------------------------------
* Three-level categorical exposure (exercises the mlogit weight paths)
* -------------------------------------------------------------------------
capture program drop _mk_data_cat
program define _mk_data_cat
    clear
    set seed 24680
    set obs 4000
    gen x1 = rnormal()
    gen x2 = rnormal()
    gen double u1 = 0.3 + 0.6*x1
    gen double u2 = -0.2 + 0.5*x2
    gen double den = 1 + exp(u1) + exp(u2)
    gen double pp1 = exp(u1)/den
    gen double pp2 = exp(u2)/den
    gen double rr = runiform()
    gen byte a = 0
    replace a = 1 if rr < pp1
    replace a = 2 if rr >= pp1 & rr < pp1 + pp2
    drop u1 u2 den pp1 pp2 rr
end

**# TEST 1: Unweighted SMD parity (hand-computed vs r(balance))
local ++test_count
capture noisily {
    _mk_data
    tvweight a, covariates(x1 x2) generate(w) balance
    matrix B = r(balance)
    * Hand-compute SMD for x1 and x2 using unweighted pooled SD denominator
    foreach v in x1 x2 {
        quietly sum `v' if a == 1
        local mt = r(mean)
        local vt = r(Var)
        quietly sum `v' if a == 0
        local mc = r(mean)
        local vc = r(Var)
        local denom = sqrt((`vt' + `vc')/2)
        local smd_hand = (`mt' - `mc')/`denom'
        local row = cond("`v'" == "x1", 1, 2)
        assert abs(B[`row',1] - `smd_hand') < 1e-8
    }
}
if _rc == 0 {
    display as result "  PASS: unweighted SMD matches hand computation (~1e-8)"
    local ++pass_count
}
else {
    display as error "  FAIL: unweighted SMD parity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**# TEST 2: ATO exact-balance property (weighted SMD == 0)
local ++test_count
capture noisily {
    _mk_data
    tvweight a, covariates(x1 x2) generate(w) wtype(ato) balance
    assert "`r(wtype)'" == "ato"
    matrix B = r(balance)
    * Overlap weights with a logistic PS yield exactly zero weighted SMD
    assert abs(B[1,2]) < 1e-6
    assert abs(B[2,2]) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: ATO weighted SMD is exactly zero (<1e-6)"
    local ++pass_count
}
else {
    display as error "  FAIL: ATO exact balance (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# TEST 3: IPTW closed-form parity vs returned propensity score
local ++test_count
capture noisily {
    _mk_data
    tvweight a, covariates(x1 x2) generate(w) denominator(ps)
    assert "`r(wtype)'" == "iptw"
    gen double w_expected = cond(a == 1, 1/ps, 1/(1-ps))
    assert reldif(w, w_expected) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: IPTW = 1/PS (treated), 1/(1-PS) (control)"
    local ++pass_count
}
else {
    display as error "  FAIL: IPTW closed-form parity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**# TEST 4: ATO closed-form parity vs returned propensity score
local ++test_count
capture noisily {
    _mk_data
    tvweight a, covariates(x1 x2) generate(w) wtype(ato) denominator(ps)
    gen double w_expected = cond(a == 1, 1-ps, ps)
    assert reldif(w, w_expected) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: ATO = (1-PS) treated, PS control"
    local ++pass_count
}
else {
    display as error "  FAIL: ATO closed-form parity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**# TEST 5: Matching-weight closed-form parity
local ++test_count
capture noisily {
    _mk_data
    tvweight a, covariates(x1 x2) generate(w) wtype(matching) denominator(ps)
    gen double w_expected = min(ps, 1-ps) / cond(a == 1, ps, 1-ps)
    assert reldif(w, w_expected) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: matching = min(PS,1-PS)/P(observed arm)"
    local ++pass_count
}
else {
    display as error "  FAIL: matching closed-form parity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

**# TEST 6: estname stores a usable propensity model
local ++test_count
capture noisily {
    _mk_data
    tvweight a, covariates(x1 x2) generate(w) estname(ps_mod)
    assert "`r(estname)'" == "ps_mod"
    estimates restore ps_mod
    assert e(cmd) == "logit"
    margins, dydx(x1) post
    estimates restore ps_mod
}
if _rc == 0 {
    display as result "  PASS: estname stores a logit model that margins can use"
    local ++pass_count
}
else {
    display as error "  FAIL: estname store/restore (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

**# TEST 7: cumulative product matches manual within-person computation
local ++test_count
capture noisily {
    clear
    set seed 555
    set obs 50
    gen long id = _n
    expand 4
    bysort id: gen int t = _n
    gen x1 = rnormal()
    gen byte a = runiform() < invlogit(0.2 + 0.5*x1)
    tvweight a, covariates(x1) id(id) time(t) generate(w) cumulative cumgenerate(wc)
    assert "`r(cumgenerate)'" == "wc"
    * Manual cumulative product of the per-row weight within id, ordered by t
    sort id t
    by id (t): gen double manual = w if _n == 1
    by id (t): replace manual = manual[_n-1] * w if _n > 1
    assert reldif(wc, manual) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: cumulative weight = within-person product of per-row weights"
    local ++pass_count
}
else {
    display as error "  FAIL: cumulative product parity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}

**# TEST 8: love plot and histogram produce graphs without error
local ++test_count
capture noisily {
    _mk_data
    graph drop _all
    tvweight a, covariates(x1 x2) generate(w) balance loveplot histogram
    capture graph describe tvw_loveplot
    assert _rc == 0
    capture graph describe tvw_histogram
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: loveplot and histogram graphs created"
    local ++pass_count
}
else {
    display as error "  FAIL: graph smoke test (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}

**# TEST 9: data not destroyed by love plot (frame-isolated)
local ++test_count
capture noisily {
    _mk_data
    local n_before = _N
    tvweight a, covariates(x1 x2) generate(w) balance loveplot
    assert _N == `n_before'
    confirm variable x1 x2 a w
}
if _rc == 0 {
    display as result "  PASS: user data intact after love plot"
    local ++pass_count
}
else {
    display as error "  FAIL: data preservation after love plot (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}

**# TEST 10: error paths for the new options
local ++test_count
capture noisily {
    _mk_data
    capture tvweight a, covariates(x1 x2) generate(w) wtype(bogus)
    assert _rc == 198
    capture tvweight a, covariates(x1 x2) generate(w) wtype(ato) stabilized
    assert _rc == 198
    capture tvweight a, covariates(x1 x2) generate(w) loveplot
    assert _rc == 198
    capture tvweight a, covariates(x1 x2) generate(w) cumulative
    assert _rc == 198
    capture tvweight a, covariates(x1 x2) generate(w) cumgenerate(z)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: invalid wtype/stabilized+ato/loveplot/cumulative guards (198)"
    local ++pass_count
}
else {
    display as error "  FAIL: error-path guards (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10"
}

**# TEST 11: categorical (mlogit) generalized overlap (ato) weight parity
* tvweight auto-promotes a 3-level exposure to mlogit; the ATO weight is the
* generalized overlap form (1/sum_k(1/p_k))/P(observed). Refit mlogit by hand
* (predictions are baseoutcome-invariant) and compare closed form.
local ++test_count
capture noisily {
    _mk_data_cat
    tvweight a, covariates(x1 x2) generate(w) wtype(ato) denominator(ps)
    assert "`r(wtype)'" == "ato"
    assert "`r(model)'" == "mlogit"
    quietly mlogit a x1 x2, baseoutcome(0)
    quietly predict double p0, outcome(0)
    quietly predict double p1, outcome(1)
    quietly predict double p2, outcome(2)
    gen double suminv = 1/p0 + 1/p1 + 1/p2
    gen double pobs = cond(a==0, p0, cond(a==1, p1, p2))
    gen double w_expected = (1/suminv)/pobs
    assert reldif(w, w_expected) < 1e-7
}
if _rc == 0 {
    display as result "  PASS: categorical ATO = (1/sum_k 1/p_k)/P(observed)"
    local ++pass_count
}
else {
    display as error "  FAIL: categorical ATO closed-form parity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11"
}

**# TEST 12: categorical (mlogit) generalized matching weight parity
* Generalized matching weight is min_k(p_k)/P(observed).
local ++test_count
capture noisily {
    _mk_data_cat
    tvweight a, covariates(x1 x2) generate(w) wtype(matching) denominator(ps)
    assert "`r(wtype)'" == "matching"
    assert "`r(model)'" == "mlogit"
    quietly mlogit a x1 x2, baseoutcome(0)
    quietly predict double p0, outcome(0)
    quietly predict double p1, outcome(1)
    quietly predict double p2, outcome(2)
    gen double minp = min(p0, p1, p2)
    gen double pobs = cond(a==0, p0, cond(a==1, p1, p2))
    gen double w_expected = minp/pobs
    assert reldif(w, w_expected) < 1e-7
}
if _rc == 0 {
    display as result "  PASS: categorical matching = min_k(p_k)/P(observed)"
    local ++pass_count
}
else {
    display as error "  FAIL: categorical matching closed-form parity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 12"
}

**# TEST 13: categorical balance table well-formed; ato sharply cuts imbalance
* For a 3-level exposure the balance table reports max |SMD| across non-ref
* levels. Unlike the binary case (exact zero via the logit score equation),
* the generalized overlap weight only achieves APPROXIMATE mean balance, so we
* assert a large reduction below the conventional 0.1 threshold, not exactness.
local ++test_count
capture noisily {
    _mk_data_cat
    tvweight a, covariates(x1 x2) generate(w) wtype(ato) balance
    matrix B = r(balance)
    assert rowsof(B) == 2 & colsof(B) == 2
    * unweighted max|SMD| is a real positive imbalance (well above 0.1)
    assert B[1,1] > 0.1 & B[2,1] > 0.1
    * weighting drops each covariate well below the 0.1 balance threshold
    assert abs(B[1,2]) < 0.05 & abs(B[2,2]) < 0.05
    * and represents a large relative reduction from the unweighted imbalance
    assert abs(B[1,2]) < 0.1*B[1,1] & abs(B[2,2]) < 0.1*B[2,1]
}
if _rc == 0 {
    display as result "  PASS: categorical ATO balance table well-formed, imbalance cut >90%"
    local ++pass_count
}
else {
    display as error "  FAIL: categorical ATO balance table (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 13"
}

* ===== Summary =====
display as result _newline "tvweight balance/wtype/cumulative validation Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: validation_tvweight_balance tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
