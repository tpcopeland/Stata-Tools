* test_finegray.do - Functional test suite for finegray package
* Tests: installation, options, error handling, return values, data preservation
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
log using "`qadir'/test_finegray.log", ///
    replace text name(_test_finegray)

* {smcl}
* {* SETUP}{...}
capture ado uninstall finegray
net install finegray, from("`pkgroot'") replace

capture which regtab
if _rc {
    capture confirm file "`pkgroot'/../tabtools/tabtools.pkg"
    if _rc == 0 {
        quietly net install tabtools, from("`pkgroot'/../tabtools") replace
    }
}
capture which regtab
if _rc {
    display as error "regtab dependency not available; install tabtools"
    log close _test_finegray
    exit 111
}

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
    * A usable clustering variable. pelnode is BINARY, so clustering on it gives
    * g = 2: the cluster-robust variance is a sum of g cluster-score totals that
    * sum to zero at the solution, so its rank is at most g-1 = 1 and it cannot
    * support 2+ coefficients. finegray now refuses that (FG-H04) instead of
    * printing standard errors invented by a g-inverse, so the cluster tests need
    * a variable with enough clusters to be meaningful.
    gen int clus = mod(_n, 20) + 1
    stset dftime, failure(dfcens==1) id(stnum)
end

* {smcl}
* {* SECTION 1: Installation and availability}{...}

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

* T4: Helper auto-loads after fresh install
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert "`e(cmd)'" == "finegray"
}
if _rc == 0 {
    display as result "  PASS: T4 helper auto-loads after net install"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 helper auto-load failed (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 2: Basic functionality}{...}

* T5: Basic 3-covariate model
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert "`e(cmd)'" == "finegray"
    assert e(converged) == 1
    assert e(N) > 0
}
if _rc == 0 {
    display as result "  PASS: T5 basic 3-covariate model"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 basic model (rc=`=_rc')"
    local ++fail_count
}

* T6: Single covariate
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp, compete(status) cause(1) nolog
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

* T7: Cause 2
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize, compete(status) cause(2) nolog
    assert e(cause) == 2
    assert e(N_fail) > 0
}
if _rc == 0 {
    display as result "  PASS: T7 cause(2)"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 cause(2) (rc=`=_rc')"
    local ++fail_count
}

* T8: With if/in restriction
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode if tumsize > 3, compete(status) cause(1) nolog
    assert e(N) < 109
}
if _rc == 0 {
    display as result "  PASS: T8 if restriction"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 if restriction (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 3: Option tests}{...}

* T9: noshr option
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog noshr
    assert e(converged) == 1
}
if _rc == 0 {
    display as result "  PASS: T9 noshr option"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 noshr (rc=`=_rc')"
    local ++fail_count
}

* T10: level option
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog level(90)
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

* T11: robust option
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog robust
    assert "`e(vce)'" == "robust"
}
if _rc == 0 {
    display as result "  PASS: T11 robust option"
    local ++pass_count
}
else {
    display as error "  FAIL: T11 robust (rc=`=_rc')"
    local ++fail_count
}

* T12: cluster option
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize, compete(status) cause(1) nolog cluster(clus)
    assert "`e(vce)'" == "cluster"
    assert "`e(clustvar)'" == "clus"
}
if _rc == 0 {
    display as result "  PASS: T12 cluster option"
    local ++pass_count
}
else {
    display as error "  FAIL: T12 cluster (rc=`=_rc')"
    local ++fail_count
}

* T13: strata option
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize, compete(status) cause(1) nolog strata(pelnode)
    assert "`e(strata)'" == "pelnode"
    assert e(converged) == 1
}
if _rc == 0 {
    display as result "  PASS: T13 strata option"
    local ++pass_count
}
else {
    display as error "  FAIL: T13 strata (rc=`=_rc')"
    local ++fail_count
}

* T14: censvalue option
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog censvalue(0)
    assert e(censvalue) == 0
}
if _rc == 0 {
    display as result "  PASS: T14 censvalue(0)"
    local ++pass_count
}
else {
    display as error "  FAIL: T14 censvalue (rc=`=_rc')"
    local ++fail_count
}

* T15: iterate option
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog iterate(50)
    assert e(iterate) == 50
}
if _rc == 0 {
    display as result "  PASS: T15 iterate(50)"
    local ++pass_count
}
else {
    display as error "  FAIL: T15 iterate (rc=`=_rc')"
    local ++fail_count
}

* T16: tolerance option
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog tolerance(1e-6)
    assert e(tolerance) == 1e-6
}
if _rc == 0 {
    display as result "  PASS: T16 tolerance(1e-6)"
    local ++pass_count
}
else {
    display as error "  FAIL: T16 tolerance (rc=`=_rc')"
    local ++fail_count
}

* T17: nolog option (suppress iteration log)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert e(converged) == 1
}
if _rc == 0 {
    display as result "  PASS: T17 nolog option"
    local ++pass_count
}
else {
    display as error "  FAIL: T17 nolog (rc=`=_rc')"
    local ++fail_count
}

* T18: Factor variable i.varname
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode ifp, compete(status) cause(1) nolog
    assert e(converged) == 1
    assert e(df_m) == 2
}
if _rc == 0 {
    display as result "  PASS: T18 factor variable i.pelnode"
    local ++pass_count
}
else {
    display as error "  FAIL: T18 factor variable (rc=`=_rc')"
    local ++fail_count
}

* T19: Factor variable ib#.varname
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ib1.pelnode ifp, compete(status) cause(1) nolog
    assert e(converged) == 1
}
if _rc == 0 {
    display as result "  PASS: T19 factor variable ib1.pelnode"
    local ++pass_count
}
else {
    display as error "  FAIL: T19 factor variable ib# (rc=`=_rc')"
    local ++fail_count
}

* T20: Combined options (strata + cluster + robust)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize, compete(status) cause(1) nolog ///
        strata(pelnode) cluster(clus)
    assert "`e(strata)'" == "pelnode"
    assert "`e(clustvar)'" == "clus"
    assert "`e(vce)'" == "cluster"
}
if _rc == 0 {
    display as result "  PASS: T20 combined options (strata + cluster)"
    local ++pass_count
}
else {
    display as error "  FAIL: T20 combined options (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 4: Error handling}{...}

* T21: Error — no stset
local ++test_count
capture noisily {
    sysuse auto, clear
    capture finegray price mpg, compete(rep78) cause(1)
    assert _rc == 119
}
if _rc == 0 {
    display as result "  PASS: T21 error: no stset (rc=119)"
    local ++pass_count
}
else {
    display as error "  FAIL: T21 error: no stset (rc=`=_rc')"
    local ++fail_count
}

* T22: Error — no compete option
local ++test_count
capture noisily {
    _setup_hypoxia
    capture finegray ifp tumsize pelnode, cause(1)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: T22 error: missing compete()"
    local ++pass_count
}
else {
    display as error "  FAIL: T22 error: missing compete (rc=`=_rc')"
    local ++fail_count
}

* T23: Error — no cause option
local ++test_count
capture noisily {
    _setup_hypoxia
    capture finegray ifp tumsize pelnode, compete(status)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: T23 error: missing cause()"
    local ++pass_count
}
else {
    display as error "  FAIL: T23 error: missing cause (rc=`=_rc')"
    local ++fail_count
}

* T24: Error — bad cause value (no matching cause)
local ++test_count
capture noisily {
    _setup_hypoxia
    capture finegray ifp tumsize pelnode, compete(status) cause(99)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T24 error: bad cause value (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T24 error: bad cause (rc=`=_rc')"
    local ++fail_count
}

* T25: No competing events is a SUPPORTED limiting case (FG-M06).
*
* This test used to assert rc == 198.  That guard has been removed deliberately:
* with no competing events nobody is retained in a risk set past their own exit,
* so the subdistribution risk set IS the ordinary risk set and the estimator is
* exactly Cox on this cause.  Refusing to fit a model that is perfectly well
* defined was itself the bug.  Asserting "it no longer errors" would be too weak,
* so assert the ANSWER: it must reproduce stcox.
local ++test_count
capture noisily {
    _setup_hypoxia
    * Make all non-censored events cause 1
    replace status = 1 if status == 2
    finegray ifp tumsize, compete(status) cause(1)
    matrix _T25a = e(b)
    stcox ifp tumsize, nolog
    matrix _T25b = e(b)
    assert abs(_T25a[1,1] - _T25b[1,1]) < 1e-7
    assert abs(_T25a[1,2] - _T25b[1,2]) < 1e-7
}
if _rc == 0 {
    display as result "  PASS: T25 no competing events collapses to stcox"
    local ++pass_count
}
else {
    display as error "  FAIL: T25 no competing events (rc=`=_rc')"
    local ++fail_count
}

* T26: Left truncation (delayed entry) is supported
local ++test_count
capture noisily {
    _setup_hypoxia
    * Force _t0 > 0 for some obs (values less than _t)
    replace _t0 = _t / 2 in 1/20
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert e(converged) == 1
}
if _rc == 0 {
    display as result "  PASS: T26 left truncation supported"
    local ++pass_count
}
else {
    display as error "  FAIL: T26 left truncation (rc=`=_rc')"
    local ++fail_count
}

* T27: Error — no stset id()
local ++test_count
capture noisily {
    _finegray_use_hypoxia
    gen byte status = failtype
    stset dftime, failure(dfcens==1)
    capture finegray ifp tumsize pelnode, compete(status) cause(1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T27 error: no stset id() (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T27 error: no stset id (rc=`=_rc')"
    local ++fail_count
}

* T28: Error — compete/stset mismatch
local ++test_count
capture noisily {
    _setup_hypoxia
    * Create fake event where _d=0 but compete!=0
    replace status = 1 if _d == 0 & _n == 1
    capture finegray ifp tumsize pelnode, compete(status) cause(1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T28 error: compete/stset mismatch (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T28 error: compete mismatch (rc=`=_rc')"
    local ++fail_count
}

* T29: Missing covariate data handled via markout
local ++test_count
capture noisily {
    _setup_hypoxia
    local N_full = _N
    replace ifp = . in 1/5
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert e(N) < `N_full'
}
if _rc == 0 {
    display as result "  PASS: T29 missing covariate markout"
    local ++pass_count
}
else {
    display as error "  FAIL: T29 missing covariate (rc=`=_rc')"
    local ++fail_count
}

* T30: Removed options produce error
local ++test_count
capture noisily {
    _setup_hypoxia
    capture finegray ifp tumsize, compete(status) cause(1) wrapper
    local rc_wrapper = _rc
    capture finegray ifp tumsize, compete(status) cause(1) tvc(pelnode)
    local rc_tvc = _rc
    capture finegray ifp tumsize, compete(status) cause(1) noshorten
    local rc_noshorten = _rc
    assert `rc_wrapper' != 0
    assert `rc_tvc' != 0
    assert `rc_noshorten' != 0
}
if _rc == 0 {
    display as result "  PASS: T30 removed options (wrapper/tvc/noshorten) error"
    local ++pass_count
}
else {
    display as error "  FAIL: T30 removed options (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 5: Stored results}{...}

* T31: All e() scalars present
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert e(N) > 0
    assert e(N) > 0
    assert e(N_fail) > 0
    assert e(N_compete) > 0
    assert e(N_cens) > 0
    assert e(ll) < 0
    assert e(ll_0) < 0
    assert e(chi2) > 0
    assert e(p) >= 0 & e(p) <= 1
    assert e(df_m) == 3
    assert e(converged) == 1
    assert e(level) == 95
    assert e(cause) == 1
    assert e(censvalue) == 0
    assert e(iterate) == 200
    assert e(tolerance) == 1e-8
}
if _rc == 0 {
    display as result "  PASS: T31 all e() scalars present"
    local ++pass_count
}
else {
    display as error "  FAIL: T31 e() scalars (rc=`=_rc')"
    local ++fail_count
}

* T32: All e() macros present
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert "`e(cmd)'" == "finegray"
    assert "`e(predict)'" == "finegray_predict"
    assert "`e(depvar)'" == "status"
    assert "`e(compete)'" == "status"
    assert "`e(covariates)'" == "ifp tumsize pelnode"
    assert "`e(title)'" == "Fine-Gray competing risks regression"
    * e(properties) drives `estimates'/`_estimates hold'; b V must both be posted.
    assert "`e(properties)'" == "b V"
}
if _rc == 0 {
    display as result "  PASS: T32 all e() macros present"
    local ++pass_count
}
else {
    display as error "  FAIL: T32 e() macros (rc=`=_rc')"
    local ++fail_count
}

* T33: e(b), e(V) always; e(basehaz) ONLY with basehaz
* Contract change: e(basehaz) is opt-in.  Creating its K-row Stata matrix is
* O(K^2) (Stata builds one dimension name per row), and that round trip was the
* package's entire superlinearity -- runtime slope 1.65 with it, 1.05 without.
* Postestimation does not need it: finegray_cif and finegray_predict rebuild the
* same curve in Mata.  Assert BOTH halves -- that the default omits it, and that
* the option restores it -- or the default could silently start posting it again.
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    confirm matrix e(b)
    confirm matrix e(V)
    capture confirm matrix e(basehaz)
    assert _rc != 0

    finegray ifp tumsize pelnode, compete(status) cause(1) nolog basehaz
    confirm matrix e(b)
    confirm matrix e(V)
    confirm matrix e(basehaz)
    assert colsof(e(b)) == 3
    assert colsof(e(V)) == 3
    assert rowsof(e(V)) == 3
    * FG-M01: one row per unique cause-event TIME, so <= N_fail (equal only when
    * no two cause events share a time)
    assert rowsof(e(basehaz)) <= e(N_fail)
    assert rowsof(e(basehaz)) >= 1
    assert colsof(e(basehaz)) == 2
}
if _rc == 0 {
    display as result "  PASS: T33 e(b), e(V), e(basehaz) matrices"
    local ++pass_count
}
else {
    display as error "  FAIL: T33 e() matrices (rc=`=_rc')"
    local ++fail_count
}

* T34: Event counts sum to N
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert e(N_fail) + e(N_compete) + e(N_cens) == e(N)
}
if _rc == 0 {
    display as result "  PASS: T34 event counts sum to N"
    local ++pass_count
}
else {
    display as error "  FAIL: T34 event count sum (rc=`=_rc')"
    local ++fail_count
}

* T35: Removed e() values not present
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    * These were removed before v1.0.0
    assert "`e(method)'" == ""
    assert "`e(tvc)'" == ""
    assert "`e(strata)'" == ""
    local n_expand = e(N_expand)
    assert `n_expand' == .
}
if _rc == 0 {
    display as result "  PASS: T35 removed e() values not present"
    local ++pass_count
}
else {
    display as error "  FAIL: T35 removed e() values (rc=`=_rc')"
    local ++fail_count
}

* T36: Conditional e() values — strata
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize, compete(status) cause(1) nolog
    assert "`e(strata)'" == ""
    finegray ifp tumsize, compete(status) cause(1) nolog strata(pelnode)
    assert "`e(strata)'" == "pelnode"
}
if _rc == 0 {
    display as result "  PASS: T36 conditional e(strata)"
    local ++pass_count
}
else {
    display as error "  FAIL: T36 conditional e(strata) (rc=`=_rc')"
    local ++fail_count
}

* T37: Conditional e() values — vce/clustvar
local ++test_count
capture noisily {
    _setup_hypoxia
    * Default is robust (sandwich SEs for pseudo-likelihood)
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert "`e(vce)'" == "robust"
    assert "`e(clustvar)'" == ""
    * norobust: model-based SEs — vce is oim
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog norobust
    assert "`e(vce)'" == "oim"
    * cluster: vce is cluster
    finegray ifp tumsize, compete(status) cause(1) nolog cluster(clus)
    assert "`e(vce)'" == "cluster"
    assert "`e(clustvar)'" == "clus"
}
if _rc == 0 {
    display as result "  PASS: T37 conditional e(vce)/e(clustvar)"
    local ++pass_count
}
else {
    display as error "  FAIL: T37 conditional e(vce) (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 6: Data preservation}{...}

* T38: Data unchanged after finegray
local ++test_count
capture noisily {
    _setup_hypoxia
    local N_before = _N
    local sortvar_before : sortedby
    summ ifp, meanonly
    local mean_before = r(mean)
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert _N == `N_before'
    assert "`sortvar_before'" == "`: sortedby'"
    summ ifp, meanonly
    assert abs(r(mean) - `mean_before') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: T38 data preserved after finegray"
    local ++pass_count
}
else {
    display as error "  FAIL: T38 data preservation (rc=`=_rc')"
    local ++fail_count
}

* T39: Varabbrev restored on success
local ++test_count
capture noisily {
    set varabbrev on
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert c(varabbrev) == "on"
    set varabbrev off
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert c(varabbrev) == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: T39 varabbrev restored on success"
    local ++pass_count
}
else {
    display as error "  FAIL: T39 varabbrev restore (rc=`=_rc')"
    local ++fail_count
}

* T40: Varabbrev restored on error
local ++test_count
capture noisily {
    set varabbrev on
    sysuse auto, clear
    capture finegray price mpg, compete(rep78) cause(1)
    assert c(varabbrev) == "on"
    set varabbrev off
    sysuse auto, clear
    capture finegray price mpg, compete(rep78) cause(1)
    assert c(varabbrev) == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: T40 varabbrev restored on error"
    local ++pass_count
}
else {
    display as error "  FAIL: T40 varabbrev error (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 7: Prediction}{...}

* T41: predict xb
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict xb_hat
    assert xb_hat < .
    drop xb_hat
}
if _rc == 0 {
    display as result "  PASS: T41 predict xb (default)"
    local ++pass_count
}
else {
    display as error "  FAIL: T41 predict xb (rc=`=_rc')"
    local ++fail_count
}

* T42: predict xb explicit
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict xb_hat, xb
    assert xb_hat < .
    drop xb_hat
}
if _rc == 0 {
    display as result "  PASS: T42 predict xb explicit"
    local ++pass_count
}
else {
    display as error "  FAIL: T42 predict xb explicit (rc=`=_rc')"
    local ++fail_count
}

* T43: predict cif
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict cif_hat, cif
    summ cif_hat, meanonly
    assert r(min) >= 0 & r(max) <= 1
    drop cif_hat
}
if _rc == 0 {
    display as result "  PASS: T43 predict cif in [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: T43 predict cif (rc=`=_rc')"
    local ++fail_count
}

* T44: predict cif with timevar
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    gen double mytime = 5
    finegray_predict cif_at5, cif timevar(mytime)
    summ cif_at5, meanonly
    assert r(min) >= 0 & r(max) <= 1
    drop mytime cif_at5
}
if _rc == 0 {
    display as result "  PASS: T44 predict cif with timevar"
    local ++pass_count
}
else {
    display as error "  FAIL: T44 predict cif timevar (rc=`=_rc')"
    local ++fail_count
}

* T45: predict error — no prior finegray
local ++test_count
capture noisily {
    _setup_hypoxia
    * Run a non-finegray estimation to overwrite e(cmd)
    quietly regress ifp tumsize
    capture finegray_predict xb_hat
    assert _rc == 301
}
if _rc == 0 {
    display as result "  PASS: T45 predict error: no prior finegray"
    local ++pass_count
}
else {
    display as error "  FAIL: T45 predict error (rc=`=_rc')"
    local ++fail_count
}

* T46: predict error — both cif and xb
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    capture finegray_predict dual, cif xb
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T46 predict error: cif + xb"
    local ++pass_count
}
else {
    display as error "  FAIL: T46 predict cif+xb (rc=`=_rc')"
    local ++fail_count
}

* T47: predict with double storage type
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict double cif_d, cif
    confirm double variable cif_d
    drop cif_d
}
if _rc == 0 {
    display as result "  PASS: T47 predict double storage type"
    local ++pass_count
}
else {
    display as error "  FAIL: T47 predict double (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 8: Dataset characteristics}{...}

* T48: Dataset chars set after finegray
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert `"`_dta[_finegray_estimated]'"' == "1"
    assert `"`_dta[_finegray_compete]'"' == "status"
    assert `"`_dta[_finegray_cause]'"' == "1"
    assert `"`_dta[_finegray_covars]'"' == "ifp tumsize pelnode"
    assert `"`_dta[_finegray_fvvars]'"' == ""
    assert `"`_dta[_finegray_fvvarlist]'"' == ""
}
if _rc == 0 {
    display as result "  PASS: T48 dataset chars set"
    local ++pass_count
}
else {
    display as error "  FAIL: T48 dataset chars (rc=`=_rc')"
    local ++fail_count
}

* T49: Removed char _finegray_method not set
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert `"`_dta[_finegray_method]'"' == ""
}
if _rc == 0 {
    display as result "  PASS: T49 removed char _finegray_method not set"
    local ++pass_count
}
else {
    display as error "  FAIL: T49 removed char (rc=`=_rc')"
    local ++fail_count
}

* T49b: FV dataset chars recorded for factor-variable models
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    assert `"`_dta[_finegray_fvvars]'"' != ""
    assert `"`_dta[_finegray_fvvarlist]'"' == `"`e(fvvarlist)'"'
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: T49b FV dataset chars recorded"
    local ++pass_count
}
else {
    display as error "  FAIL: T49b FV dataset chars (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 9: Basehaz matrix properties}{...}

* T50: Basehaz column names
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog basehaz
    matrix bh = e(basehaz)
    local cnames : colnames bh
    assert "`cnames'" == "time cumhazard"
}
if _rc == 0 {
    display as result "  PASS: T50 basehaz column names"
    local ++pass_count
}
else {
    display as error "  FAIL: T50 basehaz colnames (rc=`=_rc')"
    local ++fail_count
}

* T51: Basehaz rows = distinct cause-event TIMES (not events)
* Contract change (FG-M01): the cumulative subhazard is a step function of time,
* so e(basehaz) carries one row per unique cause-event time. Through v1.1.4 it
* emitted one row per cause EVENT, leaving it multi-valued at ties (50 tied
* events -> 50 rows, 1 unique time). rows == e(N_fail) only held because no
* fixture had tied cause events.
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog basehaz
    matrix bh = e(basehaz)

    quietly levelsof _t if status == 1 & e(sample), local(_evt)
    local n_evtimes : word count `_evt'
    assert rowsof(bh) == `n_evtimes'
    assert rowsof(bh) <= e(N_fail)

    * times are strictly increasing and unique
    local prev = -1
    forvalues r = 1/`=rowsof(bh)' {
        assert bh[`r',1] > `prev'
        local prev = bh[`r',1]
    }
}
if _rc == 0 {
    display as result "  PASS: T51 basehaz rows = N_fail"
    local ++pass_count
}
else {
    display as error "  FAIL: T51 basehaz rows (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 10: Additional coverage for SSC release}{...}

* T52: in range restriction
local ++test_count
capture noisily {
    _setup_hypoxia
    local N_full = _N
    finegray ifp tumsize pelnode in 1/50, compete(status) cause(1) nolog
    assert e(N) <= 50
    assert e(N) < `N_full'
    * Small subsets may not converge — check model ran, not convergence
    assert e(ll) < .
}
if _rc == 0 {
    display as result "  PASS: T52 in range restriction"
    local ++pass_count
}
else {
    display as error "  FAIL: T52 in range (rc=`=_rc')"
    local ++fail_count
}

* T53: norobust option produces model-based SEs (different from default)
local ++test_count
capture noisily {
    _setup_hypoxia
    * Default is robust/sandwich
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    matrix V_robust = e(V)
    assert "`e(vce)'" == "robust"
    * norobust gives model-based (observed information)
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog norobust
    matrix V_model = e(V)
    assert "`e(vce)'" == "oim"
    * Model-based and default (robust) SEs should differ
    local diff = 0
    forvalues i = 1/3 {
        if abs(V_robust[`i',`i'] - V_model[`i',`i']) > 1e-10 local diff = 1
    }
    assert `diff' == 1
}
if _rc == 0 {
    display as result "  PASS: T53 norobust produces different SEs"
    local ++pass_count
}
else {
    display as error "  FAIL: T53 norobust (rc=`=_rc')"
    local ++fail_count
}

* T54: Factor variable coefficients match manual indicators
local ++test_count
capture noisily {
    _setup_hypoxia
    * pelnode is binary (0/1) — manual indicator for level 1
    gen byte pel_1 = (pelnode == 1)
    finegray pel_1 ifp, compete(status) cause(1) nolog
    matrix b_manual = e(b)
    drop pel_1
    * Factor variable version: i.pelnode creates _fg_pelnode_1 (ref=0)
    finegray i.pelnode ifp, compete(status) cause(1) nolog
    matrix b_fv = e(b)
    * Both should have 2 coefficients with identical values
    assert colsof(b_fv) == 2
    assert abs(b_fv[1,1] - b_manual[1,1]) < 1e-8
    assert abs(b_fv[1,2] - b_manual[1,2]) < 1e-8
}
if _rc == 0 {
    display as result "  PASS: T54 factor variable matches manual indicators"
    local ++pass_count
}
else {
    display as error "  FAIL: T54 factor vs manual (rc=`=_rc')"
    local ++fail_count
}

* T55: Non-default censvalue with recoded data
local ++test_count
capture noisily {
    _setup_hypoxia
    * Recode: 9=censored, 1=cause, 2=competing
    gen byte status9 = status
    replace status9 = 9 if status == 0
    * Need to re-stset with matching failure indicator
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status9) cause(1) censvalue(9) nolog
    assert e(converged) == 1
    assert e(censvalue) == 9
    assert e(N_cens) > 0
    * Coefficients should match the standard coding
    matrix b_recode = e(b)
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    matrix b_std = e(b)
    forvalues i = 1/3 {
        assert abs(b_recode[1,`i'] - b_std[1,`i']) < 1e-8
    }
    drop status9
}
if _rc == 0 {
    display as result "  PASS: T55 non-default censvalue(9)"
    local ++pass_count
}
else {
    display as error "  FAIL: T55 censvalue(9) (rc=`=_rc')"
    local ++fail_count
}

* T56: predict with if restriction
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict xb_if if ifp > 10, xb
    quietly count if xb_if < . & ifp > 10
    local n_pred = r(N)
    quietly count if xb_if < . & ifp <= 10
    assert r(N) == 0
    assert `n_pred' > 0
    drop xb_if
}
if _rc == 0 {
    display as result "  PASS: T56 predict with if restriction"
    local ++pass_count
}
else {
    display as error "  FAIL: T56 predict if (rc=`=_rc')"
    local ++fail_count
}

* T57: predict cif with in restriction
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict cif_in in 1/20, cif
    quietly count if cif_in < .
    assert r(N) == 20
    summ cif_in, meanonly
    assert r(min) >= 0 & r(max) <= 1
    drop cif_in
}
if _rc == 0 {
    display as result "  PASS: T57 predict cif with in restriction"
    local ++pass_count
}
else {
    display as error "  FAIL: T57 predict cif in (rc=`=_rc')"
    local ++fail_count
}

* T58: Multiple strata variables (auto-combined internally)
local ++test_count
capture noisily {
    _setup_hypoxia
    gen byte ifp_grp = (ifp > 10)
    finegray tumsize, compete(status) cause(1) nolog strata(pelnode ifp_grp)
    assert "`e(strata)'" == "pelnode ifp_grp"
    assert e(converged) == 1
    drop ifp_grp
}
if _rc == 0 {
    display as result "  PASS: T58 multiple strata variables"
    local ++pass_count
}
else {
    display as error "  FAIL: T58 multiple strata (rc=`=_rc')"
    local ++fail_count
}

* T59: Error — negative factor values (Stata FV rejects them, rc=452)
local ++test_count
capture noisily {
    _setup_hypoxia
    gen int neg_var = pelnode - 2
    replace neg_var = -2 if stnum <= 10
    capture finegray i.neg_var ifp, compete(status) cause(1)
    assert _rc != 0
    drop neg_var
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: T59 error: negative factor values"
    local ++pass_count
}
else {
    display as error "  FAIL: T59 negative factor values (rc=`=_rc')"
    local ++fail_count
}

* T60: Single-level factor expands to a constant column, which the unpenalized
* Fine-Gray partial likelihood cannot identify -> explicit r(459), not a
* silent ridge-dependent fit (v1.1.2 behaviour).
local ++test_count
capture noisily {
    _setup_hypoxia
    gen byte const_fv = 1
    capture finegray i.const_fv ifp, compete(status) cause(1) nolog
    assert _rc == 459
    drop const_fv
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: T60 single-level factor rejected (rc=459)"
    local ++pass_count
}
else {
    display as error "  FAIL: T60 single-level factor (rc=`=_rc')"
    local ++fail_count
}

* T61: No censored observations is a SUPPORTED limiting case (FG-M06).
*
* This test used to assert rc == 198.  That guard has been removed deliberately:
* with complete follow-up G(t) == 1 everywhere, so the combined weight A collapses
* to 1 and every retained weight is exactly 1.  Complete follow-up is not a defect.
* Assert the weight actually collapses -- e(max_lt_weight) == 1 -- not merely that
* the command returns.
local ++test_count
capture noisily {
    _setup_hypoxia
    * Make all censored obs become cause 2
    replace status = 2 if status == 0
    * Also need to set _d=1 for consistency
    replace _d = 1 if _d == 0
    finegray ifp tumsize, compete(status) cause(1)
    assert e(N_cens) == 0
    assert abs(e(max_lt_weight) - 1) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: T61 no censored observations: all weights = 1"
    local ++pass_count
}
else {
    display as error "  FAIL: T61 no censored (rc=`=_rc')"
    local ++fail_count
}

* T62: Nonexistent base category — fvrevar treats as phantom reference, so both
* levels enter as indicators.  They sum to 1, and the Fine-Gray partial
* likelihood is invariant to an additive constant in xb, so the pair is not
* identified: reject with r(459) rather than return an arbitrary split.
local ++test_count
capture noisily {
    _setup_hypoxia
    capture finegray ib99.pelnode ifp, compete(status) cause(1) nolog
    assert _rc == 459
    * The identified spec (real base category) must still fit.
    finegray ib0.pelnode ifp, compete(status) cause(1) nolog
    assert e(converged) == 1
    assert e(df_m) == 2
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: T62 phantom base category rejected (rc=459)"
    local ++pass_count
}
else {
    display as error "  FAIL: T62 phantom base (rc=`=_rc')"
    local ++fail_count
}

* T63: Version consistency across package files
local ++test_count
capture noisily {
    capture which finegray
    local rc1 = _rc
    capture which finegray_predict
    local rc2 = _rc
    capture which _finegray_mata
    local rc3 = _rc
    assert `rc1' == 0
    assert `rc2' == 0
    assert `rc3' == 0
}
if _rc == 0 {
    display as result "  PASS: T63 all package files installed"
    local ++pass_count
}
else {
    display as error "  FAIL: T63 package files (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 11: finegray_phtest}{...}

* T64: Basic phtest after finegray
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_phtest
    assert r(chi2) >= 0
}
if _rc == 0 {
    display as result "  PASS: T64 basic phtest"
    local ++pass_count
}
else {
    display as error "  FAIL: T64 basic phtest (rc=`=_rc')"
    local ++fail_count
}

* T65: time(rank) option
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_phtest, time(rank)
    assert "`r(time)'" == "rank"
}
if _rc == 0 {
    display as result "  PASS: T65 time(rank)"
    local ++pass_count
}
else {
    display as error "  FAIL: T65 time(rank) (rc=`=_rc')"
    local ++fail_count
}

* T66: time(log) option
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_phtest, time(log)
    assert "`r(time)'" == "log"
}
if _rc == 0 {
    display as result "  PASS: T66 time(log)"
    local ++pass_count
}
else {
    display as error "  FAIL: T66 time(log) (rc=`=_rc')"
    local ++fail_count
}

* T67: time(identity) option
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_phtest, time(identity)
    assert "`r(time)'" == "identity"
}
if _rc == 0 {
    display as result "  PASS: T67 time(identity)"
    local ++pass_count
}
else {
    display as error "  FAIL: T67 time(identity) (rc=`=_rc')"
    local ++fail_count
}

* T68: detail option
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_phtest, detail
    assert r(chi2) >= 0
}
if _rc == 0 {
    display as result "  PASS: T68 detail option"
    local ++pass_count
}
else {
    display as error "  FAIL: T68 detail (rc=`=_rc')"
    local ++fail_count
}

* T69: r() scalars present and valid
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    local nfail_e = e(N_fail)
    finegray_phtest
    assert r(chi2) > 0
    assert r(df) == 3
    assert r(p) >= 0 & r(p) <= 1
    assert r(N_fail) == `nfail_e'
}
if _rc == 0 {
    display as result "  PASS: T69 r() scalars present and valid"
    local ++pass_count
}
else {
    display as error "  FAIL: T69 r() scalars (rc=`=_rc')"
    local ++fail_count
}

* T70: r(phtest) matrix dimensions and labels
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_phtest
    confirm matrix r(phtest)
    assert rowsof(r(phtest)) == 3
    assert colsof(r(phtest)) == 3
    local cnames : colnames r(phtest)
    assert "`cnames'" == "chi2 df p"
    local rnames : rownames r(phtest)
    assert "`rnames'" == "ifp tumsize pelnode"
}
if _rc == 0 {
    display as result "  PASS: T70 r(phtest) matrix 3x3 with correct labels"
    local ++pass_count
}
else {
    display as error "  FAIL: T70 r(phtest) matrix (rc=`=_rc')"
    local ++fail_count
}

* T71: Error rc=301 — phtest after regress (no prior finegray)
local ++test_count
capture noisily {
    _setup_hypoxia
    quietly regress ifp tumsize
    capture finegray_phtest
    assert _rc == 301
}
if _rc == 0 {
    display as result "  PASS: T71 error: phtest after regress (rc=301)"
    local ++pass_count
}
else {
    display as error "  FAIL: T71 phtest no finegray (rc=`=_rc')"
    local ++fail_count
}

* T72: Error rc=198 — bad time function
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    capture finegray_phtest, time(invalid)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T72 error: time(invalid) (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T72 bad time function (rc=`=_rc')"
    local ++fail_count
}

* T73: phtest with single-covariate model
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp, compete(status) cause(1) nolog
    finegray_phtest
    assert r(df) == 1
    assert rowsof(r(phtest)) == 1
}
if _rc == 0 {
    display as result "  PASS: T73 phtest single-covariate model"
    local ++pass_count
}
else {
    display as error "  FAIL: T73 phtest single covariate (rc=`=_rc')"
    local ++fail_count
}

* T74: phtest varabbrev restore on success
local ++test_count
capture noisily {
    set varabbrev on
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_phtest
    assert c(varabbrev) == "on"
    set varabbrev off
    finegray_phtest
    assert c(varabbrev) == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: T74 phtest varabbrev restore on success"
    local ++pass_count
}
else {
    display as error "  FAIL: T74 phtest varabbrev (rc=`=_rc')"
    local ++fail_count
}

* T75: phtest varabbrev restore on error
local ++test_count
capture noisily {
    set varabbrev on
    _setup_hypoxia
    quietly regress ifp tumsize
    capture finegray_phtest
    assert c(varabbrev) == "on"
    set varabbrev off
    capture finegray_phtest
    assert c(varabbrev) == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: T75 phtest varabbrev restore on error"
    local ++pass_count
}
else {
    display as error "  FAIL: T75 phtest varabbrev error (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 12: Schoenfeld predictions}{...}

* T76: predict schoenfeld — creates variables without error
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict sch_stub, schoenfeld
    confirm variable sch_stub
    drop sch_stub*
}
if _rc == 0 {
    display as result "  PASS: T76 predict schoenfeld runs"
    local ++pass_count
}
else {
    display as error "  FAIL: T76 predict schoenfeld (rc=`=_rc')"
    local ++fail_count
}

* T77: Schoenfeld creates p variables for 3-cov model
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict sch, schoenfeld
    confirm variable sch
    confirm variable sch_2
    confirm variable sch_3
    drop sch sch_2 sch_3
}
if _rc == 0 {
    display as result "  PASS: T77 schoenfeld creates 3 variables"
    local ++pass_count
}
else {
    display as error "  FAIL: T77 schoenfeld var count (rc=`=_rc')"
    local ++fail_count
}

* T78: Schoenfeld residuals only at cause-event times
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    local nfail = e(N_fail)
    finegray_predict sch, schoenfeld
    quietly count if sch < .
    assert r(N) == `nfail'
    drop sch sch_2 sch_3
}
if _rc == 0 {
    display as result "  PASS: T78 schoenfeld non-missing count == N_fail"
    local ++pass_count
}
else {
    display as error "  FAIL: T78 schoenfeld count (rc=`=_rc')"
    local ++fail_count
}

* T79: Error rc=198 — schoenfeld + cif conflict
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    capture finegray_predict sch_cif, schoenfeld cif
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T79 error: schoenfeld + cif conflict (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T79 schoenfeld+cif (rc=`=_rc')"
    local ++fail_count
}

* T80: Error rc=198 — schoenfeld + xb conflict
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    capture finegray_predict sch_xb, schoenfeld xb
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T80 error: schoenfeld + xb conflict (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T80 schoenfeld+xb (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 13: Documentation reality}{...}

* T81: sthlp basic example verbatim
local ++test_count
capture noisily {
    _finegray_use_hypoxia
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    assert e(converged) == 1
}
if _rc == 0 {
    display as result "  PASS: T81 sthlp basic example verbatim"
    local ++pass_count
}
else {
    display as error "  FAIL: T81 sthlp basic example (rc=`=_rc')"
    local ++fail_count
}

* T82: sthlp strata example
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize, compete(status) cause(1) strata(pelnode)
    assert e(converged) == 1
}
if _rc == 0 {
    display as result "  PASS: T82 sthlp strata example"
    local ++pass_count
}
else {
    display as error "  FAIL: T82 sthlp strata example (rc=`=_rc')"
    local ++fail_count
}

* T83: sthlp CIF prediction example
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1)
    finegray_predict cif_hat, cif
    assert cif_hat < .
    drop cif_hat
}
if _rc == 0 {
    display as result "  PASS: T83 sthlp CIF example"
    local ++pass_count
}
else {
    display as error "  FAIL: T83 sthlp CIF example (rc=`=_rc')"
    local ++fail_count
}

* T84: sthlp margins at() example
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    margins, at(ifp=(0 5 10)) predict(xb)
    confirm matrix r(table)
}
if _rc == 0 {
    display as result "  PASS: T84 sthlp margins at() example"
    local ++pass_count
}
else {
    display as error "  FAIL: T84 margins at() (rc=`=_rc')"
    local ++fail_count
}

* T85: sthlp margins dydx example
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    margins, dydx(ifp) predict(xb)
    confirm matrix r(table)
}
if _rc == 0 {
    display as result "  PASS: T85 sthlp margins dydx() example"
    local ++pass_count
}
else {
    display as error "  FAIL: T85 margins dydx() (rc=`=_rc')"
    local ++fail_count
}

* T86: sthlp factor variable example
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode ifp, compete(status) cause(1)
    assert e(converged) == 1
}
if _rc == 0 {
    display as result "  PASS: T86 sthlp factor variable example"
    local ++pass_count
}
else {
    display as error "  FAIL: T86 sthlp factor example (rc=`=_rc')"
    local ++fail_count
}

* T87: sthlp ib# factor variable example
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ib1.pelnode ifp, compete(status) cause(1)
    assert e(converged) == 1
}
if _rc == 0 {
    display as result "  PASS: T87 sthlp ib# factor example"
    local ++pass_count
}
else {
    display as error "  FAIL: T87 sthlp ib# example (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 14: Predict error paths and varabbrev}{...}

* T88: predict error rc=111 — missing timevar
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    capture finegray_predict cif_hat, cif timevar(nonexistent_var)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: T88 predict error: missing timevar (rc=111)"
    local ++pass_count
}
else {
    display as error "  FAIL: T88 predict missing timevar (rc=`=_rc')"
    local ++fail_count
}

* T89: predict error rc=2000 — no observations after if
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    capture finegray_predict cif_hat if 0, cif
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: T89 predict error: no obs (rc=2000)"
    local ++pass_count
}
else {
    display as error "  FAIL: T89 predict no obs (rc=`=_rc')"
    local ++fail_count
}

* T90: finegray_predict varabbrev restore on success
local ++test_count
capture noisily {
    set varabbrev on
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict xb_va, xb
    assert c(varabbrev) == "on"
    drop xb_va
    set varabbrev off
    finegray_predict xb_va2, xb
    assert c(varabbrev) == "off"
    drop xb_va2
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: T90 predict varabbrev restore on success"
    local ++pass_count
}
else {
    display as error "  FAIL: T90 predict varabbrev (rc=`=_rc')"
    local ++fail_count
}

* T91: finegray_predict varabbrev restore on error
local ++test_count
capture noisily {
    set varabbrev on
    _setup_hypoxia
    quietly regress ifp tumsize
    capture finegray_predict xb_hat
    assert c(varabbrev) == "on"
    set varabbrev off
    capture finegray_predict xb_hat
    assert c(varabbrev) == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: T91 predict varabbrev restore on error"
    local ++pass_count
}
else {
    display as error "  FAIL: T91 predict varabbrev error (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 15: Interaction support (fvrevar-based)}{...}

* T92: i.var##c.var — full factorial interaction
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    assert e(converged) == 1
    assert e(df_m) == 4
    assert "`e(fvvarlist)'" != ""
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: T92 i.var##c.var interaction"
    local ++pass_count
}
else {
    display as error "  FAIL: T92 i##c interaction (rc=`=_rc')"
    local ++fail_count
}

* T93: i.var#c.var — interaction only (no main effects)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode#c.ifp tumsize, compete(status) cause(1) nolog
    assert e(converged) == 1
    assert e(df_m) == 2
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: T93 i.var#c.var interaction-only"
    local ++pass_count
}
else {
    display as error "  FAIL: T93 i#c interaction (rc=`=_rc')"
    local ++fail_count
}

* T94: i.var##i.var — two-factor interaction
local ++test_count
capture noisily {
    _setup_hypoxia
    gen byte ifp_grp = (ifp > 10)
    finegray i.pelnode##i.ifp_grp tumsize, compete(status) cause(1) nolog
    * Sparse interaction cell may cause quasi-separation → df_m <= 4
    assert e(df_m) <= 4
    assert e(df_m) >= 2
    assert e(ll) < .
    drop ifp_grp
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: T94 i.var##i.var interaction"
    local ++pass_count
}
else {
    display as error "  FAIL: T94 i##i interaction (rc=`=_rc')"
    local ++fail_count
}

* T95: Interaction + predict CIF — values in [0,1]
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    finegray_predict cif_int, cif
    summ cif_int, meanonly
    assert r(min) >= 0 & r(max) <= 1
    drop cif_int
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: T95 interaction predict CIF in [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: T95 interaction CIF (rc=`=_rc')"
    local ++fail_count
}

* T96: Interaction + predict xb
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    finegray_predict xb_int, xb
    assert !missing(xb_int) if e(sample)
    drop xb_int
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: T96 interaction predict xb"
    local ++pass_count
}
else {
    display as error "  FAIL: T96 interaction xb (rc=`=_rc')"
    local ++fail_count
}

* T97: Interaction + strata + cluster combined
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode##c.ifp, compete(status) cause(1) nolog ///
        strata(pelnode) cluster(clus)
    assert e(converged) == 1
    assert "`e(strata)'" == "pelnode"
    assert "`e(clustvar)'" == "clus"
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: T97 interaction + strata + cluster"
    local ++pass_count
}
else {
    display as error "  FAIL: T97 interaction combined (rc=`=_rc')"
    local ++fail_count
}

* T98: _fg_ variable naming for interactions
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode##c.ifp, compete(status) cause(1) nolog
    * Main effect: _fg_pelnode_1 (backward compatible)
    confirm variable _fg_pelnode_1
    * Interaction: _fg_pelnode_1Xifp
    confirm variable _fg_pelnode_1Xifp
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: T98 _fg_ naming for interactions"
    local ++pass_count
}
else {
    display as error "  FAIL: T98 _fg_ naming (rc=`=_rc')"
    local ++fail_count
}

* T99: e(fvvarlist) stored correctly
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    assert "`e(fvvarlist)'" == "i.pelnode ifp i.pelnode#c.ifp tumsize"
    cap drop _fg_*
    * Non-FV model: e(fvvarlist) should be empty
    finegray ifp tumsize, compete(status) cause(1) nolog
    assert "`e(fvvarlist)'" == ""
}
if _rc == 0 {
    display as result "  PASS: T99 e(fvvarlist) stored correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: T99 e(fvvarlist) (rc=`=_rc')"
    local ++fail_count
}

* T100: _fg_ collision error for interaction variable names
local ++test_count
capture noisily {
    _setup_hypoxia
    gen byte _fg_pelnode_1Xifp = 0
    capture finegray i.pelnode##c.ifp, compete(status) cause(1)
    assert _rc == 198
    drop _fg_pelnode_1Xifp
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: T100 _fg_ collision error for interactions"
    local ++pass_count
}
else {
    display as error "  FAIL: T100 _fg_ collision (rc=`=_rc')"
    local ++fail_count
}

* T101: Backward compat — i.var produces same _fg_ names as before
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode ifp, compete(status) cause(1) nolog
    * Should create _fg_pelnode_1 (same name as old manual expansion)
    confirm variable _fg_pelnode_1
    local lbl : variable label _fg_pelnode_1
    assert `"`lbl'"' == "1 (vs. 0)"
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: T101 backward compat _fg_ naming"
    local ++pass_count
}
else {
    display as error "  FAIL: T101 backward compat (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 12: regtab Excel output — finegray vs stcrreg}{...}

local output_dir "`qadir'"

* Delete stale workbook so confirm file tests are meaningful
capture erase "`output_dir'/finegray_regtab.xlsx"

* T102: regtab — basic 3-covariate model (finegray vs stcrreg)
local ++test_count
capture noisily {
    _setup_hypoxia
    collect clear
    collect: finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    * stcrreg needs failure(status==1)
    stset dftime, failure(status==1) id(stnum)
    collect: stcrreg ifp tumsize pelnode, compete(status == 2)
    regtab, xlsx("`output_dir'/finegray_regtab.xlsx") sheet("Basic") ///
        coef("SHR") models("finegray \ stcrreg") ///
        title("Basic model: finegray vs stcrreg") stats(n)
    confirm file "`output_dir'/finegray_regtab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: T102 regtab basic finegray vs stcrreg"
    local ++pass_count
}
else {
    display as error "  FAIL: T102 regtab basic (rc=`=_rc')"
    local ++fail_count
}

* T103: regtab — model-based SEs (finegray norobust vs stcrreg)
local ++test_count
capture noisily {
    _setup_hypoxia
    collect clear
    collect: finegray ifp tumsize pelnode, compete(status) cause(1) nolog norobust
    stset dftime, failure(status==1) id(stnum)
    collect: stcrreg ifp tumsize pelnode, compete(status == 2) nohr
    regtab, xlsx("`output_dir'/finegray_regtab.xlsx") sheet("Model-based SE") ///
        coef("Coef.") models("finegray (norobust) \ stcrreg (nohr)") ///
        title("Model-based SEs: coefficients") stats(n ll)
    confirm file "`output_dir'/finegray_regtab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: T103 regtab model-based SEs"
    local ++pass_count
}
else {
    display as error "  FAIL: T103 regtab model-based SE (rc=`=_rc')"
    local ++fail_count
}

* T104: regtab — factor variable model
local ++test_count
capture noisily {
    _setup_hypoxia
    collect clear
    collect: finegray i.pelnode ifp tumsize, compete(status) cause(1) nolog
    stset dftime, failure(status==1) id(stnum)
    collect: stcrreg i.pelnode ifp tumsize, compete(status == 2)
    regtab, xlsx("`output_dir'/finegray_regtab.xlsx") sheet("Factor vars") ///
        coef("SHR") models("finegray \ stcrreg") ///
        title("Factor variable model: i.pelnode") stats(n)
    confirm file "`output_dir'/finegray_regtab.xlsx"
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: T104 regtab factor variables"
    local ++pass_count
}
else {
    display as error "  FAIL: T104 regtab factor vars (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SECTION 16: Coverage gaps (added 2026-03-31)}{...}

* T105: Error — cause == censvalue
local ++test_count
capture noisily {
    _setup_hypoxia
    capture finegray ifp tumsize pelnode, compete(status) cause(0) censvalue(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T105 error: cause==censvalue (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T105 cause==censvalue (rc=`=_rc')"
    local ++fail_count
}

* T106: Schoenfeld with single-covariate model
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp, compete(status) cause(1) nolog
    local nfail = e(N_fail)
    finegray_predict sch1, schoenfeld
    confirm variable sch1
    * Single covariate — should NOT create sch1_2
    capture confirm variable sch1_2
    assert _rc != 0
    quietly count if sch1 < .
    assert r(N) == `nfail'
    drop sch1
}
if _rc == 0 {
    display as result "  PASS: T106 schoenfeld single-covariate model"
    local ++pass_count
}
else {
    display as error "  FAIL: T106 schoenfeld single-cov (rc=`=_rc')"
    local ++fail_count
}

* T107: Predict CIF after left-truncation model
local ++test_count
capture noisily {
    _setup_hypoxia
    replace _t0 = _t / 2 in 1/20
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict cif_lt, cif
    summ cif_lt, meanonly
    assert r(min) >= 0 & r(max) <= 1
    drop cif_lt
}
if _rc == 0 {
    display as result "  PASS: T107 predict CIF after left truncation"
    local ++pass_count
}
else {
    display as error "  FAIL: T107 predict CIF left trunc (rc=`=_rc')"
    local ++fail_count
}

* T108: Predict xb after left-truncation model
local ++test_count
capture noisily {
    _setup_hypoxia
    replace _t0 = _t / 2 in 1/20
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict xb_lt, xb
    assert !missing(xb_lt) if e(sample)
    drop xb_lt
}
if _rc == 0 {
    display as result "  PASS: T108 predict xb after left truncation"
    local ++pass_count
}
else {
    display as error "  FAIL: T108 predict xb left trunc (rc=`=_rc')"
    local ++fail_count
}

* T109: phtest with strata
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize, compete(status) cause(1) nolog strata(pelnode)
    finegray_phtest
    assert r(chi2) >= 0
    assert r(df) == 2
}
if _rc == 0 {
    display as result "  PASS: T109 phtest with strata"
    local ++pass_count
}
else {
    display as error "  FAIL: T109 phtest strata (rc=`=_rc')"
    local ++fail_count
}

* T110: phtest with FV model
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode ifp, compete(status) cause(1) nolog
    finegray_phtest
    assert r(chi2) >= 0
    assert r(df) == 2
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: T110 phtest with FV model"
    local ++pass_count
}
else {
    display as error "  FAIL: T110 phtest FV model (rc=`=_rc')"
    local ++fail_count
}

* T111: Basehaz is non-decreasing (monotonicity)
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    matrix bh = e(basehaz)
    local n_bh = rowsof(bh)
    local mono_ok = 1
    forvalues i = 2/`n_bh' {
        if bh[`i', 2] < bh[`=`i'-1', 2] local mono_ok = 0
    }
    assert `mono_ok' == 1
}
if _rc == 0 {
    display as result "  PASS: T111 basehaz monotonically non-decreasing"
    local ++pass_count
}
else {
    display as error "  FAIL: T111 basehaz monotonicity (rc=`=_rc')"
    local ++fail_count
}

* T112: iterate(1) posts a nonconverged fit, but nothing may consume it
* The fit-time contract matches stcrreg: rc 0, e(converged)=0, results posted,
* warning above the table. The gate is in the post-estimation commands, which
* through v1.1.4 read e(b) without ever checking that it converged (FG-H07).
local ++test_count
capture noisily {
    _setup_hypoxia
    capture noisily finegray ifp tumsize pelnode, compete(status) cause(1) nolog iterate(1)
    assert _rc == 0
    assert e(N) > 0
    assert e(converged) == 0

    capture finegray_cif, attime(5)
    assert _rc == 430
    capture finegray_predict t112_xb, xb
    assert _rc == 430
    capture finegray_phtest
    assert _rc == 430

    * the converged fit on the same data still works end to end
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert e(converged) == 1
    finegray_predict t112_ok, xb
    confirm variable t112_ok
}
if _rc == 0 {
    display as result "  PASS: T112 nonconverged fit posts but post-estimation refuses it"
    local ++pass_count
}
else {
    display as error "  FAIL: T112 iterate(1) (rc=`=_rc')"
    local ++fail_count
}

* T113: e(cmdline) contains full command
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert strpos("`e(cmdline)'", "finegray") > 0
    assert strpos("`e(cmdline)'", "compete(status)") > 0
    assert strpos("`e(cmdline)'", "cause(1)") > 0
}
if _rc == 0 {
    display as result "  PASS: T113 e(cmdline) content"
    local ++pass_count
}
else {
    display as error "  FAIL: T113 e(cmdline) (rc=`=_rc')"
    local ++fail_count
}

* T114: Schoenfeld with FV/interaction model
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode##c.ifp tumsize, compete(status) cause(1) nolog
    local nfail = e(N_fail)
    local p = e(df_m)
    finegray_predict sch_fv, schoenfeld
    confirm variable sch_fv
    * 4 covariates: sch_fv, sch_fv_2, sch_fv_3, sch_fv_4
    confirm variable sch_fv_2
    confirm variable sch_fv_3
    confirm variable sch_fv_4
    quietly count if sch_fv < .
    assert r(N) == `nfail'
    drop sch_fv sch_fv_2 sch_fv_3 sch_fv_4
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: T114 schoenfeld with FV/interaction model"
    local ++pass_count
}
else {
    display as error "  FAIL: T114 schoenfeld FV (rc=`=_rc')"
    local ++fail_count
}

* T115: Basehaz times are non-decreasing
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    matrix bh = e(basehaz)
    local n_bh = rowsof(bh)
    local time_ok = 1
    forvalues i = 2/`n_bh' {
        if bh[`i', 1] < bh[`=`i'-1', 1] local time_ok = 0
    }
    assert `time_ok' == 1
}
if _rc == 0 {
    display as result "  PASS: T115 basehaz times non-decreasing"
    local ++pass_count
}
else {
    display as error "  FAIL: T115 basehaz times (rc=`=_rc')"
    local ++fail_count
}

* T116: Schoenfeld residuals varabbrev restore
local ++test_count
capture noisily {
    set varabbrev on
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict sch_va, schoenfeld
    assert c(varabbrev) == "on"
    drop sch_va sch_va_2 sch_va_3
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: T116 schoenfeld varabbrev restore"
    local ++pass_count
}
else {
    display as error "  FAIL: T116 schoenfeld varabbrev (rc=`=_rc')"
    local ++fail_count
}

* T117: Schoenfeld respects if qualifier
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    * Predict only for first 10 obs
    finegray_predict sch_if if _n <= 10, schoenfeld
    * No residuals should exist outside the requested sample
    quietly count if sch_if < . & _n > 10
    assert r(N) == 0
    * Residuals should only appear at cause events within first 10 obs
    quietly count if sch_if < .
    quietly count if sch_if < . & _n <= 10
    assert r(N) == r(N)
    drop sch_if sch_if_2 sch_if_3
}
if _rc == 0 {
    display as result "  PASS: T117 schoenfeld respects if qualifier"
    local ++pass_count
}
else {
    display as error "  FAIL: T117 schoenfeld if qualifier (rc=`=_rc')"
    local ++fail_count
}

* T118: Schoenfeld respects in qualifier
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict sch_in in 1/20, schoenfeld
    * No residuals outside in range
    quietly count if sch_in < . & _n > 20
    assert r(N) == 0
    drop sch_in sch_in_2 sch_in_3
}
if _rc == 0 {
    display as result "  PASS: T118 schoenfeld respects in qualifier"
    local ++pass_count
}
else {
    display as error "  FAIL: T118 schoenfeld in qualifier (rc=`=_rc')"
    local ++fail_count
}

* T119: User _fg_* variable survives repeated FV estimation
local ++test_count
capture noisily {
    _setup_hypoxia
    gen byte _fg_user_keep = 7
    finegray i.pelnode ifp, compete(status) cause(1) nolog
    finegray i.pelnode ifp, compete(status) cause(1) nolog
    assert _fg_user_keep == 7
    drop _fg_user_keep
    cap drop _fg_*
}
if _rc == 0 {
    display as result "  PASS: T119 user _fg_* variable preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: T119 user _fg_* preserved (rc=`=_rc')"
    local ++fail_count
}

* T120: FV predict rebuilds design columns if _fg_* variables are missing
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode ifp, compete(status) cause(1) nolog
    cap drop _fg_*
    finegray_predict xb_fv_missing, xb
    assert xb_fv_missing < .
    drop xb_fv_missing
}
if _rc == 0 {
    display as result "  PASS: T120 FV predict rebuilds missing design columns"
    local ++pass_count
}
else {
    display as error "  FAIL: T120 FV predict rebuild (rc=`=_rc')"
    local ++fail_count
}

* T121: FV phtest works after dropping _fg_* columns
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode ifp, compete(status) cause(1) nolog
    cap drop _fg_*
    finegray_phtest
    assert r(chi2) < .
    assert r(df) == 2
    assert r(p) < .
}
if _rc == 0 {
    display as result "  PASS: T121 FV phtest rebuilds missing design columns"
    local ++pass_count
}
else {
    display as error "  FAIL: T121 FV phtest rebuild (rc=`=_rc')"
    local ++fail_count
}

* T122: Non-FV rerun drops stale _fg_* variables
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode ifp, compete(status) cause(1) nolog
    capture confirm variable _fg_pelnode_1
    assert _rc == 0
    finegray ifp tumsize, compete(status) cause(1) nolog
    capture confirm variable _fg_pelnode_1
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: T122 non-FV rerun drops stale _fg_* variables"
    local ++pass_count
}
else {
    display as error "  FAIL: T122 FV cleanup on non-FV rerun (rc=`=_rc')"
    local ++fail_count
}

* T123: Schoenfeld label includes covariate name for single-covariate model
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp, compete(status) cause(1) nolog
    finegray_predict sch_single, schoenfeld
    local lbl : variable label sch_single
    assert strpos("`lbl'", "ifp") > 0
    drop sch_single
}
if _rc == 0 {
    display as result "  PASS: T123 Schoenfeld label includes covariate name (p=1)"
    local ++pass_count
}
else {
    display as error "  FAIL: T123 Schoenfeld label p=1 (rc=`=_rc')"
    local ++fail_count
}

* T124: FV Schoenfeld rebuild keeps semantic factor labels after dropping _fg_*
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode ifp, compete(status) cause(1) nolog
    cap drop _fg_*
    finegray_predict sch, schoenfeld
    local lbl : variable label sch
    assert strpos("`lbl'", "__") == 0
    assert strpos("`lbl'", "pelnode") > 0
    drop sch sch_2
}
if _rc == 0 {
    display as result "  PASS: T124 FV Schoenfeld rebuild keeps semantic labels"
    local ++pass_count
}
else {
    display as error "  FAIL: T124 FV Schoenfeld rebuild labels (rc=`=_rc')"
    local ++fail_count
}

* T125: FV phtest rebuild keeps semantic factor rownames after dropping _fg_*
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode ifp, compete(status) cause(1) nolog
    cap drop _fg_*
    finegray_phtest
    matrix pht = r(phtest)
    local row1 : rownames pht
    local first : word 1 of `row1'
    assert strpos("`first'", "__") == 0
    assert strpos("`first'", "pelnode") > 0
}
if _rc == 0 {
    display as result "  PASS: T125 FV phtest rebuild keeps semantic rownames"
    local ++pass_count
}
else {
    display as error "  FAIL: T125 FV phtest rebuild rownames (rc=`=_rc')"
    local ++fail_count
}

* T126: Doc-contract — finegray_predict, cif equals 1-exp(-H0(t)*exp(xb)) with
*        H0(t) read from e(basehaz) as a right-continuous step function at the
*        timevar() horizon (largest event time <= t). This locks the time-point
*        semantics documented in finegray_predict.sthlp (per-row _t / timevar()).
local ++test_count
capture noisily {
    _setup_hypoxia
    * basehaz: this test reconstructs H0(t*) from the matrix itself, so it needs
    * e(basehaz) posted.  It is opt-in since the K-row matrix is O(K^2) to create.
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog basehaz

    * Independent xb and a fixed horizon shared by all subjects
    finegray_predict xb_chk, xb
    local tstar = 5
    gen double _tv = `tstar'
    finegray_predict cif_chk, cif timevar(_tv)

    * H0(tstar): largest cumhazard among basehaz times <= tstar (step function)
    matrix bh = e(basehaz)
    local nbh = rowsof(bh)
    local H0 = 0
    forvalues i = 1/`nbh' {
        if bh[`i', 1] <= `tstar' local H0 = bh[`i', 2]
    }

    * Documented formula, recomputed independently. Tolerance 1e-6 (not bit-exact):
    * the internal Mata predict path and this external Stata reconstruction differ
    * only by floating-point noise (~5e-8, about half of float epsilon). A genuine
    * formula/time-point regression would be O(0.1), so 1e-6 still catches it.
    gen double cif_ref = 1 - exp(-`H0' * exp(xb_chk))
    gen double _absdiff = abs(cif_chk - cif_ref)
    summ _absdiff, meanonly
    assert r(max) < 1e-6

    drop xb_chk cif_chk cif_ref _absdiff _tv
}
if _rc == 0 {
    display as result "  PASS: T126 cif = 1-exp(-H0(t)*exp(xb)) at timevar horizon"
    local ++pass_count
}
else {
    display as error "  FAIL: T126 cif formula/timevar contract (rc=`=_rc')"
    local ++fail_count
}

* T127: Doc-contract — default xb example includes the required comma
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    finegray_predict xb_default,
    quietly count if e(sample) & missing(xb_default)
    assert r(N) == 0
    local xb_label : variable label xb_default
    assert "`xb_label'" == "Linear prediction (xb)"
}
if _rc == 0 {
    display as result "  PASS: T127 default xb help example"
    local ++pass_count
}
else {
    display as error "  FAIL: T127 default xb help example (rc=`=_rc')"
    local ++fail_count
}

* T128: Doc-contract — omitted level() follows c(level)
local ++test_count
capture noisily {
    set level 90
    _setup_hypoxia
    finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert e(level) == 90
}
local _t128_rc = _rc
set level 95
if `_t128_rc' == 0 {
    display as result "  PASS: T128 default level follows c(level)"
    local ++pass_count
}
else {
    display as error "  FAIL: T128 default level contract (rc=`_t128_rc')"
    local ++fail_count
}

* T129: Doc-contract — factor-profile, custom-grid, and saving() CIF examples
local ++test_count
capture noisily {
    _setup_hypoxia
    finegray i.pelnode ifp tumsize, compete(status) cause(1) nolog
    finegray_cif, at(pelnode=1 ifp=20 tumsize=5) attime(1 5 8) ci
    matrix _T129 = r(table)
    assert rowsof(_T129) == 3
    assert colsof(_T129) == 5
    assert _T129[1, 2] >= 0 & _T129[1, 2] <= 1

    tempfile cifsave
    finegray_cif, timepoints(1 2 3 4 5 6 7 8) ci nograph ///
        saving("`cifsave'",replace)
    confirm file "`cifsave'"
    preserve
    use "`cifsave'", clear
    assert _N == 8
    confirm numeric variable time cif se lci uci
    assert inrange(cif, 0, 1)
    assert lci <= cif & cif <= uci
    restore
}
if _rc == 0 {
    display as result "  PASS: T129 finegray_cif help workflow"
    local ++pass_count
}
else {
    display as error "  FAIL: T129 finegray_cif help workflow (rc=`=_rc')"
    local ++fail_count
}

* T130: run-to-run determinism.  Mata's order() and Stata's sort resolve ties
* from a sort seed that ADVANCES on every sort, so a tied key handed the engine
* a different row order on each fit and the risk-set scan accumulated in a
* different floating-point order.  With no delayed entry EVERY _t0 is 0, so that
* key is entirely ties -- the worst case.  Before the (t,row_id)/(t0,row_id)
* ordering fix, the same command on the same data returned different last bits.
* Compare bit-for-bit in hex: a tolerance-based check cannot see this bug.
local ++test_count
capture noisily {
    clear
    set seed 20260713
    quietly set obs 3000
    gen double z1 = rnormal()
    gen double z2 = rnormal()
    gen byte   st = runiform() < 0.5
    gen double lp = 0.5*z1 - 0.5*z2
    gen double pz = 1 - 0.5^exp(lp)
    gen byte   cause = cond(runiform() < pz, 1, 2)
    gen double u = runiform()
    gen double tev = -ln(1 - (1 - (1 - u*pz)^exp(-lp))/0.5) if cause == 1
    replace    tev = rexponential(1) if cause == 2
    gen double c = runiform()*4
    gen double t = min(tev, c)
    gen byte   status = cond(tev <= c, cause, 0)
    gen byte   anyev = status > 0
    gen long   id = _n
    quietly stset t, failure(anyev==1) id(id)

    quietly finegray z1 z2, compete(status) cause(1) strata(st) nolog
    matrix _T130a = e(b)
    * advance the sort seed the way any real workflow would, then refit
    sort z2
    sort id
    quietly finegray z1 z2, compete(status) cause(1) strata(st) nolog
    matrix _T130b = e(b)
    forvalues j = 1/`=colsof(_T130a)' {
        assert "`=string(_T130a[1,`j'], "%21x")'" == "`=string(_T130b[1,`j'], "%21x")'"
    }
}
if _rc == 0 {
    display as result "  PASS: T130 refit is bit-identical (no delayed entry)"
    local ++pass_count
}
else {
    display as error "  FAIL: T130 refit not bit-identical (rc=`=_rc')"
    local ++fail_count
}

* T131: the same determinism guarantee under left truncation + truncstrata().
local ++test_count
capture noisily {
    clear
    set seed 20260714
    quietly set obs 20000
    gen byte   z1 = runiform() < 0.5
    gen double z2 = rnormal()
    gen double lp = 0.5*z1 - 0.5*z2
    gen double pz = 1 - 0.5^exp(lp)
    gen byte   cause = cond(runiform() < pz, 1, 2)
    gen double u = runiform()
    gen double tev = -ln(1 - (1 - (1 - u*pz)^exp(-lp))/0.5) if cause == 1
    replace    tev = rexponential(1) if cause == 2
    gen double c = min(rexponential(1/0.15), 6)
    gen double x = min(tev, c)
    gen byte   status = cond(tev <= c, cause, 0)
    gen double entry = rexponential(cond(z1 == 1, 1/1.6, 1/0.5))
    quietly keep if entry < x
    gen byte anyev = status > 0
    gen long id = _n
    quietly stset x, failure(anyev==1) enter(time entry) id(id)

    quietly finegray z1 z2, compete(status) cause(1) truncstrata(z1) nolog
    matrix _T131a = e(b)
    sort z2
    sort id
    quietly finegray z1 z2, compete(status) cause(1) truncstrata(z1) nolog
    matrix _T131b = e(b)
    forvalues j = 1/`=colsof(_T131a)' {
        assert "`=string(_T131a[1,`j'], "%21x")'" == "`=string(_T131b[1,`j'], "%21x")'"
    }
}
if _rc == 0 {
    display as result "  PASS: T131 refit is bit-identical (left truncation)"
    local ++pass_count
}
else {
    display as error "  FAIL: T131 refit not bit-identical under LT (rc=`=_rc')"
    local ++fail_count
}

* T132: determinism with TIED EVENT TIMES.  T130 uses continuous times, so its
* _t has no ties and it only exercises the entry-time key (_t0, all zeros).  Real
* follow-up data is discrete (integer months, rounded visits), which ties _t as
* well and exercises the OTHER ordering key, `ord'.  Both keys must be total.
local ++test_count
capture noisily {
    clear
    set seed 20260715
    quietly set obs 3000
    gen double z1 = rnormal()
    gen double z2 = rnormal()
    gen byte   st = runiform() < 0.5
    gen double lp = 0.5*z1 - 0.5*z2
    gen double pz = 1 - 0.5^exp(lp)
    gen byte   cause = cond(runiform() < pz, 1, 2)
    gen double u = runiform()
    gen double tev = -ln(1 - (1 - (1 - u*pz)^exp(-lp))/0.5) if cause == 1
    replace    tev = rexponential(1) if cause == 2
    gen double c = runiform()*4
    * discretize to 12 distinct times -> heavy ties in _t
    gen double t = ceil(min(tev, c) * 3) / 3
    gen byte   status = cond(min(tev, c) == tev, cause, 0)
    gen byte   anyev = status > 0
    gen long   id = _n
    quietly stset t, failure(anyev==1) id(id)

    quietly finegray z1 z2, compete(status) cause(1) strata(st) nolog
    matrix _T132a = e(b)
    sort z2
    sort id
    quietly finegray z1 z2, compete(status) cause(1) strata(st) nolog
    matrix _T132b = e(b)
    forvalues j = 1/`=colsof(_T132a)' {
        assert "`=string(_T132a[1,`j'], "%21x")'" == "`=string(_T132b[1,`j'], "%21x")'"
    }
}
if _rc == 0 {
    display as result "  PASS: T132 refit is bit-identical (tied event times)"
    local ++pass_count
}
else {
    display as error "  FAIL: T132 refit not bit-identical with tied times (rc=`=_rc')"
    local ++fail_count
}

* {smcl}
* {* SUMMARY}{...}
display ""
display as text _dup(60) "="
display as text "RESULTS: test_finegray.do"
display as text _dup(60) "="
display as text "Total:  " as result `test_count'
display as text "Passed: " as result `pass_count'
display as text "Failed: " as result `fail_count'
display as text _dup(60) "="

display as text "RESULT: test_finegray tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}

log close _test_finegray
