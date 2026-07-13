clear all
set more off
version 16.0
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"

set seed 9401
set obs 900
gen long row=_n
gen double c=rnormal()
gen byte x=rbinomial(1,invlogit(.2*c))
gen byte m=rbinomial(1,invlogit(-.5+.7*x+.2*c))
gen byte y=rbinomial(1,invlogit(-1+.5*x+.7*m+.2*c))

quietly regress y x c
estimates store _gcomp_m_1
tempname caller_b
matrix `caller_b'=e(b)

gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) sim(420) samples(3) seed(151)
tempname ordinary_b
matrix `ordinary_b'=e(b)

* H15: capture is explicitly an approximation, names are collision-free and
* persistent, diagnostics contain only real models, and optional capture does
* not perturb the stochastic point/bootstrap stream.
gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) sim(420) samples(3) seed(151) savemodels diagnostics
assert "`e(model_capture)'"=="analytic_sample_refit_approximation"
assert e(N_models)==2
assert "`e(model_depvars)'"=="m y"
assert "`e(model_skipped)'"==""
assert "`e(msm)'"==""
local model_names "`e(model_names)'"
assert `: word count `model_names''==2
foreach nm of local model_names {
    assert "`nm'"!="_gcomp_m_1"
    capture estimates restore `nm'
    assert _rc==0
    capture estimates replay `nm'
    assert _rc==0
}

tempname captured_b diag delta
matrix `captured_b'=e(b)
* Restore gcomp's active results after replaying component models.
gcomp y m x c, outcome(y) mediation obe exposure(x) mediator(m) ///
    commands(m: logit, y: logit) equations(m: x c, y: m x c) ///
    base_confs(c) sim(420) samples(3) seed(151) savemodels diagnostics
matrix `captured_b'=e(b)
matrix `diag'=e(model_diagnostics)
local diag_rows : rownames `diag'
assert "`diag_rows'"=="m y"
assert rowsof(`diag')==2 & colsof(`diag')==5
matrix `delta'=`ordinary_b'-`captured_b'
mata: st_numscalar("max_rng_delta", max(abs(st_matrix("`delta'"))))
assert max_rng_delta<1e-13

* The historical predictable caller estimate remains byte-for-byte restorable.
estimates restore _gcomp_m_1
tempname restored_b caller_delta
matrix `restored_b'=e(b)
matrix `caller_delta'=`restored_b'-`caller_b'
mata: st_numscalar("max_caller_delta", max(abs(st_matrix("`caller_delta'"))))
assert max_caller_delta<1e-13

* Nonpooled time-varying capture is retained but unambiguously labelled as a
* pooled analytic-sample refit approximation rather than an exact loop fit.
clear
set seed 9402
set obs 1200
gen long id=ceil(_n/4)
bysort id: gen double time=2*_n-1
gen double L=rnormal()+.1*time
gen byte A=rbinomial(1,invlogit(-.8+.2*L))
gen double Y=.5*A+.3*L+rnormal()
gcomp Y L A id time, outcome(Y) idvar(id) tvar(time) varyingcovariates(L) ///
    intvars(A) interventions(A=1, A=0) eofu ///
    commands(L: regress, A: logit, Y: regress) ///
    equations(L: time, A: L time, Y: A L time) ///
    sim(160) samples(3) seed(152) savemodels
assert "`e(model_capture)'"=="analytic_sample_refit_approximation"
assert e(N_models)==3
assert "`e(model_depvars)'"=="L A Y"
assert "`e(cmdline)'"!=""
assert "`e(idvar)'"=="id" & "`e(tvar)'"=="time"
assert "`e(intvars)'"=="A"
assert "`e(interventions)'"=="A=1, A=0"
assert e(bootstrap_requested)==3
assert e(bootstrap_successful)==3
assert e(bootstrap_failed)==0

display "RESULT: H15 model capture/metadata/replay status=PASS"
display "RESULT: gcomp_model_metadata_probe status=PASS"

display "RESULT: test_model_metadata tests=1 pass=1 fail=0 status=PASS"

