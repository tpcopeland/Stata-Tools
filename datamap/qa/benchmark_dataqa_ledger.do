clear all
set more off
version 16.0
set linesize 255

* benchmark_dataqa_ledger.do - datamap 2.1.0 P2: dataqa report, assert,
* compare, and export on a 20,000-row ledger.  Benchmark lane only (timing
* depends on the machine): run from its own lane with set processors 1 in a
* profile.do in the working directory.  Timing only; never part of quick,
* core, or full, and never a correctness gate.
*
* Design: a synthetic ledger in the dataprobe ledger schema, generated from
* seed 20261115: two runs (base, cur) of 10,000 rows each, 1,000 calls of 10
* rows over 50 datasets, five families (stat rows feed the stattol pass),
* by() groups on 1 row in 13, bands on 1 in 17.  cur has about 5% failed rows,
* 4 call errors, N and stat changes on about 1 row in 40, 50 rows of a new
* by() group, and 100 baseline gates it no longer has.  Every row is masked
* under mincell(5), so base is exportable.  Timed: report (bands markdown()),
* assert (halts on cur's failures; captured), compare, and export of base.
*
* Optional argument: a directory.  When given, each command's console output
* is logged there (report.log, assert.log, compare.log, export.log) beside
* the markdown register and the release copy, so two versions of the code
* can be compared byte for byte (strip the log header lines).
*
* Measured on the development machine (1 processor), seconds:
*                         2.0.0 loops    2.1.0
*   report, bands md        see qa/README.md
*   assert                  (filled in by the supervisor from the handoff)
*   compare
*   export

args outdir

local qa_dir  "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") force
discard
macro drop DATAMAP_DQ

local keep = (`"`outdir'"' != "")
if !`keep' {
    local outdir `"`c(tmpdir)'/dq_bench_`=floor(runiform() * 1e9)'"'
    capture mkdir `"`outdir'"'
}

* Synthetic ledger
set seed 20261115
local nper 10000
quietly {
    set obs `=2 * `nper''
    generate long _r = mod(_n - 1, `nper') + 1
    generate strL run = cond(_n <= `nper', "base", "cur")
    generate str19 stamp = "2026-11-15_10:00:00"
    generate long seq = ceil(_r / 10)
    generate strL dataset = "ds" + string(mod(seq, 50), "%02.0f")
    generate strL scope = ""
    generate str32 family = word("rule inrange stat notmissing allowed", 1 + mod(_r, 5))
    generate strL label = "g" + string(_r)
    generate strL variable = "x" + string(mod(_r, 7))
    generate strL grp = ""
    replace grp = "by(site | site=" + string(mod(_r, 4)) + ")" if mod(_r, 13) == 0
    generate str10 kind = "invariant"
    replace kind = "band" if mod(_r, 17) == 0
    generate str8 status = "pass"
    replace status = "fail" if run == "cur" & runiform() < 0.05
    replace status = "warn" if kind == "band" & status == "fail"
    generate double n_scope = 1000 + mod(_r, 97)
    replace n_scope = n_scope * 1.2 if run == "cur" & mod(_r, 40) == 0
    generate double observed_num = cond(family == "stat", 10 + mod(_r, 11) / 10, 0)
    replace observed_num = observed_num * 1.5 if run == "cur" & family == "stat" & mod(_r, 40) == 5
    replace observed_num = cond(status == "fail", 3, observed_num) if family != "stat"
    generate strL observed = cond(family == "stat", strofreal(observed_num), string(observed_num) + " violations")
    generate strL expected = cond(family == "stat", "[5, 20]", "0 violations")
    generate str12 version = "2.0.0"
    generate strL signature = ""
    generate byte masked = 1
    generate int mincell = 5
    generate double minshown = .
    generate byte obs_masked = 0
    generate strL message = family + "(" + label + "): " + observed
    * cur: 4 call errors, 50 rows of a new by() group, 100 gates renamed
    replace status = "error" if run == "cur" & inlist(_r, 2501, 5002, 7503, 9904)
    replace family = "call" if status == "error"
    replace observed_num = 198 if status == "error"
    replace grp = "by(site | site=9)" if run == "cur" & mod(_r, 13) == 0 & _r <= 650
    replace label = label + "b" if run == "cur" & mod(_r, 100) == 50
    drop _r
}
tempfile ledger
quietly save `"`ledger'"'
display as text "ledger: " _N " rows"

capture program drop _bench_log
program define _bench_log
    args action file
    if "`action'" == "on" quietly log using `"`file'"', text replace name(_bench)
    else quietly log close _bench
end

timer clear
_bench_log on `"`outdir'/report.log"'
timer on 1
dataqa report using `"`ledger'"', bands markdown(`"`outdir'/register.md"') replace
timer off 1
_bench_log off

_bench_log on `"`outdir'/assert.log"'
timer on 2
capture noisily dataqa assert using `"`ledger'"', run(cur) baseline(base)
local arc = _rc
timer off 2
_bench_log off

_bench_log on `"`outdir'/compare.log"'
timer on 3
dataqa compare using `"`ledger'"', run(cur) baseline(base)
timer off 3
_bench_log off

_bench_log on `"`outdir'/export.log"'
timer on 4
dataqa export using `"`ledger'"', run(base) saving(`"`outdir'/release.dta"') replace
timer off 4
_bench_log off

quietly timer list
display as text "assert rc (expected 9): `arc'"
display as text "BENCH report  " %8.2f r(t1)
display as text "BENCH assert  " %8.2f r(t2)
display as text "BENCH compare " %8.2f r(t3)
display as text "BENCH export  " %8.2f r(t4)
if !`keep' {
    foreach f in report.log assert.log compare.log export.log register.md release.dta {
        capture erase `"`outdir'/`f'"'
    }
    capture rmdir `"`outdir'"'
}
display "RESULT: benchmark_dataqa_ledger tests=0 pass=0 fail=0"
