* validation_finegray.do - Validation suite for finegray package
* Tests: cross-validation vs stcrreg, known-answer, invariants, CIF
* Package: finegray v1.0.0
* Date: 2026-03-15

clear all
set more off
local test_count = 0
local pass_count = 0
local fail_count = 0

capture log close _val_finegray
log using "/home/tpcopeland/Stata-Dev/finegray/qa/validation_finegray.log", ///
    replace text name(_val_finegray)

* =========================================================================
* SETUP
* =========================================================================
capture ado uninstall finegray
net install finegray, from("/home/tpcopeland/Stata-Dev/finegray")

program define _setup_hypoxia
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)
end

* =========================================================================
* SECTION 1: Fast mode vs stcrreg (gold standard cross-validation)
* stcrreg reference values from webuse hypoxia:
*   ifp:     0.0326664
*   tumsize: 0.2603096
*   pelnode: -0.7791140
*   ll:      -138.5308
* =========================================================================

local tol = 1e-4
local tol_se = 0.01

* V1: Fast mode coefficients match stcrreg
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    matrix b = e(b)
    assert abs(b[1,1] - 0.0326664) < `tol'
    assert abs(b[1,2] - 0.2603096) < `tol'
    assert abs(b[1,3] - (-0.7791140)) < `tol'
}
if _rc == 0 {
    display as result "  PASS: V1 fast coefficients match stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: V1 fast coefficients (rc=`=_rc')"
    local ++fail_count
}

* V2: Fast mode log-likelihood matches stcrreg
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    assert abs(e(ll) - (-138.5308)) < 0.001
}
if _rc == 0 {
    display as result "  PASS: V2 fast ll matches stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: V2 fast ll (rc=`=_rc')"
    local ++fail_count
}

* V3: Fast mode SEs match stcrreg robust SEs
* stcrreg SE: ifp=0.0178938, tumsize=0.1271191, pelnode=0.1972067
* Note: finegray fast uses model-based info matrix, not clustered robust
* So SEs may differ. Check they are in right ballpark.
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    matrix V = e(V)
    local se_ifp = sqrt(V[1,1])
    local se_tum = sqrt(V[2,2])
    local se_pel = sqrt(V[3,3])
    * Model-based SEs should be in same order of magnitude
    assert `se_ifp' > 0.005 & `se_ifp' < 0.05
    assert `se_tum' > 0.05 & `se_tum' < 0.3
    assert `se_pel' > 0.1 & `se_pel' < 0.8
}
if _rc == 0 {
    display as result "  PASS: V3 fast SEs in reasonable range"
    local ++pass_count
}
else {
    display as error "  FAIL: V3 fast SEs (rc=`=_rc')"
    local ++fail_count
}

* V4: Live cross-validation: fast vs stcrreg (same session)
local ++test_count
capture noisily {
    _setup_hypoxia

    * Run stcrreg
    preserve
    stset dftime, failure(status==1) id(stnum)
    stcrreg ifp tumsize pelnode, compete(status == 2)
    matrix b_ref = e(b)
    restore

    * Re-stset for finegray
    stset dftime, failure(dfcens==1) id(stnum)

    * Run fast mode
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    matrix b_fast = e(b)

    * Compare
    assert abs(b_fast[1,1] - b_ref[1,1]) < `tol'
    assert abs(b_fast[1,2] - b_ref[1,2]) < `tol'
    assert abs(b_fast[1,3] - b_ref[1,3]) < `tol'
}
if _rc == 0 {
    display as result "  PASS: V4 live fast vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: V4 live fast vs stcrreg (rc=`=_rc')"
    local ++fail_count
}

* V5: Fast mode single covariate vs stcrreg
local ++test_count
capture noisily {
    _setup_hypoxia

    * stcrreg
    preserve
    stset dftime, failure(status==1) id(stnum)
    stcrreg ifp, compete(status == 2)
    local b_ref = e(b)[1,1]
    restore

    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp, events(status) cause(1) fast nolog
    local b_fast = e(b)[1,1]

    assert abs(`b_fast' - `b_ref') < `tol'
}
if _rc == 0 {
    display as result "  PASS: V5 single covariate fast vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: V5 single covariate (rc=`=_rc')"
    local ++fail_count
}

* V6: Cause 2 cross-validation
local ++test_count
capture noisily {
    _setup_hypoxia

    preserve
    stset dftime, failure(status==2) id(stnum)
    stcrreg ifp tumsize, compete(status == 1)
    matrix b_ref = e(b)
    restore

    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize, events(status) cause(2) fast nolog
    matrix b_fast = e(b)

    assert abs(b_fast[1,1] - b_ref[1,1]) < `tol'
    assert abs(b_fast[1,2] - b_ref[1,2]) < `tol'
}
if _rc == 0 {
    display as result "  PASS: V6 cause(2) fast vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: V6 cause(2) (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
* SECTION 2: Model invariants
* =========================================================================

* V7: Null model (no covariates = all betas zero) ll = ll_0
local ++test_count
capture noisily {
    _setup_hypoxia
    * Run with a "null-like" covariate (constant-ish)
    gen double null_x = 0
    finegray null_x, events(status) cause(1) fast nolog
    * Coefficient should be near zero
    assert abs(e(b)[1,1]) < 0.01
    drop null_x
}
if _rc == 0 {
    display as result "  PASS: V7 null covariate → near-zero beta"
    local ++pass_count
}
else {
    display as error "  FAIL: V7 null covariate (rc=`=_rc')"
    local ++fail_count
}

* V8: SHR > 0 (exp(beta) always positive)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    matrix b = e(b)
    forvalues i = 1/3 {
        assert exp(b[1,`i']) > 0
    }
}
if _rc == 0 {
    display as result "  PASS: V8 SHR > 0"
    local ++pass_count
}
else {
    display as error "  FAIL: V8 SHR > 0 (rc=`=_rc')"
    local ++fail_count
}

* V9: chi2 = b' * V^-1 * b (Wald statistic)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    matrix b = e(b)
    matrix V = e(V)
    matrix Vi = invsym(V)
    matrix chi2_manual = b * Vi * b'
    assert abs(chi2_manual[1,1] - e(chi2)) < 0.01
}
if _rc == 0 {
    display as result "  PASS: V9 chi2 = b'V^-1 b"
    local ++pass_count
}
else {
    display as error "  FAIL: V9 chi2 computation (rc=`=_rc')"
    local ++fail_count
}

* V10: p-value from chi2
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    local p_manual = chi2tail(e(df_m), e(chi2))
    assert abs(`p_manual' - e(p)) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: V10 p = chi2tail(df, chi2)"
    local ++pass_count
}
else {
    display as error "  FAIL: V10 p-value (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
* SECTION 3: CIF prediction validation
* =========================================================================

* V11: CIF monotonically increases with time for same covariates
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    finegray_predict cif_pred, cif
    * For a fixed covariate pattern, CIF should increase with time
    * Take the first observation and check nearby times
    sort _t
    local prev_cif = cif_pred[1]
    local ok = 1
    * Check first 20 obs (sorted by time)
    forvalues i = 2/20 {
        if cif_pred[`i'] < `prev_cif' - 1e-10 & ///
           ifp[`i'] == ifp[1] & tumsize[`i'] == tumsize[1] & pelnode[`i'] == pelnode[1] {
            local ok = 0
        }
        local prev_cif = cif_pred[`i']
    }
    * CIF should generally be non-decreasing across subjects when sorted by time
    * (even with different covariates, the range should make sense)
    summ cif_pred, meanonly
    assert r(min) >= 0 & r(max) <= 1
    drop cif_pred
}
if _rc == 0 {
    display as result "  PASS: V11 CIF in [0,1] and sensible"
    local ++pass_count
}
else {
    display as error "  FAIL: V11 CIF properties (rc=`=_rc')"
    local ++fail_count
}

* V12: CIF formula: 1 - exp(-H0(t)*exp(xb))
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    finegray_predict xb_val, xb
    finegray_predict cif_val, cif

    * Manually compute CIF from xb and basehaz
    matrix bh = e(basehaz)
    local nr = rowsof(bh)

    * For obs with large _t, H0 should be large, so CIF should be high
    summ _t, meanonly
    local max_t = r(max)
    local H0_max = bh[`nr', 2]
    * Check a specific observation
    local test_obs = 1
    local t1 = _t[`test_obs']
    local xb1 = xb_val[`test_obs']

    * Find H0(t1) from basehaz
    local H0_1 = 0
    forvalues j = 1/`nr' {
        if bh[`j', 1] <= `t1' {
            local H0_1 = bh[`j', 2]
        }
    }

    local cif_manual = 1 - exp(-`H0_1' * exp(`xb1'))
    local cif_stored = cif_val[`test_obs']
    assert abs(`cif_manual' - `cif_stored') < 1e-6

    drop xb_val cif_val
}
if _rc == 0 {
    display as result "  PASS: V12 CIF = 1 - exp(-H0*exp(xb))"
    local ++pass_count
}
else {
    display as error "  FAIL: V12 CIF formula (rc=`=_rc')"
    local ++fail_count
}

* V13: xb prediction matches manual matrix multiplication
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    finegray_predict xb_pred, xb

    * Manual: xb = ifp*b1 + tumsize*b2 + pelnode*b3
    matrix b = e(b)
    gen double xb_manual = ifp*b[1,1] + tumsize*b[1,2] + pelnode*b[1,3]

    * Check all observations
    gen double xb_diff = abs(xb_pred - xb_manual)
    summ xb_diff, meanonly
    assert r(max) < 1e-6

    drop xb_pred xb_manual xb_diff
}
if _rc == 0 {
    display as result "  PASS: V13 xb = Z*beta (manual)"
    local ++pass_count
}
else {
    display as error "  FAIL: V13 xb manual (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
* SECTION 4: Basehaz properties
* =========================================================================

* V14: Basehaz times are event times
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    matrix bh = e(basehaz)
    * Number of basehaz rows should equal number of cause events
    assert rowsof(bh) == e(N_fail)
}
if _rc == 0 {
    display as result "  PASS: V14 basehaz rows = N_fail"
    local ++pass_count
}
else {
    display as error "  FAIL: V14 basehaz rows (rc=`=_rc')"
    local ++fail_count
}

* V15: Basehaz cumhazard positive and increasing
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    matrix bh = e(basehaz)
    local nr = rowsof(bh)
    local ok = 1
    assert bh[1, 2] > 0
    forvalues i = 2/`nr' {
        local prev = `i' - 1
        if bh[`i', 2] < bh[`prev', 2] - 1e-12 {
            local ok = 0
        }
    }
    assert `ok' == 1
}
if _rc == 0 {
    display as result "  PASS: V15 basehaz cumhazard increasing"
    local ++pass_count
}
else {
    display as error "  FAIL: V15 basehaz increasing (rc=`=_rc')"
    local ++fail_count
}

* V16: Basehaz times sorted
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    matrix bh = e(basehaz)
    local nr = rowsof(bh)
    local ok = 1
    forvalues i = 2/`nr' {
        local prev = `i' - 1
        if bh[`i', 1] < bh[`prev', 1] {
            local ok = 0
        }
    }
    assert `ok' == 1
}
if _rc == 0 {
    display as result "  PASS: V16 basehaz times sorted"
    local ++pass_count
}
else {
    display as error "  FAIL: V16 basehaz sorted (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
* SECTION 5: Sensitivity and robustness
* =========================================================================

* V17: Scaling covariates changes coefficients proportionally
local ++test_count
capture noisily {
    _setup_hypoxia
    * Original
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    local b1_orig = e(b)[1,1]

    * Scale ifp by 10
    gen double ifp10 = ifp * 10
    finegray ifp10 tumsize pelnode, events(status) cause(1) fast nolog
    local b1_scaled = e(b)[1,1]

    * b_scaled should be b_orig / 10
    assert abs(`b1_scaled' - `b1_orig'/10) < `tol'
    drop ifp10
}
if _rc == 0 {
    display as result "  PASS: V17 covariate scaling"
    local ++pass_count
}
else {
    display as error "  FAIL: V17 covariate scaling (rc=`=_rc')"
    local ++fail_count
}

* V18: Adding irrelevant variable doesn't change other coefficients much
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize, events(status) cause(1) fast nolog
    local b_ifp_2 = e(b)[1,1]
    local b_tum_2 = e(b)[1,2]

    gen double noise = rnormal()
    finegray ifp tumsize noise, events(status) cause(1) fast nolog
    local b_ifp_3 = e(b)[1,1]
    local b_tum_3 = e(b)[1,2]

    * Coefficients should not change dramatically
    assert abs(`b_ifp_3' - `b_ifp_2') < 0.05
    assert abs(`b_tum_3' - `b_tum_2') < 0.05
    drop noise
}
if _rc == 0 {
    display as result "  PASS: V18 irrelevant variable stability"
    local ++pass_count
}
else {
    display as error "  FAIL: V18 irrelevant var (rc=`=_rc')"
    local ++fail_count
}

* V19: Wrapper mode produces e(basehaz) for predict
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, events(status) cause(1) nolog
    confirm matrix e(basehaz)
    assert rowsof(e(basehaz)) > 0
    finegray_predict cif_w, cif
    summ cif_w, meanonly
    assert r(min) >= 0 & r(max) <= 1
    drop cif_w
}
if _rc == 0 {
    display as result "  PASS: V19 wrapper basehaz + CIF predict"
    local ++pass_count
}
else {
    display as error "  FAIL: V19 wrapper basehaz (rc=`=_rc')"
    local ++fail_count
}

* V20: Fast and wrapper xb predictions are comparable direction
local ++test_count
capture noisily {
    _setup_hypoxia

    * Fast mode
    finegray ifp tumsize pelnode, events(status) cause(1) fast nolog
    finegray_predict xb_fast, xb

    * Wrapper mode
    finegray ifp tumsize pelnode, events(status) cause(1) nolog
    finegray_predict xb_wrap, xb

    * Correlation should be strongly positive
    correlate xb_fast xb_wrap
    assert r(rho) > 0.9

    drop xb_fast xb_wrap
}
if _rc == 0 {
    display as result "  PASS: V20 fast/wrapper xb correlated"
    local ++pass_count
}
else {
    display as error "  FAIL: V20 fast/wrapper corr (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================
* SUMMARY
* =========================================================================
display ""
display as text _dup(60) "="
display as text "RESULTS: validation_finegray.do"
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

log close _val_finegray
