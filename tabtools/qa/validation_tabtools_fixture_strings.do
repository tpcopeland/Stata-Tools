*! validation_tabtools_fixture_strings.do -- literal labels consumed by actual numerical tables
*! Author: Timothy P Copeland, Karolinska Institutet
version 17
clear all
set more off
capture log close _all
log using validation_tabtools_fixture_strings.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_hostile.do
do _qa_state.do
local tests 0
local pass 0
local fail 0

**# crosstab nine literal variable labels
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    local corpus `r(names)'
    foreach g of local corpus {
    * expect: EXACT
    mata: st_varlabel("group",st_global(st_local("g")))
    tempname display counts
    qa_state_snapshot, tag(tt_strings)
    quietly crosstab group y, frame(`display')
    assert r(N)==40
    matrix `counts'=r(table)
    assert rowsof(`counts')==4 & colsof(`counts')==2
    forvalues i=1/4 {
        assert `counts'[`i',1]==5 & `counts'[`i',2]==5
    }
    matrix drop `counts'
    frame `display': python: from sfi import Data,Macro; assert Data.getAt("c1",1)==Macro.getGlobal(Macro.getLocal("g"))
    frame drop `display'
    qa_state_compare, tag(tt_strings)
    }
}
local outcome=_rc
capture frame drop `display'
capture matrix drop `counts'
if `outcome' {
    local ++fail
    display as error "FAIL: crosstab literal labels rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: crosstab literal labels"
}

**# desctab nine literal variable labels
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    local corpus `r(names)'
    foreach g of local corpus {
    * expect: EXACT
    mata: st_varlabel("x",st_global(st_local("g")))
    tempname display counts
    qa_state_snapshot, tag(tt_strings)
    quietly desctab, by(group) vars(x contn %9.1f) frame(`display')
    frame `display': assert _N==3
    frame `display': assert group_1[3]=="5.5±3.0" & group_2[3]=="15.5±3.0" & group_5[3]=="25.5±3.0" & group_9[3]=="35.5±3.0"
    frame `display': python: from sfi import Data,Macro; assert Data.getAt("factor",2)==Macro.getGlobal(Macro.getLocal("g"))
    frame drop `display'
    qa_state_compare, tag(tt_strings)
    }
}
local outcome=_rc
capture frame drop `display'
capture matrix drop `counts'
if `outcome' {
    local ++fail
    display as error "FAIL: desctab literal labels rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab literal labels"
}

**# table1_tc nine literal variable labels
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    local corpus `r(names)'
    foreach g of local corpus {
    * expect: EXACT
    mata: st_varlabel("x",st_global(st_local("g")))
    tempname display counts
    qa_state_snapshot, tag(tt_strings)
    quietly table1_tc, by(group) vars(x contn %9.1f) frame(`display')
    frame `display': assert _N==3
    frame `display': assert group_1[3]=="5.5±3.0" & group_2[3]=="15.5±3.0" & group_5[3]=="25.5±3.0" & group_9[3]=="35.5±3.0"
    frame `display': python: from sfi import Data,Macro; assert Data.getAt("factor",2)==Macro.getGlobal(Macro.getLocal("g"))
    frame drop `display'
    qa_state_compare, tag(tt_strings)
    }
}
local outcome=_rc
capture frame drop `display'
capture matrix drop `counts'
if `outcome' {
    local ++fail
    display as error "FAIL: table1_tc literal labels rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: table1_tc literal labels"
}

display "RESULT: validation_tabtools_fixture_strings tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
