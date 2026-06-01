* test_qba_qa_manifest_sync.do -- QA helper runner and manifest contract tests
* Package: qba
* Usage: cd qba/qa && stata-mp -b do test_qba_qa_manifest_sync.do

clear all
version 16.0

capture do "_qba_qa_common.do"
if _rc {
    do "qa/_qba_qa_common.do"
}

_qba_qa_root
local pkg_dir `"`r(pkg_dir)'"'
local qa_dir `"`r(qa_dir)'"'

local test_count = 0
local pass_count = 0
local fail_count = 0

**# M1: S4 helper tests are present in the active runner
local ++test_count
capture noisily {
    foreach f in test_qba_qa_common_bootstrap test_qba_qa_assert_helpers ///
        test_qba_qa_text_assertions test_qba_qa_manifest_sync {
        confirm file "`qa_dir'/`f'.do"
        _qba_qa_assert_file_contains using "`qa_dir'/run_all.do", pattern("`f'")
    }
}
if _rc == 0 {
    display as result "  PASS: M1 helper tests are in run_all.do"
    local ++pass_count
}
else {
    display as error "  FAIL: M1 helper tests are in run_all.do (error `=_rc')"
    local ++fail_count
}

**# M2: QA helper remains QA-only and is not shipped in qba.pkg
local ++test_count
capture noisily {
    confirm file "`qa_dir'/_qba_qa_common.do"
    _qba_qa_assert_file_not_contains using "`pkg_dir'/qba.pkg", pattern("_qba_qa_common.do")
}
if _rc == 0 {
    display as result "  PASS: M2 helper is not in runtime package manifest"
    local ++pass_count
}
else {
    display as error "  FAIL: M2 helper package-manifest contract (error `=_rc')"
    local ++fail_count
}

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_qba_qa_manifest_sync tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_qba_qa_manifest_sync tests=`test_count' pass=`pass_count' fail=`fail_count'"
