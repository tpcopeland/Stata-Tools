*! validation_massdesas_fixture_primitives.do -- genuine SAS contents and hostile caller preservation
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
log using validation_massdesas_fixture_primitives.log,text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_hostile.do
do _qa_state.do
do _massdesas_qa_common.do
_massdesas_qa_bootstrap
local tests 0
local pass 0
local fail 0

**# Actual conversion with hostile caller names
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local discovery `"`r(path_sas)'"'
    local source `"`macval(root)'/canonical.dta"'
    local valid `"`macval(root)'/valid.sas7bdat"'
    local converted `"`macval(root)'/valid.dta"'
    qa_fx_a7_labelled, clear seed(37)
    quietly save `"`macval(source)'"'
    python: __import__("subprocess").run(["Rscript","-e","library(haven);a<-commandArgs(TRUE);x<-read_dta(a[1]);write_sas(x[c('id','group','x','y')],a[2])",__import__("sfi").Macro.getLocal("source"),__import__("sfi").Macro.getLocal("valid")],check=True)
    * SAS fixed-name/string rules are separate from arbitrary caller data.
    * The command promises to preserve the caller while converting a file.
    * expect: INVARIANT
    qa_hostile_names, clear
    qa_state_snapshot, tag(sas_primitive)
    massdesas, directory(`"`macval(root)'"') erase
    assert r(n_converted)==1 & r(n_failed)==1
    qa_state_compare, tag(sas_primitive)
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
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: names rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: names"
}

**# Actual conversion with hostile caller codes
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local discovery `"`r(path_sas)'"'
    local source `"`macval(root)'/canonical.dta"'
    local valid `"`macval(root)'/valid.sas7bdat"'
    local converted `"`macval(root)'/valid.dta"'
    qa_fx_a7_labelled, clear seed(37)
    quietly save `"`macval(source)'"'
    python: __import__("subprocess").run(["Rscript","-e","library(haven);a<-commandArgs(TRUE);x<-read_dta(a[1]);write_sas(x[c('id','group','x','y')],a[2])",__import__("sfi").Macro.getLocal("source"),__import__("sfi").Macro.getLocal("valid")],check=True)
    * SAS fixed-name/string rules are separate from arbitrary caller data.
    * The command promises to preserve the caller while converting a file.
    * expect: INVARIANT
    qa_hostile_codes, clear
    qa_state_snapshot, tag(sas_primitive)
    massdesas, directory(`"`macval(root)'"') erase
    assert r(n_converted)==1 & r(n_failed)==1
    qa_state_compare, tag(sas_primitive)
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
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: codes rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: codes"
}

**# Actual conversion with hostile caller missing
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local discovery `"`r(path_sas)'"'
    local source `"`macval(root)'/canonical.dta"'
    local valid `"`macval(root)'/valid.sas7bdat"'
    local converted `"`macval(root)'/valid.dta"'
    qa_fx_a7_labelled, clear seed(37)
    quietly save `"`macval(source)'"'
    python: __import__("subprocess").run(["Rscript","-e","library(haven);a<-commandArgs(TRUE);x<-read_dta(a[1]);write_sas(x[c('id','group','x','y')],a[2])",__import__("sfi").Macro.getLocal("source"),__import__("sfi").Macro.getLocal("valid")],check=True)
    * SAS fixed-name/string rules are separate from arbitrary caller data.
    * The command promises to preserve the caller while converting a file.
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37) perturb(miss_all_column)
    qa_state_snapshot, tag(sas_primitive)
    massdesas, directory(`"`macval(root)'"') erase
    assert r(n_converted)==1 & r(n_failed)==1
    qa_state_compare, tag(sas_primitive)
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
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: missing rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: missing"
}

**# Actual conversion with hostile caller strings
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local discovery `"`r(path_sas)'"'
    local source `"`macval(root)'/canonical.dta"'
    local valid `"`macval(root)'/valid.sas7bdat"'
    local converted `"`macval(root)'/valid.dta"'
    qa_fx_a7_labelled, clear seed(37)
    quietly save `"`macval(source)'"'
    python: __import__("subprocess").run(["Rscript","-e","library(haven);a<-commandArgs(TRUE);x<-read_dta(a[1]);write_sas(x[c('id','group','x','y')],a[2])",__import__("sfi").Macro.getLocal("source"),__import__("sfi").Macro.getLocal("valid")],check=True)
    * SAS fixed-name/string rules are separate from arbitrary caller data.
    * The command promises to preserve the caller while converting a file.
    * expect: INVARIANT
    qa_fx_a7_labelled, clear seed(37)
    qa_hostile_strings
    local corpus `r(names)'
    generate strL caption=""
    local row=0
    foreach g of local corpus {
        local ++row
        mata: st_sstore(strtoreal(st_local("row")),"caption",st_global(st_local("g")))
    }
    qa_state_snapshot, tag(sas_primitive)
    massdesas, directory(`"`macval(root)'"') erase
    assert r(n_converted)==1 & r(n_failed)==1
    qa_state_compare, tag(sas_primitive)
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
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: strings rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: strings"
}

display "RESULT: validation_massdesas_fixture_primitives tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
