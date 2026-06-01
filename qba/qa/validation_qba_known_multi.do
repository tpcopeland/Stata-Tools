* validation_qba_known_multi.do -- hand-computable qba_multi validations
* Package: qba (Quantitative Bias Analysis)
* Usage: cd qba/qa && stata-mp -b do validation_qba_known_multi.do

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
tempfile plus_stub personal_stub
local plusdir "`plus_stub'_dir"
local personaldir "`personal_stub'_dir"
mkdir "`plusdir'"
mkdir "`personaldir'"
sysdir set PLUS "`plusdir'"
sysdir set PERSONAL "`personaldir'"

capture ado uninstall qba
quietly net install qba, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _assert_close
program define _assert_close
    args actual expected tolerance
    if "`tolerance'" == "" local tolerance = 1e-8
    local diff = abs(`actual' - `expected')
    if `diff' > `tolerance' {
        display as error "Expected: `expected', got: `actual' (diff: `diff')"
        exit 9
    }
end

capture program drop _assert_saved_constant
program define _assert_saved_constant
    syntax using/ , A(real) B(real) C(real) D(real) RESULT(real) MEasure(string)
    preserve
    use "`using'", clear
    assert _N > 0
    confirm variable a_corr
    confirm variable b_corr
    confirm variable c_corr
    confirm variable d_corr
    confirm variable corrected_`=strlower("`measure'")'
    summarize a_corr, meanonly
    _assert_close `r(min)' `a' 1e-8
    _assert_close `r(max)' `a' 1e-8
    summarize b_corr, meanonly
    _assert_close `r(min)' `b' 1e-8
    _assert_close `r(max)' `b' 1e-8
    summarize c_corr, meanonly
    _assert_close `r(min)' `c' 1e-8
    _assert_close `r(max)' `c' 1e-8
    summarize d_corr, meanonly
    _assert_close `r(min)' `d' 1e-8
    _assert_close `r(max)' `d' 1e-8
    summarize corrected_`=strlower("`measure'")', meanonly
    _assert_close `r(min)' `result' 1e-8
    _assert_close `r(max)' `result' 1e-8
    restore
end

**# V1: Default constant chain equals manual misclass -> selection -> confounding
local ++test_count
capture noisily {
    tempfile default_save

    * Observed table: a=80 b=120 c=200 d=600.
    * Misclassification first, exposure type, Se=.8 Sp=.9:
    * a1=600/7, b1=800/7, c1=1200/7, d1=4400/7.
    * Selection then divides by .8, .5, .6, .9:
    * a2=750/7, b2=1600/7, c2=2000/7, d2=44000/63.
    * OR before confounding = 55/48.
    * Schneeweiss BF with p1=.4, p0=.2, rrcd=2 is 7/6.
    * Final OR = (55/48)/(7/6) = 55/56.
    local exp_a = 750 / 7
    local exp_b = 1600 / 7
    local exp_c = 2000 / 7
    local exp_d = 44000 / 63
    local exp_or = 55 / 56

    qba_multi, a(80) b(120) c(200) d(600) reps(150) ///
        seca(.8) spca(.9) ///
        sela(.8) selb(.5) selc(.6) seld(.9) ///
        p1(.4) p0(.2) rrcd(2) seed(1001) ///
        saving("`default_save'", replace)

    assert r(n_biases) == 3
    assert r(n_valid) == r(reps)
    assert r(n_draw_invalid) == 0
    assert "`r(order)'" == "misclass selection"
    _assert_close `=r(corrected)' `exp_or' 1e-8
    _assert_close `=r(mean)' `exp_or' 1e-8
    _assert_close `=r(ci_lower)' `exp_or' 1e-8
    _assert_close `=r(ci_upper)' `exp_or' 1e-8
    assert r(sd) < 1e-12

    _assert_saved_constant using "`default_save'", a(`exp_a') b(`exp_b') ///
        c(`exp_c') d(`exp_d') result(`exp_or') measure(OR)
}
if _rc == 0 {
    display as result "  PASS: V1 default multi chain equals hand calculation"
    local ++pass_count
}
else {
    display as error "  FAIL: V1 default multi chain (error `=_rc')"
    local ++fail_count
}

**# V2: Reverse constant chain equals manual selection -> misclass -> confounding
local ++test_count
capture noisily {
    tempfile reverse_save

    * Selection first: a1=100, b1=240, c1=1000/3, d1=2000/3.
    * Exposure misclassification with Se=.8 Sp=.9:
    * a2=660/7, b2=1720/7, c2=1000/3, d2=2000/3.
    * OR before confounding = 33/43.
    * Final OR = (33/43)/(7/6) = 198/301.
    local exp_a = 660 / 7
    local exp_b = 1720 / 7
    local exp_c = 1000 / 3
    local exp_d = 2000 / 3
    local exp_or = 198 / 301
    local default_or = 55 / 56

    qba_multi, a(80) b(120) c(200) d(600) reps(150) ///
        seca(.8) spca(.9) ///
        sela(.8) selb(.5) selc(.6) seld(.9) ///
        p1(.4) p0(.2) rrcd(2) order(selection misclass) seed(1001) ///
        saving("`reverse_save'", replace)

    assert "`r(order)'" == "selection misclass"
    _assert_close `=r(corrected)' `exp_or' 1e-8
    assert abs(r(corrected) - `default_or') > .1

    _assert_saved_constant using "`reverse_save'", a(`exp_a') b(`exp_b') ///
        c(`exp_c') d(`exp_d') result(`exp_or') measure(OR)
}
if _rc == 0 {
    display as result "  PASS: V2 reverse multi chain equals hand calculation"
    local ++pass_count
}
else {
    display as error "  FAIL: V2 reverse multi chain (error `=_rc')"
    local ++fail_count
}

**# V3: RR chain uses the same corrected cells and the requested measure
local ++test_count
capture noisily {
    tempfile rr_save

    * Same default-chain cells as V1.
    * RR before confounding = 73/66.
    * Final RR = (73/66)/(7/6) = 73/77.
    local exp_a = 750 / 7
    local exp_b = 1600 / 7
    local exp_c = 2000 / 7
    local exp_d = 44000 / 63
    local exp_rr = 73 / 77

    qba_multi, a(80) b(120) c(200) d(600) reps(150) measure(RR) ///
        seca(.8) spca(.9) ///
        sela(.8) selb(.5) selc(.6) seld(.9) ///
        p1(.4) p0(.2) rrcd(2) seed(1001) ///
        saving("`rr_save'", replace)

    assert "`r(measure)'" == "RR"
    _assert_close `=r(corrected)' `exp_rr' 1e-8
    _assert_close `=r(mean)' `exp_rr' 1e-8

    _assert_saved_constant using "`rr_save'", a(`exp_a') b(`exp_b') ///
        c(`exp_c') d(`exp_d') result(`exp_rr') measure(RR)
}
if _rc == 0 {
    display as result "  PASS: V3 RR multi chain equals hand calculation"
    local ++pass_count
}
else {
    display as error "  FAIL: V3 RR multi chain (error `=_rc')"
    local ++fail_count
}

**# V4: Single active bias matches corresponding single-bias commands
local ++test_count
capture noisily {
    qba_misclass, a(80) b(120) c(200) d(600) seca(.8) spca(.9)
    local mis_or = r(corrected)
    qba_multi, a(80) b(120) c(200) d(600) reps(150) ///
        seca(.8) spca(.9) seed(202)
    assert r(n_biases) == 1
    assert "`r(order)'" == "misclass"
    _assert_close `=r(corrected)' `mis_or' 1e-8

    qba_misclass, a(80) b(120) c(200) d(600) seca(.8) spca(.9) measure(RR)
    local mis_rr = r(corrected)
    qba_multi, a(80) b(120) c(200) d(600) reps(150) measure(RR) ///
        seca(.8) spca(.9) seed(202)
    _assert_close `=r(corrected)' `mis_rr' 1e-8

    qba_selection, a(200) b(100) c(300) d(400) ///
        sela(.8) selb(.5) selc(.6) seld(.9)
    local sel_or = r(corrected)
    qba_multi, a(200) b(100) c(300) d(400) reps(150) ///
        sela(.8) selb(.5) selc(.6) seld(.9) seed(303)
    assert r(n_biases) == 1
    assert "`r(order)'" == "selection"
    _assert_close `=r(corrected)' `sel_or' 1e-8

    qba_confound, estimate(2.5) p1(.4) p0(.2) rrcd(2)
    local conf_or = r(corrected)
    qba_multi, a(100) b(100) c(100) d(250) reps(150) ///
        p1(.4) p0(.2) rrcd(2) seed(404)
    assert r(n_biases) == 1
    assert "`r(order)'" == ""
    _assert_close `=r(observed)' 2.5 1e-8
    _assert_close `=r(corrected)' `conf_or' 1e-8
}
if _rc == 0 {
    display as result "  PASS: V4 single active bias matches single-bias commands"
    local ++pass_count
}
else {
    display as error "  FAIL: V4 single active bias equivalence (error `=_rc')"
    local ++fail_count
}

**# Summary
display as text ""
display as result "Known qba_multi validation Results: `pass_count'/`test_count' passed, `fail_count' failed"

capture ado uninstall qba
capture sysdir set PLUS "`orig_plus'"
capture sysdir set PERSONAL "`orig_personal'"
capture shell rm -rf "`plusdir'" "`personaldir'"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_qba_known_multi tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 9
}
else {
    display as result "ALL TESTS PASSED"
    display "RESULT: validation_qba_known_multi tests=`test_count' pass=`pass_count' fail=`fail_count'"
}
