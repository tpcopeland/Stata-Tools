* benchmark_tvweight_cumprod.do
* Registered benchmark for the tvweight within-person cumulative product.
*
* Manually invoked; deliberately NOT part of any correctness lane and not in
* qa/_tvtools_qa_manifest.do. It emits timings, never a RESULT: line, and never
* a timing assertion.
*
* Compares three implementations of the same grouped product:
*   legacy  the released 1.9.0 preserve / keep / save / restore / merge block,
*           replicated verbatim below so the comparison survives the refactor
*   candA   _tvweight_cumprod.ado (in-place Stata/MP sort + by-group recursion)
*   candB   a Mata kernel: read structural columns, order(), loop, st_store()
*
* Usage (one fresh Stata process per invocation, run serially):
*   stata-mp -b do benchmark_tvweight_cumprod.do <nrows> <nids> <rep> [impl]
*     nrows  total observations            (default 100000)
*     nids   distinct persons              (default  10000)
*     rep    repetition index; odd/even flips the execution order (default 1)
*     impl   all | legacy | candA | candB  (default all)
*
* Use impl=all for paired timing (identical data, alternating order). Use a
* single impl under `/usr/bin/time -v` when peak resident memory is wanted, so
* one process holds one implementation.
*
* Driver for a full paired sweep (serial, fresh process per pair):
*   for n in 10000 100000 1000000; do
*     for r in $(seq 0 9); do
*       stata-mp -b do benchmark_tvweight_cumprod.do $n $((n/10)) $r
*       grep '^BENCH:' benchmark_tvweight_cumprod.log
*     done
*   done
* Repetition 0 is the warm-up and is discarded. Keep raw logs outside the
* package tree; they are not tracked.

version 16.0
clear all
set more off
set varabbrev off
set linesize 244

local nrows = cond("`1'" == "", 100000, real("`1'"))
local nids  = cond("`2'" == "",  10000, real("`2'"))
local rep   = cond("`3'" == "",      1, real("`3'"))
local impl  = cond("`4'" == "",  "all", "`4'")

* Resolve the package directory from this script's location so the benchmark
* runs from a scratch copy without editing paths.
local qadir "`c(pwd)'"
capture ado uninstall tvtools
while !_rc {
    capture ado uninstall tvtools
}
adopath ++ "`qadir'/.."

**# Released 1.9.0 algorithm, replicated for comparison
capture program drop _bench_legacy_cumprod
program define _bench_legacy_cumprod
    version 16.0
    syntax varname(numeric) [if] [in], ID(varname) TIME(varname) GENerate(name)
    local input `varlist'
    marksample touse, novarlist
    quietly {
        tempvar _origorder
        generate long `_origorder' = _n
        preserve
        keep if `touse'
        sort `id' `time' `_origorder'
        by `id': generate double `generate' = `input' if _n == 1
        by `id': replace `generate' = `generate'[_n-1] * `input' if _n > 1
        keep `_origorder' `generate'
        tempfile _cumvals
        save `_cumvals'
        restore
        merge 1:1 `_origorder' using `_cumvals', nogenerate
        drop `_origorder'
    }
end

**# Candidate B: Mata kernel
capture mata: mata drop _tvp_bench_cumprod()
mata:
mata set matastrict on
void _tvp_bench_cumprod(string scalar vgid, string scalar vtime,
    string scalar vrow, string scalar vtouse, string scalar vin,
    string scalar vout)
{
    real matrix    X, K
    real colvector sel, ord, out, obs
    real scalar    i, n, r, g, prev

    X = st_data(., (vgid, vtime, vrow, vtouse, vin))
    sel = selectindex(X[., 4] :== 1)
    if (rows(sel) == 0) return
    K   = X[sel, (1, 2, 3)]
    ord = order(K, (1, 2, 3))
    n   = rows(ord)
    out = J(n, 1, .)
    obs = J(n, 1, .)
    g    = .
    prev = .
    for (i = 1; i <= n; i++) {
        r = ord[i]
        if (K[r, 1] != g) {
            g    = K[r, 1]
            prev = X[sel[r], 5]
        }
        else prev = prev * X[sel[r], 5]
        out[i] = prev
        obs[i] = sel[r]
    }
    st_store(obs, vout, out)
}
end

capture program drop _bench_candb_cumprod
program define _bench_candb_cumprod
    version 16.0
    syntax varname(numeric) [if] [in], ID(varname) TIME(varname) GENerate(name)
    local input `varlist'
    marksample touse, novarlist
    quietly {
        tempvar _row
        generate long `_row' = _n
        generate double `generate' = .
        mata: _tvp_bench_cumprod("`id'", "`time'", "`_row'", "`touse'", ///
            "`input'", "`generate'")
    }
end

**# Deterministic input
set seed 20260729
set sortseed 20260729
quietly set obs `nrows'
quietly generate long pid = 1 + mod(_n - 1, `nids')
quietly bysort pid: generate int t = _n
quietly generate double w = 0.85 + runiform() * 0.3
* Exclude ~2% of rows, including interior periods, so the touse-gap path is
* exercised at scale rather than only in the unit tests.
quietly generate byte keep_it = runiform() > 0.02
* Shuffle so no implementation benefits from a pre-sorted input.
quietly generate double _shuf = runiform()
sort _shuf
quietly drop _shuf
quietly generate long rowid = _n

local run_legacy = ("`impl'" == "all" | "`impl'" == "legacy")
local run_a      = ("`impl'" == "all" | "`impl'" == "candA")
local run_b      = ("`impl'" == "all" | "`impl'" == "candB")

* Alternate execution order across repetitions so a warm-cache or
* allocator-growth advantage cannot attach itself to one implementation.
local order = cond(mod(`rep', 2) == 0, "legacy-first", "candidate-first")

timer clear
local t_legacy = .
local t_a      = .
local t_b      = .

capture program drop _bench_one
program define _bench_one
    version 16.0
    args which slot
    if "`which'" == "legacy" {
        timer on `slot'
        _bench_legacy_cumprod w if keep_it, id(pid) time(t) generate(cum_`which')
        timer off `slot'
    }
    else if "`which'" == "candA" {
        timer on `slot'
        _tvweight_cumprod w if keep_it, id(pid) time(t) generate(cum_`which')
        timer off `slot'
    }
    else {
        timer on `slot'
        _bench_candb_cumprod w if keep_it, id(pid) time(t) generate(cum_`which')
        timer off `slot'
    }
    quietly assert rowid == _n
end

if "`order'" == "legacy-first" {
    if `run_legacy' _bench_one legacy 1
    if `run_a'      _bench_one candA  2
    if `run_b'      _bench_one candB  3
}
else {
    if `run_a'      _bench_one candA  2
    if `run_b'      _bench_one candB  3
    if `run_legacy' _bench_one legacy 1
}

quietly timer list
if `run_legacy' local t_legacy = r(t1)
if `run_a'      local t_a      = r(t2)
if `run_b'      local t_b      = r(t3)

**# Correctness guard: a fast wrong answer is not a result
local maxdiff_a = .
local maxdiff_b = .
local badmiss_a = .
local badmiss_b = .
if `run_legacy' & `run_a' {
    quietly generate double _da = abs(cum_legacy - cum_candA)
    quietly summarize _da, meanonly
    local maxdiff_a = cond(r(N) == 0, 0, r(max))
    quietly count if missing(cum_legacy) != missing(cum_candA)
    local badmiss_a = r(N)
    quietly drop _da
}
if `run_legacy' & `run_b' {
    quietly generate double _db = abs(cum_legacy - cum_candB)
    quietly summarize _db, meanonly
    local maxdiff_b = cond(r(N) == 0, 0, r(max))
    quietly count if missing(cum_legacy) != missing(cum_candB)
    local badmiss_b = r(N)
    quietly drop _db
}

quietly count if keep_it
local n_sel = r(N)

local ratio_a = .
local ratio_b = .
if `t_legacy' < . & `t_a' < . & `t_legacy' > 0 local ratio_a = `t_a' / `t_legacy'
if `t_legacy' < . & `t_b' < . & `t_legacy' > 0 local ratio_b = `t_b' / `t_legacy'

display as text ""
display as text "BENCH: n=`nrows' ids=`nids' selected=`n_sel' rep=`rep' " ///
    "order=`order' impl=`impl' legacy=`t_legacy' candA=`t_a' candB=`t_b' " ///
    "ratioA=`ratio_a' ratioB=`ratio_b' maxdiffA=`maxdiff_a' " ///
    "maxdiffB=`maxdiff_b' missmismatchA=`badmiss_a' missmismatchB=`badmiss_b'"
display as text "ENV: stata=`c(stata_version)' flavour=`c(flavor)' " ///
    "edition=`c(edition_real)' processors=`c(processors)' os=`c(os)'"
