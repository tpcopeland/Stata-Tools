* test_finegray.do - Functional test suite for finegray package
* Tests: installation, options, error handling, return values, data preservation
* Package: finegray v1.0.0
* Date: 2026-03-15

clear all
set more off
local test_count = 0
local pass_count = 0
local fail_count = 0

capture log close _test_finegray
log using "/home/tpcopeland/Stata-Dev/finegray/qa/test_finegray.log", ///
    replace text name(_test_finegray)

* =========================================================================
* SETUP: install and prepare data
* =========================================================================
capture ado uninstall finegray
net install finegray, from("/home/tpcopeland/Stata-Dev/finegray")

program define _setup_hypoxia
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)
end

* =========================================================================
* SECTION 1: Installation and basic availability
* =========================================================================

* T1: finegray installed
local ++test_count
capture noisily {
    which finegray
}
if _rc == 0 {
    display as result "  PASS: T1 finegray.ado installed"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 finegray.ado not installed"
    local ++fail_count
}

* T2: _finegray_mata installed
local ++test_count
capture noisily {
    which _finegray_mata
}
if _rc == 0 {
    display as result "  PASS: T2 _finegray_mata.ado installed"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 _finegray_mata.ado not installed"
    local ++fail_count
}

* T3: finegray_predict installed
local ++test_count
capture noisily {
    which finegray_predict
}
if _rc == 0 {
    display as result "  PASS: T3 finegray_predict.ado installed"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 finegray_predict.ado not installed"
    local ++fail_count
}

* =========================================================================
* SECTION 2: Basic functionality
* =========================================================================

* T4: Wrapper mode runs
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) nolog
    assert "`e(cmd)'" == "finegray"
}
if _rc == 0 {
    display as result "  PASS: T4 wrapper mode basic"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 wrapper mode basic (rc=`=_rc')"
    local ++fail_count
}

* T5: Fast mode runs
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    assert "`e(cmd)'" == "finegray"
}
if _rc == 0 {
    display as result "  PASS: T5 fast mode basic"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 fast mode basic (rc=`=_rc')"
    local ++fail_count
}

* T6: Single covariate
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp, events(status) cause(1) nolog
    assert e(df_m) == 1
}
if _rc == 0 {
    display as result "  PASS: T6 single covariate"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 single covariate (rc=`=_rc')"
    local ++fail_count
}

* T7: Single covariate fast mode
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp, events(status) cause(1) fast nolog
    assert e(df_m) == 1
}
if _rc == 0 {
    display as result "  PASS: T7 single covariate fast"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 single covariate fast (rc=`=_rc')"
    local ++fail_count
}

* T8: Cause 2 (distant recurrence)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize, events(status) cause(2) fast nolog
    assert e(N_fail) == 17
    assert e(N_compete) == 33
}
if _rc == 0 {
    display as result "  PASS: T8 cause(2) works"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 cause(2) (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
* SECTION 3: Option tests
* =========================================================================

* T9: nohr option
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog nohr
    assert "`e(cmd)'" == "finegray"
}
if _rc == 0 {
    display as result "  PASS: T9 nohr option"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 nohr option (rc=`=_rc')"
    local ++fail_count
}

* T10: level option
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog level(90)
    assert e(level) == 90
}
if _rc == 0 {
    display as result "  PASS: T10 level(90)"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 level(90) (rc=`=_rc')"
    local ++fail_count
}

* T11: robust option (fast mode)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog robust
    assert "`e(vce)'" == "robust"
}
if _rc == 0 {
    display as result "  PASS: T11 robust (fast)"
    local ++pass_count
}
else {
    display as error "  FAIL: T11 robust fast (rc=`=_rc')"
    local ++fail_count
}

* T12: robust option (wrapper mode)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) nolog robust
    assert "`e(vce)'" == "robust"
}
if _rc == 0 {
    display as result "  PASS: T12 robust (wrapper)"
    local ++pass_count
}
else {
    display as error "  FAIL: T12 robust wrapper (rc=`=_rc')"
    local ++fail_count
}

* T13: cluster option (fast mode)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize, events(status) cause(1) fast nolog cluster(pelnode)
    assert "`e(clustvar)'" == "pelnode"
}
if _rc == 0 {
    display as result "  PASS: T13 cluster (fast)"
    local ++pass_count
}
else {
    display as error "  FAIL: T13 cluster fast (rc=`=_rc')"
    local ++fail_count
}

* T14: byg option (fast mode)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize, events(status) cause(1) fast nolog byg(pelnode)
    assert "`e(byg)'" == "pelnode"
}
if _rc == 0 {
    display as result "  PASS: T14 byg (fast)"
    local ++pass_count
}
else {
    display as error "  FAIL: T14 byg fast (rc=`=_rc')"
    local ++fail_count
}

* T15: noshorten option (wrapper mode)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) nolog noshorten
    assert "`e(cmd)'" == "finegray"
}
if _rc == 0 {
    display as result "  PASS: T15 noshorten (wrapper)"
    local ++pass_count
}
else {
    display as error "  FAIL: T15 noshorten (rc=`=_rc')"
    local ++fail_count
}

* T16: iterate/tolerance options (fast mode)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog ///
        iterate(50) tolerance(1e-6)
    assert e(iterate) == 50
    assert abs(e(tolerance) - 1e-6) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: T16 iterate/tolerance"
    local ++pass_count
}
else {
    display as error "  FAIL: T16 iterate/tolerance (rc=`=_rc')"
    local ++fail_count
}

* T17: censvalue option
local ++test_count
capture noisily {
    _setup_hypoxia
    * Recode events to use censvalue=9
    replace status = 9 if status == 0
    finegray ifp tumsize pelnode, events(status) cause(1) censvalue(9) fast nolog
    assert e(censvalue) == 9
    assert e(N_cens) == 59
}
if _rc == 0 {
    display as result "  PASS: T17 censvalue(9)"
    local ++pass_count
}
else {
    display as error "  FAIL: T17 censvalue(9) (rc=`=_rc')"
    local ++fail_count
}

* T18: if/in condition
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode if age > 50, events(status) cause(1) fast nolog
    assert e(N) < 109
}
if _rc == 0 {
    display as result "  PASS: T18 if condition"
    local ++pass_count
}
else {
    display as error "  FAIL: T18 if condition (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
* SECTION 4: Error handling
* =========================================================================

* T19: No stset → should error (rc != 0)
local ++test_count
webuse auto, clear
gen byte status = rep78
capture finegray price mpg, events(status) cause(1)
local _t19_rc = _rc
if `_t19_rc' != 0 {
    display as result "  PASS: T19 error: no stset (rc=`_t19_rc')"
    local ++pass_count
}
else {
    display as error "  FAIL: T19 error: no stset should fail"
    local ++fail_count
}

* T20: No id() in stset
local ++test_count
capture noisily {
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1)
    capture finegray ifp tumsize, events(status) cause(1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T20 error: no id()"
    local ++pass_count
}
else {
    display as error "  FAIL: T20 error: no id() (rc=`=_rc')"
    local ++fail_count
}

* T21: Invalid cause value
local ++test_count
capture noisily {
    _setup_hypoxia
    capture finegray ifp tumsize, events(status) cause(99)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T21 error: invalid cause"
    local ++pass_count
}
else {
    display as error "  FAIL: T21 error: invalid cause (rc=`=_rc')"
    local ++fail_count
}

* T22: No competing events
local ++test_count
capture noisily {
    _setup_hypoxia
    * Keep only cause 1 and censored (drop competing)
    drop if status == 2
    stset dftime, failure(dfcens==1) id(stnum)
    capture finegray ifp tumsize, events(status) cause(1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T22 error: no competing events"
    local ++pass_count
}
else {
    display as error "  FAIL: T22 error: no competing (rc=`=_rc')"
    local ++fail_count
}

* T23: tvc not allowed with fast
local ++test_count
capture noisily {
    _setup_hypoxia
    capture finegray ifp tumsize, events(status) cause(1) fast tvc(pelnode)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T23 error: tvc+fast"
    local ++pass_count
}
else {
    display as error "  FAIL: T23 error: tvc+fast (rc=`=_rc')"
    local ++fail_count
}

* T24: strata not allowed with fast
local ++test_count
capture noisily {
    _setup_hypoxia
    capture finegray ifp tumsize, events(status) cause(1) fast strata(pelnode)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T24 error: strata+fast"
    local ++pass_count
}
else {
    display as error "  FAIL: T24 error: strata+fast (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
* SECTION 5: Return values (e() results)
* =========================================================================

* T25: All e() scalars present (fast mode)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    assert e(N) == 109
    assert e(N_sub) == 109
    assert e(N_fail) == 33
    assert e(N_compete) == 17
    assert e(N_cens) == 59
    assert e(ll) != .
    assert e(ll_0) != .
    assert e(chi2) != .
    assert e(p) != .
    assert e(df_m) == 3
    assert e(converged) == 1
    assert e(level) == 95
    assert e(cause) == 1
    assert e(censvalue) == 0
}
if _rc == 0 {
    display as result "  PASS: T25 e() scalars (fast)"
    local ++pass_count
}
else {
    display as error "  FAIL: T25 e() scalars fast (rc=`=_rc')"
    local ++fail_count
}

* T26: All e() locals present
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    assert "`e(cmd)'" == "finegray"
    assert "`e(method)'" == "fast"
    assert "`e(predict)'" == "finegray_predict"
    assert "`e(depvar)'" == "status"
    assert "`e(events)'" == "status"
    assert "`e(covariates)'" == "ifp tumsize pelnode"
    assert "`e(title)'" == "Fine-Gray competing risks regression"
}
if _rc == 0 {
    display as result "  PASS: T26 e() locals (fast)"
    local ++pass_count
}
else {
    display as error "  FAIL: T26 e() locals fast (rc=`=_rc')"
    local ++fail_count
}

* T27: e() matrices present
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    assert colsof(e(b)) == 3
    assert colsof(e(V)) == 3
    assert rowsof(e(V)) == 3
    confirm matrix e(basehaz)
    assert rowsof(e(basehaz)) > 0
    assert colsof(e(basehaz)) == 2
}
if _rc == 0 {
    display as result "  PASS: T27 e() matrices"
    local ++pass_count
}
else {
    display as error "  FAIL: T27 e() matrices (rc=`=_rc')"
    local ++fail_count
}

* T28: Wrapper e() scalars
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) wrapper nolog
    assert "`e(method)'" == "wrapper"
    assert e(N_expand) > 0
    assert e(N_expand) >= e(N)
}
if _rc == 0 {
    display as result "  PASS: T28 e() wrapper-specific"
    local ++pass_count
}
else {
    display as error "  FAIL: T28 e() wrapper-specific (rc=`=_rc')"
    local ++fail_count
}

* T29: Event count consistency
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    assert e(N_fail) + e(N_compete) + e(N_cens) == e(N)
}
if _rc == 0 {
    display as result "  PASS: T29 event count consistency"
    local ++pass_count
}
else {
    display as error "  FAIL: T29 event count consistency (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
* SECTION 6: Data preservation
* =========================================================================

* T30: Data unchanged after wrapper
local ++test_count
capture noisily {
    _setup_hypoxia
    local N_before = _N
    tempfile before
    save `before'
    finegray ifp tumsize pelnode, events(status) cause(1) nolog
    local N_after = _N
    assert `N_before' == `N_after'
    * Check data integrity via checksum
    cf _all using `before'
}
if _rc == 0 {
    display as result "  PASS: T30 data preserved (wrapper)"
    local ++pass_count
}
else {
    display as error "  FAIL: T30 data preserved wrapper (rc=`=_rc')"
    local ++fail_count
}

* T31: Data unchanged after fast
local ++test_count
capture noisily {
    _setup_hypoxia
    local N_before = _N
    tempfile before
    save `before'
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    local N_after = _N
    assert `N_before' == `N_after'
    cf _all using `before'
}
if _rc == 0 {
    display as result "  PASS: T31 data preserved (fast)"
    local ++pass_count
}
else {
    display as error "  FAIL: T31 data preserved fast (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
* SECTION 7: finegray_predict
* =========================================================================

* T32: xb prediction (default)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    finegray_predict xb_test
    assert xb_test != .
    summ xb_test, meanonly
    assert r(N) == 109
    drop xb_test
}
if _rc == 0 {
    display as result "  PASS: T32 predict xb"
    local ++pass_count
}
else {
    display as error "  FAIL: T32 predict xb (rc=`=_rc')"
    local ++fail_count
}

* T33: cif prediction
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    finegray_predict cif_test, cif
    assert cif_test != .
    summ cif_test, meanonly
    * CIF must be in [0, 1]
    assert r(min) >= 0
    assert r(max) <= 1
    drop cif_test
}
if _rc == 0 {
    display as result "  PASS: T33 predict cif in [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: T33 predict cif (rc=`=_rc')"
    local ++fail_count
}

* T34: predict after wrapper
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) nolog
    finegray_predict xb_w, xb
    finegray_predict cif_w, cif
    summ cif_w, meanonly
    assert r(min) >= 0
    assert r(max) <= 1
    drop xb_w cif_w
}
if _rc == 0 {
    display as result "  PASS: T34 predict after wrapper"
    local ++pass_count
}
else {
    display as error "  FAIL: T34 predict wrapper (rc=`=_rc')"
    local ++fail_count
}

* T35: predict error without finegray → should error (rc != 0)
local ++test_count
sysuse auto, clear
capture finegray_predict test_var, xb
local _t35_rc = _rc
if `_t35_rc' != 0 {
    display as result "  PASS: T35 predict error: no estimates (rc=`_t35_rc')"
    local ++pass_count
}
else {
    display as error "  FAIL: T35 predict should fail without finegray"
    local ++fail_count
}

* T36: predict with if condition
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    finegray_predict cif_sub if age > 50, cif
    quietly count if cif_sub != . & age > 50
    local n_pred = r(N)
    quietly count if age > 50
    assert `n_pred' == r(N)
    drop cif_sub
}
if _rc == 0 {
    display as result "  PASS: T36 predict with if"
    local ++pass_count
}
else {
    display as error "  FAIL: T36 predict if (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
* SECTION 8: Convergence and model properties
* =========================================================================

* T37: Fast mode converges
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    assert e(converged) == 1
}
if _rc == 0 {
    display as result "  PASS: T37 fast convergence"
    local ++pass_count
}
else {
    display as error "  FAIL: T37 fast convergence (rc=`=_rc')"
    local ++fail_count
}

* T38: Log-likelihood ordering: ll < ll_0 (typically)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    * Full model should have higher ll than null
    assert e(ll) >= e(ll_0)
}
if _rc == 0 {
    display as result "  PASS: T38 ll >= ll_0"
    local ++pass_count
}
else {
    display as error "  FAIL: T38 ll ordering (rc=`=_rc')"
    local ++fail_count
}

* T39: Chi2 positive
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    assert e(chi2) > 0
    assert e(p) >= 0 & e(p) <= 1
}
if _rc == 0 {
    display as result "  PASS: T39 chi2 > 0, p in [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: T39 chi2/p (rc=`=_rc')"
    local ++fail_count
}

* T40: V matrix positive semi-definite (diagonal elements > 0)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    matrix V = e(V)
    forvalues i = 1/3 {
        assert V[`i', `i'] > 0
    }
}
if _rc == 0 {
    display as result "  PASS: T40 V diagonal positive"
    local ++pass_count
}
else {
    display as error "  FAIL: T40 V diagonal (rc=`=_rc')"
    local ++fail_count
}

* T41: Basehaz monotonically increasing
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    matrix bh = e(basehaz)
    local nr = rowsof(bh)
    local ok = 1
    forvalues i = 2/`nr' {
        local prev = `i' - 1
        if bh[`i', 2] < bh[`prev', 2] {
            local ok = 0
        }
    }
    assert `ok' == 1
}
if _rc == 0 {
    display as result "  PASS: T41 basehaz monotone increasing"
    local ++pass_count
}
else {
    display as error "  FAIL: T41 basehaz monotone (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
* SUMMARY
* =========================================================================
display ""
display as text _dup(60) "="
display as text "RESULTS: test_finegray.do"
display as text _dup(60) "="
display as text "Total:  " as result `test_count'
display as text "Passed: " as result `pass_count'
display as text "Failed: " as result `fail_count'
display as text _dup(60) "="

if `fail_count' > 0 {
    display as error "RESULT: FAIL (`fail_count' of `test_count' tests failed)"
    exit 1
}
else {
    display as result "RESULT: PASS (all `test_count' tests passed)"
}

log close _test_finegray
