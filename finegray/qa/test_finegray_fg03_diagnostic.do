* test_finegray_fg03_diagnostic.do
* Regression tests for finegray_phtest as a DIAGNOSTIC-ONLY command (FG-03).
*
* finegray_phtest formerly printed chi2 = n*rho^2, df = 1, and Prob>chi2 for a
* statistic whose own help conceded had no published subdistribution-hazard null
* calibration.  It now reports only the scaled-Schoenfeld/time CORRELATION as an
* exploratory diagnostic: no chi2, no df, no p-value, in the display OR in
* r(phtest).  These tests FAIL on the pre-FG-03 code, where a "Prob>chi2" column
* is printed and r(phtest) is a p x 3 [chi2, df, p] matrix.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_fg03_diagnostic.log", replace name(_fg03)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _mk_fg03
program define _mk_fg03
    clear
    set seed 20260716
    quietly set obs 400
    gen long id = _n
    gen double x1 = rnormal()
    gen double x2 = 0.8 * x1 + 0.6 * rnormal()
    gen double x3 = rnormal()
    gen double t = -ln(runiform()) * exp(-0.5 * x1)
    gen byte ev = 0
    quietly replace ev = 1 if mod(_n, 3) == 0
    quietly replace ev = 2 if mod(_n, 7) == 0 & ev == 0
    quietly stset t, failure(ev) id(id)
end

**# 1. r(phtest) is the diagnostic surface [correlation, events], not [chi2,df,p]
local ++test_count
capture noisily {
    _mk_fg03
    finegray x1 x2 x3, compete(ev) cause(1) nolog
    finegray_phtest
    matrix ph = r(phtest)
    assert colsof(ph) == 2
    local cn : colnames ph
    assert "`cn'" == "correlation events"
    * no p-value / chi2 / df scalar leaks
    assert missing(r(chi2))
    assert missing(r(df))
    assert missing(r(p))
    * correlations are in [-1, 1]
    forvalues v = 1/3 {
        assert ph[`v', 1] >= -1 & ph[`v', 1] <= 1
    }
}
if _rc == 0 {
    display as result "  PASS: FG03-1 r(phtest) is diagnostic [correlation, events]"
    local ++pass_count
}
else {
    display as error "  FAIL: FG03-1 r(phtest) surface (rc=`=_rc')"
    local ++fail_count
}

**# 2. The console prints NO chi2 / Prob>chi2 column (display-level contract)
* r() being clean is not enough: a stale display path could still print a
* p-value.  Parse the captured console as DATA.
local ++test_count
capture noisily {
    _mk_fg03
    finegray x1 x2 x3, compete(ev) cause(1) nolog
    log close _fg03
    capture erase "_fg03_capture.log"
    log using "_fg03_capture.log", replace name(_cap) text
    finegray_phtest
    log close _cap
    log using "test_finegray_fg03_diagnostic.log", append name(_fg03)

    tempname fh
    file open `fh' using "_fg03_capture.log", read text
    file read `fh' line
    local saw_p = 0
    while r(eof) == 0 {
        if regexm(`"`macval(line)'"', "Prob *> *chi2") local saw_p = 1
        if regexm(`"`macval(line)'"', "Prob *> *chi") local saw_p = 1
        file read `fh' line
    }
    file close `fh'
    capture erase "_fg03_capture.log"
    assert `saw_p' == 0
}
if _rc == 0 {
    display as result "  PASS: FG03-2 no Prob>chi2 column printed"
    local ++pass_count
}
else {
    display as error "  FAIL: FG03-2 Prob>chi2 still printed (rc=`=_rc')"
    local ++fail_count
}

**# 3. The diagnostic still refuses when a residual does not vary (r(459) guard)
* FG-03 must not weaken the pre-existing no-variation guard.
local ++test_count
capture noisily {
    clear
    set seed 42
    quietly set obs 200
    gen long id = _n
    gen double x1 = rnormal()
    * all cause events at a single time -> correlation undefined
    gen double t = 5
    gen byte ev = cond(mod(_n,3)==0, 1, cond(mod(_n,5)==0, 2, 0))
    quietly stset t, failure(ev) id(id)
    quietly finegray x1, compete(ev) cause(1) nolog
    capture finegray_phtest
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: FG03-3 undefined-diagnostic guard still fires (459)"
    local ++pass_count
}
else {
    display as error "  FAIL: FG03-3 no-variation guard (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_fg03_diagnostic tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fg03
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fg03
