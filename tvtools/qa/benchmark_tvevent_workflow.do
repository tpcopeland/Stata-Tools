* benchmark_tvevent_workflow.do
* Registered benchmark for the tvevent split/segment workflow.
*
* Covers the tvevent scope of Section 7.1 of the tvtools single-pass plan:
*   case 5  tvevent with no events, boundary events, and many internal events
*   paired control: using-file inputs vs frame() inputs built from
*                   byte-identical intervals, which isolates input
*                   serialisation from segment work
*
* 7.1 cases 1, 2, 6, and 7 (tvweight IPCW end to end, default categorical
* tvexpose, and the end-to-end construction chain) are NOT here. The tvmerge
* cases live in benchmark_tvmerge_workflow.do and the tvweight grouped product
* in benchmark_tvweight_cumprod.do.
*
* Manually invoked; deliberately NOT part of any correctness lane and not in
* qa/_tvtools_qa_manifest.do. It emits BENCH: lines, never a RESULT: line, and
* never a timing assertion.
*
* Usage (one fresh Stata process per invocation, run serially):
*   stata-mp -b do benchmark_tvevent_workflow.do <case> <scale> <rep>
*     case   none | boundary | internal | dense | frame
*     scale  interval rows to generate (default 20000)
*     rep    repetition index; odd/even flips execution order where a case
*            runs a pair (default 1)
*
* tvevent is output-sensitive in the same way tvmerge is: one internal event
* turns one interval into two rows, so elapsed time without the split count is
* uninterpretable. Every BENCH: line therefore reports I (interval rows in),
* E (event rows in), S (split points discovered, from the "Splitting intervals
* for N internal events" stage), and Nout (output rows) next to elapsed time.
*
* S is not exposed in r(), so it is derived rather than parsed: for these
* generated inputs each event date is strictly inside exactly one interval, so
* the split count is the number of non-missing generated event dates. The
* derivation is asserted against Nout - I for the cases where it must hold
* exactly, which is what makes it evidence instead of a label.
*
* Peak resident memory is not measured from inside Stata: wrap the process in
* /usr/bin/time -v, one implementation per process.
*
* Driver for a paired sweep (serial, fresh process per run; rep 0 discarded):
*   for c in none boundary internal dense frame; do
*     for r in $(seq 0 9); do
*       stata-mp -b do benchmark_tvevent_workflow.do $c 20000 $r
*       grep '^BENCH:' benchmark_tvevent_workflow.log
*     done
*   done
* Keep raw logs outside the package tree; they are not tracked.

version 16.0
clear all
set more off
set varabbrev off
set linesize 244

local case  = cond("`1'" == "", "internal", "`1'")
local scale = cond("`2'" == "", 20000, real("`2'"))
local rep   = cond("`3'" == "",     1, real("`3'"))

local qadir "`c(pwd)'"
adopath ++ "`qadir'/.."

* Both seeds are set and reported. The generators below are fully
* deterministic -- no random draws at all -- so no measured result can depend
* on either seed; they are recorded for protocol compliance, not because a
* result hinges on them.
set seed 20260730
set sortseed 20260730

local workdir "`c(tmpdir)'/tve_bench_`c(pid)'"
capture mkdir "`workdir'"

* Provenance. A paired legacy/candidate sweep that runs this file from a
* directory whose parent holds no tvtools silently resolves the INSTALLED
* package for BOTH arms and reports a ratio of 1.00 with no error anywhere.
* That happened once while this benchmark was being built. Print the resolved
* path and refuse to continue if it is not the tree this invocation intended.
capture findfile tvevent.ado
if _rc {
    display as error "BENCHBAD: tvevent.ado not found on the adopath"
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
* Interval geometry is fixed: every person owns `per' consecutive 30-day
* intervals starting 01jan2020, each covering [s, s+29]. Events are placed
* relative to that geometry so the split count is known by construction rather
* than discovered from the output.

capture program drop _be_intervals
program define _be_intervals
    version 16.0
    args nrows nids path
    clear
    quietly set obs `nrows'
    quietly generate long pid = 1 + mod(_n - 1, `nids')
    quietly bysort pid: generate long seq = _n
    quietly generate int i_start = 21915 + (seq - 1) * 30
    quietly generate int i_stop  = i_start + 29
    quietly generate byte trt = mod(seq, 3)
    quietly generate double payload = 10 * seq
    format i_start i_stop %tdCCYY/NN/DD
    quietly drop seq
    quietly save "`path'", replace
end

* One event column per person, wide format.
*   kind = none      all-missing dates: no split points at all
*   kind = boundary  date == the stop of the person's first interval: flagged
*                    without a split, which is the contract that separates
*                    "matched" from "splits"
*   kind = internal  date strictly inside the person's first interval
*
* Every case runs type(recurring). Under type(single) tvevent truncates
* follow-up at the first event, so a single internal event per person collapses
* 10 intervals to 1 output row and the benchmark measures truncation rather
* than segment construction -- the first draft did exactly that and its own
* Nout guard caught it (expected 22,000, observed 2,000). Recurring retains all
* person-time, so Nout - I is exactly the split count.
capture program drop _be_events_single
program define _be_events_single
    version 16.0
    args nids kind path
    clear
    quietly set obs `nids'
    quietly generate long pid = _n
    if "`kind'" == "none"     quietly generate int evdate1 = .
    if "`kind'" == "boundary" quietly generate int evdate1 = 21915 + 29
    if "`kind'" == "internal" quietly generate int evdate1 = 21915 + 15
    format evdate1 %tdCCYY/NN/DD
    quietly save "`path'", replace
end

* Wide-format recurring events: one internal date per interval the person owns,
* so every interval in the dataset splits exactly once. This is the case that
* stresses the released joinby: a person with P intervals and P split dates
* produces P*P joined rows before the valid-split filter reduces them.
capture program drop _be_events_dense
program define _be_events_dense
    version 16.0
    args nids per path
    clear
    quietly set obs `nids'
    quietly generate long pid = _n
    forvalues k = 1/`per' {
        quietly generate int evdate`k' = 21915 + (`k' - 1) * 30 + 15
        format evdate`k' %tdCCYY/NN/DD
    }
    quietly save "`path'", replace
end

capture program drop _be_report
program define _be_report
    version 16.0
    args tag secs i e s nout rc
    display "BENCH: case=`tag' rep=$BE_REP scale=$BE_SCALE " ///
        "I=`i' E=`e' S=`s' Nout=`nout' rc=`rc' seconds=`secs'"
end

global BE_REP   = `rep'
global BE_SCALE = `scale'

* 10 intervals per person at every scale, so the joinby fan-out per person is
* held constant and scale moves the person count, not the per-person shape.
local per  = 10
local nids = max(1, floor(`scale' / `per'))
local scale = `nids' * `per'

local ifile "`workdir'/ivl.dta"
local efile "`workdir'/ev.dta"

_be_intervals `scale' `nids' "`ifile'"
quietly use "`ifile'", clear
local I = _N

**# ---------------------------------------------------------------------
**# Case dispatch
**# ---------------------------------------------------------------------

if inlist("`case'", "none", "boundary", "internal") {
    _be_events_single `nids' "`case'" "`efile'"
    quietly use "`efile'", clear
    local E = _N
    * Split points by construction: none and boundary produce zero, internal
    * produces one per person.
    local S = cond("`case'" == "internal", `nids', 0)

    * Warm the file cache with a discarded run so the measured pass is not
    * paying first-read cost. Timings are warm-cache and reported as such.
    quietly use "`efile'", clear
    capture quietly tvevent using "`ifile'", id(pid) date(evdate) ///
        start(i_start) stop(i_stop) type(recurring)

    quietly use "`efile'", clear
    timer clear 1
    timer on 1
    capture noisily tvevent using "`ifile'", id(pid) date(evdate) ///
        start(i_start) stop(i_stop) type(recurring)
    local rc = _rc
    timer off 1
    quietly timer list 1
    local secs = r(t1)
    local nout = _N
    * Every split adds exactly one row. If this does not hold, S is mislabelled
    * and the BENCH line would be reporting a number it did not measure.
    if `rc' == 0 & `nout' != `I' + `S' {
        display as error "BENCHBAD: expected Nout=`=`I' + `S'' but observed `nout'"
    }
    _be_report `case' `secs' `I' `E' `S' `nout' `rc'
}

if "`case'" == "dense" {
    _be_events_dense `nids' `per' "`efile'"
    quietly use "`efile'", clear
    local E = _N
    * One internal date per interval: every interval splits exactly once.
    local S = `I'

    quietly use "`efile'", clear
    capture quietly tvevent using "`ifile'", id(pid) date(evdate) ///
        start(i_start) stop(i_stop) type(recurring)

    quietly use "`efile'", clear
    timer clear 1
    timer on 1
    capture noisily tvevent using "`ifile'", id(pid) date(evdate) ///
        start(i_start) stop(i_stop) type(recurring)
    local rc = _rc
    timer off 1
    quietly timer list 1
    local secs = r(t1)
    local nout = _N
    if `rc' == 0 & `nout' != `I' + `S' {
        display as error "BENCHBAD: expected Nout=`=`I' + `S'' but observed `nout'"
    }
    _be_report dense `secs' `I' `E' `S' `nout' `rc'
}

**# --- frame: paired using-file vs frame() control -------------------------
* The two runs consume byte-identical intervals. Any difference is
* attributable to how the interval input is delivered, not to segment
* construction. Execution order alternates with rep so a warm-up asymmetry
* cannot masquerade as a result.
if "`case'" == "frame" {
    _be_events_single `nids' internal "`efile'"
    quietly use "`efile'", clear
    local E = _N
    local S = `nids'

    quietly use "`efile'", clear
    capture quietly tvevent using "`ifile'", id(pid) date(evdate) ///
        start(i_start) stop(i_stop) type(recurring)

    local order "file frame"
    if mod(`rep', 2) == 1 local order "frame file"

    foreach which of local order {
        if "`which'" == "file" {
            quietly use "`efile'", clear
            timer clear 2
            timer on 2
            capture noisily tvevent using "`ifile'", id(pid) date(evdate) ///
                start(i_start) stop(i_stop) type(recurring)
            local rc = _rc
            timer off 2
            quietly timer list 2
            local secs = r(t2)
            local nout = _N
            _be_report frame_file `secs' `I' `E' `S' `nout' `rc'
        }
        else {
            capture frame drop beI
            frame create beI
            frame beI: use "`ifile'", clear
            quietly use "`efile'", clear
            timer clear 3
            timer on 3
            capture noisily tvevent, frame(beI) id(pid) date(evdate) ///
                start(i_start) stop(i_stop) type(recurring)
            local rc = _rc
            timer off 3
            quietly timer list 3
            local secs = r(t3)
            local nout = _N
            _be_report frame_frame `secs' `I' `E' `S' `nout' `rc'
            capture frame drop beI
        }
    }
}

capture erase "`ifile'"
capture erase "`efile'"
capture rmdir "`workdir'"
display as text "BENCHDONE"
