* Hostile name, missingness, comparable-pair, and state contracts.

version 16.0
clear all
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall cstat_surv
quietly net install cstat_surv, from("`pkg_dir'") replace

local tests = 0
local pass = 0
local fail = 0
local longcov "abcdefghijklmnopqrstuvwxyzabcdef"

**# Legal 32-character covariate survives a fresh refit and repeat call
local ++tests
capture noisily {
    clear
    set obs 8
    gen double time = _n
    gen byte fail = mod(_n, 2)
    gen double `longcov' = _n / 8
    stset time, failure(fail)
    stcox `longcov', nolog
    cstat_surv
    local first_c = e(c)
    assert !missing(`first_c')
    summarize time
    stcox `longcov', nolog
    cstat_surv
    assert !missing(e(c))
    assert abs(e(c) - `first_c') < 1e-12
    assert "`e(cmd)'" == "cstat_surv"
}
if _rc == 0 local ++pass
else local ++fail

**# Extended missing covariates plus tied events leave no comparable pairs
local ++tests
capture noisily {
    clear
    set obs 4
    gen double time = 5
    gen byte fail = 1
    gen double x = _n
    replace x = .a in 3
    replace x = .z in 4
    stset time, failure(fail)
    stcox x, nolog
    local cmd_before "`e(cmd)'"
    capture noisily cstat_surv
    local call_rc = _rc
    assert `call_rc' == 2001
    assert "`e(cmd)'" == "`cmd_before'"
    assert _N == 4
}
if _rc == 0 local ++pass
else local ++fail

**# Refusal after non-Cox estimation preserves data and active estimates
local ++tests
capture noisily {
    sysuse auto, clear
    gen long order_before = _n
    regress price mpg
    local cmd_before "`e(cmd)'"
    local n_before = e(N)
    capture noisily cstat_surv
    local call_rc = _rc
    assert `call_rc' == 301
    assert "`e(cmd)'" == "`cmd_before'"
    assert e(N) == `n_before'
    assert _N == 74
    assert order_before == _n
}
if _rc == 0 local ++pass
else local ++fail

display "RESULT: test_cstat_surv_hostile tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' > 0 exit 1
