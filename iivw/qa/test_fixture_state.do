*! test_fixture_state.do — stored-estimate inspection preserves caller columns
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
local qa_dir "`c(pwd)'"
local pkg_dir=regexr("`qa_dir'","/qa$","")
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap
do "`qa_dir'/_qa_fx_a3.do"
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_metamorphic.do"

capture program drop _fx_diag_state
program define _fx_diag_state, rclass
    version 16.0
    args op
    tempfile source
    quietly save `source'
    local tests=0
    local pass=0
    local fail=0
    foreach active in present absent {
        foreach route in success refusal {
            local ++tests
            capture noisily {
                quietly use `source', clear
                estimates clear
                quietly regress y time
                estimates store fx_u
                estimates store fx_w
                estimates store fx_a
                if "`active'"=="absent" ereturn clear
                * Existing native markers are deliberately interleaved with
                * ordinary columns. A value-only comparison misses this leak.
                order id _est_fx_u time _est_fx_w y _est_fx_a
                tempvar prior_pred prior_sample next_pred
                if "`active'"=="present" {
                    quietly predict double `prior_pred', xb
                    generate byte `prior_sample'=e(sample)
                }
                unab before : _all
                qa_state_snapshot, tag(diag_state)
                if "`route'"=="success" {
                    iivw_diagnose time, unweighted(fx_u) weighted(fx_w) adjusted(fx_a)
                    assert r(sample_identical)==1 & r(decomposable)==1
                    tempname D
                    matrix `D'=r(decomp)
                    assert `D'[1,1]==0 & `D'[2,1]==0 & `D'[3,1]==0
                    matrix drop `D'
                }
                else {
                    * expect: REFUSED
                    capture noisily iivw_diagnose no_such_coefficient, unweighted(fx_u) weighted(fx_w) adjusted(fx_a)
                    assert _rc==111
                }
                unab after : _all
                assert "`before'"=="`after'"
                qa_state_compare, tag(diag_state) keep
                if "`active'"=="present" {
                    assert `prior_sample'==e(sample)
                    quietly predict double `next_pred', xb
                    assert `prior_pred'==`next_pred'
                    drop `next_pred'
                    qa_state_compare, tag(diag_state)
                }
                else qa_state_drop, tag(diag_state)
                di "ORACLE diagnose `op' active-`active' `route': exact column/data/e/state preservation"
            }
            local case_rc=_rc
            if `case_rc'==0 local ++pass
            else {
                local ++fail
                di as error "FAIL diagnose `op' `active' `route' rc=`case_rc'"
            }
        }
    }
    return scalar tests=`tests'
    return scalar pass=`pass'
    return scalar fail=`fail'
end

local tests=0
local pass=0
local fail=0
qa_fx_a3_visit, clear tier(unit)
_fx_diag_state friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a3_visit, clear tier(unit) perturb(unsorted)
_fx_diag_state unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
display "RESULT: test_fixture_state tests=`tests' pass=`pass' fail=`fail' skip=0"
iivw_qa_sandbox_restore
if `fail'>0 exit 1
