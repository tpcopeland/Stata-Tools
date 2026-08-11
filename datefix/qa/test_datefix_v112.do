*! test_datefix_v112.do — regressions fixed in datefix 1.1.2
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set varabbrev off
version 16.0

capture log close _all

local qa_dir "`c(pwd)'"
do "`qa_dir'/_datefix_qa_common.do"
quietly _datefix_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Colon-separated daily dates

local ++test_count
capture noisily {
    clear
    input str10 ymd str10 dmy str10 autodate
    "2020:01:15" "15:01:2020" "2020:01:15"
    "2024:12:31" "31:12:2024" "2024:12:31"
    end
    datefix ymd, order(YMD)
    datefix dmy, order(DMY)
    datefix autodate
    assert ymd[1] == mdy(1, 15, 2020)
    assert ymd[2] == mdy(12, 31, 2024)
    assert dmy[1] == mdy(1, 15, 2020)
    assert dmy[2] == mdy(12, 31, 2024)
    assert autodate[1] == mdy(1, 15, 2020)
    assert autodate[2] == mdy(12, 31, 2024)
}
if _rc == 0 {
    display as result "  PASS: colon-separated daily dates are parsed"
    local ++pass_count
}
else {
    display as error "  FAIL: colon-separated daily dates (error `=_rc')"
    local ++fail_count
}

**# All-missing input rejects zero-result success

local ++test_count
capture noisily {
    clear
    set obs 3
    generate str10 datestr = ""
    set varabbrev on
    capture noisily datefix datestr, order(YMD)
    local call_rc = _rc
    assert `call_rc' == 2000
    confirm string variable datestr
    assert datestr == ""
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: all-missing string input errors without mutation"
    local ++pass_count
}
else {
    display as error "  FAIL: all-missing string input (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    set obs 3
    generate double numdate = .
    format numdate %9.0g
    local fmt_before : format numdate
    capture noisily datefix numdate
    local call_rc = _rc
    assert `call_rc' == 2000
    confirm numeric variable numdate
    assert missing(numdate)
    local fmt_after : format numdate
    assert "`fmt_after'" == "`fmt_before'"
}
if _rc == 0 {
    display as result "  PASS: all-missing numeric input errors without mutation"
    local ++pass_count
}
else {
    display as error "  FAIL: all-missing numeric input (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input str10 good str10 empty
    "2020-01-15" ""
    "2020-06-30" ""
    end
    unab order_before : _all
    capture noisily datefix good empty, order(YMD)
    local call_rc = _rc
    assert `call_rc' == 2000
    confirm string variable good
    confirm string variable empty
    assert good[1] == "2020-01-15"
    assert empty == ""
    unab order_after : _all
    assert "`order_after'" == "`order_before'"
}
if _rc == 0 {
    display as result "  PASS: mixed varlist with an all-missing member is atomic"
    local ++pass_count
}
else {
    display as error "  FAIL: mixed all-missing varlist rollback (error `=_rc')"
    local ++fail_count
}

**# Diagnostic output fidelity

local ++test_count
capture noisily {
    clear
    input str20 datestr
    "{it:not-a-date}"
    end
    tempfile diagbase
    local diaglog "`diagbase'.log"
    capture log close _dfdiag
    log using "`diaglog'", replace text name(_dfdiag)
    capture noisily datefix datestr, order(YMD) diagnose
    local call_rc = _rc
    log close _dfdiag
    assert `call_rc' == 198

    local found_literal = 0
    tempname fh
    file open `fh' using "`diaglog'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "{it:not-a-date}") local found_literal = 1
        file read `fh' line
    }
    file close `fh'
    assert `found_literal' == 1
}
if _rc == 0 {
    display as result "  PASS: diagnostic values print literal SMCL-like text"
    local ++pass_count
}
else {
    local test_rc = _rc
    capture log close _dfdiag
    display as error "  FAIL: diagnostic SMCL fidelity (error `test_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    set obs 1
    local uchar = ustrunescape("\u00e5")
    local unicode_value ""
    forvalues i = 1/20 {
        local unicode_value "`unicode_value'`uchar'"
    }
    generate strL datestr = "`unicode_value'"

    tempfile diagbase
    local diaglog "`diagbase'.log"
    capture log close _dfdiag
    log using "`diaglog'", replace text name(_dfdiag)
    capture noisily datefix datestr, order(YMD) diagnose
    local call_rc = _rc
    log close _dfdiag
    assert `call_rc' == 198

    local found_unicode = 0
    tempname fh
    file open `fh' using "`diaglog'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "`unicode_value'") local found_unicode = 1
        file read `fh' line
    }
    file close `fh'
    assert `found_unicode' == 1
}
if _rc == 0 {
    display as result "  PASS: diagnostic truncation counts Unicode characters"
    local ++pass_count
}
else {
    local test_rc = _rc
    capture log close _dfdiag
    display as error "  FAIL: diagnostic Unicode fidelity (error `test_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input str12 datestr
    "alpha-bad"
    "beta-bad"
    "alpha-bad"
    end

    tempfile diagbase
    local diaglog "`diagbase'.log"
    capture log close _dfdiag
    log using "`diaglog'", replace text name(_dfdiag)
    capture noisily datefix datestr, order(YMD) diagnose
    local call_rc = _rc
    log close _dfdiag
    assert `call_rc' == 198

    local found_alpha = 0
    local found_beta = 0
    tempname fh
    file open `fh' using "`diaglog'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "alpha-bad") & ///
                strpos(`"`macval(line)'"', "2") & ///
                strpos(`"`macval(line)'"', "1, 3") local found_alpha = 1
        if strpos(`"`macval(line)'"', "beta-bad") & ///
                strpos(`"`macval(line)'"', "1") & ///
                strpos(`"`macval(line)'"', "2") local found_beta = 1
        file read `fh' line
    }
    file close `fh'
    assert `found_alpha' == 1
    assert `found_beta' == 1
}
if _rc == 0 {
    display as result "  PASS: diagnostic frequencies and observation rows are exact"
    local ++pass_count
}
else {
    local test_rc = _rc
    capture log close _dfdiag
    display as error "  FAIL: diagnostic frequency/row output (error `test_rc')"
    local ++fail_count
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_datefix_v112 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
