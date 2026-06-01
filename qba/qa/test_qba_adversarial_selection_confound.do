* test_qba_adversarial_selection_confound.do -- adversarial tests for qba_selection and qba_confound
* Package: qba (Quantitative Bias Analysis)
* Usage: cd qba/qa && stata-mp -b do test_qba_adversarial_selection_confound.do

clear all
version 16.0

* Bootstrap from package root derived from qa/ working directory.
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

local _orig_plus "`c(sysdir_plus)'"
local _orig_personal "`c(sysdir_personal)'"
local _orig_varabbrev "`c(varabbrev)'"
tempfile _qba_plus_stub _qba_personal_stub
local _qba_plus "`_qba_plus_stub'_dir"
local _qba_personal "`_qba_personal_stub'_dir"
mkdir "`_qba_plus'"
mkdir "`_qba_personal'"
sysdir set PLUS "`_qba_plus'"
sysdir set PERSONAL "`_qba_personal'"

capture ado uninstall qba
quietly net install qba, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _assert_close
program define _assert_close
    args actual expected tolerance
    if "`tolerance'" == "" local tolerance = 0.0001
    if missing(`actual') | missing(`expected') {
        assert missing(`actual') & missing(`expected')
        exit
    }
    local diff = abs(`actual' - `expected')
    if `diff' > `tolerance' {
        display as error "Expected: `expected', Got: `actual' (diff: `diff')"
        exit 9
    }
end

capture program drop _assert_reldif
program define _assert_reldif
    args actual expected tolerance
    if "`tolerance'" == "" local tolerance = 1e-8
    if missing(`actual') | missing(`expected') {
        assert missing(`actual') & missing(`expected')
        exit
    }
    local diff = reldif(`actual', `expected')
    if `diff' > `tolerance' {
        display as error "Expected: `expected', Got: `actual' (reldif: `diff')"
        exit 9
    }
end

**# A1: selection probabilities reject zero and tolerate near-zero support
local ++test_count
capture noisily {
    capture qba_selection, a(10) b(20) c(30) d(40) ///
        sela(0) selb(.5) selc(.5) seld(.5)
    assert _rc == 198

    capture qba_selection, a(10) b(20) c(30) d(40) ///
        sela(.5) selb(-.01) selc(.5) seld(.5)
    assert _rc == 198

    capture qba_selection, a(10) b(20) c(30) d(40) ///
        sela(.5) selb(.5) selc(1.0000001) seld(.5)
    assert _rc == 198

    qba_selection, a(10) b(20) c(30) d(40) ///
        sela(1e-8) selb(.5) selc(.25) seld(.75)
    local expected_a = 10 / 1e-8
    local expected_b = 20 / .5
    local expected_c = 30 / .25
    local expected_d = 40 / .75
    _assert_reldif `=r(corrected_a)' `expected_a' 1e-12
    _assert_reldif `=r(corrected_b)' `expected_b' 1e-12
    _assert_reldif `=r(corrected_c)' `expected_c' 1e-12
    _assert_reldif `=r(corrected_d)' `expected_d' 1e-12
    assert r(corrected) < .
}
if _rc == 0 {
    display as result "  PASS: A1 selection zero/near-zero probabilities"
    local ++pass_count
}
else {
    display as error "  FAIL: A1 selection zero/near-zero probabilities (error `=_rc')"
    local ++fail_count
}

**# A2: invalid and partial confounding parameters are rejected
local ++test_count
capture noisily {
    capture qba_confound, estimate(2) p1(-.01) p0(.2) rrcd(2)
    assert _rc == 198

    capture qba_confound, estimate(2) p1(.4) p0(1.01) rrcd(2)
    assert _rc == 198

    capture qba_confound, estimate(2) p1(.4) p0(.2) rrcd(0)
    assert _rc == 198

    capture qba_confound, estimate(2) p1(.4) p0(.2) rrud(-1)
    assert _rc == 198

    capture qba_confound, estimate(2) evalue p1(.4) p0(.2)
    assert _rc == 198

    capture qba_confound, estimate(2) evalue rrcd(0)
    assert _rc == 198

    capture qba_confound, estimate(2) evalue p1(2)
    assert _rc == 198

    sysuse auto, clear
    quietly regress price mpg
    capture qba_confound, from_model p1(.2) p0(.1) confeffect(.)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: A2 invalid and partial confounding parameters"
    local ++pass_count
}
else {
    display as error "  FAIL: A2 invalid and partial confounding parameters (error `=_rc')"
    local ++fail_count
}

**# A3: constant probabilistic selection matches simple selection
local ++test_count
capture noisily {
    qba_selection, a(25) b(40) c(75) d(160) ///
        sela(.8) selb(.6) selc(.7) seld(.9)
    local simple_corr = r(corrected)
    local simple_obs = r(observed)
    local simple_bf = r(bias_factor)

    qba_selection, a(25) b(40) c(75) d(160) ///
        sela(.8) selb(.6) selc(.7) seld(.9) reps(100) ///
        dist_sela("constant .8") dist_selb("constant .6") ///
        dist_selc("constant .7") dist_seld("constant .9") seed(1234)
    _assert_close `=r(observed)' `simple_obs' 1e-12
    _assert_close `=r(corrected)' `simple_corr' 1e-12
    _assert_close `=r(mean)' `simple_corr' 1e-12
    _assert_close `=r(sd)' 0 1e-12
    _assert_close `simple_bf' `=(.8*.9)/(.6*.7)' 1e-12
    assert r(n_valid) == 100
}
if _rc == 0 {
    display as result "  PASS: A3 constant probabilistic selection matches simple"
    local ++pass_count
}
else {
    display as error "  FAIL: A3 constant probabilistic selection (error `=_rc')"
    local ++fail_count
}

**# A4: constant probabilistic confounding matches simple confounding
local ++test_count
capture noisily {
    qba_confound, estimate(2.25) p1(.45) p0(.15) rrcd(3)
    local simple_corr = r(corrected)
    local simple_bf = r(bias_factor)

    qba_confound, estimate(2.25) p1(.45) p0(.15) rrcd(3) reps(100) ///
        dist_p1("constant .45") dist_p0("constant .15") ///
        dist_rr("constant 3") seed(4321)
    _assert_close `=r(corrected)' `simple_corr' 1e-12
    _assert_close `=r(mean)' `simple_corr' 1e-12
    _assert_close `=r(sd)' 0 1e-12
    _assert_close `simple_bf' `=(.45*(3-1)+1)/(.15*(3-1)+1)' 1e-12
    assert r(n_valid) == 100
}
if _rc == 0 {
    display as result "  PASS: A4 constant probabilistic confounding matches simple"
    local ++pass_count
}
else {
    display as error "  FAIL: A4 constant probabilistic confounding (error `=_rc')"
    local ++fail_count
}

**# A5: from_model handles logistic, logit, poisson, and regress while preserving e()
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly logistic foreign mpg
    local b_before = _b[mpg]
    local se_before = _se[mpg]
    local expected = exp(`b_before')
    qba_confound, from_model p1(.3) p0(.1) rrcd(2)
    assert "`r(measure)'" == "OR"
    _assert_reldif `=r(observed)' `expected' 1e-10
    assert "`e(cmd)'" == "logistic"
    _assert_reldif `=_b[mpg]' `b_before' 1e-12
    _assert_reldif `=_se[mpg]' `se_before' 1e-12

    sysuse auto, clear
    quietly logit foreign mpg, nolog
    local b_before = _b[mpg]
    local se_before = _se[mpg]
    local expected = exp(`b_before')
    qba_confound, from_model p1(.3) p0(.1) rrcd(2) reps(100) ///
        dist_p1("constant .3") dist_p0("constant .1") ///
        dist_rr("constant 2") seed(20260506)
    assert "`r(measure)'" == "OR"
    _assert_reldif `=r(observed)' `expected' 1e-10
    assert "`e(cmd)'" == "logit"
    _assert_reldif `=_b[mpg]' `b_before' 1e-12
    _assert_reldif `=_se[mpg]' `se_before' 1e-12

    sysuse auto, clear
    quietly poisson rep78 mpg if rep78 < ., nolog
    local b_before = _b[mpg]
    local se_before = _se[mpg]
    local expected = exp(`b_before')
    qba_confound, from_model p1(.3) p0(.1) rrcd(2)
    assert "`r(measure)'" == "RR"
    _assert_reldif `=r(observed)' `expected' 1e-10
    assert "`e(cmd)'" == "poisson"
    _assert_reldif `=_b[mpg]' `b_before' 1e-12
    _assert_reldif `=_se[mpg]' `se_before' 1e-12

    sysuse auto, clear
    quietly regress price mpg
    local b_before = _b[mpg]
    local se_before = _se[mpg]
    local expected = `b_before' - (.3 - .1) * 100
    qba_confound, from_model p1(.3) p0(.1) confeffect(100)
    assert "`r(measure)'" == "coefficient"
    assert "`r(correction_type)'" == "subtractive"
    _assert_reldif `=r(observed)' `b_before' 1e-12
    _assert_reldif `=r(corrected)' `expected' 1e-10
    assert "`e(cmd)'" == "regress"
    _assert_reldif `=_b[mpg]' `b_before' 1e-12
    _assert_reldif `=_se[mpg]' `se_before' 1e-12
}
if _rc == 0 {
    display as result "  PASS: A5 from_model command families preserve e()"
    local ++pass_count
}
else {
    display as error "  FAIL: A5 from_model command families (error `=_rc')"
    local ++fail_count
}

**# A6: E-value edge cases match known formulas
local ++test_count
capture noisily {
    qba_confound, estimate(1) evalue
    _assert_close `=r(evalue)' 1 1e-12

    qba_confound, estimate(.5) evalue
    _assert_close `=r(evalue)' 3.4142135624 1e-8

    qba_confound, estimate(2) evalue ci_bound(.9)
    _assert_close `=r(evalue_ci)' 1 1e-12

    qba_confound, estimate(.5) evalue ci_bound(1.1)
    _assert_close `=r(evalue_ci)' 1 1e-12
}
if _rc == 0 {
    display as result "  PASS: A6 E-value edge cases"
    local ++pass_count
}
else {
    display as error "  FAIL: A6 E-value edge cases (error `=_rc')"
    local ++fail_count
}

**# A7: OR/RR formulas and subtractive linear correction are exact
local ++test_count
capture noisily {
    qba_selection, a(30) b(20) c(70) d(80) ///
        sela(.75) selb(.5) selc(.8) seld(.9)
    local obs_or = (30 * 80) / (20 * 70)
    local sbf = (.75 * .9) / (.5 * .8)
    _assert_close `=r(observed)' `obs_or' 1e-12
    _assert_close `=r(bias_factor)' `sbf' 1e-12
    _assert_close `=r(corrected)' `=`obs_or'/`sbf'' 1e-12
    _assert_close `=r(ratio)' `=1/`sbf'' 1e-12

    qba_selection, a(30) b(20) c(70) d(80) ///
        sela(.75) selb(.5) selc(.8) seld(.9) measure(RR)
    local ac = 30 / .75
    local bc = 20 / .5
    local cc = 70 / .8
    local dc = 80 / .9
    local rr_corr = (`ac' / (`ac' + `cc')) / (`bc' / (`bc' + `dc'))
    _assert_close `=r(corrected)' `rr_corr' 1e-12

    qba_confound, estimate(2.4) measure(OR) p1(.6) p0(.2) rrud(4)
    local expected_bf = (.6 * 4 + (1 - .6)) / (.2 * 4 + (1 - .2))
    local expected_corr = 2.4 / `expected_bf'
    _assert_close `=r(bias_factor)' `expected_bf' 1e-12
    _assert_close `=r(corrected)' `expected_corr' 1e-12
    assert "`r(measure)'" == "OR"

    qba_confound, estimate(2.4) measure(RR) p1(.6) p0(.2) rrud(4)
    _assert_close `=r(bias_factor)' `expected_bf' 1e-12
    _assert_close `=r(corrected)' `expected_corr' 1e-12
    assert "`r(measure)'" == "RR"

    sysuse auto, clear
    quietly regress price mpg
    local expected_linear = _b[mpg] - (.1 - .6) * 250
    qba_confound, from_model p1(.1) p0(.6) confeffect(250)
    _assert_close `=r(corrected)' `expected_linear' 1e-8
}
if _rc == 0 {
    display as result "  PASS: A7 formula consistency and linear subtraction"
    local ++pass_count
}
else {
    display as error "  FAIL: A7 formula consistency and linear subtraction (error `=_rc')"
    local ++fail_count
}

**# A8: saving(), replace, and no-replace failure behavior
local ++test_count
capture noisily {
    capture restore
    sysuse auto, clear
    datasignature
    local sig_before "`r(datasignature)'"
    tempfile selout confout

    qba_selection, a(20) b(40) c(60) d(120) ///
        sela(.8) selb(.6) selc(.7) seld(.9) reps(100) ///
        dist_sela("constant .8") dist_selb("constant .6") ///
        dist_selc("constant .7") dist_seld("constant .9") ///
        saving("`selout'", replace)
    datasignature
    assert "`r(datasignature)'" == "`sig_before'"
    preserve
    use "`selout'", clear
    assert _N == 100
    confirm variable corrected_or
    confirm variable sel_a
    confirm variable sel_d
    restore

    capture qba_selection, a(20) b(40) c(60) d(120) ///
        sela(.8) selb(.6) selc(.7) seld(.9) reps(100) ///
        saving("`selout'")
    local rc = _rc
    assert `rc' == 602
    assert r(corrected) < .

    qba_confound, estimate(2) p1(.4) p0(.2) rrcd(3) reps(100) ///
        dist_p1("constant .4") dist_p0("constant .2") ///
        dist_rr("constant 3") saving("`confout'", replace)
    datasignature
    assert "`r(datasignature)'" == "`sig_before'"
    preserve
    use "`confout'", clear
    assert _N == 100
    confirm variable corrected_rr
    confirm variable bias_factor
    confirm variable rr_confounder
    restore

    capture qba_confound, estimate(2) p1(.4) p0(.2) rrcd(3) reps(100) ///
        saving("`confout'")
    local rc = _rc
    assert `rc' == 602
    assert r(corrected) < .
}
if _rc == 0 {
    display as result "  PASS: A8 saving/replace/no-replace behavior"
    local ++pass_count
}
else {
    capture restore
    display as error "  FAIL: A8 saving/replace/no-replace behavior (error `=_rc')"
    local ++fail_count
}

**# A9: varabbrev restores on success and nested error paths
local ++test_count
capture noisily {
    foreach state in on off {
        set varabbrev `state'
        qba_selection, a(10) b(20) c(30) d(40) ///
            sela(.9) selb(.8) selc(.7) seld(.9)
        assert c(varabbrev) == "`state'"

        set varabbrev `state'
        capture qba_selection, a(10) b(20) c(30) d(40) ///
            sela(.9) selb(.8) selc(.7) seld(.9) reps(100) ///
            dist_sela("uniform .9 .8")
        assert _rc == 198
        assert c(varabbrev) == "`state'"

        set varabbrev `state'
        qba_confound, estimate(2) p1(.4) p0(.2) rrcd(2) evalue
        assert c(varabbrev) == "`state'"

        set varabbrev `state'
        capture qba_confound, estimate(2) evalue p1(2)
        assert _rc == 198
        assert c(varabbrev) == "`state'"
    }
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: A9 varabbrev restore on success/error"
    local ++pass_count
}
else {
    set varabbrev on
    display as error "  FAIL: A9 varabbrev restore (error `=_rc')"
    local ++fail_count
}

**# A10: probabilistic commands preserve caller data
local ++test_count
capture noisily {
    capture restore
    sysuse auto, clear
    local n_before = _N
    datasignature
    local sig_before "`r(datasignature)'"

    qba_selection, a(20) b(40) c(60) d(120) ///
        sela(.8) selb(.6) selc(.7) seld(.9) reps(100) ///
        dist_sela("constant .8") dist_selb("constant .6") ///
        dist_selc("constant .7") dist_seld("constant .9")
    assert _N == `n_before'
    datasignature
    assert "`r(datasignature)'" == "`sig_before'"

    qba_confound, estimate(2) p1(.4) p0(.2) rrcd(3) reps(100) ///
        dist_p1("constant .4") dist_p0("constant .2") ///
        dist_rr("constant 3")
    assert _N == `n_before'
    datasignature
    assert "`r(datasignature)'" == "`sig_before'"
}
if _rc == 0 {
    display as result "  PASS: A10 probabilistic data preservation"
    local ++pass_count
}
else {
    capture restore
    display as error "  FAIL: A10 probabilistic data preservation (error `=_rc')"
    local ++fail_count
}

sysdir set PLUS "`_orig_plus'"
sysdir set PERSONAL "`_orig_personal'"
capture shell rm -rf "`_qba_plus'" "`_qba_personal'"
capture ado uninstall qba
set varabbrev `_orig_varabbrev'

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_qba_adversarial_selection_confound tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_qba_adversarial_selection_confound tests=`test_count' pass=`pass_count' fail=`fail_count'"
