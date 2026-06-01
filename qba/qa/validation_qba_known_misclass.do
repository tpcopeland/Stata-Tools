* validation_qba_known_misclass.do -- hand-computable qba_misclass oracles
* Package: qba
* Usage: cd qba/qa && stata-mp -b do validation_qba_known_misclass.do

clear all
version 16.0

capture do "_qba_qa_common.do"
if _rc {
    do "qa/_qba_qa_common.do"
}
_qba_qa_bootstrap, isolated
local qa_dir `"`r(qa_dir)'"'
local pkg_dir `"`r(pkg_dir)'"'
local orig_plus `"`r(orig_plus)'"'
local orig_personal `"`r(orig_personal)'"'
local plusdir `"`r(plusdir)'"'
local personaldir `"`r(personaldir)'"'
local orig_varabbrev "`c(varabbrev)'"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# K1: Nondifferential exposure misclassification OR and RR
local ++test_count
capture noisily {
    local a 90
    local b 120
    local c 210
    local d 180
    local se .8
    local sp .9
    local den = `se' + `sp' - 1
    local M1 = `a' + `b'
    local M0 = `c' + `d'
    local ea = (`a' - (1 - `sp') * `M1') / `den'
    local eb = `M1' - `ea'
    local ec = (`c' - (1 - `sp') * `M0') / `den'
    local ed = `M0' - `ec'
    local e_or = (`ea' * `ed') / (`eb' * `ec')
    local e_rr = (`ea' / (`ea' + `ec')) / (`eb' / (`eb' + `ed'))

    qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp')
    _assert_close `=r(corrected_a)' `ea'
    _assert_close `=r(corrected_b)' `eb'
    _assert_close `=r(corrected_c)' `ec'
    _assert_close `=r(corrected_d)' `ed'
    _assert_close `=r(corrected)' `e_or'
    _assert_close `=r(corrected_a) + r(corrected_b)' `M1'
    _assert_close `=r(corrected_c) + r(corrected_d)' `M0'
    _assert_close `=r(ratio)' `=r(corrected) / r(observed)'
    assert "`r(method)'" == "simple"
    assert "`r(type)'" == "exposure"
    assert "`r(measure)'" == "OR"

    qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') ///
        measure(RR)
    _assert_close `=r(corrected)' `e_rr'
    _assert_close `=r(corrected_a)' `ea'
    _assert_close `=r(corrected_d)' `ed'
    assert "`r(measure)'" == "RR"
}
if _rc == 0 {
    display as result "  PASS: K1 nondifferential exposure OR/RR known answer"
    local ++pass_count
}
else {
    display as error "  FAIL: K1 nondifferential exposure known answer (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K1"
}

**# K2: Nondifferential outcome misclassification OR and RR
local ++test_count
capture noisily {
    local a 90
    local b 120
    local c 210
    local d 180
    local se .8
    local sp .9
    local den = `se' + `sp' - 1
    local N1 = `a' + `c'
    local N0 = `b' + `d'
    local ea = (`a' - (1 - `sp') * `N1') / `den'
    local ec = `N1' - `ea'
    local eb = (`b' - (1 - `sp') * `N0') / `den'
    local ed = `N0' - `eb'
    local e_or = (`ea' * `ed') / (`eb' * `ec')
    local e_rr = (`ea' / (`ea' + `ec')) / (`eb' / (`eb' + `ed'))

    qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') ///
        type(outcome)
    _assert_close `=r(corrected_a)' `ea'
    _assert_close `=r(corrected_b)' `eb'
    _assert_close `=r(corrected_c)' `ec'
    _assert_close `=r(corrected_d)' `ed'
    _assert_close `=r(corrected)' `e_or'
    _assert_close `=r(corrected_a) + r(corrected_c)' `N1'
    _assert_close `=r(corrected_b) + r(corrected_d)' `N0'
    assert "`r(type)'" == "outcome"

    qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`se') spca(`sp') ///
        type(outcome) measure(RR)
    _assert_close `=r(corrected)' `e_rr'
    _assert_close `=r(corrected_a)' `ea'
    _assert_close `=r(corrected_d)' `ed'
}
if _rc == 0 {
    display as result "  PASS: K2 nondifferential outcome OR/RR known answer"
    local ++pass_count
}
else {
    display as error "  FAIL: K2 nondifferential outcome known answer (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K2"
}

**# K3: Differential exposure misclassification hand solution
local ++test_count
capture noisily {
    local a 90
    local b 120
    local c 210
    local d 180
    local seA .8
    local spA .9
    local seB .7
    local spB .85
    local M1 = `a' + `b'
    local M0 = `c' + `d'
    local denA = `seA' + `spA' - 1
    local denB = `seB' + `spB' - 1
    local ea = (`a' - (1 - `spA') * `M1') / `denA'
    local eb = `M1' - `ea'
    local ec = (`c' - (1 - `spB') * `M0') / `denB'
    local ed = `M0' - `ec'
    local e_or = (`ea' * `ed') / (`eb' * `ec')
    local e_rr = (`ea' / (`ea' + `ec')) / (`eb' / (`eb' + `ed'))

    qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`seA') spca(`spA') ///
        secb(`seB') spcb(`spB')
    _assert_close `=r(corrected_a)' `ea'
    _assert_close `=r(corrected_b)' `eb'
    _assert_close `=r(corrected_c)' `ec'
    _assert_close `=r(corrected_d)' `ed'
    _assert_close `=r(corrected)' `e_or'
    assert r(seca) == `seA'
    assert r(spca) == `spA'
    assert r(secb) == `seB'
    assert r(spcb) == `spB'

    qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`seA') spca(`spA') ///
        secb(`seB') spcb(`spB') measure(RR)
    _assert_close `=r(corrected)' `e_rr'
}
if _rc == 0 {
    display as result "  PASS: K3 differential exposure OR/RR known answer"
    local ++pass_count
}
else {
    display as error "  FAIL: K3 differential exposure known answer (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K3"
}

**# K4: Differential outcome misclassification hand solution
local ++test_count
capture noisily {
    local a 90
    local b 120
    local c 210
    local d 180
    local seA .8
    local spA .9
    local seB .7
    local spB .85
    local N1 = `a' + `c'
    local N0 = `b' + `d'
    local denA = `seA' + `spA' - 1
    local denB = `seB' + `spB' - 1
    local ea = (`a' - (1 - `spA') * `N1') / `denA'
    local ec = `N1' - `ea'
    local eb = (`b' - (1 - `spB') * `N0') / `denB'
    local ed = `N0' - `eb'
    local e_or = (`ea' * `ed') / (`eb' * `ec')
    local e_rr = (`ea' / (`ea' + `ec')) / (`eb' / (`eb' + `ed'))

    qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`seA') spca(`spA') ///
        secb(`seB') spcb(`spB') type(outcome)
    _assert_close `=r(corrected_a)' `ea'
    _assert_close `=r(corrected_b)' `eb'
    _assert_close `=r(corrected_c)' `ec'
    _assert_close `=r(corrected_d)' `ed'
    _assert_close `=r(corrected)' `e_or'
    _assert_close `=r(corrected_a) + r(corrected_c)' `N1'
    _assert_close `=r(corrected_b) + r(corrected_d)' `N0'

    qba_misclass, a(`a') b(`b') c(`c') d(`d') seca(`seA') spca(`spA') ///
        secb(`seB') spcb(`spB') type(outcome) measure(RR)
    _assert_close `=r(corrected)' `e_rr'
}
if _rc == 0 {
    display as result "  PASS: K4 differential outcome OR/RR known answer"
    local ++pass_count
}
else {
    display as error "  FAIL: K4 differential outcome known answer (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K4"
}

**# K5: Identifiability boundary and just-identifiable finite cells
local ++test_count
capture noisily {
    capture qba_misclass, a(50) b(50) c(50) d(50) seca(.5) spca(.5)
    assert _rc == 198
    capture qba_misclass, a(50) b(50) c(50) d(50) seca(.49) spca(.51)
    assert _rc == 198

    qba_misclass, a(50.01) b(49.99) c(50.01) d(49.99) ///
        seca(.5001) spca(.5)
    _assert_close `=r(corrected_a)' 100 .000001
    _assert_close `=r(corrected_b)' 0 .000001
    _assert_close `=r(corrected_c)' 100 .000001
    _assert_close `=r(corrected_d)' 0 .000001
    assert r(corrected) < .

    capture qba_misclass, a(50) b(50) c(50) d(50) ///
        seca(.9) spca(.9) secb(.5) spcb(.5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: K5 identifiability boundary contracts"
    local ++pass_count
}
else {
    display as error "  FAIL: K5 identifiability boundary contracts (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K5"
}

**# K6: Differential no-op classification equals observed table
local ++test_count
capture noisily {
    qba_misclass, a(90) b(120) c(210) d(180) seca(1) spca(1) ///
        secb(1) spcb(1) type(outcome) measure(RR)
    _assert_close `=r(corrected_a)' 90
    _assert_close `=r(corrected_b)' 120
    _assert_close `=r(corrected_c)' 210
    _assert_close `=r(corrected_d)' 180
    _assert_close `=r(observed)' `=r(corrected)'
    _assert_close `=r(ratio)' 1
}
if _rc == 0 {
    display as result "  PASS: K6 differential perfect classification no-op"
    local ++pass_count
}
else {
    display as error "  FAIL: K6 differential perfect classification no-op (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K6"
}

**# K7: Constant probabilistic differential outcome equals simple mode
local ++test_count
capture noisily {
    qba_misclass, a(90) b(120) c(210) d(180) seca(.8) spca(.9) ///
        secb(.7) spcb(.85) type(outcome) measure(RR)
    local simple = r(corrected)

    qba_misclass, a(90) b(120) c(210) d(180) seca(.8) spca(.9) ///
        secb(.7) spcb(.85) type(outcome) measure(RR) reps(101) seed(20260508) ///
        dist_se("constant .8") dist_sp("constant .9") ///
        dist_se1("constant .7") dist_sp1("constant .85")
    assert r(n_valid) == 101
    _assert_close `=r(corrected)' `simple'
    _assert_close `=r(mean)' `simple'
    _assert_close `=r(ci_lower)' `simple'
    _assert_close `=r(ci_upper)' `simple'
    _assert_close `=r(sd)' 0
    assert "`r(method)'" == "probabilistic"
    assert "`r(type)'" == "outcome"
    assert "`r(measure)'" == "RR"
    assert "`r(dist_se)'" == "constant .8"
    assert "`r(dist_sp)'" == "constant .9"
}
if _rc == 0 {
    display as result "  PASS: K7 constant probabilistic differential outcome equals simple"
    local ++pass_count
}
else {
    display as error "  FAIL: K7 constant probabilistic equivalence (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K7"
}

**# K8: Simple-mode missing measure keeps corrected cells and omits ratio
local ++test_count
capture noisily {
    qba_misclass, a(2) b(95) c(98) d(5) seca(.9) spca(.95) ///
        type(outcome)
    assert r(corrected_a) < 0
    assert r(corrected_d) < 0
    assert r(corrected) == .
    _assert_close `=r(corrected_a) + r(corrected_c)' 100
    _assert_close `=r(corrected_b) + r(corrected_d)' 100
}
if _rc == 0 {
    display as result "  PASS: K8 infeasible corrected table r() semantics"
    local ++pass_count
}
else {
    display as error "  FAIL: K8 infeasible corrected table r() semantics (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' K8"
}

_qba_qa_restore_isolation, origplus("`orig_plus'") ///
    origpersonal("`orig_personal'") plusdir("`plusdir'") ///
    personaldir("`personaldir'") uninstall
set varabbrev `orig_varabbrev'

display as text ""
display as result "Known misclass Validation Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: validation_qba_known_misclass tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: validation_qba_known_misclass tests=`test_count' pass=`pass_count' fail=`fail_count'"
