clear all
set varabbrev off
version 16.0

do _fvgen_qa_common.do
_fvgen_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# 1. ref() drops the requested base and keeps the default base level
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##i.grp, ref(grp 2)
    * grp==2 is now the base -> dropped; grp==1 now present
    capture confirm variable _grp_2
    assert _rc != 0
    confirm variable _grp_1
    * the effective spec records the chosen base
    assert strpos("`r(spec)'", "ib2.grp") > 0
}
if _rc == 0 {
    display as result "  PASS: ref() re-references the base level"
    local ++pass_count
}
else {
    display as error "  FAIL: ref() re-reference (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**# 2. Equivalence: ref() matches native ibN. parameterization
local ++test_count
capture noisily {
    _fvgen_make_data
    quietly regress y i.arm##ib2.grp
    scalar r2n = e(r2)
    scalar nn  = e(N)
    fvgen i.arm##i.grp, ref(grp 2)
    quietly regress y `r(allvars)'
    assert reldif(e(r2), r2n) < 1e-10
    assert e(N) == nn
}
if _rc == 0 {
    display as result "  PASS: ref() equivalent to native ibN."
    local ++pass_count
}
else {
    display as error "  FAIL: ref() equivalence (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# 3. Multiple references with comma syntax
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##i.grp, ref(arm 1, grp 3)
    * arm==1 base -> _arm_1 dropped, _arm_0 present
    capture confirm variable _arm_1
    assert _rc != 0
    confirm variable _arm_0
    * grp==3 base -> _grp_3 dropped
    capture confirm variable _grp_3
    assert _rc != 0
    assert strpos("`r(spec)'", "ib1.arm")  > 0
    assert strpos("`r(spec)'", "ib3.grp")  > 0
}
if _rc == 0 {
    display as result "  PASS: multiple ref() pairs (comma syntax)"
    local ++pass_count
}
else {
    display as error "  FAIL: multiple ref() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**# 4. ref() + alllevels keeps the (re-referenced) base too
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.grp, ref(grp 2) alllevels
    confirm variable _grp_1
    confirm variable _grp_2
    confirm variable _grp_3
}
if _rc == 0 {
    display as result "  PASS: ref() with alllevels"
    local ++pass_count
}
else {
    display as error "  FAIL: ref() with alllevels (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**# 4b. ref() accepts a value-label string and resolves it to the level
local ++test_count
capture noisily {
    _fvgen_make_data
    * grp is labeled 1 Low 2 Mid 3 High; "Mid" must resolve to level 2
    fvgen i.arm##i.grp, ref(grp "Mid")
    capture confirm variable _grp_2
    assert _rc != 0
    confirm variable _grp_1
    confirm variable _grp_3
    assert strpos("`r(spec)'", "ib2.grp") > 0
    * label-by-string is equivalent to the integer code
    fvgen i.arm##i.grp, ref(grp 2) replace
    assert strpos("`r(spec)'", "ib2.grp") > 0
    * mixed integer + label pair in one call
    fvgen i.arm##i.grp, ref(arm 1, grp "High") replace
    assert strpos("`r(spec)'", "ib1.arm") > 0
    assert strpos("`r(spec)'", "ib3.grp") > 0
    * labels containing spaces and punctuation must remain one ref() token
    fvgen i.arm##i.grp, ref(arm "large & wide") replace
    assert strpos("`r(spec)'", "ib1.arm") > 0
}
if _rc == 0 {
    display as result "  PASS: ref() by value-label string"
    local ++pass_count
}
else {
    display as error "  FAIL: ref() by label (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4b"
}

**# 5. ref() does not mutate fvset state on the data
local ++test_count
capture noisily {
    _fvgen_make_data
    * default base for grp is level 1; ensure it stays default afterwards
    fvgen i.grp, ref(grp 2)
    fvexpand i.grp
    * default base (level 1) must still be the base after the command
    assert strpos("`r(varlist)'", "1b.grp") > 0
}
if _rc == 0 {
    display as result "  PASS: ref() leaves fvset state untouched"
    local ++pass_count
}
else {
    display as error "  FAIL: ref() fvset state (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

**# Summary
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED:`failed_tests'"
    display "RESULT: test_ref tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_ref tests=`test_count' pass=`pass_count' fail=`fail_count'"
