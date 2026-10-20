* validation_finegray_phtest_recovery.do
* Known-truth recovery for finegray_phtest: the residual-time correlation is a
* deterministic transform of the fitted coefficients, so on data where every
* term of that transform can be written out by hand, the reported value must
* equal the hand computation.
*
* Fixture: 14 subjects, distinct event times, NO censoring, eight cause-1 and
* six cause-2 events.  With no censoring the censoring survivor G(t) is 1
* everywhere, so every Fine-Gray weight is exactly 1 and the subdistribution
* risk set at a cause-1 time t_j is: every subject with T_i >= t_j, plus every
* cause-2 subject with T_i < t_j (who stays in the set forever).  The raw
* Schoenfeld residual of covariate k at t_j is then
*
*     x_jk - sum_{i in R_j} x_ik exp(b'x_i) / sum_{i in R_j} exp(b'x_i)
*
* written below with generate/summarize only -- no package code -- and the
* correlation with rank(t), t and ln(t) over the cause-1 events is Pearson's.
* The only package input is e(b), the coefficients the transform is defined at.
*
* Run from finegray/qa:  stata-mp -b do validation_finegray_phtest_recovery.do

clear all
set varabbrev off
version 16.0

capture log close _all
log using "validation_finegray_phtest_recovery.log", replace text name(_phr)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture confirm file "`pkg_dir'/finegray.pkg"
if _rc {
    display as error "validation_finegray_phtest_recovery.do must run from finegray/qa"
    capture log close _phr
    exit 601
}
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* `input' cannot sit inside a program body, so the fixture is built once here.
clear
input long id double(t) byte status double(x1 x2)
 1  1.0 1  0.9 -0.3
 2  1.5 2  0.1  0.8
 3  2.2 1  1.4  0.2
 4  2.9 2 -0.5 -1.1
 5  3.4 1  0.3  1.3
 6  4.1 1 -0.2 -0.6
 7  4.8 2  1.1  0.4
 8  5.5 1 -0.8  0.9
 9  6.3 2  0.6 -1.4
10  7.0 1 -1.2  0.1
11  7.6 2  0.0  0.5
12  8.4 1 -0.4 -0.9
13  9.1 2  0.7  1.6
14  9.9 1 -1.5 -0.2
end
tempfile phr_fixture
quietly save "`phr_fixture'"
global PHR_FIXTURE "`phr_fixture'"

capture program drop _phr_data
program define _phr_data
    use "$PHR_FIXTURE", clear
    quietly stset t, failure(status) id(id)
end

* Hand-computed residuals and correlations, left in locals h_<fn>_<k>.
capture program drop _phr_hand
program define _phr_hand, rclass
    args b1 b2
    sort t
    quietly gen double eta = `b1' * x1 + `b2' * x2
    quietly gen double r1 = .
    quietly gen double r2 = .
    quietly gen byte inr = .
    quietly gen double w0 = .
    quietly gen double w1 = .
    quietly gen double w2 = .
    forvalues j = 1/`=_N' {
        if status[`j'] != 1 continue
        local tj = t[`j']
        quietly replace inr = (t >= `tj') | (status == 2 & t < `tj')
        quietly replace w0 = inr * exp(eta)
        quietly replace w1 = w0 * x1
        quietly replace w2 = w0 * x2
        quietly summarize w0, meanonly
        local s0 = r(sum)
        quietly summarize w1, meanonly
        local s1 = r(sum)
        quietly summarize w2, meanonly
        local s2 = r(sum)
        quietly replace r1 = x1 - `s1' / `s0' in `j'
        quietly replace r2 = x2 - `s2' / `s0' in `j'
    }
    quietly keep if status == 1
    * distinct event times, so rank is the time order 1..m
    quietly gen double f_rank = _n
    quietly gen double f_identity = t
    quietly gen double f_log = ln(t)
    local m = _N
    * every correlate runs before the first return, so no r() is clobbered
    foreach fn in rank identity log {
        forvalues k = 1/2 {
            quietly correlate r`k' f_`fn'
            local h_`fn'_`k' = r(rho)
        }
    }
    return scalar m = `m'
    foreach fn in rank identity log {
        forvalues k = 1/2 {
            return scalar h_`fn'_`k' = `h_`fn'_`k''
        }
    }
end

**# PHR1: reported correlations equal the hand-computed transform, three time functions
local ++test_count
capture noisily {
    _phr_data
    quietly finegray x1 x2, compete(status) cause(1) nolog
    assert e(converged) == 1
    assert e(N) == 14
    tempname b
    matrix `b' = e(b)
    local b1 = `b'[1, 1]
    local b2 = `b'[1, 2]
    assert !missing(`b1', `b2')

    foreach fn in rank identity log {
        quietly finegray_phtest, time(`fn')
        tempname P_`fn'
        matrix `P_`fn'' = r(phtest)
    }

    preserve
    _phr_hand `b1' `b2'
    local m = r(m)
    foreach fn in rank identity log {
        forvalues k = 1/2 {
            local h_`fn'_`k' = r(h_`fn'_`k')
        }
    }
    restore

    assert `m' == 8
    foreach fn in rank identity log {
        forvalues k = 1/2 {
            local got = `P_`fn''[`k', 1]
            local want = `h_`fn'_`k''
            assert !missing(`got', `want')
            display as text "  time(`fn') x`k': phtest " %18.15f `got' "  hand " %18.15f `want'
            assert abs(`got' - `want') < 1e-10
            * every cause-1 event enters the correlation
            assert `P_`fn''[`k', 2] == 8
        }
    }
}
if _rc == 0 {
    display as result "  PASS: PHR1 phtest correlations equal the hand-computed Fine-Gray residual-time transform"
    local ++pass_count
}
else {
    display as error "  FAIL: PHR1 phtest hand-computed recovery (rc=`=_rc')"
    local ++fail_count
}

**# PHR2: the hand transform is not vacuous -- a wrong risk set gives a different answer
* Dropping the cause-2 subjects who left before t_j (the Cox risk set instead of
* the subdistribution one) must move the correlation, or PHR1 could not tell the
* two definitions apart on this fixture.
local ++test_count
capture noisily {
    _phr_data
    quietly finegray x1 x2, compete(status) cause(1) nolog
    assert e(converged) == 1
    tempname b
    matrix `b' = e(b)
    local b1 = `b'[1, 1]
    local b2 = `b'[1, 2]
    quietly finegray_phtest, time(rank)
    tempname P
    matrix `P' = r(phtest)
    preserve
    sort t
    quietly gen double eta = `b1' * x1 + `b2' * x2
    quietly gen double r1 = .
    quietly gen double w0 = .
    quietly gen double w1 = .
    forvalues j = 1/`=_N' {
        if status[`j'] != 1 continue
        local tj = t[`j']
        quietly replace w0 = (t >= `tj') * exp(eta)
        quietly replace w1 = w0 * x1
        quietly summarize w0, meanonly
        local s0 = r(sum)
        quietly summarize w1, meanonly
        local s1 = r(sum)
        quietly replace r1 = x1 - `s1' / `s0' in `j'
    }
    quietly keep if status == 1
    quietly gen double f_rank = _n
    quietly correlate r1 f_rank
    local cox_rho = r(rho)
    restore
    assert !missing(`cox_rho', `P'[1, 1])
    display as text "  subdistribution " %12.9f `P'[1, 1] "  cox risk set " %12.9f `cox_rho'
    assert abs(`P'[1, 1] - `cox_rho') > 1e-3
}
if _rc == 0 {
    display as result "  PASS: PHR2 the subdistribution risk set is distinguishable from the Cox risk set"
    local ++pass_count
}
else {
    display as error "  FAIL: PHR2 risk-set discrimination (rc=`=_rc')"
    local ++fail_count
}

**# Summary
macro drop PHR_FIXTURE
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_finegray_phtest_recovery tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _phr
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_finegray_phtest_recovery tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _phr
