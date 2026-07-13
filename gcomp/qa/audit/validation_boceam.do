clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"
set seed 149
set obs 800
gen double c = rnormal()
gen byte x = rbinomial(1, invlogit(-.2 + .3*c))
gen byte m = rbinomial(1, invlogit(-.7 + .8*x + .4*c))
gen double y = .5*x + .7*m + .2*c + rnormal()
tempfile d
save `d'
capture noisily gcomp y m x c, outcome(y) mediation obe boceam ///
    exposure(x) mediator(m) commands(m: logit, y: regress) ///
    equations(m: x c, y: x m c) base_confs(c) ///
    simulations(500) samples(2) seed(35)
assert _rc == 198

use `d', clear
gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: regress) equations(m: x c, y: x m c) ///
    base_confs(c) msm(regress y x m) simulations(500) samples(3) seed(35) minsim
tempname plain
matrix `plain' = e(b)

use `d', clear
gcomp y m x c, outcome(y) mediation obe boceam exposure(x) mediator(m) ///
    commands(m: logit, y: regress) equations(m: x c, y: x m c) ///
    base_confs(c) msm(regress y x m) simulations(500) samples(3) seed(35) minsim
tempname bo
matrix `bo' = e(b)
foreach eff in tce nde nie pm {
    assert reldif(`plain'[1,colnumb(`plain',"`eff'")], ///
        `bo'[1,colnumb(`bo',"`eff'")]) < 1e-13
}
display "RESULT: gcomp_boceam_probe status=PASS"

display "RESULT: validation_boceam tests=1 pass=1 fail=0 status=PASS"

