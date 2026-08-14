/*  benchmark_finegray.do - Speed comparison on the hypoxia data

    Produces:
      1. finegray, stcrreg and stcrprep+stcox timings -> benchmark_finegray.log
*/

version 16.0
clear all
set more off
set varabbrev off
set linesize 120

**# Paths and local installation
local pkg_dir "finegray/demo"
capture log close _all
log using "`pkg_dir'/benchmark_finegray.log", ///
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

**# Hypoxia data
webuse hypoxia, clear
gen byte status = failtype

**# Warm-up (untimed), matching benchmark_large.do
* Without this the FIRST command timed pays one-time costs -- loading the Mata
* library, faulting in the ado files -- that the two run after it do not.  At
* N=109 those fixed costs dominate the fit itself, so an unwarmed run reports
* the load order, not the algorithms.
quietly stset dftime, failure(dfcens==1) id(stnum)
quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
preserve
quietly stset dftime, failure(status==1) id(stnum)
quietly stcrreg ifp tumsize pelnode, compete(status == 2)
restore
preserve
quietly stset dftime, failure(status==1 2) id(stnum)
quietly stcrprep, events(status) keep(ifp tumsize pelnode) trans(1)
quietly stset tstop [pw=weight_c], failure(status==1) enter(tstart)
quietly stcox ifp tumsize pelnode, nolog
restore

**# Timed comparisons, median of three repeats
* At N=109 every fit is a few hundredths of a second, which is the scale at
* which a SINGLE timer reading is mostly scheduler noise.  Median of three, as
* in benchmark_large.do.  Timer 3 is the whole pipeline a user pays for one
* Fine-Gray fit: the weight expansion, the re-stset that carries the weights,
* and the Cox fit.  Timer 4 is the stcox call alone, which is what a second
* model on the SAME expanded data would cost -- stcrprep's design goal is that
* the expansion is computed once and reused, so charging every model the
* expansion would understate it.
forvalues rep = 1/3 {
    quietly stset dftime, failure(dfcens==1) id(stnum)
    timer clear
    timer on 1
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    timer off 1
    quietly timer list 1
    local fg`rep' = r(t1)
    matrix _b_fg = e(b)

    preserve
    quietly stset dftime, failure(status==1) id(stnum)
    timer clear
    timer on 2
    quietly stcrreg ifp tumsize pelnode, compete(status == 2)
    timer off 2
    quietly timer list 2
    local cr`rep' = r(t2)
    matrix _b_cr = e(b)
    restore

    preserve
    quietly stset dftime, failure(status==1 2) id(stnum)
    timer clear
    timer on 3
    quietly stcrprep, events(status) keep(ifp tumsize pelnode) trans(1)
    quietly stset tstop [pw=weight_c], failure(status==1) enter(tstart)
    timer on 4
    quietly stcox ifp tumsize pelnode, nolog
    timer off 4
    timer off 3
    quietly timer list
    local sp`rep' = r(t3)
    local cx`rep' = r(t4)
    matrix _b_sp = e(b)
    local _rows = _N
    restore
}
local _t1 = max(min(`fg1',`fg2'), min(max(`fg1',`fg2'),`fg3'))
local _t2 = max(min(`cr1',`cr2'), min(max(`cr1',`cr2'),`cr3'))
local _t3 = max(min(`sp1',`sp2'), min(max(`sp1',`sp2'),`sp3'))
local _t4 = max(min(`cx1',`cx2'), min(max(`cx1',`cx2'),`cx3'))

**# Agreement check
* A speed table is only meaningful if the three commands fit the same model.
local _maxrd = 0
forvalues j = 1/3 {
    local _maxrd = max(`_maxrd', reldif(_b_fg[1,`j'], _b_cr[1,`j']))
    local _maxrd = max(`_maxrd', reldif(_b_fg[1,`j'], _b_sp[1,`j']))
}

**# Results
display as text "Speed comparison on hypoxia data (N=109 subjects, 3 covariates):"
display as text "  stcrprep expanded the 109 subjects to `_rows' weighted rows"
display as text "  max relative coefficient difference across the three fits: " ///
    as result %12.3e `_maxrd'
display as text "  timings are the median of 3 timed repeats after one warm-up"
display as text _newline "  1 finegray                 " as result %9.3f `_t1' as text "s"
display as text "  2 stcrreg                  " as result %9.3f `_t2' as text "s" ///
    as text "   speedup vs finegray " as result %7.1f cond(`_t1' > 0, `_t2'/`_t1', .) as text "x"
display as text "  3 stcrprep + stcox (total) " as result %9.3f `_t3' as text "s" ///
    as text "   speedup vs finegray " as result %7.1f cond(`_t1' > 0, `_t3'/`_t1', .) as text "x"
display as text "  4 stcox alone (reused wts) " as result %9.3f `_t4' as text "s"

capture matrix drop _b_fg _b_cr _b_sp
log close benchmark
capture adopath - "`c(pwd)'/finegray"
clear
