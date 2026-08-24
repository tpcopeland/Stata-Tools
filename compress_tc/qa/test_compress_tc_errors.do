clear all
set more off
set varabbrev off
version 16.0

capture log close _all
log using "test_compress_tc_errors.log", replace text nomsg

capture ado uninstall compress_tc
local pkg_dir = subinstr("`c(pwd)'", "/qa", "", 1)
adopath ++ "`pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0

* Mutually exclusive processing modes reject before changing values
local ++test_count
capture noisily {
    clear
    input str12 code byte marker
    "ABCDEFGHIJK" 7
    end
    local before = marker[1]
    capture noisily compress_tc code, nocompress nostrl
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker[1] == `before'
    compress_tc code, nocompress
    assert !missing(r(k_converted))
    assert r(k_converted) >= 0
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Negative minlength errors before conversion; boundary zero is legal
local ++test_count
capture noisily {
    clear
    input str12 code byte marker
    "ABCDEFGHIJK" 8
    end
    local before = marker[1]
    capture noisily compress_tc code, minlength(-1)
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker[1] == `before'
    compress_tc code, minlength(0) nocompress
    assert "`r(varlist)'" == "code"
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Empty data is a defined clean result rather than a silent error
local ++test_count
capture noisily {
    clear
    set obs 0
    generate str8 code = ""
    compress_tc code, quietly
    assert r(bytes_saved) == 0
    assert r(k_converted) == 0
    assert _N == 0
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_compress_tc_errors tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
capture log close _all
