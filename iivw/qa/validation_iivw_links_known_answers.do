clear all
version 16.0
set varabbrev off

* validation_iivw_links_known_answers.do
*
* Exact known-answer checks for canonical outcome links not covered by the
* Gaussian identities in validation_iivw_known_answers.do:
*   KA1 Poisson-log with treatment, linear time, and quadratic time
*   KA2 Binomial-logit with exact arm-specific event proportions

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "validation_iivw_links_known_answers.do must be run from iivw/qa"
    exit 198
}

do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir "`r(pkg_dir)'"

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# KA1 - Poisson-log recovers an exact quadratic mean surface
*
* For every treatment-time cell the observed count equals its conditional mean:
*
*   E(Y | A,t) = 2^(1 + A + t + t^2)
*   log E(Y | A,t) = log(2) + log(2)A + log(2)t + log(2)t^2.
*
* All cells have equal replication, and identical scheduled visit times make
* the fitted visit-process coefficient exactly zero. Thus every IIW is exactly
* one and the Poisson GEE has the four coefficients log(2).
local ++test_count
capture noisily {
    clear
    set obs 72
    gen long id = ceil(_n / 3)
    bysort id: gen byte t = _n
    gen byte A = id > 12
    gen byte visit_group = A
    gen double y = 2^(1 + A + t + t^2)

    iivw_weight, endatlastvisit baseline(event) id(id) time(t) ///
        visit_cov(visit_group) nolog
    quietly count if abs(_iivw_weight - 1) > 1e-12
    assert r(N) == 0

    iivw_fit y A, family(poisson) link(log) timespec(quadratic) ///
        vce(fixed) nolog
    assert abs(_b[_cons] - ln(2)) < 1e-7
    assert abs(_b[A] - ln(2)) < 1e-7
    assert abs(_b[t] - ln(2)) < 1e-7
    assert abs(_b[_iivw_time_sq] - ln(2)) < 1e-7
    assert e(N) == 72
    assert "`e(iivw_model)'" == "gee"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: KA1 - exact Poisson-log quadratic surface"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' KA1"
    display as error "FAIL: KA1 - exact Poisson-log quadratic surface (error `=_rc')"
}

**# KA2 - Binomial-logit recovers exact arm logits
*
* Control risk = 5/20 = 0.25 and treated risk = 15/20 = 0.75, hence
*
*   intercept = logit(0.25) = -log(3)
*   treatment = logit(0.75) - logit(0.25) = log(9).
*
* An intercept-only propensity model has fitted treatment probability 0.5 in
* both arms, so the stabilized IPTW is exactly one for every subject.
local ++test_count
capture noisily {
    clear
    set obs 40
    gen long id = _n
    gen byte t = 0
    gen byte A = id > 20
    gen byte L = mod(id, 2)
    gen byte y = (id <= 5) | (id > 20 & id <= 35)

    iivw_weight, id(id) time(t) treat(A) treat_cov(L) wtype(iptw) nolog
    quietly count if abs(_iivw_weight - 1) > 1e-12
    assert r(N) == 0

    iivw_fit y A, family(binomial) link(logit) timespec(none) ///
        vce(fixed) nolog
    assert abs(_b[_cons] + ln(3)) < 1e-9
    assert abs(_b[A] - ln(9)) < 1e-9
    assert e(N) == 40
    assert "`e(iivw_model)'" == "gee"
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: KA2 - exact binomial-logit arm contrast"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' KA2"
    display as error "FAIL: KA2 - exact binomial-logit arm contrast (error `=_rc')"
}

**# Summary

local run_only = 0
iivw_qa_summary, name(validation_iivw_links_known_answers) ///
    tests(`test_count') pass(`pass_count') fail(`fail_count') ///
    runonly(`run_only') failedtests("`failed_tests'")

clear
