clear all
set more off
version 16.0
set varabbrev off

* test_iivw_weight_validation_guards.do - adversarial panel validation tests
*
* Usage:
*   do test_iivw_weight_validation_guards.do

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _make_guard_panel
program define _make_guard_panel
    version 16.0
    clear
    set obs 60
    gen long id = ceil(_n / 3)
    bysort id: gen byte visit = _n
    gen double time = visit
    gen double x = 0.05 * id + 0.1 * visit
    gen double z = mod(id, 3)
    gen byte treat = mod(id, 2)
    bysort id: replace treat = treat[1]
    gen double entry = 0
end

**# Tests

local ++test_count
capture noisily {
    _make_guard_panel
    replace id = . in 1
    capture noisily iivw_weight, id(id) time(time) visit_cov(x z) nolog
    assert _rc == 198
    capture confirm variable _iivw_weight
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: missing id() rejected before weighting"
    local ++pass_count
}
else {
    display as error "  FAIL: missing id() guard (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _make_guard_panel
    replace time = . in 2
    capture noisily iivw_weight, id(id) time(time) visit_cov(x z) nolog
    assert _rc == 198
    capture confirm variable _iivw_weight
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: missing time() rejected before stset"
    local ++pass_count
}
else {
    display as error "  FAIL: missing time() guard (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _make_guard_panel
    replace entry = . in 1
    capture noisily iivw_weight, id(id) time(time) visit_cov(x z) entry(entry) nolog
    assert _rc == 198
    capture confirm variable _iivw_weight
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: missing entry() rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: missing entry() guard (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _make_guard_panel
    replace entry = 0.5 in 2
    capture noisily iivw_weight, id(id) time(time) visit_cov(x z) entry(entry) nolog
    assert _rc == 198
    capture confirm variable _iivw_weight
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: within-id varying entry() rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: varying entry() guard (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _make_guard_panel
    replace entry = 1
    capture noisily iivw_weight, id(id) time(time) visit_cov(x z) entry(entry) nolog
    assert _rc == 198
    capture confirm variable _iivw_weight
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: entry() equal to first visit rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: entry equal first-visit guard (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _make_guard_panel
    replace entry = 2
    capture noisily iivw_weight, id(id) time(time) visit_cov(x z) entry(entry) nolog
    assert _rc == 198
    capture confirm variable _iivw_weight
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: entry() after first visit rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: entry after first-visit guard (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _make_guard_panel
    replace entry = 0.25
    iivw_weight, id(id) time(time) visit_cov(x z) entry(entry) nolog
    assert r(N) == 60
    assert r(n_ids) == 20
    bysort id (time): assert _iivw_iw == 1 if _n == 1
    assert "`: char _dta[_iivw_weighted]'" == "1"
}
if _rc == 0 {
    display as result "  PASS: valid entry() strictly before first visit succeeds"
    local ++pass_count
}
else {
    display as error "  FAIL: valid entry() path (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _make_guard_panel
    set varabbrev on
    replace time = . in 2
    capture noisily iivw_weight, id(id) time(time) visit_cov(x z) nolog
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: varabbrev restored after validation error"
    local ++pass_count
}
else {
    display as error "  FAIL: varabbrev validation-error restore (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _make_guard_panel
    iivw_weight, id(id) time(time) visit_cov(x z) nolog
    assert "`: char _dta[_iivw_weighted]'" == "1"
    replace time = . in 2
    capture noisily iivw_weight, id(id) time(time) visit_cov(x z) replace nolog
    assert _rc == 198
    * v1.0.6+: validation-stage failures preserve prior weighting metadata
    assert "`: char _dta[_iivw_weighted]'" == "1"
    * iivw_fit can still use the prior valid weighting
    capture noisily iivw_fit x z, nolog
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: failed validation preserves prior weighting metadata (v1.0.6 behavior)"
    local ++pass_count
}
else {
    display as error "  FAIL: stale metadata invalidation after validation error (error `=_rc')"
    local ++fail_count
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_iivw_weight_validation_guards tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_iivw_weight_validation_guards tests=`test_count' pass=`pass_count' fail=`fail_count'"
