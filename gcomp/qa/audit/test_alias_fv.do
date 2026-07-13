clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"
set seed 401
set obs 720
gen long row = _n
gen byte keep = mod(_n, 6) != 0
gen double abcdefghijklmnopqrstuvwxyzABCDEF = rnormal()
gen double x_ = rnormal()
gen double z_omitted = rnormal()
gen byte x = rbinomial(1, invlogit(-.3 + .2*z_omitted + .1*x_))
gen byte m = rbinomial(1, invlogit(-.7 + .8*x + .3*z_omitted + .2*x*z_omitted))
gen byte y = rbinomial(1, invlogit(-1 + .5*x + .7*m + .2*z_omitted + .2*m*z_omitted))
sort x row
tempfile before
save `before'
gcomp y m x x_ abcdefghijklmnopqrstuvwxyzABCDEF if keep, outcome(y) ///
    mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) ///
    equations(m: i.x##c.z_omitted x_, y: i.m##c.z_omitted x x_) ///
    base_confs(z_omitted x_ abcdefghijklmnopqrstuvwxyzABCDEF) ///
    simulations(450) samples(3) seed(904)
assert e(N_rows) == 600
assert e(sample) == keep
cf _all using `before', all
display "RESULT: gcomp_alias_fv_probe status=PASS"

display "RESULT: test_alias_fv tests=1 pass=1 fail=0 status=PASS"

