* test_codescan_coverage.do - Consolidated coverage tests for codescan
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

**# Consolidated Tests from Expanded + Codex Fixes + New Coverage

* ============================================================
* Time Window Extended
* ============================================================

**## lookforward(0) without inclusive → rc=2000
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21914 21915
    2 "E110" 21915 21915
    3 "E110" 21916 21915
    end
    format visit_dt index_dt %td
    capture codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookforward(0)
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: lookforward(0) without inclusive (rc=2000)"
    local ++pass_count
}
else {
    display as error "  FAIL: lookforward(0) without inclusive (error `=_rc')"
    local ++fail_count
}

**## lookforward(0) with inclusive matches refdate only
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21914 21915
    2 "E110" 21915 21915
    3 "E110" 21916 21915
    end
    format visit_dt index_dt %td
    codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookforward(0) inclusive
    assert dm2 == 0 in 1
    assert dm2 == 1 in 2
    assert dm2 == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: lookforward(0) inclusive matches refdate only"
    local ++pass_count
}
else {
    display as error "  FAIL: lookforward(0) inclusive refdate only (error `=_rc')"
    local ++fail_count
}

**## Very large lookback (99999 days) accepted
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(99999)
    assert r(lookback) == 99999
}
if _rc == 0 {
    display as result "  PASS: Very large lookback(99999) accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: Very large lookback (error `=_rc')"
    local ++fail_count
}

**## Error — negative lookforward rejected
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookforward(-5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — negative lookforward rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — negative lookforward (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Date Summaries Extended
* ============================================================

**## latestdate only (without earliestdate)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(365) collapse latestdate
    confirm variable dm2_last
    capture confirm variable dm2_first
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: latestdate only (no earliestdate)"
    local ++pass_count
}
else {
    display as error "  FAIL: latestdate only (error `=_rc')"
    local ++fail_count
}

**## countdate only (without earliest/latest)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(365) collapse countdate
    confirm variable dm2_count
    capture confirm variable dm2_first
    assert _rc != 0
    capture confirm variable dm2_last
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: countdate only (no earliest/latest)"
    local ++pass_count
}
else {
    display as error "  FAIL: countdate only (error `=_rc')"
    local ++fail_count
}

**## Error — latestdate without date()
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) collapse latestdate
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — latestdate without date() (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — latestdate without date (error `=_rc')"
    local ++fail_count
}

**## Error — countdate without collapse or merge
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(365) countdate
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — countdate without collapse (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — countdate without collapse (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Label Edge Cases
* ============================================================

**## Labels with special characters (commas, parentheses)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        label(dm2 "Type 2 Diabetes (E11.x)" \ htn "Hypertension, essential")
    local lbl_dm2 : variable label dm2
    assert `"`lbl_dm2'"' == "Type 2 Diabetes (E11.x)"
    local lbl_htn : variable label htn
    assert `"`lbl_htn'"' == "Hypertension, essential"
}
if _rc == 0 {
    display as result "  PASS: Labels with special characters"
    local ++pass_count
}
else {
    display as error "  FAIL: Labels with special characters (error `=_rc')"
    local ++fail_count
}

**## Partial labels (only some conditions labeled)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]" | cvd "I2[0-5]") ///
        label(dm2 "DM2 only")
    local lbl : variable label dm2
    assert `"`lbl'"' == "DM2 only"
    local lbl2 : variable label htn
    assert `"`lbl2'"' == "htn"
}
if _rc == 0 {
    display as result "  PASS: Partial labels (some conditions only)"
    local ++pass_count
}
else {
    display as error "  FAIL: Partial labels (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Code Format Edge Cases
* ============================================================

**## Codes with dots (regex mode, escaped)
local ++test_count
capture noisily {
    clear
    set obs 4
    gen str10 dx1 = ""
    replace dx1 = "E11.0" in 1
    replace dx1 = "E110"  in 2
    replace dx1 = "E11"   in 3
    replace dx1 = "Z00"   in 4
    codescan dx1, define(dm2 "E11")
    * E11.0 starts with E11 → match, E110 → match
    assert dm2 == 1 in 1
    assert dm2 == 1 in 2
    assert dm2 == 1 in 3
    assert dm2 == 0 in 4
}
if _rc == 0 {
    display as result "  PASS: Codes with dots (regex)"
    local ++pass_count
}
else {
    display as error "  FAIL: Codes with dots regex (error `=_rc')"
    local ++fail_count
}

**## Very long code strings (str60)
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str60 code1 = ""
    replace code1 = "E110_very_long_suffix_that_extends_past_32_characters_here" in 1
    replace code1 = "Z00_something_equally_long_that_does_not_match_E11_pattern" in 2
    replace code1 = "E119" in 3
    codescan code1, define(dm2 "E11")
    assert dm2 == 1 in 1
    assert dm2 == 0 in 2
    assert dm2 == 1 in 3
}
if _rc == 0 {
    display as result "  PASS: Very long code strings (str60)"
    local ++pass_count
}
else {
    display as error "  FAIL: Very long code strings (error `=_rc')"
    local ++fail_count
}

**## Exact code match with $ anchor
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str10 dx1 = ""
    replace dx1 = "E11"  in 1
    replace dx1 = "E110" in 2
    replace dx1 = "E119" in 3
    codescan dx1, define(exact "E11$")
    assert exact == 1 in 1
    assert exact == 0 in 2
    assert exact == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: Exact code match with $ anchor"
    local ++pass_count
}
else {
    display as error "  FAIL: Exact code match $ anchor (error `=_rc')"
    local ++fail_count
}

**## Case sensitivity: E11 does NOT match e11 by default
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str10 dx1 = ""
    replace dx1 = "E11" in 1
    replace dx1 = "e11" in 2
    replace dx1 = "e110" in 3
    codescan dx1, define(dm2 "E11")
    assert dm2 == 1 in 1
    assert dm2 == 0 in 2
    assert dm2 == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: Case sensitivity (E11 != e11)"
    local ++pass_count
}
else {
    display as error "  FAIL: Case sensitivity (error `=_rc')"
    local ++fail_count
}

**## Case sensitivity in prefix mode
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str10 dx1 = ""
    replace dx1 = "E11" in 1
    replace dx1 = "e11" in 2
    replace dx1 = "e110" in 3
    codescan dx1, define(dm2 "E11") mode(prefix)
    assert dm2 == 1 in 1
    assert dm2 == 0 in 2
    assert dm2 == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: Case sensitivity in prefix mode"
    local ++pass_count
}
else {
    display as error "  FAIL: Case sensitivity prefix mode (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Type and Format Checks
* ============================================================

**## Indicator variables are byte type
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]")
    local t_dm2 : type dm2
    local t_htn : type htn
    assert "`t_dm2'" == "byte"
    assert "`t_htn'" == "byte"
}
if _rc == 0 {
    display as result "  PASS: Indicator variables are byte type"
    local ++pass_count
}
else {
    display as error "  FAIL: Indicator byte type (error `=_rc')"
    local ++fail_count
}

**## Collapsed indicator is byte type
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse
    local t : type dm2
    assert "`t'" == "byte"
}
if _rc == 0 {
    display as result "  PASS: Collapsed indicator is byte type"
    local ++pass_count
}
else {
    display as error "  FAIL: Collapsed indicator byte type (error `=_rc')"
    local ++fail_count
}

**## countdate _count variable is long type
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(365) collapse countdate
    local t : type dm2_count
    assert "`t'" == "long"
}
if _rc == 0 {
    display as result "  PASS: countdate _count is long type"
    local ++pass_count
}
else {
    display as error "  FAIL: countdate long type (error `=_rc')"
    local ++fail_count
}

**## Date format %tdCCYY-NN-DD preserved after collapse
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "E110" 21914
    1 "E119" 21920
    end
    format visit_dt %tdCCYY-NN-DD
    gen double index_dt = 21920
    format index_dt %tdCCYY-NN-DD
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(365) collapse earliestdate latestdate
    local fmt : format dm2_first
    assert "`fmt'" == "%tdCCYY-NN-DD"
    local fmt2 : format dm2_last
    assert "`fmt2'" == "%tdCCYY-NN-DD"
}
if _rc == 0 {
    display as result "  PASS: Date format %tdCCYY-NN-DD preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: Date format preserved (error `=_rc')"
    local ++fail_count
}

**## String id variable works with collapse
local ++test_count
capture noisily {
    clear
    input str10 sid str10 dx1
    "A001" "E110"
    "A001" "I10"
    "A002" "E119"
    "A002" "Z00"
    end
    codescan dx1, define(dm2 "E11" | htn "I10") id(sid) collapse
    assert _N == 2
    assert dm2 == 1 if sid == "A001"
    assert dm2 == 1 if sid == "A002"
    assert htn == 1 if sid == "A001"
    assert htn == 0 if sid == "A002"
}
if _rc == 0 {
    display as result "  PASS: String id variable works with collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: String id collapse (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Return Value Extended Tests
* ============================================================

**## r(lookforward) and r(refdate) returned
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(365) lookforward(180)
    assert r(lookforward) == 180
    assert "`r(refdate)'" == "index_dt"
}
if _rc == 0 {
    display as result "  PASS: r(lookforward) and r(refdate) returned"
    local ++pass_count
}
else {
    display as error "  FAIL: r(lookforward) and r(refdate) (error `=_rc')"
    local ++fail_count
}

**## Summary matrix row and column names
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]")
    matrix S = r(summary)
    local rn : rowfullnames S
    local cn : colfullnames S
    assert "`rn'" == "dm2 htn"
    assert "`cn'" == "count prevalence ci_low ci_high total_hits positive_units"
}
if _rc == 0 {
    display as result "  PASS: Summary matrix row/col names"
    local ++pass_count
}
else {
    display as error "  FAIL: Summary matrix names (error `=_rc')"
    local ++fail_count
}

**## r(newvars) correct with latestdate+countdate (no earliestdate)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(365) collapse latestdate countdate
    local nv = "`r(newvars)'"
    assert strpos("`nv'", "dm2") > 0
    assert strpos("`nv'", "dm2_last") > 0
    assert strpos("`nv'", "dm2_count") > 0
    assert strpos("`nv'", "dm2_first") == 0
}
if _rc == 0 {
    display as result "  PASS: r(newvars) with latestdate+countdate"
    local ++pass_count
}
else {
    display as error "  FAIL: r(newvars) latestdate+countdate (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Regression Tests (from codex_fixes)
* ============================================================

**## Merge mode r(summary) has valid counts (v1.4.2 fix)
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21914 21915
    1 "Z00"  21916 21915
    2 "I10"  21914 21915
    end
    format visit_dt index_dt %td
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) ///
        refdate(index_dt) lookback(365) merge earliestdate
    assert r(summary)[1,1] == 1
    assert r(summary)[1,2] < .
}
if _rc == 0 {
    display as result "  PASS: Merge mode r(summary) valid counts"
    local ++pass_count
}
else {
    display as error "  FAIL: Merge mode r(summary) (error `=_rc')"
    local ++fail_count
}

**## Merge + replace refreshes earliestdate variables in master data
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21914 21915
    1 "Z00"  21916 21915
    2 "I10"  21914 21915
    end
    format visit_dt index_dt %td
    gen double dm2_first = .
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) ///
        refdate(index_dt) lookback(365) merge earliestdate replace
    assert dm2 == 1 in 1
    assert dm2 == 1 in 2
    assert dm2 == 0 in 3
    assert dm2_first == 21914 in 1
    assert dm2_first == 21914 in 2
    assert missing(dm2_first) in 3
}
if _rc == 0 {
    display as result "  PASS: Merge + replace refreshes earliestdate values"
    local ++pass_count
}
else {
    display as error "  FAIL: Merge + replace earliestdate refresh (error `=_rc')"
    local ++fail_count
}

**## Countmode r(summary) stores total, not obs>0 (v1.4.2 fix)
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3
    "E110" "E119" "I10"
    end
    codescan dx1 dx2 dx3, define(dm2 "E11" | htn "I10") countmode
    assert r(summary)[1,1] == 2
    assert r(summary)[2,1] == 1
}
if _rc == 0 {
    display as result "  PASS: Countmode r(summary) stores total matches"
    local ++pass_count
}
else {
    display as error "  FAIL: Countmode r(summary) total (error `=_rc')"
    local ++fail_count
}

**## Countmode + earliestdate/latestdate non-missing (v1.4.2 fix)
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2 double visit_dt
    1 "E110" "E119" 21914
    1 "Z00"  ""     21920
    end
    format visit_dt %td
    codescan dx1 dx2, define(dm2 "E11") id(pid) date(visit_dt) ///
        collapse countmode earliestdate latestdate
    assert dm2 == 2
    assert dm2_first < .
    assert dm2_last < .
    assert dm2_first == 21914
    assert dm2_last == 21914
}
if _rc == 0 {
    display as result "  PASS: Countmode + dates non-missing"
    local ++pass_count
}
else {
    display as error "  FAIL: Countmode + dates (error `=_rc')"
    local ++fail_count
}

**## Cooccurrence under countmode uses binary (v1.4.2 fix)
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3
    "E110" "E119" "I10"
    end
    codescan dx1 dx2 dx3, define(dm2 "E11" | htn "I10") countmode cooccurrence
    assert r(cooccurrence)[1,1] == 1
    assert r(cooccurrence)[1,2] == 1
    assert r(cooccurrence)[2,1] == 1
    assert r(cooccurrence)[2,2] == 1
}
if _rc == 0 {
    display as result "  PASS: Cooccurrence correct under countmode"
    local ++pass_count
}
else {
    display as error "  FAIL: Cooccurrence countmode (error `=_rc')"
    local ++fail_count
}

**## Matched_code cleared after exclusion (v1.4.2 fix)
local ++test_count
capture noisily {
    clear
    input str10 dx1
    "E116"
    "E110"
    "Z00"
    end
    codescan dx1, define(dm2 "E11" ~ "E116") matched_code(mc)
    assert dm2[1] == 0
    assert mc[1] == ""
    assert dm2[2] == 1
    assert mc[2] == "E110"
    assert dm2[3] == 0
    assert mc[3] == ""
}
if _rc == 0 {
    display as result "  PASS: Matched_code cleared after exclusion"
    local ++pass_count
}
else {
    display as error "  FAIL: Matched_code exclusion (error `=_rc')"
    local ++fail_count
}

**## varabbrev restore verified (redundant safety check)
local ++test_count
capture noisily {
    set varabbrev on
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11")
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11")
    assert "`c(varabbrev)'" == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: varabbrev restore preserves both on and off"
    local ++pass_count
}
else {
    display as error "  FAIL: varabbrev restore both states (error `=_rc')"
    local ++fail_count
    capture set varabbrev on
}


* ============================================================
* NEW: r(ci_level) and Non-Default Confidence Level
* ============================================================

**## r(ci_level) returned at default 95%
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11")
    assert r(ci_level) == 95
}
if _rc == 0 {
    display as result "  PASS: r(ci_level) returns 95 at default"
    local ++pass_count
}
else {
    display as error "  FAIL: r(ci_level) default (error `=_rc')"
    local ++fail_count
}

* Restore the suite baseline. This sits AFTER the verdict, never before:
* `set varabbrev' resets _rc, so restoring ahead of the `if _rc == 0'
* would make the test pass unconditionally. Leaving it unrestored let a
* varabbrev=on leak into every later suite in the lane.
set varabbrev `_qa_va0'

**## Non-default c(level) = 90 changes CI width
local ++test_count
capture noisily {
    local _orig_level = c(level)
    _make_test_data
    set level 95
    codescan dx1-dx3, define(dm2 "E11") replace
    matrix S95 = r(summary)
    local ci_lo_95 = S95[1,3]
    local ci_hi_95 = S95[1,4]
    set level 90
    codescan dx1-dx3, define(dm2 "E11") replace
    matrix S90 = r(summary)
    local ci_lo_90 = S90[1,3]
    local ci_hi_90 = S90[1,4]
    assert r(ci_level) == 90
    * 90% CI should be narrower than 95% CI
    assert (`ci_hi_90' - `ci_lo_90') < (`ci_hi_95' - `ci_lo_95')
    set level `_orig_level'
}
if _rc == 0 {
    display as result "  PASS: Non-default c(level)=90 narrows CI"
    local ++pass_count
}
else {
    display as error "  FAIL: Non-default c(level) (error `=_rc')"
    local ++fail_count
    capture set level 95
}


* ============================================================
* NEW: matched_code Type Check
* ============================================================

**## matched_code is str244 type
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") matched_code(mc)
    local t : type mc
    assert "`t'" == "str244"
}
if _rc == 0 {
    display as result "  PASS: matched_code is str244 type"
    local ++pass_count
}
else {
    display as error "  FAIL: matched_code type (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: save() on codescan (not describe)
* ============================================================

**## save() roundtrip: save define → use as codefile
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        save("_codescan_test_save.csv", replace)
    local r1_dm2 = r(summary)[1,1]
    local r1_htn = r(summary)[2,1]

    _make_test_data
    codescan dx1-dx3, codefile("_codescan_test_save.csv")
    local r2_dm2 = r(summary)[1,1]
    local r2_htn = r(summary)[2,1]
    assert `r1_dm2' == `r2_dm2'
    assert `r1_htn' == `r2_htn'
}
if _rc == 0 {
    display as result "  PASS: save() roundtrip define → codefile"
    local ++pass_count
}
else {
    display as error "  FAIL: save() roundtrip (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: Documentation Reality Tests
* ============================================================

**## Error — codefile .txt extension rejected
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, codefile("myfile.txt")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — codefile .txt extension rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — codefile .txt extension (error `=_rc')"
    local ++fail_count
}

**## Error — save() combined with codefile()
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, codefile("_codescan_test_save.csv") save("out.csv")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — save() with codefile() (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — save+codefile (error `=_rc')"
    local ++fail_count
}

**## Error — level(11) out of range rejected
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") mode(prefix) level(11)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — level(11) rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — level bounds (error `=_rc')"
    local ++fail_count
}

**## Error — save() non-csv extension
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") save("out.xlsx")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — save() non-csv rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — save non-csv (error `=_rc')"
    local ++fail_count
}

**## Error — multi-window lookback without collapse or merge
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(365 1825)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — multi-window without collapse (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — multi-window no collapse (error `=_rc')"
    local ++fail_count
}

**## Collapse with if + time window + date summaries
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3 if pid <= 3, define(dm2 "E11") id(pid) ///
        date(visit_dt) refdate(index_dt) lookback(365) collapse alldates
    * Only patients 1-3 should appear
    quietly count
    assert r(N) <= 3
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: Collapse with if + window + alldates"
    local ++pass_count
}
else {
    display as error "  FAIL: Collapse if+window+alldates (error `=_rc')"
    local ++fail_count
}

**## Noisily with collapse and date summaries
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) ///
        refdate(index_dt) lookback(365) collapse earliestdate noisily
    assert r(collapsed) == 1
}
if _rc == 0 {
    display as result "  PASS: Noisily with collapse + dates"
    local ++pass_count
}
else {
    display as error "  FAIL: Noisily collapse dates (error `=_rc')"
    local ++fail_count
}

**## Collapse with latestdate + countdate only (no earliestdate)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) ///
        refdate(index_dt) lookback(365) collapse latestdate countdate
    confirm variable dm2_last
    confirm variable dm2_count
    capture confirm variable dm2_first
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Collapse with latestdate+countdate only"
    local ++pass_count
}
else {
    display as error "  FAIL: Collapse latest+count only (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: Prefix Mode Extended
* ============================================================

**## Multi-column prefix mode with multi-prefix patterns
local ++test_count
capture noisily {
    clear
    set obs 6
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    replace dx1 = "E110" in 1
    replace dx2 = "I10"  in 1
    replace dx1 = "Z00"  in 2
    replace dx1 = "E119" in 3
    replace dx2 = "I13"  in 4
    replace dx1 = "K21"  in 5
    replace dx2 = "I25"  in 6
    codescan dx1 dx2, define(dm2 "E11" | htn "I10|I13" | cvd "I25") mode(prefix)
    assert dm2 == 1 in 1
    assert htn == 1 in 1
    assert htn == 1 in 4
    assert cvd == 1 in 6
    assert dm2 == 0 in 5
}
if _rc == 0 {
    display as result "  PASS: Multi-column multi-prefix mode"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-column multi-prefix (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: codescan_describe Extended
* ============================================================

**## codescan_describe preserves original data after tostring
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double code1 = _n * 100
    local N_before = _N
    local t_before : type code1
    codescan_describe code1, tostring
    assert _N == `N_before'
    local t_after : type code1
    assert "`t_after'" == "`t_before'"
}
if _rc == 0 {
    display as result "  PASS: codescan_describe tostring preserves data"
    local ++pass_count
}
else {
    display as error "  FAIL: Describe tostring preservation (error `=_rc')"
    local ++fail_count
}

**## codescan_describe top(0) error
local ++test_count
capture noisily {
    clear
    set obs 5
    gen str10 dx1 = "E110"
    capture codescan_describe dx1, top(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: codescan_describe top(0) error"
    local ++pass_count
}
else {
    display as error "  FAIL: Describe top(0) error (error `=_rc')"
    local ++fail_count
}

**## codescan_describe with save() generates CSV
local ++test_count
capture noisily {
    clear
    set obs 5
    gen str10 dx1 = ""
    replace dx1 = "E110" in 1
    replace dx1 = "I10"  in 2
    replace dx1 = "J45"  in 3
    replace dx1 = "K21"  in 4
    replace dx1 = "E119" in 5
    codescan_describe dx1, save("_codescan_describe_save.csv", replace)
    confirm file "_codescan_describe_save.csv"
}
if _rc == 0 {
    display as result "  PASS: codescan_describe save() generates CSV"
    local ++pass_count
}
else {
    display as error "  FAIL: Describe save CSV (error `=_rc')"
    local ++fail_count
}

**## codescan_describe save() non-csv error
local ++test_count
capture noisily {
    clear
    set obs 5
    gen str10 dx1 = "E110"
    capture codescan_describe dx1, save("out.xlsx")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: codescan_describe save() non-csv error"
    local ++pass_count
}
else {
    display as error "  FAIL: Describe save non-csv error (error `=_rc')"
    local ++fail_count
}

**## codescan_describe varabbrev restored after error
local ++test_count
capture noisily {
    set varabbrev on
    clear
    set obs 3
    gen double numvar = _n
    capture codescan_describe numvar
    assert _rc == 109
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: codescan_describe varabbrev restored after error"
    local ++pass_count
}
else {
    display as error "  FAIL: Describe varabbrev on error (error `=_rc')"
    local ++fail_count
}

* Restore the suite baseline. This sits AFTER the verdict, never before:
* `set varabbrev' resets _rc, so restoring ahead of the `if _rc == 0'
* would make the test pass unconditionally. Leaving it unrestored let a
* varabbrev=on leak into every later suite in the lane.
set varabbrev `_qa_va0'


* ============================================================
* NEW: Error — _count variable exists without replace
* ============================================================

local ++test_count
capture noisily {
    clear
    set obs 5
    gen str10 dx1 = "E110"
    gen long pid = _n
    gen double visit_dt = 21914
    gen double index_dt = 21915
    format visit_dt index_dt %td
    gen byte dm2_count = 0
    capture codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) ///
        refdate(index_dt) lookback(365) collapse countdate
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: Error — _count exists without replace (rc=110)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — _count exists (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: Package Install Verification (extended)
* ============================================================

* Explicit .dta paths for saving() tests (tempfile omits .dta; Stata save appends it)
local _tf_save    "`qa_dir'/cs_test_save.dta"
local _tf_replace "`qa_dir'/cs_test_replace.dta"
local _tf_merge   "`qa_dir'/cs_test_merge.dta"

**## saving() — basic: file created with correct structure
local ++test_count
capture noisily {
    clear
    set obs 4
    gen str8 dx1 = ""
    replace dx1 = "E11" in 1
    replace dx1 = "E11" in 2
    replace dx1 = "I10" in 3
    replace dx1 = ""    in 4
    gen pid = cond(_n <= 2, 1, _n - 1)
    codescan dx1, define(dm2 "E11" | htn "I10") id(pid) collapse ///
        saving("`_tf_save'", replace)
    confirm file "`_tf_save'"
    preserve
    use "`_tf_save'", clear
    quietly count
    assert r(N) == 3    // 3 unique patients
    confirm variable dm2
    confirm variable htn
    confirm variable pid
    restore
}
if _rc == 0 {
    display as result "  PASS: saving() creates file with correct structure"
    local ++pass_count
}
else {
    display as error "  FAIL: saving() basic (error `=_rc')"
    local ++fail_count
}

**## saving() requires collapse or merge
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str8 dx1 = "E11"
    gen pid = _n
    capture codescan dx1, define(dm2 "E11") saving("`_tf_save'")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: saving() requires collapse or merge"
    local ++pass_count
}
else {
    display as error "  FAIL: saving() collapse guard (error `=_rc')"
    local ++fail_count
}

**## saving() — replace suboption overwrites existing file
local ++test_count
capture noisily {
    * First call: create the file (replace in case it exists from prior run)
    clear
    set obs 2
    gen str8 dx1 = "E11"
    gen pid = _n
    codescan dx1, define(dm2 "E11") id(pid) collapse saving("`_tf_replace'", replace)
    * Second call: overwrite it (data needs to be fresh since collapse destroyed dx1)
    clear
    set obs 2
    gen str8 dx1 = "E11"
    gen pid = _n
    codescan dx1, define(dm2 "E11") id(pid) collapse ///
        saving("`_tf_replace'", replace) replace
    confirm file "`_tf_replace'"
}
if _rc == 0 {
    display as result "  PASS: saving() replace suboption works"
    local ++pass_count
}
else {
    display as error "  FAIL: saving() replace (error `=_rc')"
    local ++fail_count
}

**## saving() with merge mode
local ++test_count
capture noisily {
    clear
    set obs 4
    gen str8 dx1 = ""
    replace dx1 = "E11" in 1
    replace dx1 = "E11" in 2
    replace dx1 = "I10" in 3
    replace dx1 = ""    in 4
    gen pid = cond(_n <= 2, 1, _n - 1)
    codescan dx1, define(dm2 "E11") id(pid) merge saving("`_tf_merge'", replace)
    confirm file "`_tf_merge'"
    preserve
    use "`_tf_merge'", clear
    quietly count
    assert r(N) == 4    // row-level: merge keeps all rows
    restore
}
if _rc == 0 {
    display as result "  PASS: saving() + merge"
    local ++pass_count
}
else {
    display as error "  FAIL: saving() + merge (error `=_rc')"
    local ++fail_count
}

**## format() — valid format accepted (command runs)
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str8 dx1 = "E11"
    codescan dx1, define(dm2 "E11") format(%9.2f)
    assert r(n_conditions) == 1
}
if _rc == 0 {
    display as result "  PASS: format() valid format accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: format() valid (error `=_rc')"
    local ++fail_count
}

**## format() — invalid format rejected (rc=198)
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str8 dx1 = "E11"
    capture codescan dx1, define(dm2 "E11") format(%z9.2f)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: format() invalid format rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: format() invalid guard (error `=_rc')"
    local ++fail_count
}

**## export() — CSV contains ci_low and ci_high columns
local ++test_count
capture noisily {
    clear
    set obs 6
    gen str8 dx1 = ""
    replace dx1 = "E11" in 1
    replace dx1 = "E11" in 2
    replace dx1 = "I10" in 3
    replace dx1 = "I10" in 4
    replace dx1 = ""    in 5
    replace dx1 = ""    in 6
    gen pid = cond(_n <= 2, 1, cond(_n <= 4, 2, 3))
    local _export_path `"`qa_dir'/codescan_ci_test.csv"'
    codescan dx1, define(dm2 "E11" | htn "I10") id(pid) collapse ///
        export(`"`_export_path'"')
    preserve
    import delimited `"`_export_path'"', clear varnames(1)
    confirm variable ci_low
    confirm variable ci_high
    * ci values should be in [0,100]
    quietly summarize ci_low
    assert r(min) >= 0 & r(max) <= 100
    quietly summarize ci_high
    assert r(min) >= 0 & r(max) <= 100
    * ci_high > ci_low for all rows with n_match > 0
    quietly count if ci_high < ci_low
    assert r(N) == 0
    restore
}
if _rc == 0 {
    display as result "  PASS: export() CSV has ci_low and ci_high in [0,100]"
    local ++pass_count
}
else {
    display as error "  FAIL: export() CI columns (error `=_rc')"
    local ++fail_count
}

**## export() — CI values in r(summary) match exported CSV
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str8 dx1 = ""
    replace dx1 = "E11" in 1
    replace dx1 = "E11" in 2
    replace dx1 = "I10" in 3
    gen pid = _n
    local _export2_path `"`qa_dir'/codescan_ci_match.csv"'
    codescan dx1, define(dm2 "E11" | htn "I10") id(pid) collapse ///
        export(`"`_export2_path'"')
    local r_ci_low  = r(summary)[1,3]
    local r_ci_high = r(summary)[1,4]
    preserve
    import delimited `"`_export2_path'"', clear varnames(1)
    * dm2 is row 1 in export
    assert abs(ci_low[1]  - `r_ci_low')  < 0.01
    assert abs(ci_high[1] - `r_ci_high') < 0.01
    restore
}
if _rc == 0 {
    display as result "  PASS: export() CI values match r(summary)"
    local ++pass_count
}
else {
    display as error "  FAIL: export() CI match r(summary) (error `=_rc')"
    local ++fail_count
}

**## codescan_describe — obs guard exits 2000 on empty if/in sample
local ++test_count
capture noisily {
    clear
    set obs 5
    gen str8 dx1 = "E11"
    gen byte flag = 0
    capture codescan_describe dx1 if flag == 1
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: codescan_describe exits 2000 on empty sample"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe obs guard (error `=_rc')"
    local ++fail_count
}

**## codescan_describe — obs guard: multiple conditions all false
local ++test_count
capture noisily {
    clear
    set obs 5
    gen str8 dx1 = "E11"
    gen byte grp = 1
    replace grp = 2 in 1/3
    capture codescan_describe dx1 if grp == 99
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: codescan_describe exits 2000 on always-false if"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe if false guard (error `=_rc')"
    local ++fail_count
}

**## r(summary) — ci_low and ci_high columns are correct
* Known answer: 2/3 prevalence with N=3 → Wilson 95% CI ≈ [20.8, 93.9]
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str8 dx1 = ""
    replace dx1 = "E11" in 1
    replace dx1 = "E11" in 2
    replace dx1 = "I10" in 3
    gen pid = _n
    codescan dx1, define(dm2 "E11") id(pid) collapse
    local _ci_lo = r(summary)[1,3]
    local _ci_hi = r(summary)[1,4]
    * Wilson 95% CI for 2/3: approx [20.8, 93.9]
    assert abs(`_ci_lo' - 20.8) < 1.0
    assert abs(`_ci_hi' - 93.9) < 1.0
    * Sanity bounds
    assert `_ci_lo' >= 0 & `_ci_lo' <= 100
    assert `_ci_hi' >= 0 & `_ci_hi' <= 100
    assert `_ci_hi' > `_ci_lo'
}
if _rc == 0 {
    display as result "  PASS: r(summary) ci_low/ci_high known-answer Wilson CI"
    local ++pass_count
}
else {
    display as error "  FAIL: r(summary) CI values (error `=_rc')"
    local ++fail_count
}

**## Cross-variable exclusion — binary mode, regex
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3
    "E110" "E116" ""
    "E116" "E110" ""
    "E116" "E116" ""
    "E110" ""     ""
    "E116" ""     ""
    "Z00"  ""     ""
    end
    codescan dx1-dx3, define(dm2 "E11" ~ "E116")
    * Row 1: dx1=E110 (valid), dx2=E116 (excluded) → 1
    * Row 2: dx1=E116 (excluded), dx2=E110 (valid) → 1
    * Row 3: both excluded → 0
    * Row 4: valid only → 1
    * Row 5: excluded only → 0
    * Row 6: no match → 0
    assert dm2 == 1 in 1
    assert dm2 == 1 in 2
    assert dm2 == 0 in 3
    assert dm2 == 1 in 4
    assert dm2 == 0 in 5
    assert dm2 == 0 in 6
}
if _rc == 0 {
    display as result "  PASS: Cross-variable exclusion (binary, regex)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cross-variable exclusion binary regex (error `=_rc')"
    local ++fail_count
}

**## Cross-variable exclusion — binary mode, prefix
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "E110" "E116"
    "E116" "E119"
    "E116" "E116"
    end
    codescan dx1-dx2, define(dm2 "E11" ~ "E116") mode(prefix)
    assert dm2 == 1 in 1
    assert dm2 == 1 in 2
    assert dm2 == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: Cross-variable exclusion (binary, prefix)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cross-variable exclusion binary prefix (error `=_rc')"
    local ++fail_count
}

**## Cross-variable exclusion — countmode
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3
    "E110" "E116" "E119"
    "E116" "E116" "E110"
    "E116" "E116" ""
    end
    codescan dx1-dx3, define(dm2 "E11" ~ "E116") countmode
    * Row 1: E110 (valid=1) + E116 (excl) + E119 (valid=1) → 2
    * Row 2: E116 (excl) + E116 (excl) + E110 (valid=1) → 1
    * Row 3: E116 (excl) + E116 (excl) → 0
    assert dm2 == 2 in 1
    assert dm2 == 1 in 2
    assert dm2 == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: Cross-variable exclusion (countmode)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cross-variable exclusion countmode (error `=_rc')"
    local ++fail_count
}

**## Cross-variable exclusion — matched_code captures valid code, not excluded
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "E116" "E110"
    "E110" "E116"
    "E116" ""
    end
    codescan dx1-dx2, define(dm2 "E11" ~ "E116") matched_code(mc)
    * Row 1: dx1=E116 excluded, dx2=E110 valid → mc=E110
    * Row 2: dx1=E110 valid → mc=E110 (E116 skipped)
    * Row 3: dx1=E116 excluded → mc=""
    assert mc == "E110" in 1
    assert mc == "E110" in 2
    assert mc == "" in 3
}
if _rc == 0 {
    display as result "  PASS: Cross-variable exclusion (matched_code)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cross-variable exclusion matched_code (error `=_rc')"
    local ++fail_count
}

**## Cross-variable exclusion — detail counts post-exclusion
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "E110" "E116"
    "E119" "E110"
    "E116" ""
    end
    codescan dx1-dx2, define(dm2 "E11" ~ "E116") detail
    * dx1: E110 (valid), E119 (valid), E116 (excluded) → 2 effective matches
    * dx2: E116 (excluded), E110 (already 1 in binary → skipped) → 0
    * But row 1: dx1=E110 sets dm2=1, then dx2=E116 is skipped (already 1)
    * Row 2: dx1=E119 sets dm2=1, then dx2 skipped
    * Row 3: dx1=E116 excluded, dx2 empty
    * Detail for dx1: 2 (rows 1,2), Detail for dx2: 0
    assert r(varcounts)[1,1] == 2 // dx1 contributions
    assert r(varcounts)[1,2] == 0 // dx2 contributions
}
if _rc == 0 {
    display as result "  PASS: Cross-variable exclusion (detail counts)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cross-variable exclusion detail (error `=_rc')"
    local ++fail_count
}

**## Cross-variable exclusion — nocase
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "e110" "e116"
    "e116" "e119"
    end
    codescan dx1-dx2, define(dm2 "E11" ~ "E116") nocase
    assert dm2 == 1 in 1
    assert dm2 == 1 in 2
}
if _rc == 0 {
    display as result "  PASS: Cross-variable exclusion (nocase)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cross-variable exclusion nocase (error `=_rc')"
    local ++fail_count
}

**## Cross-variable exclusion — collapse preserves valid matches
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2
    1 "E110" "E116"
    1 "E119" ""
    2 "E116" "E116"
    2 "E116" ""
    end
    codescan dx1-dx2, define(dm2 "E11" ~ "E116") id(pid) collapse
    * pid 1: row 1 dm2=1 (E110 valid), row 2 dm2=1 → max=1
    * pid 2: row 1 dm2=0 (both excluded), row 2 dm2=0 → max=0
    assert dm2 == 1 if pid == 1
    assert dm2 == 0 if pid == 2
}
if _rc == 0 {
    display as result "  PASS: Cross-variable exclusion (collapse)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cross-variable exclusion collapse (error `=_rc')"
    local ++fail_count
}

**## Cross-variable exclusion — merge preserves valid matches
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2
    1 "E110" "E116"
    1 "E116" "E116"
    2 "E116" ""
    end
    codescan dx1-dx2, define(dm2 "E11" ~ "E116") id(pid) merge
    * pid 1: row 1 dm2=1 (E110 valid), row 2 dm2=0 → max=1 → all pid1 rows=1
    * pid 2: dm2=0
    assert dm2 == 1 if pid == 1
    assert dm2 == 0 if pid == 2
}
if _rc == 0 {
    display as result "  PASS: Cross-variable exclusion (merge)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cross-variable exclusion merge (error `=_rc')"
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
_codescan_qa_publish "test_codescan_coverage" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_codescan_coverage tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
