clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"
set seed 91234
set obs 900
gen double c = rnormal()
gen byte x = rbinomial(1, invlogit(-.4 + .5*c))
gen byte m = rbinomial(1, invlogit(-.8 + .9*x + .4*c))
gen byte y = rbinomial(1, invlogit(-1.1 + .7*x + .8*m + .3*c))
local saved "/tmp/gcomp saved stochastic match.dta"
capture erase `"`saved'"'
gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) simulations(700) samples(4) seed(711) ///
    saving(`"`saved'"') replace
tempname b
matrix `b' = e(b)
local tce = `b'[1, colnumb(`b', "tce")]
local nde = `b'[1, colnumb(`b', "nde")]
local nie = `b'[1, colnumb(`b', "nie")]
local run_id `"`e(run_id)'"'
local rngstate `"`e(rngstate)'"'
local schema `"`e(saving_schema)'"'
assert `"`e(saving)'"' == `"`saved'"'
assert e(bootstrap_requested) == 4
assert e(bootstrap_successful) == 4
use `"`saved'"', clear
assert "`: char _dta[gcomp_schema_version]'" == "1"
assert `"`: char _dta[gcomp_run_id]'"' == `"`run_id'"'
assert `"`: char _dta[gcomp_rngstate]'"' == `"`rngstate'"'
confirm variable _int _id y m x c
assert inrange(_int, 0, 3)
assert inrange(_id, 1, 700) if _int > 0
quietly summarize y if _int == 3, meanonly
local e0 = r(mean)
quietly summarize y if _int == 1, meanonly
local e1 = r(mean)
quietly summarize y if _int == 2, meanonly
local e2 = r(mean)
assert reldif(`tce', `e0' - `e2') < 1e-13
assert reldif(`nde', `e1' - `e2') < 1e-13
assert reldif(`nie', (`e0' - `e2') - (`e1' - `e2')) < 1e-13
display "RESULT: gcomp_saved_match_probe status=PASS"

capture erase `"`saved'"'

display "RESULT: test_saved_match tests=1 pass=1 fail=0 status=PASS"

