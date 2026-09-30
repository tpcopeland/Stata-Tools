*! test_fixture_error_returns.do -- cold strict empty/full prior r() and named refusals
* Timothy P Copeland, Karolinska Institutet
version 17.0
set processors 1
set more off
capture log close _all
log using "test_fixture_error_returns.log",text replace
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
local tests=0
local pass=0
local fail=0
foreach context in empty full {
    foreach strict in off on {
        foreach route in sheet singleton {
            local ++tests
            capture noisily {
                clear all
                quietly do "_qa_fx_a1.do"
                quietly do "_qa_state.do"
                qa_fx_a1_logit,clear n(360) seed(541)
                if "`route'"=="singleton" keep in 1
                generate double modelse=1
                mata: mata set matastrict `strict'
                tempfile book refusal
                capture log close refusal
                log using "`refusal'",text replace name(refusal)
                quietly do "_simtab_qa_prior_r.do" `context'
                if "`context'"=="full" assert r(caller_scalar)==1/7 & "`r(caller_macro)'"=="CALLER macro payload" & r(caller_matrix)[2,2]==4.123456789012345
                else assert missing(r(caller_scalar)) & "`r(caller_macro)'"==""
                qa_state_snapshot,tag(errorr) rreturn
                local sheet "Truth"
                if "`route'"=="sheet" local sheet "Bad/Sheet"
                * expect: REFUSED
                capture noisily simtab xcat,estimate(y) se(modelse) true(0) metrics(mean bias empse n) digits(6) sedigits(6) xlsx("`book'.xlsx") sheet("`sheet'")
                local candidate_rc=_rc
                capture noisily qa_state_compare,tag(errorr)
                local fp_rc=_rc
                log close refusal
                if "`route'"=="sheet" {
                    assert `candidate_rc'==198
                    mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("refusal"))),"sheet name contains characters not allowed by excel"))))
                }
                else {
                    assert `candidate_rc'==2001
                    mata: st_local("named",strofreal(any(strpos(strlower(cat(st_local("refusal"))),"usable replication"))))
                }
                assert `named'==1 & `fp_rc'==0 & "`c(matastrict)'"=="`strict'"
                capture confirm file "`book'.xlsx"
                assert _rc==601
                display "ERROR_R `context' strict(`strict') `route': named rc=`candidate_rc'; exact original scalar/macro/matrix r plus non-r caller state before logclose"
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
