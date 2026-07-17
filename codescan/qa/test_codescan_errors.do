* test_codescan_errors.do - Error-path tests for codescan
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

**# Expanded Error Path Tests

**## Error — define() empty string
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define()
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — define() empty string (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — define() empty string (error `=_rc')"
    local ++fail_count
}

**## Error — define() condition with no pattern
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — define() condition with no pattern (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — define() condition with no pattern (error `=_rc')"
    local ++fail_count
}

**## Error — define() tilde without exclusion pattern
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11" ~ )
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — tilde without exclusion pattern (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — tilde without exclusion pattern (error `=_rc')"
    local ++fail_count
}

**## Error — neither define() nor codefile()
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — neither define nor codefile (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — neither define nor codefile (error `=_rc')"
    local ++fail_count
}

**## Error — both define() and codefile()
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") codefile("dummy.csv")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — both define and codefile (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — both define and codefile (error `=_rc')"
    local ++fail_count
}

**## Error — lookback() with non-integer
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookback(abc)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — lookback non-integer (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — lookback non-integer (error `=_rc')"
    local ++fail_count
}

**## Error — lookback() with negative value
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookback(-10)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — lookback negative (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — lookback negative (error `=_rc')"
    local ++fail_count
}

**## Error — lookforward() negative
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookforward(-5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — lookforward negative (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — lookforward negative (error `=_rc')"
    local ++fail_count
}

**## Error — multi-window lookback without collapse/merge
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookback(90 365)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — multi-window without collapse (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — multi-window without collapse (error `=_rc')"
    local ++fail_count
}

**## Error — date() with string variable
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(dx1) refdate(index_dt) lookback(365)
    assert _rc == 7
}
if _rc == 0 {
    display as result "  PASS: Error — date() with string variable"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — date() with string variable (error `=_rc')"
    local ++fail_count
}

**## Error — refdate() with string variable
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(dx1) lookback(365)
    assert _rc == 7
}
if _rc == 0 {
    display as result "  PASS: Error — refdate() with string variable"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — refdate() with string variable (error `=_rc')"
    local ++fail_count
}

**## Error — codefile() with invalid extension
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, codefile("test.txt")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — codefile invalid extension (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — codefile invalid extension (error `=_rc')"
    local ++fail_count
}

**## Error — codefile() file not found
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, codefile("nonexistent_codescan_test.csv")
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: Error — codefile not found (rc=601)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — codefile not found (error `=_rc')"
    local ++fail_count
}

**## Error — codefile() empty file
local ++test_count
capture noisily {
    preserve
    clear
    set obs 0
    gen str32 name = ""
    gen str32 pattern = ""
    export delimited using "_cs_empty_cf.csv", replace
    restore
    _make_test_data
    capture codescan dx1-dx3, codefile("_cs_empty_cf.csv")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — codefile empty file (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — codefile empty file (error `=_rc')"
    local ++fail_count
}

**## Error — codefile() missing name column
local ++test_count
capture noisily {
    preserve
    clear
    set obs 1
    gen str32 pattern = "E11"
    gen str32 code = "dm2"
    export delimited using "_cs_no_name.csv", replace
    restore
    _make_test_data
    capture codescan dx1-dx3, codefile("_cs_no_name.csv")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — codefile missing name column (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — codefile missing name column (error `=_rc')"
    local ++fail_count
}

**## Error — codefile() missing pattern column
local ++test_count
capture noisily {
    preserve
    clear
    set obs 1
    gen str32 name = "dm2"
    gen str32 label = "Diabetes"
    export delimited using "_cs_no_pattern.csv", replace
    restore
    _make_test_data
    capture codescan dx1-dx3, codefile("_cs_no_pattern.csv")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — codefile missing pattern column (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — codefile missing pattern column (error `=_rc')"
    local ++fail_count
}

**## Error — level() out of range
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") mode(prefix) level(15)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — level(15) out of range (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — level(15) out of range (error `=_rc')"
    local ++fail_count
}

**## Error — export() invalid extension
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") export("test.txt")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — export invalid extension (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — export invalid extension (error `=_rc')"
    local ++fail_count
}

**## Error — preserve without collapse/merge
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") preserve
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — preserve without collapse (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — preserve without collapse (error `=_rc')"
    local ++fail_count
}

**## Error — frame() without collapse/merge
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") frame(myframe)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — frame without collapse (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — frame without collapse (error `=_rc')"
    local ++fail_count
}

**## Error — unmatched() variable exists without replace
local ++test_count
capture noisily {
    _make_test_data
    gen byte nomatch = 0
    capture codescan dx1-dx3, define(dm2 "E11") unmatched(nomatch)
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: Error — unmatched var exists without replace (rc=110)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — unmatched var exists without replace (error `=_rc')"
    local ++fail_count
}

**## Error — matched_code() variable exists without replace
local ++test_count
capture noisily {
    _make_test_data
    gen str10 mc = ""
    capture codescan dx1-dx3, define(dm2 "E11") matched_code(mc)
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: Error — matched_code var exists without replace (rc=110)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — matched_code var exists without replace (error `=_rc')"
    local ++fail_count
}

**## Error — matched_code() collides with generated condition name
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") matched_code(dm2)
    assert _rc == 198
    capture confirm variable dm2
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: Error — matched_code collision with condition name (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — matched_code collision with condition name (error `=_rc')"
    local ++fail_count
}

**## Error — matched_code() cannot overwrite a scan variable even with replace
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1 dx2, define(dm2 "E11") matched_code(dx1) replace
    assert _rc == 198
    assert dx1[1] == "E110"
}
if _rc == 0 {
    display as result "  PASS: Error — matched_code() rejects scan-var collision under replace"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — matched_code() scan-var collision under replace (error `=_rc')"
    local ++fail_count
}

**## Error — unmatched() cannot overwrite a scan variable even with replace
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1 dx2, define(dm2 "E11") unmatched(dx1) replace
    assert _rc == 198
    assert dx1[1] == "E110"
}
if _rc == 0 {
    display as result "  PASS: Error — unmatched() rejects scan-var collision under replace"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — unmatched() scan-var collision under replace (error `=_rc')"
    local ++fail_count
}

**## Error — derived collapse output cannot overwrite a scan variable even with replace
local ++test_count
capture noisily {
    _make_test_data
    gen str10 dm2_count = dx1
    capture codescan dx1 dm2_count, define(dm2 "E11") id(pid) date(visit_dt) ///
        collapse countdate replace
    assert _rc == 198
    assert dm2_count[1] == "E110"
}
if _rc == 0 {
    display as result "  PASS: Error — derived collapse output rejects scan-var collision under replace"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — derived collapse output scan-var collision under replace (error `=_rc')"
    local ++fail_count
}

**## Error — unmatched() cannot reuse id() name
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) merge unmatched(pid)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — unmatched() structural name collision (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — unmatched() structural collision (error `=_rc')"
    local ++fail_count
}

**## Error — zero observations after time window (error 2000)
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21000 21915
    2 "E110" 21001 21915
    end
    format visit_dt index_dt %td
    * lookback(30) from 21915 → window [21885, 21915) — no obs
    capture codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookback(30)
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: Error — zero obs after window filter (rc=2000)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — zero obs after window filter (error `=_rc')"
    local ++fail_count
}

**## Error — earliestdate without date()
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) collapse earliestdate
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — earliestdate without date (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — earliestdate without date (error `=_rc')"
    local ++fail_count
}

**## Error — condition name >26 chars
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(abcdefghijklmnopqrstuvwxyz1 "E11")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — condition name >26 chars (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — condition name >26 chars (error `=_rc')"
    local ++fail_count
}

**## Error — indicator variable exists without replace
local ++test_count
capture noisily {
    _make_test_data
    gen byte dm2 = 0
    capture codescan dx1-dx3, define(dm2 "E11")
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: Error — indicator exists without replace (rc=110)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — indicator exists without replace (error `=_rc')"
    local ++fail_count
}

**## Error — _first variable exists without replace
local ++test_count
capture noisily {
    _make_test_data
    gen double dm2_first = .
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse earliestdate
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: Error — _first exists without replace (rc=110)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — _first exists without replace (error `=_rc')"
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
_codescan_qa_publish "test_codescan_errors" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_codescan_errors tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
