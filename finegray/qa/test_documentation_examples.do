* test_documentation_examples.do
* Every runnable code block in README.md and in the Examples section of all four
* command help files must run for an installed user, verbatim, with rc 0.  This
* is the axis the release gate `runnable_examples' probes and the one the other
* suites do not: they test the commands, not the documented invocations of them.
* A doc example that no longer parses -- a renamed option, a dropped default, a
* changed syntax, a block that references variables the dataset above it does
* not have -- is invisible to every test that calls the command its own way.
*
* SCOPE (widened 2026-09-02).  Before this the suite ran 10 of about 40
* documented blocks and NOTHING from finegray_cif.sthlp or
* finegray_predict.sthlp.  It now runs, in help-file order:
*   FGH-*   every block of finegray.sthlp {title:Examples}
*   CIFH-*  every block of finegray_cif.sthlp {title:Examples}
*   PRDH-*  every block of finegray_predict.sthlp {title:Examples}
*   PHTH-*  every block of finegray_phtest.sthlp {title:Examples}
*   RDM-*   README.md Quick Start and worked examples 1-12 (3a, 6a, 6b, 6c
*           included), plus the doc-advertised invocations that appear in the
*           prose only
*
* Each block is copied AS PRINTED.  Do not "improve" them here; if a block needs
* changing, change the doc first, then mirror it.  Blocks within one help file
* run IN ORDER and share state, exactly as a reader working down the page would
* have them: a block that silently depended on a dataset the block above it left
* in memory is the failure mode this ordering exists to catch.  Two blocks are
* documented REFUSALS and are asserted at rc 198 rather than rc 0:
*   FGH-21b  `finegray age pneumonia' (finegray.sthlp, internal time-varying
*            covariate)
*   RDM-12a  the same refusal in README worked example 12
*
* WATCHED FAIL 2026-09-02.  Run against the pre-fix help file, FGH-22 and FGH-23
* (the bootstrap wrapper and the stcrreg comparison) failed r(111): both blocks
* referenced hypoxia variables while the block above them had left `pneumonia'
* in memory.  The help file now reloads hypoxia at the head of FGH-22, and the
* two blocks are executed here as printed, in sequence after the pneumonia
* block, so the same regression cannot return unseen.  The same run turned up
* `bootstrap ..., nolog' as r(198) -- `nolog' is not a bootstrap prefix option;
* it belongs to the finegray call inside the wrapper program, where README has
* it.
*
* RUNTIME.  Measured 2026-09-02 on this machine, the slowest documented blocks
* are CIFH-10 `bootstrap(500)' 4.6s, PRDH-07 `bootstrap(200)' 1.5s, FGH-22
* `bootstrap _b, reps(200)' 1.6s and the two `mi impute regress ... add(10)'
* blocks.  Every block is run at the reps the documentation prints; none is
* silently reduced, and none approaches the three-minute mark.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_documentation_examples.log", replace name(_docex)

local pkgroot "`c(pwd)'"
capture confirm file "`pkgroot'/finegray.pkg"
if _rc {
    capture confirm file "`pkgroot'/../finegray.pkg"
    if _rc {
        display as error "could not locate finegray package root"
        exit 601
    }
    local pkgroot "`pkgroot'/.."
}
capture ado uninstall finegray
quietly net install finegray, from("`pkgroot'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* Run one documented block; PASS iff it completes with rc 0.  Blocks are wrapped
* in capture noisily so a failure is reported, not fatal, and the remaining
* blocks still run.
capture program drop _docblock
program define _docblock
    args tag
    display as text _newline "=== example: `tag' ==="
end

* One PASS/FAIL line per documented block.  `want' is the rc the DOCUMENTATION
* claims: 0 for a runnable block, 198 for the two blocks printed as refusals.
capture program drop _docres
program define _docres, rclass
    args rc label want
    if "`want'" == "" local want 0
    if `rc' == `want' {
        display as result "  PASS: `label'"
        return scalar pass = 1
        return scalar fail = 0
    }
    else {
        display as error "  FAIL: `label' (rc=`rc', documented rc=`want')"
        return scalar pass = 0
        return scalar fail = 1
    }
end

* =============================================================================
* finegray.sthlp {title:Examples} -- every block, in printed order
* =============================================================================

local ++test_count
capture noisily {
    _docblock "FGH-01 help finegray Setup"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-01 help finegray Setup" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-02 help finegray Basic model"
    finegray ifp tumsize pelnode, compete(status) cause(1)
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-02 help finegray Basic model" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-03 help finegray Stratified censoring distribution"
    finegray ifp tumsize, compete(status) cause(1) strata(pelnode)
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-03 help finegray Stratified censoring distribution" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-04 help finegray Stratified baseline subhazard"
    finegray ifp tumsize, compete(status) cause(1) bstrata(pelnode)
    finegray_cif, attime(1 5) bstratum(0) ci
    finegray_cif, attime(1 5) bstratum(1) ci
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-04 help finegray Stratified baseline subhazard" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-05 help finegray Baseline and censoring both stratified"
    finegray ifp tumsize, compete(status) cause(1) bstrata(pelnode) strata(pelnode)
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-05 help finegray Baseline and censoring both stratified" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-06 help finegray Piecewise-constant time-varying effect"
    finegray ifp tumsize pelnode, compete(status) cause(1) tvc(pelnode) tsplit(1)
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-06 help finegray Piecewise-constant time-varying effect" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-07 help finegray test of a constant effect"
    test [tvc1]pelnode = [tvc2]pelnode
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-07 help finegray test of a constant effect" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-08 help finegray three intervals, xb at a time, CIF"
    finegray ifp tumsize pelnode, compete(status) cause(1) tvc(pelnode) tsplit(0.5 1.5)
    finegray_predict xb2, xb attime(2)
    finegray_cif, at(ifp=20 tumsize=5 pelnode=0) attime(1 3 5)
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-08 help finegray three intervals, xb at a time, CIF" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-09 help finegray Sampling weights"
    gen double sw = cond(pelnode == 1, 2, 1)
    finegray ifp tumsize [pweight = sw], compete(status) cause(1)
    finegray_cif, attime(1 5) ci
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-09 help finegray Sampling weights" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-10 help finegray Model-based standard errors"
    finegray ifp tumsize pelnode, compete(status) cause(1) norobust
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-10 help finegray Model-based standard errors" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-11 help finegray Log-SHR"
    finegray ifp tumsize pelnode, compete(status) cause(1) noshr
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-11 help finegray Log-SHR" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-12 help finegray CIF prediction"
    finegray ifp tumsize pelnode, compete(status) cause(1)
    finegray_predict cif_hat, cif
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-12 help finegray CIF prediction" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-13 help finegray CIF curve and fixed-horizon table"
    finegray_cif, ci
    finegray_cif, attime(1 5 8) ci
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-13 help finegray CIF curve and fixed-horizon table" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-14 help finegray Factor variables"
    finegray i.pelnode ifp, compete(status) cause(1)
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-14 help finegray Factor variables" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-15 help finegray Factor variables with specified base category"
    finegray ib1.pelnode ifp, compete(status) cause(1)
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-15 help finegray Factor variables with specified base category" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-16 help finegray Interaction factor x continuous"
    finegray i.pelnode##c.ifp tumsize, compete(status) cause(1)
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-16 help finegray Interaction factor x continuous" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-17 help finegray Margins"
    finegray ifp tumsize pelnode, compete(status) cause(1)
    margins, at(ifp=(0 5 10)) predict(xb)
    margins, dydx(ifp) predict(xb)

    finegray i.pelnode##c.ifp tumsize, compete(status) cause(1)
    margins pelnode
    margins, dydx(pelnode) at(ifp=(5 15))
    contrast pelnode
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-17 help finegray Margins" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-18 help finegray Delayed entry with entry strata"
    clear
    set seed 20260713
    set obs 24000
    gen byte z1 = runiform() < 0.5
    gen double z2 = rnormal()
    gen double ez = exp(0.5*z1 - 0.5*z2)
    gen double p1 = 1 - (1 - 0.5)^ez
    gen byte cause = cond(runiform() < p1, 1, 2)
    gen double v = runiform()
    gen double event_time = -ln(1 - (1 - (1 - v*p1)^(1/ez))/0.5) if cause == 1
    replace event_time = rexponential(1/(0.5*exp(0.5*z1 + 0.5*z2))) if cause == 2
    gen double censor_time = min(rexponential(1/0.15), 6)
    gen double entry_time = rexponential(1/cond(z1 == 1, 1.6, 0.5))
    gen double time = min(event_time, censor_time)
    gen byte status = cond(event_time <= censor_time, cause, 0)
    drop if !(entry_time < time)
    keep in 1/4000
    gen long id = _n
    gen byte any_event = status > 0
    stset time, failure(any_event == 1) id(id) enter(time entry_time)
    finegray z1 z2, compete(status) cause(1) truncstrata(z1)
    display "`e(lt_weight)'"
    display e(min_weight_prob), e(max_lt_weight)
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-18 help finegray Delayed entry with entry strata" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-19 help finegray Grouped cumulative incidence (hiv_si)"
    webuse hiv_si, clear
    gen byte any_event = status > 0
    stset time, failure(any_event==1) id(patnr)
    finegray ccr5, compete(status) cause(2)
    finegray_cif, over(ccr5) attime(2 5 10) ci
    finegray_cif, over(ccr5) ci
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-19 help finegray Grouped cumulative incidence (hiv_si)" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-20 help finegray Multiple imputation"
    webuse hypoxia, clear
    gen byte status = failtype
    replace ifp = . in 1/12
    mi set wide
    mi register imputed ifp
    mi register regular tumsize pelnode status dftime dfcens stnum
    mi impute regress ifp = tumsize pelnode, add(10) rseed(20260825)
    mi stset dftime, failure(dfcens==1) id(stnum)
    mi estimate, cmdok eform("SHR"): finegray ifp tumsize, compete(status) cause(1)
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-20 help finegray Multiple imputation" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-21a help finegray internal tvc, baseline-exposure fit accepted"
    webuse pneumonia, clear
    gen byte outcome = cond(died==1, 1, cond(discharged==1, 2, 0))
    gen byte any_event = outcome > 0
    stset ndays, failure(any_event==1) id(id)
    bysort id (ndays): gen byte pneu0 = pneumonia[1]
    finegray age pneu0, compete(outcome) cause(1)
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-21a help finegray internal tvc, baseline-exposure fit accepted" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-21b help finegray internal tvc, time-updated fit refused r(198)"
    finegray age pneumonia, compete(outcome) cause(1)
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-21b help finegray internal tvc, time-updated fit refused r(198)" 198
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-22 help finegray Bootstrap inference for the coefficients"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)
    capture program drop fgboot
    program define fgboot, eclass
        version 16.0
        capture drop _st _d _t _t0
        quietly stset dftime, failure(dfcens==1) id(newid)
        finegray ifp tumsize pelnode, compete(status) cause(1) noshr nolog
    end
    bootstrap _b, reps(200) seed(13579) cluster(stnum) idcluster(newid): fgboot
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-22 help finegray Bootstrap inference for the coefficients" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-23 help finegray Compare with stcrreg"
    stset dftime, failure(status==1) id(stnum)
    stcrreg ifp tumsize pelnode, compete(status == 2)
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-23 help finegray Compare with stcrreg" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "FGH-24 help finegray Two-interval time-varying effect comparison"
    stcrreg ifp tumsize pelnode, compete(status == 2) tvc(pelnode) texp(_t > 1) noshr
}
local _rc = _rc
capture restore
_docres `_rc' "FGH-24 help finegray Two-interval time-varying effect comparison" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* =============================================================================
* finegray_cif.sthlp {title:Examples} -- every block, in printed order
* =============================================================================

local ++test_count
capture noisily {
    _docblock "CIFH-01 help finegray_cif Setup"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)
    finegray i.pelnode ifp tumsize, compete(status) cause(1)
}
local _rc = _rc
capture restore
_docres `_rc' "CIFH-01 help finegray_cif Setup" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "CIFH-02 help finegray_cif curve at the covariate means"
    finegray_cif, ci
}
local _rc = _rc
capture restore
_docres `_rc' "CIFH-02 help finegray_cif curve at the covariate means" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "CIFH-03 help finegray_cif curve for a specified profile"
    finegray_cif, at(pelnode=1 ifp=20 tumsize=5) ci
}
local _rc = _rc
capture restore
_docres `_rc' "CIFH-03 help finegray_cif curve for a specified profile" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "CIFH-04 help finegray_cif fixed-horizon table"
    finegray_cif, attime(1 5 8) ci
}
local _rc = _rc
capture restore
_docres `_rc' "CIFH-04 help finegray_cif fixed-horizon table" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "CIFH-05 help finegray_cif profile of an interaction model"
    finegray i.pelnode c.ifp i.pelnode#c.ifp tumsize, compete(status) cause(1)
    finegray_cif, at(pelnode=1 ifp=20) attime(1 5) ci
}
local _rc = _rc
capture restore
_docres `_rc' "CIFH-05 help finegray_cif profile of an interaction model" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "CIFH-06 help finegray_cif custom time grid"
    finegray_cif, timepoints(1 2 3 4 5 6 7 8) ci
}
local _rc = _rc
capture restore
_docres `_rc' "CIFH-06 help finegray_cif custom time grid" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "CIFH-07 help finegray_cif saving()"
    finegray_cif, ci nograph saving(cifcurve.dta,replace)
    capture erase "cifcurve.dta"
}
local _rc = _rc
capture restore
_docres `_rc' "CIFH-07 help finegray_cif saving()" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "CIFH-08 help finegray_cif one curve per exposure group (hiv_si)"
    webuse hiv_si, clear
    gen byte any_event = status > 0
    stset time, failure(any_event==1) id(patnr)
    finegray ccr5, compete(status) cause(2)
    finegray_cif, over(ccr5) attime(2 5 10) ci
    finegray_cif, over(ccr5) ci
}
local _rc = _rc
capture restore
_docres `_rc' "CIFH-08 help finegray_cif one curve per exposure group (hiv_si)" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "CIFH-09 help finegray_cif over() on a factor with an interaction"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)
    finegray i.pelnode c.ifp i.pelnode#c.ifp tumsize, compete(status) cause(1)
    finegray_cif, over(pelnode) at(ifp=20) ci
}
local _rc = _rc
capture restore
_docres `_rc' "CIFH-09 help finegray_cif over() on a factor with an interaction" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "CIFH-10 help finegray_cif band by subject bootstrap (500 reps)"
    finegray_cif, attime(1 5 8) ci bootstrap(500) seed(12345)
}
local _rc = _rc
capture restore
_docres `_rc' "CIFH-10 help finegray_cif band by subject bootstrap (500 reps)" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "CIFH-11 help finegray_cif after a baseline-strata fit"
    finegray ifp tumsize, compete(status) cause(1) bstrata(pelnode)
    finegray_cif, attime(1 5) bstratum(0) ci
    finegray_cif, attime(1 5) bstratum(1) ci
    finegray_cif, over(pelnode) ci
}
local _rc = _rc
capture restore
_docres `_rc' "CIFH-11 help finegray_cif after a baseline-strata fit" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* =============================================================================
* finegray_predict.sthlp {title:Examples} -- every block, in printed order
* =============================================================================

local ++test_count
capture noisily {
    _docblock "PRDH-01 help finegray_predict Setup"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
}
local _rc = _rc
capture restore
_docres `_rc' "PRDH-01 help finegray_predict Setup" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "PRDH-02 help finegray_predict linear predictor"
    finegray_predict xb_hat, xb
}
local _rc = _rc
capture restore
_docres `_rc' "PRDH-02 help finegray_predict linear predictor" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "PRDH-03 help finegray_predict cumulative incidence function"
    finegray_predict cif_hat, cif
}
local _rc = _rc
capture restore
_docres `_rc' "PRDH-03 help finegray_predict cumulative incidence function" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "PRDH-04 help finegray_predict CIF with explicit storage type"
    finegray_predict double cif_precise, cif
    summarize cif_precise
}
local _rc = _rc
capture restore
_docres `_rc' "PRDH-04 help finegray_predict CIF with explicit storage type" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "PRDH-05 help finegray_predict CIF at custom time points"
    gen double mytime = 5
    finegray_predict cif_at5, cif timevar(mytime)
}
local _rc = _rc
capture restore
_docres `_rc' "PRDH-05 help finegray_predict CIF at custom time points" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "PRDH-06 help finegray_predict 5-year CIF with a confidence interval"
    gen double mytime_ci = 5
    finegray_predict cif5, cif timevar(mytime_ci) ci
    list cif5 cif5_lci cif5_uci in 1/5
}
local _rc = _rc
capture restore
_docres `_rc' "PRDH-06 help finegray_predict 5-year CIF with a confidence interval" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "PRDH-07 help finegray_predict 5-year CIF, bootstrap limits (200 reps)"
    gen double mytime_bs = 5
    finegray_predict cif5_bs, cif timevar(mytime_bs) ci bootstrap(200) seed(12345)
}
local _rc = _rc
capture restore
_docres `_rc' "PRDH-07 help finegray_predict 5-year CIF, bootstrap limits (200 reps)" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "PRDH-08 help finegray_predict baseline cumulative subdistribution hazard"
    finegray_predict basech, basecshazard
    summarize basech
}
local _rc = _rc
capture restore
_docres `_rc' "PRDH-08 help finegray_predict baseline cumulative subdistribution hazard" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "PRDH-09 help finegray_predict Schoenfeld residuals"
    finegray_predict sch, schoenfeld
    list sch* in 1/5
}
local _rc = _rc
capture restore
_docres `_rc' "PRDH-09 help finegray_predict Schoenfeld residuals" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "PRDH-10 help finegray_predict after a tvc() fit"
    finegray ifp tumsize pelnode, compete(status) cause(1) tvc(pelnode) tsplit(1)
    finegray_predict xb_own, xb
    finegray_predict xb_at2, xb attime(2)
    summarize xb_own xb_at2
}
local _rc = _rc
capture restore
_docres `_rc' "PRDH-10 help finegray_predict after a tvc() fit" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "PRDH-11 help finegray_predict after a stratified-baseline fit"
    finegray ifp tumsize, compete(status) cause(1) bstrata(pelnode)
    finegray_predict h0_s, basecshazard
    finegray_predict cif_s, cif
    tabstat h0_s cif_s, by(pelnode) stat(min max)
}
local _rc = _rc
capture restore
_docres `_rc' "PRDH-11 help finegray_predict after a stratified-baseline fit" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* =============================================================================
* finegray_phtest.sthlp {title:Examples} -- every block, in printed order
* =============================================================================

local ++test_count
capture noisily {
    _docblock "PHTH-01 help finegray_phtest Setup"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
}
local _rc = _rc
capture restore
_docres `_rc' "PHTH-01 help finegray_phtest Setup" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "PHTH-02 help finegray_phtest default diagnostic"
    finegray_phtest
}
local _rc = _rc
capture restore
_docres `_rc' "PHTH-02 help finegray_phtest default diagnostic" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "PHTH-03 help finegray_phtest log-time transformation"
    finegray_phtest, time(log)
}
local _rc = _rc
capture restore
_docres `_rc' "PHTH-03 help finegray_phtest log-time transformation" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "PHTH-04 help finegray_phtest analysis time itself"
    finegray_phtest, time(identity)
}
local _rc = _rc
capture restore
_docres `_rc' "PHTH-04 help finegray_phtest analysis time itself" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "PHTH-05 help finegray_phtest display residuals"
    finegray_phtest, detail
}
local _rc = _rc
capture restore
_docres `_rc' "PHTH-05 help finegray_phtest display residuals" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* =============================================================================
* README.md -- Quick Start and worked examples 1-12
* =============================================================================

**# README block 0 -- Quick Start
local ++test_count
capture noisily {
    _docblock "README Quick Start"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)

    finegray ifp tumsize pelnode, compete(status) cause(1)
    assert e(cmd) == "finegray" & e(N) == 109 & colsof(e(b)) == 3
    finegray_cif, attime(1 5 8) ci
    * one row per requested horizon, and the ci columns actually populated:
    * the README block promises a table, not merely a command that returns
    assert rowsof(r(table)) == 3 & colsof(r(table)) == 5
    assert !missing(el(r(table), 1, 1)) & !missing(el(r(table), 3, 5))
    finegray_phtest
}
if _rc == 0 {
    display as result "  PASS: README Quick Start"
    local ++pass_count
}
else {
    display as error "  FAIL: README Quick Start (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _docblock "RDM-QS2 README Quick Start, second block"
    finegray_predict double cif_hat, cif
    finegray_phtest, time(log)
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-QS2 README Quick Start, second block" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-01 README 1. basic model and estimates"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens == 1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    ereturn list
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-01 README 1. basic model and estimates" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-02 README 2. linear predictors and common-horizon CIFs"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens == 1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    finegray_predict double xb_hat, xb
    gen double horizon5 = 5
    finegray_predict double cif5, cif timevar(horizon5) ci level(95)
    summarize xb_hat cif5 cif5_lci cif5_uci
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-02 README 2. linear predictors and common-horizon CIFs" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-03 README 3. profile-specific CIF table"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens == 1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    finegray_cif, at(pelnode=1 ifp=20 tumsize=5) attime(1 3 5 8) ci
    return list
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-03 README 3. profile-specific CIF table" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-03a README 3a. compare cumulative incidence between two groups"
    webuse hiv_si, clear
    gen byte any_event = status > 0
    stset time, failure(any_event == 1) id(patnr)
    finegray ccr5, compete(status) cause(2)
    finegray_cif, over(ccr5) attime(2 5 10) ci
    finegray_cif, over(ccr5) ci
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-03a README 3a. compare cumulative incidence between two groups" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-03a2 README 3a. the same on a factor interaction"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens == 1) id(stnum)
    finegray i.pelnode c.ifp i.pelnode#c.ifp tumsize, compete(status) cause(1)
    finegray_cif, over(pelnode) at(ifp=20) ci
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-03a2 README 3a. the same on a factor interaction" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-04 README 4. save a confidence-banded CIF curve"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens == 1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1)
    tempfile cifout
    finegray_cif, timepoints(1 2 3 4 5 6 7 8) ci nograph saving("`cifout'", replace)
    use "`cifout'", clear
    list time cif se lci uci, noobs
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-04 README 4. save a confidence-banded CIF curve" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-05 README 5. factor variables and proportional hazards"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens == 1) id(stnum)
    finegray i.pelnode c.ifp##c.tumsize, compete(status) cause(1)
    finegray_predict double schoenfeld, schoenfeld
    finegray_phtest, time(log) detail
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-05 README 5. factor variables and proportional hazards" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-06 README 6. censoring strata and clustered robust inference"
    webuse hypoxia, clear
    gen byte status = failtype
    gen int site = ceil(_n / 10)
    stset dftime, failure(dfcens == 1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1) strata(pelnode) cluster(site)
    display "clusters = " e(N_clust)
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-06 README 6. censoring strata and clustered robust inference" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-06a README 6a. stratified baseline subdistribution hazard"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens == 1) id(stnum)
    finegray ifp tumsize, compete(status) cause(1) bstrata(pelnode)
    display "baseline strata = " e(k_bstrata)
    finegray_cif, attime(1 5) bstratum(0) ci nograph
    finegray_cif, attime(1 5) bstratum(1) ci nograph
    finegray_predict double h0, basecshazard
    tabstat h0, by(pelnode) stat(min max)
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-06a README 6a. stratified baseline subdistribution hazard" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-06b README 6b. piecewise-constant time-varying effect"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens == 1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1) tvc(pelnode) tsplit(1)
    test [tvc1]pelnode = [tvc2]pelnode
    finegray_predict double xb_late, xb attime(2)
    finegray_cif, at(ifp=20 tumsize=5 pelnode=0) attime(1 3 5) nograph
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-06b README 6b. piecewise-constant time-varying effect" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-06b2 README 6b. the stcrreg parameterization"
    stset dftime, failure(status == 1) id(stnum)
    stcrreg ifp tumsize pelnode, compete(status == 2) tvc(pelnode) texp(_t > 1) noshr
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-06b2 README 6b. the stcrreg parameterization" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-06c README 6c. sampling weights"
    webuse hypoxia, clear
    gen byte status = failtype
    gen double sw = cond(pelnode == 1, 2, 1)
    stset dftime, failure(dfcens == 1) id(stnum)
    finegray ifp tumsize [pweight = sw], compete(status) cause(1)
    finegray_cif, attime(1 5) ci nograph
    display "`e(wtype)' `e(wexp)'  sum of weights = " e(sum_w)
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-06c README 6c. sampling weights" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-07 README 7. bootstrap confidence intervals for a CIF profile"
    webuse hypoxia, clear
    gen byte status = failtype
    gen int site = ceil(_n / 10)
    stset dftime, failure(dfcens == 1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1) cluster(site)
    finegray_cif, attime(1 5 8) ci bootstrap(25) seed(24680)
    return list
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-07 README 7. bootstrap confidence intervals for a CIF profile" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-08 README 8. delayed-entry model and the weight path"
    clear
    set seed 20260713
    set obs 24000
    gen byte z1 = runiform() < 0.5
    gen double z2 = rnormal()
    gen byte g4 = ceil(runiform() * 4)
    gen double ez = exp(0.5*z1 - 0.5*z2)
    gen double p1 = 1 - (1 - 0.5)^ez
    gen byte cause = cond(runiform() < p1, 1, 2)
    gen double v = runiform()
    gen double event_time = -ln(1 - (1 - (1 - v*p1)^(1/ez))/0.5) if cause == 1
    replace event_time = rexponential(1/(0.5*exp(0.5*z1 + 0.5*z2))) if cause == 2
    gen double censor_time = min(rexponential(1/0.15), 6)
    gen double entry_time = rexponential(1/cond(z1 == 1, 1.6, 0.5))
    gen double time = min(event_time, censor_time)
    gen byte status = cond(event_time <= censor_time, cause, 0)
    drop if !(entry_time < time)
    keep in 1/4000
    gen long id = _n
    gen byte any_event = status > 0
    stset time, failure(any_event == 1) id(id) enter(time entry_time)

    finegray z1 z2, compete(status) cause(1) truncstrata(z1)
    display "weight method = " "`e(lt_weight)'"
    display "smallest weight probability = " e(min_weight_prob)
    display "largest entry weight = " e(max_lt_weight)
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-08 README 8. delayed-entry model and the weight path" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-08b README 8. the pooled-weight comparison"
    finegray z1 z2, compete(status) cause(1) noshr
    display "weight method = " "`e(lt_weight)'"
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-08b README 8. the pooled-weight comparison" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-08c README 8. strata() and truncstrata() compose"
    finegray z1 z2, compete(status) cause(1) strata(z1) truncstrata(z1)
    finegray z1 z2, compete(status) cause(1) strata(g4) truncstrata(z1)
    finegray_cif, attime(1 3 5) ci nograph
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-08c README 8. strata() and truncstrata() compose" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-09 README 9. baseline hazard and baseline cumulative subhazard"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens == 1) id(stnum)
    finegray ifp tumsize pelnode, compete(status) cause(1) basehaz
    matrix list e(basehaz)
    finegray_predict double baseline_subhaz, basecshazard
    summarize baseline_subhaz
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-09 README 9. baseline hazard and baseline cumulative subhazard" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-10 README 10. pool a fit over multiply imputed data"
    webuse hypoxia, clear
    gen byte status = failtype
    replace ifp = . in 1/12
    mi set wide
    mi register imputed ifp
    mi register regular tumsize pelnode status dftime dfcens stnum
    mi impute regress ifp = tumsize pelnode, add(10) rseed(20260825)
    mi stset dftime, failure(dfcens == 1) id(stnum)
    mi estimate, cmdok eform("SHR"): finegray ifp tumsize pelnode, compete(status) cause(1)
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-10 README 10. pool a fit over multiply imputed data" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-11 README 11. bootstrap the coefficients"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens == 1) id(stnum)
    capture program drop fgboot
    program define fgboot, eclass
        version 16.0
        capture drop _st _d _t _t0
        quietly stset dftime, failure(dfcens == 1) id(newid)
        finegray ifp tumsize pelnode, compete(status) cause(1) noshr nolog
    end
    bootstrap _b, reps(200) seed(13579) cluster(stnum) idcluster(newid): fgboot
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-11 README 11. bootstrap the coefficients" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-12a README 12. internal time-varying covariate refused r(198)"
    webuse pneumonia, clear
    gen byte status = cond(died == 1, 1, cond(discharged == 1, 2, 0))
    bysort id (ndays): gen byte outcome = status[_N]
    gen byte any_event = status > 0
    stset ndays, id(id) failure(any_event == 1)
    finegray age pneumonia, compete(outcome) cause(1)
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-12a README 12. internal time-varying covariate refused r(198)" 198
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
capture noisily {
    _docblock "RDM-12b README 12. the baseline-exposure fit is accepted"
    bysort id (ndays): gen byte pneu0 = pneumonia[1]
    finegray age pneu0, compete(outcome) cause(1)
}
local _rc = _rc
capture restore
_docres `_rc' "RDM-12b README 12. the baseline-exposure fit is accepted" 0
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# Doc-advertised new-in-1.2.0 invocations: basehaz + basecshazard
* These are documented (Options table, Stored results, help) but appear in no
* README code block; a reader who copies the prose must still be able to run them.
local ++test_count
capture noisily {
    _docblock "basehaz + basecshazard"
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)

    finegray ifp tumsize pelnode, compete(status) cause(1) basehaz
    confirm matrix e(basehaz)
    * the posted curve has rows and rises: an empty or all-zero baseline would
    * pass `confirm matrix' and every downstream CIF built on it would be 0
    assert rowsof(e(basehaz)) > 0 & colsof(e(basehaz)) >= 2
    finegray_predict bch, basecshazard
    confirm variable bch
    quietly count if !missing(bch)
    assert r(N) == e(N)
    quietly summarize bch
    * stata-dev-ignore: missing-passes-assert — fail-closed: the `count if !missing(bch)' + `assert r(N) == e(N)' pair two lines above already refuses an all-missing column, so r(min)/r(max) here cannot be missing
    assert r(min) >= 0 & r(max) > 0
}
if _rc == 0 {
    display as result "  PASS: basehaz + basecshazard"
    local ++pass_count
}
else {
    display as error "  FAIL: basehaz + basecshazard (rc=`=_rc')"
    local ++fail_count
}

**# help finegray, Multiple imputation -- BOTH printed blocks, verbatim
* WATCHED FAIL 2026-09-01.  Both blocks used to open at `mi stset', on data that
* had never been `mi set': a reader who copied them got r(119) "data are not mi
* set" and no fit at all.  The README's section 10 carries the four setup lines
* the help file omitted; they are now printed in the help file too, and both
* blocks are exercised here as printed.  The assertion is on CONTENT, not on
* rc: `mi estimate' posts its own e(), so e(cmd_mi) is what names the command
* that was actually pooled, and the pooled e(b) must carry one column per
* covariate typed.
local ++test_count
capture noisily {
    _docblock "help finegray -- mi, one covariate"
    webuse hypoxia, clear
    gen byte status = failtype
    replace ifp = . in 1/12
    mi set wide
    mi register imputed ifp
    mi register regular tumsize pelnode status dftime dfcens stnum
    mi impute regress ifp = tumsize pelnode, add(10) rseed(20260825)
    mi stset dftime, failure(dfcens==1) id(stnum)
    mi estimate, cmdok eform("SHR"): finegray ifp, compete(status) cause(1)
    assert "`e(cmd)'" == "mi estimate"
    assert "`e(cmd_mi)'" == "finegray"
    * The POOLED coefficient vector is e(b_mi), not e(b): after `mi estimate'
    * e(b) is empty (a 0 x 0 copy), so an assertion written against e(b) would
    * be vacuous rather than wrong.  It also has to be copied to a named matrix
    * first -- in an EXPRESSION e(b_mi) resolves as a scalar e() result and
    * colsof() is r(109) type mismatch.
    tempname _mib1
    matrix `_mib1' = e(b_mi)
    assert colsof(`_mib1') == 1
    assert `_mib1'[1,1] < .
    assert "`: colnames `_mib1''" == "ifp"
}
if _rc == 0 {
    display as result "  PASS: help finegray -- mi, one covariate"
    local ++pass_count
}
else {
    display as error "  FAIL: help finegray -- mi, one covariate (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _docblock "help finegray -- mi, two covariates"
    webuse hypoxia, clear
    gen byte status = failtype
    replace ifp = . in 1/12
    mi set wide
    mi register imputed ifp
    mi register regular tumsize pelnode status dftime dfcens stnum
    mi impute regress ifp = tumsize pelnode, add(10) rseed(20260825)
    mi stset dftime, failure(dfcens==1) id(stnum)
    mi estimate, cmdok eform("SHR"): finegray ifp tumsize, compete(status) cause(1)
    assert "`e(cmd_mi)'" == "finegray"
    tempname _mib2
    matrix `_mib2' = e(b_mi)
    assert colsof(`_mib2') == 2
    assert `_mib2'[1,1] < . & `_mib2'[1,2] < .
    assert "`: colnames `_mib2''" == "ifp tumsize"
    * post-estimation after a pooled fit is refused by name, as the help says
    capture finegray_cif, attime(5) nograph
    assert _rc == 301
}
if _rc == 0 {
    display as result "  PASS: help finegray -- mi, two covariates"
    local ++pass_count
}
else {
    display as error "  FAIL: help finegray -- mi, two covariates (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_documentation_examples tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _docex
    exit 1
}
display as result "ALL TESTS PASSED"
log close _docex
