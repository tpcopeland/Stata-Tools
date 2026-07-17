* test_codescan_v2_no_scoring.do — asserts comorbidity scoring is gone from codescan v2.0.
clear all
version 16.0
set varabbrev off

* Install the local package copy so an installed build cannot shadow it.
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
* Guarded shared bootstrap. Sandboxes PLUS/PERSONAL under c(tmpdir), then
* installs this working copy. Running this suite standalone must not mutate
* the developer's real adopath, which the bare net install here used to do;
* only run_all.do was sandboxed. Idempotent, so the lane re-entering it is
* harmless.
quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap

* Session settings captured for the hygiene check at the end of this suite.
* A suite that leaves c(level) or c(varabbrev) changed silently alters every
* later suite in the lane -- the level-80/99 CI scenarios restored inside a
* captured block, so any assertion failure above them used to leak.
local _qa_level0 = c(level)
local _qa_va0 "`c(varabbrev)'"
local _qa_pwd0 "`c(pwd)'"


input long pid str6 dx1
1 "E119"
2 "I50"
end

local test_count = 0
local pass_count = 0
local fail_count = 0

* score() must no longer be a valid option
local ++test_count
capture codescan dx1, define(dm "E11") id(pid) collapse score(charlson)
if _rc == 198 {
    display as result "  PASS: score() rejected"
    local ++pass_count
}
else {
    display as error "FAIL: score() still accepted (rc=`=_rc', expected 198)"
    local ++fail_count
}

* hierarchy() must no longer be a valid option
local ++test_count
capture codescan dx1, define(dm "E11" | dm2 "E10") id(pid) collapse hierarchy(dm > dm2)
if _rc == 198 {
    display as result "  PASS: hierarchy() rejected"
    local ++pass_count
}
else {
    display as error "FAIL: hierarchy() still accepted (rc=`=_rc', expected 198)"
    local ++fail_count
}

* basename codefile resolution must be gone (file genuinely not found -> 601)
local ++test_count
capture codescan dx1, codefile(charlson_icd10_example.csv) id(pid) collapse
if _rc == 601 {
    display as result "  PASS: basename codefile no longer resolved"
    local ++pass_count
}
else {
    display as error "FAIL: basename codefile still resolved (rc=`=_rc', expected 601)"
    local ++fail_count
}

* core scanning still works
local ++test_count
capture noisily {
    codescan dx1, define(dm "E11" | chf "I50") id(pid) collapse
    assert r(n_conditions) == 2
}
if _rc == 0 {
    display as result "  PASS: core scanning still works"
    local ++pass_count
}
else {
    display as error "FAIL: core scanning failed (rc=`=_rc')"
    local ++fail_count
}


**# Settings hygiene

* This suite must not leak a session setting to whatever runs next.
local ++test_count
capture noisily {
    assert c(level) == `_qa_level0'
    assert "`c(varabbrev)'" == "`_qa_va0'"
    assert "`c(pwd)'" == "`_qa_pwd0'"
}
if _rc == 0 {
    display as result "  PASS: no session setting leaked"
    local ++pass_count
}
else {
    display as error "  FAIL: session setting leaked (error `=_rc')"
    local ++fail_count
}


display as result "RESULT: test_codescan_v2_no_scoring tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
display as result "ALL TESTS PASSED"
