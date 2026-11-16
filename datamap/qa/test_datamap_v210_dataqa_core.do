clear all
set more off
version 16.0
set linesize 255

* test_datamap_v210_dataqa_core.do - datamap 2.1.0, dataqa core:
*   R1  ledger text holding " ' $ ` { } and SMCL braces prints literally,
*       exports intact and never expands a macro, in dataqa set, report,
*       assert, export and compare;
*   U6  phase() on dataqa set and dataprobe (ledger column phase),
*       phase() filtering on report, assert, compare and export, and
*       pending() on assert;
*   P2  the vectorized row selection in compare gives the counts an
*       independent oracle computes from the two runs.
* Hostile ledgers are built directly in the ledger schema; the phase tests
* run real dataprobe calls.  Expectations come from the fixture designs.

* === Bootstrap: targeted local reinstall ===
local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard
macro drop DATAMAP_DQ

* === Tally helper ===
global TC 0
global PASS 0
global FAIL 0
capture program drop _v2t
program define _v2t
    args rc msg
    global TC = $TC + 1
    if `rc' == 0 {
        display as result "  PASS: `msg'"
        global PASS = $PASS + 1
    }
    else {
        display as error "  FAIL (rc=`rc'): `msg'"
        global FAIL = $FAIL + 1
    }
end

* The hostile text: a double quote, a single quote, a global reference, a
* local reference, SMCL braces, a lone } and {, and a compound-quote pair.
* The global HG and the local lm hold EXPANDED: if either is ever expanded,
* the word appears in the output.
global HG "EXPANDED"
local lm "EXPANDED"
mata:
_v2_H = "q" + char(34) + "x" + char(39) + " " + char(36) + "HG " + char(96) + "lm" + ///
    char(39) + " {bf:B} }{ " + char(96) + char(34) + "c" + char(34) + char(39)
string scalar _v2_read(string scalar f)
{
    real scalar fh
    string scalar s, c
    fh = fopen(f, "r")
    s = ""
    while ((c = fread(fh, 65536)) != J(0, 0, "")) s = s + c
    fclose(fh)
    return(s)
}
real scalar _v2_nline(string scalar f, string scalar pre)
{
    real scalar fh, n, L
    string matrix ln
    fh = fopen(f, "r")
    n = 0
    L = strlen(pre)
    while ((ln = fget(fh)) != J(0, 0, "")) n = n + (substr(ln, 1, L) == pre)
    fclose(fh)
    return(n)
}
real scalar _v2_count(string scalar s0, string scalar t)
{
    real scalar n, p
    string scalar s
    s = s0
    n = 0
    while ((p = strpos(s, t)) > 0) {
        n++
        s = substr(s, p + strlen(t), .)
    }
    return(n)
}
end

* n rows of a valid, masked ledger in the 2.0.0 schema (no phase column):
* one stat() invariant per row, dataset dsK, label gK, run r0
capture program drop _v2_base
program define _v2_base
    args n
    clear
    quietly {
        set obs `n'
        generate strL run = "r0"
        generate str19 stamp = "2026-11-15_10:00:00"
        generate long seq = _n
        generate strL dataset = "ds" + string(_n)
        generate strL scope = ""
        generate str32 family = "stat"
        generate strL label = "g" + string(_n)
        generate strL variable = "x"
        generate strL grp = ""
        generate str10 kind = "invariant"
        generate str8 status = "pass"
        generate strL observed = "10"
        generate double observed_num = 10
        generate strL expected = "[0, 100]"
        generate double n_scope = 100
        generate str12 version = "2.0.0"
        generate strL signature = ""
        generate byte masked = 1
        generate int mincell = 5
        generate double minshown = .
        generate byte obs_masked = 0
        generate strL message = "stat(" + label + "): 10 within [0, 100]"
    }
end

* run a command with its output logged to file f; local _rc in the caller
capture program drop _v2_cap
program define _v2_cap, rclass
    gettoken f 0 : 0
    quietly log using `"`f'"', text replace name(_v2log)
    capture noisily `macval(0)'
    local rc = _rc
    return add
    quietly log close _v2log
    c_local _rc `rc'
end

tempfile L LB LG MD EX L20 LP
local work "`c(tmpdir)'"

**# R1 - hostile ledger text, every subcommand

* The hostile two-run ledger.  Rows 1-3 in base (r0) and cur (r1):
*   row 1: dataset, label, grp (a helper level) and expected all hostile;
*          N 100 -> 200 and stat 10 -> 20; the signature changes
*   row 2: a by() gate, label hostile, group site=1 in r0, site=2 in r1
*          (one absent gate, one new group)
*   row 3: r0 only, label "abs" + hostile, expected hostile (absent)
* r1 row 1 is failed, so report lists it as an open row.
capture noisily {
    _v2_base 3
    mata: st_sstore(1, "dataset", _v2_H); st_sstore(1, "label", _v2_H); ///
        st_sstore(1, "grp", "lv = " + _v2_H); st_sstore(1, "expected", _v2_H)
    mata: st_sstore(2, "label", _v2_H); st_sstore(2, "grp", "by(site | site=1)")
    mata: st_sstore(3, "label", "abs" + _v2_H); st_sstore(3, "expected", _v2_H)
    quietly replace family = "rule" in 2/3
    quietly replace signature = "1:s0" in 1
    quietly save `"`LB'"', replace
    quietly drop in 3
    quietly replace run = "r1"
    quietly replace n_scope = 200 in 1
    quietly replace observed_num = 20 in 1
    quietly replace observed = "20" in 1
    quietly replace status = "fail" in 1
    quietly replace signature = "1:s1" in 1
    quietly replace grp = "by(site | site=2)" in 2
    mata: st_sstore(1, "message", "stat(" + _v2_H + "): 20 outside " + _v2_H)
    quietly append using `"`LB'"'
    quietly save `"`L'"', replace
}
_v2t `=_rc' "R1 fixture: hostile two-run ledger built"

**## compare
capture noisily {
    _v2_cap `"`LG'"' dataqa compare using `"`L'"', run(r1) baseline(r0)
    assert `_rc' == 0
    assert r(n_flags) == 6
    mata: _v2_t = _v2_read(st_local("LG"))
    * N, stat and the signature line on row 1; the new group; two absent
    mata: assert(_v2_count(_v2_t, "  N  " + _v2_H + " stat(" + _v2_H + ") [lv = " + _v2_H + "]: 100 -> 200 (100.0%)") == 1)
    mata: assert(_v2_count(_v2_t, "  stat  " + _v2_H + " stat(" + _v2_H + ") [lv = " + _v2_H + "]:") == 1)
    mata: assert(_v2_count(_v2_t, "  signature  " + _v2_H + ": the data changed") == 1)
    mata: assert(_v2_count(_v2_t, "  new  ds2 rule(" + _v2_H + ") [by(site | site=2)]: a group not in the baseline") == 1)
    mata: assert(_v2_count(_v2_t, "  absent  ds2 rule(" + _v2_H + ") [by(site | site=1)], expected [0, 100]: in the baseline") == 1)
    mata: assert(_v2_count(_v2_t, "  absent  ds3 rule(abs" + _v2_H + "), expected " + _v2_H + ": in the baseline") == 1)
    mata: assert(_v2_count(_v2_t, "EXPANDED") == 0)
}
_v2t `=_rc' "R1 compare: hostile label, group and expected print literally on every line; nothing expands"

**## report
capture noisily {
    _v2_cap `"`LG'"' dataqa report using `"`L'"', run(r1) bands markdown(`"`MD'"') replace
    assert `_rc' == 0
    assert r(N) == 2 & r(n_failed) == 1 & r(n_datasets) == 2 & r(n_bands) == 1
    mata: _v2_t = _v2_read(st_local("LG"))
    mata: assert(_v2_count(_v2_t, "EXPANDED") == 0)
    mata: assert(_v2_count(_v2_t, "  " + _v2_H + "   ") == 1)
    * the register: ledger text written as stored
    mata: _v2_m = _v2_read(st_local("MD"))
    mata: assert(_v2_count(_v2_m, "| r1 | " + _v2_H + " | stat(" + _v2_H + "): 20 against " + _v2_H + " [lv = " + _v2_H + "] | 20 | " + _v2_H + "; source: | open (invariant failed;") == 1)
    mata: assert(_v2_count(_v2_m, "| r1 | " + _v2_H + " | stat(" + _v2_H + ") [lv = " + _v2_H + "] | fail | " + _v2_H + " | 20 |") == 1)
    mata: assert(_v2_count(_v2_m, "| r1 | ds2 | all gates passed: rule | 0 violations in 1 gate entries |") == 1)
    mata: assert(_v2_count(_v2_m, "EXPANDED") == 0)
}
_v2t `=_rc' "R1 report: console and register carry the hostile text literally, as stored"

**## assert
capture noisily {
    * r1 lacks ds3 (a baseline dataset) and fails row 1
    _v2_cap `"`LG'"' dataqa assert using `"`L'"', run(r1) baseline(r0)
    assert `_rc' == 9
    assert r(n_failed) == 1 & r(n_missing_base) == 1
    mata: assert(st_global("r(missing_base)") == char(96) + char(34) + "ds3" + char(34) + char(39))
    mata: _v2_t = _v2_read(st_local("LG"))
    mata: assert(_v2_count(_v2_t, "    " + _v2_H + ": stat(" + _v2_H + "): 20 outside " + _v2_H) == 1)
    mata: assert(_v2_count(_v2_t, "EXPANDED") == 0)
    * a hostile baseline dataset absent from the run: listed literally, and
    * r(missing_base) holds it as stored
    _v2_base 2
    mata: st_sstore(1, "dataset", _v2_H)
    quietly save `"`LB'"', replace
    quietly drop in 1
    quietly replace run = "r1"
    quietly append using `"`LB'"'
    quietly save `"`LP'"', replace
    _v2_cap `"`LG'"' dataqa assert using `"`LP'"', run(r1) baseline(r0)
    assert `_rc' == 9
    assert r(n_missing_base) == 1
    mata: assert(st_global("r(missing_base)") == char(96) + char(34) + _v2_H + char(34) + char(39))
    mata: _v2_t = _v2_read(st_local("LG"))
    mata: assert(_v2_count(_v2_t, char(10) + "    " + _v2_H + char(10)) == 1)
    mata: assert(_v2_count(_v2_t, "EXPANDED") == 0)
    * the same dataset waived by optional(), typed from a local
    mata: st_local("hd", _v2_H)
    _v2_cap `"`LG'"' dataqa assert using `"`LP'"', run(r1) baseline(r0) optional(`"`macval(hd)'"')
    assert `_rc' == 0
    assert r(n_optional_absent) == 1 & r(n_missing_base) == 0
    mata: assert(st_global("r(optional_absent)") == char(96) + char(34) + _v2_H + char(34) + char(39))
    * expect() with the hostile name met by the base run's rows
    _v2_cap `"`LG'"' dataqa assert using `"`LP'"', run(r0) expect(`"`macval(hd)'"' ds2)
    assert `_rc' == 0
    assert `"`r(missing)'"' == ""
}
_v2t `=_rc' "R1 assert: hostile messages, missing and optional datasets print and return as stored"

**## export
capture noisily {
    _v2_cap `"`LG'"' dataqa export using `"`L'"', run(r1) saving(`"`EX'"') replace
    assert `_rc' == 0
    assert r(N) == 2
    preserve
    quietly use `"`EX'"', clear
    quietly keep if family == "stat"
    assert _N == 1
    mata: assert(st_sdata(1, "dataset") == _v2_H & st_sdata(1, "label") == _v2_H)
    mata: assert(st_sdata(1, "expected") == _v2_H & st_sdata(1, "grp") == "lv = " + _v2_H)
    restore
    mata: _v2_t = _v2_read(st_local("LG"))
    mata: assert(_v2_count(_v2_t, "EXPANDED") == 0)
}
_v2t `=_rc' "R1 export: the release copy keeps hostile label, expected, group and dataset byte for byte"

**## set
capture noisily {
    macro drop DATAMAP_DQ
    * a run label with a backtick pair is refused: expanded in quotes it
    * read as empty text and passed the test
    mata: st_local("rb", "a" + char(96) + "lm" + char(39))
    capture dataqa set ledger(`"`L20'"') run(`macval(rb)')
    assert _rc == 198
    assert `"$DATAMAP_DQ"' == ""
    * braces are allowed in a run label and print literally
    _v2_cap `"`LG'"' dataqa set ledger(`"`L20'"') run(r{bf:x})
    assert `_rc' == 0
    mata: assert(strpos(st_global("DATAMAP_DQ"), "run(r{bf:x})") > 0)
    mata: _v2_t = _v2_read(st_local("LG"))
    mata: assert(_v2_count(_v2_t, "run(r{bf:x})") == 1)
    _v2_cap `"`LG'"' dataqa set
    mata: _v2_t = _v2_read(st_local("LG"))
    mata: assert(_v2_count(_v2_t, "run(r{bf:x})") == 1)
    macro drop DATAMAP_DQ
}
_v2t `=_rc' "R1 set: a backtick run label is refused; an SMCL-brace run label prints literally"

**## hostile run name
* dataqa set refuses such a run label, but dataprobe's ledger(file, run())
* writes one as typed: report, assert, compare and export print it as
* typed and r(run) returns it unexpanded
capture noisily {
    mata: st_local("hr", "r" + char(96) + "lm" + char(39) + char(36) + "HG{bf:x}}{")
    _v2_base 2
    quietly save `"`LB'"', replace
    mata: st_sstore(., "run", J(st_nobs(), 1, st_local("hr")))
    quietly append using `"`LB'"'
    quietly save `"`L'"', replace
    foreach sc in report assert compare {
        local _bo = cond("`sc'" == "compare", "baseline(r0)", "")
        _v2_cap `"`LG'"' dataqa `sc' using `"`L'"', run(`macval(hr)') `_bo'
        assert `_rc' == 0
        mata: assert(st_global("r(run)") == st_local("hr"))
        mata: _v2_t = _v2_read(st_local("LG"))
        mata: assert(_v2_count(_v2_t, "EXPANDED") == 0)
        mata: assert(_v2_count(_v2_t, "run " + st_local("hr")) == 1)
    }
    _v2_cap `"`LG'"' dataqa export using `"`L'"', run(`macval(hr)') saving(`"`EX'"') replace
    assert `_rc' == 0
    mata: _v2_t = _v2_read(st_local("LG"))
    mata: assert(_v2_count(_v2_t, "EXPANDED") == 0)
    preserve
    quietly use `"`EX'"', clear
    mata: assert(all(st_sdata(., "run") :== st_local("hr")))
    restore
}
_v2t `=_rc' "R1 a run name holding a macro reference prints as typed and r(run) returns it unexpanded"

**# U6 - phase-tagged ledgers

capture program drop _v2_data
program define _v2_data
    clear
    quietly set obs 20
    generate long id = _n
    generate double x = _n
end

* r0: A (build, passes), B (analysis via the call's phase(), fails),
* C (build and analysis rows, passes).  Collected, masked.
capture noisily {
    capture erase `"`LP'"'
    macro drop DATAMAP_DQ
    dataqa set maskrare mincell(5) ledger(`"`LP'"') run(r0) phase(build) collect
    assert strpos(`"`r(defaults)'"', "phase(build)") > 0
    _v2_data
    dataprobe, gatesonly expectn(20) name(A)
    dataprobe, gatesonly expectn(99) name(B) phase(analysis)
    dataprobe, gatesonly expectn(20) name(C)
    dataprobe, gatesonly isid(id) name(C) phase(analysis)
    preserve
    quietly use `"`LP'"', clear
    confirm string variable phase
    assert phase == "build" if inlist(dataset, "A") | (dataset == "C" & family == "expectn")
    assert phase == "analysis" if dataset == "B" | (dataset == "C" & family == "isid")
    assert _N == 4
    restore
}
_v2t `=_rc' "U6 phase(): the session phase tags rows; a call's phase() overrides it"

capture noisily {
    capture dataqa assert, run(r0)
    assert _rc == 9
    dataqa assert, run(r0) phase(build)
    assert r(N) == 2 & r(n_failed) == 0 & "`r(phase)'" == "build"
    capture dataqa assert, run(r0) phase(analysis)
    assert _rc == 9
    assert r(N) == 2 & r(n_failed) == 1
    dataqa report, run(r0) phase(analysis)
    assert r(N) == 2 & r(n_failed) == 1 & r(n_datasets) == 2 & "`r(phase)'" == "analysis"
    dataqa report, run(r0) phase(build analysis)
    assert r(N) == 4
    dataqa export, run(r0) phase(build) saving(`"`EX'"') replace
    assert r(N) == 2
    preserve
    quietly use `"`EX'"', clear
    assert _N == 2 & phase == "build"
    restore
}
_v2t `=_rc' "U6 phase() filtering on assert, report and export selects the listed phases"

* r1: build phase only (A, C build gates); B and C's analysis gate pending
capture noisily {
    dataqa set maskrare mincell(5) ledger(`"`LP'"') run(r1) phase(build) collect
    _v2_data
    dataprobe, gatesonly expectn(20) name(A)
    capture dataqa assert, run(r1) baseline(r0)
    assert _rc == 9
    assert r(n_missing_base) == 2
    * B (all baseline rows analysis) is pending; C has a build row too, so
    * C absent is still missing
    capture dataqa assert, run(r1) baseline(r0) pending(analysis)
    assert _rc == 9
    assert r(n_pending) == 1 & `"`r(pending)'"' == `"`"B"'"'
    assert r(n_missing_base) == 1 & `"`r(missing_base)'"' == `"`"C"'"'
    dataprobe, gatesonly expectn(20) name(C)
    _v2_cap `"`LG'"' dataqa assert, run(r1) baseline(r0) pending(analysis)
    assert `_rc' == 0
    assert r(n_pending) == 1 & r(n_missing_base) == 0
    mata: _v2_t = _v2_read(st_local("LG"))
    mata: assert(_v2_count(_v2_t, "    PENDING B") == 1)
    mata: assert(_v2_count(_v2_t, "; 1 pending") == 1)
    * C has rows now, but its analysis gate (isid) has not run: a pending
    * gate, listed, not halting
    assert r(n_pending_gates) == 1
    mata: assert(_v2_count(_v2_t, "    PENDING C: isid(") == 1)
    mata: assert(_v2_count(_v2_t, "; 1 gate(s) pending") == 1)
    * without pending() nothing is listed and the result has no count
    capture dataqa assert, run(r1) baseline(r0) optional(B)
    assert _rc == 0 & missing(r(n_pending_gates))
    * expect(B): an expected dataset of a pending phase is pending too
    dataqa assert, run(r1) baseline(r0) pending(analysis) expect(A B)
    assert `"`r(missing)'"' == "" & r(n_pending) == 1
    capture dataqa assert, run(r1) baseline(r0) pending(analysis) expect(Z)
    assert _rc == 9
    assert `"`r(missing)'"' == "Z"
    * a pending-phase dataset that has rows must pass: B fails now
    dataprobe, gatesonly expectn(99) name(B) phase(analysis)
    capture dataqa assert, run(r1) baseline(r0) pending(analysis)
    assert _rc == 9
    assert r(n_failed) == 1 & r(n_pending) == 0
}
_v2t `=_rc' "U6 pending(): absent datasets of a pending phase pass as PENDING; present rows must still pass"

* gate-level pending with hostile text: dataset and label print as typed
capture noisily {
    _v2_base 3
    quietly generate str32 phase = "build"
    mata: st_sstore(., "dataset", J(3, 1, _v2_H)); st_sstore(1, "label", _v2_H)
    quietly replace phase = "analysis" in 1
    * row 3: a build gate absent now, not pending (2.0.0: not checked)
    quietly save `"`LB'"', replace
    quietly keep in 2
    quietly replace run = "r1"
    quietly append using `"`LB'"'
    quietly save `"`L'"', replace
    _v2_cap `"`LG'"' dataqa assert using `"`L'"', run(r1) baseline(r0) pending(analysis)
    assert `_rc' == 0
    assert r(n_pending_gates) == 1 & r(n_pending) == 0 & r(n_missing_base) == 0
    mata: _v2_t = _v2_read(st_local("LG"))
    mata: assert(_v2_count(_v2_t, "EXPANDED") == 0)
    mata: assert(_v2_count(_v2_t, "    PENDING " + _v2_H + ": stat(" + _v2_H + ")") == 1)
    * the same gate with a changed declared range has run: not pending
    quietly use `"`L'"', clear
    quietly expand 2 if run == "r1", generate(_e)
    mata: st_sstore(selectindex(st_data(., "_e")), "label", _v2_H)
    quietly replace phase = "analysis" if _e
    quietly replace expected = "[0, 50]" if _e
    quietly drop _e
    quietly save `"`L'"', replace
    dataqa assert using `"`L'"', run(r1) baseline(r0) pending(analysis)
    assert r(n_pending_gates) == 0
}
_v2t `=_rc' "U6 pending(): a missing gate of a pending phase in a present dataset is listed as PENDING, text as typed"

capture noisily {
    * compare phase(build): the analysis rows are left out on both sides
    dataqa compare, run(r1) baseline(r0) phase(build)
    assert r(n_flags) == 0 & "`r(phase)'" == "build"
    dataqa compare, run(r1) baseline(r0)
    assert r(n_flags) >= 0
    * pending() without a baseline: ignored, with a note
    capture dataqa assert, run(r1) pending(analysis)
    assert _rc == 9
    assert r(n_pending) == 0
}
_v2t `=_rc' "U6 compare phase() pairs only the listed phases; pending() without a baseline is ignored"

capture noisily {
    * a call error row is kept under any phase() filter: the failed call
    * may have named another phase
    dataqa set maskrare mincell(5) ledger(`"`LP'"') run(r2) phase(analysis) collect
    _v2_data
    dataprobe, gatesonly expectn(20) name(D)
    dataqa set maskrare mincell(5) ledger(`"`LP'"') run(r2) phase(build) collect
    capture dataprobe, gatesonly isid(nosuchvar) name(E)
    assert _rc != 0
    capture dataqa assert, run(r2) phase(analysis)
    assert _rc == 9
    assert r(n_errors) == 1 & r(N) == 2
    preserve
    quietly use `"`LP'"', clear
    quietly keep if run == "r2" & status == "error"
    assert _N == 1 & phase == "build"
    restore
}
_v2t `=_rc' "U6 call error rows carry the session phase and survive every phase() filter"

**## 2.0.0 ledgers
capture noisily {
    macro drop DATAMAP_DQ
    preserve
    quietly use `"`LP'"', clear
    quietly drop phase
    quietly keep if run == "r0"
    quietly save `"`L20'"', replace
    restore
    dataqa report using `"`L20'"', run(r0)
    assert r(N) == 4 & r(n_failed) == 1
    capture dataqa assert using `"`L20'"', run(r0)
    assert _rc == 9 & r(N) == 4
    * no phase column: a phase() selection keeps no row, and fails closed
    capture dataqa assert using `"`L20'"', run(r0) phase(build)
    assert _rc == 9 & r(N) == 0
    capture dataqa export using `"`L20'"', run(r0) phase(build) saving(`"`EX'"') replace
    assert _rc == 2000
    * a baseline without the column: nothing is pending
    capture dataqa assert using `"`L20'"', run(r0) baseline(r0) pending(analysis)
    assert _rc == 9 & r(n_pending) == 0
    * new rows append to it: the old rows read as phase ""
    _v2_data
    dataprobe, gatesonly expectn(20) name(F) ledger(`"`L20'"', run(r9)) phase(build)
    preserve
    quietly use `"`L20'"', clear
    assert phase == "" if run == "r0"
    assert phase == "build" if run == "r9"
    restore
}
_v2t `=_rc' "U6 2.0.0 ledgers load and work; without a phase column a phase() selection is empty"

**## errors
capture noisily {
    macro drop DATAMAP_DQ
    capture dataqa set phase(build)
    assert _rc == 198
    capture dataqa set ledger(`"`L20'"') phase(1build)
    assert _rc == 198
    capture dataqa set ledger(`"`L20'"') phase(`"a b"')
    assert _rc != 0
    assert `"$DATAMAP_DQ"' == ""
    _v2_data
    capture dataprobe, gatesonly expectn(20) phase(build)
    assert _rc == 198
    capture dataqa report using `"`L20'"', phase(a-b)
    assert _rc != 0
    capture dataqa assert using `"`L20'"', run(r0) phase(build) pending(build)
    assert _rc == 198
    capture dataqa assert using `"`L20'"', run(r0) baseline(r0) pending(1x)
    assert _rc != 0
}
_v2t `=_rc' "U6 errors: phase() needs a ledger and a name; a phase cannot be both selected and pending"

**# Edge cases

capture noisily {
    * empty sample: a run with no rows (2.0.0 stopped at r(3598) here)
    _v2_base 1
    quietly save `"`L'"', replace
    dataqa report using `"`L'"', run(nosuch)
    assert r(N) == 0 & r(n_datasets) == 0
    capture dataqa assert using `"`L'"', run(nosuch)
    assert _rc == 9 & r(N) == 0
    * one row, one group: compare with itself flags nothing
    dataqa compare using `"`L'"', run(r0) baseline(r0)
    assert r(n_flags) == 0
    * all missing: n_scope and the stat value withheld on both sides
    _v2_base 2
    quietly replace n_scope = .
    quietly replace observed_num = .
    quietly replace obs_masked = 1
    quietly save `"`LB'"', replace
    quietly replace run = "r1"
    quietly append using `"`LB'"'
    quietly save `"`L'"', replace
    dataqa compare using `"`L'"', run(r1) baseline(r0)
    assert r(n_flags) == 0
}
_v2t `=_rc' "edge: empty run, one row, and all-missing counts and values"

**# P2 - compare's selection against an independent oracle

capture noisily {
    * the ntol()/stattol() boundaries: rel exactly 0.05 does not flag
    _v2_base 4
    quietly replace n_scope = 1000
    quietly replace observed_num = 10
    quietly save `"`LB'"', replace
    quietly replace run = "r1"
    quietly replace n_scope = 1050 in 1
    quietly replace n_scope = 1051 in 2
    quietly replace observed_num = 10.5 in 3
    quietly replace observed_num = 10.51 in 4
    quietly append using `"`LB'"'
    quietly save `"`L'"', replace
    dataqa compare using `"`L'"', run(r1) baseline(r0)
    assert r(n_flags) == 2
    * a random two-run ledger: counts with zero and missing baselines
    set seed 210
    _v2_base 600
    quietly replace family = cond(runiform() < 0.4, "stat", "rule")
    quietly replace n_scope = floor(runiform() * 50)
    quietly replace n_scope = . if runiform() < 0.05
    quietly replace observed_num = round(runiform() * 20, 0.01)
    quietly replace observed_num = . if runiform() < 0.05
    quietly save `"`LB'"', replace
    quietly replace run = "r1"
    quietly replace n_scope = cond(runiform() < 0.5, n_scope, floor(runiform() * 50))
    quietly replace n_scope = . if runiform() < 0.05
    quietly replace observed_num = cond(runiform() < 0.5, observed_num, round(runiform() * 20, 0.01))
    quietly replace observed_num = . if runiform() < 0.05
    quietly drop if runiform() < 0.1
    tempfile cur
    quietly save `"`cur'"'
    quietly append using `"`LB'"'
    quietly save `"`L'"', replace
    * oracle: the runs matched by label in plain Stata
    quietly use `"`LB'"', clear
    keep label n_scope observed_num
    rename (n_scope observed_num) (b sb)
    quietly recast str20 label
    tempfile bas
    quietly save `"`bas'"'
    quietly use `"`cur'"', clear
    keep label family n_scope observed_num
    rename (n_scope observed_num) (a sa)
    quietly recast str20 label
    quietly merge 1:1 label using `"`bas'"', generate(_m)
    quietly count if _m == 2
    local o_abs = r(N)
    quietly count if _m == 3 & !(missing(a) & missing(b)) & (missing(a) | missing(b) | ///
        (b == 0 & a != 0) | (b != 0 & abs((a - b) / b) > 0.05))
    local o_n = r(N)
    quietly count if _m == 3 & family == "stat" & !(missing(sa) & missing(sb)) & ///
        (missing(sa) | missing(sb) | abs(cond(sb != 0, (sa - sb) / abs(sb), sa - sb)) > 0.05)
    local o_s = r(N)
    display as text "oracle: N `o_n', stat `o_s', absent `o_abs'"
    assert `o_n' > 50 & `o_s' > 20 & `o_abs' > 20
    dataqa compare using `"`L'"', run(r1) baseline(r0)
    assert r(n_flags) == `o_n' + `o_s' + `o_abs'
}
_v2t `=_rc' "P2 compare: flags at the tolerance boundaries and on a random ledger match an independent oracle"

* a selection longer than one macro can hold: 120,000 failed rows of one
* dataset, about 840,000 characters as a row list, over c(macrolen).  Every
* row is listed, counted and written (the lists are passed in chunks).
capture noisily {
    local NB 120000
    _v2_base `NB'
    quietly replace dataset = "dsA"
    quietly replace status = "fail"
    quietly save `"`LB'"', replace
    quietly keep in 1/5
    quietly replace run = "r1"
    quietly append using `"`LB'"'
    quietly save `"`L'"', replace
    * compare: every baseline gate absent from r1 is flagged
    quietly dataqa compare using `"`L'"', run(r1) baseline(r0)
    assert r(n_flags) == `NB' - 5
    * assert: every failed row listed, the last one included
    _v2_cap `"`LG'"' dataqa assert using `"`L'"', run(r0)
    assert `_rc' == 9 & r(n_failed) == `NB'
    mata: assert(_v2_nline(st_local("LG"), "    dsA: ") == `NB')
    mata: assert(_v2_nline(st_local("LG"), "    dsA: stat(g`NB'): ") == 1)
    * report: every open row and band row in the markdown, every band row
    * on the console (and the one summary row)
    _v2_cap `"`LG'"' dataqa report using `"`L'"', run(r0) bands markdown(`"`MD'"') replace
    assert `_rc' == 0 & r(n_bands) == `NB' & r(n_rows) == `NB'
    mata: assert(_v2_nline(st_local("LG"), "  dsA ") == `NB' + 1)
    mata: assert(_v2_nline(st_local("MD"), "| r0 | dsA | ") == 2 * `NB')
    mata: assert(_v2_nline(st_local("MD"), "| r0 | dsA | stat(g`NB'): ") == 1)
    mata: assert(_v2_nline(st_local("MD"), "| r0 | dsA | stat(g`NB') | ") == 1)
}
_v2t `=_rc' "P2 a selection of 120,000 rows is listed, counted and written in full by compare, assert and report"

macro drop DATAMAP_DQ HG
capture mata: mata drop _v2_H _v2_t _v2_m _v2_read() _v2_count() _v2_nline()

display as result "Results: $PASS/$TC passed, $FAIL failed"
display "RESULT: test_datamap_v210_dataqa_core tests=$TC pass=$PASS fail=$FAIL"
if $FAIL > 0 exit 1
