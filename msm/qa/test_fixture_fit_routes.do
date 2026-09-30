* test_fixture_fit_routes.do -- canonical native fit parity and unsupported predictions
* Author: Timothy P Copeland, Karolinska Institutet
* guard: finite-sample native estimator parity; no multi-period causal truth claim.
version 16.0
clear all
set more off
set varabbrev off
set processors 1
capture log close _all
local qa_dir "`c(pwd)'"
do "`qa_dir'/_install_msm_isolated.do" "`qa_dir'/.."
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_state.do"
local test_count 0
local pass_count 0
local fail_count 0

capture program drop _fx_fit_route
program define _fx_fit_route
    args model hist op
    local perturb ""
    if "`op'"=="unsorted" local perturb "perturb(unsorted)"
    qa_fx_a3_seq, clear n(1800) seed(9157) `perturb'
    gen long fx_order=_n
    bysort id (period): gen byte fx_sample=sum(y[_n-1])==0 if _n>1
    replace fx_sample=1 if missing(fx_sample)
    by id (period): gen byte fx_lag=cond(_n==1,0,a[_n-1])
    by id (period): gen double fx_cum=sum(a)-a
    by id (period): gen double fx_dur=0
    by id (period): replace fx_dur=cond(a[_n-1]==1,fx_dur[_n-1]+1,0) if _n>1
    gen byte fx_int=a*fx_lag
    sort fx_order
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    quietly msm_weight, treat_d_cov(l_t l0) nolog
    local history ""
    if "`hist'"!="none" local history "history(`hist')"
    quietly msm_fit, model(`model') period_spec(linear) `history' nolog
    matrix fx_route_b=e(b)
    matrix fx_route_v=e(V)
    local fitted_n=e(N)
    assert _msm_esample==fx_sample
    assert e(msm_n_clusters)==1800
    local terms ""
    if "`hist'"=="lag1" {
        assert _msm_hist_lag1==fx_lag
        local terms "_msm_hist_lag1"
    }
    if "`hist'"=="cumulative" {
        assert _msm_hist_cum==fx_cum
        local terms "_msm_hist_cum"
    }
    if "`hist'"=="duration" {
        assert _msm_hist_dur==fx_dur
        local terms "_msm_hist_dur"
    }
    if "`hist'"=="interaction" {
        assert _msm_hist_lag1==fx_lag & _msm_hist_int==fx_int
        local terms "_msm_hist_int"
    }
    tempname fitted
    estimates store `fitted'
    if "`model'"=="logistic" {
        quietly glm y a period `terms' [pw=_msm_weight] if fx_sample, family(binomial) link(logit) vce(cluster id) nolog
    }
    else if "`model'"=="linear" {
        quietly regress y a period [pw=_msm_weight] if fx_sample, vce(cluster id)
    }
    else {
        preserve
        gen double fx_enter=period
        gen double fx_exit=period+1
        quietly stset fx_exit [pw=_msm_weight] if fx_sample, enter(fx_enter) failure(y)
        quietly stcox a, vce(cluster id) nolog
    }
    matrix fx_native_b=e(b)
    matrix fx_native_v=e(V)
    assert e(N)==`fitted_n'
    assert !missing(mreldif(fx_route_b,fx_native_b),mreldif(fx_route_v,fx_native_v))
    assert mreldif(fx_route_b,fx_native_b)<1e-10
    assert mreldif(fx_route_v,fx_native_v)<1e-9
    local pkgstripe : colfullnames fx_route_b
    local nativestripe : colfullnames fx_native_b
    assert "`pkgstripe'"=="`nativestripe'"
    if "`model'"=="cox" restore
    estimates restore `fitted'
    estimates drop `fitted'
    if "`model'"!="logistic" {
        tempfile refusal
        capture log close fxref
        log using "`refusal'", text name(fxref)
        qa_state_snapshot, tag(fitroute) rreturn
        capture noisily msm_predict, times(1 3) samples(10) seed(9160)
        local rc=_rc
        qa_state_compare, tag(fitroute)
        log close fxref
        assert `rc'==198
        python: assert 'currently only supports logistic model' in open(__import__('sfi').Macro.getLocal('refusal'),encoding='utf-8').read()
    }
    else {
        quietly msm_predict, times(1 3) samples(10) seed(9160)
        matrix fx_route_predictions=r(predictions)
        assert rowsof(fx_route_predictions)==2
        assert !missing(fx_route_predictions[1,1],fx_route_predictions[2,1])
    }
end

foreach route in logistic linear cox lag1 cumulative duration interaction {
    foreach op in friendly unsorted {
        **# F/U: documented fit routes and independently constructed retained sample/history
        * expect: INVARIANT under unsorted input; unsupported non-logistic prediction REFUSED
        local ++test_count
        capture noisily {
            local model "logistic"
            local hist "none"
            if inlist("`route'","linear","cox") local model "`route'"
            if inlist("`route'","lag1","cumulative","duration","interaction") local hist "`route'"
            _fx_fit_route "`model'" "`hist'" "`op'"
            if "`op'"=="friendly" {
                matrix fx_friendly_b=fx_route_b
                matrix fx_friendly_v=fx_route_v
            }
            else {
                assert !missing(mreldif(fx_friendly_b,fx_route_b),mreldif(fx_friendly_v,fx_route_v))
                assert mreldif(fx_friendly_b,fx_route_b)<1e-10
                assert mreldif(fx_friendly_v,fx_route_v)<1e-9
            }
        }
        if !_rc {
            local ++pass_count
            display as result "PASS: `route'/`op' native fit and state"
        }
        else {
            local ++fail_count
            display as error "FAIL: `route'/`op' (rc=`=_rc')"
        }
    }
}
do "`qa_dir'/_record_qa_result.do" test_fixture_fit_routes `test_count' `pass_count' `fail_count' 0
display "RESULT: test_fixture_fit_routes tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count'>0 exit 1
