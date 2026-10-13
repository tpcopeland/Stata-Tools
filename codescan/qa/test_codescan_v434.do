* test_codescan_v434.do - Regression tests for the v4.3.4 zero-match summary note
*
* Covers:
*   T1: several empty conditions print ONE summary note listing every empty
*       name (4.3.3 printed one note per empty condition)
*   T2: exactly one empty condition keeps the singular note
*   T3: no empty condition prints no note

clear all
version 16.0
set varabbrev off
capture log close _all

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap
local _qa_owner "`r(owner)'"

local _tmp "`c(tmpdir)'"
if substr("`_tmp'", -1, 1) != "/" local _tmp "`_tmp'/"
tempfile _stem
local _tag = substr("`_stem'", strrpos("`_stem'", "/") + 1, .) + "_cs434"

capture mata: mata drop _cs434_note()
mata:
// Join the lines of the "(note: ..." block (up to the line ending in ")") with
// single spaces; return the joined text, line count and longest line.
void _cs434_note(string scalar f)
{
    string colvector L
    real scalar i, on, n, mx
    string scalar j
    L = cat(f)
    on = 0; n = 0; mx = 0; j = ""
    for (i = 1; i <= rows(L); i++) {
        if (substr(L[i], 1, 7) == "(note: ") on = 1
        if (on) {
            j = j + (n > 0 ? " " : "") + strtrim(L[i])
            n++
            mx = max((mx, strlen(L[i])))
            if (substr(L[i], strlen(L[i]), 1) == ")") break
        }
    }
    st_local("joined", j); st_local("nlines", strofreal(n)); st_local("maxlen", strofreal(mx))
}
end

capture program drop _cs434_data
program define _cs434_data
    clear
    quietly set obs 4
    generate long pid = _n
    generate str6 dx1 = cond(_n == 1, "E110", cond(_n == 2, "Z00", cond(_n == 3, "E119", "I10")))
end

* Count the "matched 0" note lines in a text log; return the count and the first.
capture program drop _cs434_scan
program define _cs434_scan, rclass
    args con
    tempname fh
    local nn 0
    local first ""
    file open `fh' using "`con'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "(note: ") == 1 & strpos(`"`macval(line)'"', "matched 0") {
            local ++nn
            if `nn' == 1 local first `"`macval(line)'"'
        }
        file read `fh' line
    }
    file close `fh'
    return scalar nn = `nn'
    return local first `"`macval(first)'"'
end

**# T1
local ++test_count
capture noisily {
    _cs434_data
    local con "`_tmp'`_tag'_t1.log"
    log using "`con'", name(cs434) text replace
    codescan dx1, define(dm "E11" a1 "QQ1" b2 "QQ2" c3 "QQ3")
    log close cs434
    _cs434_scan "`con'"
    capture erase "`con'"
    assert r(nn) == 1
    assert `"`r(first)'"' == "(note: 3 conditions matched 0 observations: a1 b2 c3)"
}
if _rc == 0 {
    display as result "  PASS: T1 - one summary note lists all empty conditions"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - summary note (error `=_rc')"
    local ++fail_count
    capture log close cs434
}

**# T2
local ++test_count
capture noisily {
    _cs434_data
    local con "`_tmp'`_tag'_t2.log"
    log using "`con'", name(cs434) text replace
    codescan dx1, define(dm "E11" a1 "QQ1")
    log close cs434
    _cs434_scan "`con'"
    capture erase "`con'"
    assert r(nn) == 1
    assert `"`r(first)'"' == "(note: condition a1 matched 0 observations)"
}
if _rc == 0 {
    display as result "  PASS: T2 - single empty condition keeps singular note"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - singular note (error `=_rc')"
    local ++fail_count
    capture log close cs434
}

**# T3
* guard: expected green at HEAD (behaviour-preservation: no empty condition, no note)
local ++test_count
capture noisily {
    _cs434_data
    local con "`_tmp'`_tag'_t3.log"
    log using "`con'", name(cs434) text replace
    codescan dx1, define(dm "E11" ht "I10")
    log close cs434
    _cs434_scan "`con'"
    capture erase "`con'"
    assert r(nn) == 0
}
if _rc == 0 {
    display as result "  PASS: T3 - no empty condition, no note"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - no note (error `=_rc')"
    local ++fail_count
    capture log close cs434
}

**# T4
local ++test_count
capture noisily {
    _cs434_data
    local defs `"dm "E11""'
    local names ""
    forvalues k = 1/9 {
        local defs `"`defs' condition_number_`k' "QQ`k'""'
        local names "`names' condition_number_`k'"
    }
    local con "`_tmp'`_tag'_t4.log"
    log using "`con'", name(cs434) text replace
    codescan dx1, define(`defs')
    log close cs434
    mata: _cs434_note("`con'")
    assert "`nlines'" != "" 
    assert real("`maxlen'") <= 80
    local want "(note: 9 conditions matched 0 observations: `=strtrim("`names'")')"
    assert `"`joined'"' == `"`want'"'
    assert real("`nlines'") >= 2
    capture erase "`con'"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: T4 long names wrap at word boundaries"
}
else {
    local ++fail_count
    display as error "  FAIL: T4 long names wrap at word boundaries (error `=_rc')"
    capture log close cs434
}

**# Summary
_codescan_qa_restore "`_qa_owner'"
_codescan_qa_publish "test_codescan_v434" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_codescan_v434 tests=`test_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}

display as result "ALL TESTS PASSED"
