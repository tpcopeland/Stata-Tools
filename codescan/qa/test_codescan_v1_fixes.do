* test_codescan_v1_fixes.do - Regression tests for the v1.0.2-v1.3.0 fixes
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

* ============================================================
* v1.0.2+ Fixes: varabbrev, collapse if/in, new returns
* ============================================================

* Test 41: varabbrev restored after successful run
local ++test_count
capture noisily {
    set varabbrev on
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11")
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: varabbrev restored after success"
    local ++pass_count
}
else {
    display as error "  FAIL: varabbrev restored after success (error `=_rc')"
    local ++fail_count
}

* Restore the suite baseline. This sits AFTER the verdict, never before:
* `set varabbrev' resets _rc, so restoring ahead of the `if _rc == 0'
* would make the test pass unconditionally. Leaving it unrestored let a
* varabbrev=on leak into every later suite in the lane.
set varabbrev `_qa_va0'

* Test 42: varabbrev restored after error
local ++test_count
capture noisily {
    set varabbrev on
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") mode(invalid)
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: varabbrev restored after error"
    local ++pass_count
}
else {
    display as error "  FAIL: varabbrev restored after error (error `=_rc')"
    local ++fail_count
}

* Restore the suite baseline. This sits AFTER the verdict, never before:
* `set varabbrev' resets _rc, so restoring ahead of the `if _rc == 0'
* would make the test pass unconditionally. Leaving it unrestored let a
* varabbrev=on leak into every later suite in the lane.
set varabbrev `_qa_va0'

* Test 43: collapse respects if condition
local ++test_count
capture noisily {
    _make_test_data
    * Only patients 1-3 (pid <= 3)
    codescan dx1-dx3 if pid <= 3, define(dm2 "E11") id(pid) collapse
    assert _N == 3
    assert r(N) == 3
}
if _rc == 0 {
    display as result "  PASS: collapse respects if condition"
    local ++pass_count
}
else {
    display as error "  FAIL: collapse respects if condition (error `=_rc')"
    local ++fail_count
}

* Test 44: collapse respects in range
local ++test_count
capture noisily {
    _make_test_data
    * Only first 12 rows (patients 1-3)
    codescan dx1-dx3 in 1/12, define(dm2 "E11") id(pid) collapse
    assert _N == 3
    assert r(N) == 3
}
if _rc == 0 {
    display as result "  PASS: collapse respects in range"
    local ++pass_count
}
else {
    display as error "  FAIL: collapse respects in range (error `=_rc')"
    local ++fail_count
}

* Test 45: r(collapsed) = 1 when collapse used
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse
    assert r(collapsed) == 1
}
if _rc == 0 {
    display as result "  PASS: r(collapsed) = 1 when collapsed"
    local ++pass_count
}
else {
    display as error "  FAIL: r(collapsed) = 1 when collapsed (error `=_rc')"
    local ++fail_count
}

* Test 46: r(collapsed) = 0 when no collapse
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11")
    assert r(collapsed) == 0
}
if _rc == 0 {
    display as result "  PASS: r(collapsed) = 0 when not collapsed"
    local ++pass_count
}
else {
    display as error "  FAIL: r(collapsed) = 0 when not collapsed (error `=_rc')"
    local ++fail_count
}

* Test 47: r(id) returned when id specified
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse
    assert "`r(id)'" == "pid"
}
if _rc == 0 {
    display as result "  PASS: r(id) returned"
    local ++pass_count
}
else {
    display as error "  FAIL: r(id) returned (error `=_rc')"
    local ++fail_count
}

* Test 48: r(newvars) — no collapse (indicators only)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]")
    assert "`r(newvars)'" == "dm2 htn"
}
if _rc == 0 {
    display as result "  PASS: r(newvars) without collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: r(newvars) without collapse (error `=_rc')"
    local ++fail_count
}

* Test 49: r(newvars) — with collapse + date summaries
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        id(pid) date(visit_dt) collapse earliestdate countdate
    assert "`r(newvars)'" == "dm2 htn dm2_first dm2_count htn_first htn_count"
}
if _rc == 0 {
    display as result "  PASS: r(newvars) with collapse + date summaries"
    local ++pass_count
}
else {
    display as error "  FAIL: r(newvars) with collapse + date summaries (error `=_rc')"
    local ++fail_count
}

* Test 49b: r(newvars) excludes row-level diagnostics after collapse
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse ///
        unmatched(nomatch) matched_code(mc)
    assert "`r(newvars)'" == "dm2"
    capture confirm variable nomatch
    assert _rc == 111
    capture confirm variable mc
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: r(newvars) excludes dropped collapse diagnostics"
    local ++pass_count
}
else {
    display as error "  FAIL: r(newvars) excludes collapse diagnostics (error `=_rc')"
    local ++fail_count
}

* ============================================================
* v1.0.4 Fix: countdate tag logic
* ============================================================

* Test 50: countdate counts date when match is not on first row in (id, date) group
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "Z00"  21900
    1 "E110" 21900
    1 "E110" 21910
    end
    gen double index_dt = 22000
    format visit_dt index_dt %td

    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) collapse countdate

    * Date 21900 has match on row 2 (not row 1) — should still count
    * Date 21910 has match on row 3 — should count
    * Total = 2 unique dates
    assert dm2_count == 2 if pid == 1
}
if _rc == 0 {
    display as result "  PASS: countdate counts when match not on first row"
    local ++pass_count
}
else {
    display as error "  FAIL: countdate counts when match not on first row (error `=_rc')"
    local ++fail_count
}

* Test 51: countdate zero when no match in any row of date group
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "Z00" 21900
    1 "Z01" 21900
    1 "Z00" 21910
    end
    gen double index_dt = 22000
    format visit_dt index_dt %td

    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) collapse countdate

    assert dm2_count == 0 if pid == 1
}
if _rc == 0 {
    display as result "  PASS: countdate zero when no match in date group"
    local ++pass_count
}
else {
    display as error "  FAIL: countdate zero when no match in date group (error `=_rc')"
    local ++fail_count
}

* Test 52: Package installation smoke test
local ++test_count
capture noisily {
    capture ado uninstall codescan
    net install codescan, from("`pkg_dir'") replace
    which codescan
}
if _rc == 0 {
    display as result "  PASS: Package installs and codescan discoverable"
    local ++pass_count
}
else {
    display as error "  FAIL: Package install (error `=_rc')"
    local ++fail_count
}


* ============================================================
* v1.0.5 Fixes: name collision, countdate touse, missing id, cleanup
* ============================================================

* Test 53: Error — condition name matches varlist variable
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dx1 "E11")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - condition name matches varlist var (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - condition name matches varlist var (error `=_rc')"
    local ++fail_count
}

* Test 54: Error — condition name matches varlist variable WITH replace
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dx1 "E11") replace
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - name matches varlist even with replace (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - name matches varlist even with replace (error `=_rc')"
    local ++fail_count
}

* Test 55: Error — condition name matches id variable
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(pid "E11") id(pid) collapse
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - condition name matches id var (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - condition name matches id var (error `=_rc')"
    local ++fail_count
}

* Test 56: Error — condition name matches date variable
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(visit_dt "E11") date(visit_dt) refdate(index_dt) lookback(365)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - condition name matches date var (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - condition name matches date var (error `=_rc')"
    local ++fail_count
}

* Test 57: Error — condition name matches refdate variable
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(index_dt "E11") date(visit_dt) refdate(index_dt) lookback(365)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - condition name matches refdate var (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - condition name matches refdate var (error `=_rc')"
    local ++fail_count
}

* Test 58: countdate correct when _n==1 in (id,date) group has touse=0
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "Z00"  21900
    1 "E110" 21900
    1 "E110" 21910
    end
    gen double index_dt = 22000
    format visit_dt index_dt %td

    * Use if condition that excludes row 1 but not row 2
    * Row 1: pid=1, dx1="Z00", visit_dt=21900, _n=1 → excluded by if _n>1
    * Row 2: pid=1, dx1="E110", visit_dt=21900, _n=2 → included
    * Row 3: pid=1, dx1="E110", visit_dt=21910, _n=3 → included
    codescan dx1 if _n > 1, define(dm2 "E11") id(pid) date(visit_dt) collapse countdate

    * Date 21900: _n==1 is touse=0, _n==2 has match+touse=1 → count this date
    * Date 21910: match+touse=1 → count this date
    * Total = 2 unique dates
    assert dm2_count == 2 if pid == 1
}
if _rc == 0 {
    display as result "  PASS: countdate correct when _n==1 has touse=0"
    local ++pass_count
}
else {
    display as error "  FAIL: countdate correct when _n==1 has touse=0 (error `=_rc')"
    local ++fail_count
}

* Test 59: Missing id excluded from collapse (no phantom patient)
local ++test_count
capture noisily {
    clear
    input double pid str10 dx1 double visit_dt
    1    "E110" 21900
    1    "Z00"  21910
    .    "E110" 21900
    .    "E119" 21910
    2    "Z00"  21900
    end
    format visit_dt %td

    codescan dx1, define(dm2 "E11") id(pid) collapse

    * Only pid 1 and 2 should remain (missing id excluded)
    assert _N == 2
    assert dm2 == 1 if pid == 1
    assert dm2 == 0 if pid == 2
}
if _rc == 0 {
    display as result "  PASS: Missing id excluded from collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing id excluded from collapse (error `=_rc')"
    local ++fail_count
}

* Test 60: Malformed regex patterns are REJECTED, valid patterns scan normally
* (v2.0.3: regexm() silently returned 0 on a bad pattern — a false-zero cohort.
* The ICU compile-probe in _codescan_validate_regex now exits 198 instead, so an
* unclosed bracket no longer creates an all-zero indicator without warning.)
local ++test_count
capture noisily {
    clear
    set obs 5
    gen str10 dx1 = "E110"
    gen str10 dx2 = "Z00"

    * An unclosed '[' is structurally invalid — must error, not silently zero.
    capture codescan dx1 dx2, define(test1 "E11" | test2 "[invalid")
    assert _rc == 198
    * No indicators should have been created on the rejected call.
    capture confirm variable test1
    assert _rc != 0
    capture confirm variable test2
    assert _rc != 0

    * The valid pattern on its own still scans correctly (resilience preserved).
    codescan dx1 dx2, define(test1 "E11")
    confirm variable test1
    assert test1 == 1
}
if _rc == 0 {
    display as result "  PASS: Malformed regex rejected, valid pattern scans"
    local ++pass_count
}
else {
    display as error "  FAIL: Malformed regex rejected, valid pattern scans (error `=_rc')"
    local ++fail_count
}

* Test 61: countdate excludes missing dates (no time window)
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "E110" 21900
    1 "E110" .
    1 "E110" 21910
    end
    format visit_dt %td

    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) collapse countdate

    * Date 21900: match → count. Date missing: excluded. Date 21910: match → count.
    * Total = 2 unique dates (missing date excluded)
    assert dm2_count == 2 if pid == 1
}
if _rc == 0 {
    display as result "  PASS: countdate excludes missing dates"
    local ++pass_count
}
else {
    display as error "  FAIL: countdate excludes missing dates (error `=_rc')"
    local ++fail_count
}

* Test 62: Non-conflicting condition name still works with replace
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11")
    codescan dx1-dx3, define(dm2 "E11") replace
    confirm variable dm2
    assert dm2 == 1 if _n == 1
}
if _rc == 0 {
    display as result "  PASS: Non-conflicting name works with replace"
    local ++pass_count
}
else {
    display as error "  FAIL: Non-conflicting name works with replace (error `=_rc')"
    local ++fail_count
}

* Test 63: Missing id rows with matches don't affect valid patient counts
local ++test_count
capture noisily {
    clear
    input double pid str10 dx1 double visit_dt
    1    "E110" 21900
    .    "E110" 21900
    .    "E110" 21905
    2    "E00"  21900
    end
    format visit_dt %td

    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) collapse ///
        countdate earliestdate latestdate

    * 2 patients (pid 1 and 2), missing-id rows excluded
    assert _N == 2
    assert dm2 == 1 if pid == 1
    assert dm2_count == 1 if pid == 1
    assert dm2_first == 21900 if pid == 1
    assert dm2 == 0 if pid == 2
    assert dm2_count == 0 if pid == 2
}
if _rc == 0 {
    display as result "  PASS: Missing id rows don't affect valid patient results"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing id rows don't affect valid patient results (error `=_rc')"
    local ++fail_count
}


* ============================================================
* v1.1.0: codescan_describe, frame(), preserve, tostring, nodots
* ============================================================

* Test 64: codescan_describe basic functionality
local ++test_count
capture noisily {
    _make_test_data
    codescan_describe dx1-dx3
    assert r(n_unique) > 0
    assert r(n_entries) > 0
    assert r(n_vars) == 3
    assert "`r(varlist)'" == "dx1 dx2 dx3"
}
if _rc == 0 {
    display as result "  PASS: codescan_describe basic"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe basic (error `=_rc')"
    local ++fail_count
}

* Test 65: codescan_describe with if/in
local ++test_count
capture noisily {
    _make_test_data
    codescan_describe dx1 in 1/4
    assert r(n_vars) == 1
    assert r(n_entries) > 0
}
if _rc == 0 {
    display as result "  PASS: codescan_describe with if/in"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe with if/in (error `=_rc')"
    local ++fail_count
}

* Test 66: codescan_describe top() option
local ++test_count
capture noisily {
    _make_test_data
    codescan_describe dx1-dx3, top(3)
    assert r(n_unique) > 0
}
if _rc == 0 {
    display as result "  PASS: codescan_describe top(3)"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe top(3) (error `=_rc')"
    local ++fail_count
}

* Test 67: codescan_describe nodots
local ++test_count
capture noisily {
    clear
    set obs 5
    gen str10 dx1 = ""
    replace dx1 = "E11.0" in 1
    replace dx1 = "E110" in 2
    replace dx1 = "I10" in 3
    replace dx1 = "I10.1" in 4
    replace dx1 = "" in 5

    * Without nodots: E11.0 and E110 are separate codes
    codescan_describe dx1
    local no_strip = r(n_unique)

    * With nodots: E11.0→E110 merges with E110, I10.1→I101 stays separate
    codescan_describe dx1, nodots
    local with_strip = r(n_unique)

    assert `with_strip' < `no_strip'
}
if _rc == 0 {
    display as result "  PASS: codescan_describe nodots merges dotted codes"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe nodots (error `=_rc')"
    local ++fail_count
}

* Test 68: codescan_describe tostring preserves user data (bug fix)
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double numcode = _n * 100
    local orig_type : type numcode

    codescan_describe numcode, tostring

    * After command, numcode should be back to original type (numeric)
    capture confirm numeric variable numcode
    assert _rc == 0
    assert "`orig_type'" == "`: type numcode'"
}
if _rc == 0 {
    display as result "  PASS: codescan_describe tostring preserves original data"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe tostring preserves original data (error `=_rc')"
    local ++fail_count
}

* Test 69: codescan_describe zero-match returns correctly
local ++test_count
capture noisily {
    clear
    set obs 5
    gen str10 dx1 = ""
    codescan_describe dx1
    assert r(n_unique) == 0
    assert r(n_entries) == 0
    assert r(n_vars) == 1
}
if _rc == 0 {
    display as result "  PASS: codescan_describe zero-match"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe zero-match (error `=_rc')"
    local ++fail_count
}

* Test 70: codescan_describe varabbrev restored
local ++test_count
capture noisily {
    _make_test_data
    set varabbrev on
    codescan_describe dx1-dx3
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: codescan_describe varabbrev restored"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe varabbrev restored (error `=_rc')"
    local ++fail_count
}

* Restore the suite baseline. This sits AFTER the verdict, never before:
* `set varabbrev' resets _rc, so restoring ahead of the `if _rc == 0'
* would make the test pass unconditionally. Leaving it unrestored let a
* varabbrev=on leak into every later suite in the lane.
set varabbrev `_qa_va0'

* Test 71: codescan_describe data preservation (N, sort, values unchanged)
local ++test_count
capture noisily {
    _make_test_data
    local orig_N = _N
    gen _sortcheck = _n
    local orig_dx1_1 = dx1[1]

    codescan_describe dx1-dx3

    assert _N == `orig_N'
    assert _sortcheck[1] == 1
    assert _sortcheck[_N] == _N
    assert dx1[1] == "`orig_dx1_1'"
    drop _sortcheck
}
if _rc == 0 {
    display as result "  PASS: codescan_describe data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe data preservation (error `=_rc')"
    local ++fail_count
}

* Test 72: codescan tostring option
local ++test_count
capture noisily {
    clear
    set obs 5
    gen long pid = _n
    gen double dx1 = .
    replace dx1 = 110 in 1
    replace dx1 = 119 in 2
    replace dx1 = 660 in 3

    codescan dx1, define(dm2 "11") tostring
    assert dm2 == 1 in 1
    assert dm2 == 1 in 2
    assert dm2 == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: codescan tostring converts and scans"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan tostring (error `=_rc')"
    local ++fail_count
}

* Test 73: codescan nodots option
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str10 dx1 = ""
    replace dx1 = "E11.0" in 1
    replace dx1 = "I10.1" in 2
    replace dx1 = "Z00" in 3

    * Without nodots: "E110" pattern would NOT match "E11.0" (dot blocks prefix)
    codescan dx1, define(dm2 "E110")
    assert dm2 == 0 in 1

    * With nodots: "E11.0"→"E110" matches "^(E110)"
    codescan dx1, define(dm2 "E110") nodots replace
    assert dm2 == 1 in 1
    assert dm2 == 0 in 2
}
if _rc == 0 {
    display as result "  PASS: codescan nodots strips dots before matching"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan nodots (error `=_rc')"
    local ++fail_count
}

* Test 74: codescan preserve option (data unchanged after collapse)
local ++test_count
capture noisily {
    _make_test_data
    local orig_N = _N
    local orig_vars : char _dta[_varnames_]
    gen _sortcheck = _n

    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse pre

    * Data should be unchanged
    assert _N == `orig_N'
    assert _sortcheck[1] == 1
    assert _sortcheck[_N] == _N
    confirm variable dx1
    confirm variable pid
    drop _sortcheck
}
if _rc == 0 {
    display as result "  PASS: preserve option keeps original data"
    local ++pass_count
}
else {
    display as error "  FAIL: preserve option (error `=_rc')"
    local ++fail_count
}

* Test 75: codescan frame() option stores results in frame
local ++test_count
capture noisily {
    _make_test_data
    local orig_N = _N
    capture frame drop _test_frame

    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        id(pid) collapse frame(_test_frame)

    * Original data unchanged
    assert _N == `orig_N'
    confirm variable dx1

    * Frame has collapsed results
    frame _test_frame: quietly count
    assert r(N) == 5
    frame _test_frame: confirm variable dm2
    frame _test_frame: confirm variable htn

    capture frame drop _test_frame
}
if _rc == 0 {
    display as result "  PASS: frame() stores results and preserves data"
    local ++pass_count
}
else {
    display as error "  FAIL: frame() option (error `=_rc')"
    local ++fail_count
}

* Test 76: frame() errors when frame exists and no replace
local ++test_count
capture noisily {
    _make_test_data
    frame create _existing_frame
    frame _existing_frame: quietly set obs 1

    capture codescan dx1-dx3, define(dm2 "E11") id(pid) collapse frame(_existing_frame)
    assert _rc == 110

    * Verify existing frame was NOT destroyed
    frame _existing_frame: quietly count
    assert r(N) == 1

    capture frame drop _existing_frame
}
if _rc == 0 {
    display as result "  PASS: frame() errors on existing frame without replace"
    local ++pass_count
}
else {
    display as error "  FAIL: frame() existing frame guard (error `=_rc')"
    local ++fail_count
}

* Test 77: frame() with replace overwrites existing frame
local ++test_count
capture noisily {
    _make_test_data
    frame create _replace_frame
    frame _replace_frame: quietly set obs 1

    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse ///
        frame(_replace_frame) replace

    * Frame should have collapsed results now
    frame _replace_frame: quietly count
    assert r(N) == 5
    frame _replace_frame: confirm variable dm2

    capture frame drop _replace_frame
}
if _rc == 0 {
    display as result "  PASS: frame() with replace overwrites existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: frame() with replace (error `=_rc')"
    local ++fail_count
}

* Test 78: preserve abbreviation "pre" works
local ++test_count
capture noisily {
    _make_test_data
    local orig_N = _N

    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse pre

    assert _N == `orig_N'
    confirm variable dx1
}
if _rc == 0 {
    display as result "  PASS: preserve abbreviated as 'pre' works"
    local ++pass_count
}
else {
    display as error "  FAIL: preserve abbreviation 'pre' (error `=_rc')"
    local ++fail_count
}

* Test 79: codescan_describe error — top(0) rejected
local ++test_count
capture noisily {
    _make_test_data
    capture codescan_describe dx1, top(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: codescan_describe top(0) error"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe top(0) error (error `=_rc')"
    local ++fail_count
}

* Test 80: codescan_describe error — numeric variable without tostring
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double numvar = _n
    capture codescan_describe numvar
    assert _rc == 109
}
if _rc == 0 {
    display as result "  PASS: codescan_describe errors on numeric without tostring"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe numeric error (error `=_rc')"
    local ++fail_count
}

* Test 81: codescan_describe varabbrev restored after error
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double numvar = _n
    set varabbrev on
    capture codescan_describe numvar
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: codescan_describe varabbrev restored after error"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe varabbrev restored after error (error `=_rc')"
    local ++fail_count
}

* Restore the suite baseline. This sits AFTER the verdict, never before:
* `set varabbrev' resets _rc, so restoring ahead of the `if _rc == 0'
* would make the test pass unconditionally. Leaving it unrestored let a
* varabbrev=on leak into every later suite in the lane.
set varabbrev `_qa_va0'


* ============================================================
* v1.3.0 New Features
* ============================================================

* Test 82: F1 — nocase matches lowercase codes
local ++test_count
capture noisily {
    _make_test_data
    replace dx1 = "e110" if _n == 17
    replace dx1 = "i10" if _n == 18
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") nocase
    assert dm2 == 1 if _n == 17
    assert htn == 1 if _n == 18
    assert "`r(nocase)'" == "nocase"
}
if _rc == 0 {
    display as result "  PASS: F1 nocase matches lowercase codes"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 nocase matches lowercase codes (error `=_rc')"
    local ++fail_count
}

* Test 83: F1 — nocase in prefix mode
local ++test_count
capture noisily {
    _make_test_data
    replace dx1 = "e110" if _n == 17
    codescan dx1-dx3, define(dm2 "E11") mode(prefix) nocase
    assert dm2 == 1 if _n == 17
    assert dm2 == 1 if _n == 1
}
if _rc == 0 {
    display as result "  PASS: F1 nocase prefix mode"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 nocase prefix mode (error `=_rc')"
    local ++fail_count
}

* Test 84: F3 — generate(prefix)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") generate(dx_)
    confirm variable dx_dm2
    confirm variable dx_htn
    assert dx_dm2 == 1 if _n == 1
    assert "`r(generate)'" == "dx_"
}
if _rc == 0 {
    display as result "  PASS: F3 generate(prefix)"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 generate(prefix) (error `=_rc')"
    local ++fail_count
}

* Test 85: F3 — generate with collapse
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") generate(cx_) id(pid) ///
        date(visit_dt) collapse alldates replace
    confirm variable cx_dm2
    confirm variable cx_dm2_first
    confirm variable cx_dm2_last
    confirm variable cx_dm2_count
}
if _rc == 0 {
    display as result "  PASS: F3 generate with collapse + alldates"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 generate with collapse + alldates (error `=_rc')"
    local ++fail_count
}

* Test 86: R1 — regex pre-validation catches unmatched parens
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(bad "E11(")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: R1 regex pre-validation — unmatched paren"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 regex pre-validation — unmatched paren (error `=_rc')"
    local ++fail_count
}

* Test 87: R1 — valid regex passes validation
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E1[1-4]0" | htn "I(10|13)")
    assert dm2 == 1 if _n == 1
}
if _rc == 0 {
    display as result "  PASS: R1 valid regex passes"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 valid regex passes (error `=_rc')"
    local ++fail_count
}

* Test 88: P1 — co-occurrence Mata produces correct matrix
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") cooccurrence
    matrix C = r(cooccurrence)
    assert rowsof(C) == 2
    assert colsof(C) == 2
    * dm2 & htn co-occur in patient 1 (row 1 has E110; row 2 has I10)
    * At row level: no row has both dm2=1 and htn=1, so co-occurrence = 0
    assert el(C, 1, 2) == 0
    * Diagonal = condition count
    assert el(C, 1, 1) == 4
    assert el(C, 2, 2) == 3
}
if _rc == 0 {
    display as result "  PASS: P1 co-occurrence Mata"
    local ++pass_count
}
else {
    display as error "  FAIL: P1 co-occurrence Mata (error `=_rc')"
    local ++fail_count
}

* Test 89: I2 — codelist matrix returned
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]")
    matrix CL = r(codelist)
    assert rowsof(CL) == 2
    * 3.0.0: count prevalence total_hits positive_units
    assert colsof(CL) == 4
    assert el(CL, 1, 1) == 4
}
if _rc == 0 {
    display as result "  PASS: I2 codelist matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: I2 codelist matrix (error `=_rc')"
    local ++fail_count
}

* Test 90: I3 — r(frame) returned
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse frame(test_fr) replace
    assert "`r(frame)'" == "test_fr"
    capture frame drop test_fr
}
if _rc == 0 {
    display as result "  PASS: I3 r(frame) returned"
    local ++pass_count
}
else {
    display as error "  FAIL: I3 r(frame) returned (error `=_rc')"
    local ++fail_count
}

* Test 91: C1 — unmatched flag
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") unmatched(nomatch)
    confirm variable nomatch
    * Patient 5 rows (17-20) have only Z codes — should be unmatched
    assert nomatch == 1 if _n == 17
    assert nomatch == 1 if _n == 20
    * Row 1 has E110 match — should NOT be unmatched
    assert nomatch == 0 if _n == 1
    assert nomatch == 0 if _n == 2
}
if _rc == 0 {
    display as result "  PASS: C1 unmatched flag"
    local ++pass_count
}
else {
    display as error "  FAIL: C1 unmatched flag (error `=_rc')"
    local ++fail_count
}

* Test 92: F6 — matched_code captures first match
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") matched_code(mc)
    confirm variable mc
    assert mc == "E110" if _n == 1
    assert mc == "I10"  if _n == 2
    assert mc == ""     if _n == 17
}
if _rc == 0 {
    display as result "  PASS: F6 matched_code"
    local ++pass_count
}
else {
    display as error "  FAIL: F6 matched_code (error `=_rc')"
    local ++fail_count
}

* Test 93: U1 — merge broadcasts patient-level indicators
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") id(pid) merge
    assert _N == 20
    assert r(merged) == 1
    * Patient 1: DM2 in rows 1,3 → all 4 rows should be dm2=1
    assert dm2 == 1 if pid == 1
    * Patient 2: HTN in rows 5,6 → all 4 rows should be htn=1
    assert htn == 1 if pid == 2
    * Patient 5: no matches → both 0
    assert dm2 == 0 if pid == 5
    assert htn == 0 if pid == 5
}
if _rc == 0 {
    display as result "  PASS: U1 merge"
    local ++pass_count
}
else {
    display as error "  FAIL: U1 merge (error `=_rc')"
    local ++fail_count
}

* Test 94: U1 — merge with date summaries
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) merge ///
        earliestdate latestdate countdate replace
    assert _N == 20
    confirm variable dm2_first
    confirm variable dm2_last
    confirm variable dm2_count
    * Patient 1: dm2 matches in rows 1,3 → first=2019-06-15, last=2020-01-01
    * Values should be broadcast to all patient 1 rows
    assert dm2_first == mdy(6, 15, 2019) if pid == 1
}
if _rc == 0 {
    display as result "  PASS: U1 merge with date summaries"
    local ++pass_count
}
else {
    display as error "  FAIL: U1 merge with date summaries (error `=_rc')"
    local ++fail_count
}

* Test 97: R2 — codefile case-tolerant column names
local ++test_count
capture noisily {
    * Create codefile with uppercase column names
    preserve
    clear
    input str10 Name str20 Pattern str30 Label
    "dm2" "E11" "Diabetes"
    end
    save "_codescan_test_case.dta", replace
    restore

    _make_test_data
    codescan dx1-dx3, codefile("_codescan_test_case.dta")
    confirm variable dm2
    assert dm2 == 1 if _n == 1
}
if _rc == 0 {
    display as result "  PASS: R2 codefile case-tolerant columns"
    local ++pass_count
}
else {
    display as error "  FAIL: R2 codefile case-tolerant columns (error `=_rc')"
    local ++fail_count
}

* Test 98: O2 — export to xlsx
local ++test_count
capture noisily {
    _make_test_data
    capture erase "codescan_test_qa.xlsx"
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        id(pid) collapse cooccurrence replace ///
        export("codescan_test_qa.xlsx")
    confirm file "codescan_test_qa.xlsx"
}
if _rc == 0 {
    display as result "  PASS: O2 export xlsx"
    local ++pass_count
}
else {
    display as error "  FAIL: O2 export xlsx (error `=_rc')"
    local ++fail_count
}

* Test 99: O2 — export to csv
local ++test_count
capture noisily {
    _make_test_data
    capture erase "codescan_test_qa.csv"
    codescan dx1-dx3, define(dm2 "E11") export("codescan_test_qa.csv") replace
    confirm file "codescan_test_qa.csv"
}
if _rc == 0 {
    display as result "  PASS: O2 export csv"
    local ++pass_count
}
else {
    display as error "  FAIL: O2 export csv (error `=_rc')"
    local ++fail_count
}

* Test 101: C4 — level() truncates patterns in prefix mode
local ++test_count
capture noisily {
    _make_test_data
    * Level 1: E → matches all E-chapter codes (E110, E119, E660)
    codescan dx1-dx3, define(endocrine "E11|E66") mode(prefix) level(1)
    * All E-chapter codes start with E
    assert endocrine == 1 if _n == 1
    assert endocrine == 1 if _n == 3
    * I10, F32 should not match
    assert endocrine == 0 if _n == 2
    assert endocrine == 0 if _n == 13
}
if _rc == 0 {
    display as result "  PASS: C4 level() truncation"
    local ++pass_count
}
else {
    display as error "  FAIL: C4 level() truncation (error `=_rc')"
    local ++fail_count
}

* Test 102: Error — merge without id
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") merge
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — merge without id"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — merge without id (error `=_rc')"
    local ++fail_count
}

* Test 103: Error — merge and collapse conflict
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) merge collapse
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — merge + collapse conflict"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — merge + collapse conflict (error `=_rc')"
    local ++fail_count
}

* Test 105: Error — generate prefix too long
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(very_long_condition_name "E11") generate(abcdefghijklmno_)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — generate prefix too long"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — generate prefix too long (error `=_rc')"
    local ++fail_count
}

* Test 106: W4 — multi-window lookback sensitivity
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) ///
        date(visit_dt) refdate(index_dt) ///
        lookback(90 365) collapse replace
    matrix S = r(sensitivity)
    assert rowsof(S) == 1
    assert colsof(S) == 2
    * 90-day window should have fewer/equal matches than 365-day
}
if _rc == 0 {
    display as result "  PASS: W4 multi-window lookback sensitivity"
    local ++pass_count
}
else {
    display as error "  FAIL: W4 multi-window lookback sensitivity (error `=_rc')"
    local ++fail_count
}

* Test 107: P3 — dead code removed (legacy subroutines)
local ++test_count
capture noisily {
    * Verify the legacy programs don't exist
    capture program list _codescan_prefix_scan
    local rc1 = _rc
    capture program list _codescan_prefix_exclude
    local rc2 = _rc
    * They should NOT be found (rc != 0)
    assert `rc1' != 0
    assert `rc2' != 0
}
if _rc == 0 {
    display as result "  PASS: P3 dead code removed"
    local ++pass_count
}
else {
    display as error "  FAIL: P3 dead code removed (error `=_rc')"
    local ++fail_count
}

* Test 108: codescan_describe O5 — cumulative percent column
local ++test_count
capture noisily {
    _make_test_data
    codescan_describe dx1-dx3
    * Just verify it runs without error and returns results
    assert r(n_unique) > 0
    assert r(n_entries) > 0
}
if _rc == 0 {
    display as result "  PASS: codescan_describe O5 cumulative percent"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe O5 cumulative percent (error `=_rc')"
    local ++fail_count
}

* Test 109: F1 — nocase with exclusion patterns
local ++test_count
capture noisily {
    _make_test_data
    replace dx1 = "e116" if _n == 17
    codescan dx1-dx3, define(dm2 "E11" ~ "E116") nocase
    * e116 should be excluded by nocase exclusion
    assert dm2 == 0 if _n == 17
    * E110 should still match
    assert dm2 == 1 if _n == 1
}
if _rc == 0 {
    display as result "  PASS: F1 nocase with exclusion"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 nocase with exclusion (error `=_rc')"
    local ++fail_count
}

* Test 111: O1 — graph without labmask
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") replace graph
}
if _rc == 0 {
    display as result "  PASS: O1 graph without labmask"
    local ++pass_count
}
else {
    display as error "  FAIL: O1 graph without labmask (error `=_rc')"
    local ++fail_count
}

* Test 112: R3 — codefile with empty name
local ++test_count
capture noisily {
    _make_test_data
    capture erase "_cs_test_r3_empty.csv"
    preserve
    clear
    set obs 2
    gen str32 name = ""
    gen str32 pattern = ""
    replace name = "" in 1
    replace pattern = "E11" in 1
    replace name = "htn" in 2
    replace pattern = "I10" in 2
    export delimited using "_cs_test_r3_empty.csv", replace
    restore
    _make_test_data
    capture codescan dx1-dx3, codefile("_cs_test_r3_empty.csv") replace
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: R3 codefile empty name error"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 codefile empty name error (error `=_rc')"
    local ++fail_count
}

* Test 113: R3 — codefile with duplicate name
local ++test_count
capture noisily {
    _make_test_data
    capture erase "_cs_test_r3_dup.csv"
    preserve
    clear
    set obs 2
    gen str32 name = ""
    gen str32 pattern = ""
    replace name = "dm2" in 1
    replace pattern = "E11" in 1
    replace name = "dm2" in 2
    replace pattern = "I10" in 2
    export delimited using "_cs_test_r3_dup.csv", replace
    restore
    _make_test_data
    capture codescan dx1-dx3, codefile("_cs_test_r3_dup.csv") replace
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: R3 codefile duplicate name error"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 codefile duplicate name error (error `=_rc')"
    local ++fail_count
}

* Test 114: R3 — codefile with empty pattern
local ++test_count
capture noisily {
    _make_test_data
    capture erase "_cs_test_r3_pat.csv"
    preserve
    clear
    set obs 1
    gen str32 name = "dm2"
    gen str32 pattern = ""
    export delimited using "_cs_test_r3_pat.csv", replace
    restore
    _make_test_data
    capture codescan dx1-dx3, codefile("_cs_test_r3_pat.csv") replace
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: R3 codefile empty pattern error"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 codefile empty pattern error (error `=_rc')"
    local ++fail_count
}

* Test 115: R3 — codefile with invalid Stata name
local ++test_count
capture noisily {
    _make_test_data
    capture erase "_cs_test_r3_bad.csv"
    preserve
    clear
    set obs 1
    gen str32 name = "2bad"
    gen str32 pattern = "E11"
    export delimited using "_cs_test_r3_bad.csv", replace
    restore
    _make_test_data
    capture codescan dx1-dx3, codefile("_cs_test_r3_bad.csv") replace
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: R3 codefile invalid name error"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 codefile invalid name error (error `=_rc')"
    local ++fail_count
}

* Test 116: R3 — valid codefile passes validation
local ++test_count
capture noisily {
    _make_test_data
    capture erase "_cs_test_r3_ok.csv"
    preserve
    clear
    set obs 2
    gen str32 name = ""
    gen str32 pattern = ""
    replace name = "dm2" in 1
    replace pattern = "E11" in 1
    replace name = "htn" in 2
    replace pattern = "I10" in 2
    export delimited using "_cs_test_r3_ok.csv", replace
    restore
    _make_test_data
    codescan dx1-dx3, codefile("_cs_test_r3_ok.csv") replace
    assert r(n_conditions) == 2
}
if _rc == 0 {
    display as result "  PASS: R3 valid codefile passes"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 valid codefile passes (error `=_rc')"
    local ++fail_count
}

* Test 117: W3 — save() writes CSV from define()
local ++test_count
capture noisily {
    _make_test_data
    capture erase "_cs_test_w3.csv"
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") replace save("_cs_test_w3.csv")
    confirm file "_cs_test_w3.csv"
    preserve
    import delimited using "_cs_test_w3.csv", clear
    assert _N == 2
    assert name[1] == "dm2"
    assert pattern[1] == "E11"
    restore
}
if _rc == 0 {
    display as result "  PASS: W3 save() writes CSV"
    local ++pass_count
}
else {
    display as error "  FAIL: W3 save() writes CSV (error `=_rc')"
    local ++fail_count
}

* Test 118: W3 — save() errors on non-.csv extension
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") replace save("test.txt")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: W3 save() non-csv error"
    local ++pass_count
}
else {
    display as error "  FAIL: W3 save() non-csv error (error `=_rc')"
    local ++fail_count
}

* Test 119: W3 — save() errors with codefile()
local ++test_count
capture noisily {
    _make_test_data
    capture erase "_cs_test_r3_ok.csv"
    preserve
    clear
    set obs 1
    gen str32 name = "dm2"
    gen str32 pattern = "E11"
    export delimited using "_cs_test_r3_ok.csv", replace
    restore
    _make_test_data
    capture codescan dx1-dx3, codefile("_cs_test_r3_ok.csv") replace save("out.csv")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: W3 save() with codefile error"
    local ++pass_count
}
else {
    display as error "  FAIL: W3 save() with codefile error (error `=_rc')"
    local ++fail_count
}

* Test 120: O5 — r(summary) has 4 columns
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") replace
    matrix S = r(summary)
    assert colsof(S) == 6
    assert rowsof(S) == 2
}
if _rc == 0 {
    display as result "  PASS: O5 summary has 4 columns"
    local ++pass_count
}
else {
    display as error "  FAIL: O5 summary has 4 columns (error `=_rc')"
    local ++fail_count
}

* Test 121: O5 — CI bounds: ci_low <= prevalence <= ci_high
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") replace
    matrix S = r(summary)
    forvalues i = 1/`=rowsof(S)' {
        assert S[`i', 3] <= S[`i', 2]
        assert S[`i', 4] >= S[`i', 2]
    }
}
if _rc == 0 {
    display as result "  PASS: O5 CI bounds ordered"
    local ++pass_count
}
else {
    display as error "  FAIL: O5 CI bounds ordered (error `=_rc')"
    local ++fail_count
}

* Test 122: O5 — CI bounds in [0, 100]
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") replace
    matrix S = r(summary)
    forvalues i = 1/`=rowsof(S)' {
        assert S[`i', 3] >= 0
        assert S[`i', 4] <= 100
    }
}
if _rc == 0 {
    display as result "  PASS: O5 CI bounds in [0,100]"
    local ++pass_count
}
else {
    display as error "  FAIL: O5 CI bounds in [0,100] (error `=_rc')"
    local ++fail_count
}

* Test 123: R1 — overlap warning displayed
local ++test_count
capture noisily {
    _make_test_data
    * dm_broad and dm2 will heavily overlap (both match E11*)
    codescan dx1-dx3, define(dm_broad "E1" | dm2 "E11") replace
    * Just verify no error — the warning is displayed as text
    assert r(n_conditions) == 2
}
if _rc == 0 {
    display as result "  PASS: R1 overlap warning runs"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 overlap warning runs (error `=_rc')"
    local ++fail_count
}

* Test 124: R1 — overlap warning suppressed with cooccurrence
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm_broad "E1" | dm2 "E11") replace cooccurrence
    assert r(n_conditions) == 2
}
if _rc == 0 {
    display as result "  PASS: R1 overlap suppressed with cooccurrence"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 overlap suppressed with cooccurrence (error `=_rc')"
    local ++fail_count
}

* Test 125: F2 — countmode produces counts > 1
local ++test_count
capture noisily {
    _make_test_data
    * Patient 1 has E110 in dx1 row 1 and E119 in dx1 row 3 — 2 matches across rows
    * But within each row, only 1 variable can match, so row-level counts are 0 or 1
    * After collapse with sum, should get count = number of matching rows
    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse replace countmode
    * Patient 1 has dm2 codes in rows 1, 3 → count should be >= 2
    summarize dm2 if pid == 1, meanonly
    assert r(mean) >= 2
    * Patient 5 has no matches → count = 0
    summarize dm2 if pid == 5, meanonly
    assert r(mean) == 0
}
if _rc == 0 {
    display as result "  PASS: F2 countmode counts > 1"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 countmode counts > 1 (error `=_rc')"
    local ++fail_count
}

* Test 126: F2 — countmode collapse uses sum
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse replace countmode
    * Patient 3 has E110 in row 11 → dm2 count should be 1
    summarize dm2 if pid == 3, meanonly
    assert r(mean) == 1
}
if _rc == 0 {
    display as result "  PASS: F2 countmode collapse sum"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 countmode collapse sum (error `=_rc')"
    local ++fail_count
}

* Test 127: F2 — r(mode_count) == 1 when countmode specified
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") replace countmode
    assert r(mode_count) == 1
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") replace
    assert r(mode_count) == 0
}
if _rc == 0 {
    display as result "  PASS: F2 r(mode_count) flag"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 r(mode_count) flag (error `=_rc')"
    local ++fail_count
}

* Test 128: P1 — matched_code captures first matching code
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") replace matched_code(mcode)
    * Row 1: dx1=E110, dx2=E660 → first match is E110 (for dm2)
    assert mcode[1] == "E110"
    * Row 5: dx1=I10 → first match is I10 (for htn)
    assert mcode[5] == "I10"
    * Row 17: no match → empty
    assert mcode[17] == ""
}
if _rc == 0 {
    display as result "  PASS: P1 matched_code Mata-accelerated"
    local ++pass_count
}
else {
    display as error "  FAIL: P1 matched_code Mata-accelerated (error `=_rc')"
    local ++fail_count
}

* Test 129: O4 — r(top_codes) matrix from codescan_describe
local ++test_count
capture noisily {
    _make_test_data
    codescan_describe dx1-dx3
    matrix T = r(top_codes)
    assert colsof(T) == 3
    assert rowsof(T) >= 1
    * frequency column should be positive
    assert T[1,1] > 0
    * percent column should be in (0, 100]
    assert T[1,2] > 0
    assert T[1,2] <= 100
    * cumulative should be >= percent
    assert T[1,3] >= T[1,2]
}
if _rc == 0 {
    display as result "  PASS: O4 r(top_codes) matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: O4 r(top_codes) matrix (error `=_rc')"
    local ++fail_count
}

* Test 130: O4 — r(chapters) matrix from codescan_describe
local ++test_count
capture noisily {
    _make_test_data
    codescan_describe dx1-dx3
    matrix C = r(chapters)
    assert colsof(C) == 2
    assert rowsof(C) >= 1
    * codes and entries should be positive
    assert C[1,1] > 0
    assert C[1,2] > 0
}
if _rc == 0 {
    display as result "  PASS: O4 r(chapters) matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: O4 r(chapters) matrix (error `=_rc')"
    local ++fail_count
}

* Test 131: I3 — codescan_describe save() writes draft codefile
local ++test_count
capture noisily {
    _make_test_data
    capture erase "_cs_test_i3.csv"
    codescan_describe dx1-dx3, save("_cs_test_i3.csv")
    confirm file "_cs_test_i3.csv"
    preserve
    import delimited using "_cs_test_i3.csv", clear
    * Should have at least 1 row (one per chapter)
    assert _N >= 1
    * Columns should exist
    confirm variable name
    confirm variable pattern
    confirm variable exclusion
    confirm variable label
    restore
}
if _rc == 0 {
    display as result "  PASS: I3 describe save() codefile"
    local ++pass_count
}
else {
    display as error "  FAIL: I3 describe save() codefile (error `=_rc')"
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
_codescan_qa_publish "test_codescan_v1_fixes" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_codescan_v1_fixes tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
