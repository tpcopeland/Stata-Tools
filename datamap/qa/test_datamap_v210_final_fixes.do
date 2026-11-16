*! test_datamap_v210_final_fixes.do  2026/11/16
*! datamap 2.1.0 final_fixes review: the unmerged-shard check on a ledger
*! with a worker column but no row of the asserted run (rc 3200 before),
*! and the pooled row of a groupstat() sum beside a mean under the mask
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Oracles are base Stata (count, summarize, use of the ledger and shard
* files) on fixtures built here; dataprobe's own output is never the
* expected value.
*
*   F1a a ledger merged once (it has a worker column), then a run written
*       only to a worker shard: assert exits 9 naming 1 shard and dataqa
*       merge, report warns with rc 0, export refuses (459); the helper
*       counts the shard's rows of the run (use oracle); after merge the
*       worker's failed gate halts assert and no shard is counted
*   F1b the same with a bare relative ledger name
*   F2a groupstat() sum beside mean (one entry, two entries in either by()
*       order, another by(), several variables, safe, the agent preset):
*       the pooled sum (printed, or the sum of the printed group sums) over
*       the pooled mean never gives back a nonmissing count whose missing
*       complement is 1..m-1; the pooled mean reads [suppr.]
*   F2b stat() without by(): a mean beside a groupstat() sum is withheld;
*       a groupstat() mean beside a stat() sum has its pooled mean withheld
*   F2c unchanged: no mask; a variable without missing values; a mean over
*       another if; a stat() mean with no groupstat() sum
version 16.0
clear all
set more off
set linesize 255
capture log close _all
log using "test_datamap_v210_final_fixes.log", replace text name(main)
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
* restored before the RESULT line so a runner's install sandbox stays in force
local _old_plus : sysdir PLUS
local _old_personal : sysdir PERSONAL
tempfile base
local W "`base'_v210ff"
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
capture program drop _ff
program define _ff
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

* _ff_cap file : cmd   runs cmd (captured) with its output in a text log;
* the rc is left in the caller's local _ff_rc and the command's r() is
* passed through
capture program drop _ff_cap
program define _ff_cap, rclass
    gettoken f 0 : 0
    gettoken colon 0 : 0
    capture log close _ffc
    quietly log using `"`f'"', replace text name(_ffc)
    capture noisily `macval(0)'
    local rc = _rc
    return add
    quietly log close _ffc
    c_local _ff_rc `rc'
end

capture mata: mata drop _ff_has()
capture mata: mata drop _ff_lines()
capture mata: mata drop _ff_tabm()
mata:
real scalar _ff_has(string scalar fn, string scalar needle)
{
	return(strpos(_ff_lines(fn), needle) > 0)
}
// the log's lines joined, Stata's "> " continuation removed
string scalar _ff_lines(string scalar fn)
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
// the rows of the k-th table whose title line starts with title: the group
// rows in _r1.._r<_nr> and the pooled row in _rp ("" when none)
void _ff_tabm(string scalar f, string scalar title, real scalar k)
{
	string colvector L
	real scalar i, seen, n, on
	L = cat(f)
	seen = 0
	n = 0
	on = 0
	st_local("_rp", "")
	for (i = 1; i <= rows(L); i++) {
		if (strpos(L[i], title) == 1) {
			seen++
			on = (seen == k)
			continue
		}
		if (!on) continue
		if (strpos(strtrim(L[i]), "Group") == 1) continue
		if (strpos(strtrim(L[i]), "pooled") == 1) {
			st_local("_rp", strtrim(L[i]))
			on = 0
			continue
		}
		if (strtrim(L[i]) == "" | substr(L[i], 1, 2) != "  ") {
			on = 0
			continue
		}
		n++
		st_local("_r" + strofreal(n), strtrim(L[i]))
	}
	st_local("_nr", strofreal(n))
}
end

* _ff_tab file title k   the k-th table of title: r(nr), r(r#), r(rp)
capture program drop _ff_tab
program define _ff_tab, rclass
    args f title k
    mata: _ff_tabm(st_local("f"), st_local("title"), strtoreal(st_local("k")))
    return scalar nr = `_nr'
    forvalues i = 1/`_nr' {
        return local r`i' `"`_r`i''"'
    }
    return local rp `"`_rp'"'
end

* _ff_pair  the pooled sum and pooled mean of one variable as printed:
*   fs ts ks cs nbs  file, title, occurrence, column, by() width of the sum
*   fm tm km cm      the same for the mean table (column cm)
*   N miss m         rows, missing count of the variable (oracles), mask
* The pooled sum is the printed pooled cell or, when that is withheld, the
* sum of the printed group cells (when every one prints).  The pair must
* not give back a nonmissing count whose missing complement is 1..m-1.
* Returns r(ps) r(pm), the pooled cells as printed.
capture program drop _ff_pair
program define _ff_pair, rclass
    args fs ts ks cs nbs fm tm km cm N miss m
    _ff_tab "`fs'" "`ts'" `ks'
    assert r(nr) > 0 & `"`r(rp)'"' != ""
    local ps : word `=1 + `cs'' of `r(rp)'
    local S = real("`ps'")
    if missing(`S') {
        local S = 0
        forvalues i = 1/`r(nr)' {
            local c : word `=`nbs' + `cs'' of `r(r`i')'
            local S = `S' + real("`c'")
        }
    }
    _ff_tab "`fm'" "`tm'" `km'
    assert `"`r(rp)'"' != ""
    local pm : word `=1 + `cm'' of `r(rp)'
    local M = real("`pm'")
    if !missing(`S') & !missing(`M') & `M' != 0 {
        local nhat = round(`S' / `M')
        assert !(`N' - `nhat' >= 1 & `N' - `nhat' < `m')
    }
    return local ps "`ps'"
    return local pm "`pm'"
end

* the S3 pooled-row fixture (600 rows): dz missing in rows 7, 8, 9 (group
* 1), sum 0 there; dx without missing values
capture program drop _ff_st
program define _ff_st
    clear
    quietly set obs 600
    quietly generate byte g = ceil(_n/100)
    quietly generate byte h = mod(_n, 2)
    quietly generate byte dx = 0
    quietly replace dx = 1 if inrange(_n, 201, 240) | inrange(_n, 401, 450)
    quietly generate byte dy = dx
    quietly replace dy = . if mod(_n, 50) == 0
    quietly generate byte dz = dx
    quietly replace dz = . if inlist(_n, 7, 8, 9)
end

* the F1 fixture: run r1 merged (the ledger gets a worker column), then run
* r2 written only by worker w1 (a failing expectn gate)
capture program drop _ff_wk
program define _ff_wk
    args L
    local stem = substr("`L'", 1, strlen("`L'") - 4)
    capture erase "`L'"
    capture erase "`stem'.shard-w1.dta"
    sysuse auto, clear
    dataqa set ledger("`L'") run(r1) replace collect
    dataprobe, safe gatesonly isid(make) name(main)
    dataqa set clear
    dataqa set ledger("`L'") run(r1) worker(w1) replace collect
    dataprobe, safe gatesonly isid(make) name(w1)
    dataqa set clear
    dataqa merge, into("`L'")
    dataqa set ledger("`L'") run(r2) worker(w1) collect
    dataprobe, safe gatesonly expectn(5) name(w2bad)
    dataqa set clear
end

**# F1a merged ledger, a new run held only in a worker shard
capture noisily {
    local L "`W'/m2.dta"
    _ff_wk "`L'"
    * oracles: the ledger has a worker column and no row of r2; the shard
    * holds the rows of r2, one of them a failed gate
    use "`L'", clear
    confirm string variable worker
    quietly count if run == "r2"
    assert r(N) == 0
    use "`W'/m2.shard-w1.dta", clear
    quietly count if run == "r2"
    local nr2 = r(N)
    assert `nr2' >= 1
    quietly count if run == "r2" & status == "fail"
    assert r(N) >= 1
    _dataqa_unmerged, file("`L'") run(r2)
    assert r(n_shards) == 1 & r(n_rows) == `nr2' & "`r(workers)'" == "w1"
    * r1 is fully merged: nothing counted
    _dataqa_unmerged, file("`L'") run(r1)
    assert r(n_shards) == 0 & r(n_rows) == 0
    sysuse auto, clear
    local f "`W'/f1a.log"
    dataqa set ledger("`L'") run(r2) collect
    _ff_cap "`f'" : dataqa assert
    assert `_ff_rc' == 9
    assert r(n_unmerged) == 1
    mata: st_local("a", strofreal(_ff_has(st_local("f"), "1 worker shard(s) (worker(s) w1) hold `nr2' row(s) of run r2 not merged into the ledger; fold them in with dataqa merge")))
    assert `a' == 1
    mata: st_local("a", strofreal(_ff_has(st_local("f"), "3200")))
    assert `a' == 0
    _ff_cap "`f'" : dataqa report
    assert `_ff_rc' == 0
    mata: st_local("a", strofreal(_ff_has(st_local("f"), "WARNING: 1 worker shard(s) (worker(s) w1) hold `nr2' row(s) of run r2 not merged")))
    assert `a' == 1
    _ff_cap "`f'" : dataqa export, saving("`W'/f1e.dta") replace
    assert `_ff_rc' == 459
    mata: st_local("a", strofreal(_ff_has(st_local("f"), "dataqa export: refused; 1 worker shard(s)")))
    assert `a' == 1
    capture confirm file "`W'/f1e.dta"
    assert _rc != 0
    dataqa set clear
    * after merge the failed gate halts assert, and nothing is unmerged
    * (the shard was merged once for r1: a second fold takes replace)
    dataqa merge, into("`L'") replace
    use "`L'", clear
    quietly count if run == "r2" & status == "fail"
    assert r(N) >= 1
    sysuse auto, clear
    dataqa set ledger("`L'") run(r2) collect
    _ff_cap "`f'" : dataqa assert
    assert `_ff_rc' == 9
    assert r(n_unmerged) == 0
    mata: st_local("a", strofreal(_ff_has(st_local("f"), "not merged into the ledger")))
    assert `a' == 0
    dataqa set clear
}
local rc = _rc
capture dataqa set clear
macro drop DATAMAP_DQ
_ff `rc' "F1a a merged ledger and a run held only in a worker shard: assert exits 9 naming the shard (no rc 3200), report warns, export refuses; after merge the worker's failure halts assert"

**# F1b the same with a bare relative ledger name
capture noisily {
    capture mkdir "`W'/rel"
    local here "`c(pwd)'"
    quietly cd "`W'/rel"
    _ff_wk "led.dta"
    use "led.shard-w1.dta", clear
    quietly count if run == "r2"
    local nr2 = r(N)
    sysuse auto, clear
    local f "`W'/f1b.log"
    dataqa set ledger("led.dta") run(r2) collect
    _ff_cap "`f'" : dataqa assert
    assert `_ff_rc' == 9
    assert r(n_unmerged) == 1
    mata: st_local("a", strofreal(_ff_has(st_local("f"), "1 worker shard(s) (worker(s) w1) hold `nr2' row(s) of run r2 not merged")))
    assert `a' == 1
    dataqa set clear
    quietly cd "`here'"
}
local rc = _rc
capture quietly cd "`qa_dir'"
capture dataqa set clear
macro drop DATAMAP_DQ
_ff `rc' "F1b a bare relative ledger name: the run held only in a shard is counted, assert exits 9"

**# F2a the pooled row of a sum beside a mean
capture noisily {
    _ff_st
    quietly count if missing(dz)
    local mz = r(N)
    assert `mz' == 3
    local f "`W'/f2a.log"
    local f2 "`W'/f2a2.log"
    * one entry; safe; maskrare
    foreach pre in "maskrare mincell(5)" "safe" {
        _ff_cap "`f'" : dataprobe, `pre' gatesonly groupstat(sum mean: dz, by(g))
        assert `_ff_rc' == 0
        _ff_pair "`f'" "GROUPSTAT sum mean: dz by(g)" 1 1 1 "`f'" "GROUPSTAT sum mean: dz by(g)" 1 2 600 `mz' 5
        assert "`r(pm)'" == "[suppr.]"
    }
    * the agent preset
    dataqa set agent
    _ff_cap "`f'" : dataprobe, gatesonly groupstat(sum mean: dz, by(g))
    assert `_ff_rc' == 0
    _ff_pair "`f'" "GROUPSTAT sum mean: dz by(g)" 1 1 1 "`f'" "GROUPSTAT sum mean: dz by(g)" 1 2 600 `mz' 5
    assert "`r(pm)'" == "[suppr.]"
    dataqa set clear
    * two entries, by() in either order
    _ff_cap "`f'" : dataprobe, maskrare mincell(5) gatesonly groupstat(sum: dz, by(g h) \ mean: dz, by(h g))
    assert `_ff_rc' == 0
    _ff_pair "`f'" "GROUPSTAT sum by(g h)" 1 1 2 "`f'" "GROUPSTAT mean by(h g)" 1 1 600 `mz' 5
    assert "`r(pm)'" == "[suppr.]"
    * a sum over another by(): its pooled row has the same rows
    _ff_cap "`f'" : dataprobe, maskrare mincell(5) gatesonly groupstat(sum: dz, by(h) \ mean: dz, by(g))
    assert `_ff_rc' == 0
    _ff_pair "`f'" "GROUPSTAT sum by(h)" 1 1 1 "`f'" "GROUPSTAT mean by(g)" 1 1 600 `mz' 5
    assert "`r(pm)'" == "[suppr.]"
    * several variables per entry: dz is the third sum column, the second
    * mean column
    _ff_cap "`f'" : dataprobe, maskrare mincell(5) gatesonly groupstat(sum: dy dx dz, by(g) \ mean: dy dz, by(g))
    assert `_ff_rc' == 0
    _ff_pair "`f'" "GROUPSTAT sum by(g)" 1 3 1 "`f'" "GROUPSTAT mean by(g)" 1 2 600 `mz' 5
    assert "`r(pm)'" == "[suppr.]"
    * profile mode (no gatesonly)
    _ff_cap "`f'" : dataprobe, maskrare mincell(5) groupstat(sum mean: dz, by(g))
    assert `_ff_rc' == 0
    _ff_pair "`f'" "GROUPSTAT sum mean: dz by(g)" 1 1 1 "`f'" "GROUPSTAT sum mean: dz by(g)" 1 2 600 `mz' 5
    assert "`r(pm)'" == "[suppr.]"
}
local rc = _rc
capture dataqa set clear
macro drop DATAMAP_DQ
_ff `rc' "F2a groupstat() sum beside mean (one entry, two entries, another by(), several variables, safe, agent, profile): the pooled pair never gives back a nonmissing count whose missing complement is 1..m-1"

**# F2b stat() without by() beside groupstat()
capture noisily {
    _ff_st
    quietly summarize dz, meanonly
    local S = r(sum)
    local f "`W'/f2b.log"
    * a stat() mean beside a groupstat() sum: withheld
    _ff_cap "`f'" : dataprobe, maskrare mincell(5) gatesonly groupstat(sum: dz, by(g)) stat(mean dz 2 3)
    assert `_ff_rc' == 9
    mata: st_local("a", strofreal(_ff_has(st_local("f"), "stat(mean dz): [suppressed], expected [2, 3]")))
    assert `a' == 1
    * the groups' sums give the pooled sum, so the mean is what must go
    _ff_tab "`f'" "GROUPSTAT sum by(g)" 1
    local T = 0
    forvalues i = 1/`r(nr)' {
        local c : word 2 of `r(r`i')'
        local T = `T' + real("`c'")
    }
    assert `T' == `S'
    * a groupstat() mean beside a stat() sum: the pooled mean is withheld
    _ff_cap "`f'" : dataprobe, maskrare mincell(5) gatesonly groupstat(mean: dz, by(g)) stat(sum dz 1000 2000)
    assert `_ff_rc' == 9
    mata: st_local("a", strofreal(_ff_has(st_local("f"), "stat(sum dz): `S', expected [1000, 2000]")))
    assert `a' == 1
    _ff_tab "`f'" "GROUPSTAT mean by(g)" 1
    local pm : word 2 of `r(rp)'
    assert "`pm'" == "[suppr.]"
}
_ff `=_rc' "F2b stat() without by(): a mean beside a groupstat() sum is withheld; a groupstat() mean beside a stat() sum has its pooled mean withheld"

**# F2c unchanged where nothing is linked or nothing is withheld
capture noisily {
    _ff_st
    local f "`W'/f2c.log"
    * no mask: the pooled mean as summarize gives it
    quietly summarize dz
    local ez = strtrim(string(r(mean), "%10.4g"))
    _ff_cap "`f'" : dataprobe, gatesonly groupstat(sum mean: dz, by(g))
    _ff_tab "`f'" "GROUPSTAT sum mean: dz by(g)" 1
    local pm : word 3 of `r(rp)'
    assert "`pm'" == "`ez'"
    * no missing values: the pooled n is shown, so is the pooled mean
    quietly summarize dx
    local ex = strtrim(string(r(mean), "%10.4g"))
    _ff_cap "`f'" : dataprobe, maskrare mincell(5) gatesonly groupstat(sum mean: dx, by(g))
    _ff_tab "`f'" "GROUPSTAT sum mean: dx by(g)" 1
    local pm : word 3 of `r(rp)'
    assert "`pm'" == "`ex'"
    * a mean over another if: not linked to the sum
    quietly summarize dz if h == 1
    local eh = strtrim(string(r(mean), "%10.4g"))
    _ff_cap "`f'" : dataprobe, maskrare mincell(5) gatesonly groupstat(sum: dz, by(g) \ mean: dz, by(g) if h == 1)
    _ff_tab "`f'" "GROUPSTAT mean by(g)" 1
    local pm : word 2 of `r(rp)'
    assert "`pm'" == "`eh'"
    * a stat() mean with no groupstat() sum: not withheld by the link
    _ff_cap "`f'" : dataprobe, maskrare mincell(5) gatesonly stat(mean dz 2 3)
    mata: st_local("a", strofreal(_ff_has(st_local("f"), "stat(mean dz): [suppressed]")))
    assert `a' == 0
}
_ff `=_rc' "F2c unchanged: no mask, a variable without missing values, a mean over another if, a stat() mean with no groupstat() sum"

**# Cleanup

macro drop DATAMAP_DQ
capture quietly cd "`qa_dir'"
sysdir set PLUS `"`_old_plus'"'
sysdir set PERSONAL `"`_old_personal'"'
discard
capture mata: mata drop _ff_has() _ff_lines() _ff_tabm()
display as result "Results: $PASS/$TC passed, $FAIL failed"
display "RESULT: test_datamap_v210_final_fixes tests=$TC pass=$PASS fail=$FAIL"
log close main
if $FAIL > 0 exit 1
