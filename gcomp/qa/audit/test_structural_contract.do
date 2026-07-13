clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"

capture program drop make_med
program define make_med
    clear
    set seed 8801
    set obs 700
    gen long row=_n
    gen double c=rnormal()
    gen byte x=rbinomial(1,invlogit(.2*c))
    gen byte m=rbinomial(1,invlogit(-.5+.7*x+.2*c))
    gen byte y=rbinomial(1,invlogit(-1+.5*x+.7*m+.2*c))
end

capture program drop run_med
program define run_med, eclass
    gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        base_confs(c) sim(300) samples(3) seed(101)
end

* C07: the supported binary OBE/logit structures are exactly 0/1.
make_med
label define binary 0 "No" 1 "Yes"
label values x m y binary
run_med
assert e(bootstrap_failed)==0

foreach coding in zero_two one_two three_level {
    make_med
    if "`coding'"=="zero_two" replace x=2 if x==1
    if "`coding'"=="one_two" replace x=x+1
    if "`coding'"=="three_level" replace x=2 in 1/20
    capture noisily run_med
    assert inlist(_rc,459,2000)
}

make_med
replace x=0
capture noisily run_med
assert _rc==2000
make_med
replace x=1
capture noisily run_med
assert _rc==2000

make_med
replace m=2 if m==1
capture noisily run_med
assert _rc==459

make_med
replace m=.a in 1/15
replace x=.z in 16/25
run_med
assert e(bootstrap_failed)==0
display "RESULT: C07 OBE/logit support matrix status=PASS"

capture program drop make_tv_struct
program define make_tv_struct
    clear
    set seed 8802
    set obs 1000
    gen long id=ceil(_n/5)
    bysort id: gen double time=2*_n-1
    gen double C=rnormal()
    bysort id: replace C=C[1]
    gen double L=rnormal()+.1*time+.2*C
    gen byte init=rbinomial(1,invlogit(-2+.2*L))
    sort id time
    by id: gen byte A=sum(init)>0
    drop init
    gen byte D=rbinomial(1,invlogit(-3+.1*time))
    gen byte Y=rbinomial(1,invlogit(-2+.4*A+.2*L))
end

* Monotreatment coding and absorbing-history contracts.
make_tv_struct
replace A=2 if A==1
capture noisily gcomp Y L A C id time, outcome(Y) idvar(id) tvar(time) ///
    varyingcovariates(L) fixedcovariates(C) intvars(A) ///
    interventions(A=1, A=0) monotreat eofu pooled ///
    commands(L: regress, A: logit, Y: logit) ///
    equations(L: C time, A: L C time, Y: A L C time) sim(120) samples(3) seed(102)
assert _rc==459

make_tv_struct
replace A=1 if id==1 & time==1
replace A=0 if id==1 & time==3
capture noisily gcomp Y L A C id time, outcome(Y) idvar(id) tvar(time) ///
    varyingcovariates(L) fixedcovariates(C) intvars(A) ///
    interventions(A=1, A=0) monotreat eofu pooled ///
    commands(L: regress, A: logit, Y: logit) ///
    equations(L: C time, A: L C time, Y: A L C time) sim(120) samples(3) seed(103)
assert _rc==459

* death() value and absorbing event-history contracts.
make_tv_struct
replace D=2 in 1
capture noisily gcomp Y D L A C id time, outcome(Y) idvar(id) tvar(time) ///
    varyingcovariates(L) fixedcovariates(C) intvars(A) death(D) ///
    interventions(A=1, A=0) eofu pooled ///
    commands(D: logit, L: regress, A: logit, Y: logit) ///
    equations(D: time, L: C time, A: L C time, Y: A L C time) ///
    sim(120) samples(3) seed(104)
assert _rc==459

make_tv_struct
replace D=0
replace D=1 if id==1 & time==1
capture noisily gcomp Y D L A C id time, outcome(Y) idvar(id) tvar(time) ///
    varyingcovariates(L) fixedcovariates(C) intvars(A) death(D) ///
    interventions(A=1, A=0) eofu pooled ///
    commands(D: logit, L: regress, A: logit, Y: logit) ///
    equations(D: time, L: C time, A: L C time, Y: A L C time) ///
    sim(120) samples(3) seed(105)
assert _rc==459
display "RESULT: C07 monotreat/death histories status=PASS"

* H13: panel keys and fixed covariates fail early; numeric gaps and unsorted
* input are deliberate supported cases.
make_tv_struct
expand 2 in 1
capture noisily gcomp Y L A C id time, outcome(Y) idvar(id) tvar(time) ///
    varyingcovariates(L) fixedcovariates(C) intvars(A) interventions(A=1, A=0) ///
    eofu pooled commands(L: regress, A: logit, Y: logit) ///
    equations(L: C time, A: L C time, Y: A L C time) sim(120) samples(3) seed(106)
assert _rc==459

make_tv_struct
replace C=C+.5 if id==2 & time==9
capture noisily gcomp Y L A C id time, outcome(Y) idvar(id) tvar(time) ///
    varyingcovariates(L) fixedcovariates(C) intvars(A) interventions(A=1, A=0) ///
    eofu pooled commands(L: regress, A: logit, Y: logit) ///
    equations(L: C time, A: L C time, Y: A L C time) sim(120) samples(3) seed(107)
assert _rc==459

make_tv_struct
gen str8 sid="s"+string(id)
capture noisily gcomp Y L A C id time, outcome(Y) idvar(sid) tvar(time) ///
    varyingcovariates(L) fixedcovariates(C) intvars(A) interventions(A=1, A=0) ///
    eofu pooled commands(L: regress, A: logit, Y: logit) ///
    equations(L: C time, A: L C time, Y: A L C time) sim(120) samples(3) seed(108)
assert _rc==109

make_tv_struct
gsort -time id
tempfile unsorted_before
save `unsorted_before'
gcomp Y L A C id time, outcome(Y) idvar(id) tvar(time) ///
    varyingcovariates(L) fixedcovariates(C) intvars(A) interventions(A=1, A=0) ///
    eofu pooled commands(L: regress, A: logit, Y: logit) ///
    equations(L: C time, A: L C time, Y: A L C time) sim(120) samples(3) seed(109)
cf _all using `unsorted_before', all
assert e(bootstrap_failed)==0

make_med
capture noisily gcomp y m x c, outcome(y) mediation oce exposure(x) mediator(m) ///
    baseline(x: 99) commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) sim(300) samples(3) seed(110)
assert _rc==459
display "RESULT: H13 panel/fixed/baseline invariants status=PASS"

display "RESULT: gcomp_structural_contract_probe status=PASS"

display "RESULT: test_structural_contract tests=1 pass=1 fail=0 status=PASS"

