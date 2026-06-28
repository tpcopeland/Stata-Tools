* test_msm_weight_ergonomics.do
* Focused QA for Workstream E msm_weight usability improvements.

version 16.0
clear all
set more off
set varabbrev off

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

capture program drop _mw_prepare_example
program define _mw_prepare_example
    version 16.0

    local qa_dir "`c(pwd)'"
    local pkg_dir "`qa_dir'/.."

    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
end

capture program drop _file_contains_ci
program define _file_contains_ci, rclass
    version 16.0
    syntax using/, PATtern(string)

    tempname fh
    local found 0

    file open `fh' using "`using'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(lower(`"`macval(line)'"'), lower(`"`pattern'"')) > 0 {
            local found 1
        }
        file read `fh' line
    }
    file close `fh'

    return scalar found = `found'
end

display as text ""
display as text "{hline 72}"
display as result "msm_weight ergonomics QA"
display as text "{hline 72}"

* --- WERG1: prepared covariates become the default denominator model ---
local ++test_count
capture noisily {
    tempfile default_ref

    _mw_prepare_example
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) nolog

    keep id period _msm_weight _msm_tw_weight
    rename _msm_weight explicit_weight
    rename _msm_tw_weight explicit_tw_weight
    save `default_ref'

    _mw_prepare_example
    msm_weight, treat_n_cov(age sex) nolog

    merge 1:1 id period using `default_ref', nogenerate
    assert reldif(_msm_weight, explicit_weight) < 1e-12
    assert reldif(_msm_tw_weight, explicit_tw_weight) < 1e-12
}
if _rc == 0 {
    display as result "  PASS WERG1: default denominator matches explicit prepared covariates"
    local ++pass_count
}
else {
    display as error "  FAIL WERG1: prepared-covariate defaulting (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' WERG1"
}

* --- WERG2: preview resolves formulas without mutating dataset state ---
local ++test_count
capture noisily {
    _mw_prepare_example

    tempfile preview_stub
    local preview_log "`preview_stub'.log"
    capture log close _all
    quietly log using "`preview_log'", text replace name(mwpreview)
    capture noisily msm_weight, treat_n_cov(age sex) preview
    local preview_rc = _rc
    capture log close mwpreview

    assert `preview_rc' == 0

    capture confirm variable _msm_weight
    assert _rc != 0
    capture confirm variable _msm_tw_weight
    assert _rc != 0

    local weighted : char _dta[_msm_weighted]
    local weight_var : char _dta[_msm_weight_var]
    assert "`weighted'" == ""
    assert "`weight_var'" == ""

    foreach pat in "treatment denom" "treatment numer" biomarker ///
        comorbidity age sex {
        quietly _file_contains_ci using "`preview_log'", pattern("`pat'")
        assert r(found) == 1
    }
}
if _rc == 0 {
    display as result "  PASS WERG2: preview shows resolved models without creating weights"
    local ++pass_count
}
else {
    display as error "  FAIL WERG2: preview mode behavior (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' WERG2"
}

* --- WERG3: truncate(#) shorthand matches symmetric truncate(# 100-#) ---
local ++test_count
capture noisily {
    tempfile trunc_ref

    _mw_prepare_example
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) truncate(1 99) nolog

    local pair_truncated = r(n_truncated)
    local pair_ess = r(ess)

    keep id period _msm_weight
    rename _msm_weight pair_weight
    save `trunc_ref'

    _mw_prepare_example
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) truncate(1) nolog

    assert r(n_truncated) == `pair_truncated'
    assert reldif(r(ess), `pair_ess') < 1e-12

    merge 1:1 id period using `trunc_ref', nogenerate
    assert reldif(_msm_weight, pair_weight) < 1e-12
}
if _rc == 0 {
    display as result "  PASS WERG3: truncate(#) shorthand matches truncate(# 100-#)"
    local ++pass_count
}
else {
    display as error "  FAIL WERG3: truncate(#) shorthand (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' WERG3"
}

* --- WERG4: r(preview) and r(treat_d_cov_source) report mode and resolution ---
local ++test_count
capture noisily {
    * Preview mode with denominator derived from msm_prepare covariates
    _mw_prepare_example
    capture log close _all
    tempfile werg4_stub
    quietly log using "`werg4_stub'.log", text replace name(werg4)
    msm_weight, treat_n_cov(age sex) preview
    local prev_preview "`r(preview)'"
    local prev_source "`r(treat_d_cov_source)'"
    capture log close werg4

    assert "`prev_preview'" == "1"
    assert "`prev_source'" == "prepared"

    * Real run with an explicit denominator specification
    _mw_prepare_example
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) nolog
    assert "`r(preview)'" == "0"
    assert "`r(treat_d_cov_source)'" == "explicit"
}
if _rc == 0 {
    display as result "  PASS WERG4: r(preview)/r(treat_d_cov_source) reflect mode and source"
    local ++pass_count
}
else {
    display as error "  FAIL WERG4: preview/source return surface (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' WERG4"
}

display as text ""
display as text "{hline 72}"
display as text "Tests run: " as result `test_count'
display as text "Passed:    " as result `pass_count'
display as text "Failed:    " as result `fail_count'
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    display as text "{hline 72}"
    exit 459
}
display as result "All msm_weight ergonomics tests passed"
display as text "{hline 72}"
