clear all
version 16.0
capture log close _all
log using "`c(tmpdir)'/test_setools_v154_regressions_`c(processid)'.log", replace nomsg
set varabbrev off

* test_setools_v154_regressions.do
* Regression coverage for person-level date validation, helper isolation, and
* PIRA relapse-file variable-name parsing.
* Run from setools/qa:
*   stata-mp -b do test_setools_v154_regressions.do

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

scalar gs_ntest = 0
scalar gs_npass = 0
scalar gs_nfail = 0
global gs_failures

capture program drop run_test
program define run_test
    args test_name result
    scalar gs_ntest = scalar(gs_ntest) + 1
    if `result' {
        display as result "  PASS: `test_name'"
        scalar gs_npass = scalar(gs_npass) + 1
    }
    else {
        display as error "  FAIL: `test_name'"
        scalar gs_nfail = scalar(gs_nfail) + 1
        global gs_failures "${gs_failures}; `test_name'"
    }
end

**# Internal helpers must disable variable abbreviation independently

clear
set obs 1
generate double baseline_score = 1
set varabbrev on
capture noisily _setools_cdp_thresh bas, generate(helper_out)
local helper_rc = _rc
capture confirm variable helper_out
local helper_output_absent = (_rc != 0)
local ok = (`helper_rc' == 111 & `helper_output_absent' & ///
    "`c(varabbrev)'" == "on")
run_test "H1: helper rejects abbreviated varname and restores varabbrev" `ok'
set varabbrev off

**# cdp validates person-level diagnosis and exit dates before visit filtering

clear
input byte id double(edss visit dx)
1 2 0 0
1 . 1 1
1 3 10 0
1 3 190 0
end
format visit dx %td
set varabbrev on
capture noisily cdp id edss visit, dxdate(dx) ///
    generate(cdp_dx_conflict) keepall quietly
local cdp_dx_rc = _rc
capture confirm variable cdp_dx_conflict
local cdp_dx_output_absent = (_rc != 0)
local ok = (`cdp_dx_rc' == 459 & `cdp_dx_output_absent' & _N == 4 & ///
    "`c(varabbrev)'" == "on")
run_test "C1: cdp rejects conflicting dxdate on missing-EDSS row" `ok'
set varabbrev off

clear
input byte id double(edss visit dx exitdt)
1 2 0 0 300
1 . 1 0 301
1 3 10 0 300
1 3 190 0 300
end
format visit dx exitdt %td
set varabbrev on
capture noisily cdp id edss visit, dxdate(dx) exit(exitdt) ///
    generate(cdp_exit_conflict) keepall quietly
local cdp_exit_rc = _rc
capture confirm variable cdp_exit_conflict
local cdp_exit_output_absent = (_rc != 0)
local ok = (`cdp_exit_rc' == 459 & `cdp_exit_output_absent' & _N == 4 & ///
    "`c(varabbrev)'" == "on")
run_test "C2: cdp rejects conflicting exit date on missing-EDSS row" `ok'
set varabbrev off

**# sustainedss validates person-level exit dates before visit filtering

clear
input byte id double(edss visit exitdt)
1 2 0 300
1 . 1 301
1 4 10 300
1 4 200 300
end
format visit exitdt %td
set varabbrev on
capture noisily sustainedss id edss visit, threshold(1) exit(exitdt) ///
    generate(ss_exit_conflict) keepall quietly
local ss_exit_rc = _rc
capture confirm variable ss_exit_conflict
local ss_exit_output_absent = (_rc != 0)
local ok = (`ss_exit_rc' == 459 & `ss_exit_output_absent' & _N == 4 & ///
    "`c(varabbrev)'" == "on")
run_test "S1: sustainedss rejects conflicting exit date on missing-EDSS row" `ok'
set varabbrev off

**# PIRA relapse-file variable options reject illegal Stata names at syntax

clear
input byte rid double relapse_date
1 1000
end
format relapse_date %td
tempfile relapses
save `relapses'

clear
input byte id double(edss visit dx)
1 2 0 0
1 3 10 0
1 3 190 0
end
format visit dx %td
set varabbrev on
capture noisily pira id edss visit, dxdate(dx) relapses("`relapses'") ///
    relapseidvar(1bad) relapsedatevar(relapse_date) ///
    generate(pira_bad_id) quietly
local pira_id_rc = _rc
capture confirm variable pira_bad_id
local pira_id_output_absent = (_rc != 0)
local ok = (`pira_id_rc' == 198 & `pira_id_output_absent' & _N == 3 & ///
    "`c(varabbrev)'" == "on")
run_test "P1: relapseidvar() rejects an illegal name with rc198" `ok'

capture noisily pira id edss visit, dxdate(dx) relapses("`relapses'") ///
    relapseidvar(rid) relapsedatevar(1bad) ///
    generate(pira_bad_date) quietly
local pira_date_rc = _rc
capture confirm variable pira_bad_date
local pira_date_output_absent = (_rc != 0)
local ok = (`pira_date_rc' == 198 & `pira_date_output_absent' & _N == 3 & ///
    "`c(varabbrev)'" == "on")
run_test "P2: relapsedatevar() rejects an illegal name with rc198" `ok'

capture noisily pira id edss visit, dxdate(dx) relapses("`relapses'") ///
    relapseidvar(rid) relapsedatevar(relapse_date) ///
    generate(_in_relapse_window) rawgenerate(_any_relapse_window) quietly
local pira_namespace_rc = _rc
capture confirm variable _in_relapse_window
local pira_has_generated = (_rc == 0)
capture confirm variable _any_relapse_window
local pira_has_raw = (_rc == 0)
if `pira_namespace_rc' == 0 {
    quietly count if !missing(_in_relapse_window)
    local pira_event_count = r(N)
}
else local pira_event_count = 0
local ok = (`pira_namespace_rc' == 0 & `pira_has_generated' & ///
    `pira_has_raw' & `pira_event_count' > 0 & "`c(varabbrev)'" == "on")
run_test "P3: relapse-window scratch names do not consume output namespace" `ok'

clear
input byte id double(edss visit dx)
1 2 0 0
1 . 1 1
1 3 10 0
1 3 190 0
end
format visit dx %td
capture noisily pira id edss visit, dxdate(dx) relapses("`relapses'") ///
    relapseidvar(rid) relapsedatevar(relapse_date) ///
    generate(pira_dx_conflict) quietly
local pira_dx_rc = _rc
capture confirm variable pira_dx_conflict
local pira_dx_output_absent = (_rc != 0)
local ok = (`pira_dx_rc' == 459 & `pira_dx_output_absent' & _N == 4 & ///
    "`c(varabbrev)'" == "on")
run_test "P4: pira rejects conflicting dxdate on missing-EDSS row" `ok'

clear
input byte id double(edss visit dx exitdt)
1 2 0 0 300
1 . 1 0 301
1 3 10 0 300
1 3 190 0 300
end
format visit dx exitdt %td
capture noisily pira id edss visit, dxdate(dx) exit(exitdt) ///
    relapses("`relapses'") relapseidvar(rid) ///
    relapsedatevar(relapse_date) generate(pira_exit_conflict) quietly
local pira_exit_rc = _rc
capture confirm variable pira_exit_conflict
local pira_exit_output_absent = (_rc != 0)
local ok = (`pira_exit_rc' == 459 & `pira_exit_output_absent' & _N == 4 & ///
    "`c(varabbrev)'" == "on")
run_test "P5: pira rejects conflicting exit date on missing-EDSS row" `ok'
set varabbrev off

local ntest = scalar(gs_ntest)
local npass = scalar(gs_npass)
local nfail = scalar(gs_nfail)
do "`qa_dir'/_setools_qa_common.do" teardown

display "RESULT: test_setools_v154_regressions tests=`ntest' pass=`npass' fail=`nfail'"
capture log close
if `nfail' > 0 {
    display as error "FAILED TESTS:${gs_failures}"
    exit 9
}
