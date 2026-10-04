clear all
set more off
version 16.0
set linesize 255

* test_dataqa_v190_defaults.do - dataqa set baseline() baseledger() (U6), the
* ledger path rule shared by writers and readers, and the end-to-end pipeline
* example of dataqa.sthlp (D5).  Oracles are hand-built run contents, a
* distinct-file check on disk, and planted defects that must halt.

* === Bootstrap: targeted local reinstall ===
local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard
macro drop DATAMAP_DQ

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

* r(s) = the words of a compound-quoted list, quotes stripped
capture program drop _dq_strip
program define _dq_strip, rclass
    local out ""
    foreach x of local 0 {
        local out `out' `x'
    }
    return local s = strtrim("`out'")
end

* a run of isid gates, one per name, appended to ledger L under label run
capture program drop _dq_run
program define _dq_run
    args L run names
    clear
    set obs 20
    gen long id = _n
    dataqa set ledger("`L'") run(`run')
    foreach n of local names {
        datacheck, gatesonly isid(id) name(`n')
    }
    dataqa set clear
end

* number of ledger rows of a run read straight from the file
capture program drop _dq_nrows
program define _dq_nrows, rclass
    args f run
    preserve
    quietly use `"`f'"', clear
    quietly count if run == `"`run'"'
    return scalar n = r(N)
    restore
end

local T "`c(tmpdir)'"
local L  "`T'/dq190d_all.dta"
local LB "`T'/dq190d_base.dta"
local LC "`T'/dq190d_cur.dta"
foreach f in "`L'" "`LB'" "`LC'" {
    capture erase `"`f'"'
}

**# Fixtures
* L: b0 = alpha beta gamma, n1 = alpha beta, n2 = alpha beta gamma
* LB: b0 = alpha beta (a baseline that n1 satisfies)
* LC: n1 = alpha beta (no b0 here)
capture noisily {
    _dq_run "`L'" b0 "alpha beta gamma"
    _dq_run "`L'" n1 "alpha beta"
    _dq_run "`L'" n2 "alpha beta gamma"
    _dq_run "`LB'" b0 "alpha beta"
    _dq_run "`LC'" n1 "alpha beta"
    _dq_nrows "`L'" b0
    assert r(n) == 3
    _dq_nrows "`L'" n1
    assert r(n) == 2
    _dq_nrows "`LB'" b0
    assert r(n) == 2
}
_dq `=_rc' "fixture ledgers hold the planned rows per run"

**# Parse, display, clear
capture noisily {
    dataqa set ledger("`L'") run(n1) baseline(b0) baseledger("`LB'")
    assert strpos(`"$DATAMAP_DQ"', "baseline(b0)") > 0
    assert strpos(`"$DATAMAP_DQ"', `"baseledger("`LB'")"') > 0
    assert `"`r(defaults)'"' == `"$DATAMAP_DQ"'
    _datamap_dqdefaults
    assert `"`r(baseline)'"' == "b0" & `"`r(baseledger)'"' == `"`LB'"'
    assert `"`r(ledger)'"' == `"`L'"' & `"`r(run)'"' == "n1"
    dataqa set
    assert `"`r(defaults)'"' == `"$DATAMAP_DQ"'
    dataqa set clear
    assert `"$DATAMAP_DQ"' == ""
    _datamap_dqdefaults
    assert `"`r(baseline)'"' == "" & `"`r(baseledger)'"' == "" & r(active) == 0
}
_dq `=_rc' "set stores, shows and parses baseline/baseledger; clear drops them"

**# compare and assert with no arguments
capture noisily {
    dataqa set ledger("`L'") run(n1) baseline(b0)
    capture noisily dataqa compare
    assert _rc == 0
    assert `"`r(baseline)'"' == "b0" & `"`r(run)'"' == "n1"
    local nf_sess = r(n_flags)
    * one flagged change: gamma is in b0, absent from n1
    assert `nf_sess' == 1
    dataqa set clear
    dataqa compare using "`L'", run(n1) baseline(b0)
    assert r(n_flags) == `nf_sess'
}
_dq `=_rc' "compare with no arguments equals the explicit form (1 flag: gamma absent)"

capture noisily {
    dataqa set ledger("`L'") run(n1) baseline(b0)
    capture dataqa assert
    assert _rc == 9
    assert r(n_missing_base) == 1 & r(baseline) == "b0"
    _dq_strip `r(missing_base)'
    assert `"`r(s)'"' == "gamma"
    dataqa set clear
    capture dataqa assert using "`L'", run(n1) baseline(b0)
    assert _rc == 9
}
_dq `=_rc' "assert with only a session baseline halts on a dataset absent now (W4 check)"

capture noisily {
    dataqa set ledger("`L'") run(n1) baseline(b0)
    capture dataqa assert, optional(gamma)
    assert _rc == 0
    assert r(n_optional_absent) == 1
    * a baseline the run satisfies passes: n2 holds everything b0 does
    dataqa set ledger("`L'") run(n2) baseline(b0)
    capture dataqa assert
    assert _rc == 0 & r(n_missing_base) == 0
    * and an extra dataset now is not an error: n1 is a subset of n2
    dataqa set ledger("`L'") run(n2) baseline(n1)
    capture dataqa assert
    assert _rc == 0
}
_dq `=_rc' "session baseline: optional() waives, a satisfied baseline passes"

**# Precedence
capture noisily {
    dataqa set ledger("`L'") run(n1) baseline(b0)
    * the explicit baseline wins: n1 against n1 has nothing missing
    capture dataqa assert, baseline(n1)
    assert _rc == 0 & r(baseline) == "n1"
    dataqa compare, baseline(n1)
    assert r(baseline) == "n1" & r(n_flags) == 0
    * and the other way: session passes, explicit halts
    dataqa set ledger("`L'") run(n1) baseline(n1)
    capture dataqa assert
    assert _rc == 0
    capture dataqa assert, baseline(b0)
    assert _rc == 9
    dataqa set clear
}
_dq `=_rc' "an explicit baseline() beats the session baseline, both directions, assert and compare"

capture noisily {
    * session baseledger LB (b0 = alpha beta): n1 in LC satisfies it
    dataqa set ledger("`LC'") run(n1) baseline(b0) baseledger("`LB'")
    capture dataqa assert
    assert _rc == 0 & r(n_missing_base) == 0
    * explicit baseledger beats the session one: L's b0 holds gamma
    capture dataqa assert, baseledger("`L'")
    assert _rc == 9
    assert r(n_missing_base) == 1
    * the session baseledger belongs to the session baseline: an explicit
    * baseline without baseledger reads LC, which holds no b0
    capture dataqa assert, baseline(b0)
    assert _rc == 2000
    * without the session baseledger the same baseline is not in LC
    dataqa set ledger("`LC'") run(n1) baseline(b0)
    capture dataqa assert
    assert _rc == 2000
    dataqa set clear
}
_dq `=_rc' "session baseledger: read when the baseline is the session's, beaten by an explicit one"

**# Empty baseline rows
capture noisily {
    dataqa set ledger("`L'") run(n1) baseline(zzz)
    capture noisily dataqa compare
    assert _rc == 0 & r(baseline) == "zzz"
    capture dataqa assert
    assert _rc == 2000
    * the explicit-baseline error is the same one
    dataqa set ledger("`L'") run(n1)
    capture dataqa assert, baseline(zzz)
    assert _rc == 2000
    dataqa set clear
}
_dq `=_rc' "session baseline with no rows: compare notes it, assert errors r(2000) as an explicit one"

**# Blanking
capture noisily {
    dataqa set ledger("`L'") run(n1) baseline(b0)
    assert strpos(`"$DATAMAP_DQ"', "baseline(") > 0
    * a set without baseline() replaces the whole spec
    dataqa set ledger("`L'") run(n1)
    assert strpos(`"$DATAMAP_DQ"', "baseline") == 0
    capture dataqa assert
    assert _rc == 0
    dataqa compare
    assert `"`r(baseline)'"' == ""
    * baseline("") is the same
    dataqa set ledger("`L'") run(n1) baseline(b0)
    dataqa set ledger("`L'") run(n1) baseline("")
    assert strpos(`"$DATAMAP_DQ"', "baseline") == 0
    * the synthetic switch of the pipeline example
    global qa_baseline ""
    dataqa set ledger("`L'") run(n1) baseline($qa_baseline)
    assert strpos(`"$DATAMAP_DQ"', "baseline") == 0
    capture dataqa assert
    assert _rc == 0
    * baseline("") with baseledger() is still refused
    capture dataqa set ledger("`L'") run(n1) baseline("") baseledger("`LB'")
    assert _rc == 198
    dataqa set clear
}
_dq `=_rc' "baseline(), baseline(\"\") and an omitted baseline() all mean no baseline; set replaces the spec"

**# Refusals
capture noisily {
    dataqa set clear
    capture dataqa set ledger("`L'") run(n1) baseledger("`LB'")
    assert _rc == 198
    assert `"$DATAMAP_DQ"' == ""
    foreach bad in "a(b)" "a;b" "a|b" "a&b" "a<b" "a>b" "a\b" {
        capture dataqa set ledger("`L'") run(n1) baseline(`bad')
        assert _rc == 198
    }
    capture dataqa set ledger("`L'") run(n1) baseline(b0) baseledger("a;b")
    assert _rc == 198
    capture dataqa set ledger("`L'") run(n1) baseline(b0) baseledger("a|b.dta")
    assert _rc == 198
    assert `"$DATAMAP_DQ"' == ""
    * a baseledger without a suffix gets .dta as ledger() does
    dataqa set ledger("`L'") run(n1) baseline(b0) baseledger("`T'/dq190d_base")
    assert strpos(`"$DATAMAP_DQ"', `"baseledger("`T'/dq190d_base.dta")"') > 0
    dataqa set clear
    * the assert-side refusal survives: baseledger() without any baseline
    capture dataqa assert using "`L'", run(n1) baseledger("`LB'")
    assert _rc == 198
    * optional() without any baseline is ignored, not refused; a session
    * baseline set later makes the same call waive gamma
    capture dataqa assert using "`L'", run(n1) optional(gamma)
    assert _rc == 0 & r(n_optional_absent) == 0 & `"`r(baseline)'"' == ""
    dataqa set ledger("`L'") run(n1) baseline(b0)
    capture dataqa assert, optional(gamma)
    assert _rc == 0 & r(n_optional_absent) == 1 & `"`r(baseline)'"' == "b0"
    capture dataqa assert
    assert _rc == 9
    dataqa set clear
}
_dq `=_rc' "refusals: baseledger without baseline, hostile characters; optional() without a baseline is ignored"

**# datacheck and datamvp tolerate the new tokens
capture noisily {
    erase "`LC'"
    clear
    set obs 30
    gen long id = _n
    gen double x = mod(_n, 5)
    gen byte g = mod(_n, 3)
    dataqa set maskrare mincell(5) ledger("`LC'") run(tol) baseline(b0) baseledger("`LB'") signature
    datacheck, gatesonly isid(id) name(tolgate)
    _dq_nrows "`LC'" tol
    assert r(n) == 1
    * a call that fails still writes its error row through the same parser
    capture datacheck, gatesonly isid(nonexistent) name(tolbad)
    assert _rc != 0
    _dq_nrows "`LC'" tol
    assert r(n) == 2
    datamvp x g
    assert _rc == 0
    * hand-written global with the tokens in any order
    global DATAMAP_DQ `"baseledger("`LB'") baseline(b0) maskrare"'
    datacheck, gatesonly isid(id)
    datamvp x g
    * a malformed tail is still refused with the clean-up hint
    global DATAMAP_DQ `"baseline(b0) notanoption"'
    capture datacheck, gatesonly isid(id)
    assert _rc == 198
    dataqa set clear
}
_dq `=_rc' "datacheck (gate and error row) and datamvp accept baseline/baseledger tokens in DATAMAP_DQ"

**# Ledger path rule: writers and readers agree on one file
* foo.v2 -> foo.v2 (a suffix is kept, as save does), foo -> foo.dta,
* foo.dta -> foo.dta, foo.DTA -> foo.DTA.
capture noisily {
    local nstate = 0
    foreach pair in "foo.v2|foo.v2" "foo|foo.dta" "foo.dta|foo.dta" "foo.DTA|foo.DTA" {
        gettoken typed want : pair, parse("|")
        local want = subinstr("`want'", "|", "", 1)
        local P "`T'/dq190d_`typed'"
        local W "`T'/dq190d_`want'"
        foreach f in "`P'" "`W'" "`P'.dta" {
            capture erase `"`f'"'
        }
        * a stray suffixless file must never be read in place of the ledger
        if "`typed'" == "foo" {
            file open _sf using "`P'", write text replace
            file write _sf "not a ledger" _n
            file close _sf
        }
        clear
        set obs 12
        gen long id = _n
        * writer 1: datacheck ledger(); writer 2: dataqa set; writer 3: error row
        datacheck, gatesonly isid(id) name(w1) ledger("`P'", run(r1))
        assert `"`r(ledger)'"' == `"`W'"'
        confirm file `"`W'"'
        dataqa set ledger("`P'") run(r1)
        datacheck, gatesonly isid(id) name(w2)
        capture datacheck, gatesonly isid(nonexistent) name(w3)
        assert _rc != 0
        dataqa set clear
        _dq_nrows "`W'" r1
        assert r(n) == 3
        * the file is exactly one: the writers did not also create a second
        if "`want'" != "`typed'" capture confirm file `"`P'"'
        if "`typed'" == "foo.v2" {
            capture confirm file `"`P'.dta"'
            assert _rc != 0
        }
        * readers, naming the ledger as typed
        dataqa report using "`P'", run(r1)
        assert r(N) == 3 & `"`r(ledger)'"' == `"`W'"'
        capture dataqa assert using "`P'", run(r1) expect(w1 w2)
        * the error row of w3 halts it: the reader saw all 3 rows
        assert _rc == 9 & r(N) == 3 & r(n_errors) == 1
        * a run against itself: only the w3 error row is flagged
        dataqa compare using "`P'", run(r1) baseline(r1)
        assert r(n_flags) == 1
        * and as the writer reports it
        dataqa report using "`W'", run(r1)
        assert r(N) == 3
        * a baseledger named as typed is read through the same rule
        dataqa assert using "`L'", run(n1) baseline(r1) baseledger("`P'") optional(w1 w2 w3)
        assert r(n_optional_absent) == 3
        capture dataqa assert using "`L'", run(n1) baseline(r1) baseledger("`P'")
        assert _rc == 9 & r(n_missing_base) == 3
        local ++nstate
    }
    assert `nstate' == 4
}
_dq `=_rc' "ledger path rule: foo.v2 / foo / foo.dta / foo.DTA resolve to one file for every writer and reader"

* the reader refuses a path that is not there, rather than reading a neighbour
capture noisily {
    capture dataqa report using "`T'/dq190d_nosuch.v2", run(r1)
    assert _rc == 601
    capture dataqa report using "`T'/dq190d_nosuch", run(r1)
    assert _rc == 601
}
_dq `=_rc' "a missing ledger is r(601) under every spelling"

**# D5: the pipeline example of dataqa.sthlp, as printed
capture noisily {
    dataqa set clear
    tempfile ledger qalog md release
    dataqa set maskrare mincell(5) ledger("`ledger'") run(base) replace
    sysuse auto, clear
    datacheck, gatesonly isid(make) bands(stat(mean mpg 18 25)) name(auto_cars)
    sysuse nlsw88, clear
    datacheck, gatesonly isid(idcode) bands(stat(mean age 38 41)) name(nlsw)
    capture datacheck, minversion(1.9.0)
    if _rc display as error "datamap 1.9.0 or later is needed"
    assert _rc == 0
    global qa_synth 0
    global qa_baseline = cond($qa_synth, "", "base")
    dataqa set maskrare mincell(5) ledger("`ledger'") run(now) collect baseline($qa_baseline) replace
    assert strpos(`"$DATAMAP_DQ"', "baseline(base)") > 0 & strpos(`"$DATAMAP_DQ"', "collect") > 0
    log using "`qalog'", name(qa) text replace
    sysuse auto, clear
    datacheck, gatesonly isid(make) bands(stat(mean mpg 18 25)) name(auto_cars)
    sysuse nlsw88, clear
    datacheck, gatesonly isid(idcode) bands(stat(mean age 38 41)) name(nlsw)
    log close qa
    dataqa compare
    local cmp_flags = r(n_flags)
    local cmp_base `"`r(baseline)'"'
    dataqa report, markdown("`md'") replace bands
    dataqa export, saving("`release'") replace
    dataqa assert, expect(auto_cars nlsw)
    local as_base `"`r(baseline)'"'
    local as_failed = r(n_failed)
    dataqa set clear
    * outcome: identical gates, so nothing flagged; both runs held 4 rows? the
    * oracle is the count straight from the ledger
    assert `cmp_flags' == 0 & `"`cmp_base'"' == "base"
    assert `"`as_base'"' == "base" & `as_failed' == 0
    assert `"$DATAMAP_DQ"' == ""
    confirm file "`qalog'"
    confirm file "`md'"
    confirm file "`release'"
    _dq_nrows "`ledger'" base
    local nb = r(n)
    _dq_nrows "`ledger'" now
    assert r(n) == `nb' & `nb' >= 2
    preserve
    use "`release'", clear
    quietly count if run != "now"
    assert r(N) == 0
    quietly count
    assert r(N) == `nb'
    restore
}
_dq `=_rc' "D5 pipeline example runs as printed: compare clean, report/export written, assert passes"

* negative controls on the pipeline: the baseline check and the collected
* failure must halt under the session baseline
capture noisily {
    tempfile ledger
    dataqa set maskrare mincell(5) ledger("`ledger'") run(base) replace
    sysuse auto, clear
    datacheck, gatesonly isid(make) bands(stat(mean mpg 18 25)) name(auto_cars)
    sysuse nlsw88, clear
    datacheck, gatesonly isid(idcode) bands(stat(mean age 38 41)) name(nlsw)
    * the synthetic switch on: no baseline at all
    global qa_synth 1
    global qa_baseline = cond($qa_synth, "", "base")
    dataqa set maskrare mincell(5) ledger("`ledger'") run(now) collect baseline($qa_baseline) replace
    assert strpos(`"$DATAMAP_DQ"', "baseline") == 0
    sysuse auto, clear
    datacheck, gatesonly isid(make) bands(stat(mean mpg 18 25)) name(auto_cars)
    dataqa compare
    assert `"`r(baseline)'"' == ""
    * switch off again: nlsw never ran now, so the session baseline halts
    global qa_synth 0
    global qa_baseline = cond($qa_synth, "", "base")
    dataqa set maskrare mincell(5) ledger("`ledger'") run(now) collect baseline($qa_baseline)
    capture dataqa assert
    assert _rc == 9
    _dq_strip `r(missing_base)'
    assert `"`r(s)'"' == "nlsw"
    * a planted failing invariant, collected, halts at assert
    dataqa set maskrare mincell(5) ledger("`ledger'") run(bad) collect baseline(base)
    sysuse auto, clear
    datacheck, gatesonly isid(make) stat(mean mpg 40 50) name(auto_cars)
    sysuse nlsw88, clear
    datacheck, gatesonly isid(idcode) name(nlsw)
    capture dataqa assert
    assert _rc == 9
    assert !missing(r(n_failed)) & r(n_failed) >= 1
    dataqa set clear
}
_dq `=_rc' "pipeline negative controls: synthetic switch blanks the baseline; absent dataset and failed gate halt assert"

foreach f in "`L'" "`LB'" "`LC'" {
    capture erase `"`f'"'
}
foreach p in foo.v2 foo foo.dta foo.DTA {
    capture erase "`T'/dq190d_`p'"
}
macro drop DATAMAP_DQ qa_synth qa_baseline

display as result "Results: $PASS/$TC passed, $FAIL failed"
if $FAIL > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_dataqa_v190_defaults tests=$TC pass=$PASS fail=$FAIL"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_dataqa_v190_defaults tests=$TC pass=$PASS fail=$FAIL"
exit 0
