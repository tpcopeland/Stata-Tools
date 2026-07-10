/*  benchmark_finegray.do - Speed comparison on the hypoxia data

    Produces:
      1. finegray and stcrreg timings -> benchmark_finegray.log
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

capture ado uninstall finegray
quietly net install finegray, from("`c(pwd)'/finegray") replace

**# Hypoxia data
webuse hypoxia, clear
gen byte status = failtype

**# finegray timer
quietly stset dftime, failure(dfcens==1) id(stnum)
timer clear
timer on 1
quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
timer off 1

**# stcrreg timer
quietly stset dftime, failure(status==1) id(stnum)
timer on 2
quietly stcrreg ifp tumsize pelnode, compete(status == 2)
timer off 2

**# Results
display as text "Speed comparison on hypoxia data (seconds):"
timer list 1
timer list 2

log close benchmark
clear
