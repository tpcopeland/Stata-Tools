clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"
set seed 619
set obs 700
gen double _gc_p1 = rnormal()
gen byte x = rbinomial(1, invlogit(-.3 + .2*_gc_p1))
gen double xb1 = -.4 + .7*x + .3*_gc_p1
gen double xb2 = .2 + .4*x - .2*_gc_p1
gen double den = 1 + exp(xb1) + exp(xb2)
gen double u = runiform()
gen byte m = 1 + (u > 1/den) + (u > (1 + exp(xb1))/den)
gen byte y = rbinomial(1, invlogit(-1 + .4*x + .3*(m==2) + .8*(m==3) + .2*_gc_p1))
drop xb1 xb2 den u
tempfile before
save `before'
gcomp y m x _gc_p1, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: mlogit, y: logit) ///
    equations(m: x _gc_p1, y: i.m x _gc_p1) base_confs(_gc_p1) ///
    simulations(450) samples(3) seed(77)
cf _all using `before', all
confirm variable _gc_p1
assert !missing(_gc_p1)
display "RESULT: gcomp_scratch_collision_probe status=PASS"

display "RESULT: test_scratch_collision tests=1 pass=1 fail=0 status=PASS"

