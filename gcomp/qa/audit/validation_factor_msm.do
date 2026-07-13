clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"
set seed 774
set obs 2400
gen double c=rnormal()
gen byte x=mod(_n,3)
gen double m=.7*x+.2*c+rnormal()
gen double y=1.4*(x==1)+3.1*(x==2)+.3*m+.1*c+rnormal(0,.2)
gcomp y m x c, outcome(y) mediation oce exposure(x) mediator(m) ///
    baseline(x: 0) commands(m: regress, y: regress) equations(m: x c, y: i.x m c) ///
    base_confs(c) msm(regress y i.x) sim(1200) samples(3) seed(2281)
matrix B=e(b)
local cn : colfullnames B
display "COLFULLNAMES: `cn'"
assert colsof(B)>=11
assert B[1,1]!=B[1,2]
local c1 : word 1 of `cn'
local c2 : word 2 of `cn'
assert `"`c1'"'!=`"`c2'"'
assert strpos(`"`c1'"',".x")
assert strpos(`"`c2'"',".x")
assert strpos(`"`c1'"',"1")
assert strpos(`"`c2'"',"2")
assert `"`e(msm)'"'=="regress y i.x"
display "MSM_COLNAMES: `e(msm_colnames)'"
assert `"`e(msm_colnames)'"'==`"`c1' `c2' _cons"'
display "RESULT: factor_msm_probe status=PASS"

display "RESULT: validation_factor_msm tests=1 pass=1 fail=0 status=PASS"

