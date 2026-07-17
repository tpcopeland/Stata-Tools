* test_codescan_v208.do - Regression tests for the v2.0.8 fixes
* Date: 2026-07-07
*
* Each test is written to FAIL on the pre-2.0.8 code and PASS after the fix.
*
* Covers:
*   T1: label() text containing a backslash (e.g. a Windows path "C:\dir")
*       no longer aborts with r(132); the backslash is preserved inside the
*       variable label while the "\" entry separator still splits entries.
*   T2: a bare "." code slot (missing-value placeholder) is skipped by
*       codescan, matching codescan_describe — a broad match-any pattern no
*       longer picks up phantom "." rows, and the two commands agree.
*       (v3.0.0: the match-any pattern here is "." rather than ".*", which is
*       now rejected as an empty-match pattern.)
*   T3: under nodots, an all-dots value ("..", "...") that strips to "" is
*       likewise skipped by codescan and codescan_describe (no phantom match).
*   T4: an if-expression referencing a numeric scan variable now works with
*       tostring, because if/in is marked against the call-time (numeric) data
*       before tostring recasts the variable to string.

clear all
set seed 12345
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

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


**# T1: backslash inside quoted label text + separator still splits

local ++test_count
capture noisily {
    clear
    input str5 dx1
    "E11"
    "I10"
    end
    gen pid = _n
    * Two entries separated by "\"; each label text contains an internal "\".
    codescan dx1, define(dm2 "E11" | i10 "I10") id(pid) collapse ///
        label(dm2 "C:\reg\dm" \ i10 "Hyper\tension")
    * Backslash must survive inside the applied variable labels...
    local _Ldm : variable label dm2
    local _Lih : variable label i10
    assert `"`_Ldm'"' == "C:\reg\dm"
    assert `"`_Lih'"' == "Hyper\tension"
}
if _rc == 0 {
    display as result "  PASS T1: label() backslash preserved; separator still splits"
    local ++pass_count
}
else {
    display as error "  FAIL T1: label() backslash handling (rc=`=_rc')"
    local ++fail_count
}

**# T2: bare "." skipped by codescan, consistent with codescan_describe

local ++test_count
capture noisily {
    clear
    input str5 dx1
    "E11"
    "I10"
    "."
    "."
    end
    gen pid = _n
    * codescan_describe treats "." as missing -> 2 unique codes.
    codescan_describe dx1
    assert r(n_unique) == 2
    * codescan must agree: a match-any pattern hits only the 2 real codes, not
    * the 2 dots. v3.0.0 rejects ".*" as an empty-match pattern (it matches every
    * code, including "", which is the C2 false-cohort class); "." is the
    * equivalent match-any-non-empty-code idiom and is what the error suggests.
    codescan dx1, define(anyc ".")
    count if anyc == 1
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS T2: bare '.' skipped; codescan agrees with describe"
    local ++pass_count
}
else {
    display as error "  FAIL T2: bare '.' handling (rc=`=_rc')"
    local ++fail_count
}

**# T3: nodots all-dots value strips to "" and is skipped by both commands

local ++test_count
capture noisily {
    clear
    input str6 dx1
    "E11"
    ".."
    end
    gen pid = _n
    * Under nodots, ".." strips to "" -> describe reports 1 unique code.
    codescan_describe dx1, nodots
    assert r(n_unique) == 1
    * codescan under nodots must also skip ".." -> match-any hits only E11.
    codescan dx1, define(anyc ".") nodots
    count if anyc == 1
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS T3: nodots all-dots value skipped by both commands"
    local ++pass_count
}
else {
    display as error "  FAIL T3: nodots all-dots handling (rc=`=_rc')"
    local ++fail_count
}

**# T4: if-expression on a numeric scan variable works with tostring

local ++test_count
capture noisily {
    clear
    set obs 6
    gen dx1 = _n            // numeric 1..6
    gen pid = _n
    * if dx1 > 4 references the scan variable while it is still numeric.
    codescan dx1 if dx1 > 4, define(hi "^[5-9]") tostring
    * Only rows 5,6 are in the sample; both match "^[5-9]".
    assert r(N) == 2
    count if hi == 1
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS T4: if on numeric scan var works with tostring"
    local ++pass_count
}
else {
    display as error "  FAIL T4: if + tostring ordering (rc=`=_rc')"
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


**# Summary

display ""
display as result "RESULT: test_codescan_v208 tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
