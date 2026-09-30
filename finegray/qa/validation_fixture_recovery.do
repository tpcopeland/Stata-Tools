*! validation_fixture_recovery.do -- independent-reference/DGP FG truth recovery
version 16.0
clear all
set processors 1
set varabbrev off
capture log close _all
log using "validation_fixture_recovery.log", text replace
local pkgdir = regexr("`c(pwd)'", "/qa$", "")
adopath ++ "`pkgdir'"
quietly do "_qa_fx_a2.do"
quietly do "_qa_hostile.do"
local tests = 0
local pass = 0
local fail = 0
foreach seed in 1701 967 {
foreach censor in admin random {
    local ++tests
    capture noisily {
        local copt ""
        if "`censor'"=="random" local copt "censoring"
        qa_fx_a2_pwexp, clear n(2400) model(finegray) seed(`seed') `copt'
        matrix truthb=r(truth_b_fg)
        matrix truthcurve=r(truth_curve)
        quietly stset t, failure(d) id(id)
        // Independent native reference bound, not analytic Monte Carlo SE.
        // Continuous primary/competing times eliminate failure-tie ambiguity;
        // independent Exp(.04) or admin censoring matches native FG assumptions.
        quietly stset t, failure(cause==1) id(id)
        quietly stcrreg x1 x2, compete(cause==2) nolog
        matrix referenceV=e(V)
        quietly stset t, failure(d) id(id)
        finegray x1 x2, compete(cause) cause(1) nolog
        assert e(converged)==1 & e(N)==2400
        foreach cov in x1 x2 {
            scalar target=truthb[1,colnumb(truthb,"`cov'")]
            assert !missing(target,_b[`cov'],referenceV[colnumb(referenceV,"`cov'"),colnumb(referenceV,"`cov'")]) & referenceV[colnumb(referenceV,"`cov'"),colnumb(referenceV,"`cov'")]>0
            assert abs(_b[`cov']-target)<4*sqrt(referenceV[colnumb(referenceV,"`cov'"),colnumb(referenceV,"`cov'")])
        }
        forvalues a=0/1 {
            forvalues x=0/1 {
                finegray_cif, at(x1=`a' x2=`x') attime(2 5 8) ci nograph
                matrix got=r(table)
                assert rowsof(got)==3 & colsof(got)==5
                forvalues k=1/3 {
                    scalar horizon=got[`k',1]
                    local row=(2*`a'+`x')*9+scalar(horizon)+1
                    scalar target=truthcurve[`row',6]
                    scalar G=cond("`censor'"=="random",exp(-.04*horizon),1)
                    scalar independent_cif_se=sqrt((target/G-target^2)/600)
                    assert !missing(target,got[`k',2],independent_cif_se) & independent_cif_se>0
                    assert abs(got[`k',2]-target)<4*independent_cif_se
                }
            }
        }
        display "RECOVERY seed=`seed' `censor': b=" %12.8f _b[x1] " " %12.8f _b[x2]
    }
    if _rc local ++fail
    else local ++pass
}
}
display "RESULT: validation_fixture_recovery tests=`tests' pass=`pass' fail=`fail' skip=0"
log close
* Leave the adopath as found: a later suite in the same run must reach the installed copy.
capture adopath - "`pkgdir'"
if `fail' exit 9
