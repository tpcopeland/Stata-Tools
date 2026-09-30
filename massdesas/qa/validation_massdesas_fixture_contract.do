*! validation_massdesas_fixture_contract.do -- canonical labelled designs and independent contents
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using "validation_massdesas_fixture_contract.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0
do _massdesas_qa_common.do
_massdesas_qa_bootstrap

**# Real SAS conversion and honest discovery failure friendly
local ++tests
capture noisily {
    local root ""
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local discovery `"`r(path_sas)'"'
    local source `"`macval(root)'/canonical.dta"'
    local valid `"`macval(root)'/valid.sas7bdat"'
    local converted `"`macval(root)'/valid.dta"'
    qa_fx_a7_labelled, clear seed(37)
    quietly save `"`macval(source)'"'
    python: __import__("subprocess").run(["Rscript","-e","library(haven);a<-commandArgs(TRUE);x<-read_dta(a[1]);write_sas(x[c('id','group','x','y')],a[2])",__import__("sfi").Macro.getLocal("source"),__import__("sfi").Macro.getLocal("valid")],check=True)
    qa_state_snapshot, tag(sas_call)
    massdesas, directory(`"`macval(root)'"') erase
    assert r(n_converted)==1 & r(n_failed)==1
    qa_state_compare, tag(sas_call)
    preserve
    quietly use `"`macval(converted)'"', clear
    assert _N==40
    sort id
    assert id==_n & x==id & y==mod(id,2)
    assert group==cond(id<=10,1,cond(id<=20,2,cond(id<=30,5,9)))
    restore
    python: assert __import__("pathlib").Path(__import__("sfi").Macro.getLocal("discovery")).read_text()=="DISCOVERY STAND-IN; NOT A SAS BINARY\n"; assert not __import__("pathlib").Path(__import__("sfi").Macro.getLocal("valid")).exists()

}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Real SAS conversion and honest discovery failure friendly; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Real SAS conversion and honest discovery failure friendly"
}

**# Real SAS conversion and honest discovery failure label_gaps
local ++tests
capture noisily {
    local root ""
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local discovery `"`r(path_sas)'"'
    local source `"`macval(root)'/canonical.dta"'
    local valid `"`macval(root)'/valid.sas7bdat"'
    local converted `"`macval(root)'/valid.dta"'
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(label_gaps)
    quietly save `"`macval(source)'"'
    python: __import__("subprocess").run(["Rscript","-e","library(haven);a<-commandArgs(TRUE);x<-read_dta(a[1]);write_sas(x[c('id','group','x','y')],a[2])",__import__("sfi").Macro.getLocal("source"),__import__("sfi").Macro.getLocal("valid")],check=True)
    qa_state_snapshot, tag(sas_call)
    massdesas, directory(`"`macval(root)'"') erase
    assert r(n_converted)==1 & r(n_failed)==1
    qa_state_compare, tag(sas_call)
    preserve
    quietly use `"`macval(converted)'"', clear
    assert _N==40
    sort id
    assert id==_n & x==id & y==mod(id,2)
    assert group==cond(id<=10,1,cond(id<=20,2,cond(id<=30,5,9)))
    restore
    python: assert __import__("pathlib").Path(__import__("sfi").Macro.getLocal("discovery")).read_text()=="DISCOVERY STAND-IN; NOT A SAS BINARY\n"; assert not __import__("pathlib").Path(__import__("sfi").Macro.getLocal("valid")).exists()

}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Real SAS conversion and honest discovery failure label_gaps; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Real SAS conversion and honest discovery failure label_gaps"
}

**# Real SAS conversion and honest discovery failure single_row
local ++tests
capture noisily {
    local root ""
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local discovery `"`r(path_sas)'"'
    local source `"`macval(root)'/canonical.dta"'
    local valid `"`macval(root)'/valid.sas7bdat"'
    local converted `"`macval(root)'/valid.dta"'
    * expect: EXACT
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    quietly save `"`macval(source)'"'
    python: __import__("subprocess").run(["Rscript","-e","library(haven);a<-commandArgs(TRUE);x<-read_dta(a[1]);write_sas(x[c('id','group','x','y')],a[2])",__import__("sfi").Macro.getLocal("source"),__import__("sfi").Macro.getLocal("valid")],check=True)
    qa_state_snapshot, tag(sas_call)
    massdesas, directory(`"`macval(root)'"') erase
    assert r(n_converted)==1 & r(n_failed)==1
    qa_state_compare, tag(sas_call)
    preserve
    quietly use `"`macval(converted)'"', clear
    assert _N==1
    sort id
    assert id==_n & x==id & y==mod(id,2)
    assert group==cond(id<=10,1,cond(id<=20,2,cond(id<=30,5,9)))
    restore
    python: assert __import__("pathlib").Path(__import__("sfi").Macro.getLocal("discovery")).read_text()=="DISCOVERY STAND-IN; NOT A SAS BINARY\n"; assert not __import__("pathlib").Path(__import__("sfi").Macro.getLocal("valid")).exists()

}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Real SAS conversion and honest discovery failure single_row; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Real SAS conversion and honest discovery failure single_row"
}

**# Real SAS conversion and honest discovery failure unsorted
local ++tests
capture noisily {
    local root ""
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local discovery `"`r(path_sas)'"'
    local source `"`macval(root)'/canonical.dta"'
    local valid `"`macval(root)'/valid.sas7bdat"'
    local converted `"`macval(root)'/valid.dta"'
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(unsorted)
    quietly save `"`macval(source)'"'
    python: __import__("subprocess").run(["Rscript","-e","library(haven);a<-commandArgs(TRUE);x<-read_dta(a[1]);write_sas(x[c('id','group','x','y')],a[2])",__import__("sfi").Macro.getLocal("source"),__import__("sfi").Macro.getLocal("valid")],check=True)
    qa_state_snapshot, tag(sas_call)
    massdesas, directory(`"`macval(root)'"') erase
    assert r(n_converted)==1 & r(n_failed)==1
    qa_state_compare, tag(sas_call)
    preserve
    quietly use `"`macval(converted)'"', clear
    assert _N==40
    sort id
    assert id==_n & x==id & y==mod(id,2)
    assert group==cond(id<=10,1,cond(id<=20,2,cond(id<=30,5,9)))
    restore
    python: assert __import__("pathlib").Path(__import__("sfi").Macro.getLocal("discovery")).read_text()=="DISCOVERY STAND-IN; NOT A SAS BINARY\n"; assert not __import__("pathlib").Path(__import__("sfi").Macro.getLocal("valid")).exists()

}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: Real SAS conversion and honest discovery failure unsorted; rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: Real SAS conversion and honest discovery failure unsorted"
}

_massdesas_qa_cleanup

display "RESULT: validation_massdesas_fixture_contract tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
