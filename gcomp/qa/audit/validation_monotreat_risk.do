clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"
set seed 1462
set obs 800
gen long id = ceil(_n/4)
bysort id: gen int time = 2*_n - 1
by id: gen byte visit = _n
gen double L = rnormal(.2*time, 1)
gen byte A = 0
gen int init = mod(id, 5) + 1
replace A = 1 if init <= 4 & visit >= init
bysort id (time): gen double Llag = cond(_n == 1, 0, L[_n-1])
bysort id (time): gen byte Alag = cond(_n == 1, 0, A[_n-1])
gen double Y = 1 + .7*A + .3*L + rnormal() if time == 7
isid id time
tempvar prior atrisk ord
gen long `ord' = _n
bysort id (time): gen long `prior' = sum(A == 1) - (A == 1)
gen byte `atrisk' = (`prior' == 0)
quietly count if `atrisk'
local oracle_N = r(N)
quietly logit A L Llag if `atrisk'
tempname oracle
matrix `oracle' = e(b)
sort `ord'

gcomp Y L A Llag Alag id time, outcome(Y) idvar(id) tvar(time) ///
    varyingcovariates(L) laggedvars(Llag Alag) ///
    lagrules(Llag: L 1, Alag: A 1) ///
    commands(Y: regress, L: regress, A: logit) ///
    equations(Y: A L, L: Llag Alag, A: L Llag) ///
    intvars(A) interventions(A=1, A=0) pooled monotreat eofu ///
    simulations(200) samples(3) seed(118) savemodels diagnostics
local deps "`e(model_depvars)'"
local names "`e(model_names)'"
local apos : list posof "A" in deps
assert `apos' > 0
local aname : word `apos' of `names'
estimates restore `aname'
assert e(N) == `oracle_N'
tempname actual
matrix `actual' = e(b)
local onames : colfullnames `oracle'
local anames : colfullnames `actual'
assert `"`onames'"' == `"`anames'"'
forvalues j = 1/`=colsof(`oracle')' {
    assert reldif(`oracle'[1,`j'], `actual'[1,`j']) < 1e-13
}
display "RESULT: gcomp_monotreat_risk_probe status=PASS N=" e(N)

display "RESULT: validation_monotreat_risk tests=1 pass=1 fail=0 status=PASS"

