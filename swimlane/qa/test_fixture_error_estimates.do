*! test_fixture_error_estimates.do -- active native estimates and empty/full prior r() on named refusals
* Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set more off
set graphics off
capture log close _all
log using "test_fixture_error_estimates.log",text replace
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
quietly do "_qa_fx_a4.do"
quietly do "_qa_state.do"
capture program drop _qa_swim_prior_r
program define _qa_swim_prior_r,rclass
    version 16.0
    args context
    return clear
    if "`context'"=="full" {
        tempname M
        matrix `M'=(1/7,-17\.,4.123456789012345)
        matrix rownames `M'=first second
        matrix colnames `M'=risk uncertainty
        return scalar caller_scalar=1/7
        return local caller_macro "CALLER macro payload"
        return matrix caller_matrix=`M'
    }
end
local tests=0
local pass=0
local fail=0
foreach context in empty full {
    foreach setting in on off {
        foreach route in early late {
            local ++tests
            capture noisily {
                if "`route'"=="late" {
                    * expect: REFUSED
                    qa_fx_a4_spells,clear tier(micro) perturb(overlap)
                }
                else qa_fx_a4_spells,clear tier(micro)
                quietly regress stop start i.category
                set varabbrev `setting'
                tempfile refusal
                capture log close refusal
                log using "`refusal'",text replace name(refusal)
                _qa_swim_prior_r `context'
                if "`context'"=="full" assert r(caller_scalar)==1/7 & "`r(caller_macro)'"=="CALLER macro payload" & r(caller_matrix)[2,2]==4.123456789012345
                else assert missing(r(caller_scalar)) & "`r(caller_macro)'"==""
                qa_state_snapshot,tag(errorr) rreturn predict(xb stdp)
                if "`route'"=="early" {
                    capture noisily swimlane, id(id) start(start) nograph
                    local candidate_rc=_rc
                }
                else {
                    capture noisily swimlane, id(id) start(start) stop(stop) state(category) maxids(all) intervalcheck(error) nograph
                    local candidate_rc=_rc
                }
                capture noisily qa_state_compare,tag(errorr)
                local fp_rc=_rc
                log close refusal
                if "`route'"=="early" {
                    assert `candidate_rc'==198
                    mata: st_local("named",strofreal(any(strpos(cat(st_local("refusal")),"start() requires stop()"))))
                }
                else {
                    assert `candidate_rc'==459
                    mata: st_local("named",strofreal(any(strpos(cat(st_local("refusal")),"state intervals contain"))))
                }
                assert `named'==1 & `fp_rc'==0
                display "ERROR_R `context' varabbrev(`setting') `route': named rc=`candidate_rc'; exact prior r scalars/macros/matrices and all non-r caller state retained before logclose"
            }
            if _rc local ++fail
            else local ++pass
        }
    }
}
display "RESULT: test_fixture_error_estimates tests=`tests' pass=`pass' fail=`fail' skip=0"
capture log close refusal
log close
if `fail' exit 9
