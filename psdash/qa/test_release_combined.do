* test_release_combined.do -- dashboard export and longitudinal identity regressions
* Author: Timothy P Copeland, Karolinska Institutet
* Usage: cd psdash/qa && stata-mp -b do test_release_combined.do

clear all
version 16.0
capture log close _all
log using "test_release_combined.log", text replace nomsg
do "`c(pwd)'/_psdash_bootstrap.do"

local initial_vao = c(varabbrev)
local tests = 0
local pass = 0
local fail = 0

**# Workbook failures retain the same analytical payload as a normal dashboard
capture noisily {
    clear
    set obs 40
    gen byte t = mod(_n, 2)
    gen double ps = .3 + .4*(_n - 1)/39
    gen double w = 1
    gen double x = mod(_n, 7)
    quietly psdash combined t ps, wvar(w) covariates(x)
    local verdict "`r(verdict)'"
    local findings `"`r(warnings)'"'
    local nfind = r(n_warnings)
    local ess = r(ess)
    local noutside = r(n_outside)
    matrix expected_balance = r(balance)
    tempfile badroot
    capture noisily psdash combined t ps, wvar(w) covariates(x) ///
        report("`badroot'/report.xlsx")
    local cmd_rc = _rc
    assert `cmd_rc' == 603
    assert "`r(treatment)'" == "t"
    assert "`r(source)'" == "manual"
    assert r(N_analysis) == 40
    assert r(n_panels) == 4
    assert r(n_warnings) == `nfind'
    assert "`r(verdict)'" == "`verdict'"
    assert `"`r(warnings)'"' == `"`findings'"'
    assert r(ess) == `ess'
    assert r(n_outside) == `noutside'
    matrix actual_balance = r(balance)
    assert mreldif(actual_balance, expected_balance) < 1e-14
    assert "`c(varabbrev)'" == "`initial_vao'"
}
local case_rc = _rc
local ++tests
if `case_rc' local ++fail
else local ++pass

**# Report retries must still propagate genuine analytical errors
capture noisily {
    clear
    set obs 20
    gen byte t = mod(_n, 2)
    gen double ps = .3 + .4*(_n - 1)/19
    gen double x = _n
    tempfile badroot
    capture noisily psdash combined t ps, covariates(x) threshold(-1) ///
        report("`badroot'/report.xlsx")
    local cmd_rc = _rc
    assert `cmd_rc' == 198
    assert "`r(verdict)'" == ""
    assert "`c(varabbrev)'" == "`initial_vao'"
}
local case_rc = _rc
local ++tests
if `case_rc' local ++fail
else local ++pass

**# Period names must identify exactly one period
capture noisily {
    clear
    set obs 8
    gen byte t = mod(_n, 2)
    gen double period = cond(_n <= 4, -1, .1)
    gen double ps = .5
    gen double w = 1
    gen byte touse = 1
    capture noisily _psdash_ltmle_diagnostics, treatment(t) period(period) ///
        psvar(ps) wvar(w) samplevar(touse)
    assert _rc == 198
    assert "`c(varabbrev)'" == "`initial_vao'"

    replace period = cond(_n <= 4, -2, .1)
    quietly _psdash_ltmle_diagnostics, treatment(t) period(period) ///
        psvar(ps) wvar(w) samplevar(touse)
    matrix periods = r(overlap_by_period)
    local names : rownames periods
    assert "`names'" == "p_2 p_1"
    assert "`r(periods)'" == "-2 .1"
    assert periods[1,1] == 4 & periods[2,1] == 4
}
local case_rc = _rc
local ++tests
if `case_rc' local ++fail
else local ++pass

**# Longitudinal weights use scale-invariant overall, period, and arm ESS
capture noisily {
    clear
    set obs 8
    gen byte t = mod(_n, 2)
    gen byte period = ceil(_n/4)
    gen double ps = .5
    gen double w = cond(inlist(_n, 1, 2, 5, 6), 1, 2)
    gen byte touse = 1
    foreach scale in 1e200 1e-200 {
        replace w = cond(inlist(_n, 1, 2, 5, 6), 1, 2) * `scale'
        quietly _psdash_ltmle_diagnostics, treatment(t) period(period) ///
            psvar(ps) wvar(w) samplevar(touse)
        assert abs(r(ess) - 7.2) < 1e-12
        assert abs(r(min_period_ess_pct) - 90) < 1e-10
        assert abs(r(min_period_arm_ess_pct) - 90) < 1e-10
        matrix weights = r(weights_by_period)
        forvalues i = 1/2 {
            assert abs(weights[`i', 7] - 90) < 1e-10
            assert abs(weights[`i', 8] - 90) < 1e-10
            assert abs(weights[`i', 9] - 90) < 1e-10
            assert !missing(weights[`i', 3])
        }
    }
}
local case_rc = _rc
local ++tests
if `case_rc' local ++fail
else local ++pass

_psdash_qa_cleanup
capture graph drop _all
display "RESULT: test_release_combined tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
