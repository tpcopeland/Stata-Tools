*! test_fixture_files.do — native filename macro state across file-backed routes
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "test_fixture_files.log", replace text nomsg
local qa_dir "`c(pwd)'"
local pkg_dir=regexr("`qa_dir'","/qa$","")
adopath ++ "`pkg_dir'"
tempfile sandbox
capture mkdir "`sandbox'_plus"
capture mkdir "`sandbox'_personal"
sysdir set PLUS "`sandbox'_plus"
sysdir set PERSONAL "`sandbox'_personal"
quietly net install codescan, from("`pkg_dir'/../codescan") replace
do "`qa_dir'/_qa_fx_a5.do"
do "`qa_dir'/_qa_state.do"
capture program drop _fx_file_state
program define _fx_file_state, rclass
    version 16.0
    args op
    tempfile source
    quietly save `source'
    local tests=0
    local pass=0
    local fail=0
    foreach status in absent present_empty opaque native {
        foreach route in collapse merge refusal {
            local ++tests
            capture noisily {
                quietly use `source', clear
                generate double ref=mdy(1,4,2020)
                format ref %td
                if "`status'"!="native" capture macro drop S_FN S_FNDATE
                if "`status'"=="present_empty" {
                    global S_FN ""
                    global S_FNDATE ""
                    mata: assert(sum(st_dir("global","macro","*"):=="S_FN")==0)
                    mata: assert(sum(st_dir("global","macro","*"):=="S_FNDATE")==0)
                }
                if "`status'"=="opaque" {
                    mata: st_global("S_FN",char(36)+"FILE_SENTINEL"+char(34)+"one")
                    mata: st_global("S_FNDATE",char(96)+"two"+char(39))
                }
                if "`status'"=="native" {
                    mata: assert(sum(st_dir("global","macro","*"):=="S_FN")==1)
                    mata: assert(st_global("S_FN")==st_local("source"))
                    mata: assert(sum(st_dir("global","macro","*"):=="S_FNDATE")==1)
                }
                qa_state_snapshot, tag(file_state)
                if "`route'"=="refusal" {
                    * expect: REFUSED
                    capture noisily comorbidity dx1-dx4, id(id) charlson(original) date(date) refdate(ref) lookback(-2)
                    assert _rc==198
                    qa_state_compare, tag(file_state)
                }
                else {
                    local shape "`route'"
                    if "`route'"=="row" local shape ""
                    comorbidity dx1-dx4, id(id) charlson(original) `shape' date(date) refdate(ref) lookback(3) inclusive
                    assert _N==4
                    qa_state_compare, tag(file_state) allow(data sort)
                }
                * The next native use must set its own filename normally.
                quietly use `source', clear
                assert _N==4
                mata: assert(st_global("S_FN")==st_local("source"))
                di "ORACLE comorbidity file macros `op' `status' `route': exact bytes/existence and next use"
            }
            local rc=_rc
            if `rc'==0 local ++pass
            else {
                local ++fail
                di as error "FAIL comorbidity file macros `op' `status' `route' rc=`rc'"
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
qa_fx_a5_wide, clear tier(micro)
_fx_file_state friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(unsorted)
_fx_file_state unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
di "RESULT: test_fixture_files tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
