* Error and inverse-option contracts for tc_schemes.

version 16.0
clear all
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall tc_schemes
quietly net install tc_schemes, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Mutually exclusive display options fail without changing data or e()
local ++test_count
capture noisily {
    sysuse auto, clear
    gen long order_before = _n
    regress price mpg
    local e_cmd_before "`e(cmd)'"
    local e_n_before = e(N)
    set varabbrev on
    capture noisily tc_schemes, list detail
    local call_rc = _rc
    assert `call_rc' == 198
    assert _N == 74
    assert order_before == _n
    assert "`e(cmd)'" == "`e_cmd_before'"
    assert e(N) == `e_n_before'
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Invalid source rejects exactly and preserves the caller session
local ++test_count
capture noisily {
    sysuse auto, clear
    gen long order_before = _n
    regress price mpg
    local e_cmd_before "`e(cmd)'"
    local e_n_before = e(N)
    set varabbrev on
    capture noisily tc_schemes, source(not_a_source)
    local call_rc = _rc
    assert `call_rc' == 198
    assert _N == 74
    assert order_before == _n
    assert "`e(cmd)'" == "`e_cmd_before'"
    assert e(N) == `e_n_before'
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Parser rejects unsupported options rather than silently ignoring them
local ++test_count
capture noisily {
    sysuse auto, clear
    gen long order_before = _n
    set varabbrev on
    capture noisily tc_schemes, ignoredoption
    local call_rc = _rc
    assert `call_rc' == 198
    assert _N == 74
    assert order_before == _n
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Legal inverse: case-normalized source(tc) remains a valid narrow query
local ++test_count
capture noisily {
    clear
    set obs 2
    gen byte protected = _n
    set varabbrev on
    quietly tc_schemes, source(TC) list
    assert r(n_schemes) == 3
    assert "`r(schemes)'" == "rdbu ki ki_black"
    assert "`r(sources)'" == "tc"
    assert protected[1] == 1
    assert protected[2] == 2
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_tc_schemes_errors tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 exit 1
