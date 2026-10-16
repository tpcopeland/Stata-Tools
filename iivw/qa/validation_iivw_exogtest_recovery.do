clear all
version 16.0
set more off
set varabbrev off
* the RESULT: line is longer than 80 characters; a wrapped line would hide smoke=
set linesize 255

* validation_iivw_exogtest_recovery.do
*
* Known-truth recovery for iivw_exogtest: the lagged-outcome coefficients of the
* Andersen-Gill visit-intensity Cox model.
*
* Covers   : r(results) column b (log hazard ratio per unit of the one-visit lag)
*            from iivw_exogtest ..., maxfu() nolog.
* Oracle   : the DGP. _iivw_exogtest_dgp.do draws exponential waiting times with
*            rate exp(a + gamma1*y_lag + gamma2*y2_lag), so the AG partial
*            likelihood is the true model and the coefficient equals gamma.
*            No other estimator is involved.
* Tolerance: Monte Carlo. Over R replicates mean(b) must be within 3 MCSE of the
*            truth, MCSE = sd(b)/sqrt(R) (TOLERANCE_FRAMEWORK.md Class M).
* Seeds    : one stream, set seed 20261015 once at the top; the loop never reseeds.
* Cells    : A gamma=0.40 (informative), B two lags gamma=(0.40,-0.30),
*            C null gamma=0 (and its second lag), D N doubled (bias must not
*            grow in MCSE units), E wrong-truth negative control (the same band
*            must REJECT a truth of 0.50 for cell A, proving the band can go red).
* R, N     : R=400 replicates; N=500 subjects (cells A-C), 1000 (cell D).
*
* Worked run (R=400): A mean 0.40018 z 0.18; B 0.39866 z -1.35 and -0.29862 z 1.35;
* C 0.00008 z 0.08 and -0.00048 z -0.46; D 0.40032 z 0.45; E wrong-truth z -97.99.
*
* Usage:  cd iivw/qa;  stata-mp -b do validation_iivw_exogtest_recovery.do

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "validation_iivw_exogtest_recovery.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap
do "`qa_dir'/_iivw_exogtest_dgp.do"

local R = 400
local MCSE_K = 3
local tests = 0
local pass = 0
local fail = 0

* _rec_cell runs R replicates and leaves one row per replicate in memory:
* the estimate of each lag coefficient plus the return code. A replicate whose
* fit errors is kept (rc != 0, b missing) so it cannot drop out of the denominator.
capture program drop _rec_cell
program define _rec_cell
    syntax , R(integer) N(integer) GAMMA(real) [GAMMA2(real 0) TWO]
    tempname P
    tempfile out
    postfile `P' int rep int rc double(b1 b2) using "`out'", replace
    forvalues r = 1/`r' {
        if "`two'" != "" iivw_exog_dgp, groups(1) n(`n') gammas(`gamma') gammatwo(`gamma2')
        else             iivw_exog_dgp, groups(1) n(`n') gammas(`gamma')
        if "`two'" != "" capture quietly iivw_exogtest y y2, id(id) time(time) maxfu(5) nolog
        else             capture quietly iivw_exogtest y, id(id) time(time) maxfu(5) nolog
        local rc = _rc
        local b1 = .
        local b2 = .
        if `rc' == 0 {
            tempname M
            matrix `M' = r(results)
            local b1 = `M'[1, 3]
            if "`two'" != "" local b2 = `M'[2, 3]
        }
        post `P' (`r') (`rc') (`b1') (`b2')
    }
    postclose `P'
    use "`out'", clear
end

* _rec_judge sets r(z) = (mean - truth)/MCSE and r(ok) = 1 if |z| < MCSE_K and finite
capture program drop _rec_judge
program define _rec_judge, rclass
    syntax , VAR(varname) TRUTH(real) K(real) LABEL(string) [EXPECTRED]
    quietly summarize `var'
    local nn = r(N)
    local m = r(mean)
    local mcse = r(sd) / sqrt(r(N))
    local z = (`m' - `truth') / `mcse'
    display as text "  `label': mean " %8.5f `m' "  truth " %8.5f `truth' "  MCSE " %8.5f `mcse' "  z " %7.2f `z' "  n " `nn'
    return scalar z = `z'
    return scalar mean = `m'
    return scalar mcse = `mcse'
    return scalar n = `nn'
    return scalar inband = (`z' < .) & (abs(`z') < `k')
end

set seed 20261015

* Cell A
display as text _newline "Cell A: gamma = 0.40, N = 500"
_rec_cell, r(`R') n(500) gamma(.4)
local ++tests
quietly count if rc != 0 | missing(b1)
local bad = r(N)
_rec_judge, var(b1) truth(.4) k(`MCSE_K') label("A b1")
if `bad' == 0 & r(inband) == 1 local ++pass
else {
    local ++fail
    display as error "FAIL A: failed replicates `bad', z = " %6.2f r(z)
}
local zA = r(z)
local mA = r(mean)
local mcseA = r(mcse)
local nA = r(n)

* Cell E: negative control on cell A's replicates. The band must reject 0.50.
local ++tests
local zE = (`mA' - .5) / `mcseA'
display as text "  E wrong-truth control: truth 0.50 gives z = " %7.2f `zE'
if `zE' < . & abs(`zE') >= `MCSE_K' local ++pass
else {
    local ++fail
    display as error "FAIL E: the recovery band did not reject a wrong truth (z = " %6.2f `zE' ")"
}

* Cell B
display as text _newline "Cell B: two lags, gamma = (0.40, -0.30), N = 500"
_rec_cell, r(`R') n(500) gamma(.4) gamma2(-.3) two
local ++tests
quietly count if rc != 0 | missing(b1, b2)
local bad = r(N)
_rec_judge, var(b1) truth(.4) k(`MCSE_K') label("B b1")
local ok1 = r(inband)
_rec_judge, var(b2) truth(-.3) k(`MCSE_K') label("B b2")
local ok2 = r(inband)
if `bad' == 0 & `ok1' == 1 & `ok2' == 1 local ++pass
else {
    local ++fail
    display as error "FAIL B: failed replicates `bad', in-band flags `ok1' `ok2'"
}

* Cell C
display as text _newline "Cell C: null, gamma = (0, 0), N = 500"
_rec_cell, r(`R') n(500) gamma(0) gamma2(0) two
local ++tests
quietly count if rc != 0 | missing(b1, b2)
local bad = r(N)
_rec_judge, var(b1) truth(0) k(`MCSE_K') label("C b1")
local ok1 = r(inband)
_rec_judge, var(b2) truth(0) k(`MCSE_K') label("C b2")
local ok2 = r(inband)
if `bad' == 0 & `ok1' == 1 & `ok2' == 1 local ++pass
else {
    local ++fail
    display as error "FAIL C: failed replicates `bad', in-band flags `ok1' `ok2'"
}

* Cell D
display as text _newline "Cell D: gamma = 0.40, N = 1000"
_rec_cell, r(`R') n(1000) gamma(.4)
local ++tests
quietly count if rc != 0 | missing(b1)
local bad = r(N)
_rec_judge, var(b1) truth(.4) k(`MCSE_K') label("D b1")
* bias must not grow in MCSE units as N doubles: |z_D| < 3 and the bias itself
* (mean - truth) in absolute terms is not larger than at N = 500 by more than
* the combined MCSE
local biasD = r(mean) - .4
local mcseD = r(mcse)
local biasA = `mA' - .4
local combined = sqrt(`mcseA'^2 + `mcseD'^2)
display as text "  D vs A: bias " %9.5f `biasD' " vs " %9.5f `biasA' "  combined MCSE " %9.5f `combined'
if `bad' == 0 & r(inband) == 1 & (abs(`biasD') - abs(`biasA')) < 3 * `combined' local ++pass
else {
    local ++fail
    display as error "FAIL D: failed replicates `bad'; recovery out of band or bias grew with N"
}

display as text _newline "Worked-run record: see the RESULT line and the z values above."
display "RESULT: validation_iivw_exogtest_recovery tests=`tests' pass=`pass' fail=`fail' skip=0"
iivw_qa_sandbox_restore
if `fail' > 0 exit 1
