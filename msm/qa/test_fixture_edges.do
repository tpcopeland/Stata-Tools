* test_fixture_edges.do -- limiting panels and incomplete baseline contracts
* Author: Timothy P Copeland, Karolinska Institutet
* guard: partial-baseline refusal sort fingerprint is red on pre-fix 1e593bb7; one-period oracle adds coverage.
version 16.0
clear all
set more off
set varabbrev off
set processors 1
capture log close _all
local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_state.do"
local test_count 0
local pass_count 0
local fail_count 0

**# U: single_period -- exact weighted binary mean oracle
local ++test_count
capture noisily {
    forvalues fx_seed = 9109/9111 {
    tempname b0 b1 p0 p1 mean0 mean1
    qa_fx_a3_seq, clear n(1600) k(1) seed(`fx_seed')
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    quietly msm_validate
    assert r(n_errors) == 0
    quietly msm_weight, treat_d_cov(l_t l0) nolog
    forvalues aa = 0/1 {
        gen double fx_num`aa' = _msm_weight*y if a == `aa'
        quietly summarize fx_num`aa', meanonly
        scalar `mean`aa'' = r(sum)
        quietly summarize _msm_weight if a == `aa', meanonly
        scalar `mean`aa'' = `mean`aa''/r(sum)
    }
    quietly msm_fit, model(logistic) period_spec(none) nolog
    matrix `b0' = e(b)
    assert e(N) == 1600 & e(msm_n_clusters) == 1600
    quietly msm_predict, times(0) difference samples(20) seed(`fx_seed')
    matrix `p0' = r(predictions)
    * Exact closed-form arm means are checked to 1e-6 numerical probability
    * precision. Three fixed-seed GLM probes gave maximum errors 2.7e-8;
    * this numerical allowance is separate from statistical/MC recovery SE.
    display "WEIGHTED-MEAN seed=`fx_seed' error0=" %21.16g (`p0'[1,2]-`mean0') " error1=" %21.16g (`p0'[1,5]-`mean1')
    assert !missing(`p0'[1,2], `p0'[1,5], `mean0', `mean1')
    assert abs(`p0'[1,2]-`mean0') < 1e-6
    assert abs(`p0'[1,5]-`mean1') < 1e-6
    * expect: INVARIANT
    qa_fx_a3_seq, clear n(1600) seed(`fx_seed') perturb(single_period)
    assert r(k) == 1 & _N == 1600
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    assert r(n_periods) == 1 & r(n_ids) == 1600
    quietly msm_validate
    assert r(n_errors) == 0
    quietly msm_weight, treat_d_cov(l_t l0) nolog
    quietly msm_fit, model(logistic) period_spec(none) nolog
    matrix `b1' = e(b)
    assert e(N) == 1600 & e(msm_n_clusters) == 1600
    quietly msm_predict, times(0) difference samples(20) seed(`fx_seed')
    matrix `p1' = r(predictions)
    assert !missing(mreldif(`b0', `b1')) & mreldif(`b0', `b1') < 1e-12
    assert abs(`p1'[1,2]-`mean0') < 1e-6 & abs(`p1'[1,5]-`mean1') < 1e-6
    }
}
if _rc == 0 {
    local ++pass_count
    display "PASS: U: single_period exact weighted binary means"
}
else {
    local ++fail_count
    display "FAIL: U: single_period exact weighted binary means (rc=`=_rc')"
}

**# U: miss_partial -- incomplete baseline mapping is refused atomically
local ++test_count
capture noisily {
    qa_fx_a3_seq, clear n(1600) seed(9109)
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    assert r(n_ids) == 1600
    * expect: REFUSED
    qa_fx_a3_seq, clear n(1600) seed(9109) perturb(miss_partial)
    assert !missing(r(perturb_n_miss_partial)) & r(perturb_n_miss_partial) > 0
    gen long fx_order = _n
    quietly regress y l_t
    tempfile msg
    tempname lh fh
    capture log close _all
    log using "`msg'", text replace name(`lh') nomsg
    qa_state_snapshot, tag(fxpartial)
    capture noisily msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    local fx_rc = _rc
    assert `fx_rc' == 198
    qa_state_compare, tag(fxpartial)
    log close `lh'
    file open `fh' using "`msg'", read text
    file read `fh' line
    local cause 0
    while r(eof) == 0 {
        if strpos(`"`line'"', "variable(s) vary within id: l0") local cause 1
        file read `fh' line
    }
    file close `fh'
    assert `cause' == 1 & fx_order == _n
}
if _rc == 0 {
    local ++pass_count
    display "PASS: U: miss_partial baseline mapping refusal"
}
else {
    local ++fail_count
    display "FAIL: U: miss_partial baseline mapping refusal (rc=`=_rc')"
}

do "`qa_dir'/_record_qa_result.do" test_fixture_edges `test_count' `pass_count' `fail_count' 0
display "RESULT: test_fixture_edges tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1
