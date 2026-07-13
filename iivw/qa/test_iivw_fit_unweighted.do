clear all
set more off
version 16.0
set varabbrev off

* test_iivw_fit_unweighted.do - focused tests for iivw_fit, unweighted
*
* Usage:
*   cd iivw/qa && stata-mp -b do test_iivw_fit_unweighted.do

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

ado dir
capture ado uninstall iivw
adopath ++ "`pkg_dir'"
discard

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _setup_unweighted_panel
program define _setup_unweighted_panel
    version 16.0
    clear
    set obs 120
    gen int id = ceil(_n / 4)
    bysort id: gen double t = _n - 1
    gen byte trt = mod(id, 2)
    gen double x = mod(id, 5) - 2 + 0.2 * t
    gen byte arm = mod(id, 3) + 1
    label define arm_lbl 1 "control" 2 "active" 3 "rescue", replace
    label values arm arm_lbl
    gen double y = 2 + 0.5 * x + 0.25 * t + 0.4 * trt + ///
        0.1 * trt * t + 0.2 * (arm == 2) - 0.1 * (arm == 3) + ///
        sin(id) / 10
    sort id t
end

**# T1: unweighted before iivw_weight matches manual glm
local ++test_count
capture noisily {
    _setup_unweighted_panel
    iivw_fit y x, unweighted id(id) time(t) timespec(linear) nolog
    scalar b_fit_x = _b[x]
    scalar b_fit_t = _b[t]
    assert "`e(iivw_cmd)'" == "iivw_fit"
    assert "`e(iivw_weighttype)'" == "unweighted"
    assert "`e(iivw_unweighted)'" == "1"
    assert "`e(iivw_weight_var)'" == ""

    glm y x t, family(gaussian) vce(cluster id) nolog
    assert reldif(b_fit_x, _b[x]) < 1e-10
    assert reldif(b_fit_t, _b[t]) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: T1 - unweighted fit before weights matches manual glm"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - unweighted fit before weights matches manual glm (error `=_rc')"
    local ++fail_count
}

**# T2: missing id() without metadata errors clearly
local ++test_count
capture noisily {
    _setup_unweighted_panel
    capture noisily iivw_fit y x, unweighted time(t) timespec(linear) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T2 - missing id() without metadata errors"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - missing id() without metadata errors (error `=_rc')"
    local ++fail_count
}

**# T3: missing time() without metadata errors when timespec needs time
local ++test_count
capture noisily {
    _setup_unweighted_panel
    capture noisily iivw_fit y x, unweighted id(id) timespec(linear) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T3 - missing time() without metadata errors"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - missing time() without metadata errors (error `=_rc')"
    local ++fail_count
}

**# T4: timespec(none) does not require time() in unweighted mode
local ++test_count
capture noisily {
    _setup_unweighted_panel
    iivw_fit y x trt, unweighted id(id) timespec(none) nolog
    scalar b_fit_x = _b[x]
    glm y x trt, family(gaussian) vce(cluster id) nolog
    assert reldif(b_fit_x, _b[x]) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: T4 - timespec(none) works without time()"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - timespec(none) works without time() (error `=_rc')"
    local ++fail_count
}

**# T5: weighted mode still rejects id()/time() overrides
local ++test_count
capture noisily {
    _setup_unweighted_panel
    capture noisily iivw_fit y x, id(id) time(t) timespec(linear) nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T5 - weighted mode rejects id()/time()"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - weighted mode rejects id()/time() (error `=_rc')"
    local ++fail_count
}

**# T6: after iivw_weight, endatlastvisit baseline(event) unweighted reuses metadata and preserves weights
local ++test_count
capture noisily {
    _setup_unweighted_panel
    iivw_weight, endatlastvisit baseline(event) id(id) time(t) visit_cov(x trt) nolog
    local weighted_before : char _dta[_iivw_weighted]
    local weighttype_before : char _dta[_iivw_weighttype]
    local weightvar_before : char _dta[_iivw_weight_var]
    gen double w_before = _iivw_weight

    iivw_fit y x, unweighted timespec(linear) nolog
    assert "`e(iivw_weighttype)'" == "unweighted"
    assert "`e(iivw_unweighted)'" == "1"
    assert "`: char _dta[_iivw_weighted]'" == "`weighted_before'"
    assert "`: char _dta[_iivw_weighttype]'" == "`weighttype_before'"
    assert "`: char _dta[_iivw_weight_var]'" == "`weightvar_before'"
    assert "`weightvar_before'" == "_iivw_weight"
    assert _iivw_weight == w_before
}
if _rc == 0 {
    display as result "  PASS: T6 - metadata fallback preserves weight state"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - metadata fallback preserves weight state (error `=_rc')"
    local ++fail_count
}

**# T7: collect works with unweighted
local ++test_count
capture noisily {
    _setup_unweighted_panel
    collect clear
    collect: iivw_fit y x, unweighted id(id) time(t) timespec(linear) nolog
    assert "`e(iivw_weighttype)'" == "unweighted"
    collect clear
}
if _rc == 0 {
    display as result "  PASS: T7 - collect prefix works"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - collect prefix works (error `=_rc')"
    local ++fail_count
}

**# T8: categorical() and interaction() work in unweighted mode
local ++test_count
capture noisily {
    _setup_unweighted_panel
    iivw_fit y trt arm, unweighted id(id) time(t) timespec(linear) ///
        categorical(arm) interaction(trt arm) nolog
    assert "`e(iivw_categorical)'" == "arm"
    assert "`e(iivw_interaction)'" == "trt arm"
    confirm variable _iivw_cat_active
    confirm variable _iivw_ix_trt_time
    confirm variable _iivw_ix_active_time
}
if _rc == 0 {
    display as result "  PASS: T8 - categorical and interaction work"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 - categorical and interaction work (error `=_rc')"
    local ++fail_count
}

**# T9: bootstrap works without pweights in unweighted mode
local ++test_count
capture noisily {
    _setup_unweighted_panel
    set seed 20260524
    iivw_fit y x, unweighted id(id) time(t) timespec(linear) ///
        bootstrap(5) nolog
    assert "`e(iivw_weighttype)'" == "unweighted"
    assert "`e(iivw_unweighted)'" == "1"
    assert "`e(vce)'" == "bootstrap"
    assert e(N_reps) == 5
}
if _rc == 0 {
    display as result "  PASS: T9 - bootstrap works unweighted"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 - bootstrap works unweighted (error `=_rc')"
    local ++fail_count
}

**# T10: weighted behavior remains available after iivw_weight
local ++test_count
capture noisily {
    _setup_unweighted_panel
    iivw_weight, endatlastvisit baseline(event) id(id) time(t) visit_cov(x trt) nolog
    iivw_fit y x, timespec(linear) nolog
    assert "`e(iivw_weighttype)'" == "iivw"
    assert "`e(iivw_unweighted)'" == "0"
    assert "`e(iivw_weight_var)'" == "_iivw_weight"
}
if _rc == 0 {
    display as result "  PASS: T10 - weighted fit remains backward compatible"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 - weighted fit remains backward compatible (error `=_rc')"
    local ++fail_count
}

**# Summary
capture adopath - "`pkg_dir'"
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_iivw_fit_unweighted tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_iivw_fit_unweighted tests=`test_count' pass=`pass_count' fail=`fail_count'"
