* test_qba_qa_text_assertions.do -- text/file-content assertion helper tests
* Package: qba
* Usage: cd qba/qa && stata-mp -b do test_qba_qa_text_assertions.do

clear all
version 16.0

capture do "_qba_qa_common.do"
if _rc {
    do "qa/_qba_qa_common.do"
}

local test_count = 0
local pass_count = 0
local fail_count = 0

tempfile textfile
tempname fh
file open `fh' using "`textfile'", write text replace
file write `fh' "alpha beta" _n
file write `fh' "qba helper line" _n
file close `fh'

**# T1: contains and not-contains helpers inspect text files
local ++test_count
capture noisily {
    _qba_qa_assert_file_contains using "`textfile'", pattern("qba helper")
    _qba_qa_assert_file_not_contains using "`textfile'", pattern("absent phrase")
    _assert_text_file_contains "`textfile'" "alpha"
    _assert_text_file_not_contains "`textfile'" "not present"
}
if _rc == 0 {
    display as result "  PASS: T1 text contains/not-contains helpers"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 text contains/not-contains helpers (error `=_rc')"
    local ++fail_count
}

**# T2: text assertions fail when the content contract is not met
local ++test_count
capture noisily {
    capture _qba_qa_assert_file_contains using "`textfile'", pattern("not present")
    assert _rc == 9
    capture _qba_qa_assert_file_not_contains using "`textfile'", pattern("qba helper")
    assert _rc == 9
}
if _rc == 0 {
    display as result "  PASS: T2 text assertion failure cases"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 text assertion failure cases (error `=_rc')"
    local ++fail_count
}

**# T3: exact first-line helper checks full line content
local ++test_count
capture noisily {
    _qba_qa_assert_file_equals using "`textfile'", text("alpha beta")
    capture _qba_qa_assert_file_equals using "`textfile'", text("alpha")
    assert _rc == 9
}
if _rc == 0 {
    display as result "  PASS: T3 exact file-content helper"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 exact file-content helper (error `=_rc')"
    local ++fail_count
}

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_qba_qa_text_assertions tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_qba_qa_text_assertions tests=`test_count' pass=`pass_count' fail=`fail_count'"
