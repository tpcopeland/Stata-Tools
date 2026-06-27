clear all
set varabbrev off
version 16.0

do _fvgen_qa_common.do
_fvgen_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# 1. Install smoke: command resolves from the sandboxed install
local ++test_count
capture noisily {
    findfile fvgen.ado
    assert strpos("`r(fn)'", "$FLATINT_QA_PLUS") > 0
    findfile fvgen.sthlp
    assert strpos("`r(fn)'", "$FLATINT_QA_PLUS") > 0
}
if _rc == 0 {
    display as result "  PASS: install smoke (ado + sthlp resolve)"
    local ++pass_count
}
else {
    display as error "  FAIL: install smoke (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**# 2. Autoload + crash-on-rerun: discard, then two calls in one session
local ++test_count
capture noisily {
    discard
    _fvgen_make_data
    * first call forces a fresh autoload of fvgen.ado (and its inline helpers)
    fvgen i.arm##c.age
    confirm variable _armXage_1
    * second call in the same session must not hit "program already defined"
    * (this exercises the inline helpers' cap-program-drop reload guards);
    * fresh data each time so the test isolates reuse, not variable collision
    _fvgen_make_data
    fvgen i.grp
    confirm variable _grp_2
    * third call confirms the helpers remain usable across repeated invocations
    _fvgen_make_data
    fvgen i.arm##c.bmi
    confirm variable _armXbmi_1
}
if _rc == 0 {
    display as result "  PASS: autoload + second in-session call"
    local ++pass_count
}
else {
    display as error "  FAIL: autoload / rerun (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# 3. Documented example (README/sthlp Example 1) runs as shown
local ++test_count
capture noisily {
    sysuse auto, clear
    fvgen i.foreign##c.mpg
    regress price `r(allvars)'
    assert e(N) == 74
}
if _rc == 0 {
    display as result "  PASS: documented Example 1 runs"
    local ++pass_count
}
else {
    display as error "  FAIL: documented example (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**# 4. Documented example 2 (cat-by-cat) runs as shown
local ++test_count
capture noisily {
    sysuse auto, clear
    label define rl 1 "Poor" 2 "Fair" 3 "Avg" 4 "Good" 5 "Best"
    label values rep78 rl
    fvgen i.foreign##i.rep78
    regress price `r(allvars)'
}
if _rc == 0 {
    display as result "  PASS: documented Example 2 runs"
    local ++pass_count
}
else {
    display as error "  FAIL: documented example 2 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**# Summary
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED:`failed_tests'"
    display "RESULT: test_package_release tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_package_release tests=`test_count' pass=`pass_count' fail=`fail_count'"
