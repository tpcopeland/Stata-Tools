version 16.0
clear all
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"
set seed 713
set obs 300
generate double regress = rnormal()
generate byte x = mod(_n, 3)
generate double m = 0.4*x + 0.2*regress + rnormal()
generate double y = 0.7*m + 0.3*x + 0.2*regress + rnormal()
capture noisily gcomp y m x regress, outcome(y) mediation oce exposure(x) mediator(m) ///
    baseline(x: 0) commands(m: regress, y: regress) ///
    equations(m: x regress, y: i.x m regress) base_confs(regress) ///
    msm(regress y i.x regress) simulations(120) samples(2) seed(713)
local rc = _rc
display "RESULT: msm_command_collision rc=`rc'"
assert `rc' == 0

display "RESULT: test_msm_command_collision tests=1 pass=1 fail=0 status=PASS"

