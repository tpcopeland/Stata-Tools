clear all
version 16.0
set varabbrev off

* test_iivw_v180_regressions.do - regressions for v1.8.0 features
*
* Coverage:
*   T1  iivw_fit, bootstrap() refitweights (IIW) sets e(iivw_refitweights)=1
*   T2  refit and fixed-weight bootstrap share the point estimate but differ in SE
*   T3  contract survival: _dta[_iivw_id]/_iivw_weight_var unchanged after refit
*       bootstrap (guards the per-replicate iivw_weight char-leak fix)
*   T4  iivw_fit, bootstrap() refitweights (FIPTIW) sets e(iivw_refitweights)=1
*   T5  refitweights without bootstrap() errors (rc 198)
*   T6  refitweights + unweighted errors (rc 198)
*   T7  refitweights + a cluster() other than the panel id errors (rc 198)
*   T8  stabilization nudge prints when stabcov() is omitted (IIW)
*   T9  stabilization nudge is absent when stabcov() is supplied
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_v180_regressions.do

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_v180_regressions.do must be run from iivw/qa"
    exit 198
}
* Sysdir sandbox + path resolution (Q3/Q8): the sandbox keeps this suite's
* net install out of the USER's real ado tree even when run standalone, and
* the "/qa" suffix is stripped by length, not by first-occurrence subinstr()
* (which mangles any path whose ancestors contain "qa").
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"
local repo_dir "`r(repo_dir)'"

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Balanced panel: 40 subjects, 3 visits each, time-invariant binary treat.
capture program drop _iivw_v180_panel
program define _iivw_v180_panel
    version 16.0
    clear
    set obs 40
    gen long id = _n
    gen double sev = sin(id / 3) + 5
    gen byte treat = mod(id, 2)
    expand 3
    bysort id: gen int visit = _n
    gen double days = visit * 30 + mod(id, 7)
    gen double y = sev + 0.3 * visit + 0.5 * treat + cos(id + visit)
end

* Helper: does a text log file contain a given substring?
capture program drop _iivw_v180_log_has
program define _iivw_v180_log_has, rclass
    version 16.0
    gettoken fn rest : 0
    local needle = strtrim(`"`rest'"')
    tempname fh
    local found 0
    file open `fh' using `fn', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "`needle'") > 0 local found 1
        file read `fh' line
    }
    file close `fh'
    return scalar found = `found'
end

**# T1: IIW refit bootstrap sets e(iivw_refitweights)=1

local ++test_count
capture noisily {
    _iivw_v180_panel
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(sev) wtype(iivw) nolog
    set seed 180180
    iivw_fit y treat, model(gee) timespec(linear) bootstrap(15) refitweights nolog
    assert "`e(iivw_refitweights)'" == "1"
    assert e(N) > 0
}
if _rc == 0 {
    display as result "  PASS: T1 - IIW refit bootstrap sets e(iivw_refitweights)=1"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - IIW refit bootstrap (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

**# T2: refit and fixed bootstrap share point estimate, differ in SE

local ++test_count
capture noisily {
    _iivw_v180_panel
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(sev) wtype(iivw) nolog

    set seed 180180
    iivw_fit y treat, model(gee) timespec(linear) bootstrap(40) refitweights nolog
    local b_refit  = _b[treat]
    local se_refit = _se[treat]

    set seed 180180
    iivw_fit y treat, model(gee) timespec(linear) bootstrap(40) nolog replace
    local b_fixed  = _b[treat]
    local se_fixed = _se[treat]

    * Observed point estimate is the same weighted fit either way
    assert reldif(`b_refit', `b_fixed') < 1e-4
    * SEs must differ: refitting the weights changes the resampling distribution
    assert reldif(`se_refit', `se_fixed') > 1e-6
    * fixed-weight fit records the mode as 0
    assert "`e(iivw_refitweights)'" == "0"
}
if _rc == 0 {
    display as result "  PASS: T2 - refit vs fixed: equal point, different SE"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - refit vs fixed SE/point contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

**# T3: contract survives a refit bootstrap (guards the char-leak fix)

local ++test_count
capture noisily {
    _iivw_v180_panel
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(sev) wtype(iivw) nolog
    local id_before     : char _dta[_iivw_id]
    local wvar_before   : char _dta[_iivw_weight_var]
    local time_before   : char _dta[_iivw_time]

    set seed 180180
    iivw_fit y treat, model(gee) timespec(linear) bootstrap(15) refitweights nolog

    local id_after   : char _dta[_iivw_id]
    local wvar_after : char _dta[_iivw_weight_var]
    local time_after : char _dta[_iivw_time]
    assert "`id_after'"   == "`id_before'"   & "`id_after'"   == "id"
    assert "`wvar_after'" == "`wvar_before'" & "`wvar_after'" == "_iivw_weight"
    assert "`time_after'" == "`time_before'" & "`time_after'" == "days"

    * a subsequent fit on the restored contract still works
    iivw_fit y treat, model(gee) timespec(linear) nolog replace
    assert e(N) > 0
}
if _rc == 0 {
    display as result "  PASS: T3 - weighting contract survives refit bootstrap"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - contract char-leak guard (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

**# T4: FIPTIW refit bootstrap sets e(iivw_refitweights)=1

local ++test_count
capture noisily {
    _iivw_v180_panel
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(sev) ///
        treat(treat) treat_cov(sev) truncate(1 99) nolog
    set seed 180180
    iivw_fit y treat sev, model(gee) timespec(linear) bootstrap(15) refitweights nolog
    assert "`e(iivw_refitweights)'" == "1"
    assert e(N) > 0
}
if _rc == 0 {
    display as result "  PASS: T4 - FIPTIW refit bootstrap sets e(iivw_refitweights)=1"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - FIPTIW refit bootstrap (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

**# T5: refitweights without bootstrap() errors (rc 198)

local ++test_count
capture noisily {
    _iivw_v180_panel
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(sev) wtype(iivw) nolog
    capture iivw_fit y treat, model(gee) refitweights nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T5 - refitweights without bootstrap errors (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - refitweights-without-bootstrap guard (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}

**# T6: refitweights + unweighted errors (rc 198)

local ++test_count
capture noisily {
    _iivw_v180_panel
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(sev) wtype(iivw) nolog
    capture iivw_fit y treat, unweighted id(id) time(days) ///
        bootstrap(15) refitweights nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T6 - refitweights + unweighted errors (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - refitweights + unweighted guard (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}

**# T7: refitweights + foreign cluster() errors (rc 198)

local ++test_count
capture noisily {
    _iivw_v180_panel
    gen long clinic = mod(id, 5)
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(sev) wtype(iivw) nolog
    capture iivw_fit y treat, model(gee) bootstrap(15) refitweights cluster(clinic) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T7 - refitweights + foreign cluster errors (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - refitweights foreign-cluster guard (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T7"
}

**# T8: stabilization nudge prints when stabcov() is omitted

local ++test_count
capture noisily {
    _iivw_v180_panel
    tempfile tlog8
    quietly log using "`tlog8'", replace text name(nudge8)
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(sev) wtype(iivw) nolog
    quietly log close nudge8
    _iivw_v180_log_has "`tlog8'" unstabilized
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: T8 - stabilization nudge prints without stabcov()"
    local ++pass_count
}
else {
    capture log close nudge8
    display as error "  FAIL: T8 - stabilization nudge present (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T8"
}

**# T9: stabilization nudge absent when stabcov() is supplied

local ++test_count
capture noisily {
    _iivw_v180_panel
    tempfile tlog9
    quietly log using "`tlog9'", replace text name(nudge9)
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(sev) stabcov(treat) wtype(iivw) nolog
    quietly log close nudge9
    _iivw_v180_log_has "`tlog9'" unstabilized
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: T9 - stabilization nudge absent with stabcov()"
    local ++pass_count
}
else {
    capture log close nudge9
    display as error "  FAIL: T9 - stabilization nudge suppressed (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T9"
}

**# Summary

display as result "Regression results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_iivw_v180_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL IIVW V1.8.0 REGRESSION TESTS PASSED"
display "RESULT: test_iivw_v180_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
