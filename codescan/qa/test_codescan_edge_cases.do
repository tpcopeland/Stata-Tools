* test_codescan_edge_cases.do - Frame/export/graph, codefile, cooccurrence, degenerate and merge edge cases
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

**# Frame, Export, Graph Functional Tests

**## frame() stores correct collapsed data
local ++test_count
capture noisily {
    _make_test_data
    capture frame drop _cs_test_frame
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        id(pid) collapse frame(_cs_test_frame) replace
    * Capture r(frame) before frame {} block clears r()
    local fr_name "`r(frame)'"
    assert "`fr_name'" == "_cs_test_frame"
    * Verify frame exists and has correct content
    frame _cs_test_frame {
        quietly count
        assert r(N) == 5
        confirm variable pid
        confirm variable dm2
        confirm variable htn
    }
    capture frame drop _cs_test_frame
}
if _rc == 0 {
    display as result "  PASS: frame() stores correct collapsed data"
    local ++pass_count
}
else {
    display as error "  FAIL: frame() stores collapsed data (error `=_rc')"
    local ++fail_count
    capture frame drop _cs_test_frame
}

**## frame() with replace on existing frame
local ++test_count
capture noisily {
    _make_test_data
    capture frame drop _cs_test_fr2
    frame create _cs_test_fr2
    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse ///
        frame(_cs_test_fr2) replace
    frame _cs_test_fr2 {
        quietly count
        assert r(N) == 5
        confirm variable dm2
    }
    capture frame drop _cs_test_fr2
}
if _rc == 0 {
    display as result "  PASS: frame() with replace on existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: frame() with replace (error `=_rc')"
    local ++fail_count
    capture frame drop _cs_test_fr2
}

**## preserve option restores original data
local ++test_count
capture noisily {
    _make_test_data
    local N_before = _N
    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse preserve replace
    * After preserve+collapse, original data should be restored
    assert _N == `N_before'
    * Indicator variables should NOT exist in original data
    capture confirm variable dm2
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: preserve option restores original data"
    local ++pass_count
}
else {
    display as error "  FAIL: preserve option (error `=_rc')"
    local ++fail_count
}

**## export() CSV writes correct content
local ++test_count
capture noisily {
    _make_test_data
    capture erase "_cs_export_test.csv"
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        replace export("_cs_export_test.csv")
    confirm file "_cs_export_test.csv"
    preserve
    import delimited using "_cs_export_test.csv", clear
    assert _N == 2
    confirm variable condition
    confirm variable matches
    confirm variable prevalence
    confirm variable pattern
    assert condition[1] == "dm2"
    assert condition[2] == "htn"
    assert matches[1] > 0
    restore
    capture erase "_cs_export_test.csv"
}
if _rc == 0 {
    display as result "  PASS: export() CSV correct content"
    local ++pass_count
}
else {
    display as error "  FAIL: export() CSV (error `=_rc')"
    local ++fail_count
}

**## export() XLSX writes file
local ++test_count
capture noisily {
    _make_test_data
    capture erase "_cs_export_test.xlsx"
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        replace export("_cs_export_test.xlsx")
    confirm file "_cs_export_test.xlsx"
    capture erase "_cs_export_test.xlsx"
}
if _rc == 0 {
    display as result "  PASS: export() XLSX writes file"
    local ++pass_count
}
else {
    display as error "  FAIL: export() XLSX (error `=_rc')"
    local ++fail_count
}

**## export() XLSX with cooccurrence adds second sheet
local ++test_count
capture noisily {
    _make_test_data
    capture erase "_cs_export_cooc.xlsx"
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        replace cooccurrence export("_cs_export_cooc.xlsx")
    confirm file "_cs_export_cooc.xlsx"
    * Read cooccurrence sheet
    preserve
    import excel using "_cs_export_cooc.xlsx", sheet("cooccurrence") ///
        firstrow clear
    assert _N == 2
    confirm variable condition
    confirm variable dm2
    confirm variable htn
    restore
    capture erase "_cs_export_cooc.xlsx"
}
if _rc == 0 {
    display as result "  PASS: export() XLSX cooccurrence sheet"
    local ++pass_count
}
else {
    display as error "  FAIL: export() XLSX cooccurrence (error `=_rc')"
    local ++fail_count
}

**## graph option runs without error
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") replace graph
    graph close _all
}
if _rc == 0 {
    display as result "  PASS: graph option runs without error"
    local ++pass_count
}
else {
    display as error "  FAIL: graph option (error `=_rc')"
    local ++fail_count
}

**## graph with single condition
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") replace graph
    graph close _all
}
if _rc == 0 {
    display as result "  PASS: graph with single condition"
    local ++pass_count
}
else {
    display as error "  FAIL: graph with single condition (error `=_rc')"
    local ++fail_count
}


**# Codefile Edge Cases

**## R2 — codefile case-tolerant column names
local ++test_count
capture noisily {
    _make_test_data
    capture erase "_cs_test_r2_case.csv"
    preserve
    clear
    set obs 1
    gen str32 Name = "dm2"
    gen str32 Pattern = "E11"
    gen str32 Label = "Diabetes"
    export delimited using "_cs_test_r2_case.csv", replace
    restore
    _make_test_data
    codescan dx1-dx3, codefile("_cs_test_r2_case.csv") replace
    assert r(n_conditions) == 1
    assert dm2[1] == 1
    capture erase "_cs_test_r2_case.csv"
}
if _rc == 0 {
    display as result "  PASS: R2 codefile case-tolerant column names"
    local ++pass_count
}
else {
    display as error "  FAIL: R2 case-tolerant columns (error `=_rc')"
    local ++fail_count
}

**## Codefile with extra unrecognized columns (ignored)
local ++test_count
capture noisily {
    _make_test_data
    capture erase "_cs_test_extra.csv"
    preserve
    clear
    set obs 1
    gen str32 name = "dm2"
    gen str32 pattern = "E11"
    gen str32 notes = "some extra column"
    gen int priority = 1
    export delimited using "_cs_test_extra.csv", replace
    restore
    _make_test_data
    codescan dx1-dx3, codefile("_cs_test_extra.csv") replace
    assert r(n_conditions) == 1
    capture erase "_cs_test_extra.csv"
}
if _rc == 0 {
    display as result "  PASS: Codefile extra columns ignored"
    local ++pass_count
}
else {
    display as error "  FAIL: Codefile extra columns (error `=_rc')"
    local ++fail_count
}

**## Codefile labels applied to indicators
local ++test_count
capture noisily {
    _make_test_data
    capture erase "_cs_test_cflbl.csv"
    preserve
    clear
    set obs 2
    gen str32 name = ""
    gen str32 pattern = ""
    gen str80 label = ""
    replace name = "dm2" in 1
    replace pattern = "E11" in 1
    replace label = "Type 2 Diabetes" in 1
    replace name = "htn" in 2
    replace pattern = "I10" in 2
    replace label = "Hypertension" in 2
    export delimited using "_cs_test_cflbl.csv", replace
    restore
    _make_test_data
    codescan dx1-dx3, codefile("_cs_test_cflbl.csv") replace
    local lbl1 : variable label dm2
    local lbl2 : variable label htn
    assert `"`lbl1'"' == "Type 2 Diabetes"
    assert `"`lbl2'"' == "Hypertension"
    capture erase "_cs_test_cflbl.csv"
}
if _rc == 0 {
    display as result "  PASS: Codefile labels applied to indicators"
    local ++pass_count
}
else {
    display as error "  FAIL: Codefile labels (error `=_rc')"
    local ++fail_count
}

**## Countmode with exclusion patterns
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3
    "E110" "E116" "E119"
    "E116" "E116" ""
    "Z00"  ""     ""
    end
    codescan dx1-dx3, define(dm2 "E11" ~ "E116") countmode
    * Per-code exclusion: each code independently evaluated
    * Row 1: dx1=E110 (match, not excluded), dx2=E116 (excluded), dx3=E119 (match) → 2
    * Row 2: dx1=E116 (excluded), dx2=E116 (excluded) → 0
    * Row 3: no match → 0
    assert dm2 == 2 in 1
    assert dm2 == 0 in 2
    assert dm2 == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: Countmode with exclusion patterns"
    local ++pass_count
}
else {
    display as error "  FAIL: Countmode with exclusion (error `=_rc')"
    local ++fail_count
}

**## Countmode with merge
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2
    1 "E110" "E119"
    1 "E110" ""
    2 "Z00"  ""
    end
    codescan dx1-dx2, define(dm2 "E11") id(pid) merge countmode replace
    * Patient 1: row 1 count=2, row 2 count=1 → sum=3
    * Patient 2: row 1 count=0
    * After merge, all rows for pid==1 should have dm2==3
    assert dm2 == 3 if pid == 1
    assert dm2 == 0 if pid == 2
    assert _N == 3
    assert r(merged) == 1
    assert r(mode_count) == 1
}
if _rc == 0 {
    display as result "  PASS: Countmode with merge"
    local ++pass_count
}
else {
    display as error "  FAIL: Countmode with merge (error `=_rc')"
    local ++fail_count
}

**## Matched_code captures first match in variable order
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3
    "Z00"  "E110" "E119"
    "E113" ""     ""
    "Z00"  ""     ""
    end
    codescan dx1-dx3, define(dm2 "E11") matched_code(mc)
    * Row 1: dx1=Z00 no, dx2=E110 yes → mc="E110" (first match)
    assert mc[1] == "E110"
    * Row 2: dx1=E113 → mc="E113"
    assert mc[2] == "E113"
    * Row 3: no match → mc=""
    assert mc[3] == ""
}
if _rc == 0 {
    display as result "  PASS: Matched_code first match in variable order"
    local ++pass_count
}
else {
    display as error "  FAIL: Matched_code order (error `=_rc')"
    local ++fail_count
}

**## Unmatched flag — all rows match → all zeros
local ++test_count
capture noisily {
    clear
    input str10 dx1
    "E110"
    "E119"
    "E11"
    end
    codescan dx1, define(dm2 "E11") unmatched(nomatch)
    assert nomatch == 0 in 1
    assert nomatch == 0 in 2
    assert nomatch == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: Unmatched all rows match (all zeros)"
    local ++pass_count
}
else {
    display as error "  FAIL: Unmatched all match (error `=_rc')"
    local ++fail_count
}

**## Unmatched flag — no rows match → all ones
local ++test_count
capture noisily {
    clear
    input str10 dx1
    "Z00"
    "Z01"
    "Z02"
    end
    codescan dx1, define(dm2 "E11") unmatched(nomatch)
    assert nomatch == 1 in 1
    assert nomatch == 1 in 2
    assert nomatch == 1 in 3
}
if _rc == 0 {
    display as result "  PASS: Unmatched no rows match (all ones)"
    local ++pass_count
}
else {
    display as error "  FAIL: Unmatched no match (error `=_rc')"
    local ++fail_count
}


**# Cooccurrence Edge Cases

**## Row-level cooccurrence (no collapse)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") cooccurrence replace
    matrix C = r(cooccurrence)
    assert rowsof(C) == 2
    assert colsof(C) == 2
    * Diagonal = count of each condition
    * dm2 matches: rows 1,3,11,14 → 4
    assert C[1,1] > 0
    * Symmetry: C[1,2] == C[2,1]
    assert C[1,2] == C[2,1]
}
if _rc == 0 {
    display as result "  PASS: Row-level cooccurrence"
    local ++pass_count
}
else {
    display as error "  FAIL: Row-level cooccurrence (error `=_rc')"
    local ++fail_count
}


**# Single-obs and Degenerate Edge Cases

**## Single patient, single row collapse
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1
    1 "E110"
    end
    codescan dx1, define(dm2 "E11") id(pid) collapse
    assert _N == 1
    assert dm2 == 1
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: Single patient single row collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: Single patient single row collapse (error `=_rc')"
    local ++fail_count
}

**## All empty code variables (zero matches)
local ++test_count
capture noisily {
    clear
    set obs 5
    gen long pid = _n
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    codescan dx1-dx2, define(dm2 "E11")
    assert dm2 == 0
}
if _rc == 0 {
    display as result "  PASS: All empty code variables (zero matches)"
    local ++pass_count
}
else {
    display as error "  FAIL: All empty code vars (error `=_rc')"
    local ++fail_count
}

**## Lookback(0) lookforward(0) inclusive — single day window
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21915 21915
    2 "E110" 21914 21915
    3 "E110" 21916 21915
    end
    format visit_dt index_dt %td
    codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(0) lookforward(0) inclusive
    * Only patient 1 (visit_dt == index_dt) should match
    assert dm2 == 1 in 1
    assert dm2 == 0 in 2
    assert dm2 == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: Lookback(0) lookforward(0) inclusive (single day)"
    local ++pass_count
}
else {
    display as error "  FAIL: Single day window (error `=_rc')"
    local ++fail_count
}

**## Level in prefix mode functional test
local ++test_count
capture noisily {
    clear
    input str10 code
    "E110"
    "E119"
    "E210"
    "E21"
    end
    * level(2) truncates "E11" to "E1", so E110, E119, E210, E21 all start with E1
    codescan code, define(e1x "E11|E21") mode(prefix) level(2)
    assert e1x == 1 in 1
    assert e1x == 1 in 2
    assert e1x == 1 in 3
    assert e1x == 1 in 4
}
if _rc == 0 {
    display as result "  PASS: Level(2) in prefix mode"
    local ++pass_count
}
else {
    display as error "  FAIL: Level in prefix mode (error `=_rc')"
    local ++fail_count
}


**# codescan_describe Extended Tests

**## codescan_describe with if restriction
local ++test_count
capture noisily {
    _make_test_data
    codescan_describe dx1-dx3 if pid <= 2
    assert r(n_vars) == 3
    * Only 8 rows (pid 1-2) should be scanned
}
if _rc == 0 {
    display as result "  PASS: codescan_describe with if"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe with if (error `=_rc')"
    local ++fail_count
}

**## codescan_describe with in restriction
local ++test_count
capture noisily {
    _make_test_data
    codescan_describe dx1-dx3 in 1/4
    assert r(n_vars) == 3
}
if _rc == 0 {
    display as result "  PASS: codescan_describe with in"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe with in (error `=_rc')"
    local ++fail_count
}

**## codescan_describe all empty codes
local ++test_count
capture noisily {
    clear
    set obs 5
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    codescan_describe dx1-dx2
    assert r(n_unique) == 0
    assert r(n_entries) == 0
}
if _rc == 0 {
    display as result "  PASS: codescan_describe all empty codes"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe empty codes (error `=_rc')"
    local ++fail_count
}

**## codescan_describe top(3) custom value
local ++test_count
capture noisily {
    _make_test_data
    codescan_describe dx1-dx3, top(3)
    matrix T = r(top_codes)
    assert rowsof(T) <= 3
}
if _rc == 0 {
    display as result "  PASS: codescan_describe top(3)"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe top(3) (error `=_rc')"
    local ++fail_count
}

**## codescan_describe varabbrev restored on error
local ++test_count
capture noisily {
    set varabbrev on
    clear
    set obs 5
    gen double num_var = _n
    capture codescan_describe num_var
    assert _rc == 109
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: codescan_describe varabbrev restored on error"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe varabbrev on error (error `=_rc')"
    local ++fail_count
}

* Restore the suite baseline. This sits AFTER the verdict, never before:
* `set varabbrev' resets _rc, so restoring ahead of the `if _rc == 0'
* would make the test pass unconditionally. Leaving it unrestored let a
* varabbrev=on leak into every later suite in the lane.
set varabbrev `_qa_va0'
set varabbrev off

**## codescan_describe with tostring and nodots combined
local ++test_count
capture noisily {
    clear
    input double code1 double code2
    110 119
    200 .
    end
    codescan_describe code1 code2, tostring nodots
    assert r(n_unique) > 0
    assert r(n_vars) == 2
}
if _rc == 0 {
    display as result "  PASS: codescan_describe tostring + nodots"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe tostring + nodots (error `=_rc')"
    local ++fail_count
}

* Restore the suite baseline. This sits AFTER the verdict, never before:
* `set varabbrev' resets _rc, so restoring ahead of the `if _rc == 0'
* would make the test pass unconditionally. Leaving it unrestored let a
* varabbrev=on leak into every later suite in the lane.
set varabbrev `_qa_va0'


**# Merge Extended Tests

**## Merge with countdate
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "E110" 21915
    1 "E119" 21916
    1 "Z00"  21917
    2 "E110" 21915
    2 "Z00"  21916
    end
    format visit_dt %td
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) merge countdate
    * Patient 1: 2 unique dates with dm2 match (21915, 21916)
    * Patient 2: 1 unique date with dm2 match (21915)
    * After merge, these should broadcast to all rows
    assert dm2_count == 2 if pid == 1
    assert dm2_count == 1 if pid == 2
    assert _N == 5
}
if _rc == 0 {
    display as result "  PASS: Merge with countdate"
    local ++pass_count
}
else {
    display as error "  FAIL: Merge with countdate (error `=_rc')"
    local ++fail_count
}

**## Merge with cooccurrence
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1
    1 "E110"
    1 "I10"
    2 "I10"
    2 "Z00"
    end
    codescan dx1, define(dm2 "E11" | htn "I10") id(pid) merge cooccurrence replace
    matrix C = r(cooccurrence)
    assert rowsof(C) == 2
    * After merge: co-occurrence is patient-level (not row-level)
    * pid 1 has dm2=1 & htn=1, pid 2 has dm2=0 & htn=1
    * C[1,2] = patients where dm2=1 AND htn=1 = 1
    assert C[1,2] == 1
    assert C[2,1] == 1
    * Symmetry
    assert C[1,2] == C[2,1]
}
if _rc == 0 {
    display as result "  PASS: Merge with cooccurrence"
    local ++pass_count
}
else {
    display as error "  FAIL: Merge with cooccurrence (error `=_rc')"
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
_codescan_qa_publish "test_codescan_edge_cases" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_codescan_edge_cases tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
