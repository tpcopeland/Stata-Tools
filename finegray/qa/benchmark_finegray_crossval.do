* benchmark_finegray_crossval.do -- wall-clock scaling of finegray vs stcrreg
* Package: finegray
*
* NOT A CORRECTNESS GATE, AND NOT A LANE MEMBER.  qa/README.md's conventions:
* "benchmark_* files measure performance and are never correctness gates", and
* run_all.do's lane lists are explicit and do not include this file.  Run it by
* hand when you want the numbers:
*
*     cd finegray/qa && stata-mp -b do benchmark_finegray_crossval.do
*
* PROVENANCE.  These five cells (N = 500, 2000, 5000, 10000, 50000) were C21-C25
* of crossval_finegray.do until 2026-09-02, where they were counted as five
* CORRECTNESS tests in that suite's RESULT line.  Their verdict was a stopwatch
* on a machine the QA lanes share, so they inflated a cross-validation pass
* count with a measurement that cross-validates nothing and whose failures would
* have been load, not code.  The one genuine cross-validation in the block --
* C21's coefficient comparison against stcrreg at N=500 -- moved here with it
* and is asserted at 1e-8 (it was 0.001 there).
*
* WALL CLOCK IS NOT A CONTRACT.  Nothing here asserts a time.  For the claim
* that actually matters -- that the delayed-entry scan is LINEAR in n rather
* than quadratic -- see benchmark_finegray_zzf.do, which measures the SLOPE of
* log(time) and log(peak memory) on log(n) in clean processes and is machine
* independent.  This file reports seconds so a human can see them.

clear all
set more off
set varabbrev off
version 16.0

local bench_rc = 0

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
log using "`qadir'/benchmark_finegray_crossval.log", ///
    replace text name(_bench_fg_xv)

* Isolated PLUS/PERSONAL, exactly as the crossval and test suites do, so this
* file cannot swap the build a concurrent lane is measuring.
do "`qadir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap

* finegray follows stcrreg's convention of posting the last iterate with rc 0
* when it does not converge, so convergence is asserted rather than assumed.
program define _finegray_xv
    finegray `0'
    assert e(converged) == 1
    assert e(ll) < . & e(ll_0) < .
    mata: assert(!hasmissing(st_matrix("e(b)")))
    mata: assert(!hasmissing(st_matrix("e(V)")))
end

display ""
display as text "PERFORMANCE BENCHMARKS: finegray vs stcrreg"
display ""

program define _run_benchmark
    args n_obs seed
    clear
    set seed `seed'
    set obs `n_obs'
    gen id = _n
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen double x3 = rbinomial(1, 0.5)
    gen double u = runiform()
    gen double t_event = -ln(u) / exp(0.3*x1 - 0.2*x2 + 0.1*x3)
    gen double t_censor = runiform() * 3
    gen double t = min(t_event, t_censor)
    gen byte d = (t_event <= t_censor)
    gen byte status = 0
    replace status = 1 if d == 1 & runiform() > 0.35
    replace status = 2 if d == 1 & status == 0
end

* B1 (was crossval_finegray.do C21): Benchmark N=500 — finegray vs stcrreg
capture noisily {
    _run_benchmark 500 42

    * Time finegray
    stset t, failure(d) id(id)
    timer clear 1
    timer on 1
    _finegray_xv x1 x2 x3, compete(status) cause(1) nolog
    timer off 1
    quietly timer list 1
    local t_fg = r(t1)
    local b_fg = e(b)[1,1]

    * Time stcrreg (feasible at N=500)
    stset t, failure(status==1) id(id)
    timer clear 2
    timer on 2
    stcrreg x1 x2 x3, compete(status == 2)
    timer off 2
    quietly timer list 2
    local t_ref = r(t2)
    local b_ref = e(b)[1,1]

    * The one CROSS-VALIDATION assertion that used to live in this block:
    * finegray and stcrreg on the same N=500 fixture.  TOLERANCE 1e-6.
    * MEASURED 2026-09-02 (seeded fixture, deterministic): 2.868e-08, so this
    * is about 35x it.  It was 0.001 while it sat in crossval_finegray.do.
    local _b1d = abs(`b_fg' - `b_ref')
    display as text "  B1 |b_fg - b_stcrreg| = " %10.3e `_b1d'
    assert `_b1d' < 1e-6

    local ratio = `t_ref' / max(`t_fg', 0.001)
    display as text "  N=500: finegray=" %6.3f `t_fg' ///
        "s  stcrreg=" %6.3f `t_ref' "s  ratio=" %6.1f `ratio' "x"
}
if _rc != 0 {
    display as error "  B1 benchmark N=500 did not run (rc=`=_rc')"
    local ++bench_rc
}

* B2 (was crossval_finegray.do C22-C23): Benchmarks at N=2000, 5000 (finegray only — stcrreg too slow)
foreach n_obs in 2000 5000 {
        capture noisily {
        _run_benchmark `n_obs' 42

        stset t, failure(d) id(id)
        timer clear 1
        timer on 1
        _finegray_xv x1 x2 x3, compete(status) cause(1) nolog
        timer off 1
        quietly timer list 1
        local t_fg = r(t1)
        assert e(converged) == 1
        display as text "  N=`n_obs': finegray=" %6.3f `t_fg' "s"
    }
    if _rc != 0 {
        display as error "  B2 benchmark N=`n_obs' did not run (rc=`=_rc')"
        local ++bench_rc
    }
}

* B3 (was crossval_finegray.do C24): Large benchmark N=10000 (finegray only — stcrreg too slow at this scale)
capture noisily {
    _run_benchmark 10000 42

    stset t, failure(d) id(id)
    timer clear 1
    timer on 1
    _finegray_xv x1 x2 x3, compete(status) cause(1) nolog
    timer off 1
    quietly timer list 1
    local t_fg = r(t1)
    assert e(converged) == 1
    display as text "  N=10000: finegray=" %6.3f `t_fg' "s (stcrreg too slow to compare)"
}
if _rc != 0 {
    display as error "  B3 benchmark N=10000 did not run (rc=`=_rc')"
    local ++bench_rc
}

* B4 (was crossval_finegray.do C25): Benchmark N=50000 (finegray stress test)
capture noisily {
    _run_benchmark 50000 42

    stset t, failure(d) id(id)
    timer clear 1
    timer on 1
    _finegray_xv x1 x2 x3, compete(status) cause(1) nolog
    timer off 1
    quietly timer list 1
    local t_fg = r(t1)
    assert e(converged) == 1
    display as text "  N=50000: finegray=" %6.3f `t_fg' "s"
}
if _rc != 0 {
    display as error "  B4 benchmark N=50000 did not run (rc=`=_rc')"
    local ++bench_rc
}

display ""
display as text "BENCHMARK COMPLETE: the seconds above are a report, not a gate."
display as text "RESULT: benchmark_finegray_crossval cells=5 not-a-correctness-gate"

if `bench_rc' > 0 {
    display as error "`bench_rc' benchmark cell(s) failed to RUN (not a timing verdict)"
    log close _bench_fg_xv
    exit 1
}
log close _bench_fg_xv
