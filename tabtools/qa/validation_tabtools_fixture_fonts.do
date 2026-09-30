*! validation_tabtools_fixture_fonts.do -- nominal font options in actual workbook styles
*! Author: Timothy P Copeland, Karolinska Institutet
* font() has an unrestricted documented string domain; no invented numeric limit.
version 17
clear all
set more off
capture log close _all
log using validation_tabtools_fixture_fonts.log, text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
do _qa_fx_a7.do
do _qa_metamorphic.do
java set heapmax 256m
program define _tt_font_setup
    qa_fx_a7_labelled, clear seed(37)
end
local tests 0
local pass 0
local fail 0
python:
from pathlib import Path
from sfi import Macro
from openpyxl import load_workbook
import hashlib, re, sys, types
def _tt_font_unrelated():
    return {str(p.relative_to(_tt_font_root)):hashlib.sha256(p.read_bytes()).hexdigest()
            for p in _tt_font_root.rglob('*') if p.is_file() and p!=_tt_font_output}
def _tt_font_check():
    w=load_workbook(_tt_font_output)
    s=w['package_summary']
    assert s['A1'].value=='Known font'
    if _tt_font_command=='corrtab':
        assert s['C3'].value=='1.00' and s['D3'].value=='1.00***'
        cells=('B3','C3','D3','B4','C4','D4')
    else:
        assert s['C4'].value=='5.5±3.0' and s['D4'].value=='15.5±3.0'
        cells=('B4','C4','D4','E4','F4')
    request=re.search(r'font\("([^\"]*)"\)',Macro.getLocal('cmd'))
    assert request is not None
    expected=request.group(1) or 'Arial'
    assert expected in ('Arial','Courier New','Ångström 研究')
    assert all(s[c].font.name==expected for c in cells)
    assert w['user_notes']['A1'].value=='USER_KEEP'
    assert w['package_detail']['A1'].value=='STALE_DETAIL'
    w.close()
    assert _tt_font_unrelated()==_tt_font_before
_tt_font_module=types.ModuleType('_tt_font_oracle')
_tt_font_module.check=_tt_font_check
sys.modules['_tt_font_oracle']=_tt_font_module
end

**# corrtab nominal font domain
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37) perturb(stale_sheet)
    local root `"`r(root)'"'
    local output `"`r(path_xlsx)'"'
    python: _tt_font_root=Path(Macro.getLocal('root')); _tt_font_output=Path(Macro.getLocal('output')); _tt_font_command='corrtab'; _tt_font_before=_tt_font_unrelated()
    qa_fx_a7_labelled, clear seed(37)
    * expect: EXACT
    qa_option_domain, command(corrtab x id, full font("@v@") xlsx(`"`macval(output)'"') sheet(package_summary) title("Known font")) inside(";Arial;Courier New;Ångström 研究") setup(_tt_font_setup) check(python: __import__('_tt_font_oracle').check())
    assert r(n_cells)==4 & r(n_violations)==0
}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: corrtab font domain rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: corrtab font domain"
}

**# desctab nominal font domain
local ++tests
local root ""
capture noisily {
    qa_fx_a7_files, clear seed(37) perturb(stale_sheet)
    local root `"`r(root)'"'
    local output `"`r(path_xlsx)'"'
    python: _tt_font_root=Path(Macro.getLocal('root')); _tt_font_output=Path(Macro.getLocal('output')); _tt_font_command='desctab'; _tt_font_before=_tt_font_unrelated()
    qa_fx_a7_labelled, clear seed(37)
    * expect: EXACT
    qa_option_domain, command(desctab, by(group) vars(x contn %9.1f) font("@v@") xlsx(`"`macval(output)'"') sheet(package_summary) title("Known font")) inside(";Arial;Courier New;Ångström 研究") setup(_tt_font_setup) check(python: __import__('_tt_font_oracle').check())
    assert r(n_cells)==4 & r(n_violations)==0
}
local outcome=_rc
if `"`macval(root)'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`macval(root)'"')
    if _rc & !`outcome' local outcome=_rc
}
if `outcome' {
    local ++fail
    display as error "FAIL: desctab font domain rc=" `outcome'
}
else {
    local ++pass
    display as result "PASS: desctab font domain"
}

display "RESULT: validation_tabtools_fixture_fonts tests=`tests' pass=`pass' fail=`fail'"
log close _all
if `fail' exit 1
