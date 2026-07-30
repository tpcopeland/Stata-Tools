* benchmark_tvmerge_pipeline.do
* Registered benchmark for the tvmerge merge pipeline.
*
* Covers the tvmerge scope of Section 7.1 of the tvtools single-pass plan:
*   case 3  tvmerge with two and three sources
*   case 4  tvmerge with sparse, moderate, and dense overlap output
*   paired control: file inputs vs frames() inputs built from byte-identical
*                   data, which isolates input serialisation from merge work
*
* 7.1 cases 1, 2, 5, 6, and 7 (tvweight IPCW end to end, tvevent, default
* categorical tvexpose, and the end-to-end construction chain) are NOT here.
* They gate Phases 2 and 3 and are still owed. The tvweight grouped product
* has its own registered benchmark, benchmark_tvweight_cumprod.do.
*
* Manually invoked; deliberately NOT part of any correctness lane and not in
* qa/_tvtools_qa_manifest.do. It emits BENCH: lines, never a RESULT: line, and
* never a timing assertion.
*
* Usage (one fresh Stata process per invocation, run serially):
*   stata-mp -b do benchmark_tvmerge_pipeline.do <case> <scale> <rep>
*     case   two | three | sparse | moderate | dense | frames
*     scale  master rows to generate (default 20000)
*     rep    repetition index; odd/even flips execution order where a case
*            runs a pair (default 1)
*
* An output-sensitive merge is meaningless without K, the number of emitted
* pairs, so every BENCH: line reports M, U, K, and the output row count
* alongside elapsed time. Peak resident memory is not measured from inside
* Stata: wrap the process in /usr/bin/time -v, one implementation per process.
*
* Driver for a paired sweep (serial, fresh process per run; rep 0 discarded):
*   for c in two three sparse moderate dense frames; do
*     for r in $(seq 0 9); do
*       stata-mp -b do benchmark_tvmerge_pipeline.do $c 20000 $r
*       grep '^BENCH:' benchmark_tvmerge_pipeline.log
*     done
*   done
* Keep raw logs outside the package tree; they are not tracked.

version 16.0
clear all
set more off
set varabbrev off
set linesize 244

local case  = cond("`1'" == "", "two", "`1'")
local scale = cond("`2'" == "", 20000, real("`2'"))
local rep   = cond("`3'" == "",     1, real("`3'"))

local qadir "`c(pwd)'"
adopath ++ "`qadir'/.."

* Both seeds are set and reported: every generated tie below also carries an
* explicit original-row tie-break, so no measured result depends on sortseed.
set seed 20260730
set sortseed 20260730

local workdir "`c(tmpdir)'/tvm_bench_`c(pid)'"
capture mkdir "`workdir'"

display as text "BENCHINFO: stata=`c(stata_version)' flavor=`c(flavor)' " ///
    "edition=`c(edition_real)' processors=`c(processors)' os=`c(os)' " ///
    "machine=`c(machine_type)' case=`case' scale=`scale' rep=`rep' " ///
    "seed=20260730 sortseed=20260730"

**# ---------------------------------------------------------------------
**# Generators
**# ---------------------------------------------------------------------
* density controls how much of each person's calendar the using source covers,
* and therefore K, the emitted pair count. Overlap density is the axis that
* decides whether a merge is output-bound or input-bound.

capture program drop _bm_master
program define _bm_master
    version 16.0
    args nrows nids path
    clear
    quietly set obs `nrows'
    quietly generate long pid = 1 + mod(_n - 1, `nids')
    quietly bysort pid: generate long seq = _n
    quietly generate int a_start = 21915 + (seq - 1) * 30
    quietly generate int a_stop  = a_start + 29
    quietly generate byte drugA  = mod(seq, 3)
    quietly generate double doseA = 10 * seq
    format a_start a_stop %tdCCYY/NN/DD
    quietly drop seq
    quietly save "`path'", replace
end

capture program drop _bm_using
program define _bm_using
    version 16.0
    * bnd is the lowercase bound stem (b, c); exp is the exposure name. They
    * are passed separately because Stata variable names are case sensitive:
    * deriving both from one token silently produced B_start against a
    * b_start request, and every merge failed with r(111).
    args nrows nids width stride bnd exp path
    clear
    quietly set obs `nrows'
    quietly generate long pid = 1 + mod(_n - 1, `nids')
    quietly bysort pid: generate long seq = _n
    quietly generate int `bnd'_start = 21915 + (seq - 1) * `stride'
    quietly generate int `bnd'_stop  = `bnd'_start + `width'
    quietly generate byte `exp' = mod(seq, 2)
    format `bnd'_start `bnd'_stop %tdCCYY/NN/DD
    quietly drop seq
    quietly save "`path'", replace
end

capture program drop _bm_report
program define _bm_report
    version 16.0
    args tag secs m u k nout rc
    display "BENCH: case=`tag' rep=$BM_REP scale=$BM_SCALE " ///
        "M=`m' U=`u' K=`k' Nout=`nout' rc=`rc' seconds=`secs'"
end

global BM_REP  = `rep'
global BM_SCALE = `scale'

local nids = max(1, floor(`scale' / 10))
local mfile "`workdir'/m.dta"
local ufile "`workdir'/u.dta"
local vfile "`workdir'/v.dta"

**# ---------------------------------------------------------------------
**# Case dispatch
**# ---------------------------------------------------------------------

if "`case'" == "sparse" {
    local width  = 4
    local stride = 120
}
else if "`case'" == "dense" {
    local width  = 120
    local stride = 15
}
else {
    * moderate is also the shape used by two/three/frames
    local width  = 24
    local stride = 30
}

_bm_master `scale' `nids' "`mfile'"
_bm_using  `scale' `nids' `width' `stride' b drugB "`ufile'"
if "`case'" == "three" {
    _bm_using `scale' `nids' 40 90 c drugC "`vfile'"
}

quietly use "`mfile'", clear
local M = _N
quietly use "`ufile'", clear
local U = _N

**# --- two / sparse / moderate / dense: single file-input merge ------------
if inlist("`case'", "two", "sparse", "moderate", "dense") {
    * Warm the file cache with a discarded run so the measured pass is not
    * paying first-read cost. Timings are warm-cache and are reported as such.
    quietly use "`mfile'", clear
    capture quietly tvmerge "`mfile'" "`ufile'", id(pid) ///
        start(a_start b_start) stop(a_stop b_stop) exposure(drugA drugB)

    quietly use "`mfile'", clear
    timer clear 1
    timer on 1
    capture noisily tvmerge "`mfile'" "`ufile'", id(pid) ///
        start(a_start b_start) stop(a_stop b_stop) exposure(drugA drugB)
    local rc = _rc
    timer off 1
    quietly timer list 1
    local secs = r(t1)
    local nout = _N
    * K, the emitted pair count, is the output row count before the final
    * full-row dedup; report both so a dedup change is visible.
    _bm_report `case' `secs' `M' `U' `nout' `nout' `rc'
}

**# --- three: three-source merge -------------------------------------------
if "`case'" == "three" {
    quietly use "`mfile'", clear
    capture quietly tvmerge "`mfile'" "`ufile'" "`vfile'", id(pid) ///
        start(a_start b_start c_start) stop(a_stop b_stop c_stop) ///
        exposure(drugA drugB drugC)

    quietly use "`mfile'", clear
    timer clear 1
    timer on 1
    capture noisily tvmerge "`mfile'" "`ufile'" "`vfile'", id(pid) ///
        start(a_start b_start c_start) stop(a_stop b_stop c_stop) ///
        exposure(drugA drugB drugC)
    local rc = _rc
    timer off 1
    quietly timer list 1
    local secs = r(t1)
    local nout = _N
    _bm_report three `secs' `M' `U' `nout' `nout' `rc'
}

**# --- frames: paired file-input vs frames()-input control -----------------
* The two runs consume byte-identical data. Any difference is attributable to
* how the input is delivered, not to the merge itself. Execution order
* alternates with rep so a warm-up asymmetry cannot masquerade as a result.
if "`case'" == "frames" {
    quietly use "`mfile'", clear
    capture quietly tvmerge "`mfile'" "`ufile'", id(pid) ///
        start(a_start b_start) stop(a_stop b_stop) exposure(drugA drugB)

    local order "file frames"
    if mod(`rep', 2) == 1 local order "frames file"

    foreach which of local order {
        if "`which'" == "file" {
            quietly use "`mfile'", clear
            timer clear 2
            timer on 2
            capture noisily tvmerge "`mfile'" "`ufile'", id(pid) ///
                start(a_start b_start) stop(a_stop b_stop) ///
                exposure(drugA drugB)
            local rc = _rc
            timer off 2
            quietly timer list 2
            local secs = r(t2)
            local nout = _N
            _bm_report frames_file `secs' `M' `U' `nout' `nout' `rc'
        }
        else {
            capture frame drop bmA
            capture frame drop bmB
            frame create bmA
            frame bmA: use "`mfile'", clear
            frame create bmB
            frame bmB: use "`ufile'", clear
            clear
            timer clear 3
            timer on 3
            capture noisily tvmerge, frames(bmA bmB) id(pid) ///
                start(a_start b_start) stop(a_stop b_stop) ///
                exposure(drugA drugB)
            local rc = _rc
            timer off 3
            quietly timer list 3
            local secs = r(t3)
            local nout = _N
            _bm_report frames_frames `secs' `M' `U' `nout' `nout' `rc'
            capture frame drop bmA
            capture frame drop bmB
        }
    }
}

capture erase "`mfile'"
capture erase "`ufile'"
capture erase "`vfile'"
capture rmdir "`workdir'"
display as text "BENCHDONE"
