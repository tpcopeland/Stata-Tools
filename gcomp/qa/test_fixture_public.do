* test_fixture_public.do -- canonical gcomptab model and file payloads
* Author: Timothy P Copeland, Karolinska Institutet
* guard: canonical adoption; estimates are formatter inputs, not fitted causal claims.
version 16.0
clear all
set more off
set varabbrev off
set processors 1
capture log close _all
local qa_dir "`c(pwd)'"
do "`qa_dir'/_qa_bootstrap.do"
do "`qa_dir'/_qa_fx_a6.do"
do "`qa_dir'/_qa_fx_a7.do"
do "`qa_dir'/_qa_fx_a1.do"
do "`qa_dir'/_qa_state.do"
local test_count 0
local pass_count 0
local fail_count 0
python:
def checkmodels():
    from sfi import Macro,Matrix
    from pathlib import Path
    from openpyxl import load_workbook
    import csv
    expected=Matrix.get('fx_model_table')
    rows=list(csv.reader(open(Macro.getLocal('csv')+'.csv',encoding='utf-8')))
    md=Path(Macro.getLocal('md')+'.md').read_text(encoding='utf-8')
    w=load_workbook(Macro.getLocal('book')+'.xlsx',data_only=True)
    assert 'Fixture' in w.sheetnames
    values=[tuple(c.value for c in row) for row in w['Fixture']]
    # Raw/noeform model point estimates are carried through table, CSV, Markdown,
    # and Excel at six decimal display precision. No inference is invented.
    for row in expected:
        b=row[0]
        display=f'{b:.6f}'
        assert any(display in str(x) for r in rows for x in r)
        assert display in md
        assert any((isinstance(x,(int,float)) and abs(x-b)<1e-12) or display in str(x) for r in values for x in r)
    if Macro.getLocal('op')=='long_row_names':
        assert 'abcdefghijklmnopqrstuvwxyzabcdeA' in md and 'abcdefghijklmnopqrstuvwxyzabcdeB' in md
    w.close()
def checksheet():
    from sfi import Macro,Matrix
    import re
    from openpyxl import load_workbook
    w=load_workbook(Macro.getLocal('book'),data_only=True)
    assert w['user_notes']['A1'].value=='USER_KEEP'
    assert w['package_detail']['A1'].value=='STALE_DETAIL'
    values=[c.value for row in w['package_summary'] for c in row]
    assert 'STALE_SUMMARY' not in values
    B=Matrix.get('fx_dose_b')[0]
    for i,b in enumerate(B):
        cell=w['package_summary'].cell(i+3,2).value
        risk=float(re.match(r'([-+0-9.]+)',cell).group(1))
        assert abs(risk-b)<=5.1e-7
    assert abs(w['package_summary']['C3'].value-(B[0]-B[1]))<=5.1e-7
    w.close()
import types,sys
m=types.ModuleType('_qa_gc_public');m.checkmodels=checkmodels;m.checksheet=checksheet;sys.modules['_qa_gc_public']=m
end
capture program drop _fx_gc_models
program define _fx_gc_models
    args op
    local opt ""
    if "`op'"!="" local opt "perturb(`op')"
    qa_fx_a6_estmat, clear post `opt'
    matrix fx_truth_b=r(b)
    matrix fx_truth_V=r(V)
    estimates store fixture_component
    tempfile csv md book
    quietly gcomptab, models usemodels(fixture_component) noeform keepintercept ///
        xlsx("`book'.xlsx") sheet("Fixture") csv("`csv'.csv") markdown("`md'.md") display decimal(6)
    matrix fx_model_table=r(table)
    assert r(N_models)==1 & r(N_rows)==cond(inlist("`op'","omitted","base_rows"),2,3)
    assert colsof(fx_model_table)==1
    assert mreldif(e(b),fx_truth_b)==0 & mreldif(e(V),fx_truth_V)==0
    local terms "`r(term_names)'"
    local n : word count `terms'
    forvalues i=1/`n' {
        local term : word `i' of `terms'
        local j=colnumb(fx_truth_b,"`term'")
        assert !missing(`j',fx_model_table[`i',1],fx_truth_b[1,`j'])
        assert abs(fx_model_table[`i',1]-fx_truth_b[1,`j'])<1e-12
    }
    python: __import__('_qa_gc_public').checkmodels()
    erase "`csv'.csv"
    erase "`md'.md"
    erase "`book'.xlsx"
    estimates drop fixture_component
end
**# F: A6 model matrices format exact coefficient payloads across all sinks
local ++test_count
capture noisily _fx_gc_models
if !_rc {
    local ++pass_count
    display as result "PASS: F A6 models exact multi-sink payload"
}
else {
    local ++fail_count
    display as error "FAIL: F A6 models (rc=`=_rc')"
}
foreach op in omitted base_rows positional_mismatch factor_names long_row_names boundary_values {
    **# U: A6 named coefficient identity and omission operator
    * expect: EXACT
    local ++test_count
    capture noisily _fx_gc_models `op'
    if !_rc {
        local ++pass_count
        display as result "PASS: U A6 `op' exact identity/value payload"
    }
    else {
        local ++fail_count
        display as error "FAIL: U A6 `op' (rc=`=_rc')"
    }
}
**# F/U: stale_sheet dose-response export retains user_notes and replaces owned sheet
* expect: EXACT
local ++test_count
local root ""
capture noisily {
    qa_fx_a7_files, clear perturb(stale_sheet)
    local root `"`r(root)'"'
    local book `"`r(path_xlsx)'"'
    qa_fx_a1_sat, clear
    expand 10
    replace id=_n
    expand 2
    bysort id: gen byte time=_n
    replace y=. if time==1
    quietly gcomp y a s x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(s x2) ///
        intvars(a) interventions(a=1,a=0) commands(a: logit,y: logit) ///
        equations(a: i.s##i.x2,y: i.a##i.s##i.x2) sim(1200) samples(2) seed(9141) minsim savemodels
    matrix fx_dose_b=e(b)
    quietly gcomptab, doseresponse reference(2) xlsx(`"`book'"') sheet("package_summary") decimal(6)
    assert !missing(r(table)[1,1]) & abs(r(table)[1,1]-11/20)<1e-8
    python: __import__('_qa_gc_public').checksheet()
}
local rc=_rc
if `"`root'"'!="" {
    capture noisily qa_fx_a7_cleanup, root(`"`root'"')
    if `rc'==0 local rc=_rc
}
if !`rc' {
    local ++pass_count
    display as result "PASS: U stale_sheet exact risks/user preservation"
}
else {
    local ++fail_count
    display as error "FAIL: U stale_sheet (rc=`rc')"
}
display "RESULT: test_fixture_public tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count'>0 exit 1
