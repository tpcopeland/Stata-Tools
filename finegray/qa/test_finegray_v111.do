* test_finegray_v111.do
* Regression tests for finegray 1.1.1:
*   - post-estimation parity between a single-record fit and the equivalent
*     multi-record (stsplit) fit: finegray_cif, finegray_phtest, predict cif ci
*   - bootstrap paths after a multi-record fit (refits see true entry times)
*   - e(sample) survives finegray_cif, bootstrap() (hold-before-preserve fix)
*   - _fg_entry lifecycle: created + char on reduced fits, cleared on
*     single-record refits and on error, user-owned name collision rejected
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

**# Summary
display as text _newline "RESULT: test_finegray_v111 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _t111
    exit 1
}
display as result "ALL TESTS PASSED"
log close _t111
