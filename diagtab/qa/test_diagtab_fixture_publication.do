*! test_diagtab_fixture_publication.do -- success and late-export analytical payload
*! Author: Timothy P Copeland, Karolinska Institutet
version 17
clear all
set more off
capture log close _all
log using test_diagtab_fixture_publication.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_state.do
program define _dt_seed_r, rclass
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
def _dt_r_tree():
    root=Path(Macro.getLocal('root'))
    return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()}
end

**# single_success
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _dt_pub_before=_dt_r_tree()
    qa_fx_a7_labelled, clear seed(37)
    tempfile causefile
    capture log close dt_pubcause
    log using `"`causefile'"', text replace name(dt_pubcause)
    _dt_seed_r full
    qa_state_snapshot, tag(pub)
    * expect: EXACT
    capture noisily diagtab x y, cutoff(20.5)
    local call_rc=_rc
    assert r(TP)==10 & r(FP)==10 & r(TN)==10 & r(FN)==10
    assert r(sensitivity)==.5 & r(specificity)==.5 & r(accuracy)==.5
    assert strlen(`"`r(methods)'"')>0
    assert missing(r(exact)) & missing(r(extended)) & `"`r(bytes)'"'==""
    mata: assert(!any(st_dir("r()","matrix","*") :== "payload") & !any(st_dir("r()","numscalar","*") :== "exact") & !any(st_dir("r()","numscalar","*") :== "extended") & !any(st_dir("r()","macro","*") :== "bytes"))
    qa_state_compare, tag(pub)
    assert `call_rc'==0
    log close dt_pubcause
    
    python: assert _dt_r_tree()==_dt_pub_before
}
local outcome=_rc
capture log close dt_pubcause
if `"`macval(root)'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: single_success rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: single_success"
}

**# single_late_export
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _dt_pub_before=_dt_r_tree()
    qa_fx_a7_labelled, clear seed(37)
    tempfile causefile
    capture log close dt_pubcause
    log using `"`causefile'"', text replace name(dt_pubcause)
    _dt_seed_r full
    qa_state_snapshot, tag(pub)
    * expect: REFUSED
    capture noisily diagtab x y, cutoff(20.5) xlsx(`"`macval(output)'"')
    local call_rc=_rc
    assert r(TP)==10 & r(FP)==10 & r(TN)==10 & r(FN)==10
    assert r(sensitivity)==.5 & r(specificity)==.5 & r(accuracy)==.5
    assert strlen(`"`r(methods)'"')>0
    assert missing(r(exact)) & missing(r(extended)) & `"`r(bytes)'"'==""
    mata: assert(!any(st_dir("r()","matrix","*") :== "payload") & !any(st_dir("r()","numscalar","*") :== "exact") & !any(st_dir("r()","numscalar","*") :== "extended") & !any(st_dir("r()","macro","*") :== "bytes"))
    qa_state_compare, tag(pub)
    assert `call_rc'==16106
    log close dt_pubcause
    python: assert 'Failed to export' in Path(Macro.getLocal('causefile')).read_text()
    python: assert not Path(Macro.getLocal('output')).exists()
    python: assert _dt_r_tree()==_dt_pub_before
}
local outcome=_rc
capture log close dt_pubcause
if `"`macval(root)'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: single_late_export rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: single_late_export"
}

**# multiple_success
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _dt_pub_before=_dt_r_tree()
    qa_fx_a7_labelled, clear seed(37)
    tempfile causefile
    capture log close dt_pubcause
    log using `"`causefile'"', text replace name(dt_pubcause)
    _dt_seed_r full
    qa_state_snapshot, tag(pub)
    * expect: EXACT
    capture noisily diagtab x y, cutoffs(20.5 30.5)
    local call_rc=_rc
    tempname got
    matrix `got'=r(cutoff_table)
    assert rowsof(`got')==2 & colsof(`got')==15
    assert `got'[1,1]==.5 & `got'[1,4]==.5 & `got'[1,13]==.5
    assert `got'[2,1]==.25 & `got'[2,4]==.75 & `got'[2,13]==.5
    assert `"`r(cutoffs)'"'=="20.5 30.5"
    matrix drop `got' 
    assert missing(r(exact)) & missing(r(extended)) & `"`r(bytes)'"'==""
    mata: assert(!any(st_dir("r()","matrix","*") :== "payload") & !any(st_dir("r()","numscalar","*") :== "exact") & !any(st_dir("r()","numscalar","*") :== "extended") & !any(st_dir("r()","macro","*") :== "bytes"))
    qa_state_compare, tag(pub)
    assert `call_rc'==0
    log close dt_pubcause
    
    python: assert _dt_r_tree()==_dt_pub_before
}
local outcome=_rc
capture log close dt_pubcause
if `"`macval(root)'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: multiple_success rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: multiple_success"
}

**# multiple_late_export
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _dt_pub_before=_dt_r_tree()
    qa_fx_a7_labelled, clear seed(37)
    tempfile causefile
    capture log close dt_pubcause
    log using `"`causefile'"', text replace name(dt_pubcause)
    _dt_seed_r full
    qa_state_snapshot, tag(pub)
    * expect: REFUSED
    capture noisily diagtab x y, cutoffs(20.5 30.5) xlsx(`"`macval(output)'"')
    local call_rc=_rc
    tempname got
    matrix `got'=r(cutoff_table)
    assert rowsof(`got')==2 & colsof(`got')==15
    assert `got'[1,1]==.5 & `got'[1,4]==.5 & `got'[1,13]==.5
    assert `got'[2,1]==.25 & `got'[2,4]==.75 & `got'[2,13]==.5
    assert `"`r(cutoffs)'"'=="20.5 30.5"
    matrix drop `got' 
    assert missing(r(exact)) & missing(r(extended)) & `"`r(bytes)'"'==""
    mata: assert(!any(st_dir("r()","matrix","*") :== "payload") & !any(st_dir("r()","numscalar","*") :== "exact") & !any(st_dir("r()","numscalar","*") :== "extended") & !any(st_dir("r()","macro","*") :== "bytes"))
    qa_state_compare, tag(pub)
    assert `call_rc'==16106
    log close dt_pubcause
    python: assert 'Failed to export' in Path(Macro.getLocal('causefile')).read_text()
    python: assert not Path(Macro.getLocal('output')).exists()
    python: assert _dt_r_tree()==_dt_pub_before
}
local outcome=_rc
capture log close dt_pubcause
if `"`macval(root)'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: multiple_late_export rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: multiple_late_export"
}

display "RESULT: test_diagtab_fixture_publication tests=`tests' pass=`pass' fail=`fail'"
log close _all
if `fail' exit 1
