* test_msm_tte_contract.do
* Focused msm/tte longitudinal contract-state smoke tests for psdash
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

* Synthetic person-period data with a per-period treatment PS and weights.
* A trailing logit fit is left active so e(cmd)=="logit" with e(depvar)=a, which
* mimics the real post-msm_weight / post-tte_weight session state: psdash must
* route via the dataset contract, NOT the stale estimation result.
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
    * leave e(cmd)=="logit" active on purpose
    quietly logit a tv_x period
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
    quietly logit a tv_x period
    char _dta[_tte_weighted] "1"
    char _dta[_tte_treatment] "a"
    char _dta[_tte_pscore_var] "ps"
    char _dta[_tte_weight_var] "w"
    char _dta[_tte_covariates] "tv_x"
    char _dta[_tte_id] "pid"
    char _dta[_tte_period] "period"
    char _dta[_tte_estimand] "PP"
end

* --- TEST 1: msm contract routes to longitudinal combined path ---
local ++test_count
capture noisily {
    _mtct_longitudinal_data
    _fake_msm_contract
    local vabbrev_before "`c(varabbrev)'"

    * pooled subcommands must refuse to auto-run on longitudinal data
    foreach subcmd in overlap balance weights support {
        capture noisily psdash `subcmd'
        assert _rc == 198
        assert "`c(varabbrev)'" == "`vabbrev_before'"
    }

    psdash combined
    assert "`c(varabbrev)'" == "`vabbrev_before'"
    assert "`r(source)'" == "msm"
    assert r(longitudinal) == 1
    assert "`r(treatment)'" == "a"
    assert "`r(psvar)'" == "ps"
    assert "`r(wvar)'" == "tw"
    assert "`r(period)'" == "period"
    assert "`r(id)'" == "pid"
    assert "`r(estimand)'" == "ate"
    matrix O = r(overlap_by_period)
    matrix W = r(weights_by_period)
    assert colsof(O) == 12
    assert colsof(W) == 7
}
_mtct_result msm_contract_uses_longitudinal_combined_path `=_rc'

* --- TEST 2: tte contract routes to longitudinal combined path ---
local ++test_count
capture noisily {
    _mtct_longitudinal_data
    _fake_tte_contract
    local vabbrev_before "`c(varabbrev)'"

    foreach subcmd in overlap balance weights support {
        capture noisily psdash `subcmd'
        assert _rc == 198
    }

    psdash combined
    assert "`r(source)'" == "tte"
    assert r(longitudinal) == 1
    assert "`r(treatment)'" == "a"
    assert "`r(psvar)'" == "ps"
    assert "`r(wvar)'" == "w"
    assert "`r(period)'" == "period"
    assert "`r(id)'" == "pid"
    assert "`r(estimand)'" == "pp"
}
_mtct_result tte_contract_uses_longitudinal_combined_path `=_rc'

* --- TEST 3: msm contract with missing PS variable gives a clean error ---
local ++test_count
capture noisily {
    _mtct_longitudinal_data
    _fake_msm_contract
    char _dta[_msm_ps_var] "no_such_ps"
    capture noisily psdash combined
    assert _rc != 0
    assert _rc != 1
}
_mtct_result msm_contract_missing_ps_errors_cleanly `=_rc'

* --- TEST 4: tte contract without a saved pscore gives a clean error ---
local ++test_count
capture noisily {
    _mtct_longitudinal_data
    _fake_tte_contract
    char _dta[_tte_pscore_var]
    capture noisily psdash combined
    assert _rc == 198
}
_mtct_result tte_contract_without_save_ps_errors_cleanly `=_rc'

display as text _n "=== MSM/TTE contract summary: " ///
    as result $PSDASH_MT_PASS_COUNT as text " passed, " ///
    as error $PSDASH_MT_FAIL_COUNT as text " failed ==="

_psdash_qa_cleanup
capture log close _all

if $PSDASH_MT_FAIL_COUNT > 0 {
    display as error "Failed tests: $PSDASH_MT_FAILED_TESTS"
    exit 9
}

global PSDASH_MT_PASS_COUNT
global PSDASH_MT_FAIL_COUNT
global PSDASH_MT_FAILED_TESTS
