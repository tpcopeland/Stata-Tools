clear all
version 16.0
set varabbrev off

* test_iivw_diagnose.do - focused QA for iivw_diagnose
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_diagnose.do

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_diagnose.do must be run from iivw/qa"
    exit 198
}
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
ado dir
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace
discard

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _iivw_diag_post
program define _iivw_diag_post, eclass
    version 16.0
    args estname b se
    tempname bmat vmat
    matrix `bmat' = (`b')
    matrix colnames `bmat' = x
    matrix `vmat' = (`se'^2)
    matrix rownames `vmat' = x
    matrix colnames `vmat' = x
    ereturn post `bmat' `vmat', obs(100)
    ereturn local cmd "regress"
    estimates store `estname'
end

capture program drop _iivw_diag_known
program define _iivw_diag_known
    version 16.0
    estimates clear
    _iivw_diag_post M_unw 0.42 0.08
    _iivw_diag_post M_wgt 0.31 0.09
    _iivw_diag_post M_adj 0.10 0.10
end

**# T1: known stored estimates produce correct gaps and shares

local ++test_count
capture noisily {
    _iivw_diag_known
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj) ///
        exogeneity(exogenous)
    assert reldif(r(b_unweighted), 0.42) < 1e-12
    assert reldif(r(b_weighted), 0.31) < 1e-12
    assert reldif(r(b_adjusted), 0.10) < 1e-12
    assert reldif(r(sampling_gap), 0.11) < 1e-12
    assert reldif(r(artifact_gap), 0.21) < 1e-12
    assert reldif(r(total_gap), 0.32) < 1e-12
    assert reldif(r(sampling_share), 0.34375) < 1e-12
    assert reldif(r(artifact_share), 0.65625) < 1e-12
    assert "`r(conclusion)'" == "point_decomposition"
    matrix E = r(estimates)
    assert rowsof(E) == 3
    assert colsof(E) == 4
}
if _rc == 0 {
    display as result "  PASS: T1 - known gaps and shares"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - known gaps and shares (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

**# T2: true() computes known biases

local ++test_count
capture noisily {
    _iivw_diag_known
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj) ///
        true(0.10) exogeneity(unknown)
    assert reldif(r(true), 0.10) < 1e-12
    assert reldif(r(bias_unweighted), 0.32) < 1e-12
    assert reldif(r(bias_weighted), 0.21) < 1e-12
    assert reldif(r(bias_adjusted), 0.00) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: T2 - true() bias returns"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - true() bias returns (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

**# T3: missing coefficient errors clearly

local ++test_count
capture noisily {
    _iivw_diag_known
    capture noisily iivw_diagnose z, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: T3 - missing coefficient rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - missing coefficient rejected (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

**# T4: missing stored estimate name errors clearly

local ++test_count
capture noisily {
    _iivw_diag_known
    capture noisily iivw_diagnose x, unweighted(NO_SUCH_EST) weighted(M_wgt) ///
        adjusted(M_adj)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: T4 - missing stored estimate rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - missing stored estimate rejected (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

**# T5: tiny total gap suppresses share calculation

local ++test_count
capture noisily {
    estimates clear
    _iivw_diag_post M_unw 0.100000001 0.01
    _iivw_diag_post M_wgt 0.1000000005 0.01
    _iivw_diag_post M_adj 0.100000000 0.01
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj)
    assert missing(r(sampling_share))
    assert missing(r(artifact_share))
    assert "`r(conclusion)'" == "unstable"
}
if _rc == 0 {
    display as result "  PASS: T5 - tiny total gap suppresses shares"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - tiny total gap suppresses shares (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}

**# T6: sign-inconsistent shares return without crashing

local ++test_count
capture noisily {
    estimates clear
    _iivw_diag_post M_unw 0.10 0.01
    _iivw_diag_post M_wgt 0.20 0.01
    _iivw_diag_post M_adj 0.00 0.01
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj)
    assert r(sampling_share) < 0
    assert r(artifact_share) > 1
    assert "`r(conclusion)'" == "sign_inconsistent"
}
if _rc == 0 {
    display as result "  PASS: T6 - sign-inconsistent shares handled"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - sign-inconsistent shares handled (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}

**# T7: exogeneity(endogenous) returns bounds and conclusion

local ++test_count
capture noisily {
    _iivw_diag_known
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj) ///
        exogeneity(endogenous)
    assert reldif(r(bounds_lower), 0.10) < 1e-12
    assert reldif(r(bounds_upper), 0.31) < 1e-12
    assert "`r(conclusion)'" == "bounds"
}
if _rc == 0 {
    display as result "  PASS: T7 - endogenous bounds"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - endogenous bounds (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T7"
}

**# T8: active estimates are preserved after command

local ++test_count
capture noisily {
    _iivw_diag_known
    clear
    set obs 40
    gen double z = _n
    gen double y = 1 + 2 * z
    regress y z
    local active_b = _b[z]
    local active_cmd "`e(cmd)'"
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj)
    assert "`e(cmd)'" == "`active_cmd'"
    assert reldif(_b[z], `active_b') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: T8 - active estimates preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 - active estimates preserved (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T8"
}

**# T9: works with estimates stored after raw glm

local ++test_count
capture noisily {
    estimates clear
    clear
    set obs 120
    gen long id = ceil(_n / 4)
    bysort id: gen double t = _n
    gen double w = cond(mod(id, 2), 1.4, 0.8)
    gen double visits = t
    gen double y = 2 + 0.50 * t + 0.15 * mod(id, 3) + 0.30 * visits
    glm y t, family(gaussian) link(identity) vce(cluster id)
    estimates store G_unw
    glm y t [pw=w], family(gaussian) link(identity) vce(cluster id)
    estimates store G_wgt
    glm y t visits [pw=w], family(gaussian) link(identity) vce(cluster id)
    estimates store G_adj
    iivw_diagnose t, unweighted(G_unw) weighted(G_wgt) adjusted(G_adj)
    assert r(b_unweighted) != .
    assert r(b_weighted) != .
    assert r(b_adjusted) != .
    assert "`r(coefficient)'" == "t"
}
if _rc == 0 {
    display as result "  PASS: T9 - raw glm stored estimates"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 - raw glm stored estimates (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T9"
}

**# T10: estimand(contrast) suppresses share returns

local ++test_count
capture noisily {
    _iivw_diag_known
    iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) adjusted(M_adj) ///
        estimand(contrast)
    assert missing(r(sampling_share))
    assert missing(r(artifact_share))
    assert "`r(conclusion)'" == "movement_only"
}
if _rc == 0 {
    display as result "  PASS: T10 - contrast suppresses shares"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 - contrast suppresses shares (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T10"
}

**# T11: invalid option values are rejected

local ++test_count
capture noisily {
    _iivw_diag_known
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) estimand(bad)
    assert _rc == 198
    capture noisily iivw_diagnose x, unweighted(M_unw) weighted(M_wgt) ///
        adjusted(M_adj) exogeneity(bad)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T11 - invalid options rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: T11 - invalid options rejected (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T11"
}

**# T12: help-file example pattern runs with shipped Stata data

local ++test_count
capture noisily {
    estimates clear
    sysuse auto, clear
    gen double visit_w = cond(foreign, 1.30, 0.85)
    regress price mpg
    estimates store M_unweighted
    regress price mpg [pw=visit_w]
    estimates store M_weighted
    regress price mpg weight [pw=visit_w]
    estimates store M_adjusted
    iivw_diagnose mpg, unweighted(M_unweighted) weighted(M_weighted) ///
        adjusted(M_adjusted) exogeneity(exogenous)
    assert "`r(coefficient)'" == "mpg"
    assert "`r(estimand)'" == "marginal"
    iivw_diagnose mpg, unweighted(M_unweighted) we(M_weighted) ///
        ad(M_adjusted) tr(0) ex(unknown)
    assert r(true) == 0
}
if _rc == 0 {
    display as result "  PASS: T12 - help-file example pattern and abbreviations"
    local ++pass_count
}
else {
    display as error "  FAIL: T12 - help-file example pattern and abbreviations (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T12"
}

**# T13: accepts estimates stored after iivw_fit, unweighted

local ++test_count
capture noisily {
    estimates clear
    clear
    set obs 120
    gen long id = ceil(_n / 4)
    bysort id: gen double t = _n
    gen double x = sin(id / 5)
    gen double z = cos(id / 7)
    gen double y = 1 + 0.20 * t + 0.40 * x + 0.10 * z

    iivw_fit y x z, unweighted id(id) time(t) timespec(linear) nolog
    assert "`e(iivw_cmd)'" == "iivw_fit"
    assert "`e(iivw_weighttype)'" == "unweighted"
    local fit_b = _b[x]
    estimates store F_unweighted

    glm y x z t, family(gaussian) link(identity) vce(cluster id)
    estimates store F_weighted
    glm y x z t, family(gaussian) link(identity) vce(cluster id)
    estimates store F_adjusted

    iivw_diagnose x, unweighted(F_unweighted) weighted(F_weighted) ///
        adjusted(F_adjusted)
    assert reldif(r(b_unweighted), `fit_b') < 1e-10
    assert "`r(unweighted)'" == "F_unweighted"
}
if _rc == 0 {
    display as result "  PASS: T13 - iivw_fit unweighted stored estimates"
    local ++pass_count
}
else {
    display as error "  FAIL: T13 - iivw_fit unweighted stored estimates (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T13"
}

capture adopath - "`pkg_dir'"
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_iivw_diagnose tests=`test_count' pass=`pass_count' fail=`fail_count'"
    display as error "Failed tests:`failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_iivw_diagnose tests=`test_count' pass=`pass_count' fail=`fail_count'"
