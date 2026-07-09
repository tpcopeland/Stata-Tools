* test_finegray_v111.do
* Regression tests for finegray 1.1.1:
*   - post-estimation parity between a single-record fit and the equivalent
*     multi-record (stsplit) fit: finegray_cif, finegray_phtest, predict cif ci
*   - bootstrap paths after a multi-record fit (refits see true entry times)
*   - e(sample) survives finegray_cif, bootstrap() (hold-before-preserve fix)
*   - _fg_entry lifecycle: created + char on reduced fits, cleared on
*     single-record refits and on error, user-owned name collision rejected
*   - string id() bootstrap: finegray_cif / finegray_predict bootstrap() no
*     longer crash r(109) with a string stset id(); no char/type leak; the
*     resampled table matches the numeric-id path under the same seed
*   - cluster bootstrap resamples whole clusters (SE inflated vs subject
*     resampling) when the fit declared cluster()
*   - finegray_cif at() accepts factor variables by their natural name,
*     mapping the level onto the internal _fg_* dummies
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_v111.log", replace name(_t111)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Helpers
program define _mk_hypoxia
    local cache "`c(tmpdir)'/finegray_hypoxia_cache.dta"
    capture confirm file "`cache'"
    if _rc {
        webuse hypoxia, clear
        quietly save "`cache'", replace
    }
    else {
        use "`cache'", clear
    }
    gen byte status = failtype
end

**# ---------------------------------------------------------------
**# 1. finegray_cif parity: single-record fit vs stsplit fit
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    quietly finegray_cif, attime(2 5 8) ci
    matrix C1 = r(table)

    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    stsplit iv, at(2 4 6 8)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    quietly finegray_cif, attime(2 5 8) ci
    matrix C2 = r(table)

    assert mreldif(C1, C2) < 1e-9
}
if _rc == 0 {
    display as result "  PASS: finegray_cif parity after stsplit reduction"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_cif parity after stsplit reduction (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 2. finegray_phtest parity: single-record fit vs stsplit fit
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    quietly finegray_phtest
    scalar ph1 = r(chi2)
    matrix P1 = r(phtest)

    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    stsplit iv, at(2 4 6 8)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    quietly finegray_phtest
    scalar ph2 = r(chi2)
    matrix P2 = r(phtest)

    assert reldif(ph1, ph2) < 1e-9
    assert mreldif(P1, P2) < 1e-9
}
if _rc == 0 {
    display as result "  PASS: finegray_phtest parity after stsplit reduction"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_phtest parity after stsplit reduction (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 3. predict cif ci parity per subject: single-record vs stsplit fit
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    gen double t5 = 5
    quietly finegray_predict cifA, cif timevar(t5) ci
    preserve
    quietly keep if !missing(cifA)
    keep stnum cifA cifA_lci cifA_uci
    tempfile single
    quietly save `single'
    restore

    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    stsplit iv, at(2 4 6 8)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    gen double t5 = 5
    quietly finegray_predict cifB, cif timevar(t5) ci
    quietly keep if !missing(cifB)
    quietly merge 1:1 stnum using `single', assert(match) nogenerate
    assert reldif(cifA, cifB) < 1e-9
    assert reldif(cifA_lci, cifB_lci) < 1e-9
    assert reldif(cifA_uci, cifB_uci) < 1e-9
}
if _rc == 0 {
    display as result "  PASS: predict cif ci per-subject parity after stsplit"
    local ++pass_count
}
else {
    display as error "  FAIL: predict cif ci per-subject parity after stsplit (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 4. e(sample) survives finegray_cif bootstrap; post-estimation still works
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    scalar Nfit = e(N)
    quietly finegray_cif, attime(5) ci bootstrap(30) seed(11)
    assert "`e(cmd)'" == "finegray"
    quietly count if e(sample)
    assert r(N) == Nfit
    * a recomputation-path command must still run after the bootstrap
    quietly finegray_phtest
    assert r(df) == 3
}
if _rc == 0 {
    display as result "  PASS: e(sample) intact after finegray_cif bootstrap"
    local ++pass_count
}
else {
    display as error "  FAIL: e(sample) intact after finegray_cif bootstrap (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 5. bootstrap after stsplit fit: both commands, refits on true entry times
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    stsplit iv, at(2 4 6 8)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    scalar Nfit = e(N)
    quietly finegray_cif, attime(5) ci
    matrix A = r(table)
    quietly finegray_cif, attime(5) ci bootstrap(100) seed(42)
    matrix B = r(table)
    * point CIF unchanged; bootstrap SE close to the analytic SE (the refits
    * would roughly triple it if they treated kept records as late entries)
    assert reldif(A[1,2], B[1,2]) < 1e-10
    assert B[1,3] > 0
    assert abs(B[1,3]/A[1,3] - 1) < 0.35
    quietly count if e(sample)
    assert r(N) == Nfit

    gen double t5 = 5
    quietly finegray_predict cbb, cif timevar(t5) ci bootstrap(60) seed(7)
    assert "`e(cmd)'" == "finegray"
    assert cbb_lci <= cbb + 1e-9 if !missing(cbb)
    assert cbb <= cbb_uci + 1e-9 if !missing(cbb)
    quietly count if !missing(cbb)
    assert r(N) == Nfit
}
if _rc == 0 {
    display as result "  PASS: bootstrap paths after stsplit reduction"
    local ++pass_count
}
else {
    display as error "  FAIL: bootstrap paths after stsplit reduction (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 6. _fg_entry lifecycle: created on reduced fit, cleared on refit/error
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    stsplit iv, at(2 4 6 8)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    confirm variable _fg_entry
    assert `"`_dta[_finegray_entryvar]'"' == "_fg_entry"

    * single-record refit drops the stale entry variable and clears the char
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    stsplit iv, at(2 4 6 8)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    drop iv
    quietly stjoin
    assert _N == e(N)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    capture confirm variable _fg_entry
    assert _rc != 0
    assert `"`_dta[_finegray_entryvar]'"' == ""

    * error after reduction must not leave _fg_entry behind
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    stsplit iv, at(2 4 6 8)
    capture finegray ifp tumsize pelnode, compete(status) cause(9)
    assert _rc == 198
    capture confirm variable _fg_entry
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: _fg_entry lifecycle (create/clear/error)"
    local ++pass_count
}
else {
    display as error "  FAIL: _fg_entry lifecycle (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 7. user-owned _fg_entry rejected without touching the variable
**# ---------------------------------------------------------------
local ++test_count
capture {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    stsplit iv, at(2 4 6 8)
    gen double _fg_entry = 99
    capture finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    assert _rc == 198
    confirm variable _fg_entry
    assert _fg_entry == 99
}
if _rc == 0 {
    display as result "  PASS: user-owned _fg_entry collision rejected (198)"
    local ++pass_count
}
else {
    display as error "  FAIL: user-owned _fg_entry collision rejected"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 8. multi-variable strata() through the CIF SE paths: must equal a
**#    single pre-combined group variable (and not error)
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    gen byte grp = mod(stnum, 2)
    stset dftime, failure(dfcens==1) id(stnum)
    quietly finegray ifp tumsize, compete(status) cause(1) strata(pelnode grp) nolog
    quietly finegray_cif, attime(5) ci
    matrix S2 = r(table)
    gen double t5 = 5
    quietly finegray_predict cs2, cif timevar(t5) ci

    egen long sgrp = group(pelnode grp)
    quietly finegray ifp tumsize, compete(status) cause(1) strata(sgrp) nolog
    quietly finegray_cif, attime(5) ci
    matrix S1 = r(table)
    quietly finegray_predict cs1, cif timevar(t5) ci

    assert mreldif(S1, S2) < 1e-9
    assert reldif(cs1, cs2) < 1e-9 if !missing(cs1)
    assert reldif(cs1_lci, cs2_lci) < 1e-9 if !missing(cs1)
    assert reldif(cs1_uci, cs2_uci) < 1e-9 if !missing(cs1)
}
if _rc == 0 {
    display as result "  PASS: multi-variable strata() CIF SE paths"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-variable strata() CIF SE paths (rc=`=_rc')"
    local ++fail_count
}

* Multi-variable strata() under bootstrap() SEs.  The analytical path above
* exercises the ng>1 censoring-KM prefix sums; the bootstrap path re-fits inside
* a frame and must agree with it to within Monte Carlo error.
local ++test_count
capture noisily {
    _mk_hypoxia
    gen byte grp = mod(stnum, 2)
    stset dftime, failure(dfcens==1) id(stnum)
    quietly finegray ifp tumsize, compete(status) cause(1) strata(pelnode grp) nolog
    quietly finegray_cif, attime(5) ci
    matrix A = r(table)
    scalar _an_cif = A[1, 2]
    scalar _an_se  = A[1, 3]
    quietly finegray_cif, attime(5) ci bootstrap(60) seed(20260710)
    matrix B = r(table)
    assert r(bootstrap_success) > 1
    * The point estimate is the full-sample fit either way.
    assert reldif(B[1, 2], _an_cif) < 1e-8
    * Bootstrap SE is independent of the ng>1 prefix-sum path but must land in
    * the same ballpark as the analytical SE.
    assert B[1, 3] > 0 & B[1, 3] < .
    assert reldif(B[1, 3], _an_se) < 0.5
    assert B[1, 4] < B[1, 2] & B[1, 2] < B[1, 5]

    gen double t5 = 5
    quietly finegray_predict cbs, cif timevar(t5) ci bootstrap(60) seed(20260710)
    quietly count if !missing(cbs) & cbs_lci < cbs & cbs < cbs_uci
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: multi-variable strata() bootstrap CIF SE paths"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-variable strata() bootstrap CIF SE (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 9. string id() bootstrap: no r(109) crash, positive SE, no leak
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    gen str8 sid = "S" + string(stnum)
    stset dftime, failure(dfcens==1) id(sid)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    * finegray_cif bootstrap used to die with r(109) (replace strvar = _n)
    quietly finegray_cif, attime(2 5) ci bootstrap(30) seed(1)
    matrix Bstr = r(table)
    assert Bstr[1,3] > 0 & Bstr[2,3] > 0
    * finegray_predict bootstrap likewise
    quietly finegray_predict cstr, cif ci bootstrap(30) seed(1)
    quietly count if !missing(cstr)
    assert r(N) > 0
    assert cstr_lci <= cstr + 1e-9 if !missing(cstr)
    assert cstr <= cstr_uci + 1e-9 if !missing(cstr)
    * the caller's string id survives untouched (no char repoint / type leak)
    assert `"`_dta[st_id]'"' == "sid"
    capture confirm string variable sid
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: string id() bootstrap (no r(109), no leak)"
    local ++pass_count
}
else {
    display as error "  FAIL: string id() bootstrap (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 10. string-id bootstrap equals numeric-id path under the same seed
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    quietly finegray_cif, attime(2 5) ci bootstrap(40) seed(99)
    matrix Bnum = r(table)

    _mk_hypoxia
    gen str8 sid = "S" + string(stnum)
    stset dftime, failure(dfcens==1) id(sid)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    quietly finegray_cif, attime(2 5) ci bootstrap(40) seed(99)
    matrix Bstr2 = r(table)
    * same rows, same seed, unique ids either way -> identical refits
    assert mreldif(Bnum, Bstr2) < 1e-7
}
if _rc == 0 {
    display as result "  PASS: string-id bootstrap matches numeric-id path"
    local ++pass_count
}
else {
    display as error "  FAIL: string-id bootstrap matches numeric-id path (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 11. cluster bootstrap resamples clusters (SE inflated vs subjects)
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    * Strong shared cluster frailty, few clusters: cluster resampling must
    * produce a substantially larger bootstrap SE than subject resampling.
    clear
    set seed 20260707
    set obs 240
    gen long cl = ceil(_n/40)
    by cl, sort: gen double u = rnormal()*1.4 if _n==1
    by cl: replace u = u[1]
    gen double x = rnormal()
    gen double lp = 0.5*x + u
    gen double tt = -ln(runiform())/exp(lp)
    gen double cc = runiform()*3
    gen double time = min(tt, cc)
    gen byte status = cond(tt<=cc, cond(runiform()<0.7,1,2), 0)
    gen long id = _n
    stset time, failure(status) id(id)

    * cluster fit -> cluster resampling (the fix)
    quietly finegray x, compete(status) cause(1) cluster(cl) nolog
    quietly finegray_cif, attime(1) ci bootstrap(200) seed(123)
    matrix Tc = r(table)
    scalar se_c = Tc[1,3]

    * same data, no-cluster fit -> subject resampling (pre-fix behavior)
    quietly finegray x, compete(status) cause(1) nolog
    quietly finegray_cif, attime(1) ci bootstrap(200) seed(123)
    matrix Ts = r(table)
    scalar se_s = Ts[1,3]

    assert se_c > 0 & se_s > 0
    * observed ratio ~2.3; old subject-resampling code would give ~1.0
    assert se_c / se_s > 1.5

    * finegray_predict has its own bsample site: cluster CIs must be wider too
    quietly finegray x, compete(status) cause(1) cluster(cl) nolog
    quietly finegray_predict pc, cif ci bootstrap(150) seed(5)
    gen double wc = pc_uci - pc_lci
    quietly summarize wc, meanonly
    scalar wcm = r(mean)
    drop pc pc_lci pc_uci wc
    quietly finegray x, compete(status) cause(1) nolog
    quietly finegray_predict ps, cif ci bootstrap(150) seed(5)
    gen double ws = ps_uci - ps_lci
    quietly summarize ws, meanonly
    assert wcm / r(mean) > 1.3
}
if _rc == 0 {
    display as result "  PASS: cluster bootstrap resamples clusters (SE inflated)"
    local ++pass_count
}
else {
    display as error "  FAIL: cluster bootstrap resamples clusters (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 12. finegray_cif at() by factor natural name (binary factor)
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    stset dftime, failure(dfcens==1) id(stnum)
    quietly finegray i.pelnode c.ifp, compete(status) cause(1) nolog

    * natural name == internal dummy name
    quietly finegray_cif, at(pelnode=1 ifp=20) attime(5)
    matrix Fn = r(table)
    matrix an = r(at)
    quietly finegray_cif, at(_fg_pelnode_1=1 ifp=20) attime(5)
    matrix Fi = r(table)
    assert mreldif(Fn, Fi) < 1e-9
    assert an[1,1] == 1

    * reference level sets the dummy to 0
    quietly finegray_cif, at(pelnode=0 ifp=20) attime(5)
    matrix ar = r(at)
    assert ar[1,1] == 0

    * invalid level and unknown var both rejected
    capture finegray_cif, at(pelnode=9 ifp=20) attime(5)
    assert _rc == 198
    capture finegray_cif, at(nosuchvar=1) attime(5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: finegray_cif at() factor natural name"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_cif at() factor natural name (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 13. at() multi-level factor coherence + interaction rejection
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    _mk_hypoxia
    gen byte grp3 = mod(stnum, 3)
    stset dftime, failure(dfcens==1) id(stnum)
    quietly finegray i.grp3 ifp, compete(status) cause(1) nolog
    * covariates: _fg_grp3_1 _fg_grp3_2 ifp

    * natural at(grp3=2) drives a coherent single-level profile (0,1)
    quietly finegray_cif, at(grp3=2 ifp=20) attime(5)
    matrix g2 = r(at)
    assert g2[1,1] == 0 & g2[1,2] == 1

    * equals the explicit coherent internal profile
    quietly finegray_cif, at(_fg_grp3_1=0 _fg_grp3_2=1 ifp=20) attime(5)
    matrix gi = r(table)
    quietly finegray_cif, at(grp3=2 ifp=20) attime(5)
    matrix gn = r(table)
    assert mreldif(gi, gn) < 1e-9

    * reference level zeros every dummy
    quietly finegray_cif, at(grp3=0 ifp=20) attime(5)
    matrix g0 = r(at)
    assert g0[1,1] == 0 & g0[1,2] == 0

    * a factor entering an interaction is rejected by natural name
    quietly finegray i.grp3##c.ifp, compete(status) cause(1) nolog
    capture finegray_cif, at(grp3=2) attime(5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: at() multi-level coherence + interaction guard"
    local ++pass_count
}
else {
    display as error "  FAIL: at() multi-level coherence + interaction guard (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline "RESULT: test_finegray_v111 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _t111
    exit 1
}
display as result "ALL TESTS PASSED"
log close _t111
