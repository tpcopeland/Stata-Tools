*! test_diagtab_fixture_rreturns.do -- exact refusal r() boundary
*! Author: Timothy P Copeland, Karolinska Institutet
version 17
clear all
set more off
capture log close _all
log using test_diagtab_fixture_rreturns.log, text replace
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

**# diagtab_xlsx_full
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local output `"`r(path_hostile)'"'
    python: _dt_r_before=_dt_r_tree()
    qa_fx_a7_labelled, clear seed(37)
    tempfile causefile
    capture log close dt_rcause
    log using `"`causefile'"', text replace name(dt_rcause)
    _dt_seed_r full
    qa_state_snapshot, tag(dt_r) rreturn
    * expect: REFUSED
    capture noisily diagtab x y, xlsx(`"`macval(output)'"')
    local call_rc=_rc
    qa_state_compare, tag(dt_r)
    assert `call_rc'==198
    log close dt_rcause
    python: assert 'contains invalid characters' in Path(Macro.getLocal('causefile')).read_text()
    python: assert _dt_r_tree()==_dt_r_before
}
local outcome=_rc
capture log close dt_rcause
if `"`macval(root)'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: diagtab_xlsx_full rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: diagtab_xlsx_full"
}

**# diagtab_xlsx_empty
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local output `"`r(path_hostile)'"'
    python: _dt_r_before=_dt_r_tree()
    qa_fx_a7_labelled, clear seed(37)
    tempfile causefile
    capture log close dt_rcause
    log using `"`causefile'"', text replace name(dt_rcause)
    _dt_seed_r empty
    qa_state_snapshot, tag(dt_r) rreturn
    * expect: REFUSED
    capture noisily diagtab x y, xlsx(`"`macval(output)'"')
    local call_rc=_rc
    qa_state_compare, tag(dt_r)
    assert `call_rc'==198
    log close dt_rcause
    python: assert 'contains invalid characters' in Path(Macro.getLocal('causefile')).read_text()
    python: assert _dt_r_tree()==_dt_r_before
}
local outcome=_rc
capture log close dt_rcause
if `"`macval(root)'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: diagtab_xlsx_empty rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: diagtab_xlsx_empty"
}

**# diagtab_excel_full
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local output `"`r(path_hostile)'"'
    python: _dt_r_before=_dt_r_tree()
    qa_fx_a7_labelled, clear seed(37)
    tempfile causefile
    capture log close dt_rcause
    log using `"`causefile'"', text replace name(dt_rcause)
    _dt_seed_r full
    qa_state_snapshot, tag(dt_r) rreturn
    * expect: REFUSED
    capture noisily diagtab x y, excel(`"`macval(output)'"')
    local call_rc=_rc
    qa_state_compare, tag(dt_r)
    assert `call_rc'==198
    log close dt_rcause
    python: assert 'contains invalid characters' in Path(Macro.getLocal('causefile')).read_text()
    python: assert _dt_r_tree()==_dt_r_before
}
local outcome=_rc
capture log close dt_rcause
if `"`macval(root)'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: diagtab_excel_full rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: diagtab_excel_full"
}

**# diagtab_excel_empty
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local output `"`r(path_hostile)'"'
    python: _dt_r_before=_dt_r_tree()
    qa_fx_a7_labelled, clear seed(37)
    tempfile causefile
    capture log close dt_rcause
    log using `"`causefile'"', text replace name(dt_rcause)
    _dt_seed_r empty
    qa_state_snapshot, tag(dt_r) rreturn
    * expect: REFUSED
    capture noisily diagtab x y, excel(`"`macval(output)'"')
    local call_rc=_rc
    qa_state_compare, tag(dt_r)
    assert `call_rc'==198
    log close dt_rcause
    python: assert 'contains invalid characters' in Path(Macro.getLocal('causefile')).read_text()
    python: assert _dt_r_tree()==_dt_r_before
}
local outcome=_rc
capture log close dt_rcause
if `"`macval(root)'"'!="" capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
if `outcome' {
    local ++fail
    display as error "FAIL: diagtab_excel_empty rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: diagtab_excel_empty"
}

display "RESULT: test_diagtab_fixture_rreturns tests=`tests' pass=`pass' fail=`fail'"
log close _all
if `fail' exit 1
