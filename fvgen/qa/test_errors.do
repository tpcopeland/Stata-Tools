*! test_errors.do — Error-path and session-state QA for fvgen
*! Author: Timothy P Copeland, Karolinska Institutet
*! Requires: Stata 16.0+

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
    _fvgen_qa_assert_error, rc(198) msg("supports up to 2-way interactions") : fvgen i.grp##i.arm##c.age
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
    _fvgen_qa_assert_error, rc(198) msg("exceeds the 32-character limit") : fvgen i.arm, prefix(abcdefghijklmnopqrstuvwxyzab)
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
    _fvgen_qa_assert_error, rc(110) msg("already exists; specify the replace option") : fvgen i.arm##c.age
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
    _fvgen_qa_assert_error, rc(2000) msg("no observations") : fvgen i.arm##c.age if age > 1e12
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
    _fvgen_qa_assert_error, rc(198) msg("ref() expects variable/level pairs") : fvgen i.arm##i.grp, ref(grp)
    _fvgen_qa_assert_error, rc(198) msg("age==2 is not an observed level") : fvgen i.arm##c.age, ref(age 2)
    _fvgen_qa_assert_error, rc(198) msg("grp==9 is not an observed level") : fvgen i.arm##i.grp, ref(grp 9)
    _fvgen_qa_assert_error, rc(111) msg("ref(): variable 'nosuchvar' not found") : fvgen i.arm##i.grp, ref(nosuchvar 1)
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
    _fvgen_qa_assert_error, rc(198) msg("interacts with a categorical term") : fvgen i.arm##i.grp, simple(arm)
    _fvgen_qa_assert_error, rc(198) msg("simple(): 'bmi' is not a factor") : fvgen i.arm##c.age, simple(bmi)
    _fvgen_qa_assert_error, rc(198) msg("simple(): 'arm' is not a factor") : fvgen i.arm i.grp, simple(arm)
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
        _fvgen_qa_assert_error, rc(198) msg("does not support the omit operator") : fvgen `s'
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
    _fvgen_qa_assert_error, rc(198) msg("not found among observed levels of grp") : fvgen i.arm##i.grp, ref(grp "Nonesuch")
    * a label string that matches no observed level is 198
    _fvgen_qa_assert_error, rc(198) msg("not found among observed levels of arm") : fvgen i.arm##i.grp, ref(arm "x") replace
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
    _fvgen_qa_assert_error, rc(198) msg("supports up to 2-way interactions") : fvgen i.grp##i.arm##c.age
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
    local failed_tests "`failed_tests' 6"
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
    _fvgen_qa_assert_error, rc(198) msg("vsref() must contain @") : fvgen i.grp, vsref("vs base")
    * drop takes no other options, so vsref alongside drop is 198
    fvgen i.grp
    _fvgen_qa_assert_error, rc(198) msg("drop does not take varlists") : fvgen, drop vsref("(vs. @)")
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

**# 9. ref() naming an ibn. (no-base) factor is rejected (198)
* Clarity audit 2026-10-12 M2: ref() silently rewrote ibn.VAR to ibL.VAR and
* dropped the level the user asked for. ref() on another factor still works.
local ++test_count
capture noisily {
    _fvgen_make_data
    _fvgen_qa_assert_error, rc(198) msg("ref(): 'arm' is specified as ibn.arm (no base level)") : fvgen ibn.arm##c.age, ref(arm 0)
    capture confirm variable _arm_0
    assert _rc == 111
    fvgen ibn.arm##c.age i.grp, ref(grp 3)
    confirm variable _arm_0 _arm_1 _grp_1 _grp_2
    capture confirm variable _grp_3
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: ref() on ibn. factor rejected; other factors unaffected"
    local ++pass_count
}
else {
    display as error "  FAIL: ref() on ibn. factor (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}

**# 10. xsymbol() containing a double quote is accepted literally
* Clarity audit 2026-10-12 M3: the default test used simple quotes and failed
* with r(132) on an embedded double quote.
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##c.age, xsymbol(`"""')
    local lb : variable label _armXage_1
    mata: st_local("hasq", strofreal(strpos(st_local("lb"), char(34)) > 0))
    assert `hasq' == 1
}
if _rc == 0 {
    display as result "  PASS: xsymbol() with a double quote"
    local ++pass_count
}
else {
    display as error "  FAIL: xsymbol() with a double quote (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10"
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
