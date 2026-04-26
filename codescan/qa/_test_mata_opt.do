* _test_mata_opt.do - Test Mata optimizations for codescan v1.1.0
* Tests: match count accumulation, co-occurrence overlap detection,
*        multi-window single-pass, describe hash tabulation

clear all
version 16.0

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall codescan
quietly net install codescan, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

clear
set seed 42
set obs 1000

gen str5 pid = "P" + string(ceil(runiform() * 200), "%04.0f")
gen double date = mdy(1,1,2020) + floor(runiform() * 365)
format date %td
gen double refdate = mdy(6,1,2020)
format refdate %td

gen str5 dx1 = ""
gen str5 dx2 = ""
gen str5 dx3 = ""

forvalues i = 1/`=_N' {
    if runiform() < 0.3 quietly replace dx1 = "E11" + string(floor(runiform()*10)) in `i'
    if runiform() < 0.2 quietly replace dx2 = "I10" in `i'
    if runiform() < 0.1 quietly replace dx3 = "J44" + string(floor(runiform()*10)) in `i'
    if runiform() < 0.15 quietly replace dx1 = "E66" in `i'
}


**# Test 1: Basic row-level scan (match counts from Mata)

local ++test_count
capture noisily {
    codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66") id(pid)
    return list
    assert r(N) == 1000
    assert r(n_conditions) == 4
}
if _rc == 0 {
    display as result "  PASS: basic row-level scan"
    local ++pass_count
}
else {
    display as error "  FAIL: basic row-level scan (error `=_rc')"
    local ++fail_count
}


**# Test 2: Collapse mode

local ++test_count
capture noisily {
    preserve
    codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66") id(pid) collapse replace
    return list
    assert r(collapsed) == 1
    restore
}
if _rc == 0 {
    display as result "  PASS: collapse mode"
    local ++pass_count
}
else {
    display as error "  FAIL: collapse mode (error `=_rc')"
    local ++fail_count
}


**# Test 3: Merge mode

local ++test_count
capture noisily {
    preserve
    codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66") id(pid) merge replace
    return list
    assert r(merged) == 1
    restore
}
if _rc == 0 {
    display as result "  PASS: merge mode"
    local ++pass_count
}
else {
    display as error "  FAIL: merge mode (error `=_rc')"
    local ++fail_count
}


**# Test 4: Countmode

local ++test_count
capture noisily {
    codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66") id(pid) countmode replace
    return list
}
if _rc == 0 {
    display as result "  PASS: countmode"
    local ++pass_count
}
else {
    display as error "  FAIL: countmode (error `=_rc')"
    local ++fail_count
}


**# Test 5: Co-occurrence overlap detection (single Mata pass)

local ++test_count
capture noisily {
    * Create overlapping conditions that trigger the overlap warning
    codescan dx1-dx3, define(diabetes "E1[01]" | dm2 "E11") id(pid) noisily replace
    return list
}
if _rc == 0 {
    display as result "  PASS: co-occurrence overlap detection"
    local ++pass_count
}
else {
    display as error "  FAIL: co-occurrence overlap detection (error `=_rc')"
    local ++fail_count
}


**# Test 6: Multi-window sensitivity (single supplementary scan)

local ++test_count
capture noisily {
    preserve
    codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44") ///
        id(pid) date(date) refdate(refdate) lookback(30 90 180 365) collapse replace
    return list
    assert r(n_conditions) == 3
    matrix list r(sensitivity)
    restore
}
if _rc == 0 {
    display as result "  PASS: multi-window sensitivity"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-window sensitivity (error `=_rc')"
    local ++fail_count
}


**# Test 7: Multi-window with collapse

local ++test_count
capture noisily {
    preserve
    codescan dx1-dx3, define(dm2 "E11" | htn "I10") ///
        id(pid) date(date) refdate(refdate) lookback(30 90 180) collapse replace
    return list
    matrix list r(sensitivity)
    restore
}
if _rc == 0 {
    display as result "  PASS: multi-window with collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-window with collapse (error `=_rc')"
    local ++fail_count
}


**# Test 8: codescan_describe (Mata hash tabulation)

local ++test_count
capture noisily {
    codescan_describe dx1-dx3
    return list
    assert r(n_unique) > 0
    assert r(n_entries) > 0
    matrix list r(top_codes)
    matrix list r(chapters)
}
if _rc == 0 {
    display as result "  PASS: codescan_describe"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe (error `=_rc')"
    local ++fail_count
}


**# Test 9: codescan_describe with nodots

local ++test_count
capture noisily {
    codescan_describe dx1-dx3, nodots
    return list
}
if _rc == 0 {
    display as result "  PASS: codescan_describe nodots"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe nodots (error `=_rc')"
    local ++fail_count
}


**# Test 10: Detail mode (per-variable tracking)

local ++test_count
capture noisily {
    codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44") id(pid) detail replace
    return list
    matrix list r(varcounts)
}
if _rc == 0 {
    display as result "  PASS: detail mode"
    local ++pass_count
}
else {
    display as error "  FAIL: detail mode (error `=_rc')"
    local ++fail_count
}


**# Test 11: Prefix mode

local ++test_count
capture noisily {
    codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44") id(pid) mode(prefix) replace
    return list
}
if _rc == 0 {
    display as result "  PASS: prefix mode"
    local ++pass_count
}
else {
    display as error "  FAIL: prefix mode (error `=_rc')"
    local ++fail_count
}


**# Test 12: Nocase

local ++test_count
capture noisily {
    codescan dx1-dx3, define(dm2 "e11" | htn "i10") id(pid) nocase replace
    return list
}
if _rc == 0 {
    display as result "  PASS: nocase"
    local ++pass_count
}
else {
    display as error "  FAIL: nocase (error `=_rc')"
    local ++fail_count
}


**# Test 13: Co-occurrence option

local ++test_count
capture noisily {
    preserve
    codescan dx1-dx3, define(dm2 "E11" | htn "I10" | copd "J44" | obesity "E66") ///
        id(pid) collapse cooccurrence replace
    return list
    matrix list r(cooccurrence)
    restore
}
if _rc == 0 {
    display as result "  PASS: co-occurrence option"
    local ++pass_count
}
else {
    display as error "  FAIL: co-occurrence option (error `=_rc')"
    local ++fail_count
}


**# Test 14: Matched code capture

local ++test_count
capture noisily {
    codescan dx1-dx3, define(dm2 "E11" | htn "I10") id(pid) matched_code(mc) replace
    assert mc != "" if dm2 == 1 | htn == 1
    return list
}
if _rc == 0 {
    display as result "  PASS: matched code capture"
    local ++pass_count
}
else {
    display as error "  FAIL: matched code capture (error `=_rc')"
    local ++fail_count
}


* Summary

display ""
display as result "RESULT: _test_mata_opt tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
