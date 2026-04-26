* test_msm_fit_guidance.do
* Focused QA for Workstream E model-aware next-step messaging in msm_fit.

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

capture program drop _fit_guidance_setup
program define _fit_guidance_setup
    version 16.0

    local qa_dir "`c(pwd)'"
    local pkg_dir "`qa_dir'/.."

    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) truncate(1 99) nolog
end

capture program drop _capture_fit_output
program define _capture_fit_output, rclass
    version 16.0
    syntax , MODEL(string)

    tempfile fit_stub
    local fit_log "`fit_stub'.log"
    capture log close _all
    quietly log using "`fit_log'", text replace name(msmfitlog)
    capture noisily msm_fit, model(`model') outcome_cov(age sex) ///
        period_spec(linear) nolog
    local fit_rc = _rc
    capture log close msmfitlog

    return scalar rc = `fit_rc'
    return local logfile "`fit_log'"
end

capture program drop _first_matching_line_ci
program define _first_matching_line_ci, rclass
    version 16.0
    syntax using/, PATtern(string)

    tempname fh
    local found 0
    local match ""

    file open `fh' using "`using'", read text
    file read `fh' line
    while r(eof) == 0 {
        if `found' == 0 & strpos(lower(`"`macval(line)'"'), lower(`"`pattern'"')) > 0 {
            local found 1
            local match `"`macval(line)'"'
        }
        file read `fh' line
    }
    file close `fh'

    return scalar found = `found'
    return local line `"`match'"'
end

display as text ""
display as text "{hline 72}"
display as result "msm_fit guidance QA"
display as text "{hline 72}"

* --- FGUIDE1: logistic fits still point users to msm_predict ---
local ++test_count
capture noisily {
    _fit_guidance_setup

    _capture_fit_output, model(logistic)
    local fit_rc = r(rc)
    local fit_log `"`r(logfile)'"'
    local model : char _dta[_msm_model]

    assert `fit_rc' == 0
    assert "`model'" == "logistic"

    quietly _first_matching_line_ci using "`fit_log'", pattern("next step:")
    assert r(found) == 1
    local nextline `"`r(line)'"'
    assert strpos(lower(`"`nextline'"'), "msm_predict") > 0
}
if _rc == 0 {
    display as result "  PASS FGUIDE1: logistic next step remains msm_predict"
    local ++pass_count
}
else {
    display as error "  FAIL FGUIDE1: logistic next-step guidance (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' FGUIDE1"
}

* --- FGUIDE2: linear fits do not suggest msm_predict as the next step ---
local ++test_count
capture noisily {
    _fit_guidance_setup

    _capture_fit_output, model(linear)
    local fit_rc = r(rc)
    local fit_log `"`r(logfile)'"'
    local model : char _dta[_msm_model]

    assert `fit_rc' == 0
    assert "`model'" == "linear"

    quietly _first_matching_line_ci using "`fit_log'", pattern("next step:")
    assert r(found) == 1
    local nextline `"`r(line)'"'
    local nextline_lc = lower(`"`nextline'"')

    assert strpos(`"`nextline_lc'"', "next step: msm_predict") == 0
    assert strpos(`"`nextline_lc'"', "next step: {cmd:msm_predict") == 0
    assert strpos(`"`nextline_lc'"', "msm_table") > 0 | ///
        strpos(`"`nextline_lc'"', "msm_report") > 0 | ///
        strpos(`"`nextline_lc'"', "msm_sensitivity") > 0
}
if _rc == 0 {
    display as result "  PASS FGUIDE2: linear next-step guidance avoids msm_predict"
    local ++pass_count
}
else {
    display as error "  FAIL FGUIDE2: linear next-step guidance (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' FGUIDE2"
}

* --- FGUIDE3: Cox fits do not suggest msm_predict as the next step ---
local ++test_count
capture noisily {
    _fit_guidance_setup

    _capture_fit_output, model(cox)
    local fit_rc = r(rc)
    local fit_log `"`r(logfile)'"'
    local model : char _dta[_msm_model]

    assert `fit_rc' == 0
    assert "`model'" == "cox"

    quietly _first_matching_line_ci using "`fit_log'", pattern("next step:")
    assert r(found) == 1
    local nextline `"`r(line)'"'
    local nextline_lc = lower(`"`nextline'"')

    assert strpos(`"`nextline_lc'"', "next step: msm_predict") == 0
    assert strpos(`"`nextline_lc'"', "next step: {cmd:msm_predict") == 0
    assert strpos(`"`nextline_lc'"', "msm_table") > 0 | ///
        strpos(`"`nextline_lc'"', "msm_report") > 0 | ///
        strpos(`"`nextline_lc'"', "msm_sensitivity") > 0
}
if _rc == 0 {
    display as result "  PASS FGUIDE3: Cox next-step guidance avoids msm_predict"
    local ++pass_count
}
else {
    display as error "  FAIL FGUIDE3: Cox next-step guidance (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' FGUIDE3"
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
display as result "All msm_fit guidance tests passed"
display as text "{hline 72}"
