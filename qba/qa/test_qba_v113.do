* test_qba_v113.do -- Tests for v1.1.3 method and documentation fixes
* Package: qba (Quantitative Bias Analysis)
* Usage: cd qba/qa && stata-mp -b do test_qba_v113.do

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

**# P36: cloglog coefficients cannot be relabeled as risk ratios
local ++test_count
capture noisily {
    clear
    set obs 400
    generate byte x = (_n > 200)
    generate byte y = 0
    replace y = 1 in 1/100
    replace y = 1 in 201/350
    quietly cloglog y x, nolog
    local b_before = _b[x]
    local se_before = _se[x]

    set varabbrev on
    capture qba_confound, from_model measure(RR) p1(.4) p0(.2) rrcd(2)
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
    assert "`e(cmd)'" == "cloglog"
    assert reldif(_b[x], `b_before') < 1e-12
    assert reldif(_se[x], `se_before') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: P36.1 cloglog from_model is rejected on the wrong scale"
    local ++pass_count
}
else {
    display as error "  FAIL: P36.1 cloglog scale rejection (error `=_rc')"
    local ++fail_count
}

**# P37: survival estimators map only supported hazard-ratio scales
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    quietly stcox age
    qba_confound, from_model evalue commonoutcome p1(.4) p0(.2) rrcd(2)
    assert "`r(measure)'" == "HR"
    assert "`r(evalue_conv)'" == "hrcommon"
    local cox_eval = r(evalue)
    local cox_rr = r(evalue_rr)
    qba_confound, from_model measure(HR) evalue commonoutcome ///
        p1(.4) p0(.2) rrcd(2)
    assert reldif(r(evalue), `cox_eval') < 1e-12
    assert reldif(r(evalue_rr), `cox_rr') < 1e-12
    capture qba_confound, from_model measure(RR) p1(.4) p0(.2) rrcd(2)
    assert _rc == 198
    assert "`e(cmd2)'" == "stcox"

    quietly streg age, distribution(weibull) nolog
    qba_confound, from_model evalue commonoutcome p1(.4) p0(.2) rrcd(2)
    assert "`r(measure)'" == "HR"
    assert "`r(evalue_conv)'" == "hrcommon"

    clear
    set obs 300
    generate double t = ceil(_n/3) + mod(_n, 7)/10
    generate byte status = mod(_n, 3)
    generate byte x = mod(_n, 2)
    stset t, failure(status==1)
    quietly stcrreg x, compete(status==2)
    local shr_before = _b[x]
    capture qba_confound, from_model p1(.4) p0(.2) rrcd(2)
    assert _rc == 198
    assert "`e(cmd)'" == "stcrreg"
    assert reldif(_b[x], `shr_before') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: P37.1 supported survival models use HR and subhazards reject"
    local ++pass_count
}
else {
    display as error "  FAIL: P37.1 survival-model scale contracts (error `=_rc')"
    local ++fail_count
}

**# P38: total-error summaries use one common valid-replicate mask
local ++test_count
capture noisily {
    tempfile draws
    qba_misclass, a(2) b(8) c(2) d(18) seca(.87) spca(.99) ///
        measure(RR) reps(5000) seed(90210) ///
        dist_se("beta 20 3") dist_sp("beta 100 1") ///
        totalerror saving("`draws'", replace)
    local n_syst = r(n_valid)
    local n_total = r(n_valid_te)
    local syst_median = r(corrected)
    local syst_lower = r(ci_lower)
    local syst_upper = r(ci_upper)
    assert `n_syst' == `n_total'

    preserve
    use "`draws'", clear
    quietly count if corrected_rr < .
    assert r(N) == `n_syst'
    quietly count if total_rr < .
    assert r(N) == `n_total'
    quietly count if corrected_rr < . & missing(total_rr)
    assert r(N) == 0
    quietly summarize corrected_rr, detail
    assert reldif(r(p50), `syst_median') < 1e-12
    quietly _pctile corrected_rr, percentiles(2.5 97.5)
    assert reldif(r(r1), `syst_lower') < 1e-12
    assert reldif(r(r2), `syst_upper') < 1e-12
    restore
}
if _rc == 0 {
    display as result "  PASS: P38.1 total-error arms share the reference validity mask"
    local ++pass_count
}
else {
    display as error "  FAIL: P38.1 total-error validity mask (error `=_rc')"
    capture restore
    local ++fail_count
}

**# P39: method labels and second-edition citations match the shipped behavior
local ++test_count
capture noisily {
    local ados : dir "`pkg_dir'" files "*.ado"
    local helps : dir "`pkg_dir'" files "*.sthlp"
    foreach f of local ados {
        _qba_qa_assert_file_not_contains using "`pkg_dir'/`f'", ///
            pattern("Lash TL, Fox MP, Fink AK")
        _qba_qa_assert_file_not_contains using "`pkg_dir'/`f'", ///
            pattern("Lash/Fox/Fink")
    }
    foreach f of local helps {
        _qba_qa_assert_file_not_contains using "`pkg_dir'/`f'", ///
            pattern("Lash TL, Fox MP, Fink AK")
        _qba_qa_assert_file_not_contains using "`pkg_dir'/`f'", ///
            pattern("Lash, Fox, and Fink")
    }
    tempfile stale_readme current_readme
    filefilter "`pkg_dir'/README.md" "`stale_readme'", ///
        from("Lash TL, Fox MP, Fink AK") to("STALE")
    assert r(occurrences) == 0
    filefilter "`pkg_dir'/README.md" "`current_readme'", ///
        from("Fox MP, MacLehose RF, Lash TL") to("CURRENT")
    assert r(occurrences) == 2
    _qba_qa_assert_file_not_contains using "`pkg_dir'/qba_plot.sthlp", ///
        pattern("full uncertainty")
    _qba_qa_assert_file_contains using "`pkg_dir'/qba.ado", ///
        pattern("Fox MP, MacLehose RF, Lash TL")
    _qba_qa_assert_file_contains using "`pkg_dir'/qba_selection.sthlp", ///
        pattern("Chapter 4")
    _qba_qa_assert_file_contains using "`pkg_dir'/qba_confound.sthlp", ///
        pattern("Chapter 5")
    _qba_qa_assert_file_contains using "`pkg_dir'/qba_misclass.sthlp", ///
        pattern("Chapter 6")
}
if _rc == 0 {
    display as result "  PASS: P39.1 method labels and citations are current"
    local ++pass_count
}
else {
    display as error "  FAIL: P39.1 method labels/citations (error `=_rc')"
    local ++fail_count
}

display as result "v1.1.3 Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture ado uninstall qba
    display "RESULT: test_qba_v113 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

capture ado uninstall qba
display "RESULT: test_qba_v113 tests=`test_count' pass=`pass_count' fail=`fail_count'"
