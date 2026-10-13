* test_msm_companion_smoke.do
* msm 2.0.0 sends tables, diagnostics, figures and E-values to companion
* packages. This suite runs each documented route on real msm output and checks
* the numbers, not only the return code. Needs the sibling package directories
* ../../tabtools, ../../eplot, ../../psdash, ../../qba and ../../swimlane
* (the Stata-Tools layout); a missing sibling is a hard failure.
*
*   CS1  collect: msm_fit -> regtab: the OR cell equals exp(_b[treatment])
*   CS2  msm_predict r(rd) -> effecttab, from(): r(table) equals r(rd)
*   CS3  msm_predict frame() -> eplot, frame() (RD rows) and its export frame
*   CS4  the documented twoway risk-curve recipe draws from the frame
*   CS5  psdash combined after msm on data with post-event rows: contract 1.1,
*        analysis weight by default, verdict PASS, N = decision-risk rows
*   CS6  psdash balance/weights on the risk set with denominator covariates
*   CS7  qba_confound, from_model ... evalue measure(HR) on the msm fit
*   CS8  swimlane draws treatment histories from the person-period data

version 16.0
clear all
set more off
set varabbrev off

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture log close _all
log using "test_msm_companion_smoke.log", replace text nomsg

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

* Companion installs into the same isolated PLUS as msm. They are named as
* literal repo_dir paths so the QA sandbox copies them.
local repo_dir "`pkg_dir'/.."
foreach cdir in "`repo_dir'/tabtools" "`repo_dir'/eplot" "`repo_dir'/psdash" ///
        "`repo_dir'/qba" "`repo_dir'/swimlane" {
    local c = substr("`cdir'", strrpos("`cdir'", "/") + 1, .)
    capture confirm file "`cdir'/`c'.pkg"
    if _rc {
        display as error "companion package directory ../../`c' not found; run from the Stata-Tools layout"
        exit 601
    }
    capture ado uninstall `c'
    quietly net install `c', from("`cdir'") replace
}

capture program drop _cs_pipeline
program define _cs_pipeline
    args pkg_dir
    use "`pkg_dir'/msm_example.dta", clear
    quietly msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(biomarker comorbidity) baseline_covariates(age sex)
    quietly msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) censor_d_cov(biomarker comorbidity age sex) ///
        censor_n_cov(age sex) truncate(1 99) nolog
end

tempfile xl
local xlsx "`xl'.xlsx"

**# CS1: regtab tabulates the msm_fit coefficients
local ++test_count
capture noisily {
    _cs_pipeline "`pkg_dir'"
    collect clear
    collect: msm_fit, model(logistic) outcome_cov(age sex) period_spec(quadratic) nolog
    local or = exp(_b[treatment])
    local lo = exp(_b[treatment] - invnormal(0.975) * _se[treatment])
    regtab, xlsx("`xlsx'") sheet(fit) coef(OR)
    assert r(N_models) == 1
    preserve
    import excel using "`xlsx'", sheet(fit) clear allstring
    * the treatment row shows the OR and lower limit at the table's 2 dp
    local want_or : display %4.2f `or'
    local want_lo : display %4.2f `lo'
    unab cells : _all
    gen strL row = ""
    foreach v of local cells {
        replace row = row + " | " + `v'
    }
    gen byte hit = strpos(row, "`=strtrim("`want_or'")'") > 0 & ///
        strpos(row, "`=strtrim("`want_lo'")'") > 0
    quietly count if hit
    assert r(N) >= 1
    restore
    collect clear
}
if _rc == 0 {
    display as result "PASS CS1: regtab reports the msm_fit odds ratio"
    local ++pass_count
}
else {
    display as error "FAIL CS1: regtab route (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' CS1"
}

**# CS2: effecttab reads r(rd)
local ++test_count
capture noisily {
    _cs_pipeline "`pkg_dir'"
    quietly msm_fit, model(logistic) outcome_cov(age sex) period_spec(quadratic) nolog
    quietly msm_predict, times(3 6 9) difference samples(100) seed(20261013)
    tempname RD T
    matrix `RD' = r(rd)
    effecttab, from(`RD') effect("Risk difference") xlsx("`xlsx'") sheet(rd)
    * r(table) holds the estimate and the p-value (missing for MC intervals)
    matrix `T' = r(table)
    assert rowsof(`T') == 3
    forvalues k = 1/3 {
        assert `T'[`k', 1] == `RD'[`k', 1]
        assert missing(`T'[`k', 2])
    }
    * the exported interval is r(rd)'s, at the table's 2 dp
    preserve
    import excel using "`xlsx'", sheet(rd) clear allstring
    unab cells : _all
    gen strL row = ""
    foreach v of local cells {
        replace row = row + " | " + `v'
    }
    forvalues k = 1/3 {
        local lo : display %4.2f `RD'[`k', 2]
        local hi : display %4.2f `RD'[`k', 3]
        quietly count if strpos(row, "(`=strtrim("`lo'")', `=strtrim("`hi'")')") > 0
        assert r(N) == 1
    }
    restore
}
if _rc == 0 {
    display as result "PASS CS2: effecttab, from(matrix of r(rd)) carries the risk differences"
    local ++pass_count
}
else {
    display as error "FAIL CS2: effecttab route (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' CS2"
}

**# CS3: eplot draws the RD rows of the predict frame
local ++test_count
capture noisily {
    _cs_pipeline "`pkg_dir'"
    quietly msm_fit, model(logistic) outcome_cov(age sex) period_spec(quadratic) nolog
    capture frame drop csp
    quietly msm_predict, times(1 3 5 7 9) difference samples(100) seed(20261013) frame(csp)
    tempname P
    matrix `P' = r(predictions)
    capture frame drop csx
    eplot if strategy == "rd", frame(csp) values export(csx)
    assert r(k) == 5
    frame csx {
        assert _N == 5
        forvalues k = 1/5 {
            assert reldif(estimate[`k'], `P'[`k', 8]) < 1e-12
            assert reldif(ll[`k'], `P'[`k', 9]) < 1e-12
            assert reldif(ul[`k'], `P'[`k', 10]) < 1e-12
        }
    }
    capture graph drop _all
    frame drop csx
}
if _rc == 0 {
    display as result "PASS CS3: eplot draws the predict frame's risk differences"
    local ++pass_count
}
else {
    display as error "FAIL CS3: eplot route (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' CS3"
}

**# CS4: the documented twoway risk-curve recipe
local ++test_count
capture noisily {
    frame csp {
        twoway (rarea ll ul horizon if strategy == "never", pstyle(p1) color(%25) lwidth(none)) ///
            (line estimate horizon if strategy == "never", pstyle(p1)) ///
            (rarea ll ul horizon if strategy == "always", pstyle(p2) color(%25) lwidth(none)) ///
            (line estimate horizon if strategy == "always", pstyle(p2)), ///
            legend(order(2 "Never treated" 4 "Always treated")) ///
            ytitle("Cumulative incidence") xtitle("Period") name(cscurve, replace)
        quietly count if strategy == "always"
        assert r(N) == 5
    }
    graph describe cscurve
    capture graph drop _all
    frame drop csp
}
if _rc == 0 {
    display as result "PASS CS4: twoway curve recipe runs on the predict frame"
    local ++pass_count
}
else {
    display as error "FAIL CS4: twoway recipe (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' CS4"
}

**# CS5: psdash combined restricts to the decision risk set (contract 1.1)
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    * legitimate post-event follow-up rows outside the risk set
    quietly {
        bysort id (period): gen byte _ev = sum(outcome)
        by id: gen byte _first = outcome == 1 & _ev == 1
        expand 3 if _first, generate(_dup)
        bysort id (period _dup): replace period = period[_n-1] + 1 if _dup
        drop _ev _first _dup
    }
    quietly msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(biomarker comorbidity) baseline_covariates(age sex)
    quietly msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) censor_d_cov(biomarker comorbidity age sex) ///
        censor_n_cov(age sex) truncate(1 99) nolog
    quietly count if _msm_decision_risk
    local nrisk = r(N)
    quietly count if !_msm_decision_risk
    local nout = r(N)
    assert `nout' > 0
    psdash combined
    assert "`r(verdict)'" == "PASS"
    assert r(N) == `nrisk'
    assert r(n_outside_risk) == `nout'
    assert "`r(riskvar)'" == "_msm_decision_risk"
    assert "`r(contract_version)'" == "1.1"
    assert "`r(wvar)'" == "_msm_weight"
    assert "`r(weight_role)'" == "analysis"
}
if _rc == 0 {
    display as result "PASS CS5: psdash combined after msm 2.0: PASS on the decision risk set"
    local ++pass_count
}
else {
    display as error "FAIL CS5: psdash combined contract 1.1 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' CS5"
}

**# CS6: psdash pooled weights and balance on the risk set
local ++test_count
capture noisily {
    _cs_pipeline "`pkg_dir'"
    * the weight summary equals a direct summary of the analysis weight
    quietly summarize _msm_weight if _msm_decision_risk
    local wmean = r(mean)
    local wmax = r(max)
    psdash weights treatment _msm_ps if _msm_decision_risk, wvar(_msm_weight)
    assert reldif(r(mean_wt), `wmean') < 1e-10
    assert reldif(r(max_wt), `wmax') < 1e-10
    * balance targets only: age and sex are stabilized-numerator covariates
    psdash balance treatment _msm_ps if _msm_decision_risk, ///
        covariates(biomarker comorbidity) wvar(_msm_weight) loveplot
    capture graph drop _all
}
if _rc == 0 {
    display as result "PASS CS6: psdash weights/balance on the msm risk set"
    local ++pass_count
}
else {
    display as error "FAIL CS6: psdash pooled routes (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' CS6"
}

**# CS7: qba_confound E-value on the msm fit
local ++test_count
capture noisily {
    _cs_pipeline "`pkg_dir'"
    quietly msm_fit, model(logistic) outcome_cov(age sex) period_spec(quadratic) nolog
    local hr = exp(_b[`e(msm_treatment)'])
    qba_confound, from_model coef(`e(msm_treatment)') evalue measure(HR)
    * rare outcome: the ratio enters VanderWeele-Ding directly (reciprocal if < 1)
    local rr = cond(`hr' < 1, 1 / `hr', `hr')
    assert reldif(r(evalue), `rr' + sqrt(`rr' * (`rr' - 1))) < 1e-8
    assert "`r(measure)'" == "HR"
}
if _rc == 0 {
    display as result "PASS CS7: qba_confound E-value on the msm fit"
    local ++pass_count
}
else {
    display as error "FAIL CS7: qba route (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' CS7"
}

**# CS8: swimlane draws treatment histories
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    keep if id <= 20
    gen double pstop = period + 1
    swimlane, id(id) start(period) stop(pstop) state(treatment) name(csswim, replace)
    graph describe csswim
    capture graph drop _all
}
if _rc == 0 {
    display as result "PASS CS8: swimlane draws the treatment histories"
    local ++pass_count
}
else {
    display as error "FAIL CS8: swimlane route (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' CS8"
}

capture erase "`xlsx'"

**# Summary
if `fail_count' > 0 display as error "Failed tests:`failed_tests'"
do "`qa_dir'/_record_qa_result.do" test_msm_companion_smoke ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: test_msm_companion_smoke tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1
