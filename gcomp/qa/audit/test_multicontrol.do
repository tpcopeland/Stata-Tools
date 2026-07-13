clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"
set seed 5678
set obs 650
gen double c = rnormal()
gen byte x = rbinomial(1, invlogit(-.2 + .4*c))
gen double m1 = .7*x + .3*c + rnormal()
gen double m2 = -.2*x + .8*m1 + .2*c + rnormal()
gen double y = .5*x + .6*m1 - .4*m2 + .3*c + rnormal()
tempfile original
save `original'

capture noisily gcomp y m1 m2 x c, outcome(y) mediation obe ///
    exposure(x) mediator(m1 m2) control(0 1) ///
    commands(m1: regress, m2: regress, y: regress) ///
    equations(m1: x c, m2: x m1 c, y: x m1 m2 c) ///
    base_confs(c) simulations(400) samples(2) seed(44)
assert _rc == 198

use `original', clear
local saved "/tmp/gcomp keyed multicontrol.dta"
capture erase `"`saved'"'
gcomp y m1 m2 x c, outcome(y) mediation obe ///
    exposure(x) mediator(m1 m2) control(m2: 1, m1: 0) ///
    commands(m1: regress, m2: regress, y: regress) ///
    equations(m1: x c, m2: x m1 c, y: x m1 m2 c) ///
    base_confs(c) simulations(400) samples(3) seed(44) ///
    saving(`"`saved'"') replace
use `"`saved'"', clear
assert m1 == 0 if inlist(_int, 3, 4)
assert m2 == 1 if inlist(_int, 3, 4)
quietly count if inlist(_int, 3, 4)
assert r(N) == 800
display "RESULT: gcomp_multicontrol_probe status=PASS"

capture erase `"`saved'"'

display "RESULT: test_multicontrol tests=1 pass=1 fail=0 status=PASS"

