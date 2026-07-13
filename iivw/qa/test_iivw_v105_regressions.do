clear all
version 16.0
set varabbrev off

* test_iivw_v105_regressions.do - regressions for post-1.0.5 review fixes
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_v105_regressions.do

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_v105_regressions.do must be run from iivw/qa"
    exit 198
}
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _iivw_v105_panel
program define _iivw_v105_panel
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

**# Regression Tests

local ++test_count
capture noisily {
    foreach wtype in iivw iptw fiptiw {
        _iivw_v105_panel
        regress y x
        local before_cmd "`e(cmd)'"
        scalar before_b = _b[x]

        if "`wtype'" == "iivw" {
            iivw_weight, endatlastvisit baseline(event) id(id) time(t) visit_cov(x z) wtype(iivw) nolog
        }
        else if "`wtype'" == "iptw" {
            iivw_weight, id(id) time(t) treat(treat) treat_cov(x z) ///
                wtype(iptw) nolog
        }
        else {
            iivw_weight, endatlastvisit baseline(event) id(id) time(t) visit_cov(x z) treat(treat) ///
                treat_cov(x z) wtype(fiptiw) nolog
        }

        assert "`before_cmd'" == "regress"
        assert "`e(cmd)'" == "regress"
        assert reldif(_b[x], before_b) < 1e-12
    }
}
if _rc == 0 {
    display as result "  PASS: active estimates preserved after iivw_weight"
    local ++pass_count
}
else {
    display as error "  FAIL: active estimate preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' active_estimates"
}

local ++test_count
capture noisily {
    _iivw_v105_panel
    gen byte __iivw_first = 7
    iivw_weight, endatlastvisit baseline(event) id(id) time(t) visit_cov(x z) wtype(iivw) nolog
    assert __iivw_first == 7

    _iivw_v105_panel
    gen double __iivw_ps_tmp = 9
    iivw_weight, id(id) time(t) treat(treat) treat_cov(x z) ///
        wtype(iptw) nolog
    assert __iivw_ps_tmp == 9
}
if _rc == 0 {
    display as result "  PASS: user scratch-name variables do not collide"
    local ++pass_count
}
else {
    display as error "  FAIL: scratch-name collision regression (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' scratch_names"
}

local ++test_count
capture noisily {
    _iivw_v105_panel
    gen double abcdefghijklmnopqrA = x + 0.01 * id
    gen double abcdefghijklmnopqrB = z - 0.01 * id
    iivw_weight, id(id) time(t) treat(treat) treat_cov(x z) ///
        wtype(iptw) nolog
    capture iivw_fit y abcdefghijklmnopqrA abcdefghijklmnopqrB, ///
        interaction(abcdefghijklmnopqrA abcdefghijklmnopqrB) ///
        timespec(linear) replace nolog
    assert _rc == 198
    capture confirm variable _iivw_ix_abcdefghijklmnopqr_time
    assert _rc != 0
    local fitted : char _dta[_iivw_fitted]
    assert "`fitted'" == ""
}
if _rc == 0 {
    display as result "  PASS: truncated interaction-name collision errors cleanly"
    local ++pass_count
}
else {
    display as error "  FAIL: interaction truncation collision (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' interaction_names"
}

**# Summary

display as result "Regression results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_iivw_v105_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL IIVW V1.0.5 REGRESSION TESTS PASSED"
display "RESULT: test_iivw_v105_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
