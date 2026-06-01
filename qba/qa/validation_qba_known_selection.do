* validation_qba_known_selection.do -- focused known-answer validation for qba_selection
* Package: qba (Quantitative Bias Analysis)
* Usage: cd qba/qa && stata-mp -b do validation_qba_known_selection.do

clear all
version 16.0

capture log close _all

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
    if "`tolerance'" == "" local tolerance = 1e-8
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
    if "`tolerance'" == "" local tolerance = 1e-10
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

**# K1: OR hand-computable corrected cells, SBF, and ratio semantics
local ++test_count
capture noisily {
    * Observed table: a=30, b=10, c=20, d=40
    * Selection: Sa=.5, Sb=.25, Sc=.8, Sd=1
    * Corrected cells: 60, 40, 25, 40
    * Observed OR = 6; corrected OR = 2.4
    * SBF = (.5*1)/(.25*.8) = 2.5; ratio = 2.4/6 = .4 = 1/SBF
    qba_selection, a(30) b(10) c(20) d(40) ///
        sela(.5) selb(.25) selc(.8) seld(1)
    _assert_close `=r(a)' 30
    _assert_close `=r(b)' 10
    _assert_close `=r(c)' 20
    _assert_close `=r(d)' 40
    _assert_close `=r(corrected_a)' 60
    _assert_close `=r(corrected_b)' 40
    _assert_close `=r(corrected_c)' 25
    _assert_close `=r(corrected_d)' 40
    _assert_close `=r(observed)' 6
    _assert_close `=r(corrected)' 2.4
    _assert_close `=r(bias_factor)' 2.5
    _assert_close `=r(ratio)' .4
    _assert_close `=r(ratio)' `=1/r(bias_factor)'
    _assert_close `=r(observed)' `=r(corrected) * r(bias_factor)'
    assert "`r(measure)'" == "OR"
    assert "`r(method)'" == "simple"
}
if _rc == 0 {
    display as result "  PASS: K1 OR cells, SBF, and ratio known-answer"
    local ++pass_count
}
else {
    display as error "  FAIL: K1 OR known-answer (error `=_rc')"
    local ++fail_count
}

**# K2: RR hand-computable corrected cells and ratio semantics
local ++test_count
capture noisily {
    * Same table/selection as K1.
    * Observed RR = (30/50)/(10/50) = 3
    * Corrected RR = (60/85)/(40/80) = 24/17
    * RR ratio = (24/17)/3 = 8/17; unlike OR, this is not 1/SBF.
    qba_selection, a(30) b(10) c(20) d(40) ///
        sela(.5) selb(.25) selc(.8) seld(1) measure(RR)
    _assert_close `=r(corrected_a)' 60
    _assert_close `=r(corrected_b)' 40
    _assert_close `=r(corrected_c)' 25
    _assert_close `=r(corrected_d)' 40
    _assert_close `=r(observed)' 3
    _assert_close `=r(corrected)' `=24/17'
    _assert_close `=r(bias_factor)' 2.5
    _assert_close `=r(ratio)' `=8/17'
    assert reldif(r(ratio), 1 / r(bias_factor)) > .01
    assert "`r(measure)'" == "RR"
}
if _rc == 0 {
    display as result "  PASS: K2 RR cells and ratio known-answer"
    local ++pass_count
}
else {
    display as error "  FAIL: K2 RR known-answer (error `=_rc')"
    local ++fail_count
}

**# K3: equal nonunit selection probabilities preserve OR and RR
local ++test_count
capture noisily {
    qba_selection, a(12) b(18) c(24) d(36) ///
        sela(.2) selb(.2) selc(.2) seld(.2)
    _assert_close `=r(corrected_a)' 60
    _assert_close `=r(corrected_b)' 90
    _assert_close `=r(corrected_c)' 120
    _assert_close `=r(corrected_d)' 180
    _assert_close `=r(bias_factor)' 1
    _assert_close `=r(corrected)' `=r(observed)'
    _assert_close `=r(ratio)' 1

    qba_selection, a(12) b(18) c(24) d(36) ///
        sela(.2) selb(.2) selc(.2) seld(.2) measure(RR)
    _assert_close `=r(bias_factor)' 1
    _assert_close `=r(corrected)' `=r(observed)'
    _assert_close `=r(ratio)' 1
}
if _rc == 0 {
    display as result "  PASS: K3 equal selection preserves OR and RR"
    local ++pass_count
}
else {
    display as error "  FAIL: K3 equal selection invariant (error `=_rc')"
    local ++fail_count
}

**# K4: extreme valid probabilities produce finite algebraic results
local ++test_count
capture noisily {
    qba_selection, a(1) b(2) c(3) d(4) ///
        sela(1e-8) selb(.25) selc(1) seld(1e-6)
    local expected_bf = (1e-8 * 1e-6) / (.25 * 1)
    local expected_obs = (1 * 4) / (2 * 3)
    local expected_corr = `expected_obs' / `expected_bf'
    _assert_reldif `=r(corrected_a)' 1e8 1e-12
    _assert_reldif `=r(corrected_b)' 8 1e-12
    _assert_reldif `=r(corrected_c)' 3 1e-12
    _assert_reldif `=r(corrected_d)' 4e6 1e-12
    _assert_reldif `=r(bias_factor)' `expected_bf' 1e-12
    _assert_reldif `=r(observed)' `expected_obs' 1e-12
    _assert_reldif `=r(corrected)' `expected_corr' 1e-12
    assert r(corrected) < .
}
if _rc == 0 {
    display as result "  PASS: K4 extreme valid probabilities"
    local ++pass_count
}
else {
    display as error "  FAIL: K4 extreme probabilities (error `=_rc')"
    local ++fail_count
}

**# K5: zero-cell semantics return defined zeros or missing values without stale ratio
local ++test_count
capture noisily {
    qba_selection, a(0) b(10) c(20) d(30) ///
        sela(.5) selb(.5) selc(.5) seld(.5)
    _assert_close `=r(observed)' 0
    _assert_close `=r(corrected)' 0
    capture local ratio = r(ratio)
    assert missing(`ratio')

    qba_selection, a(10) b(0) c(20) d(30) ///
        sela(.5) selb(.5) selc(.5) seld(.5)
    assert missing(r(observed))
    assert missing(r(corrected))
    capture local ratio = r(ratio)
    assert missing(`ratio')

    qba_selection, a(10) b(0) c(20) d(30) ///
        sela(.5) selb(.5) selc(.5) seld(.5) measure(RR)
    assert missing(r(observed))
    assert missing(r(corrected))
    capture local ratio = r(ratio)
    assert missing(`ratio')
}
if _rc == 0 {
    display as result "  PASS: K5 zero-cell semantics"
    local ++pass_count
}
else {
    display as error "  FAIL: K5 zero-cell semantics (error `=_rc')"
    local ++fail_count
}

sysdir set PLUS "`_orig_plus'"
sysdir set PERSONAL "`_orig_personal'"
capture shell rm -rf "`_qba_plus'" "`_qba_personal'"
capture ado uninstall qba

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_qba_known_selection tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_qba_known_selection tests=`test_count' pass=`pass_count' fail=`fail_count'"
