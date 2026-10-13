* test_msm_documentation_examples.do -- literal help and README workflows
* Runs the msm.sthlp examples and the README Quick Start and Worked Examples
* as printed (msm 2.0.0), including the companion-package calls. Needs the
* sibling package directories (tabtools, psdash, eplot, qba, swimlane).

clear all
version 16.0
set varabbrev off
local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"
* Companions are named as literal repo_dir paths so the QA sandbox copies them.
local repo_dir "`pkg_dir'/.."
foreach cdir in "`repo_dir'/tabtools" "`repo_dir'/psdash" "`repo_dir'/eplot" ///
        "`repo_dir'/qba" "`repo_dir'/swimlane" {
    local c = substr("`cdir'", strrpos("`cdir'", "/") + 1, .)
    capture confirm file "`cdir'/`c'.pkg"
    if _rc {
        display as error "companion package directory ../../`c' not found"
        exit 601
    }
    capture ado uninstall `c'
    quietly net install `c', from("`cdir'") replace
}

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Work in a scratch directory so net get and xlsx outputs stay out of qa/.
tempfile wanchor
local wdir "`wanchor'_docs"
capture mkdir "`wdir'"
local here "`c(pwd)'"
quietly cd "`wdir'"
* The help files print the public URL; the QA copy fetches from the package
* checkout instead so the example data match the code under test.
net get msm, from("`pkg_dir'") replace

**# D1: msm.sthlp prediction-ready workflow
local ++test_count
capture noisily {
    capture confirm file msm_example.dta
    use msm_example.dta, clear
    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        censor(censored) covariates(biomarker comorbidity) baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) treat_n_cov(age sex) ///
        censor_d_cov(biomarker comorbidity age sex) censor_n_cov(age sex) truncate(1 99) nolog
    msm_diagnose, threshold(0.1)
    msm_fit, model(logistic) outcome_cov(age sex) period_spec(quadratic) nolog
    msm_predict, times(3 5 7 9) difference samples(500) seed(12345) frame(pred, replace)
    msm, status
    assert r(fitted) == 1
    frame pred: assert _N == 12
}
if _rc == 0 {
    display as result "PASS D1: msm.sthlp prediction workflow"
    local ++pass_count
}
else {
    display as error "FAIL D1 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D1"
}

**# D2: msm.sthlp estimation-only Cox workflow
local ++test_count
capture noisily {
    use msm_example.dta, clear
    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        covariates(biomarker comorbidity) baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) treat_n_cov(age sex) nolog
    msm_fit, model(cox) outcome_cov(age sex) nolog
    stcox, hr
    assert "`e(cmd2)'" == "stcox"
}
if _rc == 0 {
    display as result "PASS D2: msm.sthlp Cox workflow"
    local ++pass_count
}
else {
    display as error "FAIL D2 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D2"
}

**# D3: README Quick Start
local ++test_count
capture noisily {
    use msm_example.dta, clear
    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        covariates(biomarker comorbidity) baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) truncate(1 99) nolog
    msm_diagnose
    msm_fit, model(logistic) outcome_cov(age sex) nolog
    msm_predict, times(1 3 5 7 9) difference samples(500) seed(12345)
    assert rowsof(r(rd)) == 5
}
if _rc == 0 {
    display as result "PASS D3: README Quick Start"
    local ++pass_count
}
else {
    display as error "FAIL D3 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D3"
}

**# D4: README Worked Examples 1-5 (one continuous session, as printed)
local ++test_count
capture noisily {
    use msm_example.dta, clear
    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        censor(censored) covariates(biomarker comorbidity) baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) treat_n_cov(age sex) ///
        censor_d_cov(biomarker comorbidity age sex) censor_n_cov(age sex) ///
        truncate(1 99) nolog
    msm_diagnose, threshold(0.1)
    msm_fit, model(logistic) outcome_cov(age sex) period_spec(quadratic) nolog
    msm_predict, times(1 3 5 7 9) difference samples(500) seed(12345) frame(pred, replace)
    matrix list r(rd)

    collect clear
    collect: msm_fit, model(logistic) outcome_cov(age sex) period_spec(quadratic) nolog
    regtab, xlsx("msm_results.xlsx") sheet("Outcome model") coef(OR)

    msm_predict, times(1 3 5 7 9) difference samples(500) seed(12345)
    matrix RD = r(rd)
    effecttab, from(RD) effect("Risk difference") xlsx("msm_results.xlsx") sheet("Risk differences")

    psdash combined
    psdash weights treatment _msm_ps if _msm_decision_risk, wvar(_msm_weight) detail graph
    psdash balance treatment _msm_ps if _msm_decision_risk, ///
        covariates(biomarker comorbidity) wvar(_msm_weight) loveplot

    msm_predict, times(1 3 5 7 9) difference samples(500) seed(12345) frame(pred, replace)
    eplot if strategy == "rd", frame(pred) values xline(0)

    frame pred: twoway ///
        (rarea ll ul horizon if strategy == "never", pstyle(p1) color(%25) lwidth(none)) ///
        (connected estimate horizon if strategy == "never", pstyle(p1)) ///
        (rarea ll ul horizon if strategy == "always", pstyle(p2) color(%25) lwidth(none)) ///
        (connected estimate horizon if strategy == "always", pstyle(p2)), ///
        legend(order(2 "Never treated" 4 "Always treated")) ///
        ytitle("Cumulative incidence") xtitle("Period")

    generate pstop = period + 1
    swimlane, id(id) start(period) stop(pstop) state(treatment)
    drop pstop

    msm_fit, model(logistic) outcome_cov(age sex) period_spec(quadratic) nolog
    qba_confound, from_model coef(treatment) evalue measure(HR)
    assert r(evalue) > 1
    confirm file "msm_results.xlsx"
    capture graph drop _all
}
if _rc == 0 {
    display as result "PASS D4: README Worked Examples 1-5"
    local ++pass_count
}
else {
    display as error "FAIL D4 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D4"
}

**# D5: README Worked Example 6 (Cox through regtab)
local ++test_count
capture noisily {
    use msm_example.dta, clear
    msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        covariates(biomarker comorbidity) baseline_covariates(age sex)
    msm_weight, treat_d_cov(biomarker comorbidity age sex) treat_n_cov(age sex) nolog
    collect clear
    collect: msm_fit, model(cox) outcome_cov(age sex) nolog
    regtab, coef(HR)
    assert r(N_models) == 1
}
if _rc == 0 {
    display as result "PASS D5: README Cox example"
    local ++pass_count
}
else {
    display as error "FAIL D5 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D5"
}

**# D6: msm_predict.sthlp "Tables and graphs" block
local ++test_count
capture noisily {
    use msm_example.dta, clear
    quietly msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
        covariates(biomarker comorbidity) baseline_covariates(age sex)
    quietly msm_weight, treat_d_cov(biomarker comorbidity age sex) treat_n_cov(age sex) truncate(1 99) nolog
    quietly msm_fit, model(logistic) outcome_cov(age sex) nolog
    msm_predict, times(1 3 5 7 9) difference samples(500) seed(12345) frame(pred, replace)
    matrix RD = r(rd)
    effecttab, from(RD) effect("Risk difference")
    eplot if strategy == "rd", frame(pred) values xline(0)
    msm_diagnose
    matrix S = r(support)
    puttab using diagnostics.xlsx, matrix(S) sheet(support)
    confirm file diagnostics.xlsx
    capture graph drop _all
}
if _rc == 0 {
    display as result "PASS D6: msm_predict and msm_diagnose help companion blocks"
    local ++pass_count
}
else {
    display as error "FAIL D6 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D6"
}

capture frame drop pred
foreach f in msm_example.dta msm_results.xlsx diagnostics.xlsx {
    capture erase "`f'"
}
quietly cd "`here'"
capture rmdir "`wdir'"

if `fail_count' > 0 display as error "Failed tests:`failed_tests'"
do "`qa_dir'/_record_qa_result.do" test_msm_documentation_examples ///
    `test_count' `pass_count' `fail_count' 0
display "RESULT: test_msm_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 exit 1
