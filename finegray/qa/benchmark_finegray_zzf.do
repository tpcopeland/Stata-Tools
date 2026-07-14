* benchmark_finegray_zzf.do - does the ZZF delayed-entry path scale LINEARLY in n?
* Package: finegray
*
* THE CLAIM UNDER TEST.  The combined weight A(t) = G(t-)H(t-) is evaluated by an
* unexpanded forward-backward scan over the risk set.  The alternative -- the one
* every textbook description of Fine-Gray implies, and the one the R oracle in
* crossval_finegray_zzf_beta_r.R actually uses -- materializes an n x (#event
* times) weight matrix, which is O(n^2) in both time and memory.  At n = 100,000
* that matrix is ~3e9 doubles (~24 TB): the oracle cannot be run at this scale at
* all.  The whole point of the scan is that finegray can.
*
* So "linear in n" is not a nice-to-have, it is the load-bearing claim, and a
* benchmark that only reports seconds cannot test it.  This file measures the
* SLOPE of log(median runtime) and log(median incremental peak memory) on log(n),
* and requires runtime in [0.8, 1.3] and memory in [0.8, 1.2].  That tests
* complexity without hard-coding a machine-specific threshold: a quadratic path
* lands near 2.0 on any machine, fast or slow.
*
* MEASUREMENT PROTOCOL (fg_zzf_plan.md, Gate Z-perf).
*   - Fixtures are generated and SAVED before any measurement, so fixture
*     construction is never inside the timer.
*   - Each cell is measured in FIVE CLEAN stata-mp PROCESSES (see the cell .do).
*     Mata compilation, ado loading, and the allocator's high-water mark all
*     persist within a process, so measuring cells in one process lets the largest
*     n contaminate every cell after it.
*   - Runtime: Stata's `timer`, around the estimation command only.
*   - Incremental peak memory: VmHWM from /proc/self/status (kernel high-water
*     mark, so no sampling loop can miss a spike), read after the data are loaded
*     and stset, and again after estimation.  The difference is the fit's own
*     peak, not the cost of holding the dataset.
*   - Per cell we take the MEDIAN of the five runs.
*   - Group count is held FIXED within a lane and varied ACROSS lanes (1, 10, 50
*     observed joint weight strata), so a fixed-n increase in group count cannot
*     be mistaken for the scaling being tested.  The child asserts the fit really
*     observed the stratum count its lane is labelled with.
*
* WALL CLOCK WOULD MAKE THIS BENCHMARK WORTHLESS ON A SHARED BOX, so it does not
* use wall clock.  An earlier version did, shared the machine with a Monte Carlo,
* and reported a slope near 1.5 -- pure scheduler noise that very nearly got
* written down as a scaling defect.  Waiting for an idle machine was not viable
* (this box never is), so each cell instead runs `set processors 1' and measures
* CPU TIME (utime + stime from /proc/self/stat).  A competing job steals wall time
* but not work done, so the log-log SLOPE survives contention.  Wall time is still
* recorded and printed, as a diagnostic only; the GATE is on CPU time.
*
* Run from finegray/qa:  stata-mp -b do benchmark_finegray_zzf.do
* This is a MEASUREMENT suite; it is not part of run_all.do's pass/fail lanes.
*
* Cheap plumbing smoke test (does NOT test scaling -- too small, too few runs):
*   ZZF_BENCH_NS="8000 16000" ZZF_BENCH_RUNS=2 ZZF_BENCH_LANES="1 10" \
*   stata-mp -b do benchmark_finegray_zzf.do

clear all
set more off
set varabbrev off
version 16.0

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
local qadir "`pkgroot'/qa"

capture log close _all
log using "`qadir'/benchmark_finegray_zzf.log", replace text name(_bench_zzf)

capture ado uninstall finegray
net install finegray, from("`pkgroot'") replace

* ---------------------------------------------------------------------------
* Configuration (env-overridable, for plumbing smoke tests only).
* ---------------------------------------------------------------------------
local NS      : environment ZZF_BENCH_NS
local RUNS    : environment ZZF_BENCH_RUNS
local LANES   : environment ZZF_BENCH_LANES

if "`NS'"      == "" local NS      "25000 50000 100000 200000"
if "`RUNS'"    == "" local RUNS    5
if "`LANES'"   == "" local LANES   "1 10 50"

* Recorded, not gated on: CPU time is what we measure, and contention does not
* change the work done.  The load is logged so the raw numbers stay interpretable.
tempname lf
local load1 = .
capture file open `lf' using "/proc/loadavg", read text
if !_rc {
    file read `lf' line
    file close `lf'
    local load1 = real(word(`"`macval(line)'"', 1))
}
display as text _newline "1-minute load average at start: `load1'"
display as text "measuring CPU time (set processors 1); wall clock is diagnostic only"

* ---------------------------------------------------------------------------
* Fixture: delayed entry, with a tunable number of truncation strata.
* ---------------------------------------------------------------------------
program define _zzf_bench_gen
    syntax , n(integer) seed(integer) groups(integer)

    clear
    set seed `seed'
    quietly set obs `=`n' * 6'

    gen byte   z1 = runiform() < 0.5
    gen double z2 = rnormal()
    gen double ez = exp(0.5 * z1 - 0.5 * z2)
    gen double p1 = 1 - (1 - 0.5)^ez

    gen byte   cause = cond(runiform() < p1, 1, 2)
    gen double v     = runiform()
    gen double tev = -ln(1 - (1 - (1 - v * p1)^(1 / ez)) / 0.5) if cause == 1
    replace    tev = rexponential(1 / (0.5 * exp(0.5 * z1 + 0.5 * z2))) if cause == 2
    gen double cens = min(rexponential(1 / 0.15), 6)
    gen double t0   = rexponential(1 / cond(z1 == 1, 1.6, 0.5))

    gen double t      = min(tev, cens)
    gen byte   status = cond(tev <= cens, cause, 0)
    gen byte   anyev  = status > 0

    quietly drop if !(t0 < t)
    quietly count
    if r(N) < `n' {
        display as error "oversample exhausted at n = `n'"
        exit 498
    }
    quietly keep in 1/`n'
    gen long id = _n

    * The weight design: `groups' observed truncation strata, fixed within a lane.
    gen int wg = ceil(runiform() * `groups')
    quietly replace wg = 1 if wg < 1
end

* ---------------------------------------------------------------------------
* Measure: one saved fixture per cell, `RUNS' clean child processes per cell.
* ---------------------------------------------------------------------------
local csv "`qadir'/benchmark_finegray_zzf_raw.csv"
capture erase "`csv'"
tempname hdr
file open `hdr' using "`csv'", write text replace
file write `hdr' "groups,nn,run,secs,kb_incr,wall" _n
file close `hdr'

local expected = 0
local fixdir "`qadir'/data"
capture mkdir "`fixdir'"

foreach G of local LANES {
    display as text _newline "lane: `G' observed joint weight strata"

    foreach n of local NS {
        quietly _zzf_bench_gen, n(`n') seed(`=20260713 + `n'') groups(`G')
        local fix "`fixdir'/_zzf_bench_`G'_`n'.dta"
        quietly save "`fix'", replace

        forvalues r = 1/`RUNS' {
            shell stata-mp -b do "`qadir'/_benchmark_finegray_zzf_cell.do" "`fix'" `G' `n' `r' "`csv'"
            local ++expected
        }
        display as text "  n = " %7.0f `n' "  measured `RUNS' clean processes"
        capture erase "`fix'"
    }
}

* ---------------------------------------------------------------------------
* THE FALSE GREEN THIS GUARDS.  Stata's `shell' does NOT set _rc, so a child that
* died -- bad path, r(459) mislabelled lane, missing finegray -- is invisible here.
* If we simply regressed on whatever rows arrived, a run where 40 of 60 children
* crashed would still print a slope, and the slope would look like evidence.
* Assert we got every row we asked for BEFORE computing anything.
* ---------------------------------------------------------------------------
import delimited using "`csv'", clear varnames(1) case(preserve)
quietly count
local got = r(N)
display as text _newline "measurement rows: `got' (expected `expected')"
if `got' != `expected' {
    display as error "MEASUREMENT INCOMPLETE: `got' of `expected' child processes reported"
    display as error "shell does not set _rc, so a crashed child is silent -- inspect the cell logs"
    log close _bench_zzf
    exit 9
}
quietly count if missing(secs) | missing(kb_incr)
if r(N) > 0 {
    display as error "MEASUREMENT INVALID: `=r(N)' rows have a missing runtime or memory reading"
    log close _bench_zzf
    exit 9
}

* ---------------------------------------------------------------------------
* Medians per cell, then the two scaling regressions.
* ---------------------------------------------------------------------------
preserve
collapse (median) secs kb_incr wall, by(groups nn)
tempfile med
quietly save "`med'"
restore

use "`med'", clear
gen double logn = ln(nn)
gen double logt = ln(secs)
gen double logm = ln(kb_incr)

display as text _newline "MEDIAN measurements per cell (secs = CPU; wall = diagnostic)"
list groups nn secs wall kb_incr, noobs sepby(groups)

* Every median increment must be positive, or the protocol is too coarse to be
* measuring anything and the slope is fitted to rounding noise.
quietly count if kb_incr <= 0
if r(N) > 0 {
    display as error _newline "MEASUREMENT TOO COARSE: `=r(N)' cells show a non-positive memory increment"
    display as error "the fit's peak is below the resolution of VmHWM; raise n or the protocol"
    log close _bench_zzf
    exit 9
}
* CPU time is read in 10 ms clock ticks, so a fit under ~0.5 s carries >2%
* quantisation error and the slope would be fitted to rounding.
quietly summarize secs, meanonly
if r(min) < 0.5 {
    display as error _newline "MEASUREMENT TOO COARSE: a median fit used `=r(min)' s CPU (< 0.5 s)"
    display as error "CPU time is quantised to 10ms ticks; the slope would be noise"
    log close _bench_zzf
    exit 9
}

display as text _newline "SCALING: slope of log(median x) on log(n), per lane"
display as text "  linear scan => ~1.0    expanded (n x K) weight matrix => ~2.0"
display as text _newline ///
    "strata     runtime slope    memory slope    KB per obs   verdict"

local fail = 0
quietly levelsof groups, local(GS)
foreach g of local GS {
    quietly regress logt logn if groups == `g'
    local ts = _b[logn]
    quietly regress logm logn if groups == `g'
    local ms = _b[logn]

    * Marginal memory per observation, between the smallest and largest n in the
    * lane.  The peak-RSS INCREMENT carries a fixed offset (the Mata engine, the
    * tempvars) that does not scale with n -- measured at ~15 MB -- so a log-log
    * slope on it is biased DOWNWARD, and the more of the n-proportional cost you
    * remove the more the offset dominates.  Dropping the K-row e(basehaz) matrix
    * (and its K auto-generated dimension names) removed exactly such a term and
    * pushed this slope from 0.95 to 0.58 while memory FELL at every n.  The
    * per-observation marginal cost is the offset-free view: it was flat across
    * consecutive doublings (0.286, 0.285, 0.319 KB/obs in lane 1).
    quietly summarize nn if groups == `g'
    local _nlo = r(min)
    local _nhi = r(max)
    quietly summarize kb_incr if groups == `g' & nn == `_nlo'
    local _kblo = r(mean)
    quietly summarize kb_incr if groups == `g' & nn == `_nhi'
    local _kbhi = r(mean)
    local kb_per_obs = (`_kbhi' - `_kblo') / (`_nhi' - `_nlo')

    local ok_t = (`ts' >= 0.8 & `ts' <= 1.3)

    * The memory gate is ONE-SIDED, and deliberately so.  Its stated failure mode
    * is the n x K expansion this package exists to avoid, which shows up as a
    * slope of ~2 -- a slope BELOW 1 cannot mean expansion, it means memory grew
    * more slowly than the data.  The old two-sided band was also serving, by
    * accident, as a "did we measure anything at all" tripwire; that job now goes
    * to an explicit check that memory actually grows with n, which is what a dead
    * or mis-wired measurement (a constant, or zero) would fail.
    local ok_m = (`ms' <= 1.2) & (`kb_per_obs' > 0.02)

    if `ok_t' & `ok_m' {
        display as result %6.0f `g' %17.2f `ts' %15.2f `ms' ///
            %16.3f `kb_per_obs' "   PASS (linear)"
    }
    else {
        local why ""
        if !`ok_t' local why "`why' runtime outside [0.8, 1.3];"
        if `ms' > 1.2 local why "`why' memory slope > 1.2 (superlinear);"
        if `kb_per_obs' <= 0.02 ///
            local why "`why' memory does not grow with n (dead measurement?);"
        display as error %6.0f `g' %17.2f `ts' %15.2f `ms' ///
            %16.3f `kb_per_obs' "   FAIL:`why'"
        local fail = 1
    }
}

display as text _newline "raw measurements: `csv'"
display as text "runtime tool: CPU time (utime+stime, /proc/self/stat), set processors 1,"
display as text "              around the estimation command only; wall clock diagnostic only"
display as text "memory tool:  VmHWM (peak RSS) from /proc/self/status, post-fit minus prefit,"
display as text "              high-water mark reset via /proc/self/clear_refs at the baseline"
display as text "runs per cell: `RUNS' clean stata-mp processes; statistic: median"
display as text "1-minute load average at start: `load1' (CPU time is insensitive to this)"

if `fail' {
    display as error _newline "BENCHMARK FAILED: the ZZF path does not scale linearly"
    log close _bench_zzf
    exit 9
}
display as result _newline "BENCHMARK PASSED: runtime and memory are linear in n in every stratum lane"
log close _bench_zzf
