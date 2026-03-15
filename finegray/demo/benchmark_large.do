* benchmark_large.do - Speed comparison on simulated datasets (N up to 5,000)
clear all
set more off

capture log close _bench
log using "/home/tpcopeland/Stata-Dev/finegray/demo/benchmark_large.log", ///
    replace text name(_bench)

capture ado uninstall finegray
net install finegray, from("/home/tpcopeland/Stata-Dev/finegray")

* Generate competing risks data
program define _gen_cr_data
    args n
    clear
    set obs `n'
    set seed 20260315

    gen long id = _n
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen double x3 = rnormal()

    * Cause-specific hazards
    gen double h1 = 0.3 * exp(0.5*x1 + 0.3*x2)
    gen double h2 = 0.2 * exp(-0.2*x1 + 0.4*x3)
    gen double hc = 0.1

    * Simulate event times from exponential
    gen double t1 = -ln(runiform()) / h1
    gen double t2 = -ln(runiform()) / h2
    gen double tc = -ln(runiform()) / hc

    * Observed time = min(t1, t2, tc)
    gen double time = min(t1, t2, tc)
    gen byte status = cond(time == t1, 1, cond(time == t2, 2, 0))

    * Administrative censoring at t=5
    replace status = 0 if time > 5
    replace time = 5 if time > 5

    drop h1 h2 hc t1 t2 tc

    gen byte fail = (status != 0)
    stset time, failure(fail) id(id)

    quietly tab status
    display "  N=`n' generated"
end

foreach n in 500 1000 2000 5000 {

    display ""
    display "N = `n'"
    _gen_cr_data `n'

    timer clear

    * Timer 1: finegray (Mata engine, default)
    timer on 1
    finegray x1 x2 x3, events(status) cause(1) nolog
    timer off 1

    * Timer 2: finegray wrapper mode
    timer on 2
    finegray x1 x2 x3, events(status) cause(1) wrapper nolog
    timer off 2

    * Timer 3: stcrreg
    preserve
    stset time, failure(status==1) id(id)
    timer on 3
    quietly stcrreg x1 x2 x3, compete(status == 2)
    timer off 3
    restore

    stset time, failure(fail) id(id)

    display ""
    display "N=`n' timings (seconds):"
    timer list 1
    timer list 2
    timer list 3
}

display ""
display "Benchmark complete."

log close _bench
