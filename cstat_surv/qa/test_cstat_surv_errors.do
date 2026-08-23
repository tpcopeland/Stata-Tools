clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0
local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
capture ado uninstall cstat_surv
adopath ++ "`pkg_dir'"

* No prior estimation is an early, exact error.
local ++test_count
capture noisily cstat_surv
local rc = _rc
if `rc' == 301 local ++pass_count
else local ++fail_count

* A non-Cox estimate must not be overwritten by a rejected call.
local ++test_count
capture noisily {
    sysuse auto, clear
    regress price mpg
    matrix b_before = e(b)
    capture noisily cstat_surv
    local call_rc = _rc
    assert `call_rc' == 301
    assert "`e(cmd)'" == "regress"
    assert mreldif(b_before, e(b)) < 1e-12
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Invalid syntax must error, while the legal inverse works after stcox.
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    stcox age drug
    matrix b_before = e(b)
    capture noisily cstat_surv, level(101)
    local call_rc = _rc
    assert `call_rc' == 198
    assert "`e(cmd)'" == "cox"
    assert mreldif(b_before, e(b)) < 1e-12
    cstat_surv, level(90)
    assert "`e(cmd)'" == "cstat_surv"
    assert e(level) == 90
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_cstat_surv_errors tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
