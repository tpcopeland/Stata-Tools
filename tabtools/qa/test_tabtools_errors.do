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

capture program drop __tt_assert_same_data
program define __tt_assert_same_data
    version 17.0
    syntax using/
    unab memory_vars : _all
    local memory_N = _N
    preserve
    quietly use `"`using'"', clear
    unab using_vars : _all
    local using_N = _N
    restore
    assert `using_N' == `memory_N'
    assert `"`using_vars'"' == `"`memory_vars'"'
    cf _all using `"`using'"'
end

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
    __tt_assert_same_data using "`before'"
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

* A custom validation message must not be followed by Stata's own stock message.
* desctab ended every validation branch with `error <rc>` after `display as
* error`, so the user saw the package message and then Stata's generic one
* ("invalid syntax"). The package convention elsewhere is `exit <rc>`.
local ++tests
capture noisily {
    sysuse auto, clear
    tempfile _errbase
    local _errlog "`_errbase'.log"
    capture log close _dtmsg
    log using "`_errlog'", replace text name(_dtmsg)
    capture noisily desctab price, by(foreign) smallcells(2)
    local _sc_rc = _rc
    log close _dtmsg
    assert `_sc_rc' == 198
    local _custom_seen 0
    local _stock_seen 0
    tempname _fh
    file open `_fh' using "`_errlog'", read text
    file read `_fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "smallcells() must be an integer") local _custom_seen 1
        if strpos(`"`line'"', "invalid syntax") local _stock_seen 1
        file read `_fh' line
    }
    file close `_fh'
    assert `_custom_seen' == 1
    assert `_stock_seen' == 0
}
if _rc == 0 local ++pass
else local ++fail

display "RESULT: test_tabtools_errors tests=`tests' pass=`pass' fail=`fail'"
log close tabtools_errors
if `fail' exit 1
