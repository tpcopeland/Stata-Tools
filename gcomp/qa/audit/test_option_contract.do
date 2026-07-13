clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"

capture program drop make_tv
program define make_tv
    clear
    set seed 7411
    set obs 1200
    gen long id = ceil(_n/4)
    bysort id: gen double time = 2*_n - 1
    gen double L = rnormal() + .05*time
    gen byte Ainit = rbinomial(1, invlogit(-1.7 + .25*L))
    sort id time
    by id (time): gen byte A = sum(Ainit)>0
    drop Ainit
    gen double Yc = .6*A + .3*L + rnormal()
    gen byte Yb = rbinomial(1, invlogit(-1.2 + .5*A + .2*L))
end

* H04: monotreat validates the intervention model, not the outcome model.
make_tv
gcomp Yc L A id time, outcome(Yc) idvar(id) tvar(time) varyingcovariates(L) ///
    intvars(A) interventions(A=1, A=0) monotreat eofu pooled ///
    commands(L: regress, A: logit, Yc: regress) ///
    equations(L: time, A: L time, Yc: A L time) ///
    sim(180) samples(3) seed(81)
assert e(bootstrap_failed)==0

make_tv
gcomp Yb L A id time, outcome(Yb) idvar(id) tvar(time) varyingcovariates(L) ///
    intvars(A) interventions(A=1, A=0) monotreat eofu pooled ///
    commands(L: regress, A: logit, Yb: logit) ///
    equations(L: time, A: L time, Yb: A L time) ///
    sim(180) samples(3) seed(82)
assert e(bootstrap_failed)==0

make_tv
capture noisily gcomp Yb L A id time, outcome(Yb) idvar(id) tvar(time) varyingcovariates(L) ///
    intvars(A) interventions(A=1, A=0) monotreat eofu pooled ///
    commands(L: regress, A: regress, Yb: logit) ///
    equations(L: time, A: L time, Yb: A L time) ///
    sim(180) samples(3) seed(83)
assert _rc==198

make_tv
capture noisily gcomp Yc L A id time, outcome(Yc) idvar(id) tvar(time) varyingcovariates(L) ///
    intvars(A) interventions(A=1, A=0) monotreat eofu pooled ///
    commands(L: regress, A: regress, Yc: regress) ///
    equations(L: time, A: L time, Yc: A L time) ///
    sim(180) samples(3) seed(84)
assert _rc==198
display "RESULT: H04 intervention-command matrix status=PASS"

* H05: time-varying moreMC is rejected rather than silently ignored; ordinary
* requests are honored at/below N and visibly capped above N.
make_tv
gcomp Yc L A id time, outcome(Yc) idvar(id) tvar(time) varyingcovariates(L) ///
    intvars(A) interventions(A=1, A=0) eofu pooled ///
    commands(L: regress, A: logit, Yc: regress) ///
    equations(L: time, A: L time, Yc: A L time) ///
    sim(180) samples(3) seed(85)
assert e(MC_sims)==180

make_tv
gcomp Yc L A id time, outcome(Yc) idvar(id) tvar(time) varyingcovariates(L) ///
    intvars(A) interventions(A=1, A=0) eofu pooled ///
    commands(L: regress, A: logit, Yc: regress) ///
    equations(L: time, A: L time, Yc: A L time) ///
    sim(300) samples(3) seed(86)
assert e(MC_sims)==300

make_tv
gcomp Yc L A id time, outcome(Yc) idvar(id) tvar(time) varyingcovariates(L) ///
    intvars(A) interventions(A=1, A=0) eofu pooled ///
    commands(L: regress, A: logit, Yc: regress) ///
    equations(L: time, A: L time, Yc: A L time) ///
    sim(450) samples(3) seed(87)
assert e(MC_sims)==300

make_tv
capture noisily gcomp Yc L A id time, outcome(Yc) idvar(id) tvar(time) varyingcovariates(L) ///
    intvars(A) interventions(A=1, A=0) eofu pooled moreMC ///
    commands(L: regress, A: logit, Yc: regress) ///
    equations(L: time, A: L time, Yc: A L time) ///
    sim(450) samples(3) seed(88)
assert _rc==198
display "RESULT: H05 Monte-Carlo-count contract status=PASS"

* H06: reject graph/eofu no-ops and create an isolated named graph on the one
* supported path without replacing a caller graph named Graph.
make_tv
capture noisily gcomp Yb L A id time, outcome(Yb) idvar(id) tvar(time) varyingcovariates(L) ///
    intvars(A) interventions(A=1, A=0) eofu pooled graph ///
    commands(L: regress, A: logit, Yb: logit) ///
    equations(L: time, A: L time, Yb: A L time) ///
    sim(180) samples(3) seed(89)
assert _rc==198

clear
set seed 7412
set obs 700
gen double c=rnormal()
gen byte x=rbinomial(1,invlogit(.2*c))
gen byte m=rbinomial(1,invlogit(-.5+.6*x+.2*c))
gen byte y=rbinomial(1,invlogit(-1+.5*x+.7*m+.2*c))
capture noisily gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) graph sim(300) samples(3) seed(90)
assert _rc==198
capture noisily gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) eofu sim(300) samples(3) seed(90)
assert _rc==198

make_tv
quietly scatter Yb L, name(Graph, replace)
gcomp Yb L A id time, outcome(Yb) idvar(id) tvar(time) varyingcovariates(L) ///
    intvars(A) interventions(A=1, A=0) pooled graph ///
    commands(L: regress, A: logit, Yb: logit) ///
    equations(L: time, A: L time, Yb: A L time) ///
    sim(180) samples(3) seed(91)
local created "`e(graph)'"
assert "`created'"!="" & "`created'"!="Graph"
capture graph describe Graph
assert _rc==0
capture graph describe `created'
assert _rc==0
display "RESULT: H06 mode/graph compatibility status=PASS graph=`created'"

display "RESULT: gcomp_option_contract_probe status=PASS"

display "RESULT: test_option_contract tests=1 pass=1 fail=0 status=PASS"

