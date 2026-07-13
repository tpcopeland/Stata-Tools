*! crossval_cci_se_python.do  1.0.0  2026/07/13
*! Required Python-lane parity against the pinned authoritative CCI fixture

version 16.0
clear all
set more off
set varabbrev off
capture log close _all

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local fixture "`qa_dir'/data/cci_authoritative_prefixes.csv"
local comparator "`qa_dir'/tools/compare_cci_fixture.py"

do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

scalar cv_tests = 0
scalar cv_pass = 0
scalar cv_fail = 0
capture program drop cv_check
program define cv_check
    args label ok
    scalar cv_tests = cv_tests + 1
    if `ok' {
        scalar cv_pass = cv_pass + 1
        display as result "  PASS: `label'"
    }
    else {
        scalar cv_fail = cv_fail + 1
        display as error "  FAIL: `label'"
    }
end

capture confirm file "`fixture'"
cv_check "authoritative fixture exists" `=(_rc == 0)'
capture confirm file "`comparator'"
cv_check "independent Python comparator exists" `=(_rc == 0)'

tempfile actual report bad_actual empty_actual bad_report empty_report ///
    compare_status perturb_status empty_status
import delimited using "`fixture'", clear varnames(1) stringcols(_all)
destring case_id era year expected_*, replace
quietly count
local expected_n = r(N)
cv_check "fixture has nonzero unique cases" `=(`expected_n' > 0)'
capture isid case_id
cv_check "fixture case IDs are unique" `=(_rc == 0)'

gen long diagnosis_date = mdy(1, 1, year)
format diagnosis_date %td
cci_se, id(case_id) icd(code) date(diagnosis_date) generate(actual_score) ///
    components prefix(actual_)
local actual_n = r(N_patients)
cv_check "cci_se processed every fixture case" `=(`actual_n' == `expected_n')'

keep case_id actual_score actual_mi actual_chf actual_pvd actual_cevd ///
    actual_copd actual_pulm actual_rheum actual_dem actual_plegia ///
    actual_diab actual_diabcomp actual_renal actual_livmild ///
    actual_livsev actual_pud actual_cancer actual_mets actual_aids
capture isid case_id
cv_check "actual result schema has one row per case" `=(_rc == 0)'
export delimited using "`actual'", replace

shell /bin/sh -c 'python3 "`comparator'" --expected "`fixture'" ///
    --actual "`actual'" --report "`report'"; echo $? > "`compare_status'"'
tempname status_handle
file open `status_handle' using "`compare_status'", read text
file read `status_handle' compare_status_line
file close `status_handle'
local compare_rc = real(strtrim("`compare_status_line'"))
cv_check "Python comparison process exits zero" `=(`compare_rc' == 0)'
capture confirm file "`report'"
local report_exists = (_rc == 0)
cv_check "fresh Python result report was created" `report_exists'

local report_ok = 0
if `report_exists' {
    tempname report_handle
    file open `report_handle' using "`report'", read text
    file read `report_handle' report_line
    file close `report_handle'
    local report_ok = strpos("`report_line'", ///
        "RESULT: cci_python_crossval matched=`expected_n' mismatches=0") > 0
}
cv_check "Python report records nonempty exact parity" `report_ok'

* Negative controls prove stale, empty, and perturbed output cannot pass.
preserve
replace actual_score = actual_score + 1 in 1
export delimited using "`bad_actual'", replace
restore
shell /bin/sh -c 'python3 "`comparator'" --expected "`fixture'" ///
    --actual "`bad_actual'" --report "`bad_report'" 2>/dev/null; ///
    echo $? > "`perturb_status'"'
file open `status_handle' using "`perturb_status'", read text
file read `status_handle' perturb_status_line
file close `status_handle'
local perturb_rc = real(strtrim("`perturb_status_line'"))
capture confirm file "`bad_report'"
local perturb_report_absent = (_rc != 0)
cv_check "perturbed score is rejected with no success report" ///
    `=(`perturb_rc' != 0 & `perturb_report_absent')'

preserve
keep if 0
export delimited using "`empty_actual'", replace
restore
shell /bin/sh -c 'python3 "`comparator'" --expected "`fixture'" ///
    --actual "`empty_actual'" --report "`empty_report'" 2>/dev/null; ///
    echo $? > "`empty_status'"'
file open `status_handle' using "`empty_status'", read text
file read `status_handle' empty_status_line
file close `status_handle'
local empty_rc = real(strtrim("`empty_status_line'"))
capture confirm file "`empty_report'"
local empty_report_absent = (_rc != 0)
cv_check "empty actual output is rejected with no success report" ///
    `=(`empty_rc' != 0 & `empty_report_absent')'

display as result "Results: " cv_pass "/" cv_tests " passed, " ///
    cv_fail " failed"
display "RESULT: crossval_cci_se_python tests=" cv_tests ///
    " pass=" cv_pass " fail=" cv_fail
if cv_fail > 0 exit 9

do "`qa_dir'/_setools_qa_common.do" teardown
