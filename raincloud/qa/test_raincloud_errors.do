* test_raincloud_errors.do
* Error-path contracts for raincloud
* Author: Timothy P Copeland, Karolinska Institutet

clear all
version 16.0
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_raincloud_qa_common.do"
_raincloud_qa_bootstrap "`pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0

* T1: numeric bounds are early contracts and must restore data/session state.
local ++test_count
capture noisily {
    sysuse auto, clear
    sort price
    local first_price = price[1]
    set varabbrev on
    capture noisily raincloud price, opacity(101) name(rc_errors_t1, replace)
    local call_rc = _rc
    assert `call_rc' == 198
    assert "`c(varabbrev)'" == "on"
    assert _N == 74
    assert price[1] == `first_price'
    raincloud price, opacity(100) name(rc_errors_t1_ok, replace)
    assert r(N) == 74
    graph drop rc_errors_t1_ok
}
if _rc == 0 local ++pass_count
else local ++fail_count

* T2: suppressing every visual element is rejected rather than silently blank.
local ++test_count
capture noisily {
    sysuse auto, clear
    local orig_N = _N
    capture noisily raincloud price, nocloud norain nobox name(rc_errors_t2, replace)
    local call_rc = _rc
    assert `call_rc' == 198
    assert _N == `orig_N'
    raincloud price, nocloud norain name(rc_errors_t2_ok, replace)
    assert r(N) == `orig_N'
    graph drop rc_errors_t2_ok
}
if _rc == 0 local ++pass_count
else local ++fail_count

* T3: a marked empty sample must error and leave the caller's observations intact.
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    local orig_N = _N
    capture noisily raincloud price if foreign == 9, name(rc_errors_t3, replace)
    local call_rc = _rc
    assert `call_rc' == 2000
    assert _N == `orig_N'
    assert "`e(cmd)'" == "regress"
    raincloud price if foreign == 0, name(rc_errors_t3_ok, replace)
    assert r(N) == 52
    graph drop rc_errors_t3_ok
}
if _rc == 0 local ++pass_count
else local ++fail_count

* T4: a late graph-saving collision preserves the old artifact and data.
local ++test_count
capture noisily {
    sysuse auto, clear
    tempfile graph_file
    local graph_path "`graph_file'.gph"
    twoway scatter price mpg, saving("`graph_path'", replace) name(rc_errors_old, replace)
    local orig_N = _N
    capture noisily raincloud price, saving("`graph_path'") name(rc_errors_t4, replace)
    local call_rc = _rc
    assert `call_rc' == 602
    assert _N == `orig_N'
    confirm file "`graph_path'"
    raincloud price, saving("`graph_path'", replace) name(rc_errors_t4_ok, replace)
    assert r(N) == `orig_N'
    graph drop rc_errors_old
    graph drop rc_errors_t4_ok
    capture graph drop rc_errors_t4
    erase "`graph_path'"
}
if _rc == 0 local ++pass_count
else local ++fail_count

if `fail_count' > 0 {
    display as error "RESULT: test_raincloud_errors tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display "RESULT: test_raincloud_errors tests=`test_count' pass=`pass_count' fail=`fail_count'"
