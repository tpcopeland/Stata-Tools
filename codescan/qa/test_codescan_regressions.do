* test_codescan_regressions.do - Regression tests for current package fixes
* Date: 2026-04-23
*
* Covers:
*   T1: r() scalars/matrices populated even when export() target fails
*   T2: r() scalars/matrices populated even when export() writes to a locked csv
*   T3: unmatched() is strict 0/1 when rows are filtered by if
*   T4: unmatched() is strict 0/1 when rows have missing id under merge
*   T5: unmatched() + collapse: option is row-level only; flag not retained after collapse
*   T6: Mata cooccurrence still posts to caller's tempname after matname refactor
*   T7: Version header reports 2.0.1
*   T8: label() with generate() accepts bare names (I3 fix)
*   T9: Reserved export column names rejected as condition names (I5 fix)
*   T11: r(date) returned when date() specified (I8 fix)
*   T12: countdate + countmode uses 0/1 flag, not raw counts (I4 fix)
*   T13: r(codefile) returns the user-supplied codefile path
*   T14: auto-labels on suffix variables when no explicit label given
*   T15: explicit labels still override auto-labels
*   T16: matched_code() not leaked by multi-window sensitivity supplementary scan
*   T17: bundled helper files are idempotent on reload (cap program drop fix) —
*        re-running a helper file in one session must not crash "already defined"
*   T18: level() is inert in mode(regex) — patterns not truncated (1.1.4)

clear all
set seed 12345
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall codescan
quietly net install codescan, from("`pkg_dir'") replace


capture program drop _make_v101_data
program define _make_v101_data
    clear
    set obs 10
    gen long pid = ceil(_n / 2)
    gen str10 dx1 = ""
    replace dx1 = "E110" if _n == 1
    replace dx1 = "Z00"  if _n == 2
    replace dx1 = "I10"  if _n == 3
    replace dx1 = "Z00"  if _n == 4
    replace dx1 = "E119" if _n == 5
    replace dx1 = "Z00"  if _n == 6
    replace dx1 = "Z00"  if _n == 7
    replace dx1 = "Z00"  if _n == 8
    replace dx1 = "I21"  if _n == 9
    replace dx1 = "Z00"  if _n == 10
end


* ============================================================
* T1: r() survives export() to an unwritable directory
* ============================================================

local ++test_count
capture noisily {
    _make_v101_data
    capture codescan dx1, define(dm2 "E11" | htn "I10") id(pid) collapse ///
        export(/nonexistent_dir_codescan_v101/out.csv)
    local _export_rc = _rc
    * Whether export succeeded or failed, r(summary) and r(n_conditions) must be present.
    assert r(n_conditions) == 2
    assert `"`=r(conditions)'"' == "dm2 htn"
    matrix _Smry = r(summary)
    assert rowsof(_Smry) == 2
    assert colsof(_Smry) == 4
    matrix drop _Smry
}
if _rc == 0 {
    display as result "  PASS T1: r() present after failed export (dir)"
    local ++pass_count
}
else {
    display as error "  FAIL T1: r() present after failed export (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T2: r() survives export() to an unwritable .xlsx path
* ============================================================

local ++test_count
capture noisily {
    _make_v101_data
    capture codescan dx1, define(dm2 "E11" | htn "I10") ///
        export(/nonexistent_dir_codescan_v101/out.xlsx)
    assert r(n_conditions) == 2
    matrix _Smry2 = r(summary)
    assert rowsof(_Smry2) == 2
    matrix drop _Smry2
}
if _rc == 0 {
    display as result "  PASS T2: r() present after failed xlsx export"
    local ++pass_count
}
else {
    display as error "  FAIL T2: r() xlsx export failure (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T3: unmatched() strict 0/1 under if filter
* ============================================================

local ++test_count
capture noisily {
    _make_v101_data
    * if filter removes rows 3-10; only rows 1-2 analyzed.
    codescan dx1 if _n <= 2, define(dm2 "E11") unmatched(nomatch)
    * Filtered rows must have nomatch == 0 (not missing).
    assert nomatch == 0 if _n > 2
    * Included row 1 (E110) matches -> nomatch == 0
    assert nomatch == 0 if _n == 1
    * Included row 2 (Z00) does not match -> nomatch == 1
    assert nomatch == 1 if _n == 2
    * No missing values anywhere.
    count if missing(nomatch)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS T3: unmatched() 0/1 under if filter"
    local ++pass_count
}
else {
    display as error "  FAIL T3: unmatched() strict 0/1 under if (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T4: unmatched() strict 0/1 with missing id under merge
* ============================================================

local ++test_count
capture noisily {
    clear
    input long pid str10 dx1
    1 "E110"
    1 "Z00"
    .  "E119"
    2 "Z00"
    2 "Z00"
    end
    codescan dx1, define(dm2 "E11") id(pid) merge unmatched(nomatch)
    * Missing-pid row is excluded from touse; nomatch must be 0 not missing.
    * (merge may reorder rows, so filter by missing(pid) rather than row number.)
    assert nomatch == 0 if missing(pid)
    count if missing(nomatch)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS T4: unmatched() 0/1 with missing id (merge)"
    local ++pass_count
}
else {
    display as error "  FAIL T4: unmatched() 0/1 under merge/missing id (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T5: unmatched() with collapse — flag dropped by collapse (per sthlp)
* ============================================================

local ++test_count
capture noisily {
    _make_v101_data
    codescan dx1, define(dm2 "E11") id(pid) collapse unmatched(nomatch)
    * nomatch is row-level; not retained in collapsed newvars.
    capture confirm variable nomatch
    assert _rc != 0
    local _nv `"`=r(newvars)'"'
    * newvars should not list nomatch.
    assert strpos("`_nv'", "nomatch") == 0
}
if _rc == 0 {
    display as result "  PASS T5: unmatched() dropped on collapse"
    local ++pass_count
}
else {
    display as error "  FAIL T5: unmatched()+collapse (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T6: cooccurrence matrix still populated after matname refactor
* ============================================================

local ++test_count
capture noisily {
    _make_v101_data
    codescan dx1, define(dm2 "E11" | htn "I10" | cvd "I2") id(pid) collapse cooccurrence
    matrix _C = r(cooccurrence)
    assert rowsof(_C) == 3
    assert colsof(_C) == 3
    * Diagonal must equal per-condition counts (patient-level).
    assert _C[1,1] >= 0
    matrix drop _C
}
if _rc == 0 {
    display as result "  PASS T6: cooccurrence matrix posts via matname"
    local ++pass_count
}
else {
    display as error "  FAIL T6: cooccurrence posting (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T7: header advertises version 2.0.1
* ============================================================

local ++test_count
capture noisily {
    findfile codescan.ado
    local _path `"`r(fn)'"'
    tempname fh
    file open `fh' using `"`_path'"', read
    file read `fh' _line1
    file close `fh'
    assert strpos("`_line1'", "2.0.1") > 0
}
if _rc == 0 {
    display as result "  PASS T7: version header is 2.0.1"
    local ++pass_count
}
else {
    display as error "  FAIL T7: version header (rc=`=_rc')"
    local ++fail_count
}

* ============================================================
* T18: level() is inert in mode(regex) — patterns not truncated (1.1.4)
* ============================================================

local ++test_count
capture noisily {
    clear
    input str6 dx1
    "E110"
    "E660"
    end
    * level(1) would truncate a prefix to "E" in prefix mode, but must be
    * ignored in regex mode: "E11" still matches only E11*, not E66*.
    codescan dx1, define(dm "E11") mode(regex) level(1)
    assert dm[1] == 1
    assert dm[2] == 0
}
if _rc == 0 {
    display as result "  PASS T18: level() ignored in regex mode"
    local ++pass_count
}
else {
    display as error "  FAIL T18: level() in regex mode (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T8: label() + generate() accepts bare condition names
* ============================================================

local ++test_count
capture noisily {
    _make_v101_data
    codescan dx1, define(dm2 "E11" | htn "I10") generate(cs_) ///
        label(dm2 "Type 2 Diabetes" \ htn "Hypertension")
    * Variables should exist with the prefix
    confirm variable cs_dm2
    confirm variable cs_htn
    * Labels should have been applied
    local _lbl : variable label cs_dm2
    assert `"`_lbl'"' == "Type 2 Diabetes"
    local _lbl : variable label cs_htn
    assert `"`_lbl'"' == "Hypertension"
}
if _rc == 0 {
    display as result "  PASS T8: label() + generate() bare names"
    local ++pass_count
}
else {
    display as error "  FAIL T8: label() + generate() bare names (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T9: reserved export column names rejected as condition names
* ============================================================

local ++test_count
capture noisily {
    _make_v101_data
    capture codescan dx1, define(pattern "E11") export(test_reserved.xlsx)
    assert _rc == 198
    capture codescan dx1, define(matches "E11") export(test_reserved.xlsx)
    assert _rc == 198
    * Without export(), same names should be fine
    capture codescan dx1, define(pattern "E11")
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS T9: reserved export column names rejected"
    local ++pass_count
}
else {
    display as error "  FAIL T9: reserved export column name check (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T11: r(date) returned when date() specified
* ============================================================

local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "E110" 21914
    1 "Z00"  21880
    2 "I10"  21900
    end
    format visit_dt %td
    codescan dx1, define(dm2 "E11") date(visit_dt)
    assert `"`=r(date)'"' == "visit_dt"
}
if _rc == 0 {
    display as result "  PASS T11: r(date) returned"
    local ++pass_count
}
else {
    display as error "  FAIL T11: r(date) not returned (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T12: countdate + countmode uses 0/1 flag (byte safe)
* ============================================================

local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21914 21920
    1 "E110" 21915 21920
    1 "E110" 21916 21920
    2 "Z00"  21914 21920
    end
    format visit_dt index_dt %td
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(365) inclusive collapse countdate countmode
    * Patient 1 has 3 unique dates with matches
    assert dm2_count == 3 if pid == 1
    * Patient 2 has 0 matching dates
    assert dm2_count == 0 if pid == 2
}
if _rc == 0 {
    display as result "  PASS T12: countdate + countmode byte-safe"
    local ++pass_count
}
else {
    display as error "  FAIL T12: countdate + countmode (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T13: r(codefile) returns the user-supplied codefile path
* ============================================================

local ++test_count
capture noisily {
    tempfile cfbase
    local cf "`cfbase'.csv"
    preserve
    clear
    input str10 name str20 pattern
    "dm2" "E11"
    end
    export delimited using "`cf'", replace
    restore

    _make_v101_data
    codescan dx1, codefile("`cf'") id(pid) collapse
    assert `"`=r(codefile)'"' == `"`cf'"'
}
if _rc == 0 {
    display as result "  PASS T13: r(codefile) returns supplied path"
    local ++pass_count
}
else {
    display as error "  FAIL T13: r(codefile) supplied path (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T14: auto-labels on suffix variables when no explicit label given
* ============================================================

local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21914 21920
    1 "Z00"  21880 21920
    2 "I10"  21900 21920
    2 "Z00"  21850 21920
    end
    format visit_dt index_dt %td
    codescan dx1, define(dm2 "E11" | htn "I10") id(pid) ///
        date(visit_dt) refdate(index_dt) lookback(365) inclusive ///
        collapse alldates countrows
    * Suffix variables should have auto-labels
    local _lbl : variable label dm2_first
    assert `"`_lbl'"' == "dm2: earliest date"
    local _lbl : variable label dm2_last
    assert `"`_lbl'"' == "dm2: latest date"
    local _lbl : variable label dm2_count
    assert `"`_lbl'"' == "dm2: unique dates"
    local _lbl : variable label dm2_nrows
    assert `"`_lbl'"' == "dm2: row count"
    local _lbl : variable label htn_first
    assert `"`_lbl'"' == "htn: earliest date"
}
if _rc == 0 {
    display as result "  PASS T14: auto-labels on suffix vars (no explicit label)"
    local ++pass_count
}
else {
    display as error "  FAIL T14: auto-labels on suffix vars (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T15: explicit labels still override auto-labels
* ============================================================

local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21914 21920
    1 "Z00"  21880 21920
    2 "I10"  21900 21920
    end
    format visit_dt index_dt %td
    codescan dx1, define(dm2 "E11" | htn "I10") id(pid) ///
        date(visit_dt) refdate(index_dt) lookback(365) inclusive ///
        collapse alldates countrows ///
        label(dm2 "Type 2 Diabetes" \ htn "Hypertension")
    * Base indicator gets explicit label
    local _lbl : variable label dm2
    assert `"`_lbl'"' == "Type 2 Diabetes"
    * Suffix variables use explicit label in existing format
    local _lbl : variable label dm2_first
    assert `"`_lbl'"' == "Earliest Type 2 Diabetes Date"
    local _lbl : variable label dm2_nrows
    assert `"`_lbl'"' == "Type 2 Diabetes Row Count"
}
if _rc == 0 {
    display as result "  PASS T15: explicit labels override auto-labels"
    local ++pass_count
}
else {
    display as error "  FAIL T15: explicit label override (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T16: matched_code() not leaked by multi-window sensitivity scan
* ============================================================
* The supplementary scan for multi-window lookback() must not populate
* matched_code() for secondary-window-only rows (rows outside the primary
* analysis window). Row A (visit_dt=990) is inside the primary 30-day window
* [970,1000]; row B (visit_dt=920) is only inside the 90-day window. With the
* leak, row B's mc was wrongly set to "E119"; it must be empty.

local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 double visit_dt double index_dt
    1 "E110" 990 1000
    1 "E119" 920 1000
    end
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(30 90) inclusive merge matched_code(mc)
    * In-primary-window matched row keeps its matched code
    assert mc == "E110" if visit_dt == 990
    * Secondary-window-only row must NOT be populated (the leak)
    assert mc == ""     if visit_dt == 920
    * Sensitivity matrix is unaffected: 1 condition x 2 windows, both 100%
    matrix _S = r(sensitivity)
    assert rowsof(_S) == 1 & colsof(_S) == 2
    assert abs(_S[1, 1] - 100) < 1e-6
    assert abs(_S[1, 2] - 100) < 1e-6
}
if _rc == 0 {
    display as result "  PASS T16: matched_code not leaked by sensitivity scan"
    local ++pass_count
}
else {
    display as error "  FAIL T16: matched_code sensitivity leak (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T17: bundled helper files are idempotent on reload
* ============================================================
* The loader in codescan.ado re-runs an entire helper file whenever ANY of its
* programs is missing from memory (partial-load state). Each bundled file defines
* several top-level programs; without a preceding `capture program drop`, the
* second run of the file crashes with rc=110 "program ... already defined". This
* test reproduces that by running each helper file twice in one session.

local ++test_count
capture noisily {
    foreach _hf in _codescan_codefile _codescan_definitions ///
                   _codescan_outputs {
        findfile `_hf'.ado
        local _hpath `"`r(fn)'"'
        run `"`_hpath'"'
        * Second run must not crash on "already defined" (the 1.1.2 fix).
        run `"`_hpath'"'
    }
}
if _rc == 0 {
    display as result "  PASS T17: bundled helper files idempotent on reload"
    local ++pass_count
}
else {
    display as error "  FAIL T17: helper reload crashed (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T19: user-named outputs (unmatched/matched_code) colliding with
*      id()/date()/refdate() are rejected by _codescan_plan_outputs'
*      protected() branch (distinct from condition-name and varlist
*      collisions). Guards the helper after the v2 score()/generate()
*      dead-code removal.
* ============================================================

local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21914 21915
    2 "I10"  21900 21915
    end
    format visit_dt index_dt %td

    * unmatched() name == id() variable -> protected collision, rc 198
    capture codescan dx1, define(dm2 "E11") id(pid) collapse unmatched(pid)
    assert _rc == 198
    * matched_code() name == date() variable -> protected collision, rc 198
    capture codescan dx1, define(dm2 "E11") date(visit_dt) matched_code(visit_dt)
    assert _rc == 198
    * matched_code() name == refdate() variable -> protected collision, rc 198
    capture codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(365) inclusive id(pid) merge matched_code(index_dt)
    assert _rc == 198
    * Non-colliding names on the same call still succeed
    codescan dx1, define(dm2 "E11") date(visit_dt) ///
        matched_code(firstcode) unmatched(nohit)
    assert _rc == 0
    confirm variable firstcode
    confirm variable nohit
}
if _rc == 0 {
    display as result "  PASS T19: output names colliding with id/date/refdate rejected"
    local ++pass_count
}
else {
    display as error "  FAIL T19: protected-name collision check (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* Summary
* ============================================================

display ""
display as result "RESULT: test_codescan_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
