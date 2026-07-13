clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"

capture program drop make_tv_rule
program define make_tv_rule
    clear
    set seed 9011
    set obs 1200
    gen long id=ceil(_n/4)
    bysort id: gen double time=2*_n-1
    gen double L=rnormal()+.1*time
    gen byte A=rbinomial(1,invlogit(-.8+.2*L))
    gen double Y=.5*A+.3*L+rnormal()
    gen double d1=0
    gen double d2=0
end

* H11: valid conditional assignment is applied, while malformed, missing,
* no-op, and all-missing rules cannot silently continue.
make_tv_rule
tempfile conditional
gcomp Y L A id time, outcome(Y) idvar(id) tvar(time) varyingcovariates(L) ///
    intvars(A) interventions(A=1 if L>0, A=0) eofu pooled ///
    commands(L: regress, A: logit, Y: regress) ///
    equations(L: time, A: L time, Y: A L time) ///
    sim(150) samples(3) seed(121) saving(`"`conditional'"') replace
preserve
use `conditional', clear
assert A==1 if _int==1 & L>0
restore

foreach badrule in "A=no_such_function(L)" "A=not_here" "A=1 if" "A=A" "Z=1" "A=." {
    make_tv_rule
    tempfile state
    save `state'
    capture noisily gcomp Y L A id time, outcome(Y) idvar(id) tvar(time) varyingcovariates(L) ///
        intvars(A) interventions(`badrule', A=0) eofu pooled ///
        commands(L: regress, A: logit, Y: regress) ///
        equations(L: time, A: L time, Y: A L time) ///
        sim(150) samples(3) seed(122)
    assert _rc!=0
    cf _all using `state', all
}

make_tv_rule
gcomp Y L A d1 d2 id time, outcome(Y) idvar(id) tvar(time) ///
    varyingcovariates(L) derived(d1 d2) derrules(d1: L^2, d2: d1+L) ///
    intvars(A) interventions(A=1, A=0) eofu pooled ///
    commands(L: regress, A: logit, Y: regress) ///
    equations(L: time, A: d1 d2 time, Y: A L d2 time) ///
    sim(150) samples(3) seed(123)
assert e(bootstrap_failed)==0

make_tv_rule
capture noisily gcomp Y L A d1 d2 id time, outcome(Y) idvar(id) tvar(time) ///
    varyingcovariates(L) derived(d1 d2) derrules(d1: d2+1, d2: d1+1) ///
    intvars(A) interventions(A=1, A=0) eofu pooled ///
    commands(L: regress, A: logit, Y: regress) ///
    equations(L: time, A: d1 d2 time, Y: A L d2 time) ///
    sim(150) samples(3) seed(124)
assert _rc==198

make_tv_rule
capture noisily gcomp Y L A d1 id time, outcome(Y) idvar(id) tvar(time) ///
    varyingcovariates(L) derived(d1) derrules(d1: no_such_variable+1) ///
    intvars(A) interventions(A=1, A=0) eofu pooled ///
    commands(L: regress, A: logit, Y: regress) ///
    equations(L: time, A: d1 time, Y: A L time) ///
    sim(150) samples(3) seed(125)
assert _rc!=0
display "RESULT: H11 checked rule execution/topology status=PASS"

capture program drop make_imp
program define make_imp
    clear
    set seed 9012
    set obs 800
    gen long row=_n
    gen double z=rnormal()
    gen double c=.5*z+rnormal()
    gen byte x=rbinomial(1,invlogit(.2*c))
    gen byte m=rbinomial(1,invlogit(-.5+.7*x+.2*c))
    gen byte y=rbinomial(1,invlogit(-1+.5*x+.7*m+.2*c))
end

* H12: only rows needing target imputation are screened for predictor
* availability; target-level counts are posted for audit.
make_imp
replace c=. in 1/100
replace z=. in 1/50
replace z=. in 101/150
gcomp y m x c z row, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) impute(c) imp_cmd(c: regress) imp_eq(c: z) imp_cycles(3) ///
    sim(350) samples(3) seed(131)
assert e(N_rows)==750
assert e(N_impute_targets)==1
assert e(impute_needed_1)==100
assert e(impute_dropped_1)==50
assert e(impute_eligible_1)==50
assert e(sample)==1 in 101
assert e(sample)==0 in 1

* Role restrictions, complete one-to-one maps, and imputation model support.
foreach forbidden in x y {
    make_imp
    replace `forbidden'=. in 1/20
    capture noisily gcomp y m x c z, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
        base_confs(c) impute(`forbidden') imp_cmd(`forbidden': logit) ///
        imp_eq(`forbidden': c z) sim(300) samples(3) seed(132)
    assert _rc==198
}

make_imp
replace c=. in 1/20
capture noisily gcomp y m x c z, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c z) impute(c z) imp_cmd(c: regress) ///
    imp_eq(c: z, z: c) sim(300) samples(3) seed(133)
assert _rc==198

make_imp
replace c=. in 1/20
capture noisily gcomp y m x c z, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) impute(c c) imp_cmd(c: regress) ///
    imp_eq(c: z) sim(300) samples(3) seed(134)
assert _rc==198

make_imp
replace c=. in 1/20
capture noisily gcomp y m x c z, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) impute(c) imp_cmd(c: logit) ///
    imp_eq(c: z) sim(300) samples(3) seed(135)
assert _rc==459

* Cyclic FCS equations across distinct targets are deliberate and supported;
* they are iterated in impute() order rather than misclassified as a DAG.
make_imp
replace c=. if mod(row,7)==0
replace z=. if mod(row,7)==1
gcomp y m x c z row, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c z, y: m x c z) ///
    base_confs(c z) impute(c z) imp_cmd(c: regress, z: regress) ///
    imp_eq(c: z x, z: c x) imp_cycles(3) sim(350) samples(3) seed(136)
assert e(N_impute_targets)==2
assert e(impute_eligible_1)>0 & e(impute_eligible_2)>0
assert e(bootstrap_failed)==0
display "RESULT: H12 imputation eligibility/maps/FCS status=PASS"

display "RESULT: gcomp_rules_imputation_probe status=PASS"

display "RESULT: test_rules_imputation tests=1 pass=1 fail=0 status=PASS"

