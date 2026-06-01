* test_qba_adversarial_confound_deep.do -- deep adversarial tests for qba_confound
* Package: qba
* Usage: cd qba/qa && stata-mp -b do test_qba_adversarial_confound_deep.do

clear all
version 16.0

* Bootstrap from package root derived from qa/ working directory.
capture do "_qba_qa_common.do"
if _rc {
    do "qa/_qba_qa_common.do"
}
_qba_qa_bootstrap, isolated
local qa_dir `"`r(qa_dir)'"'
local pkg_dir `"`r(pkg_dir)'"'
local _orig_plus `"`r(orig_plus)'"'
local _orig_personal `"`r(orig_personal)'"'
local _qba_plus `"`r(plusdir)'"'
local _qba_personal `"`r(personaldir)'"'
local _orig_varabbrev "`c(varabbrev)'"

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _post_onecoef
program define _post_onecoef, eclass
    syntax , CMD(string) B(real) SE(real) [COEF(string) LINK(string)]
    if "`coef'" == "" local coef "x"
    tempname bmat vmat
    matrix `bmat' = (`b')
    matrix colnames `bmat' = `coef'
    matrix `vmat' = (`se' ^ 2)
    matrix rownames `vmat' = `coef'
    matrix colnames `vmat' = `coef'
    ereturn post `bmat' `vmat'
    ereturn local cmd "`cmd'"
    if "`link'" != "" {
        ereturn local link "`link'"
    }
end

capture program drop _post_factor_binary
program define _post_factor_binary, eclass
    tempname bmat vmat
    matrix `bmat' = (0, ln(3), 0)
    matrix colnames `bmat' = 0b.exposed 1.exposed _cons
    matrix `vmat' = (0, 0, 0 \ 0, .04, 0 \ 0, 0, 0)
    matrix rownames `vmat' = 0b.exposed 1.exposed _cons
    matrix colnames `vmat' = 0b.exposed 1.exposed _cons
    ereturn post `bmat' `vmat'
    ereturn local cmd "logit"
end

capture program drop _post_two_actual
program define _post_two_actual, eclass
    tempname bmat vmat
    matrix `bmat' = (ln(2), ln(5), 0)
    matrix colnames `bmat' = x1 x2 _cons
    matrix `vmat' = (.01, 0, 0 \ 0, .01, 0 \ 0, 0, 0)
    matrix rownames `vmat' = x1 x2 _cons
    matrix colnames `vmat' = x1 x2 _cons
    ereturn post `bmat' `vmat'
    ereturn local cmd "logit"
end

**# D1: coef selection excludes omitted/base and constant columns
local ++test_count
capture noisily {
    _post_factor_binary
    qba_confound, from_model p1(.75) p0(.25) rrcd(5)
    _assert_close `=r(observed)' 3 1e-12
    _assert_close `=r(corrected)' 1.5 1e-12
    assert "`e(cmd)'" == "logit"
    _assert_close `=_b[1.exposed]' `=ln(3)' 1e-12

    _post_factor_binary
    capture qba_confound, from_model coef(0b.exposed) p1(.75) p0(.25) rrcd(5)
    assert _rc == 198
    assert "`e(cmd)'" == "logit"

    _post_factor_binary
    capture qba_confound, from_model coef(_cons) p1(.75) p0(.25) rrcd(5)
    assert _rc == 198
    assert "`e(cmd)'" == "logit"

    _post_two_actual
    capture qba_confound, from_model p1(.75) p0(.25) rrcd(5)
    assert _rc == 198

    _post_two_actual
    qba_confound, from_model coef(x2) p1(.75) p0(.25) rrcd(5)
    _assert_close `=r(observed)' 5 1e-12
    _assert_close `=r(corrected)' 2.5 1e-12
}
if _rc == 0 {
    display as result "  PASS: D1 coef selection rejects omitted/base ambiguity"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 coef selection ambiguity (error `=_rc')"
    local ++fail_count
}

**# D2: real from_model families preserve e()
local ++test_count
capture noisily {
    local bf = (.75 * (5 - 1) + 1) / (.25 * (5 - 1) + 1)

    sysuse auto, clear
    quietly logistic foreign mpg
    local b_before = _b[mpg]
    local se_before = _se[mpg]
    qba_confound, from_model p1(.75) p0(.25) rrcd(5)
    assert "`r(measure)'" == "OR"
    _assert_close `=r(observed)' `=exp(`b_before')' 1e-10
    _assert_close `=r(corrected)' `=exp(`b_before') / `bf'' 1e-10
    assert "`e(cmd)'" == "logistic"
    _assert_close `=_b[mpg]' `b_before' 1e-12
    _assert_close `=_se[mpg]' `se_before' 1e-12

    sysuse auto, clear
    quietly logit foreign mpg, nolog
    local b_before = _b[mpg]
    local se_before = _se[mpg]
    qba_confound, from_model p1(.75) p0(.25) rrcd(5)
    assert "`r(measure)'" == "OR"
    _assert_close `=r(observed)' `=exp(`b_before')' 1e-10
    assert "`e(cmd)'" == "logit"
    _assert_close `=_b[mpg]' `b_before' 1e-12
    _assert_close `=_se[mpg]' `se_before' 1e-12

    sysuse auto, clear
    quietly poisson rep78 mpg if rep78 < ., nolog
    local b_before = _b[mpg]
    local se_before = _se[mpg]
    qba_confound, from_model p1(.75) p0(.25) rrcd(5)
    assert "`r(measure)'" == "RR"
    _assert_close `=r(observed)' `=exp(`b_before')' 1e-10
    assert "`e(cmd)'" == "poisson"
    _assert_close `=_b[mpg]' `b_before' 1e-12
    _assert_close `=_se[mpg]' `se_before' 1e-12

    sysuse auto, clear
    quietly cloglog foreign mpg, nolog
    local b_before = _b[mpg]
    local se_before = _se[mpg]
    capture qba_confound, from_model p1(.75) p0(.25) rrcd(5)
    assert _rc == 198
    assert "`e(cmd)'" == "cloglog"
    _assert_close `=_b[mpg]' `b_before' 1e-12
    qba_confound, from_model measure(RR) p1(.75) p0(.25) rrcd(5)
    assert "`r(measure)'" == "RR"
    _assert_close `=r(observed)' `=exp(`b_before')' 1e-10
    assert "`e(cmd)'" == "cloglog"
    _assert_close `=_se[mpg]' `se_before' 1e-12

    sysuse auto, clear
    quietly regress price mpg
    local b_before = _b[mpg]
    local se_before = _se[mpg]
    local expected = `b_before' - (.75 - .25) * 6
    qba_confound, from_model p1(.75) p0(.25) confeffect(6)
    assert "`r(measure)'" == "coefficient"
    _assert_close `=r(observed)' `b_before' 1e-12
    _assert_close `=r(corrected)' `expected' 1e-10
    assert "`e(cmd)'" == "regress"
    _assert_close `=_b[mpg]' `b_before' 1e-12
    _assert_close `=_se[mpg]' `se_before' 1e-12
}
if _rc == 0 {
    display as result "  PASS: D2 real from_model families preserve e()"
    local ++pass_count
}
else {
    display as error "  FAIL: D2 real from_model families (error `=_rc')"
    local ++fail_count
}

**# D3: constant probabilistic mode equals simple mode
local ++test_count
capture noisily {
    qba_confound, estimate(3) p1(.75) p0(.25) rrcd(5)
    local simple_corr = r(corrected)
    local simple_bf = r(bias_factor)

    qba_confound, estimate(3) p1(.75) p0(.25) rrcd(5) reps(100) ///
        dist_p1("constant .75") dist_p0("constant .25") ///
        dist_rr("constant 5") seed(20260508)
    _assert_close `=r(corrected)' `simple_corr' 1e-12
    _assert_close `=r(mean)' `simple_corr' 1e-12
    _assert_close `=r(sd)' 0 1e-12
    _assert_close `simple_bf' 2 1e-12
    assert r(n_valid) == 100
    assert r(n_draw_invalid) == 0

    _post_onecoef, cmd(regress) b(4) se(.5) coef(x)
    qba_confound, from_model p1(.75) p0(.25) confeffect(6)
    local simple_linear = r(corrected)

    _post_onecoef, cmd(regress) b(4) se(.5) coef(x)
    qba_confound, from_model p1(.75) p0(.25) confeffect(6) reps(100) ///
        dist_p1("constant .75") dist_p0("constant .25") ///
        dist_confeffect("constant 6") seed(20260508)
    _assert_close `=r(corrected)' `simple_linear' 1e-12
    _assert_close `=r(mean)' `simple_linear' 1e-12
    _assert_close `=r(sd)' 0 1e-12
    assert r(n_valid) == 100
    assert r(n_draw_invalid) == 0
}
if _rc == 0 {
    display as result "  PASS: D3 constant probabilistic equivalence"
    local ++pass_count
}
else {
    display as error "  FAIL: D3 constant probabilistic equivalence (error `=_rc')"
    local ++fail_count
}

**# D4: invalid draw accounting matches saved missing results
local ++test_count
capture noisily {
    capture restore
    sysuse auto, clear
    datasignature
    local sig_before "`r(datasignature)'"
    tempfile draws

    qba_confound, estimate(2) p1(.9) p0(.2) rrcd(3) reps(500) ///
        dist_p1("uniform .8 1.2") dist_p0("constant .2") ///
        dist_rr("constant 3") seed(98765) saving("`draws'", replace)
    local reps = r(reps)
    local n_valid = r(n_valid)
    local n_draw_invalid = r(n_draw_invalid)
    assert `n_draw_invalid' > 0
    assert `n_valid' > 0
    assert `n_valid' + `n_draw_invalid' == `reps'

    datasignature
    assert "`r(datasignature)'" == "`sig_before'"

    preserve
    use "`draws'", clear
    assert _N == `reps'
    confirm variable p1
    confirm variable p0
    confirm variable rr_confounder
    confirm variable corrected_rr
    count if missing(corrected_rr)
    assert r(N) == `n_draw_invalid'
    count if !missing(corrected_rr)
    assert r(N) == `n_valid'
    restore
}
if _rc == 0 {
    display as result "  PASS: D4 invalid draw accounting and saved schema"
    local ++pass_count
}
else {
    capture restore
    display as error "  FAIL: D4 invalid draw accounting (error `=_rc')"
    local ++fail_count
}

**# D5: all-invalid draws preserve data and varabbrev
local ++test_count
capture noisily {
    capture restore
    sysuse auto, clear
    tempfile before_invalid
    save "`before_invalid'", replace
    datasignature
    local sig_before "`r(datasignature)'"

    set varabbrev off
    capture qba_confound, estimate(2) p1(.9) p0(.2) rrcd(3) reps(100) ///
        dist_p1("constant 1.2") dist_p0("constant .2") ///
        dist_rr("constant 3") seed(222)
    assert _rc == 198
    assert c(varabbrev) == "off"
    datasignature
    assert "`r(datasignature)'" == "`sig_before'"
    cf _all using "`before_invalid'"

    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: D5 all-invalid draws preserve caller state"
    local ++pass_count
}
else {
    capture restore
    set varabbrev on
    display as error "  FAIL: D5 all-invalid draw failure path (error `=_rc')"
    local ++fail_count
}

**# D6: save failure posts r() and preserves e()/data
local ++test_count
capture noisily {
    clear
    set obs 1
    gen byte marker = 1
    tempfile exists
    save "`exists'", replace

    _post_onecoef, cmd(logit) b(`=ln(3)') se(.2) coef(x)
    local b_before = _b[x]
    local se_before = _se[x]
    capture qba_confound, from_model p1(.75) p0(.25) rrcd(5) reps(100) ///
        dist_p1("constant .75") dist_p0("constant .25") ///
        dist_rr("constant 5") seed(123) saving("`exists'")
    local rc = _rc
    assert `rc' == 602
    _assert_close `=r(corrected)' 1.5 1e-12
    _assert_close `=r(mean)' 1.5 1e-12
    assert "`e(cmd)'" == "logit"
    _assert_close `=_b[x]' `b_before' 1e-12
    _assert_close `=_se[x]' `se_before' 1e-12
    assert _N == 1
    assert marker[1] == 1
}
if _rc == 0 {
    display as result "  PASS: D6 save failure preserves analytical returns and e()"
    local ++pass_count
}
else {
    display as error "  FAIL: D6 save failure returns/e() preservation (error `=_rc')"
    local ++fail_count
}

**# D7: varabbrev restores on success and parser errors
local ++test_count
capture noisily {
    foreach state in on off {
        set varabbrev `state'
        qba_confound, estimate(2) p1(.75) p0(.25) rrcd(5)
        assert c(varabbrev) == "`state'"

        set varabbrev `state'
        capture qba_confound, estimate(2) p1(2) p0(.25) rrcd(5)
        assert _rc == 198
        assert c(varabbrev) == "`state'"
    }
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: D7 varabbrev restores on success/error"
    local ++pass_count
}
else {
    set varabbrev on
    display as error "  FAIL: D7 varabbrev restore (error `=_rc')"
    local ++fail_count
}

_qba_qa_restore_isolation, origplus("`_orig_plus'") ///
    origpersonal("`_orig_personal'") plusdir("`_qba_plus'") ///
    personaldir("`_qba_personal'") uninstall
set varabbrev `_orig_varabbrev'

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_qba_adversarial_confound_deep tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_qba_adversarial_confound_deep tests=`test_count' pass=`pass_count' fail=`fail_count'"
