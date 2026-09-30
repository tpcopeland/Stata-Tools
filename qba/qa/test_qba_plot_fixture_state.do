*! test_qba_plot_fixture_state.do -- fresh/opaque native-global success and refusal fingerprints
*! Author: Timothy P Copeland, Karolinska Institutet
version 16
clear all
set more off
capture log close _all
log using "test_qba_plot_fixture_state.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a6.do
do _qa_state.do
local tests 0
local pass 0
local fail 0
foreach existing in 0 1 2 {
    foreach route in success syntax late_export tipping {
        local ++tests
        capture noisily {
            qa_fx_a6_bias, clear seed(37)
            capture macro drop T_gm_fix_span
            if `existing'==1 {
                mata: st_global("T_gm_fix_span","opaque "+char(96)+"caller_local"+char(39)+" "+char(36)+"CALLER_KEEP "+char(34)+"quoted"+char(34))
            }
            if `existing'==2 global T_gm_fix_span ""
            local a=observed_n[1]
            local b=observed_n[3]
            local c=observed_n[2]
            local d=observed_n[4]
            qa_state_snapshot, tag(qba_fresh_plot)
            if "`route'"=="syntax" {
                capture noisily qba_plot, tornado steps(1)
                assert _rc==198
            }
            else if "`route'"=="late_export" {
                tempfile stem
                capture noisily qba_plot, tornado a(`a') b(`b') c(`c') d(`d') type(outcome) param1(se) range1(.8 1) base_sp(.9) steps(3) saving("`stem'/missing/out.svg")
                assert _rc==603
                assert r(n_missing)==0 & `"`r(plot_type)'"'=="tornado"
            }
            else if "`route'"=="tipping" {
                quietly qba_plot, tipping a(`a') b(`b') c(`c') d(`d') type(outcome) param1(se) range1(.8 1) param2(sp) range2(.9 1) steps(3)
                assert r(n_missing)==0 & `"`r(plot_type)'"'=="tipping"
            }
            else {
                quietly qba_plot, tornado a(`a') b(`b') c(`c') d(`d') type(outcome) param1(se) range1(.8 1) base_sp(.9) steps(3)
                assert r(n_missing)==0 & `"`r(plot_type)'"'=="tornado"
            }
            qa_state_compare, tag(qba_fresh_plot)
        }
        local outcome=_rc
        if `outcome' {
            local ++fail
            display as error "FAIL: existing`existing' `route'; rc=" `outcome'
        }
        else {
            local ++pass
            display as result "PASS: existing`existing' `route'"
        }
    }
}
display "RESULT: test_qba_plot_fixture_state tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
