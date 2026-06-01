* test_qba_adversarial_selection_deep.do -- deep adversarial tests for qba_selection
* Package: qba (Quantitative Bias Analysis)
* Usage: cd qba/qa && stata-mp -b do test_qba_adversarial_selection_deep.do

clear all
version 16.0

capture log close _all

* Bootstrap from package root derived from qa/ working directory.
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

local _orig_plus "`c(sysdir_plus)'"
local _orig_personal "`c(sysdir_personal)'"
local _orig_varabbrev "`c(varabbrev)'"
tempfile _qba_plus_stub _qba_personal_stub
local _qba_plus "`_qba_plus_stub'_dir"
local _qba_personal "`_qba_personal_stub'_dir"
mkdir "`_qba_plus'"
mkdir "`_qba_personal'"
sysdir set PLUS "`_qba_plus'"
sysdir set PERSONAL "`_qba_personal'"

capture ado uninstall qba
quietly net install qba, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _assert_close
program define _assert_close
    args actual expected tolerance
    if "`tolerance'" == "" local tolerance = 1e-8
    if missing(`actual') | missing(`expected') {
        assert missing(`actual') & missing(`expected')
        exit
    }
    local diff = abs(`actual' - `expected')
    if `diff' > `tolerance' {
        display as error "Expected: `expected', Got: `actual' (diff: `diff')"
        exit 9
    }
end

capture program drop _assert_selection_data_unchanged
program define _assert_selection_data_unchanged
    args expected_n expected_sig expected_varabbrev
    assert _N == `expected_n'
    confirm variable id
    confirm variable exposure
    confirm variable outcome
    confirm variable marker
    datasignature
    assert "`r(datasignature)'" == "`expected_sig'"
    assert c(varabbrev) == "`expected_varabbrev'"
end

capture program drop _make_caller_data
program define _make_caller_data, rclass
    clear
    set obs 8
    gen byte id = _n
    gen byte exposure = mod(_n, 2)
    gen byte outcome = _n <= 3
    gen double marker = id * 10 + exposure - outcome / 10
    sort marker
    datasignature
    return local sig "`r(datasignature)'"
    return scalar n = _N
end

**# D1: invalid distribution parse errors restore caller data and varabbrev
local ++test_count
capture noisily {
    foreach state in on off {
        set varabbrev `state'
        _make_caller_data
        local sig_before "`r(sig)'"
        local n_before = r(n)
        capture qba_selection, a(20) b(40) c(60) d(120) ///
            sela(.8) selb(.6) selc(.7) seld(.9) reps(100) ///
            dist_sela("uniform .9 .8")
        assert _rc == 198
        _assert_selection_data_unchanged `n_before' "`sig_before'" "`state'"

        set varabbrev `state'
        _make_caller_data
        local sig_before "`r(sig)'"
        local n_before = r(n)
        capture qba_selection, a(20) b(40) c(60) d(120) ///
            sela(.8) selb(.6) selc(.7) seld(.9) reps(100) ///
            dist_selb("constant .6 .7")
        assert _rc == 198
        _assert_selection_data_unchanged `n_before' "`sig_before'" "`state'"

        set varabbrev `state'
        _make_caller_data
        local sig_before "`r(sig)'"
        local n_before = r(n)
        capture qba_selection, a(20) b(40) c(60) d(120) ///
            sela(.8) selb(.6) selc(.7) seld(.9) reps(100) ///
            dist_selc("unknown .7")
        assert _rc == 198
        _assert_selection_data_unchanged `n_before' "`sig_before'" "`state'"
    }
}
if _rc == 0 {
    display as result "  PASS: D1 invalid distributions restore data and varabbrev"
    local ++pass_count
}
else {
    display as error "  FAIL: D1 invalid distribution preservation (error `=_rc')"
    local ++fail_count
}

**# D2: out-of-support selection draws fail cleanly and preserve data
local ++test_count
capture noisily {
    _make_caller_data
    local sig_before "`r(sig)'"
    local n_before = r(n)
    local vabbrev_before "`c(varabbrev)'"
    capture qba_selection, a(20) b(40) c(60) d(120) ///
        sela(.8) selb(.6) selc(.7) seld(.9) reps(100) ///
        dist_sela("constant 0")
    assert _rc == 198
    _assert_selection_data_unchanged `n_before' "`sig_before'" "`vabbrev_before'"

    _make_caller_data
    local sig_before "`r(sig)'"
    local n_before = r(n)
    local vabbrev_before "`c(varabbrev)'"
    capture qba_selection, a(20) b(40) c(60) d(120) ///
        sela(.8) selb(.6) selc(.7) seld(.9) reps(100) ///
        dist_seld("constant 1.0001")
    assert _rc == 198
    _assert_selection_data_unchanged `n_before' "`sig_before'" "`vabbrev_before'"
}
if _rc == 0 {
    display as result "  PASS: D2 out-of-support draws fail cleanly"
    local ++pass_count
}
else {
    display as error "  FAIL: D2 out-of-support draws (error `=_rc')"
    local ++fail_count
}

**# D3: constant probabilistic OR matches simple mode and saved schema
local ++test_count
capture noisily {
    tempfile saved_or
    qba_selection, a(25) b(40) c(75) d(160) ///
        sela(.8) selb(.6) selc(.7) seld(.9)
    local simple_obs = r(observed)
    local simple_corr = r(corrected)
    local simple_a = r(corrected_a)
    local simple_b = r(corrected_b)
    local simple_c = r(corrected_c)
    local simple_d = r(corrected_d)

    qba_selection, a(25) b(40) c(75) d(160) ///
        sela(.8) selb(.6) selc(.7) seld(.9) reps(100) ///
        dist_sela("constant .8") dist_selb("constant .6") ///
        dist_selc("constant .7") dist_seld("constant .9") ///
        seed(12345) saving("`saved_or'", replace)
    _assert_close `=r(observed)' `simple_obs' 1e-12
    _assert_close `=r(corrected)' `simple_corr' 1e-12
    _assert_close `=r(mean)' `simple_corr' 1e-12
    _assert_close `=r(sd)' 0 1e-12
    _assert_close `=r(ci_lower)' `simple_corr' 1e-12
    _assert_close `=r(ci_upper)' `simple_corr' 1e-12
    assert r(n_valid) == 100
    preserve
    use "`saved_or'", clear
    assert _N == 100
    confirm variable corrected_or
    confirm variable sel_a
    confirm variable sel_b
    confirm variable sel_c
    confirm variable sel_d
    confirm variable a_corr
    confirm variable b_corr
    confirm variable c_corr
    confirm variable d_corr
    summarize corrected_or, meanonly
    _assert_close `=r(min)' `simple_corr' 1e-12
    _assert_close `=r(max)' `simple_corr' 1e-12
    summarize a_corr, meanonly
    _assert_close `=r(min)' `simple_a' 1e-12
    _assert_close `=r(max)' `simple_a' 1e-12
    summarize b_corr, meanonly
    _assert_close `=r(min)' `simple_b' 1e-12
    summarize c_corr, meanonly
    _assert_close `=r(min)' `simple_c' 1e-12
    summarize d_corr, meanonly
    _assert_close `=r(min)' `simple_d' 1e-12
    restore
}
if _rc == 0 {
    display as result "  PASS: D3 constant probabilistic OR and saved schema"
    local ++pass_count
}
else {
    capture restore
    display as error "  FAIL: D3 constant probabilistic OR (error `=_rc')"
    local ++fail_count
}

**# D4: constant probabilistic RR matches simple mode and saved schema
local ++test_count
capture noisily {
    tempfile saved_rr
    qba_selection, a(25) b(40) c(75) d(160) ///
        sela(.8) selb(.6) selc(.7) seld(.9) measure(RR)
    local simple_obs = r(observed)
    local simple_corr = r(corrected)

    qba_selection, a(25) b(40) c(75) d(160) ///
        sela(.8) selb(.6) selc(.7) seld(.9) measure(RR) reps(100) ///
        dist_sela("constant .8") dist_selb("constant .6") ///
        dist_selc("constant .7") dist_seld("constant .9") ///
        seed(54321) saving("`saved_rr'", replace)
    _assert_close `=r(observed)' `simple_obs' 1e-12
    _assert_close `=r(corrected)' `simple_corr' 1e-12
    _assert_close `=r(mean)' `simple_corr' 1e-12
    _assert_close `=r(sd)' 0 1e-12
    _assert_close `=r(ci_lower)' `simple_corr' 1e-12
    _assert_close `=r(ci_upper)' `simple_corr' 1e-12
    assert r(n_valid) == 100
    preserve
    use "`saved_rr'", clear
    assert _N == 100
    confirm variable corrected_rr
    capture confirm variable corrected_or
    assert _rc != 0
    summarize corrected_rr, meanonly
    _assert_close `=r(min)' `simple_corr' 1e-12
    _assert_close `=r(max)' `simple_corr' 1e-12
    restore
}
if _rc == 0 {
    display as result "  PASS: D4 constant probabilistic RR and saved schema"
    local ++pass_count
}
else {
    capture restore
    display as error "  FAIL: D4 constant probabilistic RR (error `=_rc')"
    local ++fail_count
}

**# D5: saving(), replace, no-replace failure, and caller-data preservation
local ++test_count
capture noisily {
    tempfile selout
    _make_caller_data
    local sig_before "`r(sig)'"
    local n_before = r(n)
    local vabbrev_before "`c(varabbrev)'"
    qba_selection, a(20) b(40) c(60) d(120) ///
        sela(.8) selb(.6) selc(.7) seld(.9) reps(100) ///
        dist_sela("constant .8") dist_selb("constant .6") ///
        dist_selc("constant .7") dist_seld("constant .9") ///
        saving("`selout'", replace)
    _assert_selection_data_unchanged `n_before' "`sig_before'" "`vabbrev_before'"

    capture qba_selection, a(20) b(40) c(60) d(120) ///
        sela(.8) selb(.6) selc(.7) seld(.9) reps(100) ///
        saving("`selout'")
    local rc = _rc
    local corrected = r(corrected)
    assert `rc' == 602
    assert `corrected' < .
    _assert_selection_data_unchanged `n_before' "`sig_before'" "`vabbrev_before'"

    qba_selection, a(20) b(40) c(60) d(120) ///
        sela(.8) selb(.6) selc(.7) seld(.9) reps(100) ///
        saving("`selout'", replace)
    _assert_selection_data_unchanged `n_before' "`sig_before'" "`vabbrev_before'"
}
if _rc == 0 {
    display as result "  PASS: D5 saving behavior and data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: D5 saving/data preservation (error `=_rc')"
    local ++fail_count
}

**# D6: parser guards reject invalid probabilistic option combinations
local ++test_count
capture noisily {
    tempfile ignored
    capture qba_selection, a(10) b(20) c(30) d(40) ///
        sela(.9) selb(.8) selc(.7) seld(.9) reps(99)
    assert _rc == 198

    capture qba_selection, a(10) b(20) c(30) d(40) ///
        sela(.9) selb(.8) selc(.7) seld(.9) reps(-1)
    assert _rc == 198

    capture qba_selection, a(10) b(20) c(30) d(40) ///
        sela(.9) selb(.8) selc(.7) seld(.9) seed(1)
    assert _rc == 198

    capture qba_selection, a(10) b(20) c(30) d(40) ///
        sela(.9) selb(.8) selc(.7) seld(.9) ///
        dist_sela("constant .9")
    assert _rc == 198

    capture qba_selection, a(10) b(20) c(30) d(40) ///
        sela(.9) selb(.8) selc(.7) seld(.9) ///
        saving("`ignored'", replace)
    assert _rc == 198

    capture qba_selection, a(10) b(20) c(30) d(40) ///
        sela(.9) selb(.8) selc(.7) seld(.9) reps(100) ///
        saving("`ignored'", append)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: D6 invalid option combinations reject"
    local ++pass_count
}
else {
    display as error "  FAIL: D6 invalid option combinations (error `=_rc')"
    local ++fail_count
}

sysdir set PLUS "`_orig_plus'"
sysdir set PERSONAL "`_orig_personal'"
capture shell rm -rf "`_qba_plus'" "`_qba_personal'"
capture ado uninstall qba
set varabbrev `_orig_varabbrev'

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_qba_adversarial_selection_deep tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_qba_adversarial_selection_deep tests=`test_count' pass=`pass_count' fail=`fail_count'"
