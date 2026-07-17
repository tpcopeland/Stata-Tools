* test_codescan_install_verify.do - Package install verification for codescan
* Date: 2026-07-17
*
* Split from test_codescan.do (audit finding Q8): the single file had grown to
* 6,859 lines / 309 tests, which no reviewer could hold. Test bodies are copied
* verbatim -- only the scaffold is new. `_make_test_data' now lives in
* _codescan_qa_common.do so every split suite shares one definition.
*
* The authoritative test count is the RESULT: sentinel this suite prints at the
* end. A hand-maintained count in a comment goes stale silently, so it is not
* repeated here.

clear all
set seed 12345
version 16.0
set varabbrev off

* ============================================================
* Setup
* ============================================================

local test_count = 0
local pass_count = 0
local fail_count = 0


* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

* Guarded shared bootstrap. Sandboxes PLUS/PERSONAL under c(tmpdir), then
* installs this working copy, and defines the shared `_make_test_data' builder.
* Running this suite standalone must not mutate the developer's real adopath.
* Idempotent, so the lane re-entering it is harmless.
quietly do "`qa_dir'/_codescan_qa_common.do"
_codescan_qa_bootstrap

* Session settings captured for the hygiene check at the end of this suite.
* A suite that leaves c(level) or c(varabbrev) changed silently alters every
* later suite in the lane.
local _qa_level0 = c(level)
local _qa_va0 "`c(varabbrev)'"
local _qa_pwd0 "`c(pwd)'"

**# Package Install Verification

**## which finds both commands after net install
local ++test_count
capture noisily {
    capture ado uninstall codescan
    quietly net install codescan, from("`pkg_dir'")
    which codescan
    which codescan_describe
}
if _rc == 0 {
    display as result "  PASS: Both commands discoverable after install"
    local ++pass_count
}
else {
    display as error "  FAIL: Commands not discoverable (error `=_rc')"
    local ++fail_count
}

**## Documentation example from README runs
local ++test_count
capture noisily {
    * Recreate a minimal version of the README example
    clear
    set obs 10
    gen long pid = _n
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    replace dx1 = "E110" in 1
    replace dx1 = "I10" in 2
    replace dx2 = "E660" in 3
    replace dx1 = "Z00" in 4/10
    codescan dx1 dx2, define(dm2 "E11" | obesity "E66")
    assert r(n_conditions) == 2
}
if _rc == 0 {
    display as result "  PASS: README example runs"
    local ++pass_count
}
else {
    display as error "  FAIL: README example (error `=_rc')"
    local ++fail_count
}


**## v1.4.1 regression tests

* Test: unmatched() with countmode — rows with count >= 2 must NOT be flagged
local ++test_count
capture noisily {
    _make_test_data
    * Patient 1 row 1: dx1=E110, dx2=E660 — dm2 matches in dx1 (count=1)
    * But we need a row matching the SAME condition in 2 vars for count >= 2
    replace dx2 = "E119" in 1
    codescan dx1 dx2, define(dm2 "E11") countmode unmatched(nomatch) replace
    * Row 1: dx1=E110 matches, dx2=E119 matches → dm2=2, nomatch should be 0
    assert dm2[1] == 2
    assert nomatch[1] == 0
    * Patient 5 row 17: dx1=Z00, dx2="" → dm2=0, nomatch should be 1
    assert dm2[17] == 0
    assert nomatch[17] == 1
}
if _rc == 0 {
    display as result "  PASS: unmatched() correct with countmode (count >= 2)"
    local ++pass_count
}
else {
    display as error "  FAIL: unmatched() with countmode (error `=_rc')"
    local ++fail_count
}

* Test: unmatched() with countmode — single match also cleared
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") countmode unmatched(nomatch) replace
    * Row 5: dx1=I10, dx2="" → htn=1, dm2=0, nomatch should be 0
    assert nomatch[5] == 0
    * Row 17: dx1=Z00 → no match, nomatch should be 1
    assert nomatch[17] == 1
}
if _rc == 0 {
    display as result "  PASS: unmatched() with countmode (single match cleared)"
    local ++pass_count
}
else {
    display as error "  FAIL: unmatched() countmode single match (error `=_rc')"
    local ++fail_count
}

* Test: multi-window sensitivity with narrow secondary window (0 patients)
local ++test_count
capture noisily {
    clear
    set obs 10
    gen long pid = _n
    gen str10 dx1 = ""
    gen double visit_dt = .
    gen double index_dt = mdy(1, 1, 2020)
    format visit_dt index_dt %td
    * All visits are 200+ days before index — outside a 7-day window
    replace visit_dt = mdy(5, 1, 2019)
    replace dx1 = "E110" in 1/5
    replace dx1 = "Z00" in 6/10
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(365 7) collapse replace
    * Primary (365d): should find matches
    assert r(n_conditions) == 1
    * Sensitivity matrix should exist and not cause errors
    matrix list r(sensitivity)
    * The 7d column may have . (missing) due to 0 patients — that's correct
}
if _rc == 0 {
    display as result "  PASS: multi-window sensitivity with narrow window (no crash)"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-window narrow window (error `=_rc')"
    local ++fail_count
}

* Test: multi-window sensitivity with adequate data in both windows
local ++test_count
capture noisily {
    clear
    set obs 10
    gen long pid = _n
    gen str10 dx1 = ""
    gen double visit_dt = .
    gen double index_dt = mdy(1, 1, 2020)
    format visit_dt index_dt %td
    * 5 patients with visits 3 days before index (within both 365d and 7d)
    replace visit_dt = mdy(12, 29, 2019)
    replace dx1 = "E110" in 1/5
    replace dx1 = "Z00" in 6/10
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(365 7) collapse replace
    * Both windows should show 50% prevalence (5 of 10)
    assert el(r(sensitivity), 1, 1) == 50
    assert el(r(sensitivity), 1, 2) == 50
}
if _rc == 0 {
    display as result "  PASS: multi-window sensitivity with data in both windows"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-window both windows (error `=_rc')"
    local ++fail_count
}


* ============================================================

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

* Summary
* ============================================================

display ""
_codescan_qa_publish "test_codescan_install_verify" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_codescan_install_verify tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
