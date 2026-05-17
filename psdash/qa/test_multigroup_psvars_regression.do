* test_multigroup_psvars_regression.do - targeted multigroup PS validation regressions
* Usage: cd psdash/qa && stata-mp -b do test_multigroup_psvars_regression.do

clear all
version 16.0

capture log close _all
log using "test_multigroup_psvars_regression.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

do "`c(pwd)'/_psdash_bootstrap.do"

capture program drop _setup_k2_single_ps
program define _setup_k2_single_ps
    clear
    set obs 8
    gen byte arm = cond(_n <= 4, 1, 2)
    gen double ps = .
    replace ps = .20 in 1
    replace ps = .30 in 2
    replace ps = .40 in 3
    replace ps = .50 in 4
    replace ps = .60 in 5
    replace ps = .70 in 6
    replace ps = .80 in 7
    replace ps = .90 in 8
    gen double x = _n
    gen double w_ate = cond(arm == 1, 1 / (1 - ps), 1 / ps)
    gen double w_att_ref1 = cond(arm == 1, 1, (1 - ps) / ps)
    gen double w_att_ref2 = cond(arm == 2, 1, ps / (1 - ps))
end

capture program drop _setup_bad_psvars
program define _setup_bad_psvars
    args mode
    clear
    set obs 9
    gen byte arm = mod(_n - 1, 3)
    gen double x = _n
    if "`mode'" == "sum" {
        gen double ps0 = .80
        gen double ps1 = .10
        gen double ps2 = .30
    }
    else if "`mode'" == "range" {
        gen double ps0 = .20
        gen double ps1 = .30
        gen double ps2 = 1.10
    }
    else {
        gen double ps0 = .20
        gen double ps1 = .30
        gen double ps2 = .50
    }
end

**# K=2 Non-0/1 Single PS Regressions

local ++test_count
capture noisily {
    _setup_k2_single_ps
    psdash weights arm ps
    local got_K = r(K)
    local got_mean = r(mean_wt)
    local got_ess = r(ess)
    quietly summarize w_ate
    local mean_exp = r(mean)
    gen double w_ate_sq = w_ate^2
    quietly summarize w_ate
    local sum_w = r(sum)
    quietly summarize w_ate_sq
    local ess_exp = (`sum_w'^2) / r(sum)
    assert `got_K' == 2
    assert abs(`got_mean' - `mean_exp') < 1e-10
    assert abs(`got_ess' - `ess_exp') < 1e-10
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: K2 single PS ATE weights use implied complementary probability"
    local ++pass_count
}
else {
    display as error "  FAIL: K2 single PS ATE weights use implied complementary probability (rc=`rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _setup_k2_single_ps
    psdash weights arm ps, estimand(att)
    local got_K = r(K)
    local got_ref "`r(reference)'"
    local got_mean = r(mean_wt)
    local got_ess = r(ess)
    quietly summarize w_att_ref1
    local mean_exp = r(mean)
    gen double w_att_sq = w_att_ref1^2
    quietly summarize w_att_ref1
    local sum_w = r(sum)
    quietly summarize w_att_sq
    local ess_exp = (`sum_w'^2) / r(sum)
    assert `got_K' == 2
    assert "`got_ref'" == "1"
    assert abs(`got_mean' - `mean_exp') < 1e-10
    assert abs(`got_ess' - `ess_exp') < 1e-10
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: K2 single PS ATT weights use first level as default reference"
    local ++pass_count
}
else {
    display as error "  FAIL: K2 single PS ATT weights use first level as default reference (rc=`rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _setup_k2_single_ps
    psdash weights arm ps, estimand(att) reference(2)
    local got_K = r(K)
    local got_ref "`r(reference)'"
    local got_mean = r(mean_wt)
    local got_ess = r(ess)
    quietly summarize w_att_ref2
    local mean_exp = r(mean)
    gen double w_att2_sq = w_att_ref2^2
    quietly summarize w_att_ref2
    local sum_w = r(sum)
    quietly summarize w_att2_sq
    local ess_exp = (`sum_w'^2) / r(sum)
    assert `got_K' == 2
    assert "`got_ref'" == "2"
    assert abs(`got_mean' - `mean_exp') < 1e-10
    assert abs(`got_ess' - `ess_exp') < 1e-10
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: K2 single PS ATT weights honor reference(2)"
    local ++pass_count
}
else {
    display as error "  FAIL: K2 single PS ATT weights honor reference(2) (rc=`rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _setup_k2_single_ps
    quietly summarize x if arm == 2 [aw=w_ate]
    local mean2 = r(mean)
    quietly summarize x if arm == 1 [aw=w_ate]
    local mean1 = r(mean)
    quietly summarize x if arm == 2
    local var2 = r(Var)
    quietly summarize x if arm == 1
    local var1 = r(Var)
    local smd_exp = (`mean2' - `mean1') / sqrt((`var2' + `var1') / 2)
    psdash balance arm ps, covariates(x)
    matrix B = r(balance)
    assert r(K) == 2
    assert abs(B[1,8] - `smd_exp') < 1e-10
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: K2 single PS balance uses implied auto-generated weights"
    local ++pass_count
}
else {
    display as error "  FAIL: K2 single PS balance uses implied auto-generated weights (rc=`rc')"
    local ++fail_count
}

**# Invalid Multigroup PSVars Regressions

local ++test_count
capture noisily {
    _setup_bad_psvars sum
    capture noisily psdash overlap arm, psvars(ps0 ps1 ps2) nograph
    assert _rc == 198
    capture noisily psdash support arm, psvars(ps0 ps1 ps2) nograph
    assert _rc == 198
    capture noisily psdash weights arm, psvars(ps0 ps1 ps2)
    assert _rc == 198
    capture noisily psdash balance arm, psvars(ps0 ps1 ps2) covariates(x)
    assert _rc == 198
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: all subcommands reject complete psvars() rows that do not sum to 1"
    local ++pass_count
}
else {
    display as error "  FAIL: all subcommands reject complete psvars() rows that do not sum to 1 (rc=`rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _setup_bad_psvars range
    capture noisily psdash weights arm, psvars(ps0 ps1 ps2)
    assert _rc == 198
    capture noisily psdash balance arm, psvars(ps0 ps1 ps2) covariates(x)
    assert _rc == 198
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: weights and balance reject out-of-range psvars() columns before auto-weighting"
    local ++pass_count
}
else {
    display as error "  FAIL: weights and balance reject out-of-range psvars() columns before auto-weighting (rc=`rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _setup_bad_psvars valid
    psdash overlap arm, psvars(ps0 ps1 ps2) nograph
    assert r(K) == 3
    psdash support arm, psvars(ps0 ps1 ps2) nograph
    assert r(K) == 3
    psdash weights arm, psvars(ps0 ps1 ps2)
    assert r(K) == 3
    psdash balance arm, psvars(ps0 ps1 ps2) covariates(x)
    assert r(K) == 3
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: valid psvars() rows summing to 1 remain accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: valid psvars() rows summing to 1 remain accepted (rc=`rc')"
    local ++fail_count
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_multigroup_psvars_regression tests=`test_count' pass=`pass_count' fail=`fail_count'"

_psdash_qa_cleanup
capture log close _all

if `fail_count' > 0 {
    exit 1
}
