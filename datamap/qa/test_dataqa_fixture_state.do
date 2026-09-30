*! test_dataqa_fixture_state.do -- fresh matastrict off/on success and refusal fingerprints
*! Author: Timothy P Copeland, Karolinska Institutet
version 16
clear all
set more off
capture log close _all
log using "test_dataqa_fixture_state.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0
foreach setting in off on {
    foreach route in compare syntax report export {
        local ++tests
        capture noisily {
            qa_fx_a7_labelled, clear seed(37)
            tempfile ledger output
            quietly dataqa set ledger("`ledger'") run(fx) maskrare mincell(5)
            quietly datacheck, gatesonly isid(id) expectn(40) allowed(group 1 2 5 9) name(canonical)
            if inlist("`route'","report","export") {
                tempname f
                file open `f' using "`output'", write text replace
                file write `f' "CALLER_KEEP" _n
                file close `f'
            }
            mata: mata set matastrict `setting'
            qa_state_snapshot, tag(dataqa_native)
            if "`route'"=="compare" {
                quietly dataqa compare using "`ledger'", run(fx) baseledger("`ledger'") baseline(fx)
                assert r(n_flags)==0
            }
            else if "`route'"=="syntax" {
                capture noisily dataqa compare using "`ledger'", run(fx) unexpected_option
                assert _rc==198
            }
            else if "`route'"=="report" {
                capture noisily dataqa report using "`ledger'", run(fx) markdown("`output'")
                assert _rc==602
                python: assert __import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text()=="CALLER_KEEP\n"
            }
            else {
                capture noisily dataqa export using "`ledger'", run(fx) saving("`output'")
                assert _rc==602
                python: assert __import__("pathlib").Path(__import__("sfi").Macro.getLocal("output")).read_text()=="CALLER_KEEP\n"
            }
            qa_state_compare, tag(dataqa_native)
            quietly dataqa set clear
        }
        local outcome=_rc
        if `outcome' {
            local ++fail
            display as error "FAIL: `setting' `route'; rc=" `outcome'
        }
        else {
            local ++pass
            display as result "PASS: `setting' `route'"
        }
    }
}
display "RESULT: test_dataqa_fixture_state tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
