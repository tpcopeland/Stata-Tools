* validation_msm_recovery.do
*
* Known-truth parameter recovery for the marginal structural model fit by
* msm_fit (model(logistic)). The estimand is the MARGINAL structural log-OR
* of current treatment a_t on outcome y_t, marginalizing over a time-varying
* confounder L_t via stabilized IPTW.
*
* Why this is the lead correctness check (not crossval): the truth is set by
* the data-generating process and computed analytically from it, so any gap is
* an unambiguous bias -- unlike R/Python parity, which cannot separate a real
* bug from a method difference. crossval_msm.do checks _b[treatment] against
* the CONDITIONAL ln(0.70) at a loose TOL of 0.20; that conflates conditional
* and marginal effects (logistic non-collapsibility). This suite targets the
* correctly-defined MARGINAL parameter tightly.
*
* DGP (exogenous time-varying confounder, no treatment->confounder feedback):
*   L_t exogenous AR(1):  L_t = 0.5*L_{t-1} + N(0,0.8)     (NOT affected by a)
*   a_t ~ Bernoulli(expit(inta + confa*L_t))               (confounded)
*   y_t ~ Bernoulli(expit(inty + effect*a_t + confy*L_t))  (current a_t only)
* Because L_t is exogenous, y_t^{a_t} depends only on CURRENT a_t, so the
* always/never oracle fit (logit y ~ a + period on huge-N counterfactual data)
* matches msm_fit's working model exactly -- the estimand is unambiguous.
* Unweighted-pooled logit (ignoring L) is confounded-biased; IPTW-MSM recovers.
*
* Return handle confirmed from source (msm_fit.ado): the marginal effect is the
* exposure coefficient _b[treatment], also exposed as e(effects)[1,1].
*
* TOL = 0.05: observed recovery error ~0.005-0.008 at SE ~0.02 over both
* scenarios (set from a worked run, not a guess); 0.05 is ~2-3*SE and ~6-10x
* the observed error -- tight enough to catch real bias, loose enough for MC.

clear all
set varabbrev off
version 16.0

capture log close
log using "validation_msm_recovery.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory (relocatable)
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall msm
quietly net install msm, from("`pkg_dir'") replace

**# Helper programs

* Build one panel. regime == -1 -> confounded (observed); 0/1 -> static regime.
* L is exogenous AR(1), so it is generated identically regardless of treatment.
capture program drop _gen_panel
program define _gen_panel
    syntax , Nper(integer) Tper(integer) EFFect(real) CONFa(real) CONFy(real) ///
             INTa(real) INTy(real) SEEDval(integer) REGime(integer)
    clear
    set seed `seedval'
    set obs `=`nper'*`tper''
    gen long id = ceil(_n/`tper')
    bysort id: gen int period = _n - 1
    gen double L = .
    gen byte a = .
    gen byte y = .
    sort id period
    quietly {
        by id: replace L = rnormal(0,1) if period==0
        forvalues p = 1/`=`tper'-1' {
            by id: replace L = 0.5*L[_n-1] + rnormal(0,0.8) if period==`p'
        }
        if `regime' == -1  replace a = runiform() < invlogit(`inta' + `confa'*L)
        else               replace a = `regime'
        replace y = runiform() < invlogit(`inty' + `effect'*a + `confy'*L)
    }
end

* One recovery scenario: build truth, assert naive misses, assert IPTW recovers.
capture program drop _run_recovery
program define _run_recovery
    syntax , EFFect(real) CONFa(real) CONFy(real) INTa(real) INTy(real) ///
             OBSseed(integer) TRUseed(integer) Nper(integer) Tper(integer) ///
             TOL(real) MINbias(real) LABel(string)

    * --- observed (confounded) data: naive + IPTW-MSM both use this sample ---
    _gen_panel, nper(`nper') tper(`tper') effect(`effect') confa(`confa') ///
        confy(`confy') inta(`inta') inty(`inty') seedval(`obsseed') regime(-1)
    tempfile obs
    save `obs'

    * --- TRUTH: oracle marginal log-OR from forward-simulated always/never ---
    * worlds at huge N, fit with msm_fit's own working model (logit y ~ a+period).
    foreach r in 1 0 {
        _gen_panel, nper(200000) tper(`tper') effect(`effect') confa(`confa') ///
            confy(`confy') inta(`inta') inty(`inty') seedval(`truseed') regime(`r')
        tempfile cf`r'
        save `cf`r''
    }
    use `cf1', clear
    append using `cf0'
    quietly logit y a period
    local truth = _b[a]

    * --- NAIVE: unadjusted pooled logit, ignoring L -> confounded-biased ---
    use `obs', clear
    quietly logit y a period
    local naive = _b[a]

    * --- IPTW-MSM: marginalize over L (denominator adjusts for L; numerator
    * is intercept + lagged treatment only -> fully stabilized, marginal) ---
    use `obs', clear
    msm_prepare, id(id) period(period) treatment(a) outcome(y) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(logistic) period_spec(linear) nolog
    local est = _b[a]
    local se  = _se[a]
    local eff = e(effects)[1,1]

    display as text "  [`label']"
    display as text "    true marginal log-OR : " as result %8.4f `truth'
    display as text "    naive _b[a] (bias)   : " as result %8.4f `naive' ///
        as text "  (" as result %6.4f `naive'-`truth' as text ")"
    display as text "    IPTW-MSM _b[a] (err) : " as result %8.4f `est' ///
        as text "  (" as result %6.4f `est'-`truth' as text ", se " %6.4f `se' as text ")"

    * naive-miss guard: the unadjusted estimator must miss the marginal truth
    assert abs(`naive' - `truth') > `minbias'
    * recovery: IPTW-MSM returns the parameter built into the data
    assert abs(`est' - `truth') < `tol'
    * return-handle consistency: documented e(effects)[1,1] == _b[treatment]
    assert reldif(`eff', `est') < 1e-8
end

**# Tests

* Scenario A: protective effect (OR 0.6), moderate confounding
local ++test_count
local effA = ln(0.6)
capture noisily _run_recovery, effect(`effA') confa(0.8) confy(0.6) ///
    inta(-0.2) inty(-1.0) obsseed(90211) truseed(5150) nper(40000) tper(4) ///
    tol(0.05) minbias(0.20) label("A: protective OR=0.6, moderate confounding")
if _rc == 0 {
    display as result "  PASS: recovery A (protective, moderate confounding)"
    local ++pass_count
}
else {
    display as error "  FAIL: recovery A (error `=_rc')"
    local ++fail_count
}

* Scenario B: harmful effect (OR 1.7), stronger confounding
local ++test_count
local effB = ln(1.7)
capture noisily _run_recovery, effect(`effB') confa(1.0) confy(0.7) ///
    inta(-0.1) inty(-1.2) obsseed(71813) truseed(33102) nper(40000) tper(4) ///
    tol(0.05) minbias(0.20) label("B: harmful OR=1.7, stronger confounding")
if _rc == 0 {
    display as result "  PASS: recovery B (harmful, stronger confounding)"
    local ++pass_count
}
else {
    display as error "  FAIL: recovery B (error `=_rc')"
    local ++fail_count
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_msm_recovery tests=`test_count' pass=`pass_count' fail=`fail_count'"
    capture log close
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_msm_recovery tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close
