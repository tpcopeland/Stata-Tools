clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"
set seed 70211
set obs 3000
gen byte x=mod(_n,2)
gen double u=rnormal()
gen double m1=x+u
gen double m2=m1
gen double xm1m2=x*m1*m2
gen double y=xm1m2
quietly summarize u
local oracle=r(Var)*(r(N)-1)/r(N)+r(mean)^2
gcomp y m1 m2 x xm1m2, outcome(y) mediation obe exposure(x) mediator(m1 m2) ///
    commands(m1: regress, m2: regress, y: regress) ///
    equations(m1: x, m2: x m1, y: xm1m2) ///
    derived(xm1m2) derrules(xm1m2: x*m1*m2) ///
    sim(3000) samples(3) seed(91273)
display "oracle=" %12.8f `oracle' " nde=" %12.8f e(nde)
assert abs(e(nde)-`oracle')<0.10
display "RESULT: joint_mediator_probe status=PASS"

display "RESULT: validation_joint_mediator tests=1 pass=1 fail=0 status=PASS"

