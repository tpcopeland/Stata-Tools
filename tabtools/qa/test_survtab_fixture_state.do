*! test_survtab_fixture_state.do -- native legacy global presence/opaque bytes and original rc
*! Author: Timothy P Copeland, Karolinska Institutet
version 17
clear all
set more off
capture log close _all
log using "test_survtab_fixture_state.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0
foreach estimator in empty foreign {
foreach status in absent present empty {
    foreach route in km median syntax export {
        local ++tests
        capture noisily {
            qa_fx_a7_labelled, clear seed(37)
            tempvar follow
            generate double `follow'=1+(y==0)
            quietly stset `follow', failure(y) id(id)
            ereturn clear
            if "`estimator'"=="foreign" quietly regress x y
            mata: st_local("current_s_e", invtokens(st_dir("global", "macro", "S_E_*")'))
            foreach g of local current_s_e {
                capture macro drop `g'
            }
            foreach g in S_1 S_2 S_3 S_5 S_6 S_E_cmd S_E_ll S_E_abcdefghijklmnopqrstuvwxyzA S_E_abcdefghijklmnopqrstuvwxyzB {
                capture macro drop `g'
                if "`status'"=="present" {
                    mata: st_global(st_local("g"), "opaque " + char(36) + "CALLER_NEVER " + char(96) + "LOCAL_NEVER" + char(39) + " " + char(34) + "Q" + char(34))
                }
                else if "`status'"=="empty" mata: st_global(st_local("g"), "")
            }
            qa_state_snapshot, tag(surv_native)
            if "`route'"=="km" {
                quietly survtab, times(.5 1 2) by(group) rmst(2)
                assert r(n_groups)==4 & r(rmst_1)==1.5 & abs(r(rmst_se_1)-sqrt(.025))<1e-14
            }
            else if "`route'"=="median" {
                quietly survtab, times(1) by(group) median
                forvalues j=1/4 {
                    assert r(median_`j')==1
                }
            }
            else if "`route'"=="syntax" {
                * expect: REFUSED
                capture noisily survtab, times(1) unexpected_option
                assert _rc==198
            }
            else {
                * expect: REFUSED
                tempfile missing_parent
                capture noisily survtab, times(1) by(group) median csv("`missing_parent'/out.csv")
                assert _rc==603
            }
            qa_state_compare, tag(surv_native)
        }
        local outcome=_rc
        if `outcome' {
            local ++fail
            display as error "FAIL: `estimator' `status' `route'; rc=" `outcome'
        }
        else {
            local ++pass
            display as result "PASS: `estimator' `status' `route'"
        }
    }
}
}
display "RESULT: test_survtab_fixture_state tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
