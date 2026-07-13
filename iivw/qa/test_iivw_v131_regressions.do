clear all
version 16.0
set varabbrev off

* test_iivw_v131_regressions.do - regressions for v1.3.1 review fixes
*
* Coverage:
*   T1  iivw_fit, collect + model(mixed) errors (rc 198) instead of silent no-op
*   T2  iivw_fit, collect + bootstrap() errors (rc 198) instead of silent no-op
*   T3  iivw_fit, collect + model(gee) (no bootstrap) still succeeds
*   T4  iivw_diagnose, level() below 10 errors (rc 198)
*   T5  iivw_diagnose, level() above 99.99 errors (rc 198)
*   T6  iivw_diagnose, level(90) (in range) succeeds
*
* Note: T5 originally asserted that level(99.99) errors. v1.9.6 moved
* iivw_diagnose from level(real 95) to level(cilevel), which honours
* `set level' and accepts Stata's standard 10-99.99 range, so 99.99 is now
* legal (see test_iivw_v196_regressions.do) and level(100) is the boundary.
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_v131_regressions.do

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_v131_regressions.do must be run from iivw/qa"
    exit 198
}
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Small balanced panel: 40 subjects, 3 visits each, time-invariant treat.
capture program drop _iivw_v131_panel
program define _iivw_v131_panel
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

**# T1: collect + model(mixed) errors (rc 198)

local ++test_count
capture noisily {
    _iivw_v131_panel
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(sev) wtype(iivw) nolog
    capture iivw_fit y treat, model(mixed) collect nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T1 - collect + model(mixed) errors (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - collect + model(mixed) guard (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

**# T2: collect + bootstrap() errors (rc 198)

local ++test_count
capture noisily {
    _iivw_v131_panel
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(sev) wtype(iivw) nolog
    capture iivw_fit y treat, model(gee) bootstrap(20) collect nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T2 - collect + bootstrap() errors (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - collect + bootstrap() guard (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

**# T3: collect + model(gee) (no bootstrap) still succeeds

local ++test_count
capture noisily {
    _iivw_v131_panel
    iivw_weight, endatlastvisit baseline(event) id(id) time(days) visit_cov(sev) wtype(iivw) nolog
    capture iivw_fit y treat, model(gee) collect nolog
    * On Stata 17+ collect succeeds (rc 0); on Stata 16 the version guard
    * fires (rc 198). Either way it must not silently mis-handle collect.
    if c(stata_version) >= 17 {
        assert _rc == 0
    }
    else {
        assert _rc == 198
    }
}
if _rc == 0 {
    display as result "  PASS: T3 - collect + model(gee) handled correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - collect + model(gee) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

**# T4: iivw_diagnose level() below 10 errors (rc 198)

local ++test_count
capture noisily {
    sysuse auto, clear
    regress price mpg
    estimates store m_u
    regress price mpg weight
    estimates store m_w
    regress price mpg weight foreign
    estimates store m_a
    capture iivw_diagnose mpg, unweighted(m_u) weighted(m_w) adjusted(m_a) level(5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T4 - level() below 10 errors (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - level() below 10 guard (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

**# T5: iivw_diagnose level() above 99.99 errors (rc 198)

local ++test_count
capture noisily {
    sysuse auto, clear
    regress price mpg
    estimates store m_u
    regress price mpg weight
    estimates store m_w
    regress price mpg weight foreign
    estimates store m_a
    capture iivw_diagnose mpg, unweighted(m_u) weighted(m_w) adjusted(m_a) level(100)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T5 - level() above 99.99 errors (rc 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - level() upper-bound guard (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}

**# T6: iivw_diagnose level(90) (in range) succeeds

local ++test_count
capture noisily {
    sysuse auto, clear
    regress price mpg
    estimates store m_u
    regress price mpg weight
    estimates store m_w
    regress price mpg weight foreign
    estimates store m_a
    iivw_diagnose mpg, unweighted(m_u) weighted(m_w) adjusted(m_a) level(90)
    assert "`r(coefficient)'" == "mpg"
}
if _rc == 0 {
    display as result "  PASS: T6 - level(90) in range succeeds"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - level(90) in range (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}

**# Summary

display as result "Regression results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_iivw_v131_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL IIVW V1.3.1 REGRESSION TESTS PASSED"
display "RESULT: test_iivw_v131_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
