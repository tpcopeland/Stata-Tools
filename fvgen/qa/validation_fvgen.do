clear all
set varabbrev off
version 16.0

do _fvgen_qa_common.do
_fvgen_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# 1. Hand-computed dummy and product values (tiny known dataset)
local ++test_count
capture noisily {
    clear
    input byte g double x
    1 10
    2 20
    1 .
    2 40
    end
    label define gl 1 "A" 2 "B"
    label values g gl
    fvgen i.g##c.x
    * base level g==1 dropped; _g_2 = (g==2)
    assert _g_2[1] == 0
    assert _g_2[2] == 1
    assert _g_2[4] == 1
    * product _gXx_2 = (g==2)*x, missing where x missing
    assert _gXx_2[1] == 0
    assert _gXx_2[2] == 20
    assert _gXx_2[4] == 40
    assert missing(_gXx_2[3])
    * x passes through unchanged
    assert x[2] == 20
}
if _rc == 0 {
    display as result "  PASS: hand-computed dummy/product values"
    local ++pass_count
}
else {
    display as error "  FAIL: hand-computed values (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**# 2. Equivalence to native ##: categorical-by-continuous
local ++test_count
capture noisily {
    _fvgen_make_data
    quietly regress y i.arm##c.age
    scalar bn = _b[1.arm#c.age]
    scalar r2n = e(r2)
    scalar nn  = e(N)
    fvgen i.arm##c.age
    quietly regress y `r(allvars)'
    assert reldif(_b[_armXage_1], bn) < 1e-8
    assert reldif(e(r2), r2n) < 1e-10
    assert e(N) == nn
}
if _rc == 0 {
    display as result "  PASS: equivalence cat-by-continuous"
    local ++pass_count
}
else {
    display as error "  FAIL: equivalence cat-by-continuous (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# 3. Equivalence to native ##: categorical-by-categorical
local ++test_count
capture noisily {
    _fvgen_make_data
    quietly regress y i.grp##i.arm
    scalar r2n = e(r2)
    scalar nn  = e(N)
    fvgen i.grp##i.arm
    quietly regress y `r(allvars)'
    assert reldif(e(r2), r2n) < 1e-10
    assert e(N) == nn
}
if _rc == 0 {
    display as result "  PASS: equivalence cat-by-cat"
    local ++pass_count
}
else {
    display as error "  FAIL: equivalence cat-by-cat (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**# 4. Equivalence to native ##: continuous-by-continuous
local ++test_count
capture noisily {
    _fvgen_make_data
    quietly regress y c.age##c.bmi
    scalar bn = _b[c.age#c.bmi]
    scalar r2n = e(r2)
    fvgen c.age##c.bmi
    quietly regress y `r(allvars)'
    assert reldif(_b[_ageXbmi], bn) < 1e-8
    assert reldif(e(r2), r2n) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: equivalence cont-by-cont"
    local ++pass_count
}
else {
    display as error "  FAIL: equivalence cont-by-cont (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**# 5. Centering invariance: interaction coef and R2 unchanged
local ++test_count
capture noisily {
    _fvgen_make_data
    quietly regress y c.age##c.bmi
    scalar bn = _b[c.age#c.bmi]
    scalar r2n = e(r2)
    fvgen c.age##c.bmi, center
    quietly regress y `r(allvars)'
    * centering shifts lower-order terms but not the product coef or fit
    assert reldif(_b[_ageXbmi], bn) < 1e-8
    assert reldif(e(r2), r2n) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: centering invariance"
    local ++pass_count
}
else {
    display as error "  FAIL: centering invariance (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

**# Summary
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED:`failed_tests'"
    display "RESULT: validation_fvgen tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_fvgen tests=`test_count' pass=`pass_count' fail=`fail_count'"
