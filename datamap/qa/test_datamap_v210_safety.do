*! test_datamap_v210_safety.do  2026/11/16
*! datamap 2.1.0 U7 (dataprobe softcollect), error-row phase and worker
*! routing, R1 (literal text: name(), byrule(), checks() rows, groupstat()
*! group labels, the Markdown writers) and D2 (p5/p95 in stat())
*! Author: Timothy P Copeland, Karolinska Institutet
*
*   S1  softcollect: missing variable, empty if sample, a gate spec that does
*       not parse, a misspelled option: rc 0, r(softfail) 1, r(softfail_rc),
*       only those two r() results, one error row, one note line
*   S2  softcollect never passes a broken check: dataqa assert exits 9 and
*       report counts the error row as failed
*   S3  softcollect stays hard: no ledger (198), an I/O target error (603,
*       row still written), a ledger that cannot take the row (111),
*       SOFTCOLLECT in capitals, a variable named soft before the comma
*   S4  strict default unchanged: the same failing call without softcollect
*       halts with its rc and prints no note; a passing call has the same
*       console text, r() and ledger rows with and without softcollect
*       (bar r(softfail) = 0)
*   S5  the error row takes the call's phase(), else the session phase (an
*       invalid phase token too); without a session the call's phase
*   S6  an error row in a dataqa set worker() session goes to the worker's
*       shard, never the ledger; softcollect works there
*   R1  name() with dollar, backtick, braces: r(dataset), ledger dataset (gate and error
*       rows) and the PASS line are literal
*   R2  byrule(): a dollar and a backtick in an expression stay literal
*       (plain, aggregate, strL), ledger expected and message literal; a
*       dollar in the
*       byspec or the label is refused
*   R3  checks() rows holding a backtick or a global reference are refused
*       naming the row; a regex end anchor is accepted
*   R4  groupstat(): group labels holding dollar, backtick, braces print literally (one and
*       several statistics) and the band-fail ledger row is literal; a group
*       variable with no value in scope
*   R5  Markdown: labels, value labels, notes and titles stay literal, "]("
*       never forms a link, unpaired brackets in a Contents entry are
*       escaped, paired brackets are not; a manifest line holding a dollar is
*       refused, never expanded
*   R5c Markdown block starts: a dataset note or a subtitle(), notes() or
*       changelog() line starting with [ cannot define a link target; a
*       note's heading, list and ordered-list markers are escaped; the
*       user's own changelog list lines are unchanged
*   R6  rule() and review(): a dollar and a backtick in an expression stay
*       literal (counts against base Stata count), ledger expected and
*       message literal; a dollar in the label is refused
*   R7  a data file whose name holds a backtick: the PASS line, r(dataset)
*       and the ledger gate and error rows (strict and softcollect) name it
*       literally, (modified) still added; no file name gives no name
*   D2  stat() p5 and p95 against summarize, detail; the help example bands;
*       D2b p1 and p99 in stat() and groupstat() against summarize, detail,
*       and p2 / p37 refused as the help says
version 16.0
clear all
set more off
set linesize 255
capture log close _all
log using "test_datamap_v210_safety.log", replace text name(main)
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
* restored before the RESULT line so a runner's install sandbox stays in force
local _old_plus : sysdir PLUS
local _old_personal : sysdir PERSONAL
tempfile base
local W "`base'_v210sf"
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
* bait: a wrongly expanded global SFB shows up as EXPANDED
global SFB "EXPANDED"
global TC 0
global PASS 0
global FAIL 0
capture program drop _ft
program define _ft
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

* _sf_cap file cmd: run cmd (captured) with its output, between two markers,
* logged to file; the rc is left in the caller's local _sf_rc
capture program drop _sf_cap
program define _sf_cap
    gettoken f 0 : 0
    capture log close _sfc
    quietly log using `"`f'"', replace text name(_sfc)
    display "<<SFSTART>>"
    capture noisily `macval(0)'
    local rc = _rc
    display "<<SFEND>>"
    quietly log close _sfc
    c_local _sf_rc `rc'
end

capture mata: mata drop _sf_txt()
capture mata: mata drop _sf_rnames()
capture mata: mata drop _sf_nmatch()
capture mata: mata drop _sf_lines()
capture mata: mata drop _sf_tail()
mata:
// the text between the markers of an _sf_cap log, lines joined by char(10)
string scalar _sf_txt(string scalar f)
{
	string colvector L
	string scalar T
	real scalar s, e
	L = cat(f)
	T = invtokens(L', char(10))
	s = strpos(T, "<<SFSTART>>")
	e = strpos(T, "<<SFEND>>")
	if (s == 0 | e == 0) return("")
	T = substr(T, s + 11, e - s - 11)
	// the echo of the display command itself, when any
	return(T)
}
// the number of lines (elements of L) matching the regular expression re
real scalar _sf_nmatch(string rowvector L, string scalar re)
{
	real scalar i, n
	n = 0
	for (i = 1; i <= cols(L); i++) n = n + ustrregexm(L[i], re)
	return(n)
}
// the nonempty lines of an _sf_cap log between the markers (cat(), not
// tokens(), which binds quotes and backticks)
string rowvector _sf_lines(string scalar f)
{
	string colvector L
	real scalar i, s, e
	L = cat(f)
	s = e = 0
	for (i = 1; i <= rows(L); i++) {
		if (!s & strpos(L[i], "<<SFSTART>>")) s = i
		else if (s & strpos(L[i], "<<SFEND>>")) {
			e = i
			break
		}
	}
	if (!s | !e | e == s + 1) return(J(1, 0, ""))
	L = L[(s + 1)::(e - 1)]
	return(select(L, strtrim(L) :!= "")')
}
// the last k blank-separated words of a line, as one string
string scalar _sf_tail(string scalar l, real scalar k)
{
	string scalar re
	re = "(" + (k - 1) * "[^ ]+ +" + "[^ ]+) *$"
	if (!ustrregexm(l, re)) return("")
	return(stritrim(ustrregexs(1)))
}
// the names of the current r() scalars and macros, sorted, as one string
string scalar _sf_rnames()
{
	string colvector n
	n = st_dir("r()", "numscalar", "*") \ st_dir("r()", "macro", "*")
	if (rows(n) == 0) return("")
	return(invtokens(sort(n, 1)'))
}
end

* hostile pieces, built in Mata so the do-file never expands them
mata: st_local("D", char(36))
mata: st_local("BT", char(96))

**# S1 softcollect: data and spec errors continue

* S1a: a missing variable
capture noisily {
    macro drop DATAMAP_DQ
    tempfile L
    clear
    quietly set obs 5
    generate x = _n
    tempfile lg
    _sf_cap "`lg'.log" dataprobe, gatesonly notmissing(zz) ledger("`L'", run(r1)) softcollect
    assert `_sf_rc' == 0
    dataprobe, gatesonly notmissing(zz) ledger("`L'", run(r1b)) softcollect
    assert r(softfail) == 1
    assert r(softfail_rc) == 111
    mata: assert(_sf_rnames() == "softfail softfail_rc")
    mata: T = _sf_txt(st_local("lg") + ".log")
    mata: assert(strpos(T, "variable zz not found") > 0)
    mata: assert(strpos(T, "softcollect: the call failed with rc 111 (variable not found)") > 0)
    * Stata's message and one note line, nothing more
    mata: assert(cols(_sf_lines(st_local("lg") + ".log")) == 2)
    preserve
    quietly use "`L'", clear
    assert _N == 2
    assert status == "error" & family == "call" & observed == "rc 111" & observed_num == 111
    restore
}
_ft `=_rc' "S1a softcollect: a missing variable returns 0 with r(softfail)=1, r(softfail_rc)=111 and nothing else in r(); one error row; one note line"

* S1b: an if sample with no observations (rc 2000)
capture noisily {
    macro drop DATAMAP_DQ
    tempfile L
    clear
    quietly set obs 5
    generate x = _n
    quietly count if x > 99
    assert r(N) == 0
    dataprobe x if x > 99, gatesonly notmissing(x) ledger("`L'") softcollect
    assert r(softfail) == 1 & r(softfail_rc) == 2000
    quietly use "`L'", clear
    assert _N == 1 & status == "error" & observed_num == 2000
}
_ft `=_rc' "S1b softcollect: an empty if sample (rc 2000) is recorded and continues"

* S1c: a gate spec that does not parse, and a misspelled option (syntax fails
* before softcollect is parsed: the raw line is read)
capture noisily {
    macro drop DATAMAP_DQ
    tempfile L
    clear
    quietly set obs 5
    generate x = _n
    capture noisily dataprobe, gatesonly inrange(x 1) ledger("`L'")
    local strict_rc = _rc
    assert `strict_rc' == 198
    dataprobe, gatesonly inrange(x 1) ledger("`L'") softcollect
    assert r(softfail) == 1 & r(softfail_rc) == `strict_rc'
    capture noisily dataprobe, gatesonly notmisingx(x) ledger("`L'")
    local strict_rc2 = _rc
    assert `strict_rc2' == 198
    dataprobe, gatesonly notmisingx(x) ledger("`L'") softcollect
    assert r(softfail) == 1 & r(softfail_rc) == `strict_rc2'
    * the shortest abbreviation
    dataprobe, gatesonly notmissing(zz) ledger("`L'") soft
    assert r(softfail) == 1 & r(softfail_rc) == 111
    quietly use "`L'", clear
    assert _N == 5
    assert status == "error"
    quietly count if observed_num == 198
    assert r(N) == 4
}
_ft `=_rc' "S1c softcollect: an unparsable gate spec and a misspelled option (both rc 198) continue; soft abbreviates it"

**# S2 the error row is a failure for dataqa

capture noisily {
    macro drop DATAMAP_DQ
    tempfile L
    clear
    quietly set obs 5
    generate x = _n
    dataprobe, gatesonly notmissing(x) ledger("`L'", run(s2)) name(okdata)
    dataprobe, gatesonly notmissing(zz) ledger("`L'", run(s2)) name(baddata) softcollect
    assert r(softfail) == 1
    capture noisily dataqa assert using "`L'", run(s2)
    assert _rc == 9
    dataqa report using "`L'", run(s2)
    assert r(n_failed) == 1
    * the same run without the soft call passes, so the 9 above is the error row
    tempfile L2
    dataprobe, gatesonly notmissing(x) ledger("`L2'", run(s2)) name(okdata)
    dataqa assert using "`L2'", run(s2)
}
_ft `=_rc' "S2 a softcollect error row makes dataqa assert exit 9 and dataqa report count it failed"

**# S3 softcollect stays hard where it must

* S3a: no ledger
capture noisily {
    macro drop DATAMAP_DQ
    clear
    quietly set obs 5
    generate x = _n
    tempfile lg
    _sf_cap "`lg'.log" dataprobe, gatesonly notmissing(x) softcollect
    assert `_sf_rc' == 198
    mata: assert(strpos(_sf_txt(st_local("lg") + ".log"), "softcollect records a failed call as a ledger error row; give ledger()") > 0)
    _sf_cap "`lg'.log" dataprobe, gatesonly notmissing(zz) softcollect
    assert `_sf_rc' == 198
}
_ft `=_rc' "S3a softcollect without a ledger is r(198), even when the call would fail anyway"

* S3b: an I/O target error (603) halts; its error row is still written
capture noisily {
    macro drop DATAMAP_DQ
    tempfile L
    clear
    quietly set obs 5
    generate x = _n
    capture noisily dataprobe x, saving("`W'/no_such_folder/p.dta") ledger("`L'") softcollect
    assert _rc == 603
    quietly use "`L'", clear
    assert _N == 1 & status == "error" & observed_num == 603
}
_ft `=_rc' "S3b softcollect: an output-path error (603) still halts, with its error row"

* S3c: a ledger that cannot take the row: nothing records the failure, so the
* call halts with its own rc
capture noisily {
    macro drop DATAMAP_DQ
    tempfile L
    clear
    quietly set obs 3
    generate notaledger = 1
    quietly save "`L'"
    capture noisily dataprobe, gatesonly notmissing(zz) ledger("`L'") softcollect
    assert _rc == 111
    quietly use "`L'", clear
    assert _N == 3
    confirm variable notaledger
}
_ft `=_rc' "S3c softcollect: when the error row cannot be written the call halts with its rc (111)"

* S3d: SOFTCOLLECT in capitals is not the option (syntax 198, halts); a
* variable named soft before the comma is not the option either
capture noisily {
    macro drop DATAMAP_DQ
    tempfile L
    clear
    quietly set obs 3
    generate soft = 1
    capture noisily dataprobe, gatesonly notmissing(soft) ledger("`L'") SOFTCOLLECT
    assert _rc == 198
    capture noisily dataprobe soft zz, gatesonly ledger("`L'")
    assert _rc == 111
    quietly use "`L'", clear
    assert _N == 2 & status == "error"
}
_ft `=_rc' "S3d softcollect: SOFTCOLLECT in capitals and a variable named soft do not make an error soft"

**# S4 the strict default is unchanged

capture noisily {
    macro drop DATAMAP_DQ
    clear
    quietly set obs 20
    generate x = _n
    generate y = cond(_n <= 3, ., _n)
    tempfile L lga lgb lgc
    * a failing call without softcollect halts and prints only Stata's message
    _sf_cap "`lgc'.log" dataprobe, gatesonly notmissing(zz) ledger("`L'", run(s4e))
    assert `_sf_rc' == 111
    mata: T = _sf_txt(st_local("lgc") + ".log")
    mata: assert(strpos(T, "variable zz not found") > 0)
    mata: assert(strpos(T, "softcollect") == 0)
    * a passing and a failing gate call, with and without softcollect
    _sf_cap "`lga'.log" dataprobe, gatesonly notmissing(x) inrange(x 1 20) ledger("`L'", run(s4a))
    assert `_sf_rc' == 0
    _sf_cap "`lgb'.log" dataprobe, gatesonly notmissing(x) inrange(x 1 20) ledger("`L'", run(s4b)) softcollect
    assert `_sf_rc' == 0
    mata: assert(_sf_txt(st_local("lga") + ".log") == _sf_txt(st_local("lgb") + ".log"))
    _sf_cap "`lga'.log" dataprobe, gatesonly notmissing(y) ledger("`L'", run(s4c)) warn
    _sf_cap "`lgb'.log" dataprobe, gatesonly notmissing(y) ledger("`L'", run(s4d)) warn softcollect
    mata: assert(_sf_txt(st_local("lga") + ".log") == _sf_txt(st_local("lgb") + ".log"))
    * r(): the same names and values, plus r(softfail) = 0
    dataprobe, gatesonly notmissing(x) inrange(x 1 20) ledger("`L'", run(s4a))
    mata: na = _sf_rnames()
    local nx = r(n_checks)
    local cr `"`r(checks_run)'"'
    dataprobe, gatesonly notmissing(x) inrange(x 1 20) ledger("`L'", run(s4b)) softcollect
    mata: nb = _sf_rnames()
    assert r(softfail) == 0
    assert r(n_checks) == `nx'
    assert `"`r(checks_run)'"' == `"`cr'"'
    mata: assert(invtokens(sort(tokens(na + " softfail")', 1)') == nb)
    * ledger rows: identical apart from run, stamp and seq
    tempfile L4
    dataprobe, gatesonly notmissing(x) inrange(x 1 20) ledger("`L4'", run(s4a))
    dataprobe, gatesonly notmissing(x) inrange(x 1 20) ledger("`L4'", run(s4b)) softcollect
    quietly use "`L4'", clear
    assert _N == 4
    assert run == cond(_n <= 2, "s4a", "s4b")
    foreach v of varlist _all {
        if inlist("`v'", "run", "stamp", "seq") continue
        capture confirm string variable `v'
        if !_rc assert `v'[1] == `v'[3] & `v'[2] == `v'[4]
        else assert (`v'[1] == `v'[3] | (missing(`v'[1]) & missing(`v'[3]))) & ///
            (`v'[2] == `v'[4] | (missing(`v'[2]) & missing(`v'[4])))
    }
}
local s4rc = _rc
_ft `s4rc' "S4 strict default: a failing call halts with no note; a passing or warning call prints the same text, the same r() (plus softfail 0) and the same ledger rows with softcollect"

**# S5 the error row takes the call's phase

capture noisily {
    macro drop DATAMAP_DQ
    tempfile L L2
    clear
    quietly set obs 3
    generate x = 1
    dataqa set ledger("`L'") run(ph) phase(analysis)
    capture noisily dataprobe, gatesonly notmissing(zz) phase(build)
    assert _rc == 111
    capture noisily dataprobe, gatesonly notmissing(zz)
    assert _rc == 111
    * not a name: syntax fails, the session phase stands
    capture noisily dataprobe, gatesonly notmissing(x) phase(1bad)
    assert _rc == 198
    dataqa set clear
    quietly use "`L'", clear
    assert _N == 3 & status == "error"
    assert phase[1] == "build"
    assert phase[2] == "analysis"
    assert phase[3] == "analysis"
    * no session: the call's own phase
    clear
    quietly set obs 3
    generate x = 1
    capture noisily dataprobe, gatesonly notmissing(zz) ledger("`L2'") phase(build)
    assert _rc == 111
    quietly use "`L2'", clear
    assert _N == 1 & phase == "build"
}
macro drop DATAMAP_DQ
_ft `=_rc' "S5 an error row is tagged with the call's phase(), else the session phase (also for an invalid phase token)"

**# S6 worker sessions: the error row goes to the shard

capture noisily {
    macro drop DATAMAP_DQ
    local SD "`W'/s6"
    capture mkdir "`SD'"
    capture erase "`SD'/main.dta"
    capture erase "`SD'/main.shard-w1.dta"
    clear
    quietly set obs 3
    generate x = 1
    dataqa set ledger("`SD'/main.dta") run(wk) worker(w1)
    capture noisily dataprobe, gatesonly notmissing(zz)
    assert _rc == 111
    dataprobe, gatesonly notmissing(zz2) softcollect
    assert r(softfail) == 1 & r(softfail_rc) == 111
    dataqa set clear
    capture confirm file "`SD'/main.dta"
    assert _rc == 601
    quietly use "`SD'/main.shard-w1.dta", clear
    assert _N == 2
    assert status == "error" & worker == "w1" & run == "wk"
}
macro drop DATAMAP_DQ
_ft `=_rc' "S6 under dataqa set worker() the error rows (strict and softcollect) go to the worker's shard, never the ledger"

**# R1 name() is literal

capture noisily {
    macro drop DATAMAP_DQ
    tempfile L lg
    mata: st_local("nm", "d" + char(36) + "SFB {bf:x} " + char(96) + "q' }")
    clear
    quietly set obs 3
    generate x = 1
    _sf_cap "`lg'.log" dataprobe, gatesonly notmissing(x) name(`"`macval(nm)'"') ledger("`L'")
    assert `_sf_rc' == 0
    mata: T = _sf_txt(st_local("lg") + ".log")
    mata: assert(strpos(T, "PASS: " + st_local("nm") + ", 1 gate(s)") > 0)
    mata: assert(strpos(T, "EXPANDED") == 0)
    dataprobe, gatesonly notmissing(x) name(`"`macval(nm)'"')
    mata: assert(st_global("r(dataset)") == st_local("nm"))
    * the error row of a failing call, strict and soft
    capture noisily dataprobe, gatesonly notmissing(zz) name(`"`macval(nm)'"') ledger("`L'")
    assert _rc == 111
    dataprobe, gatesonly notmissing(zz) name(`"`macval(nm)'"') ledger("`L'") softcollect
    assert r(softfail) == 1
    * a failing gate: the violation header names it literally
    generate y = .
    _sf_cap "`lg'.log" dataprobe, gatesonly notmissing(y) name(`"`macval(nm)'"')
    assert `_sf_rc' == 9
    mata: assert(strpos(_sf_txt(st_local("lg") + ".log"), "EXPECTATION VIOLATIONS (1): " + st_local("nm")) > 0)
    quietly use "`L'", clear
    assert _N == 3
    mata: assert(all(st_sdata(., "dataset") :== st_local("nm")))
}
_ft `=_rc' "R1 name() holding dollar, backtick and braces is kept literally in the PASS and violation lines, r(dataset), and ledger gate and error rows"

**# R2 byrule() text is literal

* R2a: a dollar and a backtick inside a string literal of the expression
capture noisily {
    macro drop DATAMAP_DQ
    tempfile L
    clear
    quietly set obs 6
    generate id = ceil(_n / 3)
    generate str12 s = "a" + char(36) + "SFB"
    quietly replace s = "a" in 3
    quietly replace s = "a" in 5/6
    * the oracle: rows equal to the literal text
    quietly count if s == "a" + char(36) + "SFB"
    local want = r(N)
    assert `want' == 3
    mata: st_local("sp", "id: lit: s != " + char(34) + "a" + char(36) + "SFB" + char(34))
    capture noisily dataprobe, gatesonly byrule(`"`macval(sp)'"') ledger("`L'")
    assert _rc == 9
    quietly use "`L'", clear
    assert _N == 1 & family == "byrule" & observed_num == `want'
    mata: assert(st_sdata(1, "expected") == "s != " + char(34) + "a" + char(36) + "SFB" + char(34))
    mata: assert(strpos(st_sdata(1, "message"), char(36) + "SFB") > 0)
    mata: assert(strpos(st_sdata(1, "message"), "EXPANDED") == 0)
    * a backtick
    clear
    quietly set obs 4
    generate id = 1
    generate str8 s = "a" + char(96) + "q"
    quietly replace s = "b" in 4
    quietly count if s != "a" + char(96) + "q"
    local want2 = r(N)
    mata: st_local("sp", "id: tick: s == " + char(34) + "a" + char(96) + "q" + char(34))
    tempfile L2
    capture noisily dataprobe, gatesonly byrule(`"`macval(sp)'"') ledger("`L2'")
    assert _rc == 9
    quietly use "`L2'", clear
    assert observed_num == `want2' & `want2' == 1
}
_ft `=_rc' "R2a byrule(): a dollar and a backtick inside a string literal are evaluated literally (counts against count if), ledger expected and message literal"

* R2b: a group aggregate and a strL variable
capture noisily {
    macro drop DATAMAP_DQ
    clear
    quietly set obs 7
    generate id = cond(_n <= 4, 1, 2)
    generate s = cond(inlist(_n, 1, 2, 5), "a" + char(36) + "SFB", "z")
    quietly recast strL s
    confirm strL variable s
    * oracle: groups with more than one literal match, by collapse
    preserve
    generate byte h = (s == "a" + char(36) + "SFB")
    collapse (sum) h, by(id)
    quietly count if h > 1
    local wantg = r(N)
    restore
    assert `wantg' == 1
    mata: st_local("sp", "id: agg: total(s == " + char(34) + "a" + char(36) + "SFB" + char(34) + ") <= 1")
    tempfile L
    capture noisily dataprobe, gatesonly byrule(`"`macval(sp)'"') ledger("`L'")
    assert _rc == 9
    preserve
    quietly use "`L'", clear
    assert observed_num == `wantg'
    mata: assert(strpos(st_sdata(1, "expected"), char(36) + "SFB") > 0)
    restore
    * the row rule on the strL variable
    quietly count if s == "a" + char(36) + "SFB"
    local wantr = r(N)
    mata: st_local("sp", "id: row: s != " + char(34) + "a" + char(36) + "SFB" + char(34))
    tempfile L2
    capture noisily dataprobe, gatesonly byrule(`"`macval(sp)'"') ledger("`L2'")
    assert _rc == 9
    quietly use "`L2'", clear
    assert observed_num == `wantr' & `wantr' == 3
}
_ft `=_rc' "R2b byrule(): a literal dollar inside a group aggregate and in a row rule on a strL variable (counts against collapse/count)"

* R2c: $ in the byspec or the label is refused
capture noisily {
    macro drop DATAMAP_DQ
    clear
    quietly set obs 3
    generate id = 1
    generate x = 1
    mata: st_local("sp", "id" + char(36) + "SFB: l: x > 0")
    tempfile lg
    _sf_cap "`lg'.log" dataprobe, gatesonly byrule(`"`macval(sp)'"')
    assert `_sf_rc' == 198
    mata: assert(strpos(_sf_txt(st_local("lg") + ".log"), "byrule() byspec must name variables") > 0)
    mata: st_local("sp", "id: l" + char(36) + "SFB: x > 0")
    _sf_cap "`lg'.log" dataprobe, gatesonly byrule(`"`macval(sp)'"')
    assert `_sf_rc' == 198
    mata: assert(strpos(_sf_txt(st_local("lg") + ".log"), "byrule() label must not contain $") > 0)
    * a plain rule is untouched
    dataprobe, gatesonly byrule(id: "ok": x > 0)
}
_ft `=_rc' "R2c byrule(): a dollar in the byspec or the label is refused with r(198); a plain rule passes"

**# R3 checks() rows holding macro characters are refused

capture noisily {
    macro drop DATAMAP_DQ
    clear
    quietly set obs 4
    generate str20 t = "abc"
    generate str20 s = "a" + char(36) + "SFB"
    tempfile data
    quietly save "`data'"
    * a rule row whose expression holds $SFB
    clear
    quietly set obs 2
    generate str10 gate = "notmissing"
    generate str40 var = "t"
    generate str60 pattern = ""
    quietly replace gate = "rule" in 2
    quietly replace var = "r1" in 2
    quietly replace pattern = "s != " + char(34) + "a" + char(36) + "SFB" + char(34) in 2
    tempfile ck
    quietly save "`ck'"
    use "`data'", clear
    tempfile lg
    _sf_cap "`lg'.log" dataprobe, gatesonly checks("`ck'")
    assert `_sf_rc' == 198
    mata: assert(strpos(_sf_txt(st_local("lg") + ".log"), "checks(): row 2, column pattern, holds a backtick") > 0)
    * a backtick in var
    use "`ck'", clear
    quietly replace pattern = "x > 0" in 2
    quietly replace var = "r" + char(96) + "1" in 2
    quietly save "`ck'", replace
    use "`data'", clear
    _sf_cap "`lg'.log" dataprobe, gatesonly checks("`ck'")
    assert `_sf_rc' == 198
    mata: assert(strpos(_sf_txt(st_local("lg") + ".log"), "checks(): row 2, column var,") > 0)
    * a regex $ anchor (no name follows) is plain text and works
    clear
    quietly set obs 1
    generate str10 gate = "regex"
    generate str10 var = "t"
    generate str20 pattern = "^[a-z]+" + char(36)
    quietly save "`ck'", replace
    use "`data'", clear
    dataprobe, gatesonly checks("`ck'")
    assert r(n_failed) == 0 & r(n_checks) == 1
    * and a regex that the anchor makes fail
    use "`ck'", clear
    quietly replace pattern = "^[a-z]" + char(36)
    quietly save "`ck'", replace
    use "`data'", clear
    capture noisily dataprobe, gatesonly checks("`ck'")
    assert _rc == 9
}
_ft `=_rc' "R3 checks(): a row holding a global reference or a backtick is refused naming the row and column; a regex end anchor is accepted and evaluated"

**# R4 groupstat() group labels print literally

capture noisily {
    macro drop DATAMAP_DQ
    clear
    quietly set obs 40
    mata: st_local("g1", "g" + char(36) + "SFB")
    mata: st_local("g2", "h{bf:y}" + char(96) + "z")
    generate str20 g = ""
    mata: st_sstore((1::20), "g", J(20, 1, st_local("g1")))
    mata: st_sstore((21::40), "g", J(20, 1, st_local("g2")))
    generate x = _n
    quietly summarize x if _n <= 20, detail
    local m1 = strtrim(string(r(mean), "%10.4g"))
    local p51 = strtrim(string(r(p5), "%10.4g"))
    local p951 = strtrim(string(r(p95), "%10.4g"))
    quietly summarize x if _n > 20
    local m2 = strtrim(string(r(mean), "%10.4g"))
    tempfile lg
    _sf_cap "`lg'.log" dataprobe x, gatesonly groupstat(mean x, by(g))
    assert `_sf_rc' == 0
    mata: L = _sf_lines(st_local("lg") + ".log")
    mata: assert(sum(strpos(L, "EXPANDED")) == 0)
    mata: r1 = select(L, strpos(L, "  " + st_local("g1") + " ") :> 0)
    mata: r2 = select(L, strpos(L, "  " + st_local("g2") + " ") :> 0)
    mata: rp = select(L, strpos(L, "  pooled ") :> 0)
    mata: assert(cols(r1) == 1 & cols(r2) == 1 & cols(rp) == 1)
    mata: assert(_sf_tail(r1[1], 1) == st_local("m1"))
    mata: assert(_sf_tail(r2[1], 1) == st_local("m2"))
    * the table keeps its columns: each group row is as long as the pooled row
    mata: assert(ustrlen(r1[1]) == ustrlen(rp[1]) & ustrlen(r2[1]) == ustrlen(rp[1]))
    * several statistics, p5 and p95 among them
    _sf_cap "`lg'.log" dataprobe x, gatesonly groupstat(mean p5 p95: x, by(g))
    assert `_sf_rc' == 0
    mata: L = _sf_lines(st_local("lg") + ".log")
    mata: r1 = select(L, strpos(L, st_local("g1")) :> 0)
    mata: assert(cols(r1) == 1)
    mata: assert(_sf_tail(r1[1], 3) == st_local("m1") + " " + st_local("p51") + " " + st_local("p951"))
    mata: assert(cols(select(L, strpos(L, st_local("g2")) :> 0)) == 1)
    * a band that the second group fails: the ledger names the group literally
    tempfile L
    capture noisily dataprobe x, gatesonly groupstat(mean x, by(g) band(0 20)) ledger("`L'")
    assert _rc == 9
    assert `m2' > 20 & `m1' <= 20
    quietly use "`L'", clear
    quietly keep if status == "fail"
    assert _N == 1
    mata: assert(st_sdata(1, "grp") == "by(g) = " + st_local("g2"))
    mata: assert(strpos(st_sdata(1, "message"), "in group " + st_local("g2") + ",") > 0)
}
_ft `=_rc' "R4 groupstat(): labels holding dollar, backtick and braces print literally, aligned, in one- and multi-statistic tables (mean/p5/p95 against summarize), and a band failure names the group literally in the ledger"

* R4b: one group, and a group variable with no value in scope
capture noisily {
    macro drop DATAMAP_DQ
    clear
    quietly set obs 10
    mata: st_local("g1", "only" + char(36) + "SFB")
    generate str20 g = ""
    mata: st_sstore(., "g", J(10, 1, st_local("g1")))
    generate x = _n
    tempfile lg
    _sf_cap "`lg'.log" dataprobe x, gatesonly groupstat(mean x, by(g))
    assert `_sf_rc' == 0
    mata: assert(strpos(_sf_txt(st_local("lg") + ".log"), st_local("g1")) > 0)
    quietly replace g = ""
    generate gn = .
    _sf_cap "`lg'.log" dataprobe x, gatesonly groupstat(mean x, by(gn))
    assert `_sf_rc' == 0
    mata: assert(strpos(_sf_txt(st_local("lg") + ".log"), "no rows in scope") > 0)
}
_ft `=_rc' "R4b groupstat(): a single hostile group prints literally; an all-missing group variable reports no rows in scope"

**# R5 the Markdown writers

capture noisily {
    macro drop DATAMAP_DQ
    local MD "`W'/md"
    capture mkdir "`MD'"
    clear
    quietly set obs 30
    generate byte cat = mod(_n, 3)
    generate str20 s = "v" + string(mod(_n, 4))
    mata: st_local("vl", "lab|pipe " + char(36) + "SFB " + char(96) + "tick' {bf:b} see [x](http://e.x) ![i](http://t.x/p.png)")
    label variable cat `"`macval(vl)'"'
    mata: st_local("v1", "one|" + char(36) + "SFB")
    label define catl 0 "zero" 1 `"`macval(v1)'"' 2 "two"
    label values cat catl
    label variable s "Weight [kg]"
    mata: st_global("_dta[note1]", "note " + char(36) + "SFB [n](http://n.x)")
    mata: st_global("_dta[note0]", "1")
    quietly save "`MD'/a]b.dta", replace
    quietly save "`MD'/c[1].dta", replace
    mata: st_local("ti", "T " + char(36) + "SFB | " + char(96) + "t' [l](http://l.x)")
    datamap, directory("`MD'") output("`MD'/out.md") title(`"`macval(ti)'"')
    mata: T = invtokens(cat(st_local("MD") + "/out.md")', char(10))
    * literal, never expanded
    mata: assert(strpos(T, "EXPANDED") == 0)
    * the variable label: pipe escaped, $ and ` as entities, links broken
    mata: assert(strpos(T, "lab\|pipe &#36;SFB &#96;tick' {bf:b} see [x]\(http://e.x) ![i]\(http://t.x/p.png)") > 0)
    mata: assert(strpos(T, "1 one\|&#36;SFB") > 0)
    mata: assert(strpos(T, "note &#36;SFB [n]\(http://n.x)") > 0)
    mata: assert(strpos(T, "# T &#36;SFB \| &#96;t' [l]\(http://l.x)") > 0)
    * no unescaped "](" outside the Contents links
    mata: L = cat(st_local("MD") + "/out.md")'
    mata: assert(_sf_nmatch(L, "\]\(") == _sf_nmatch(L, "^[0-9]+\. \[.*\]\(#"))
    * the two datasets and the Linkage section
    mata: assert(_sf_nmatch(L, "^[0-9]+\. \[") == 3)
    * brackets that pair up are left alone; a label without "](" is unchanged
    mata: assert(strpos(T, "Weight [kg]") > 0)
    mata: assert(_sf_nmatch(L, "^[0-9]+\. \[c\[1\]\]\(#") == 1)
    * unpaired brackets in a Contents entry are escaped, so the link works
    mata: assert(sum(strpos(L, ". [a\]b](#") :> 0) == 1)
}
_ft `=_rc' "R5a Markdown: labels, value labels, notes and the title stay literal; a bracket-paren never forms a link or image; Contents brackets escaped only when unpaired"

capture noisily {
    macro drop DATAMAP_DQ
    local MD "`W'/md2"
    capture mkdir "`MD'"
    clear
    quietly set obs 3
    generate x = _n
    * the file a wrongly expanded line would name
    quietly save "`MD'/EXPANDED.dta", replace
    tempname fh
    file open `fh' using "`MD'/list.txt", write text replace
    mata: st_local("ml", st_local("MD") + "/" + char(36) + "SFB.dta")
    file write `fh' `"`macval(ml)'"' _n
    file close `fh'
    capture noisily datamap, manifest("`MD'/list.txt") output("`MD'/out.md")
    assert _rc == 198
    capture confirm file "`MD'/out.md"
    assert _rc == 601
    * a plain manifest line still works
    file open `fh' using "`MD'/list.txt", write text replace
    file write `fh' "`MD'/EXPANDED.dta" _n
    file close `fh'
    datamap, manifest("`MD'/list.txt") output("`MD'/out.md")
    confirm file "`MD'/out.md"
}
_ft `=_rc' "R5b Markdown: a manifest line holding a global reference is refused (r(198)), never expanded into another file; a plain line works"

* R5c: Markdown block starts cannot define a link target or a heading
capture noisily {
    macro drop DATAMAP_DQ
    local MD "`W'/md3"
    capture mkdir "`MD'"
    clear
    quietly set obs 10
    generate byte x = mod(_n, 2)
    label variable x "[a][b] ref"
    mata: st_global("_dta[note1]", "[ref]: http://evil.example/x")
    mata: st_global("_dta[note2]", "# Not a heading")
    mata: st_global("_dta[note3]", "12. list item")
    mata: st_global("_dta[note4]", "1999 was a year")
    mata: st_global("_dta[note5]", "- dash")
    mata: st_global("_dta[note6]", "plain note [x] y")
    mata: st_global("_dta[note0]", "6")
    quietly save "`MD'/d.dta", replace
    tempname fh
    file open `fh' using "`MD'/chlog.txt", write text replace
    file write `fh' "- item one" _n
    file write `fh' "[c]: http://c.example/" _n
    file close `fh'
    datamap, directory("`MD'") output("`MD'/out.md") title("T") ///
        subtitle("[s]: http://s.example/") notes("[n]: http://n.example/") ///
        changelog("`MD'/chlog.txt")
    mata: L = cat(st_local("MD") + "/out.md")'
    * no line of the document can define a link reference
    mata: assert(_sf_nmatch(L, "^ {0,3}\[[^\]]*\]:") == 0)
    mata: assert(_sf_nmatch(L, "^ *- \[[^\]]*\]:") == 0)
    mata: assert(sum(L :== "  - \[ref]: http://evil.example/x") == 1)
    mata: assert(sum(L :== "\[s]: http://s.example/") == 1)
    mata: assert(sum(L :== "\[n]: http://n.example/") == 1)
    mata: assert(sum(L :== "\[c]: http://c.example/") == 1)
    * a note's own heading and list markers read as text
    mata: assert(sum(L :== "  - \# Not a heading") == 1)
    mata: assert(sum(L :== "  - 12\. list item") == 1)
    mata: assert(sum(L :== "  - \- dash") == 1)
    * text that starts any other way is unchanged
    mata: assert(sum(L :== "  - 1999 was a year") == 1)
    mata: assert(sum(L :== "  - plain note [x] y") == 1)
    mata: assert(_sf_nmatch(L, "\| \[a\]\[b\] ref \|") == 1)
    * the user's own changelog list line keeps its marker
    mata: assert(sum(L :== "- item one") == 1)
}
_ft `=_rc' "R5c Markdown: a note, subtitle, notes() or changelog() line starting with [ never defines a link target; a note's heading and list markers are escaped; other text and the user's own list lines unchanged"

**# R6 rule() and review() text is literal

capture noisily {
    macro drop DATAMAP_DQ
    tempfile L lg
    clear
    quietly set obs 6
    generate str12 s = "a" + char(36) + "SFB"
    quietly replace s = "a" in 3
    * the oracles: rows equal to the literal text, and the rest
    quietly count if s == "a" + char(36) + "SFB"
    local nlit = r(N)
    quietly count if s != "a" + char(36) + "SFB"
    local nother = r(N)
    assert `nlit' == 5 & `nother' == 1
    mata: st_local("ex", "s != " + char(34) + "a" + char(36) + "SFB" + char(34))
    mata: st_local("sp", "l: " + st_local("ex"))
    * strict: the rule fails on the rows equal to the literal
    _sf_cap "`lg'.log" dataprobe, gatesonly rule(`"`macval(sp)'"') review(`"`macval(sp)'"') ledger("`L'")
    assert `_sf_rc' == 9
    mata: T = _sf_txt(st_local("lg") + ".log")
    mata: assert(strpos(T, "EXPANDED") == 0)
    mata: assert(strpos(T, "rule(l): `nlit' obs fail " + st_local("ex")) > 0)
    mata: assert(strpos(T, "review(l): `nother' of 6 rows") > 0)
    quietly use "`L'", clear
    assert _N == 2
    quietly count if family == "rule" & observed_num == `nlit'
    assert r(N) == 1
    quietly count if family == "review" & observed_num == `nother'
    assert r(N) == 1
    mata: assert(all(st_sdata(., "expected") :== st_local("ex")))
    mata: assert(sum(strpos(st_sdata(., "message"), "EXPANDED")) == 0)
    mata: assert(sum(st_sdata(., "message") :== "rule(l): `nlit' obs fail " + st_local("ex")) == 1)
    * a backtick: no row holds the literal, so every row fails
    clear
    quietly set obs 4
    generate str8 s = "a"
    mata: st_local("ex", "s == " + char(34) + "a" + char(96) + "x'" + char(34))
    mata: st_local("sp", "q: " + st_local("ex"))
    quietly count if !(s == "a" + char(96) + "x'")
    local nbad = r(N)
    assert `nbad' == 4
    tempfile L2
    capture noisily dataprobe, gatesonly rule(`"`macval(sp)'"') ledger("`L2'")
    assert _rc == 9
    quietly use "`L2'", clear
    assert _N == 1 & observed_num == `nbad'
    mata: assert(st_sdata(1, "expected") == st_local("ex"))
    * a dollar in the label is refused, never expanded
    clear
    quietly set obs 2
    generate x = 1
    mata: st_local("sl", "l" + char(36) + "SFB: x == 1")
    _sf_cap "`lg'.log" dataprobe, gatesonly rule(`"`macval(sl)'"')
    assert `_sf_rc' == 198
    mata: assert(strpos(_sf_txt(st_local("lg") + ".log"), "rule() label must not contain $") > 0)
    _sf_cap "`lg'.log" dataprobe, gatesonly review(`"`macval(sl)'"')
    assert `_sf_rc' == 198
    mata: assert(strpos(_sf_txt(st_local("lg") + ".log"), "review() label must not contain $") > 0)
    * a plain rule is unchanged
    dataprobe, gatesonly rule(one: x == 1) review("two": x == 1)
    assert r(n_failed) == 0
}
_ft `=_rc' "R6 rule() and review(): a dollar and a backtick in an expression stay literal (fail and review counts equal base count), ledger expected and message literal; a dollar in the label is refused"

**# R7 a data file name holding a backtick

capture noisily {
    macro drop DATAMAP_DQ
    local FN "`W'/fn"
    capture mkdir "`FN'"
    tempfile L lg
    clear
    quietly set obs 3
    generate x = 1
    mata: st_local("bn", "b" + char(96) + "t")
    mata: st_local("full", st_local("FN") + "/" + st_local("bn") + ".dta")
    quietly save `"`macval(full)'"', replace
    quietly use `"`macval(full)'"', clear
    mata: assert(st_global("c(filename)") == st_local("full"))
    _sf_cap "`lg'.log" dataprobe, gatesonly notmissing(x) ledger("`L'")
    assert `_sf_rc' == 0
    mata: assert(strpos(_sf_txt(st_local("lg") + ".log"), "PASS: " + st_local("bn") + ", 1 gate(s)") > 0)
    dataprobe, gatesonly notmissing(x)
    mata: assert(st_global("r(dataset)") == st_local("bn"))
    * strict error: its own rc, one error row
    capture noisily dataprobe, gatesonly notmissing(zz) ledger("`L'")
    assert _rc == 111
    * softcollect: continues, one more error row
    dataprobe, gatesonly notmissing(zz) ledger("`L'") softcollect
    assert r(softfail) == 1 & r(softfail_rc) == 111
    * a call that fails in syntax: _dataprobe_errrow names the file itself
    capture noisily dataprobe, gatesonly notmissing(x) nosuchopt ledger("`L'")
    assert _rc == 198
    * modified since the save
    quietly replace x = 2
    dataprobe, gatesonly notmissing(x)
    mata: assert(st_global("r(dataset)") == st_local("bn") + " (modified)")
    quietly use "`L'", clear
    assert _N == 4
    quietly count if status == "pass"
    assert r(N) == 1
    quietly count if status == "error"
    assert r(N) == 3
    mata: assert(all(st_sdata(., "dataset") :== st_local("bn")))
    * no file name: no dataset name, as before
    clear
    quietly set obs 2
    generate x = 1
    dataprobe, gatesonly notmissing(x)
    assert `"`r(dataset)'"' == ""
}
_ft `=_rc' "R7 a data file named with a backtick: PASS line, r(dataset) and ledger pass and error rows (strict, softcollect, and a syntax failure) name it literally; (modified) kept; no file name gives none"

**# D2 p5 and p95 in stat()

capture noisily {
    macro drop DATAMAP_DQ
    sysuse auto, clear
    quietly summarize price, detail
    local p5 = r(p5)
    local p95 = r(p95)
    * the help example's bands hold the true values
    assert inrange(`p5', 3000, 4000) & inrange(`p95', 12000, 15000)
    dataprobe, gatesonly stat(p5 price 3000 4000 \ p95 price 12000 15000)
    assert r(n_failed) == 0
    dataprobe, gatesonly stat(p5 price `p5' `p5' \ p95 price `p95' `p95')
    assert r(n_failed) == 0
    capture noisily dataprobe, gatesonly stat(p5 price `=`p5' + 1' 99999)
    assert _rc == 9
    capture noisily dataprobe, gatesonly stat(p95 price 0 `=`p95' - 1')
    assert _rc == 9
}
_ft `=_rc' "D2 stat(): p5 and p95 equal summarize, detail (bands at the value pass, just beyond fail); the help example bands hold"

* D2b: p1 and p99 work in stat() and groupstat(); a percentile summarize,
* detail does not report is refused, as the help says
capture noisily {
    macro drop DATAMAP_DQ
    sysuse auto, clear
    quietly summarize price, detail
    local p1 = r(p1)
    local p99 = r(p99)
    dataprobe, gatesonly stat(p1 price `p1' `p1' \ p99 price `p99' `p99')
    assert r(n_failed) == 0
    capture noisily dataprobe, gatesonly stat(p99 price 0 `=`p99' - 1')
    assert _rc == 9
    quietly summarize price if foreign == 1, detail
    local g1 = r(p95)
    capture noisily dataprobe, gatesonly groupstat(p95 price, by(foreign) band(0 `=`g1' - 1'))
    assert _rc == 9
    dataprobe, gatesonly groupstat(p1 p5 p95 p99: price, by(foreign))
    foreach p in p2 p37 {
        capture noisily dataprobe, gatesonly stat(`p' price 0 20000)
        assert _rc == 198
        capture noisily dataprobe, gatesonly groupstat(`p' price, by(foreign))
        assert _rc == 198
    }
}
_ft `=_rc' "D2b stat() p1 and p99 equal summarize, detail; groupstat() p95 band fails below the group value; p2 and p37 are refused (r(198))"

**# Cleanup

macro drop DATAMAP_DQ
macro drop SFB
sysdir set PLUS `"`_old_plus'"'
sysdir set PERSONAL `"`_old_personal'"'
discard
capture mata: mata drop _sf_txt() _sf_rnames() _sf_nmatch() _sf_lines() _sf_tail()
capture mata: mata drop T L r1 r2 rp w na nb
display as result "Results: $PASS/$TC passed, $FAIL failed"
display "RESULT: test_datamap_v210_safety tests=$TC pass=$PASS fail=$FAIL"
log close main
if $FAIL > 0 exit 1
