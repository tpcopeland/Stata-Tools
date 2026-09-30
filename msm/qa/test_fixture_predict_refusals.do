* test_fixture_predict_refusals.do -- strict seeded and late prediction transactions
* Author: Timothy P Copeland, Karolinska Institutet
* guard: explicit boundary fault injection proves error cleanup, not a DGP failure mode.
version 16.0
clear all
set more off
set varabbrev off
set processors 1
set seed 9162
capture log close _all
local qa_dir "`c(pwd)'"
do "`qa_dir'/_install_msm_isolated.do" "`qa_dir'/.."
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_state.do"
local test_count 0
local pass_count 0
local fail_count 0

capture program drop _fx_caller_r
program define _fx_caller_r, rclass
    tempname payload
    matrix `payload'=(1,2\3,4)
    return matrix payload=`payload'
    return scalar fxscalar=17/120
    mata: st_local("bait", "literal " + char(36) + "bait " + char(96) + "tick" + char(39) + char(34))
    return local fxbait `"`macval(bait)'"'
end

foreach cell in strategy times absent opaque draws persist {
    **# U: actual early/support refusals and planted engine/persistence failures
    * expect: REFUSED with full caller data/order/e/r/RNG/globals preserved
    local ++test_count
    capture noisily {
        * Reload original programs so planted failures do not survive a cell.
        capture program drop msm_predict
        capture program drop _msm_mat_save
        foreach fn in _msm_mvn_factor _msm_predict_feature _msm_predict_vectorized _msm_pctile _msm_diff_pctile {
            capture mata: mata drop `fn'()
        }
        quietly run "`qa_dir'/../msm_predict.ado"
        capture macro drop MSM_UUID_SEQ
        qa_fx_a3_seq, clear n(1000) seed(9163) perturb(unsorted)
        quietly msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(l_t)
        quietly msm_weight, treat_d_cov(l_t) nolog
        quietly msm_fit, period_spec(linear) nolog
        quietly msm_predict, times(1 3) samples(10) seed(9164)
        matrix fx_before_predictions=r(predictions)
        * Preserve a genuinely foreign active fit and its predictions on failure.
        quietly regress l_t a l0
        local command "times(1 3) samples(10) seed(9165)"
        local expected_rc 198
        local cause "strategy() must be"
        if "`cell'"=="strategy" local command "`command' strategy(bogus)"
        if inlist("`cell'","times","absent","opaque") {
            local command "times(99) samples(10) seed(9165)"
            local cause "exceeds the fitted risk-set support"
        }
        if "`cell'"=="absent" macro drop MSM_UUID_SEQ
        if "`cell'"=="opaque" {
            mata: st_global("MSM_UUID_SEQ", "literal " + char(36) + "bait " + char(96) + "tick" + char(39))
            local command "times(99) samples(10)"
        }
        if "`cell'"=="draws" {
            local expected_rc 3498
            local cause "planted prediction draw failure"
            mata: mata drop _msm_predict_vectorized()
            mata: void _msm_predict_vectorized(string scalar b, string scalar bu, string scalar f, string scalar k, string scalar c, string scalar a, string scalar p, string scalar s, string scalar t, string scalar ty, string scalar kn, string scalar df, real scalar base, real scalar last, real scalar n, real scalar deg, string scalar result, string scalar m0, string scalar m1) { real scalar draw; draw=rnormal(1,1,0,1); errprintf("planted prediction draw failure\n"); _error(3498); }
        }
        if "`cell'"=="persist" {
            local expected_rc 603
            local cause "planted prediction persistence failure"
            capture program drop _msm_mat_save
            tempfile fault_source
            tempname fault_handle
            file open `fault_handle' using "`fault_source'", write text replace
            file write `fault_handle' "program define _msm_mat_save" _n
            file write `fault_handle' `"display as error "planted prediction persistence failure""' _n
            file write `fault_handle' "exit 603" _n "end" _n
            file close `fault_handle'
            run "`fault_source'"
        }
        tempfile refusal
        capture log close fxref
        log using "`refusal'", text name(fxref)
        if "`cell'"=="absent" return clear
        else _fx_caller_r
        qa_state_snapshot, tag(predictref) rreturn predict(xb stdp)
        capture noisily msm_predict, `command'
        local command_rc=_rc
        qa_state_compare, tag(predictref)
        log close fxref
        assert `command_rc'==`expected_rc'
        assert !missing(mreldif(_msm_pred_matrix,fx_before_predictions))
        assert mreldif(_msm_pred_matrix,fx_before_predictions)==0
        python: assert __import__('sfi').Macro.getLocal('cause') in open(__import__('sfi').Macro.getLocal('refusal'),encoding='utf-8').read()
    }
    if !_rc {
        local ++pass_count
        display as result "PASS: `cell' full prediction refusal"
    }
    else {
        local ++fail_count
        display as error "FAIL: `cell' prediction refusal (rc=`=_rc')"
        capture log close fxref
    }
}
capture program drop msm_predict
capture program drop _msm_mat_save
capture mata: mata drop _msm_predict_vectorized()
do "`qa_dir'/_record_qa_result.do" test_fixture_predict_refusals `test_count' `pass_count' `fail_count' 0
display "RESULT: test_fixture_predict_refusals tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count'>0 exit 1
