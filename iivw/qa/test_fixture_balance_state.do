*! test_fixture_balance_state.do — native/opaque/absent balance refit state controls
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
do _iivw_qa_common.do
iivw_qa_bootstrap
do _qa_fx_a3.do
do _qa_state.do
capture program drop _fx_balance_state
program define _fx_balance_state, rclass
    version 16.0
    args op
    drop if !visit
    iivw_weight, id(id) time(time) visit_cov(lag_y) maxfu(4) wtype(iivw) nolog
    iivw_fit y, vce(fixed) timespec(linear) nolog
    tempname visitB
    matrix `visitB'=e(b)
    local pass=0
    local fail=0
    foreach status in absent present present_empty native {
        foreach route in success refusal {
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
                qa_state_snapshot, tag(balance_global)
                if "`route'"=="success" {
                    iivw_balance
                    assert r(N)>0 & r(N)<=_N & r(n_ids)==100
                    assert !missing(r(ess)) & r(ess)>0 & r(ess)<=r(N)
                    qa_state_compare, tag(balance_global)
                }
                else {
                    capture noisily iivw_balance, cvcut(-1)
                    local call_rc=_rc
                    assert `call_rc'==198
                    qa_state_compare, tag(balance_global)
                }
                quietly summarize y, meanonly
                local wantN=r(N)
                local wantmean=r(mean)
                ttest y==0
                assert r(N_1)==`wantN' & reldif(r(mu_1),`wantmean')<1e-12
                assert $S_1==`wantN' & reldif(real("$S_2"),`wantmean')<1e-12
                di "ORACLE VISIT balance `op' `status' `route': exact state and next native ttest"
            }
            local rc=_rc
            if `rc'==0 local ++pass
            else {
                local ++fail
                di as error "FAIL VISIT balance state `op' `status' `route' rc=`rc'"
            }
        }
    }
    tempname nextB
    iivw_fit y, vce(fixed) timespec(linear) nolog
    matrix `nextB'=e(b)
    assert mreldif(`visitB',`nextB')<1e-12
    predict double native_next, mu
    assert !missing(native_next) & reldif(native_next,_b[_cons]+_b[time]*time)<1e-10
    drop native_next
    return scalar tests=8
    return scalar pass=`pass'
    return scalar fail=`fail'
end
local tests=0
local pass=0
local fail=0
qa_fx_a3_visit, clear tier(unit) n(100) seed(931)
_fx_balance_state friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a3_visit, clear tier(unit) n(100) seed(931) perturb(unsorted)
_fx_balance_state unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
display "RESULT: test_fixture_balance_state tests=`tests' pass=`pass' fail=`fail' skip=0"
iivw_qa_sandbox_restore
if `fail'>0 exit 1
