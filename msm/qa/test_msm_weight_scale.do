* test_msm_weight_scale.do
* Scale invariance of the weight diagnostics (R-tabtools Codex audit of
* 2026-09-26, finding D2, as it applies to msm).
* Written against msm 1.4.8 before any fix:
*   WS1  the Kish ESS (sum w)^2 / sum w^2 of weights 1, 2, 3 is 18/7 when
*        they are multiplied by 1e-200, 1e-300, 1e200 or 1e300 (was missing:
*        the squares underflowed to 0 or overflowed)
*   WS2  the ESS helper honours if/in, skips missing weights, and returns
*        missing for an empty sample
*   WS3  msm_weight r(ess), msm_diagnose r(ess)/r(ess_pct), the ess columns
*        of r(support) and r(treatment_balance), and the ESS msm_report
*        exports agree with an ESS computed in Mata from _msm_weight
*   WS4  the weighted SMD of a continuous covariate is unchanged when the
*        weights are multiplied by 1e-200 or 1e200 (was missing: sum w^2 and
*        (sum w)^2 left the double range)
* Oracles: 18/7 by hand; Mata sums over the weights; the Austin & Stuart
* reliability-weight SMD formula evaluated in Mata on unscaled weights.

version 16.0
clear all
set more off
set varabbrev off

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture log close _all
log using "test_msm_weight_scale.log", replace text nomsg

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

* Kish ESS of `w' `if' in Mata, from sums over the weights divided by
* their largest value (an independent route from the package's helper).
capture program drop _ws_mata_ess
program define _ws_mata_ess, rclass
    version 16.0
    syntax varname [if]
    marksample touse
    mata: st_local("ess", strofreal(_ws_ess(st_data(., "`varlist'", "`touse'")), "%21.17g"))
    return scalar ess = `ess'
end

mata:
real scalar _ws_ess(real colvector w)
{
    real colvector v
    v = w / max(w)
    return(sum(v)^2 / sum(v :^ 2))
}

// Austin & Stuart (2015) weighted SMD for a continuous covariate:
// (m1 - m0) / sqrt((s1 + s0) / 2), s = sum(w) / (sum(w)^2 - sum(w^2))
// * sum(w (x - m)^2), on weights divided by their largest value.
real scalar _ws_smd(real colvector x, real colvector t, real colvector w)
{
    real colvector v, x1, x0, v1, v0
    real scalar m1, m0, s1, s0

    v  = w / max(w)
    x1 = select(x, t :== 1); v1 = select(v, t :== 1)
    x0 = select(x, t :== 0); v0 = select(v, t :== 0)
    m1 = sum(v1 :* x1) / sum(v1)
    m0 = sum(v0 :* x0) / sum(v0)
    s1 = sum(v1) / (sum(v1)^2 - sum(v1 :^ 2)) * sum(v1 :* (x1 :- m1) :^ 2)
    s0 = sum(v0) / (sum(v0)^2 - sum(v0 :^ 2)) * sum(v0 :* (x0 :- m0) :^ 2)
    return((m1 - m0) / sqrt((s1 + s0) / 2))
}
end

* A small person-period panel with a time-varying confounder.
capture program drop _ws_panel
program define _ws_panel
    version 16.0
    clear
    set seed 26092026
    quietly set obs 1200
    gen long id = ceil(_n / 6)
    bysort id: gen int period = _n - 1
    gen byte bl = mod(id, 2)
    gen double L = rnormal() + 0.2 * period + 0.3 * bl
    gen byte treatment = runiform() < invlogit(-0.5 + 0.4 * bl + 0.5 * L)
    gen byte outcome = runiform() < invlogit(-4 + 0.4 * treatment + 0.2 * L)
    bysort id (period): gen byte _prior = sum(outcome[_n-1]) >= 1 if _n > 1
    quietly replace _prior = 0 if missing(_prior)
    quietly drop if _prior
    drop _prior
end

**# WS1: ESS of weights 1, 2, 3 at extreme scales
foreach s in 1 1e-200 1e-300 1e200 1e300 {
    local ++test_count
    capture noisily {
        clear
        quietly set obs 3
        gen double w = `s' * _n
        _msm_ess w
        assert reldif(r(ess), 18/7) < 1e-14
        assert r(N) == 3
    }
    if _rc == 0 {
        display as result "  PASS WS1: weights 1, 2, 3 times `s' have ESS 18/7"
        local ++pass_count
    }
    else {
        display as error "  FAIL WS1: weights 1, 2, 3 times `s' (rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' WS1(`s')"
    }
}

* Many rows (so the sums themselves approach the range edges).
foreach s in 1e-250 1e250 {
    local ++test_count
    capture noisily {
        clear
        quietly set obs 5000
        gen double w1 = 1 + mod(_n, 7)
        gen double w = `s' * w1
        _ws_mata_ess w1
        local want = r(ess)
        _msm_ess w
        assert reldif(r(ess), `want') < 1e-12
    }
    if _rc == 0 {
        display as result "  PASS WS1: 5,000 weights times `s' keep the unscaled ESS"
        local ++pass_count
    }
    else {
        display as error "  FAIL WS1: 5,000 weights times `s' (rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' WS1n(`s')"
    }
}

**# WS2: ESS helper sample handling
local ++test_count
capture noisily {
    clear
    quietly set obs 6
    gen double w = 1e-200 * _n
    replace w = . in 6
    gen byte keep = _n != 1
    * rows 2..5 (row 6 missing): weights 2, 3, 4, 5 -> 14^2 / 54
    _msm_ess w if keep
    assert reldif(r(ess), 196/54) < 1e-14
    assert r(N) == 4
    _msm_ess w in 1/3
    assert reldif(r(ess), 18/7) < 1e-14
    _msm_ess w if 0
    assert missing(r(ess))
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS WS2: ESS helper honours if/in, missing weights and empty samples"
    local ++pass_count
}
else {
    display as error "  FAIL WS2: ESS helper sample handling (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' WS2"
}

**# WS3: call sites agree with a Mata ESS of _msm_weight
local ++test_count
capture noisily {
    _ws_panel
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L) baseline_covariates(bl)
    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) nolog
    local weight_ess = r(ess)
    _ws_mata_ess _msm_weight if _msm_decision_risk
    local want = r(ess)
    quietly count if _msm_decision_risk
    local n_risk = r(N)
    assert reldif(`weight_ess', `want') < 1e-12

    msm_diagnose, balance_covariates(L)
    assert reldif(r(ess), `want') < 1e-12
    assert reldif(r(ess_pct), 100 * `want' / `n_risk') < 1e-12

    tempname sup tb
    matrix `sup' = r(support)
    matrix `tb' = r(treatment_balance)
    local c_ess = colnumb(`sup', "ess")
    local c_per = colnumb(`sup', "period")
    forvalues i = 1/`=rowsof(`sup')' {
        local p = `sup'[`i', `c_per']
        _ws_mata_ess _msm_weight if _msm_decision_risk & period == `p'
        assert reldif(`sup'[`i', `c_ess'], r(ess)) < 1e-12
    }

    * Treatment balance strata: period by prior treatment (-1 at baseline).
    tempvar hist
    quietly bysort id (period): gen double `hist' = treatment[_n-1]
    quietly replace `hist' = -1 if period == 0
    local t_ess = colnumb(`tb', "ess")
    local t_per = colnumb(`tb', "period")
    local t_his = colnumb(`tb', "history")
    forvalues i = 1/`=rowsof(`tb')' {
        local p = `tb'[`i', `t_per']
        local h = `tb'[`i', `t_his']
        _ws_mata_ess _msm_weight if _msm_decision_risk & period == `p' & ///
            `hist' == `h' & !missing(treatment)
        assert reldif(`tb'[`i', `t_ess'], r(ess)) < 1e-12
    }
}
if _rc == 0 {
    display as result "  PASS WS3: msm_weight and msm_diagnose ESS match the Mata oracle"
    local ++pass_count
}
else {
    display as error "  FAIL WS3: msm_weight/msm_diagnose ESS (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' WS3"
}

* msm_report exports the ESS over every _msm_weight row (%9.1f).
local ++test_count
capture noisily {
    _ws_panel
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L) baseline_covariates(bl)
    msm_weight, treat_d_cov(L bl) treat_n_cov(bl) nolog
    _ws_mata_ess _msm_weight if !missing(_msm_weight)
    local want = strtrim(string(r(ess), "%9.1f"))
    msm_fit, model(logistic) outcome_cov(bl) nolog
    tempfile rep
    local csv "`rep'.csv"
    msm_report, export("`csv'") format(csv) replace
    tempname fh
    local got ""
    file open `fh' using "`csv'", read text
    file read `fh' line
    while r(eof) == 0 {
        if substr(`"`line'"', 1, 4) == "ESS," local got = substr(`"`line'"', 5, .)
        file read `fh' line
    }
    file close `fh'
    capture erase "`csv'"
    assert "`got'" == "`want'"
}
if _rc == 0 {
    display as result "  PASS WS3: msm_report exports the Mata-oracle ESS"
    local ++pass_count
}
else {
    display as error "  FAIL WS3: msm_report ESS (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' WS3r"
}

**# WS4: weighted continuous SMD at extreme scales
foreach s in 1 1e-200 1e200 {
    local ++test_count
    capture noisily {
        clear
        quietly set obs 40
        gen byte t = _n > 20
        gen double x = _n + mod(_n, 7)
        gen double w1 = 1 + mod(_n, 5)
        gen double w = `s' * w1
        gen byte u = 1
        mata: st_local("want", strofreal(_ws_smd(st_data(., "x"), ///
            st_data(., "t"), st_data(., "w1")), "%21.17g"))
        _msm_smd x, treatment(t) weight(w) touse(u)
        assert !missing(`_msm_smd_value')
        assert reldif(`_msm_smd_value', `want') < 1e-12
    }
    if _rc == 0 {
        display as result "  PASS WS4: weighted SMD with weights times `s' matches the oracle"
        local ++pass_count
    }
    else {
        display as error "  FAIL WS4: weighted SMD with weights times `s' (rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' WS4(`s')"
    }
}

display as text ""
display as text "Tests run: " as result `test_count'
display as text "Passed:    " as result `pass_count'
display as text "Failed:    " as result `fail_count'
do "`qa_dir'/_record_qa_result.do" test_msm_weight_scale ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: test_msm_weight_scale tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 459
}
display as result "All msm weight-scale tests passed"
