* test_fixture_putexcel_context.do -- caller workbook context and unsaved cells
* Author: Timothy P Copeland, Karolinska Institutet
* guard: closed caller writes and open-handle refusal require actual cell evidence.
version 16.0
clear all
set more off
set varabbrev off
set processors 1
capture log close _all
local qa_dir "`c(pwd)'"
do "`qa_dir'/_qa_bootstrap.do"
do "`qa_dir'/_qa_fx_a6.do"
do "`qa_dir'/_qa_state.do"
* Explicitly load bundled helpers for their direct QA boundary.
run "`qa_dir'/../gcomptab.ado"
local test_count 0
local pass_count 0
local fail_count 0
python:
def checkcontext():
    from sfi import Macro
    from openpyxl import load_workbook
    from pathlib import Path
    w=load_workbook(Macro.getLocal('caller')+'.xlsx',data_only=True)
    sheet=Macro.getLocal('sheet')
    assert w[sheet]['A1'].value==Macro.getLocal('first')
    assert w[sheet]['A2'].value=='AFTER'
    w.close()
    if Macro.getLocal('refused')=='1':
        assert not Path(Macro.getLocal('target')+'.xlsx').exists()
        assert 'putexcel workbook is open' in Path(Macro.getLocal('refusal')).read_text()
    else:
        w=load_workbook(Macro.getLocal('target')+'.xlsx',data_only=True)
        assert 'Fixture' in w.sheetnames
        assert any((isinstance(c.value,(int,float)) and abs(c.value-.5)<1e-12) or '0.500000' in str(c.value) for row in w['Fixture'] for c in row)
        w.close()
import types,sys
m=types.ModuleType('_qa_gc_context');m.checkcontext=checkcontext;sys.modules['_qa_gc_context']=m
end
**# F: configured closed workbook remains the destination of the next caller write
local ++test_count
capture noisily {
    qa_fx_a6_estmat, clear post
    estimates store fixture_context
    tempfile caller target
    local sheet "Caller"
    local first "BEFORE"
    local refused 0
    putexcel set "`caller'.xlsx", replace sheet("`sheet'")
    putexcel A1=("`first'")
    qa_state_snapshot, tag(closedcaller)
    quietly gcomptab, models usemodels(fixture_context) noeform keepintercept xlsx("`target'.xlsx") sheet("Fixture") decimal(6)
    qa_state_compare, tag(closedcaller)
    putexcel A2=("AFTER")
    putexcel close
    python: __import__('_qa_gc_context').checkcontext()
    putexcel clear
    erase "`caller'.xlsx"
    erase "`target'.xlsx"
    estimates drop fixture_context
}
if !_rc {
    local ++pass_count
    display as result "PASS: F closed workbook next-write destination/cells"
}
else {
    local ++fail_count
    display as error "FAIL: F closed context (rc=`=_rc')"
}
**# U: open caller workbook refuses without closing or losing pending unsaved cells
* expect: REFUSED
local ++test_count
capture noisily {
    qa_fx_a6_estmat, clear post perturb(long_row_names)
    estimates store fixture_context
    tempfile caller target refusal
    local sheet "Open"
    local first "PENDING"
    local refused 1
    putexcel set "`caller'.xlsx", replace sheet("`sheet'") open
    putexcel A1=("`first'")
    capture log close _all
    log using "`refusal'", text replace name(context_refusal)
    qa_state_snapshot, tag(opencaller)
    capture noisily _gcomptab_models, usemodels(fixture_context) noeform keepintercept xlsx("`target'.xlsx") sheet("Fixture") decimal(6)
    local rc=_rc
    qa_state_compare, tag(opencaller)
    assert `rc'==198
    log close context_refusal
    * Native writes prove the caller's real Mata handle remains live.
    putexcel A2=("AFTER")
    putexcel save
    putexcel close
    python: __import__('_qa_gc_context').checkcontext()
    putexcel clear
    erase "`caller'.xlsx"
    erase "`refusal'"
    estimates drop fixture_context
}
local rc=_rc
capture log close _all
if !`rc' {
    local ++pass_count
    display as result "PASS: U open refusal preserves pending cells/live handle"
}
else {
    local ++fail_count
    display as error "FAIL: U open context (rc=`rc')"
}
**# F: genuinely absent/empty native context remains absent after workbook export
local ++test_count
capture noisily {
    putexcel clear
    qa_fx_a6_estmat, clear post
    estimates store fixture_context
    tempfile target
    mata: st_global("S_PUTEXCEL_FILE_NAME", "")
    local globals_before : all globals
    assert !strpos(" `globals_before' ", " S_PUTEXCEL_FILE_NAME ")
    qa_state_snapshot, tag(emptycontext)
    quietly _gcomptab_models, usemodels(fixture_context) noeform keepintercept xlsx("`target'.xlsx") sheet("Fixture") decimal(6)
    qa_state_compare, tag(emptycontext)
    assert !missing(r(table)[1,1]) & r(table)[1,1]==.5
    python: __import__('openpyxl').load_workbook(__import__('sfi').Macro.getLocal('target')+'.xlsx').close()
    erase "`target'.xlsx"
    estimates drop fixture_context
}
if !_rc {
    local ++pass_count
    display as result "PASS: F absent/empty context and native output"
}
else {
    local ++fail_count
    display as error "FAIL: F absent/empty context (rc=`=_rc')"
}
**# U: arbitrary non-open entry bytes are transported opaquely
* expect: INVARIANT
local ++test_count
capture noisily {
    putexcel clear
    qa_fx_a6_estmat, clear post perturb(boundary_values)
    estimates store fixture_context
    tempfile target
    * Construct macro bait through Mata so neither setup nor guard reparses it.
    mata: st_global("S_PUTEXCEL_OPEN_FHANDLE", char(36)+"UNSET_BAIT "+char(96)+"literal"+char(39)+" "+char(34)+"quote"+char(34))
    qa_state_snapshot, tag(contextbytes)
    quietly _gcomptab_models, usemodels(fixture_context) noeform keepintercept xlsx("`target'.xlsx") sheet("Fixture") decimal(6)
    qa_state_compare, tag(contextbytes)
    putexcel clear
    erase "`target'.xlsx"
    estimates drop fixture_context
}
if !_rc {
    local ++pass_count
    display as result "PASS: U closed context macro-bait bytes retained"
}
else {
    local ++fail_count
    display as error "FAIL: U opaque context (rc=`=_rc')"
}
if `fail_count' > 0 {
    display "RESULT: test_fixture_putexcel_context tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    capture log close _all
    exit 1
}
else {
    display "RESULT: test_fixture_putexcel_context tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"
    capture log close _all
}
