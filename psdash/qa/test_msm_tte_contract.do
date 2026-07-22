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

display as text _n "=== MSM/TTE contract summary: " ///
    as result $PSDASH_MT_PASS_COUNT as text " passed, " ///
    as error $PSDASH_MT_FAIL_COUNT as text " failed ==="

_psdash_qa_cleanup
capture log close _all

display "RESULT: test_msm_tte_contract tests=`test_count' pass=$PSDASH_MT_PASS_COUNT fail=$PSDASH_MT_FAIL_COUNT"
if $PSDASH_MT_FAIL_COUNT > 0 {
    display as error "Failed tests: $PSDASH_MT_FAILED_TESTS"
    exit 9
}

global PSDASH_MT_PASS_COUNT
global PSDASH_MT_FAIL_COUNT
global PSDASH_MT_FAILED_TESTS
