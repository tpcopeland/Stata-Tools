* test_fixture_public.do -- canonical public pipeline and its returned payloads
* msm 2.0.0: the graph and export cells left with msm_plot/msm_report/msm_table/
* msm_diagtab/msm_sensitivity; the predict frame payload replaces them.
* Author: Timothy P Copeland, Karolinska Institutet
* guard: catalog adoption; no source repair asserted by this suite.
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

capture program drop _fx_msm_public
program define _fx_msm_public
    args op
    local perturb ""
    if "`op'" != "" local perturb "perturb(`op')"
    qa_fx_a3_seq, clear n(1600) seed(9101) `perturb'
    gen long fx_row = _n
    quietly msm, list
    assert r(n_commands) == 5
    assert "`r(commands)'" == "msm_prepare msm_weight msm_diagnose msm_fit msm_predict"
    quietly msm, detail
    assert r(n_commands) == 5
    quietly msm, status
    assert r(prepared) == 0 & r(fitted) == 0
    quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t) baseline_covariates(l0)
    assert r(n_gap_ids) == 0 & "`r(missing_vars)'" == ""
    quietly msm, status
    assert r(prepared) == 1 & r(weighted) == 0
    assert "`r(id)'" == "id" & "`r(stage)'" == "prepared"
    quietly msm_weight, treat_d_cov(l_t l0) nolog
    local wess = r(ess)
    quietly summarize _msm_weight, meanonly
    local sw = r(sum)
    gen double fx_w2 = _msm_weight^2
    quietly summarize fx_w2, meanonly
    local ess = `sw'^2/r(sum)
    assert !missing(`wess',`ess') & reldif(`wess',`ess') < 1e-10
    quietly msm_diagnose, balance_covariates(l_t l0)
    assert "`r(covariates)'" == "l_t l0"
    matrix fx_expected_balance = r(balance)
    assert rowsof(fx_expected_balance) == 2
    assert "`: rownames fx_expected_balance'" == "l_t l0"
    quietly msm_fit, model(logistic) period_spec(cubic) nolog
    matrix fx_expected_b = e(b)
    matrix fx_expected_V = e(V)
    capture frame drop fxpred
    quietly msm_predict, times(1 3) difference samples(20) seed(9122) frame(fxpred)
    matrix fx_expected_predictions = r(predictions)
    matrix fx_expected_rd = r(rd)
    assert rowsof(fx_expected_predictions) == 2
    * The frame payload is the predictions matrix, row for row.
    frame fxpred {
        assert _N == 6
        forvalues k = 1/2 {
            assert estimate[3*`k'-2] == fx_expected_predictions[`k',2]
            assert estimate[3*`k'-1] == fx_expected_predictions[`k',5]
            assert estimate[3*`k']   == fx_expected_predictions[`k',8]
            assert ll[3*`k'] == fx_expected_rd[`k',2] & ul[3*`k'] == fx_expected_rd[`k',3]
        }
    }
    frame drop fxpred
    quietly msm, status
    assert r(prepared) == 1 & r(weighted) == 1 & r(fitted) == 1
    assert "`r(model)'" == "logistic"
    assert "`r(next_step)'" == "msm_predict"
    assert fx_row == _n
    matrix fx_public_b = fx_expected_b
    matrix fx_public_pred = fx_expected_predictions
end

**# F: canonical panel public readers and returned payloads
local ++test_count
capture noisily _fx_msm_public
if !_rc {
    local ++pass_count
    matrix fx_f_b = fx_public_b
    matrix fx_f_pred = fx_public_pred
    display as result "PASS: F canonical public pipeline/artifacts"
}
else {
    local ++fail_count
    display as error "FAIL: F canonical public pipeline/artifacts (rc=`=_rc')"
}

**# U: unsorted canonical panel retains public reader and export values
* expect: INVARIANT
local ++test_count
capture noisily {
    _fx_msm_public unsorted
    assert !missing(mreldif(fx_f_b,fx_public_b)) & mreldif(fx_f_b,fx_public_b)<1e-10
    assert !missing(fx_f_pred[1,2],fx_public_pred[1,2],fx_f_pred[2,5],fx_public_pred[2,5])
    assert reldif(fx_f_pred[1,2],fx_public_pred[1,2])<1e-10
    assert reldif(fx_f_pred[2,5],fx_public_pred[2,5])<1e-10
}
if !_rc {
    local ++pass_count
    display as result "PASS: U unsorted public pipeline/artifacts"
}
else {
    local ++fail_count
    display as error "FAIL: U unsorted public pipeline/artifacts (rc=`=_rc')"
}

display "RESULT: test_fixture_public tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
do "`qa_dir'/_record_qa_result.do" "test_fixture_public" `test_count' `pass_count' `fail_count'
capture log close _all
if `fail_count' > 0 exit 1
