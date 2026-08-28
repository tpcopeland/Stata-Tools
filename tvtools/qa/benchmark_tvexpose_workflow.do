* benchmark_tvexpose_workflow.do
* Registered benchmark for the tvexpose categorical construction workflow and
* for the end-to-end tvtools construction chain.
*
* Covers the tvexpose scope of Section 7.1 of the tvtools single-pass plan:
*   case 6  default categorical tvexpose with no retained episodes after
*           clipping, sparse episodes, and many clean non-overlapping episodes
*   case 7  the end-to-end construction chain
*                (tvexpose -> tvexpose -> tvmerge -> tvevent)
*   paired control: default caller replacement vs frameout() output on
*                   byte-identical inputs, which isolates the output commit
*                   from the construction work
*
* 7.1 cases 1 and 2 (tvweight cumulative IPTW with and without IPCW) are NOT
* here. tvmerge lives in benchmark_tvmerge_workflow.do, tvevent in
* benchmark_tvevent_workflow.do, and the tvweight grouped product in
* benchmark_tvweight_cumprod.do.
*
* Manually invoked; deliberately NOT part of any correctness lane and not in
* qa/_tvtools_qa_manifest.do. The shape case is the registered algorithmic
* scaling gate; ordinary cases emit timings without wall-clock thresholds.
*
* Usage (one fresh Stata process per invocation, run serially):
*   stata-mp -b do benchmark_tvexpose_workflow.do <case> <scale> <rep>
*     case   clipout | sparse | dense | frameout | chain | shape
*     scale  source episode rows to generate (default 20000)
*     rep    repetition index; odd/even flips execution order where a case
*            runs a pair (default 1)
*
* tvexpose is output-sensitive: one source episode inside a window becomes
* between one and three output rows depending on where the study bounds fall,
* so elapsed time without the output row count is uninterpretable. Every
* BENCH: line therefore reports M (master persons in), E (source episode rows
* in), and Nout (output rows) next to elapsed time.
*
* Nout is known by construction for every case, and asserted. That assertion
* is what makes the geometry evidence rather than a label: if the generator
* and the command disagree about how many rows the workload produces, the
* BENCH line would otherwise report a perfectly stable time for work nobody
* characterised. The tvevent benchmark's equivalent guard caught exactly that
* defect in its own first draft.
*
* Peak resident memory is not measured from inside Stata: wrap the process in
* /usr/bin/time -v, one implementation per process.
*
* Driver for a paired sweep (serial, fresh process per run; rep 0 discarded):
*   for c in clipout sparse dense frameout chain; do
*     for r in $(seq 0 9); do
*       stata-mp -b do benchmark_tvexpose_workflow.do $c 20000 $r
*       grep '^BENCH:' benchmark_tvexpose_workflow.log
*     done
*   done
* Keep raw logs outside the package tree; they are not tracked.

version 16.0
clear all
set more off
set varabbrev off
set linesize 244
set processors 1

local case  = cond("`1'" == "", "dense", "`1'")
local scale = cond("`2'" == "", 20000, real("`2'"))
local rep   = cond("`3'" == "",     1, real("`3'"))

local qadir "`c(pwd)'"
capture ado uninstall tvtools
while !_rc {
    capture ado uninstall tvtools
}
adopath ++ "`qadir'/.."

* Both seeds are set and reported. The generators below are fully
* deterministic -- no random draws at all -- so no measured result can depend
* on either seed; they are recorded for protocol compliance, not because a
* result hinges on them.
set seed 20260730
set sortseed 20260730

local workdir "`c(tmpdir)'/tvx_bench_`c(pid)'"
capture mkdir "`workdir'"

* Provenance. A paired legacy/candidate sweep that runs this file from a
* directory whose parent holds no tvtools silently resolves the INSTALLED
* package for BOTH arms and reports a ratio of 1.00 with no error anywhere.
* That happened once while the tvevent benchmark was being built. Print the
* resolved path and refuse to continue if it is not the tree this invocation
* intended.
capture findfile tvexpose.ado
if _rc {
    display as error "BENCHBAD: tvexpose.ado not found on the adopath"
    exit 111
}
local _ado "`r(fn)'"
display as text "BENCHADO: `_ado'"
if strpos("`_ado'", "`qadir'/..") == 0 & strpos("`_ado'", "`qadir'") == 0 {
    * Resolve both sides to absolute form before comparing: `qadir'/.. is not
    * textually equal to the parent path findfile returns.
    mata: st_local("_abs", pathresolve("`qadir'/..", ""))
    if strpos("`_ado'", "`_abs'") == 0 {
        display as error "BENCHBAD: resolved `_ado', expected a file under `_abs'"
        exit 111
    }
}

display as text "BENCHINFO: stata=`c(stata_version)' flavor=`c(flavor)' " ///
    "edition=`c(edition_real)' processors=`c(processors)' os=`c(os)' " ///
    "machine=`c(machine_type)' case=`case' scale=`scale' rep=`rep' " ///
    "seed=20260730 sortseed=20260730"

**# ---------------------------------------------------------------------
**# Generators
**# ---------------------------------------------------------------------
* Geometry is fixed so that scale moves the PERSON count, never the
* per-person shape. Every generated workload satisfies the Section 11.1
* eligibility predicate except where a case says otherwise: whole-number
* category codes, no code equal to reference(0), and no within-person overlap
* of any kind after clipping.
*
* Calendar anchor: 21915 = 01jan2020. Every window is [21915, 22120].

capture program drop _bx_master
program define _bx_master
    version 16.0
    args nids path
    clear
    quietly set obs `nids'
    quietly generate long pid = _n
    quietly generate int s_entry = 21915
    quietly generate int s_exit  = 22120
    format s_entry s_exit %tdCCYY/NN/DD
    quietly save "`path'", replace
end

* `per' episodes per person, each 30 days long, separated by 10-day gaps, the
* block sitting strictly inside the window. Category codes alternate 1/2 and
* never take the reference value.
*
*   episode k: [21920 + 40*(k-1), 21949 + 40*(k-1)]
*
* Output per person: 1 baseline + `per' episodes + (`per'-1) gaps + 1 post.
capture program drop _bx_episodes
program define _bx_episodes
    version 16.0
    args nids per path
    clear
    quietly set obs `=`nids' * `per''
    quietly generate long pid = 1 + floor((_n - 1) / `per')
    quietly generate long seq = 1 + mod(_n - 1, `per')
    quietly generate int e_start = 21920 + (seq - 1) * 40
    quietly generate int e_stop  = e_start + 29
    quietly generate byte drug = 1 + mod(seq, 2)
    label define _druglbl 1 "low" 2 "high"
    label values drug _druglbl
    format e_start e_stop %tdCCYY/NN/DD
    quietly drop seq
    quietly save "`path'", replace
end

* One episode per person, entirely before the window: every row clips out and
* every person collapses to a single reference row. This is the case that
* isolates fixed per-person overhead from episode work.
capture program drop _bx_clipout
program define _bx_clipout
    version 16.0
    args nids path
    clear
    quietly set obs `nids'
    quietly generate long pid = _n
    quietly generate int e_start = 21000
    quietly generate int e_stop  = 21100
    quietly generate byte drug = 1
    format e_start e_stop %tdCCYY/NN/DD
    quietly save "`path'", replace
end

* Event dates for the chain case: one internal date per person, placed inside
* the first episode so the final tvevent stage actually splits. The column is
* evdate1 because type(recurring) reads wide-format evdate1, evdate2, ...
capture program drop _bx_events
program define _bx_events
    version 16.0
    args nids path
    clear
    quietly set obs `nids'
    quietly generate long id = _n
    quietly generate int evdate1 = 21930
    format evdate1 %tdCCYY/NN/DD
    quietly save "`path'", replace
end

capture program drop _bx_report
program define _bx_report
    version 16.0
    args tag secs m e nout rc
    display "BENCH: case=`tag' rep=$BX_REP scale=$BX_SCALE " ///
        "M=`m' E=`e' Nout=`nout' rc=`rc' seconds=`secs'"
end

capture program drop _bx_time
program define _bx_time, rclass
    version 16.0
    args tag mstfile expfile opts
    quietly use "`mstfile'", clear
    capture quietly tvexpose using "`expfile'", id(pid) start(e_start) ///
        stop(e_stop) exposure(drug) reference(0) entry(s_entry) exit(s_exit) `opts'
    quietly use "`mstfile'", clear
    timer clear 91
    timer on 91
    capture noisily tvexpose using "`expfile'", id(pid) start(e_start) ///
        stop(e_stop) exposure(drug) reference(0) entry(s_entry) exit(s_exit) `opts'
    local rc = _rc
    timer off 91
    quietly timer list 91
    return scalar seconds = r(t91)
    return scalar rc = `rc'
    return scalar Nout = _N
end

global BX_REP   = `rep'
global BX_SCALE = `scale'

local mfile "`workdir'/mst.dta"
local efile "`workdir'/exp.dta"
local bfile "`workdir'/exp_b.dta"
local vfile "`workdir'/ev.dta"

**# ---------------------------------------------------------------------
**# Case dispatch
**# ---------------------------------------------------------------------

**# --- clipout: a non-empty source whose every row clips out ---------------
if "`case'" == "clipout" {
    local nids = max(1, `scale')
    local E    = `nids'
    _bx_master   `nids' "`mfile'"
    _bx_clipout  `nids' "`efile'"
    local expected = `nids'

    * Warm the file cache with a discarded run so the measured pass is not
    * paying first-read cost. Timings are warm-cache and reported as such.
    quietly use "`mfile'", clear
    capture quietly tvexpose using "`efile'", id(pid) start(e_start) ///
        stop(e_stop) exposure(drug) reference(0) entry(s_entry) exit(s_exit)

    quietly use "`mfile'", clear
    timer clear 1
    timer on 1
    capture noisily tvexpose using "`efile'", id(pid) start(e_start) ///
        stop(e_stop) exposure(drug) reference(0) entry(s_entry) exit(s_exit)
    local rc = _rc
    timer off 1
    quietly timer list 1
    local secs = r(t1)
    local nout = _N
    if `rc' == 0 & `nout' != `expected' {
        display as error "BENCHBAD: expected Nout=`expected' but observed `nout'"
    }
    _bx_report clipout `secs' `nids' `E' `nout' `rc'
}

**# --- sparse: one episode per person -------------------------------------
if "`case'" == "sparse" {
    local nids = max(1, `scale')
    local E    = `nids'
    _bx_master   `nids' "`mfile'"
    _bx_episodes `nids' 1 "`efile'"
    * 1 baseline + 1 episode + 0 gaps + 1 post.
    local expected = `nids' * 3

    quietly use "`mfile'", clear
    capture quietly tvexpose using "`efile'", id(pid) start(e_start) ///
        stop(e_stop) exposure(drug) reference(0) entry(s_entry) exit(s_exit)

    quietly use "`mfile'", clear
    timer clear 1
    timer on 1
    capture noisily tvexpose using "`efile'", id(pid) start(e_start) ///
        stop(e_stop) exposure(drug) reference(0) entry(s_entry) exit(s_exit)
    local rc = _rc
    timer off 1
    quietly timer list 1
    local secs = r(t1)
    local nout = _N
    if `rc' == 0 & `nout' != `expected' {
        display as error "BENCHBAD: expected Nout=`expected' but observed `nout'"
    }
    _bx_report sparse `secs' `nids' `E' `nout' `rc'
}

**# --- dense: five clean non-overlapping episodes per person ---------------
if "`case'" == "dense" {
    local per  = 5
    local nids = max(1, floor(`scale' / `per'))
    local E    = `nids' * `per'
    _bx_master   `nids' "`mfile'"
    _bx_episodes `nids' `per' "`efile'"
    * 1 baseline + `per' episodes + (`per'-1) gaps + 1 post.
    local expected = `nids' * (2 * `per' + 1)

    quietly use "`mfile'", clear
    capture quietly tvexpose using "`efile'", id(pid) start(e_start) ///
        stop(e_stop) exposure(drug) reference(0) entry(s_entry) exit(s_exit)

    quietly use "`mfile'", clear
    timer clear 1
    timer on 1
    capture noisily tvexpose using "`efile'", id(pid) start(e_start) ///
        stop(e_stop) exposure(drug) reference(0) entry(s_entry) exit(s_exit)
    local rc = _rc
    timer off 1
    quietly timer list 1
    local secs = r(t1)
    local nout = _N
    if `rc' == 0 & `nout' != `expected' {
        display as error "BENCHBAD: expected Nout=`expected' but observed `nout'"
    }
    _bx_report dense `secs' `nids' `E' `nout' `rc'
}

**# --- frameout: paired caller-replacement vs frameout() control ----------
* The two runs consume byte-identical inputs and build the same result. Any
* difference is attributable to how the result is COMMITTED -- replacing the
* caller's data versus copying into a named frame and reloading the caller's
* snapshot -- not to construction. Execution order alternates with rep so a
* warm-up asymmetry cannot masquerade as a result.
if "`case'" == "frameout" {
    local per  = 5
    local nids = max(1, floor(`scale' / `per'))
    local E    = `nids' * `per'
    _bx_master   `nids' "`mfile'"
    _bx_episodes `nids' `per' "`efile'"
    local expected = `nids' * (2 * `per' + 1)

    quietly use "`mfile'", clear
    capture quietly tvexpose using "`efile'", id(pid) start(e_start) ///
        stop(e_stop) exposure(drug) reference(0) entry(s_entry) exit(s_exit)

    local order "caller frame"
    if mod(`rep', 2) == 1 local order "frame caller"

    foreach which of local order {
        if "`which'" == "caller" {
            quietly use "`mfile'", clear
            timer clear 2
            timer on 2
            capture noisily tvexpose using "`efile'", id(pid) start(e_start) ///
                stop(e_stop) exposure(drug) reference(0) entry(s_entry) ///
                exit(s_exit)
            local rc = _rc
            timer off 2
            quietly timer list 2
            local secs = r(t2)
            local nout = _N
            if `rc' == 0 & `nout' != `expected' {
                display as error "BENCHBAD: caller arm expected Nout=`expected' but observed `nout'"
            }
            _bx_report frameout_caller `secs' `nids' `E' `nout' `rc'
        }
        else {
            capture frame drop bxout
            quietly use "`mfile'", clear
            timer clear 3
            timer on 3
            capture noisily tvexpose using "`efile'", id(pid) start(e_start) ///
                stop(e_stop) exposure(drug) reference(0) entry(s_entry) ///
                exit(s_exit) frameout(bxout)
            local rc = _rc
            timer off 3
            quietly timer list 3
            local secs = r(t3)
            local nout = 0
            capture frame bxout: local nout = _N
            if `rc' == 0 & `nout' != `expected' {
                display as error "BENCHBAD: frame arm expected Nout=`expected' but observed `nout'"
            }
            _bx_report frameout_frame `secs' `nids' `E' `nout' `rc'
            capture frame drop bxout
        }
    }
}

**# --- chain: the end-to-end construction chain (7.1 case 7) --------------
* tvexpose (source A) -> tvexpose (source B) -> tvmerge -> tvevent, with every
* intermediate result held in a frame. The reported time is the WHOLE chain;
* the per-stage attribution is deliberately not claimed, because the stages
* have different output cardinalities and a single elapsed number cannot be
* apportioned between them without measuring each separately.
if "`case'" == "chain" {
    local per  = 3
    local nids = max(1, floor(`scale' / `per'))
    local E    = `nids' * `per'
    _bx_master   `nids' "`mfile'"
    _bx_episodes `nids' `per' "`efile'"
    _bx_events   `nids' "`vfile'"

    * Source B is source A shifted by 20 days, which produces a genuinely
    * different tiling for tvmerge to align rather than a copy.
    quietly use "`efile'", clear
    quietly replace e_start = e_start + 20
    quietly replace e_stop  = e_stop  + 20
    quietly replace e_stop  = 22120 if e_stop > 22120
    quietly drop if e_start > 22120
    quietly rename drug drug2
    quietly save "`bfile'", replace

    capture frame drop bxA
    capture frame drop bxB
    capture frame drop bxM
    quietly use "`mfile'", clear
    capture quietly tvexpose using "`efile'", id(pid) start(e_start) ///
        stop(e_stop) exposure(drug) reference(0) entry(s_entry) exit(s_exit) ///
        frameout(bxA)
    capture frame drop bxA

    quietly use "`mfile'", clear
    timer clear 4
    timer on 4
    capture noisily {
        tvexpose using "`efile'", id(pid) start(e_start) stop(e_stop) ///
            exposure(drug) reference(0) entry(s_entry) exit(s_exit) ///
            frameout(bxA)
        tvexpose using "`bfile'", id(pid) start(e_start) stop(e_stop) ///
            exposure(drug2) reference(0) entry(s_entry) exit(s_exit) ///
            frameout(bxB)
        * tvexpose renames the structural bounds back to the caller's own
        * start()/stop() option names on commit, so the frames it produced
        * carry e_start/e_stop, not start/stop.
        tvmerge, frames(bxA bxB) id(pid) start(e_start e_start) ///
            stop(e_stop e_stop) exposure(tv_drug tv_drug2) ///
            frameout(bxM) replace
        * tvmerge, unlike tvexpose, does NOT rename its structural columns
        * back to the caller's option names: its output frame carries id,
        * start, and stop whatever id() was passed. The chain therefore keys
        * the final stage on id, not pid.
        use "`vfile'", clear
        tvevent, frame(bxM) id(id) date(evdate) start(start) stop(stop) ///
            type(recurring)
    }
    local rc = _rc
    timer off 4
    quietly timer list 4
    local secs = r(t4)
    local nout = _N
    * No closed-form Nout for the chain: the merge intersects two different
    * tilings. Report the observed count and do not assert a number the
    * generator cannot predict.
    _bx_report chain `secs' `nids' `E' `nout' `rc'
    capture frame change default
    capture frame drop bxA
    capture frame drop bxB
    capture frame drop bxM
}

**# --- shape: 5x scaling for fast, forced legacy, and duration ------------
* The gate is on algorithmic shape, not an absolute elapsed-time target.
* A 5x increase in persons and episodes may take up to 5.5x elapsed time,
* allowing modest scheduler noise while rejecting superlinear regressions.
if "`case'" == "shape" {
    local small = max(100, `scale')
    local large = 5 * `small'
    tempfile _bsm _bse _blm _ble
    _bx_master `small' "`_bsm'"
    _bx_episodes `small' 5 "`_bse'"
    _bx_master `large' "`_blm'"
    _bx_episodes `large' 5 "`_ble'"

    local _bad = 0
    foreach arm in fast legacy duration {
        local _opts = cond("`arm'" == "legacy", "nofastpath", ///
            cond("`arm'" == "duration", ///
            "duration(1 3) continuousunit(years)", ""))
        _bx_time `arm'_small "`_bsm'" "`_bse'" "`_opts'"
        local _ts = r(seconds)
        local _rs = r(rc)
        local _ns = r(Nout)
        _bx_time `arm'_large "`_blm'" "`_ble'" "`_opts'"
        local _tl = r(seconds)
        local _rl = r(rc)
        local _nl = r(Nout)
        local _ratio = `_tl' / `_ts'
        display "BENCH: case=shape arm=`arm' Msmall=`small' Mlarge=`large' " ///
            "Esmall=`=`small'*5' Elarge=`=`large'*5' Nsmall=`_ns' Nlarge=`_nl' " ///
            "small_seconds=`_ts' large_seconds=`_tl' ratio=`_ratio'"
        if `_rs' | `_rl' | `_ratio' > 5.5 {
            local _bad = 1
            display as error "BENCHBAD: `arm' rc=`_rs'/`_rl' scaling=`_ratio' (>5.5)"
        }
    }
    if `_bad' exit 459
}

capture erase "`mfile'"
capture erase "`efile'"
capture erase "`bfile'"
capture erase "`vfile'"
capture rmdir "`workdir'"
display as text "BENCHDONE"
