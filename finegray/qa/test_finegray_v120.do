* test_finegray_v120.do
* Regression tests for finegray 1.2.0:
*   the finegray_phtest omnibus ("Global test") statistic is RETIRED.
*
* Before this release, finegray_phtest summed the per-covariate 1-df statistics and
* referred the total to chi2(p), returning it in r(chi2)/r(df)/r(p) and printing
* it as "Global test | chi2 df Prob>chi2".  The sum is chi2(p) only if the
* components are independent; scaled Schoenfeld residuals are correlated
* whenever the covariates are, so the printed probability had no stated
* reference distribution.  It was removed rather than relabeled.
*
* These tests FAIL on the pre-retirement code by construction: on the old code
* r(chi2)/r(df)/r(p) are populated and the "Global test" row is printed.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_v120.log", replace name(_t120)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _mk_ph_120
program define _mk_ph_120
    clear
    set seed 20260716
    quietly set obs 400
    gen long id = _n
    * Correlated covariates: the case where summing the marginal statistics is
    * provably wrong, because the residual components are correlated too.
    gen double x1 = rnormal()
    gen double x2 = 0.8 * x1 + 0.6 * rnormal()
    gen double x3 = rnormal()
    gen double t = -ln(runiform()) * exp(-0.5 * x1)
    gen byte ev = 0
    quietly replace ev = 1 if mod(_n, 3) == 0
    quietly replace ev = 2 if mod(_n, 7) == 0 & ev == 0
    quietly stset t, failure(ev) id(id)
end

**# 1. r(chi2), r(df), r(p) are no longer stored
* On the pre-retirement code all three are populated -> this block errors on the old code.
local ++test_count
capture noisily {
    _mk_ph_120
    finegray x1 x2 x3, compete(ev) cause(1) nolog
    finegray_phtest
    assert missing(r(chi2))
    assert missing(r(df))
    assert missing(r(p))
}
if _rc == 0 {
    display as result "  PASS: V120-1 omnibus scalars r(chi2)/r(df)/r(p) not stored"
    local ++pass_count
}
else {
    display as error "  FAIL: V120-1 omnibus scalars still stored (rc=`=_rc')"
    local ++fail_count
}

**# 2. The surviving return surface is intact
* Retiring the omnibus must not disturb the per-covariate payload.
local ++test_count
capture noisily {
    _mk_ph_120
    finegray x1 x2 x3, compete(ev) cause(1) nolog
    finegray_phtest, time(rank)
    assert r(N_fail) > 0 & r(N_fail) < .
    assert "`r(time)'" == "rank"
    matrix ph = r(phtest)
    assert rowsof(ph) == 3
    * FG-03: diagnostic-only surface -- two columns [correlation, events],
    * NOT [chi2, df, p].  On the pre-FG-03 code colsof(ph) == 3 and column 2 is
    * df==1, so both asserts below fail there.
    assert colsof(ph) == 2
    local cn : colnames ph
    assert "`cn'" == "correlation events"
    forvalues v = 1/3 {
        * correlation in [-1, 1]; event count positive and finite
        assert ph[`v', 1] >= -1 & ph[`v', 1] <= 1
        assert ph[`v', 2] > 0 & ph[`v', 2] < .
    }
    local rn : rowfullnames ph
    assert "`rn'" == "x1 x2 x3"
}
if _rc == 0 {
    display as result "  PASS: V120-2 per-covariate return surface unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: V120-2 per-covariate return surface (rc=`=_rc')"
    local ++fail_count
}

**# 3. No "Global test" row is printed
* The user-facing axis: r() being clean is not the same as the console being
* clean.  A suite that only checked r() would stay green if the row were still
* displayed from a stale local.
local ++test_count
capture noisily {
    _mk_ph_120
    finegray x1 x2 x3, compete(ev) cause(1) nolog
    log close _t120
    capture erase "_v120_capture.log"
    log using "_v120_capture.log", replace name(_cap) text
    finegray_phtest
    log close _cap
    log using "test_finegray_v120.log", append name(_t120)

    * Parse the captured console as DATA -- macros die r(132) on the log's own
    * quotes and brace directives.
    tempname fh
    file open `fh' using "_v120_capture.log", read text
    file read `fh' line
    * Key on the retired TABLE ROW ("Global test |"), not the bare phrase: the
    * help pointer legitimately names the retired section, and matching the
    * phrase alone made this test red against correct code.
    local sawglobal = 0
    while r(eof) == 0 {
        if regexm(`"`macval(line)'"', "Global test[ ]*\|") local sawglobal = 1
        if regexm(`"`macval(line)'"', "^Global test") local sawglobal = 1
        file read `fh' line
    }
    file close `fh'
    capture erase "_v120_capture.log"
    assert `sawglobal' == 0
}
if _rc == 0 {
    display as result "  PASS: V120-3 no Global test row printed"
    local ++pass_count
}
else {
    display as error "  FAIL: V120-3 Global test row still printed (rc=`=_rc')"
    local ++fail_count
}

**# 4. The retired sum is not silently relocated into r(phtest)
* r(phtest) must stay p x 3 -- no appended global row.
local ++test_count
capture noisily {
    _mk_ph_120
    finegray x1 x2 x3, compete(ev) cause(1) nolog
    finegray_phtest
    matrix ph = r(phtest)
    assert rowsof(ph) == 3
    local rn : rowfullnames ph
    assert strpos("`rn'", "Global") == 0
    assert strpos("`rn'", "global") == 0
}
if _rc == 0 {
    display as result "  PASS: V120-4 no global row appended to r(phtest)"
    local ++pass_count
}
else {
    display as error "  FAIL: V120-4 global row in r(phtest) (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_v120 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _t120
    exit 1
}
display as result "ALL TESTS PASSED"
log close _t120
