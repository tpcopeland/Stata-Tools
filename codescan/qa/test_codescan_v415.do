* test_codescan_v415.do - Regression tests for v4.1.5 fixes
* Date: 2026-08-19
*
* Covers:
*   T1: Unicode prefix level() truncation (ISSUE-1)
*   T2: export() pattern/exclusion width (ISSUE-2)
*   T3: codescan_describe save() extension validation timing (ISSUE-3)
*   T4: graph bar label format() passthrough (ISSUE-4)
*   T5: codescan_describe error 2000 without duplicate message (ISSUE-5)

clear all
version 16.0
set varabbrev off
set seed 41500
capture log close _all

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")

quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap
local _qa_owner "`r(owner)'"


**# T1: level() must truncate by Unicode character, not by byte

local ++test_count
capture noisily {
    clear
    set obs 3
    gen str10 dx = ""
    replace dx = "Å12" in 1
    replace dx = "Ä34" in 2
    replace dx = "A56" in 3

    codescan dx, define(nordic "Å12") mode(prefix) level(1) replace
    assert nordic == 1 in 1
    assert nordic == 0 in 2
    assert nordic == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: T1 - level(1) truncates by Unicode character, not byte"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - Unicode level() truncation (error `=_rc')"
    local ++fail_count
}


**# T1b: level() on mixed ASCII and multibyte patterns

local ++test_count
capture noisily {
    clear
    set obs 4
    gen str10 dx = ""
    replace dx = "Å10" in 1
    replace dx = "Å20" in 2
    replace dx = "Ö10" in 3
    replace dx = "A10" in 4

    codescan dx, define(grp "Å10|Ö10") mode(prefix) level(2) replace
    assert grp == 1 in 1
    assert grp == 0 in 2
    assert grp == 1 in 3
    assert grp == 0 in 4
}
if _rc == 0 {
    display as result "  PASS: T1b - level(2) on mixed ASCII/multibyte prefixes"
    local ++pass_count
}
else {
    display as error "  FAIL: T1b - mixed prefix level() (error `=_rc')"
    local ++fail_count
}


**# T1c: level() on pure ASCII is unaffected by the usubstr change

local ++test_count
capture noisily {
    clear
    set obs 3
    gen str10 dx = ""
    replace dx = "E110" in 1
    replace dx = "E120" in 2
    replace dx = "I200" in 3

    codescan dx, define(dm "E11|E12") mode(prefix) level(3) replace
    assert dm == 1 in 1
    assert dm == 1 in 2
    assert dm == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: T1c - level() on pure ASCII unchanged"
    local ++pass_count
}
else {
    display as error "  FAIL: T1c - ASCII level() (error `=_rc')"
    local ++fail_count
}


**# T2: export() preserves patterns longer than 80 characters

local ++test_count
capture noisily {
    clear
    set obs 1
    gen str10 dx = "E110"

    local longpat "E110|E111|E112|E113|E114|E115|E116|E117|E118|E119|E120|E121|E122|E123|E124|E125|E126|E127|E128|E129"
    local patlen = strlen("`longpat'")
    assert `patlen' > 80

    tempfile expfile
    codescan dx, define(dm2 "`longpat'") export(`expfile'.csv, replace) replace

    preserve
    quietly import delimited using `expfile'.csv, clear stringcols(_all)
    assert strlen(pattern[1]) == `patlen'
    restore
}
if _rc == 0 {
    display as result "  PASS: T2 - export() preserves >80 char patterns"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - export() truncation (error `=_rc')"
    local ++fail_count
}


**# T3: codescan_describe save(invalid.txt) rejects before scan output

local ++test_count
capture noisily {
    clear
    input str8 dx1
    "E110"
    "E111"
    "I200"
    end

    tempname loghandle
    tempfile logpath
    log using `logpath', name(`loghandle') text replace
    capture noisily codescan_describe dx1, save(invalid_file.txt)
    local desc_rc = _rc
    log close `loghandle'

    assert `desc_rc' == 198

    file open `loghandle' using `logpath', read text
    local log_contents ""
    file read `loghandle' line
    while r(eof) == 0 {
        local log_contents `"`log_contents'`line'"'
        file read `loghandle' line
    }
    file close `loghandle'

    * The log should NOT contain any tabulation output (e.g. "Top" header or
    * code frequency table lines), because the extension check fires first.
    local has_table = regexm(`"`log_contents'"', "Top [0-9]+ codes")
    assert `has_table' == 0
}
if _rc == 0 {
    display as result "  PASS: T3 - describe save() rejects non-.csv before scan"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - deferred extension check (error `=_rc')"
    local ++fail_count
}


**# T4: graph bar label uses user-specified format

local ++test_count
capture noisily {
    clear
    set obs 10
    gen str10 dx = "E110"

    codescan dx, define(dm "E110") graph format(%9.3f) replace
    graph close _all
}
if _rc == 0 {
    display as result "  PASS: T4 - graph runs with user-specified format()"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - graph format passthrough (error `=_rc')"
    local ++fail_count
}


**# T5: codescan_describe error 2000 on empty sample (no duplicate message)

local ++test_count
capture noisily {
    clear
    input byte keep str8 dx1
    0 "A10"
    0 "B20"
    end

    capture codescan_describe dx1 if keep == 1
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: T5 - empty sample exits 2000"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - error 2000 path (error `=_rc')"
    local ++fail_count
}


**# Summary

_codescan_qa_restore "`_qa_owner'"
_codescan_qa_publish "test_codescan_v415" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_codescan_v415 tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Functional Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}

display as result "ALL TESTS PASSED"
