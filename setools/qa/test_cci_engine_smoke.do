*! test_cci_engine_smoke.do  1.0.0  2026/07/13
*! Deterministic smoke test for the current Mata classification engine

version 16.0
clear all
set more off
capture log close _all

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

clear
input long id str20 icd int year
1 "I21 I50" 2000
2 "E108" 2000
3 "E112" 2000
4 "C50 C78" 2000
5 "F024" 2000
6 "191" 1968
7 "175" 1986
end
gen long visit_date = mdy(1, 1, year)
format visit_date %td

cci_se, id(id) icd(icd) date(visit_date) components
local returned_patients = r(N_patients)
local returned_any = r(N_any)

capture {
    assert _N == 7 & `returned_patients' == 7 & `returned_any' == 5
    assert charlson == 2 & cci_mi == 1 & cci_chf == 1 if id == 1
    assert charlson == 1 & cci_diab == 1 if id == 2
    assert charlson == 2 & cci_diabcomp == 1 & cci_diab == 0 if id == 3
    assert charlson == 6 & cci_mets == 1 & cci_cancer == 0 if id == 4
    assert charlson == 7 & cci_dem == 1 & cci_aids == 1 if id == 5
    assert charlson == 0 & cci_cancer == 0 if inlist(id, 6, 7)
}
local ok = (_rc == 0)
display "RESULT: test_cci_engine_smoke tests=1 pass=`ok' fail=`=1-`ok''"
if !`ok' exit 9

do "`qa_dir'/_setools_qa_common.do" teardown
