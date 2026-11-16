*! test_datamap_v210_final.do  2026/11/16
*! datamap 2.1.0 final integration review: M1 (topvalues() entry mincell()
*! below the call's mask), M2 (unmerged worker shards and dataqa assert,
*! report, export), S1 (smallcells() margins pattern names under the mask),
*! S3 (two printed statistics that give back a withheld count), S5 (dataqa
*! flow report phase())
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Oracles are base Stata (count, contract, summarize, use of the ledger
* file) on fixtures built here; dataprobe's own output is never the
* expected value.
*
*   M1a safe / maskrare / rare() / agent preset: an entry mincell() below the
*       call's mask is raised to it with a note; the levels listed are those
*       with at least the mask of rows (contract oracle) and no value of a
*       rarer level prints
*   M1b an entry mincell() above the mask, and every entry without the mask,
*       is used as given (no note; rarer levels listed when unmasked)
*   M2a before merge: assert exits 9 naming 2 unmerged shards and dataqa
*       merge; report warns, rc 0; export refuses (459); r(n_unmerged)
*   M2b after merge: no unmerged shard; assert halts on the worker's failed
*       row and its error row; a worker pass of the same gate does not hide
*       a worker failure, before or after the merge
*   M2c a rerun of a merged worker counts again until merge, replace
*   M2d not counted: a shard of another run only, a flow file, a worker
*       session's own assert; counted: a file named as a shard that is not one
*   S1  margins patterns under maskrare / safe print as exposed (single
*       kept); without the mask singletons and pinned are named
*   S3a groupstat(sum mean:) and separate sum / mean entries: no printed
*       pair gives back a nonmissing count whose missing complement is
*       1..m-1 (count oracle); zero sums print 0; unmasked values unchanged
*   S3b stat(sum) beside stat(mean) (with by(), and from groupstat mean):
*       the sum is withheld where the missing count is small; not without
*   S3c groupstat(n pmiss:): no pmiss shown where n is withheld, and the
*       shown groups' rows never fall 1..m-1 short of N
*   S5  dataqa flow report phase(): the flow gate row carries it; else the
*       session phase; else empty; an invalid name is r(198)
version 16.0
clear all
set more off
set linesize 255
capture log close _all
log using "test_datamap_v210_final.log", replace text name(main)
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
* restored before the RESULT line so a runner's install sandbox stays in force
local _old_plus : sysdir PLUS
local _old_personal : sysdir PERSONAL
tempfile base
local W "`base'_v210fin"
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

* _fn_cap file : cmd   runs cmd (captured) with its output in a text log;
* the rc is left in the caller's local _fn_rc and the command's r() is
* passed through
capture program drop _fn_cap
program define _fn_cap, rclass
    gettoken f 0 : 0
    gettoken colon 0 : 0
    capture log close _fnc
    quietly log using `"`f'"', replace text name(_fnc)
    capture noisily `macval(0)'
    local rc = _rc
    return add
    quietly log close _fnc
    c_local _fn_rc `rc'
end

capture mata: mata drop _fn_has()
capture mata: mata drop _fn_lines()
mata:
// 1 when the log file fn holds the text needle (lines joined; Stata's
// log wrap continuation "> " removed)
real scalar _fn_has(string scalar fn, string scalar needle)
{
	return(strpos(_fn_lines(fn), needle) > 0)
}
string scalar _fn_lines(string scalar fn)
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
end

* the M1 fixture: v aaa 100, bbb 3, ccc 2, ddd 1, blank 4 (110 rows)
capture program drop _fn_tv
program define _fn_tv
    clear
    quietly set obs 110
    quietly generate str3 v = "aaa" in 1/100
    quietly replace v = "bbb" in 101/103
    quietly replace v = "ccc" in 104/105
    quietly replace v = "ddd" in 106
    quietly generate long pid = _n
end

* levels of v with at least m rows (contract oracle)
capture program drop _fn_nlev
program define _fn_nlev, rclass
    args m
    preserve
    contract v, freq(_f)
    quietly count if _f >= `m'
    return scalar n = r(N)
    restore
end

**# M1a the call's mask is a floor for an entry mincell()
capture noisily {
    _fn_tv
    _fn_nlev 5
    local n5 = r(n)
    _fn_nlev 2
    local n2 = r(n)
    _fn_nlev 7
    local n7 = r(n)
    assert `n5' == 1 & `n2' == 4 & `n7' == 1
    local f "`W'/m1a.log"
    * safe
    _fn_cap "`f'" : dataprobe, safe topvalues(v, mincell(2))
    assert `_fn_rc' == 0
    assert el(r(topvalues), 1, 4) == `n5'
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "note: safe raises topvalues() mincell(2) to 5")))
    assert `a' == 1
    foreach bad in "bbb" "ccc" "ddd" "(blank)" "listed: 2 or more" {
        mata: st_local("a", strofreal(_fn_has(st_local("f"), st_local("bad"))))
        assert `a' == 0
    }
    * safe with mincell(1): raised, no longer r(198)
    _fn_cap "`f'" : dataprobe, safe topvalues(v, mincell(1))
    assert `_fn_rc' == 0
    assert el(r(topvalues), 1, 4) == `n5'
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "note: safe raises topvalues() mincell(1) to 5")))
    assert `a' == 1
    * maskrare mincell(5)
    _fn_cap "`f'" : dataprobe, maskrare mincell(5) topvalues(v, mincell(2))
    assert `_fn_rc' == 0
    assert el(r(topvalues), 1, 4) == `n5'
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "note: maskrare raises topvalues() mincell(2) to 5")))
    assert `a' == 1
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "bbb")))
    assert `a' == 0
    * maskrare with rare(7) and no mincell(): the mask is 7
    _fn_cap "`f'" : dataprobe, maskrare rare(7) topvalues(v, mincell(3))
    assert `_fn_rc' == 0
    assert el(r(topvalues), 1, 4) == `n7'
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "note: maskrare raises topvalues() mincell(3) to 7")))
    assert `a' == 1
    * session maskrare (dataqa set) and the agent preset
    dataqa set maskrare mincell(5)
    _fn_cap "`f'" : dataprobe, topvalues(v, mincell(2))
    assert `_fn_rc' == 0
    assert el(r(topvalues), 1, 4) == `n5'
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "bbb")))
    assert `a' == 0
    dataqa set clear
    dataqa set agent
    _fn_cap "`f'" : dataprobe, topvalues(v, mincell(2))
    assert `_fn_rc' == 0
    assert el(r(topvalues), 1, 4) == `n5'
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "note: safe raises topvalues() mincell(2) to 5")))
    assert `a' == 1
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "bbb")))
    assert `a' == 0
    dataqa set clear
}
local rc = _rc
capture dataqa set clear
macro drop DATAMAP_DQ
_ft `rc' "M1a safe, maskrare mincell(), maskrare rare(), the dataqa set mask and the agent preset raise an entry mincell() to the call's mask, with a note; no rarer level prints"

**# M1b used as given above the mask, and without it
capture noisily {
    _fn_tv
    _fn_nlev 8
    local n8 = r(n)
    _fn_nlev 2
    local n2 = r(n)
    local f "`W'/m1b.log"
    _fn_cap "`f'" : dataprobe, maskrare mincell(5) topvalues(v, mincell(8))
    assert `_fn_rc' == 0
    assert el(r(topvalues), 1, 4) == `n8'
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "raises topvalues()")))
    assert `a' == 0
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "listed: 8 or more rows")))
    assert `a' == 1
    * no mask: the entry's threshold, rarer levels listed
    _fn_cap "`f'" : dataprobe, mincell(5) topvalues(v, mincell(2))
    assert `_fn_rc' == 0
    * 4 levels reach 2 rows; the pool holds ddd alone (one level), and a
    * pool needs two levels, so the smallest listed level (ccc) joins it
    assert el(r(topvalues), 1, 4) == `n2' - 1
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "raises topvalues()")))
    assert `a' == 0
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "bbb")))
    assert `a' == 1
    * no mask, mincell(1): still r(198)
    capture noisily dataprobe, topvalues(v, mincell(1))
    assert _rc == 198
}
_ft `=_rc' "M1b an entry mincell() above the mask, and any entry mincell() without the mask, is used as given (no note)"

**# M2 fixture: a passing main session, w1 failing (collect), w2 error row
capture program drop _fn_wk
program define _fn_wk
    args L
    local stem = substr("`L'", 1, strlen("`L'") - 4)
    capture erase "`L'"
    foreach x in w1 w2 w3 {
        capture erase "`stem'.shard-`x'.dta"
        capture erase "`stem'.shard-`x'.flow.dta"
    }
    sysuse auto, clear
    dataqa set ledger("`L'") run(r1) replace
    dataprobe, gatesonly isid(make) name(cars)
    dataqa set clear
    dataqa set ledger("`L'") run(r1) worker(w1) collect replace
    dataprobe, gatesonly expectn(5) name(cars2)
    * the same gate as w2 below: w1 fails it
    dataprobe, gatesonly expectn(5) name(both)
    dataqa set clear
    dataqa set ledger("`L'") run(r1) worker(w2) replace
    dataprobe, gatesonly notmissing(nosuchvar) name(cars3) softcollect
    dataprobe, gatesonly expectn(74) name(both)
    dataqa set clear
end

**# M2a before merge
capture noisily {
    local L "`W'/wk.dta"
    _fn_wk "`L'"
    * the oracle: the shards exist and hold rows of r1; the ledger has none
    * of their workers
    use "`W'/wk.shard-w1.dta", clear
    quietly count if run == "r1"
    assert r(N) == 2
    use "`W'/wk.shard-w2.dta", clear
    quietly count if run == "r1"
    assert r(N) == 2
    use "`L'", clear
    assert _N == 1 & status[1] == "pass"
    sysuse auto, clear
    local f "`W'/m2a.log"
    dataqa set ledger("`L'") run(r1)
    _fn_cap "`f'" : dataqa assert
    assert `_fn_rc' == 9
    assert r(n_unmerged) == 2
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "2 worker shard(s) (worker(s) w1 w2) hold 4 row(s) of run r1 not merged into the ledger; fold them in with dataqa merge")))
    assert `a' == 1
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "every invariant passed")))
    assert `a' == 0
    * phase() selection does not hide them
    capture noisily dataqa assert, phase(zzz)
    assert _rc == 9
    _fn_cap "`f'" : dataqa report
    assert `_fn_rc' == 0
    assert r(n_unmerged) == 2
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "WARNING: 2 worker shard(s) (worker(s) w1 w2) hold 4 row(s) of run r1 not merged")))
    assert `a' == 1
    _fn_cap "`f'" : dataqa export, saving("`W'/exp.dta") replace
    assert `_fn_rc' == 459
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "dataqa export: refused; 2 worker shard(s)")))
    assert `a' == 1
    capture confirm file "`W'/exp.dta"
    assert _rc != 0
    dataqa set clear
    * assert using the ledger, outside any session, sees them as well
    capture noisily dataqa assert using "`L'", run(r1)
    assert _rc == 9 & r(n_unmerged) == 2
}
local rc = _rc
capture dataqa set clear
macro drop DATAMAP_DQ
_ft `rc' "M2a before dataqa merge: assert exits 9 naming 2 unmerged shards (any phase), report warns with rc 0, export refuses (459)"

**# M2b after merge
capture noisily {
    local L "`W'/wk.dta"
    dataqa merge, into("`L'")
    local f "`W'/m2b.log"
    _fn_cap "`f'" : dataqa assert using "`L'", run(r1)
    assert `_fn_rc' == 9
    assert r(n_unmerged) == 0
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "not merged")))
    assert `a' == 0
    * the oracle: the ledger rows of the workers
    use "`L'", clear
    quietly count if worker == "w1" & dataset == "both" & status == "fail"
    assert r(N) == 1
    quietly count if worker == "w2" & dataset == "both" & status == "pass"
    assert r(N) == 1
    * the w1 failure of "both" is listed though w2 passed the same gate,
    * and so are cars2 and the w2 error row
    foreach t in "both: expectn" "cars2: expectn" "cars3: call error" {
        mata: st_local("a", strofreal(_fn_has(st_local("f"), st_local("t"))))
        assert `a' == 1
    }
    _fn_cap "`f'" : dataqa report using "`L'", run(r1)
    assert `_fn_rc' == 0 & r(n_unmerged) == 0
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "WARNING")))
    assert `a' == 0
}
_ft `=_rc' "M2b after dataqa merge: no unmerged shard is counted; assert halts on the worker failure that another worker's pass of the same gate does not hide"

**# M2c a merged worker reruns: counted again until merge, replace
capture noisily {
    local L "`W'/wk.dta"
    sysuse auto, clear
    dataqa set ledger("`L'") run(r1) worker(w1) collect replace
    dataprobe, gatesonly expectn(74) name(cars2)
    dataprobe, gatesonly expectn(74) name(both)
    dataqa set clear
    capture noisily dataqa assert using "`L'", run(r1)
    assert _rc == 9 & r(n_unmerged) == 1
    capture noisily dataqa merge, into("`L'")
    assert _rc == 459
    dataqa merge, into("`L'") replace
    capture noisily dataqa assert using "`L'", run(r1)
    * the w2 error row still halts; nothing is unmerged
    assert _rc == 9 & r(n_unmerged) == 0 & r(n_errors) == 1
}
_ft `=_rc' "M2c a rerun of a merged worker counts as unmerged until dataqa merge, replace folds it in"

**# M2d what is and is not counted
capture noisily {
    local L "`W'/wk4.dta"
    local stem "`W'/wk4"
    foreach x in w1 w2 w3 {
        capture erase "`stem'.shard-`x'.dta"
    }
    capture erase "`L'"
    sysuse auto, clear
    dataqa set ledger("`L'") run(r1) replace
    dataprobe, gatesonly isid(make) name(cars)
    dataqa set clear
    * a shard of another run only
    dataqa set ledger("`L'") run(r9) worker(w1) replace
    dataprobe, gatesonly expectn(5) name(other) warn
    * a worker session's own assert reads its shard as designed
    capture noisily dataqa assert
    assert r(n_unmerged) == 0
    dataqa set clear
    capture noisily dataqa assert using "`L'", run(r1)
    assert _rc == 0 & r(n_unmerged) == 0
    * a flow file of a worker is not a shard
    dataqa set ledger("`L'") run(r1) worker(w2) replace
    dataqa flow step all
    dataqa set clear
    capture confirm file "`stem'.shard-w2.flow.dta"
    assert _rc == 0
    capture noisily dataqa assert using "`L'", run(r1)
    assert _rc == 0 & r(n_unmerged) == 0
    * a file named as a shard that is not one: counted (fail closed)
    preserve
    clear
    quietly set obs 1
    generate x = 1
    quietly save "`stem'.shard-w3.dta", replace
    restore
    capture noisily dataqa assert using "`L'", run(r1)
    assert _rc == 9 & r(n_unmerged) == 1
    erase "`stem'.shard-w3.dta"
    capture noisily dataqa assert using "`L'", run(r1)
    assert _rc == 0 & r(n_unmerged) == 0
}
local rc = _rc
capture dataqa set clear
macro drop DATAMAP_DQ
_ft `rc' "M2d not counted: a shard of another run, a flow file, a worker's own assert; counted: a file named as a shard that cannot be read as one"

**# S1 margins pattern names under the mask
* c: 1 on 40 rows; 2 and 3 on one row each (singletons beside a total);
* d: 1 on 40, 2 and 3 on 4 rows each with m=5 (sum 8 = 2 x (m-1): pinned)
capture noisily {
    clear
    quietly set obs 42
    generate byte c = cond(_n <= 40, 1, cond(_n == 41, 2, 3))
    local L "`W'/s1.dta"
    local E "expected no small cell recoverable from a margin (m=5)"
    capture erase "`L'"
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2 c==3, margins) ledger("`L'")
    capture noisily dataprobe, gatesonly maskrare mincell(5) smallcells(c==1 c==2 c==3, margins) ledger("`L'")
    capture noisily dataprobe, gatesonly safe smallcells(c==1 c==2 c==3, margins) ledger("`L'")
    clear
    quietly set obs 48
    generate byte c = cond(_n <= 40, 1, cond(_n <= 44, 2, 3))
    capture noisily dataprobe, gatesonly mincell(5) smallcells(c==1 c==2 c==3, margins) ledger("`L'")
    capture noisily dataprobe, gatesonly maskrare mincell(5) smallcells(c==1 c==2 c==3, margins) ledger("`L'")
    * one small cell: single, under the mask too
    clear
    quietly set obs 42
    generate byte c = cond(_n <= 40, 1, 2)
    capture noisily dataprobe, gatesonly maskrare mincell(5) smallcells(c==1 c==2, margins) ledger("`L'")
    use "`L'", clear
    keep if strpos(label, "[margins]")
    assert _N == 6
    assert message[1] == "smallcells(c==1 c==2 c==3, margins) margins: 1 exposed, total: singletons (c==2, c==3); `E'"
    assert message[2] == "smallcells(c==1 c==2 c==3, margins) margins: <5 exposed, total: exposed (c==2, c==3); `E'"
    assert message[3] == "smallcells(c==1 c==2 c==3, margins) margins: <5 exposed, total: exposed (c==2, c==3); `E'"
    assert message[4] == "smallcells(c==1 c==2 c==3, margins) margins: 1 exposed, total: pinned (c==2, c==3); `E'"
    assert message[5] == "smallcells(c==1 c==2 c==3, margins) margins: <5 exposed, total: exposed (c==2, c==3); `E'"
    assert message[6] == "smallcells(c==1 c==2, margins) margins: <5 exposed, total: single (c==2); `E'"
    forvalues i = 2/6 {
        if `i' == 4 continue
        assert strpos(message[`i'], "singletons") == 0 & strpos(message[`i'], "pinned") == 0
    }
}
_ft `=_rc' "S1 under maskrare and safe the margins patterns singletons and pinned print as exposed (single kept); without the mask they are named"

**# S3 fixture: 6 groups of 100 and one of 3; dy has 2 missing per group
capture program drop _fn_st
program define _fn_st
    clear
    quietly set obs 603
    quietly generate byte g = ceil(_n/100)
    quietly replace g = 7 in 601/603
    quietly generate byte dx = 0
    quietly replace dx = 1 if inrange(_n, 201, 240) | inrange(_n, 401, 450)
    quietly generate byte dy = dx
    quietly replace dy = . if mod(_n, 50) == 0
    set seed 20261116
    quietly generate double z = runiform()
    quietly replace z = . if mod(_n, 10) == 0
end

* _fn_rows file title k: the k-th table titled title in the log, as rows of
* cells in locals r#_c# (row 1 the first group), r(nr) rows
capture program drop _fn_tab
program define _fn_tab, rclass
    args f title k
    mata: _fn_tabm(st_local("f"), st_local("title"), strtoreal(st_local("k")))
    return scalar nr = `_nr'
    forvalues i = 1/`_nr' {
        return local r`i' `"`_r`i''"'
    }
end
capture mata: mata drop _fn_tabm()
mata:
void _fn_tabm(string scalar f, string scalar title, real scalar k)
{
	string colvector L
	real scalar i, seen, n, on
	L = cat(f)
	seen = 0
	n = 0
	on = 0
	for (i = 1; i <= rows(L); i++) {
		if (strpos(L[i], title) == 1) {
			seen++
			on = (seen == k)
			continue
		}
		if (!on) continue
		if (strpos(strtrim(L[i]), "Group") == 1) continue
		if (strpos(strtrim(L[i]), "pooled") == 1 | strtrim(L[i]) == "") {
			on = 0
			continue
		}
		n++
		st_local("_r" + strofreal(n), strtrim(L[i]))
	}
	st_local("_nr", strofreal(n))
}
end

**# S3a groupstat sum and mean
capture noisily {
    _fn_st
    * oracle: per group, missing dy and nonmissing count
    forvalues k = 1/6 {
        quietly count if g == `k' & missing(dy)
        local miss`k' = r(N)
        quietly count if g == `k'
        local N`k' = r(N)
        quietly summarize dy if g == `k', meanonly
        local sum`k' = r(sum)
        assert `miss`k'' == 2
    }
    local f "`W'/s3a.log"
    foreach spec in "sum mean: dy, by(g)" "sum: dy, by(g) \ mean: dy, by(g)" {
        _fn_cap "`f'" : dataprobe, maskrare mincell(5) gatesonly groupstat(`spec')
        assert `_fn_rc' == 0
        if strpos("`spec'", "\") {
            _fn_tab "`f'" "GROUPSTAT sum by(g)" 1
            local ns = r(nr)
            forvalues i = 1/`ns' {
                local s`i' : word 2 of `r(r`i')'
            }
            _fn_tab "`f'" "GROUPSTAT mean by(g)" 1
            forvalues i = 1/`ns' {
                local m`i' : word 2 of `r(r`i')'
            }
        }
        else {
            _fn_tab "`f'" "GROUPSTAT sum mean: dy by(g)" 1
            local ns = r(nr)
            forvalues i = 1/`ns' {
                local s`i' : word 2 of `r(r`i')'
                local m`i' : word 3 of `r(r`i')'
            }
        }
        assert `ns' == 6
        forvalues k = 1/6 {
            * no printed pair gives back the nonmissing count (its missing
            * complement, 2, is withheld by the n rule)
            if real("`s`k''") < . & real("`m`k''") < . & real("`m`k''") != 0 {
                local nhat = round(real("`s`k''") / real("`m`k''"))
                assert !(`N`k'' - `nhat' >= 1 & `N`k'' - `nhat' < 5)
            }
            * a zero sum prints 0; a nonzero one is withheld here
            if `sum`k'' == 0 assert "`s`k''" == "0"
            else assert "`s`k''" == "[suppr.]"
            * the mean is not withheld by the link
            if `sum`k'' > 0 assert real("`m`k''") < .
        }
    }
    * without the mask the values print as before
    _fn_cap "`f'" : dataprobe, gatesonly groupstat(sum mean: dy, by(g))
    _fn_tab "`f'" "GROUPSTAT sum mean: dy by(g)" 1
    forvalues k = 1/6 {
        local s : word 2 of `r(r`k')'
        assert real("`s'") == `sum`k''
    }
    * a sum alone (no mean of dy over these groups) is not linked
    _fn_cap "`f'" : dataprobe, maskrare mincell(5) gatesonly groupstat(sum: dy, by(g) \ mean: dy, by(g) if z < .)
    _fn_tab "`f'" "GROUPSTAT sum by(g)" 1
    local s : word 2 of `r(r3)'
    assert real("`s'") == `sum3'
}
_ft `=_rc' "S3a groupstat(): a sum beside a mean of the same variable and groups (one entry or two) never gives back a nonmissing count whose missing complement is 1..m-1; zero sums and unmasked values unchanged"

**# S3b stat() sum beside a mean
capture noisily {
    _fn_st
    quietly summarize dy if g == 3, meanonly
    local sum3 = r(sum)
    quietly summarize dy, meanonly
    local sumall = r(sum)
    quietly count if missing(dy)
    assert r(N) >= 5
    local f "`W'/s3b.log"
    _fn_cap "`f'" : dataprobe, maskrare mincell(5) gatesonly by(g) stat(sum dy 0 10 \ mean dy 0 0.1)
    assert `_fn_rc' == 9
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "by(g | g=3): stat(sum dy): [suppressed]")))
    assert `a' == 1
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "stat(sum dy): `sum3'")))
    assert `a' == 0
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "by(g | g=3): stat(mean dy): .4")))
    assert `a' == 1
    * the mean from groupstat() over the call's by()
    _fn_cap "`f'" : dataprobe, maskrare mincell(5) gatesonly by(g) stat(sum dy 0 10) groupstat(mean dy, by(g))
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "by(g | g=3): stat(sum dy): [suppressed]")))
    assert `a' == 1
    * no by(): the missing count (12) is not small, the sum prints
    _fn_cap "`f'" : dataprobe, maskrare mincell(5) gatesonly stat(sum dy 0 10 \ mean dy 0 0.1)
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "stat(sum dy): `sumall', expected")))
    assert `a' == 1
    * no mean: the sum prints
    _fn_cap "`f'" : dataprobe, maskrare mincell(5) gatesonly by(g) stat(sum dy 0 10)
    mata: st_local("a", strofreal(_fn_has(st_local("f"), "by(g | g=3): stat(sum dy): `sum3', expected")))
    assert `a' == 1
}
_ft `=_rc' "S3b stat(sum) beside a mean of the same variable and scope (stat() or groupstat() over the call's by()) is withheld where the missing count is 1..m-1; it prints otherwise"

**# S3c groupstat n and pmiss
capture noisily {
    _fn_st
    local f "`W'/s3c.log"
    _fn_cap "`f'" : dataprobe, maskrare mincell(5) gatesonly groupstat(n pmiss: z, by(g))
    assert `_fn_rc' == 0
    _fn_tab "`f'" "GROUPSTAT n pmiss: z by(g)" 1
    local nr = r(nr)
    local Nsh = 0
    forvalues i = 1/`nr' {
        local row `"`r(r`i')'"'
        local gl : word 1 of `row'
        local nn : word 2 of `row'
        local pm : word 3 of `row'
        * a pmiss never shows beside a withheld n
        if real("`nn'") >= . assert real("`pm'") >= .
        if real("`nn'") < . & real("`pm'") < . {
            quietly count if g == `gl'
            local Nsh = `Nsh' + r(N)
        }
    }
    * the rows of the groups whose n and pmiss both show (n / (1 - pmiss))
    * never fall 1..4 short of N or of the rows with a group
    quietly count
    local N = r(N)
    assert !(`N' - `Nsh' >= 1 & `N' - `Nsh' < 5)
    * pmiss alone is not linked (as documented): group 1's share prints
    _fn_cap "`f'" : dataprobe, maskrare mincell(5) gatesonly groupstat(pmiss: z, by(g))
    _fn_tab "`f'" "GROUPSTAT pmiss by(g)" 1
    local pm : word 2 of `r(r1)'
    quietly count if g == 1 & missing(z)
    local m1 = r(N)
    assert reldif(real("`pm'"), `m1' / 100) < 1e-4
}
_ft `=_rc' "S3c groupstat(n pmiss:): no pmiss beside a withheld n, and the shown groups' rows never fall 1..m-1 short of N"

**# S5 dataqa flow report phase()
capture noisily {
    local L "`W'/fl.dta"
    capture erase "`L'"
    capture erase "`W'/fl.flow.dta"
    sysuse auto, clear
    dataqa set ledger("`L'") run(f1) replace
    dataqa flow step all
    quietly keep if foreign == 0
    dataqa flow step domestic
    dataqa flow report, phase(build)
    dataqa set ledger("`L'") run(f1) phase(analysis)
    dataqa flow report
    dataqa set clear
    dataqa set ledger("`L'") run(f1)
    dataqa flow report
    capture noisily dataqa flow report, phase(1bad)
    assert _rc == 198
    dataqa set clear
    use "`L'", clear
    keep if family == "flow"
    assert _N == 3
    assert phase[1] == "build" & phase[2] == "analysis" & phase[3] == ""
    assert status[1] == "pass"
}
local rc = _rc
capture dataqa set clear
macro drop DATAMAP_DQ
_ft `rc' "S5 dataqa flow report phase() tags the flow gate row; else the session phase; else none; an invalid name is r(198)"

**# Cleanup

macro drop DATAMAP_DQ
sysdir set PLUS `"`_old_plus'"'
sysdir set PERSONAL `"`_old_personal'"'
discard
capture mata: mata drop _fn_has() _fn_lines() _fn_tabm()
display as result "Results: $PASS/$TC passed, $FAIL failed"
display "RESULT: test_datamap_v210_final tests=$TC pass=$PASS fail=$FAIL"
log close main
if $FAIL > 0 exit 1
