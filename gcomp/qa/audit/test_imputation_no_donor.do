clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"
set seed 88
set obs 200
gen double z = rnormal()
gen byte x = rbinomial(1, invlogit(z))
gen byte m = rbinomial(1, invlogit(x + z))
gen byte y = rbinomial(1, invlogit(x + m + z))
gen double c = .a
timer clear 1
timer on 1
capture noisily gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) impute(c) imp_cmd(c: regress) imp_eq(c: x) ///
    imp_cycles(1) simulations(100) samples(2) seed(1)
local rc = _rc
timer off 1
quietly timer list 1
assert `rc' == 2000
assert r(t1) < 5
display "RESULT: gcomp_no_donor_probe status=PASS rc=" `rc' " seconds=" r(t1)

display "RESULT: test_imputation_no_donor tests=1 pass=1 fail=0 status=PASS"

