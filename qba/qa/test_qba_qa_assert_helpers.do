* test_qba_qa_assert_helpers.do -- numeric assertion helper tests
* Package: qba
* Usage: cd qba/qa && stata-mp -b do test_qba_qa_assert_helpers.do

clear all
version 16.0

capture do "_qba_qa_common.do"
if _rc {
    do "qa/_qba_qa_common.do"
}

local test_count = 0
local pass_count = 0
local fail_count = 0

**# A1: numeric close accepts exact and within-tolerance values
local ++test_count
capture noisily {
    _qba_qa_assert_close 1 1
    _qba_qa_assert_close 1.0000001 1 0.000001
    _assert_close 2.5 2.50000001 0.000001
}
if _rc == 0 {
    display as result "  PASS: A1 numeric close success cases"
    local ++pass_count
}
else {
    display as error "  FAIL: A1 numeric close success cases (error `=_rc')"
    local ++fail_count
}

**# A2: numeric close rejects out-of-tolerance values
local ++test_count
capture noisily {
    capture _qba_qa_assert_close 1.1 1 0.001
    assert _rc == 9
    capture _assert_close 1 1.1 0.001
    assert _rc == 9
}
if _rc == 0 {
    display as result "  PASS: A2 numeric close failure cases"
    local ++pass_count
}
else {
    display as error "  FAIL: A2 numeric close failure cases (error `=_rc')"
    local ++fail_count
}

**# A3: missing values compare only to missing values
local ++test_count
capture noisily {
    _qba_qa_assert_close . .
    capture _qba_qa_assert_close . 1
    assert _rc == 9
    capture _qba_qa_assert_close 1 .
    assert _rc == 9
}
if _rc == 0 {
    display as result "  PASS: A3 missing-value comparison"
    local ++pass_count
}
else {
    display as error "  FAIL: A3 missing-value comparison (error `=_rc')"
    local ++fail_count
}

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_qba_qa_assert_helpers tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_qba_qa_assert_helpers tests=`test_count' pass=`pass_count' fail=`fail_count'"
