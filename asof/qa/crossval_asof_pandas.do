*! crossval_asof_pandas.do - pandas.merge_asof parity for asof
*! Author: Timothy P Copeland, Karolinska Institutet
*! Requires: Stata 16.0+, Python 3, pandas, and NumPy

clear all
set processors 1
set varabbrev off
version 16.0

capture log close _all
log using "crossval_asof_pandas.log", replace text nomsg
global ASOF_QA_STATUS "fail"

do "_asof_qa_common.do"
quietly _asof_qa_bootstrap
local qa_dir "`r(qa_dir)'"

local test_count = 0
local pass_count = 0
local fail_count = 0

tempfile output_stub
local output_dir "`output_stub'_dir"
capture mkdir "`output_dir'"
shell python3 "`qa_dir'/crossval_asof_pandas.py" "`output_dir'"
local python_rc = _rc
if `python_rc' {
    display as error "pandas oracle generation failed with rc=`python_rc'"
    display "RESULT: crossval_asof_pandas tests=1 pass=0 fail=1 skip=0"
    capture log close _all
    exit 1
}
confirm file "`output_dir'/master.dta"
confirm file "`output_dir'/events.dta"
confirm file "`output_dir'/oracle_backward.dta"
confirm file "`output_dir'/oracle_forward.dta"

**# pandas backward equals on-or-before nearest within tolerance
local ++test_count
capture noisily {
    use "`output_dir'/master.dta", clear
    asof event_row visit using "`output_dir'/events.dta", ///
        id(id) date(visit) anchor(anchor) direction(onorbefore) ///
        select(nearest) window(-35 .) generate(stata_row stata_date) nowarn
    assert r(N_master) == 5000
    merge 1:1 id using "`output_dir'/oracle_backward.dta", assert(3) nogen
    assert (missing(stata_row) & missing(expected_row)) | ///
        stata_row == expected_row
    assert (missing(stata_date) & missing(expected_date)) | ///
        stata_date == expected_date
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# pandas forward equals on-or-after nearest within tolerance
local ++test_count
capture noisily {
    use "`output_dir'/master.dta", clear
    asof event_row visit using "`output_dir'/events.dta", ///
        id(id) date(visit) anchor(anchor) direction(onorafter) ///
        select(nearest) window(. 35) generate(stata_row stata_date) nowarn
    assert r(N_master) == 5000
    merge 1:1 id using "`output_dir'/oracle_forward.dta", assert(3) nogen
    assert (missing(stata_row) & missing(expected_row)) | ///
        stata_row == expected_row
    assert (missing(stata_date) & missing(expected_date)) | ///
        stata_date == expected_date
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: crossval_asof_pandas tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
global ASOF_QA_STATUS "pass"
log close _all
