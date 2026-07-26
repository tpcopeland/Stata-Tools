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

**# M3: qba.pkg lists every .ado in the package directory
* A helper added without its `f' line works on a dev machine (tests `run' the
* file) and is simply absent for an installed user. Enumerate the directory
* rather than a hand-kept list, so a new helper cannot be forgotten here too.
local ++test_count
capture noisily {
    local shipped : dir "`pkg_dir'" files "*.ado"
    local n_checked = 0
    foreach f of local shipped {
        _qba_qa_assert_file_contains using "`pkg_dir'/qba.pkg", pattern("f `f'")
        local ++n_checked
    }
    if `n_checked' < 15 {
        display as error "only `n_checked' .ado files enumerated; expected the full package"
        exit 9
    }
    * and every .sthlp likewise
    local helps : dir "`pkg_dir'" files "*.sthlp"
    foreach f of local helps {
        _qba_qa_assert_file_contains using "`pkg_dir'/qba.pkg", pattern("f `f'")
    }
}
if _rc == 0 {
    display as result "  PASS: M3 qba.pkg lists every shipped .ado and .sthlp"
    local ++pass_count
}
else {
    display as error "  FAIL: M3 qba.pkg shipped-file completeness (error `=_rc')"
    local ++fail_count
}

**# M4: every suite in qa/ is wired into run_all.do
* A suite that exists but is not in the runner is the quietest false green
* there is: it passes in isolation and never executes in the lane. Enumerate
* the directory instead of trusting a hand-kept list.
local ++test_count
capture noisily {
    local suites ""
    foreach pat in test_*.do validation_*.do crossval_*.do {
        local found : dir "`qa_dir'" files "`pat'"
        local suites `"`suites' `found'"'
    }
    local n_checked = 0
    foreach f of local suites {
        * The runner itself and the shared helper are not suites.
        if "`f'" == "run_all.do" | "`f'" == "_qba_qa_common.do" continue
        local stem = subinstr("`f'", ".do", "", .)
        _qba_qa_assert_file_contains using "`qa_dir'/run_all.do", pattern("`stem'")
        local ++n_checked
    }
    if `n_checked' < 30 {
        display as error "only `n_checked' suites enumerated; expected the full qa/ directory"
        exit 9
    }
}
if _rc == 0 {
    display as result "  PASS: M4 every qa/ suite is wired into run_all.do"
    local ++pass_count
}
else {
    display as error "  FAIL: M4 runner completeness (error `=_rc')"
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
