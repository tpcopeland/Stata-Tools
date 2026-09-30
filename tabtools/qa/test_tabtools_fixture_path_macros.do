*! test_tabtools_fixture_path_macros.do -- refuse literal macro-looking filename bytes
*! Author: Timothy P Copeland, Karolinska Institutet
version 17
clear all
set more off
capture log close _all
log using test_tabtools_fixture_path_macros.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
java set heapmax 256m
run "`pkg_dir'/_tabtools_common.ado"
do _qa_fx_a7.do
do _qa_state.do
global QA_PATH_BAIT allowed
local tests 0
local pass 0
local fail 0
python:
from sfi import Macro
from pathlib import Path
import hashlib
def _tt_macro_tree():
    root=Path(Macro.getLocal('root'))
    return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()}
end

**# helper dollar
local ++tests
local root ""
capture noisily {
    local kind dollar
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/"+(st_local("kind")=="dollar" ? char(36)+"QA_PATH_BAIT" : char(96)+"_orig_varabbrev"+char(39))+".xlsx")
    global QA_PATH_BAIT allowed
    python: _tt_macro_before=_tt_macro_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_macrofile)
    tempfile causefile
    capture log close tt_macrocause
    log using `"`causefile'"', text replace name(tt_macrocause)
    * expect: REFUSED
    capture noisily _tabtools_validate_path `"`macval(output)'"' "xlsx()"
    local call_rc=_rc
    log close tt_macrocause
    assert `call_rc'==198
    python: assert 'xlsx() contains invalid characters' in Path(Macro.getLocal("causefile")).read_text()
    python: assert _tt_macro_tree()==_tt_macro_before
    qa_state_compare, tag(tt_macrofile)
}
local outcome=_rc
capture restore
capture log close tt_macrocause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: helper dollar rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: helper dollar"
}

**# helper backtick
local ++tests
local root ""
capture noisily {
    local kind backtick
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/"+(st_local("kind")=="dollar" ? char(36)+"QA_PATH_BAIT" : char(96)+"_orig_varabbrev"+char(39))+".xlsx")
    global QA_PATH_BAIT allowed
    python: _tt_macro_before=_tt_macro_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_macrofile)
    tempfile causefile
    capture log close tt_macrocause
    log using `"`causefile'"', text replace name(tt_macrocause)
    * expect: REFUSED
    capture noisily _tabtools_validate_path `"`macval(output)'"' "xlsx()"
    local call_rc=_rc
    log close tt_macrocause
    assert `call_rc'==198
    python: assert 'xlsx() contains invalid characters' in Path(Macro.getLocal("causefile")).read_text()
    python: assert _tt_macro_tree()==_tt_macro_before
    qa_state_compare, tag(tt_macrofile)
}
local outcome=_rc
capture restore
capture log close tt_macrocause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: helper backtick rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: helper backtick"
}

**# helper_absent dollar
local ++tests
local root ""
capture noisily {
    local kind dollar
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/"+(st_local("kind")=="dollar" ? char(36)+"QA_PATH_BAIT" : char(96)+"_orig_varabbrev"+char(39))+".xlsx")
    macro drop QA_PATH_BAIT
    python: _tt_macro_before=_tt_macro_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_macrofile)
    tempfile causefile
    capture log close tt_macrocause
    log using `"`causefile'"', text replace name(tt_macrocause)
    * expect: REFUSED
    capture noisily _tabtools_validate_path `"`macval(output)'"' "xlsx()"
    local call_rc=_rc
    log close tt_macrocause
    assert `call_rc'==198
    python: assert 'xlsx() contains invalid characters' in Path(Macro.getLocal("causefile")).read_text()
    python: assert _tt_macro_tree()==_tt_macro_before
    qa_state_compare, tag(tt_macrofile)
}
local outcome=_rc
capture restore
capture log close tt_macrocause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: helper_absent dollar rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: helper_absent dollar"
}

**# helper_absent backtick
local ++tests
local root ""
capture noisily {
    local kind backtick
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/"+(st_local("kind")=="dollar" ? char(36)+"QA_PATH_BAIT" : char(96)+"_orig_varabbrev"+char(39))+".xlsx")
    macro drop QA_PATH_BAIT
    python: _tt_macro_before=_tt_macro_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_macrofile)
    tempfile causefile
    capture log close tt_macrocause
    log using `"`causefile'"', text replace name(tt_macrocause)
    * expect: REFUSED
    capture noisily _tabtools_validate_path `"`macval(output)'"' "xlsx()"
    local call_rc=_rc
    log close tt_macrocause
    assert `call_rc'==198
    python: assert 'xlsx() contains invalid characters' in Path(Macro.getLocal("causefile")).read_text()
    python: assert _tt_macro_tree()==_tt_macro_before
    qa_state_compare, tag(tt_macrofile)
}
local outcome=_rc
capture restore
capture log close tt_macrocause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: helper_absent backtick rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: helper_absent backtick"
}

**# helper_opaque dollar
local ++tests
local root ""
capture noisily {
    local kind dollar
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/"+(st_local("kind")=="dollar" ? char(36)+"QA_PATH_BAIT" : char(96)+"_orig_varabbrev"+char(39))+".xlsx")
    mata: st_global("QA_PATH_BAIT",char(36)+"UNSET"+char(96)+"missing"+char(39)+char(34)+"opaque")
    python: _tt_macro_before=_tt_macro_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_macrofile)
    tempfile causefile
    capture log close tt_macrocause
    log using `"`causefile'"', text replace name(tt_macrocause)
    * expect: REFUSED
    capture noisily _tabtools_validate_path `"`macval(output)'"' "xlsx()"
    local call_rc=_rc
    log close tt_macrocause
    assert `call_rc'==198
    python: assert 'xlsx() contains invalid characters' in Path(Macro.getLocal("causefile")).read_text()
    python: assert _tt_macro_tree()==_tt_macro_before
    qa_state_compare, tag(tt_macrofile)
}
local outcome=_rc
capture restore
capture log close tt_macrocause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: helper_opaque dollar rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: helper_opaque dollar"
}

**# helper_opaque backtick
local ++tests
local root ""
capture noisily {
    local kind backtick
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/"+(st_local("kind")=="dollar" ? char(36)+"QA_PATH_BAIT" : char(96)+"_orig_varabbrev"+char(39))+".xlsx")
    mata: st_global("QA_PATH_BAIT",char(36)+"UNSET"+char(96)+"missing"+char(39)+char(34)+"opaque")
    python: _tt_macro_before=_tt_macro_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_macrofile)
    tempfile causefile
    capture log close tt_macrocause
    log using `"`causefile'"', text replace name(tt_macrocause)
    * expect: REFUSED
    capture noisily _tabtools_validate_path `"`macval(output)'"' "xlsx()"
    local call_rc=_rc
    log close tt_macrocause
    assert `call_rc'==198
    python: assert 'xlsx() contains invalid characters' in Path(Macro.getLocal("causefile")).read_text()
    python: assert _tt_macro_tree()==_tt_macro_before
    qa_state_compare, tag(tt_macrofile)
}
local outcome=_rc
capture restore
capture log close tt_macrocause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: helper_opaque backtick rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: helper_opaque backtick"
}

**# helper_local_absent dollar
local ++tests
local root ""
capture noisily {
    local kind dollar
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/"+(st_local("kind")=="dollar" ? char(36)+"QA_PATH_BAIT" : char(96)+"_orig_varabbrev"+char(39))+".xlsx")
    global QA_PATH_BAIT allowed
    python: _tt_macro_before=_tt_macro_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_macrofile)
    tempfile causefile
    capture log close tt_macrocause
    log using `"`causefile'"', text replace name(tt_macrocause)
    * expect: REFUSED
    capture noisily _tabtools_validate_path `"`macval(output)'"' "xlsx()"
    local call_rc=_rc
    log close tt_macrocause
    assert `call_rc'==198
    python: assert 'xlsx() contains invalid characters' in Path(Macro.getLocal("causefile")).read_text()
    python: assert _tt_macro_tree()==_tt_macro_before
    qa_state_compare, tag(tt_macrofile)
}
local outcome=_rc
capture restore
capture log close tt_macrocause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: helper_local_absent dollar rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: helper_local_absent dollar"
}

**# helper_local_absent backtick
local ++tests
local root ""
capture noisily {
    local kind backtick
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/"+(st_local("kind")=="dollar" ? char(36)+"QA_PATH_BAIT" : char(96)+"_orig_varabbrev"+char(39))+".xlsx")
    global QA_PATH_BAIT allowed
    mata: st_local("output",st_local("root")+"/"+char(96)+"QA_PATH_UNDEFINED"+char(39)+".xlsx")
    python: _tt_macro_before=_tt_macro_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_macrofile)
    tempfile causefile
    capture log close tt_macrocause
    log using `"`causefile'"', text replace name(tt_macrocause)
    * expect: REFUSED
    capture noisily _tabtools_validate_path `"`macval(output)'"' "xlsx()"
    local call_rc=_rc
    log close tt_macrocause
    assert `call_rc'==198
    python: assert 'xlsx() contains invalid characters' in Path(Macro.getLocal("causefile")).read_text()
    python: assert _tt_macro_tree()==_tt_macro_before
    qa_state_compare, tag(tt_macrofile)
}
local outcome=_rc
capture restore
capture log close tt_macrocause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: helper_local_absent backtick rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: helper_local_absent backtick"
}

**# corrtab dollar
local ++tests
local root ""
capture noisily {
    local kind dollar
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/"+(st_local("kind")=="dollar" ? char(36)+"QA_PATH_BAIT" : char(96)+"_orig_varabbrev"+char(39))+".xlsx")
    global QA_PATH_BAIT allowed
    python: _tt_macro_before=_tt_macro_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_macrofile)
    tempfile causefile
    capture log close tt_macrocause
    log using `"`causefile'"', text replace name(tt_macrocause)
    * expect: REFUSED
    capture noisily corrtab x id, xlsx(`"`macval(output)'"')
    local call_rc=_rc
    log close tt_macrocause
    assert `call_rc'==198
    python: assert 'xlsx() contains invalid characters' in Path(Macro.getLocal("causefile")).read_text()
    python: assert _tt_macro_tree()==_tt_macro_before
    qa_state_compare, tag(tt_macrofile)
}
local outcome=_rc
capture restore
capture log close tt_macrocause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: corrtab dollar rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: corrtab dollar"
}

**# corrtab backtick
local ++tests
local root ""
capture noisily {
    local kind backtick
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/"+(st_local("kind")=="dollar" ? char(36)+"QA_PATH_BAIT" : char(96)+"_orig_varabbrev"+char(39))+".xlsx")
    global QA_PATH_BAIT allowed
    python: _tt_macro_before=_tt_macro_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_macrofile)
    tempfile causefile
    capture log close tt_macrocause
    log using `"`causefile'"', text replace name(tt_macrocause)
    * expect: REFUSED
    capture noisily corrtab x id, xlsx(`"`macval(output)'"')
    local call_rc=_rc
    log close tt_macrocause
    assert `call_rc'==198
    python: assert 'xlsx() contains invalid characters' in Path(Macro.getLocal("causefile")).read_text()
    python: assert _tt_macro_tree()==_tt_macro_before
    qa_state_compare, tag(tt_macrofile)
}
local outcome=_rc
capture restore
capture log close tt_macrocause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: corrtab backtick rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: corrtab backtick"
}

**# corrtab_alias dollar
local ++tests
local root ""
capture noisily {
    local kind dollar
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/"+(st_local("kind")=="dollar" ? char(36)+"QA_PATH_BAIT" : char(96)+"_orig_varabbrev"+char(39))+".xlsx")
    global QA_PATH_BAIT allowed
    python: _tt_macro_before=_tt_macro_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_macrofile)
    tempfile causefile
    capture log close tt_macrocause
    log using `"`causefile'"', text replace name(tt_macrocause)
    * expect: REFUSED
    capture noisily corrtab x id, excel(`"`macval(output)'"')
    local call_rc=_rc
    log close tt_macrocause
    assert `call_rc'==198
    python: assert 'xlsx() contains invalid characters' in Path(Macro.getLocal("causefile")).read_text()
    python: assert _tt_macro_tree()==_tt_macro_before
    qa_state_compare, tag(tt_macrofile)
}
local outcome=_rc
capture restore
capture log close tt_macrocause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: corrtab_alias dollar rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: corrtab_alias dollar"
}

**# corrtab_alias backtick
local ++tests
local root ""
capture noisily {
    local kind backtick
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/"+(st_local("kind")=="dollar" ? char(36)+"QA_PATH_BAIT" : char(96)+"_orig_varabbrev"+char(39))+".xlsx")
    global QA_PATH_BAIT allowed
    python: _tt_macro_before=_tt_macro_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_macrofile)
    tempfile causefile
    capture log close tt_macrocause
    log using `"`causefile'"', text replace name(tt_macrocause)
    * expect: REFUSED
    capture noisily corrtab x id, excel(`"`macval(output)'"')
    local call_rc=_rc
    log close tt_macrocause
    assert `call_rc'==198
    python: assert 'xlsx() contains invalid characters' in Path(Macro.getLocal("causefile")).read_text()
    python: assert _tt_macro_tree()==_tt_macro_before
    qa_state_compare, tag(tt_macrofile)
}
local outcome=_rc
capture restore
capture log close tt_macrocause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: corrtab_alias backtick rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: corrtab_alias backtick"
}

**# crosstab dollar
local ++tests
local root ""
capture noisily {
    local kind dollar
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/"+(st_local("kind")=="dollar" ? char(36)+"QA_PATH_BAIT" : char(96)+"_orig_varabbrev"+char(39))+".xlsx")
    global QA_PATH_BAIT allowed
    python: _tt_macro_before=_tt_macro_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_macrofile)
    tempfile causefile
    capture log close tt_macrocause
    log using `"`causefile'"', text replace name(tt_macrocause)
    * expect: REFUSED
    capture noisily crosstab group y, xlsx(`"`macval(output)'"')
    local call_rc=_rc
    log close tt_macrocause
    assert `call_rc'==198
    python: assert 'xlsx() contains invalid characters' in Path(Macro.getLocal("causefile")).read_text()
    python: assert _tt_macro_tree()==_tt_macro_before
    qa_state_compare, tag(tt_macrofile)
}
local outcome=_rc
capture restore
capture log close tt_macrocause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: crosstab dollar rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: crosstab dollar"
}

**# crosstab backtick
local ++tests
local root ""
capture noisily {
    local kind backtick
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/"+(st_local("kind")=="dollar" ? char(36)+"QA_PATH_BAIT" : char(96)+"_orig_varabbrev"+char(39))+".xlsx")
    global QA_PATH_BAIT allowed
    python: _tt_macro_before=_tt_macro_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_macrofile)
    tempfile causefile
    capture log close tt_macrocause
    log using `"`causefile'"', text replace name(tt_macrocause)
    * expect: REFUSED
    capture noisily crosstab group y, xlsx(`"`macval(output)'"')
    local call_rc=_rc
    log close tt_macrocause
    assert `call_rc'==198
    python: assert 'xlsx() contains invalid characters' in Path(Macro.getLocal("causefile")).read_text()
    python: assert _tt_macro_tree()==_tt_macro_before
    qa_state_compare, tag(tt_macrofile)
}
local outcome=_rc
capture restore
capture log close tt_macrocause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: crosstab backtick rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: crosstab backtick"
}

**# crosstab_alias dollar
local ++tests
local root ""
capture noisily {
    local kind dollar
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/"+(st_local("kind")=="dollar" ? char(36)+"QA_PATH_BAIT" : char(96)+"_orig_varabbrev"+char(39))+".xlsx")
    global QA_PATH_BAIT allowed
    python: _tt_macro_before=_tt_macro_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_macrofile)
    tempfile causefile
    capture log close tt_macrocause
    log using `"`causefile'"', text replace name(tt_macrocause)
    * expect: REFUSED
    capture noisily crosstab group y, excel(`"`macval(output)'"')
    local call_rc=_rc
    log close tt_macrocause
    assert `call_rc'==198
    python: assert 'xlsx() contains invalid characters' in Path(Macro.getLocal("causefile")).read_text()
    python: assert _tt_macro_tree()==_tt_macro_before
    qa_state_compare, tag(tt_macrofile)
}
local outcome=_rc
capture restore
capture log close tt_macrocause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: crosstab_alias dollar rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: crosstab_alias dollar"
}

**# crosstab_alias backtick
local ++tests
local root ""
capture noisily {
    local kind backtick
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/"+(st_local("kind")=="dollar" ? char(36)+"QA_PATH_BAIT" : char(96)+"_orig_varabbrev"+char(39))+".xlsx")
    global QA_PATH_BAIT allowed
    python: _tt_macro_before=_tt_macro_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_macrofile)
    tempfile causefile
    capture log close tt_macrocause
    log using `"`causefile'"', text replace name(tt_macrocause)
    * expect: REFUSED
    capture noisily crosstab group y, excel(`"`macval(output)'"')
    local call_rc=_rc
    log close tt_macrocause
    assert `call_rc'==198
    python: assert 'xlsx() contains invalid characters' in Path(Macro.getLocal("causefile")).read_text()
    python: assert _tt_macro_tree()==_tt_macro_before
    qa_state_compare, tag(tt_macrofile)
}
local outcome=_rc
capture restore
capture log close tt_macrocause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: crosstab_alias backtick rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: crosstab_alias backtick"
}

**# desctab dollar
local ++tests
local root ""
capture noisily {
    local kind dollar
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/"+(st_local("kind")=="dollar" ? char(36)+"QA_PATH_BAIT" : char(96)+"_orig_varabbrev"+char(39))+".xlsx")
    global QA_PATH_BAIT allowed
    python: _tt_macro_before=_tt_macro_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_macrofile)
    tempfile causefile
    capture log close tt_macrocause
    log using `"`causefile'"', text replace name(tt_macrocause)
    * expect: REFUSED
    capture noisily desctab, by(group) vars(x contn %9.1f) xlsx(`"`macval(output)'"')
    local call_rc=_rc
    log close tt_macrocause
    assert `call_rc'==198
    python: assert 'excel() contains invalid characters' in Path(Macro.getLocal("causefile")).read_text()
    python: assert _tt_macro_tree()==_tt_macro_before
    qa_state_compare, tag(tt_macrofile)
}
local outcome=_rc
capture restore
capture log close tt_macrocause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: desctab dollar rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab dollar"
}

**# desctab backtick
local ++tests
local root ""
capture noisily {
    local kind backtick
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/"+(st_local("kind")=="dollar" ? char(36)+"QA_PATH_BAIT" : char(96)+"_orig_varabbrev"+char(39))+".xlsx")
    global QA_PATH_BAIT allowed
    python: _tt_macro_before=_tt_macro_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_macrofile)
    tempfile causefile
    capture log close tt_macrocause
    log using `"`causefile'"', text replace name(tt_macrocause)
    * expect: REFUSED
    capture noisily desctab, by(group) vars(x contn %9.1f) xlsx(`"`macval(output)'"')
    local call_rc=_rc
    log close tt_macrocause
    assert `call_rc'==198
    python: assert 'excel() contains invalid characters' in Path(Macro.getLocal("causefile")).read_text()
    python: assert _tt_macro_tree()==_tt_macro_before
    qa_state_compare, tag(tt_macrofile)
}
local outcome=_rc
capture restore
capture log close tt_macrocause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: desctab backtick rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab backtick"
}

**# desctab_alias dollar
local ++tests
local root ""
capture noisily {
    local kind dollar
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/"+(st_local("kind")=="dollar" ? char(36)+"QA_PATH_BAIT" : char(96)+"_orig_varabbrev"+char(39))+".xlsx")
    global QA_PATH_BAIT allowed
    python: _tt_macro_before=_tt_macro_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_macrofile)
    tempfile causefile
    capture log close tt_macrocause
    log using `"`causefile'"', text replace name(tt_macrocause)
    * expect: REFUSED
    capture noisily desctab, by(group) vars(x contn %9.1f) excel(`"`macval(output)'"')
    local call_rc=_rc
    log close tt_macrocause
    assert `call_rc'==198
    python: assert 'excel() contains invalid characters' in Path(Macro.getLocal("causefile")).read_text()
    python: assert _tt_macro_tree()==_tt_macro_before
    qa_state_compare, tag(tt_macrofile)
}
local outcome=_rc
capture restore
capture log close tt_macrocause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: desctab_alias dollar rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab_alias dollar"
}

**# desctab_alias backtick
local ++tests
local root ""
capture noisily {
    local kind backtick
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    mata: st_local("output",st_local("root")+"/"+(st_local("kind")=="dollar" ? char(36)+"QA_PATH_BAIT" : char(96)+"_orig_varabbrev"+char(39))+".xlsx")
    global QA_PATH_BAIT allowed
    python: _tt_macro_before=_tt_macro_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_macrofile)
    tempfile causefile
    capture log close tt_macrocause
    log using `"`causefile'"', text replace name(tt_macrocause)
    * expect: REFUSED
    capture noisily desctab, by(group) vars(x contn %9.1f) excel(`"`macval(output)'"')
    local call_rc=_rc
    log close tt_macrocause
    assert `call_rc'==198
    python: assert 'excel() contains invalid characters' in Path(Macro.getLocal("causefile")).read_text()
    python: assert _tt_macro_tree()==_tt_macro_before
    qa_state_compare, tag(tt_macrofile)
}
local outcome=_rc
capture restore
capture log close tt_macrocause
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: desctab_alias backtick rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab_alias backtick"
}

macro drop QA_PATH_BAIT
display "RESULT: test_tabtools_fixture_path_macros tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
