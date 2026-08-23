clear all
set more off
set varabbrev off
version 16.0

capture log close _all
log using "test_datefix_errors.log", replace text nomsg

do "_datefix_qa_common.do"
quietly _datefix_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

* Invalid order errors exactly, preserves source, and a legal order succeeds
local ++test_count
capture noisily {
    clear
    input str10 datestr byte marker
    "2020-01-15" 7
    end
    capture noisily datefix datestr, order(INVALID)
    local call_rc = _rc
    assert `call_rc' == 198
    assert datestr == "2020-01-15"
    assert marker == 7
    datefix datestr, order(YMD)
    assert datestr == mdy(1, 15, 2020)
}
if _rc == 0 local ++pass_count
else local ++fail_count

* A malformed nonmissing date errors, reports a stable fragment, and is atomic
local ++test_count
capture noisily {
    clear
    input str10 good str10 bad
    "2020-01-15" "2020-00-15"
    end
    tempfile logbase
    local errlog "`logbase'.log"
    capture log close _dferr
    log using "`errlog'", replace text name(_dferr)
    capture noisily datefix good bad, order(YMD)
    local call_rc = _rc
    log close _dferr
    assert `call_rc' == 198
    assert good == "2020-01-15"
    assert bad == "2020-00-15"
    local found = 0
    tempname fh
    file open `fh' using "`errlog'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "Specified ordering produced") local found = 1
        file read `fh' line
    }
    file close `fh'
    assert `found' == 1
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Same-name newvar errors; a distinct newvar is the legal inverse
local ++test_count
capture noisily {
    clear
    input str10 datestr
    "2020-01-15"
    end
    capture noisily datefix datestr, newvar(datestr) order(YMD)
    local call_rc = _rc
    assert `call_rc' == 198
    confirm string variable datestr
    datefix datestr, newvar(parsed) order(YMD)
    assert parsed == mdy(1, 15, 2020)
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_datefix_errors tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
capture log close _all
