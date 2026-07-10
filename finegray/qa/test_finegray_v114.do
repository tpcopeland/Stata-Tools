* test_finegray_v114.do
* Regression tests for finegray 1.1.4 fixes:
*   1. bootstrap refits that lose a factor level are skipped (not mispaired
*      in finegray_cif, not a Mata conformability crash in finegray_predict)
*   2. finegray_cif saving(filename,replace) accepted without a space
*   3. finegray_predict drops its created variables when it exits with error
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_v114.log", replace name(_t114)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* Competing-risks data with a rare factor level (level 3: two subjects), so
* that bootstrap resamples can lose the level and the refit posts a shorter
* coefficient vector.
capture program drop _mk_rarelvl_114
program define _mk_rarelvl_114
    clear
    set seed 42
    quietly set obs 120
    gen long id = _n
    gen byte grp = 1 + (_n > 60) + (_n >= 119)
    gen double x = rnormal()
    gen double t = -ln(runiform()) * 2
    gen byte ev = 0
    quietly replace ev = 1 if mod(_n, 3) == 0
    quietly replace ev = 2 if mod(_n, 5) == 0 & ev == 0
    quietly stset t, failure(ev) id(id)
end

**# 1. finegray_cif bootstrap skips level-dropping refits
* Pre-1.1.4 these replications "succeeded" while silently pairing the shorter
* refit e(b) against the full covariate profile; the skip is the regression
* signal: at least one replication must now be counted as failed.
local ++test_count
capture noisily {
    _mk_rarelvl_114
    quietly finegray i.grp x, compete(ev) cause(1) nolog
    finegray_cif, attime(1) ci bootstrap(20) seed(7) nograph
    assert r(bootstrap_requested) == 20
    assert r(bootstrap_failed) > 0
    assert r(bootstrap_success) >= 2
    assert r(bootstrap_success) + r(bootstrap_failed) == 20
    matrix _T114 = r(table)
    assert _T114[1, 3] > 0 & _T114[1, 3] < .
    matrix drop _T114
}
if _rc == 0 {
    display as result "  PASS: finegray_cif bootstrap skips level-dropping refits"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_cif bootstrap level-drop guard (rc=`=_rc')"
    local ++fail_count
}

**# 2. finegray_predict bootstrap survives level-dropping refits
* Pre-1.1.4 this aborted with a Mata conformability error r(3200).
local ++test_count
capture noisily {
    _mk_rarelvl_114
    quietly finegray i.grp x, compete(ev) cause(1) nolog
    gen double t1 = 1
    finegray_predict cb, cif timevar(t1) ci bootstrap(20) seed(7)
    confirm variable cb
    confirm variable cb_lci
    confirm variable cb_uci
    quietly count if cb < . & cb_lci < . & cb_uci < . & e(sample)
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: finegray_predict bootstrap skips level-dropping refits"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_predict bootstrap level-drop guard (rc=`=_rc')"
    local ++fail_count
}

**# 3. saving(filename,replace) without a space after the comma
local ++test_count
capture noisily {
    _mk_rarelvl_114
    quietly finegray i.grp x, compete(ev) cause(1) nolog
    local _sv "`c(tmpdir)'/fg114_save.dta"
    capture erase "`_sv'"
    finegray_cif, nograph saving("`_sv'",replace)
    confirm file "`_sv'"
    * spaced form still works, replace honored
    finegray_cif, nograph saving("`_sv'", replace)
    confirm file "`_sv'"
    erase "`_sv'"
    * junk suboptions are still rejected
    capture finegray_cif, nograph saving("`_sv'", junk)
    assert _rc == 198
    capture confirm file "`_sv'"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: saving(filename,replace) comma parsing"
    local ++pass_count
}
else {
    display as error "  FAIL: saving(filename,replace) comma parsing (rc=`=_rc')"
    local ++fail_count
}

**# 4. finegray_predict drops created variables on error
* A pre-existing <newvar>_lci makes the ci path fail after the point CIF has
* been generated; the failed call must not leave the point CIF behind.
local ++test_count
capture noisily {
    _mk_rarelvl_114
    quietly finegray i.grp x, compete(ev) cause(1) nolog
    gen double pc_lci = .
    capture finegray_predict pc, cif ci
    assert _rc == 110
    capture confirm variable pc
    assert _rc != 0
    capture confirm variable pc_uci
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: finegray_predict all-or-nothing output on error"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_predict error-path variable cleanup (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_v114 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _t114
    exit 1
}
display as result "ALL TESTS PASSED"
log close _t114
