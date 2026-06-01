* test_qba_adversarial_misclass.do -- adversarial qba_misclass/helper QA
* Package: qba
* Usage: cd qba/qa && stata-mp -b do test_qba_adversarial_misclass.do

clear all
version 16.0

* Bootstrap from qba/qa.
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

**# Install surface and helper auto-loading
local ++test_count
capture noisily {
    which qba_misclass
    findfile _qba_distributions.ado
    capture program drop _qba_parse_dist
    capture program drop _qba_draw_one
    capture program drop _qba_draw_scalar

    qba_misclass, a(80) b(120) c(300) d(500) seca(.85) spca(.95) ///
        reps(100) seed(101)
    assert r(n_valid) == 100
    assert "`r(method)'" == "probabilistic"
}
if _rc == 0 {
    display as result "  PASS: T1 installed qba_misclass auto-loads distribution helper"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 helper auto-load after net install (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

capture findfile _qba_distributions.ado
if _rc {
    display as error "_qba_distributions.ado not found after install"
    exit 111
}
run "`r(fn)'"

**# Impossible corrected cells
local ++test_count
capture noisily {
    qba_misclass, a(2) b(95) c(98) d(5) seca(.90) spca(.95) ///
        type(outcome) measure(RR)
    assert r(corrected_a) < 0
    assert r(corrected_d) < 0
    assert r(corrected) == .
    _assert_close `=r(corrected_a) + r(corrected_c)' 100 0.000001
    _assert_close `=r(corrected_b) + r(corrected_d)' 100 0.000001
}
if _rc == 0 {
    display as result "  PASS: T2 impossible outcome correction returns missing RR and preserves columns"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 impossible corrected cells (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

**# Se + Sp identifiability boundaries
local ++test_count
capture noisily {
    capture qba_misclass, a(50) b(50) c(50) d(50) seca(.5) spca(.5)
    assert _rc == 198

    capture qba_misclass, a(50) b(50) c(50) d(50) seca(.499999999) spca(.5)
    assert _rc == 198

    qba_misclass, a(50.000001) b(49.999999) c(50.000001) d(49.999999) ///
        seca(.50000001) spca(.5)
    assert "`r(method)'" == "simple"
    assert r(corrected_a) < .

    capture qba_misclass, a(50) b(50) c(50) d(50) ///
        seca(.9) spca(.9) secb(.5) spcb(.5)
    assert _rc == 198

    qba_misclass, a(50.000001) b(49.999999) c(50.000001) d(49.999999) ///
        seca(.9) spca(.9) secb(.50000001) spcb(.5)
    assert "`r(method)'" == "simple"
}
if _rc == 0 {
    display as result "  PASS: T3 Se+Sp boundary rejection and near-boundary acceptance"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 Se+Sp boundaries (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

**# Differential parameter defaults and stratum totals
local ++test_count
capture noisily {
    qba_misclass, a(90) b(70) c(210) d(630) ///
        seca(.88) spca(.96) secb(.77) type(exposure)
    assert r(secb) == .77
    assert r(spcb) == .96
    _assert_close `=r(corrected_a) + r(corrected_b)' 160 0.000001
    _assert_close `=r(corrected_c) + r(corrected_d)' 840 0.000001

    qba_misclass, a(90) b(70) c(210) d(630) ///
        seca(.88) spca(.96) spcb(.93) type(outcome)
    assert r(secb) == .88
    assert r(spcb) == .93
    _assert_close `=r(corrected_a) + r(corrected_c)' 300 0.000001
    _assert_close `=r(corrected_b) + r(corrected_d)' 700 0.000001
}
if _rc == 0 {
    display as result "  PASS: T4 differential defaults preserve exposure/outcome strata"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 differential defaults (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

**# OR/RR consistency for the same corrected table
local ++test_count
capture noisily {
    qba_misclass, a(80) b(120) c(300) d(500) seca(.8) spca(.9) ///
        type(outcome)
    local or_obs = r(observed)
    local or_corr = r(corrected)
    local a_corr = r(corrected_a)
    local b_corr = r(corrected_b)
    local c_corr = r(corrected_c)
    local d_corr = r(corrected_d)

    qba_misclass, a(80) b(120) c(300) d(500) seca(.8) spca(.9) ///
        type(outcome) measure(RR)
    _assert_close `=r(corrected_a)' `a_corr' 0.000001
    _assert_close `=r(corrected_b)' `b_corr' 0.000001
    _assert_close `=r(corrected_c)' `c_corr' 0.000001
    _assert_close `=r(corrected_d)' `d_corr' 0.000001
    assert r(observed) != `or_obs'
    assert r(corrected) != `or_corr'
    assert r(observed) > 0
    assert r(corrected) > 0
}
if _rc == 0 {
    display as result "  PASS: T5 OR/RR share corrected cells but return scale-specific measures"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 OR/RR consistency (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}

**# Probabilistic reproducibility with differential outcome parameters
local ++test_count
capture noisily {
    qba_misclass, a(90) b(70) c(210) d(630) seca(.88) spca(.97) ///
        secb(.76) spcb(.93) type(outcome) measure(RR) reps(300) seed(20260506) ///
        dist_se("uniform .84 .92") dist_sp("triangular .94 .97 .995") ///
        dist_se1("uniform .70 .82") dist_sp1("uniform .90 .96")
    local med1 = r(corrected)
    local mean1 = r(mean)
    local lo1 = r(ci_lower)
    local hi1 = r(ci_upper)
    local valid1 = r(n_valid)

    qba_misclass, a(90) b(70) c(210) d(630) seca(.88) spca(.97) ///
        secb(.76) spcb(.93) type(outcome) measure(RR) reps(300) seed(20260506) ///
        dist_se("uniform .84 .92") dist_sp("triangular .94 .97 .995") ///
        dist_se1("uniform .70 .82") dist_sp1("uniform .90 .96")
    _assert_close `=r(corrected)' `med1' 0.0000000001
    _assert_close `=r(mean)' `mean1' 0.0000000001
    _assert_close `=r(ci_lower)' `lo1' 0.0000000001
    _assert_close `=r(ci_upper)' `hi1' 0.0000000001
    assert r(n_valid) == `valid1'
}
if _rc == 0 {
    display as result "  PASS: T6 differential probabilistic analysis is seed-reproducible"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 probabilistic reproducibility (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}

**# Invalid distributions fail cleanly
local ++test_count
capture noisily {
    capture _qba_parse_dist, dist("")
    assert _rc == 198
    capture _qba_parse_dist, dist("weibull 1 2")
    assert _rc == 198
    capture _qba_parse_dist, dist("uniform .8 .8")
    assert _rc == 198
    capture _qba_parse_dist, dist("beta -1 2")
    assert _rc == 198
    capture _qba_parse_dist, dist("logit-normal 0 0")
    assert _rc == 198
    capture _qba_parse_dist, dist("constant .8 .9")
    assert _rc == 198
    capture _qba_parse_dist, dist("trapezoidal .7 bad .9 1")
    assert _rc == 198

    capture qba_misclass, a(80) b(120) c(300) d(500) seca(.85) spca(.95) ///
        reps(100) dist_se("beta -1 2")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T7 invalid distribution specifications return rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 invalid distributions (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T7"
}

**# n_valid and invalid parameter draw behavior
local ++test_count
capture noisily {
    tempfile invalid_draws
    qba_misclass, a(80) b(120) c(300) d(500) seca(.85) spca(.95) ///
        reps(500) seed(24680) dist_se("uniform -.2 .8") ///
        dist_sp("constant .7") saving("`invalid_draws'", replace)
    local n_valid = r(n_valid)
    assert `n_valid' > 0
    assert `n_valid' < 500

    preserve
    use "`invalid_draws'", clear
    assert _N == 500
    count if se <= 0 | se > 1 | sp <= 0 | sp > 1 | se + sp <= 1
    local n_draw_invalid = r(N)
    assert `n_draw_invalid' > 0
    count if (se <= 0 | se > 1 | sp <= 0 | sp > 1 | se + sp <= 1) & corrected_or < .
    assert r(N) == 0
    count if corrected_or < .
    assert r(N) == `n_valid'
    restore
}
if _rc == 0 {
    display as result "  PASS: T8 n_valid matches saved nonmissing results and invalid draws are excluded"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 n_valid/invalid draw behavior (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T8"
}

**# All-invalid Monte Carlo draws fail without changing caller data
local ++test_count
capture noisily {
    clear
    input int id double value
    1 10
    2 20
    3 30
    end
    gen int seq = _n
    tempfile before_invalid
    save "`before_invalid'", replace

    set varabbrev on
    capture qba_misclass, a(80) b(120) c(300) d(500) seca(.85) spca(.95) ///
        reps(100) dist_se("constant .2") dist_sp("constant .7")
    local rc = _rc
    assert `rc' == 198
    assert c(varabbrev) == "on"
    cf _all using "`before_invalid'"
}
if _rc == 0 {
    display as result "  PASS: T9 all-invalid draws return rc 198 and preserve caller state"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 all-invalid draw failure path (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T9"
}

**# saving(), replace, and save-failure return behavior
local ++test_count
capture noisily {
    tempfile save_stub
    local savepath "`save_stub' qba adversarial save.dta"
    capture erase "`savepath'"

    qba_misclass, a(80) b(120) c(300) d(500) seca(.85) spca(.95) ///
        reps(100) seed(777) saving("`savepath'", replace)
    local corrected = r(corrected)
    confirm file "`savepath'"

    preserve
    use "`savepath'", clear
    assert _N == 100
    confirm variable corrected_or
    restore

    clear
    set obs 1
    gen byte marker = 42
    save "`savepath'", replace

    capture qba_misclass, a(80) b(120) c(300) d(500) seca(.85) spca(.95) ///
        reps(100) seed(777) saving("`savepath'")
    local rc = _rc
    local failed_corrected = r(corrected)
    assert `rc' == 602
    assert `failed_corrected' == `corrected'

    preserve
    use "`savepath'", clear
    confirm variable marker
    restore

    qba_misclass, a(80) b(120) c(300) d(500) seca(.85) spca(.95) ///
        reps(100) seed(777) saving("`savepath'", replace)
    preserve
    use "`savepath'", clear
    capture confirm variable marker
    assert _rc != 0
    confirm variable corrected_or
    restore
    erase "`savepath'"
}
if _rc == 0 {
    display as result "  PASS: T10 saving() honors replace and posts returns on save failure"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 saving/replace behavior (error `=_rc')"
    capture erase "`savepath'"
    local ++fail_count
    local failed_tests "`failed_tests' T10"
}

**# qba_misclass varabbrev and data preservation on success and parser error
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

    set varabbrev off
    qba_misclass, a(80) b(120) c(300) d(500) seca(.85) spca(.95) ///
        reps(100) seed(909)
    assert c(varabbrev) == "off"
    cf _all using "`before_state'"

    set varabbrev on
    capture qba_misclass, a(80) b(120) c(300) d(500) seca(.85) spca(.95) ///
        reps(100) dist_se("uniform bad params")
    local rc = _rc
    assert `rc' == 198
    assert c(varabbrev) == "on"
    cf _all using "`before_state'"
}
if _rc == 0 {
    display as result "  PASS: T11 qba_misclass restores varabbrev and data on success/error"
    local ++pass_count
}
else {
    display as error "  FAIL: T11 qba_misclass state preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T11"
}

**# Distribution helper scalar draw preserves data on error
local ++test_count
capture noisily {
    clear
    input int id double value
    1 100
    2 200
    end
    tempfile before_scalar
    save "`before_scalar'", replace

    set varabbrev off
    capture _qba_draw_scalar, dist("uniform bad params")
    local rc = _rc
    assert `rc' == 198
    assert c(varabbrev) == "off"
    cf _all using "`before_scalar'"
}
if _rc == 0 {
    display as result "  PASS: T12 _qba_draw_scalar restores data and varabbrev on error"
    local ++pass_count
}
else {
    display as error "  FAIL: T12 _qba_draw_scalar state preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T12"
}

_qba_qa_restore_isolation, origplus("`orig_plus'") ///
    origpersonal("`orig_personal'") plusdir("`plusdir'") ///
    personaldir("`personaldir'") uninstall
set varabbrev `orig_varabbrev'

display as text ""
display as result "Adversarial misclass Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_qba_adversarial_misclass tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_qba_adversarial_misclass tests=`test_count' pass=`pass_count' fail=`fail_count'"
