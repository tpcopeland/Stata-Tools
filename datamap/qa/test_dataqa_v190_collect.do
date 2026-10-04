clear all
set more off
version 16.0
set linesize 255

* test_dataqa_v190_collect.do - R4 (an error row for any non-gate exit of a
* datacheck call under a ledger) and W3 (dataqa set collect).  The planted
* defects: a call that fails to parse, a misspelled option, a bad rule()
* expression and a missing variable must each leave an error row that
* dataqa assert halts on; collect must change only the exit of a gate
* failure, never the ledger rows and never a non-gate error.

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
end

capture program drop _dq_has
program define _dq_has, rclass
    args f needle
    mata: st_numscalar("_dq_h", strpos(_dq_read(st_local("f")), st_local("needle")) > 0)
    return scalar has = scalar(_dq_h)
end

capture program drop _dq_fix
program define _dq_fix
    clear
    set obs 20
    gen long id = _n
    gen double x = _n
end

* rows of a ledger run with a given status: r(n)
capture program drop _dq_nstat
program define _dq_nstat, rclass
    args file run status
    preserve
    quietly use `"`file'"', clear
    quietly count if run == `"`run'"' & status == `"`status'"'
    return scalar n = r(N)
    restore
end

local L  "`c(tmpdir)'/dq190c_ledger.dta"
local L2 "`c(tmpdir)'/dq190c_ledger2.dta"
local LG "`c(tmpdir)'/dq190c_log.txt"
local MD "`c(tmpdir)'/dq190c_md.md"
local EX "`c(tmpdir)'/dq190c_ex.dta"
foreach f in "`L'" "`L2'" "`LG'" "`MD'" "`EX'" {
    capture erase `"`f'"'
}

**# R4: the fail-open, one planted defect at a time

* A good call, then four calls that exit with rc 198 / 111 under capture
* noisily.  Each leaves exactly one error row; assert halts naming auto.
local k = 0
foreach bad in `"rule("bad": x >>> 3)"' `"isdi(id)"' `"rule("e": nosuchvar > 3)"' `"notmissing(x) nonoption"' {
    local ++k
    capture noisily {
        _dq_fix
        capture erase "`L'"
        dataqa set ledger("`L'") run(r`k')
        datacheck, gatesonly isid(id) name(auto)
        capture datacheck, gatesonly name(auto) `bad'
        local rc_call = _rc
        assert `rc_call' != 0 & `rc_call' != 9
        _dq_nstat "`L'" r`k' error
        assert r(n) == 1
        * the row carries the original rc, the dataset name and family call
        preserve
        quietly use "`L'", clear
        quietly keep if status == "error"
        assert _N == 1
        assert family == "call" & dataset == "auto" & observed_num == `rc_call' ///
            & observed == "rc `rc_call'"
        restore
        * assert halts, and names the dataset and the rc
        capture log close _dql
        log using "`LG'", text replace name(_dql)
        capture noisily dataqa assert, run(r`k')
        local arc = _rc
        local ne = r(n_errors)
        log close _dql
        assert `arc' == 9
        assert `ne' == 1
        _dq_has "`LG'" "auto: call error, rc `rc_call'"
        assert r(has) == 1
        dataqa set clear
    }
    _dq `=_rc' "R4 case `k': a failed call leaves an error row with the original rc; assert exits 9 naming auto"
}
capture log close _dql

* the same call with no error row (a clean ledger) passes: the control
capture noisily {
    _dq_fix
    capture erase "`L'"
    dataqa set ledger("`L'") run(ok)
    datacheck, gatesonly isid(id) name(auto)
    dataqa assert, run(ok)
    assert r(n_errors) == 0
    dataqa set clear
}
_dq `=_rc' "R4 control: a clean run still passes assert"

* a missing variable in the varlist (rc 111), data name from c(filename)
capture noisily {
    _dq_fix
    capture erase "`L'"
    dataqa set ledger("`L'") run(mv)
    capture datacheck nosuchvar, gatesonly isid(id)
    assert _rc == 111
    _dq_nstat "`L'" mv error
    assert r(n) == 1
    capture dataqa assert, run(mv)
    assert _rc == 9
    dataqa set clear
}
_dq `=_rc' "R4: a missing variable (rc 111) writes an error row with an empty dataset name; assert exits 9"

* a ledger() given only on the failing call, which fails in syntax
capture noisily {
    _dq_fix
    capture erase "`L2'"
    capture datacheck, gatesonly ledger("`L2'", run(ex1)) name(zed) isdi(id)
    assert _rc == 198
    preserve
    quietly use "`L2'", clear
    assert _N == 1 & run == "ex1" & dataset == "zed" & status == "error" & observed_num == 198
    restore
    capture dataqa assert using "`L2'", run(ex1)
    assert _rc == 9
}
_dq `=_rc' "R4: ledger(file, run()) and name() are read from the raw line of a call that failed to parse"

* the minversion() probe and Break write no row
capture noisily {
    _dq_fix
    capture erase "`L'"
    dataqa set ledger("`L'") run(mp)
    datacheck, gatesonly isid(id) name(auto)
    datacheck, minversion(1.0.0)
    capture datacheck, minversion(99.0.0)
    assert _rc == 198
    _dq_nstat "`L'" mp error
    assert r(n) == 0
    quietly use "`L'", clear
    assert _N == 1
    dataqa set clear
}
_dq `=_rc' "R4: the minversion() probe, passing or failing, writes no row"

* a gate failure (rc 9) writes gate rows only, no error row
capture noisily {
    _dq_fix
    capture erase "`L'"
    dataqa set ledger("`L'") run(g9)
    capture datacheck, gatesonly rule("big": x <= 18) name(auto)
    assert _rc == 9
    _dq_nstat "`L'" g9 error
    assert r(n) == 0
    _dq_nstat "`L'" g9 fail
    assert r(n) == 1
    dataqa set clear
}
_dq `=_rc' "R4: a gate failure (exit 9) adds no error row"

* an error row is never superseded: a later clean call of the same dataset
capture noisily {
    _dq_fix
    capture erase "`L'"
    dataqa set ledger("`L'") run(ns)
    capture datacheck, gatesonly name(auto) isdi(id)
    capture datacheck, gatesonly name(auto) isdi(id)
    datacheck, gatesonly isid(id) name(auto)
    datacheck, gatesonly isid(id) name(auto)
    capture dataqa assert, run(ns)
    assert _rc == 9
    assert r(n_errors) == 2
    dataqa set clear
}
_dq `=_rc' "R4: error rows are not superseded by later calls of the same dataset"

* an unwritable ledger: the original rc comes back with a note
capture noisily {
    _dq_fix
    capture datacheck, gatesonly name(auto) isdi(id) ledger("/nonexistent_dq_dir/none.dta")
    assert _rc == 198
}
_dq `=_rc' "R4: a failed error-row write still exits with the original rc"

**# R4: report, export and compare on a ledger holding error rows

capture noisily {
    _dq_fix
    capture erase "`L'"
    dataqa set ledger("`L'") run(b0)
    datacheck, gatesonly isid(id) name(auto)
    dataqa set ledger("`L'") run(c1)
    capture datacheck, gatesonly name(auto) isdi(id)
    datacheck, gatesonly isid(id) name(auto)
    dataqa set clear
    capture log close _dql
    log using "`LG'", text replace name(_dql)
    dataqa report using "`L'", run(c1) bands markdown("`MD'") replace
    local nf = r(n_failed)
    log close _dql
    assert `nf' == 1
    _dq_has "`LG'" "auto: rc 198"
    assert r(has) == 1
    _dq_has "`MD'" "call error, rc 198"
    assert r(has) == 1
    * the markdown draft does not call a run with an error row clean
    _dq_has "`MD'" "all gates passed"
    assert r(has) == 0
}
_dq `=_rc' "report and the markdown draft show the error row, never calling the run clean"
* export must refuse, not crash
capture noisily {
    capture dataqa export using "`L'", run(c1) saving("`EX'") replace
    assert _rc == 459
    capture confirm file "`EX'"
    assert _rc != 0
}
_dq `=_rc' "export refuses a run with an error row (rc 459) and writes nothing"
capture log close _dql

capture noisily {
    capture log close _dql
    log using "`LG'", text replace name(_dql)
    dataqa compare using "`L'", run(c1) baseline(b0)
    log close _dql
    assert r(n_flags) >= 1
    _dq_has "`LG'" "error  auto: the call exited with rc 198"
    assert r(has) == 1
    * the control: a baseline against itself flags nothing
    dataqa compare using "`L'", run(b0) baseline(b0)
    assert r(n_flags) == 0
}
_dq `=_rc' "compare flags a call that errors now and does not crash"
capture log close _dql

**# W3: collect

* without collect: exit 9; with collect: rc 0, rows written, r(n_failed) set,
* a clear line, and assert halts
capture noisily {
    _dq_fix
    capture erase "`L'"
    dataqa set ledger("`L'") run(w0)
    capture datacheck, gatesonly rule("big": x <= 18) name(auto)
    assert _rc == 9
    dataqa set ledger("`L'") run(w1) collect
    assert strpos(`"$DATAMAP_DQ"', "collect") > 0
    capture log close _dql
    log using "`LG'", text replace name(_dql)
    capture noisily datacheck, gatesonly rule("big": x <= 18) name(auto)
    local crc = _rc
    local nf = r(n_failed)
    local ne = r(n_errors)
    log close _dql
    assert `crc' == 0
    assert `nf' == 1 & `ne' == 1
    _dq_has "`LG'" "EXPECTATION VIOLATIONS (1): auto"
    assert r(has) == 1
    _dq_has "`LG'" "dataqa assert will halt"
    assert r(has) == 1
    _dq_nstat "`L'" w1 fail
    assert r(n) == 1
    _dq_nstat "`L'" w0 fail
    assert r(n) == 1
    capture dataqa assert, run(w1)
    assert _rc == 9
    assert r(n_failed) == 1
    dataqa set clear
}
_dq `=_rc' "collect: a failing gate returns rc 0 with r(n_failed), prints its block, writes its rows; assert halts; without collect it is exit 9"
capture log close _dql

* a non-gate error still halts under collect, with an error row
capture noisily {
    _dq_fix
    capture erase "`L'"
    dataqa set ledger("`L'") run(w2) collect
    capture datacheck, gatesonly isid(id) name(auto) isdi(id)
    assert _rc == 198
    _dq_nstat "`L'" w2 error
    assert r(n) == 1
    dataqa set clear
}
_dq `=_rc' "collect: a parse error still exits nonzero and writes its error row"

* collect together with bandwarn: band rows warn, an invariant fail halts
capture noisily {
    _dq_fix
    capture erase "`L'"
    dataqa set ledger("`L'") run(bw1) collect bandwarn
    * only a band fails: no halt, no failed row, assert passes
    datacheck, gatesonly isid(id) bands(stat(mean x 0 5)) name(alpha)
    _dq_nstat "`L'" bw1 warn
    assert r(n) == 1
    _dq_nstat "`L'" bw1 fail
    assert r(n) == 0
    dataqa assert, run(bw1)
    * an invariant fails as well: rc 0 under collect, assert halts
    dataqa set ledger("`L'") run(bw2) collect bandwarn
    datacheck, gatesonly rule("big": x <= 18) bands(stat(mean x 0 5)) name(alpha)
    assert r(n_failed) >= 1
    _dq_nstat "`L'" bw2 warn
    assert r(n) == 1
    _dq_nstat "`L'" bw2 fail
    assert r(n) == 1
    capture dataqa assert, run(bw2)
    assert _rc == 9
    dataqa set clear
}
_dq `=_rc' "collect + bandwarn: band rows are warns, an invariant fail still halts at assert"

* collect with no ledger: no effect, exit 9 and a note
capture noisily {
    _dq_fix
    dataqa set collect
    capture log close _dql
    log using "`LG'", text replace name(_dql)
    capture noisily datacheck, gatesonly rule("big": x <= 18) name(auto)
    local crc = _rc
    log close _dql
    assert `crc' == 9
    _dq_has "`LG'" "collect has no effect without a ledger"
    assert r(has) == 1
    dataqa set clear
}
_dq `=_rc' "collect without a ledger: exit 9 with a note"
capture log close _dql

* a ledger write failure under collect is nonzero
capture noisily {
    _dq_fix
    dataqa set collect
    capture datacheck, gatesonly rule("big": x <= 18) name(auto) ledger("/nonexistent_dq_dir/none.dta")
    assert _rc != 0
    dataqa set clear
}
_dq `=_rc' "collect: a failed ledger append exits nonzero, never 0"

* an explicit ledger() with collect from the session
capture noisily {
    _dq_fix
    capture erase "`L'"
    dataqa set collect
    datacheck, gatesonly rule("big": x <= 18) name(auto) ledger("`L'", run(ex))
    assert r(n_failed) == 1
    _dq_nstat "`L'" ex fail
    assert r(n) == 1
    dataqa set clear
}
_dq `=_rc' "collect applies with an explicit ledger() as well"

* set shows collect; clear drops it; datamvp tolerates it
capture noisily {
    dataqa set ledger("`L'") run(sh) collect
    assert strpos(`"`r(defaults)'"', "collect") > 0
    _datamap_dqdefaults
    assert r(collect) == 1 & r(active) == 1
    _dq_fix
    datamvp id x
    dataqa set clear
    assert `"$DATAMAP_DQ"' == ""
    _datamap_dqdefaults
    assert r(collect) == 0 & r(active) == 0
    dataqa set maskrare mincell(5)
    _datamap_dqdefaults
    assert r(collect) == 0
    dataqa set clear
}
_dq `=_rc' "dataqa set shows collect, clear drops it, datamvp runs under it"

foreach f in "`L'" "`L2'" "`LG'" "`MD'" "`EX'" {
    capture erase `"`f'"'
}
macro drop DATAMAP_DQ

* ============================================================
* Summary
* ============================================================
display as result "Results: $PASS/$TC passed, $FAIL failed"
if $FAIL > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_dataqa_v190_collect tests=$TC pass=$PASS fail=$FAIL"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_dataqa_v190_collect tests=$TC pass=$PASS fail=$FAIL"
exit 0
