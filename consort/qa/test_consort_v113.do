* test_consort_v113.do -- text keeps a visible margin inside its box
* Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
local pkg_dir "`c(pwd)'/.."
capture ado uninstall consort
quietly net install consort, from("`pkg_dir'") replace
tempfile out_base
local out "`out_base'_consort_margin"
capture mkdir "`out'"
local test_count 0
local pass_count 0
local fail_count 0

* M1: measured text sits at least 0.055 in inside every box at 100/150/300 dpi
local ++test_count
capture noisily {
    shell python3 tools/check_margin.py "`pkg_dir'" > "`out'/receipt" 2>&1
    tempname fh
    local ok 0
    file open `fh' using "`out'/receipt", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "MARGIN_PASS") local ok 1
        file read `fh' line
    }
    file close `fh'
    assert `ok' == 1
}
if _rc == 0 {
    local ++pass_count
    display "PASS: M1 text margin inside boxes"
}
else {
    local ++fail_count
    display "FAIL: M1 text margin inside boxes"
}
display "RESULT: test_consort_v113 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
