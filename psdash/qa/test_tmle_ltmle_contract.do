* test_tmle_ltmle_contract.do
* RB-07 tmle/ltmle contract validation for psdash.
*
* The pre-RB-07 version FABRICATED tmle/ltmle estimation state (a fake eclass
* program setting e(cmd)="tmle"/"ltmle" plus dataset characteristics) and asserted
* psdash ACCEPTED it and dispatched diagnostics. Per the audit (C1/C2) that is the
* failure mode: psdash trusted a contract the producer's own guard would reject.
* psdash now calls the producer guard (_tmle_get_context / _ltmle_get_context) via
* _psdash_verify_producer and fails closed when the state is unverifiable or the
* producer package is not installed. tmle and ltmle are development-only producers
* (RB-15): a released psdash cannot install them, so it correctly refuses their
* metadata rather than presenting diagnostics for an unverifiable analysis.
*
* Fail-on-old: against shipped psdash 1.4.1 the fabricated contracts below were
* ACCEPTED (source=tmle/ltmle, r0). Every reject assertion here fails on old.
*
* Usage: cd psdash/qa && stata-mp -b do test_tmle_ltmle_contract.do

clear all
version 16.0
set more off

capture log close _all
log using "test_tmle_ltmle_contract.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

local test_count = 0
global PSDASH_TMLE_PASS_COUNT = 0
global PSDASH_TMLE_FAIL_COUNT = 0
global PSDASH_TMLE_FAILED_TESTS ""

capture program drop _tmlect_result
program define _tmlect_result
    args test_id rc
    if `rc' == 0 {
        display as result "PASS: `test_id'"
        global PSDASH_TMLE_PASS_COUNT = $PSDASH_TMLE_PASS_COUNT + 1
    }
    else {
        display as error "FAIL: `test_id' (rc=`rc')"
        global PSDASH_TMLE_FAIL_COUNT = $PSDASH_TMLE_FAIL_COUNT + 1
        global PSDASH_TMLE_FAILED_TESTS "$PSDASH_TMLE_FAILED_TESTS `test_id'"
    }
end

capture program drop _fake_tmle_contract
program define _fake_tmle_contract, eclass
    quietly regress y x1 x2
    ereturn local cmd "tmle"
    char _dta[_tmle_estimated] "1"
    char _dta[_tmle_method] "tmle"
    char _dta[_tmle_treatment] "treat"
    char _dta[_tmle_covariates] "x1 x2"
    char _dta[_tmle_ps_var] "_tmle_ps"
    char _dta[_tmle_estimand] "ATT"
end

capture program drop _fake_ltmle_contract
program define _fake_ltmle_contract, eclass
    quietly regress y x tv_x base_x
    ereturn local cmd "ltmle"
    char _dta[_ltmle_estimated] "1"
    char _dta[_ltmle_method] "ltmle"
    char _dta[_ltmle_treatment] "a"
    char _dta[_ltmle_id] "pid"
    char _dta[_ltmle_period] "period"
    char _dta[_ltmle_ps_var] "g_ps"
    char _dta[_ltmle_weight_var] "g_w"
    char _dta[_ltmle_estimand] "ATE"
end

capture program drop _tmlect_cross_sectional_data
program define _tmlect_cross_sectional_data
    clear
    set seed 20260518
    set obs 120
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen double _tmle_ps = invlogit(-0.35 + 0.7*x1 - 0.4*x2)
    gen byte treat = runiform() < _tmle_ps
    replace treat = 0 in 1/4
    replace treat = 1 in 117/120
    gen double y = 1 + 1.2*treat + 0.3*x1 - 0.2*x2 + rnormal()
end

capture program drop _tmlect_longitudinal_data
program define _tmlect_longitudinal_data
    clear
    set seed 20260518
    set obs 120
    gen int pid = ceil(_n / 3)
    bysort pid: gen byte period = _n
    bysort pid: gen double base_x = rnormal() if _n == 1
    bysort pid: replace base_x = base_x[1]
    gen double tv_x = rnormal() + 0.15*period + 0.2*base_x
    gen double g_ps = invlogit(-0.5 + 0.25*period + 0.35*tv_x)
    gen byte a = runiform() < g_ps
    bysort period: replace a = 0 if _n <= 3
    bysort period: replace a = 1 if _n > _N - 3
    gen double g_w = cond(a == 1, 1 / g_ps, 1 / (1 - g_ps))
    gen double x = tv_x + base_x
    gen double y = 1 + a + 0.2*tv_x + 0.1*base_x + rnormal()
end

* --- TEST 1: fabricated cross-sectional tmle contract is rejected ---
local ++test_count
capture noisily {
    _tmlect_cross_sectional_data
    _fake_tmle_contract
    local vabbrev_before "`c(varabbrev)'"
    foreach subcmd in overlap balance weights support combined {
        capture noisily psdash `subcmd'
        assert _rc != 0
        assert "`c(varabbrev)'" == "`vabbrev_before'"
    }
}
_tmlect_result fabricated_tmle_contract_rejected `=_rc'

* --- TEST 2: fabricated longitudinal ltmle contract is rejected ---
local ++test_count
capture noisily {
    _tmlect_longitudinal_data
    _fake_ltmle_contract
    local vabbrev_before "`c(varabbrev)'"
    foreach subcmd in overlap balance weights support combined {
        capture noisily psdash `subcmd'
        assert _rc != 0
        assert "`c(varabbrev)'" == "`vabbrev_before'"
    }
}
_tmlect_result fabricated_ltmle_contract_rejected `=_rc'

* --- TEST 3: explicit args bypass the (unverifiable) tmle contract ---
local ++test_count
capture noisily {
    _tmlect_cross_sectional_data
    _fake_tmle_contract
    psdash overlap treat _tmle_ps, nograph
    assert "`r(source)'" == "manual"
    assert "`r(treatment)'" == "treat"
    assert "`r(psvar)'" == "_tmle_ps"
}
_tmlect_result explicit_args_bypass_tmle_contract `=_rc'

display as text _n "=== TMLE/LTMLE contract summary: " ///
    as result $PSDASH_TMLE_PASS_COUNT as text " passed, " ///
    as error $PSDASH_TMLE_FAIL_COUNT as text " failed ==="

_psdash_qa_cleanup
capture log close _all

display "RESULT: test_tmle_ltmle_contract tests=`test_count' pass=$PSDASH_TMLE_PASS_COUNT fail=$PSDASH_TMLE_FAIL_COUNT"
if $PSDASH_TMLE_FAIL_COUNT > 0 {
    display as error "Failed tests: $PSDASH_TMLE_FAILED_TESTS"
    exit 9
}

global PSDASH_TMLE_PASS_COUNT
global PSDASH_TMLE_FAIL_COUNT
global PSDASH_TMLE_FAILED_TESTS
