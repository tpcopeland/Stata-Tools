* test_qba_adversarial_misclass_deep.do -- deep adversarial qba_misclass QA
* Package: qba
* Usage: cd qba/qa && stata-mp -b do test_qba_adversarial_misclass_deep.do

clear all
version 16.0

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
capture confirm file "`pkg_dir'/qba.pkg"
if _rc {
    local pkg_dir "`qa_dir'"
    capture confirm file "`pkg_dir'/qba.pkg"
    if _rc {
        display as error "could not locate qba package root from `c(pwd)'"
        exit 601
    }
    local qa_dir "`pkg_dir'/qa"
}

local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
local orig_varabbrev "`c(varabbrev)'"
tempfile plus_stub personal_stub
local plusdir "`plus_stub'_dir"
local personaldir "`personal_stub'_dir"
mkdir "`plusdir'"
mkdir "`personaldir'"
sysdir set PLUS "`plusdir'"
sysdir set PERSONAL "`personaldir'"

capture ado uninstall qba
quietly net install qba, from("`pkg_dir'") replace

capture findfile _qba_distributions.ado
if _rc {
    display as error "_qba_distributions.ado not found after install"
    exit 111
}
run "`r(fn)'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _assert_close
program define _assert_close
    args actual expected tolerance
    if "`tolerance'" == "" local tolerance = 0.000001
    local diff = abs(`actual' - `expected')
    if `diff' > `tolerance' {
        display as error "Expected: `expected', Got: `actual' (diff: `diff')"
        exit 9
    }
end

**# D1: Distribution parser contracts and varabbrev restore
local ++test_count
capture noisily {
    set varabbrev on
    _qba_parse_dist, dist("TRIANGULAR 0 .25 1")
    assert "`r(dtype)'" == "triangular"
    assert strtrim("`r(params)'") == "0 .25 1"
    assert "`c(varabbrev)'" == "on"

    set varabbrev off
    capture _qba_parse_dist, dist("uniform .8 .8")
    assert _rc == 198
    assert "`c(varabbrev)'" == "off"

    capture _qba_parse_dist, dist("constant")
    assert _rc == 198
    capture _qba_parse_dist, dist("trapezoidal 0 .9 .8 1")
    assert _rc == 198
    capture _qba_parse_dist, dist("logit-normal 0 -1")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: D1 distribution parser contracts"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 distribution parser contracts (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D1"
}

**# D2: Distribution draw support and degenerate invariants
local ++test_count
capture noisily {
    clear
    set obs 5000
    set seed 20260508
    _qba_draw_one, dist("uniform .2 .4") gen(u) n(5000)
    assert u >= .2 & u < .4
    summarize u, meanonly
    assert r(min) >= .2
    assert r(max) < .4

    _qba_draw_one, dist("beta 2 5") gen(be) n(5000)
    assert be > 0 & be < 1

    _qba_draw_one, dist("logit-normal 0 1") gen(ln) n(5000)
    assert ln > 0 & ln < 1

    _qba_draw_one, dist("triangular .7 .7 .7") gen(tri0) n(5000)
    assert tri0 == .7

    _qba_draw_one, dist("trapezoidal .6 .6 .6 .6") gen(trap0) n(5000)
    assert trap0 == .6

    _qba_draw_one, dist("triangular .1 .5 .9") gen(tri) n(5000)
    assert tri >= .1 & tri <= .9

    _qba_draw_one, dist("trapezoidal .1 .2 .8 .9") gen(trap) n(5000)
    assert trap >= .1 & trap <= .9
}
if _rc == 0 {
    display as result "  PASS: D2 distribution draw support and degeneracy"
    local ++pass_count
}
else {
    display as error "  FAIL: D2 distribution draw support and degeneracy (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D2"
}

**# D3: Differential saved schema, constants, and r() agreement
local ++test_count
capture noisily {
    tempfile diffsave
    qba_misclass, a(90) b(120) c(210) d(180) seca(.8) spca(.9) ///
        secb(.7) spcb(.85) type(outcome) measure(RR) reps(111) seed(111) ///
        dist_se("constant .8") dist_sp("constant .9") ///
        dist_se1("constant .7") dist_sp1("constant .85") ///
        saving("`diffsave'", replace)
    local r_corrected = r(corrected)
    local r_mean = r(mean)
    local r_lo = r(ci_lower)
    local r_hi = r(ci_upper)
    assert r(n_valid) == 111

    preserve
    use "`diffsave'", clear
    assert _N == 111
    ds
    assert "`r(varlist)'" == "se sp se1 sp1 a_corr b_corr c_corr d_corr corrected_rr"
    assert se == .8
    assert sp == .9
    assert se1 == .7
    assert sp1 == .85
    assert corrected_rr < .
    summarize corrected_rr, meanonly
    _assert_close `=r(min)' `r_corrected'
    _assert_close `=r(max)' `r_corrected'
    _assert_close `=r(mean)' `r_mean'
    _assert_close `r_lo' `r_corrected'
    _assert_close `r_hi' `r_corrected'
    _assert_close `=a_corr + c_corr' 300
    _assert_close `=b_corr + d_corr' 300
    restore
}
if _rc == 0 {
    display as result "  PASS: D3 differential saved schema and r() agreement"
    local ++pass_count
}
else {
    display as error "  FAIL: D3 differential saved schema and r() agreement (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D3"
}

**# D4: Probabilistic defaults for partial differential mode
local ++test_count
capture noisily {
    tempfile partialsave
    qba_misclass, a(90) b(120) c(210) d(180) seca(.8) spca(.9) ///
        secb(.7) type(exposure) reps(101) seed(222) ///
        dist_se("constant .8") dist_sp("constant .9") ///
        saving("`partialsave'", replace)
    assert r(n_valid) == 101

    preserve
    use "`partialsave'", clear
    assert _N == 101
    confirm variable se1
    confirm variable sp1
    assert se == .8
    assert sp == .9
    assert se1 == .7
    assert sp1 == .9
    _assert_close `=a_corr + b_corr' 210
    _assert_close `=c_corr + d_corr' 390
    restore
}
if _rc == 0 {
    display as result "  PASS: D4 partial differential defaults propagate to saved draws"
    local ++pass_count
}
else {
    display as error "  FAIL: D4 partial differential defaults (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D4"
}

**# D5: Option gating and expected error codes
local ++test_count
capture noisily {
    capture qba_misclass, a(90) b(120) c(210) d(180) seca(.8) spca(.9) ///
        reps(99)
    assert _rc == 198
    capture qba_misclass, a(90) b(120) c(210) d(180) seca(.8) spca(.9) ///
        seed(1)
    assert _rc == 198
    capture qba_misclass, a(90) b(120) c(210) d(180) seca(.8) spca(.9) ///
        saving(foo, replace)
    assert _rc == 198
    capture qba_misclass, a(90) b(120) c(210) d(180) seca(.8) spca(.9) ///
        dist_se("constant .8")
    assert _rc == 198
    capture qba_misclass, a(90) b(120) c(210) d(180) seca(.8) spca(.9) ///
        reps(100) dist_se1("constant .7")
    assert _rc == 198
    capture qba_misclass, a(90) b(120) c(210) d(180) seca(.8) spca(.9) ///
        reps(100) dist_sp1("constant .85")
    assert _rc == 198
    capture qba_misclass, a(0) b(0) c(0) d(0) seca(.8) spca(.9)
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: D5 option gating errors"
    local ++pass_count
}
else {
    display as error "  FAIL: D5 option gating errors (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D5"
}

**# D6: Caller data and varabbrev survive success and failure paths
local ++test_count
capture noisily {
    clear
    input int id double value
    3 30
    1 10
    2 20
    end
    gen int seq = _n
    tempfile before_state
    save "`before_state'", replace

    set varabbrev on
    qba_misclass, a(90) b(120) c(210) d(180) seca(.8) spca(.9) ///
        secb(.7) spcb(.85) type(outcome) measure(RR) reps(101) seed(333) ///
        dist_se("constant .8") dist_sp("constant .9") ///
        dist_se1("constant .7") dist_sp1("constant .85")
    assert "`c(varabbrev)'" == "on"
    cf _all using "`before_state'"

    set varabbrev off
    capture qba_misclass, a(90) b(120) c(210) d(180) seca(.8) spca(.9) ///
        reps(100) dist_se("uniform bad params")
    local rc = _rc
    assert `rc' == 198
    assert "`c(varabbrev)'" == "off"
    cf _all using "`before_state'"

    set varabbrev on
    capture qba_misclass, a(90) b(120) c(210) d(180) seca(.8) spca(.9) ///
        reps(100) dist_se("constant .2") dist_sp("constant .7")
    local rc = _rc
    assert `rc' == 198
    assert "`c(varabbrev)'" == "on"
    cf _all using "`before_state'"
}
if _rc == 0 {
    display as result "  PASS: D6 data and varabbrev preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: D6 data and varabbrev preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D6"
}

**# D7: Helper draw errors do not mutate caller state
local ++test_count
capture noisily {
    clear
    input int id double value
    1 1.5
    2 2.5
    end
    tempfile before_helper
    save "`before_helper'", replace

    set varabbrev on
    capture _qba_draw_one, dist("uniform .8 .8") gen(draw) n(2)
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
    capture confirm variable draw
    assert _rc != 0
    cf _all using "`before_helper'"

    capture _qba_draw_scalar, dist("trapezoidal .1 .8 .2 .9")
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
    cf _all using "`before_helper'"
}
if _rc == 0 {
    display as result "  PASS: D7 helper error paths preserve caller state"
    local ++pass_count
}
else {
    display as error "  FAIL: D7 helper error path preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D7"
}

capture ado uninstall qba
capture sysdir set PLUS "`orig_plus'"
capture sysdir set PERSONAL "`orig_personal'"
capture shell rm -rf "`plusdir'" "`personaldir'"
set varabbrev `orig_varabbrev'

display as text ""
display as result "Deep adversarial misclass Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_qba_adversarial_misclass_deep tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_qba_adversarial_misclass_deep tests=`test_count' pass=`pass_count' fail=`fail_count'"
