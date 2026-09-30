*! test_fixture_error_returns.do -- genuine empty/full prior r() before analytic payload
* Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set processors 1
set more off
set graphics off
capture log close _all
log using "test_fixture_error_returns.log",text replace
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
quietly do "_qa_fx_a7.do"
quietly do "_qa_state.do"
capture program drop _qa_rain_prior_r
program define _qa_rain_prior_r,rclass
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
        foreach route in early {
            local ++tests
            capture noisily {
                qa_fx_a7_labelled, clear tier(micro)
                set varabbrev `setting'
                tempfile refusal
                capture log close refusal
                log using "`refusal'",text replace name(refusal)
                _qa_rain_prior_r `context'
                if "`context'"=="full" assert r(caller_scalar)==1/7 & "`r(caller_macro)'"=="CALLER macro payload" & r(caller_matrix)[2,2]==4.123456789012345
                else assert missing(r(caller_scalar)) & "`r(caller_macro)'"==""
                qa_state_snapshot,tag(errorr) rreturn
                capture noisily raincloud x, jitter(-1)
                local candidate_rc=_rc
                capture noisily qa_state_compare,tag(errorr)
                local fp_rc=_rc
                log close refusal
                assert `candidate_rc'==198
                mata: st_local("named",strofreal(any(strpos(cat(st_local("refusal")),"jitter() must be between 0 and 1"))))
                assert `named'==1 & `fp_rc'==0
                display "ERROR_R `context' varabbrev(`setting') `route': named rc=`candidate_rc'; exact prior r scalars/macros/matrices and all non-r caller state retained before logclose"
            }
            if _rc local ++fail
            else local ++pass
        }
    }
}
display "RESULT: test_fixture_error_returns tests=`tests' pass=`pass' fail=`fail' skip=0"
capture log close refusal
log close
if `fail' exit 9
