* test_qba_adversarial_multi_deep.do -- adversarial qba_multi QA
* Package: qba (Quantitative Bias Analysis)
* Usage: cd qba/qa && stata-mp -b do test_qba_adversarial_multi_deep.do

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
local orig_varabbrev "`c(varabbrev)'"
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

capture program drop _assert_signature
program define _assert_signature
    syntax , N(integer) SIGnature(string)
    assert _N == `n'
    datasignature
    assert "`r(datasignature)'" == "`signature'"
end

capture program drop _run_and_check_varabbrev
program define _run_and_check_varabbrev
    syntax , State(string) RC(integer) CMD(string asis)
    set varabbrev `state'
    capture noisily `cmd'
    local got = _rc
    assert `got' == `rc'
    assert c(varabbrev) == "`state'"
end

**# A1: Inactive-family and invalid family options reject
local ++test_count
capture noisily {
    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) dist_sela("constant .9")
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) dist_p1("constant .4")
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        sela(.9) selb(.8) selc(.7) seld(.95) dist_se("constant .85")
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        p1(.4) p0(.2) rrcd(2) dist_seld("constant .95")
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        p1(.4) p0(.2) rrcd(2) secb(.9)
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) mctype(both)
    assert _rc == 198

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) measure(rate)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: A1 inactive and invalid family options reject"
    local ++pass_count
}
else {
    display as error "  FAIL: A1 inactive/invalid options (error `=_rc')"
    local ++fail_count
}

**# A2: Parameter-invalid draws are counted and saved as missing results
local ++test_count
capture noisily {
    tempfile invalid_params
    qba_multi, a(100) b(200) c(50) d(300) reps(500) ///
        p1(.4) p0(.2) rrcd(2) dist_p1("uniform .2 1.2") ///
        seed(444) saving("`invalid_params'", replace)
    local reps = r(reps)
    local n_valid = r(n_valid)
    local n_draw_invalid = r(n_draw_invalid)
    assert `n_draw_invalid' > 0
    assert `n_valid' > 0
    assert `n_valid' + `n_draw_invalid' == `reps'

    preserve
    use "`invalid_params'", clear
    assert _N == `reps'
    count if missing(corrected_or)
    assert r(N) == `n_draw_invalid'
    count if !missing(corrected_or)
    assert r(N) == `n_valid'
    restore
}
if _rc == 0 {
    display as result "  PASS: A2 parameter-invalid accounting"
    local ++pass_count
}
else {
    display as error "  FAIL: A2 parameter-invalid accounting (error `=_rc')"
    local ++fail_count
}

**# A3: Result-invalid draws are distinct from out-of-support parameter draws
local ++test_count
capture noisily {
    tempfile invalid_results
    qba_multi, a(5) b(95) c(100) d(800) reps(500) ///
        seca(.99) spca(.9) dist_sp("uniform .85 .99") ///
        seed(555) saving("`invalid_results'", replace)
    local reps = r(reps)
    local n_valid = r(n_valid)
    assert r(n_draw_invalid) == 0
    assert `n_valid' > 0
    assert `n_valid' < `reps'

    preserve
    use "`invalid_results'", clear
    assert _N == `reps'
    count if missing(corrected_or)
    assert r(N) == `reps' - `n_valid'
    count if a_corr < 0 | b_corr < 0 | c_corr < 0 | d_corr < 0
    assert r(N) == `reps' - `n_valid'
    restore
}
if _rc == 0 {
    display as result "  PASS: A3 result-invalid accounting"
    local ++pass_count
}
else {
    display as error "  FAIL: A3 result-invalid accounting (error `=_rc')"
    local ++fail_count
}

**# A4: Seed reproducibility covers returns and saved Monte Carlo dataset
local ++test_count
capture noisily {
    tempfile seed_one seed_two seed_three

    qba_multi, a(100) b(200) c(50) d(300) reps(350) ///
        seca(.85) spca(.95) dist_se("uniform .8 .9") dist_sp("uniform .9 .99") ///
        sela(.9) selb(.8) selc(.7) seld(.95) p1(.4) p0(.2) rrcd(2) ///
        dist_rr("uniform 1.5 2.5") seed(98765) saving("`seed_one'", replace)
    local corrected_one = r(corrected)
    local mean_one = r(mean)
    local sd_one = r(sd)
    preserve
    use "`seed_one'", clear
    datasignature
    local sig_one "`r(datasignature)'"
    restore

    qba_multi, a(100) b(200) c(50) d(300) reps(350) ///
        seca(.85) spca(.95) dist_se("uniform .8 .9") dist_sp("uniform .9 .99") ///
        sela(.9) selb(.8) selc(.7) seld(.95) p1(.4) p0(.2) rrcd(2) ///
        dist_rr("uniform 1.5 2.5") seed(98765) saving("`seed_two'", replace)
    _assert_close `=r(corrected)' `corrected_one' 1e-12
    _assert_close `=r(mean)' `mean_one' 1e-12
    _assert_close `=r(sd)' `sd_one' 1e-12
    preserve
    use "`seed_two'", clear
    datasignature
    assert "`r(datasignature)'" == "`sig_one'"
    restore

    qba_multi, a(100) b(200) c(50) d(300) reps(350) ///
        seca(.85) spca(.95) dist_se("uniform .8 .9") dist_sp("uniform .9 .99") ///
        sela(.9) selb(.8) selc(.7) seld(.95) p1(.4) p0(.2) rrcd(2) ///
        dist_rr("uniform 1.5 2.5") seed(98766) saving("`seed_three'", replace)
    assert abs(r(mean) - `mean_one') > 1e-10
}
if _rc == 0 {
    display as result "  PASS: A4 seed reproducibility"
    local ++pass_count
}
else {
    display as error "  FAIL: A4 seed reproducibility (error `=_rc')"
    local ++fail_count
}

**# A5: saving() schema is stable for OR and RR outputs
local ++test_count
capture noisily {
    tempfile or_save rr_save

    qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) sela(.9) selb(.8) selc(.7) seld(.95) ///
        p1(.4) p0(.2) rrcd(2) seed(11) saving("`or_save'", replace)
    preserve
    use "`or_save'", clear
    ds
    assert "`r(varlist)'" == "a_corr b_corr c_corr d_corr corrected_or"
    foreach v in a_corr b_corr c_corr d_corr corrected_or {
        confirm numeric variable `v'
    }
    restore

    qba_multi, a(100) b(200) c(50) d(300) reps(120) measure(RR) ///
        seca(.85) spca(.95) sela(.9) selb(.8) selc(.7) seld(.95) ///
        p1(.4) p0(.2) rrud(2) seed(11) saving("`rr_save'", replace)
    preserve
    use "`rr_save'", clear
    ds
    assert "`r(varlist)'" == "a_corr b_corr c_corr d_corr corrected_rr"
    foreach v in a_corr b_corr c_corr d_corr corrected_rr {
        confirm numeric variable `v'
    }
    restore
}
if _rc == 0 {
    display as result "  PASS: A5 saving schema"
    local ++pass_count
}
else {
    display as error "  FAIL: A5 saving schema (error `=_rc')"
    local ++fail_count
}

**# A6: Caller data and varabbrev survive success, parser errors, and save errors
local ++test_count
capture noisily {
    tempfile exists_save

    sysuse auto, clear
    datasignature
    local sig_before "`r(datasignature)'"
    local n_before = _N

    qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) seed(42)
    _assert_signature, n(`n_before') signature("`sig_before'")

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) dist_se("uniform bad")
    assert _rc == 198
    _assert_signature, n(`n_before') signature("`sig_before'")

    preserve
    clear
    set obs 1
    gen byte marker = 1
    save "`exists_save'", replace
    restore

    capture qba_multi, a(100) b(200) c(50) d(300) reps(120) ///
        seca(.85) spca(.95) seed(42) saving("`exists_save'")
    assert _rc == 602
    assert r(corrected) < .
    _assert_signature, n(`n_before') signature("`sig_before'")

    foreach state in on off {
        _run_and_check_varabbrev, state(`state') rc(0) ///
            cmd(qba_multi, a(100) b(200) c(50) d(300) reps(120) seca(.85) spca(.95) seed(42))
        _run_and_check_varabbrev, state(`state') rc(198) ///
            cmd(qba_multi, a(100) b(200) c(50) d(300) reps(120) seca(.85) spca(.95) dist_se("uniform bad"))
    }
}
if _rc == 0 {
    display as result "  PASS: A6 data and varabbrev preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: A6 data/varabbrev preservation (error `=_rc')"
    set varabbrev `orig_varabbrev'
    local ++fail_count
}

**# Summary
display as text ""
display as result "Adversarial qba_multi deep Results: `pass_count'/`test_count' passed, `fail_count' failed"

capture ado uninstall qba
capture sysdir set PLUS "`orig_plus'"
capture sysdir set PERSONAL "`orig_personal'"
capture shell rm -rf "`plusdir'" "`personaldir'"
set varabbrev `orig_varabbrev'

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_qba_adversarial_multi_deep tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 9
}
else {
    display as result "ALL TESTS PASSED"
    display "RESULT: test_qba_adversarial_multi_deep tests=`test_count' pass=`pass_count' fail=`fail_count'"
}
