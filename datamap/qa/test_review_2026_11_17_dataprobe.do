*! test_review_2026_11_17_dataprobe.do  2026/11/17
*! dataprobe fixes from the 2026-11-17 external review (slice A): user text
*! re-expanded as macros, masking and safe gaps, empty-sample crashes,
*! option parsing, help-file lint
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Oracles are base Stata (count, summarize, collapse, string()) on fixtures
* built here, or the documented message text; dataprobe's own output is
* never the expected value.  Hostile text ($name, a backtick) is built from
* char() in Mata and run as `macval(cmd)', so the do-file never expands it;
* global b is set so an expansion would show as EXPANDED_B.
*
*   R1  smallcells(): "a$b" and a backtick in a condition or if reach the
*       evaluator and the ledger as typed (microdata and results table)
*   R2  if 0 with by(), maskrare and snapshot()/diff(): no Mata r(3300)
*   R3  reconcile(..., by()) under maskrare: failing-group counts masked,
*       and withheld when the unnamed-group count is masked
*   R4  safe: a likely identifier read only by a gate is excluded; a
*       topvalues() of one is refused before any output
*   R5  stat(): a compound-quoted entry; "a$b" and a backtick in the if
*   R6  events(): string levels and value labels holding $ or a backtick,
*       and an events if holding $, printed and stored as typed
*   R7  safe inrange() on a date: p1/p99 withheld, not month dates
*   R8  violations(): noreplace and unknown words are r(198) before work
*   R9  diff() and isid()/nodups on 0 rows: key unique after, no r(111)
*   R10 diff()/reconcile() name.dta missing never reads name.dta.dta
*   R11 topvalues() with no varlist and brief: r(198), not a silent drop
*   R12 r(masked) is 1 when CONTINUOUS or DATE suppresses a statistic
*   R13 allowed()/forbid()/notvalues()/regex() values holding $ or a
*       backtick match as typed (forbid passed silently before)
*   R14 stat(ess)/groupstat(ess) with a negative weight: r(459)
*   R15 dataprobe.sthlp: small:cells abbreviation, synopt widths
*   R16 stat() parse errors echo an entry holding $ as typed (the ratio
*       word-count message expanded it through a one-line if)
*   R17 groupstat(): a by() value or value label holding a double quote
*       then a right quote, $ or a backtick prints and is stored as typed,
*       with and without maskrare, one statistic or several (was r(132))
*   R18 single(), checks() and keyset() name.dta missing is r(601), never
*       name.dta.dta read at rc 0; name without .dta still finds name.dta
*   R19 violations("a b.dta", replace): a quoted file name with a space is
*       written (r(198) "got b.dta , replace" before); replace still checked
*   R20 contract: stored results are not masked; with the reconcile()
*       difference [suppressed] on the console, r(reconcile_rows_delta) and
*       r(reconcile_ids_delta) hold the exact difference
*   R21 help text: brief + topvalues(), violations() suboption and quoted
*       file, .dta read as given, groupstat(ess) r(459); datamap datesafe
*       categorical()
version 16.0
clear all
set more off
set linesize 255
capture log close _all
log using "test_review_2026_11_17_dataprobe.log", replace text name(main)
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
* restored before the RESULT line so a runner's install sandbox stays in force
local _old_plus : sysdir PLUS
local _old_personal : sysdir PERSONAL
tempfile base
local W "`base'_rv1117"
capture mkdir "`W'"
capture mkdir "`W'/plus"
capture mkdir "`W'/personal"
mata: assert(direxists(st_local("W") + "/plus"))
sysdir set PLUS "`W'/plus"
sysdir set PERSONAL "`W'/personal"
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace
discard
macro drop DATAMAP_DQ
global b "EXPANDED_B"
global TC 0
global PASS 0
global FAIL 0
capture program drop _rv
program define _rv
    args rc desc
    global TC = $TC + 1
    if `rc' == 0 {
        global PASS = $PASS + 1
        display as result "PASS: `desc'"
    }
    else {
        global FAIL = $FAIL + 1
        display as error "FAIL (rc `rc'): `desc'"
    }
end

**# Helpers

* _rv_cap file : cmd   runs cmd (captured) with its output in a text log;
* the rc is left in the caller's local _rv_rc and r() is passed through
capture program drop _rv_cap
program define _rv_cap, rclass
    gettoken f 0 : 0
    gettoken colon 0 : 0
    capture log close _rvc
    quietly log using `"`f'"', replace text name(_rvc)
    capture noisily `macval(0)'
    local rc = _rc
    return add
    quietly log close _rvc
    c_local _rv_rc `rc'
end

capture mata: mata drop _rv_x()
capture mata: mata drop _rv_lines()
capture mata: mata drop _rv_has()
capture mata: mata drop _rv_eq()
mata:
// {D} is $, {B} a backtick, {Q} a right quote: hostile text written
// without a live macro character in this file
string scalar _rv_x(string scalar s)
{
	return(subinstr(subinstr(subinstr(s, "{D}", char(36)), "{B}", char(96)), "{Q}", char(39)))
}
// the log's lines joined, Stata's "> " continuation removed
string scalar _rv_lines(string scalar fn)
{
	string colvector L
	string scalar T
	real scalar i
	L = cat(fn)
	T = ""
	for (i = 1; i <= rows(L); i++) {
		if (substr(L[i], 1, 2) == "> ") T = T + substr(L[i], 3, .)
		else T = T + char(10) + L[i]
	}
	return(T)
}
real scalar _rv_has(string scalar fn, string scalar needle)
{
	return(strpos(_rv_lines(fn), _rv_x(needle)) > 0)
}
// row r of string variable v in the current frame equals the expected text
real scalar _rv_eq(real scalar r, string scalar v, string scalar want)
{
	string scalar got
	got = st_sdata(r, v)
	if (got != _rv_x(want)) {
		printf("{err}  got:  %s\n", got)
		printf("{err}  want: %s\n", _rv_x(want))
		return(0)
	}
	return(1)
}
end

local f "`W'/cap.log"

**# R1 smallcells(): macro characters in a condition or if

capture noisily {
    * microdata: one row of s == "a$b" in stratum g = 1; six rows hold the
    * text an expansion would produce, so an expanded condition passes
    clear
    quietly set obs 10
    generate str12 s = "z"
    quietly replace s = "a" + char(36) + "b" in 1
    quietly replace s = "aEXPANDED_B" in 2/7
    generate byte g = 1
    quietly count if s == "a" + char(36) + "b" & g == 1
    assert r(N) == 1
    mata: st_local("cmd", _rv_x(`"dataprobe, gatesonly mincell(5) smallcells((s == "a{D}b"), by(g)) violations(rv1, replace)"'))
    _rv_cap "`f'" : `macval(cmd)'
    assert `_rv_rc' == 9
    frame rv1 {
        assert _N == 1
        mata: assert(_rv_eq(1, "label", `"(s == "a{D}b"), by(g)"'))
        mata: assert(_rv_eq(1, "message", `"smallcells((s == "a{D}b"), by(g)): 1 cells fail, (s == "a{D}b") in g=1 (rows); expected no cell of 1..4 rows (m=5)"'))
    }
    mata: assert(_rv_has(st_local("f"), "(s == " + char(34) + "a{D}b" + char(34) + ") in g=1"))
    mata: assert(!_rv_has(st_local("f"), "EXPANDED_B"))
    * a results table: n = 3 on the row the if selects
    clear
    quietly set obs 4
    generate str12 s = "z"
    quietly replace s = "a" + char(36) + "b" in 1
    generate n = 10
    quietly replace n = 3 in 1
    mata: st_local("cmd", _rv_x(`"dataprobe, gatesonly mincell(5) smallcells(n if s == "a{D}b") violations(rv1, replace)"'))
    _rv_cap "`f'" : `macval(cmd)'
    assert `_rv_rc' == 9
    frame rv1 {
        mata: assert(_rv_eq(1, "variable", `"n if s == "a{D}b""'))
        mata: assert(_rv_eq(1, "message", `"smallcells(n if s == "a{D}b"): 1 table rows fail, n (1 small); expected no released count in 1..4 (m=5)"'))
    }
    * a backtick in the condition: evaluated as typed, not an error
    quietly replace s = "a" + char(96) + "b" + char(39) in 1
    mata: st_local("cmd", _rv_x(`"dataprobe, gatesonly mincell(5) smallcells(n if s == "a{B}b{Q}") violations(rv1, replace)"'))
    _rv_cap "`f'" : `macval(cmd)'
    assert `_rv_rc' == 9
    frame rv1: mata: assert(_rv_eq(1, "message", `"smallcells(n if s == "a{B}b{Q}"): 1 table rows fail, n (1 small); expected no released count in 1..4 (m=5)"'))
    * two failing countexps: the pieces keep their "; " separator
    generate m = 10
    quietly replace m = 2 in 1
    mata: st_local("cmd", _rv_x(`"dataprobe, gatesonly mincell(5) smallcells(n m if s == "a{B}b{Q}") violations(rv1, replace)"'))
    _rv_cap "`f'" : `macval(cmd)'
    assert `_rv_rc' == 9
    frame rv1: mata: assert(_rv_eq(1, "message", `"smallcells(n m if s == "a{B}b{Q}"): 1 table rows fail, n (1 small); m (1 small); expected no released count in 1..4 (m=5)"'))
    * margins over two small cells: the cells keep their ", " separator
    clear
    quietly set obs 43
    generate byte c = cond(_n <= 20, 1, cond(_n <= 22, 2, cond(_n <= 25, 3, 4)))
    generate long pid = _n
    quietly replace pid = 21 in 22
    quietly replace pid = 23 in 24/25
    _rv_cap "`f'" : dataprobe, gatesonly mincell(5) smallcells(c==1 c==2 c==3, id(pid) margins) violations(rv1, replace)
    assert `_rv_rc' == 9
    frame rv1: mata: assert(_rv_has(st_local("f"), "singletons (c==2, c==3)"))
    * unchanged: a condition that selects no small row passes
    clear
    quietly set obs 4
    generate str12 s = "z"
    generate n = cond(_n == 1, 3, 10)
    quietly replace s = "y" in 1
    _rv_cap "`f'" : dataprobe, gatesonly mincell(5) smallcells(n if s == "z")
    assert `_rv_rc' == 0
}
_rv `=_rc' "R1 smallcells(): \$ and a backtick in a condition or if reach the evaluator and ledger as typed"

**# R2 an empty sample with by(), maskrare and snapshot()/diff()

capture noisily {
    sysuse auto, clear
    quietly dataprobe price, snapshot(rv2b, replace)
    _rv_cap "`f'" : dataprobe price if 0, by(foreign) maskrare snapshot(rv2, replace)
    assert `_rv_rc' == 0
    confirm frame rv2
    _rv_cap "`f'" : dataprobe price if 0, by(foreign) maskrare diff(rv2b)
    assert `_rv_rc' == 0
    mata: assert(_rv_has(st_local("f"), "N: current 0, baseline 74"))
    mata: assert(!_rv_has(st_local("f"), "3300"))
    capture frame drop rv2
    capture frame drop rv2b
}
_rv `=_rc' "R2 if 0 with by(), maskrare and snapshot()/diff() runs (was Mata r(3300))"

**# R3 reconcile(..., by()) failing-group counts under maskrare

capture noisily {
    * two groups: g = 1 has 2 rows in the file and 3 in memory (small,
    * failing), g = 2 has 20 on both sides
    clear
    quietly set obs 22
    generate byte g = cond(_n <= 2, 1, 2)
    quietly save "`W'/rv3a.dta", replace
    clear
    quietly set obs 23
    generate byte g = cond(_n <= 3, 1, 2)
    quietly count if g == 1
    assert r(N) == 3
    _rv_cap "`f'" : dataprobe, gatesonly reconcile("`W'/rv3a.dta", n by(g)) violations(rv3, replace)
    assert `_rv_rc' == 9
    mata: assert(_rv_has(st_local("f"), "by(g): 2 groups, 1 failing"))
    frame rv3: mata: assert(_rv_eq(2, "observed", "1 of 2 groups fail"))
    _rv_cap "`f'" : dataprobe, gatesonly maskrare reconcile("`W'/rv3a.dta", n by(g)) violations(rv3, replace)
    assert `_rv_rc' == 9
    assert r(masked) == 1
    mata: assert(_rv_has(st_local("f"), "by(g): 2 groups, <5 failing"))
    mata: assert(_rv_has(st_local("f"), "(not shown): <5 failing"))
    mata: assert(!_rv_has(st_local("f"), "1 failing"))
    frame rv3: mata: assert(_rv_eq(2, "observed", "<5 of 2 groups fail"))
    * seven groups, six of 20 rows failing by one row and one of 2 rows
    * failing: 7 failing is not small, but 7 minus the 6 named lines is
    * the masked unnamed count, so 7 is withheld too
    clear
    quietly set obs 7
    generate byte g = _n
    generate n = cond(g == 1, 2, 20)
    quietly expand n
    drop n
    quietly save "`W'/rv3b.dta", replace
    clear
    quietly set obs 7
    generate byte g = _n
    generate n = cond(g == 1, 3, 21)
    quietly expand n
    drop n
    quietly count
    assert r(N) == 129
    _rv_cap "`f'" : dataprobe, gatesonly maskrare reconcile("`W'/rv3b.dta", n by(g)) violations(rv3, replace)
    assert `_rv_rc' == 9
    mata: assert(_rv_has(st_local("f"), "by(g): 7 groups, [suppressed] failing"))
    mata: assert(_rv_has(st_local("f"), "(not shown): <5 failing"))
    frame rv3: mata: assert(_rv_eq(2, "observed", "[suppressed] of 7 groups fail"))
    capture frame drop rv3
}
_rv `=_rc' "R3 reconcile by() under maskrare: failing-group counts masked and linked"

**# R4 safe: a likely identifier read only by a gate

capture noisily {
    clear
    quietly set obs 1000
    generate long lopnr = 1000 + _n
    generate age = mod(_n, 80)
    quietly summarize lopnr, detail
    local p1 = strtrim(string(r(p1), "%14.0g"))
    _rv_cap "`f'" : dataprobe age, gatesonly safe inrange(lopnr 1 100)
    assert `_rv_rc' == 9
    mata: assert(_rv_has(st_local("f"), "note: safe excludes likely identifier(s): lopnr"))
    mata: assert(_rv_has(st_local("f"), "(extremes withheld: excluded)"))
    mata: assert(!_rv_has(st_local("f"), "p1 `p1'"))
    * already in exclude(): no second note
    _rv_cap "`f'" : dataprobe age, gatesonly safe exclude(lopnr) inrange(lopnr 1 100)
    assert `_rv_rc' == 9
    mata: assert(!_rv_has(st_local("f"), "note: safe excludes"))
    * topvalues() of a gate-only identifier: refused before any output
    _rv_cap "`f'" : dataprobe age, safe topvalues(lopnr)
    assert `_rv_rc' == 198
    mata: assert(_rv_has(st_local("f"), "topvalues(): the values of lopnr are withheld"))
    mata: assert(!_rv_has(st_local("f"), "CONTINUOUS"))
    mata: assert(!_rv_has(st_local("f"), "TOP VALUES"))
    * unchanged without safe: the extremes print
    _rv_cap "`f'" : dataprobe age, gatesonly maskrare inrange(lopnr 1 100)
    mata: assert(_rv_has(st_local("f"), "p1 `p1'"))
}
_rv `=_rc' "R4 safe excludes a gate-only likely identifier; topvalues() of one refused early"

**# R5 stat(): compound quotes, $ and a backtick in the if

capture noisily {
    clear
    quietly set obs 4
    generate id = _n
    generate str12 s = "a" + char(36) + "b"
    quietly replace s = "x" in 3/4
    _rv_cap "`f'" : dataprobe, gatesonly stat(`"mean id 1 3"')
    assert `_rv_rc' == 0
    mata: assert(_rv_has(st_local("f"), "PASS: 1 gate(s) (stat)"))
    quietly summarize id if s == "a" + char(36) + "b"
    local m = strtrim(string(r(mean), "%10.4g"))
    mata: st_local("cmd", _rv_x(`"dataprobe, gatesonly stat(mean id 5 6 if s == "a{D}b") violations(rv5, replace)"'))
    _rv_cap "`f'" : `macval(cmd)'
    assert `_rv_rc' == 9
    frame rv5: mata: assert(_rv_eq(1, "message", `"stat(mean id): `m', expected [5, 6] (if s == "a{D}b")"'))
    quietly summarize id if s != "a" + char(96) + "b"
    local m = strtrim(string(r(mean), "%10.4g"))
    mata: st_local("cmd", _rv_x(`"dataprobe, gatesonly stat(mean id 1 2 if s != "a{B}b") violations(rv5, replace)"'))
    _rv_cap "`f'" : `macval(cmd)'
    assert `_rv_rc' == 9
    frame rv5: mata: assert(_rv_eq(1, "message", `"stat(mean id): `m', expected [1, 2] (if s != "a{B}b")"'))
    capture frame drop rv5
}
_rv `=_rc' "R5 stat(): compound-quoted entry; \$ and backtick in the if as typed"

**# R6 events(): hostile levels, labels and if

capture noisily {
    clear
    quietly set obs 8
    generate byte ev = 1
    generate str12 cov = "ok"
    quietly replace cov = "a" + char(36) + "b" in 1
    quietly replace cov = "a" + char(96) + "b" + char(39) in 2
    quietly replace ev = 0 in 1/2
    _rv_cap "`f'" : dataprobe, gatesonly events(ev: cov) violations(rv6, replace)
    assert `_rv_rc' == 9
    frame rv6 {
        assert _N == 2
        mata: assert(_rv_eq(1, "message", "events(ev): cov = a{D}b has 0 events, expected >= 1"))
        mata: assert(_rv_eq(2, "message", "events(ev): cov = a{B}b{Q} has 0 events, expected >= 1"))
    }
    mata: assert(_rv_has(st_local("f"), "cov = a{D}b has 0 events"))
    * a value label holding $ and a backtick
    clear
    quietly set obs 8
    generate byte ev = (_n > 1)
    generate byte c2 = cond(_n == 1, 1, 2)
    mata: st_vlmodify("c2l", (1 \ 2), (_rv_x("lab{D}b") \ _rv_x("o{B}k{Q}")))
    label values c2 c2l
    _rv_cap "`f'" : dataprobe, gatesonly events(ev: c2) violations(rv6, replace)
    assert `_rv_rc' == 9
    frame rv6: mata: assert(_rv_eq(1, "message", "events(ev): c2 = 1 (lab{D}b) has 0 events, expected >= 1"))
    * an events if holding $: the event sum is restricted as typed
    generate str12 s = "z"
    quietly replace s = "a" + char(36) + "b" in 2/8
    quietly replace s = "aEXPANDED_B" in 1
    mata: st_local("cmd", _rv_x(`"dataprobe, gatesonly events(ev if s == "a{D}b": c2) violations(rv6, replace)"'))
    _rv_cap "`f'" : `macval(cmd)'
    assert `_rv_rc' == 9
    frame rv6 {
        assert _N == 1
        mata: assert(_rv_eq(1, "message", "events(ev): c2 = 1 (lab{D}b) has 0 events, expected >= 1"))
    }
    capture frame drop rv6
}
_rv `=_rc' "R6 events(): levels, labels and if holding \$ or a backtick printed and stored as typed"

**# R7 safe inrange() on a date

capture noisily {
    clear
    quietly set obs 1000
    generate dt = td(01jan2015) + mod(_n, 100)
    format dt %td
    quietly summarize dt, detail
    local mp1 = string(r(p1), "%tdCCYY-NN")
    _rv_cap "`f'" : dataprobe, gatesonly safe inrange(dt td(01jan2020) td(31dec2020))
    assert `_rv_rc' == 9
    mata: assert(_rv_has(st_local("f"), "(p1 [withheld], p99 [withheld])"))
    mata: assert(!_rv_has(st_local("f"), "p1 `mp1'"))
    * unchanged under maskrare without safe: month precision
    _rv_cap "`f'" : dataprobe, gatesonly maskrare inrange(dt td(01jan2020) td(31dec2020))
    assert `_rv_rc' == 9
    mata: assert(_rv_has(st_local("f"), "p1 `mp1'"))
}
_rv `=_rc' "R7 safe withholds a date's inrange() p1/p99"

**# R8 violations() suboptions

capture noisily {
    sysuse auto, clear
    capture frame drop rv8
    frame create rv8 byte keepme
    frame rv8: quietly set obs 3
    _rv_cap "`f'" : dataprobe, gatesonly inrange(price 0 100) violations(rv8, noreplace)
    assert `_rv_rc' == 198
    mata: assert(_rv_has(st_local("f"), "violations(): the only suboption is replace; got noreplace"))
    mata: assert(!_rv_has(st_local("f"), "EXPECTATION VIOLATIONS"))
    frame rv8 {
        assert _N == 3
        confirm variable keepme
    }
    _rv_cap "`f'" : dataprobe, gatesonly inrange(price 0 100) violations(rv8b, bogus)
    assert `_rv_rc' == 198
    capture confirm frame rv8b
    assert _rc
    * replace and the existing-frame refusal are unchanged
    _rv_cap "`f'" : dataprobe, gatesonly inrange(price 0 100) violations(rv8)
    assert `_rv_rc' == 110
    _rv_cap "`f'" : dataprobe, gatesonly inrange(price 0 100) violations(rv8, replace)
    assert `_rv_rc' == 9
    frame rv8: assert _N == 1
    capture frame drop rv8
}
_rv `=_rc' "R8 violations(): noreplace and unknown words are r(198) before any work"

**# R9 diff(), isid() and nodups on 0 rows

capture noisily {
    sysuse auto, clear
    quietly dataprobe, gatesonly snapshot(rv9, replace)
    quietly keep if 0
    _rv_cap "`f'" : dataprobe make price, diff(rv9)
    assert `_rv_rc' == 0
    assert r(diff_key_after) == 1
    assert r(diff_key_surplus) == 0
    mata: assert(_rv_has(st_local("f"), "key make: unique before and after"))
    _rv_cap "`f'" : dataprobe, gatesonly isid(make) diff(rv9)
    assert `_rv_rc' == 0
    mata: assert(_rv_has(st_local("f"), "1 gate(s) (isid), N = 0, 0 violations"))
    _rv_cap "`f'" : dataprobe, gatesonly nodups diff(rv9)
    assert `_rv_rc' == 0
    * unchanged on rows: a unique key passes, a duplicated one fails, by()
    * and nodups (oracle: duplicates report)
    sysuse auto, clear
    _rv_cap "`f'" : dataprobe, gatesonly isid(make) nodups by(foreign)
    assert `_rv_rc' == 0
    quietly duplicates report rep78
    assert r(unique_value) < r(N)
    _rv_cap "`f'" : dataprobe, gatesonly isid(rep78)
    assert `_rv_rc' == 9
    capture frame drop rv9
}
_rv `=_rc' "R9 diff()/isid()/nodups on 0 rows: key unique after, no r(111)"

**# R10 name.dta missing never falls back to name.dta.dta

capture noisily {
    sysuse auto, clear
    quietly save "`W'/rv10.dta.dta", replace
    capture confirm file "`W'/rv10.dta"
    assert _rc
    _rv_cap "`f'" : dataprobe, gatesonly diff("`W'/rv10.dta")
    assert `_rv_rc' == 601
    _rv_cap "`f'" : dataprobe, gatesonly reconcile("`W'/rv10.dta", n)
    assert `_rv_rc' == 601
    * a name without .dta still finds name.dta
    quietly save "`W'/rv10b.dta", replace
    _rv_cap "`f'" : dataprobe, gatesonly diff("`W'/rv10b")
    assert `_rv_rc' == 0
    _rv_cap "`f'" : dataprobe, gatesonly reconcile("`W'/rv10b", n)
    assert `_rv_rc' == 0
}
_rv `=_rc' "R10 diff()/reconcile() name.dta missing is r(601), not name.dta.dta"

**# R11 topvalues() with no varlist and brief

capture noisily {
    sysuse auto, clear
    _rv_cap "`f'" : dataprobe, topvalues(rep78) brief
    assert `_rv_rc' == 198
    mata: assert(_rv_has(st_local("f"), "brief cannot be combined with topvalues() and no varlist"))
    mata: assert(!_rv_has(st_local("f"), "TOP VALUES"))
    _rv_cap "`f'" : dataprobe, topvalues(rep78)
    assert `_rv_rc' == 0
    assert r(gatesonly) == 1
}
_rv `=_rc' "R11 topvalues() with no varlist and brief is r(198)"

**# R12 r(masked) when a profile statistic is suppressed

capture noisily {
    * one value of 1000 above 29 small ones: mean, p1 and p99 have fewer
    * than 5 rows on a side; no count is 1..4
    clear
    quietly set obs 30
    generate double x = _n / 1000
    quietly replace x = 1000 in 1
    quietly summarize x
    quietly count if x >= r(mean)
    assert r(N) < 5
    _rv_cap "`f'" : dataprobe x, maskrare
    assert `_rv_rc' == 0
    mata: assert(_rv_has(st_local("f"), "mean=[suppressed]"))
    assert r(masked) == 1
    clear
    quietly set obs 30
    generate dt = td(01jan2020) + _n * 30
    format dt %td
    _rv_cap "`f'" : dataprobe dt, maskrare mincell(16)
    assert `_rv_rc' == 0
    mata: assert(_rv_has(st_local("f"), "p1=[suppressed]"))
    assert r(masked) == 1
    * nothing suppressed: r(masked) stays 0
    clear
    quietly set obs 1000
    generate double x = _n
    _rv_cap "`f'" : dataprobe x, maskrare
    assert `_rv_rc' == 0
    mata: assert(!_rv_has(st_local("f"), "[suppressed]"))
    assert r(masked) == 0
}
_rv `=_rc' "R12 r(masked) is 1 when CONTINUOUS or DATE suppresses a statistic"

**# R13 value-domain gates with $ or a backtick

capture noisily {
    clear
    quietly set obs 4
    generate str12 s = "a" + char(36) + "b"
    quietly replace s = "x" in 3/4
    mata: st_local("cmd", _rv_x(`"dataprobe, gatesonly allowed(s "a{D}b" "x")"'))
    _rv_cap "`f'" : `macval(cmd)'
    assert `_rv_rc' == 0
    quietly count if s == "a" + char(36) + "b"
    local k = r(N)
    mata: st_local("cmd", _rv_x(`"dataprobe, gatesonly forbid(s "a{D}b") violations(rv13, replace)"'))
    _rv_cap "`f'" : `macval(cmd)'
    assert `_rv_rc' == 9
    frame rv13 {
        mata: assert(_rv_eq(1, "expected", "none of a{D}b"))
        mata: assert(_rv_eq(1, "message", "forbid(s): `k' obs contain forbidden values {a{D}b}"))
    }
    mata: st_local("cmd", _rv_x(`"dataprobe, gatesonly notvalues(s "a{D}b")"'))
    _rv_cap "`f'" : `macval(cmd)'
    assert `_rv_rc' == 9
    quietly replace s = "a" + char(96) + "b" + char(39) in 1/2
    mata: st_local("cmd", _rv_x(`"dataprobe, gatesonly forbid(s "a{B}b{Q}") violations(rv13, replace)"'))
    _rv_cap "`f'" : `macval(cmd)'
    assert `_rv_rc' == 9
    frame rv13: mata: assert(_rv_eq(1, "message", "forbid(s): 2 obs contain forbidden values {a{B}b{Q}}"))
    * regex: a pattern holding $ as typed
    quietly replace s = "a" + char(36) + "b" in 1/2
    mata: st_local("cmd", _rv_x(`"dataprobe, gatesonly regex(s ^(a[{D}]b|x){D})"'))
    _rv_cap "`f'" : `macval(cmd)'
    assert `_rv_rc' == 0
    mata: st_local("cmd", _rv_x(`"dataprobe, gatesonly regex(s ^x{D}) violations(rv13, replace)"'))
    _rv_cap "`f'" : `macval(cmd)'
    assert `_rv_rc' == 9
    frame rv13: mata: assert(_rv_eq(1, "message", "regex(s): 2 obs do not match ^x{D}"))
    capture frame drop rv13
}
_rv `=_rc' "R13 allowed/forbid/notvalues/regex values holding \$ or a backtick match as typed"

**# R14 ess with a negative weight

capture noisily {
    clear
    quietly set obs 5
    generate double w = 1
    quietly replace w = -1 in 1
    generate byte g = 1
    _rv_cap "`f'" : dataprobe, gatesonly stat(ess w 0 100)
    assert `_rv_rc' == 459
    mata: assert(_rv_has(st_local("f"), "ess: w has negative values in scope"))
    _rv_cap "`f'" : dataprobe, gatesonly groupstat(ess: w, by(g))
    assert `_rv_rc' == 459
    * nonnegative weights: Kish (sum w)^2 / sum(w^2) as before
    quietly replace w = 2 in 1
    quietly summarize w
    local s1 = r(sum)
    generate double w2 = w^2
    quietly summarize w2
    local e = `s1'^2 / r(sum)
    assert reldif(`e', 4.5) < 1e-12
    _rv_cap "`f'" : dataprobe, gatesonly stat(ess w 4.4 4.6)
    assert `_rv_rc' == 0
    _rv_cap "`f'" : dataprobe, gatesonly stat(ess w 4.6 5)
    assert `_rv_rc' == 9
}
_rv `=_rc' "R14 stat(ess)/groupstat(ess) refuse a negative weight (r(459))"

**# R15 dataprobe.sthlp lint fixes

capture noisily {
    mata: L = cat(st_local("pkg_dir") + "/dataprobe.sthlp")
    mata: assert(sum(strpos(L, "{synopt:{opt small:cells(spec)}}") :== 1) == 1)
    mata: assert(sum(strpos(L, "{synopt:{opt smallcells(spec)}}") :== 1) == 0)
    * the stored-results rows that wrapped (48 > 71 - 24 visible
    * characters), as now written: 38 and 37 characters
    mata: assert(sum(L :== "{synopt:{cmd:r(coverage_outside_low)}}dates before {it:lo}; {opt coverage()} with {cmd:sides}{p_end}") == 1)
    mata: assert(sum(L :== "{synopt:{cmd:r(coverage_outside_high)}}dates after {it:hi}; {opt coverage()} with {cmd:sides}{p_end}") == 1)
    mata: mata drop L
}
_rv `=_rc' "R15 dataprobe.sthlp: small:cells abbreviation, coverage synopt rows"

**# R16 stat() parse-error messages echo the entry as typed

capture noisily {
    clear
    quietly set obs 4
    generate id = _n
    generate str12 s = "x"
    mata: st_local("cmd", _rv_x(`"dataprobe, gatesonly stat(ratio id 1 2 if s == "a{D}b")"'))
    _rv_cap "`f'" : `macval(cmd)'
    assert `_rv_rc' == 198
    mata: assert(_rv_has(st_local("f"), `"stat() ratio spec must be "ratio num den lo hi [if exp]": ratio id 1 2 if s == "a{D}b""'))
    mata: assert(!_rv_has(st_local("f"), "EXPANDED_B"))
    mata: st_local("cmd", _rv_x(`"dataprobe, gatesonly stat(mean id 1 if s == "a{D}b")"'))
    _rv_cap "`f'" : `macval(cmd)'
    assert `_rv_rc' == 198
    mata: assert(_rv_has(st_local("f"), `"stat() spec must be "statistic var lo hi [if exp]": mean id 1 if s == "a{D}b""'))
    mata: st_local("cmd", _rv_x(`"dataprobe, gatesonly stat(mean id 5 1 if s == "a{D}b")"'))
    _rv_cap "`f'" : `macval(cmd)'
    assert `_rv_rc' == 198
    mata: assert(_rv_has(st_local("f"), `"stat() lower bound exceeds upper bound: mean id 5 1 if s == "a{D}b""'))
    mata: assert(!_rv_has(st_local("f"), "EXPANDED_B"))
}
_rv `=_rc' "R16 stat() parse-error messages echo an entry holding \$ as typed"

**# R17 groupstat(): group labels holding "', $ or a backtick

capture noisily {
    * three groups of 10 rows (k), x missing on every third row; the
    * oracle shares come from count on k, never from dataprobe
    clear
    quietly set obs 30
    generate byte k = ceil(_n / 10)
    generate double x = cond(mod(_n, 3) == 0, ., _n)
    forvalues kk = 1/3 {
        quietly count if missing(x) & k == `kk'
        local pm`kk' = strtrim(string(r(N) / 10, "%10.4g"))
        quietly count if !missing(x) & k == `kk'
        local nn`kk' = r(N)
    }
    assert "`pm1'" == ".3" & "`pm3'" == ".4"
    * the labels: "' (char 34, char 39), a$b, q`z' -- sorted as k
    mata: _rv_L = (char(34) + "{Q}" \ "a{D}b" \ "q{B}z{Q}")
    mata: for (i = 1; i <= 3; i++) _rv_L[i] = _rv_x(_rv_L[i])
    generate str12 grp = ""
    mata: st_sstore(., "grp", _rv_L[st_data(., "k")])
    * a string by(): table rows and the ledger as typed
    _rv_cap "`f'" : dataprobe, gatesonly groupstat(pmiss x, by(grp))
    assert `_rv_rc' == 0
    forvalues kk = 1/3 {
        mata: assert(_rv_has(st_local("f"), "  " + sprintf("%-24s", _rv_L[`kk']) + sprintf("%13s", st_local("pm`kk'"))))
    }
    mata: assert(!_rv_has(st_local("f"), "EXPANDED_B"))
    _rv_cap "`f'" : dataprobe, gatesonly groupstat(pmiss x, by(grp) band(0 0.1)) violations(rv17, replace)
    assert `_rv_rc' == 9
    frame rv17 {
        assert _N == 3
        forvalues kk = 1/3 {
            mata: assert(_rv_eq(`kk', "group", "by(grp) = " + _rv_L[`kk']))
            mata: assert(_rv_eq(`kk', "message", "groupstat(pmiss x): pmiss `pm`kk'' in group " + _rv_L[`kk'] + ", expected [0, .1] [3 groups above (rows 30)]"))
        }
    }
    * maskrare: 3 or 4 missing of 10 masks every share; labels unchanged
    _rv_cap "`f'" : dataprobe, gatesonly maskrare groupstat(pmiss x, by(grp) band(0 0.1)) violations(rv17, replace)
    assert `_rv_rc' == 9
    mata: assert(_rv_has(st_local("f"), "  " + sprintf("%-24s", _rv_L[1]) + sprintf("%13s", "[suppr.]")))
    frame rv17 {
        assert _N == 3
        forvalues kk = 1/3 {
            mata: assert(_rv_eq(`kk', "group", "by(grp) = " + _rv_L[`kk']))
            mata: assert(_rv_eq(`kk', "message", "groupstat(pmiss x): pmiss [suppressed] in group " + _rv_L[`kk'] + ", expected [0, .1] [3 groups above (rows 30)]"))
        }
    }
    * several statistics (the colon form's cell frame)
    _rv_cap "`f'" : dataprobe, gatesonly groupstat(pmiss n: x, by(grp))
    assert `_rv_rc' == 0
    forvalues kk = 1/3 {
        mata: assert(_rv_has(st_local("f"), "  " + sprintf("%-16s", _rv_L[`kk']) + sprintf("%10s", st_local("pm`kk'")) + sprintf("%10s", st_local("nn`kk'"))))
    }
    * the same text as value labels of a numeric by()
    mata: st_vlmodify("rv17l", (1 \ 2 \ 3), _rv_L)
    label values k rv17l
    _rv_cap "`f'" : dataprobe, gatesonly groupstat(pmiss x, by(k))
    assert `_rv_rc' == 0
    forvalues kk = 1/3 {
        mata: assert(_rv_has(st_local("f"), "  " + sprintf("%-24s", _rv_L[`kk']) + sprintf("%13s", st_local("pm`kk'"))))
    }
    _rv_cap "`f'" : dataprobe, gatesonly maskrare groupstat(pmiss x, by(k) band(0 0.1)) violations(rv17, replace)
    assert `_rv_rc' == 9
    frame rv17 {
        assert _N == 3
        forvalues kk = 1/3 {
            mata: assert(_rv_eq(`kk', "group", "by(k) = " + _rv_L[`kk']))
            mata: assert(_rv_eq(`kk', "message", "groupstat(pmiss x): pmiss [suppressed] in group " + _rv_L[`kk'] + ", expected [0, .1] [3 groups above (rows 30)]"))
        }
    }
    _rv_cap "`f'" : dataprobe, gatesonly maskrare groupstat(pmiss n: x, by(k))
    assert `_rv_rc' == 0
    mata: assert(_rv_has(st_local("f"), "  " + sprintf("%-16s", _rv_L[1]) + sprintf("%10s", "[suppr.]")))
    mata: assert(_rv_has(st_local("f"), "  " + sprintf("%-16s", _rv_L[3]) + sprintf("%10s", "[suppr.]")))
    mata: assert(!_rv_has(st_local("f"), "EXPANDED_B"))
    capture frame drop rv17
    capture mata: mata drop _rv_L
}
_rv `=_rc' "R17 groupstat(): by() values and value labels holding a double then a right quote, \$ or a backtick as typed (was r(132))"

**# R18 single(), checks(), keyset(): name.dta is read as given

capture noisily {
    clear
    quietly set obs 10
    generate id = _n
    generate x = _n
    quietly save "`W'/k18.dta.dta", replace
    capture confirm file "`W'/k18.dta"
    assert _rc
    _rv_cap "`f'" : dataprobe, single("`W'/k18.dta")
    assert `_rv_rc' == 601
    mata: assert(_rv_has(st_local("f"), "file " + st_local("W") + "/k18.dta not found"))
    mata: assert(!_rv_has(st_local("f"), "QUICK REFERENCE"))
    _rv_cap "`f'" : dataprobe x, gatesonly checks("`W'/k18.dta")
    assert `_rv_rc' == 601
    mata: assert(_rv_has(st_local("f"), "checks() file " + st_local("W") + "/k18.dta not found"))
    _rv_cap "`f'" : dataprobe x, gatesonly keyset(id using "`W'/k18.dta", equal)
    assert `_rv_rc' == 601
    mata: assert(_rv_has(st_local("f"), "keyset(): file " + st_local("W") + "/k18.dta not found"))
    mata: assert(!_rv_has(st_local("f"), "KEYSET PREFLIGHT"))
    * a name without .dta still finds name.dta (single, keyset, checks)
    quietly save "`W'/k18b.dta", replace
    _rv_cap "`f'" : dataprobe, single("`W'/k18b")
    assert `_rv_rc' == 0
    assert r(N) == 10
    _rv_cap "`f'" : dataprobe x, gatesonly keyset(id using "`W'/k18b", equal)
    assert `_rv_rc' == 0
    mata: assert(_rv_has(st_local("f"), "keys: 10 matched, 0 memory only, 0 k18b only"))
    quietly dataprobe x, gatesonly inrange(x 1 10) makespec("`W'/k18s.dta", replace)
    confirm file "`W'/k18s.dta"
    _rv_cap "`f'" : dataprobe x, gatesonly checks("`W'/k18s")
    assert `_rv_rc' == 0
    _rv_cap "`f'" : dataprobe x, gatesonly checks("`W'/k18s.dta")
    assert `_rv_rc' == 0
}
_rv `=_rc' "R18 single()/checks()/keyset() name.dta missing is r(601), not name.dta.dta"

**# R19 violations() with a quoted file name holding a space

capture noisily {
    clear
    quietly set obs 10
    generate x = _n
    quietly count if x < 3 | x > 4
    local nout = r(N)
    capture erase "`W'/my vio.dta"
    _rv_cap "`f'" : dataprobe x, gatesonly inrange(x 3 4) violations("`W'/my vio.dta", replace)
    assert `_rv_rc' == 9
    mata: assert(!_rv_has(st_local("f"), "the only suboption is replace"))
    preserve
    use "`W'/my vio.dta", clear
    assert _N == 1
    mata: assert(_rv_eq(1, "message", "inrange(x): `nout' obs outside [3, 4] (2 below, 6 above)  (min 1, max 10)"))
    restore
    * the file exists: without replace r(602), and a bad word is r(198)
    _rv_cap "`f'" : dataprobe x, gatesonly inrange(x 3 4) violations("`W'/my vio.dta")
    assert `_rv_rc' == 602
    _rv_cap "`f'" : dataprobe x, gatesonly inrange(x 3 4) violations("`W'/my vio.dta", bogus)
    assert `_rv_rc' == 198
    mata: assert(_rv_has(st_local("f"), "violations(): the only suboption is replace; got bogus"))
    * a quoted frame name is a frame
    capture frame drop rv19
    _rv_cap "`f'" : dataprobe x, gatesonly inrange(x 3 4) violations("rv19", replace)
    assert `_rv_rc' == 9
    frame rv19: assert _N == 1
    capture frame drop rv19
}
_rv `=_rc' "R19 violations(): a quoted file name with a space is written; replace still checked"

**# R20 reconcile() deltas in r(): not masked

capture noisily {
    clear
    quietly set obs 37
    generate long id = _n
    quietly save "`W'/rv20.dta", replace
    clear
    quietly set obs 40
    generate long id = _n
    generate x = 1
    * oracle: 40 - 37
    quietly describe using "`W'/rv20.dta"
    local d = 40 - r(N)
    assert `d' == 3
    _rv_cap "`f'" : dataprobe x, gatesonly maskrare reconcile("`W'/rv20.dta", n ids(id))
    assert `_rv_rc' == 9
    mata: assert(_rv_has(st_local("f"), "rows: memory [suppressed], rv20 [suppressed]; more in memory"))
    mata: assert(!_rv_has(st_local("f"), "3 more in memory"))
    assert r(masked) == 1
    assert r(reconcile_rows_delta) == `d' & r(reconcile_ids_delta) == `d'
}
_rv `=_rc' "R20 reconcile(): r() deltas exact beside a [suppressed] console (stored results are not masked)"

**# R21 help text for the 2026-11-17 fixes

capture noisily {
    mata: _rv_T = invtokens(cat(st_local("pkg_dir") + "/dataprobe.sthlp")', char(10))
    mata: assert(strpos(_rv_T, "{opt topvalues()} and no {it:varlist} is r(198).") > 0)
    mata: assert(strpos(_rv_T, "{cmd:replace}; any other word is r(198) before any work.") > 0)
    mata: assert(strpos(_rv_T, "space ({cmd:violations(" + char(34) + "my vio.dta" + char(34) + ", replace)}); any other name is a frame.") > 0)
    mata: assert(strpos(_rv_T, "extension is optional; a {it:filename} that ends in {opt .dta} is read as" + char(10) + "given, never as {it:filename}{cmd:.dta}.") > 0)
    mata: assert(strpos(_rv_T, "{it:name}{cmd:.dta}; a {it:name} that ends in {opt .dta} is read as" + char(10) + "given);") > 0)
    mata: assert(strpos(_rv_T, "both. A {it:filename} that ends in {opt .dta} is read as given, and one without") > 0)
    mata: assert(strpos(_rv_T, "not changed. A {it:filename} that ends in {opt .dta} is read as given, and one") > 0)
    mata: assert(strpos(_rv_T, "{opt check:s(filename)} reads gate specifications from {it:filename} (a name" + char(10) + "that ends in {opt .dta} is read as given") > 0)
    mata: assert(strpos(_rv_T, "{cmd:ratio}. An {cmd:ess} with a negative weight in scope is r(459), as in") > 0)
    mata: _rv_T = invtokens(cat(st_local("pkg_dir") + "/datamap.sthlp")', char(10))
    mata: assert(strpos(_rv_T, "{bf:candidates withheld (datesafe)}. Text forced into {opt categorical()}") > 0)
    mata: assert(strpos(_rv_T, "reads {it:k}{bf: distinct; frequencies withheld (datesafe)}.") > 0)
    mata: assert(strpos(_rv_T, "variable prints in the date format when it is date-formatted") > 0)
    mata: mata drop _rv_T
}
_rv `=_rc' "R21 help text: brief/topvalues(), violations(), .dta as given, groupstat(ess), datesafe categorical()"

**# Cleanup

macro drop DATAMAP_DQ
global b
capture quietly cd "`qa_dir'"
local files : dir "`W'" files "*"
foreach fl of local files {
    capture erase "`W'/`fl'"
}
sysdir set PLUS `"`_old_plus'"'
sysdir set PERSONAL `"`_old_personal'"'
discard
capture mata: mata drop _rv_x() _rv_lines() _rv_has() _rv_eq()
display as result "Results: $PASS/$TC passed, $FAIL failed"
display "RESULT: test_review_2026_11_17_dataprobe tests=$TC pass=$PASS fail=$FAIL"
log close main
if $FAIL > 0 exit 1
