* test_qba_adversarial_multi_plot.do -- adversarial QA for qba_multi and qba_plot
* Package: qba (Quantitative Bias Analysis)
* Usage: cd qba/qa && stata-mp -b do test_qba_adversarial_multi_plot.do

clear all
version 16.0

* === Bootstrap ===
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

capture program drop _assert_varabbrev_restore
program define _assert_varabbrev_restore
    syntax , State(string) RC(integer) CMD(string asis)
    set varabbrev `state'
    local run_cmd `"`cmd'"'
    capture noisily `run_cmd'
    local got = _rc
    assert `got' == `rc'
    assert c(varabbrev) == "`state'"
end

capture program drop _assert_signature
program define _assert_signature
    syntax , N(integer) SIGnature(string)
    assert _N == `n'
    datasignature
    assert "`r(datasignature)'" == "`signature'"
end

capture program drop _make_distribution_data
program define _make_distribution_data
    syntax , SAving(string)
    clear
    set obs 40
    gen double corrected_or = 1 + _n / 100
    replace corrected_or = . in 1/5
    save "`saving'", replace
end

capture program drop _make_allmissing_data
program define _make_allmissing_data
    syntax , SAving(string)
    clear
    set obs 10
    gen double corrected_or = .
    save "`saving'", replace
end

capture program drop _make_string_result_data
program define _make_string_result_data
    syntax , SAving(string)
    clear
    set obs 10
    gen str8 corrected_or = "bad"
    save "`saving'", replace
end

**# M1: qba_multi active-bias combinations and deterministic constants
local ++test_count
capture noisily {
    tempfile combo_save

    qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) seed(101)
    assert r(n_biases) == 1
    assert r(n_valid) == r(reps)
    assert r(n_draw_invalid) == 0
    assert "`r(order)'" == "misclass"
    assert r(sd) <= 1e-12

    qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        sela(.9) selb(.8) selc(.7) seld(.95) seed(101)
    assert r(n_biases) == 1
    assert r(n_valid) == r(reps)
    assert r(n_draw_invalid) == 0
    assert "`r(order)'" == "selection"
    assert r(sd) <= 1e-12

    qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        p1(.4) p0(.2) rrcd(2) seed(101)
    assert r(n_biases) == 1
    assert r(n_valid) == r(reps)
    assert r(n_draw_invalid) == 0
    assert "`r(order)'" == ""
    assert r(sd) <= 1e-12

    qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) sela(.9) selb(.8) selc(.7) seld(.95) seed(101)
    assert r(n_biases) == 2
    assert "`r(order)'" == "misclass selection"
    assert r(sd) <= 1e-12

    qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) p1(.4) p0(.2) rrcd(2) seed(101)
    assert r(n_biases) == 2
    assert "`r(order)'" == "misclass"
    assert r(sd) <= 1e-12

    qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        sela(.9) selb(.8) selc(.7) seld(.95) p1(.4) p0(.2) rrcd(2) seed(101)
    assert r(n_biases) == 2
    assert "`r(order)'" == "selection"
    assert r(sd) <= 1e-12

    qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) sela(.9) selb(.8) selc(.7) seld(.95) ///
        p1(.4) p0(.2) rrcd(2) seed(101) saving("`combo_save'", replace)
    assert r(n_biases) == 3
    assert r(n_valid) == r(reps)
    assert r(n_draw_invalid) == 0
    assert "`r(order)'" == "misclass selection"
    assert r(sd) <= 1e-12

    preserve
    use "`combo_save'", clear
    assert _N == 120
    confirm variable a_corr
    confirm variable b_corr
    confirm variable c_corr
    confirm variable d_corr
    confirm variable corrected_or
    summarize corrected_or, meanonly
    _assert_close `r(min)' `r(max)' 1e-12
    restore
}
if _rc == 0 {
    display as result "  PASS: M1.1 qba_multi active-bias combinations and constants"
    local ++pass_count
}
else {
    display as error "  FAIL: M1.1 qba_multi combinations/constants (error `=_rc')"
    local ++fail_count
}

**# M2: qba_multi order semantics
local ++test_count
capture noisily {
    qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.75) spca(.95) sela(.6) selb(.9) selc(.7) seld(.95) seed(222)
    local default_corrected = r(corrected)
    assert "`r(order)'" == "misclass selection"

    qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.75) spca(.95) sela(.6) selb(.9) selc(.7) seld(.95) ///
        order(misclass selection) seed(222)
    _assert_close `=r(corrected)' `default_corrected' 1e-12

    qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.75) spca(.95) sela(.6) selb(.9) selc(.7) seld(.95) ///
        order(selection misclass) seed(222)
    local reverse_corrected = r(corrected)
    assert "`r(order)'" == "selection misclass"
    assert abs(`reverse_corrected' - `default_corrected') > 1e-8

    qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.75) spca(.95) sela(.6) selb(.9) selc(.7) seld(.95) ///
        p1(.4) p0(.2) rrcd(2) order(selection misclass) seed(222)
    local with_confound = r(corrected)
    local bf = (.4 * (2 - 1) + 1) / (.2 * (2 - 1) + 1)
    _assert_close `with_confound' `=`reverse_corrected' / `bf'' 1e-10
    assert "`r(order)'" == "selection misclass"

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) p1(.4) p0(.2) rrcd(2) order(misclass confound)
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) sela(.9) selb(.8) selc(.7) seld(.95) ///
        order(misclass)
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) order(misclass misclass)
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) order(foo)
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        sela(.9) selb(.85) selc(.7) seld(.8) order(selection misclass) seed(1)
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) order(misclass selection) seed(1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: M2.1 qba_multi order semantics"
    local ++pass_count
}
else {
    display as error "  FAIL: M2.1 qba_multi order semantics (error `=_rc')"
    local ++fail_count
}

**# M3: qba_multi invalid and insufficient parameter sets
local ++test_count
capture noisily {
    capture qba_multi, a(100) b(200) c(50) d(300) reps(120)
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(99) seca(.85) spca(.95)
    assert _rc == 198

    capture qba_multi, a(0) b(0) c(0) d(0) reps(120) seca(.85) spca(.95)
    assert _rc == 2000

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) seca(.85)
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        sela(.9) selb(.8) selc(.7)
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) p1(.4) p0(.2)
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        p1(.4) p0(.2) rrcd(2) rrud(2)
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        secb(.8) spcb(.9) p1(.4) p0(.2) rrcd(2)
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.5) spca(.5)
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        p1(.4) p0(.2) rrcd(2) dist_se("constant .85")
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) dist_se1("constant .8")
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) saving("foo", append)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: M3.1 qba_multi invalid parameter sets reject"
    local ++pass_count
}
else {
    display as error "  FAIL: M3.1 qba_multi invalid parameter sets (error `=_rc')"
    local ++fail_count
}

**# M4: qba_multi draw-invalid accounting
local ++test_count
capture noisily {
    qba_multi, a(100) b(200) c(50) d(300) reps(500) ///
        p1(.4) p0(.2) rrcd(2) dist_p1("uniform .2 1.2") seed(444)
    assert r(n_draw_invalid) > 0
    assert r(n_valid) > 0
    assert r(n_valid) < r(reps)
    assert r(n_valid) + r(n_draw_invalid) == r(reps)
    assert r(n_biases) == 1
}
if _rc == 0 {
    display as result "  PASS: M4.1 qba_multi n_valid/n_draw_invalid accounting"
    local ++pass_count
}
else {
    display as error "  FAIL: M4.1 qba_multi draw accounting (error `=_rc')"
    local ++fail_count
}

**# M5: qba_multi saving(), replace, and save-failure returns
local ++test_count
capture noisily {
    tempfile clean_save exists_save
    qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) p1(.4) p0(.2) rrcd(2) seed(11) ///
        saving("`clean_save'", replace)
    confirm file "`clean_save'"
    preserve
    use "`clean_save'", clear
    assert _N == 120
    confirm variable corrected_or
    restore

    clear
    set obs 1
    gen byte marker = 1
    save "`exists_save'", replace

    sysuse auto, clear
    datasignature
    local sig_before "`r(datasignature)'"
    local n_before = _N
    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) p1(.4) p0(.2) rrcd(2) seed(11) ///
        saving("`exists_save'")
    local save_rc = _rc
    local saved_corrected = r(corrected)
    assert `save_rc' == 602
    assert `saved_corrected' < .
    _assert_signature, n(`n_before') signature("`sig_before'")
}
if _rc == 0 {
    display as result "  PASS: M5.1 qba_multi saving and replace behavior"
    local ++pass_count
}
else {
    display as error "  FAIL: M5.1 qba_multi saving behavior (error `=_rc')"
    local ++fail_count
}

**# P1: qba_plot graph export and name collisions
local ++test_count
capture noisily {
    tempfile dist_data
    _make_distribution_data, saving("`dist_data'")

    qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(se) range1(.7 1) steps(5) name(qba_adv_collision, replace)

    capture qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(se) range1(.7 1) steps(5) name(qba_adv_collision)
    local name_rc = _rc
    local name_plot_type "`r(plot_type)'"
    assert `name_rc' != 0
    assert "`name_plot_type'" == "tornado"
    capture graph drop Graph
    graph drop qba_adv_collision

    local export_svg "`c(tmpdir)'/qba_adv_export_collision.svg"
    capture erase "`export_svg'"
    qba_plot, distribution using("`dist_data'") observed(1.2) ///
        saving("`export_svg'") name(qba_adv_export_seed) replace
    confirm file "`export_svg'"
    _assert_text_file_contains "`export_svg'" "Distribution"
    graph drop qba_adv_export_seed

    capture qba_plot, distribution using("`dist_data'") observed(1.2) ///
        saving("`export_svg'") name(qba_adv_export_collision, replace)
    local export_rc = _rc
    local export_plot_type "`r(plot_type)'"
    assert `export_rc' == 602
    assert "`export_plot_type'" == "distribution"
    graph drop qba_adv_export_collision

    qba_plot, distribution using("`dist_data'") observed(1.2) ///
        saving("`export_svg'") name(qba_adv_export_replace) replace
    confirm file "`export_svg'"
    graph drop qba_adv_export_replace
    erase "`export_svg'"
}
if _rc == 0 {
    display as result "  PASS: P1.1 qba_plot graph collisions and replace"
    local ++pass_count
}
else {
    display as error "  FAIL: P1.1 qba_plot graph collisions (error `=_rc')"
    capture graph drop Graph
    capture graph drop qba_adv_collision
    capture graph drop qba_adv_export_seed
    capture graph drop qba_adv_export_collision
    capture graph drop qba_adv_export_replace
    capture erase "`export_svg'"
    local ++fail_count
}

**# P2: qba_plot distribution input variables and missing values
local ++test_count
capture noisily {
    tempfile good allmissing string_result ambig rr_only
    _make_distribution_data, saving("`good'")
    _make_allmissing_data, saving("`allmissing'")
    _make_string_result_data, saving("`string_result'")

    clear
    set obs 10
    gen double corrected_or = 1 + runiform()
    gen double corrected_rr = 1 + runiform()
    save "`ambig'", replace

    clear
    set obs 10
    gen double corrected_rr = 1 + runiform()
    save "`rr_only'", replace

    capture qba_plot, distribution observed(1)
    assert _rc == 198

    capture qba_plot, distribution using("`good'")
    assert _rc == 198

    capture qba_plot, distribution using("`allmissing'") observed(1)
    assert _rc == 198

    capture qba_plot, distribution using("`string_result'") observed(1)
    assert _rc == 198

    capture qba_plot, distribution using("`ambig'") observed(1)
    assert _rc == 198

    capture qba_plot, distribution using("`rr_only'") observed(1) measure(OR)
    assert _rc == 198

    qba_plot, distribution using("`good'") observed(1.2) measure(OR) ///
        name(qba_adv_dist_good, replace)
    assert "`r(plot_type)'" == "distribution"
    assert "`r(measure)'" == "OR"
    graph drop qba_adv_dist_good

    qba_plot, distribution using("`rr_only'") observed(1.2) ///
        name(qba_adv_dist_rr, replace)
    assert "`r(measure)'" == "RR"
    graph drop qba_adv_dist_rr
}
if _rc == 0 {
    display as result "  PASS: P2.1 qba_plot distribution variable validation"
    local ++pass_count
}
else {
    display as error "  FAIL: P2.1 qba_plot distribution validation (error `=_rc')"
    capture graph drop qba_adv_dist_good
    capture graph drop qba_adv_dist_rr
    local ++fail_count
}

**# P3: qba_plot tornado and tipping parameter validation
local ++test_count
capture noisily {
    capture qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(se) range1(.7 1) measure(coefficient)
    assert _rc == 198

    capture qba_plot, tipping a(100) b(200) c(50) d(300) ///
        param1(se) range1(.7 1) param2(sp) range2(.7 1) measure(coefficient)
    assert _rc == 198

    capture qba_plot, tornado a(100) b(200) c(50) d(300) param1(se)
    assert _rc == 198

    capture qba_plot, tornado a(100) b(200) c(50) d(300) range1(.7 1)
    assert _rc == 198

    capture qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(se) range1(1 .7)
    assert _rc == 198

    capture qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(se) range1(. 1)
    assert _rc != 0

    capture qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(secb) range1(.7 1)
    assert _rc == 198

    capture qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(sela) range1(0 1)
    assert _rc == 198

    capture qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(p1) range1(-.1 .8)
    assert _rc == 198

    capture qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(rrcd) range1(0 4)
    assert _rc == 198

    capture qba_plot, tipping a(100) b(200) c(50) d(300) ///
        param1(se) range1(.6 1) param2(seca) range2(.6 1)
    assert _rc == 198

    capture qba_plot, tipping a(100) b(200) c(50) d(300) ///
        param1(se) range1(.6 1) param2(p1) range2(0 .6)
    assert _rc == 198

    capture qba_plot, tipping a(100) b(200) c(50) d(300) ///
        param1(sela) range1(.6 1) param2(selb) range2(.6 1)
    assert _rc == 198

    capture qba_plot, tipping a(100) b(200) c(50) d(300) ///
        param1(rrcd) range1(1 4) param2(rrud) range2(1 4)
    assert _rc == 198

    capture qba_plot, tipping a(100) b(200) c(50) d(300) ///
        param1(se) range1(.6 1) param2(sp) range2(.6 1) ///
        param3(p1) range3(0 .5)
    assert _rc == 198

    qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(p1) range1(0 .6) base_rrud(2) steps(5) ///
        name(qba_adv_tornado_rrud, replace)
    assert "`r(plot_type)'" == "tornado"
    graph drop qba_adv_tornado_rrud

    qba_plot, tipping a(100) b(200) c(50) d(300) ///
        param1(p1) range1(0 .6) param2(rrud) range2(1 4) ///
        base_rrud(2) steps(5) name(qba_adv_tipping_rrud, replace)
    assert "`r(plot_type)'" == "tipping"
    graph drop qba_adv_tipping_rrud
}
if _rc == 0 {
    display as result "  PASS: P3.1 qba_plot tornado/tipping validation"
    local ++pass_count
}
else {
    display as error "  FAIL: P3.1 qba_plot tornado/tipping validation (error `=_rc')"
    capture graph drop qba_adv_tornado_rrud
    capture graph drop qba_adv_tipping_rrud
    local ++fail_count
}

**# S1: varabbrev restore on success and error paths
local ++test_count
capture noisily {
    tempfile good string_result
    _make_distribution_data, saving("`good'")
    _make_string_result_data, saving("`string_result'")

    foreach state in on off {
        _assert_varabbrev_restore, state(`state') rc(0) ///
            cmd(qba_multi, a(100) b(200) c(50) d(300) reps(120) seca(.85) spca(.95) seed(7))

        _assert_varabbrev_restore, state(`state') rc(198) ///
            cmd(qba_multi, a(100) b(200) c(50) d(300) reps(120) seca(.85) spca(.95) dist_se("uniform bad"))

        _assert_varabbrev_restore, state(`state') rc(0) ///
            cmd(qba_plot, distribution using("`good'") observed(1.2) name(qba_adv_varabbrev_`state', replace))
        capture graph drop qba_adv_varabbrev_`state'

        _assert_varabbrev_restore, state(`state') rc(198) ///
            cmd(qba_plot, distribution using("`string_result'") observed(1.2))
    }
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: S1.1 varabbrev restored on success and error"
    local ++pass_count
}
else {
    display as error "  FAIL: S1.1 varabbrev restore (error `=_rc')"
    capture graph drop qba_adv_varabbrev_on
    capture graph drop qba_adv_varabbrev_off
    set varabbrev on
    local ++fail_count
}

**# S2: data preservation across internal preserve/restore paths
local ++test_count
capture noisily {
    tempfile good allmissing
    _make_distribution_data, saving("`good'")
    _make_allmissing_data, saving("`allmissing'")

    sysuse auto, clear
    datasignature
    local sig_before "`r(datasignature)'"
    local n_before = _N

    qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) p1(.4) p0(.2) rrcd(2) seed(12)
    _assert_signature, n(`n_before') signature("`sig_before'")

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) dist_se("uniform bad")
    assert _rc == 198
    _assert_signature, n(`n_before') signature("`sig_before'")

    qba_plot, tornado a(100) b(200) c(50) d(300) ///
        param1(se) range1(.7 1) steps(5) name(qba_adv_preserve_tornado, replace)
    graph drop qba_adv_preserve_tornado
    _assert_signature, n(`n_before') signature("`sig_before'")

    qba_plot, distribution using("`good'") observed(1.2) ///
        name(qba_adv_preserve_dist, replace)
    graph drop qba_adv_preserve_dist
    _assert_signature, n(`n_before') signature("`sig_before'")

    capture qba_plot, distribution using("`allmissing'") observed(1.2)
    assert _rc == 198
    _assert_signature, n(`n_before') signature("`sig_before'")
}
if _rc == 0 {
    display as result "  PASS: S2.1 qba_multi/qba_plot preserve caller data"
    local ++pass_count
}
else {
    display as error "  FAIL: S2.1 data preservation (error `=_rc')"
    capture graph drop qba_adv_preserve_tornado
    capture graph drop qba_adv_preserve_dist
    local ++fail_count
}

**# Summary
display as text ""
display as result "Adversarial qba_multi/qba_plot Results: `pass_count'/`test_count' passed, `fail_count' failed"

capture graph drop _all
_qba_qa_restore_isolation, origplus("`orig_plus'") ///
    origpersonal("`orig_personal'") plusdir("`plusdir'") ///
    personaldir("`personaldir'") uninstall
set varabbrev `orig_varabbrev'

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_qba_adversarial_multi_plot tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 9
}
else {
    display as result "ALL TESTS PASSED"
    display "RESULT: test_qba_adversarial_multi_plot tests=`test_count' pass=`pass_count' fail=`fail_count'"
}
