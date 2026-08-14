/*  benchmark_large.do - Speed comparison on simulated data

    Produces:
      1. finegray, stcrreg and stcrprep+stcox timings for N=500 to 10,000
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

* Use the local development copy via adopath, without mutating the user's ado
* tree (no `ado uninstall'/`net install').  Session-local; removed on exit.
adopath ++ "`c(pwd)'/finegray"

* stcrprep (Lambert, SSC) is the third comparator: it expands the data with
* time-dependent censoring weights so that a weighted stcox reproduces the
* Fine-Gray fit.  Installed on demand -- this is the one place the benchmark
* writes to the user's ado tree, and only when the command is genuinely absent.
capture which stcrprep
if _rc {
    display as text "installing stcrprep from SSC (third comparator)"
    ssc install stcrprep, replace
}

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

**# Environment capture (so the table is interpretable and reproducible)
display as text "Benchmark environment:"
display as text "  Stata:   " c(stata_version) " " c(flavor) " (" c(bit) "-bit), MP procs=" c(processors)
display as text "  OS:      " c(os) " " c(machine_type)
display as text "  Note:    absolute seconds are machine-dependent; the SPEEDUP"
display as text "           ratio is the reproducible, portable quantity."

**# Timed comparisons.
* A single timer call is too noisy for a release claim: report the MEDIAN of
* three timed runs after one untimed warm-up (first call pays one-time cache and
* JIT costs neither command should be charged for).  N runs to 10,000 so the
* published table row is reproducible from this harness.
*
* Three comparators, all fitting the SAME Fine-Gray model:
*   finegray            Mata forward-backward scan, no data expansion
*   stcrreg             Stata's built-in, expands internally at every iteration
*   stcrprep + stcox    expand once with time-dependent weights, then weighted Cox
* The stcrprep column is the whole pipeline, which is what one Fine-Gray fit
* costs.  stcox alone is reported separately because stcrprep's design goal is
* that the expansion is amortised over several models fitted on the same
* weights; charging every model the expansion would understate that use.
capture matrix drop _bench
foreach n in 500 1000 2000 5000 10000 {
    _finegray_demo_data `n'

    * warm-up (untimed): all three paths, so first-call costs are excluded
    quietly finegray x1 x2 x3, compete(status) cause(1) nolog
    preserve
    quietly stset time, failure(status==1) id(id)
    quietly stcrreg x1 x2 x3, compete(status == 2)
    restore
    preserve
    quietly stset time, failure(status==1 2) id(id)
    quietly stcrprep, events(status) keep(x1 x2 x3) trans(1)
    quietly stset tstop [pw=weight_c], failure(status==1) enter(tstart)
    quietly stcox x1 x2 x3, nolog
    restore

    * three timed repeats; take the median
    forvalues rep = 1/3 {
        _finegray_demo_data `n'
        timer clear
        timer on 1
        quietly finegray x1 x2 x3, compete(status) cause(1) nolog
        timer off 1
        quietly timer list 1
        local fg`rep' = r(t1)
        if `rep' == 1 matrix _b_fg = e(b)

        preserve
        quietly stset time, failure(status==1) id(id)
        timer clear
        timer on 2
        quietly stcrreg x1 x2 x3, compete(status == 2)
        timer off 2
        quietly timer list 2
        local cr`rep' = r(t2)
        if `rep' == 1 matrix _b_cr = e(b)
        restore

        preserve
        quietly stset time, failure(status==1 2) id(id)
        timer clear
        timer on 3
        quietly stcrprep, events(status) keep(x1 x2 x3) trans(1)
        quietly stset tstop [pw=weight_c], failure(status==1) enter(tstart)
        timer on 4
        quietly stcox x1 x2 x3, nolog
        timer off 4
        timer off 3
        quietly timer list
        local sp`rep' = r(t3)
        local cx`rep' = r(t4)
        if `rep' == 1 {
            matrix _b_sp = e(b)
            local rows`n' = _N
        }
        restore
    }
    * median of three = the middle value after sorting
    local fgmed = max(min(`fg1',`fg2'), min(max(`fg1',`fg2'),`fg3'))
    local crmed = max(min(`cr1',`cr2'), min(max(`cr1',`cr2'),`cr3'))
    local spmed = max(min(`sp1',`sp2'), min(max(`sp1',`sp2'),`sp3'))
    local cxmed = max(min(`cx1',`cx2'), min(max(`cx1',`cx2'),`cx3'))
    local ratio   = cond(`fgmed' > 0, `crmed'/`fgmed', .)
    local ratiosp = cond(`fgmed' > 0, `spmed'/`fgmed', .)

    * The speed table only means something if the three fits agree.
    local maxrd = 0
    forvalues j = 1/3 {
        local maxrd = max(`maxrd', reldif(_b_fg[1,`j'], _b_cr[1,`j']))
        local maxrd = max(`maxrd', reldif(_b_fg[1,`j'], _b_sp[1,`j']))
    }

    display as text "N=`n': finegray=" as result %8.3f `fgmed' ///
        as text "s  stcrreg=" as result %8.3f `crmed' ///
        as text "s  stcrprep+stcox=" as result %8.3f `spmed' ///
        as text "s  (stcox alone=" as result %7.3f `cxmed' as text "s)"
    display as text "        speedup vs stcrreg=" as result %7.1f `ratio' ///
        as text "x  vs stcrprep+stcox=" as result %7.1f `ratiosp' ///
        as text "x  expanded rows=" as result `rows`n'' ///
        as text "  max coef reldif=" as result %10.2e `maxrd'
    matrix _row = (`n', `fgmed', `crmed', `spmed', `cxmed', `ratio', `ratiosp')
    matrix _bench = nullmat(_bench) \ _row
}

matrix colnames _bench = N finegray_s stcrreg_s stcrprep_s stcox_s sp_crreg sp_crprep
display as text _newline "Benchmark table (median of 3 timed runs, one warm-up):"
matrix list _bench, noheader format(%10.3f)

**# Cleanup
capture program drop _finegray_demo_data
capture matrix drop _bench _row _b_fg _b_cr _b_sp
log close benchmark
capture adopath - "`c(pwd)'/finegray"
clear
