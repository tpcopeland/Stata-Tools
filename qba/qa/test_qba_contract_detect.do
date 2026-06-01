* test_qba_contract_detect.do -- active estimator contract tests for qba_confound
* Package: qba
* Usage: cd qba/qa && stata-mp -b do test_qba_contract_detect.do

clear all
version 16.0

capture do "_qba_qa_common.do"
if _rc {
    do "qa/_qba_qa_common.do"
}

_qba_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _qba_fake_contract
program define _qba_fake_contract, eclass
    version 16.0
    syntax , CMD(string) TAU(real) SE(real) CILO(real) CIHI(real) ///
        [MEAsure(string)]

    clear
    set obs 20
    tempvar esample
    gen byte `esample' = 1

    tempname b V
    matrix `b' = (`tau')
    matrix colnames `b' = ATE
    matrix `V' = (`se'^2)
    matrix colnames `V' = ATE
    matrix rownames `V' = ATE

    ereturn post `b' `V', obs(20) esample(`esample')
    ereturn scalar tau = `tau'
    ereturn scalar se = `se'
    ereturn scalar ci_lo = `cilo'
    ereturn scalar ci_hi = `cihi'
    ereturn local cmd "`cmd'"
    ereturn local outcome "y"
    ereturn local treatment "a"
    ereturn local estimand "ATE"
    if "`measure'" != "" {
        ereturn local measure "`measure'"
    }
end

**# C1: tmle additive contract is consumed and E-value is skipped
local ++test_count
capture noisily {
    _qba_fake_contract, cmd(tmle) tau(-0.12) se(0.1) cilo(-0.316) cihi(0.076)
    qba_confound, evalue

    _qba_qa_assert_close `=r(observed)' -0.12 1e-12
    _qba_qa_assert_close `=r(ci_lower)' -0.316 1e-12
    _qba_qa_assert_close `=r(ci_upper)' 0.076 1e-12
    assert "`r(measure)'" == "coefficient"
    assert "`r(correction_type)'" == "subtractive"
    assert "`r(source)'" == "tmle"
    assert "`r(cmd)'" == "tmle"
    assert "`r(outcome)'" == "y"
    assert "`r(treatment)'" == "a"
    assert "`r(estimand)'" == "ATE"
    capture confirm scalar r(evalue)
    assert _rc != 0
    assert "`e(cmd)'" == "tmle"
}
if _rc == 0 {
    display as result "  PASS: C1 tmle additive contract consumed"
    local ++pass_count
}
else {
    display as error "  FAIL: C1 tmle additive contract (error `=_rc')"
    local ++fail_count
}

**# C2: ltmle additive contract supports subtractive correction
local ++test_count
capture noisily {
    _qba_fake_contract, cmd(ltmle) tau(-0.12) se(0.1) cilo(-0.316) cihi(0.076)
    qba_confound, p1(.4) p0(.2) confeffect(1.5)

    _qba_qa_assert_close `=r(observed)' -0.12 1e-12
    _qba_qa_assert_close `=r(corrected)' -0.42 1e-12
    assert "`r(measure)'" == "coefficient"
    assert "`r(correction_type)'" == "subtractive"
    assert "`r(source)'" == "ltmle"
    assert "`e(cmd)'" == "ltmle"
}
if _rc == 0 {
    display as result "  PASS: C2 ltmle additive correction consumed"
    local ++pass_count
}
else {
    display as error "  FAIL: C2 ltmle additive correction (error `=_rc')"
    local ++fail_count
}

**# C3: explicit ratio-measure contract permits E-value
local ++test_count
capture noisily {
    _qba_fake_contract, cmd(tmle) tau(2) se(0.2) cilo(1.2) cihi(2.8) measure(RR)
    qba_confound, evalue

    _qba_qa_assert_close `=r(observed)' 2 1e-12
    _qba_qa_assert_close `=r(evalue)' `=2 + sqrt(2)' 1e-12
    _qba_qa_assert_close `=r(evalue_ci)' `=1.2 + sqrt(1.2 * .2)' 1e-12
    assert "`r(measure)'" == "RR"
    assert "`r(source)'" == "tmle"
}
if _rc == 0 {
    display as result "  PASS: C3 ratio-measure contract permits E-value"
    local ++pass_count
}
else {
    display as error "  FAIL: C3 ratio-measure contract E-value (error `=_rc')"
    local ++fail_count
}

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_qba_contract_detect tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_qba_contract_detect tests=`test_count' pass=`pass_count' fail=`fail_count'"
