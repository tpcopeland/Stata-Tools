* test_qa_contract_gaps.do
* Focused semantic coverage for static QA contract gaps.

clear all
version 16.0
set more off
set varabbrev off

capture log close _all
log using "test_qa_contract_gaps.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"

local test_count = 0
global QCG_PASS_COUNT = 0
global QCG_FAIL_COUNT = 0

capture program drop _qcg_record
program define _qcg_record
    args rc label
    if `rc' == 0 {
        display as result "PASS: `label'"
        global QCG_PASS_COUNT = $QCG_PASS_COUNT + 1
    }
    else {
        display as error "FAIL: `label' (rc=`rc')"
        global QCG_FAIL_COUNT = $QCG_FAIL_COUNT + 1
    }
end

capture program drop _qcg_binary_data
program define _qcg_binary_data
    clear
    set obs 8
    gen byte treat = (_n > 4)
    gen double ps = .
    replace ps = .20 in 1
    replace ps = .30 in 2
    replace ps = .40 in 3
    replace ps = .50 in 4
    replace ps = .50 in 5
    replace ps = .60 in 6
    replace ps = .70 in 7
    replace ps = .80 in 8
    gen double x1 = _n
    gen double x2 = 10 - _n
    gen double wt = .
    replace wt = 1.0 in 1
    replace wt = 2.0 in 2
    replace wt = 4.0 in 3
    replace wt = 8.0 in 4
    replace wt = 1.5 in 5
    replace wt = 3.0 in 6
    replace wt = 6.0 in 7
    replace wt = 9.0 in 8
end

capture program drop _qcg_multigroup_data
program define _qcg_multigroup_data
    clear
    set obs 6
    gen byte arm = .
    replace arm = 0 in 1/2
    replace arm = 1 in 3/4
    replace arm = 2 in 5/6

    gen double gps0 = .
    replace gps0 = .30 in 1
    replace gps0 = .40 in 2
    replace gps0 = .35 in 3
    replace gps0 = .30 in 4
    replace gps0 = .40 in 5
    replace gps0 = .30 in 6

    gen double gps1 = .
    replace gps1 = .40 in 1
    replace gps1 = .30 in 2
    replace gps1 = .30 in 3
    replace gps1 = .40 in 4
    replace gps1 = .30 in 5
    replace gps1 = .30 in 6

    gen double gps2 = .
    replace gps2 = .30 in 1
    replace gps2 = .30 in 2
    replace gps2 = .35 in 3
    replace gps2 = .30 in 4
    replace gps2 = .30 in 5
    replace gps2 = .40 in 6

    gen double x1 = arm + _n / 10
    gen double x2 = cond(arm == 0, 1, cond(arm == 1, 2, 3)) + _n / 20
    gen double wt = .
    replace wt = 1 in 1
    replace wt = 2 in 2
    replace wt = 3 in 3
    replace wt = 3 in 4
    replace wt = 4 in 5
    replace wt = 8 in 6
end

**# Public detector command

local ++test_count
capture noisily {
    _qcg_binary_data
    quietly psdash_detect treat ps, covariates(x1 x2) wvar(wt) estimand(ate)
    assert "`r(source)'" == "manual"
    assert "`r(treatment)'" == "treat"
    assert "`r(psvar)'" == "ps"
    assert "`r(covariates)'" == "x1 x2"
    assert "`r(wvar)'" == "wt"
    assert "`r(estimand)'" == "ate"
    assert r(n_covariates) == 2
    assert r(psvar_auto) == 0
    assert r(multigroup) == 0
    assert r(longitudinal) == 0
}
_qcg_record `=_rc' "psdash_detect public command and returns"

**# Binary weight modification returns

local ++test_count
capture noisily {
    _qcg_binary_data
    quietly psdash_weights treat ps, wvar(wt) truncate(5) generate(w_trunc)
    local got_new_sd = r(new_sd)
    local got_new_min = r(new_min)
    local got_new_ess_pct = r(new_ess_pct)
    local got_pct_extreme = r(pct_extreme)

    quietly summarize w_trunc, detail
    local expected_new_sd = r(sd)
    local expected_new_min = r(min)
    tempvar wtrunc_sq
    gen double `wtrunc_sq' = w_trunc^2
    quietly summarize w_trunc
    local trunc_sum = r(sum)
    quietly summarize `wtrunc_sq'
    local trunc_sum_sq = r(sum)
    local expected_new_ess = (`trunc_sum'^2) / `trunc_sum_sq'
    local expected_new_ess_pct = 100 * `expected_new_ess' / _N
    quietly count if wt > 10
    local expected_pct_extreme = 100 * r(N) / _N

    assert abs(`got_new_sd' - `expected_new_sd') < 1e-10
    assert abs(`got_new_min' - `expected_new_min') < 1e-10
    assert abs(`got_new_ess_pct' - `expected_new_ess_pct') < 1e-10
    assert abs(`got_pct_extreme' - `expected_pct_extreme') < 1e-10
    assert abs(`got_new_min' - 1) < 1e-10
    assert abs(`got_pct_extreme' - 0) < 1e-10
}
_qcg_record `=_rc' "psdash_weights modified and extreme-weight returns"

**# Multi-group balance returns

local ++test_count
capture noisily {
    _qcg_multigroup_data
    quietly psdash_balance arm gps0, covariates(x1 x2) wvar(wt) nowvar ///
        psvars(gps0 gps1 gps2) reference(1)
    local n_group_ "N_group_"
    foreach lev in 0 1 2 {
        local result_name "`n_group_'`lev'"
        assert r(`result_name') == 2
    }
    assert r(K) == 3
    assert "`r(levels)'" == "0 1 2"
    assert "`r(reference)'" == "1"
}
_qcg_record `=_rc' "psdash_balance group-suffixed counts"

**# Multi-group overlap returns

local ++test_count
capture noisily {
    _qcg_multigroup_data
    quietly psdash_overlap arm gps0, nograph psvars(gps0 gps1 gps2) reference(1)
    local n_group_ "N_group_"
    local mean_ps_group_ "mean_ps_group_"
    local min_ps_group_ "min_ps_group_"
    local max_ps_group_ "max_ps_group_"

    foreach lev in 0 1 2 {
        local n_result "`n_group_'`lev'"
        assert r(`n_result') == 2
    }
    local mean_result "`mean_ps_group_'0"
    assert abs(r(`mean_result') - .35) < 1e-10
    local mean_result "`mean_ps_group_'1"
    assert abs(r(`mean_result') - .35) < 1e-10
    local mean_result "`mean_ps_group_'2"
    assert abs(r(`mean_result') - .35) < 1e-10
    local min_result "`min_ps_group_'0"
    assert abs(r(`min_result') - .30) < 1e-10
    local min_result "`min_ps_group_'1"
    assert abs(r(`min_result') - .30) < 1e-10
    local min_result "`min_ps_group_'2"
    assert abs(r(`min_result') - .30) < 1e-10
    local max_result "`max_ps_group_'0"
    assert abs(r(`max_result') - .40) < 1e-10
    local max_result "`max_ps_group_'1"
    assert abs(r(`max_result') - .40) < 1e-10
    local max_result "`max_ps_group_'2"
    assert abs(r(`max_result') - .40) < 1e-10
}
_qcg_record `=_rc' "psdash_overlap group-suffixed summaries"

**# Multi-group support returns

local ++test_count
capture noisily {
    _qcg_multigroup_data
    quietly psdash_support arm gps0, nograph psvars(gps0 gps1 gps2) reference(1)
    local n_group_ "N_group_"
    local n_outside_group_ "n_outside_group_"

    foreach lev in 0 1 2 {
        local n_result "`n_group_'`lev'"
        local outside_result "`n_outside_group_'`lev'"
        assert r(`n_result') == 2
        assert r(`outside_result') == 0
    }
    assert abs(r(lower_bound) - .30) < 1e-10
    assert abs(r(upper_bound) - .40) < 1e-10
    assert r(n_outside) == 0
    assert abs(r(pct_outside) - 0) < 1e-10
}
_qcg_record `=_rc' "psdash_support group-suffixed outside counts"

**# Multi-group weight returns

local ++test_count
capture noisily {
    _qcg_multigroup_data
    quietly psdash_weights arm gps0, wvar(wt) psvars(gps0 gps1 gps2) reference(1)
    local n_group_ "N_group_"
    local ess_group_ "ess_group_"
    local ess_pct_group_ "ess_pct_group_"

    foreach lev in 0 1 2 {
        local n_result "`n_group_'`lev'"
        assert r(`n_result') == 2
    }
    local ess_result "`ess_group_'0"
    local pct_result "`ess_pct_group_'0"
    assert abs(r(`ess_result') - 1.8) < 1e-10
    assert abs(r(`pct_result') - 90) < 1e-10
    local ess_result "`ess_group_'1"
    local pct_result "`ess_pct_group_'1"
    assert abs(r(`ess_result') - 2) < 1e-10
    assert abs(r(`pct_result') - 100) < 1e-10
    local ess_result "`ess_group_'2"
    local pct_result "`ess_pct_group_'2"
    assert abs(r(`ess_result') - 1.8) < 1e-10
    assert abs(r(`pct_result') - 90) < 1e-10
}
_qcg_record `=_rc' "psdash_weights group-suffixed ESS returns"

**# Public detector with multi-group psvars()/reference()

local ++test_count
capture noisily {
    _qcg_multigroup_data
    quietly psdash_detect arm gps0, psvars(gps0 gps1 gps2) reference(1)
    assert "`r(source)'" == "manual"
    assert r(multigroup) == 1
    assert r(K) == 3
    assert "`r(levels)'" == "0 1 2"
    assert "`r(reference)'" == "1"
}
_qcg_record `=_rc' "psdash_detect multi-group psvars()/reference() options"

**# Overlap with covariates() auto-detection context

local ++test_count
capture noisily {
    _qcg_binary_data
    quietly psdash_overlap treat ps, nograph covariates(x1 x2)
    assert r(N) == 8
    assert "`r(treatment)'" == "treat"
    assert "`r(psvar)'" == "ps"
}
_qcg_record `=_rc' "psdash_overlap covariates() option"

**# Combined dashboard imbalmax() verdict threshold

local ++test_count
capture noisily {
    _qcg_binary_data
    capture graph drop _all
    quietly psdash combined treat ps, covariates(x1 x2) wvar(wt) imbalmax(2)
    assert r(imbalmax) == 2
    assert r(N) == 8
    assert "`r(treatment)'" == "treat"
    assert "`r(psvar)'" == "ps"
    capture graph drop _all
}
_qcg_record `=_rc' "psdash combined imbalmax() option and return"

**# Summary

local pass_count = $QCG_PASS_COUNT
local fail_count = $QCG_FAIL_COUNT
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_qa_contract_gaps tests=`test_count' pass=`pass_count' fail=`fail_count'"

_psdash_qa_cleanup
capture log close _all
global QCG_PASS_COUNT
global QCG_FAIL_COUNT

if `fail_count' > 0 {
    exit 9
}
