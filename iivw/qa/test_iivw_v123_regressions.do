clear all
version 16.0
set varabbrev off

* test_iivw_v123_regressions.do - regressions for post-1.2.2 review fixes
*
* Coverage:
*   T1  iivw_fit, bootstrap() honors level() in the GEE bootstrap path
*   T2  iivw_fit, bootstrap() default level is 95 (no regression for default)
*
* The v1.2.3 fix added level() to the `bootstrap' prefix in both the GEE and
* mixed branches (identical one-line edit). T1 exercises the shared
* `bootstrap, ..., level()' mechanism; the mixed branch is not bootstrapped
* here because pweighted mixed bootstrap on small clusters is prohibitively
* slow for routine QA.
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_v123_regressions.do

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_v123_regressions.do must be run from iivw/qa"
    exit 198
}
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _iivw_v123_panel
program define _iivw_v123_panel
    version 16.0
    clear
    set obs 160
    gen long id = ceil(_n / 4)
    bysort id: gen double t = _n
    gen double x = sin(id / 3)
    gen double z = cos(id / 4)
    gen byte treat = inlist(mod(id, 4), 1, 2)
    bysort id (t): replace treat = treat[1]
    gen double y = 2 + 0.4 * treat + 0.2 * x + 0.1 * t + 0.15 * z
end

**# T1: GEE bootstrap path honors level()
* Before the v1.2.3 fix, the bootstrap prefix ignored level() and the
* bootstrapped results table always reported 95% intervals while the
* iivw_fit summary table used the requested level. e(level) exposes which
* level the bootstrap actually used.

local ++test_count
capture noisily {
    _iivw_v123_panel
    iivw_weight, id(id) time(t) visit_cov(x z) wtype(iivw) nolog
    iivw_fit y treat x, timespec(linear) bootstrap(40) level(90) nolog
    assert e(level) == 90
}
if _rc == 0 {
    display as result "  PASS: T1 - GEE bootstrap honors level(90)"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - GEE bootstrap level() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

**# T2: GEE bootstrap default level remains 95

local ++test_count
capture noisily {
    _iivw_v123_panel
    iivw_weight, id(id) time(t) visit_cov(x z) wtype(iivw) nolog
    iivw_fit y treat x, timespec(linear) bootstrap(40) nolog
    assert e(level) == 95
}
if _rc == 0 {
    display as result "  PASS: T2 - GEE bootstrap default level is 95"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - GEE bootstrap default level (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

**# Summary

display as result "Regression results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_iivw_v123_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL IIVW V1.2.3 REGRESSION TESTS PASSED"
display "RESULT: test_iivw_v123_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
