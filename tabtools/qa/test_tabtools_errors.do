*! test_tabtools_errors.do
*! Error-path contracts for crosstab's 2x2 association measures.

clear all
set varabbrev off
version 17.0
capture log close _all
log using "test_tabtools_errors.log", replace text name(tabtools_errors)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local tests = 0
local pass = 0
local fail = 0

* Association measures require exactly 2x2 support and may not mutate caller data.
local ++tests
capture noisily {
    clear
    input byte outcome byte exposure
    0 0
    0 1
    1 0
    1 2
    end
    tempfile before
    save "`before'", replace
    capture noisily crosstab outcome exposure, or
    local rc = _rc
    assert `rc' == 198
    cf _all using "`before'"
}
if _rc == 0 local ++pass
else local ++fail

* A genuine 2x2 table remains accepted and posts its requested statistic.
local ++tests
capture noisily {
    clear
    input byte outcome byte exposure
    0 0
    0 1
    1 0
    1 1
    end
    crosstab outcome exposure, or
    assert r(or) < .
}
if _rc == 0 local ++pass
else local ++fail

* Invalid persistent border defaults fail immediately and preserve the caller's
* previously configured value.
local ++tests
capture noisily {
    tabtools set clear
    tabtools set borderstyle thin
    capture noisily tabtools set borderstyle broken
    local rc = _rc
    assert `rc' == 198
    assert "$TABTOOLS_BORDER" == "thin"
}
if _rc == 0 local ++pass
else local ++fail
capture noisily tabtools set clear

* The documented digits range ends at 6; rejecting 7 must preserve the
* caller's existing default.
local ++tests
capture noisily {
    tabtools set clear
    tabtools set digits 3
    capture noisily tabtools set digits 7
    local rc = _rc
    assert `rc' == 198
    assert "$TABTOOLS_DIGITS" == "3"
}
if _rc == 0 local ++pass
else local ++fail
capture noisily tabtools set clear

* boldp() is an open interval: zero is invalid and must not replace a valid
* caller default.
local ++tests
capture noisily {
    tabtools set clear
    tabtools set boldp .05
    capture noisily tabtools set boldp 0
    local rc = _rc
    assert `rc' == 198
    assert "$TABTOOLS_BOLDP" == ".05"
}
if _rc == 0 local ++pass
else local ++fail
capture noisily tabtools set clear

display "RESULT: test_tabtools_errors tests=`tests' pass=`pass' fail=`fail'"
log close tabtools_errors
if `fail' exit 1
