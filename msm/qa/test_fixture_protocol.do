* test_fixture_protocol.do -- canonical protocol text and owned file-tree exports
* Author: Timothy P Copeland, Karolinska Institutet
* guard: canonical adoption; errors retain strict fingerprints.
version 16.0
clear all
set more off
set varabbrev off
set processors 1
capture log close _all
local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"
do "`qa_dir'/_qa_fx_a7.do"
do "`qa_dir'/_qa_hostile.do"
do "`qa_dir'/_qa_state.do"
local test_count 0
local pass_count 0
local fail_count 0
python:
def textcheck():
    from sfi import Macro
    from pathlib import Path
    import csv
    from openpyxl import load_workbook
    expected=Macro.getLocal('payload')
    rows=list(csv.reader(open(Macro.getLocal('csv'),encoding='utf-8')))
    assert len(rows)==8 and all(r[1]==expected for r in rows[1:])
    wb=load_workbook(Macro.getLocal('book')+'.xlsx',data_only=True)
    assert [wb['Protocol'].cell(i,2).value for i in range(2,9)]==[expected]*7
    wb.close()
    tex=Path(Macro.getLocal('tex')).read_text(encoding='utf-8')
    escaped=''.join({'\\':r'\textbackslash{}','&':r'\&','%':r'\%',chr(36):chr(92)+chr(36),'#':r'\#','_':r'\_','{':r'\{','}':r'\}','~':r'\textasciitilde{}','^':r'\textasciicircum{}'}.get(c,c) for c in expected)
    assert tex.count(escaped)==7 and '\\begin{tabular}' in tex
def check2():
    from sfi import Macro
    from openpyxl import load_workbook
    w=load_workbook(Macro.getLocal('book'))
    w.create_sheet('Protocol')['Z99']='STALE_OWNED'
    w.save(Macro.getLocal('book'));w.close()
def check3():
    from sfi import Macro
    from openpyxl import load_workbook
    w=load_workbook(Macro.getLocal('book'),data_only=True)
    assert w['user_notes']['A1'].value=='USER_KEEP'
    assert w['package_summary']['A1'].value=='STALE_SUMMARY'
    assert w['Protocol']['B2'].value=='Canonical replacement' and w['Protocol']['Z99'].value is None
    w.close()
def check4():
    from sfi import Macro
    from pathlib import Path
    assert Path(Macro.getLocal('target')).read_text()=='EXTENSIONLESS_KEEP\n'
import types, sys
m=types.ModuleType('_qa_msm_protocol');m.textcheck=textcheck
m.check2=check2
m.check3=check3
m.check4=check4
sys.modules['_qa_msm_protocol']=m
end
capture program drop _fx_protocol
program define _fx_protocol
    args corpus
    if "`corpus'"=="" {
        qa_fx_a7_labelled, clear
        local payload=text[1]
    }
    else {
        mata: st_local("payload",st_global("`corpus'"))
    }
    tempfile csv book tex
    foreach format in display csv excel latex {
        local opts ""
        if "`format'"=="csv" local opts `"export("`csv'") replace"'
        if "`format'"=="excel" local opts `"export("`book'.xlsx") replace"'
        if "`format'"=="latex" local opts `"export("`tex'") replace"'
        qa_state_snapshot, tag(protocolsuccess)
        quietly msm_protocol, population(`"`macval(payload)'"') treatment(`"`macval(payload)'"') ///
            confounders(`"`macval(payload)'"') outcome(`"`macval(payload)'"') ///
            causal_contrast(`"`macval(payload)'"') weight_spec(`"`macval(payload)'"') ///
            analysis(`"`macval(payload)'"') format(`format') `opts'
        qa_state_compare, tag(protocolsuccess)
        foreach field in population treatment confounders outcome causal_contrast weight_spec analysis {
            mata: assert(st_global("r(`field')")==st_local("payload"))
        }
    }
    python: __import__('_qa_msm_protocol').textcheck()
    erase "`csv'"
    erase "`book'.xlsx"
    erase "`tex'"
end
**# F: protocol display/CSV/Excel/LaTeX preserve seven UTF-8 descriptions
local ++test_count
capture noisily _fx_protocol
if !_rc {
    local ++pass_count
    display as result "PASS: F seven protocol descriptions and real files"
}
else {
    local ++fail_count
    display as error "FAIL: F seven protocol descriptions (rc=`=_rc')"
}
**# U: string_hostile corpus remains byte-exact in returns and escaped exports
* expect: EXACT
local ++test_count
capture noisily {
    qa_hostile_strings
    local names "`r(names)'"
    foreach g of local names {
        display "CORPUS: `g'"
        _fx_protocol `g'
    }
}
if !_rc {
    local ++pass_count
    display as result "PASS: U string_hostile protocol corpus"
}
else {
    local ++fail_count
    display as error "FAIL: U string_hostile protocol corpus (rc=`=_rc')"
}
**# F/U: stale_sheet replacement preserves unrelated user cells and clears owned payload
* expect: EXACT
local ++test_count
local root ""
capture noisily {
    qa_fx_a7_files, clear perturb(stale_sheet)
    local root `"`r(root)'"'
    local book `"`r(path_xlsx)'"'
    python: __import__("_qa_msm_protocol").check2()
    quietly msm_protocol, population("Canonical replacement") treatment("A") confounders("L") outcome("Y") causal_contrast("RD") weight_spec("IPW") analysis("MSM") format(excel) export(`"`book'"') replace
    python: __import__("_qa_msm_protocol").check3()
}
local rc=_rc
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`root'"')
    if `rc'==0 local rc=_rc
}
if !`rc' {
    local ++pass_count
    display as result "PASS: U stale_sheet owned replacement/user preservation"
}
else {
    local ++fail_count
    display as error "FAIL: U stale_sheet (rc=`rc')"
}
**# U: path_noext existing CSV target refuses without changing caller or sentinel
* expect: REFUSED
local ++test_count
local root ""
capture noisily {
    qa_fx_a7_files, clear perturb(path_noext)
    local root `"`r(root)'"'
    local target `"`r(path_active)'"'
    tempfile refusal
    capture log close _all
    log using "`refusal'", text replace name(protocol_refusal)
    qa_state_snapshot, tag(noext)
    capture noisily msm_protocol, population("Overwrite bait") treatment("A") confounders("L") outcome("Y") causal_contrast("RD") weight_spec("IPW") analysis("MSM") format(csv) export(`"`target'"')
    local rc=_rc
    assert `rc'==602
    qa_state_compare, tag(noext)
    log close protocol_refusal
    python: assert 'already exists' in __import__('pathlib').Path(__import__('sfi').Macro.getLocal('refusal')).read_text()
    erase "`refusal'"
    python: __import__("_qa_msm_protocol").check4()
}
local rc=_rc
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`root'"')
    if `rc'==0 local rc=_rc
}
if !`rc' {
    local ++pass_count
    display as result "PASS: U path_noext refuses existing CSV target unchanged"
}
else {
    local ++fail_count
    display as error "FAIL: U path_noext (rc=`rc')"
}
**# U: missing parent refuses without publishing any protocol export
* expect: REFUSED
local ++test_count
local root ""
capture noisily {
    qa_fx_a7_files, clear
    local root `"`r(root)'"'
    local target `"`r(path_missing)'"'
    tempfile refusal
    capture log close _all
    log using "`refusal'", text replace name(protocol_refusal)
    qa_state_snapshot, tag(protocolmissing)
    capture noisily msm_protocol, population("No partial output") treatment("A") confounders("L") outcome("Y") causal_contrast("RD") weight_spec("IPW") analysis("MSM") format(csv) export(`"`macval(target)'"') replace
    local rc=_rc
    qa_state_compare, tag(protocolmissing)
    assert `rc'==603
    log close protocol_refusal
    python: assert 'could not be opened' in __import__('pathlib').Path(__import__('sfi').Macro.getLocal('refusal')).read_text()
    python: assert not __import__('pathlib').Path(__import__('sfi').Macro.getLocal('target')).exists()
    erase "`refusal'"
}
local rc=_rc
capture log close _all
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`root'"')
    if `rc'==0 local rc=_rc
}
if !`rc' {
    local ++pass_count
    display as result "PASS: U missing parent refuses unchanged/no export"
}
else {
    local ++fail_count
    display as error "FAIL: U missing parent (rc=`rc')"
}
display "RESULT: test_fixture_protocol tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
do "`qa_dir'/_record_qa_result.do" "test_fixture_protocol" `test_count' `pass_count' `fail_count'
capture log close _all
if `fail_count'>0 exit 1
