clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"
set seed 3181
set obs 700
gen double c0 = rnormal()
gen byte x = rbinomial(1, invlogit(-.3 + .4*c0))
gen byte m = rbinomial(1, invlogit(-.7 + .8*x + .5*c0))
gen byte y = rbinomial(1, invlogit(-1 + .6*x + .8*m + .3*c0))
gen double c = c0
replace c = .a if mod(_n, 7) == 0
tempfile ext sys
save `ext'
replace c = . if missing(c)
save `sys'

use `ext', clear
gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) impute(c) imp_cmd(c: regress) imp_eq(c: x) ///
    imp_cycles(2) simulations(500) samples(3) seed(923)
tempname be
matrix `be' = e(b)

use `sys', clear
gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) impute(c) imp_cmd(c: regress) imp_eq(c: x) ///
    imp_cycles(2) simulations(500) samples(3) seed(923)
tempname bs
matrix `bs' = e(b)
assert colsof(`be') == colsof(`bs')
forvalues j = 1/`=colsof(`be')' {
    assert reldif(`be'[1,`j'], `bs'[1,`j']) < 1e-13
}
display "RESULT: gcomp_extended_missing_probe status=PASS"

display "RESULT: test_extended_missing tests=1 pass=1 fail=0 status=PASS"

