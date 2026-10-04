clear all
set more off
version 16.0
set linesize 255

* test_dataqa_v190_groupkeys.do - I4 (the ledger records a datacheck by()
* group by its values, and dataqa compare pairs groups by them) and the blank
* string by() label fix.  Oracles: count if for every group size, a hand
* decode of each escaped value against the data, and the number-keyed pairing
* the old ledger form gives, rebuilt by rewriting grp to "by(v group k)".

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
// decode the \xHH escapes of a bracketed value; independent of the writer
string scalar _dq_unesc(string scalar s)
{
    string scalar out, h
    real scalar i
    out = ""
    i = 1
    while (i <= strlen(s)) {
        if (substr(s, i, 2) == char(92) + "x") {
            h = substr(s, i + 2, 2)
            out = out + char(strpos("0123456789abcdef", substr(h, 1, 1)) * 16 - 16 + strpos("0123456789abcdef", substr(h, 2, 1)) - 1)
            i = i + 4
        }
        else {
            out = out + substr(s, i, 1)
            i++
        }
    }
    return(out)
}
string colvector _dq_unesc_all(string colvector v)
{
    string colvector o
    real scalar i
    o = v
    for (i = 1; i <= rows(v); i++) o[i] = _dq_unesc(v[i])
    return(o)
}
end

capture program drop _dq_has
program define _dq_has, rclass
    args f needle
    mata: st_numscalar("_dq_h", strpos(_dq_read(st_local("f")), st_local("needle")) > 0)
    return scalar has = scalar(_dq_h)
end

* rewrite a by-value ledger to the pre-1.9.0 number form: by(v | v=..) -> by(v group k),
* k the rank of the group within its call (the call's rows are in group order)
capture program drop _dq_oldform
program define _dq_oldform
    args infile outfile
    preserve
    quietly use `"`infile'"', clear
    quietly generate long _o = _n
    quietly generate strL _bv = ""
    quietly replace _bv = ustrregexs(1) if ustrregexm(grp, "^by\(([^()|]*) \| ")
    quietly generate strL _gp = ustrregexs(0) if ustrregexm(grp, "^by\([^()|]* \| ([^\[\])]|\[[^\[\]]*\])*\)")
    * the rank of the by-part within its (run, seq-block) call: first seen order of
    * the distinct parts within the run and variable list
    quietly generate long _k = .
    quietly levelsof run, local(runs)
    foreach r of local runs {
        local k = 0
        forvalues j = 1/`=_N' {
            if run[`j'] != "`r'" | _gp[`j'] == "" continue
            if _k[`j'] < . continue
            local ++k
            local gj = _gp[`j']
            local bj = _bv[`j']
            forvalues m = `j'/`=_N' {
                if run[`m'] == "`r'" & _gp[`m'] == `"`gj'"' & _bv[`m'] == `"`bj'"' quietly replace _k = `k' in `m'
            }
        }
    }
    quietly replace grp = "by(" + _bv + " group " + string(_k) + ")" if _gp != ""
    quietly drop _o _bv _gp _k
    quietly save `"`outfile'"', replace
    restore
end

local L  "`c(tmpdir)'/dq190g_a.dta"
local L2 "`c(tmpdir)'/dq190g_b.dta"
local LO "`c(tmpdir)'/dq190g_old.dta"
local LG "`c(tmpdir)'/dq190g_log.txt"
foreach f in "`L'" "`L2'" "`LO'" "`LG'" {
    capture erase `"`f'"'
}

**# the blank string by() label: the group is (blank), not its number

capture restore
capture noisily {
    clear
    set obs 14
    gen long id = _n
    gen str6 s = cond(_n <= 5, "a", cond(_n <= 9, "", "b"))
    gen double x = cond(_n == 6 | _n == 12, ., _n)
    capture erase "`L'"
    capture log close _dql
    log using "`LG'", text replace name(_dql)
    capture noisily datacheck, by(s) notmissing(x) name(bl) ledger("`L'", run(r1))
    local rc1 = _rc
    log close _dql
    assert `rc1' == 9
    * old label fell back to the group number: the blank group (group 1)
    * printed as "1".  Now every line of the table names it (blank)
    _dq_has "`LG'" "(blank)"
    assert r(has) == 1
    * hand oracle for the blank group: 4 rows, one with x missing
    quietly count if s == ""
    local nb = r(N)
    quietly count if s == "" & missing(x)
    local nbm = r(N)
    assert `nb' == 4 & `nbm' == 1
    preserve
    quietly use "`L'", clear
    quietly keep if family == "notmissing" & grp == "by(s | s=[])"
    assert _N == 1 & n_scope == `nb' & status == "fail" & observed == "`nbm' missing"
    restore
    * the group table row: N == count if, and no row is labelled with a number
    _dq_has "`LG'" "(blank)                     4"
    assert r(has) == 1
}
_dq `=_rc' "blank string by(): label (blank) in GROUPWISE, N == count if, ledger grp is s=[]"

capture restore
capture noisily {
    * numeric by() with . and .a: each its own group with its own code
    clear
    set obs 12
    gen long id = _n
    gen double v = cond(_n <= 4, 1, cond(_n <= 7, ., cond(_n <= 9, .a, .b)))
    gen byte y = _n != 5
    replace y = . if _n == 5
    capture erase "`L'"
    capture log close _dql
    log using "`LG'", text replace name(_dql)
    capture noisily datacheck, by(v) notmissing(y) name(nm) ledger("`L'", run(r1))
    log close _dql
    assert _rc == 9
    foreach code in "." ".a" ".b" {
        quietly count if v == `code'
        local n`=subinstr("`code'", ".", "d", 1)' = r(N)
    }
    assert `nd' == 3 & `nda' == 2 & `ndb' == 3
    preserve
    quietly use "`L'", clear
    quietly keep if family == "notmissing"
    assert _N == 4
    quietly count if grp == "by(v | v=1)" & n_scope == 4 & status == "pass"
    assert r(N) == 1
    quietly count if grp == "by(v | v=.)" & n_scope == `nd' & status == "fail"
    assert r(N) == 1
    quietly count if grp == "by(v | v=.a)" & n_scope == `nda' & status == "pass"
    assert r(N) == 1
    quietly count if grp == "by(v | v=.b)" & n_scope == `ndb' & status == "pass"
    assert r(N) == 1
    restore
    _dq_has "`LG'" "  .a "
    assert r(has) == 1
}
_dq `=_rc' "numeric by(): . .a .b are distinct groups, recorded by their code, sizes == count if"

**# the ledger form: values, not labels, hand-written exact text

capture restore
capture noisily {
    clear
    set obs 8
    gen long id = _n
    gen byte site = 3 + (_n > 4)
    gen int year = 2015
    label define sl 3 "Beta" 4 "Delta"
    label values site sl
    capture erase "`L'"
    datacheck, gatesonly by(site year) notmissing(id) name(f1) ledger("`L'", run(r1))
    preserve
    quietly use "`L'", clear
    quietly keep if family == "notmissing"
    assert _N == 2
    assert grp[1] == "by(site year | site=3 year=2015)"
    assert grp[2] == "by(site year | site=4 year=2015)"
    quietly count if strpos(grp, "Beta") | strpos(grp, "Delta") | strpos(grp, "group")
    assert r(N) == 0
    restore
    * relabel: the same groups, so the ledger is unchanged
    label define sl 3 "Gamma" 4 "Zeta", modify
    datacheck, gatesonly by(site year) notmissing(id) name(f1) ledger("`L'", run(r2))
    preserve
    quietly use "`L'", clear
    quietly keep if family == "notmissing"
    quietly count if run == "r1" & grp == "by(site year | site=3 year=2015)"
    local a = r(N)
    quietly count if run == "r2" & grp == "by(site year | site=3 year=2015)"
    assert `a' == 1 & r(N) == 1
    restore
    dataqa compare using "`L'", run(r2) baseline(r1)
    assert r(n_flags) == 0
}
_dq `=_rc' "ledger grp is by(vars | v=value ...): exact text, no value label, stable when labels change"

**# hostile string values round-trip

capture restore
capture noisily {
    clear
    set obs 22
    gen long id = _n
    gen strL hv = ""
    replace hv = "a b" in 1
    replace hv = "x=1" in 2
    replace hv = "p(q)" in 3
    replace hv = "q" + char(34) + "r" + char(34) + char(39) in 4
    replace hv = char(96) + char(34) in 5
    replace hv = char(36) + "x" + char(36) + "{y}" in 6
    replace hv = "[z]" in 7
    replace hv = "a|b" in 8
    replace hv = char(92) + "x41" in 9
    replace hv = "a;b); " in 10
    replace hv = "{c}" in 11
    replace hv = "it" + char(39) + "s" in 12
    replace hv = "" in 13
    replace hv = "x y=z (1)" in 14
    replace hv = "tab" + char(9) + "t" in 15
    replace hv = "nl" + char(10) + "n" in 16
    replace hv = "uni" + char(195) + char(169) in 17
    replace hv = "a b" in 18
    replace hv = "  lead" in 19
    replace hv = "trail  " in 20
    replace hv = "#" in 21
    replace hv = "by(hv | hv=[a])" in 22
    gen double x = .
    * strL cannot be a by() variable: use a fixed-width copy
    gen str30 h = hv
    drop hv
    capture erase "`L'"
    capture noisily datacheck, gatesonly by(h) notmissing(x) name(h1) ledger("`L'", run(r1))
    assert _rc == 9
    * every distinct value is one group; 22 rows hold 21 distinct (row 18 repeats row 1)
    quietly levelsof h, local(dv)
    quietly egen _g = group(h), missing
    quietly summarize _g
    local ng = r(max)
    assert `ng' == 21
    preserve
    quietly use "`L'", clear
    quietly keep if family == "notmissing"
    assert _N == `ng'
    quietly generate strL inner = ustrregexs(1) if ustrregexm(grp, "^by\(h \| h=\[(.*)\]\)$")
    * decode each ledger value and match it to the data values (multiset)
    tempfile led
    quietly keep inner n_scope
    quietly generate str60 dec = ""
    mata: st_sstore(., "dec", _dq_unesc_all(st_sdata(., "inner")))
    quietly save "`led'"
    restore
    preserve
    quietly collapse (count) nobs = id, by(h)
    rename h dec
    tempfile dat
    quietly save "`dat'"
    quietly use "`led'", clear
    quietly merge 1:1 dec using "`dat'"
    quietly count if _merge != 3
    assert r(N) == 0
    * group sizes round-trip too
    assert n_scope == nobs
    restore
    * the ledger reads back, and the same data pair 1:1 with itself
    capture datacheck, gatesonly by(h) notmissing(x) name(h1) ledger("`L'", run(r2))
    assert _rc == 9
    dataqa compare using "`L'", run(r2) baseline(r1)
    assert r(n_flags) == 0
    quietly dataqa report using "`L'", run(r2)
    capture dataqa assert using "`L'", run(r2)
    assert _rc == 9
}
_dq `=_rc' "hostile by() values (spaces, =, |, quotes, backtick, \$, brackets, braces, tab, newline) are 21 distinct, decodable groups"

**# the new level that sorts first: value pairing vs number pairing

capture restore
capture noisily {
    * run 1: sites 2 3 4 with 10, 20, 40 rows.  Run 2 adds site 1 (15 rows).
    clear
    set obs 70
    gen long id = _n
    gen byte site = cond(_n <= 10, 2, cond(_n <= 30, 3, 4))
    gen double x = 1
    capture erase "`L'"
    datacheck, gatesonly by(site) notmissing(x) name(ins) ledger("`L'", run(r1))
    clear
    set obs 85
    gen long id = _n
    gen byte site = cond(_n <= 15, 1, cond(_n <= 25, 2, cond(_n <= 45, 3, 4)))
    gen double x = 1
    datacheck, gatesonly by(site) notmissing(x) name(ins) ledger("`L'", run(r2))
    * by value: every surviving group pairs with itself (no N drift), site 1 is new
    capture log close _dql
    log using "`LG'", text replace name(_dql)
    dataqa compare using "`L'", run(r2) baseline(r1)
    local nf_val = r(n_flags)
    log close _dql
    assert `nf_val' == 1
    _dq_has "`LG'" "ins notmissing(x) [by(site | site=1)]: a group not in the baseline"
    assert r(has) == 1
    _dq_has "`LG'" "N  "
    assert r(has) == 0
    * the number scheme (the same two runs in the pre-1.9.0 form) pairs group k
    * with group k: 10 -> 15, 20 -> 10, 40 -> 20, all three wrong
    _dq_oldform "`L'" "`LO'"
    preserve
    quietly use "`LO'", clear
    quietly keep if family == "notmissing"
    assert grp[1] == "by(site group 1)" & grp[2] == "by(site group 2)"
    assert strpos(grp[4], "group 1") > 0 & strpos(grp[7], "group 4") > 0
    restore
    capture log close _dql
    log using "`LG'", text replace name(_dql)
    dataqa compare using "`LO'", run(r2) baseline(r1)
    local nf_old = r(n_flags)
    log close _dql
    assert `nf_old' == 3
    _dq_has "`LG'" "10 -> 15"
    assert r(has) == 1
    _dq_has "`LG'" "40 -> 20"
    assert r(has) == 1
}
_dq `=_rc' "new site sorting first: values pair 3 survivors with themselves and report 1 new group; numbers mis-pair all 3"

**# old ledgers load, report, assert and compare among themselves

capture restore
capture noisily {
    dataqa report using "`LO'", run(r2)
    assert r(n_failed) == 0
    dataqa assert using "`LO'", run(r2)
    assert r(n_failed) == 0
    * old against old, same data: no drift
    dataqa compare using "`LO'", run(r1) baseline(r1)
    assert r(n_flags) == 0
}
_dq `=_rc' "pre-1.9.0 ledger (group N): report, assert and compare against itself still work"

**# old baseline against a new run: detected, never paired by number against value

capture restore
capture noisily {
    * the baseline run r1 of the old-form file against run r2 of the new-form file
    preserve
    quietly use "`L'", clear
    quietly keep if run == "r2"
    quietly save "`L2'", replace
    quietly use "`LO'", clear
    quietly keep if run == "r1"
    quietly append using "`L2'"
    quietly save "`L2'", replace
    restore
    capture log close _dql
    log using "`LG'", text replace name(_dql)
    dataqa compare using "`L2'", run(r2) baseline(r1)
    local nf = r(n_flags)
    log close _dql
    * one mixed flag for the gate; no N drift from number-vs-value pairs, no absent
    assert `nf' == 1
    _dq_has "`LG'" "mixed  by(site)"
    assert r(has) == 1
    _dq_has "`LG'" "N  "
    assert r(has) == 0
    _dq_has "`LG'" "absent"
    assert r(has) == 0
    * the reverse mix: a new-form baseline against an old-form run
    preserve
    quietly use "`LO'", clear
    quietly keep if run == "r2"
    quietly save "`L2'", replace
    quietly use "`L'", clear
    quietly keep if run == "r1"
    quietly append using "`L2'"
    quietly save "`L2'", replace
    restore
    capture log close _dql
    log using "`LG'", text replace name(_dql)
    dataqa compare using "`L2'", run(r2) baseline(r1)
    local nf = r(n_flags)
    log close _dql
    assert `nf' == 1
    _dq_has "`LG'" "mixed  by(site)"
    assert r(has) == 1
}
_dq `=_rc' "old-form baseline against new-form run (and the reverse) is flagged mixed, not paired"

**# maskrare: a withheld group is not named by value

capture restore
capture noisily {
    clear
    set obs 63
    gen long id = _n
    gen int site = cond(_n <= 30, 2, cond(_n <= 60, 3, 7777))
    gen double x = 1
    capture erase "`L'"
    capture log close _dql
    log using "`LG'", text replace name(_dql)
    capture noisily datacheck, by(site) notmissing(x) isid(id) maskrare mincell(5) name(mk) ledger("`L'", run(r1))
    log close _dql
    assert _rc == 0
    * site 7777 has 3 rows: below the mask, so it is withheld everywhere
    quietly count if site == 7777
    assert r(N) == 3
    _dq_has "`LG'" "7777"
    assert r(has) == 0
    preserve
    quietly use "`L'", clear
    ds, has(type string)
    local sv `r(varlist)'
    foreach v of local sv {
        quietly count if strpos(`v', "7777") > 0
        assert r(N) == 0
    }
    * 3 rows are withheld, and so is the smallest shown group (site 2) that
    * keeps the 3 from being recovered as N minus the shown groups: only
    * site 3 is named by value; the other two carry their numbers
    quietly count if family == "notmissing" & grp == "by(site | site=3)" & n_scope == 30
    assert r(N) == 1
    quietly count if family == "notmissing" & regexm(grp, "^by\(site group [0-9]+\)$")
    assert r(N) == 2
    quietly count if family == "notmissing" & regexm(grp, "^by\(site group [0-9]+\)$") & missing(n_scope)
    assert r(N) == 2
    quietly count if strpos(grp, "site=2") | strpos(grp, "site=7777")
    assert r(N) == 0
    restore
    * the same call without the mask names every group, 7777 included: the
    * mask is what holds the value back
    capture erase "`L'"
    datacheck, gatesonly by(site) notmissing(x) name(mk) ledger("`L'", run(r1))
    preserve
    quietly use "`L'", clear
    quietly count if grp == "by(site | site=7777)"
    assert r(N) == 1
    restore
}
_dq `=_rc' "maskrare: a group withheld from the tables is not named by value in the ledger or the log"

**# events(): the level text is the value, not the label, and still supersedes

capture restore
capture noisily {
    clear
    set obs 40
    gen byte lv = ceil(_n / 20)
    label define lvl 1 "Low" 2 "High"
    label values lv lvl
    gen byte ev = _n <= 25
    capture erase "`L'"
    capture noisily datacheck, gatesonly name(ev) events(ev: lv, min(10)) ledger("`L'", run(r1))
    assert _rc == 9
    preserve
    quietly use "`L'", clear
    quietly keep if family == "events" & status == "fail"
    assert _N == 1 & grp == "lv = 2"
    restore
    replace ev = 1
    datacheck, gatesonly name(ev) events(ev: lv, min(10)) ledger("`L'", run(r1))
    dataqa assert using "`L'", run(r1)
    assert r(n_failed) == 0 & r(n_superseded) == 1
    * inside by(): by value, then the level, and the passing rerun supersedes
    replace ev = _n <= 25
    gen byte g = 1 + (_n > 20)
    capture erase "`L'"
    capture noisily datacheck, gatesonly by(g) name(ev) events(ev: lv, min(10)) ledger("`L'", run(r1))
    assert _rc == 9
    preserve
    quietly use "`L'", clear
    quietly keep if family == "events" & status == "fail"
    assert _N == 1 & grp == "by(g | g=2); lv = 2"
    restore
    replace ev = 1
    datacheck, gatesonly by(g) name(ev) events(ev: lv, min(10)) ledger("`L'", run(r1))
    dataqa assert using "`L'", run(r1)
    assert r(n_failed) == 0 & r(n_superseded) == 2
}
_dq `=_rc' "events(): grp carries the level value (lv = 2); inside by() it follows the by value; a rerun supersedes"

capture restore
capture noisily {
    clear
    set obs 40
    gen byte g = ceil(_n / 20)
    gen double x = cond(g == 2, 10, 1)
    capture erase "`L'"
    capture noisily datacheck, gatesonly name(gs) groupstat(mean x, by(g) band(0 2)) warn ledger("`L'", run(r1))
    dataqa report using "`L'", run(r1)
    assert r(n_warned) == 1
    replace x = 1
    datacheck, gatesonly name(gs) groupstat(mean x, by(g) band(0 2)) warn ledger("`L'", run(r1))
    dataqa report using "`L'", run(r1)
    assert r(n_warned) == 0 & r(n_superseded) == 2
    * under by(): by value + groupstat level; superseded by the passing rerun
    gen byte h = 1
    replace x = cond(g == 2, 10, 1)
    capture erase "`L'"
    capture noisily datacheck, gatesonly by(h) name(gs) groupstat(mean x, by(g) band(0 2)) warn ledger("`L'", run(r1))
    dataqa report using "`L'", run(r1)
    assert r(n_warned) == 1
    replace x = 1
    datacheck, gatesonly by(h) name(gs) groupstat(mean x, by(g) band(0 2)) warn ledger("`L'", run(r1))
    dataqa report using "`L'", run(r1)
    assert r(n_warned) == 0
}
_dq `=_rc' "groupstat() band level text still supersedes, alone and under a by() value"

foreach f in "`L'" "`L2'" "`LO'" "`LG'" "`c(tmpdir)'/dq190g_ex.dta" {
    capture erase `"`f'"'
}
macro drop DATAMAP_DQ

* ============================================================
* Summary
* ============================================================
display as result "Results: $PASS/$TC passed, $FAIL failed"
if $FAIL > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_dataqa_v190_groupkeys tests=$TC pass=$PASS fail=$FAIL"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_dataqa_v190_groupkeys tests=$TC pass=$PASS fail=$FAIL"
exit 0
