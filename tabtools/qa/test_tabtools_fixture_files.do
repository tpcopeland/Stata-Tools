*! test_tabtools_fixture_files.do -- real table cells and owned-tree preservation
*! Author: Timothy P Copeland, Karolinska Institutet
version 17.0
clear all
set more off
capture log close _all
log using test_tabtools_fixture_files.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
java set heapmax 256m
do _qa_fx_a7.do
do _qa_state.do
local tests 0
local pass 0
local fail 0
python:
from pathlib import Path
from sfi import Macro
from openpyxl import load_workbook
import hashlib

def _tt_tree():
    root=Path(Macro.getLocal('root'))
    return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()}

def _tt_file_cells():
    cmd=Macro.getLocal('consumer')
    w=load_workbook(Macro.getLocal('output'))
    t=w['package_summary']
    assert t['A1'].value=='Known cells'
    if cmd=='corrtab':
        assert [t.cell(2,c).value for c in (3,4)]==['Exact sequence 1–40','id']
        assert [t.cell(3,c).value for c in (3,4)]==['1.00','1.00***']
        assert [t.cell(4,c).value for c in (3,4)]==['1.00***','1.00']
        assert t.max_row==5 and t.max_column==4
    elif cmd=='crosstab':
        assert [t.cell(2,c).value for c in (2,3,4,5)]==['group','0','1','Total']
        for row,code in enumerate([1,2,5,9],3):
            assert [t.cell(row,c).value for c in (2,3,4,5)]==[str(code),'5 (25.0%)','5 (25.0%)','10']
        assert [t.cell(7,c).value for c in (2,3,4,5)]==['Total','20','20','40']
        # 2.6.2: p from 0.10 prints two decimals (the package p-value rule)
        assert t['B8'].value=="Pearson's chi-squared test: chi2 = 0.00, p = 1.00"
        assert t.max_row==8 and t.max_column==5
    else:
        assert t['B4'].value=='Exact sequence 1–40'
        assert [t.cell(3,c).value for c in range(3,7)]==['N=10']*4
        assert [t.cell(4,c).value for c in range(3,7)]==['5.5±3.0','15.5±3.0','25.5±3.0','35.5±3.0']
        assert t['G4'].value=='<0.001'
        assert t.max_row==4 and t.max_column==7
    if Macro.getLocal('case')=='stale_sheet':
        assert w['user_notes']['A1'].value=='USER_KEEP'
        assert w['package_detail']['A1'].value=='STALE_DETAIL'
    w.close()
end

**# corrtab path_hostile
local ++tests
local root ""
capture noisily {
    local consumer corrtab
    local case path_hostile
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    python: _tt_before=_tt_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_files)
    * expect: REFUSED
    tempfile path_cause
    capture log close tt_pathcause
    log using `"`path_cause'"', text replace name(tt_pathcause)
    capture noisily corrtab x id, full xlsx(`"`macval(output)'"') sheet(package_summary) title("Known cells")
    local call_rc=_rc
    log close tt_pathcause
    python: assert 'xlsx() contains invalid characters' in Path(Macro.getLocal("path_cause")).read_text()
    assert `call_rc'==198
    python: assert _tt_tree()==_tt_before
    qa_state_compare, tag(tt_files)
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: corrtab path_hostile rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: corrtab path_hostile"
}

**# corrtab path_hostile_alias
local ++tests
local root ""
capture noisily {
    local consumer corrtab
    local case path_hostile_alias
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    python: _tt_before=_tt_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_files)
    * expect: REFUSED
    tempfile path_cause
    capture log close tt_pathcause
    log using `"`path_cause'"', text replace name(tt_pathcause)
    capture noisily corrtab x id, full excel(`"`macval(output)'"') sheet(package_summary) title("Known cells")
    local call_rc=_rc
    log close tt_pathcause
    python: assert 'xlsx() contains invalid characters' in Path(Macro.getLocal("path_cause")).read_text()
    assert `call_rc'==198
    python: assert _tt_tree()==_tt_before
    qa_state_compare, tag(tt_files)
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: corrtab path_hostile_alias rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: corrtab path_hostile_alias"
}

**# corrtab path_noext
local ++tests
local root ""
capture noisily {
    local consumer corrtab
    local case path_noext
    qa_fx_a7_files, clear seed(37) perturb(path_noext)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    python: _tt_before=_tt_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_files)
    * expect: REFUSED
    capture noisily corrtab x id, full xlsx(`"`macval(output)'"') sheet(package_summary) title("Known cells")
    local call_rc=_rc
    assert `call_rc'==198
    python: assert _tt_tree()==_tt_before
    qa_state_compare, tag(tt_files)
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: corrtab path_noext rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: corrtab path_noext"
}

**# corrtab stale_sheet
local ++tests
local root ""
capture noisily {
    local consumer corrtab
    local case stale_sheet
    qa_fx_a7_files, clear seed(37) perturb(stale_sheet)
    local root `"`r(root)'"'
    local output `"`r(path_xlsx)'"'
    python: _tt_before=_tt_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_files)
    * expect: EXACT
    quietly corrtab x id, full xlsx(`"`macval(output)'"') sheet(package_summary) title("Known cells")
    python: _tt_file_cells()
    python: _tt_after=_tt_tree(); _tt_changed=str(Path(Macro.getLocal("output")).relative_to(Path(Macro.getLocal("root")))); assert {k:v for k,v in _tt_after.items() if k!=_tt_changed}=={k:v for k,v in _tt_before.items() if k!=_tt_changed}
    qa_state_compare, tag(tt_files)
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: corrtab stale_sheet rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: corrtab stale_sheet"
}

**# corrtab unicode_spaces
local ++tests
local root ""
capture noisily {
    local consumer corrtab
    local case unicode_spaces
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local output `"`r(path_xlsx)'"'
    local output `"`macval(root)'/Accepted Å spaces.xlsx"'
    python: _tt_before=_tt_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_files)
    * expect: EXACT
    quietly corrtab x id, full xlsx(`"`macval(output)'"') sheet(package_summary) title("Known cells")
    python: _tt_file_cells()
    python: _tt_after=_tt_tree(); _tt_changed=str(Path(Macro.getLocal("output")).relative_to(Path(Macro.getLocal("root")))); assert {k:v for k,v in _tt_after.items() if k!=_tt_changed}=={k:v for k,v in _tt_before.items() if k!=_tt_changed}
    qa_state_compare, tag(tt_files)
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: corrtab unicode_spaces rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: corrtab unicode_spaces"
}

**# corrtab unicode_spaces_alias
local ++tests
local root ""
capture noisily {
    local consumer corrtab
    local case unicode_spaces_alias
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local output `"`r(path_xlsx)'"'
    local output `"`macval(root)'/Accepted Å spaces.xlsx"'
    python: _tt_before=_tt_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_files)
    * expect: EXACT
    quietly corrtab x id, full excel(`"`macval(output)'"') sheet(package_summary) title("Known cells")
    python: _tt_file_cells()
    python: _tt_after=_tt_tree(); _tt_changed=str(Path(Macro.getLocal("output")).relative_to(Path(Macro.getLocal("root")))); assert {k:v for k,v in _tt_after.items() if k!=_tt_changed}=={k:v for k,v in _tt_before.items() if k!=_tt_changed}
    qa_state_compare, tag(tt_files)
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: corrtab unicode_spaces_alias rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: corrtab unicode_spaces_alias"
}

**# crosstab path_hostile
local ++tests
local root ""
capture noisily {
    local consumer crosstab
    local case path_hostile
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    python: _tt_before=_tt_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_files)
    * expect: REFUSED
    tempfile path_cause
    capture log close tt_pathcause
    log using `"`path_cause'"', text replace name(tt_pathcause)
    capture noisily crosstab group y, xlsx(`"`macval(output)'"') sheet(package_summary) title("Known cells")
    local call_rc=_rc
    log close tt_pathcause
    python: assert 'xlsx() contains invalid characters' in Path(Macro.getLocal("path_cause")).read_text()
    assert `call_rc'==198
    python: assert _tt_tree()==_tt_before
    qa_state_compare, tag(tt_files)
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: crosstab path_hostile rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: crosstab path_hostile"
}

**# crosstab path_hostile_alias
local ++tests
local root ""
capture noisily {
    local consumer crosstab
    local case path_hostile_alias
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    python: _tt_before=_tt_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_files)
    * expect: REFUSED
    tempfile path_cause
    capture log close tt_pathcause
    log using `"`path_cause'"', text replace name(tt_pathcause)
    capture noisily crosstab group y, excel(`"`macval(output)'"') sheet(package_summary) title("Known cells")
    local call_rc=_rc
    log close tt_pathcause
    python: assert 'xlsx() contains invalid characters' in Path(Macro.getLocal("path_cause")).read_text()
    assert `call_rc'==198
    python: assert _tt_tree()==_tt_before
    qa_state_compare, tag(tt_files)
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: crosstab path_hostile_alias rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: crosstab path_hostile_alias"
}

**# crosstab path_noext
local ++tests
local root ""
capture noisily {
    local consumer crosstab
    local case path_noext
    qa_fx_a7_files, clear seed(37) perturb(path_noext)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    python: _tt_before=_tt_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_files)
    * expect: REFUSED
    capture noisily crosstab group y, xlsx(`"`macval(output)'"') sheet(package_summary) title("Known cells")
    local call_rc=_rc
    assert `call_rc'==198
    python: assert _tt_tree()==_tt_before
    qa_state_compare, tag(tt_files)
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: crosstab path_noext rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: crosstab path_noext"
}

**# crosstab stale_sheet
local ++tests
local root ""
capture noisily {
    local consumer crosstab
    local case stale_sheet
    qa_fx_a7_files, clear seed(37) perturb(stale_sheet)
    local root `"`r(root)'"'
    local output `"`r(path_xlsx)'"'
    python: _tt_before=_tt_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_files)
    * expect: EXACT
    quietly crosstab group y, xlsx(`"`macval(output)'"') sheet(package_summary) title("Known cells")
    python: _tt_file_cells()
    python: _tt_after=_tt_tree(); _tt_changed=str(Path(Macro.getLocal("output")).relative_to(Path(Macro.getLocal("root")))); assert {k:v for k,v in _tt_after.items() if k!=_tt_changed}=={k:v for k,v in _tt_before.items() if k!=_tt_changed}
    qa_state_compare, tag(tt_files)
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: crosstab stale_sheet rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: crosstab stale_sheet"
}

**# crosstab unicode_spaces
local ++tests
local root ""
capture noisily {
    local consumer crosstab
    local case unicode_spaces
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local output `"`r(path_xlsx)'"'
    local output `"`macval(root)'/Accepted Å spaces.xlsx"'
    python: _tt_before=_tt_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_files)
    * expect: EXACT
    quietly crosstab group y, xlsx(`"`macval(output)'"') sheet(package_summary) title("Known cells")
    python: _tt_file_cells()
    python: _tt_after=_tt_tree(); _tt_changed=str(Path(Macro.getLocal("output")).relative_to(Path(Macro.getLocal("root")))); assert {k:v for k,v in _tt_after.items() if k!=_tt_changed}=={k:v for k,v in _tt_before.items() if k!=_tt_changed}
    qa_state_compare, tag(tt_files)
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: crosstab unicode_spaces rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: crosstab unicode_spaces"
}

**# crosstab unicode_spaces_alias
local ++tests
local root ""
capture noisily {
    local consumer crosstab
    local case unicode_spaces_alias
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local output `"`r(path_xlsx)'"'
    local output `"`macval(root)'/Accepted Å spaces.xlsx"'
    python: _tt_before=_tt_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_files)
    * expect: EXACT
    quietly crosstab group y, excel(`"`macval(output)'"') sheet(package_summary) title("Known cells")
    python: _tt_file_cells()
    python: _tt_after=_tt_tree(); _tt_changed=str(Path(Macro.getLocal("output")).relative_to(Path(Macro.getLocal("root")))); assert {k:v for k,v in _tt_after.items() if k!=_tt_changed}=={k:v for k,v in _tt_before.items() if k!=_tt_changed}
    qa_state_compare, tag(tt_files)
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: crosstab unicode_spaces_alias rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: crosstab unicode_spaces_alias"
}

**# desctab path_hostile
local ++tests
local root ""
capture noisily {
    local consumer desctab
    local case path_hostile
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    python: _tt_before=_tt_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_files)
    * expect: REFUSED
    tempfile path_cause
    capture log close tt_pathcause
    log using `"`path_cause'"', text replace name(tt_pathcause)
    capture noisily desctab, by(group) vars(x contn %9.1f) xlsx(`"`macval(output)'"') sheet(package_summary) title("Known cells")
    local call_rc=_rc
    log close tt_pathcause
    python: assert 'excel() contains invalid characters' in Path(Macro.getLocal("path_cause")).read_text()
    assert `call_rc'==198
    python: assert _tt_tree()==_tt_before
    qa_state_compare, tag(tt_files)
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: desctab path_hostile rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab path_hostile"
}

**# desctab path_hostile_alias
local ++tests
local root ""
capture noisily {
    local consumer desctab
    local case path_hostile_alias
    qa_fx_a7_files, clear seed(37) perturb(path_hostile)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    python: _tt_before=_tt_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_files)
    * expect: REFUSED
    tempfile path_cause
    capture log close tt_pathcause
    log using `"`path_cause'"', text replace name(tt_pathcause)
    capture noisily desctab, by(group) vars(x contn %9.1f) excel(`"`macval(output)'"') sheet(package_summary) title("Known cells")
    local call_rc=_rc
    log close tt_pathcause
    python: assert 'excel() contains invalid characters' in Path(Macro.getLocal("path_cause")).read_text()
    assert `call_rc'==198
    python: assert _tt_tree()==_tt_before
    qa_state_compare, tag(tt_files)
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: desctab path_hostile_alias rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab path_hostile_alias"
}

**# desctab path_noext
local ++tests
local root ""
capture noisily {
    local consumer desctab
    local case path_noext
    qa_fx_a7_files, clear seed(37) perturb(path_noext)
    local root `"`r(root)'"'
    local output `"`r(path_active)'"'
    python: _tt_before=_tt_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_files)
    * expect: REFUSED
    capture noisily desctab, by(group) vars(x contn %9.1f) xlsx(`"`macval(output)'"') sheet(package_summary) title("Known cells")
    local call_rc=_rc
    assert `call_rc'==198
    python: assert _tt_tree()==_tt_before
    qa_state_compare, tag(tt_files)
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: desctab path_noext rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab path_noext"
}

**# desctab stale_sheet
local ++tests
local root ""
capture noisily {
    local consumer desctab
    local case stale_sheet
    qa_fx_a7_files, clear seed(37) perturb(stale_sheet)
    local root `"`r(root)'"'
    local output `"`r(path_xlsx)'"'
    python: _tt_before=_tt_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_files)
    * expect: EXACT
    quietly desctab, by(group) vars(x contn %9.1f) xlsx(`"`macval(output)'"') sheet(package_summary) title("Known cells")
    python: _tt_file_cells()
    python: _tt_after=_tt_tree(); _tt_changed=str(Path(Macro.getLocal("output")).relative_to(Path(Macro.getLocal("root")))); assert {k:v for k,v in _tt_after.items() if k!=_tt_changed}=={k:v for k,v in _tt_before.items() if k!=_tt_changed}
    qa_state_compare, tag(tt_files)
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: desctab stale_sheet rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab stale_sheet"
}

**# desctab unicode_spaces
local ++tests
local root ""
capture noisily {
    local consumer desctab
    local case unicode_spaces
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local output `"`r(path_xlsx)'"'
    local output `"`macval(root)'/Accepted Å spaces.xlsx"'
    python: _tt_before=_tt_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_files)
    * expect: EXACT
    quietly desctab, by(group) vars(x contn %9.1f) xlsx(`"`macval(output)'"') sheet(package_summary) title("Known cells")
    python: _tt_file_cells()
    python: _tt_after=_tt_tree(); _tt_changed=str(Path(Macro.getLocal("output")).relative_to(Path(Macro.getLocal("root")))); assert {k:v for k,v in _tt_after.items() if k!=_tt_changed}=={k:v for k,v in _tt_before.items() if k!=_tt_changed}
    qa_state_compare, tag(tt_files)
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: desctab unicode_spaces rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab unicode_spaces"
}

**# desctab unicode_spaces_alias
local ++tests
local root ""
capture noisily {
    local consumer desctab
    local case unicode_spaces_alias
    qa_fx_a7_files, clear seed(37)
    local root `"`r(root)'"'
    local output `"`r(path_xlsx)'"'
    local output `"`macval(root)'/Accepted Å spaces.xlsx"'
    python: _tt_before=_tt_tree()
    qa_fx_a7_labelled, clear seed(37)
    qa_state_snapshot, tag(tt_files)
    * expect: EXACT
    quietly desctab, by(group) vars(x contn %9.1f) excel(`"`macval(output)'"') sheet(package_summary) title("Known cells")
    python: _tt_file_cells()
    python: _tt_after=_tt_tree(); _tt_changed=str(Path(Macro.getLocal("output")).relative_to(Path(Macro.getLocal("root")))); assert {k:v for k,v in _tt_after.items() if k!=_tt_changed}=={k:v for k,v in _tt_before.items() if k!=_tt_changed}
    qa_state_compare, tag(tt_files)
}
local outcome=_rc
capture restore
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: desctab unicode_spaces_alias rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab unicode_spaces_alias"
}

display "RESULT: test_tabtools_fixture_files tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
