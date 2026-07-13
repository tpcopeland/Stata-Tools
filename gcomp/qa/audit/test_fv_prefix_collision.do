version 16.0
clear all
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"
set seed 714
set obs 240
generate double c = rnormal()
generate double z = rnormal()
generate byte x = mod(_n, 2)
generate double m = 0.4*x + 0.2*z + 0.1*c + rnormal()
generate double y = 0.7*m + 0.3*x + 0.2*z + 0.1*c + rnormal()
capture noisily gcomp y m x c z, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: regress, y: regress) equations(m: x c.z c, y: m x c.z c) ///
    base_confs(c z) simulations(100) samples(2) seed(714)
local rc = _rc
display "RESULT: fv_prefix_collision rc=`rc'"
assert `rc' == 0

display "RESULT: test_fv_prefix_collision tests=1 pass=1 fail=0 status=PASS"

