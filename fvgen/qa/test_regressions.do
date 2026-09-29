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

**# 12. fvgen on a narrower if-sample than the estimator must block margins
* Levels outside the fvgen sample are lumped with the base in the flattened
* fit; the native refit estimates them, so it is a different model.
local ++test_count
capture noisily {
    sysuse auto, clear
    fvgen i.rep78 if foreign == 1
    local av "`r(allvars)'"
    assert "`av'" == "_rep78_4 _rep78_5"
    quietly regress price `av'
    local flat_names : colnames e(b)
    local flat_rank = e(rank)
    assert `flat_rank' == 3
    * independent oracle: the native model on the same sample has rank 5
    quietly regress price i.rep78
    assert e(rank) == 5
    quietly regress price `av'

    capture fvgen, margins
    local command_rc = _rc
    assert `command_rc' == 498
    assert "`e(cmd)'" == "regress"
    local active_names : colnames e(b)
    assert `"`active_names'"' == `"`flat_names'"'
    assert e(rank) == `flat_rank'
}
if _rc == 0 {
    display as result "  PASS: if-sample mismatch blocks the margins refit"
    local ++pass_count
}
else {
    display as error "  FAIL: if-sample mismatch margins guard (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 12"
}

**# 13. alllevels + noconstant must block margins; alllevels + constant must not
local ++test_count
capture noisily {
    sysuse auto, clear
    fvgen i.rep78, alllevels
    local av "`r(allvars)'"
    quietly regress price `av', noconstant
    assert e(rank) == 5
    quietly regress price i.rep78, noconstant
    assert e(rank) == 4
    quietly regress price `av', noconstant
    capture fvgen, margins
    local command_rc = _rc
    assert `command_rc' == 498
    assert "`e(cmd)'" == "regress"
    assert e(rank) == 5

    * with a constant the two designs span the same space: bridge proceeds
    quietly regress price i.rep78
    quietly margins rep78
    tempname native_m flat_m
    matrix `native_m' = r(b)
    quietly regress price `av'
    fvgen, margins
    assert "`r(margins)'" == "active"
    quietly margins rep78
    matrix `flat_m' = r(b)
    assert colsof(`flat_m') == colsof(`native_m')
    forvalues j = 1/`=colsof(`native_m')' {
        assert !missing(`native_m'[1, `j'], `flat_m'[1, `j'])
        assert reldif(`native_m'[1, `j'], `flat_m'[1, `j']) < 1e-9
    }
}
if _rc == 0 {
    display as result "  PASS: alllevels noconstant refused; alllevels constant bridged"
    local ++pass_count
}
else {
    display as error "  FAIL: alllevels margins equivalence guard (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 13"
}

**# 14. Matching if-samples (and a subgroup fit) still bridge exactly
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price i.rep78##c.mpg if foreign == 0
    quietly margins rep78
    tempname native_m flat_m
    matrix `native_m' = r(b)

    fvgen i.rep78##c.mpg
    quietly regress price `r(allvars)' if foreign == 0
    fvgen, margins
    assert "`r(margins)'" == "active"
    quietly margins rep78
    matrix `flat_m' = r(b)
    assert colsof(`flat_m') == colsof(`native_m')
    forvalues j = 1/`=colsof(`native_m')' {
        assert !missing(`native_m'[1, `j'], `flat_m'[1, `j'])
        assert reldif(`native_m'[1, `j'], `flat_m'[1, `j']) < 1e-9
    }
    fvgen, drop

    fvgen i.rep78 if foreign == 1
    quietly regress price `r(allvars)' if foreign == 1
    fvgen, margins
    assert "`r(margins)'" == "active"
    assert e(N) == 21
}
if _rc == 0 {
    display as result "  PASS: equivalent subgroup fits still bridge"
    local ++pass_count
}
else {
    display as error "  FAIL: equivalent subgroup margins bridge (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 14"
}

**# 15. store() without replace must not clobber an existing stored estimate
local ++test_count
capture noisily {
    sysuse auto, clear
    capture estimates drop fvkeep
    quietly regress price weight
    estimates store fvkeep
    fvgen i.foreign##c.mpg
    quietly regress price `r(allvars)'
    local flat_names : colnames e(b)

    capture fvgen, margins store(fvkeep)
    local command_rc = _rc
    assert `command_rc' == 110
    local active_names : colnames e(b)
    assert `"`active_names'"' == `"`flat_names'"'
    estimates restore fvkeep
    assert `"`e(cmdline)'"' == "regress price weight"

    quietly regress price _foreign_1 mpg _foreignXmpg_1
    fvgen, margins store(fvkeep) replace
    assert "`r(stored)'" == "fvkeep"
    estimates restore fvkeep
    assert "`e(fvgen_margins)'" == "1"
    estimates drop fvkeep
}
if _rc == 0 {
    display as result "  PASS: store() refuses to overwrite without replace"
    local ++pass_count
}
else {
    display as error "  FAIL: store() clobber guard (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 15"
}

**# 16. A level missing from an attached value label is labeled var=level
local ++test_count
capture noisily {
    sysuse auto, clear
    label define fv_rl 1 "Poor" 3 "Avg"
    label values rep78 fv_rl
    fvgen i.rep78##c.mpg, vsref("(vs. @)")
    assert `"`: variable label _rep78_2'"' == `"rep78=2 (vs. Poor)"'
    assert `"`: variable label _rep78_3'"' == `"Avg (vs. Poor)"'
    assert `"`: variable label _rep78Xmpg_4'"' == `"rep78=4 × Mileage (mpg)"'
    assert `"`: variable label _rep78Xmpg_3'"' == `"Avg × Mileage (mpg)"'
    fvgen i.rep78, ref(rep78 2) vsref("(vs. @)") replace
    assert `"`: variable label _rep78_1'"' == `"Poor (vs. rep78=2)"'
}
if _rc == 0 {
    display as result "  PASS: partially labeled factor keeps var=level context"
    local ++pass_count
}
else {
    display as error "  FAIL: partial value-label fallback (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16"
}

**# 17. String variables are rejected by name, not as "no observations"
local ++test_count
capture noisily {
    sysuse auto, clear
    local k0 = c(k)
    capture fvgen make
    assert _rc == 109
    capture fvgen i.foreign##c.make
    assert _rc == 109
    capture fvgen i.foreign make, center
    assert _rc == 109
    assert c(k) == `k0'
}
if _rc == 0 {
    display as result "  PASS: string variables rejected with r(109)"
    local ++pass_count
}
else {
    display as error "  FAIL: string variable rejection (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 17"
}

**# 18. ref()/simple() with i(numlist) report the unsupported form
local ++test_count
capture noisily {
    sysuse auto, clear
    tempfile msglog
    local k0 = c(k)
    capture log close _fvgen_msg
    quietly log using "`msglog'", text replace name(_fvgen_msg)
    capture noisily fvgen i(2 3 4).rep78, ref(rep78 3)
    local rc_ref = _rc
    capture noisily fvgen i(0 1).foreign##c.mpg, simple(foreign)
    local rc_simple = _rc
    quietly log close _fvgen_msg
    assert `rc_ref' == 198
    assert `rc_simple' == 198
    assert c(k) == `k0'
    * both refusals name the unsupported level-restricted form
    local hits = 0
    tempname fh
    file open `fh' using "`msglog'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "level-restricted factors") local ++hits
        file read `fh' line
    }
    file close `fh'
    assert `hits' == 2
    * a plain ib(freq) factor still accepts ref()
    fvgen ib(freq).rep78##c.mpg, ref(rep78 4)
    assert "`r(spec)'" == "ib4.rep78 mpg ib4.rep78#c.mpg"
}
if _rc == 0 {
    display as result "  PASS: i(numlist) with ref()/simple() refused explicitly"
    local ++pass_count
}
else {
    display as error "  FAIL: i(numlist) ref()/simple() message (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 18"
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
