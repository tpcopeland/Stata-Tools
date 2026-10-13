*! test_datefix_message.do -- summary wording: numeric inputs are reformatted, not converted
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

* N1: numeric input is reported as already numeric, never as converted
local ++test_count
capture noisily {
    clear
    set obs 3
    gen double d = mdy(1,15,2020) + _n
    tempfile base
    local lg "`base'.log"
    capture log close _dfmsg
    log using "`lg'", replace text name(_dfmsg)
    datefix d
    log close _dfmsg
    local nconv = 0
    local nnum = 0
    tempname fh
    file open `fh' using "`lg'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "converted to numeric date") local nconv = 1
        if strpos(`"`line'"', "Variable d is already numeric; date format applied.") local nnum = 1
        file read `fh' line
    }
    file close `fh'
    assert `nconv' == 0
    assert `nnum' == 1
}
if _rc == 0 {
    display as result "PASS: N1 numeric input wording"
    local ++pass_count
}
else {
    capture log close _dfmsg
    display as error "FAIL: N1 numeric input wording"
    local ++fail_count
}

* guard: N2 is expected green at HEAD (string wording is unchanged)
* N2: string input is still reported as converted
local ++test_count
capture noisily {
    clear
    input str12 s
    "2020-01-15"
    "2020-02-20"
    end
    tempfile base2
    local lg "`base2'.log"
    capture log close _dfmsg
    log using "`lg'", replace text name(_dfmsg)
    datefix s, order(YMD)
    log close _dfmsg
    local nconv = 0
    tempname fh
    file open `fh' using "`lg'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "Variable s converted to numeric date.") local nconv = 1
        file read `fh' line
    }
    file close `fh'
    assert `nconv' == 1
}
if _rc == 0 {
    display as result "PASS: N2 string input wording"
    local ++pass_count
}
else {
    capture log close _dfmsg
    display as error "FAIL: N2 string input wording"
    local ++fail_count
}

display "RESULT: test_datefix_message tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
