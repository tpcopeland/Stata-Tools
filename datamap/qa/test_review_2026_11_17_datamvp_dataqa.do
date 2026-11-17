*! test_review_2026_11_17_datamvp_dataqa.do  2026/11/17
*! datamap 2.1.0 external review (2026-11-17), datamvp and dataqa slice:
*! scratch-variable collisions, quote-hostile bytable() labels, a leak of
*! a masked count through Mean missing/obs under notable, save() naming
*! the current frame, correlations on one observation, and smallcells()
*! literals in the dataqa export release copy
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Oracles are base Stata (count, frames, use of the exported file) on
* fixtures built here, and the literal text a fixture writes; datamvp's own
* output is never the expected value.
*
*   R10 graph(patterns) gby() with a varlist variable named _mv_n and a gby()
*       variable named _ng: rc 0 and the graph is drawn (r(110) before)
*   R11 bytable() labels holding "' , $name and a backtick: rc 0, the header
*       prints each label as written, r(lab#) of the helper match the data,
*       miss_by matches a count oracle (r(109) in the helper before)
*   R12 notable maskrare on N = 100 with 2 missing: Mean missing/obs reads
*       [suppressed] (0.02 before), r(masked) = 1; unmasked it reads 0.02
*   R22 save(<current frame>) errors r(198) with a message before any table
*       (silent r(119) before); save(<other frame>) still writes the patterns
*   R26 N = 1: correlate skips with a note (rc 0, no r(corr_miss));
*       graph(correlation) exits r(2001) with a message, r(N) still posted
*   L5  dataqa export blanks a smallcells() label, variable and message
*       holding a literal (id==12345, nm=="Smith", id>=12345); one with no
*       literal is kept; no string column of the copy carries the literal
*   L6  dataqa export blanks a stat() message whose "(if ...)" tail holds a
*       literal (id==12345, s=="ab"); a stat() if without one and events()
*       messages are kept; no string column carries the literal
*   R13 datamvp contract: stored results are not masked; with Mean
*       missing/obs [suppressed] on the console, r(mean_miss) and
*       r(N_mv_total) hold the exact values (oracle: count)
version 16.0
clear all
set more off
set linesize 255
capture log close _all
log using "test_review_2026_11_17_datamvp_dataqa.log", replace text name(main)
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
* restored before the RESULT line so a runner's install sandbox stays in force
local _old_plus : sysdir PLUS
local _old_personal : sysdir PERSONAL
tempfile base
local W "`base'_rv1117c"
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
* the rc is left in the caller's local _rv_rc and the command's r() is
* passed through
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

capture mata: mata drop _rv_has() _rv_line() _rv_after()
mata:
// 1 when a line of the log holds needle (the needle is passed through a
// local, so quotes and dollar signs reach Mata as written)
real scalar _rv_has(string scalar fn, string scalar needle)
{
	string colvector L
	real scalar i
	L = cat(fn)
	for (i = 1; i <= rows(L); i++) if (strpos(L[i], needle)) return(1)
	return(0)
}
// the line after the first line of the log that starts with mark
string scalar _rv_after(string scalar fn, string scalar mark)
{
	string colvector L
	real scalar i
	L = cat(fn)
	for (i = 1; i < rows(L); i++) if (strpos(L[i], mark) == 1) return(L[i + 1])
	return("")
}
// the first line of the log that starts with head
string scalar _rv_line(string scalar fn, string scalar head)
{
	string colvector L
	real scalar i
	L = cat(fn)
	for (i = 1; i <= rows(L); i++) if (strpos(L[i], head) == 1) return(L[i])
	return("")
}
end

**# R10 graph(patterns) gby(): user variables named like the old scratch names

capture noisily {
    local f "`W'/r10.log"
    clear
    set obs 60
    generate double _mv_n = cond(mod(_n, 3) == 0, ., _n)
    generate double x = cond(mod(_n, 4) == 0, ., _n)
    generate byte _ng = mod(_n, 2)
    capture graph drop r10g
    _rv_cap "`f'" : datamvp _mv_n x, gby(_ng) graph(patterns) gname(r10g) nodraw
    assert `_rv_rc' == 0
    assert r(N) == 60
    * the named graph exists
    graph describe r10g
    * the caller's data is untouched (oracle: count)
    count if missing(_mv_n)
    assert r(N) == 20
    confirm variable _mv_n x _ng
    assert c(k) == 3
    graph drop r10g
}
_rv `=_rc' "R10 graph(patterns) gby(): a varlist variable _mv_n and a gby() variable _ng draw (no r(110))"

**# R11 bytable() labels with "' , $ and backtick

capture noisily {
    local f "`W'/r11.log"
    global e "EXPANDED"
    clear
    set obs 40
    generate double x = cond(mod(_n, 3) == 0, ., _n)
    generate double y = cond(mod(_n, 5) == 0, ., _n)
    generate str12 grp = "d" + char(36) + "e" + char(34) + "f" if _n <= 20
    replace grp = "a" + char(34) + char(39) + "b" if _n > 20
    * the literal labels, built without macro syntax
    mata: st_local("L1", "a" + char(34) + char(39) + "b")
    mata: st_local("L2", "d" + char(36) + "e" + char(34) + "f")
    _rv_cap "`f'" : datamvp x y, bytable(grp)
    assert `_rv_rc' == 0
    * the header prints both labels as written (egen group order: a... first)
    mata: st_local("hdr", _rv_after(st_local("f"), "Percent missing by grp"))
    mata: st_local("want", "Variable     |" + (9 - 4) * " " + st_local("L1") + (9 - 5) * " " + st_local("L2") + "  Max diff    Hi/Lo")
    mata: assert(st_local("hdr") == st_local("want"))
    mata: assert(!_rv_has(st_local("f"), "EXPANDED"))
    * miss_by against a count oracle: x is missing on rows 3,6,...; group a
    * is rows 21-40
    matrix MB = r(miss_by)
    count if missing(x) & _n > 20
    local ma = r(N)
    count if missing(x) & _n <= 20
    local md = r(N)
    assert !missing(MB[1, 1]) & !missing(MB[1, 2]) & `ma' > 0 & `md' > 0
    assert abs(MB[1, 1] - 100 * `ma' / 20) < 1e-12
    assert abs(MB[1, 2] - 100 * `md' / 20) < 1e-12
    * the helper's labels are returned as written
    tempvar t
    generate byte `t' = 1
    _datamap_missby x y, by(grp) touse(`t')
    mata: assert(st_global("r(lab1)") == st_local("L1"))
    mata: assert(st_global("r(lab2)") == st_local("L2"))
    assert r(G) == 2
    * a backtick label and a bare $name
    replace grp = "d" + char(36) + "e" if _n <= 20
    replace grp = "q" + char(96) + "z" + char(39) if _n > 20
    mata: st_local("L3", "d" + char(36) + "e")
    mata: st_local("L4", "q" + char(96) + "z" + char(39))
    _rv_cap "`f'" : datamvp x y, bytable(grp)
    assert `_rv_rc' == 0
    mata: st_local("hdr", _rv_after(st_local("f"), "Percent missing by grp"))
    mata: st_local("want", "Variable     |" + (9 - 3) * " " + st_local("L3") + (9 - 4) * " " + st_local("L4") + "  Max diff    Hi/Lo")
    mata: assert(st_local("hdr") == st_local("want"))
    mata: assert(!_rv_has(st_local("f"), "EXPANDED"))
    macro drop e
}
_rv `=_rc' "R11 bytable(): labels holding quote-apostrophe, dollar and backtick print as written"
capture macro drop e

**# R12 notable maskrare: Mean missing/obs of a lone masked variable

capture noisily {
    local f "`W'/r12.log"
    clear
    set obs 100
    generate double x = cond(_n <= 2, ., _n)
    count if missing(x)
    assert r(N) == 2
    _rv_cap "`f'" : datamvp x, notable maskrare
    assert `_rv_rc' == 0
    assert r(masked) == 1
    mata: assert(_rv_line(st_local("f"), "Mean missing/obs:") == "Mean missing/obs:        [suppressed]")
    mata: assert(!_rv_has(st_local("f"), "0.02"))
    * with the table the same suppression (unchanged)
    _rv_cap "`f'" : datamvp x, maskrare
    mata: assert(_rv_line(st_local("f"), "Mean missing/obs:") == "Mean missing/obs:        [suppressed]")
    * no mask: the mean is 2 / 100
    _rv_cap "`f'" : datamvp x, notable
    assert `_rv_rc' == 0
    mata: assert(_rv_line(st_local("f"), "Mean missing/obs:") == "Mean missing/obs:              0.02")
    * a count at or above m is not masked under notable either
    replace x = . if _n <= 10
    _rv_cap "`f'" : datamvp x, notable maskrare
    assert r(masked) == 0
    mata: assert(_rv_line(st_local("f"), "Mean missing/obs:") == "Mean missing/obs:              0.10")
}
_rv `=_rc' "R12 notable maskrare: Mean missing/obs is [suppressed] when a Miss or Obs count is 1..m-1"

**# R22 save() naming the current frame

capture noisily {
    local f "`W'/r22.log"
    clear
    set obs 30
    generate double x = cond(mod(_n, 3) == 0, ., _n)
    generate double y = cond(mod(_n, 5) == 0, ., _n)
    local cf = c(frame)
    _rv_cap "`f'" : datamvp x y, save(`cf')
    assert `_rv_rc' == 198
    mata: assert(_rv_has(st_local("f"), "save(" + st_local("cf") + "): " + st_local("cf") + " is the current frame; name another frame or a file"))
    * refused before any table is printed
    mata: assert(!_rv_has(st_local("f"), "Total observations:"))
    assert _N == 30 & c(frame) == "`cf'"
    * another frame name still receives the patterns
    capture frame drop r22fr
    datamvp x y, save(r22fr)
    local np = r(N_patterns)
    frame r22fr: assert _N == `np'
    frame r22fr: summarize freq, meanonly
    frame r22fr: assert r(sum) == 30
    frame drop r22fr
}
_rv `=_rc' "R22 save(<current frame>) errors r(198) with a message before output; another frame still written"
capture frame drop r22fr

**# R26 one observation: correlate and graph(correlation)

capture noisily {
    local f "`W'/r26.log"
    clear
    set obs 1
    generate double x = .
    generate double y = 1
    _rv_cap "`f'" : datamvp x y, nodrop correlate
    assert `_rv_rc' == 0
    mata: assert(_rv_has(st_local("f"), "(correlations not computed (rc=2001); skipped)"))
    capture confirm matrix r(corr_miss)
    assert _rc != 0
    assert r(N) == 1
    _rv_cap "`f'" : datamvp x y, nodrop graph(correlation) nodraw
    assert `_rv_rc' == 2001
    mata: assert(_rv_has(st_local("f"), "correlation graph not drawn: the missingness correlations could not be computed (too few observations)"))
    * the analytical returns are still posted
    assert r(N) == 1 & r(N_vars) == 2
    * two observations still compute the correlation
    set obs 2
    replace x = 1 in 2
    replace y = . in 2
    datamvp x y, nodrop correlate
    confirm matrix r(corr_miss)
}
_rv `=_rc' "R26 N = 1: correlate skips with a note; graph(correlation) exits r(2001) with a message"

**# L5 dataqa export: smallcells() literal in label and message

capture noisily {
    local f "`W'/l5.log"
    local L "`W'/l5_ledger.dta"
    local EX "`W'/l5_export.dta"
    capture erase "`L'"
    clear
    set obs 50
    generate long id = _n + 12340
    generate byte c = mod(_n, 3)
    generate str10 nm = cond(_n == 3, "Smith", "Jones")
    capture noisily dataprobe, gatesonly maskrare smallcells(id==12345 c==1) ledger("`L'", run(s1))
    capture noisily dataprobe, gatesonly maskrare smallcells(nm=="Smith" c==1) ledger("`L'", run(s1))
    capture noisily dataprobe, gatesonly maskrare smallcells(id>=12345 c==1) ledger("`L'", run(s1))
    capture noisily dataprobe, gatesonly maskrare smallcells(c==1 c==2) ledger("`L'", run(s1))
    * the working ledger holds the literal (oracle: use)
    preserve
    use "`L'", clear
    count if family == "smallcells" & strpos(label, "12345")
    assert r(N) == 2
    count if family == "smallcells" & (strpos(variable, "12345") | strpos(variable, "Smith"))
    assert r(N) == 3
    restore
    dataqa export using "`L'", run(s1) saving("`EX'") replace
    assert r(n_text_dropped) == 6
    preserve
    use "`EX'", clear
    keep if family == "smallcells"
    assert _N == 4
    * no column of the release copy carries a literal
    foreach v of varlist _all {
        capture confirm string variable `v'
        if !_rc {
            count if strpos(`v', "12345") | strpos(`v', "Smith")
            assert r(N) == 0
        }
    }
    count if label == "" & message == "" & variable == ""
    assert r(N) == 3
    count if label == "c==1 c==2" & variable == "c==1 c==2" & message != ""
    assert r(N) == 1
    restore
}
_rv `=_rc' "L5 dataqa export: a smallcells() label, variable and message holding a literal are blanked; one without is kept"

**# L6 dataqa export: a stat() if literal in the message

capture noisily {
    local f "`W'/l6.log"
    local L "`W'/l6_ledger.dta"
    local EX "`W'/l6_export.dta"
    capture erase "`L'"
    clear
    set obs 60
    generate long id = 12340 + _n
    generate double x = _n
    generate byte c = (_n <= 3)
    generate byte ev = mod(_n, 2)
    generate str4 s = cond(_n <= 2, "ab", "cd")
    capture noisily dataprobe, gatesonly maskrare mincell(5) stat(mean x 0 1 if id==12345) ledger("`L'", run(s1))
    capture noisily dataprobe, gatesonly maskrare mincell(5) stat(mean x 0 1 if s=="ab") ledger("`L'", run(s1))
    capture noisily dataprobe, gatesonly maskrare mincell(5) stat(mean x 0 1 if x > 0) ledger("`L'", run(s1))
    capture noisily dataprobe, gatesonly maskrare mincell(5) events(ev if id==12345: c, min(50)) ledger("`L'", run(s1))
    * the working ledger holds the literal in the message (oracle: use)
    preserve
    use "`L'", clear
    count if family == "stat" & strpos(message, "(if id==12345)")
    assert r(N) == 1
    count if family == "stat" & strpos(message, "(if s==" + char(34) + "ab" + char(34) + ")")
    assert r(N) == 1
    restore
    _rv_cap "`f'" : dataqa export using "`L'", run(s1) saving("`EX'") replace
    assert `_rv_rc' == 0
    assert r(n_text_dropped) == 2
    mata: assert(_rv_has(st_local("f"), "  2 expectation, label, or message text(s) with literal values blanked"))
    preserve
    use "`EX'", clear
    assert _N == 5
    foreach v of varlist _all {
        capture confirm string variable `v'
        if !_rc {
            count if strpos(`v', "12345") | strpos(`v', char(34))
            assert r(N) == 0
        }
    }
    count if family == "stat" & message == ""
    assert r(N) == 2
    * the stat() row without a literal keeps its message, if and all
    count if family == "stat" & strpos(message, "stat(mean x): ") == 1 & strpos(message, "(if x > 0)")
    assert r(N) == 1
    * events() messages carry no if text and are kept
    count if family == "events" & message == "events(ev): c = 1 has 0 events, expected >= 50"
    assert r(N) == 1
    restore
}
_rv `=_rc' "L6 dataqa export: a stat() message whose (if ...) holds a literal is blanked; one without is kept"

**# R13 datamvp contract: r() is not masked

capture noisily {
    local f "`W'/r13.log"
    * N = 100: x1 missing on 2 rows (a small cell), x2 on 33, none on both
    clear
    set obs 100
    generate double x1 = cond(_n <= 2, ., 1)
    generate double x2 = cond(mod(_n, 3) == 0, ., 1)
    count if missing(x1)
    local n1 = r(N)
    count if missing(x2)
    local ntot = `n1' + r(N)
    assert `ntot' == 35
    _rv_cap "`f'" : datamvp x1 x2, notable maskrare mincell(5)
    assert `_rv_rc' == 0
    mata: assert(_rv_line(st_local("f"), "Mean missing/obs:") == "Mean missing/obs:        [suppressed]")
    assert r(masked) == 1
    assert r(N_mv_total) == `ntot'
    assert reldif(r(mean_miss), `ntot' / 100) < 1e-12
}
_rv `=_rc' "R13 datamvp: r(mean_miss) and r(N_mv_total) exact beside a [suppressed] console (stored results are not masked)"

**# Cleanup

macro drop DATAMAP_DQ
capture quietly cd "`qa_dir'"
sysdir set PLUS `"`_old_plus'"'
sysdir set PERSONAL `"`_old_personal'"'
discard
capture mata: mata drop _rv_has() _rv_line() _rv_after()
display as result "Results: $PASS/$TC passed, $FAIL failed"
display "RESULT: test_review_2026_11_17_datamvp_dataqa tests=$TC pass=$PASS fail=$FAIL"
log close main
if $FAIL > 0 exit 1
