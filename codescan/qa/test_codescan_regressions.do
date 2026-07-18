* test_codescan_regressions.do - Regression tests for current package fixes
* Date: 2026-04-23
*
* Covers:
*   T1: r() scalars/matrices populated even when export() target fails
*   T2: r() scalars/matrices populated even when export() writes to a locked csv
*   T3: unmatched() marks rows filtered out by if as missing, not 0 (I4, 3.0.0)
*   T4: unmatched() marks a missing-id row under merge as missing, not 0 (I4)
*   T5: unmatched() + collapse: option is row-level only; flag not retained after collapse
*   T6: Mata cooccurrence still posts to caller's tempname after matname refactor
*   T7: the .ado version header agrees with the flagship help version
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
*   T20: countmode+merge screens merged-in missing counts from the summary (2.0.6)
*   T21: strL scan variables rejected up front with rc 109 in both commands (2.0.6)
*   T22: r() survives saving() to an unwritable path (return-before-side-effect)
*   T23: graph tempfile round-trip leaves r() populated and restores indicators
*   T24: empty alternation branch (E11|, |E11, E11||E12, (E11|)) rejected 198 (2.0.7)
*   T25: duplicate/overlapping varlist rejected 198 in both commands (2.0.7)
*   T32: saving()+merge writes no internal tempvars (4.0.1, audit F1)
*   T33: codescan self-heals after mata: mata clear (4.0.1, audit F7)
*   T34: case-variant duplicate condition/output/codefile names rejected (4.0.1, F10)
*   T35: datetime %tc date()/refdate() rejected 198 with a clear hint (4.0.1, F11)
*   T36: merge marks a fully-excluded id as . not 0 (4.0.1 doc, audit F8)
*   T37: reloaded regex validator still rejects invalid patterns post-clear (F7)

clear all
set seed 12345
version 16.0
set varabbrev off

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

* The export target lives under a uniquely named directory that is never
* created, so the failure is owned by this suite and cannot be satisfied by
* residue from an earlier run.
local _nodir "`c(tmpdir)'/cs_regr_absent_`=strofreal(runiformint(1, 999999999))'"
capture confirm file "`_nodir'/out.csv"
assert _rc != 0

local ++test_count
capture noisily {
    _make_v101_data
    * Baseline for the r() surface, taken from a run that writes nowhere.
    codescan dx1, define(dm2 "E11" | htn "I10") id(pid) collapse
    matrix _SmryOK = r(summary)
    local _condsOK `"`r(conditions)'"'
    local _nOK = r(n_conditions)
    tempfile _dataOK
    quietly save `_dataOK'

    _make_v101_data
    capture codescan dx1, define(dm2 "E11" | htn "I10") id(pid) collapse ///
        export("`_nodir'/out.csv")
    local _export_rc = _rc
    * The export must actually fail — without this the test passes on a build
    * that silently writes the file, or one that ignores export() entirely.
    assert `_export_rc' == 603
    capture confirm file "`_nodir'/out.csv"
    assert _rc == 601

    * The analytical payload must survive the failed side effect intact, and
    * must equal what the same scan returns when no export is requested.
    assert r(n_conditions) == `_nOK'
    assert `"`r(conditions)'"' == `"`_condsOK'"'
    matrix _Smry = r(summary)
    assert rowsof(_Smry) == 2
    assert colsof(_Smry) == 4
    assert mreldif(_Smry, _SmryOK) < 1e-12
    matrix drop _Smry _SmryOK

    * ...and the data left in memory must be the collapsed result, unchanged.
    cf _all using `_dataOK'
}
if _rc == 0 {
    display as result "  PASS T1: r() present after unwritable export path"
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
    codescan dx1, define(dm2 "E11" | htn "I10")
    matrix _Smry2OK = r(summary)
    local _n2OK = r(n_conditions)

    _make_v101_data
    capture codescan dx1, define(dm2 "E11" | htn "I10") ///
        export("`_nodir'/out.xlsx")
    assert _rc == 603
    capture confirm file "`_nodir'/out.xlsx"
    assert _rc == 601

    assert r(n_conditions) == `_n2OK'
    matrix _Smry2 = r(summary)
    assert rowsof(_Smry2) == 2
    assert mreldif(_Smry2, _Smry2OK) < 1e-12
    matrix drop _Smry2 _Smry2OK
}
if _rc == 0 {
    display as result "  PASS T2: r() present after unwritable xlsx export"
    local ++pass_count
}
else {
    display as error "  FAIL T2: r() xlsx export failure (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T3: unmatched() marks non-analyzed rows missing under an if filter (I4)
* ============================================================
* v3.0.0 contract: 1 = analyzed, nothing matched; 0 = analyzed, something
* matched; . = not analyzed. This test previously asserted the opposite — that a
* filtered-out row carried 0, i.e. was indistinguishable from a row that
* genuinely matched. That was the I4 defect, asserted as if it were the contract.

local ++test_count
capture noisily {
    _make_v101_data
    * if filter removes rows 3-10; only rows 1-2 analyzed.
    codescan dx1 if _n <= 2, define(dm2 "E11") unmatched(nomatch)
    * Rows outside the analysis sample are missing, NOT 0.
    assert missing(nomatch) if _n > 2
    * Included row 1 (E110) matches -> nomatch == 0
    assert nomatch == 0 if _n == 1
    * Included row 2 (Z00) does not match -> nomatch == 1
    assert nomatch == 1 if _n == 2
    * Exactly the filtered rows are missing.
    count if missing(nomatch)
    assert r(N) == 8
}
if _rc == 0 {
    display as result "  PASS T3: unmatched() marks non-analyzed rows missing under if"
    local ++pass_count
}
else {
    display as error "  FAIL T3: unmatched() analysis-sample semantics under if (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T4: unmatched() marks a missing-id row missing under merge (I4)
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
    * The missing-pid row is excluded from touse, so it is NOT analyzed and must
    * be missing -- not 0, which would claim a condition matched it.
    * (merge may reorder rows, so filter by missing(pid) rather than row number.)
    assert missing(nomatch) if missing(pid)
    * Exactly one row was excluded; every analyzed row has a real 0/1.
    count if missing(nomatch)
    assert r(N) == 1
    count if !missing(pid) & missing(nomatch)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS T4: unmatched() marks missing-id row missing (merge)"
    local ++pass_count
}
else {
    display as error "  FAIL T4: unmatched() analysis-sample semantics under merge (rc=`=_rc')"
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
    * _make_v101_data cannot test this: no patient there carries two
    * conditions, so its co-occurrence matrix is diagonal and every
    * off-diagonal cell is structurally zero. Use data with real overlap.
    clear
    input long pid str10 dx1 str10 dx2
    1 "E110" "I10"
    2 "E119" "Z00"
    3 "I10"  "I21"
    4 "Z00"  "Z00"
    5 "E110" "I10"
    5 "I21"  "Z00"
    end
    codescan dx1 dx2, define(dm2 "E11" | htn "I10" | cvd "I2") ///
        id(pid) collapse cooccurrence
    matrix _C = r(cooccurrence)
    assert rowsof(_C) == 3
    assert colsof(_C) == 3
    assert "`: rownames _C'" == "dm2 htn cvd"
    assert "`: colnames _C'" == "dm2 htn cvd"

    * Hand-computed patient-level counts from the six rows above:
    *   dm2 = pids 1,2,5   htn = pids 1,3,5   cvd = pids 3,5
    * Diagonal = per-condition patient count.
    assert _C[1,1] == 3
    assert _C[2,2] == 3
    assert _C[3,3] == 2
    * Off-diagonal = patients carrying BOTH conditions.
    assert _C[2,1] == 2
    assert _C[3,1] == 1
    assert _C[3,2] == 2
    * Co-occurrence counts patients, not rows: pid 5 contributes once to
    * dm2&htn despite matching both on two separate rows.
    assert _C[1,2] == _C[2,1]
    assert _C[1,3] == _C[3,1]
    assert _C[2,3] == _C[3,2]
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
* T7: the .ado header version matches the flagship help version
* ============================================================
* This used to assert a hardcoded literal, which went stale on every release
* (its own section comment still said 2.0.7 while the assert had been bumped to
* 2.0.9). Compare the two surfaces to each other instead: the flagship .sthlp
* owns the package version, and the .ado header must agree with it.

local ++test_count
capture noisily {
    findfile codescan.ado
    local _ado_path `"`r(fn)'"'
    tempname fh
    file open `fh' using `"`_ado_path'"', read
    file read `fh' _line1
    file close `fh'
    assert ustrregexm(`"`macval(_line1)'"', "^\*! codescan Version ([0-9]+\.[0-9]+\.[0-9]+)")
    local _ado_ver = ustrregexs(1)

    findfile codescan.sthlp
    local _help_path `"`r(fn)'"'
    tempname fh2
    file open `fh2' using `"`_help_path'"', read
    file read `fh2' _hline
    local _help_ver ""
    while r(eof) == 0 {
        if ustrregexm(`"`macval(_hline)'"', "^\{\* \*! version ([0-9]+\.[0-9]+\.[0-9]+)") {
            local _help_ver = ustrregexs(1)
            continue, break
        }
        file read `fh2' _hline
    }
    file close `fh2'

    assert "`_help_ver'" != ""
    assert "`_ado_ver'" == "`_help_ver'"
}
if _rc == 0 {
    display as result "  PASS T7: .ado header version matches flagship help version"
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
    * Every column the export dataset creates is reserved (4.0.0: the guard
    * covers all of them, including label/total_hits/positive_units that were
    * added to the export by I3 but were once missing from the guard).
    foreach nm in condition label matches total_hits positive_units prevalence pattern exclusion {
        capture codescan dx1, define(`nm' "E11") export(test_reserved.xlsx)
        assert _rc == 198
    }
    * Without export(), the same names are fine (positive control).
    capture codescan dx1, define(pattern "E11")
    assert _rc == 0
    capture codescan dx1, define(total_hits "E11")
    assert _rc == 0
    * A non-reserved name works WITH export (guard is not over-rejecting).
    capture codescan dx1, define(diabetes "E11") export(test_reserved.xlsx, replace)
    assert _rc == 0
    capture erase test_reserved.xlsx
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
* T20: countmode + merge does not count merged-in missing as a match (2.0.6)
* ============================================================
* A patient whose rows are all excluded (here: by if) comes back from the
* merge with a MISSING count. Missing > 0 is true in Stata, so before the
* fix the summary counted that patient in Obs>0, inflating prevalence.

local ++test_count
capture noisily {
    clear
    input str4 pid str5 dx1 str5 dx2
    "p1" "E11" ""
    "p1" "E11" "E11"
    "p2" "I10" ""
    "p3" "E11" ""
    end
    codescan dx1 dx2 if pid != "p3", define(dm2 "E11") id(pid) merge countmode
    * p3 is excluded: N = 2 patients (p1, p2); only p1 matches
    assert r(N) == 2
    matrix _S = r(summary)
    assert _S[1,1] == 3            // Total: 3 matched slots, all p1
    assert reldif(_S[1,2], 50) < 1e-12   // prevalence 50%, not 100%
    matrix drop _S
    * The merged variable itself: p3 must be missing, not counted
    assert dm2 == . if pid == "p3"
    assert dm2 == 3 if pid == "p1"
    assert dm2 == 0 if pid == "p2"
    drop dm2
}
if _rc == 0 {
    display as result "  PASS T20: countmode+merge screens missing counts from the summary"
    local ++pass_count
}
else {
    display as error "  FAIL T20: countmode+merge missing-count screening (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T21: strL scan variables rejected up front with rc 109 (2.0.6)
* ============================================================
* st_sview() cannot form views onto strL; both commands must reject strL
* with a clear error instead of dying inside Mata with r(3300).

local ++test_count
capture noisily {
    clear
    set obs 4
    gen str4 pid = "p" + string(_n)
    gen strL dxL = cond(mod(_n, 2), "E11", "I10")
    capture codescan dxL, define(dm2 "E11")
    assert _rc == 109
    capture codescan dxL, define(dm2 "E11") tostring
    assert _rc == 109
    capture codescan_describe dxL
    assert _rc == 109
    capture codescan_describe dxL, tostring
    assert _rc == 109
    * Fixed-width strings still scan fine
    gen str5 dx1 = dxL
    codescan dx1, define(dm2 "E11")
    assert r(N) == 4
    drop dm2
}
if _rc == 0 {
    display as result "  PASS T21: strL inputs rejected with rc 109, str# unaffected"
    local ++pass_count
}
else {
    display as error "  FAIL T21: strL rejection (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T22: r() survives saving() to an unwritable path (2.0.6)
* ============================================================
* saving() posts r() before the save side effect and does not touch memory,
* so a failed save must still leave r() and the collapsed dataset intact —
* the same return-before-side-effect contract exercised for export() in T1/T2.

local ++test_count
capture noisily {
    _make_v101_data
    capture codescan dx1, define(dm2 "E11" | htn "I10") id(pid) collapse ///
        saving(/nonexistent_dir_codescan_v101/out.dta, replace)
    local _saving_rc = _rc
    * The save itself must have failed (proves the failure path is exercised).
    assert `_saving_rc' != 0
    * Whether saving succeeded or failed, r() must be present and correct.
    assert r(n_conditions) == 2
    assert r(collapsed) == 1
    assert `"`=r(conditions)'"' == "dm2 htn"
    matrix _SmrySv = r(summary)
    assert rowsof(_SmrySv) == 2
    assert colsof(_SmrySv) == 4
    matrix drop _SmrySv
    * The collapse ran and left patient-level data in memory (5 pids).
    assert _N == 5
}
if _rc == 0 {
    display as result "  PASS T22: r() present after unwritable saving() path"
    local ++pass_count
}
else {
    display as error "  FAIL T22: r() present after failed saving() (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T23: graph tempfile round-trip preserves r() and restores data (2.0.6)
* ============================================================
* The graph block saves the analysis dataset to a tempfile, builds a throwaway
* condition/prevalence dataset to draw the bar chart, then restores. Existing
* graph tests only assert "runs without error"; this guards the round-trip
* post-conditions: r() populated AND the original indicators back in memory
* (not the temporary graph dataset).

local ++test_count
capture noisily {
    _make_v101_data
    quietly count
    local _pre_N = r(N)
    codescan dx1, define(dm2 "E11" | htn "I10") graph
    graph close _all
    * r() survives the graph side effect.
    assert r(n_conditions) == 2
    assert `"`=r(conditions)'"' == "dm2 htn"
    matrix _SmryG = r(summary)
    assert rowsof(_SmryG) == 2
    matrix drop _SmryG
    * Original dataset restored: row count unchanged and indicators present
    * (the transient graph dataset had variables condition/prevalence/order).
    quietly count
    assert r(N) == `_pre_N'
    confirm variable dx1 pid dm2 htn
    capture confirm variable prevalence
    assert _rc != 0
    capture confirm variable condition
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS T23: graph round-trip preserves r() and restores data"
    local ++pass_count
}
else {
    display as error "  FAIL T23: graph round-trip (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T24: empty alternation branch rejected (2.0.7)
*   A stray leading/trailing/doubled | in a regex pattern anchors as
*   ^(...|...) with an empty branch that matches EVERY code — a silent
*   match-everything cohort. Every such form must exit 198 (pattern and
*   exclusion), while well-formed alternations, a literal | inside a class,
*   and an escaped \| must still be accepted and match correctly.
* ============================================================

local ++test_count
capture noisily {
    clear
    set obs 3
    gen str6 dx1 = "E11" in 1
    replace dx1 = "Z00" in 2
    replace dx1 = "I10" in 3

    * Every empty-branch form is rejected with 198
    foreach _bad in "E11|" "|E11" "E11||E12" "(E11|)" "(|E11)" "(E11||E12)" {
        capture codescan dx1, define(dm2 `"`_bad'"')
        assert _rc == 198
    }
    * Empty branch in an EXCLUSION is rejected too
    capture codescan dx1, define(dm2 "E1" ~ "E11|")
    assert _rc == 198
    capture codescan dx1, define(dm2 "E1" ~ "|E11")
    assert _rc == 198

    * Well-formed top-level alternation still works and matches both arms
    codescan dx1, define(a "E11|I10")
    assert el(r(summary), 1, 1) == 2
    drop a
    * Literal | inside a character class is not an alternation (matches E11 only here)
    codescan dx1, define(b "E1[0-9|]")
    assert el(r(summary), 1, 1) == 1
    drop b
    * Escaped \| is a literal pipe: matches nothing in this data, but must NOT
    * be rejected as an empty branch (rc 0 with zero matches, not rc 198)
    capture codescan dx1, define(c "E11\|x")
    assert _rc == 0
    assert el(r(summary), 1, 1) == 0
}
if _rc == 0 {
    display as result "  PASS T24: empty alternation branch rejected; legit alternations pass"
    local ++pass_count
}
else {
    display as error "  FAIL T24: empty alternation guard (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T25: duplicate/overlapping varlist rejected (2.0.7)
*   A scan variable read more than once (directly or via overlapping ranges)
*   silently double-counts under countmode/countrows/detail. Both codescan
*   and codescan_describe must reject the repeat with 198; distinct varlists
*   are unaffected.
* ============================================================

local ++test_count
capture noisily {
    clear
    set obs 3
    gen str6 dx1 = "E11"
    gen str6 dx2 = "I10"
    gen str6 dx3 = "Z00"
    gen str6 dx4 = ""
    gen str6 dx5 = ""

    * Exact repeat rejected in codescan
    capture codescan dx1 dx1, define(dm2 "E11") countmode
    assert _rc == 198
    * Overlapping ranges (dx1-dx3 dx2-dx4 repeats dx2,dx3) rejected
    capture codescan dx1-dx3 dx2-dx4, define(dm2 "E11")
    assert _rc == 198
    * Exact repeat rejected in codescan_describe
    capture codescan_describe dx1 dx1
    assert _rc == 198
    capture codescan_describe dx1-dx3 dx2-dx4
    assert _rc == 198

    * Distinct varlist still works in both commands
    codescan dx1 dx2 dx3, define(dm2 "E11")
    assert r(N) == 3
    drop dm2
    codescan_describe dx1 dx2 dx3
    assert r(n_vars) == 3
}
if _rc == 0 {
    display as result "  PASS T25: duplicate/overlapping varlist rejected in both commands"
    local ++pass_count
}
else {
    display as error "  FAIL T25: duplicate varlist guard (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T26: nocase preserves regex escape semantics (2.0.9)
* ============================================================

local ++test_count
capture noisily {
    clear
    input str6 dx1
    "123"
    "ABC"
    "a1"
    end
    codescan dx1, define(digit "\d") nocase
    assert digit[1] == 1
    assert digit[2] == 0
    assert digit[3] == 0
}
if _rc == 0 {
    display as result "  PASS T26: nocase leaves regex escapes intact"
    local ++pass_count
}
else {
    display as error "  FAIL T26: nocase regex escape semantics (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T27: merge preserves the caller's row order (2.0.9)
* ============================================================

local ++test_count
capture noisily {
    clear
    input long seq long pid str4 dx1 long visit_dt
    1 2 "E11" 2
    2 1 "Z00" 2
    3 2 "Z00" 1
    4 1 "E11" 1
    end
    codescan dx1, define(hit "E11") id(pid) date(visit_dt) ///
        merge countdate countrows cooccurrence
    assert seq == _n
}
if _rc == 0 {
    display as result "  PASS T27: merge preserves input row order"
    local ++pass_count
}
else {
    display as error "  FAIL T27: merge row order (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T28: tostring scans through tempvars without recasting inputs (2.0.9)
* ============================================================

local ++test_count
capture noisily {
    clear
    input long dx1
    11
    12
    end
    clonevar expected = dx1
    local before_type : type dx1
    codescan dx1, define(hit "11") tostring
    assert dx1 == expected
    local after_type : type dx1
    assert "`before_type'" == "`after_type'"
    assert hit[1] == 1 & hit[2] == 0
}
if _rc == 0 {
    display as result "  PASS T28: tostring preserves numeric scan variables"
    local ++pass_count
}
else {
    display as error "  FAIL T28: tostring input preservation (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T29: describe accepts arbitrary code rownames and saves valid rules (2.0.9)
* ============================================================

local ++test_count
capture noisily {
    clear
    input str12 code
    "A B"
    "A B"
    "A B"
    "A/B"
    "A/B"
    "A-B"
    end
    codescan_describe code
    matrix _TC = r(top_codes)
    mata: st_local("_rn1", st_matrixrowstripe("_TC")[1,2])
    assert `"`_rn1'"' == "A B"
    matrix drop _TC

    clear
    input str4 code
    "Å1"
    "Å2"
    "Ö1"
    end
    codescan_describe code
    matrix _CH = r(chapters)
    assert rowsof(_CH) == 2
    matrix drop _CH

    clear
    input str4 code
    "/A"
    "-B"
    end
    tempfile _draft_base
    local _draft "`_draft_base'.csv"
    codescan_describe code, save("`_draft'")
    import delimited using "`_draft'", clear stringcols(_all)
    assert _N == 2
    assert name[1] != name[2]
    forvalues i = 1/2 {
        local _nm = name[`i']
        confirm name `_nm'
    }
}
if _rc == 0 {
    display as result "  PASS T29: describe rownames and draft rule names are valid"
    local ++pass_count
}
else {
    display as error "  FAIL T29: describe arbitrary code names (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T30: prefix mode rejects empty alternatives (2.0.9)
* ============================================================

local ++test_count
capture noisily {
    clear
    input str4 dx1
    "E11"
    "Z00"
    end
    foreach _bad in "E11|" "|E11" "E11||E12" "E11| |E12" {
        capture codescan dx1, define(hit `"`_bad'"') mode(prefix)
        assert _rc == 198
    }
    capture codescan dx1, define(hit "E1" ~ "|E11") mode(prefix)
    assert _rc == 198
    codescan dx1, define(hit "E11|E12") mode(prefix)
    assert hit[1] == 1 & hit[2] == 0
}
if _rc == 0 {
    display as result "  PASS T30: empty prefix alternatives rejected"
    local ++pass_count
}
else {
    display as error "  FAIL T30: empty prefix alternative guard (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T31: all file-path options reject unsafe metacharacters (2.0.9)
* ============================================================

local ++test_count
capture noisily {
    clear
    input long pid str4 dx1
    1 "E11"
    2 "Z00"
    end
    capture codescan dx1, define(hit "E11") save("bad;name.csv")
    assert _rc == 198
    capture codescan dx1, define(hit "E11") export("bad;name.csv")
    assert _rc == 198
    capture codescan dx1, define(hit "E11") id(pid) collapse saving("bad;name.dta")
    assert _rc == 198
    capture codescan dx1, codefile("bad;name.csv")
    assert _rc == 198
    capture codescan_describe dx1, save("bad;name.csv")
    assert _rc == 198

    * A comma inside an ordinarily quoted path is data, not a suboption split.
    tempfile _comma_base
    local _comma_save "`_comma_base',result.dta"
    codescan dx1, define(hit "E11") id(pid) collapse ///
        saving(`"`_comma_save'"', replace)
    confirm file `"`_comma_save'"'
}
if _rc == 0 {
    display as result "  PASS T31: unsafe file paths rejected"
    local ++pass_count
}
else {
    display as error "  FAIL T31: file-path guards (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T32: saving() under merge writes NO internal tempvars (F32/4.0.1, audit F1)
* ============================================================
* The old code did a plain `save' of the in-memory data, which under merge
* still holds touse and the merge/date/row-count scaffolding, so the saved
* file carried __00000X columns beside the intended outputs. Proven red: on the
* old build the __-name assertion below fails for every sub-case.
capture program drop _cs_assert_no_tempvars
program define _cs_assert_no_tempvars
    * errors if any variable name in memory begins with __ (a Stata tempvar)
    foreach _v of varlist * {
        assert substr("`_v'", 1, 2) != "__"
    }
end

local ++test_count
capture noisily {
    tempfile _s1 _s2 _s3
    clear
    input long pid str6 dx1
    1 "E11"
    1 "I10"
    2 "E11"
    2 "I10"
    end

    * (a) plain merge
    preserve
    codescan dx1, define(dm2 "E11" | htn "I10") id(pid) merge saving(`"`_s1'"', replace)
    restore
    preserve
    use `"`_s1'"', clear
    _cs_assert_no_tempvars
    * discriminating: the real result columns must be present
    confirm variable dm2 htn pid dx1
    restore

    * (b) merge + countrows + all date summaries (the audit Q5 leak: 11 tempvars)
    preserve
    gen mdate = mdy(1, _n, 2020)
    format mdate %td
    codescan dx1, define(dm2 "E11" | htn "I10") id(pid) date(mdate) merge ///
        countrows alldates saving(`"`_s2'"', replace)
    restore
    preserve
    use `"`_s2'"', clear
    _cs_assert_no_tempvars
    confirm variable dm2_first dm2_last dm2_count dm2_nrows
    restore

    * (c) tostring + merge exercises the _scan_string_* tempvar the audit missed
    preserve
    clear
    input long pid double numdx
    1 111
    2 111
    end
    codescan numdx, define(dm2 "111") id(pid) tostring merge saving(`"`_s3'"', replace)
    restore
    preserve
    use `"`_s3'"', clear
    _cs_assert_no_tempvars
    confirm variable dm2 numdx pid
    restore
}
if _rc == 0 {
    display as result "  PASS T32: saving()+merge writes no internal tempvars"
    local ++pass_count
}
else {
    display as error "  FAIL T32: saving()+merge tempvar leak (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T33: codescan self-heals after mata: mata clear (4.0.1, audit F7)
* ============================================================
* The scan engine lives in _codescan_engine.ado and the regex validator in
* _codescan_definitions.ado; clearing Mata drops both while leaving the ado
* programs in place, so the program-list reload never fired and every later
* call died r(3499). Proven red: on the old build the post-clear call fails
* r(3499) here.
capture program drop _cs_f7_data
program define _cs_f7_data
    clear
    set obs 4
    gen long pid = _n
    gen str3 dx1 = "E11"
end

local ++test_count
capture noisily {
    * warm the engine
    _cs_f7_data
    quietly codescan dx1, define(dm2 "E11") id(pid) collapse
    * nuke Mata, then prefix mode (scan engine) must self-heal on fresh data
    mata: mata clear
    _cs_f7_data
    capture noisily codescan dx1, define(dm2 "E11") mode(prefix)
    assert _rc == 0
    * regex mode (needs _codescan_validate_regex) after another clear
    mata: mata clear
    _cs_f7_data
    capture noisily codescan dx1, define(dm2 "E1[12]") mode(regex)
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS T33: codescan self-heals after mata clear"
    local ++pass_count
}
else {
    display as error "  FAIL T33: mata-clear recovery (rc=`=_rc')"
    local ++fail_count
}
* T33's final regex-mode call already recompiled the full engine, so Mata is
* live again for the tests and suites that follow.


* ============================================================
* T34: case-variant duplicate names rejected everywhere (4.0.1, audit F10)
* ============================================================
* DM2 and dm2 make distinct Stata variables but are almost always a typo. The
* three uniqueness checks (define, codefile, output planner) were exact-match.
* Proven red: on the old build each define/codefile/output call below returned
* rc=0 instead of 198. Each rejection is paired with a same-shaped positive
* control that must still succeed.
capture program drop _cs_f10_data
program define _cs_f10_data
    clear
    set obs 3
    gen str3 dx1 = "E11"
end

local ++test_count
capture noisily {
    * Build the codefiles first, before any codescan call touches the data.
    tempfile _cf_dup _cf_ok
    clear
    input str8 name str8 pattern
    "DM2" "E11"
    "dm2" "I10"
    end
    export delimited using `"`_cf_dup'.csv"', replace
    clear
    input str8 name str8 pattern
    "dm2" "E11"
    "htn" "I10"
    end
    export delimited using `"`_cf_ok'.csv"', replace

    * Each codescan call gets fresh data so a prior success can't leave a
    * variable behind that trips the "already exists" guard before the check.
    * define(): case-variant duplicate rejected; distinct names accepted
    _cs_f10_data
    capture codescan dx1, define(DM2 "E11" | dm2 "I10")
    assert _rc == 198
    _cs_f10_data
    capture codescan dx1, define(dm2 "E11" | htn "I10")
    assert _rc == 0

    * output planner: unmatched() colliding with a condition name by case only
    _cs_f10_data
    capture codescan dx1, define(dm2 "E11") unmatched(DM2)
    assert _rc == 198
    _cs_f10_data
    capture codescan dx1, define(dm2 "E11") unmatched(nomatch)
    assert _rc == 0

    * codefile(): two rows whose names differ only in case
    _cs_f10_data
    capture codescan dx1, codefile(`"`_cf_dup'.csv"')
    assert _rc == 198
    _cs_f10_data
    capture codescan dx1, codefile(`"`_cf_ok'.csv"')
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS T34: case-variant duplicate names rejected"
    local ++pass_count
}
else {
    display as error "  FAIL T34: case-insensitive uniqueness (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T35: datetime date()/refdate() rejected with a clear message (4.0.1, F11)
* ============================================================
* Time windows are measured in days; a %tc/%tC datetime makes the window ~86.4M
* times too narrow. Proven red: on the old build the datetime call returned
* r(2000) (or a silent near-empty cohort), not the diagnostic r(198) asserted
* here. The daily-date control must still run.
local ++test_count
capture noisily {
    clear
    set obs 4
    gen long pid = _n
    gen str3 dx1 = "E11"
    gen double edate_tc = mdyhms(1, _n, 2020, 0, 0, 0)
    format edate_tc %tc
    gen double rdate_tc = mdyhms(6, 1, 2020, 0, 0, 0)
    format rdate_tc %tc
    gen edate_td = mdy(1, _n, 2020)
    format edate_td %td
    gen rdate_td = mdy(6, 1, 2020)
    format rdate_td %td

    * datetime date() rejected
    capture codescan dx1, define(dm2 "E11") id(pid) date(edate_tc) refdate(rdate_td) lookback(365)
    assert _rc == 198
    * datetime refdate() rejected
    capture codescan dx1, define(dm2 "E11") id(pid) date(edate_td) refdate(rdate_tc) lookback(365)
    assert _rc == 198
    * daily dates accepted (positive control)
    capture codescan dx1, define(dm2 "E11") id(pid) date(edate_td) refdate(rdate_td) lookback(365)
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS T35: datetime date()/refdate() rejected 198"
    local ++pass_count
}
else {
    display as error "  FAIL T35: datetime guard (rc=`=_rc')"
    local ++fail_count
}


* ============================================================
* T36: merge leaves . (not 0) on a fully-excluded id (4.0.1 doc, audit F8)
* ============================================================
* Characterization guard for the documented three-state merge behavior: an
* id() whose rows are all excluded returns missing, distinct from an analyzed
* id that had no match (0).
local ++test_count
capture noisily {
    clear
    input long pid str3 dx1 byte keeprow
    1 "E11" 1
    1 "I10" 1
    2 "E11" 0
    2 "I10" 0
    end
    codescan dx1 if keeprow, define(dm2 "E11") id(pid) merge
    * pid 2 fully excluded -> missing in every condition variable
    quietly count if pid == 2 & missing(dm2)
    assert r(N) == 2
    * pid 1 analyzed -> 0/1, not missing
    quietly count if pid == 1 & !missing(dm2)
    assert r(N) == 2
    assert dm2[1] == 1
}
if _rc == 0 {
    display as result "  PASS T36: merge marks fully-excluded id as missing"
    local ++pass_count
}
else {
    display as error "  FAIL T36: merge missing-id characterization (rc=`=_rc')"
    local ++fail_count
}

* ============================================================
* T37: reloaded regex validator still VALIDATES after mata clear (4.0.1, F7)
* ============================================================
* T33 proves a VALID regex reaches rc==0 post-clear. This is the stronger
* semantic guard: after mata clear, an INVALID pattern must still be REJECTED
* (rc==198), proving _codescan_validate_regex (Mata, in _codescan_definitions.ado)
* was not just reloaded but is functioning — otherwise a broken cohort scans
* silently. Proven red on the pre-F7 build: with the validator's Mata dropped and
* the program-list reload never firing, the same call dies r(3499), and on any
* build where the validator is skipped the bad pattern would scan at rc==0.
* NOTE: the scan/cooccurrence engine self-heals on the pre-F7 build too (its
* inline Mata recompiles on invocation), so the genuine F7 regression lives in
* the separately-loaded definitions helper, which is what this test pins.
capture program drop _cs_f7b_data
program define _cs_f7b_data
    clear
    set obs 6
    gen str4 dx1 = "E11"
end

local ++test_count
capture noisily {
    * warm both Mata files, then nuke Mata
    _cs_f7b_data
    quietly codescan dx1, define(dm "E11") mode(regex)
    mata: mata clear
    * valid pattern must recover to rc==0 (engine + validator reloaded)
    _cs_f7b_data
    capture codescan dx1, define(dm "E11") mode(regex)
    assert _rc == 0
    * invalid pattern after another clear must be REJECTED 198, not 3499/0
    mata: mata clear
    _cs_f7b_data
    capture codescan dx1, define(bad "E1[0-9") mode(regex)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS T37: reloaded regex validator still rejects bad patterns"
    local ++pass_count
}
else {
    display as error "  FAIL T37: validator-reload semantics (rc=`=_rc')"
    local ++fail_count
}
* T37's calls recompiled both Mata files; Mata is live for what follows.
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
_codescan_qa_publish "test_codescan_regressions" `test_count' `pass_count' `fail_count'
display as result "RESULT: test_codescan_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
