* _benchmark_finegray_zzf_cell.do - ONE clean-process measurement of one ZZF fit.
* Package: finegray
*
* Called by benchmark_finegray_zzf.do, once per (lane, n, replicate), in a FRESH
* stata-mp process.  A fresh process is not ceremony: Mata compilation, ado
* loading, and the allocator's high-water mark all persist within a process, so
* measuring several cells in one process lets the largest n contaminate every
* cell that follows it.
*
* Usage:
*   stata-mp -b do _benchmark_finegray_zzf_cell.do FIXTURE GROUPS N RUN CSV
*
* Appends one row to CSV:  groups,nn,run,secs,kb_incr
*
* RUNTIME.  The first finegray call in a process pays Mata compilation and ado
* loading.  That is a FIXED cost, so leaving it inside the timer would inflate the
* smallest n most and bias the fitted slope DOWNWARD -- flattering exactly the
* linearity claim under test.  So we run an untimed warm-up fit first.
*
* MEMORY.  VmHWM in /proc/self/status is the peak resident set size the kernel has
* seen for this process: a high-water mark, so it needs no sampling loop and
* cannot miss a transient spike between polls.  Writing "5" to /proc/self/clear_refs
* resets that mark to the current RSS, which lets us set the baseline AFTER the
* data are loaded, stset, and warmed up -- so the fit's increment is the fit's own
* peak, not the cost of holding the dataset.
*
* Two Stata string traps, both hit while building this and both silent:
*   - /proc lines are TAB-separated ("VmHWM:\t  25156 kB"), and Stata's trim() and
*     word() treat a space as whitespace but NOT a tab.  real("\t25156") is
*     MISSING, so the naive parse returns "." forever and the memory slope is
*     fitted to nothing.  Tabs are converted to spaces before parsing.
*   - Stata's `shell' does not set _rc, so if this child dies the parent sees
*     nothing.  The parent counts the rows it got against the rows it asked for.

args fixture groups nn run csv

clear all
set more off
set varabbrev off
version 16.0

* ---------------------------------------------------------------------------
* Peak RSS (kB) from /proc/self/status, and the high-water-mark reset.
* ---------------------------------------------------------------------------
capture program drop _fg_vmhwm
program define _fg_vmhwm, rclass
    tempname fh
    local kb = .
    capture file open `fh' using "/proc/self/status", read text
    if _rc {
        return scalar kb = .
        exit
    }
    file read `fh' line
    while r(eof) == 0 {
        if substr(`"`macval(line)'"', 1, 6) == "VmHWM:" {
            * Tabs first -- see the header.  word() will not split on one.
            local clean = subinstr(`"`macval(line)'"', char(9), " ", .)
            local clean = subinstr("`clean'", "VmHWM:", "", 1)
            local kb = real(word("`clean'", 1))
        }
        file read `fh' line
    }
    file close `fh'
    return scalar kb = `kb'
end

capture program drop _fg_vmreset
program define _fg_vmreset
    tempname cr
    capture file open `cr' using "/proc/self/clear_refs", write text
    if _rc exit
    file write `cr' "5" _n
    file close `cr'
end

* ---------------------------------------------------------------------------
* Untimed warm-up: pays Mata compilation and ado loading.
* ---------------------------------------------------------------------------
* Pooled weights (no truncstrata) so the warm-up is valid in EVERY lane -- a lane
* with 50 groups would trip the <20-subjects-per-stratum support check on a small
* subsample and leave Mata uncompiled, silently pushing that cost into the timer.
use "`fixture'", clear
if _N > 3000 quietly keep in 1/3000
quietly stset t, failure(anyev == 1) id(id) enter(time t0)
capture quietly finegray z1 z2, compete(status) cause(1)
if _rc {
    display as error "warm-up fit failed (rc=`=_rc'); the timed fit would pay Mata compilation"
    exit 459
}

* ---------------------------------------------------------------------------
* The measured fit.
* ---------------------------------------------------------------------------
use "`fixture'", clear
quietly stset t, failure(anyev == 1) id(id) enter(time t0)

* Baseline: data loaded, stset, Mata warm.  Reset the high-water mark to here.
_fg_vmreset
_fg_vmhwm
local kb_pre = r(kb)

timer clear 1
timer on 1
if `groups' == 1 {
    quietly finegray z1 z2, compete(status) cause(1)
}
else {
    quietly finegray z1 z2, compete(status) cause(1) truncstrata(wg)
}
timer off 1
quietly timer list 1
local secs = r(t1)

_fg_vmhwm
local kb_post = r(kb)

if missing(`kb_pre') | missing(`kb_post') {
    display as error "could not read VmHWM from /proc/self/status; memory is unmeasured"
    exit 459
}

* A lane is DEFINED by its observed weight-stratum count.  If the fit silently
* collapsed the groups, this cell measures a different experiment than the one it
* is labelled as, and the lane's slope would be comparing across designs.
local njobs = e(N_weight_strata)
if `njobs' != `groups' {
    display as error "cell mislabelled: asked for `groups' weight strata, fit reports `njobs'"
    exit 459
}

local kb_incr = `kb_post' - `kb_pre'

tempname out
file open `out' using "`csv'", write text append
file write `out' "`groups',`nn',`run',`secs',`kb_incr',`kb_pre',`kb_post'" _n
file close `out'

display as text "cell groups=`groups' n=`nn' run=`run' secs=`secs' kb_incr=`kb_incr' kb_peak=`kb_post'"
