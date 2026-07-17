* test_codescan_functional.do - Extended functional tests for codescan
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

**# Expanded Functional Tests

**## alldates shorthand creates all three date variables
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse alldates
    confirm variable dm2_first
    confirm variable dm2_last
    confirm variable dm2_count
    assert dm2_first == mdy(6, 15, 2019) if pid == 1
    assert dm2_last == mdy(1, 1, 2020) if pid == 1
    assert dm2_count == 2 if pid == 1
}
if _rc == 0 {
    display as result "  PASS: alldates shorthand creates _first, _last, _count"
    local ++pass_count
}
else {
    display as error "  FAIL: alldates shorthand (error `=_rc')"
    local ++fail_count
}

**## detail option returns varcounts matrix
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") detail replace
    matrix V = r(varcounts)
    assert rowsof(V) == 2
    assert colsof(V) == 3
    * dm2 matches in dx1 (rows 1,3,11) and dx2 (rows 1 col E660 no, 14 col E111 yes)
    * All match counts should be non-negative
    forvalues i = 1/2 {
        forvalues j = 1/3 {
            assert V[`i',`j'] >= 0
        }
    }
    * Total matches across vars should equal summary count
    matrix S = r(summary)
    assert V[1,1] + V[1,2] + V[1,3] == S[1,1]
}
if _rc == 0 {
    display as result "  PASS: detail returns varcounts with correct dimensions"
    local ++pass_count
}
else {
    display as error "  FAIL: detail varcounts (error `=_rc')"
    local ++fail_count
}

**## countmode at row level (not collapsed)
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3
    "E110" "E119" "E11"
    "E110" ""     ""
    "Z00"  ""     ""
    end
    codescan dx1-dx3, define(dm2 "E11") countmode
    * Row 1: 3 matching variables → count=3
    assert dm2 == 3 in 1
    * Row 2: 1 matching variable → count=1
    assert dm2 == 1 in 2
    * Row 3: 0 matching variables → count=0
    assert dm2 == 0 in 3
    assert r(mode_count) == 1
}
if _rc == 0 {
    display as result "  PASS: countmode row-level counts matching vars"
    local ++pass_count
}
else {
    display as error "  FAIL: countmode row-level (error `=_rc')"
    local ++fail_count
}

**## Exclusion patterns in prefix mode
local ++test_count
capture noisily {
    clear
    input str10 dx1
    "E110"
    "E116"
    "E119"
    "Z00"
    end
    codescan dx1, define(dm2 "E11" ~ "E116") mode(prefix)
    assert dm2 == 1 in 1
    assert dm2 == 0 in 2
    assert dm2 == 1 in 3
    assert dm2 == 0 in 4
}
if _rc == 0 {
    display as result "  PASS: Exclusion patterns in prefix mode"
    local ++pass_count
}
else {
    display as error "  FAIL: Exclusion in prefix mode (error `=_rc')"
    local ++fail_count
}

**## Multiple exclusion patterns
local ++test_count
capture noisily {
    clear
    input str10 dx1
    "E110"
    "E112"
    "E116"
    "E119"
    end
    codescan dx1, define(dm2 "E11" ~ "E116" ~ "E112")
    assert dm2 == 1 in 1
    assert dm2 == 0 in 2
    assert dm2 == 0 in 3
    assert dm2 == 1 in 4
}
if _rc == 0 {
    display as result "  PASS: Multiple exclusion patterns"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple exclusion patterns (error `=_rc')"
    local ++fail_count
}

**## nocase combined with nodots
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str10 dx1 = ""
    replace dx1 = "e11.0" in 1
    replace dx1 = "E11.9" in 2
    replace dx1 = "z00" in 3
    codescan dx1, define(dm2 "E110|E119") nocase nodots
    assert dm2 == 1 in 1
    assert dm2 == 1 in 2
    assert dm2 == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: nocase + nodots combined"
    local ++pass_count
}
else {
    display as error "  FAIL: nocase + nodots combined (error `=_rc')"
    local ++fail_count
}

**## Codefile DTA format
local ++test_count
capture noisily {
    preserve
    clear
    input str10 name str20 pattern str10 exclusion str30 label
    "dm2" "E11" "E116" "Type 2 Diabetes"
    "htn" "I1[0-35]" "" "Hypertension"
    end
    save "_cs_test_dta.dta", replace
    restore
    _make_test_data
    codescan dx1-dx3, codefile("_cs_test_dta.dta") replace
    assert r(n_conditions) == 2
    confirm variable dm2
    confirm variable htn
    * Check exclusion applied: no row should have E116 match
    * Test data doesn't contain E116, but dm2 still works
    assert dm2 == 1 if _n == 1
}
if _rc == 0 {
    display as result "  PASS: Codefile DTA format with exclusion"
    local ++pass_count
}
else {
    display as error "  FAIL: Codefile DTA format (error `=_rc')"
    local ++fail_count
}

**## Merge with time window
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(365) inclusive merge replace
    * Row count preserved
    assert _N == 20
    * Patient 1: dm2 found in lookback window → broadcast to all rows
    assert dm2 == 1 if pid == 1
    * Patient 5: no match → 0
    assert dm2 == 0 if pid == 5
}
if _rc == 0 {
    display as result "  PASS: Merge with time window"
    local ++pass_count
}
else {
    display as error "  FAIL: Merge with time window (error `=_rc')"
    local ++fail_count
}

**## Merge preserves sort order
local ++test_count
capture noisily {
    _make_test_data
    gen long _rowid = _n
    codescan dx1-dx3, define(dm2 "E11") id(pid) merge replace
    * Verify sort order preserved
    assert _rowid[1] == 1
    assert _rowid[_N] == 20
    forvalues i = 1/20 {
        assert _rowid[`i'] == `i'
    }
    drop _rowid
}
if _rc == 0 {
    display as result "  PASS: Merge preserves sort order"
    local ++pass_count
}
else {
    display as error "  FAIL: Merge preserves sort order (error `=_rc')"
    local ++fail_count
}

**## Merge with date summaries broadcast correctly
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) merge ///
        earliestdate latestdate countdate replace
    * All 4 rows of patient 1 should have same first/last/count
    forvalues i = 1/4 {
        assert dm2_first[`i'] == mdy(6, 15, 2019)
        assert dm2_last[`i'] == mdy(1, 1, 2020)
        assert dm2_count[`i'] == 2
    }
    * Patient 5 rows: all missing first/last, count=0
    forvalues i = 17/20 {
        assert missing(dm2_first[`i'])
        assert dm2_count[`i'] == 0
    }
}
if _rc == 0 {
    display as result "  PASS: Merge date summaries broadcast to all rows"
    local ++pass_count
}
else {
    display as error "  FAIL: Merge date summaries broadcast (error `=_rc')"
    local ++fail_count
}

**## save() preserves exclusion patterns
local ++test_count
capture noisily {
    _make_test_data
    capture erase "_cs_excl_save.csv"
    codescan dx1-dx3, define(dm2 "E11" ~ "E116" | htn "I1[0-35]") ///
        replace save("_cs_excl_save.csv")
    preserve
    import delimited using "_cs_excl_save.csv", clear
    assert _N == 2
    assert name[1] == "dm2"
    assert exclusion[1] == "E116"
    assert exclusion[2] == ""
    restore
}
if _rc == 0 {
    display as result "  PASS: save() preserves exclusion patterns"
    local ++pass_count
}
else {
    display as error "  FAIL: save() preserves exclusions (error `=_rc')"
    local ++fail_count
}

**## r(define) macro returned
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") replace
    assert `"`r(define)'"' != ""
}
if _rc == 0 {
    display as result "  PASS: r(define) macro returned"
    local ++pass_count
}
else {
    display as error "  FAIL: r(define) macro (error `=_rc')"
    local ++fail_count
}

**## r(codefile) macro returned
local ++test_count
capture noisily {
    preserve
    clear
    set obs 1
    gen str32 name = "dm2"
    gen str32 pattern = "E11"
    export delimited using "_cs_test_rmacro.csv", replace
    restore
    _make_test_data
    codescan dx1-dx3, codefile("_cs_test_rmacro.csv") replace
    assert "`r(codefile)'" == "_cs_test_rmacro.csv"
}
if _rc == 0 {
    display as result "  PASS: r(codefile) macro returned"
    local ++pass_count
}
else {
    display as error "  FAIL: r(codefile) macro (error `=_rc')"
    local ++fail_count
}

**## Co-occurrence with collapse
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        id(pid) collapse cooccurrence replace
    matrix C = r(cooccurrence)
    assert rowsof(C) == 2
    assert colsof(C) == 2
    * After collapse: patient-level co-occurrence
    * Patient 1 has both dm2=1 and htn=1 → co-occur
    * Patient 3 has both dm2=1 and htn=0 → no co-occur for dm2/htn
    assert el(C, 1, 2) >= 1
}
if _rc == 0 {
    display as result "  PASS: Co-occurrence with collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: Co-occurrence with collapse (error `=_rc')"
    local ++fail_count
}

**## Condition name exactly 26 characters (boundary)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(abcdefghijklmnopqrstuvwxyz "E11") replace
    confirm variable abcdefghijklmnopqrstuvwxyz
}
if _rc == 0 {
    display as result "  PASS: Condition name exactly 26 chars accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: Condition name 26 chars (error `=_rc')"
    local ++fail_count
}

**## Data preservation: variable names, types, values
local ++test_count
capture noisily {
    _make_test_data
    local orig_N = _N
    local orig_dx1_1 = dx1[1]
    local orig_pid_type : type pid
    local orig_sortorder = pid[1]
    gen long _preserve_check = _n

    codescan dx1-dx3, define(dm2 "E11") replace

    assert _N == `orig_N'
    assert dx1[1] == "`orig_dx1_1'"
    assert "`: type pid'" == "`orig_pid_type'"
    * Sort preserved
    assert _preserve_check[1] == 1
    assert _preserve_check[_N] == `orig_N'
    drop _preserve_check
}
if _rc == 0 {
    display as result "  PASS: Data preservation (names, types, values, sort)"
    local ++pass_count
}
else {
    display as error "  FAIL: Data preservation (error `=_rc')"
    local ++fail_count
}

**## Cleanup on error: partial variables dropped
local ++test_count
capture noisily {
    _make_test_data
    * Force an error mid-execution by using conflicting condition name for second
    * condition while first would succeed — test that first indicator is cleaned up
    capture codescan dx1-dx3, define(dm2 "E11" | pid "I10") id(pid) collapse
    assert _rc == 198
    * dm2 should NOT exist in dataset (cleaned up after error)
    capture confirm variable dm2
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Cleanup on error drops partial variables"
    local ++pass_count
}
else {
    display as error "  FAIL: Cleanup on error (error `=_rc')"
    local ++fail_count
}

**## Lookback(0) without inclusive yields error 2000 (empty window)
local ++test_count
capture noisily {
    _make_test_data
    * lookback(0) without inclusive = [refdate, refdate) = empty window → error 2000
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookback(0) replace
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: lookback(0) without inclusive → error 2000"
    local ++pass_count
}
else {
    display as error "  FAIL: lookback(0) empty window (error `=_rc')"
    local ++fail_count
}

**## Lookforward(0) inclusive matches refdate only
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookforward(0) inclusive replace
    * Only refdate (2020-01-01) included → rows on that exact date
    * Row 3 (patient 1, visit_dt=2020-01-01, dx1=E119): match
    assert dm2 == 1 if _n == 3
    * Row 1 (patient 1, visit_dt=2019-06-15): outside
    assert dm2 == 0 if _n == 1
}
if _rc == 0 {
    display as result "  PASS: lookforward(0) inclusive matches refdate only"
    local ++pass_count
}
else {
    display as error "  FAIL: lookforward(0) inclusive (error `=_rc')"
    local ++fail_count
}

**## Multi-window with 3 windows
local ++test_count
capture noisily {
    * Need data where even the narrowest window has observations
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21900 21915
    1 "Z00"  21910 21915
    2 "E110" 21880 21915
    2 "Z00"  21914 21915
    3 "Z00"  21910 21915
    end
    format visit_dt index_dt %td
    * 30-day lookback from 21915: [21885, 21915)
    * 90-day lookback from 21915: [21825, 21915)
    * 365-day lookback from 21915: [21550, 21915)
    * Day 21900 is within all 3. Day 21880 within 90 and 365.
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(30 90 365) collapse replace
    matrix S = r(sensitivity)
    assert rowsof(S) == 1
    assert colsof(S) == 3
    * Wider windows should have >= prevalence of narrower
    assert S[1,3] >= S[1,2]
    assert S[1,2] >= S[1,1]
}
if _rc == 0 {
    display as result "  PASS: Multi-window with 3 lookback values"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-window 3 values (error `=_rc')"
    local ++fail_count
}

**## Unmatched without collapse (row-level flag)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") unmatched(nomatch) replace
    confirm variable nomatch
    * Row 17 (patient 5): no match → nomatch=1
    assert nomatch == 1 if _n == 17
    * Row 1 (patient 1): has E110 → nomatch=0
    assert nomatch == 0 if _n == 1
    * Row 4 (J45, no match): nomatch=1
    assert nomatch == 1 if _n == 4
}
if _rc == 0 {
    display as result "  PASS: Unmatched row-level flag"
    local ++pass_count
}
else {
    display as error "  FAIL: Unmatched row-level (error `=_rc')"
    local ++fail_count
}

**## Matched_code with prefix mode
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I10|I13") mode(prefix) ///
        matched_code(mc) replace
    assert mc[1] == "E110"
    assert mc[5] == "I10"
    assert mc[17] == ""
}
if _rc == 0 {
    display as result "  PASS: matched_code with prefix mode"
    local ++pass_count
}
else {
    display as error "  FAIL: matched_code prefix mode (error `=_rc')"
    local ++fail_count
}

**## Replace with collapse + date variables
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse ///
        earliestdate latestdate countdate
    * Run again with different define — replace should drop old vars
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse ///
        earliestdate latestdate countdate replace
    confirm variable dm2
    confirm variable dm2_first
    confirm variable dm2_last
    confirm variable dm2_count
}
if _rc == 0 {
    display as result "  PASS: Replace with collapse + date variables"
    local ++pass_count
}
else {
    display as error "  FAIL: Replace with collapse + date vars (error `=_rc')"
    local ++fail_count
}

**## Generate prefix with unmatched and matched_code
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") generate(dx_) ///
        unmatched(nomatch) matched_code(mc) replace
    confirm variable dx_dm2
    confirm variable nomatch
    confirm variable mc
    assert dx_dm2 == 1 if _n == 1
    assert nomatch == 1 if _n == 17
}
if _rc == 0 {
    display as result "  PASS: generate prefix with unmatched and matched_code"
    local ++pass_count
}
else {
    display as error "  FAIL: generate + unmatched + matched_code (error `=_rc')"
    local ++fail_count
}

**## Tostring preserves original variables as numeric
local ++test_count
capture noisily {
    clear
    set obs 5
    gen long pid = _n
    gen double dx1 = .
    gen double dx2 = .
    replace dx1 = 110 in 1
    replace dx1 = 660 in 2
    replace dx2 = 119 in 3
    clonevar expected_dx1 = dx1
    clonevar expected_dx2 = dx2
    local type_dx1 : type dx1
    local type_dx2 : type dx2
    codescan dx1 dx2, define(dm2 "11") tostring
    * Indicators created correctly
    assert dm2 == 1 in 1
    assert dm2 == 0 in 2
    assert dm2 == 1 in 3
    * Original numeric variables and storage types are unchanged.
    assert dx1 == expected_dx1
    assert dx2 == expected_dx2
    local after_dx1 : type dx1
    local after_dx2 : type dx2
    assert "`type_dx1'" == "`after_dx1'"
    assert "`type_dx2'" == "`after_dx2'"
}
if _rc == 0 {
    display as result "  PASS: Tostring scans without mutating inputs"
    local ++pass_count
}
else {
    display as error "  FAIL: Tostring conversion (error `=_rc')"
    local ++fail_count
}

**## Level() ignored in regex mode (no error)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") mode(regex) level(2) replace
    * Level only applies to prefix; in regex mode it's accepted but ignored
    assert dm2 == 1 if _n == 1
}
if _rc == 0 {
    display as result "  PASS: level() silently accepted in regex mode"
    local ++pass_count
}
else {
    display as error "  FAIL: level() in regex mode (error `=_rc')"
    local ++fail_count
}

**## Codescan_describe save() with nodots
local ++test_count
capture noisily {
    clear
    set obs 5
    gen str10 dx1 = ""
    replace dx1 = "E11.0" in 1
    replace dx1 = "I10.1" in 2
    replace dx1 = "Z00" in 3
    replace dx1 = "E11.0" in 4
    replace dx1 = "I10.1" in 5
    capture erase "_cs_desc_nd.csv"
    codescan_describe dx1, nodots save("_cs_desc_nd.csv")
    confirm file "_cs_desc_nd.csv"
    assert r(n_vars) == 1
}
if _rc == 0 {
    display as result "  PASS: codescan_describe save with nodots"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe save + nodots (error `=_rc')"
    local ++fail_count
}

**## Large condition count (15 conditions)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define( ///
        c01 "E11" | c02 "E66" | c03 "I10" | c04 "I13" | c05 "I21" | ///
        c06 "I25" | c07 "F32" | c08 "F33" | c09 "J45" | c10 "K21" | ///
        c11 "Z00" | c12 "Z01" | c13 "Z02" | c14 "Z03" | c15 "Q99") replace
    assert r(n_conditions) == 15
    confirm variable c01
    confirm variable c15
    matrix S = r(summary)
    assert rowsof(S) == 15
}
if _rc == 0 {
    display as result "  PASS: 15 conditions simultaneously"
    local ++pass_count
}
else {
    display as error "  FAIL: 15 conditions (error `=_rc')"
    local ++fail_count
}

**## Replace on unmatched and matched_code
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") unmatched(nomatch) matched_code(mc)
    codescan dx1-dx3, define(dm2 "E11") unmatched(nomatch) matched_code(mc) replace
    confirm variable nomatch
    confirm variable mc
}
if _rc == 0 {
    display as result "  PASS: Replace on unmatched and matched_code"
    local ++pass_count
}
else {
    display as error "  FAIL: Replace unmatched + matched_code (error `=_rc')"
    local ++fail_count
}

**## Merge data preservation — original vars intact, indicators added
local ++test_count
capture noisily {
    _make_test_data
    local orig_N = _N
    local orig_dx1_1 = dx1[1]
    codescan dx1-dx3, define(dm2 "E11") id(pid) merge replace
    * Row count preserved
    assert _N == `orig_N'
    * Original variables still exist
    confirm variable dx1
    confirm variable dx2
    confirm variable dx3
    confirm variable pid
    * Original values unchanged
    assert dx1[1] == "`orig_dx1_1'"
    * Indicator added
    confirm variable dm2
}
if _rc == 0 {
    display as result "  PASS: Merge data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: Merge data preservation (error `=_rc')"
    local ++fail_count
}

**## Codescan_describe with tostring on numeric codes
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double dx1 = .
    replace dx1 = 110 in 1
    replace dx1 = 119 in 2
    replace dx1 = 660 in 3
    replace dx1 = 110 in 4
    codescan_describe dx1, tostring
    assert r(n_unique) > 0
    assert r(n_entries) > 0
}
if _rc == 0 {
    display as result "  PASS: codescan_describe with tostring on numeric"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe tostring numeric (error `=_rc')"
    local ++fail_count
}

**## Codescan_describe error — negative top
local ++test_count
capture noisily {
    _make_test_data
    capture codescan_describe dx1, top(-5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: codescan_describe top(-5) error"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe top(-5) error (error `=_rc')"
    local ++fail_count
}

**## r(nocase) and r(generate) returned correctly
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") nocase generate(dx_) replace
    assert "`r(nocase)'" == "nocase"
    assert "`r(generate)'" == "dx_"
}
if _rc == 0 {
    display as result "  PASS: r(nocase) and r(generate) macros"
    local ++pass_count
}
else {
    display as error "  FAIL: r(nocase) and r(generate) macros (error `=_rc')"
    local ++fail_count
}

**## Error — merge without id
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") merge
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — merge without id (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — merge without id (error `=_rc')"
    local ++fail_count
}

**## Error — merge and collapse both specified
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) merge collapse
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — merge + collapse conflict (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — merge + collapse conflict (error `=_rc')"
    local ++fail_count
}

**## Error — _last variable exists without replace
local ++test_count
capture noisily {
    _make_test_data
    gen double dm2_last = .
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse latestdate
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: Error — _last exists without replace (rc=110)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — _last exists without replace (error `=_rc')"
    local ++fail_count
}

**## Error — _count variable exists without replace
local ++test_count
capture noisily {
    _make_test_data
    gen long dm2_count = 0
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse countdate
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: Error — _count exists without replace (rc=110)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — _count exists without replace (error `=_rc')"
    local ++fail_count
}

**## Error — latestdate without collapse or merge
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) latestdate
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — latestdate without collapse/merge (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — latestdate without collapse/merge (error `=_rc')"
    local ++fail_count
}

**## Error — countdate without collapse or merge
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) countdate
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — countdate without collapse/merge (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — countdate without collapse/merge (error `=_rc')"
    local ++fail_count
}

**## Error — generate prefix too long
local ++test_count
capture noisily {
    _make_test_data
    * prefix "very_long_prefix_" (17) + name "dm2" (3) + "_count" (6) = 26 → OK
    * prefix "extremely_long_prefix_x_" (23) + "dm2" (3) + "_count" (6) = 32 → OK (exactly 32)
    * prefix "extremely_long_prefix_xx_" (24) + "dm2" (3) + "_count" (6) = 33 → FAIL
    capture codescan dx1-dx3, define(dm2 "E11") generate(extremely_long_prefix_xx_)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — generate prefix too long (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — generate prefix too long (error `=_rc')"
    local ++fail_count
}

**## Error — condition name not valid Stata name in define()
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(2bad "E11")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — invalid Stata name in define (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — invalid Stata name in define (error `=_rc')"
    local ++fail_count
}

**## Error — regex unmatched parenthesis
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11(")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — regex unmatched paren (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — regex unmatched paren (error `=_rc')"
    local ++fail_count
}

**## Error — regex unmatched closing parenthesis
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11)")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — regex unmatched closing paren (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — regex unmatched closing paren (error `=_rc')"
    local ++fail_count
}

**## Error — frame name already exists without replace
local ++test_count
capture noisily {
    _make_test_data
    capture frame drop _test_fr
    frame create _test_fr
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) collapse frame(_test_fr)
    local rc1 = _rc
    capture frame drop _test_fr
    assert `rc1' == 110
}
if _rc == 0 {
    display as result "  PASS: Error — frame exists without replace (rc=110)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — frame exists without replace (error `=_rc')"
    local ++fail_count
}

**## Error — frame invalid name
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) collapse frame(123bad)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — frame invalid name (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — frame invalid name (error `=_rc')"
    local ++fail_count
}

**## Error — codescan_describe save() non-csv
local ++test_count
capture noisily {
    _make_test_data
    capture codescan_describe dx1-dx3, save("test.xlsx")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — describe save() non-csv (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — describe save() non-csv (error `=_rc')"
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
display as result "RESULT: test_codescan_functional tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
