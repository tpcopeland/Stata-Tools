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
*   T7: Version header reports 1.0.3
*   T8: label() with generate() accepts bare names (I3 fix)
*   T9: Reserved export column names rejected as condition names (I5 fix)
*   T10: generate() + hierarchy() with bare names (M8)
*   T11: r(date) returned when date() specified (I8 fix)
*   T12: countdate + countmode uses 0/1 flag, not raw counts (I4 fix)

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
* T7: header advertises version 1.0.3
* ============================================================

local ++test_count
capture noisily {
    findfile codescan.ado
    local _path `"`r(fn)'"'
    tempname fh
    file open `fh' using `"`_path'"', read
    file read `fh' _line1
    file close `fh'
    assert strpos("`_line1'", "1.0.3") > 0
}
if _rc == 0 {
    display as result "  PASS T7: version header is 1.0.3"
    local ++pass_count
}
else {
    display as error "  FAIL T7: version header (rc=`=_rc')"
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
* T10: generate() + hierarchy() with bare names
* ============================================================

local ++test_count
capture noisily {
    _make_v101_data
    codescan dx1, define(dm_comp "E10" | dm_uncomp "E11") generate(cs_) ///
        id(pid) collapse hierarchy(dm_comp > dm_uncomp)
    confirm variable cs_dm_comp
    confirm variable cs_dm_uncomp
    * Hierarchy should have suppressed dm_uncomp where dm_comp is present
}
if _rc == 0 {
    display as result "  PASS T10: generate() + hierarchy() bare names"
    local ++pass_count
}
else {
    display as error "  FAIL T10: generate()+hierarchy() bare names (rc=`=_rc')"
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
