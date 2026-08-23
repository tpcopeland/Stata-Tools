*! test_tc_schemes_hostile.do - session-state and catalogue boundary stress
version 16.0
clear all
set more off
set varabbrev off
capture log close _all

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall tc_schemes
quietly net install tc_schemes, from("`pkg_dir'") replace
local tests = 0
local pass = 0
local fail = 0

**# Repeated narrow/wide calls replace returns rather than leaking the prior selection
local ++tests
capture noisily {
    tc_schemes, source(tc)
    assert r(n_schemes) == 3
    assert "`r(sources)'" == "tc"
    tc_schemes, source(schemepack)
    assert r(n_schemes) == 35
    assert "`r(sources)'" == "schemepack"
    assert strpos(" `r(schemes)' ", " ki ") == 0
    tc_schemes
    assert r(n_schemes) == 45
    assert "`r(sources)'" == "blindschemes schemepack cleanplots modern tc"
}
if _rc == 0 local ++pass
else local ++fail

**# Empty data and foreign estimates survive a read-only catalogue call
local ++tests
capture noisily {
    clear
    set obs 0
    sysuse auto, clear
    regress price mpg
    local e_cmd_before "`e(cmd)'"
    local e_n_before = e(N)
    preserve
    keep if 0
    set varabbrev on
    tc_schemes, source(modern) detail
    assert _N == 0
    assert "`e(cmd)'" == "`e_cmd_before'"
    assert e(N) == `e_n_before'
    assert "`c(varabbrev)'" == "on"
    restore
}
if _rc == 0 local ++pass
else local ++fail

display "RESULT: test_tc_schemes_hostile tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' exit 9
