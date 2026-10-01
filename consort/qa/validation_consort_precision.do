*! validation_consort_precision.do -- precise numerical payload, independent input arithmetic
*! Author: Timothy P Copeland, Karolinska Institutet
* Phase2 S1 probe; no session-hygiene or cosmetic contract claim.
version 16.0
clear all
set more off
capture log close _all
log using "validation_consort_precision.log", text replace
local pkg_dir=substr("`c(pwd)'",1,strlen("`c(pwd)'")-3)
adopath ++ "`pkg_dir'"
local tests 0
local pass 0
local fail 0
do _qa_fx_a7.do

**# resolved numerical counts and percent text share independent arithmetic
local ++tests
capture noisily {
    qa_fx_a7_labelled, clear seed(37)
    expand 2 if id==40
    tempfile track image resolved workbook
    consort init, initial("Initial") file("`track'")
    consort exclude if id==1, label("Drop one") remaining("After one")
    assert r(n_excluded)==1 & r(n_remaining)==40
    consort exclude if id==2 | id==3, label("Drop two") remaining("After three")
    assert r(n_excluded)==2 & r(n_remaining)==38
    consort save, output("`image'.svg") csv("`resolved'") xlsx("`workbook'.xlsx") final("Final") dpi(72)
    assert r(N_initial)==41 & r(N_final)==38 & r(N_excluded)==3
    python: import csv; from sfi import Macro; from openpyxl import load_workbook; _rows=list(csv.DictReader(open(Macro.getLocal('resolved'),encoding='utf-8'))); assert len(_rows)==3; assert [int(q['n_remaining']) for q in _rows]==[41,40,38]; assert [int(q['n_excluded']) if q['n_excluded'] not in ('','.') else None for q in _rows]==[None,1,2]; assert [q['pct_of_initial'].strip() for q in _rows]==[format(100*n/41,'.2f') for n in [41,40,38]]
    python: _wb=load_workbook(Macro.getLocal('workbook')+'.xlsx',data_only=True); _ws=_wb.active; assert _ws.max_row==4; assert [_ws.cell(i,3).value for i in range(2,5)]==[41,40,38]; assert [_ws.cell(i,5).value for i in range(2,5)]==[None,1,2]; assert [str(_ws.cell(i,6).value).strip() for i in range(2,5)]==[format(100*n/41,'.2f') for n in [41,40,38]]; _wb.close()
    consort clear, quiet
    erase "`track'"
    erase "`image'.svg"
    erase "`resolved'"
    erase "`workbook'.xlsx"

}
if _rc {
    local ++fail
    display as error "FAIL: resolved numerical counts and percent text share independent arithmetic; rc=" _rc
}
else {
    local ++pass
    display as result "PASS: resolved numerical counts and percent text share independent arithmetic"
}

display "RESULT: validation_consort_precision tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
if `fail' exit 1
