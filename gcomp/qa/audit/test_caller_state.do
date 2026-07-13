clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"
set seed 3301
set obs 600
gen long row = _n
gen double c = rnormal()
gen byte x = rbinomial(1, invlogit(.2*c))
gen byte m = rbinomial(1, invlogit(-.6 + .7*x + .3*c))
gen byte y = rbinomial(1, invlogit(-1 + .5*x + .7*m + .2*c))
sort x row
tempfile before graph_before graph_after
matrix b = (11, 12)
matrix V = (21, 22 \ 23, 24)
matrix se = (31)
matrix matvis = (41)
matrix EPO = (51)
matrix catvals = (61)
matrix _gc_diag_result = (71)
global S_1 "caller-one"
global S_51 "caller-fifty-one"
scalar caller_scalar = 81
mata: b = 91
frame create caller_frame
frame caller_frame: set obs 1
frame caller_frame: gen marker = 101
quietly scatter y c, name(Graph, replace)
graph save Graph `"`graph_before'"', replace
quietly regress y x c
estimates store caller_est
set varabbrev off
save `before'

gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) simulations(350) samples(3) seed(48)
cf _all using `before', all
assert b[1,1] == 11 & b[1,2] == 12
assert V[2,1] == 23 & V[2,2] == 24
assert se[1,1] == 31
assert matvis[1,1] == 41
assert EPO[1,1] == 51
assert catvals[1,1] == 61
assert _gc_diag_result[1,1] == 71
assert "$S_1" == "caller-one"
assert "$S_51" == "caller-fifty-one"
assert caller_scalar == 81
mata: assert(b == 91)
frame caller_frame: assert marker == 101
estimates restore caller_est
assert e(cmd) == "regress"
graph save Graph `"`graph_after'"', replace
assert c(varabbrev) == "off"

capture noisily gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) simulations(350) samples(3) seed(-1)
assert _rc == 198
cf _all using `before', all
assert b[1,1] == 11 & V[2,2] == 24
assert "$S_1" == "caller-one" & "$S_51" == "caller-fifty-one"
mata: assert(b == 91)
frame caller_frame: assert marker == 101
capture graph describe Graph
assert _rc == 0
capture estimates restore caller_est
assert _rc == 0
set varabbrev on
display "RESULT: gcomp_caller_state_probe status=PASS"

display "RESULT: test_caller_state tests=1 pass=1 fail=0 status=PASS"

