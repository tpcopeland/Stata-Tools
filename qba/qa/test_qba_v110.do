* test_qba_v110.do — Tests for v1.1.0 fixes (18 panel deliberation items)
* Package: qba (Quantitative Bias Analysis)

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

capture program drop _assert_varabbrev_restore
program define _assert_varabbrev_restore
    syntax , State(string) RC(integer) CMD(string asis)
    set varabbrev `state'
    local run_cmd `"`cmd'"'
    local _cmd_len = length(`"`run_cmd'"')
    if `_cmd_len' >= 2 {
        if substr(`"`run_cmd'"', 1, 1) == `"""' & ///
            substr(`"`run_cmd'"', `_cmd_len', 1) == `"""' {
            local run_cmd = substr(`"`run_cmd'"', 2, `_cmd_len' - 2)
        }
    }
    capture noisily `run_cmd'
    local got = _rc
    assert `got' == `rc'
    assert c(varabbrev) == "`state'"
end

**# P12: varabbrev restore
local ++test_count
capture noisily {
    foreach state in on off {
        _assert_varabbrev_restore, state(`state') rc(0) cmd(qba)
        _assert_varabbrev_restore, state(`state') rc(0) ///
            cmd(qba_misclass, a(100) b(200) c(50) d(300) seca(.85) spca(.95))
        _assert_varabbrev_restore, state(`state') rc(0) ///
            cmd(qba_selection, a(100) b(200) c(50) d(300) sela(.9) selb(.85) selc(.7) seld(.8))
        _assert_varabbrev_restore, state(`state') rc(0) ///
            cmd(qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2.0))
        _assert_varabbrev_restore, state(`state') rc(0) ///
            cmd(qba_multi, a(100) b(200) c(50) d(300) reps(100) seca(.85) spca(.95) seed(1))
        _assert_varabbrev_restore, state(`state') rc(0) ///
            cmd(qba_plot, tornado a(100) b(200) c(50) d(300) param1(se) range1(.7 1) steps(5) name(varabbrev_plot_`state', replace))
        capture graph drop varabbrev_plot_`state'
        _assert_varabbrev_restore, state(`state') rc(0) ///
            cmd(_qba_parse_dist, dist("constant .85"))
        preserve
        clear
        set obs 10
        _assert_varabbrev_restore, state(`state') rc(0) ///
            cmd(_qba_draw_one, dist("constant .85") gen(_draw) n(10))
        restore
        _assert_varabbrev_restore, state(`state') rc(0) ///
            cmd(_qba_draw_scalar, dist("constant .85"))
    }
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: P12.1 varabbrev restored after successful commands"
    local ++pass_count
}
else {
    display as error "  FAIL: P12.1 varabbrev success restore (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    foreach state in on off {
        _assert_varabbrev_restore, state(`state') rc(198) ///
            cmd(qba_misclass, a(-1) b(200) c(50) d(300) seca(.85) spca(.95))
        _assert_varabbrev_restore, state(`state') rc(198) ///
            cmd(qba_selection, a(100) b(200) c(50) d(300) sela(0) selb(.85) selc(.7) seld(.8))
        _assert_varabbrev_restore, state(`state') rc(198) ///
            cmd(qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2.0) rrud(2.0))
        _assert_varabbrev_restore, state(`state') rc(198) ///
            cmd(qba_multi, a(100) b(200) c(50) d(300) reps(100))
        _assert_varabbrev_restore, state(`state') rc(198) ///
            cmd(qba_plot, a(100) b(200) c(50) d(300))
        _assert_varabbrev_restore, state(`state') rc(198) ///
            cmd(_qba_parse_dist, dist("gamma 2 3"))
    }
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: P12.2 varabbrev restored after error paths"
    local ++pass_count
}
else {
    display as error "  FAIL: P12.2 varabbrev error restore (error `=_rc')"
    local ++fail_count
}

**# P14: reject both rrcd and rrud
local ++test_count
capture noisily {
    qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2.0) rrud(2.0)
}
if _rc == 198 {
    display as result "  PASS: P14.1 both rrcd+rrud rejected in qba_confound"
    local ++pass_count
}
else {
    display as error "  FAIL: P14.1 expected rc 198, got `=_rc'"
    local ++fail_count
}

local ++test_count
capture noisily {
    qba_multi, a(100) b(200) c(50) d(300) reps(100) ///
        p1(.4) p0(.2) rrcd(2.0) rrud(2.0)
}
if _rc == 198 {
    display as result "  PASS: P14.2 both rrcd+rrud rejected in qba_multi"
    local ++pass_count
}
else {
    display as error "  FAIL: P14.2 expected rc 198, got `=_rc'"
    local ++fail_count
}

**# P3: coef() option for multivariable models
local ++test_count
capture noisily {
    sysuse auto, clear
    logistic foreign price weight
    qba_confound, from_model p1(.3) p0(.1) rrcd(2.0) coef(price)
    assert r(corrected) < .
}
if _rc == 0 {
    display as result "  PASS: P3.1 coef() selects specific coefficient"
    local ++pass_count
}
else {
    display as error "  FAIL: P3.1 coef() (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    sysuse auto, clear
    logistic foreign price weight
    qba_confound, from_model p1(.3) p0(.1) rrcd(2.0)
}
if _rc == 198 {
    display as result "  PASS: P3.2 multi-coef without coef() errors"
    local ++pass_count
}
else {
    display as error "  FAIL: P3.2 expected rc 198, got `=_rc'"
    local ++fail_count
}

local ++test_count
capture noisily {
    sysuse auto, clear
    logistic foreign price
    qba_confound, from_model p1(.3) p0(.1) rrcd(2.0)
    assert r(corrected) < .
}
if _rc == 0 {
    display as result "  PASS: P3.3 single-coef auto-detects without coef()"
    local ++pass_count
}
else {
    display as error "  FAIL: P3.3 single-coef auto-detect (error `=_rc')"
    local ++fail_count
}

**# P4: auto-detect measure from e(cmd)
local ++test_count
capture noisily {
    sysuse auto, clear
    logistic foreign price
    qba_confound, from_model p1(.3) p0(.1) rrcd(2.0)
    assert "`r(measure)'" == "OR"
}
if _rc == 0 {
    display as result "  PASS: P4.1 logistic auto-detects OR"
    local ++pass_count
}
else {
    display as error "  FAIL: P4.1 measure auto-detect (error `=_rc')"
    local ++fail_count
}

**# P1: subtractive correction for linear models
local ++test_count
	capture noisily {
	    sysuse auto, clear
	    regress price weight
	    qba_confound, from_model p1(.4) p0(.2) confeffect(500) coef(weight)
	    * Subtractive: corrected = b_weight - (p1 - p0) * confeffect
	    * corrected = b_weight - (0.4 - 0.2) * 500 = b_weight - 100
	    local b_weight = _b[weight]
	    local expected = `b_weight' - (.4 - .2) * 500
	    _assert_close `r(corrected)' `expected' 0.01
	    assert r(confeffect) == 500
	    assert "`r(correction_type)'" == "subtractive"
	    assert "`r(measure)'" == "coefficient"
	}
if _rc == 0 {
    display as result "  PASS: P1.1 linear model subtractive correction"
    local ++pass_count
}
else {
    display as error "  FAIL: P1.1 linear subtractive (error `=_rc')"
    local ++fail_count
}

**# P10: MC mode allows negative linear results
local ++test_count
	capture noisily {
	    sysuse auto, clear
	    regress price weight
	    qba_confound, from_model p1(.4) p0(.2) confeffect(500) coef(weight) ///
	        reps(500) seed(12345)
	    assert r(n_valid) > 0
	}
if _rc == 0 {
    display as result "  PASS: P10.1 linear MC preserves negative results"
    local ++pass_count
}
else {
    display as error "  FAIL: P10.1 linear MC (error `=_rc')"
    local ++fail_count
}

**# P5: negative corrected cells return undefined corrected measure
local ++test_count
capture noisily {
    qba_misclass, a(10) b(200) c(5) d(300) seca(.55) spca(.55)
    assert r(corrected_a) < 0
    assert r(corrected_c) < 0
    assert r(corrected) == .
}
if _rc == 0 {
    display as result "  PASS: P5.1 negative cells return missing corrected measure"
    local ++pass_count
}
else {
    display as error "  FAIL: P5.1 negative cells (error `=_rc')"
    local ++fail_count
}

**# P13: partial bias params rejected
local ++test_count
capture noisily {
    qba_multi, a(100) b(200) c(50) d(300) reps(100) ///
        seca(.85) sela(.9) selb(.85) selc(.7) seld(.8)
}
if _rc == 198 {
    display as result "  PASS: P13.1 seca without spca errors in multi"
    local ++pass_count
}
else {
    display as error "  FAIL: P13.1 expected rc 198, got `=_rc'"
    local ++fail_count
}

local ++test_count
capture noisily {
    qba_misclass, a(100) b(200) c(50) d(300) seca(.85) spca(.95) ///
        reps(100) dist_se1("uniform 0.7 0.9")
}
if _rc == 198 {
    display as result "  PASS: P13.2 dist_se1 without secb errors in misclass"
    local ++pass_count
}
else {
    display as error "  FAIL: P13.2 expected rc 198, got `=_rc'"
    local ++fail_count
}

local ++test_count
capture noisily {
    qba_multi, a(100) b(200) c(50) d(300) reps(100) ///
        seca(.85) spca(.95) dist_se1("uniform 0.7 0.9")
}
if _rc == 198 {
    display as result "  PASS: P13.3 dist_se1 without secb errors in multi"
    local ++pass_count
}
else {
    display as error "  FAIL: P13.3 expected rc 198, got `=_rc'"
    local ++fail_count
}

local ++test_count
capture noisily {
    qba_multi, a(100) b(200) c(50) d(300) reps(100) ///
        secb(.80) spcb(.90) p1(.4) p0(.2) rrcd(2.0)
}
if _rc == 198 {
    display as result "  PASS: P13.4 secb/spcb without seca/spca errors in multi"
    local ++pass_count
}
else {
    display as error "  FAIL: P13.4 expected rc 198, got `=_rc'"
    local ++fail_count
}

**# P2: order() redesign
local ++test_count
capture noisily {
    qba_multi, a(100) b(200) c(50) d(300) reps(500) seed(12345) ///
        seca(.85) spca(.95) sela(.9) selb(.85) selc(.7) seld(.8) ///
        order(selection misclass)
    assert r(corrected) < .
}
if _rc == 0 {
    display as result "  PASS: P2.1 order(selection misclass) works"
    local ++pass_count
}
else {
    display as error "  FAIL: P2.1 reversed order (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    qba_multi, a(100) b(200) c(50) d(300) reps(100) ///
        seca(.85) spca(.95) ///
        order(misclass selection confound)
}
if _rc == 198 {
    display as result "  PASS: P2.2 confound in order() rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: P2.2 expected rc 198, got `=_rc'"
    local ++fail_count
}

local ++test_count
capture noisily {
    qba_multi, a(100) b(200) c(50) d(300) reps(100) ///
        seca(.85) spca(.95) sela(.9) selb(.85) selc(.7) seld(.8) ///
        order(misclass)
}
if _rc == 198 {
    display as result "  PASS: P2.3 missing active bias in order() errors"
    local ++pass_count
}
else {
    display as error "  FAIL: P2.3 expected rc 198, got `=_rc'"
    local ++fail_count
}

**# P9: secb/spcb validation in multi
local ++test_count
capture noisily {
    qba_multi, a(100) b(200) c(50) d(300) reps(100) ///
        seca(.85) spca(.95) secb(1.1) spcb(.95)
}
if _rc == 198 {
    display as result "  PASS: P9.1 secb out of range rejected in multi"
    local ++pass_count
}
else {
    display as error "  FAIL: P9.1 expected rc 198, got `=_rc'"
    local ++fail_count
}

**# P7: qba_plot input validation
local ++test_count
capture noisily {
    qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(se) range1(.7 1) measure(HR)
}
if _rc == 198 {
    display as result "  PASS: P7.1 invalid measure(HR) rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: P7.1 expected rc 198, got `=_rc'"
    local ++fail_count
}

local ++test_count
capture noisily {
    qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(foo) range1(.7 1)
}
if _rc == 198 {
    display as result "  PASS: P7.2 invalid param name rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: P7.2 expected rc 198, got `=_rc'"
    local ++fail_count
}

local ++test_count
capture noisily {
    qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(sela) range1(0 1)
}
if _rc == 198 {
    display as result "  PASS: P7.3 selection sweep range excludes zero"
    local ++pass_count
}
else {
    display as error "  FAIL: P7.3 expected rc 198, got `=_rc'"
    local ++fail_count
}

local ++test_count
capture noisily {
    qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(p1) range1(-.1 .5)
}
if _rc == 198 {
    display as result "  PASS: P7.4 confounder probability range bounded"
    local ++pass_count
}
else {
    display as error "  FAIL: P7.4 expected rc 198, got `=_rc'"
    local ++fail_count
}

local ++test_count
capture noisily {
    qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(rrcd) range1(0 4)
}
if _rc == 198 {
    display as result "  PASS: P7.5 confounder RR range must be positive"
    local ++pass_count
}
else {
    display as error "  FAIL: P7.5 expected rc 198, got `=_rc'"
    local ++fail_count
}

local ++test_count
capture noisily {
    qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(sela) range1(.5 1) base_selb(0)
}
if _rc == 198 {
    display as result "  PASS: P7.6 selection baselines exclude zero"
    local ++pass_count
}
else {
    display as error "  FAIL: P7.6 expected rc 198, got `=_rc'"
    local ++fail_count
}

local ++test_count
capture noisily {
    qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(p1) range1(0 .5) base_p0(1.2)
}
if _rc == 198 {
    display as result "  PASS: P7.7 confounder baselines bounded"
    local ++pass_count
}
else {
    display as error "  FAIL: P7.7 expected rc 198, got `=_rc'"
    local ++fail_count
}

local ++test_count
capture noisily {
    qba_plot, tipping a(100) b(200) c(50) d(300) ///
        param1(se) range1(.6 1) param2(sp) range2(.6 1) ///
        param3(p1) range3(0 .5)
}
if _rc == 198 {
    display as result "  PASS: P7.8 param3 rejected for tipping"
    local ++pass_count
}
else {
    display as error "  FAIL: P7.8 expected rc 198, got `=_rc'"
    local ++fail_count
}

local ++test_count
capture noisily {
	    tempfile coef_mc
	    sysuse auto, clear
	    regress price weight
	    qba_confound, from_model coef(weight) p1(.4) p0(.2) confeffect(500) ///
	        reps(200) seed(20260427) saving("`coef_mc'", replace)
    local observed = r(observed)

    preserve
    use "`coef_mc'", clear
    confirm variable corrected_coefficient
    restore

    qba_plot, distribution using("`coef_mc'") observed(`observed') ///
        name(coef_dist_infer, replace)
    assert "`r(measure)'" == "coefficient"
    graph drop coef_dist_infer

    qba_plot, distribution using("`coef_mc'") observed(`observed') ///
        measure(coefficient) name(coef_dist_explicit, replace)
    assert "`r(measure)'" == "coefficient"
    graph drop coef_dist_explicit

    capture noisily qba_plot, distribution using("`coef_mc'") ///
        observed(`observed') measure(OR)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: P7.9 coefficient distribution plots are detected"
    local ++pass_count
}
else {
    display as error "  FAIL: P7.9 coefficient distribution plot (error `=_rc')"
    local ++fail_count
    capture graph drop coef_dist_infer
    capture graph drop coef_dist_explicit
}

**# P8: secb/spcb rejected in tornado
local ++test_count
capture noisily {
    qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(secb) range1(.7 1)
}
if _rc == 198 {
    display as result "  PASS: P8.1 secb rejected in tornado"
    local ++pass_count
}
else {
    display as error "  FAIL: P8.1 expected rc 198, got `=_rc'"
    local ++fail_count
}

**# P18: steps(1) rejected
local ++test_count
capture noisily {
    qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(se) range1(.7 1) steps(1)
}
if _rc == 198 {
    display as result "  PASS: P18.1 steps(1) rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: P18.1 expected rc 198, got `=_rc'"
    local ++fail_count
}

**# P17: alias dedup in tipping
local ++test_count
capture noisily {
    qba_plot, tipping a(100) b(200) c(50) d(300) ///
        param1(se) range1(.6 1) param2(seca) range2(.6 1)
}
if _rc == 198 {
    display as result "  PASS: P17.1 duplicate param (se/seca) rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: P17.1 expected rc 198, got `=_rc'"
    local ++fail_count
}

local ++test_count
capture noisily {
    qba_plot, tipping a(100) b(200) c(50) d(300) ///
        param1(se) range1(.6 1) param2(p1) range2(0 .6)
}
if _rc == 198 {
    display as result "  PASS: P17.2 mixed tipping parameter types rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: P17.2 expected rc 198, got `=_rc'"
    local ++fail_count
}

local ++test_count
capture noisily {
    qba_plot, tipping a(100) b(200) c(50) d(300) ///
        param1(sela) range1(.6 1) param2(selb) range2(.6 1)
}
if _rc == 198 {
    display as result "  PASS: P17.3 selection tipping parameters rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: P17.3 expected rc 198, got `=_rc'"
    local ++fail_count
}

**# P15: tornado identifiability guard (no crash on Se+Sp<=1)
local ++test_count
capture noisily {
    qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(se) range1(.05 1) base_sp(.9) steps(20)
}
if _rc == 0 {
    display as result "  PASS: P15.1 tornado handles Se+Sp<=1 without crash"
    local ++pass_count
}
else {
    display as error "  FAIL: P15.1 tornado identifiability (error `=_rc')"
    local ++fail_count
}

**# P6: draw-level validation
local ++test_count
capture noisily {
    qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2.0) ///
        reps(1000) dist_p1("uniform 0.0 1.5") seed(54321)
    assert r(n_draw_invalid) > 0
    assert r(n_valid) > 0
    assert r(n_valid) < r(reps)
}
if _rc == 0 {
    display as result "  PASS: P6.1 out-of-support draws filtered and counted"
    local ++pass_count
}
else {
    display as error "  FAIL: P6.1 draw validation (error `=_rc')"
    local ++fail_count
}

**# P11: saving with standard path
local ++test_count
capture noisily {
    local space_dir "`c(tmpdir)'/qba saving spaces"
    capture mkdir "`space_dir'"

    local mis_file "`space_dir'/misclass result"
    local sel_file "`space_dir'/selection result"
    local conf_file "`space_dir'/confound result"
    local multi_file "`space_dir'/multi result"
    capture erase "`mis_file'.dta"
    capture erase "`sel_file'.dta"
    capture erase "`conf_file'.dta"
    capture erase "`multi_file'.dta"

    qba_misclass, a(100) b(200) c(50) d(300) seca(.85) spca(.95) ///
        reps(120) seed(99) saving("`mis_file'", replace)
    confirm file "`mis_file'.dta"
    preserve
    use "`mis_file'", clear
    assert _N == 120
    confirm variable corrected_or
    restore

    qba_selection, a(100) b(200) c(50) d(300) ///
        sela(.9) selb(.85) selc(.7) seld(.8) ///
        reps(120) seed(99) saving("`sel_file'", replace)
    confirm file "`sel_file'.dta"
    preserve
    use "`sel_file'", clear
    assert _N == 120
    confirm variable sel_a
    restore

    qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2.0) ///
        reps(120) seed(99) saving("`conf_file'", replace)
    confirm file "`conf_file'.dta"
    preserve
    use "`conf_file'", clear
    assert _N == 120
    confirm variable bias_factor
    restore

    qba_multi, a(100) b(200) c(50) d(300) reps(120) seed(99) ///
        seca(.85) spca(.95) p1(.4) p0(.2) rrcd(2.0) ///
        saving("`multi_file'", replace)
    confirm file "`multi_file'.dta"
    preserve
    use "`multi_file'", clear
    assert _N == 120
    confirm variable corrected_or
    restore

    capture erase "`mis_file'.dta"
    capture erase "`sel_file'.dta"
    capture erase "`conf_file'.dta"
    capture erase "`multi_file'.dta"
    capture rmdir "`space_dir'"
}
if _rc == 0 {
    display as result "  PASS: P11.1 saving() works with suboptions and spaces"
    local ++pass_count
}
else {
    display as error "  FAIL: P11.1 saving (error `=_rc')"
    local ++fail_count
    capture erase "`mis_file'.dta"
    capture erase "`sel_file'.dta"
    capture erase "`conf_file'.dta"
    capture erase "`multi_file'.dta"
    capture rmdir "`space_dir'"
}

**# Summary
display as text ""
display as text "{hline 50}"
display as text "v1.1.0 Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
display as text "{hline 50}"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture ado uninstall qba
    exit 9
}
else {
    display as result "ALL TESTS PASSED"
    capture ado uninstall qba
}
