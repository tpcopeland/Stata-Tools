* benchmark_finegray.do - Speed comparison: finegray vs wrapper vs stcrreg
clear all
set more off

capture log close _bench
log using "/home/tpcopeland/Stata-Dev/finegray/demo/benchmark_finegray.log", ///
    replace text name(_bench)

capture ado uninstall finegray
net install finegray, from("/home/tpcopeland/Stata-Dev/finegray")

webuse hypoxia, clear
gen byte status = failtype

* Timer 1: finegray default (Mata engine)
stset dftime, failure(dfcens==1) id(stnum)

timer clear
timer on 1
finegray ifp tumsize pelnode, events(status) cause(1) nolog
timer off 1

* Timer 2: finegray wrapper mode (stcrprep + stcox)
timer on 2
finegray ifp tumsize pelnode, events(status) cause(1) wrapper nolog
timer off 2

* Timer 3: stcrreg (Stata built-in)
stset dftime, failure(status==1) id(stnum)

timer on 3
stcrreg ifp tumsize pelnode, compete(status == 2)
timer off 3

* Results
display ""
display "Speed comparison on hypoxia data (seconds):"
timer list 1
timer list 2
timer list 3

log close _bench
