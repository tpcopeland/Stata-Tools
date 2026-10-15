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

**# 19. A rejected run leaves the previous run's provenance intact
* An earlier build cleared every _dta[fvgen_*] char before validating, so a call that
* correctly failed r(110) still made the earlier model unusable by margins.
local ++test_count
capture noisily {
    sysuse auto, clear
    fvgen i.foreign##c.mpg
    regress price `r(allvars)'
    generate byte _rep78_3 = 1
    _fvgen_qa_assert_error, rc(110) msg("variable '_rep78_3' already exists") : fvgen i.rep78
    local spec : char _dta[fvgen_spec]
    assert "`spec'" == "i.foreign mpg i.foreign#c.mpg"
    fvgen, margins
    assert "`r(margins)'" == "active"
    assert "`e(fvgen_margins)'" == "1"
    assert strpos(`"`e(fvgen_native_cmdline)'"', "regress price i.foreign mpg i.foreign#c.mpg")
    * a call that has nothing to materialize is also rejected without
    * touching the provenance
    sysuse auto, clear
    fvgen i.foreign##c.mpg
    regress price `r(allvars)'
    _fvgen_qa_assert_error, rc(198) msg("no variables to materialize") : fvgen ib1.foreign if foreign == 1
    local spec : char _dta[fvgen_spec]
    assert "`spec'" == "i.foreign mpg i.foreign#c.mpg"
    fvgen, margins
    assert "`e(fvgen_margins)'" == "1"
}
if _rc == 0 {
    display as result "  PASS: rejected run keeps prior provenance"
    local ++pass_count
}
else {
    display as error "  FAIL: provenance after rejected run (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 19"
}

**# 20. margins replays the user's command line under the user's varabbrev
* An earlier build forced varabbrev off for the refit, so an abbreviated depvar that the
* flattened fit accepted made the native replay fail r(111).
local ++test_count
capture noisily {
    sysuse auto, clear
    set varabbrev on
    fvgen i.foreign##c.mpg
    regress pri `r(allvars)'
    local flat_r2 = e(r2)
    fvgen, margins
    assert "`c(varabbrev)'" == "on"
    assert "`e(depvar)'" == "price"
    assert !missing(e(r2), `flat_r2')
    assert reldif(e(r2), `flat_r2') < 1e-12
    set varabbrev off
}
local rc20 = _rc
set varabbrev off
if `rc20' == 0 {
    display as result "  PASS: refit honours the caller's varabbrev on"
    local ++pass_count
}
else {
    display as error "  FAIL: varabbrev during margins refit (rc=`rc20')"
    local ++fail_count
    local failed_tests "`failed_tests' 20"
}

**# 21. Generated-name length is counted in characters, not bytes
local ++test_count
capture noisily {
    clear
    set obs 10
    * 29 two-byte characters: _<29>_1 is 32 characters (62 bytes)
    generate byte ååååååååååååååååååååååååååååå = mod(_n, 2)
    fvgen i.ååååååååååååååååååååååååååååå
    confirm variable _ååååååååååååååååååååååååååååå_1
    * 30 characters: _<30>_1 is 33 characters and must still be refused
    generate byte åååååååååååååååååååååååååååååå = mod(_n, 2)
    local k0 = c(k)
    _fvgen_qa_assert_error, rc(198) msg("exceeds the 32-character limit") : fvgen i.åååååååååååååååååååååååååååååå
    assert c(k) == `k0'
}
if _rc == 0 {
    display as result "  PASS: 32-character Unicode names accepted, 33 refused"
    local ++pass_count
}
else {
    display as error "  FAIL: Unicode name length (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 21"
}

**# 22. ref() naming one variable twice reports the duplicate
local ++test_count
capture noisily {
    sysuse auto, clear
    local k0 = c(k)
    _fvgen_qa_assert_error, rc(198) msg("ref(): variable 'rep78' specified more than once") : fvgen i.rep78, ref(rep78 2, rep78 4)
    * reported as a duplicate even when the second level is also invalid
    _fvgen_qa_assert_error, rc(198) msg("ref(): variable 'rep78' specified more than once") : fvgen i.rep78, ref(rep78 2, rep78 99)
    assert c(k) == `k0'
}
if _rc == 0 {
    display as result "  PASS: duplicate ref() variable reported"
    local ++pass_count
}
else {
    display as error "  FAIL: duplicate ref() variable (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 22"
}

**# 23. Under center + replace, a weight that reads a centered copy is refused
* Under center + replace, the centered copy is dropped before the weight is read.
local ++test_count
capture noisily {
    sysuse auto, clear
    generate double _mpg_c = 1 + mod(_n, 3)
    generate double keep_w = _mpg_c
    * prior provenance and the data must survive every refused weight type
    fvgen i.rep78
    local spec0 : char _dta[fvgen_spec]
    local sig0  : char _dta[fvgen_signature]
    local k0 = c(k)
    foreach wt in aw fw pw iw {
        _fvgen_qa_assert_error, rc(198) msg("the weight expression uses '_mpg_c'") : fvgen i.foreign##c.mpg [`wt'=2*_mpg_c], center replace
        confirm variable _mpg_c
        assert _mpg_c == keep_w
        assert c(k) == `k0'
        assert "`: char _dta[fvgen_spec]'" == "`spec0'"
        assert "`: char _dta[fvgen_signature]'" == "`sig0'"
    }
    fvgen, drop
    * without replace the collision stays an r(110) existence error
    _fvgen_qa_assert_error, rc(110) msg("variable '_mpg_c' already exists") : fvgen i.foreign##c.mpg [aw=_mpg_c], center
    * a weight naming a non-centered output is read before that output is
    * replaced, so it is not refused, with or without center
    generate double _foreign_1 = 1 + mod(_n, 2)
    generate double keep_f = _foreign_1
    fvgen i.foreign [aw=_foreign_1], replace
    replace _foreign_1 = keep_f
    fvgen i.foreign##c.mpg [aw=_foreign_1], center replace
    quietly summarize mpg [aw=keep_f]
    assert !missing(_mpg_c, mpg - r(mean))
    assert reldif(_mpg_c, mpg - r(mean)) < 1e-12
    drop _foreign_1 keep_f
    * names that merely contain an output name, including Unicode letters
    generate double w_mpg_c2 = keep_w
    generate double _mpg_cé = keep_w
    generate double é_mpg_c = keep_w
    foreach w in w_mpg_c2 _mpg_cé é_mpg_c {
        fvgen i.foreign##c.mpg [aw=`w'], center replace
        assert "`r(genvars)'" == "_mpg_c _foreign_1 _foreignXmpg_1"
    }
}
if _rc == 0 {
    display as result "  PASS: weight reading a centered copy refused under center + replace"
    local ++pass_count
}
else {
    display as error "  FAIL: weight/output collision (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 23"
}

**# 24. List provenance on wide data is chunked under the characteristic limit
* One characteristic holds at most 67,784 bytes. The sigvars, allvars and
* terms inventories of a wide dataset exceed it; this used to fail r(1004)
* after the generated variables had already been created.
local ++test_count
capture noisily {
    clear
    set obs 3000
    set seed 24
    generate double y = rnormal()
    generate byte a = runiformint(1, 3)
    generate double x = rnormal()
    forvalues i = 1/2400 {
        quietly generate float v_abcdefghijklmnopqrstuvwx_`i' = rnormal()
    }
    quietly fvgen i.a##c.x v_abcdefghijklmnopqrstuvwx_1-v_abcdefghijklmnopqrstuvwx_2400
    local allv `r(allvars)'
    assert `: word count `allv'' == 2405
    assert "`r(genvars)'" == "_a_2 _a_3 _aXx_2 _aXx_3"
    * each inventory spans more than one chunk and reassembles exactly
    unab all_now : _all
    foreach c in allvars sigvars {
        local c1 : char _dta[fvgen_`c']
        local c2 : char _dta[fvgen_`c'_2]
        local c3 : char _dta[fvgen_`c'_3]
        assert `"`c2'"' != ""
        assert `"`c3'"' == ""
        assert strlen(`"`c1'"') <= 67784 & strlen(`"`c2'"') <= 67784
        if "`c'" == "allvars" assert `"`c1' `c2'"' == `"`allv'"'
        if "`c'" == "sigvars" assert `"`c1' `c2'"' == `"`all_now'"'
    }
    quietly regress y `allv'
    tempname bflat
    matrix `bflat' = e(b)
    fvgen, margins
    assert "`e(fvgen_margins)'" == "1"
    foreach v in x v_abcdefghijklmnopqrstuvwx_2400 {
        local b_nat = _b[`v']
        local b_flat = `bflat'[1, colnumb(`bflat', "`v'")]
        assert !missing(`b_nat') & !missing(`b_flat')
        assert reldif(`b_nat', `b_flat') < 1e-10
    }
    * a change to a variable recorded only in the second chunk is still stale
    quietly regress y `allv'
    quietly replace v_abcdefghijklmnopqrstuvwx_2400 = 0 in 1
    capture fvgen, margins
    assert _rc == 498
    * a shorter re-run leaves no continuation chunk from the wide run
    drop v_abcdefghijklmnopqrstuvwx_*
    quietly fvgen i.a##c.x, replace
    foreach c in allvars sigvars terms genvars {
        local c1 : char _dta[fvgen_`c']
        local c2 : char _dta[fvgen_`c'_2]
        assert `"`c1'"' != ""
        assert `"`c2'"' == ""
    }
    unab all_now : _all
    assert `"`: char _dta[fvgen_sigvars]'"' == `"`all_now'"'
    * teardown clears every chunk (positive control: chars exist first)
    local dchars : char _dta[]
    local pre_hits = 0
    foreach ch of local dchars {
        if substr("`ch'", 1, 6) == "fvgen_" local ++pre_hits
    }
    assert `pre_hits' > 0
    fvgen, drop
    local dchars : char _dta[]
    local hits = 0
    foreach ch of local dchars {
        if substr("`ch'", 1, 6) == "fvgen_" local ++hits
    }
    assert `hits' == 0
}
if _rc == 0 {
    display as result "  PASS: wide-data provenance chunked, margins and stale guard intact"
    local ++pass_count
}
else {
    display as error "  FAIL: wide-data provenance (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 24"
}

**# 25. Console output carries no internal-command noise
* Every documented workflow is logged and read back: the deliberate fvgen
* messages must be present, and estimator tables, iteration logs, replay or
* bootstrap chatter, "real changes made" notes and error codes must not be.
local ++test_count
capture noisily {
    tempfile noise_log
    sysuse auto, clear
    label define rl 1 "Poor" 2 "Fair" 3 "Avg" 4 "Good" 5 "Best"
    label values rep78 rl
    generate byte hp = price > 6000
    capture log close _fvgen_noise
    log using "`noise_log'", text replace name(_fvgen_noise)
    fvgen i.foreign##c.mpg
    fvgen i.foreign##i.rep78, replace
    fvgen c.mpg##c.weight [pw=weight], center replace
    fvgen i.foreign##i.rep78, alllevels xsymbol(x) replace
    fvgen i.foreign##i.rep78, ref(rep78 3) replace
    fvgen i.foreign##c.mpg, simple(foreign) replace
    fvgen i.foreign##c.mpg, ref(foreign "Domestic") replace
    fvgen i.foreign##i.rep78, vsref("(vs. @)") replace
    fvgen, drop
    fvgen i.foreign##c.mpg, replace
    quietly regress price _foreign_1 mpg _foreignXmpg_1
    fvgen, margins store(m_noise) replace
    fvgen, margins
    quietly logit hp _foreign_1 mpg _foreignXmpg_1
    fvgen, margins
    quietly bootstrap, reps(5) seed(25): regress price _foreign_1 mpg _foreignXmpg_1
    fvgen, margins
    fvgen, drop
    fvgen, drop
    log close _fvgen_noise
    estimates drop m_noise

    local want_created = 0
    local want_margins = 0
    local want_stored = 0
    local want_dropped = 0
    local want_none = 0
    local noise = 0
    tempname fh
    file open `fh' using "`noise_log'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "fvgen created ") local ++want_created
        if strpos(`"`macval(line)'"', "fvgen rebuilt the active estimates") local ++want_margins
        if strpos(`"`macval(line)'"', "fvgen stored margins-ready estimates as m_noise") local ++want_stored
        if strpos(`"`macval(line)'"', "fvgen dropped ") local ++want_dropped
        if strpos(`"`macval(line)'"', "no fvgen-generated variables found") local ++want_none
        foreach pat in "real change" "variable created" "Number of obs" "Coefficient" ///
            "Iteration " "Log likelihood" "replications" "Source |" "(output omitted)" ///
            "datasignature" "estimation sample" "note:" {
            if strpos(`"`macval(line)'"', "`pat'") {
                display as error `"noise: `macval(line)'"'
                local ++noise
            }
        }
        if regexm(`"`macval(line)'"', "^r\([0-9]+\);") {
            display as error `"error in log: `macval(line)'"'
            local ++noise
        }
        file read `fh' line
    }
    file close `fh'
    assert `want_created' == 9
    assert `want_margins' == 3
    assert `want_stored' == 1
    assert `want_dropped' == 2
    assert `want_none' == 1
    assert `noise' == 0
}
if _rc == 0 {
    display as result "  PASS: documented workflows print only fvgen's own messages"
    local ++pass_count
}
else {
    local noise_rc = _rc
    capture log close _fvgen_noise
    display as error "  FAIL: console noise (rc=`noise_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 25"
}

**# 26. A large factor-by-factor design on narrow data is chunked too
* Two 47-level factors on a full grid give 2,208 generated variables; the
* terms, allvars and genvars inventories then exceed one characteristic.
local ++test_count
capture noisily {
    clear
    set obs 47
    generate int regioncode12 = _n
    expand 47
    bysort regioncode12: generate int cliniccode12 = _n
    expand 2
    set seed 26
    generate double y = rnormal()
    quietly fvgen i.regioncode12##i.cliniccode12
    local allv `r(allvars)'
    local genv `r(genvars)'
    assert r(k_all) == 2208 & r(k_int) == 46 * 46
    foreach c in terms allvars genvars sigvars {
        local c1 : char _dta[fvgen_`c']
        local c2 : char _dta[fvgen_`c'_2]
        assert `"`c1'"' != "" & `"`c2'"' != ""
        assert strlen(`"`c1'"') <= 67784 & strlen(`"`c2'"') <= 67784
        if "`c'" == "allvars" assert `"`c1' `c2'"' == `"`allv'"'
        if "`c'" == "genvars" assert `"`c1' `c2'"' == `"`genv'"'
    }
    quietly regress y `allv'
    local flat_b = _b[_regioncode12Xcliniccode12_47_47]
    local flat_r2 = e(r2)
    fvgen, margins
    local nat_b = _b[47.regioncode12#47.cliniccode12]
    assert !missing(`flat_b') & !missing(`nat_b')
    assert reldif(`flat_b', `nat_b') < 1e-8
    local nat_r2 = e(r2)
    assert !missing(`flat_r2') & !missing(`nat_r2')
    assert reldif(`flat_r2', `nat_r2') < 1e-10
    local dchars : char _dta[]
    local pre_hits = 0
    foreach ch of local dchars {
        if substr("`ch'", 1, 6) == "fvgen_" local ++pre_hits
    }
    assert `pre_hits' > 0
    fvgen, drop
    assert r(k_dropped) == 2208
    local dchars : char _dta[]
    local hits = 0
    foreach ch of local dchars {
        if substr("`ch'", 1, 6) == "fvgen_" local ++hits
    }
    assert `hits' == 0
}
if _rc == 0 {
    display as result "  PASS: factor-by-factor provenance chunked, margins and drop intact"
    local ++pass_count
}
else {
    display as error "  FAIL: factor-by-factor provenance (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 26"
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
