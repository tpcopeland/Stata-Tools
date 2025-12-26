/*******************************************************************************
* test_boundary_edge.do
*
* Purpose: Test boundary edge cases in tvmerge overlap detection
*
* Author: Claude Code
* Date: 2025-12-18
*******************************************************************************/

clear all
set more off
version 16.0

* Try to detect path from current working directory
    capture confirm file "_validation"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "_testing"
        if _rc == 0 {
            global STATA_TOOLS_PATH "`c(pwd)'"
        }
        else {
            global STATA_TOOLS_PATH "/home/`c(username)'/Stata-Tools"
        }
    }
capture net uninstall tvtools
quietly net install tvtools, from("${STATA_TOOLS_PATH}/tvtools")

display _n "{hline 70}"
display "TVMERGE BOUNDARY EDGE CASE TEST"
display "{hline 70}"

* Create test case: two periods that share exactly one day
* Period A: [100, 200], Period B: [200, 300]
* Day 200 is in both periods - this IS an overlap

display _n "Test: Single-day overlap detection in tvmerge"
display "  Dataset 1: [100, 200]"
display "  Dataset 2: [200, 300]"
display "  Day 200 is in BOTH periods - should merge to single-day intersection"

* Create dataset 1
clear
input long id double(start1 stop1) byte exp1
    1  100  200  1
end
save "${STATA_TOOLS_PATH}/_validation/data/_edge_ds1.dta", replace

* Create dataset 2
clear
input long id double(start2 stop2) byte exp2
    1  200  300  2
end
save "${STATA_TOOLS_PATH}/_validation/data/_edge_ds2.dta", replace

* Run tvmerge
use "${STATA_TOOLS_PATH}/_validation/data/_edge_ds1.dta", clear
tvmerge "${STATA_TOOLS_PATH}/_validation/data/_edge_ds1.dta" "${STATA_TOOLS_PATH}/_validation/data/_edge_ds2.dta", id(id) start(start1 start2) stop(stop1 stop2) exposure(exp1 exp2)

display _n "Result:"
list

* Check if single-day intersection exists
* After tvmerge, variables are renamed to start/stop
count if start == 200 & stop == 200
local single_day = r(N)

if `single_day' >= 1 {
    display as result _n "PASS: Single-day intersection [200, 200] preserved"
}
else {
    display as error _n "FAIL: Single-day intersection missing!"
}

* tvmerge does INNER merge by default - only intersection is kept
* So we expect just 1 row: [200, 200] exp1=1, exp2=2
count
local n_rows = r(N)
display "Total rows: `n_rows'"

* Verify both exposures present in the intersection
count if exp1 == 1 & exp2 == 2
local both_exp = r(N)
if `both_exp' >= 1 {
    display as result "PASS: Both exposures present in intersection"
}
else {
    display as error "FAIL: Missing exposures in intersection!"
}

display _n "{hline 70}"
display "Test complete"
display "{hline 70}"
