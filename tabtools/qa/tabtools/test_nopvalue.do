* test_nopvalue.do - Tests for table1_tc nopvalue option
* Tests: 12

clear all
version 16.0

capture log close _nopvalue
log using "test_nopvalue.log", replace nomsg name(_nopvalue)

local test_count = 0
local pass_count = 0
local fail_count = 0

adopath + "/home/tpcopeland/Stata-Tools/tabtools"

**# T1: Default by() produces p-value column

local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc mpg price weight, by(foreign) clear
    confirm variable pvalue
}
if _rc == 0 {
    display as result "  PASS T1: Default produces pvalue column"
    local ++pass_count
}
else {
    display as error "  FAIL T1: Default should produce pvalue column (rc=`=_rc')"
    local ++fail_count
}

**# T2: nopvalue suppresses p-value column

local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc mpg price weight, by(foreign) nopvalue clear
    capture confirm variable pvalue
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS T2: nopvalue suppresses pvalue column"
    local ++pass_count
}
else {
    display as error "  FAIL T2: nopvalue should suppress pvalue column (rc=`=_rc')"
    local ++fail_count
}

**# T3: nop abbreviation works

local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc mpg price weight, by(foreign) nop clear
    capture confirm variable pvalue
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS T3: nop abbreviation works"
    local ++pass_count
}
else {
    display as error "  FAIL T3: nop abbreviation should suppress pvalue (rc=`=_rc')"
    local ++fail_count
}

**# T4: nopvalue + smd still shows SMD

local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc mpg price weight, by(foreign) nopvalue smd clear
    confirm variable smd_str
    capture confirm variable pvalue
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS T4: nopvalue + smd shows SMD without pvalue"
    local ++pass_count
}
else {
    display as error "  FAIL T4: nopvalue + smd should show SMD without pvalue (rc=`=_rc')"
    local ++fail_count
}

**# T5: nopvalue + test suppresses test column

local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc mpg price weight, by(foreign) nopvalue test clear
    capture confirm variable test
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS T5: nopvalue suppresses test column"
    local ++pass_count
}
else {
    display as error "  FAIL T5: nopvalue + test should suppress test column (rc=`=_rc')"
    local ++fail_count
}

**# T6: nopvalue + statistic suppresses statistic column

local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc mpg price weight, by(foreign) nopvalue statistic clear
    capture confirm variable statistic
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS T6: nopvalue suppresses statistic column"
    local ++pass_count
}
else {
    display as error "  FAIL T6: nopvalue + statistic should suppress statistic column (rc=`=_rc')"
    local ++fail_count
}

**# T7: nopvalue without by() does not error

local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc mpg price weight, nopvalue
}
if _rc == 0 {
    display as result "  PASS T7: nopvalue without by() does not error"
    local ++pass_count
}
else {
    display as error "  FAIL T7: nopvalue without by() should not error (rc=`=_rc')"
    local ++fail_count
}

**# T8: r(Dapa) mentions P-values suppressed

local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc mpg price weight, by(foreign) nopvalue
    local dapa "`r(Dapa)'"
    assert strpos("`dapa'", "P-values suppressed") > 0
}
if _rc == 0 {
    display as result "  PASS T8: r(Dapa) mentions P-values suppressed"
    local ++pass_count
}
else {
    display as error "  FAIL T8: r(Dapa) should mention P-values suppressed (rc=`=_rc')"
    local ++fail_count
}

**# T9: r(methods) is empty with nopvalue

local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc mpg price weight, by(foreign) nopvalue
    assert "`r(methods)'" == ""
}
if _rc == 0 {
    display as result "  PASS T9: r(methods) empty with nopvalue"
    local ++pass_count
}
else {
    display as error "  FAIL T9: r(methods) should be empty with nopvalue (rc=`=_rc')"
    local ++fail_count
}

**# T10: Excel export with nopvalue works

local ++test_count
capture noisily {
    sysuse auto, clear
    tempfile xlsxout
    local xlsxout "`xlsxout'.xlsx"
    table1_tc mpg price weight, by(foreign) nopvalue xlsx("`xlsxout'")
    confirm file "`xlsxout'"
}
if _rc == 0 {
    display as result "  PASS T10: Excel export works with nopvalue"
    local ++pass_count
}
else {
    display as error "  FAIL T10: Excel export should work with nopvalue (rc=`=_rc')"
    local ++fail_count
}

**# T11: Categorical vars with nopvalue

local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc rep78, by(foreign) nopvalue clear
    capture confirm variable pvalue
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS T11: nopvalue works with categorical vars"
    local ++pass_count
}
else {
    display as error "  FAIL T11: nopvalue should suppress pvalue for categorical (rc=`=_rc')"
    local ++fail_count
}

**# T12: Binary vars with nopvalue

local ++test_count
capture noisily {
    sysuse auto, clear
    gen byte highmpg = mpg > 20
    table1_tc, vars(highmpg bin) by(foreign) nopvalue clear
    capture confirm variable pvalue
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS T12: nopvalue works with binary vars"
    local ++pass_count
}
else {
    display as error "  FAIL T12: nopvalue should suppress pvalue for binary (rc=`=_rc')"
    local ++fail_count
}

**# Summary

display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_nopvalue tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _nopvalue
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_nopvalue tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _nopvalue
