clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_qa_bootstrap.do"
set seed 606
set obs 80
gen byte x = mod(_n, 2)
gen double c = rnormal()
gen byte m = inlist(_n, 19, 40, 61, 80)
gen byte y = mod(_n, 3) == 0
capture noisily gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x, y: m x c) ///
    base_confs(c) simulations(150) samples(100) seed(606)
local rc = _rc
display "observed rc=" `rc'
assert `rc' == 459
display "TEST_RESULT: gcomp_bootstrap_failure_probe status=PASS rc=" `rc'

display "RESULT: test_expected_resampling_failure tests=1 pass=1 fail=0 status=PASS"
