*! test_fixture_exog_state.do — native globals on analytical success and late export refusal
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
do _iivw_qa_common.do
iivw_qa_bootstrap
do _qa_fx_a3.do
do _qa_state.do
capture program drop _fx_exog_state
program define _fx_exog_state, rclass
    version 16.0
    args op
    drop if !visit
    iivw_weight, id(id) time(time) visit_cov(lag_y) maxfu(4) wtype(iivw) nolog
    iivw_fit y, vce(fixed) timespec(linear) nolog
    tempname visitB nextB fh
    matrix `visitB'=e(b)
    local pass=0
    local fail=0
    foreach status in absent present present_empty native {
        foreach route in success late_refusal {
            capture noisily {
                capture macro drop S_1 S_2
                if "`status'"=="present" {
                    foreach key in S_1 S_2 {
                        mata: st_global(st_local("key"),char(36)+"OPAQUE"+char(34)+char(96)+"native"+char(39))
                    }
                }
                if "`status'"=="present_empty" {
                    global S_1 ""
                    global S_2 ""
                    mata: assert(sum(st_dir("global","macro","*"):=="S_1")==0)
                }
                if "`status'"=="native" {
                    ttest y==0
                    mata: assert(sum(st_dir("global","macro","*"):=="S_1")==1)
                }
                qa_state_snapshot, tag(exog_global)
                local exportopts ""
                tempfile workbook cause_log
                if "`route'"=="late_refusal" local exportopts `"xlsx("`workbook'.xlsx") sheet(Bad/Sheet) replace"'
                log using `cause_log', name(exog_cause) text replace nomsg
                capture noisily iivw_exogtest y, id(id) time(time) maxfu(4) generate(_exog_) nolog `exportopts'
                local call_rc=_rc
                local rows=rowsof(r(results))
                local hr=r(results)[1,7]
                local nmodels=r(n_models)
                log close exog_cause
                assert `nmodels'>0 & `rows'>0 & !missing(`hr')
                if "`route'"=="success" assert `call_rc'==0
                else {
                    local named=0
                    file open `fh' using `cause_log', read text
                    file read `fh' line
                    while !r(eof) {
                        if strpos(`"`macval(line)'"',"sheet() contains an invalid Excel worksheet character") local named=1
                        file read `fh' line
                    }
                    file close `fh'
                    assert `call_rc'==198 & `named'==1
                    capture confirm file "`workbook'.xlsx"
                    assert _rc==601
                }
                confirm variable _exog_y_lag1
                * Analytical output is retained on the documented late export
                * refusal; removing that one owned column must expose an exact
                * match of every original data byte/order and caller state.
                preserve
                drop _exog_y_lag1
                capture noisily qa_state_compare, tag(exog_global)
                local state_rc=_rc
                restore
                drop _exog_y_lag1
                if `state_rc' exit `state_rc'
                matrix `nextB'=e(b)
                assert mreldif(`visitB',`nextB')<1e-12
                predict double native_next, mu
                assert !missing(native_next) & reldif(native_next,_b[_cons]+_b[time]*time)<1e-10
                drop native_next
                quietly summarize y, meanonly
                local wantN=r(N)
                local wantmean=r(mean)
                ttest y==0
                assert r(N_1)==`wantN' & reldif(r(mu_1),`wantmean')<1e-12
                assert $S_1==`wantN' & reldif(real("$S_2"),`wantmean')<1e-12
                display "ORACLE VISIT exog `op' `status' `route': analytical payload, exact non-r caller state and next prediction/ttest"
            }
            local rc=_rc
            if `rc'==0 local ++pass
            else {
                local ++fail
                capture log close exog_cause
                capture drop _exog_y_lag1 native_next
                display as error "FAIL VISIT exog state `op' `status' `route' rc=`rc'"
            }
        }
    }
    return scalar tests=8
    return scalar pass=`pass'
    return scalar fail=`fail'
end
local tests=0
local pass=0
local fail=0
qa_fx_a3_visit, clear tier(unit) n(100) seed(931)
_fx_exog_state friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a3_visit, clear tier(unit) n(100) seed(931) perturb(unsorted)
_fx_exog_state unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
display "RESULT: test_fixture_exog_state tests=`tests' pass=`pass' fail=`fail' skip=0"
iivw_qa_sandbox_restore
if `fail'>0 exit 1
