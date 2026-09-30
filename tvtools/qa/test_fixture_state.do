*! test_fixture_state.do — caller legacy globals across success and refusal
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "test_fixture_state.log", replace text nomsg
local qa_dir "`c(pwd)'"
local pkg_dir=regexr("`qa_dir'","/qa$","")
adopath ++ "`pkg_dir'"
do "`qa_dir'/_qa_fx_a1.do"
do "`qa_dir'/_qa_state.do"
do "`qa_dir'/_qa_metamorphic.do"
program define _fx_globals, rclass
    args op
    local tests=0
    local pass=0
    local fail=0

    tempfile source
    save `source'
    foreach status in absent present present_empty native {
        foreach route in success refusal {
            local ++tests
            capture noisily {
                use `source', clear
                capture macro drop S_1 S_2
                if "`status'"=="present" {
                    mata: st_global("S_1",char(36)+"QA_SENTINEL"+char(34)+"one")
                    mata: st_global("S_2",char(96)+"two"+char(39))
                }
                if "`status'"=="present_empty" {
                    global S_1 ""
                    global S_2 ""
                    mata: assert(sum(st_dir("global","macro","*"):=="S_1")==0)
                    mata: assert(sum(st_dir("global","macro","*"):=="S_2")==0)
                }
                if "`status'"=="native" {
                    generate double native_value=_n
                    quietly ttest native_value==0
                    mata: assert(sum(st_dir("global","macro","*"):=="S_1")==1)
                    mata: assert(sum(st_dir("global","macro","*"):=="S_2")==1)
                    mata: assert(strtoreal(st_global("S_1"))==st_nobs())
                    mata: assert(strtoreal(st_global("S_2"))==(st_nobs()+1)/2)
                }
                qa_state_snapshot, tag(sglobals)
                if "`route'"=="success" {
                    tvweight a, covariates(i.s##i.x2) generate(got) nolog
                    qa_state_compare, tag(sglobals) allow(data rng)
                }
                else {
                    * expect: REFUSED
                    qa_option_effect, command(tvweight a, covariates(i.s##i.x2) wtype(@v@)) values(invalid) returns(r(N)) refused cause(wtype)
                    qa_state_compare, tag(sglobals)
                }
                if "`status'"=="native" {
                    quietly ttest native_value==0
                    assert r(N_1)==_N & r(mu_1)==(_N+1)/2
                    mata: assert(strtoreal(st_global("S_1"))==st_nobs())
                    mata: assert(strtoreal(st_global("S_2"))==(st_nobs()+1)/2)
                }
                di "ORACLE legacy globals `op' `status' `route': bytes/existence preserved"
            }
            local case_rc=_rc
            capture restore
            if `case_rc'==0 local ++pass
            else {
                local ++fail
                di as error "FAIL globals `op' `status' `route' rc=`case_rc'"
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
qa_fx_a1_sat, clear
_fx_globals friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a1_sat, clear perturb(unsorted)
_fx_globals unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
di "RESULT: test_fixture_state tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
