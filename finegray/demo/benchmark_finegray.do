* benchmark_finegray.do - Speed comparison: finegray vs stcrreg
clear all

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
local demodir "`pkgroot'/demo"

capture log close _bench
log using "`demodir'/benchmark_finegray.log", ///
    replace text name(_bench)

capture ado uninstall finegray
net install finegray, from("`pkgroot'")

webuse hypoxia, clear
gen byte status = failtype

* Timer 1: finegray (Mata engine)
stset dftime, failure(dfcens==1) id(stnum)

timer clear
timer on 1
finegray ifp tumsize pelnode, compete(status) cause(1) nolog
timer off 1

* Timer 2: stcrreg (Stata built-in)
stset dftime, failure(status==1) id(stnum)

timer on 2
stcrreg ifp tumsize pelnode, compete(status == 2)
timer off 2

* Results
display ""
display "Speed comparison on hypoxia data (seconds):"
timer list 1
timer list 2

log close _bench
