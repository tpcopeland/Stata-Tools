clear all
set varabbrev off
version 16.0

do _fvgen_qa_common.do
_fvgen_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# 1. Higher-order (3-way) interaction is rejected with 198
local ++test_count
capture noisily {
    _fvgen_make_data
    capture fvgen i.grp##i.arm##c.age
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: 3-way interaction rejected (198)"
    local ++pass_count
}
else {
    display as error "  FAIL: 3-way rejection (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**# 2. Generated name exceeding 32 characters is rejected with 198
local ++test_count
capture noisily {
    _fvgen_make_data
    * a 28-character prefix pushes prefix+arm_1 past the 32-char limit
    capture fvgen i.arm, prefix(abcdefghijklmnopqrstuvwxyzab)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: over-long generated name rejected (198)"
    local ++pass_count
}
else {
    display as error "  FAIL: over-long name rejection (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# 3. Name collision without replace is rejected with 110
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##c.age
    capture fvgen i.arm##c.age
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: name collision rejected (110)"
    local ++pass_count
}
else {
    display as error "  FAIL: collision rejection (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**# 4. No observations in sample is rejected with 2000
local ++test_count
capture noisily {
    _fvgen_make_data
    capture fvgen i.arm##c.age if age > 1e12
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: empty sample rejected (2000)"
    local ++pass_count
}
else {
    display as error "  FAIL: empty sample rejection (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**# 5a. ref() error paths: odd tokens / continuous / bad level / missing var
local ++test_count
capture noisily {
    _fvgen_make_data
    capture fvgen i.arm##i.grp, ref(grp)
    assert _rc == 198
    capture fvgen i.arm##c.age, ref(age 2)
    assert _rc == 198
    capture fvgen i.arm##i.grp, ref(grp 9)
    assert _rc == 198
    capture fvgen i.arm##i.grp, ref(nosuchvar 1)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: ref() error paths (198/198/198/111)"
    local ++pass_count
}
else {
    display as error "  FAIL: ref() error paths (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5a"
}

**# 5b. simple() error paths: cat-by-cat / not-a-factor / no interaction
local ++test_count
capture noisily {
    _fvgen_make_data
    capture fvgen i.arm##i.grp, simple(arm)
    assert _rc == 198
    capture fvgen i.arm##c.age, simple(bmi)
    assert _rc == 198
    capture fvgen i.arm i.grp, simple(arm)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: simple() error paths (198 x3)"
    local ++pass_count
}
else {
    display as error "  FAIL: simple() error paths (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5b"
}

**# 5c. omit operator (o.) is rejected in every form (198)
local ++test_count
capture noisily {
    _fvgen_make_data
    foreach s in "o.grp" "2o.grp" "i.arm#2o.grp" "i.arm##2o.grp" "c.age#2o.grp" {
        capture fvgen `s'
        assert _rc == 198
    }
    * legitimate no-base (ibn.) and explicit base (ibN.) are NOT rejected
    capture fvgen ibn.grp
    assert _rc == 0
    capture fvgen ib2.grp, replace
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: omit operator rejected, ibn./ibN. allowed"
    local ++pass_count
}
else {
    display as error "  FAIL: omit-operator handling (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5c"
}

**# 5d. ref() value-label string that does not match any level (198)
local ++test_count
capture noisily {
    _fvgen_make_data
    capture fvgen i.arm##i.grp, ref(grp "Nonesuch")
    assert _rc == 198
    * a label string that matches no observed level is 198
    capture fvgen i.arm##i.grp, ref(arm "x") replace
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: ref() bad value-label string rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: ref() bad label (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5d"
}

**# 6. varabbrev is restored after an error path
local ++test_count
capture noisily {
    _fvgen_make_data
    set varabbrev on
    local before "`c(varabbrev)'"
    capture fvgen i.grp##i.arm##c.age
    assert _rc == 198
    assert "`c(varabbrev)'" == "`before'"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: varabbrev restored on error"
    local ++pass_count
}
else {
    display as error "  FAIL: varabbrev restore (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

**# 7. varabbrev is restored after success and drop success paths
local ++test_count
capture noisily {
    _fvgen_make_data
    set varabbrev on
    local before "`c(varabbrev)'"
    fvgen i.arm##c.age
    assert "`c(varabbrev)'" == "`before'"
    fvgen, drop
    assert "`c(varabbrev)'" == "`before'"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: varabbrev restored on success"
    local ++pass_count
}
else {
    display as error "  FAIL: varabbrev success restore (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}

**# 8. vsref() error paths: template without @, and vsref with drop
local ++test_count
capture noisily {
    _fvgen_make_data
    * a template missing the @ placeholder is rejected with 198
    capture fvgen i.grp, vsref("vs base")
    assert _rc == 198
    * drop takes no other options, so vsref alongside drop is 198
    fvgen i.grp
    capture fvgen, drop vsref("(vs. @)")
    assert _rc == 198
    * cleanup
    capture fvgen, drop
}
if _rc == 0 {
    display as result "  PASS: vsref() error paths (no-@ 198, drop+vsref 198)"
    local ++pass_count
}
else {
    display as error "  FAIL: vsref() error paths (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}

**# Summary
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED:`failed_tests'"
    display "RESULT: test_errors tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_errors tests=`test_count' pass=`pass_count' fail=`fail_count'"
