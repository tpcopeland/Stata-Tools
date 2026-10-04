clear all
set more off
version 16.0
set linesize 255

* test_dataqa_v190.do - dataqa assert, baseline() optional() (W4) and
* dataqa report, bands (O4).  Expectations are hand-built from the fixture
* designs below; every gate must fail on a planted defect.

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
capture program drop _dq
program define _dq
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

* whole-file bytes as a Mata string; r(same) compares two files, the first
* with its date column normalized when dn is given
capture program drop _dq_same
program define _dq_same, rclass
    args f1 f2 dn
    mata: st_numscalar("_dq_same", _dq_cmp(st_local("f1"), st_local("f2"), st_local("dn") != ""))
    return scalar same = scalar(_dq_same)
end
mata:
string scalar _dq_read(string scalar f)
{
    real scalar fh
    string scalar s, c
    fh = fopen(f, "r")
    s = ""
    while ((c = fread(fh, 65536)) != J(0, 0, "")) s = s + c
    fclose(fh)
    return(s)
}
real scalar _dq_cmp(string scalar f1, string scalar f2, real scalar dn)
{
    string scalar a, b
    a = _dq_read(f1)
    b = _dq_read(f2)
    if (dn) a = ustrregexra(a, "\| [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] \|", "| DATE |")
    return(a == b)
}
end

* whole-file text of f, r(has) = 1 when needle occurs
capture program drop _dq_has
program define _dq_has, rclass
    args f needle
    mata: st_numscalar("_dq_h", strpos(_dq_read(st_local("f")), st_local("needle")) > 0)
    return scalar has = scalar(_dq_h)
end

* r(missing_base) / r(optional_absent) with the compound quotes stripped
capture program drop _dq_strip
program define _dq_strip, rclass
    local out ""
    foreach x of local 0 {
        local out `out' `x'
    }
    return local s = strtrim("`out'")
end

capture program drop _dq_fix
program define _dq_fix
    clear
    set obs 20
    gen long id = _n
    gen double x = _n
end

local LB "`c(tmpdir)'/dq190_base.dta"
local LC "`c(tmpdir)'/dq190_cur.dta"
local L  "`c(tmpdir)'/dq190_all.dta"
local MD "`c(tmpdir)'/dq190_md.md"
local MD2 "`c(tmpdir)'/dq190_md2.md"
local LG "`c(tmpdir)'/dq190_log.txt"
local EXP "`c(tmpdir)'/dq190_exp.md"
foreach f in "`LB'" "`LC'" "`L'" "`MD'" "`MD2'" {
    capture erase `"`f'"'
}
tempfile lgf

**# W4 fixtures: one ledger L with several runs of isid gates

* b0 (the baseline): alpha, beta, gamma.  n1: gamma deleted.  n2: unchanged.
* n3: all three plus a new dataset delta.  n4: beta and gamma deleted.
* n5: all three, but alpha's rule gate fails.  Run via dataqa set ledger/run.
capture program drop _dq_run
program define _dq_run
    args L run names bad
    _dq_fix
    dataqa set ledger("`L'") run(`run')
    foreach n of local names {
        if "`n'" == "alpha" & "`bad'" != "" {
            capture datacheck, gatesonly isid(id) rule("big": x <= 18) name(alpha)
        }
        else datacheck, gatesonly isid(id) name(`n')
    }
    dataqa set clear
end

capture noisily {
    _dq_run "`L'" b0 "alpha beta gamma"
    _dq_run "`L'" n1 "alpha beta"
    _dq_run "`L'" n2 "alpha beta gamma"
    _dq_run "`L'" n3 "alpha beta gamma delta"
    _dq_run "`L'" n4 "alpha"
    _dq_run "`L'" n5 "alpha beta gamma" bad
    * the oracle: distinct datasets per run counted straight from the ledger
    preserve
    use "`L'", clear
    foreach r in b0 n1 n2 n3 n4 n5 {
        tempvar t
        egen byte `t' = tag(dataset) if run == "`r'"
        quietly count if `t' == 1
        local nd_`r' = r(N)
        drop `t'
    }
    restore
    assert `nd_b0' == 3 & `nd_n1' == 2 & `nd_n2' == 3 & `nd_n3' == 4 & `nd_n4' == 1 & `nd_n5' == 3
}
_dq `=_rc' "fixture: ledger holds the planted runs (datasets per run 3,2,3,4,1,3)"

**# W4: the before contrast

capture noisily {
    * before 1.9.0 a deleted dataset is invisible to assert without expect()
    dataqa assert using "`L'", run(n1)
    assert r(n_failed) == 0
    * and the new option catches the same ledger
    capture dataqa assert using "`L'", run(n1) baseline(b0)
    assert _rc == 9
}
_dq `=_rc' "before/after: assert without baseline() passes the run with gamma deleted; baseline(b0) halts it with exit 9"

**# W4: deleted dataset fails, optional() waives it

capture noisily {
    capture dataqa assert using "`L'", run(n1) baseline(b0)
    assert _rc == 9
    assert r(n_missing_base) == 1
    assert "`r(baseline)'" == "b0"
    local _mb `"`r(missing_base)'"'
    _dq_strip `_mb'
    assert "`r(s)'" == "gamma"
    * optional() waives exactly that dataset
    dataqa assert using "`L'", run(n1) baseline(b0) optional(gamma)
    assert r(n_missing_base) == 0 & r(n_optional_absent) == 1
    local _mb `"`r(optional_absent)'"'
    _dq_strip `_mb'
    assert "`r(s)'" == "gamma"
    * a different optional name does not waive it
    capture dataqa assert using "`L'", run(n1) baseline(b0) optional(alpha delta)
    assert _rc == 9 & r(n_missing_base) == 1
    * two datasets deleted: both are named, and optional() of one leaves the other
    capture dataqa assert using "`L'", run(n4) baseline(b0)
    assert _rc == 9 & r(n_missing_base) == 2
    local _mb `"`r(missing_base)'"'
    _dq_strip `_mb'
    assert "`r(s)'" == "beta gamma"
    capture dataqa assert using "`L'", run(n4) baseline(b0) optional(beta)
    assert _rc == 9 & r(n_missing_base) == 1
    local _mb `"`r(missing_base)'"'
    _dq_strip `_mb'
    assert "`r(s)'" == "gamma"
    dataqa assert using "`L'", run(n4) baseline(b0) optional(beta gamma)
    assert r(n_optional_absent) == 2
}
_dq `=_rc' "assert baseline(): a deleted dataset halts (exit 9) and is named; optional() waives only the datasets listed"

**# W4: the console names every missing dataset

capture noisily {
    capture log close _dql
    log using "`lgf'", text replace name(_dql)
    capture noisily dataqa assert using "`L'", run(n4) baseline(b0)
    log close _dql
    _dq_has "`lgf'" "2 dataset(s) in baseline run b0 have no rows in run n4"
    assert r(has) == 1
    _dq_has "`lgf'" "    beta"
    assert r(has) == 1
    _dq_has "`lgf'" "    gamma"
    assert r(has) == 1
    * alpha is present and is not named
    _dq_has "`lgf'" "    alpha"
    assert r(has) == 0
}
_dq `=_rc' "assert baseline(): console lists every missing dataset and no present one"
capture log close _dql

**# W4: unchanged rerun, new dataset, invariant halt, expect()

capture noisily {
    dataqa assert using "`L'", run(n2) baseline(b0)
    assert r(n_missing_base) == 0 & r(N) == 3
    * a dataset that exists now but not in the baseline is fine
    dataqa assert using "`L'", run(n3) baseline(b0)
    assert r(n_missing_base) == 0
    * the baseline run against itself
    dataqa assert using "`L'", run(b0) baseline(b0)
    * invariant failure still halts, with a clean baseline comparison
    capture dataqa assert using "`L'", run(n5) baseline(b0)
    assert _rc == 9 & r(n_failed) == 1 & r(n_missing_base) == 0
    * the invariant failure also halts without baseline(), as before
    capture dataqa assert using "`L'", run(n5)
    assert _rc == 9 & r(n_failed) == 1
    * expect() combined with baseline(): both lists are checked
    capture dataqa assert using "`L'", run(n3) baseline(b0) expect(alpha zeta)
    assert _rc == 9 & r(missing) == "zeta" & r(n_missing_base) == 0
    capture dataqa assert using "`L'", run(n1) baseline(b0) optional(gamma) expect(alpha zeta)
    assert _rc == 9 & r(missing) == "zeta" & r(n_optional_absent) == 1
    dataqa assert using "`L'", run(n2) baseline(b0) expect(alpha beta gamma)
    * expect() alone is unchanged
    capture dataqa assert using "`L'", run(n1) expect(alpha gamma)
    assert _rc == 9 & r(missing) == "gamma"
}
_dq `=_rc' "assert baseline(): unchanged rerun and a new dataset pass; invariant halt and expect() unchanged and combinable"

**# W4: separate baseledger()

capture noisily {
    preserve
    use "`L'", clear
    keep if run == "b0"
    save "`LB'", replace
    use "`L'", clear
    keep if inlist(run, "n1", "n2")
    save "`LC'", replace
    restore
    * the current ledger holds no b0 rows at all
    preserve
    use "`LC'", clear
    count if run == "b0"
    assert r(N) == 0
    restore
    capture dataqa assert using "`LC'", run(n1) baseline(b0) baseledger("`LB'")
    assert _rc == 9
    local _mb `"`r(missing_base)'"'
    _dq_strip `_mb'
    assert "`r(s)'" == "gamma"
    dataqa assert using "`LC'", run(n1) baseline(b0) baseledger("`LB'") optional(gamma)
    dataqa assert using "`LC'", run(n2) baseline(b0) baseledger("`LB'")
    assert r(n_missing_base) == 0
    * without baseledger() the baseline label is looked up in the current ledger: no rows, an error
    capture dataqa assert using "`LC'", run(n2) baseline(b0)
    assert _rc == 2000
    * session defaults supply the current ledger
    dataqa set ledger("`LC'") run(n1)
    capture dataqa assert, baseline(b0) baseledger("`LB'")
    assert _rc == 9
    dataqa set clear
}
_dq `=_rc' "assert baseline(): baseledger() reads the baseline from a separate file; session ledger default works"
dataqa set clear

**# optional() with no baseline is ignored with a note

capture noisily {
    capture log close _dql
    log using "`lgf'", text replace name(_dql)
    capture noisily dataqa assert using "`L'", run(n1) optional(gamma)
    local rc1 = _rc
    local N1 = r(N)
    local nf1 = r(n_failed)
    local nopt1 = r(n_optional_absent)
    local nmb1 = r(n_missing_base)
    local bl1 `"`r(baseline)'"'
    log close _dql
    * n1 has alpha and beta (2 rows), no failed gate: the run passes
    assert `rc1' == 0
    assert `N1' == 2 & `nf1' == 0 & `nopt1' == 0 & `nmb1' == 0 & `"`bl1'"' == ""
    _dq_has "`lgf'" "note: optional() ignored; no baseline set"
    assert r(has) == 1
    * a compound-quoted name with a space is ignored the same way
    capture dataqa assert using "`L'", run(n1) optional(`"b c"' d)
    assert _rc == 0
    * ignoring optional() softens no halt: a failed invariant and an unmet
    * expect() still exit 9
    capture dataqa assert using "`L'", run(n5) optional(alpha)
    assert _rc == 9 & r(n_failed) == 1
    capture dataqa assert using "`L'", run(n1) optional(gamma) expect(gamma)
    assert _rc == 9 & r(missing) == "gamma"
    * no note without optional(), nor when a baseline makes optional() live
    log using "`lgf'", text replace name(_dql)
    dataqa assert using "`L'", run(n1)
    capture noisily dataqa assert using "`L'", run(n1) baseline(b0) optional(gamma)
    local rc2 = _rc
    local nopt2 = r(n_optional_absent)
    log close _dql
    assert `rc2' == 0 & `nopt2' == 1
    _dq_has "`lgf'" "optional() ignored"
    assert r(has) == 0
}
_dq `=_rc' "assert: optional() without a baseline is ignored with a note (rc 0); halts and expect() unaffected"
capture log close _dql

**# W4: parse errors and an empty baseline

capture noisily {
    capture dataqa assert using "`L'", run(n1) baseledger("`LB'")
    assert _rc == 198
    * a baseline label with no rows is an error, never a silent pass
    capture dataqa assert using "`L'", run(n2) baseline(nosuchrun)
    assert _rc == 2000
    * an absent baseledger file is r(601)
    capture dataqa assert using "`L'", run(n2) baseline(b0) baseledger("`c(tmpdir)'/dq190_nofile.dta")
    assert _rc == 601
    * a file that is not a ledger is r(610)
    preserve
    clear
    set obs 3
    gen z = 1
    save "`c(tmpdir)'/dq190_notled.dta", replace
    restore
    capture dataqa assert using "`L'", run(n2) baseline(b0) baseledger("`c(tmpdir)'/dq190_notled.dta")
    assert _rc == 610
    capture erase "`c(tmpdir)'/dq190_notled.dta"
}
_dq `=_rc' "assert baseline(): baseledger() without baseline() r(198); empty baseline 2000; missing file 601; not a ledger 610"

**# W4: compare is unchanged by the shared baseline loader

capture noisily {
    dataqa compare using "`L'", run(n1) baseline(b0)
    assert !missing(r(n_flags)) & r(n_flags) >= 1
    capture log close _dql
    log using "`lgf'", text replace name(_dql)
    dataqa compare using "`L'", run(n1) baseline(b0)
    log close _dql
    _dq_has "`lgf'" "absent  gamma"
    assert r(has) == 1
    dataqa compare using "`LC'", run(n1) baseline(b0) baseledger("`LB'")
    assert !missing(r(n_flags)) & r(n_flags) >= 1
    dataqa compare using "`L'", run(n2) baseline(b0)
    assert r(n_flags) == 0
}
_dq `=_rc' "compare: still reports the deleted dataset as absent, and an unchanged rerun as no change"
capture log close _dql

**# O4 fixtures

* g1: the register-draft fixture of test_dataqa.do (golden/dataqa_report.md).
* bd: passing and failing bands, a stat() invariant, a masked value.
* nb: a run with no bands.
capture noisily {
    capture erase "`L'"
    dataqa set maskrare mincell(5) ledger("`L'") run(g1) bandwarn
    _dq_fix
    capture datacheck, gatesonly isid(id) rule("big": x <= 18) ///
        bands(stat(mean x 0 5)) review("low": x < 3) name(alpha)
    assert _rc == 9
    _dq_fix
    datacheck, gatesonly isid(id) name(beta)
    dataqa set maskrare mincell(5) ledger("`L'") run(bd)
    _dq_fix
    capture datacheck, gatesonly isid(id) rule("big": x <= 18) ///
        stat(mean x 10 11 \ n x 0 3 if x < 3) ///
        bands(stat(mean x 0 5) expectn(15 25)) name(alpha)
    assert _rc == 9
    _dq_fix
    capture datacheck, gatesonly stat(sum x 0 100) name(beta)
    assert _rc == 9
    dataqa set maskrare mincell(5) ledger("`L'") run(nb)
    _dq_fix
    datacheck, gatesonly isid(id) review("low": x < 3) name(alpha)
    dataqa set clear
    * the oracle for the true values the table must show
    _dq_fix
    quietly summarize x
    assert r(mean) == 10.5 & r(sum) == 210
    quietly count if x < 3
    assert r(N) == 2
}
_dq `=_rc' "bands fixture: g1, bd and nb runs written to one ledger"

**# O4: the register draft is byte-identical without bands

capture noisily {
    capture erase "`MD'"
    dataqa report using "`L'", run(g1) markdown("`MD'")
    assert r(n_rows) == 4
    _dq_same "`MD'" "`qa_dir'/golden/dataqa_report.md" dn
    assert r(same) == 1
    * the plain console summary has no bands block
    capture erase "`MD2'"
    dataqa report using "`L'", run(g1) markdown("`MD2'") bands
    assert r(n_rows) == 4 & r(n_bands) == 1
    * with bands the draft is the golden draft plus one section appended
    mata: st_numscalar("_dq_pre", strpos(_dq_read(st_local("MD2")), _dq_read(st_local("MD"))) == 1 & ///
        strlen(_dq_read(st_local("MD2"))) > strlen(_dq_read(st_local("MD"))))
    assert scalar(_dq_pre) == 1
}
_dq `=_rc' "report: register draft without bands equals the golden file byte for byte; with bands it only appends a section"

**# O4: the bands table against a hand-built expectation

capture noisily {
    capture erase "`MD'"
    capture log close _dql
    log using "`lgf'", text replace name(_dql)
    dataqa report using "`L'", run(bd) bands markdown("`MD'")
    local nb = r(n_bands)
    local nr = r(n_rows)
    log close _dql
    assert `nb' == 5 & `nr' == 3
    * the oracle for the row count: band and stat rows of the run, straight from the ledger
    preserve
    use "`L'", clear
    keep if run == "bd"
    count if kind == "band" | family == "stat"
    assert r(N) == 5
    count if family == "isid" | family == "rule"
    assert r(N) == 2
    restore
    * hand-built markdown section
    tempname fh
    file open `fh' using "`EXP'", write text replace
    file write `fh' "## Bands and stat() invariants" _n _n
    file write `fh' "| Run | Dataset | Gate | Status | Declared range | Observed |" _n
    file write `fh' "|---|---|---|---|---|---|" _n
    file write `fh' "| bd | alpha | expectn() | pass | [15, 25] | 20 |" _n
    file write `fh' "| bd | alpha | stat(mean x) | pass | [10, 11] | mean 10.5 |" _n
    file write `fh' "| bd | alpha | stat(n x) | pass | [0, 3] | n <5 |" _n
    file write `fh' "| bd | alpha | stat(mean x) | fail | [0, 5] | mean 10.5 |" _n
    file write `fh' "| bd | beta | stat(sum x) | fail | [0, 100] | sum 210 |" _n
    file close `fh'
    * the draft ends with the expected section, after the register table
    mata: st_numscalar("_dq_sec", strpos(_dq_read(st_local("MD")), ///
        "|" + char(10) + char(10) + _dq_read(st_local("EXP"))) > 0 & ///
        substr(_dq_read(st_local("MD")), strlen(_dq_read(st_local("MD"))) - strlen(_dq_read(st_local("EXP"))) + 1, .) == ///
        _dq_read(st_local("EXP")))
    assert scalar(_dq_sec) == 1
    * console rows: passing and failing, masked value as stored
    _dq_has "`lgf'" "stat(n x)"
    assert r(has) == 1
    _dq_has "`lgf'" "n <5"
    assert r(has) == 1
    _dq_has "`lgf'" "5 band(s) and stat() invariant(s)"
    assert r(has) == 1
    * the true count of x < 3 (2) is never shown for the masked stat
    _dq_has "`MD'" "n 2"
    assert r(has) == 0
    * statuses cover both outcomes
    _dq_has "`MD'" "| fail | [0, 5] | mean 10.5 |"
    assert r(has) == 1
    _dq_has "`MD'" "| pass | [10, 11] | mean 10.5 |"
    assert r(has) == 1
    capture erase "`EXP'"
}
_dq `=_rc' "report bands: passing and failing bands, a stat() invariant and a masked value match the hand-built table"
capture log close _dql
capture file close `fh'

**# O4: no mask means no masking; a stat() value shown unmasked is the stored one

capture noisily {
    local LU "`c(tmpdir)'/dq190_unmasked.dta"
    capture erase "`LU'"
    dataqa set ledger("`LU'") run(u)
    _dq_fix
    datacheck, gatesonly stat(n x 0 3 if x < 3) name(alpha)
    dataqa set clear
    dataqa report using "`LU'", run(u) bands markdown("`MD'") replace
    assert r(n_bands) == 1
    _dq_has "`MD'" "| u | alpha | stat(n x) | pass | [0, 3] | n 2 |"
    assert r(has) == 1
    capture erase "`LU'"
}
_dq `=_rc' "report bands: without maskrare the observed value is the stored count (n 2)"

**# O4: a run with no bands

capture noisily {
    capture erase "`MD'"
    capture log close _dql
    log using "`lgf'", text replace name(_dql)
    dataqa report using "`L'", run(nb) bands markdown("`MD'")
    local nb = r(n_bands)
    log close _dql
    assert `nb' == 0
    _dq_has "`lgf'" "no bands or stat() invariants in the selected run"
    assert r(has) == 1
    _dq_has "`MD'" "No bands or stat() invariants in the selected run."
    assert r(has) == 1
    * and no table header for the empty section
    _dq_has "`MD'" "| Declared range |"
    assert r(has) == 0
    * without bands, nothing about bands is printed and r(n_bands) is not set
    capture log close _dql
    log using "`lgf'", text replace name(_dql)
    dataqa report using "`L'", run(nb)
    local nbs "`r(n_bands)'"
    log close _dql
    _dq_has "`lgf'" "bands:"
    assert r(has) == 0
    assert "`nbs'" == ""
}
_dq `=_rc' "report bands: a run with no bands prints a clear no-bands line in console and markdown; absent without the option"
capture log close _dql

**# O4: what the ledger can and cannot show (reporting, not asserting a guess)

capture noisily {
    * the declared range is the ledger's expected column: bounds for stat and
    * expectn, a sentence for coverage and the like; a row with no expected
    * text is shown as "(not recorded)", never reconstructed
    preserve
    use "`L'", clear
    keep if run == "bd" & (kind == "band" | family == "stat")
    assert expected != ""
    * the table reads observed and expected only: they equal the ledger's text
    assert observed[1] == "20" & expected[1] == "[15, 25]"
    restore
    * an old ledger row with an empty expected column prints (not recorded)
    preserve
    use "`L'", clear
    keep if run == "bd" & family == "stat" & kind == "band"
    replace expected = ""
    replace run = "old"
    save "`c(tmpdir)'/dq190_old.dta", replace
    restore
    capture erase "`MD'"
    dataqa report using "`c(tmpdir)'/dq190_old.dta", run(old) bands markdown("`MD'")
    _dq_has "`MD'" "| fail | (not recorded) | mean 10.5 |"
    assert r(has) == 1
    capture erase "`c(tmpdir)'/dq190_old.dta"
}
_dq `=_rc' "report bands: an empty expected column is shown as (not recorded), not reconstructed"

foreach f in "`L'" "`LB'" "`LC'" "`MD'" "`MD2'" "`LG'" {
    capture erase `"`f'"'
}
macro drop DATAMAP_DQ

* ============================================================
* Summary
* ============================================================
display as result "Results: $PASS/$TC passed, $FAIL failed"
if $FAIL > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_dataqa_v190 tests=$TC pass=$PASS fail=$FAIL"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_dataqa_v190 tests=$TC pass=$PASS fail=$FAIL"
exit 0
