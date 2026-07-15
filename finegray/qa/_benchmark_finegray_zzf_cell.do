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

* Install the exact source tree in every clean child.  The parent also installs
* it before spawning cells, but a child must not be able to inherit a stale PLUS
* registration if the parent setup is changed or interrupted.
local pkgroot "`c(pwd)'"
capture confirm file "`pkgroot'/finegray.pkg"
if _rc {
    capture confirm file "`pkgroot'/../finegray.pkg"
    if _rc {
        display as error "could not locate finegray package root"
        exit 601
    }
    local pkgroot "`pkgroot'/.."
}
capture ado uninstall finegray
quietly net install finegray, from("`pkgroot'") replace
discard

* ---------------------------------------------------------------------------
* Measure CPU TIME, single-threaded -- not wall clock.
* ---------------------------------------------------------------------------
* Wall clock on a shared box measures the SCHEDULER, not the estimator.  An earlier
* run of this benchmark shared the machine with a Monte Carlo and reported a slope
* near 1.5; that number was noise and very nearly got written down as a scaling
* defect.  Waiting for an idle machine is not an option here -- the box is never
* idle -- so the fix is to measure a quantity contention does not move:
*
*   set processors 1   removes MP thread-scheduling variance, so the fit does a
*                      single deterministic amount of work.
*   utime + stime      from /proc/self/stat is CPU time actually consumed by THIS
*                      process.  Another job stealing a core stretches wall time
*                      but not the work done, so the log-log SLOPE is preserved.
*
* Wall time is still recorded, as a diagnostic only.  The gate is on CPU time.
capture set processors 1

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

* CPU time (seconds) consumed by this process: utime + stime from /proc/self/stat,
* fields 14 and 15, in clock ticks (100/s on Linux).  The comm field is
* "(stata-mp)" -- no embedded spaces -- so plain word() parsing is safe here.
capture program drop _fg_cpu
program define _fg_cpu, rclass
    tempname fh
    local secs = .
    capture file open `fh' using "/proc/self/stat", read text
    if _rc {
        return scalar secs = .
        exit
    }
    file read `fh' line
    file close `fh'
    local clean = subinstr(`"`macval(line)'"', char(9), " ", .)
    local ut = real(word("`clean'", 14))
    local st = real(word("`clean'", 15))
    if !missing(`ut') & !missing(`st') local secs = (`ut' + `st') / 100
    return scalar secs = `secs'
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
_fg_cpu
local cpu_pre = r(secs)

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
local wall = r(t1)

_fg_cpu
local cpu_post = r(secs)
_fg_vmhwm
local kb_post = r(kb)

local secs = `cpu_post' - `cpu_pre'
if missing(`secs') {
    display as error "could not read CPU time from /proc/self/stat"
    exit 459
}

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
file write `out' "`groups',`nn',`run',`secs',`kb_incr',`wall'" _n
file close `out'

display as text "cell groups=`groups' n=`nn' run=`run' cpu=`secs' wall=`wall' kb_incr=`kb_incr'"
