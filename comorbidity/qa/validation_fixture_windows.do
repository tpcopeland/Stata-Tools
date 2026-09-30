*! validation_fixture_windows.do — exact canonical code-window boundaries
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
set varabbrev off
capture log close _all
log using "validation_fixture_windows.log", replace text nomsg
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
do "`qa_dir'/_qa_metamorphic.do"
capture program drop _fx_windows
program define _fx_windows, rclass
    version 16.0
    args op
    tempfile source
    quietly save `source'
    local tests=0
    local pass=0
    local fail=0
    foreach side in lookback lookforward {
        foreach width in 0 3 {
            local ++tests
            capture noisily {
                quietly use `source', clear
                generate double ref=cond("`side'"=="lookback",mdy(1,4,2020),mdy(1,1,2020))
                format ref %td
                local bounds "lookback(`width') lookforward(0)"
                if "`side'"=="lookforward" local bounds "lookback(0) lookforward(`width')"
                local j=0
                foreach name in mi dm renal meta {
                    local ++j
                    local code : word `j' of I21 E11 N18 C78
                    generate byte want_`name'=0
                    forvalues slot=1/4 {
                        replace want_`name'=1 if substr(dx`slot',1,3)=="`code'"
                    }
                    replace want_`name'=. if cond("`side'"=="lookback",!inrange(date,ref-`width',ref),!inrange(date,ref,ref+`width'))
                }
                qa_state_snapshot, tag(code_window)
                comorbidity dx1-dx4, id(id) charlson(original) merge date(date) refdate(ref) `bounds' inclusive
                qa_state_compare, tag(code_window) allow(data)
                assert charlson==want_mi+want_dm+2*want_renal+6*want_meta
                assert _N==4
                di "ORACLE comorbidity `op' `side'(`width'): all person flags/scores exact"
            }
            local rc=_rc
            if `rc'==0 local ++pass
            else {
                local ++fail
                di as error "FAIL comorbidity window `op' `side' `width' rc=`rc'"
            }
        }
    }
    local ++tests
    capture noisily {
        use `source', clear
        generate double ref=mdy(1,4,2020)
        format ref %td
        * expect: EXACT
        qa_option_domain, command(comorbidity dx1-dx4, id(id) charlson(original) merge date(date) refdate(ref) lookback(@v@) lookforward(0) inclusive) inside(-1;0;3) outside(-2;0.5)
    }
    if _rc==0 local ++pass
    else local ++fail
    local ++tests
    capture noisily {
        use `source', clear
        generate double ref=mdy(1,1,2020)
        format ref %td
        * expect: EXACT
        qa_option_domain, command(comorbidity dx1-dx4, id(id) charlson(original) merge date(date) refdate(ref) lookforward(@v@) inclusive) inside(0;3) outside(-2;0.5)
    }
    if _rc==0 local ++pass
    else local ++fail
    return scalar tests=`tests'
    return scalar pass=`pass'
    return scalar fail=`fail'
end
local tests=0
local pass=0
local fail=0
qa_fx_a5_wide, clear tier(micro)
_fx_windows friendly
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
* expect: EXACT
qa_fx_a5_wide, clear tier(micro) perturb(unsorted)
_fx_windows unsorted
local tests=`tests'+r(tests)
local pass=`pass'+r(pass)
local fail=`fail'+r(fail)
di "RESULT: validation_fixture_windows tests=`tests' pass=`pass' fail=`fail' skip=0"
log close _all
if `fail'>0 exit 1
