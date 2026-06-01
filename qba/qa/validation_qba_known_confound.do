* validation_qba_known_confound.do -- known-answer validation for qba_confound
* Package: qba
* Usage: cd qba/qa && stata-mp -b do validation_qba_known_confound.do

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
    if "`tolerance'" == "" local tolerance = 1e-10
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

**# K1: Schneeweiss rrcd bias factor
local ++test_count
capture noisily {
    * estimate=3, p1=.75, p0=.25, rrcd=5
    * BF = (.75*(5-1)+1)/(.25*(5-1)+1) = 4/2 = 2
    * corrected = 3/2 = 1.5
    qba_confound, estimate(3) measure(RR) p1(.75) p0(.25) rrcd(5)
    _assert_close `=r(observed)' 3 1e-12
    _assert_close `=r(bias_factor)' 2 1e-12
    _assert_close `=r(corrected)' 1.5 1e-12
    _assert_close `=r(ratio)' .5 1e-12
    _assert_close `=r(rrcd)' 5 1e-12
    assert "`r(measure)'" == "RR"
}
if _rc == 0 {
    display as result "  PASS: K1 rrcd known-answer bias factor"
    local ++pass_count
}
else {
    display as error "  FAIL: K1 rrcd known-answer bias factor (error `=_rc')"
    local ++fail_count
}

**# K2: Greenland rrud parameterization matches its closed form
local ++test_count
capture noisily {
    * estimate=3, p1=.75, p0=.25, rrud=5
    * BF = (.75*5 + .25)/(.25*5 + .75) = 4/2 = 2
    qba_confound, estimate(3) measure(OR) p1(.75) p0(.25) rrud(5)
    _assert_close `=r(bias_factor)' 2 1e-12
    _assert_close `=r(corrected)' 1.5 1e-12
    _assert_close `=r(rrud)' 5 1e-12
    assert "`r(measure)'" == "OR"

    qba_confound, estimate(3) measure(OR) p1(.75) p0(.25) rrcd(5)
    local bf_rrcd = r(bias_factor)
    qba_confound, estimate(3) measure(OR) p1(.75) p0(.25) rrud(5)
    _assert_close `=r(bias_factor)' `bf_rrcd' 1e-12
}
if _rc == 0 {
    display as result "  PASS: K2 rrud known-answer and rrcd equivalence"
    local ++pass_count
}
else {
    display as error "  FAIL: K2 rrud known-answer (error `=_rc')"
    local ++fail_count
}

**# K3: Protective confounder-disease association
local ++test_count
capture noisily {
    * estimate=2, p1=.6, p0=.2, rrcd=.5
    * BF = (.6*(-.5)+1)/(.2*(-.5)+1) = .7/.9 = 7/9
    * corrected = 2/(7/9) = 18/7
    qba_confound, estimate(2) p1(.6) p0(.2) rrcd(.5)
    _assert_close `=r(bias_factor)' `=7/9' 1e-12
    _assert_close `=r(corrected)' `=18/7' 1e-12
}
if _rc == 0 {
    display as result "  PASS: K3 protective confounder known-answer"
    local ++pass_count
}
else {
    display as error "  FAIL: K3 protective confounder (error `=_rc')"
    local ++fail_count
}

**# K4: E-value point and CI formulas
local ++test_count
capture noisily {
    * Point: RR=4, E = 4 + sqrt(4*(4-1)).
    * CI: bound=1.25, E = 1.25 + sqrt(1.25*(1.25-1)).
    qba_confound, estimate(4) evalue ci_bound(1.25)
    _assert_close `=r(evalue)' `=4 + sqrt(12)' 1e-12
    _assert_close `=r(evalue_ci)' `=1.25 + sqrt(1.25*.25)' 1e-12

    * Protective point estimate uses the reciprocal; CI crossing the null is 1.
    qba_confound, estimate(.25) evalue ci_bound(1.1)
    _assert_close `=r(evalue)' `=4 + sqrt(12)' 1e-12
    _assert_close `=r(evalue_ci)' 1 1e-12
}
if _rc == 0 {
    display as result "  PASS: K4 E-value known formulas"
    local ++pass_count
}
else {
    display as error "  FAIL: K4 E-value known formulas (error `=_rc')"
    local ++fail_count
}

**# K5: from_model log-scale command handling
local ++test_count
capture noisily {
    local z = invnormal(.975)
    local b = ln(3)
    local se = .2
    local bf = 2

    foreach cmd in logistic logit {
        _post_onecoef, cmd(`cmd') b(`b') se(`se') coef(x)
        qba_confound, from_model p1(.75) p0(.25) rrcd(5)
        assert "`r(measure)'" == "OR"
        _assert_close `=r(observed)' 3 1e-12
        _assert_close `=r(corrected)' 1.5 1e-12
        _assert_close `=r(ci_lower)' `=exp(`b' - `z' * `se')' 1e-12
        _assert_close `=r(ci_upper)' `=exp(`b' + `z' * `se')' 1e-12
    }

    _post_onecoef, cmd(poisson) b(`b') se(`se') coef(x)
    qba_confound, from_model p1(.75) p0(.25) rrcd(5)
    assert "`r(measure)'" == "RR"
    _assert_close `=r(observed)' 3 1e-12
    _assert_close `=r(corrected)' 1.5 1e-12

    _post_onecoef, cmd(cloglog) b(`b') se(`se') coef(x)
    capture qba_confound, from_model p1(.75) p0(.25) rrcd(5)
    assert _rc == 198

    _post_onecoef, cmd(cloglog) b(`b') se(`se') coef(x)
    qba_confound, from_model measure(RR) p1(.75) p0(.25) rrcd(5)
    assert "`r(measure)'" == "RR"
    _assert_close `=r(observed)' 3 1e-12
    _assert_close `=r(corrected)' 1.5 1e-12
}
if _rc == 0 {
    display as result "  PASS: K5 from_model log-scale family known answers"
    local ++pass_count
}
else {
    display as error "  FAIL: K5 from_model log-scale family (error `=_rc')"
    local ++fail_count
}

**# K6: from_model linear subtractive correction
local ++test_count
capture noisily {
    local z = invnormal(.975)
    _post_onecoef, cmd(regress) b(4) se(.5) coef(x)
    qba_confound, from_model p1(.75) p0(.25) confeffect(6)
    * corrected = 4 - (.75 - .25) * 6 = 1
    _assert_close `=r(observed)' 4 1e-12
    _assert_close `=r(corrected)' 1 1e-12
    _assert_close `=r(confeffect)' 6 1e-12
    _assert_close `=r(ci_lower)' `=4 - `z' * .5' 1e-12
    _assert_close `=r(ci_upper)' `=4 + `z' * .5' 1e-12
    assert "`r(measure)'" == "coefficient"
    assert "`r(correction_type)'" == "subtractive"
}
if _rc == 0 {
    display as result "  PASS: K6 from_model linear subtractive known answer"
    local ++pass_count
}
else {
    display as error "  FAIL: K6 from_model linear subtractive (error `=_rc')"
    local ++fail_count
}

sysdir set PLUS "`_orig_plus'"
sysdir set PERSONAL "`_orig_personal'"
capture shell rm -rf "`_qba_plus'" "`_qba_personal'"
capture ado uninstall qba

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_qba_known_confound tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_qba_known_confound tests=`test_count' pass=`pass_count' fail=`fail_count'"
