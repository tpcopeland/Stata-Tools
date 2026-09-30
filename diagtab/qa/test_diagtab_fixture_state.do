*! test_diagtab_fixture_state.do -- fresh native globals and cold helper/dispatcher settings
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using test_diagtab_fixture_state.log,text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0
foreach setting in off on {
foreach status in absent present empty {
foreach route in auc cutoff syntax late {
    local ++tests
    capture noisily {
        qa_fx_a7_labelled, clear seed(37)
        ereturn clear
        foreach g in S_1 S_2 S_3 S_4 S_5 S_6 {
            capture macro drop `g'
            if "`status'"=="present" {
                mata: st_global(st_local("g"), "opaque " + char(36) + "CALLER_NEVER " + char(96) + "LOCAL_NEVER" + char(39) + " " + char(34) + "Q" + char(34))
            }
            else if "`status'"=="empty" mata: st_global(st_local("g"), "")
        }
        capture program drop diagtab
        capture program drop _diagtab_helpers_ready
        mata: mata set matastrict `setting'
        qa_state_snapshot, tag(diag_native)
        if "`route'"=="auc" {
            quietly diagtab x y, cutoff(20.5) auc
            assert r(TP)==10 & r(FP)==10 & r(TN)==10 & r(FN)==10
            assert !missing(r(auc)) & abs(r(auc)-.475)<1e-7
        }
        else if "`route'"=="cutoff" {
            quietly diagtab x y, cutoff(20.5)
            assert r(TP)==10 & r(FP)==10 & r(TN)==10 & r(FN)==10
        }
        else if "`route'"=="syntax" {
            * expect: REFUSED
            capture noisily diagtab x y, cutoff(20.5) unexpected_option
            assert _rc==198
        }
        else {
            * expect: REFUSED
            tempfile missing_parent
            capture noisily diagtab x y, cutoff(20.5) auc csv("`missing_parent'/out.csv")
            assert _rc==603
            * Analytical payload survives the optional side-effect refusal.
            assert r(TP)==10 & r(FP)==10 & r(TN)==10 & r(FN)==10
            assert !missing(r(auc)) & abs(r(auc)-.475)<1e-7
        }
        qa_state_compare, tag(diag_native)
    }
    local outcome=_rc
    if `outcome' {
        local ++fail
        display as error "FAIL: `setting' `status' `route'; rc=" `outcome'
    }
    else {
        local ++pass
        display as result "PASS: `setting' `status' `route'"
    }
}
}
}
display "RESULT: test_diagtab_fixture_state tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
