*! test_tabtools_fixture_publication.do -- success and late-export analytical payload
*! Author: Timothy P Copeland, Karolinska Institutet
version 17
clear all
set more off
capture log close _all
log using test_tabtools_fixture_publication.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
program define _tt_seed_r, rclass
    args kind
    return clear
    if "`kind'"=="empty" exit
    tempname payload
    matrix `payload'=(1,-2\3,4)
    matrix rownames `payload'=First second
    matrix colnames `payload'=X y
    return scalar exact=123.125
    return scalar extended=.a
    local opaque ""
    mata: st_local("opaque",char(36)+"UNSET"+char(96)+"missing"+char(39)+char(34)+"opaque")
    return local bytes `"`macval(opaque)'"'
    return matrix payload=`payload'
end
local tests 0
local pass 0
local fail 0
python:
from pathlib import Path
from sfi import Macro
import hashlib
def _tt_r_tree():
    root=Path(Macro.getLocal('root'))
    return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()}
end

**# corrtab_success
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _tt_pub_before=_tt_r_tree()
    qa_fx_a7_labelled, clear seed(37)
    tempfile causefile
    capture log close tt_pubcause
    log using `"`causefile'"', text replace name(tt_pubcause)
    _tt_seed_r full
    qa_state_snapshot, tag(pub)
    * expect: EXACT
    capture noisily corrtab x id, full
    local call_rc=_rc
    tempname got nn
    matrix `got'=r(C)
    matrix `nn'=r(N)
    assert rowsof(`got')==2 & colsof(`got')==2
    assert !missing(`got'[1,1],`got'[2,2],`got'[1,2]) & abs(`got'[1,1]-1)<1e-12 & abs(`got'[2,2]-1)<1e-12 & abs(`got'[1,2]-1)<1e-12
    assert `nn'[1,1]==40 & `nn'[1,2]==40 & `nn'[2,1]==40 & `nn'[2,2]==40
    assert strpos(`"`r(methods)'"',"Pearson")>0
    matrix drop `got' `nn' 
    assert missing(r(exact)) & missing(r(extended)) & `"`r(bytes)'"'==""
    mata: assert(!any(st_dir("r()","matrix","*") :== "payload") & !any(st_dir("r()","numscalar","*") :== "exact") & !any(st_dir("r()","numscalar","*") :== "extended") & !any(st_dir("r()","macro","*") :== "bytes"))
    qa_state_compare, tag(pub)
    assert `call_rc'==0
    log close tt_pubcause
    
    python: assert _tt_r_tree()==_tt_pub_before
}
local outcome=_rc
capture log close tt_pubcause
if `"`macval(root)'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: corrtab_success rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: corrtab_success"
}

**# corrtab_late_export
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _tt_pub_before=_tt_r_tree()
    qa_fx_a7_labelled, clear seed(37)
    tempfile causefile
    capture log close tt_pubcause
    log using `"`causefile'"', text replace name(tt_pubcause)
    _tt_seed_r full
    qa_state_snapshot, tag(pub)
    * expect: REFUSED
    capture noisily corrtab x id, full xlsx(`"`macval(output)'"')
    local call_rc=_rc
    tempname got nn
    matrix `got'=r(C)
    matrix `nn'=r(N)
    assert rowsof(`got')==2 & colsof(`got')==2
    assert !missing(`got'[1,1],`got'[2,2],`got'[1,2]) & abs(`got'[1,1]-1)<1e-12 & abs(`got'[2,2]-1)<1e-12 & abs(`got'[1,2]-1)<1e-12
    assert `nn'[1,1]==40 & `nn'[1,2]==40 & `nn'[2,1]==40 & `nn'[2,2]==40
    assert strpos(`"`r(methods)'"',"Pearson")>0
    matrix drop `got' `nn' 
    assert missing(r(exact)) & missing(r(extended)) & `"`r(bytes)'"'==""
    mata: assert(!any(st_dir("r()","matrix","*") :== "payload") & !any(st_dir("r()","numscalar","*") :== "exact") & !any(st_dir("r()","numscalar","*") :== "extended") & !any(st_dir("r()","macro","*") :== "bytes"))
    qa_state_compare, tag(pub)
    assert `call_rc'==16106
    log close tt_pubcause
    python: assert 'Failed to export' in Path(Macro.getLocal('causefile')).read_text()
    python: assert not Path(Macro.getLocal('output')).exists()
    python: assert _tt_r_tree()==_tt_pub_before
}
local outcome=_rc
capture log close tt_pubcause
if `"`macval(root)'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: corrtab_late_export rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: corrtab_late_export"
}

**# crosstab_success
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _tt_pub_before=_tt_r_tree()
    qa_fx_a7_labelled, clear seed(37)
    tempfile causefile
    capture log close tt_pubcause
    log using `"`causefile'"', text replace name(tt_pubcause)
    _tt_seed_r full
    qa_state_snapshot, tag(pub)
    * expect: EXACT
    capture noisily crosstab group y, label
    local call_rc=_rc
    tempname got
    matrix `got'=r(table)
    assert rowsof(`got')==4 & colsof(`got')==2
    forvalues j=1/4 {
        assert `got'[`j',1]==5 & `got'[`j',2]==5
    }
    assert r(N)==40 & r(chi2)==0 & r(p)==1
    assert strlen(`"`r(methods)'"')>0
    matrix drop `got' 
    assert missing(r(exact)) & missing(r(extended)) & `"`r(bytes)'"'==""
    mata: assert(!any(st_dir("r()","matrix","*") :== "payload") & !any(st_dir("r()","numscalar","*") :== "exact") & !any(st_dir("r()","numscalar","*") :== "extended") & !any(st_dir("r()","macro","*") :== "bytes"))
    qa_state_compare, tag(pub)
    assert `call_rc'==0
    log close tt_pubcause
    
    python: assert _tt_r_tree()==_tt_pub_before
}
local outcome=_rc
capture log close tt_pubcause
if `"`macval(root)'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: crosstab_success rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: crosstab_success"
}

**# crosstab_late_export
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _tt_pub_before=_tt_r_tree()
    qa_fx_a7_labelled, clear seed(37)
    tempfile causefile
    capture log close tt_pubcause
    log using `"`causefile'"', text replace name(tt_pubcause)
    _tt_seed_r full
    qa_state_snapshot, tag(pub)
    * expect: REFUSED
    capture noisily crosstab group y, label xlsx(`"`macval(output)'"')
    local call_rc=_rc
    tempname got
    matrix `got'=r(table)
    assert rowsof(`got')==4 & colsof(`got')==2
    forvalues j=1/4 {
        assert `got'[`j',1]==5 & `got'[`j',2]==5
    }
    assert r(N)==40 & r(chi2)==0 & r(p)==1
    assert strlen(`"`r(methods)'"')>0
    matrix drop `got' 
    assert missing(r(exact)) & missing(r(extended)) & `"`r(bytes)'"'==""
    mata: assert(!any(st_dir("r()","matrix","*") :== "payload") & !any(st_dir("r()","numscalar","*") :== "exact") & !any(st_dir("r()","numscalar","*") :== "extended") & !any(st_dir("r()","macro","*") :== "bytes"))
    qa_state_compare, tag(pub)
    assert `call_rc'==16106
    log close tt_pubcause
    python: assert 'Failed to export' in Path(Macro.getLocal('causefile')).read_text()
    python: assert not Path(Macro.getLocal('output')).exists()
    python: assert _tt_r_tree()==_tt_pub_before
}
local outcome=_rc
capture log close tt_pubcause
if `"`macval(root)'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: crosstab_late_export rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: crosstab_late_export"
}

**# desctab_success
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _tt_pub_before=_tt_r_tree()
    qa_fx_a7_labelled, clear seed(37)
    tempfile causefile
    capture log close tt_pubcause
    log using `"`causefile'"', text replace name(tt_pubcause)
    _tt_seed_r full
    qa_state_snapshot, tag(pub)
    * expect: EXACT
    capture noisily desctab, by(group) vars(x contn %9.1f)
    local call_rc=_rc
    tempname got
    matrix `got'=r(table)
    assert rowsof(`got')==1 & colsof(`got')==1
    assert !missing(`got'[1,1]) & abs(`got'[1,1]-Ftail(3,36,2000/11))<1e-30
    assert `"`r(varlist)'"'=="x"
    assert strlen(`"`r(Dapa)'"')>0 & strlen(`"`r(methods)'"')>0
    matrix drop `got' 
    assert missing(r(exact)) & missing(r(extended)) & `"`r(bytes)'"'==""
    mata: assert(!any(st_dir("r()","matrix","*") :== "payload") & !any(st_dir("r()","numscalar","*") :== "exact") & !any(st_dir("r()","numscalar","*") :== "extended") & !any(st_dir("r()","macro","*") :== "bytes"))
    qa_state_compare, tag(pub)
    assert `call_rc'==0
    log close tt_pubcause
    
    python: assert _tt_r_tree()==_tt_pub_before
}
local outcome=_rc
capture log close tt_pubcause
if `"`macval(root)'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: desctab_success rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab_success"
}

**# desctab_late_export
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _tt_pub_before=_tt_r_tree()
    qa_fx_a7_labelled, clear seed(37)
    tempfile causefile
    capture log close tt_pubcause
    log using `"`causefile'"', text replace name(tt_pubcause)
    _tt_seed_r full
    qa_state_snapshot, tag(pub)
    * expect: REFUSED
    capture noisily desctab, by(group) vars(x contn %9.1f) xlsx(`"`macval(output)'"')
    local call_rc=_rc
    tempname got
    matrix `got'=r(table)
    assert rowsof(`got')==1 & colsof(`got')==1
    assert !missing(`got'[1,1]) & abs(`got'[1,1]-Ftail(3,36,2000/11))<1e-30
    assert `"`r(varlist)'"'=="x"
    assert strlen(`"`r(Dapa)'"')>0 & strlen(`"`r(methods)'"')>0
    matrix drop `got' 
    assert missing(r(exact)) & missing(r(extended)) & `"`r(bytes)'"'==""
    mata: assert(!any(st_dir("r()","matrix","*") :== "payload") & !any(st_dir("r()","numscalar","*") :== "exact") & !any(st_dir("r()","numscalar","*") :== "extended") & !any(st_dir("r()","macro","*") :== "bytes"))
    qa_state_compare, tag(pub)
    assert `call_rc'==16106
    log close tt_pubcause
    python: assert 'Failed to export' in Path(Macro.getLocal('causefile')).read_text()
    python: assert not Path(Macro.getLocal('output')).exists()
    python: assert _tt_r_tree()==_tt_pub_before
}
local outcome=_rc
capture log close tt_pubcause
if `"`macval(root)'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: desctab_late_export rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab_late_export"
}

display "RESULT: test_tabtools_fixture_publication tests=`tests' pass=`pass' fail=`fail'"
log close _all
if `fail' exit 1
