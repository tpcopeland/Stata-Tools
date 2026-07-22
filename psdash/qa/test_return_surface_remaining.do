* test_return_surface_remaining.do — semantic checks for previously unreferenced returns

clear all
version 16.0
set more off
set varabbrev off

capture log close _all
log using "test_return_surface_remaining.log", replace nomsg
do "`c(pwd)'/_psdash_bootstrap.do"
discard

global rs_tests = 0
global rs_pass = 0
global rs_fail = 0

capture program drop _rs_result
program define _rs_result
    args id rc
    global rs_tests = $rs_tests + 1
    if `rc' == 0 {
        global rs_pass = $rs_pass + 1
        display as result "PASS: `id'"
    }
    else {
        global rs_fail = $rs_fail + 1
        display as error "FAIL: `id' (rc=`rc')"
    }
end

**# Teffects sample ledger is present on balance, weights, support, and combined
capture noisily {
    clear
    set seed 22072026
    set obs 120
    gen double x = rnormal()
    gen byte eligible = _n <= 100
    gen byte treat = runiform() < invlogit(-.2 + .5*x)
    gen double y = 2*treat + x + rnormal()
    teffects ipw (y) (treat x) if eligible, ate

    psdash balance
    assert r(n_estimation) == 100
    assert r(n_excluded) == 20

    psdash weights
    assert r(n_estimation) == 100
    assert r(n_excluded) == 20
    assert r(n_wt_undefined) == 0

    psdash support, nograph
    assert "`r(source)'" == "teffects"
    assert r(n_estimation) == 100

    psdash combined, nobalance nooverlap nosupport
    assert r(n_estimation) == 100
    assert r(n_common_excluded) == 20
    assert "`r(warning_panels)'" != "" | r(n_warnings) == 0
}
_rs_result "teffects_return_ledgers" `=_rc'

**# Manual detect does not leak producer-only metadata
capture noisily {
    clear
    set obs 20
    gen byte treat = _n > 10
    gen double ps = cond(treat, .6, .4)
    psdash detect treat ps
    assert "`r(iivwcomponent)'" == ""
    assert "`r(id)'" == ""
    assert "`r(period)'" == ""
    assert "`r(regime)'" == ""
    assert "`r(method)'" == ""
    assert "`r(contract_version)'" == ""
}
_rs_result "manual_detect_has_no_producer_metadata" `=_rc'

**# Multi-group combined identity returns agree with the requested mapping
capture noisily {
    clear
    set obs 90
    gen byte arm = mod(_n - 1, 3)
    gen double p0 = cond(arm == 0, .60, .20)
    gen double p1 = cond(arm == 1, .60, .20)
    gen double p2 = 1 - p0 - p1
    gen double x = arm + runiform()
    psdash combined arm, psvars(p0 p1 p2) covariates(x) ///
        reference(1) nooverlap noweights nosupport
    assert r(K) == 3
    assert "`r(levels)'" == "0 1 2"
    assert "`r(reference)'" == "1"
}
_rs_result "multigroup_identity_returns" `=_rc'

**# Longitudinal metadata and diagnostic ledgers survive the combined engine
capture noisily {
    clear
    set obs 40
    gen int person = ceil(_n/2)
    gen byte period = 1 + (_n > 20)
    gen byte treat = mod(_n, 2)
    gen double ps = cond(treat, .6, .4)
    gen double wt = 1
    gen byte sample = 1
    _psdash_ltmle_diagnostics, treatment(treat) period(period) ///
        psvar(ps) wvar(wt) samplevar(sample) id("person") ///
        estimand(ate) regime(static) method(logit) contract(1.0) source(test)
    assert "`r(method)'" == "logit"
    assert "`r(contract_version)'" == "1.0"
    assert "`r(id)'" == "person"
    assert "`r(period)'" == "period"
    assert "`r(regime)'" == "static"
    assert r(longitudinal) == 1
}
_rs_result "longitudinal_metadata_returns" `=_rc'

display as text _n "RESULT: test_return_surface_remaining tests=$rs_tests pass=$rs_pass fail=$rs_fail"
local final_fail = $rs_fail
macro drop rs_tests rs_pass rs_fail
_psdash_qa_cleanup
capture log close _all
if `final_fail' > 0 exit 9
