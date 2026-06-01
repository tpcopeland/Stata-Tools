* test_qba_v111.do -- Tests for v1.1.1 robustness fixes
* Package: qba (Quantitative Bias Analysis)
* Usage: cd qba/qa && stata-mp -b do test_qba_v111.do

clear all

* === Bootstrap ===
capture do "_qba_qa_common.do"
if _rc {
    do "qa/_qba_qa_common.do"
}
_qba_qa_bootstrap
local qa_dir `"`r(qa_dir)'"'
local pkg_dir `"`r(pkg_dir)'"'

local test_count = 0
local pass_count = 0
local fail_count = 0

**# P19: nonnumeric distribution parameters fail cleanly
local ++test_count
capture noisily {
    findfile _qba_distributions.ado
    run "`r(fn)'"

    capture _qba_parse_dist, dist("uniform a b")
    assert _rc == 198

    capture qba_misclass, a(100) b(200) c(50) d(300) seca(.85) spca(.95) ///
        reps(100) dist_se("uniform a b")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: P19.1 nonnumeric distribution parameters return rc 198"
    local ++pass_count
}
else {
    display as error "  FAIL: P19.1 distribution parameter validation (error `=_rc')"
    local ++fail_count
}

**# P20: all-zero tables are rejected
local ++test_count
capture noisily {
    capture qba_misclass, a(0) b(0) c(0) d(0) seca(.9) spca(.9)
    assert _rc == 2000

    capture qba_selection, a(0) b(0) c(0) d(0) sela(.9) selb(.9) selc(.9) seld(.9)
    assert _rc == 2000

    capture qba_multi, a(0) b(0) c(0) d(0) reps(100) seca(.9) spca(.9)
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: P20.1 all-zero analytical tables are rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: P20.1 all-zero table rejection (error `=_rc')"
    local ++fail_count
}

**# P21: qba_plot rejects invalid and empty grids
local ++test_count
capture noisily {
    capture qba_plot, tornado a(-2) b(1) c(1) d(1) ///
        param1(se) range1(.7 1) steps(3)
    assert _rc == 198

    capture qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(se) range1(.05 .2) base_sp(.5) steps(3)
    assert _rc == 198

    capture qba_plot, tipping a(100) b(200) c(50) d(300) ///
        param1(se) range1(.05 .2) param2(sp) range2(.05 .2) steps(3)
    assert _rc == 198

    tempfile allmissing
    clear
    set obs 5
    gen double corrected_or = .
    save "`allmissing'", replace

    capture qba_plot, distribution using("`allmissing'") observed(1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: P21.1 qba_plot rejects invalid cells and empty outputs"
    local ++pass_count
}
else {
    display as error "  FAIL: P21.1 qba_plot empty-output guards (error `=_rc')"
    local ++fail_count
}

**# P22: qba_plot recognizes secb/spcb before rejecting unsupported sweeps
local ++test_count
capture noisily {
    capture qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(secb) range1(.7 1)
    assert _rc == 198

    capture qba_plot, tipping a(100) b(200) c(50) d(300) ///
        param1(secb) range1(.7 1) param2(spcb) range2(.7 1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: P22.1 secb/spcb unsupported sweep path remains guarded"
    local ++pass_count
}
else {
    display as error "  FAIL: P22.1 secb/spcb plot guard (error `=_rc')"
    local ++fail_count
}

**# P23: package commands reload bundled helper over stale in-memory helpers
local ++test_count
capture noisily {
    capture program drop _qba_draw_one
    program define _qba_draw_one
        version 16.0
        display as error "stub helper invoked"
        exit 459
    end
    qba_misclass, a(100) b(200) c(50) d(300) seca(.85) spca(.95) ///
        reps(100) seed(1)
    assert r(n_valid) == 100

    capture program drop _qba_draw_one
    program define _qba_draw_one
        version 16.0
        display as error "stub helper invoked"
        exit 459
    end
    qba_selection, a(100) b(200) c(50) d(300) ///
        sela(.9) selb(.8) selc(.7) seld(.9) reps(100) seed(1)
    assert r(n_valid) == 100

    capture program drop _qba_draw_one
    program define _qba_draw_one
        version 16.0
        display as error "stub helper invoked"
        exit 459
    end
    qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2.0) reps(100) seed(1)
    assert r(n_valid) == 100

    capture program drop _qba_draw_one
    program define _qba_draw_one
        version 16.0
        display as error "stub helper invoked"
        exit 459
    end
    qba_multi, a(100) b(200) c(50) d(300) reps(100) ///
        seca(.85) spca(.95) p1(.4) p0(.2) rrcd(2.0) seed(1)
    assert r(n_valid) == 100
}
if _rc == 0 {
    display as result "  PASS: P23.1 commands reload bundled distribution helper"
    local ++pass_count
}
else {
    display as error "  FAIL: P23.1 helper reload over stale program (error `=_rc')"
    local ++fail_count
}

**# P24: qba_plot rrud baseline and cloglog from_model semantics
local ++test_count
capture noisily {
    qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(p1) range1(.2 .5) base_p0(.1) base_rrud(3) steps(4) ///
        name(plot_base_rrud, replace)
    graph drop plot_base_rrud

    sysuse auto, clear
    quietly cloglog foreign mpg, nolog
    capture qba_confound, from_model p1(.3) p0(.1) rrcd(2.0)
    assert _rc == 198

    qba_confound, from_model measure(RR) p1(.3) p0(.1) rrcd(2.0)
    assert "`r(measure)'" == "RR"
}
if _rc == 0 {
    display as result "  PASS: P24.1 rrud plot baseline and cloglog semantics are guarded"
    local ++pass_count
}
else {
    display as error "  FAIL: P24.1 rrud/cloglog regressions (error `=_rc')"
    capture graph drop plot_base_rrud
    local ++fail_count
}

display as text ""
display as result "v1.1.1 Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture ado uninstall qba
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
    capture ado uninstall qba
}
