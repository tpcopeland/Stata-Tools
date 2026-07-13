version 16.0
clear all
set varabbrev on
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"

set seed 7132026
set obs 120
generate double c = rnormal()
generate byte x = mod(_n, 2)
generate double m = 0.4*x + 0.2*c + rnormal()
generate double y = 0.6*m + 0.3*x + 0.2*c + rnormal()

quietly regress y c
tempname before_b
matrix `before_b' = e(b)
local before_cmd "`e(cmd)'"
local before_depvar "`e(depvar)'"

capture noisily gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: regress, y: regress) equations(m: x c, y: m x c) ///
    base_confs(c) simulations(80) samples(2) seed(713) ///
    savemodels saving("/definitely/not/a/real/directory/gcomp.dta") replace
local rc = _rc
assert `rc' != 0
assert "`e(cmd)'" == "`before_cmd'"
assert "`e(depvar)'" == "`before_depvar'"
tempname after_b diff_b maxdiff
matrix `after_b' = e(b)
matrix `diff_b' = `after_b' - `before_b'
mata: st_numscalar(st_local("maxdiff"), max(abs(st_matrix(st_local("diff_b")))))
assert `maxdiff' == 0
quietly estimates dir
assert strpos(" `r(names)' ", " _gcmp") == 0
assert "`c(varabbrev)'" == "on"
display "RESULT: late_error_state status=PASS rc=`rc'"

display "RESULT: test_late_error_state tests=1 pass=1 fail=0 status=PASS"

