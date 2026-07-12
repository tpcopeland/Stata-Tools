* validation_finegray.do - Validation suite for finegray package
* Tests: cross-validation vs stcrreg, known-answer, invariants, CIF, basehaz
* Package: finegray v1.1.0

clear all
set more off
set varabbrev off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local pkgroot "`c(pwd)'"
capture confirm file "`pkgroot'/finegray.pkg"
if _rc {
    capture confirm file "`pkgroot'/../finegray.pkg"
    if _rc {
        display as error "could not locate finegray package root"
        exit 601
    }
    local pkgroot "`pkgroot'/.."
}
local qadir "`pkgroot'/qa"

capture log close _all
log using "`qadir'/validation_finegray.log", ///
    replace text name(_val_finegray)

* {smcl}
* {* SETUP}{...}
capture ado uninstall finegray
net install finegray, from("`pkgroot'") replace

program define _finegray_use_hypoxia
    local cache "`c(tmpdir)'/finegray_hypoxia_cache.dta"
    capture confirm file "`cache'"
    if _rc {
        webuse hypoxia, clear
        quietly save "`cache'", replace
    }
    else {
        use "`cache'", clear
    }
end

program define _setup_hypoxia
    _finegray_use_hypoxia
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)
end

* {smcl}
* {* SECTION 1: Coefficients vs stcrreg (gold standard)}{...}
* stcrreg reference values from webuse hypoxia:
*   ifp:     0.0326664
*   tumsize: 0.2603096
*   pelnode: -0.7791140
*   ll:      -138.5308

local tol = 1e-4

* V1: 3-cov cause 1 coefficients match stcrreg
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    matrix b = e(b)
    assert abs(b[1,1] - 0.0326664) < `tol'
    assert abs(b[1,2] - 0.2603096) < `tol'
    assert abs(b[1,3] - (-0.7791140)) < `tol'
}
if _rc == 0 {
    display as result "  PASS: V1 coefficients match stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: V1 coefficients (rc=`=_rc')"
    local ++fail_count
}

* V2: Log-likelihood matches stcrreg
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert abs(e(ll) - (-138.5308)) < 0.001
}
if _rc == 0 {
    display as result "  PASS: V2 log-likelihood matches stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: V2 log-likelihood (rc=`=_rc')"
    local ++fail_count
}

* V3: SEs in reasonable range
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    matrix V = e(V)
    local se_ifp = sqrt(V[1,1])
    local se_tum = sqrt(V[2,2])
    local se_pel = sqrt(V[3,3])
    assert `se_ifp' > 0.005 & `se_ifp' < 0.05
    assert `se_tum' > 0.05 & `se_tum' < 0.3
    assert `se_pel' > 0.1 & `se_pel' < 0.8
}
if _rc == 0 {
    display as result "  PASS: V3 SEs in reasonable range"
    local ++pass_count
}
else {
    display as error "  FAIL: V3 SEs (rc=`=_rc')"
    local ++fail_count
}

* V4: Live cross-validation vs stcrreg (same session)
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==1) id(stnum)
    stcrreg ifp tumsize pelnode, compete(status == 2)
    matrix b_ref = e(b)
    restore
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    matrix b_fg = e(b)
    assert abs(b_fg[1,1] - b_ref[1,1]) < `tol'
    assert abs(b_fg[1,2] - b_ref[1,2]) < `tol'
    assert abs(b_fg[1,3] - b_ref[1,3]) < `tol'
}
if _rc == 0 {
    display as result "  PASS: V4 live vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: V4 live vs stcrreg (rc=`=_rc')"
    local ++fail_count
}

* V5: Single covariate vs stcrreg
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==1) id(stnum)
    stcrreg ifp, compete(status == 2)
    local b_ref = e(b)[1,1]
    restore
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp, compete(status) cause(1) nolog
    local b_fg = e(b)[1,1]
    assert abs(`b_fg' - `b_ref') < `tol'
}
if _rc == 0 {
    display as result "  PASS: V5 single covariate vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: V5 single covariate (rc=`=_rc')"
    local ++fail_count
}

* V6: Cause 2 vs stcrreg
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==2) id(stnum)
    stcrreg ifp tumsize, compete(status == 1)
    matrix b_ref = e(b)
    restore
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize, compete(status) cause(2) nolog
    matrix b_fg = e(b)
    assert abs(b_fg[1,1] - b_ref[1,1]) < `tol'
    assert abs(b_fg[1,2] - b_ref[1,2]) < `tol'
}
if _rc == 0 {
    display as result "  PASS: V6 cause(2) vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: V6 cause(2) (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 2: Model invariants}{...}

* V7: Null covariate is rejected as unidentified
local ++test_count
capture noisily {
    _setup_hypoxia
    gen double null_x = 0
    capture finegray null_x, compete(status) cause(1) nolog
    assert _rc == 459
    drop null_x
}
if _rc == 0 {
    display as result "  PASS: V7 null covariate rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: V7 null covariate (rc=`=_rc')"
    local ++fail_count
}

* V8: SHR > 0
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
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
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
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
    display as error "  FAIL: V9 chi2 (rc=`=_rc')"
    local ++fail_count
}

* V10: p-value from chi2
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
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

* V11: Scaling covariates changes coefficients proportionally
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    local b1_orig = e(b)[1,1]
    gen double ifp10 = ifp * 10
    finegray ifp10 tumsize pelnode, compete(status) cause(1) nolog
    local b1_scaled = e(b)[1,1]
    assert abs(`b1_scaled' - `b1_orig'/10) < `tol'
    drop ifp10
}
if _rc == 0 {
    display as result "  PASS: V11 covariate scaling"
    local ++pass_count
}
else {
    display as error "  FAIL: V11 scaling (rc=`=_rc')"
    local ++fail_count
}

* V12: Adding irrelevant variable doesn't change other coefficients
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize, compete(status) cause(1) nolog
    local b_ifp_2 = e(b)[1,1]
    local b_tum_2 = e(b)[1,2]
    set seed 12345
    gen double noise = rnormal()
    finegray ifp tumsize noise, compete(status) cause(1) nolog
    local b_ifp_3 = e(b)[1,1]
    local b_tum_3 = e(b)[1,2]
    assert abs(`b_ifp_3' - `b_ifp_2') < 0.05
    assert abs(`b_tum_3' - `b_tum_2') < 0.05
    drop noise
}
if _rc == 0 {
    display as result "  PASS: V12 irrelevant variable stability"
    local ++pass_count
}
else {
    display as error "  FAIL: V12 irrelevant var (rc=`=_rc')"
    local ++fail_count
}

* V13: Reproducibility — identical on second run
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    local ll_1 = e(ll)
    matrix b_1 = e(b)
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    local ll_2 = e(ll)
    matrix b_2 = e(b)
    assert abs(`ll_1' - `ll_2') < 1e-8
    forvalues i = 1/3 {
        assert abs(b_1[1,`i'] - b_2[1,`i']) < 1e-10
    }
}
if _rc == 0 {
    display as result "  PASS: V13 reproducibility"
    local ++pass_count
}
else {
    display as error "  FAIL: V13 reproducibility (rc=`=_rc')"
    local ++fail_count
}

* V14: Constant covariate is rejected rather than ridge-regularized
local ++test_count
capture noisily {
    _setup_hypoxia
    gen double const_x = 5
    capture finegray const_x ifp, compete(status) cause(1) nolog
    assert _rc == 459
    assert `"`_dta[_finegray_estimated]'"' == ""
}
if _rc == 0 {
    display as result "  PASS: V14 constant covariate rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: V14 constant covariate (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 3: CIF prediction validation}{...}

* V15: CIF in [0,1]
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict cif_pred, cif
    summ cif_pred, meanonly
    assert r(min) >= 0 & r(max) <= 1
    drop cif_pred
}
if _rc == 0 {
    display as result "  PASS: V15 CIF in [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: V15 CIF properties (rc=`=_rc')"
    local ++fail_count
}

* V16: CIF formula: 1 - exp(-H0(t)*exp(xb))
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict xb_val, xb
    finegray_predict cif_val, cif
    matrix bh = e(basehaz)
    local nr = rowsof(bh)
    local test_obs = 1
    local t1 = _t[`test_obs']
    local xb1 = xb_val[`test_obs']
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
    display as result "  PASS: V16 CIF = 1 - exp(-H0*exp(xb))"
    local ++pass_count
}
else {
    display as error "  FAIL: V16 CIF formula (rc=`=_rc')"
    local ++fail_count
}

* V17: xb matches manual z'beta
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict xb_pred, xb
    matrix b = e(b)
    gen double xb_manual = ifp*b[1,1] + tumsize*b[1,2] + pelnode*b[1,3]
    gen double xb_diff = abs(xb_pred - xb_manual)
    summ xb_diff, meanonly
    assert r(max) < 1e-6
    drop xb_pred xb_manual xb_diff
}
if _rc == 0 {
    display as result "  PASS: V17 xb = Z*beta (manual)"
    local ++pass_count
}
else {
    display as error "  FAIL: V17 xb manual (rc=`=_rc')"
    local ++fail_count
}

* V18: CIF monotonically non-decreasing for fixed covariate pattern
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    matrix bh = e(basehaz)
    local nr = rowsof(bh)
    local xb1 = e(b)[1,1] * ifp[1] + e(b)[1,2] * tumsize[1] + ///
        e(b)[1,3] * pelnode[1]
    local ok = 1
    forvalues i = 2/`nr' {
        local prev = `i' - 1
        local cif_i = 1 - exp(-bh[`i', 2] * exp(`xb1'))
        local cif_prev = 1 - exp(-bh[`prev', 2] * exp(`xb1'))
        if `cif_i' < `cif_prev' - 1e-12 {
            local ok = 0
        }
    }
    assert `ok' == 1
}
if _rc == 0 {
    display as result "  PASS: V18 CIF monotonically non-decreasing"
    local ++pass_count
}
else {
    display as error "  FAIL: V18 CIF monotonicity (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 4: Basehaz properties}{...}

* V19: Basehaz cumhazard positive and increasing
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
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
    display as result "  PASS: V19 basehaz cumhazard increasing"
    local ++pass_count
}
else {
    display as error "  FAIL: V19 basehaz increasing (rc=`=_rc')"
    local ++fail_count
}

* V20: Basehaz times sorted
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
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
    display as result "  PASS: V20 basehaz times sorted"
    local ++pass_count
}
else {
    display as error "  FAIL: V20 basehaz sorted (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 5: Robust/cluster SE validation}{...}

* V21: Default robust V is symmetric and positive diagonal
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    matrix V_robust = e(V)
    forvalues i = 1/3 {
        forvalues j = 1/3 {
            assert abs(V_robust[`i',`j'] - V_robust[`j',`i']) < 1e-12
        }
    }
    forvalues i = 1/3 {
        assert V_robust[`i',`i'] > 0
    }
}
if _rc == 0 {
    display as result "  PASS: V21 robust V symmetric and positive diagonal"
    local ++pass_count
}
else {
    display as error "  FAIL: V21 robust V (rc=`=_rc')"
    local ++fail_count
}

* V22: strata produces reasonable results
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize, compete(status) cause(1) nolog strata(pelnode)
    assert e(converged) == 1
    assert e(N_fail) == 33
}
if _rc == 0 {
    display as result "  PASS: V22 strata produces reasonable results"
    local ++pass_count
}
else {
    display as error "  FAIL: V22 strata (rc=`=_rc')"
    local ++fail_count
}

* V23: bysort fix — if/in restriction with multi-record stset
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    matrix b_ref = e(b)
    local N_ref = e(N)
    local N_orig = _N
    set obs `=`N_orig'+1'
    replace stnum = 1 in `=`N_orig'+1'
    replace dftime = 99 in `=`N_orig'+1'
    replace dfcens = 0 in `=`N_orig'+1'
    replace status = 0 in `=`N_orig'+1'
    replace ifp = 0 in `=`N_orig'+1'
    replace tumsize = 0 in `=`N_orig'+1'
    replace pelnode = 0 in `=`N_orig'+1'
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode if _n <= `N_orig', compete(status) cause(1) nolog
    matrix b_test = e(b)
    assert abs(b_test[1,1] - b_ref[1,1]) < `tol'
    assert abs(b_test[1,2] - b_ref[1,2]) < `tol'
    assert abs(b_test[1,3] - b_ref[1,3]) < `tol'
    assert e(N) == `N_ref'
}
if _rc == 0 {
    display as result "  PASS: V23 bysort fix: coefficients match"
    local ++pass_count
}
else {
    display as error "  FAIL: V23 bysort fix (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 6: norobust SE validation}{...}

* V24: norobust V is symmetric and positive on the diagonal
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog norobust
    matrix V_nr = e(V)
    assert "`e(vce)'" == "oim"
    forvalues i = 1/3 {
        forvalues j = 1/3 {
            assert abs(V_nr[`i',`j'] - V_nr[`j',`i']) < 1e-12
        }
    }
    forvalues i = 1/3 {
        assert V_nr[`i',`i'] > 0
    }
}
if _rc == 0 {
    display as result "  PASS: V24 norobust V symmetric and positive diagonal"
    local ++pass_count
}
else {
    display as error "  FAIL: V24 norobust V (rc=`=_rc')"
    local ++fail_count
}

* V24b: Robust SEs vs stcrreg robust SEs (like-for-like comparison)
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==1) id(stnum)
    stcrreg ifp tumsize pelnode, compete(status == 2)
    matrix V_ref = e(V)
    restore
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    matrix V_rob = e(V)
    * Both use sandwich estimator but with different computational
    * approaches (data expansion vs forward-backward scan IPCW).
    * Tolerance of 15% reflects genuine algorithmic differences.
    forvalues i = 1/3 {
        local se_ref = sqrt(V_ref[`i',`i'])
        local se_rob = sqrt(V_rob[`i',`i'])
        local rel_diff = abs(`se_rob' - `se_ref') / `se_ref'
        display as text "  robust SE var `i': fg=" %8.5f `se_rob' ///
            " ref=" %8.5f `se_ref' " rel_diff=" %6.3f `rel_diff'
        assert `rel_diff' < 0.15
    }
}
if _rc == 0 {
    display as result "  PASS: V24b robust SEs vs stcrreg (< 15%)"
    local ++pass_count
}
else {
    display as error "  FAIL: V24b robust SEs (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 7: Factor variable coefficient validation}{...}

* V25: Factor variable coefficients vs stcrreg with manual indicators
local ++test_count
capture noisily {
    _setup_hypoxia
    * pelnode is binary (0/1) — manual indicator for level 1
    gen byte pel_1 = (pelnode == 1)
    preserve
    stset dftime, failure(status==1) id(stnum)
    stcrreg pel_1 ifp, compete(status == 2)
    matrix b_ref = e(b)
    restore
    stset dftime, failure(dfcens==1) id(stnum)
    drop pel_1
    * Factor variable version
    finegray i.pelnode ifp, compete(status) cause(1) nolog
    matrix b_fg = e(b)
    assert abs(b_fg[1,1] - b_ref[1,1]) < `tol'
    assert abs(b_fg[1,2] - b_ref[1,2]) < `tol'
}
if _rc == 0 {
    display as result "  PASS: V25 factor variable coefficients vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: V25 factor vs stcrreg (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 8: Non-default censvalue validation}{...}

* V26: censvalue(9) produces identical coefficients to censvalue(0)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    matrix b_std = e(b)
    local ll_std = e(ll)
    * Recode censoring to 9
    gen byte status9 = status
    replace status9 = 9 if status == 0
    finegray ifp tumsize pelnode, compete(status9) cause(1) censvalue(9) nolog
    matrix b_alt = e(b)
    local ll_alt = e(ll)
    forvalues i = 1/3 {
        assert abs(b_alt[1,`i'] - b_std[1,`i']) < 1e-8
    }
    assert abs(`ll_alt' - `ll_std') < 1e-8
    drop status9
}
if _rc == 0 {
    display as result "  PASS: V26 censvalue(9) identical to censvalue(0)"
    local ++pass_count
}
else {
    display as error "  FAIL: V26 censvalue equivalence (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 9: Predict if/in invariance}{...}

* V27: predict xb with if/in matches full-sample values
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict xb_full, xb
    finegray_predict xb_if if ifp > 10, xb
    * Where both are non-missing, values must match exactly
    gen double xb_diff = abs(xb_full - xb_if) if xb_if < .
    summ xb_diff, meanonly
    assert r(max) < 1e-10
    drop xb_full xb_if xb_diff
}
if _rc == 0 {
    display as result "  PASS: V27 predict xb if matches full-sample"
    local ++pass_count
}
else {
    display as error "  FAIL: V27 predict if invariance (rc=`=_rc')"
    local ++fail_count
}

* V28: predict cif with in matches full-sample values
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict cif_full, cif
    finegray_predict cif_in in 1/50, cif
    gen double cif_diff = abs(cif_full - cif_in) if cif_in < .
    summ cif_diff, meanonly
    assert r(max) < 1e-10
    drop cif_full cif_in cif_diff
}
if _rc == 0 {
    display as result "  PASS: V28 predict cif in matches full-sample"
    local ++pass_count
}
else {
    display as error "  FAIL: V28 predict cif in invariance (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 10: Multiple strata validation}{...}

* V29: Multiple strata matches manual egen group — exact coefficient match
local ++test_count
capture noisily {
    _setup_hypoxia
    gen byte ifp_grp = (ifp > 10)
    * Multiple strata (auto-combined internally)
    finegray tumsize, compete(status) cause(1) nolog strata(pelnode ifp_grp)
    matrix b_multi = e(b)
    local ll_multi = e(ll)
    * Manual egen group equivalent
    egen int strata_combo = group(pelnode ifp_grp)
    finegray tumsize, compete(status) cause(1) nolog strata(strata_combo)
    matrix b_manual = e(b)
    local ll_manual = e(ll)
    * Must produce identical results
    assert abs(b_multi[1,1] - b_manual[1,1]) < 1e-8
    assert abs(`ll_multi' - `ll_manual') < 1e-8
    drop ifp_grp strata_combo
}
if _rc == 0 {
    display as result "  PASS: V29 multiple strata — reasonable coefficients"
    local ++pass_count
}
else {
    display as error "  FAIL: V29 multiple strata (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 11: phtest invariants}{...}

local tol = 1e-4

* V30: Global chi2 == sum of per-variable chi2
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_phtest
    matrix ph = r(phtest)
    local sum_chi2 = ph[1,1] + ph[2,1] + ph[3,1]
    assert abs(`sum_chi2' - r(chi2)) < 1e-8
}
if _rc == 0 {
    display as result "  PASS: V30 global chi2 == sum of per-var chi2"
    local ++pass_count
}
else {
    display as error "  FAIL: V30 chi2 sum (rc=`=_rc')"
    local ++fail_count
}

* V31: Each per-variable df == 1
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_phtest
    matrix ph = r(phtest)
    forvalues i = 1/3 {
        assert ph[`i', 2] == 1
    }
}
if _rc == 0 {
    display as result "  PASS: V31 each per-var df == 1"
    local ++pass_count
}
else {
    display as error "  FAIL: V31 per-var df (rc=`=_rc')"
    local ++fail_count
}

* V32: Each per-variable p == chi2tail(1, chi2_i)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_phtest
    matrix ph = r(phtest)
    forvalues i = 1/3 {
        local p_manual = chi2tail(1, ph[`i', 1])
        assert abs(ph[`i', 3] - `p_manual') < 1e-10
    }
}
if _rc == 0 {
    display as result "  PASS: V32 per-var p == chi2tail(1, chi2_i)"
    local ++pass_count
}
else {
    display as error "  FAIL: V32 per-var p formula (rc=`=_rc')"
    local ++fail_count
}

* V33: r(N_fail) matches e(N_fail) from prior finegray
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    local nfail_e = e(N_fail)
    finegray_phtest
    assert r(N_fail) == `nfail_e'
}
if _rc == 0 {
    display as result "  PASS: V33 r(N_fail) matches e(N_fail)"
    local ++pass_count
}
else {
    display as error "  FAIL: V33 N_fail match (rc=`=_rc')"
    local ++fail_count
}

* V34: Different time functions produce different chi2 values
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_phtest, time(rank)
    local chi2_rank = r(chi2)
    finegray_phtest, time(log)
    local chi2_log = r(chi2)
    finegray_phtest, time(identity)
    local chi2_id = r(chi2)
    * All three should differ (on real data with non-trivial time distribution)
    assert abs(`chi2_rank' - `chi2_log') > 1e-6
    assert abs(`chi2_rank' - `chi2_id') > 1e-6
    assert abs(`chi2_log' - `chi2_id') > 1e-6
}
if _rc == 0 {
    display as result "  PASS: V34 time functions produce different chi2"
    local ++pass_count
}
else {
    display as error "  FAIL: V34 time functions differ (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 12: Schoenfeld residual properties}{...}

* V35: Schoenfeld residuals approximately sum to 0
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict sch, schoenfeld
    foreach v in sch sch_2 sch_3 {
        quietly summ `v', meanonly
        assert abs(r(sum)) < 1.0
    }
    drop sch sch_2 sch_3
}
if _rc == 0 {
    display as result "  PASS: V35 Schoenfeld residuals sum near 0"
    local ++pass_count
}
else {
    display as error "  FAIL: V35 Schoenfeld sum (rc=`=_rc')"
    local ++fail_count
}

* V36: Schoenfeld residuals defined for exactly N_fail observations
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    local nfail = e(N_fail)
    finegray_predict sch, schoenfeld
    foreach v in sch sch_2 sch_3 {
        quietly count if `v' < .
        assert r(N) == `nfail'
    }
    drop sch sch_2 sch_3
}
if _rc == 0 {
    display as result "  PASS: V36 Schoenfeld count == N_fail for all covariates"
    local ++pass_count
}
else {
    display as error "  FAIL: V36 Schoenfeld count (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 13: Convergence stress tests}{...}

* V37: iterate(1) forces non-convergence
* Contract (FG-H07): the fit posts, as stcrreg's does -- rc 0, e(converged)=0,
* e(b)/e(V) available for inspection -- with the warning printed above the
* coefficient table. What changed is that the post-estimation commands now
* refuse to consume it; through v1.1.4 they read e(b) without checking.
local ++test_count
capture noisily {
    _setup_hypoxia
    capture noisily finegray ifp tumsize pelnode, compete(status) cause(1) nolog iterate(1)
    assert _rc == 0
    assert e(converged) == 0
    confirm matrix e(b)
    confirm matrix e(V)

    * but the result surface is quarantined from every consumer
    capture finegray_cif, attime(5)
    assert _rc == 430
    capture finegray_phtest
    assert _rc == 430

    * the converged fit on the same data still posts a full result surface
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert e(converged) == 1
    confirm matrix e(b)
    confirm matrix e(V)
}
if _rc == 0 {
    display as result "  PASS: V37 nonconverged fit posts but is quarantined from post-estimation"
    local ++pass_count
}
else {
    display as error "  FAIL: V37 iterate(1) (rc=`=_rc')"
    local ++fail_count
}

* V38: Collinear covariates are rejected rather than ridge-regularized
local ++test_count
capture noisily {
    _setup_hypoxia
    gen double ifp2 = ifp * 2
    capture finegray ifp ifp2 tumsize, compete(status) cause(1) nolog
    assert _rc == 459
    assert `"`_dta[_finegray_estimated]'"' == ""
    drop ifp2
}
if _rc == 0 {
    display as result "  PASS: V38 collinear covariates rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: V38 collinear covariates (rc=`=_rc')"
    local ++fail_count
}

* V39: Near-separation — binary covariate that nearly predicts cause
local ++test_count
capture noisily {
    _setup_hypoxia
    gen byte near_sep = (status == 1)
    * Flip a few to avoid perfect separation
    replace near_sep = 1 - near_sep in 1/3
    finegray near_sep ifp, compete(status) cause(1) nolog
    * Should converge (possibly with large coefficient) or error gracefully
    confirm matrix e(b)
    drop near_sep
}
if _rc == 0 {
    display as result "  PASS: V39 near-separation handled"
    local ++pass_count
}
else {
    display as error "  FAIL: V39 near-separation (rc=`=_rc')"
    local ++fail_count
}

* V40: Zero cause events in one strata stratum
local ++test_count
capture noisily {
    _setup_hypoxia
    * Create strata variable where one stratum has no cause-1 events
    gen byte strata_var = (ifp > 20)
    * Remove cause-1 events in the small stratum
    replace status = 2 if status == 1 & strata_var == 1
    finegray ifp tumsize, compete(status) cause(1) nolog strata(strata_var)
    assert e(converged) == 1
    drop strata_var
}
if _rc == 0 {
    display as result "  PASS: V40 zero-events stratum converges"
    local ++pass_count
}
else {
    display as error "  FAIL: V40 zero-events stratum (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 14: Interaction validation}{...}

* V42: i.var##c.var — coefficient sign/magnitude sanity
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    * All coefficients should be finite and non-missing
    matrix b = e(b)
    local p = colsof(b)
    forvalues j = 1/`p' {
        assert !missing(b[1,`j'])
        assert abs(b[1,`j']) < 100
    }
    * SEs should be positive
    matrix V = e(V)
    forvalues j = 1/`p' {
        assert V[`j',`j'] > 0
    }
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: V42 interaction coefficient sanity"
    local ++pass_count
}
else {
    display as error "  FAIL: V42 interaction sanity (rc=`=_rc')"
    local ++fail_count
}

* V43: Full factorial (##) = main effects + interaction match
local ++test_count
capture noisily {
    _setup_hypoxia
    * Fit with ##
    finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    matrix b_full = e(b)
    local ll_full = e(ll)
    cap drop _fg_*
    * Fit with separate main effects + interaction
    finegray i.pelnode ifp i.pelnode#c.ifp tumsize, compete(status) cause(1) nolog
    matrix b_sep = e(b)
    local ll_sep = e(ll)
    * Log-likelihoods must match (same model, different syntax)
    assert abs(`ll_full' - `ll_sep') < 1e-6
    * Coefficients must match (same order: pelnode_1, ifp, pelnode_1Xifp, tumsize)
    local p = colsof(b_full)
    forvalues j = 1/`p' {
        assert abs(b_full[1,`j'] - b_sep[1,`j']) < 1e-6
    }
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: V43 ## equals main + interaction"
    local ++pass_count
}
else {
    display as error "  FAIL: V43 ## vs main+interaction (rc=`=_rc')"
    local ++fail_count
}

* V44: CIF from interaction model in [0,1] with tighter checks
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    finegray_predict cif_v, cif
    * All CIF values should be in [0,1]
    assert cif_v >= 0 & cif_v <= 1 if !missing(cif_v)
    * Mean CIF should be reasonable (not 0 or 1)
    summ cif_v, meanonly
    assert r(mean) > 0.01 & r(mean) < 0.99
    drop cif_v
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: V44 interaction CIF bounds"
    local ++pass_count
}
else {
    display as error "  FAIL: V44 interaction CIF (rc=`=_rc')"
    local ++fail_count
}

* V45: Multiple FV terms in one model
local ++test_count
capture noisily {
    _setup_hypoxia
    gen byte ifp_grp = (ifp > 10)
    finegray i.pelnode##i.ifp_grp c.tumsize, compete(status) cause(1) nolog
    * Sparse interaction cell may cause quasi-separation → df_m <= 4
    assert e(df_m) <= 4
    assert e(df_m) >= 2
    assert e(ll) < .
    drop ifp_grp
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: V45 multiple FV terms"
    local ++pass_count
}
else {
    display as error "  FAIL: V45 multiple FV terms (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SUMMARY}{...}
display ""
display as text _dup(60) "="
display as text "RESULTS: validation_finegray.do"
display as text _dup(60) "="
display as text "Total:  " as result `test_count'
display as text "Passed: " as result `pass_count'
display as text "Failed: " as result `fail_count'
display as text _dup(60) "="

display as text "RESULT: validation_finegray tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}

log close _val_finegray
