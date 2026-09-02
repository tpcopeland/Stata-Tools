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
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
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

**# FG03-4  the printed Variable column carries the FULL design name
* WATCHED FAIL 2026-09-01.  The table printed abbrev(name, 12) in a fixed %12s
* column, so every design name over twelve characters reached the reader as a
* tilde stub: the two 29-character covariates below printed as
* "aaaaaaa~e_x1" and "aaaaaaa~f_x1", differing in one character, while
* r(phtest) carried both names in full.  Two terms whose difference falls
* inside the discarded middle print IDENTICALLY, and the row the reader acts on
* is then whichever he guesses.  The column is now widened to the longest
* design name (floor 12, cap 32), so nothing is dropped.
*
* The probe reads the command's own output back out of a log file and asserts
* the FULL names are present and the tilde-abbreviated forms are not; asserting
* on r(phtest) alone would pass on the pre-fix build, because the returned
* matrix was already correct.  It is the DISPLAY that was lossy.
local ++test_count
capture noisily {
    clear
    set seed 20260901
    quietly set obs 500
    gen long id = _n
    gen byte g = 1 + floor(2 * runiform())
    * 29 characters each, differing only in the middle
    gen double aaaaaaaaaa_bbb_ccc_ddd_eee_x1 = rnormal()
    gen double aaaaaaaaaa_bbb_ccc_ddd_fff_x1 = rnormal()
    gen double t = 1 + floor(8 * runiform())
    gen byte status = cond(runiform() < .45, 1, cond(runiform() < .5, 2, 0))
    quietly stset t, failure(status) id(id)
    quietly finegray i.g aaaaaaaaaa_bbb_ccc_ddd_eee_x1 aaaaaaaaaa_bbb_ccc_ddd_fff_x1, compete(status) cause(1) nolog

    tempfile phlog
    capture log close _fg03ph
    quietly log using "`phlog'", replace text name(_fg03ph)
    finegray_phtest
    * Grab r(phtest) NOW.  `capture' resets r(), so a `capture log close' between
    * the command and this line silently hands back an empty matrix -- measured:
    * rownames came back as "r1".
    tempname P
    matrix `P' = r(phtest)
    capture log close _fg03ph

    tempname fh
    local blob ""
    file open `fh' using "`phlog'", read text
    file read `fh' line
    while r(eof) == 0 {
        local blob `"`blob' `line'"'
        file read `fh' line
    }
    file close `fh'
    display as text "  full name 1 printed: " (strpos(`"`blob'"', "aaaaaaaaaa_bbb_ccc_ddd_eee_x1") > 0)
    display as text "  full name 2 printed: " (strpos(`"`blob'"', "aaaaaaaaaa_bbb_ccc_ddd_fff_x1") > 0)
    display as text "  a tilde stub printed:  " (strpos(`"`blob'"', "aaaaaaa~") > 0)
    assert strpos(`"`blob'"', "aaaaaaaaaa_bbb_ccc_ddd_eee_x1") > 0
    assert strpos(`"`blob'"', "aaaaaaaaaa_bbb_ccc_ddd_fff_x1") > 0
    * no truncated form of either name reaches the reader
    assert strpos(`"`blob'"', "aaaaaaa~") == 0

    * r(phtest) was already right and must stay right
    local rn : rownames `P'
    display as text "  r(phtest) rownames: `rn'"
    assert strpos("`rn'", "aaaaaaaaaa_bbb_ccc_ddd_eee_x1") > 0
    assert strpos("`rn'", "aaaaaaaaaa_bbb_ccc_ddd_fff_x1") > 0

    * a short-name fit is unchanged: the column keeps its 12-character floor
    quietly finegray i.g, compete(status) cause(1) nolog
    capture log close _fg03ph
    quietly log using "`phlog'", replace text name(_fg03ph)
    finegray_phtest
    capture log close _fg03ph
    local blob2 ""
    file open `fh' using "`phlog'", read text
    file read `fh' line
    while r(eof) == 0 {
        local blob2 `"`blob2' `line'"'
        file read `fh' line
    }
    file close `fh'
    assert strpos(`"`blob2'"', "2.g") > 0
}
if _rc == 0 {
    display as result "  PASS: FG03-4 phtest prints full design names, no abbrev() collision"
    local ++pass_count
}
else {
    display as error "  FAIL: FG03-4 phtest name column (rc=`=_rc')"
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
