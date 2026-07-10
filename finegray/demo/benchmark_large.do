/*  benchmark_large.do - Speed comparison on simulated data

    Produces:
      1. finegray and stcrreg timings for N=500 to 5,000
         -> benchmark_large.log
*/

version 16.0
clear all
set more off
set varabbrev off
set linesize 120

**# Paths and local installation
local pkg_dir "finegray/demo"
capture log close _all
log using "`pkg_dir'/benchmark_large.log", ///
    replace text name(benchmark) nomsg

capture ado uninstall finegray
quietly net install finegray, from("`c(pwd)'/finegray") replace

**# Synthetic competing-risks data
capture program drop _finegray_demo_data
program define _finegray_demo_data
    version 16.0
    args n

    clear
    set obs `n'
    set seed 20260315

    gen long id = _n
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen double x3 = rnormal()

    gen double h1 = 0.3 * exp(0.5*x1 + 0.3*x2)
    gen double h2 = 0.2 * exp(-0.2*x1 + 0.4*x3)
    gen double hc = 0.1

    gen double t1 = -ln(runiform()) / h1
    gen double t2 = -ln(runiform()) / h2
    gen double tc = -ln(runiform()) / hc

    gen double time = min(t1, t2, tc)
    gen byte status = cond(time == t1, 1, cond(time == t2, 2, 0))
    replace status = 0 if time > 5
    replace time = 5 if time > 5

    drop h1 h2 hc t1 t2 tc
    gen byte fail = (status != 0)
    quietly stset time, failure(fail) id(id)
end

**# Timed comparisons
foreach n in 500 1000 2000 5000 {
    _finegray_demo_data `n'
    timer clear

    timer on 1
    quietly finegray x1 x2 x3, compete(status) cause(1) nolog
    timer off 1

    preserve
    quietly stset time, failure(status==1) id(id)
    timer on 2
    quietly stcrreg x1 x2 x3, compete(status == 2)
    timer off 2
    restore

    display as text "N=`n' timings (seconds):"
    timer list 1
    timer list 2
}

**# Cleanup
capture program drop _finegray_demo_data
log close benchmark
clear
