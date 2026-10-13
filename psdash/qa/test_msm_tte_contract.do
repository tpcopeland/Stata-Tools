* test_msm_tte_contract.do
* RB-07 msm/tte longitudinal contract validation for psdash.
*
* The pre-RB-07 version FABRICATED msm and tte dataset characteristics and
* asserted psdash ACCEPTED them and dispatched longitudinal diagnostics. Per the
* audit (C1/C2) that is exactly the failure mode: psdash trusted labels the
* producer's own guard rejects. psdash now calls the producer guard
* (_msm_check_weighted / _tte_get_weight_state) via _psdash_verify_producer and
* fails closed when the contract is unverified, stale, or the producer package is
* not installed. This suite asserts that fail-closed contract.
*
*   - Fabricated msm/tte metadata (no real msm_weight / tte_weight run) is
*     REJECTED, whether or not the producer is installed.
*   - psdash never mutates the caller's varabbrev setting on any path.
*
* Real end-to-end positive controls for every available producer are in
* test_real_producer_integrations.do. This file isolates the negative contract
* cases and explicit-argument escape hatch.
*
* Fail-on-old: against shipped psdash 1.4.1 the fabricated contracts below were
* ACCEPTED (source=msm/tte, r0). Every reject assertion here fails on old.
*
* Usage: cd psdash/qa && stata-mp -b do test_msm_tte_contract.do

clear all
version 16.0
set more off

capture log close _all
log using "test_msm_tte_contract.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

local test_count = 0
global PSDASH_MT_PASS_COUNT = 0
global PSDASH_MT_FAIL_COUNT = 0
global PSDASH_MT_FAILED_TESTS ""

capture program drop _mtct_result
program define _mtct_result
    args test_id rc
    if `rc' == 0 {
        display as result "PASS: `test_id'"
        global PSDASH_MT_PASS_COUNT = $PSDASH_MT_PASS_COUNT + 1
    }
    else {
        display as error "FAIL: `test_id' (rc=`rc')"
        global PSDASH_MT_FAIL_COUNT = $PSDASH_MT_FAIL_COUNT + 1
        global PSDASH_MT_FAILED_TESTS "$PSDASH_MT_FAILED_TESTS `test_id'"
    }
end

capture program drop _mtct_longitudinal_data
program define _mtct_longitudinal_data
    clear
    set seed 20260613
    set obs 240
    gen int pid = ceil(_n / 4)
    bysort pid: gen byte period = _n
    bysort pid: gen double base_x = rnormal() if _n == 1
    bysort pid: replace base_x = base_x[1]
    gen double tv_x = rnormal() + 0.15*period + 0.2*base_x
    gen double ps = invlogit(-0.5 + 0.25*period + 0.35*tv_x)
    gen byte a = runiform() < ps
    bysort period: replace a = 0 if _n <= 3
    bysort period: replace a = 1 if _n > _N - 3
    gen double w = cond(a == 1, 1 / ps, 1 / (1 - ps))
    gen double tw = w
    gen double y = 1 + a + 0.2*tv_x + 0.1*base_x + rnormal()
end

capture program drop _fake_msm_contract
program define _fake_msm_contract
    char _dta[_msm_weighted] "1"
    char _dta[_msm_treatment] "a"
    char _dta[_msm_ps_var] "ps"
    char _dta[_msm_tw_var] "tw"
    char _dta[_msm_weight_var] "w"
    char _dta[_msm_ps_covars] "tv_x"
    char _dta[_msm_id] "pid"
    char _dta[_msm_period] "period"
    char _dta[_msm_estimand] "ate"
    char _dta[_msm_contract_version] "1.0"
end

capture program drop _fake_tte_contract
program define _fake_tte_contract
    char _dta[_tte_weighted] "1"
    char _dta[_tte_treatment] "a"
    char _dta[_tte_pscore_var] "ps"
    char _dta[_tte_weight_var] "w"
    char _dta[_tte_covariates] "tv_x"
    char _dta[_tte_id] "pid"
    char _dta[_tte_period] "period"
    char _dta[_tte_estimand] "PP"
end

* --- TEST 1: fabricated msm contract is rejected (fail closed) ---
local ++test_count
capture noisily {
    _mtct_longitudinal_data
    _fake_msm_contract
    local vabbrev_before "`c(varabbrev)'"
    capture noisily psdash combined
    assert _rc != 0
    assert "`c(varabbrev)'" == "`vabbrev_before'"
    * pooled subcommands must also refuse the unverified contract
    foreach subcmd in overlap balance weights support {
        capture noisily psdash `subcmd'
        assert _rc != 0
        assert "`c(varabbrev)'" == "`vabbrev_before'"
    }
}
_mtct_result fabricated_msm_contract_rejected `=_rc'

* --- TEST 2: fabricated tte contract is rejected (fail closed) ---
local ++test_count
capture noisily {
    _mtct_longitudinal_data
    _fake_tte_contract
    local vabbrev_before "`c(varabbrev)'"
    capture noisily psdash combined
    assert _rc != 0
    assert "`c(varabbrev)'" == "`vabbrev_before'"
    foreach subcmd in overlap balance weights support {
        capture noisily psdash `subcmd'
        assert _rc != 0
    }
}
_mtct_result fabricated_tte_contract_rejected `=_rc'

* --- TEST 3: explicit args still bypass the contract entirely ---
* A user who supplies treatment + PS explicitly is not relying on producer
* metadata, so no producer guard is involved and the manual path works.
local ++test_count
capture noisily {
    _mtct_longitudinal_data
    _fake_msm_contract
    psdash overlap a ps, nograph
    assert "`r(source)'" == "manual"
    assert "`r(treatment)'" == "a"
}
_mtct_result explicit_args_bypass_contract `=_rc'

* --- TESTS 4-9: real msm producer, risk set and diagnosed weight ---
* psdash 1.7.5 diagnosed the treatment-only, untruncated weight
* (_msm_tw_weight) and ignored msm's risk-set indicator, so legitimate rows
* after the outcome were "incomplete input rows" and forced FAIL. psdash 1.8.0
* defaults to the analysis weight msm_fit uses (_msm_weight), restricts to the
* risk set (_msm_risk_var under contract 1.1, _msm_decision_risk under 1.0),
* and says which weight it diagnosed.
local repo_dir = substr("`pkg_dir'", 1, strlen("`pkg_dir'") - strlen("/psdash"))
local msm_ok = fileexists("`repo_dir'/msm/msm.pkg") & ///
    fileexists("`repo_dir'/msm/msm_example.dta")
capture program drop _mtct_msm_post_event
program define _mtct_msm_post_event
    args repo_dir
    use "`repo_dir'/msm/msm_example.dta", clear
    * one legitimate post-event row for every subject whose last row has the event
    bysort id (period): generate byte _ev = outcome[_N] == 1 & _n == _N
    quietly count if _ev
    assert r(N) > 0
    expand 2 if _ev, generate(_dup)
    replace period = period + 1 if _dup
    replace outcome = 0 if _dup
    drop _ev _dup
    sort id period
    quietly msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)
    quietly msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
        treat_n_cov(age sex) censor_d_cov(biomarker comorbidity age sex) ///
        censor_n_cov(age sex) truncate(1 99) nolog
end

* The msm install/uninstall below must only ever touch the QA sandbox that
* _psdash_bootstrap.do set up (PLUS under a tempfile root), never a user's
* real ado tree. Refuse, as a counted failure, when PLUS is not that sandbox.
local plus_now = subinstr("`c(sysdir_plus)'", "\", "/", .)
local plus_box = subinstr("`_qa_plus'", "\", "/", .)
local plus_sandboxed = ("`plus_box'" != "" & strpos("`plus_now'", "`plus_box'") == 1)
local msm_installed = 0
if `msm_ok' & `plus_sandboxed' {
    capture ado uninstall msm
    capture quietly net install msm, from("`repo_dir'/msm") replace
    local msm_installed = (_rc == 0)
}
* A missing fixture, a failed install, or an unsandboxed PLUS is a failure,
* not a silent skip: tests 4-9 are the msm risk-set acceptance tests.
local ++test_count
capture noisily {
    if !`plus_sandboxed' display as error "PLUS (`plus_now') is not the QA sandbox; msm tests refused"
    if !`msm_ok' display as error "msm producer fixture missing at `repo_dir'/msm"
    assert `msm_installed'
}
_mtct_result msm_fixture_available_sandboxed `=_rc'

if `msm_installed' {
    * TEST 4: real msm post-event data (contract 1.0 from msm 1.x, 1.1 from
    * msm 2.x) -> PASS on the risk set, analysis weight
    local ++test_count
    capture noisily {
        _mtct_msm_post_event "`repo_dir'"
        assert inlist("`: char _dta[_msm_contract_version]'", "1.0", "1.1")
        quietly count if _msm_decision_risk
        local n_risk = r(N)
        quietly count if !_msm_decision_risk
        local n_out = r(N)
        assert `n_out' > 0
        quietly summarize _msm_weight if _msm_decision_risk
        local wmax = r(max)
        local wmean = r(mean)
        psdash combined
        assert "`r(verdict)'" == "PASS"
        assert r(N) == `n_risk'
        assert r(n_outside_risk) == `n_out'
        assert r(n_excluded) == 0
        assert "`r(riskvar)'" == "_msm_decision_risk"
        assert "`r(wvar)'" == "_msm_weight"
        assert "`r(weight_role)'" == "analysis"
        assert reldif(r(max_wt), `wmax') < 1e-12
        assert reldif(r(mean_wt), `wmean') < 1e-12
        * psdash detect reports the same weight role and risk set
        psdash detect
        assert "`r(wvar)'" == "_msm_weight"
        assert "`r(weight_role)'" == "analysis"
        assert "`r(riskvar)'" == "_msm_decision_risk"
    }
    _mtct_result msm10_post_event_risk_set_pass `=_rc'

    * TEST 5: the treatment-only weight on request, labelled as such
    local ++test_count
    capture noisily {
        quietly summarize _msm_tw_weight if _msm_decision_risk
        local twmax = r(max)
        psdash combined, wvar(_msm_tw_weight)
        assert "`r(wvar)'" == "_msm_tw_weight"
        assert "`r(weight_role)'" == "treatment"
        assert reldif(r(max_wt), `twmax') < 1e-12
        assert r(N) == `n_risk'
    }
    _mtct_result msm_treatment_weight_on_request `=_rc'
}

* TEST 6: contract 1.1 names the risk set in _msm_risk_var. The chars are
* stamped by hand so the test does not depend on the msm version installed,
* and msm's own guard is replaced by a stub that accepts them (the real guard
* re-signs chars).
* (program define cannot sit inside a block, hence the split; the stub is
* dropped again after test 9.)
capture program drop _msm_check_weighted
program define _msm_check_weighted
    exit 0
end
if `msm_installed' {
    local ++test_count
    capture noisily {
        generate byte my_risk = _msm_decision_risk
        replace my_risk = 0 if period == 0 & id <= 5
        quietly count if my_risk
        local n_risk11 = r(N)
        char _dta[_msm_risk_var] "my_risk"
        char _dta[_msm_contract_version] "1.1"
        psdash combined
        assert "`r(contract_version)'" == "1.1"
        assert "`r(riskvar)'" == "my_risk"
        assert r(N) == `n_risk11'
        assert "`r(verdict)'" == "PASS"
    }
    _mtct_result msm11_risk_var_char_honoured `=_rc'

    * TEST 7: a named risk variable that does not exist fails closed, for
    * that reason (contract 1.0 here, so an unsupported-version 459 cannot
    * satisfy the test)
    local ++test_count
    capture noisily {
        char _dta[_msm_contract_version] "1.0"
        char _dta[_msm_risk_var] "no_such_risk"
        tempfile msg7
        log using "`msg7'", text replace name(mtct7)
        capture noisily psdash combined
        local rc7 = _rc
        log close mtct7
        assert `rc7' == 459
        assert strpos(fileread("`msg7'"), "names risk-set variable no_such_risk") > 0
        char _dta[_msm_contract_version] "1.1"
    }
    _mtct_result msm11_missing_risk_var_rejected `=_rc'

    * TEST 8: a non-binary risk indicator fails closed (contract 1.0 path, so
    * the check is on the implicit _msm_decision_risk)
    local ++test_count
    capture noisily {
        char _dta[_msm_risk_var] ""
        char _dta[_msm_contract_version] "1.0"
        local keep1 = _msm_decision_risk[1]
        replace _msm_decision_risk = 2 in 1
        capture noisily psdash combined
        assert _rc == 459
        replace _msm_decision_risk = `keep1' in 1
        char _dta[_msm_risk_var] "my_risk"
        char _dta[_msm_contract_version] "1.1"
    }
    _mtct_result msm_nonbinary_risk_var_rejected `=_rc'

    * TEST 9: an unknown future contract version still fails closed
    local ++test_count
    capture noisily {
        char _dta[_msm_contract_version] "1.2"
        tempfile msg9
        log using "`msg9'", text replace name(mtct9)
        capture noisily psdash combined
        local rc9 = _rc
        log close mtct9
        assert `rc9' == 459
        assert strpos(fileread("`msg9'"), "supports msm contract versions 1.0 to 1.1") > 0
        assert strpos(fileread("`msg9'"), "found 1.2") > 0
    }
    _mtct_result msm_future_contract_rejected `=_rc'
    capture ado uninstall msm
}
capture program drop _msm_check_weighted

display as text _n "=== MSM/TTE contract summary: " ///
    as result $PSDASH_MT_PASS_COUNT as text " passed, " ///
    as error $PSDASH_MT_FAIL_COUNT as text " failed ==="

local mt_fail = $PSDASH_MT_FAIL_COUNT
display "RESULT: test_msm_tte_contract tests=`test_count' pass=$PSDASH_MT_PASS_COUNT fail=$PSDASH_MT_FAIL_COUNT"
if `mt_fail' > 0 {
    display as error "Failed tests: $PSDASH_MT_FAILED_TESTS"
}

_psdash_qa_cleanup
global PSDASH_MT_PASS_COUNT
global PSDASH_MT_FAIL_COUNT
global PSDASH_MT_FAILED_TESTS
capture log close _all
if `mt_fail' > 0 {
    exit 9
}
