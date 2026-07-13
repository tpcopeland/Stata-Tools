clear all
version 16.0
set varabbrev off

* test_iivw_v106_regressions.do - regressions for post-1.0.6 review fixes
*
* Coverage:
*   T1  panel_time in indepvars + timespec(linear) is rejected
*   T2  panel_time in indepvars + timespec(none) is allowed
*   T3  iivw_fit validation-stage failure preserves prior fit metadata
*   T4  iivw_weight validation-stage failure preserves prior weight metadata
*   T5  collinear-dropped predictor shows up as "(omitted)" row in summary table
*   T6  iivw_weight accepts the short abbreviation w() for wtype()
*   T7  _iivw_bs_estimate direct call: rejects bad model(), missing weight var
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_v106_regressions.do

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_v106_regressions.do must be run from iivw/qa"
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

capture program drop _iivw_v106_panel
program define _iivw_v106_panel
    version 16.0
    clear
    set obs 80
    gen long id = ceil(_n / 4)
    bysort id: gen double t = _n
    gen double x = sin(id / 3)
    gen double z = cos(id / 4)
    gen byte treat = inlist(mod(id, 4), 1, 2)
    bysort id (t): replace treat = treat[1]
    gen double y = 2 + 0.4 * treat + 0.2 * x + 0.1 * t + 0.15 * z
end

**# T1: panel_time in indepvars with non-none timespec is rejected

local ++test_count
capture noisily {
    _iivw_v106_panel
    iivw_weight, endatlastvisit baseline(event) id(id) time(t) visit_cov(x z) wtype(iivw) nolog
    capture noisily iivw_fit y t treat x, timespec(linear) nolog
    assert _rc == 198
    capture noisily iivw_fit y t treat x, timespec(ns(3)) nolog
    assert _rc == 198
    capture noisily iivw_fit y t treat x, timespec(quadratic) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T1 - panel_time in indepvars rejected for non-none timespec"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - panel_time-collision guard (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

**# T2: panel_time in indepvars allowed when timespec(none)

local ++test_count
capture noisily {
    _iivw_v106_panel
    iivw_weight, endatlastvisit baseline(event) id(id) time(t) visit_cov(x z) wtype(iivw) nolog
    iivw_fit y t treat x, timespec(none) nolog
    assert _b[t] != .
    assert "`e(iivw_timespec)'" == "none"
}
if _rc == 0 {
    display as result "  PASS: T2 - panel_time in indepvars allowed with timespec(none)"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - timespec(none) allows panel_time predictor (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

**# T3: iivw_fit validation failure preserves prior fit metadata

local ++test_count
capture noisily {
    _iivw_v106_panel
    iivw_weight, endatlastvisit baseline(event) id(id) time(t) visit_cov(x z) wtype(iivw) nolog
    iivw_fit y treat x, timespec(linear) nolog
    local prior_fitted   : char _dta[_iivw_fitted]
    local prior_model    : char _dta[_iivw_model]
    local prior_timespec : char _dta[_iivw_timespec]
    assert "`prior_fitted'"   == "1"
    assert "`prior_model'"    == "gee"
    assert "`prior_timespec'" == "linear"

    * Validation failure (bad model())
    capture noisily iivw_fit y treat x, model(foo) timespec(linear) nolog
    assert _rc == 198
    local post_fitted   : char _dta[_iivw_fitted]
    local post_model    : char _dta[_iivw_model]
    local post_timespec : char _dta[_iivw_timespec]
    assert "`post_fitted'"   == "1"
    assert "`post_model'"    == "gee"
    assert "`post_timespec'" == "linear"

    * Validation failure (negative bootstrap)
    capture noisily iivw_fit y treat x, bootstrap(-1) timespec(linear) nolog
    assert _rc == 198
    local post2_fitted : char _dta[_iivw_fitted]
    assert "`post2_fitted'" == "1"
}
if _rc == 0 {
    display as result "  PASS: T3 - iivw_fit validation failure preserves prior metadata"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - iivw_fit metadata preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

**# T4: iivw_weight validation failure preserves prior weight metadata

local ++test_count
capture noisily {
    _iivw_v106_panel
    iivw_weight, endatlastvisit baseline(event) id(id) time(t) visit_cov(x z) wtype(iivw) nolog
    local prior_weighted   : char _dta[_iivw_weighted]
    local prior_weighttype : char _dta[_iivw_weighttype]
    local prior_wvar       : char _dta[_iivw_weight_var]
    assert "`prior_weighted'"   == "1"
    assert "`prior_weighttype'" == "iivw"
    assert "`prior_wvar'"       == "_iivw_weight"

    * Validation failure: bad wtype()
    capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(t) visit_cov(x z) wtype(foo) ///
        replace nolog
    assert _rc == 198
    local post_weighted   : char _dta[_iivw_weighted]
    local post_weighttype : char _dta[_iivw_weighttype]
    assert "`post_weighted'"   == "1"
    assert "`post_weighttype'" == "iivw"

    * Validation failure: bad truncate range
    capture noisily iivw_weight, endatlastvisit baseline(event) id(id) time(t) visit_cov(x z) ///
        truncate(0 100) replace nolog
    assert _rc == 198
    local post2_weighted : char _dta[_iivw_weighted]
    assert "`post2_weighted'" == "1"
}
if _rc == 0 {
    display as result "  PASS: T4 - iivw_weight validation failure preserves prior metadata"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - iivw_weight metadata preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

**# T5: collinear-dropped predictor displays "(omitted)" row

local ++test_count
capture noisily {
    _iivw_v106_panel
    gen double x_copy = x
    iivw_weight, endatlastvisit baseline(event) id(id) time(t) visit_cov(x z) wtype(iivw) nolog
    * x and x_copy are perfectly collinear; glm drops one. The custom
    * summary loop should emit "(omitted)" rather than silently skipping.
    tempname fh
    tempfile fitlog
    log using "`fitlog'.txt", text replace
    capture noisily iivw_fit y treat x x_copy, timespec(linear) nolog
    local fit_rc = _rc
    log close
    assert `fit_rc' == 0

    * Scan the captured log for an "(omitted)" row in the custom summary
    * table. glm's own line also says "(omitted)"; assert at least 2 hits
    * (one from glm, one from the iivw_fit summary loop).
    local n_omit = 0
    file open `fh' using "`fitlog'.txt", read text
    file read `fh' line
    while !r(eof) {
        if strpos(`"`line'"', "(omitted)") > 0 local ++n_omit
        file read `fh' line
    }
    file close `fh'
    assert `n_omit' >= 2
    erase "`fitlog'.txt"
}
if _rc == 0 {
    display as result "  PASS: T5 - collinear-dropped predictor shows (omitted) row"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - omitted-row display (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}

**# T6: iivw_weight accepts wt() (documented min) and treat_c() abbreviations

local ++test_count
capture noisily {
    _iivw_v106_panel
    iivw_weight, endatlastvisit baseline(event) id(id) time(t) visit_cov(x z) wt(iivw) nolog
    assert "`r(weighttype)'" == "iivw"

    iivw_weight, id(id) time(t) treat(treat) treat_c(x z) wt(iptw) ///
        replace nolog
    assert "`r(weighttype)'" == "iptw"

    iivw_weight, endatlastvisit baseline(event) id(id) time(t) visit_cov(x z) treat(treat) ///
        treat_c(x z) wt(fiptiw) replace nolog
    assert "`r(weighttype)'" == "fiptiw"
}
if _rc == 0 {
    display as result "  PASS: T6 - wt() and treat_c() abbreviations accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - wtype/treat_cov abbreviation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}

**# T7: _iivw_bs_estimate direct-call adversarial

local ++test_count
capture noisily {
    _iivw_v106_panel
    iivw_weight, endatlastvisit baseline(event) id(id) time(t) visit_cov(x z) wtype(iivw) nolog

    * Bad model() must error
    capture noisily _iivw_bs_estimate y x z, weightvar(_iivw_weight) model(foo) family(gaussian)
    assert _rc == 198

    * v1.1.0+: missing weightvar() is the unweighted bootstrap path
    capture noisily _iivw_bs_estimate y x z, model(gee) family(gaussian)
    assert _rc == 0
    assert _b[x] != .

    * Empty sample must error 2000
    capture noisily _iivw_bs_estimate y x z if id < 0, weightvar(_iivw_weight) model(gee) family(gaussian)
    assert _rc == 2000

    * Happy path: weighted gee with valid args succeeds
    _iivw_bs_estimate y x z, weightvar(_iivw_weight) model(gee) family(gaussian) nolog
    assert _b[x] != .
}
if _rc == 0 {
    display as result "  PASS: T7 - _iivw_bs_estimate adversarial contract"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - _iivw_bs_estimate contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T7"
}

**# Summary

display as result "Regression results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_iivw_v106_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL IIVW V1.0.6 REGRESSION TESTS PASSED"
display "RESULT: test_iivw_v106_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
