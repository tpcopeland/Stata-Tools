* crossval_external_qba.do -- cross-validates qba against external R examples
* Package: qba (Quantitative Bias Analysis)
* Usage: cd qba/qa && stata-mp -b do crossval_external_qba.do

clear all
version 16.0

capture program drop _qba_ext_assert_close
program define _qba_ext_assert_close
    args actual expected tolerance
    if "`tolerance'" == "" local tolerance = 0.000001
    if missing(`actual') | missing(`expected') {
        display as error "Missing comparison value: actual=`actual' expected=`expected'"
        exit 9
    }
    local diff = abs(`actual' - `expected')
    if `diff' > `tolerance' {
        display as error "Expected: " %21.12g `expected' ///
            ", Got: " %21.12g `actual' ///
            " (diff: " %21.12g `diff' ", tolerance: " %21.12g `tolerance' ")"
        exit 9
    }
end

capture program drop _qba_ext_expect
program define _qba_ext_expect, rclass
    syntax , Name(string) USing(string)
    preserve
    quietly use "`using'", clear
    quietly keep if name == "`name'"
    assert _N == 1
    return scalar value = value[1]
    restore
end

capture program drop _qba_ext_compare
program define _qba_ext_compare
    syntax , Actual(real) Name(string) USing(string) [Tolerance(real 0.000001)]
    _qba_ext_expect, name("`name'") using("`using'")
    _qba_ext_assert_close `actual' `r(value)' `tolerance'
end

capture program drop _qba_crossval_external_main
program define _qba_crossval_external_main
    version 16.0

    local test_count = 0
    local pass_count = 0
    local fail_count = 0
    local failed_tests ""

    local qa_dir "`c(pwd)'"
    local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
    capture confirm file "`pkg_dir'/qba.pkg"
    if _rc {
        display as error "could not locate qba package root from `c(pwd)'"
        exit 601
    }

    local oracle_script "`qa_dir'/tools/oracle_external_qba.R"
    capture confirm file "`oracle_script'"
    if _rc {
        display as error "external oracle script not found: `oracle_script'"
        exit 601
    }

    tempfile dependency_check rscript_ok episensr_ok
    tempname depfh
    file open `depfh' using "`dependency_check'", write text replace
    file write `depfh' "args <- commandArgs(trailingOnly = TRUE)" _n
    file write `depfh' "if (length(args) != 2) quit(status = 2)" _n
    file write `depfh' "writeLines('ok', args[1])" _n
    file write `depfh' "if (requireNamespace('episensr', quietly = TRUE)) writeLines('ok', args[2])" _n
    file close `depfh'

    capture noisily shell Rscript --version
    capture shell Rscript "`dependency_check'" "`rscript_ok'" "`episensr_ok'"
    capture confirm file "`rscript_ok'"
    if _rc {
        display as text "SKIP: Rscript is not available; external qba cross-validation not run"
        exit 77
    }
    capture confirm file "`episensr_ok'"
    if _rc {
        display as text "SKIP: R package episensr is not available; external qba cross-validation not run"
        exit 77
    }

    capture ado uninstall qba
    quietly net install qba, from("`pkg_dir'") replace

    tempfile oracle_csv oracle_dta

    capture noisily shell Rscript "`oracle_script'" "`oracle_csv'"
    if _rc {
        display as error "episensr external oracle failed (error `=_rc')"
        exit 1
    }

    preserve
    import delimited using "`oracle_csv'", varnames(1) clear stringcols(_all)
    assert _N == 34
    gen double value_d = real(value)
    assert !missing(value_d)
    drop value
    rename value_d value
    save "`oracle_dta'", replace
    restore

    **# Misclassification

    local ++test_count
    capture noisily {
        * episensr::misclass() Fink and Lash 2003 exposure example.
        qba_misclass, a(215) b(1449) c(668) d(4296) ///
            seca(.78) secb(.78) spca(.99) spcb(.99) ///
            type(exposure)
        local got_a = r(corrected_a)
        local got_b = r(corrected_b)
        local got_c = r(corrected_c)
        local got_d = r(corrected_d)
        local got_or = r(corrected)
        _qba_ext_compare, actual(`got_a') name("mis_fink_a") ///
            using("`oracle_dta'")
        _qba_ext_compare, actual(`got_b') name("mis_fink_b") ///
            using("`oracle_dta'")
        _qba_ext_compare, actual(`got_c') name("mis_fink_c") ///
            using("`oracle_dta'")
        _qba_ext_compare, actual(`got_d') name("mis_fink_d") ///
            using("`oracle_dta'")
        _qba_ext_compare, actual(`got_or') name("mis_fink_or") ///
            using("`oracle_dta'")

        qba_misclass, a(215) b(1449) c(668) d(4296) ///
            seca(.78) secb(.78) spca(.99) spcb(.99) ///
            type(exposure) measure(RR)
        local got_rr = r(corrected)
        _qba_ext_compare, actual(`got_rr') name("mis_fink_rr") ///
            using("`oracle_dta'")
    }
    if _rc == 0 {
        display as result "  PASS: M1 exposure misclassification matches episensr"
        local ++pass_count
    }
    else {
        display as error "  FAIL: M1 exposure misclassification (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' M1"
    }

    local ++test_count
    capture noisily {
        * episensr::misclass() AMI death outcome example.
        qba_misclass, a(4558) b(3428) c(46305) d(46085) ///
            seca(.53) secb(.53) spca(.99) spcb(.99) ///
            type(outcome)
        local got_a = r(corrected_a)
        local got_b = r(corrected_b)
        local got_c = r(corrected_c)
        local got_d = r(corrected_d)
        local got_or = r(corrected)
        _qba_ext_compare, actual(`got_a') name("mis_ami_a") ///
            using("`oracle_dta'")
        _qba_ext_compare, actual(`got_b') name("mis_ami_b") ///
            using("`oracle_dta'")
        _qba_ext_compare, actual(`got_c') name("mis_ami_c") ///
            using("`oracle_dta'")
        _qba_ext_compare, actual(`got_d') name("mis_ami_d") ///
            using("`oracle_dta'")
        _qba_ext_compare, actual(`got_or') name("mis_ami_or") ///
            using("`oracle_dta'")

        qba_misclass, a(4558) b(3428) c(46305) d(46085) ///
            seca(.53) secb(.53) spca(.99) spcb(.99) ///
            type(outcome) measure(RR)
        local got_rr = r(corrected)
        _qba_ext_compare, actual(`got_rr') name("mis_ami_rr") ///
            using("`oracle_dta'")
    }
    if _rc == 0 {
        display as result "  PASS: M2 outcome misclassification matches episensr"
        local ++pass_count
    }
    else {
        display as error "  FAIL: M2 outcome misclassification (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' M2"
    }

    **# Selection Bias

    local ++test_count
    capture noisily {
        * episensr::selection() Stang et al. 2006 uveal melanoma example.
        qba_selection, a(136) b(107) c(297) d(165) ///
            sela(.94) selb(.85) selc(.64) seld(.25)
        local got_a = r(corrected_a)
        local got_b = r(corrected_b)
        local got_c = r(corrected_c)
        local got_d = r(corrected_d)
        local got_or = r(corrected)
        local got_bf = r(bias_factor)
        _qba_ext_compare, actual(`got_a') name("sel_stang_a") ///
            using("`oracle_dta'")
        _qba_ext_compare, actual(`got_b') name("sel_stang_b") ///
            using("`oracle_dta'")
        _qba_ext_compare, actual(`got_c') name("sel_stang_c") ///
            using("`oracle_dta'")
        _qba_ext_compare, actual(`got_d') name("sel_stang_d") ///
            using("`oracle_dta'")
        _qba_ext_compare, actual(`got_or') name("sel_stang_or") ///
            using("`oracle_dta'")
        _qba_ext_compare, actual(`got_bf') name("sel_stang_bf") ///
            using("`oracle_dta'")

        qba_selection, a(136) b(107) c(297) d(165) ///
            sela(.94) selb(.85) selc(.64) seld(.25) measure(RR)
        local got_rr = r(corrected)
        _qba_ext_compare, actual(`got_rr') name("sel_stang_rr") ///
            using("`oracle_dta'")
    }
    if _rc == 0 {
        display as result "  PASS: S1 selection bias matches episensr"
        local ++pass_count
    }
    else {
        display as error "  FAIL: S1 selection bias (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' S1"
    }

    **# Unmeasured Confounding and E-values

    local ++test_count
    capture noisily {
        * episensr::confounders() Tyndall et al. 1996 HIV/circumcision example.
        local obs_rr = (105 / (105 + 527)) / (85 / (85 + 93))
        qba_confound, estimate(`obs_rr') measure(RR) ///
            p1(.8) p0(.05) rrcd(.63)
        local got_corrected = r(corrected)
        local got_bf = r(bias_factor)
        _qba_ext_compare, actual(`obs_rr') name("conf_tyndall_observed_rr") ///
            using("`oracle_dta'")
        _qba_ext_compare, actual(`got_corrected') ///
            name("conf_tyndall_corrected_rr") using("`oracle_dta'")
        _qba_ext_compare, actual(`got_bf') ///
            name("conf_tyndall_bf") using("`oracle_dta'")
    }
    if _rc == 0 {
        display as result "  PASS: C1 unmeasured confounding matches episensr"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C1 unmeasured confounding (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' C1"
    }

    local ++test_count
    capture noisily {
        * episensr::confounders_evalue() Victoria et al. 1987 RR example.
        qba_confound, estimate(3.9) measure(RR) evalue
        local got_evalue = r(evalue)
        _qba_ext_compare, actual(`got_evalue') name("evalue_victoria_point") ///
            using("`oracle_dta'")
    }
    if _rc == 0 {
        display as result "  PASS: E1 E-value matches episensr"
        local ++pass_count
    }
    else {
        display as error "  FAIL: E1 E-value (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' E1"
    }

    **# Multi-bias Chaining

    local ++test_count
    capture noisily {
        * episensr "Multiple Bias Modeling" Chien et al. sequential example:
        * misclass() -> selection() -> confounders().
        local se_case = 24 / (24 + 19)
        local se_control = 18 / (18 + 13)
        local sp_case = 144 / (144 + 2)
        local sp_control = 130 / (130 + 4)
        qba_multi, a(118) b(832) c(103) d(884) reps(200) ///
            seca(`se_case') secb(`se_control') ///
            spca(`sp_case') spcb(`sp_control') ///
            sela(.734) selb(.605) selc(.816) seld(.756) ///
            p1(.299) p0(.436) rrcd(.8) ///
            dist_se("constant `se_case'") ///
            dist_se1("constant `se_control'") ///
            dist_sp("constant `sp_case'") ///
            dist_sp1("constant `sp_control'") ///
            dist_sela("constant .734") dist_selb("constant .605") ///
            dist_selc("constant .816") dist_seld("constant .756") ///
            dist_p1("constant .299") dist_p0("constant .436") ///
            dist_rr("constant .8") seed(529)
        local got_corrected = r(corrected)
        local got_mean = r(mean)
        local got_n_biases = r(n_biases)
        local got_order "`r(order)'"
        _qba_ext_compare, actual(`got_corrected') name("multi_chien_final_or") ///
            using("`oracle_dta'")
        _qba_ext_compare, actual(`got_mean') name("multi_chien_final_or") ///
            using("`oracle_dta'")
        assert `got_n_biases' == 3
        assert "`got_order'" == "misclass selection"
    }
    if _rc == 0 {
        display as result "  PASS: X1 multi-bias chain matches episensr vignette"
        local ++pass_count
    }
    else {
        display as error "  FAIL: X1 multi-bias chain (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' X1"
    }

    **# Summary

    display as text ""
    display as result "External cross-validation: `pass_count'/`test_count' passed, `fail_count' failed"
    display "RESULT: crossval_external_qba tests=`test_count' pass=`pass_count' fail=`fail_count'"

    if `fail_count' > 0 {
        display as error "FAILED TESTS: `failed_tests'"
        exit 1
    }
    display as result "ALL TESTS PASSED"
end

local _orig_plus "`c(sysdir_plus)'"
local _orig_personal "`c(sysdir_personal)'"
tempfile _qba_plus_stub _qba_personal_stub
local _qba_plus "`_qba_plus_stub'_dir"
local _qba_personal "`_qba_personal_stub'_dir"
mkdir "`_qba_plus'"
mkdir "`_qba_personal'"
sysdir set PLUS "`_qba_plus'"
sysdir set PERSONAL "`_qba_personal'"

capture noisily _qba_crossval_external_main
local _rc_main = _rc

capture ado uninstall qba
capture sysdir set PLUS "`_orig_plus'"
capture sysdir set PERSONAL "`_orig_personal'"
capture shell rm -rf "`_qba_plus'" "`_qba_personal'"
capture program drop _qba_crossval_external_main
capture program drop _qba_ext_compare
capture program drop _qba_ext_expect
capture program drop _qba_ext_assert_close

if `_rc_main' exit `_rc_main'
