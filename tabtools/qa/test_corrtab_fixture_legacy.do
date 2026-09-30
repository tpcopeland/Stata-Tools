*! test_corrtab_fixture_legacy.do -- native Spearman globals on every exit
*! Author: Timothy P Copeland, Karolinska Institutet
version 17
clear all
set more off
capture log close _all
log using test_corrtab_fixture_legacy.log, text replace
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
def _tt_corr_tree():
    root=Path(Macro.getLocal('root'))
    return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()}
end

**# absent globals success
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _tt_corr_before=_tt_corr_tree()
    qa_fx_a7_labelled, clear seed(37)
    capture macro drop S_1 S_4 S_6
    tempfile causefile
    capture log close legacy_cause
    log using `"`causefile'"', text replace name(legacy_cause)
    _tt_seed_r full
    qa_state_snapshot, tag(corr_legacy)
    * expect: EXACT
    capture noisily corrtab x id, full spearman
    local call_rc=_rc
    tempname cc nn
    matrix `cc'=r(C)
    matrix `nn'=r(N)
    assert !missing(`cc'[1,1],`cc'[1,2],`cc'[2,2]) & abs(`cc'[1,1]-1)<1e-12 & abs(`cc'[1,2]-1)<1e-12 & abs(`cc'[2,2]-1)<1e-12
    assert `nn'[1,1]==40 & `nn'[1,2]==40 & `nn'[2,2]==40
    assert strpos(`"`r(methods)'"',"Spearman")>0
    matrix drop `cc' `nn' 
    qa_state_compare, tag(corr_legacy)
    assert `call_rc'==0
    log close legacy_cause
    
    python: assert _tt_corr_tree()==_tt_corr_before
}
local outcome=_rc
capture log close legacy_cause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: absent success rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: absent success"
}

**# absent globals early
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _tt_corr_before=_tt_corr_tree()
    qa_fx_a7_labelled, clear seed(37)
    capture macro drop S_1 S_4 S_6
    tempfile causefile
    capture log close legacy_cause
    log using `"`causefile'"', text replace name(legacy_cause)
    _tt_seed_r full
    qa_state_snapshot, tag(corr_legacy) rreturn
    * expect: REFUSED
    capture noisily corrtab x id, full spearman star(0.1 0.2 0.3 0.4)
    local call_rc=_rc
    
    qa_state_compare, tag(corr_legacy)
    assert `call_rc'==198
    log close legacy_cause
    python: assert 'star() permits at most 3 unique thresholds' in Path(Macro.getLocal('causefile')).read_text()
    python: assert _tt_corr_tree()==_tt_corr_before
}
local outcome=_rc
capture log close legacy_cause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: absent early rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: absent early"
}

**# absent globals single_row
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _tt_corr_before=_tt_corr_tree()
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    capture macro drop S_1 S_4 S_6
    tempfile causefile
    capture log close legacy_cause
    log using `"`causefile'"', text replace name(legacy_cause)
    _tt_seed_r full
    qa_state_snapshot, tag(corr_legacy)
    * expect: EXACT
    capture noisily corrtab x id, full spearman
    local call_rc=_rc
    
    tempname cc pp nn
    matrix `cc'=r(C)
    matrix `pp'=r(P)
    matrix `nn'=r(N)
    forvalues i=1/2 {
        forvalues j=1/2 {
            assert missing(`cc'[`i',`j']) & missing(`pp'[`i',`j'])
            assert `nn'[`i',`j']==1
        }
    }
    assert strpos(`"`r(methods)'"',"Spearman")>0
    matrix drop `cc' `pp' `nn'
    qa_state_compare, tag(corr_legacy)
    assert `call_rc'==0
    log close legacy_cause
    python: assert _tt_corr_tree()==_tt_corr_before
}
local outcome=_rc
capture log close legacy_cause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: absent single_row rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: absent single_row"
}

**# absent globals late_export
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _tt_corr_before=_tt_corr_tree()
    qa_fx_a7_labelled, clear seed(37)
    capture macro drop S_1 S_4 S_6
    tempfile causefile
    capture log close legacy_cause
    log using `"`causefile'"', text replace name(legacy_cause)
    _tt_seed_r full
    qa_state_snapshot, tag(corr_legacy)
    * expect: REFUSED
    capture noisily corrtab x id, full spearman xlsx(`"`macval(output)'"')
    local call_rc=_rc
    tempname cc nn
    matrix `cc'=r(C)
    matrix `nn'=r(N)
    assert !missing(`cc'[1,1],`cc'[1,2],`cc'[2,2]) & abs(`cc'[1,1]-1)<1e-12 & abs(`cc'[1,2]-1)<1e-12 & abs(`cc'[2,2]-1)<1e-12
    assert `nn'[1,1]==40 & `nn'[1,2]==40 & `nn'[2,2]==40
    assert strpos(`"`r(methods)'"',"Spearman")>0
    matrix drop `cc' `nn' 
    qa_state_compare, tag(corr_legacy)
    assert `call_rc'==16106
    log close legacy_cause
    python: assert 'Failed to export' in Path(Macro.getLocal('causefile')).read_text()
    python: assert _tt_corr_tree()==_tt_corr_before
}
local outcome=_rc
capture log close legacy_cause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: absent late_export rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: absent late_export"
}

**# numeric globals success
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _tt_corr_before=_tt_corr_tree()
    qa_fx_a7_labelled, clear seed(37)
    global S_1 271828
    global S_4 .25
    global S_6 .125
    tempfile causefile
    capture log close legacy_cause
    log using `"`causefile'"', text replace name(legacy_cause)
    _tt_seed_r full
    qa_state_snapshot, tag(corr_legacy)
    * expect: EXACT
    capture noisily corrtab x id, full spearman
    local call_rc=_rc
    tempname cc nn
    matrix `cc'=r(C)
    matrix `nn'=r(N)
    assert !missing(`cc'[1,1],`cc'[1,2],`cc'[2,2]) & abs(`cc'[1,1]-1)<1e-12 & abs(`cc'[1,2]-1)<1e-12 & abs(`cc'[2,2]-1)<1e-12
    assert `nn'[1,1]==40 & `nn'[1,2]==40 & `nn'[2,2]==40
    assert strpos(`"`r(methods)'"',"Spearman")>0
    matrix drop `cc' `nn' 
    qa_state_compare, tag(corr_legacy)
    assert `call_rc'==0
    log close legacy_cause
    
    python: assert _tt_corr_tree()==_tt_corr_before
}
local outcome=_rc
capture log close legacy_cause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: numeric success rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: numeric success"
}

**# numeric globals early
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _tt_corr_before=_tt_corr_tree()
    qa_fx_a7_labelled, clear seed(37)
    global S_1 271828
    global S_4 .25
    global S_6 .125
    tempfile causefile
    capture log close legacy_cause
    log using `"`causefile'"', text replace name(legacy_cause)
    _tt_seed_r full
    qa_state_snapshot, tag(corr_legacy) rreturn
    * expect: REFUSED
    capture noisily corrtab x id, full spearman star(0.1 0.2 0.3 0.4)
    local call_rc=_rc
    
    qa_state_compare, tag(corr_legacy)
    assert `call_rc'==198
    log close legacy_cause
    python: assert 'star() permits at most 3 unique thresholds' in Path(Macro.getLocal('causefile')).read_text()
    python: assert _tt_corr_tree()==_tt_corr_before
}
local outcome=_rc
capture log close legacy_cause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: numeric early rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: numeric early"
}

**# numeric globals single_row
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _tt_corr_before=_tt_corr_tree()
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    global S_1 271828
    global S_4 .25
    global S_6 .125
    tempfile causefile
    capture log close legacy_cause
    log using `"`causefile'"', text replace name(legacy_cause)
    _tt_seed_r full
    qa_state_snapshot, tag(corr_legacy)
    * expect: EXACT
    capture noisily corrtab x id, full spearman
    local call_rc=_rc
    
    tempname cc pp nn
    matrix `cc'=r(C)
    matrix `pp'=r(P)
    matrix `nn'=r(N)
    forvalues i=1/2 {
        forvalues j=1/2 {
            assert missing(`cc'[`i',`j']) & missing(`pp'[`i',`j'])
            assert `nn'[`i',`j']==1
        }
    }
    assert strpos(`"`r(methods)'"',"Spearman")>0
    matrix drop `cc' `pp' `nn'
    qa_state_compare, tag(corr_legacy)
    assert `call_rc'==0
    log close legacy_cause
    python: assert _tt_corr_tree()==_tt_corr_before
}
local outcome=_rc
capture log close legacy_cause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: numeric single_row rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: numeric single_row"
}

**# numeric globals late_export
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _tt_corr_before=_tt_corr_tree()
    qa_fx_a7_labelled, clear seed(37)
    global S_1 271828
    global S_4 .25
    global S_6 .125
    tempfile causefile
    capture log close legacy_cause
    log using `"`causefile'"', text replace name(legacy_cause)
    _tt_seed_r full
    qa_state_snapshot, tag(corr_legacy)
    * expect: REFUSED
    capture noisily corrtab x id, full spearman xlsx(`"`macval(output)'"')
    local call_rc=_rc
    tempname cc nn
    matrix `cc'=r(C)
    matrix `nn'=r(N)
    assert !missing(`cc'[1,1],`cc'[1,2],`cc'[2,2]) & abs(`cc'[1,1]-1)<1e-12 & abs(`cc'[1,2]-1)<1e-12 & abs(`cc'[2,2]-1)<1e-12
    assert `nn'[1,1]==40 & `nn'[1,2]==40 & `nn'[2,2]==40
    assert strpos(`"`r(methods)'"',"Spearman")>0
    matrix drop `cc' `nn' 
    qa_state_compare, tag(corr_legacy)
    assert `call_rc'==16106
    log close legacy_cause
    python: assert 'Failed to export' in Path(Macro.getLocal('causefile')).read_text()
    python: assert _tt_corr_tree()==_tt_corr_before
}
local outcome=_rc
capture log close legacy_cause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: numeric late_export rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: numeric late_export"
}

**# opaque globals success
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _tt_corr_before=_tt_corr_tree()
    qa_fx_a7_labelled, clear seed(37)
    foreach name in S_1 S_4 S_6 {
        mata: st_global(st_local("name"),st_local("name")+char(36)+"UNSET"+char(96)+"missing"+char(39)+char(34)+"opaque")
    }
    tempfile causefile
    capture log close legacy_cause
    log using `"`causefile'"', text replace name(legacy_cause)
    _tt_seed_r full
    qa_state_snapshot, tag(corr_legacy)
    * expect: EXACT
    capture noisily corrtab x id, full spearman
    local call_rc=_rc
    tempname cc nn
    matrix `cc'=r(C)
    matrix `nn'=r(N)
    assert !missing(`cc'[1,1],`cc'[1,2],`cc'[2,2]) & abs(`cc'[1,1]-1)<1e-12 & abs(`cc'[1,2]-1)<1e-12 & abs(`cc'[2,2]-1)<1e-12
    assert `nn'[1,1]==40 & `nn'[1,2]==40 & `nn'[2,2]==40
    assert strpos(`"`r(methods)'"',"Spearman")>0
    matrix drop `cc' `nn' 
    qa_state_compare, tag(corr_legacy)
    assert `call_rc'==0
    log close legacy_cause
    
    python: assert _tt_corr_tree()==_tt_corr_before
}
local outcome=_rc
capture log close legacy_cause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: opaque success rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: opaque success"
}

**# opaque globals early
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _tt_corr_before=_tt_corr_tree()
    qa_fx_a7_labelled, clear seed(37)
    foreach name in S_1 S_4 S_6 {
        mata: st_global(st_local("name"),st_local("name")+char(36)+"UNSET"+char(96)+"missing"+char(39)+char(34)+"opaque")
    }
    tempfile causefile
    capture log close legacy_cause
    log using `"`causefile'"', text replace name(legacy_cause)
    _tt_seed_r full
    qa_state_snapshot, tag(corr_legacy) rreturn
    * expect: REFUSED
    capture noisily corrtab x id, full spearman star(0.1 0.2 0.3 0.4)
    local call_rc=_rc
    
    qa_state_compare, tag(corr_legacy)
    assert `call_rc'==198
    log close legacy_cause
    python: assert 'star() permits at most 3 unique thresholds' in Path(Macro.getLocal('causefile')).read_text()
    python: assert _tt_corr_tree()==_tt_corr_before
}
local outcome=_rc
capture log close legacy_cause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: opaque early rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: opaque early"
}

**# opaque globals single_row
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _tt_corr_before=_tt_corr_tree()
    qa_fx_a7_labelled, clear seed(37) perturb(single_row)
    foreach name in S_1 S_4 S_6 {
        mata: st_global(st_local("name"),st_local("name")+char(36)+"UNSET"+char(96)+"missing"+char(39)+char(34)+"opaque")
    }
    tempfile causefile
    capture log close legacy_cause
    log using `"`causefile'"', text replace name(legacy_cause)
    _tt_seed_r full
    qa_state_snapshot, tag(corr_legacy)
    * expect: EXACT
    capture noisily corrtab x id, full spearman
    local call_rc=_rc
    
    tempname cc pp nn
    matrix `cc'=r(C)
    matrix `pp'=r(P)
    matrix `nn'=r(N)
    forvalues i=1/2 {
        forvalues j=1/2 {
            assert missing(`cc'[`i',`j']) & missing(`pp'[`i',`j'])
            assert `nn'[`i',`j']==1
        }
    }
    assert strpos(`"`r(methods)'"',"Spearman")>0
    matrix drop `cc' `pp' `nn'
    qa_state_compare, tag(corr_legacy)
    assert `call_rc'==0
    log close legacy_cause
    python: assert _tt_corr_tree()==_tt_corr_before
}
local outcome=_rc
capture log close legacy_cause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: opaque single_row rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: opaque single_row"
}

**# opaque globals late_export
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/missing parent/report.xlsx")
    python: _tt_corr_before=_tt_corr_tree()
    qa_fx_a7_labelled, clear seed(37)
    foreach name in S_1 S_4 S_6 {
        mata: st_global(st_local("name"),st_local("name")+char(36)+"UNSET"+char(96)+"missing"+char(39)+char(34)+"opaque")
    }
    tempfile causefile
    capture log close legacy_cause
    log using `"`causefile'"', text replace name(legacy_cause)
    _tt_seed_r full
    qa_state_snapshot, tag(corr_legacy)
    * expect: REFUSED
    capture noisily corrtab x id, full spearman xlsx(`"`macval(output)'"')
    local call_rc=_rc
    tempname cc nn
    matrix `cc'=r(C)
    matrix `nn'=r(N)
    assert !missing(`cc'[1,1],`cc'[1,2],`cc'[2,2]) & abs(`cc'[1,1]-1)<1e-12 & abs(`cc'[1,2]-1)<1e-12 & abs(`cc'[2,2]-1)<1e-12
    assert `nn'[1,1]==40 & `nn'[1,2]==40 & `nn'[2,2]==40
    assert strpos(`"`r(methods)'"',"Spearman")>0
    matrix drop `cc' `nn' 
    qa_state_compare, tag(corr_legacy)
    assert `call_rc'==16106
    log close legacy_cause
    python: assert 'Failed to export' in Path(Macro.getLocal('causefile')).read_text()
    python: assert _tt_corr_tree()==_tt_corr_before
}
local outcome=_rc
capture log close legacy_cause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: opaque late_export rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: opaque late_export"
}

capture macro drop S_1 S_4 S_6
display "RESULT: test_corrtab_fixture_legacy tests=`tests' pass=`pass' fail=`fail'"
log close _all
if `fail' exit 1
