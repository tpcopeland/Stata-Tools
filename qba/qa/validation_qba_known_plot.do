* validation_qba_known_plot.do -- exact known-answer checks for qba and qba_plot
* Package: qba (Quantitative Bias Analysis)
* Usage: cd qba/qa && stata-mp -b do validation_qba_known_plot.do

clear all
version 16.0

* === Bootstrap ===
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

capture ado uninstall qba
net install qba, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

**# K1: Dispatcher exact returned contract
local ++test_count
capture noisily {
    qba
    assert "`r(version)'" == "1.0.0"
    assert "`r(commands)'" == "qba_misclass qba_selection qba_confound qba_multi qba_plot"

    qba, version
    assert "`r(version)'" == "1.0.0"
    assert "`r(commands)'" == "qba_misclass qba_selection qba_confound qba_multi qba_plot"
}
if _rc == 0 {
    display as result "  PASS: K1 qba dispatcher returns exact command contract"
    local ++pass_count
}
else {
    display as error "  FAIL: K1 qba dispatcher contract (error `=_rc')"
    local ++fail_count
}

**# K2: Tornado grid exact missing count
* Grid: se = .05(.10).95 with base_sp=.90.
* For a=80,b=120,c=200,d=600, se=.05 is nonidentifiable, and
* se=.15,.25,.35 give nonpositive corrected cells. Remaining 6 are usable.
local ++test_count
capture noisily {
    qba_plot, tornado a(80) b(120) c(200) d(600) ///
        param1(se) range1(.05 .95) base_sp(.9) steps(10) ///
        name(qba_known_tornado, replace)
    assert "`r(plot_type)'" == "tornado"
    assert "`r(measure)'" == "OR"
    assert r(n_missing) == 4
    graph drop qba_known_tornado
}
if _rc == 0 {
    display as result "  PASS: K2 tornado grid has exact infeasible-count known answer"
    local ++pass_count
}
else {
    display as error "  FAIL: K2 tornado grid known answer (error `=_rc')"
    local ++fail_count
    capture graph drop qba_known_tornado
}

**# K3: Tipping misclassification grid exact missing count
* Grid: se,sp in {.5,.75,1}. Six of nine cells are infeasible or have
* nonpositive corrected cells; only (.5,1), (.75,1), and (1,1) are usable.
local ++test_count
capture noisily {
    qba_plot, tipping a(80) b(120) c(200) d(600) ///
        param1(se) range1(.5 1) param2(sp) range2(.5 1) ///
        steps(3) name(qba_known_tipping_misclass, replace)
    assert "`r(plot_type)'" == "tipping"
    assert "`r(measure)'" == "OR"
    assert r(n_missing) == 6
    graph drop qba_known_tipping_misclass
}
if _rc == 0 {
    display as result "  PASS: K3 tipping misclassification grid has exact missing count"
    local ++pass_count
}
else {
    display as error "  FAIL: K3 tipping misclassification grid (error `=_rc')"
    local ++fail_count
    capture graph drop qba_known_tipping_misclass
}

**# K4: Tipping confounding grid has no structural missing values
local ++test_count
capture noisily {
    qba_plot, tipping a(80) b(120) c(200) d(600) measure(RR) ///
        param1(p1) range1(0 .4) param2(rrcd) range2(1 3) ///
        base_p0(.1) steps(3) name(qba_known_tipping_confound, replace)
    assert "`r(plot_type)'" == "tipping"
    assert "`r(measure)'" == "RR"
    assert r(n_missing) == 0
    graph drop qba_known_tipping_confound
}
if _rc == 0 {
    display as result "  PASS: K4 tipping confounding grid returns complete RR surface"
    local ++pass_count
}
else {
    display as error "  FAIL: K4 tipping confounding grid (error `=_rc')"
    local ++fail_count
    capture graph drop qba_known_tipping_confound
}

**# K5: Distribution plot infers coefficient scale and rejects wrong scale
local ++test_count
capture noisily {
    tempfile coef_mc
    clear
    set obs 5
    gen double corrected_coefficient = -0.2 + (_n - 1) * 0.1
    save "`coef_mc'", replace

    qba_plot, distribution using("`coef_mc'") observed(0) ///
        name(qba_known_coef_dist, replace)
    assert "`r(plot_type)'" == "distribution"
    assert "`r(measure)'" == "coefficient"
    graph drop qba_known_coef_dist

    capture qba_plot, distribution using("`coef_mc'") observed(0) measure(OR)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: K5 distribution plot coefficient scale contract"
    local ++pass_count
}
else {
    display as error "  FAIL: K5 distribution plot coefficient contract (error `=_rc')"
    local ++fail_count
    capture graph drop qba_known_coef_dist
}

**# Summary
display as result "Known plot validation Results: `pass_count'/`test_count' passed, `fail_count' failed"

capture ado uninstall qba

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_qba_known_plot tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: validation_qba_known_plot tests=`test_count' pass=`pass_count' fail=`fail_count'"
