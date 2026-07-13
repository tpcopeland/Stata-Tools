*! test_cci_dates_parity.do  1.0.0  2026/07/13
*! Exact dates/no-dates parity on a deterministic local fixture

version 16.0
clear all
set more off
capture log close _all

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

scalar dp_tests = 0
scalar dp_pass = 0
scalar dp_fail = 0
capture program drop dp_check
program define dp_check
    args label ok
    scalar dp_tests = dp_tests + 1
    if `ok' {
        scalar dp_pass = dp_pass + 1
        display as result "  PASS: `label'"
    }
    else {
        scalar dp_fail = dp_fail + 1
        display as error "  FAIL: `label'"
    }
end

tempfile source nodates
clear
input long id str12 icd long visit_date
1 "I21" 10
1 "I21" 20
1 "E112" 30
2 "C50" 40
2 "C78" 50
3 "F024" 60
4 "ZZZ" 70
end
replace visit_date = visit_date + td(01jan2000)
format visit_date %td
save `source', replace

cci_se, id(id) icd(icd) date(visit_date) components ///
    prefix(n_) generate(score_n)
quietly count
local n_nodates = r(N)
save `nodates', replace

use `source', clear
cci_se, id(id) icd(icd) date(visit_date) dates ///
    prefix(d_) generate(score_d)
quietly count
local n_dates = r(N)
merge 1:1 id using `nodates', assert(match) nogen

local components "mi chf pvd cevd copd pulm rheum dem plegia diab diabcomp renal livmild livsev pud cancer mets aids"
local exact = (`n_dates' == 4 & `n_nodates' == 4)
quietly count
if r(N) == 0 local exact = 0
quietly count if score_d != score_n
if r(N) != 0 local exact = 0
foreach component of local components {
    quietly count if d_`component' != n_`component'
    if r(N) != 0 local exact = 0
}
dp_check "dates and no-dates scores/components match on four IDs" `exact'

capture {
    assert d_mi_date == td(11jan2000) if id == 1
    assert d_diabcomp_date == td(31jan2000) if id == 1
    assert missing(d_cancer_date) & d_mets_date == td(20feb2000) if id == 2
    assert d_dem_date == td(01mar2000) & d_aids_date == td(01mar2000) if id == 3
    foreach component of local components {
        assert missing(d_`component'_date) if d_`component' == 0
        assert !missing(d_`component'_date) if d_`component' == 1
    }
}
dp_check "component dates are exact, earliest, and hierarchy-consistent" ///
    `=(_rc == 0)'

preserve
replace score_n = score_n + 1 in 1
capture assert score_d == score_n
local perturb_rejected = (_rc != 0)
restore
dp_check "deliberately perturbed no-dates control is rejected" ///
    `perturb_rejected'

display "RESULT: test_cci_dates_parity tests=" dp_tests ///
    " pass=" dp_pass " fail=" dp_fail
if dp_fail > 0 exit 9

do "`qa_dir'/_setools_qa_common.do" teardown
