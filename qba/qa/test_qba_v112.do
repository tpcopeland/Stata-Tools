* test_qba_v112.do -- Tests for v1.1.2 deep-review fixes
* Package: qba (Quantitative Bias Analysis)
* Usage: cd qba/qa && stata-mp -b do test_qba_v112.do

clear all

* Fixed seed for randomized temporary graph and fixture names below.
set seed 20260823

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

**# P25: missing numeric options are rejected
local ++test_count
capture noisily {
    capture qba_selection, a(.) b(20) c(30) d(40) sela(.9) selb(.9) selc(.9) seld(.9)
    assert _rc == 198

    capture qba_misclass, a(.) b(50) c(80) d(200) seca(.9) spca(.95)
    assert _rc == 198

    capture qba_confound, estimate(.) p1(.4) p0(.2) rrcd(2)
    assert _rc == 198

    capture qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(.)
    assert _rc == 198

    capture qba_multi, a(.) b(50) c(80) d(200) reps(100) seca(.9) spca(.95)
    assert _rc == 198

    capture qba_plot, distribution using("missing_file_for_qba") observed(.)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: P25.1 missing numeric options are rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: P25.1 missing numeric rejection (error `=_rc')"
    local ++fail_count
}

**# P26: simple-mode probabilistic-only options are rejected
local ++test_count
capture noisily {
    tempfile ignored
    capture qba_selection, a(10) b(20) c(30) d(40) sela(.9) selb(.9) selc(.9) seld(.9) ///
        saving("`ignored'", replace)
    assert _rc == 198

    capture qba_misclass, a(100) b(50) c(80) d(200) seca(.9) spca(.95) ///
        dist_se("constant .9")
    assert _rc == 198

    capture qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2) seed(123)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: P26.1 simple-mode probabilistic-only options reject"
    local ++pass_count
}
else {
    display as error "  FAIL: P26.1 simple-mode option rejection (error `=_rc')"
    local ++fail_count
}

**# P27: linear confounding uses signed confeffect(), not RR options
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price weight
    local b_weight = _b[weight]
    qba_confound, from_model coef(weight) p1(.4) p0(.2) confeffect(-500)
    local expected = `b_weight' - (.4 - .2) * (-500)
    _assert_close `=r(corrected)' `expected' 0.01
    assert r(confeffect) == -500
    assert "`r(measure)'" == "coefficient"

    capture qba_confound, from_model coef(weight) p1(.4) p0(.2) rrcd(2)
    assert _rc == 198

    capture qba_confound, estimate(1.5) p1(.4) p0(.2) confeffect(500)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: P27.1 linear confounding has signed additive API"
    local ++pass_count
}
else {
    display as error "  FAIL: P27.1 linear confounding API (error `=_rc')"
    local ++fail_count
}

**# P28: save failures still post analytical returns
local ++test_count
capture noisily {
    tempfile exists
    clear
    set obs 1
    gen byte marker = 1
    save "`exists'", replace

    capture qba_selection, a(100) b(200) c(50) d(300) ///
        sela(.9) selb(.8) selc(.7) seld(.9) reps(100) seed(1) saving("`exists'")
    local rc = _rc
    local corrected = r(corrected)
    assert `rc' == 602
    assert `corrected' < .

    capture qba_misclass, a(100) b(200) c(50) d(300) seca(.85) spca(.95) ///
        reps(100) seed(1) saving("`exists'")
    local rc = _rc
    local corrected = r(corrected)
    assert `rc' == 602
    assert `corrected' < .

    capture qba_confound, estimate(1.5) p1(.4) p0(.2) rrcd(2) ///
        reps(100) seed(1) saving("`exists'")
    local rc = _rc
    local corrected = r(corrected)
    assert `rc' == 602
    assert `corrected' < .

    capture qba_multi, a(100) b(200) c(50) d(300) reps(100) ///
        seca(.85) spca(.95) p1(.4) p0(.2) rrcd(2) seed(1) saving("`exists'")
    local rc = _rc
    local corrected = r(corrected)
    assert `rc' == 602
    assert `corrected' < .
}
if _rc == 0 {
    display as result "  PASS: P28.1 save failures preserve analytical r()"
    local ++pass_count
}
else {
    display as error "  FAIL: P28.1 save-failure returns (error `=_rc')"
    local ++fail_count
}

**# P29: differential misclassification saved schema uses public names
local ++test_count
capture noisily {
    tempfile diffsave
    qba_misclass, a(90) b(70) c(210) d(630) ///
        seca(.88) spca(.97) secb(.76) spcb(.93) type(outcome) ///
        reps(100) seed(7) saving("`diffsave'", replace)
    preserve
    use "`diffsave'", clear
    confirm variable se
    confirm variable sp
    confirm variable se1
    confirm variable sp1
    capture confirm variable _se1
    assert _rc != 0
    restore
}
if _rc == 0 {
    display as result "  PASS: P29.1 differential saved schema is public"
    local ++pass_count
}
else {
    display as error "  FAIL: P29.1 differential saved schema (error `=_rc')"
    local ++fail_count
}

**# P30: qba_multi rejects inactive-family distribution options
local ++test_count
capture noisily {
    capture qba_multi, a(100) b(200) c(50) d(300) reps(100) ///
        p1(.4) p0(.2) rrcd(2) dist_se("uniform bad params")
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(100) ///
        seca(.85) spca(.95) dist_sela("constant .9")
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(100) ///
        seca(.85) spca(.95) dist_rr("constant 2")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: P30.1 inactive qba_multi distributions reject"
    local ++pass_count
}
else {
    display as error "  FAIL: P30.1 inactive dist_* rejection (error `=_rc')"
    local ++fail_count
}

**# P31: qba_plot rejects ambiguous/unsupported result variables and RR parameter conflicts
local ++test_count
capture noisily {
    tempfile bad ambig
    local graph_tmp "`c(tmpdir)'"
    if substr("`graph_tmp'", -1, 1) != "/" local graph_tmp "`graph_tmp'/"
    local graph_id = floor(runiform() * 1000000000)
    local existing_png "`graph_tmp'qba_v112_export_`graph_id'.png"
    capture erase "`existing_png'"
    clear
    set obs 10
    gen double corrected_a = 1
    save "`bad'", replace
    capture qba_plot, distribution using("`bad'") observed(1)
    assert _rc == 198

    clear
    set obs 10
    gen double corrected_or = 1 + runiform()
    gen double corrected_rr = 1 + runiform()
    save "`ambig'", replace
    capture qba_plot, distribution using("`ambig'") observed(1)
    assert _rc == 198

    qba_plot, distribution using("`ambig'") observed(1) measure(OR) ///
        name(qba_v112_or, replace)
    assert "`r(measure)'" == "OR"
    graph drop qba_v112_or

    graph export "`existing_png'", replace
    capture qba_plot, distribution using("`ambig'") observed(1) measure(OR) ///
        saving("`existing_png'") name(qba_v112_or_export, replace)
    local graph_rc = _rc
    assert `graph_rc' == 602
    assert "`r(measure)'" == "OR"
    graph drop qba_v112_or_export
    erase "`existing_png'"

    capture qba_plot, tipping a(100) b(200) c(50) d(300) ///
        param1(rrcd) range1(1 4) param2(rrud) range2(1 4)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: P31.1 qba_plot result and tipping guards"
    local ++pass_count
}
else {
    display as error "  FAIL: P31.1 qba_plot guards (error `=_rc')"
    capture graph drop qba_v112_or
    capture graph drop qba_v112_or_export
    capture erase "`existing_png'"
    local ++fail_count
}

**# P32: isolated install smoke
local ++test_count
local orig_plus ""
local orig_personal ""
local plusdir ""
local personaldir ""
capture noisily {
    _qba_qa_bootstrap, isolated
    local orig_plus `"`r(orig_plus)'"'
    local orig_personal `"`r(orig_personal)'"'
    local plusdir `"`r(plusdir)'"'
    local personaldir `"`r(personaldir)'"'
    which qba
    findfile qba.sthlp
    findfile _qba_distributions.ado
    qba_misclass, a(80) b(120) c(200) d(600) seca(.8) spca(.9)
    assert !missing(r(corrected))
    assert r(corrected) > 0
    _qba_qa_restore_isolation, origplus("`orig_plus'") ///
        origpersonal("`orig_personal'") plusdir("`plusdir'") ///
        personaldir("`personaldir'") uninstall
}
local iso_rc = _rc
if `iso_rc' {
    capture _qba_qa_restore_isolation, origplus("`orig_plus'") ///
        origpersonal("`orig_personal'") plusdir("`plusdir'") ///
        personaldir("`personaldir'") uninstall
}
if `iso_rc' == 0 {
    display as result "  PASS: P32.1 isolated install smoke"
    local ++pass_count
}
else {
    display as error "  FAIL: P32.1 isolated install smoke (error `iso_rc')"
    local ++fail_count
}

**# P33: README install block is release-oriented
local ++test_count
capture noisily {
    tempfile has_dist has_local has_prerelease
    capture erase "`has_dist'"
    capture erase "`has_local'"
    capture erase "`has_prerelease'"
    shell bash -c "grep -q 'raw.githubusercontent.com/tpcopeland/Stata-Tools/main/qba' '`pkg_dir'/README.md' && touch '`has_dist'' || true"
    confirm file "`has_dist'"
    shell bash -c "grep -q '/full/path/to/qba' '`pkg_dir'/README.md' && touch '`has_local'' || true"
    capture confirm file "`has_local'"
    assert _rc != 0
    shell bash -c "grep -q 'pre-release' '`pkg_dir'/README.md' && touch '`has_prerelease'' || true"
    capture confirm file "`has_prerelease'"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: P33.1 README install block is release-oriented"
    local ++pass_count
}
else {
    display as error "  FAIL: P33.1 README install block (error `=_rc')"
    local ++fail_count
}

**# P34: unsupported from_model link scales are rejected
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly probit foreign mpg
    capture qba_confound, from_model coef(mpg) p1(.4) p0(.2) confeffect(1)
    assert _rc == 198
    assert "`e(cmd)'" == "probit"

    quietly ologit rep78 mpg if rep78 < .
    capture qba_confound, from_model coef(mpg) p1(.4) p0(.2) confeffect(1)
    assert _rc == 198
    assert "`e(cmd)'" == "ologit"

    quietly glm price weight, family(gaussian) link(identity) nolog
    qba_confound, from_model coef(weight) p1(.4) p0(.2) confeffect(500)
    assert "`r(measure)'" == "coefficient"
    assert "`e(cmd)'" == "glm"
}
if _rc == 0 {
    display as result "  PASS: P34.1 unsupported from_model link scales reject"
    local ++pass_count
}
else {
    display as error "  FAIL: P34.1 unsupported model-scale guard (error `=_rc')"
    local ++fail_count
}

**# P35: previously uncovered options and stored results have semantic checks
local ++test_count
capture noisily {
    qba_misclass, a(100) b(50) c(80) d(200) seca(.9) spca(.95)
    assert r(b) == 50
    assert r(d) == 200

    qba_selection, a(100) b(200) c(50) d(300) ///
        sela(.9) selb(.8) selc(.7) seld(.6)
    assert r(sela) == .9
    assert r(selb) == .8
    assert r(selc) == .7
    assert r(seld) == .6

    sysuse auto, clear
    quietly regress price weight
    qba_confound, from_model coef(weight) p1(.4) p0(.2) ///
        confeffect(500) level(90)
    assert r(p1) == .4
    assert r(p0) == .2
    assert !missing(r(se), _se[weight])
    assert reldif(r(se), _se[weight]) < 1e-6
    local half90 = invnormal(.95) * _se[weight]
    _assert_close `=r(ci_upper) - r(observed)' `half90' 1e-6

    qba_confound, from_model coef(weight) p1(.4) p0(.2) confeffect(500) ///
        reps(100) seed(814) dist_p1("constant .4") ///
        dist_p0("constant .2") dist_confeffect("constant 500")
    assert !missing(r(se), _se[weight])
    assert reldif(r(se), _se[weight]) < 1e-6

    qba_selection, a(100) b(200) c(50) d(300) ///
        sela(.9) selb(.8) selc(.7) seld(.6) ///
        dist_sela("uniform .7 .95") reps(500) seed(812) level(80)
    local sw80 = r(ci_upper) - r(ci_lower)
    qba_selection, a(100) b(200) c(50) d(300) ///
        sela(.9) selb(.8) selc(.7) seld(.6) ///
        dist_sela("uniform .7 .95") reps(500) seed(812) level(95)
    assert !missing(r(ci_lower))
    assert r(ci_upper) - r(ci_lower) >= `sw80'

    qba_multi, a(100) b(200) c(50) d(300) seca(.85) spca(.95) ///
        dist_se("uniform .75 .95") reps(500) seed(813) level(80)
    local mw80 = r(ci_upper) - r(ci_lower)
    qba_multi, a(100) b(200) c(50) d(300) seca(.85) spca(.95) ///
        dist_se("uniform .75 .95") reps(500) seed(813) level(95)
    assert !missing(r(ci_lower))
    assert r(ci_upper) - r(ci_lower) >= `mw80'

    qba_plot, tornado a(100) b(200) c(50) d(300) type(outcome) ///
        param1(se) range1(.8 .95) steps(3) base_p1(.4) base_p0(.2) ///
        base_rrcd(2) null(1.2) scheme(s2color) ///
        name(qba_v112_option_contract, replace)
    assert "`r(plot_type)'" == "tornado"
    assert "`r(scheme)'" == "s2color"
    graph drop qba_v112_option_contract
}
if _rc == 0 {
    display as result "  PASS: P35.1 option and stored-result contracts"
    local ++pass_count
}
else {
    display as error "  FAIL: P35.1 option/return contracts (error `=_rc')"
    capture graph drop qba_v112_option_contract
    local ++fail_count
}

display as text ""
display as result "v1.1.2 Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture ado uninstall qba
    display "RESULT: test_qba_v112 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
    capture ado uninstall qba
    display "RESULT: test_qba_v112 tests=`test_count' pass=`pass_count' fail=`fail_count'"
}
