*! test_datamap_fixture_option_strings.do -- graph/ledger domain controls
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using test_datamap_fixture_option_strings.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_metamorphic.do
do _qa_state.do
capture program drop _dm_ledger_check
program define _dm_ledger_check
    local ledger `"`r(ledger)'"'
    assert r(N)==40 & r(n_checks)==1 & r(n_passed)==1 & r(n_failed)==0
    preserve
    quietly use `"`ledger'"', clear
    assert _N==1 & family=="expectn" & observed_num==40 & n_scope==40 & status=="pass"
    restore
end
local tests 0
local pass 0
local fail 0
local ++tests
capture noisily {
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37)
    generate double a=y
    generate double b=y
    replace a=. if inrange(id,1,10)
    replace b=. if inrange(id,6,15)
    qa_state_snapshot, tag(graph_domain)
    qa_option_domain, command(datamvp a b, nodrop graph(@v@) gname(dm_types) nodraw) inside(bar patterns matrix correlation) outside(not_a_graph) check(assert r(N)==40 & r(N_complete)==25 & r(N_mv_total)==20 & r(N_patterns)==4 & r(mean_miss)==.5)
    assert r(n_cells)==5 & r(n_violations)==0
    qa_state_compare, tag(graph_domain)
    graph drop dm_types
}
local outcome=_rc
capture graph drop dm_types
if `outcome' {
    local ++fail
    display as error "FAIL: graph domain rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: graph domain"
}
local ++tests
local root ""
capture noisily {
    * expect: EXACT
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local ledgerA `"`root'/ledger_A.dta"'
    local ledgerB `"`root'/ledger_B.dta"'
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(ledger_domain)
    qa_option_domain, command(datacheck, gatesonly expectn(40) ledger("@v@")) inside(`""`ledgerA'" "`ledgerB'""') outside(`""`root'/absent/ledger.dta""') check(_dm_ledger_check)
    assert r(n_cells)==3 & r(n_violations)==0
    qa_state_compare, tag(ledger_domain)
}
local outcome=_rc
capture restore
if `"`root'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: ledger filename domain rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: ledger filename domain"
}
display "RESULT: test_datamap_fixture_option_strings tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
