*! test_fixture_error_payload.do -- late export failure retains analytical publication
* Timothy P Copeland, Karolinska Institutet
version 17.0
clear all
set processors 1
set more off
capture log close _all
log using "test_fixture_error_payload.log", text replace
local pkgdir=regexr("`c(pwd)'","/qa$","")
adopath ++ "`pkgdir'"
quietly do "_qa_fx_a7.do"
quietly do "_qa_state.do"
local tests=0
local pass=0
local fail=0
foreach strict in off on {
    local ++tests
    qa_fx_a7_files, clear tier(micro)
    local root `"`r(root)'"'
    local missingpath `"`r(path_missing)'"'
    local target=subinstr(`"`macval(missingpath)'"',".xlsx",".csv",.)
    qa_fx_a7_labelled, clear tier(micro)
    capture noisily {
        generate double modelse=2
        quietly regress x i.group
        mata: mata set matastrict `strict'
        tempfile refusal
        log using "`refusal'", text replace name(refusal)
        quietly do "_simtab_qa_prior_r.do" full
        qa_state_snapshot, tag(latepayload) predict(xb stdp)
        capture noisily simtab group, estimate(x) se(modelse) true(20.5) metrics(mean bias empse n) order(sort) plotframe(fxpayload,replace) csv(`"`macval(target)'"')
        local candidate_rc=_rc
        qa_state_compare, tag(latepayload) allow(frame)
        assert `candidate_rc'==603 & r(N_cells)==4 & r(N_input)==40
        assert "`r(mode)'"=="compute" & "`r(plotframe)'"=="fxpayload"
        assert missing(r(caller_scalar)) & "`r(caller_macro)'"==""
        log close refusal
        mata: st_local("named", strofreal(any(strpos(strlower(cat(st_local("refusal"))),"could not be opened"))))
        assert `named'==1 & "`c(matastrict)'"=="`strict'"
        frame fxpayload: assert _N==4 & n==10 & !missing(mean,bias,empse)
        frame fxpayload: assert abs(empse-sqrt(110/12))<1e-12
        frame fxpayload: assert abs(mean-(5.5+10*(_n-1)))<1e-12 & abs(bias-(5.5+10*(_n-1)-20.5))<1e-12
        capture confirm file `"`macval(target)'"'
        assert _rc==601
        frame drop fxpayload
        display "LATE_PAYLOAD strict(`strict'): named603, exact four analytic cells, prior r replaced, input/native e/RNG/settings retained"
    }
    local case_rc=_rc
    capture log close refusal
    capture frame drop fxpayload
    qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if `case_rc' local ++fail
    else local ++pass
}
display "RESULT: test_fixture_error_payload tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 9
