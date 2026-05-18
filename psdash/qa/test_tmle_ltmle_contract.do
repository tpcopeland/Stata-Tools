* test_tmle_ltmle_contract.do
* Focused tmle/ltmle contract-state smoke tests for psdash
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
    ereturn scalar is_longitudinal = 0
    ereturn local cmd "tmle"
    ereturn local method "tmle"
    ereturn local contract_version "1.0"
    ereturn local ps_var "_tmle_ps"
    ereturn local weight_var ""
    ereturn local if_var "_tmle_if"
    ereturn local covariates "x1 x2"
    ereturn local outcome "y"
    ereturn local treatment "treat"
    ereturn local tmodel "x1 x2"
    ereturn local estimand "ATT"
    char _dta[_tmle_estimated] "1"
    char _dta[_tmle_method] "tmle"
    char _dta[_tmle_contract_version] "1.0"
    char _dta[_tmle_treatment] "treat"
    char _dta[_tmle_covariates] "x1 x2"
    char _dta[_tmle_tmodel] "x1 x2"
    char _dta[_tmle_ps_var] "_tmle_ps"
    char _dta[_tmle_weight_var] ""
    char _dta[_tmle_estimand] "ATT"
end

capture program drop _fake_ltmle_contract
program define _fake_ltmle_contract, eclass
    quietly regress y x tv_x base_x
    ereturn scalar is_longitudinal = 1
    ereturn scalar N_id = 40
    ereturn scalar T = 3
    ereturn local cmd "ltmle"
    ereturn local method "ltmle"
    ereturn local contract_version "1.0"
    ereturn local id "pid"
    ereturn local period "period"
    ereturn local outcome "y"
    ereturn local treatment "a"
    ereturn local covariates "tv_x"
    ereturn local baseline "base_x"
    ereturn local regime "always_never"
    ereturn local estimand "ATE"
    ereturn local ps_var "g_ps"
    ereturn local weight_var "g_w"
    char _dta[_ltmle_estimated] "1"
    char _dta[_ltmle_method] "ltmle"
    char _dta[_ltmle_contract_version] "1.0"
    char _dta[_ltmle_treatment] "a"
    char _dta[_ltmle_id] "pid"
    char _dta[_ltmle_period] "period"
    char _dta[_ltmle_ps_var] "g_ps"
    char _dta[_ltmle_weight_var] "g_w"
    char _dta[_ltmle_tmodel] "tv_x base_x"
    char _dta[_ltmle_estimand] "ATE"
    char _dta[_ltmle_regime] "always_never"
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
    gen double _tmle_if = y - 1
    gen byte _tmle_esample = 1
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
    gen byte _ltmle_esample = 1
end

local ++test_count
capture noisily {
    _tmlect_cross_sectional_data
    _fake_tmle_contract
    psdash overlap, nograph
    assert r(N) == 120
    assert "`r(treatment)'" == "treat"
    assert "`r(psvar)'" == "_tmle_ps"
    assert "`r(estimand)'" == "att"

    psdash balance, nowvar
    assert "`r(varlist)'" == "x1 x2"

    psdash weights
    assert "`r(treatment)'" == "treat"
    assert "`r(estimand)'" == "att"
    assert "`r(wvar)'" == "auto-generated"

    psdash support, nograph
    assert r(N) == 120
    assert "`r(treatment)'" == "treat"
    assert "`r(psvar)'" == "_tmle_ps"
}
_tmlect_result tmle_contract_autodetects_individual_subcommands `=_rc'

local ++test_count
capture noisily {
    _tmlect_cross_sectional_data
    _fake_tmle_contract
    capture graph drop _all
    psdash combined
    assert "`r(source)'" == "tmle"
    assert "`r(treatment)'" == "treat"
    assert "`r(psvar)'" == "_tmle_ps"
    assert "`r(estimand)'" == "att"
    assert r(N) == 120
    assert r(pct_outside) >= 0
}
_tmlect_result tmle_contract_uses_cross_sectional_combined_path `=_rc'

local ++test_count
capture noisily {
    _tmlect_longitudinal_data
    _fake_ltmle_contract
    local vabbrev_before "`c(varabbrev)'"
    foreach subcmd in overlap balance weights support {
        capture noisily psdash `subcmd'
        assert _rc == 198
        assert "`c(varabbrev)'" == "`vabbrev_before'"
    }

    psdash combined
    assert "`c(varabbrev)'" == "`vabbrev_before'"
    assert "`r(source)'" == "ltmle"
    assert r(longitudinal) == 1
    assert "`r(treatment)'" == "a"
    assert "`r(psvar)'" == "g_ps"
    assert "`r(wvar)'" == "g_w"
    assert "`r(period)'" == "period"
    assert "`r(id)'" == "pid"
    assert r(N_periods) == 3
    matrix O = r(overlap_by_period)
    matrix W = r(weights_by_period)
    assert rowsof(O) == 3
    assert colsof(O) == 12
    assert rowsof(W) == 3
    assert colsof(W) == 7
}
_tmlect_result ltmle_contract_uses_longitudinal_combined_path `=_rc'

display as text _n "=== TMLE/LTMLE contract summary: " ///
    as result $PSDASH_TMLE_PASS_COUNT as text " passed, " ///
    as error $PSDASH_TMLE_FAIL_COUNT as text " failed ==="

_psdash_qa_cleanup
capture log close _all

if $PSDASH_TMLE_FAIL_COUNT > 0 {
    display as error "Failed tests: $PSDASH_TMLE_FAILED_TESTS"
    exit 9
}

global PSDASH_TMLE_PASS_COUNT
global PSDASH_TMLE_FAIL_COUNT
global PSDASH_TMLE_FAILED_TESTS
