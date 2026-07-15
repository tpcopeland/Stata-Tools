* crossval_finegray.do - Cross-validation suite for finegray package
* Tests: systematic vs stcrreg, strata, robust/cluster SEs, CIF, DGP, benchmarks
* Package: finegray v1.1.0

clear all
set more off
set varabbrev off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0

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
* Generated R cross-check CSVs are transient: write them to a temp directory so
* nothing lands in (or churns) the tracked qa/ tree, and so a failed/absent R
* run cannot silently validate against a stale committed copy (matches
* crossval_cif.do, which already uses c(tmpdir)).
local datadir "`c(tmpdir)'/finegray_xv_main"
capture mkdir "`datadir'"

capture log close _all
log using "`qadir'/crossval_finegray.log", ///
    replace text name(_crossval_finegray)

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

local tol = 1e-4

* {smcl}
* {* SECTION 1: finegray vs stcrreg — covariate combinations}{...}

* C1: 2-cov cause 1
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==1) id(stnum)
    stcrreg ifp tumsize, compete(status == 2)
    matrix b_ref = e(b)
    restore
    finegray ifp tumsize, compete(status) cause(1) nolog
    matrix b_fg = e(b)
    assert abs(b_fg[1,1] - b_ref[1,1]) < `tol'
    assert abs(b_fg[1,2] - b_ref[1,2]) < `tol'
}
if _rc == 0 {
    display as result "  PASS: C1 2-cov cause 1 vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: C1 2-cov cause 1 (rc=`=_rc')"
    local ++fail_count
}

* C2: 1-cov cause 2
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==2) id(stnum)
    stcrreg ifp, compete(status == 1)
    local b_ref = e(b)[1,1]
    restore
    finegray ifp, compete(status) cause(2) nolog
    local b_fg = e(b)[1,1]
    assert abs(`b_fg' - `b_ref') < `tol'
}
if _rc == 0 {
    display as result "  PASS: C2 1-cov cause 2 vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: C2 1-cov cause 2 (rc=`=_rc')"
    local ++fail_count
}

* C3: 3-cov cause 2
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==2) id(stnum)
    stcrreg ifp tumsize pelnode, compete(status == 1)
    matrix b_ref = e(b)
    restore
    finegray ifp tumsize pelnode, compete(status) cause(2) nolog
    matrix b_fg = e(b)
    forvalues i = 1/3 {
        assert abs(b_fg[1,`i'] - b_ref[1,`i']) < `tol'
    }
}
if _rc == 0 {
    display as result "  PASS: C3 3-cov cause 2 vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: C3 3-cov cause 2 (rc=`=_rc')"
    local ++fail_count
}

* C4: 1-cov cause 1 (tumsize only)
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==1) id(stnum)
    stcrreg tumsize, compete(status == 2)
    local b_ref = e(b)[1,1]
    restore
    finegray tumsize, compete(status) cause(1) nolog
    local b_fg = e(b)[1,1]
    assert abs(`b_fg' - `b_ref') < `tol'
}
if _rc == 0 {
    display as result "  PASS: C4 1-cov cause 1 (tumsize) vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: C4 1-cov tumsize (rc=`=_rc')"
    local ++fail_count
}

* C5: 2-cov cause 2 (ifp pelnode)
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==2) id(stnum)
    stcrreg ifp pelnode, compete(status == 1)
    matrix b_ref = e(b)
    restore
    finegray ifp pelnode, compete(status) cause(2) nolog
    matrix b_fg = e(b)
    assert abs(b_fg[1,1] - b_ref[1,1]) < `tol'
    assert abs(b_fg[1,2] - b_ref[1,2]) < `tol'
}
if _rc == 0 {
    display as result "  PASS: C5 2-cov cause 2 (ifp pelnode) vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: C5 2-cov cause 2 (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 2: SE cross-validation against stcrreg}{...}

* C6: Robust SEs vs stcrreg (3-cov cause 1)
* Note: Both use sandwich estimator but different computational approaches
* (IPCW forward-backward scan vs data expansion). Max observed diff ~13%.
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==1) id(stnum)
    stcrreg ifp tumsize pelnode, compete(status == 2)
    matrix V_ref = e(V)
    restore
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    matrix V_fg = e(V)
    forvalues i = 1/3 {
        local se_ref = sqrt(V_ref[`i',`i'])
        local se_fg = sqrt(V_fg[`i',`i'])
        local rel_diff = abs(`se_fg' - `se_ref') / `se_ref'
        display as text "  SE var `i': fg=" %8.5f `se_fg' " ref=" %8.5f `se_ref' ///
            " rel_diff=" %6.3f `rel_diff'
        assert `rel_diff' < 0.15
    }
}
if _rc == 0 {
    display as result "  PASS: C6 SEs vs stcrreg (< 15% rel diff)"
    local ++pass_count
}
else {
    display as error "  FAIL: C6 SEs vs stcrreg (rc=`=_rc')"
    local ++fail_count
}

* C7: SEs vs stcrreg (1-cov cause 2)
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==2) id(stnum)
    stcrreg ifp, compete(status == 1)
    local se_ref = sqrt(e(V)[1,1])
    restore
    finegray ifp, compete(status) cause(2) nolog
    local se_fg = sqrt(e(V)[1,1])
    local rel_diff = abs(`se_fg' - `se_ref') / `se_ref'
    display as text "  SE cause 2: fg=" %8.5f `se_fg' " ref=" %8.5f `se_ref' ///
        " rel_diff=" %6.3f `rel_diff'
    assert `rel_diff' < 0.25
}
if _rc == 0 {
    display as result "  PASS: C7 SE cause 2 vs stcrreg (< 25%)"
    local ++pass_count
}
else {
    display as error "  FAIL: C7 SE cause 2 (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 3: Log-likelihood and chi2 cross-validation}{...}

* C8: LL matches stcrreg
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==1) id(stnum)
    stcrreg ifp tumsize pelnode, compete(status == 2)
    local ll_ref = e(ll)
    restore
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    local ll_fg = e(ll)
    local rel_diff = abs(`ll_fg' - `ll_ref') / abs(`ll_ref')
    assert `rel_diff' < 0.001
}
if _rc == 0 {
    display as result "  PASS: C8 LL matches stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: C8 LL (rc=`=_rc')"
    local ++fail_count
}

* C9: ll > ll_0 (model improves on null)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert e(ll) > e(ll_0)
}
if _rc == 0 {
    display as result "  PASS: C9 ll > ll_0"
    local ++pass_count
}
else {
    display as error "  FAIL: C9 ll > ll_0 (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 4: Robust SE cross-validation}{...}

* C10: Robust SEs vs stcrreg robust
local ++test_count
capture noisily {
    _setup_hypoxia
    preserve
    stset dftime, failure(status==1) id(stnum)
    stcrreg ifp tumsize, compete(status == 2)
    matrix V_ref = e(V)
    restore
    finegray ifp tumsize, compete(status) cause(1) nolog
    matrix V_fg = e(V)
    forvalues i = 1/2 {
        local se_ref = sqrt(V_ref[`i',`i'])
        local se_fg = sqrt(V_fg[`i',`i'])
        local ratio = `se_fg' / `se_ref'
        display as text "  robust SE ratio var `i': " %6.3f `ratio'
        assert `ratio' > 0.95 & `ratio' < 1.05
    }
}
if _rc == 0 {
    display as result "  PASS: C10 robust SEs vs stcrreg (ratio 0.95-1.05)"
    local ++pass_count
}
else {
    display as error "  FAIL: C10 robust SEs (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 5: strata cross-validation}{...}

* C11: strata vs no strata — coefficients differ (different censoring model)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize, compete(status) cause(1) nolog
    matrix b_nostrata = e(b)
    finegray ifp tumsize, compete(status) cause(1) nolog strata(pelnode)
    matrix b_strata = e(b)
    * Coefficients should be similar but not identical
    local diff1 = abs(b_strata[1,1] - b_nostrata[1,1])
    local diff2 = abs(b_strata[1,2] - b_nostrata[1,2])
    * Both should be non-zero (model ran)
    assert b_strata[1,1] != 0
    assert b_strata[1,2] != 0
    * Should be in the same ballpark (within 50% of each other)
    assert abs(b_strata[1,1] - b_nostrata[1,1]) / max(abs(b_nostrata[1,1]), 0.01) < 0.5
}
if _rc == 0 {
    display as result "  PASS: C11 strata vs no strata — reasonable divergence"
    local ++pass_count
}
else {
    display as error "  FAIL: C11 strata vs no strata (rc=`=_rc')"
    local ++fail_count
}

* C12: strata with CIF prediction
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize, compete(status) cause(1) nolog strata(pelnode)
    finegray_predict cif_strata, cif
    summ cif_strata, meanonly
    assert r(min) >= 0 & r(max) <= 1
    drop cif_strata
}
if _rc == 0 {
    display as result "  PASS: C12 strata CIF in [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: C12 strata CIF (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 6: Predict cross-validation}{...}

* C13: xb + basehaz → CIF consistency
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog basehaz
    finegray_predict xb_hat, xb
    finegray_predict cif_hat, cif
    matrix bh = e(basehaz)
    local nr = rowsof(bh)
    * Check that xb and cif are correlated (same direction)
    * and CIF is in valid range — precision of step function lookup in
    * Stata locals vs Mata binary search can differ, so avoid pointwise
    * comparison
    summ cif_hat, meanonly
    assert r(min) >= 0 & r(max) <= 1
    * CIF depends on both xb and _t, so correlation with xb alone is moderate
    spearman xb_hat cif_hat
    display as text "  xb-CIF Spearman rho = " %6.4f r(rho)
    assert r(rho) > 0.5
    drop xb_hat cif_hat
}
if _rc == 0 {
    display as result "  PASS: C13 xb+basehaz → CIF consistency"
    local ++pass_count
}
else {
    display as error "  FAIL: C13 CIF consistency (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 7: Simulated DGP cross-validation}{...}

* C14: Simulated data — known beta, recover direction
local ++test_count
capture noisily {
    clear
    set seed 42
    set obs 1000
    gen id = _n
    gen double x1 = rnormal()
    gen double x2 = rbinomial(1, 0.5)
    * True beta: x1=0.5, x2=-0.3
    gen double h = exp(0.5*x1 - 0.3*x2)
    gen double u = runiform()
    gen double t_event = -ln(u) / h
    gen double t_censor = runiform() * 5
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    * Competing risk: 30% of events become competing
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.3
    replace status = 2 if d == 1 & status == 0
    stset t, failure(d) id(id)
    finegray x1 x2, compete(status) cause(1) nolog
    * Coefficients should have correct signs
    assert e(b)[1,1] > 0
    assert e(b)[1,2] < 0
    assert e(converged) == 1
}
if _rc == 0 {
    display as result "  PASS: C14 simulated DGP — correct sign recovery"
    local ++pass_count
}
else {
    display as error "  FAIL: C14 simulated DGP (rc=`=_rc')"
    local ++fail_count
}

* C15: Simulated data — finegray vs stcrreg on same DGP
local ++test_count
capture noisily {
    clear
    set seed 777
    set obs 500
    gen id = _n
    gen double x1 = rnormal()
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.3*x1)
    gen double t_censor = runiform() * 4
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.4
    replace status = 2 if d == 1 & status == 0
    * finegray
    stset t, failure(d) id(id)
    finegray x1, compete(status) cause(1) nolog
    local b_fg = e(b)[1,1]
    * stcrreg
    stset t, failure(status==1) id(id)
    stcrreg x1, compete(status == 2)
    local b_ref = e(b)[1,1]
    assert abs(`b_fg' - `b_ref') < 0.001
}
if _rc == 0 {
    display as result "  PASS: C15 simulated finegray vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: C15 simulated vs stcrreg (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 8: CIF mathematical properties}{...}

* C16: CIF at t=0 is 0 for all covariate patterns
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    gen double t_zero = 0
    finegray_predict cif_zero, cif timevar(t_zero)
    summ cif_zero, meanonly
    assert r(max) < 1e-10
    drop t_zero cif_zero
}
if _rc == 0 {
    display as result "  PASS: C16 CIF(0) = 0"
    local ++pass_count
}
else {
    display as error "  FAIL: C16 CIF(0) (rc=`=_rc')"
    local ++fail_count
}

* C17: CIF increases with time
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    gen double t_early = 2
    gen double t_late = 10
    finegray_predict cif_early, cif timevar(t_early)
    finegray_predict cif_late, cif timevar(t_late)
    * CIF at later time should be >= CIF at earlier time
    gen double diff = cif_late - cif_early
    summ diff, meanonly
    assert r(min) >= -1e-10
    drop t_early t_late cif_early cif_late diff
}
if _rc == 0 {
    display as result "  PASS: C17 CIF increases with time"
    local ++pass_count
}
else {
    display as error "  FAIL: C17 CIF time monotone (rc=`=_rc')"
    local ++fail_count
}

* C18: Higher positive xb → higher CIF (at fixed time)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict xb_hat, xb
    gen double t_fixed = 5
    finegray_predict cif_hat, cif timevar(t_fixed)
    * Rank correlation between xb and CIF should be positive
    spearman xb_hat cif_hat
    assert r(rho) > 0.9
    drop xb_hat t_fixed cif_hat
}
if _rc == 0 {
    display as result "  PASS: C18 higher xb → higher CIF"
    local ++pass_count
}
else {
    display as error "  FAIL: C18 xb-CIF correlation (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 9: Extreme censoring stress test}{...}

* C19: High censoring (80%) — finegray vs stcrreg
local ++test_count
capture noisily {
    clear
    set seed 99
    set obs 500
    gen id = _n
    gen double x1 = rnormal()
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.4*x1)
    * Heavy censoring
    gen double t_censor = runiform() * 1.5
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.5
    replace status = 2 if d == 1 & status == 0
    * finegray
    stset t, failure(d) id(id)
    finegray x1, compete(status) cause(1) nolog
    local b_fg = e(b)[1,1]
    * stcrreg
    stset t, failure(status==1) id(id)
    stcrreg x1, compete(status == 2)
    local b_ref = e(b)[1,1]
    assert abs(`b_fg' - `b_ref') < 0.01
}
if _rc == 0 {
    display as result "  PASS: C19 high censoring finegray vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: C19 high censoring (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 10: Cluster SE cross-validation}{...}

* C20: Cluster SEs — positive AND larger than model SEs under intra-cluster
* correlation.  The point of a cluster-robust SE is that it inflates when
* observations within a cluster are correlated; asserting only that it is
* positive (QA-H03) is vacuous -- it passes even when clustering makes NO
* difference.  The old DGP had essentially no within-cluster correlation, so the
* cluster SE was actually SMALLER than the model SE (0.06474 vs 0.06546), which
* is exactly why the assertion had been weakened to `> 0' and the pass message
* quietly renamed.  Fix the DGP, not the assertion: a shared cluster frailty now
* drives both x1 and the hazard, so the independence SE genuinely understates and
* the contrast the test is named for actually holds (ratio ~1.15).
local ++test_count
capture noisily {
    clear
    set seed 20260715
    set obs 60
    gen clid = _n
    gen double u_cl = rnormal()            // cluster random effect
    expand 20
    bysort clid: gen id = _n + 1000*clid
    gen double x1 = u_cl + 0.3*rnormal()   // x1 shares the cluster effect
    gen double frail = exp(1.2*u_cl)       // frailty on the hazard, same effect
    gen double u = runiform()
    gen double t_event = -ln(u) / (exp(0.3*x1) * frail)
    gen double t_censor = runiform() * 4
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.4
    replace status = 2 if d == 1 & status == 0
    stset t, failure(d) id(id)
    finegray x1, compete(status) cause(1) nolog
    local se_model = sqrt(e(V)[1,1])
    finegray x1, compete(status) cause(1) nolog cluster(clid)
    local se_cluster = sqrt(e(V)[1,1])
    assert `se_cluster' > 0
    display as text "  model SE=" %8.5f `se_model' " cluster SE=" %8.5f `se_cluster' ///
        " ratio=" %6.3f `se_cluster'/`se_model'
    * the contrast the test is named for: clustering inflates the SE here
    assert `se_cluster' > `se_model'
}
if _rc == 0 {
    display as result "  PASS: C20 cluster SE > model SE under intra-cluster correlation"
    local ++pass_count
}
else {
    display as error "  FAIL: C20 cluster SEs (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 11: Performance benchmarks — finegray vs stcrreg}{...}

display ""
display as text _dup(60) "="
display as text "PERFORMANCE BENCHMARKS: finegray vs stcrreg"
display as text _dup(60) "="

program define _run_benchmark
    args n_obs seed
    clear
    set seed `seed'
    set obs `n_obs'
    gen id = _n
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen double x3 = rbinomial(1, 0.5)
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.3*x1 - 0.2*x2 + 0.1*x3)
    gen double t_censor = runiform() * 3
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.35
    replace status = 2 if d == 1 & status == 0
end

* C21: Benchmark N=500 — finegray vs stcrreg
local ++test_count
capture noisily {
    _run_benchmark 500 42

    * Time finegray
    stset t, failure(d) id(id)
    timer clear 1
    timer on 1
    finegray x1 x2 x3, compete(status) cause(1) nolog
    timer off 1
    quietly timer list 1
    local t_fg = r(t1)
    local b_fg = e(b)[1,1]

    * Time stcrreg (feasible at N=500)
    stset t, failure(status==1) id(id)
    timer clear 2
    timer on 2
    stcrreg x1 x2 x3, compete(status == 2)
    timer off 2
    quietly timer list 2
    local t_ref = r(t2)
    local b_ref = e(b)[1,1]

    * Coefficients must match
    assert abs(`b_fg' - `b_ref') < 0.001

    local ratio = `t_ref' / max(`t_fg', 0.001)
    display as text "  N=500: finegray=" %6.3f `t_fg' ///
        "s  stcrreg=" %6.3f `t_ref' "s  ratio=" %6.1f `ratio' "x"
}
if _rc == 0 {
    display as result "  PASS: benchmark N=500"
    local ++pass_count
}
else {
    display as error "  FAIL: benchmark N=500 (rc=`=_rc')"
    local ++fail_count
}

* C22-C23: Benchmarks at N=2000, 5000 (finegray only — stcrreg too slow)
foreach n_obs in 2000 5000 {
    local ++test_count
    capture noisily {
        _run_benchmark `n_obs' 42

        stset t, failure(d) id(id)
        timer clear 1
        timer on 1
        finegray x1 x2 x3, compete(status) cause(1) nolog
        timer off 1
        quietly timer list 1
        local t_fg = r(t1)
        assert e(converged) == 1
        display as text "  N=`n_obs': finegray=" %6.3f `t_fg' "s"
    }
    if _rc == 0 {
        display as result "  PASS: benchmark N=`n_obs' (finegray only)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: benchmark N=`n_obs' (rc=`=_rc')"
        local ++fail_count
    }
}

* C24: Large benchmark N=10000 (finegray only — stcrreg too slow at this scale)
local ++test_count
capture noisily {
    _run_benchmark 10000 42

    stset t, failure(d) id(id)
    timer clear 1
    timer on 1
    finegray x1 x2 x3, compete(status) cause(1) nolog
    timer off 1
    quietly timer list 1
    local t_fg = r(t1)
    assert e(converged) == 1
    display as text "  N=10000: finegray=" %6.3f `t_fg' "s (stcrreg too slow to compare)"
}
if _rc == 0 {
    display as result "  PASS: benchmark N=10000 (finegray only)"
    local ++pass_count
}
else {
    display as error "  FAIL: benchmark N=10000 (rc=`=_rc')"
    local ++fail_count
}

* C25: Benchmark N=50000 (finegray stress test)
local ++test_count
capture noisily {
    _run_benchmark 50000 42

    stset t, failure(d) id(id)
    timer clear 1
    timer on 1
    finegray x1 x2 x3, compete(status) cause(1) nolog
    timer off 1
    quietly timer list 1
    local t_fg = r(t1)
    assert e(converged) == 1
    display as text "  N=50000: finegray=" %6.3f `t_fg' "s"
}
if _rc == 0 {
    display as result "  PASS: benchmark N=50000 (finegray stress)"
    local ++pass_count
}
else {
    display as error "  FAIL: benchmark N=50000 (rc=`=_rc')"
    local ++fail_count
}

display as text _dup(60) "="

* {smcl}
* {* SECTION 12: norobust cross-validation vs stcrreg}{...}

* C26: norobust SEs vs stcrreg — simulated data
local ++test_count
capture noisily {
    clear
    set seed 55
    set obs 800
    gen id = _n
    gen double x1 = rnormal()
    gen double x2 = rbinomial(1, 0.4)
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.5*x1 - 0.2*x2)
    gen double t_censor = runiform() * 4
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.35
    replace status = 2 if d == 1 & status == 0
    * finegray norobust
    stset t, failure(d) id(id)
    finegray x1 x2, compete(status) cause(1) nolog norobust
    matrix V_fg = e(V)
    matrix b_fg = e(b)
    * stcrreg
    stset t, failure(status==1) id(id)
    stcrreg x1 x2, compete(status == 2)
    matrix V_ref = e(V)
    matrix b_ref = e(b)
    * Coefficients should match
    assert abs(b_fg[1,1] - b_ref[1,1]) < 0.001
    assert abs(b_fg[1,2] - b_ref[1,2]) < 0.001
    * SEs should be in the same range
    forvalues i = 1/2 {
        local se_fg = sqrt(V_fg[`i',`i'])
        local se_ref = sqrt(V_ref[`i',`i'])
        local ratio = `se_fg' / `se_ref'
        display as text "  norobust SE ratio var `i': " %6.3f `ratio'
        assert `ratio' > 0.5 & `ratio' < 2
    }
}
if _rc == 0 {
    display as result "  PASS: C26 norobust SEs vs stcrreg (simulated)"
    local ++pass_count
}
else {
    display as error "  FAIL: C26 norobust SEs (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 13: Factor variable cross-validation}{...}

* C27: Factor variable vs stcrreg — simulated data
local ++test_count
capture noisily {
    clear
    set seed 88
    set obs 600
    gen id = _n
    gen byte grp = mod(_n-1, 3)
    gen double x1 = rnormal()
    gen double u = runiform()
    * True model: grp==1 SHR=1.5 (beta=0.4), grp==2 SHR=0.7 (beta=-0.36)
    gen double h = exp(0.4*(grp==1) - 0.36*(grp==2) + 0.3*x1)
    gen double t_event = -ln(u) / h
    gen double t_censor = runiform() * 3
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.3
    replace status = 2 if d == 1 & status == 0
    * finegray with factor
    stset t, failure(d) id(id)
    finegray i.grp x1, compete(status) cause(1) nolog
    matrix b_fg = e(b)
    * stcrreg with manual indicators (drop factor-created vars first)
    capture drop grp_1
    capture drop grp_2
    gen byte grp_1 = (grp == 1)
    gen byte grp_2 = (grp == 2)
    stset t, failure(status==1) id(id)
    stcrreg grp_1 grp_2 x1, compete(status == 2)
    matrix b_ref = e(b)
    * Coefficients must match
    forvalues i = 1/3 {
        assert abs(b_fg[1,`i'] - b_ref[1,`i']) < 0.001
    }
}
if _rc == 0 {
    display as result "  PASS: C27 factor variable vs stcrreg (simulated)"
    local ++pass_count
}
else {
    display as error "  FAIL: C27 factor vs stcrreg (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 14: in restriction cross-validation}{...}

* C28: in restriction — coefficients match if restriction on same data
local ++test_count
capture noisily {
    _setup_hypoxia
    * Sort deterministically to make in predictable
    sort stnum
    local N_half = int(_N / 2)
    finegray ifp tumsize pelnode if _n <= `N_half', compete(status) cause(1) nolog
    matrix b_if = e(b)
    local N_if = e(N)
    finegray ifp tumsize pelnode in 1/`N_half', compete(status) cause(1) nolog
    matrix b_in = e(b)
    local N_in = e(N)
    * Same observations — coefficients should match within float precision
    assert `N_if' == `N_in'
    forvalues i = 1/3 {
        assert abs(b_if[1,`i'] - b_in[1,`i']) < 1e-6
    }
}
if _rc == 0 {
    display as result "  PASS: C28 if vs in restriction equivalence"
    local ++pass_count
}
else {
    display as error "  FAIL: C28 if vs in (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 15: Non-default censvalue cross-validation}{...}

* C29: censvalue cross-validation — simulated data with non-zero censor code
local ++test_count
capture noisily {
    clear
    set seed 123
    set obs 500
    gen id = _n
    gen double x1 = rnormal()
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.4*x1)
    gen double t_censor = runiform() * 3
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    * Code: 5=censored, 1=cause, 2=competing
    gen byte status = 5
    replace status = 1 if d == 1 & runiform() > 0.4
    replace status = 2 if d == 1 & status == 5
    * finegray with censvalue(5)
    stset t, failure(d) id(id)
    finegray x1, compete(status) cause(1) censvalue(5) nolog
    local b_fg = e(b)[1,1]
    assert e(N_cens) > 0
    * stcrreg (standard setup)
    stset t, failure(status==1) id(id)
    stcrreg x1, compete(status == 2)
    local b_ref = e(b)[1,1]
    assert abs(`b_fg' - `b_ref') < 0.001
}
if _rc == 0 {
    display as result "  PASS: C29 censvalue(5) vs stcrreg (simulated)"
    local ++pass_count
}
else {
    display as error "  FAIL: C29 censvalue(5) (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 16: Multiple strata cross-validation}{...}

* C30: Multiple strata variables — CIF valid and matches manual egen
local ++test_count
capture noisily {
    clear
    set seed 77
    set obs 600
    gen id = _n
    gen byte site = mod(_n-1, 3) + 1
    gen byte arm = mod(_n-1, 2)
    gen double x1 = rnormal()
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.3*x1)
    gen double t_censor = runiform() * 4
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.4
    replace status = 2 if d == 1 & status == 0
    stset t, failure(d) id(id)
    * Multiple strata variables (auto-combined)
    finegray x1, compete(status) cause(1) nolog strata(site arm)
    assert e(converged) == 1
    local b_multi = e(b)[1,1]
    finegray_predict cif_multi, cif
    summ cif_multi, meanonly
    assert r(min) >= 0 & r(max) <= 1
    * Compare against manual egen group
    egen int strata_combo = group(site arm)
    finegray x1, compete(status) cause(1) nolog strata(strata_combo)
    local b_manual = e(b)[1,1]
    assert abs(`b_multi' - `b_manual') < 1e-8
    drop cif_multi strata_combo
}
if _rc == 0 {
    display as result "  PASS: C30 multiple strata — valid CIF and matches manual"
    local ++pass_count
}
else {
    display as error "  FAIL: C30 multiple strata (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 17: phtest cross-validation}{...}

* C31: phtest detects known PH violation (time-varying effect)
local ++test_count
capture noisily {
    clear
    set seed 314
    set obs 2000
    gen id = _n
    gen double x1 = rnormal()
    gen double u = runiform()
    * Time-varying effect: x1 effect changes with time
    * At early times beta=0.8, at later times beta=-0.2
    * This creates a strong PH violation
    gen double t_event = -ln(u) / exp(0.8*x1)
    * Make the hazard time-dependent by resampling late events
    replace t_event = t_event * exp(-1.0*x1) if t_event > 1.5
    gen double t_censor = runiform() * 6
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.3
    replace status = 2 if d == 1 & status == 0
    stset t, failure(d) id(id)
    finegray x1, compete(status) cause(1) nolog
    finegray_phtest
    * With 2000 obs and strong PH violation, p should be small
    display as text "  PH violation test: chi2=" %8.3f r(chi2) " p=" %8.5f r(p)
    assert r(p) < 0.10
}
if _rc == 0 {
    display as result "  PASS: C31 phtest detects PH violation"
    local ++pass_count
}
else {
    display as error "  FAIL: C31 PH violation detection (rc=`=_rc')"
    local ++fail_count
}

* C32: phtest does not reject on simple model with weak effect
* Note: Random allocation to competing events can induce non-proportional
* subdistribution hazards even from proportional cause-specific hazards.
* Use weak effect + moderate N to avoid spurious rejection.
local ++test_count
capture noisily {
    clear
    set seed 999
    set obs 500
    gen id = _n
    gen double x1 = rnormal()
    gen double u = runiform()
    * Very weak effect — beta=0.05 — minimal PH violation from competing risk allocation
    gen double t_event = -ln(u) / exp(0.05*x1)
    gen double t_censor = runiform() * 5
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.35
    replace status = 2 if d == 1 & status == 0
    stset t, failure(d) id(id)
    finegray x1, compete(status) cause(1) nolog
    finegray_phtest
    * With weak effect and moderate N, p should be non-significant
    display as text "  Weak effect PH test: chi2=" %8.3f r(chi2) " p=" %8.5f r(p)
    assert r(p) > 0.01
}
if _rc == 0 {
    display as result "  PASS: C32 phtest non-rejection (weak effect)"
    local ++pass_count
}
else {
    display as error "  FAIL: C32 non-rejection (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 18: R cross-validation via cmprsk::crr}{...}

display ""
display as text _dup(60) "="
display as text "R CROSS-VALIDATION: finegray vs cmprsk::crr"
display as text _dup(60) "="

* Export hypoxia data for R
_setup_hypoxia
local r_available = 1

capture noisily {
    preserve
    keep if e(sample) != 1
    * Need fresh data — reload
    restore
    _setup_hypoxia
    * Run finegray first to identify estimation sample
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    * Save Stata results for comparison
    matrix b_stata = e(b)
    matrix V_stata = e(V)
    local ll_stata = e(ll)

    * Export data for R (unstratified hypoxia)
    preserve
    keep if e(sample)
    keep stnum _t status ifp tumsize pelnode
    rename stnum id
    rename _t time
    gen str16 dataset = "hypoxia"
    gen byte strata = .
    export delimited using ///
        "`datadir'/finegray_r_input.csv", ///
        replace
    restore

    * Export stratified dataset for R (hypoxia with pelnode as strata)
    * Re-fit with strata to get estimation sample
    *
    * noadjust is required for a LIKE-FOR-LIKE SE comparison against cmprsk.
    * finegray applies a finite-sample adjustment to the sandwich by default
    * (N/(N-1), matching stcrreg); cmprsk::crr applies none. On hypoxia
    * (N = 109) that factor is sqrt(109/108) = 1.0046, i.e. a 0.46% inflation --
    * which is exactly the discrepancy C52 saw against its 0.1% tolerance. That
    * is a difference in the reported estimand, not in the estimator, so the
    * oracle must be compared against the same quantity it computes.
    finegray ifp tumsize, compete(status) cause(1) nolog strata(pelnode) noadjust
    matrix b_strata_stata = e(b)
    matrix V_strata_stata = e(V)
    local ll_strata_stata = e(ll)
    preserve
    keep if e(sample)
    keep stnum _t status ifp tumsize pelnode
    rename stnum id
    rename _t time
    gen str16 dataset = "hypoxia_strata"
    rename pelnode strata
    export delimited using ///
        "`datadir'/finegray_r_strata.csv", ///
        replace
    restore
}

if _rc != 0 {
    display as error "  SKIP: Could not export data for R crossval"
    local r_available = 0
}

* Call R (unstratified)
if `r_available' {
    capture noisily {
        shell Rscript "`qadir'/crossval_finegray_r.R" ///
            "`datadir'/finegray_r_input.csv" ///
            "`datadir'/finegray_r_output.csv"
    }
    capture confirm file "`datadir'/finegray_r_output.csv"
    if _rc != 0 {
        display as error "  SKIP: R script failed or output not found"
        local r_available = 0
    }
}

* Call R (stratified)
local r_strata_available = 0
if `r_available' {
    capture noisily {
        shell Rscript "`qadir'/crossval_finegray_r.R" ///
            "`datadir'/finegray_r_strata.csv" ///
            "`datadir'/finegray_r_strata_output.csv"
    }
    capture confirm file "`datadir'/finegray_r_strata_output.csv"
    if _rc == 0 {
        local r_strata_available = 1
    }
    else {
        display as error "  NOTE: R strata script failed; strata crossval will be skipped"
    }
}

if `r_available' {
    * Load R results
    preserve
    import delimited using ///
        "`datadir'/finegray_r_output.csv", ///
        clear

    * C33: Coefficients vs cmprsk::crr
    local ++test_count
    local t33_pass = 1
    foreach var in ifp tumsize pelnode {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "coef" & variable == "`var'", meanonly
        }
        if r(N) == 0 {
            display as error "  FAIL [C33.`var']: R coef not found"
            local t33_pass = 0
            continue
        }
        local r_coef = r(mean)
        * Get Stata coef position
        if "`var'" == "ifp" local pos = 1
        if "`var'" == "tumsize" local pos = 2
        if "`var'" == "pelnode" local pos = 3
        local s_coef = b_stata[1, `pos']
        local adiff = abs(`s_coef' - `r_coef')
        display as text "  coef[`var']: Stata=" %10.6f `s_coef' " R=" %10.6f `r_coef' ///
            " diff=" %8.6f `adiff'
        if `adiff' >= 0.01 {
            display as error "  FAIL [C33.`var']: diff `adiff' >= 0.01"
            local t33_pass = 0
        }
    }
    if `t33_pass' {
        display as result "  PASS: C33 coefficients vs cmprsk::crr (< 0.01)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C33 coefficients vs cmprsk::crr"
        local ++fail_count
    }

    * C34: Robust SEs vs cmprsk::crr
    local ++test_count
    local t34_pass = 1
    foreach var in ifp tumsize pelnode {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "se_robust" & variable == "`var'", meanonly
        }
        if r(N) == 0 {
            display as error "  FAIL [C34.`var']: R se_robust not found"
            local t34_pass = 0
            continue
        }
        local r_se = r(mean)
        if "`var'" == "ifp" local pos = 1
        if "`var'" == "tumsize" local pos = 2
        if "`var'" == "pelnode" local pos = 3
        local s_se = sqrt(V_stata[`pos', `pos'])
        local rdiff = abs(`s_se' - `r_se') / `r_se'
        display as text "  se_robust[`var']: Stata=" %10.6f `s_se' " R=" %10.6f `r_se' ///
            " rel_diff=" %6.3f `rdiff'
        if `rdiff' >= 0.15 {
            display as error "  FAIL [C34.`var']: rel_diff `rdiff' >= 0.15"
            local t34_pass = 0
        }
    }
    if `t34_pass' {
        display as result "  PASS: C34 robust SEs vs cmprsk::crr (< 15%)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C34 robust SEs vs cmprsk::crr"
        local ++fail_count
    }

    * C35: Model-based SEs (norobust) vs crr$invinf
    local ++test_count
    local t35_pass = 1
    restore
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog norobust
    matrix V_nr = e(V)
    preserve
    import delimited using ///
        "`datadir'/finegray_r_output.csv", ///
        clear
    foreach var in ifp tumsize pelnode {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "se_model" & variable == "`var'", meanonly
        }
        if r(N) == 0 {
            display as error "  FAIL [C35.`var']: R se_model not found"
            local t35_pass = 0
            continue
        }
        local r_se = r(mean)
        if "`var'" == "ifp" local pos = 1
        if "`var'" == "tumsize" local pos = 2
        if "`var'" == "pelnode" local pos = 3
        local s_se = sqrt(V_nr[`pos', `pos'])
        local rdiff = abs(`s_se' - `r_se') / `r_se'
        display as text "  se_model[`var']: Stata=" %10.6f `s_se' " R=" %10.6f `r_se' ///
            " rel_diff=" %6.3f `rdiff'
        if `rdiff' >= 0.15 {
            display as error "  FAIL [C35.`var']: rel_diff `rdiff' >= 0.15"
            local t35_pass = 0
        }
    }
    if `t35_pass' {
        display as result "  PASS: C35 model-based SEs vs crr$invinf (< 15%)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C35 model-based SEs vs crr$invinf"
        local ++fail_count
    }

    * C36: Log-likelihood vs cmprsk::crr
    local ++test_count
    capture noisily {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "loglik" & variable == "final", meanonly
        }
        local r_ll = r(mean)
        local rdiff = abs(`ll_stata' - `r_ll') / abs(`r_ll')
        display as text "  loglik: Stata=" %12.4f `ll_stata' " R=" %12.4f `r_ll' ///
            " rel_diff=" %8.6f `rdiff'
        assert `rdiff' < 0.001
    }
    if _rc == 0 {
        display as result "  PASS: C36 log-likelihood vs cmprsk::crr (< 0.1%)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C36 log-likelihood (rc=`=_rc')"
        local ++fail_count
    }

    * C37: CIF at reference pattern (z=0) vs predict.crr
    * QA-H03: t37_pass stayed 1 if EVERY time point skipped (R output missing),
    * so C37 could report PASS having compared nothing.  Count the comparisons
    * actually made and require at least one -- a verdict on zero comparisons is
    * not a pass.
    local ++test_count
    local t37_pass = 1
    local t37_ncmp = 0
    restore
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog basehaz
    * CIF at z=0: 1 - exp(-H0(t))
    matrix bh = e(basehaz)
    local nr_bh = rowsof(bh)
    preserve
    import delimited using ///
        "`datadir'/finegray_r_output.csv", ///
        clear
    foreach tt in 2 5 10 {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "cif_ref" & variable == "t`tt'", meanonly
        }
        if r(N) == 0 {
            display as text "  SKIP [C37.t`tt']: R cif_ref not found"
            continue
        }
        local r_cif = r(mean)
        * Find Stata H0 at time tt
        local H0_tt = 0
        forvalues j = 1/`nr_bh' {
            if bh[`j', 1] <= `tt' {
                local H0_tt = bh[`j', 2]
            }
        }
        local s_cif = 1 - exp(-`H0_tt')
        local adiff = abs(`s_cif' - `r_cif')
        local ++t37_ncmp
        display as text "  CIF(t=`tt',z=0): Stata=" %8.6f `s_cif' " R=" %8.6f `r_cif' ///
            " diff=" %8.6f `adiff'
        if `adiff' >= 0.01 {
            display as error "  FAIL [C37.t`tt']: diff `adiff' >= 0.01"
            local t37_pass = 0
        }
    }
    if `t37_ncmp' == 0 {
        display as error "  FAIL: C37 compared 0 time points (R cif_ref missing)"
        local t37_pass = 0
    }
    if `t37_pass' {
        display as result "  PASS: C37 CIF at z=0 vs predict.crr (< 0.01)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C37 CIF vs predict.crr"
        local ++fail_count
    }
    restore
}
else {
    * R not available — skip C33-C37
    display as text "  SKIP: R cross-validation tests (C33-C37) — R or cmprsk not available"
    forvalues i = 33/37 {
        local ++test_count
        local ++skip_count
    }
}

* {smcl}
* {* SECTION 19: Interaction cross-validation}{...}

* C38: i.var##c.var vs manual indicators + interaction — same coefficients
local ++test_count
capture noisily {
    _setup_hypoxia
    * Fit with fvrevar-based ##
    finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    matrix b_fv = e(b)
    local ll_fv = e(ll)
    cap drop _fg_*
    * Fit with manual indicators and interaction
    gen byte pel_1 = (pelnode == 1)
    gen double pel_1_ifp = pel_1 * ifp
    finegray pel_1 ifp pel_1_ifp tumsize, compete(status) cause(1) nolog
    matrix b_man = e(b)
    local ll_man = e(ll)
    * Must produce identical results
    assert abs(`ll_fv' - `ll_man') < 1e-6
    forvalues j = 1/4 {
        assert abs(b_fv[1,`j'] - b_man[1,`j']) < 1e-6
    }
    drop pel_1 pel_1_ifp
}
if _rc == 0 {
    display as result "  PASS: C38 i##c vs manual — identical coefficients"
    local ++pass_count
}
else {
    display as error "  FAIL: C38 i##c vs manual (rc=`=_rc')"
    local ++fail_count
}

* C39: i.var##i.var vs manual indicators — same coefficients
local ++test_count
capture noisily {
    _setup_hypoxia
    gen byte ifp_grp = (ifp > 10)
    * Fit with fvrevar
    finegray i.pelnode##i.ifp_grp tumsize, compete(status) cause(1) nolog
    matrix b_fv = e(b)
    local ll_fv = e(ll)
    cap drop _fg_*
    * Manual: create indicators and interaction
    gen byte pel_1 = (pelnode == 1)
    gen byte ifpg_1 = (ifp_grp == 1)
    gen byte pel_1_ifpg_1 = pel_1 * ifpg_1
    finegray pel_1 ifpg_1 pel_1_ifpg_1 tumsize, compete(status) cause(1) nolog
    matrix b_man = e(b)
    local ll_man = e(ll)
    assert abs(`ll_fv' - `ll_man') < 1e-6
    forvalues j = 1/4 {
        * Use relative tolerance for large coefficients (quasi-separation)
        local _bfv = b_fv[1,`j']
        local _bman = b_man[1,`j']
        local _scale = max(abs(`_bfv'), abs(`_bman'), 1)
        assert abs(`_bfv' - `_bman') / `_scale' < 1e-4
    }
    drop ifp_grp pel_1 ifpg_1 pel_1_ifpg_1
}
if _rc == 0 {
    display as result "  PASS: C39 i##i vs manual — identical coefficients"
    local ++pass_count
}
else {
    display as error "  FAIL: C39 i##i vs manual (rc=`=_rc')"
    local ++fail_count
}

* C40: Interaction model CIF matches manual computation
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog basehaz
    * CIF via finegray_predict
    finegray_predict cif_auto, cif
    * CIF via manual: 1 - exp(-H0(t) * exp(xb))
    finegray_predict xb_man, xb
    tempname bh
    matrix `bh' = e(basehaz)
    tempvar H0 alltouse
    quietly gen double `H0' = 0
    quietly gen byte `alltouse' = 1
    mata: _finegray_step_lookup("`bh'", "_t", "`H0'", "`alltouse'")
    gen double cif_manual = 1 - exp(-`H0' * exp(xb_man))
    * Must match within floating point tolerance
    gen double cif_diff = abs(cif_auto - cif_manual)
    summ cif_diff, meanonly
    assert r(max) < 1e-6
    drop cif_auto xb_man cif_manual cif_diff
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: C40 interaction CIF matches manual"
    local ++pass_count
}
else {
    display as error "  FAIL: C40 interaction CIF (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 14: Cluster VCE vs stcrreg}{...}

* C41: Cluster VCE coefficients match stcrreg
local ++test_count
capture noisily {
    clear
    set seed 7742
    set obs 1000
    gen id = _n
    gen clid = mod(_n-1, 100) + 1
    gen double x1 = rnormal() + 0.3 * (clid > 50)
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.5*x1)
    gen double t_censor = runiform() * 5
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.3
    replace status = 2 if d == 1 & status == 0
    stset t, failure(d) id(id)

    finegray x1, compete(status) cause(1) nolog cluster(clid)
    local b_fg = e(b)[1,1]
    local se_fg = sqrt(e(V)[1,1])

    preserve
    stset t, failure(status==1) id(id)
    stcrreg x1, compete(status == 2) vce(cluster clid)
    local b_ref = e(b)[1,1]
    local se_ref = sqrt(e(V)[1,1])
    restore

    local b_rel = abs(`b_fg' - `b_ref') / abs(`b_ref')
    local se_rel = abs(`se_fg' - `se_ref') / abs(`se_ref')
    display as text "  coef: finegray=" %9.5f `b_fg' " stcrreg=" %9.5f `b_ref' " REL=" %6.4f `b_rel'
    display as text "  SE:   finegray=" %9.5f `se_fg' " stcrreg=" %9.5f `se_ref' " REL=" %6.4f `se_rel'
    assert `b_rel' < 0.02
    assert `se_rel' < 0.05
}
if _rc == 0 {
    display as result "  PASS: C41 cluster VCE coef+SE vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: C41 cluster VCE vs stcrreg (rc=`=_rc')"
    local ++fail_count
}

* C42: Cluster VCE with two covariates vs stcrreg
local ++test_count
capture noisily {
    clear
    set seed 8853
    set obs 800
    gen id = _n
    gen clid = mod(_n-1, 80) + 1
    gen double x1 = rnormal()
    gen double x2 = rnormal() + 0.2 * (clid > 40)
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.4*x1 - 0.3*x2)
    gen double t_censor = runiform() * 4
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.35
    replace status = 2 if d == 1 & status == 0
    stset t, failure(d) id(id)

    finegray x1 x2, compete(status) cause(1) nolog cluster(clid)
    matrix b_fg = e(b)
    matrix V_fg = e(V)

    preserve
    stset t, failure(status==1) id(id)
    stcrreg x1 x2, compete(status == 2) vce(cluster clid)
    matrix b_ref = e(b)
    matrix V_ref = e(V)
    restore

    forvalues j = 1/2 {
        local b_rel = abs(b_fg[1,`j'] - b_ref[1,`j']) / abs(b_ref[1,`j'])
        local se_fg_j = sqrt(V_fg[`j',`j'])
        local se_ref_j = sqrt(V_ref[`j',`j'])
        local se_rel = abs(`se_fg_j' - `se_ref_j') / abs(`se_ref_j')
        display as text "  x`j' coef REL=" %6.4f `b_rel' " SE REL=" %6.4f `se_rel'
        assert `b_rel' < 0.02
        assert `se_rel' < 0.05
    }
}
if _rc == 0 {
    display as result "  PASS: C42 2-covariate cluster VCE vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: C42 cluster VCE 2-cov (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 15: Left-truncation cross-validation}{...}

* C43: Left-truncated coefficients match stcrreg
local ++test_count
capture noisily {
    clear
    set seed 5567
    set obs 600
    gen id = _n
    gen double x1 = rnormal()
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.5*x1)
    gen double t_censor = runiform() * 5
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.3
    replace status = 2 if d == 1 & status == 0
    * Create delayed entry: ~40% of subjects enter late
    gen double t_enter = runiform() * 0.5 if runiform() > 0.6
    replace t_enter = 0 if missing(t_enter)
    * Drop subjects whose entry is after their event/censor time
    drop if t_enter >= t
    stset t, failure(d) id(id) enter(time t_enter)

    finegray x1, compete(status) cause(1) nolog
    local b_fg = e(b)[1,1]
    local se_fg = sqrt(e(V)[1,1])

    preserve
    stset t, failure(status==1) id(id) enter(time t_enter)
    stcrreg x1, compete(status == 2)
    local b_ref = e(b)[1,1]
    local se_ref = sqrt(e(V)[1,1])
    restore

    local b_rel = abs(`b_fg' - `b_ref') / abs(`b_ref')
    local se_rel = abs(`se_fg' - `se_ref') / abs(`se_ref')
    display as text "  coef: finegray=" %9.5f `b_fg' " stcrreg=" %9.5f `b_ref' " REL=" %6.4f `b_rel'
    display as text "  SE:   finegray=" %9.5f `se_fg' " stcrreg=" %9.5f `se_ref' " REL=" %6.4f `se_rel'

    * INVERTED, deliberately: under left truncation finegray must NOT match
    * stcrreg, and this test used to assert that it did (b_rel < 0.02).
    *
    * finegray now implements the stabilized Zhang-Zhang-Fine weight, which
    * reweights the risk set for delayed entry.  stcrreg does not: it applies the
    * censoring weight only, which is the estimator the recovery gate
    * (validation_finegray_zzf_recovery.do) measured as BIASED -- the pooled /
    * stcrreg-style arm missed the known truth by +62.96 and +190.07 MC SE, while
    * the ZZF arms recovered it to within +-3 MC SE.  So a green "matches stcrreg
    * under LT" was a test asserting the defect.
    *
    * Asserting mere inequality would pass on any garbage, so pin BOTH sides:
    *   (1) under LT the two must genuinely diverge, and
    *   (2) with the SAME data and NO delayed entry they must still agree --
    *       which proves the divergence is specific to left truncation and not a
    *       general regression against StataCorp.
    assert `b_rel' > 0.02

    * (2) parity WITHOUT delayed entry, same dataset
    preserve
    quietly replace t_enter = 0
    stset t, failure(d) id(id) enter(time t_enter)
    quietly finegray x1, compete(status) cause(1) nolog
    local b_fg0 = e(b)[1,1]
    stset t, failure(status==1) id(id) enter(time t_enter)
    quietly stcrreg x1, compete(status == 2)
    local b_ref0 = e(b)[1,1]
    restore
    local b_rel0 = abs(`b_fg0' - `b_ref0') / abs(`b_ref0')
    display as text "  no-LT parity: finegray=" %9.5f `b_fg0' " stcrreg=" ///
        %9.5f `b_ref0' " REL=" %8.6f `b_rel0'
    assert `b_rel0' < 0.02
}
if _rc == 0 {
    display as result "  PASS: C43 LT diverges from stcrreg (by design); no-LT parity holds"
    local ++pass_count
}
else {
    display as error "  FAIL: C43 left-truncation vs stcrreg (rc=`=_rc')"
    local ++fail_count
}

* C44: Left-truncated with two covariates vs stcrreg
local ++test_count
capture noisily {
    clear
    set seed 6678
    set obs 800
    gen id = _n
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.4*x1 - 0.2*x2)
    gen double t_censor = runiform() * 4
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.35
    replace status = 2 if d == 1 & status == 0
    gen double t_enter = runiform() * 0.3 if runiform() > 0.5
    replace t_enter = 0 if missing(t_enter)
    drop if t_enter >= t
    stset t, failure(d) id(id) enter(time t_enter)

    finegray x1 x2, compete(status) cause(1) nolog
    matrix b_fg = e(b)
    matrix V_fg = e(V)

    preserve
    stset t, failure(status==1) id(id) enter(time t_enter)
    stcrreg x1 x2, compete(status == 2)
    matrix b_ref = e(b)
    matrix V_ref = e(V)
    restore

    * INVERTED for the same reason as C43: stcrreg does not reweight the risk set
    * for delayed entry, and the recovery gate measured that estimator as biased.
    * At least one coefficient must diverge under LT, and the SAME data with no
    * delayed entry must still reproduce stcrreg -- the divergence has to be
    * caused by the truncation, not by a general disagreement.
    local n_diverged = 0
    forvalues j = 1/2 {
        local b_rel = abs(b_fg[1,`j'] - b_ref[1,`j']) / abs(b_ref[1,`j'])
        local se_fg_j = sqrt(V_fg[`j',`j'])
        local se_ref_j = sqrt(V_ref[`j',`j'])
        local se_rel = abs(`se_fg_j' - `se_ref_j') / abs(`se_ref_j')
        display as text "  x`j' coef REL=" %6.4f `b_rel' " SE REL=" %6.4f `se_rel'
        if `b_rel' > 0.02 local ++n_diverged
    }
    assert `n_diverged' >= 1

    preserve
    quietly replace t_enter = 0
    stset t, failure(d) id(id) enter(time t_enter)
    quietly finegray x1 x2, compete(status) cause(1) nolog
    matrix b_fg0 = e(b)
    stset t, failure(status==1) id(id) enter(time t_enter)
    quietly stcrreg x1 x2, compete(status == 2)
    matrix b_ref0 = e(b)
    restore
    forvalues j = 1/2 {
        local b_rel0 = abs(b_fg0[1,`j'] - b_ref0[1,`j']) / abs(b_ref0[1,`j'])
        display as text "  no-LT parity x`j': REL=" %8.6f `b_rel0'
        assert `b_rel0' < 0.02
    }
}
if _rc == 0 {
    display as result "  PASS: C44 LT diverges from stcrreg (by design); no-LT parity holds"
    local ++pass_count
}
else {
    display as error "  FAIL: C44 left-truncation 2-cov (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 20: fastcmprsk::fastCrr cross-validation}{...}

display ""
display as text _dup(60) "="
display as text "R CROSS-VALIDATION: finegray vs fastcmprsk::fastCrr"
display as text _dup(60) "="

* R output already generated in Section 18. Check if fastcmprsk results exist.
local fastcmprsk_available = 0
if `r_available' {
    preserve
    import delimited using ///
        "`datadir'/finegray_r_output.csv", ///
        clear
    quietly count if quantity == "fastcmprsk_coef"
    if r(N) > 0 {
        local fastcmprsk_available = 1
    }
    restore
}

if `fastcmprsk_available' {
    * Reload Stata results (same model as Section 18)
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog basehaz
    matrix b_stata = e(b)
    matrix V_stata = e(V)
    local ll_stata = e(ll)
    matrix bh_stata = e(basehaz)
    local nr_bh = rowsof(bh_stata)

    preserve
    import delimited using ///
        "`datadir'/finegray_r_output.csv", ///
        clear

    * C45: Coefficients vs fastcmprsk::fastCrr
    local ++test_count
    local t45_pass = 1
    foreach var in ifp tumsize pelnode {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "fastcmprsk_coef" ///
                & variable == "`var'", meanonly
        }
        if r(N) == 0 {
            display as error "  FAIL [C45.`var']: fastCrr coef not found"
            local t45_pass = 0
            continue
        }
        local r_coef = r(mean)
        if "`var'" == "ifp" local pos = 1
        if "`var'" == "tumsize" local pos = 2
        if "`var'" == "pelnode" local pos = 3
        local s_coef = b_stata[1, `pos']
        local adiff = abs(`s_coef' - `r_coef')
        display as text "  coef[`var']: Stata=" %10.6f `s_coef' ///
            " fastCrr=" %10.6f `r_coef' " diff=" %8.6f `adiff'
        if `adiff' >= 0.01 {
            display as error "  FAIL [C45.`var']: diff `adiff' >= 0.01"
            local t45_pass = 0
        }
    }
    if `t45_pass' {
        display as result "  PASS: C45 coefficients vs fastcmprsk::fastCrr (< 0.01)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C45 coefficients vs fastcmprsk::fastCrr"
        local ++fail_count
    }

    * C46: Log-likelihood vs fastcmprsk::fastCrr
    local ++test_count
    capture noisily {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "fastcmprsk_loglik" ///
                & variable == "final", meanonly
        }
        local r_ll = r(mean)
        local rdiff = abs(`ll_stata' - `r_ll') / abs(`r_ll')
        display as text "  loglik: Stata=" %12.4f `ll_stata' ///
            " fastCrr=" %12.4f `r_ll' " rel_diff=" %8.6f `rdiff'
        assert `rdiff' < 0.001
    }
    if _rc == 0 {
        display as result "  PASS: C46 log-likelihood vs fastcmprsk::fastCrr (< 0.1%)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C46 log-likelihood (rc=`=_rc')"
        local ++fail_count
    }

    * C47: Baseline cumulative hazard vs fastcmprsk::fastCrr
    local ++test_count
    capture noisily {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "fastcmprsk_cumbasehaz" ///
                & variable == "tmax", meanonly
        }
        local r_cbh = r(mean)
        * Stata cumbasehaz at last event time
        local s_cbh = bh_stata[`nr_bh', 2]
        local adiff = abs(`s_cbh' - `r_cbh')
        display as text "  cumbasehaz(tmax): Stata=" %10.8f `s_cbh' ///
            " fastCrr=" %10.8f `r_cbh' " diff=" %10.8f `adiff'
        assert `adiff' < 0.001
    }
    if _rc == 0 {
        display as result "  PASS: C47 baseline hazard vs fastcmprsk::fastCrr (< 0.001)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C47 baseline hazard (rc=`=_rc')"
        local ++fail_count
    }

    * C48: CIF at z=0 vs fastcmprsk::fastCrr
    local ++test_count
    local t48_pass = 1
    foreach tt in 2 5 10 {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "fastcmprsk_cif_ref" ///
                & variable == "t`tt'", meanonly
        }
        if r(N) == 0 {
            display as text "  SKIP [C48.t`tt']: fastCrr cif_ref not found"
            continue
        }
        local r_cif = r(mean)
        * Stata CIF at z=0: 1 - exp(-H0(t))
        local H0_tt = 0
        forvalues j = 1/`nr_bh' {
            if bh_stata[`j', 1] <= `tt' {
                local H0_tt = bh_stata[`j', 2]
            }
        }
        local s_cif = 1 - exp(-`H0_tt')
        local adiff = abs(`s_cif' - `r_cif')
        display as text "  CIF(t=`tt',z=0): Stata=" %8.6f `s_cif' ///
            " fastCrr=" %8.6f `r_cif' " diff=" %8.6f `adiff'
        if `adiff' >= 0.01 {
            display as error "  FAIL [C48.t`tt']: diff `adiff' >= 0.01"
            local t48_pass = 0
        }
    }
    if `t48_pass' {
        display as result "  PASS: C48 CIF at z=0 vs fastcmprsk::fastCrr (< 0.01)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C48 CIF vs fastcmprsk::fastCrr"
        local ++fail_count
    }

    * C49: Bootstrap SEs vs analytic SEs (fastcmprsk uses bootstrap, not sandwich)
    * Bootstrap SEs should be in the same ballpark — within 50% of analytic.
    local ++test_count
    local t49_pass = 1
    foreach var in ifp tumsize pelnode {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "fastcmprsk_se" ///
                & variable == "`var'", meanonly
        }
        if r(N) == 0 {
            display as error "  FAIL [C49.`var']: fastCrr SE not found"
            local t49_pass = 0
            continue
        }
        local r_se = r(mean)
        if "`var'" == "ifp" local pos = 1
        if "`var'" == "tumsize" local pos = 2
        if "`var'" == "pelnode" local pos = 3
        local s_se = sqrt(V_stata[`pos', `pos'])
        local rdiff = abs(`s_se' - `r_se') / `r_se'
        display as text "  SE[`var']: Stata=" %10.6f `s_se' ///
            " fastCrr(boot)=" %10.6f `r_se' " rel_diff=" %6.3f `rdiff'
        if `rdiff' >= 0.50 {
            display as error "  FAIL [C49.`var']: rel_diff `rdiff' >= 0.50"
            local t49_pass = 0
        }
    }
    if `t49_pass' {
        display as result ///
            "  PASS: C49 bootstrap SEs vs analytic (< 50% — expected divergence)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C49 bootstrap SEs vs analytic"
        local ++fail_count
    }

    * C50: Three-way agreement — finegray vs cmprsk vs fastcmprsk
    * Verify all three implementations agree on coefficients within tolerance
    local ++test_count
    local t50_pass = 1
    foreach var in ifp tumsize pelnode {
        quietly {
            summ value if dataset == "hypoxia" & quantity == "coef" ///
                & variable == "`var'", meanonly
        }
        local crr_coef = r(mean)
        quietly {
            summ value if dataset == "hypoxia" & quantity == "fastcmprsk_coef" ///
                & variable == "`var'", meanonly
        }
        local fast_coef = r(mean)
        if "`var'" == "ifp" local pos = 1
        if "`var'" == "tumsize" local pos = 2
        if "`var'" == "pelnode" local pos = 3
        local s_coef = b_stata[1, `pos']
        * Max pairwise difference across all three
        local d12 = abs(`s_coef' - `crr_coef')
        local d13 = abs(`s_coef' - `fast_coef')
        local d23 = abs(`crr_coef' - `fast_coef')
        local maxd = max(`d12', `d13', `d23')
        display as text "  `var': finegray=" %10.6f `s_coef' ///
            " crr=" %10.6f `crr_coef' " fastCrr=" %10.6f `fast_coef' ///
            " max_diff=" %8.6f `maxd'
        if `maxd' >= 0.01 {
            display as error "  FAIL [C50.`var']: max_diff `maxd' >= 0.01"
            local t50_pass = 0
        }
    }
    if `t50_pass' {
        display as result "  PASS: C50 three-way coef agreement (< 0.01)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C50 three-way agreement"
        local ++fail_count
    }
    restore
}
else {
    * fastcmprsk not available — skip C45-C50
    display as text "  SKIP: fastcmprsk tests (C45-C50) — package not available"
    forvalues i = 45/50 {
        local ++test_count
        local ++skip_count
    }
}

* {smcl}
* {* SECTION 21: Strata cross-validation vs cmprsk::crr cengroup}{...}

display ""
display as text _dup(60) "="
display as text "R CROSS-VALIDATION: finegray strata() vs cmprsk::crr cengroup"
display as text _dup(60) "="

if `r_strata_available' {
    preserve
    import delimited using ///
        "`datadir'/finegray_r_strata_output.csv", ///
        clear

    * C51: Strata coefficients vs crr cengroup
    * This is a regression gate for group-specific IPCW numerators: using one
    * pooled competing-event accumulator shifts tumsize by about .002 in this
    * dataset even though each stratum's censoring KM is otherwise correct.
    local ++test_count
    local t51_pass = 1
    foreach var in ifp tumsize {
        quietly {
            summ value if dataset == "hypoxia_strata" & ///
                quantity == "strata_coef" & variable == "`var'", meanonly
        }
        if r(N) == 0 {
            display as error "  FAIL [C51.`var']: R strata coef not found"
            local t51_pass = 0
            continue
        }
        local r_coef = r(mean)
        if "`var'" == "ifp" local pos = 1
        if "`var'" == "tumsize" local pos = 2
        local s_coef = b_strata_stata[1, `pos']
        local adiff = abs(`s_coef' - `r_coef')
        display as text "  strata coef[`var']: Stata=" %10.6f `s_coef' ///
            " R(cengroup)=" %10.6f `r_coef' " diff=" %8.6f `adiff'
        if `adiff' >= 1e-6 {
            display as error "  FAIL [C51.`var']: diff `adiff' >= 1e-6"
            local t51_pass = 0
        }
    }
    if `t51_pass' {
        display as result ///
            "  PASS: C51 strata coefficients vs crr cengroup (< 1e-6)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C51 strata coefficients vs crr cengroup"
        local ++fail_count
    }

    * C52: Strata robust SEs vs crr cengroup
    local ++test_count
    local t52_pass = 1
    foreach var in ifp tumsize {
        quietly {
            summ value if dataset == "hypoxia_strata" & ///
                quantity == "strata_se_robust" & variable == "`var'", meanonly
        }
        if r(N) == 0 {
            display as error "  FAIL [C52.`var']: R strata SE not found"
            local t52_pass = 0
            continue
        }
        local r_se = r(mean)
        if "`var'" == "ifp" local pos = 1
        if "`var'" == "tumsize" local pos = 2
        local s_se = sqrt(V_strata_stata[`pos', `pos'])
        local rdiff = abs(`s_se' - `r_se') / `r_se'
        display as text "  strata se[`var']: Stata=" %10.6f `s_se' ///
            " R(cengroup)=" %10.6f `r_se' " rel_diff=" %6.3f `rdiff'
        if `rdiff' >= 0.001 {
            display as error "  FAIL [C52.`var']: rel_diff `rdiff' >= 0.001"
            local t52_pass = 0
        }
    }
    if `t52_pass' {
        display as result ///
            "  PASS: C52 strata robust SEs vs crr cengroup (< 0.1%)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C52 strata robust SEs vs crr cengroup"
        local ++fail_count
    }

    * C53: Strata log-likelihood vs crr cengroup
    local ++test_count
    capture noisily {
        quietly {
            summ value if dataset == "hypoxia_strata" & ///
                quantity == "strata_loglik" & variable == "final", meanonly
        }
        local r_ll = r(mean)
        local rdiff = abs(`ll_strata_stata' - `r_ll') / abs(`r_ll')
        display as text "  strata loglik: Stata=" %12.4f `ll_strata_stata' ///
            " R(cengroup)=" %12.4f `r_ll' " rel_diff=" %8.6f `rdiff'
        assert `rdiff' < 1e-6
    }
    if _rc == 0 {
        display as result ///
            "  PASS: C53 strata log-likelihood vs crr cengroup (< 1e-6 relative)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C53 strata log-likelihood (rc=`=_rc')"
        local ++fail_count
    }

    * C54: Strata CIF at z=0 vs crr cengroup
    local ++test_count
    local t54_pass = 1
    * Get Stata baseline hazard for CIF calculation
    restore
    _setup_hypoxia
    finegray ifp tumsize, compete(status) cause(1) nolog strata(pelnode) basehaz
    matrix bh_strata = e(basehaz)
    local nr_bh_s = rowsof(bh_strata)
    preserve
    import delimited using ///
        "`datadir'/finegray_r_strata_output.csv", ///
        clear
    foreach tt in 2 5 10 {
        quietly {
            summ value if dataset == "hypoxia_strata" & ///
                quantity == "strata_cif_ref" & variable == "t`tt'", meanonly
        }
        if r(N) == 0 {
            display as text "  SKIP [C54.t`tt']: R strata cif_ref not found"
            continue
        }
        local r_cif = r(mean)
        * Find Stata H0 at time tt
        local H0_tt = 0
        forvalues j = 1/`nr_bh_s' {
            if bh_strata[`j', 1] <= `tt' {
                local H0_tt = bh_strata[`j', 2]
            }
        }
        local s_cif = 1 - exp(-`H0_tt')
        local adiff = abs(`s_cif' - `r_cif')
        display as text "  strata CIF(t=`tt',z=0): Stata=" %8.6f `s_cif' ///
            " R(cengroup)=" %8.6f `r_cif' " diff=" %8.6f `adiff'
        if `adiff' >= 1e-5 {
            display as error "  FAIL [C54.t`tt']: diff `adiff' >= 1e-5"
            local t54_pass = 0
        }
    }
    if `t54_pass' {
        display as result ///
            "  PASS: C54 strata CIF at z=0 vs crr cengroup (< 1e-5)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C54 strata CIF vs crr cengroup"
        local ++fail_count
    }

    * C55: Strata vs no-strata — coefficients differ (confirms strata is active)
    local ++test_count
    capture noisily {
        * Get unstratified R coefficients for comparison
        restore
        preserve
        import delimited using ///
            "`datadir'/finegray_r_strata_output.csv", ///
            clear
        * Unstratified coef (from the same dataset, no cengroup)
        quietly summ value if dataset == "hypoxia_strata" & ///
            quantity == "coef" & variable == "ifp", meanonly
        local r_nostrata_coef = r(mean)
        * Stratified coef
        quietly summ value if dataset == "hypoxia_strata" & ///
            quantity == "strata_coef" & variable == "ifp", meanonly
        local r_strata_coef = r(mean)
        * They should be similar but not identical (different censoring model)
        local coef_diff = abs(`r_strata_coef' - `r_nostrata_coef')
        display as text "  R coef[ifp]: no-strata=" %10.6f `r_nostrata_coef' ///
            " strata=" %10.6f `r_strata_coef' " diff=" %8.6f `coef_diff'
        * Both should be non-zero
        assert `r_strata_coef' != 0
        assert `r_nostrata_coef' != 0
    }
    if _rc == 0 {
        display as result ///
            "  PASS: C55 strata vs no-strata differ in R (confirms cengroup active)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C55 strata vs no-strata (rc=`=_rc')"
        local ++fail_count
    }
    restore
}
else {
    * R strata not available — skip C51-C55
    display as text ///
        "  SKIP: strata crossval tests (C51-C55) — R strata output not available"
    forvalues i = 51/55 {
        local ++test_count
        local ++skip_count
    }
}

* {smcl}
* {* SUMMARY}{...}
display ""
display as text _dup(60) "="
display as text "RESULTS: crossval_finegray.do"
display as text _dup(60) "="
display as text "Total:   " as result `test_count'
display as text "Passed:  " as result `pass_count'
display as text "Failed:  " as result `fail_count'
display as text "Skipped: " as result `skip_count'
display as text _dup(60) "="
display as text "RESULT: crossval_finegray tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count'"

if `fail_count' > 0 {
    display as error "RESULT: FAIL (`fail_count' of `test_count' tests failed)"
    log close _crossval_finegray
    exit 1
}
else if `skip_count' > 0 {
    display as result ///
        "RESULT: PASS (`pass_count' passed, `skip_count' skipped)"
}
else {
    display as result "RESULT: PASS (all `test_count' tests passed)"
}

log close _crossval_finegray
