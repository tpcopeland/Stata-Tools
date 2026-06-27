clear all
set varabbrev off
version 16.0

do _fvgen_qa_common.do
_fvgen_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# 1. Per-group slopes: one slope per moderator level, no plain main, labels
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##c.age, simple(arm)
    * one slope variable per arm level (incl. base), and the moderator dummy
    confirm variable _armXage_0
    confirm variable _armXage_1
    confirm variable _arm_1
    * plain continuous main is absorbed (not a standalone regressor)
    assert strpos(" `r(allvars)' ", " age ") == 0
    * effective spec is the nested form
    assert strpos("`r(spec)'", "i.arm#c.age") > 0
    * per-group label reads "<continuous> (<group>)", quote-safe moderator label
    local lb : variable label _armXage_0
    assert ustrpos(`"`lb'"', `"(6" rim)"') > 0
}
if _rc == 0 {
    display as result "  PASS: per-group slopes surface + labels"
    local ++pass_count
}
else {
    display as error "  FAIL: per-group slopes surface (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**# 2. Equivalence: per-group slope == main + interaction from native ##
local ++test_count
capture noisily {
    _fvgen_make_data
    quietly regress y i.arm##c.age
    scalar s0 = _b[age]
    scalar s1 = _b[age] + _b[1.arm#c.age]
    scalar r2n = e(r2)
    fvgen i.arm##c.age, simple(arm)
    quietly regress y `r(allvars)'
    assert reldif(_b[_armXage_0], s0) < 1e-8
    assert reldif(_b[_armXage_1], s1) < 1e-8
    assert reldif(e(r2), r2n) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: simple-slope equivalence to native ##"
    local ++pass_count
}
else {
    display as error "  FAIL: simple-slope equivalence (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# 3. Multi-level moderator: one slope per level (including base)
local ++test_count
capture noisily {
    _fvgen_make_data
    * capture the native fit first; regress clears r(), so fvgen must run
    * immediately before r(allvars) is consumed
    quietly regress y i.grp##c.age
    scalar r2n = e(r2)
    fvgen i.grp##c.age, simple(grp)
    confirm variable _grpXage_1
    confirm variable _grpXage_2
    confirm variable _grpXage_3
    quietly regress y `r(allvars)'
    assert reldif(e(r2), r2n) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: multi-level moderator slopes"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-level moderator (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**# 4. A continuous main that does NOT interact with the moderator is kept
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##c.age c.bmi, simple(arm)
    * bmi does not interact with arm -> stays as a standalone regressor
    assert strpos(" `r(allvars)' ", " bmi ") > 0
    * age interacts with arm -> absorbed into per-group slopes
    assert strpos(" `r(allvars)' ", " age ") == 0
    confirm variable _armXage_0
}
if _rc == 0 {
    display as result "  PASS: non-moderated continuous main retained"
    local ++pass_count
}
else {
    display as error "  FAIL: non-moderated main retained (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**# 5. simple() + center combined path (concept item 5 — riskiest interaction)
* The continuous term is centered AND absorbed into per-group slopes. Per-group
* slopes are slope-invariant to centering, so they still match the native main
* and main+interaction, and the model fit is unchanged.
local ++test_count
capture noisily {
    _fvgen_make_data
    quietly regress y i.arm##c.age
    scalar s0  = _b[age]
    scalar s1  = _b[age] + _b[1.arm#c.age]
    scalar r2n = e(r2)
    fvgen i.arm##c.age, simple(arm) center
    * a centered helper copy is created (absorbed, not itself a regressor)
    confirm variable _age_c
    assert "`: char _age_c[fvgen_role]'" == "centered"
    assert strpos(" `r(allvars)' ", " _age_c ") == 0
    * per-group slopes survive centering and equal the native quantities
    quietly regress y `r(allvars)'
    assert reldif(_b[_armXage_0], s0) < 1e-7
    assert reldif(_b[_armXage_1], s1) < 1e-7
    assert reldif(e(r2), r2n) < 1e-9
}
if _rc == 0 {
    display as result "  PASS: simple() + center combined path"
    local ++pass_count
}
else {
    display as error "  FAIL: simple() + center (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

**# Summary
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED:`failed_tests'"
    display "RESULT: test_simple tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_simple tests=`test_count' pass=`pass_count' fail=`fail_count'"
