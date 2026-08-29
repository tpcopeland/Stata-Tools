*! test_regressions.do — Regression guards for review-discovered fvgen defects
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

capture program drop _fvgen_replay_probe
program define _fvgen_replay_probe, eclass
    version 16.0
    local replay_cmdline : copy local 0
    if strpos(`"`replay_cmdline'"', ".") {
        ereturn clear
        error 459
    }
    quietly regress `replay_cmdline'
    ereturn local cmdline `"_fvgen_replay_probe `replay_cmdline'"'
    ereturn local cmd "_fvgen_replay_probe"
end

capture program drop _fvgen_nonconvergence_probe
program define _fvgen_nonconvergence_probe, eclass
    version 16.0
    local replay_cmdline : copy local 0
    quietly regress `replay_cmdline'
    if strpos(`"`replay_cmdline'"', ".") {
        ereturn scalar converged = 0
    }
    else {
        ereturn scalar converged = 1
    }
    ereturn local cmdline `"_fvgen_nonconvergence_probe `replay_cmdline'"'
    ereturn local cmd "_fvgen_nonconvergence_probe"
end

**# 1. Distinct interaction terms must not collapse to one generated name
local ++test_count
capture noisily {
    clear
    set obs 20
    generate double a = _n
    generate double bXc = 2 * _n
    generate double aXb = 3 * _n
    generate double c = 4 * _n

    capture fvgen c.a#c.bXc c.aXb#c.c, replace
    local command_rc = _rc
    assert `command_rc' == 198
    capture confirm variable _aXbXc
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: structural generated-name collision rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: structural generated-name collision (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**# 2. replace must not overwrite a source variable needed by the specification
local ++test_count
capture noisily {
    clear
    set obs 20
    generate double x = _n
    generate double _x_c = 100 + _n
    generate double original_source = _x_c

    capture fvgen c.x##c._x_c, center replace
    local command_rc = _rc
    assert `command_rc' == 198
    assert _x_c == original_source
}
if _rc == 0 {
    display as result "  PASS: generated output cannot overwrite a source"
    local ++pass_count
}
else {
    display as error "  FAIL: source/output name collision (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# 3. A late existing-name collision must fail before creating earlier outputs
local ++test_count
capture noisily {
    clear
    set obs 20
    generate byte g = 1 + mod(_n, 2)
    generate double x = _n
    generate double _gXx_2 = 99

    capture fvgen i.g##c.x
    local command_rc = _rc
    assert `command_rc' == 110
    capture confirm variable _g_2
    assert _rc != 0
    assert _gXx_2 == 99
}
if _rc == 0 {
    display as result "  PASS: collision failure leaves no partial output"
    local ++pass_count
}
else {
    display as error "  FAIL: collision failure atomicity (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**# 4. A duplicated value-label string is ambiguous and must be rejected
local ++test_count
capture noisily {
    clear
    set obs 30
    generate byte g = 1 + mod(_n, 3)
    label define gl 1 "Same" 2 "Same" 3 "Other"
    label values g gl

    capture fvgen i.g, ref(g "Same")
    local command_rc = _rc
    assert `command_rc' == 198
    capture confirm variable _g_1
    assert _rc != 0
    capture confirm variable _g_3
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: ambiguous reference label rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: ambiguous reference label (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**# 5. A quoted numeric token is a value-label string, not a numeric code
local ++test_count
capture noisily {
    clear
    set obs 30
    generate byte g = 1 + mod(_n, 2)
    label define gn 1 "2" 2 "Other"
    label values g gn

    fvgen i.g, ref(g "2")
    assert strpos("`r(spec)'", "ib1.g") > 0
    capture confirm variable _g_1
    assert _rc != 0
    confirm variable _g_2
}
if _rc == 0 {
    display as result "  PASS: quoted numeric reference resolves by label"
    local ++pass_count
}
else {
    display as error "  FAIL: quoted numeric reference label (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

**# 6. Editing a source after the flattened fit must block the margins refit
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##c.age
    local allvars "`r(allvars)'"
    quietly regress y `allvars'
    local before_cmd "`e(cmd)'"
    local before_r2 = e(r2)

    replace age = age^2 if !missing(age)
    capture fvgen, margins
    local command_rc = _rc
    assert `command_rc' == 498
    assert "`e(cmd)'" == "`before_cmd'"
    assert !missing(e(r2), `before_r2')
    assert reldif(e(r2), `before_r2') < 1e-14
}
if _rc == 0 {
    display as result "  PASS: changed source blocks stale margins refit"
    local ++pass_count
}
else {
    display as error "  FAIL: changed-source margins guard (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

**# 7. Editing a generated regressor must also block the margins refit
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##c.age
    local allvars "`r(allvars)'"
    quietly regress y `allvars'
    local before_cmd "`e(cmd)'"
    local before_r2 = e(r2)

    replace _arm_1 = 1 - _arm_1 if !missing(_arm_1)
    capture fvgen, margins
    local command_rc = _rc
    assert `command_rc' == 498
    assert "`e(cmd)'" == "`before_cmd'"
    assert !missing(e(r2), `before_r2')
    assert reldif(e(r2), `before_r2') < 1e-14
}
if _rc == 0 {
    display as result "  PASS: changed generated variable blocks stale margins refit"
    local ++pass_count
}
else {
    display as error "  FAIL: changed-generated margins guard (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}

**# 8. An unrelated new variable does not invalidate the margins bridge
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##c.age
    local allvars "`r(allvars)'"
    quietly regress y `allvars'
    generate double unrelated = _n

    fvgen, margins
    assert "`r(margins)'" == "active"
    assert "`e(cmd)'" == "regress"
}
if _rc == 0 {
    display as result "  PASS: unrelated variable leaves margins provenance valid"
    local ++pass_count
}
else {
    display as error "  FAIL: unrelated-variable margins control (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}

**# 9. Changing the outcome must block a stale margins refit
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##c.age
    local allvars "`r(allvars)'"
    quietly regress y `allvars'
    tempname before_b after_b
    matrix `before_b' = e(b)
    local before_cmd "`e(cmd)'"

    replace y = y + 1000 if !missing(y)
    capture fvgen, margins
    local command_rc = _rc
    assert `command_rc' == 498
    assert "`e(cmd)'" == "`before_cmd'"
    matrix `after_b' = e(b)
    assert colsof(`after_b') == colsof(`before_b')
    forvalues j = 1/`=colsof(`before_b')' {
        assert !missing(`before_b'[1, `j'], `after_b'[1, `j'])
        assert reldif(`before_b'[1, `j'], `after_b'[1, `j']) < 1e-14
    }
}
if _rc == 0 {
    display as result "  PASS: changed outcome blocks stale margins refit"
    local ++pass_count
}
else {
    display as error "  FAIL: changed-outcome margins guard (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}

**# 10. A failed native replay must restore the active flattened estimate
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##c.age
    local allvars "`r(allvars)'"
    _fvgen_replay_probe y `allvars'
    tempname before_b after_b
    matrix `before_b' = e(b)
    local before_cmd "`e(cmd)'"

    capture fvgen, margins
    local command_rc = _rc
    assert `command_rc' == 459
    assert "`e(cmd)'" == "`before_cmd'"
    matrix `after_b' = e(b)
    assert colsof(`after_b') == colsof(`before_b')
    forvalues j = 1/`=colsof(`before_b')' {
        assert !missing(`before_b'[1, `j'], `after_b'[1, `j'])
        assert reldif(`before_b'[1, `j'], `after_b'[1, `j']) < 1e-14
    }
}
if _rc == 0 {
    display as result "  PASS: failed native replay restores active estimates"
    local ++pass_count
}
else {
    display as error "  FAIL: replay-failure estimate restore (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10"
}

**# 11. A nonconverged native replay must fail and restore active estimates
local ++test_count
capture noisily {
    _fvgen_make_data
    fvgen i.arm##c.age
    local allvars "`r(allvars)'"
    _fvgen_nonconvergence_probe y `allvars'
    tempname before_b after_b
    matrix `before_b' = e(b)
    local before_cmd "`e(cmd)'"

    capture fvgen, margins
    local command_rc = _rc
    assert `command_rc' == 430
    assert "`e(cmd)'" == "`before_cmd'"
    matrix `after_b' = e(b)
    assert colsof(`after_b') == colsof(`before_b')
    forvalues j = 1/`=colsof(`before_b')' {
        assert !missing(`before_b'[1, `j'], `after_b'[1, `j'])
        assert reldif(`before_b'[1, `j'], `after_b'[1, `j']) < 1e-14
    }
}
if _rc == 0 {
    display as result "  PASS: nonconverged replay restores active estimates"
    local ++pass_count
}
else {
    display as error "  FAIL: nonconverged replay guard (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11"
}

**# Summary
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED:`failed_tests'"
    display "RESULT: test_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
