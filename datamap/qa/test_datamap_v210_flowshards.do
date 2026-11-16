*! test_datamap_v210_flowshards.do  2026/11/15
*! datamap 2.1.0 F10 (dataqa flow: attrition steps under the mask) and F12
*! (dataqa set worker() shards and dataqa merge)
*! Author: Timothy P Copeland, Karolinska Institutet
*
*   F1  hand-built flows: every protected table cell, both layouts, against
*       values worked out by hand from the rule in dataqa.sthlp
*   F2  privacy property: an independent brute-force reader enumerates every
*       flow consistent with the printed numbers; every withheld number must
*       take two or more values, every printed number is 0 or >= mincell, so
*       is every difference of two printed remaining counts, and the true
*       flow is among the candidates (exhaustive small flows, direct call)
*   F3  end to end on seeded random flows: r(table) equals the rule, the
*       reader finds no recoverable value, printed numbers equal the counts
*   F4  conservation: a step that adds rows fails the gate, prints no count,
*       writes a failed flow row, assert halts; collect returns 0; a fixed
*       rerun supersedes it; rows and ids are both checked whatever count()
*       prints (rows rising under ids fails)
*   F5  steps: ids vs rows, rerun replaces later steps, clear, string and
*       strL ids, missing ids, empty data, one step, the data untouched;
*       dataqa set replace clears the run's flows; clear, all; agent note
*   F6  integrity and option errors (mincell 1/2, agent, count(), paths,
*       no ledger, no flow file, no steps, edited flow file)
*   F7  hostile label text prints and exports literally; .md/.csv export
*   W1  dataqa set worker()/sharddir() validation and r(shard)
*   W2  a worker session writes the shard, never the ledger; schema
*   W3  merge: order, seq renumbering, report/assert after merge, double
*       merge refused, replace, 2.0.0 target, schema/duplicate refusals,
*       the target untouched after a refusal; one worker's failure is not
*       superseded by another worker's pass (gates and flows); file-name id
*       must match the worker column; run() filter and per-shard run list
*   W4  four concurrent Stata workers write shards at once; the merge
*       equals the union of what each wrote and an independent sequential
*       reference run
version 16.0
clear all
set more off
set linesize 255
capture log close _all
log using "test_datamap_v210_flowshards.log", replace text name(main)
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
* restored before the RESULT line so a runner's install sandbox stays in force
local _old_plus : sysdir PLUS
local _old_personal : sysdir PERSONAL
tempfile base
local W "`base'_v210fs"
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

* _fl_make "N1 N2 ...", flow() [ledger() id(2) label()]: data of N1 rows (with
* id(2), two rows per id: the remaining counts are then ids), then each
* count kept in turn and recorded as step s1, s2, ...
capture program drop _fl_make
program define _fl_make
    syntax anything(name=counts), FLOW(name) [LEDger(string) ID(integer 0) RUN(string)]
    local lo ""
    if `"`ledger'"' != "" local lo `"ledger(`"`ledger'"')"'
    local ro ""
    if `"`run'"' != "" local ro "run(`run')"
    clear
    local k = 0
    foreach c of local counts {
        local ++k
        if `k' == 1 {
            if `id' quietly set obs `=2 * `c''
            else quietly set obs `c'
            quietly generate long pid = ceil(_n / cond(`id', 2, 1))
        }
        else quietly keep if pid <= `c'
        if `id' quietly dataqa flow step s`k', flow(`flow') id(pid) `lo' `ro'
        else quietly dataqa flow step s`k', flow(`flow') `lo' `ro'
    }
end

* _fl_cap file cmd: run cmd with its output logged to file; _rc in caller
capture program drop _fl_cap
program define _fl_cap
    gettoken f 0 : 0
    capture log close _flc
    quietly log using `"`f'"', replace text name(_flc)
    capture noisily `macval(0)'
    local rc = _rc
    capture log close _flc
    c_local _rc `rc'
end

capture mata: mata drop _ft_fread() _ft_has() _ft_dfs() _ft_reader() _ft_props() _ft_exhaust() _ft_selftest()
mata:
string scalar _ft_fread(string scalar f)
{
	real scalar fh
	string scalar s, l
	fh = fopen(f, "r")
	s = ""
	while ((l = fget(fh)) != J(0, 0, "")) s = s + l + char(10)
	fclose(fh)
	return(s)
}
real scalar _ft_has(string scalar f, string scalar t)
{
	return(strpos(_ft_fread(f), t) > 0)
}
// Independent reader.  T: rows (first, last, remaining, excluded) as the
// report prints them, .m = withheld (no range is printed).  Enumerates every
// non-increasing nonnegative integer flow N[1..S] (N[1] <= cap) that agrees
// with every printed number; lo/hi: each cell's least and largest value
// over the candidates (cells 2r-1 remaining, 2r excluded).
void _ft_dfs(real scalar i, real colvector N, real matrix T, real scalar cap,
	real colvector rend, real colvector lo, real colvector hi, real scalar nc,
	real scalar S)
{
	real scalar a, b, v, r, f, x
	a = 0
	b = (i == 1 ? cap : N[i - 1])
	r = rend[i]
	if (r) {
		if (T[r, 3] != .m) {
			a = max((a, T[r, 3]))
			b = min((b, T[r, 3]))
		}
		f = T[r, 1]
		if (r > 1 & T[r, 4] != .m) {
			x = N[f - 1] - T[r, 4]
			a = max((a, x))
			b = min((b, x))
		}
	}
	for (v = a; v <= b; v++) {
		N[i] = v
		if (i < S) _ft_dfs(i + 1, N, T, cap, rend, lo, hi, nc, S)
		else {
			nc++
			for (r = 1; r <= rows(T); r++) {
				x = N[T[r, 2]]
				if (x < lo[2 * r - 1]) lo[2 * r - 1] = x
				if (x > hi[2 * r - 1]) hi[2 * r - 1] = x
				if (r > 1) {
					x = N[T[r, 1] - 1] - N[T[r, 2]]
					if (x < lo[2 * r]) lo[2 * r] = x
					if (x > hi[2 * r]) hi[2 * r] = x
				}
			}
		}
	}
}
// number of withheld cells the printed numbers determine (0 = safe), or -1
// when the true flow is not a candidate (a printed number is wrong)
real scalar _ft_reader(real matrix T, real colvector truth, real scalar cap)
{
	real colvector N, rend, lo, hi
	real scalar S, r, nc, bad, ok, x
	S = T[rows(T), 2]
	rend = J(S, 1, 0)
	for (r = 1; r <= rows(T); r++) rend[T[r, 2]] = r
	// the truth agrees with every printed number
	ok = 1
	for (r = 1; r <= rows(T); r++) {
		if (T[r, 3] != .m & T[r, 3] != truth[T[r, 2]]) ok = 0
		if (r > 1 & T[r, 4] != .m) {
			if (T[r, 4] != truth[T[r, 1] - 1] - truth[T[r, 2]]) ok = 0
		}
	}
	if (!ok) return(-1)
	N = J(S, 1, 0)
	lo = J(2 * rows(T), 1, .)
	hi = J(2 * rows(T), 1, -1)
	nc = 0
	_ft_dfs(1, N, T, max((cap, truth[1])), rend, lo, hi, nc, S)
	bad = 0
	for (r = 1; r <= rows(T); r++) {
		if (T[r, 3] == .m & !(hi[2 * r - 1] > lo[2 * r - 1])) bad++
		if (r > 1) {
			if (T[r, 4] == .m & !(hi[2 * r] > lo[2 * r])) bad++
		}
	}
	return(bad)
}
// printed-number properties: every printed number 0 or >= m, every
// difference of two printed remaining counts 0 or >= m; returns violations
real scalar _ft_props(real matrix T, real scalar m)
{
	real scalar r, q, v, bad
	real colvector P
	bad = 0
	P = J(0, 1, .)
	for (r = 1; r <= rows(T); r++) {
		v = T[r, 3]
		if (v != .m) {
			if (v > 0 & v < m) bad++
			P = P \ v
		}
		v = T[r, 4]
		if (r > 1 & v != .m) {
			if (v > 0 & v < m) bad++
		}
	}
	for (r = 1; r <= rows(P); r++) {
		for (q = r + 1; q <= rows(P); q++) {
			v = abs(P[r] - P[q])
			if (v > 0 & v < m) bad++
		}
	}
	return(bad)
}
// every non-increasing flow of 2 to 5 steps (N1 <= 16, 16, 12, 9), mincell
// 3 to 5, both layouts, through the reader and the property check
void _ft_exhaust()
{
	real scalar nflows, nleak, nprop, nwrong, S, nmax, i, k, done, m, pool, b
	real colvector N
	real matrix X, T
	nflows = nleak = nprop = nwrong = 0
	for (S = 2; S <= 5; S++) {
		nmax = (S <= 3 ? 16 : (S == 4 ? 12 : 9))
		N = J(S, 1, nmax)
		done = 0
		while (!done) {
			for (m = 3; m <= 5; m++) {
				for (pool = 0; pool <= 1; pool++) {
					X = _dataqa_flowmask(N, m, pool)
					T = X[., 1..4]
					b = _ft_reader(T, N, 12)
					if (b < 0) nwrong++
					else if (b > 0) nleak++
					nprop = nprop + _ft_props(T, m)
				}
			}
			nflows++
			k = S
			while (k >= 1) {
				if (N[k] > 0) break
				k--
			}
			if (k < 1) done = 1
			else {
				N[k] = N[k] - 1
				for (i = k + 1; i <= S; i++) N[i] = N[k]
			}
		}
	}
	printf("F2: %f flows x 3 thresholds x 2 layouts; leaks %f, property violations %f, wrong printed %f\n", nflows, nleak, nprop, nwrong)
	st_local("nflows", strofreal(nflows))
	st_local("nleak", strofreal(nleak))
	st_local("nprop", strofreal(nprop))
	st_local("nwrong", strofreal(nwrong))
}
void _ft_selftest()
{
	real matrix T
	T = (1, 1, 100, . \ 2, 2, 96, .m \ 3, 3, 90, 6)
	assert(_ft_reader(T, (100 \ 96 \ 90), 12) == 1)
	T = (1, 1, 100, . \ 2, 2, 96, 4)
	assert(_ft_props(T, 5) == 2)
	T = (1, 1, 100, . \ 2, 2, 95, .m)
	assert(_ft_reader(T, (100 \ 96), 12) == -1)
}
end

local L "`W'/led.dta"
local LS "`W'/led"
dataqa set maskrare mincell(5) ledger("`L'") run(r1)

**# F1 - hand-built flows, every cell against the rule worked by hand

* each line: counts | expected masking-layout table (rem exc per step, m =
* withheld, . = none) | expected poolsmall table (first last rem exc per row)
local c1 "100 96 90 40"
local m1 "100 . m m 90 m 40 50"
local p1 "1 1 100 . 2 3 90 10 4 4 40 50"
local c2 "50 45 3 1"
local m2 "50 . 45 5 m m m m"
local p2 "1 1 50 . 2 2 45 5 3 4 m m"
local c3 "50 45 3 0"
local m3 "50 . 45 5 m m 0 m"
local p3 "1 1 50 . 2 2 45 5 3 4 0 45"
local c4 "50 48 47"
local m4 "50 . m m m m"
local p4 "1 1 50 . 2 3 m m"
local c5 "4 2 0"
local m5 "m . m m 0 m"
local p5 "1 1 m . 2 3 0 m"
local c6 "0 0 0"
local m6 "0 . 0 0 0 0"
local p6 "1 1 0 . 2 2 0 0 3 3 0 0"
local c7 "20 0 0"
local m7 "20 . 0 20 0 0"
local p7 "1 1 20 . 2 2 0 20 3 3 0 0"
local c8 "100 80 78"
local m8 "100 . m m 78 m"
local p8 "1 1 100 . 2 3 78 22"
local c9 "100 98 98 90 90"
local m9 "100 . m m m m 90 m 90 0"
local p9 "1 1 100 . 2 4 90 10 5 5 90 0"
local c10 "30 29 28 27 26 25"
local m10 "30 . m m m m m m m m 25 m"
local p10 "1 1 30 . 2 6 25 5"
local c11 "200"
local m11 "200 ."
local p11 "1 1 200 ."
forvalues t = 1/11 {
    capture noisily {
        _fl_make `c`t'', flow(h`t')
        quietly dataqa flow report, flow(h`t')
        assert r(status) == "pass" & r(count) == "rows"
        matrix A = r(table)
        local S : word count `c`t''
        assert rowsof(A) == `S'
        local k = 0
        forvalues i = 1/`S' {
            assert A[`i', 1] == `i' & A[`i', 2] == `i'
            local ++k
            local x : word `k' of `m`t''
            if "`x'" == "m" assert A[`i', 3] == .m
            else assert A[`i', 3] == `x'
            local ++k
            local x : word `k' of `m`t''
            if "`x'" == "m" assert A[`i', 4] == .m
            else if "`x'" == "." assert A[`i', 4] == .
            else assert A[`i', 4] == `x'
        }
        quietly dataqa flow report, flow(h`t') poolsmall
        matrix B = r(table)
        local nw : word count `p`t''
        assert rowsof(B) == `nw' / 4
        local k = 0
        forvalues i = 1/`=rowsof(B)' {
            forvalues j = 1/4 {
                local ++k
                local x : word `k' of `p`t''
                if "`x'" == "m" assert B[`i', `j'] == .m
                else if "`x'" == "." assert B[`i', `j'] == .
                else assert B[`i', `j'] == `x'
            }
        }
        quietly dataqa flow report, flow(h`t') mincell(0)
        matrix C = r(table)
        forvalues i = 1/`S' {
            local x : word `i' of `c`t''
            assert C[`i', 3] == `x'
        }
        assert r(n_masked) == 0
    }
    _ft `=_rc' "F1.`t' flow `c`t'': masking, poolsmall and mincell(0) tables equal the hand-worked rule"
}

* the same flows counted as ids (two rows per id): the table is the ids'
capture noisily {
    _fl_make `c1', flow(hid) id(2)
    quietly dataqa flow report, flow(hid) poolsmall
    assert r(count) == "ids"
    matrix B = r(table)
    assert B[2, 3] == 90 & B[2, 4] == 10 & B[3, 3] == 40
    quietly dataqa flow report, flow(hid) poolsmall count(rows)
    matrix B = r(table)
    * rows are 200 192 180 80: 8 then 12 excluded, both >= 5, no pooling
    assert rowsof(B) == 4 & B[2, 4] == 8 & B[3, 4] == 12 & B[4, 3] == 80
}
local _brc = _rc
capture restore
_ft `_brc' "F1.12 id(): ids are counted by default; count(rows) gives the row table"

**# F2 - the brute-force reader over every small flow (direct call of the rule)

* the rule's Mata is private to the autoloaded file; run the installed
* copy so the reader can call it directly
quietly findfile _dataqa_flow.ado
capture program drop _dataqa_flow
quietly run "`r(fn)'"

* every non-increasing flow with S steps and N1 <= nmax, mincell 3, 4, 5,
* both layouts: no withheld cell determined, printed numbers 0 or >= m,
* pairwise differences of printed remaining counts 0 or >= m, the truth a
* candidate.  The rule is loaded by one report call above.
capture noisily {
    mata: _ft_exhaust()
    assert `nflows' == 4944
    assert `nleak' == 0 & `nprop' == 0 & `nwrong' == 0
}
local _brc = _rc
capture restore
_ft `_brc' "F2 exhaustive small flows: no withheld number is determined by the printed ones; printed numbers and differences are 0 or >= m"

* the reader is not blind: a naive table that withholds only the small
* exclusion is caught (one withheld cell determined), and a table that
* prints a small count fails the property check
capture noisily {
    mata: _ft_selftest()
}
local _brc = _rc
capture restore
_ft `_brc' "F2 reader self-test: it flags a recoverable cell, a small printed number, and a wrong printed number"

**# F3 - end to end on seeded random flows

capture noisily {
    set seed 210010
    local nbad = 0
    forvalues t = 1/40 {
        local S = runiformint(2, 6)
        local m = runiformint(3, 6)
        local n = runiformint(0, 40)
        local cs "`n'"
        forvalues i = 2/`S' {
            local u = runiform()
            if `u' < 0.45 local d = min(`n', runiformint(1, `m' - 1))
            else if `u' < 0.6 local d = 0
            else local d = runiformint(0, `n')
            local n = `n' - `d'
            local cs "`cs' `n'"
        }
        _fl_make `cs', flow(rnd`t')
        foreach pl in "" "poolsmall" {
            quietly dataqa flow report, flow(rnd`t') mincell(`m') `pl'
            matrix A = r(table)
            mata: A = st_matrix("A"); Nt = strtoreal(tokens(st_local("cs")))'
            mata: st_local("chk", strofreal(_ft_reader(A, Nt, 12) != 0 | _ft_props(A, `m') != 0))
            mata: X = _dataqa_flowmask(Nt, `m', "`pl'" != ""); st_local("same", strofreal(A == X[., 1..4]))
            if `chk' | !`same' {
                display as error "flow `cs' m `m' `pl': chk `chk' same `same'"
                local ++nbad
            }
        }
        quietly dataqa flow clear, flow(rnd`t')
    }
    assert `nbad' == 0
}
local _brc = _rc
capture restore
_ft `_brc' "F3 40 seeded random flows end to end: r(table) is the rule, nothing recoverable, printed numbers are the true counts"

**# F4 - conservation

local LG "`W'/f4.log"
capture noisily {
    _fl_make 50 40 30, flow(up)
    quietly set obs 45
    quietly replace pid = _n
    quietly dataqa flow step s4, flow(up)
    _fl_cap "`LG'" dataqa flow report, flow(up)
    assert `_rc' == 9
    capture dataqa flow report, flow(up)
    assert _rc == 9
    assert r(status) == "fail" & r(bad_step) == "s4" & r(n_steps) == 4
    mata: assert(_ft_has(st_local("LG"), "FAIL flow up: step s4 has more rows than step s3"))
    * nothing of the flow is printed: no count of the flow in the output
    foreach v in 50 40 30 45 {
        mata: assert(!_ft_has(st_local("LG"), " `v'"))
    }
    preserve
    quietly use "`L'", clear
    quietly keep if family == "flow" & dataset == "flow_up"
    * one row per report call (two above), each a failed invariant
    assert _N == 2
    assert status == "fail" & kind == "invariant" & observed == "increase at s4" & expected == "non-increasing rows"
    restore
    _fl_cap "`LG'" dataqa assert
    assert `_rc' == 9
    * collect: recorded, rc 0
    dataqa set maskrare mincell(5) ledger("`L'") run(r1) collect
    _fl_cap "`LG'" dataqa flow report, flow(up)
    assert `_rc' == 0
    mata: assert(_ft_has(st_local("LG"), "collect: the failure is recorded in the ledger"))
    quietly dataqa flow report, flow(up)
    assert r(status) == "fail" & r(bad_step) == "s4"
    dataqa set maskrare mincell(5) ledger("`L'") run(r1)
    * the fixed rerun replaces s4 and supersedes the failure
    quietly keep in 1/30
    quietly dataqa flow step s4, flow(up)
    assert r(step) == 4
    quietly dataqa flow report, flow(up)
    assert r(status) == "pass"
}
local _brc = _rc
capture restore
_ft `_brc' "F4 a step that adds rows fails the flow gate (rc 9, no count printed, failed ledger row, assert halts); collect gives 0; a rerun supersedes"

dataqa set maskrare mincell(5) ledger("`L'") run(r1)
capture noisily {
    * the same through ids: rows fall but ids rise is a failure under ids
    clear
    quietly set obs 20
    quietly generate long pid = ceil(_n / 2)
    quietly dataqa flow step a, flow(upid) id(pid)
    quietly replace pid = _n
    quietly keep in 1/15
    quietly dataqa flow step b, flow(upid) id(pid)
    capture dataqa flow report, flow(upid)
    assert _rc == 9 & r(bad_step) == "b"
    * ids are checked whatever count() prints: count(rows) fails as well
    capture dataqa flow report, flow(upid) count(rows)
    assert _rc == 9 & r(bad_step) == "b" & r(status) == "fail"
    capture dataqa assert
    assert _rc == 9
}
local _brc = _rc
capture restore
_ft `_brc' "F4 ids are checked whatever count() prints: ids rising fails count(ids) and count(rows); assert halts"

capture noisily {
    * rows rising while ids stay level fails the default (ids) report too
    * (reviewer finding: expand in a step passed under count(ids))
    local LG "`W'/f4r.log"
    clear
    quietly set obs 100
    quietly generate long pid = ceil(_n / 2)
    quietly dataqa flow step a, flow(rowsup) id(pid)
    quietly expand 3 in 1/10
    * by hand: 100 + 2 * 10 rows, still 50 ids
    assert _N == 120
    preserve
    quietly contract pid
    assert _N == 50
    restore
    _fl_cap "`LG'" dataqa flow step b, flow(rowsup) id(pid)
    mata: assert(_ft_has(st_local("LG"), "will fail this flow"))
    quietly keep if pid <= 20
    quietly dataqa flow step c, flow(rowsup) id(pid)
    _fl_cap "`LG'" dataqa flow report, flow(rowsup) mincell(5)
    assert `_rc' == 9
    mata: assert(_ft_has(st_local("LG"), "FAIL flow rowsup: step b has more rows than step a"))
    mata: assert(!_ft_has(st_local("LG"), "PASS flow rowsup"))
    capture dataqa flow report, flow(rowsup)
    assert _rc == 9 & r(status) == "fail" & r(bad_step) == "b"
    preserve
    quietly use "`L'", clear
    quietly keep if dataset == "flow_rowsup"
    assert _N == 2
    assert status == "fail" & observed == "increase at b" & expected == "non-increasing rows and ids"
    restore
    capture dataqa assert
    assert _rc == 9
    * a passing flow with ids names both in the PASS line
    quietly dataqa flow clear, flow(rowsup)
    _fl_make 30 20, flow(rowsup) id(2)
    _fl_cap "`LG'" dataqa flow report, flow(rowsup)
    assert `_rc' == 0
    mata: assert(_ft_has(st_local("LG"), "PASS flow rowsup: remaining rows and ids never increase (2 steps)"))
}
local _brc = _rc
capture restore
_ft `_brc' "F4 a step that adds rows with ids level fails the default ids report (rc 9, step named, gate row non-increasing rows and ids)"

**# F5 - steps

capture noisily {
    quietly dataqa flow clear, flow(upid)
    assert r(n_cleared) == 2
    capture dataqa flow report, flow(upid)
    assert _rc == 2000
    * rerun replaces the step and the later ones
    _fl_make 10 9 8 7, flow(rr)
    clear
    quietly set obs 10
    quietly generate long pid = _n
    quietly dataqa flow step s2, flow(rr)
    assert r(step) == 2
    preserve
    quietly use "`LS'.flow.dta", clear
    quietly count if flow == "rr"
    assert r(N) == 2
    restore
    * one step only
    quietly dataqa flow report, flow(rr) mincell(0)
    matrix A = r(table)
    assert rowsof(A) == 2 & A[2, 3] == 10 & A[2, 4] == 0
    quietly dataqa flow clear, flow(rr)
    _fl_make 7, flow(one)
    quietly dataqa flow report, flow(one) mincell(0)
    assert r(n_rows) == 1 & r(n_steps) == 1
    quietly dataqa flow report, flow(one)
    matrix A = r(table)
    assert A[1, 3] == 7
    quietly dataqa flow report, flow(one) mincell(10)
    matrix A = r(table)
    assert A[1, 3] == .m
}
local _brc = _rc
capture restore
_ft `_brc' "F5 rerun of a step name replaces it and later steps; clear; a one-step flow"

capture noisily {
    * string and strL ids, distinct counts against contract
    clear
    quietly set obs 30
    quietly generate str5 sid = "p" + string(mod(_n, 11))
    quietly generate strL lid = sid + char(10) + "x"
    preserve
    contract sid
    local nd = _N
    restore
    quietly dataqa flow step a, flow(sid) id(sid)
    quietly drop if inlist(sid, "p1", "p2", "p3", "p4", "p5", "p6")
    quietly dataqa flow step b, flow(sid) id(lid)
    quietly dataqa flow report, flow(sid) mincell(0)
    matrix A = r(table)
    assert A[1, 3] == `nd' & A[2, 3] == `nd' - 6 & A[2, 4] == 6
    * missing ids are refused; all-missing too
    quietly replace sid = "" in 1
    capture dataqa flow step c, flow(sid) id(sid)
    assert _rc == 416
    quietly generate double nid = .
    capture dataqa flow step c, flow(sid) id(nid)
    assert _rc == 416
    quietly replace nid = .a in 1
    capture dataqa flow step c, flow(sid) id(nid)
    assert _rc == 416
}
local _brc = _rc
capture restore
_ft `_brc' "F5 string and strL ids count distinct values (contract); a missing or extended-missing id is r(416)"

capture noisily {
    * empty data: a step of 0 rows, and a flow that starts empty
    _fl_make 12 0, flow(emp)
    quietly dataqa flow report, flow(emp)
    matrix A = r(table)
    assert A[1, 3] == 12 & A[2, 3] == 0 & A[2, 4] == 12
    clear
    quietly dataqa flow step z, flow(emp0)
    quietly dataqa flow report, flow(emp0)
    matrix A = r(table)
    assert A[1, 3] == 0
    * the data are untouched by step and report
    sysuse auto, clear
    quietly datasignature
    local sg "`r(datasignature)'"
    local sv "`: sortedby'"
    quietly dataqa flow step a, flow(au) id(make)
    quietly dataqa flow report, flow(au)
    quietly datasignature
    assert "`r(datasignature)'" == "`sg'" & "`: sortedby'" == "`sv'"
    assert c(changed) == 0
}
local _brc = _rc
capture restore
_ft `_brc' "F5 empty data and a flow that starts at 0; step and report leave the data, sort order and changed flag as they were"

capture noisily {
    * dataqa set ... replace starts the run's flows afresh (reviewer
    * finding: stale steps of the previous attempt were kept)
    local RL "`W'/frep.dta"
    local RS "`W'/frep"
    capture erase "`RL'"
    capture erase "`RS'.flow.dta"
    dataqa set maskrare mincell(5) ledger("`RL'") run(r1)
    _fl_make 50 40 30, flow(main)
    _fl_make 20 10, flow(other)
    dataqa set maskrare mincell(5) ledger("`RL'") run(r2)
    _fl_make 60 50, flow(main)
    * before: r1 holds 3 + 2 steps, r2 holds 2 (by hand)
    preserve
    quietly use "`RS'.flow.dta", clear
    quietly count if run == "r1"
    assert r(N) == 5
    restore
    dataqa set maskrare mincell(5) ledger("`RL'") run(r1) replace
    assert r(n_flow_removed) == 5 & r(n_removed) == 0
    preserve
    quietly use "`RS'.flow.dta", clear
    quietly count if run == "r1"
    assert r(N) == 0
    quietly count if run == "r2"
    assert r(N) == 2
    restore
    * the rerun's first step is step 1, not step 4
    clear
    quietly set obs 70
    quietly generate long pid = _n
    quietly dataqa flow step start
    assert r(step) == 1
    quietly keep in 1/60
    quietly dataqa flow step b2
    assert r(step) == 2
    quietly dataqa flow report, mincell(5)
    assert r(status) == "pass" & r(n_steps) == 2 & r(steps) == "start b2"
    * no flow file: replace stores no n_flow_removed and prints nothing of flows
    local RL2 "`W'/frep2.dta"
    capture erase "`RL2'"
    dataqa set ledger("`RL2'") run(r1) replace
    assert missing(r(n_flow_removed))
    * flow clear, all: every flow of the run; all with flow() is 198
    dataqa set maskrare mincell(5) ledger("`RL'") run(r2)
    _fl_make 9 8, flow(x2)
    capture dataqa flow clear, all flow(main)
    assert _rc == 198
    quietly dataqa flow clear, all
    assert r(n_cleared) == 4 & r(found) == 1
    preserve
    quietly use "`RS'.flow.dta", clear
    quietly count if run == "r2"
    assert r(N) == 0
    quietly count if run == "r1"
    assert r(N) == 2
    restore
    * the agent preset: the first step of a flow says the flow file is
    * outside it; later steps do not
    local LG "`W'/fagent.log"
    dataqa set agent ledger("`RL'") run(r3)
    clear
    quietly set obs 10
    _fl_cap "`LG'" dataqa flow step a1, flow(ag)
    mata: assert(_ft_has(st_local("LG"), "the flow file holds exact counts, small ones included"))
    _fl_cap "`LG'" dataqa flow step a2, flow(ag)
    mata: assert(!_ft_has(st_local("LG"), "the flow file holds exact counts"))
    dataqa set clear
    clear
    quietly set obs 10
    _fl_cap "`LG'" dataqa flow step a1, flow(ag2) ledger("`RL'") run(r3)
    mata: assert(!_ft_has(st_local("LG"), "the flow file holds exact counts"))
}
local _brc = _rc
capture restore
_ft `_brc' "F5 dataqa set replace removes every flow step of the run (r(n_flow_removed)), other runs kept; clear, all; the agent-preset note on the flow file"
dataqa set maskrare mincell(5) ledger("`L'") run(r1)

**# F6 - errors and integrity

capture noisily {
    _fl_make 20 10, flow(err)
    foreach mc in 1 2 -1 {
        capture dataqa flow report, flow(err) mincell(`mc')
        assert _rc == 198
    }
    capture dataqa flow report, flow(err) count(people)
    assert _rc == 198
    capture dataqa flow report, flow(err) count(ids)
    assert _rc == 198
    capture dataqa flow report, flow(err) export("`W'/x.txt")
    assert _rc == 198
    capture dataqa flow report, flow(err) export("`W'/x;rm.md")
    assert _rc == 198
    capture dataqa flow step 1bad, flow(err)
    assert _rc == 198
    capture dataqa flow frob
    assert _rc == 198
    capture dataqa flow report, flow(nosuch)
    assert _rc == 2000
    capture dataqa flow report, flow(err) run(other)
    assert _rc == 2000
    capture dataqa flow report, flow(err) ledger("`W'/elsewhere.dta")
    assert _rc == 601
    dataqa set clear
    capture dataqa flow step x
    assert _rc == 198
    capture dataqa flow report
    assert _rc == 198
    * agent preset: at least 5, and the session mincell is the default
    dataqa set agent mincell(3) ledger("`L'") run(r1)
    capture dataqa flow report, flow(err)
    assert _rc == 198
    capture dataqa flow report, flow(err) mincell(4)
    assert _rc == 198
    quietly dataqa flow report, flow(err) mincell(5)
    assert r(mincell) == 5
    dataqa set maskrare mincell(7) ledger("`L'") run(r1)
    quietly dataqa flow report, flow(err)
    assert r(mincell) == 7
    dataqa set ledger("`L'") run(r1)
    quietly dataqa flow report, flow(err)
    assert r(mincell) == 5
    dataqa set maskrare mincell(5) ledger("`L'") run(r1)
    * an edited flow file is refused
    preserve
    quietly use "`LS'.flow.dta", clear
    quietly replace ex_rows = ex_rows + 1 if flow == "err" & step == 2
    quietly save "`LS'.flow.dta", replace
    restore
    capture dataqa flow report, flow(err)
    assert _rc == 610
    preserve
    quietly use "`LS'.flow.dta", clear
    quietly replace ex_rows = ex_rows - 1 if flow == "err" & step == 2
    quietly replace step = 3 if flow == "err" & step == 2
    quietly save "`LS'.flow.dta", replace
    restore
    capture dataqa flow report, flow(err)
    assert _rc == 610
    quietly dataqa flow clear, flow(err)
}
local _brc = _rc
capture restore
_ft `_brc' "F6 option and path errors (198/601/2000), the agent floor and session default of mincell, an edited flow file is r(610)"

**# F7 - hostile text and export

local H = "a " + char(34) + "q" + char(34) + " 'b' " + char(36) + "x " + char(96) + "c" + char(39) + " {d} {bf:e} | f"
local LG "`W'/f7.log"
capture noisily {
    clear
    quietly set obs 40
    quietly generate long pid = _n
    quietly dataqa flow step all, flow(hx) label(`"`macval(H)'"')
    quietly keep in 1/38
    quietly dataqa flow step drop2, flow(hx) label("plain")
    quietly keep in 1/30
    quietly dataqa flow step drop8, flow(hx)
    _fl_cap "`LG'" dataqa flow report, flow(hx) poolsmall export("`W'/hx.md") replace
    assert `_rc' == 0
    mata: assert(_ft_has(st_local("LG"), st_local("H")))
    mata: assert(_ft_has(st_local("LG"), "drop2 + drop8"))
    mata: md = _ft_fread(st_local("W") + "/hx.md")
    mata: H = st_local("H")
    mata: assert(strpos(md, subinstr(H, "|", char(92) + "|")) > 0)
    mata: assert(strpos(md, "| all | " + subinstr(H, "|", char(92) + "|") + " | 40 |  |") > 0)
    mata: assert(strpos(md, "| drop2 + drop8 | plain | 30 | 10 |") > 0)
    _fl_cap "`LG'" dataqa flow report, flow(hx) export("`W'/hx.csv") replace
    mata: cs = _ft_fread(st_local("W") + "/hx.csv")
    mata: assert(strpos(cs, char(34) + "all" + char(34) + "," + char(34) + subinstr(H, char(34), char(34) + char(34)) + char(34) + "," + char(34) + "40" + char(34)) > 0)
    mata: assert(strpos(cs, char(34) + "drop2" + char(34) + "," + char(34) + "plain" + char(34) + "," + char(34) + "suppressed" + char(34) + "," + char(34) + "suppressed" + char(34)) > 0)
    mata: assert(strpos(cs, char(34) + "drop8" + char(34) + ",," + char(34) + "30" + char(34) + "," + char(34) + "suppressed" + char(34)) > 0 | strpos(cs, char(34) + "drop8" + char(34) + "," + char(34) + char(34) + "," + char(34) + "30" + char(34) + "," + char(34) + "suppressed" + char(34)) > 0)
    * no small number printed: 2 and 8 never appear as counts
    mata: assert(!strpos(cs, char(34) + "2" + char(34)) & !strpos(cs, char(34) + "8" + char(34)))
    capture dataqa flow report, flow(hx) export("`W'/hx.csv")
    assert _rc == 602
    * a hostile run label is refused, as in dataqa set
    capture dataqa flow report, flow(hx) run(a;b)
    assert _rc == 198
    quietly dataqa flow clear, flow(hx)
}
local _brc = _rc
capture restore
_ft `_brc' "F7 hostile label text prints and exports literally; md/csv rows exact; no small number written; export without replace is r(602)"

**# W1 - dataqa set worker() and sharddir()

capture noisily {
    foreach bad in "a.b" "a/b" "a b" "1234567890123456789012345678901234" "w1'" {
        capture dataqa set ledger("`L'") worker(`"`bad'"')
        assert _rc == 198
    }
    local bad = "x" + char(36) + "y"
    capture dataqa set ledger("`L'") worker(`"`macval(bad)'"')
    assert _rc == 198
    local bad = "x" + char(96) + "y"
    capture dataqa set ledger("`L'") worker(`"`macval(bad)'"')
    assert _rc == 198
    dataqa set ledger("`L'") worker("w1")
    assert r(shard) == "`W'/led.shard-w1.dta"
    capture dataqa set worker(w1)
    assert _rc == 198
    capture dataqa set ledger("`L'") sharddir("`W'")
    assert _rc == 198
    capture dataqa set ledger("`L'") worker(w1) sharddir("`W'/nosuch")
    assert _rc == 601
    capture dataqa set ledger("`L'") worker(w1) sharddir("`W';x")
    assert _rc == 198
    dataqa set ledger("`L'") run(r2) worker(w-1_A)
    assert r(shard) == "`W'/led.shard-w-1_A.dta"
    capture mkdir "`W'/sd"
    dataqa set ledger("`L'") run(r2) worker(w1) sharddir("`W'/sd")
    assert r(shard) == "`W'/sd/led.shard-w1.dta"
    _datamap_dqdefaults
    assert r(worker) == "w1" & r(sharddir) == "`W'/sd" & r(ledger) == "`L'"
    dataqa set clear
}
local _brc = _rc
capture restore
_ft `_brc' "W1 worker() is a file-name token (198 otherwise), needs ledger(); sharddir() needs worker() and an existing directory; r(shard)"

**# W2 - a worker writes its shard, never the ledger

local SL "`W'/sl.dta"
capture noisily {
    capture erase "`SL'"
    dataqa set ledger("`SL'") run(r1) collect worker(wa)
    sysuse auto, clear
    quietly dataprobe, gatesonly isid(make) bands(stat(mean mpg 18 25)) name(autoA)
    assert r(n_failed) == 0
    quietly dataprobe, gatesonly bands(stat(mean mpg 50 60)) name(autoA2)
    capture confirm file "`SL'"
    assert _rc == 601
    confirm file "`W'/sl.shard-wa.dta"
    * an error row of a failed call also goes to the shard
    capture dataprobe, gatesonly isid(nosuchvar) name(autoE)
    assert _rc != 0
    capture confirm file "`SL'"
    assert _rc == 601
    * report/assert in the worker read the shard
    quietly dataqa report
    assert !missing(r(N)) & r(N) > 0 & r(ledger) == "`W'/sl.shard-wa.dta"
    capture dataqa assert
    assert _rc == 9
    dataqa set clear
    preserve
    quietly use "`W'/sl.shard-wa.dta", clear
    quietly ds
    assert "`r(varlist)'" == "run stamp seq dataset scope family label variable grp kind status observed observed_num expected n_scope version signature masked mincell minshown obs_masked message phase worker"
    assert worker == "wa"
    quietly count if status == "error"
    assert r(N) == 1
    restore
    * without worker() the ledger schema is the wave-1 one, no worker column
    tempfile pl
    dataqa set ledger("`pl'") run(r1)
    quietly dataprobe, gatesonly isid(make) name(autoP)
    dataqa set clear
    preserve
    quietly use "`pl'", clear
    quietly ds
    assert "`r(varlist)'" == "run stamp seq dataset scope family label variable grp kind status observed observed_num expected n_scope version signature masked mincell minshown obs_masked message phase"
    restore
}
local _brc = _rc
capture restore
_ft `_brc' "W2 a worker session writes gate and error rows to its shard (worker column), never the ledger; report/assert read the shard; plain sessions keep the schema"

capture noisily {
    * a flow in a worker session: steps in the shard's flow file, the gate
    * row in the shard; merge skips the flow file
    local SL2 "`W'/sl2.dta"
    dataqa set ledger("`SL2'") run(r1) worker(wf)
    sysuse auto, clear
    quietly dataprobe, gatesonly isid(make) name(autoF)
    quietly dataqa flow step all, id(make)
    assert r(flowfile) == "`W'/sl2.shard-wf.flow.dta"
    quietly keep if foreign
    quietly dataqa flow step foreign, id(make)
    quietly dataqa flow report
    matrix A = r(table)
    * auto: 74 cars and the foreign ones, counted independently
    sysuse auto, clear
    quietly count if foreign
    local nf = r(N)
    assert A[1, 3] == 74 & A[2, 3] == `nf' & A[2, 4] == 74 - `nf'
    capture confirm file "`SL2'"
    assert _rc == 601
    capture confirm file "`W'/sl2.flow.dta"
    assert _rc == 601
    * replace under worker() clears the run from the shard, not the ledger
    preserve
    quietly use "`W'/sl2.shard-wf.dta", clear
    quietly count if run == "r1"
    local nr1 = r(N)
    quietly count if family == "flow"
    assert r(N) == 1
    restore
    dataqa set ledger("`SL2'") run(r1) worker(wf) replace
    assert r(n_removed) == `nr1'
    capture confirm file "`SL2'"
    assert _rc == 601
    preserve
    quietly use "`W'/sl2.shard-wf.dta", clear
    assert _N == 0
    restore
    * an empty shard alone: nothing to merge
    capture dataqa merge, into("`SL2'")
    assert _rc == 2000
    * rewrite and merge: one shard, the flow file is not read as a shard
    quietly dataprobe, gatesonly isid(make) name(autoF)
    dataqa set clear
    dataqa merge, into("`SL2'")
    assert r(n_shards) == 1 & r(workers) == "wf"
}
local _brc = _rc
capture restore
dataqa set clear
_ft `_brc' "W2 a worker's flow lives in the shard's flow file, its gate row in the shard; replace clears the shard's run; merge skips flow files"

**# W3 - merge

capture program drop _fl_wrun
program define _fl_wrun
    * _fl_wrun ledger wid "dataset names": one worker's calls, sequentially
    args led wid names
    dataqa set ledger("`led'") run(m1) collect worker(`wid')
    foreach n of local names {
        sysuse auto, clear
        quietly dataprobe, gatesonly isid(make) bands(stat(mean mpg 18 25)) name(`n')
    }
    dataqa set clear
end

local ML "`W'/ml.dta"
capture noisily {
    capture erase "`ML'"
    * the ledger already holds two calls of run m1 from the main job
    dataqa set ledger("`ML'") run(m1)
    sysuse auto, clear
    quietly dataprobe, gatesonly isid(make) name(main1)
    quietly dataprobe, gatesonly isid(make) name(main2)
    dataqa set clear
    _fl_wrun "`ML'" wB "b1 b2 b3"
    _fl_wrun "`ML'" wA "a1 a2"
    preserve
    quietly use "`ML'", clear
    local n0 = _N
    restore
    preserve
    quietly use "`W'/ml.shard-wA.dta", clear
    local nA = _N
    quietly use "`W'/ml.shard-wB.dta", clear
    local nB = _N
    restore
    dataqa merge, into("`ML'")
    assert r(n_shards) == 2 & r(workers) == "wA wB" & r(n_added) == `nA' + `nB'
    assert r(N) == `n0' + `nA' + `nB'
    preserve
    quietly use "`ML'", clear
    * order: ledger rows, then wA, then wB; datasets in that order
    quietly generate long o = _n
    assert worker == "" in 1/`n0'
    assert worker == "wA" in `=`n0' + 1'/`=`n0' + `nA''
    assert worker == "wB" in `=`n0' + `nA' + 1'/l
    * seq: one per call, 1..7 in that order
    quietly bysort seq (o): assert dataset == dataset[1]
    sort o
    quietly levelsof dataset, local(ds) clean
    local want "main1 main2 a1 a2 b1 b2 b3"
    forvalues s = 1/7 {
        quietly levelsof dataset if seq == `s', local(d) clean
        assert "`d'" == "`: word `s' of `want''"
    }
    assert seq[_n] >= seq[_n - 1] if _n > 1
    restore
    quietly dataqa report using "`ML'", run(m1)
    assert r(n_datasets) == 7 & r(n_failed) == 0
    quietly dataqa assert using "`ML'", run(m1) expect(main1 main2 a1 a2 b1 b2 b3)
    * a second merge of the same shards is refused, the ledger untouched
    preserve
    quietly use "`ML'", clear
    quietly datasignature
    local sg0 "`r(datasignature)'"
    restore
    capture dataqa merge, into("`ML'")
    assert _rc == 459
    preserve
    quietly use "`ML'", clear
    quietly datasignature
    assert "`r(datasignature)'" == "`sg0'"
    restore
    * replace: wA rerun with one call; its old rows are replaced
    capture erase "`W'/ml.shard-wA.dta"
    _fl_wrun "`ML'" wA "a9"
    * both shards are merged again: every earlier row of wA and wB is replaced
    dataqa merge, into("`ML'") replace
    assert r(n_replaced) == `nA' + `nB' & r(n_added) == `nA' / 2 + `nB'
    preserve
    quietly use "`ML'", clear
    quietly count if worker == "wA"
    assert r(N) == `nA' / 2
    quietly count if dataset == "a1" | dataset == "a2"
    assert r(N) == 0
    quietly count if worker == "wB"
    assert r(N) == `nB'
    restore
}
local _brc = _rc
capture restore
_ft `_brc' "W3 merge: ledger rows first, then shards in worker order, seq renumbered per call; report/assert read the merged run; re-merge 459 and untouched; replace"

capture noisily {
    * a 2.0.0 ledger (no phase column) as the target; from(dir) and from(pattern)
    local OL "`W'/old.dta"
    tempfile pl2
    dataqa set ledger("`pl2'") run(m1)
    sysuse auto, clear
    quietly dataprobe, gatesonly isid(make) name(old1)
    dataqa set clear
    preserve
    quietly use "`pl2'", clear
    quietly drop phase
    quietly save "`OL'", replace
    local n0 = _N
    restore
    capture mkdir "`W'/shd"
    dataqa set ledger("`OL'") run(m1) worker(z9) sharddir("`W'/shd")
    sysuse auto, clear
    quietly dataprobe, gatesonly isid(make) name(new1)
    dataqa set clear
    capture dataqa merge, into("`OL'")
    assert _rc == 601
    dataqa merge, into("`OL'") from("`W'/shd")
    assert r(n_shards) == 1
    preserve
    quietly use "`OL'", clear
    assert phase == "" & worker == "" in 1/`n0'
    assert worker == "z9" in `=`n0' + 1'/l
    restore
    quietly dataqa assert using "`OL'", run(m1) expect(old1 new1)
    capture dataqa merge, into("`W'/old2.dta") from("`W'/shd/*.dta")
    assert _rc == 0 & r(n_shards) == 1
}
local _brc = _rc
capture restore
_ft `_brc' "W3 a 2.0.0 ledger without phase is a valid target; from(dir) and from(pattern); no shards is r(601)"

capture noisily {
    * refusals: schema, mixed worker, duplicate worker, type mismatch
    local RL "`W'/rl.dta"
    capture erase "`RL'"
    _fl_wrun "`RL'" r1 "x1"
    _fl_wrun "`RL'" r2 "x2"
    local good1 "`W'/rl.shard-r1.dta"
    local good2 "`W'/rl.shard-r2.dta"
    local bad "`W'/rl.shard-r3.dta"
    foreach how in extra missing type mixed badid dup empty {
        preserve
        quietly use "`good1'", clear
        if "`how'" == "extra" quietly generate byte junk = 1
        if "`how'" == "missing" quietly drop phase
        if "`how'" == "type" {
            quietly drop seq
            quietly generate str3 seq = "1"
        }
        if "`how'" == "mixed" {
            quietly expand 2
            quietly replace worker = "r3" in 1
        }
        if "`how'" == "badid" quietly replace worker = "r.3"
        if "`how'" == "empty" quietly drop in 1/l
        quietly save "`bad'", replace
        restore
        capture dataqa merge, into("`RL'")
        if "`how'" == "empty" {
            * an empty shard is skipped; the other two merge
            assert _rc == 0 & r(n_shards) == 2 & r(n_skipped) == 1
            erase "`RL'"
            continue
        }
        * dup: a copy of r1's shard under the name r3.  Two shards of one
        * worker (r(459)) can no longer arise from file names alone: the
        * name check refuses the copy first (named r3, rows r1), r(610)
        assert _rc == 610
        if "`how'" == "dup" {
            _fl_cap "`W'/rdup.log" dataqa merge, into("`RL'")
            assert `_rc' == 610
            mata: assert(_ft_has(st_local("W") + "/rdup.log", "is named for worker r3 but its rows are worker r1"))
        }
        capture confirm file "`RL'"
        assert _rc == 601
    }
    capture erase "`bad'"
    * a target whose column type differs
    preserve
    quietly use "`good1'", clear
    quietly drop worker
    quietly drop observed_num
    quietly generate str3 observed_num = ""
    quietly save "`RL'", replace
    restore
    capture dataqa merge, into("`RL'")
    assert _rc == 610
    * a target that is not a ledger
    preserve
    sysuse auto, clear
    quietly save "`RL'", replace
    restore
    capture dataqa merge, into("`RL'")
    assert _rc == 610
    capture dataqa merge, into("`W'/x;y.dta")
    assert _rc == 198
    capture dataqa merge
    assert _rc == 198
}
local _brc = _rc
capture restore
_ft `_brc' "W3 refusals: extra/missing/retyped column, mixed or invalid worker (610), a shard copied under another worker's name (610), an empty shard skipped, target type mismatch or not a ledger (610); nothing written"

capture program drop _fl_wgate
program define _fl_wgate
    * _fl_wgate ledger wid run dup: one worker's isid(make) gate on auto,
    * named cars; dup 1 duplicates a row so the gate fails, 2 fails and
    * then reruns clean (the worker's own rerun)
    args led wid run dup
    dataqa set ledger("`led'") run(`run') collect worker(`wid')
    sysuse auto, clear
    if `dup' quietly expand 2 in 1
    quietly dataprobe, gatesonly isid(make) name(cars)
    if `dup' == 2 {
        sysuse auto, clear
        quietly dataprobe, gatesonly isid(make) name(cars)
    }
    dataqa set clear
end

capture noisily {
    * the same gate on two workers, one failing (reviewer finding: the later
    * worker's pass superseded the other's failure), in both worker orders
    local GL "`W'/gl.dta"
    foreach ord in ab ba {
        capture erase "`GL'"
        capture erase "`W'/gl.shard-wa.dta"
        capture erase "`W'/gl.shard-wb.dta"
        local fw = substr("`ord'", 1, 1)
        local pw = substr("`ord'", 2, 1)
        _fl_wgate "`GL'" w`fw' g1 1
        _fl_wgate "`GL'" w`pw' g1 0
        quietly dataqa merge, into("`GL'")
        * by hand: one isid row per worker, the w`fw' one failed
        preserve
        quietly use "`GL'", clear
        quietly count if dataset == "cars" & family == "isid"
        assert r(N) == 2
        quietly count if dataset == "cars" & family == "isid" & status == "fail" & worker == "w`fw'"
        assert r(N) == 1
        restore
        quietly dataqa report using "`GL'", run(g1)
        assert r(n_failed) == 1
        capture dataqa assert using "`GL'", run(g1)
        assert _rc == 9 & r(n_failed) == 1
        if "`ord'" == "ab" {
            * compare reads the worst-status row of the two workers (the
            * failed wa call on 75 rows), not the later worker's pass on
            * 74: against a plain baseline on auto (74 rows) N changes
            dataqa set ledger("`GL'") run(g0)
            sysuse auto, clear
            quietly dataprobe, gatesonly isid(make) name(cars)
            dataqa set clear
            _fl_cap "`W'/gcmp.log" dataqa compare using "`GL'", run(g1) baseline(g0) ntol(0)
            assert `_rc' == 0
            mata: assert(_ft_has(st_local("W") + "/gcmp.log", "74 -> 75"))
            quietly dataqa compare using "`GL'", run(g1) baseline(g0) ntol(0)
            assert r(n_flags) == 1
        }
    }
    * a worker's own rerun still supersedes its own failure after a merge
    capture erase "`GL'"
    capture erase "`W'/gl.shard-wa.dta"
    capture erase "`W'/gl.shard-wb.dta"
    _fl_wgate "`GL'" wa g2 2
    _fl_wgate "`GL'" wb g2 0
    quietly dataqa merge, into("`GL'")
    quietly dataqa report using "`GL'", run(g2)
    assert r(n_failed) == 0
    quietly dataqa assert using "`GL'", run(g2)
}
local _brc = _rc
capture restore
_ft `_brc' "W3 one worker's failure of a gate is not superseded by another worker's pass (both orders: report 1 failed, assert rc 9; compare reads the failed row); a worker's own rerun still supersedes"

capture noisily {
    * the flow gate of the same flow on two workers, one broken
    local GF "`W'/gf.dta"
    capture erase "`GF'"
    foreach w in fx fy {
        dataqa set ledger("`GF'") run(g3) collect worker(`w') mincell(5)
        clear
        quietly set obs 40
        quietly dataqa flow step a
        if "`w'" == "fx" quietly set obs 45
        else quietly keep in 1/30
        quietly dataqa flow step b
        capture dataqa flow report
        assert _rc == 0
        assert r(status) == cond("`w'" == "fx", "fail", "pass")
        dataqa set clear
    }
    quietly dataqa merge, into("`GF'")
    capture dataqa assert using "`GF'", run(g3)
    assert _rc == 9 & r(n_failed) == 1
}
local _brc = _rc
capture restore
_ft `_brc' "W3 a broken flow on one worker fails assert after merge although another worker's same flow passed"

capture noisily {
    * the file-name id must be the worker column's id
    local NL "`W'/nl.dta"
    capture erase "`NL'"
    _fl_wrun "`NL'" n1 "y1"
    copy "`W'/nl.shard-n1.dta" "`W'/nl.shard-n9.dta", replace
    capture dataqa merge, into("`NL'")
    assert _rc == 610
    capture confirm file "`NL'"
    assert _rc == 601
    erase "`W'/nl.shard-n9.dta"
    * from(pattern): a match not named as a shard is refused
    capture mkdir "`W'/nlp"
    copy "`W'/nl.shard-n1.dta" "`W'/nlp/copy_of_n1.dta", replace
    capture dataqa merge, into("`NL'") from("`W'/nlp/*.dta")
    assert _rc == 610
    capture confirm file "`NL'"
    assert _rc == 601
    * correctly named, it merges
    copy "`W'/nl.shard-n1.dta" "`W'/nlp/other.shard-n1.dta", replace
    erase "`W'/nlp/copy_of_n1.dta"
    quietly dataqa merge, into("`NL'") from("`W'/nlp/*.dta")
    assert r(n_shards) == 1 & r(workers) == "n1"
}
local _brc = _rc
capture restore
_ft `_brc' "W3 a shard renamed or copied to another worker's name, or a pattern match not named as a shard, is r(610); nothing written"

capture noisily {
    * run(): only that run's rows are folded in; stale runs are shown
    local QL "`W'/ql.dta"
    local LG "`W'/qrun.log"
    capture erase "`QL'"
    * worker q1 wrote run old earlier and run new now; q2 only run old
    dataqa set ledger("`QL'") run(old) collect worker(q1)
    sysuse auto, clear
    quietly dataprobe, gatesonly isid(make) name(s1)
    dataqa set ledger("`QL'") run(new) collect worker(q1)
    quietly dataprobe, gatesonly isid(make) bands(stat(mean mpg 18 25)) name(s2)
    dataqa set ledger("`QL'") run(old) collect worker(q2)
    quietly dataprobe, gatesonly isid(make) name(s3)
    dataqa set clear
    preserve
    quietly use "`W'/ql.shard-q1.dta", clear
    quietly count if run == "new"
    local nnew = r(N)
    quietly count if run == "old"
    local nold1 = r(N)
    quietly use "`W'/ql.shard-q2.dta", clear
    local nold2 = _N
    restore
    assert `nnew' > 0 & `nold1' > 0 & `nold2' > 0
    _fl_cap "`LG'" dataqa merge, into("`QL'") run(new)
    assert `_rc' == 0
    mata: assert(_ft_has(st_local("LG"), "worker q1: `nnew' row(s) of the run, `nold1' of other runs left out (runs: new old)"))
    quietly dataqa merge, into("`QL'") run(new) replace
    assert r(n_shards) == 1 & r(n_skipped) == 1 & r(n_added) == `nnew' & r(workers) == "q1"
    preserve
    quietly use "`QL'", clear
    assert run == "new"
    assert _N == `nnew'
    restore
    * without run(): each shard's line lists its runs
    capture erase "`QL'"
    _fl_cap "`LG'" dataqa merge, into("`QL'")
    assert `_rc' == 0
    local nq1 = `nnew' + `nold1'
    mata: assert(_ft_has(st_local("LG"), "worker q1: `nq1' row(s) of run(s) new old"))
    mata: assert(_ft_has(st_local("LG"), "worker q2: `nold2' row(s) of run(s) old"))
    * a run no shard holds is r(2000), nothing written
    capture erase "`QL'"
    capture dataqa merge, into("`QL'") run(nosuch)
    assert _rc == 2000
    capture confirm file "`QL'"
    assert _rc == 601
}
local _brc = _rc
capture restore
_ft `_brc' "W3 merge run() folds in only that run (other runs counted as left out, a shard without it skipped); each shard's line lists its runs; an absent run is r(2000)"

**# W4 - four concurrent Stata workers

local PL "`W'/par.dta"
local BAR "`W'/bar"
local NW 4
local NC 24
capture noisily {
    capture mkdir "`BAR'"
    local plus : sysdir PLUS
    tempname sh
    file open `sh' using "`BAR'/launch.sh", write text replace
    forvalues k = 1/`NW' {
        capture mkdir "`BAR'/job`k'"
        capture mkdir "`BAR'/job`k'/tmp"
        copy "`qa_dir'/_qa_flowshards_worker.do" "`BAR'/job`k'/_qa_flowshards_worker.do", replace
        file write `sh' `"cd "`BAR'/job`k'" && TMPDIR="`BAR'/job`k'/tmp" nohup stata-mp -b do _qa_flowshards_worker.do "`plus'" "`PL'" w`k' "`BAR'" `NW' `NC' > /dev/null 2>&1 &"' _n
        file write `sh' "echo " _char(36) `"! > "`BAR'/pid`k'.txt""' _n
    }
    file close `sh'
    shell bash "`BAR'/launch.sh"
    * wait for every done file (at most 600 s)
    local waited = 0
    local all = 0
    while !`all' & `waited' < 1200 {
        local all = 1
        forvalues k = 1/`NW' {
            capture confirm file "`BAR'/done_w`k'.txt"
            if _rc local all = 0
        }
        if !`all' {
            sleep 500
            local ++waited
        }
    }
    if !`all' {
        * stop only the children this suite started
        forvalues k = 1/`NW' {
            capture confirm file "`BAR'/pid`k'.txt"
            if !_rc {
                tempname ph
                file open `ph' using "`BAR'/pid`k'.txt", read text
                file read `ph' pid
                file close `ph'
                shell ps -p `pid' -o comm= | grep -q stata && kill `pid'
            }
        }
        display as error "W4: workers did not finish"
        exit 459
    }
    local t0max = 0
    local t1min = .
    forvalues k = 1/`NW' {
        tempname dh
        file open `dh' using "`BAR'/done_w`k'.txt", read text
        file read `dh' line
        file close `dh'
        local rck : word 1 of `line'
        local a : word 2 of `line'
        local b : word 3 of `line'
        display as text "worker w`k': rc `rck' start `a' end `b'"
        assert `rck' == 0
        local t0max = max(`t0max', `a')
        local t1min = min(`t1min', `b')
    }
    * every worker started before any finished: they wrote at the same time
    assert `t0max' <= `t1min'
    * each worker passed the halfway barrier, which it leaves only when
    * every worker has written half its calls (see _qa_flowshards_worker.do)
    forvalues k = 1/`NW' {
        confirm file "`BAR'/mid_w`k'.txt"
    }
    capture confirm file "`PL'"
    assert _rc == 601
    dataqa merge, into("`PL'")
    assert r(n_shards) == `NW'
    * the union of the shards, in worker order, is the merged ledger
    preserve
    clear
    forvalues k = 1/`NW' {
        quietly append using "`W'/par.shard-w`k'.dta"
    }
    quietly generate long o = _n
    quietly drop seq
    tempfile un
    quietly save "`un'"
    quietly use "`PL'", clear
    quietly generate long o = _n
    assert seq[_n] >= seq[_n - 1] if _n > 1
    quietly summarize seq
    assert r(min) == 1 & r(max) == `NW' * `NC'
    quietly drop seq
    unab v1 : _all
    quietly describe using "`un'", varlist
    assert "`v1'" == "`r(varlist)'"
    quietly cf _all using "`un'"
    restore
    * the independent reference: the same calls run one after another in a
    * plain (non-worker) session; every column but stamp, seq and worker
    * equals the merged ledger row for row
    local RF "`W'/ref.dta"
    capture erase "`RF'"
    dataqa set ledger("`RF'") run(par) collect
    forvalues k = 1/`NW' {
        forvalues c = 1/`NC' {
            sysuse auto, clear
            local hi = cond(mod(`c', 3) == 0, 19, 25)
            quietly dataprobe, gatesonly isid(make) bands(stat(mean mpg 18 `hi')) name(w`k'_d`c')
        }
    }
    dataqa set clear
    preserve
    quietly use "`RF'", clear
    quietly count if status == "fail"
    local nfail = r(N)
    assert `nfail' == `NW' * floor(`NC' / 3)
    quietly drop stamp
    quietly save "`RF'", replace
    quietly use "`PL'", clear
    quietly drop stamp worker
    unab v1 : _all
    quietly describe using "`RF'", varlist
    assert "`v1'" == "`r(varlist)'"
    quietly cf _all using "`RF'"
    restore
    capture dataqa assert using "`PL'", run(par)
    assert _rc == 9 & r(n_failed) == `nfail'
}
local w4rc = _rc
capture restore
* no child left: every pid this suite started has exited (one still alive
* after its done file and a pause is stopped and fails the test)
sleep 2000
forvalues k = 1/`NW' {
    capture confirm file "`BAR'/pid`k'.txt"
    if !_rc {
        tempname ph
        file open `ph' using "`BAR'/pid`k'.txt", read text
        file read `ph' pid
        file close `ph'
        shell ps -p `pid' -o comm= | grep -q stata && echo alive > "`BAR'/alive`k'.txt" && kill `pid'
        capture confirm file "`BAR'/alive`k'.txt"
        if !_rc & !`w4rc' local w4rc = 459
    }
    else if !`w4rc' local w4rc = 601
}
_ft `w4rc' "W4 four concurrent Stata workers write shards at once; the merged ledger is the union of the shards and equals a sequential plain-session reference"

macro drop DATAMAP_DQ
sysdir set PLUS `"`_old_plus'"'
sysdir set PERSONAL `"`_old_personal'"'
discard
capture mata: mata drop _ft_fread() _ft_has() _ft_dfs() _ft_reader() _ft_props() _ft_exhaust() _ft_selftest()
display as result "Results: $PASS/$TC passed, $FAIL failed"
display "RESULT: test_datamap_v210_flowshards tests=$TC pass=$PASS fail=$FAIL"
log close main
if $FAIL > 0 exit 1
