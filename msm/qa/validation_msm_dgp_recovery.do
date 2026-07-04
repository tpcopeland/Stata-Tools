* validation_msm_dgp_recovery.do
*
* Broad known-truth parameter-recovery battery for the msm suite. Each scenario
* simulates data from a data-generating process (DGP) whose true causal effect
* is set by us, computes that truth ANALYTICALLY from the DGP (never from another
* estimator), confirms a naive estimator MISSES it, and asserts the IPTW-MSM
* estimator RECOVERS it. This is the lead correctness check (Core Principles ->
* "Recover a known truth"): the oracle is unambiguous because we wrote the DGP.
*
* Companion to validation_msm_recovery.do (2 marginal-log-OR scenarios); this
* file broadens coverage across outcome models, estimands, and weight machinery:
*
*   LINEAR  ATE  (model(linear), _b[treatment]) -- collapsible, truth = effect:
*     D1 positive ATE, point treatment, moderate confounding
*     D2 negative ATE, point treatment, strong confounding
*     D3 null ATE = 0, point treatment
*     D4 multi-period time-varying treatment, positive ATE
*     D5 point ATE with a time-fixed outcome_cov() adjustment covariate
*
*   RISK DIFFERENCE (logistic fit + msm_predict) -- collapsible marginal RD:
*     D6 point RD, harmful
*     D7 point RD, protective
*     D8 point RD, null -> RD ~ 0
*     D9 multi-period cumulative-incidence RD at a horizon (forward-sim oracle)
*
*   MARGINAL LOG-OR (model(logistic), _b[treatment]) -- non-collapsible, oracle
*   is the pooled-logit fit on forward-simulated always/never worlds:
*     D10 multi-period harmful log-OR, strong confounding (positivity ok)
*     D11 multi-period null log-OR = 0
*
*   MARGINAL LOG-HR (model(cox), _b[treatment]) -- oracle is stcox on the
*   forward-simulated always/never worlds (marginal, non-collapsible):
*     D12 time-varying protective log-HR
*     D13 time-varying harmful log-HR
*
*   WEIGHT MACHINERY:
*     D14 IPCW: informative censoring, linear ATE recovered with censor weights
*     D15 truncate(): bounded gate -- moderate truncation still recovers RD
*     D16 stronger treatment confounding still recovers marginal log-OR
*
*   SCOPE BOUNDARY (documented known answer, not a bug):
*     D17 time-invariant (baseline) treatment across a panel is out of scope
*         (msm.sthlp: "consider teffects ipw instead"); msm_weight must refuse
*         to fabricate weights (perfect prediction in A_t ~ lagged A_t) and exit
*         with a targeted diagnostic naming the cause.
*
* Return handles confirmed from source:
*   msm_fit    : marginal effect = _b[treatment] == e(effects)[1,1]  (all models)
*   msm_predict: risk difference at time t = r(rd_`t')
*
* Tolerances are set from worked exploration runs (observed error vs Monte-Carlo
* SE), not guessed. Collapsible LINEAR/RD scenarios use exact analytic truths and
* tight TOL. Non-collapsible log-OR/log-HR and the multi-period cumulative-
* incidence RD use forward-sim oracles; because those oracles are stochastic, each
* is computed at TWO independent seeds and asserted to agree within a tight guard
* (oracle-stability check) before its average is taken as truth -- so the recovery
* TOL bounds estimator finite-sample error alone, not oracle Monte-Carlo noise.
* (Measured oracle MC-SD at nper=200000 is ~0.0015 for the log-OR oracle, well
* under the two-seed guard and ~3% of the 0.05 recovery TOL.)

clear all
set varabbrev off
version 16.0

capture log close
log using "validation_msm_dgp_recovery.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Bootstrap: derive package root from qa/ working directory (relocatable)
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall msm
quietly net install msm, from("`pkg_dir'") replace

**# Helper programs

* Point-treatment single-period panel (one row per id, period 0).
* Treatment varies across PEOPLE (cross-sectional IPW, in scope as one period).
*   L ~ N(0,1) confounder
*   a ~ Bernoulli(expit(inta + confa*L))
*   binary : y ~ Bernoulli(expit(inty + effect*a + confy*L))
*   linear : y = inty + effect*a + confy*L + N(0,1)
* Optional informative censoring:  c ~ Bernoulli(expit(cint + cconf*L)).
capture program drop _pt_gen
program define _pt_gen
    syntax , N(integer) EFFect(real) CONFa(real) CONFy(real) INTa(real) ///
             INTy(real) SEEDval(integer) [BINary CINT(real 999) CCONF(real 0)]
    clear
    set seed `seedval'
    set obs `n'
    gen long id = _n
    gen int period = 0
    gen double L = rnormal()
    gen byte a = runiform() < invlogit(`inta' + `confa'*L)
    if "`binary'" != "" {
        gen byte outcome = runiform() < invlogit(`inty' + `effect'*a + `confy'*L)
    }
    else {
        gen double ycont = `inty' + `effect'*a + `confy'*L + rnormal(0,1)
        gen byte outcome = 0
    }
    if `cint' != 999 {
        gen byte censor = runiform() < invlogit(`cint' + `cconf'*L)
    }
end

* Analytic marginal risk difference for the point binary DGP: E_L[ p(a=1) - p(a=0) ]
* computed by Monte-Carlo integration over the KNOWN L distribution (independent
* of the estimator). Returns r(rd).
capture program drop _pt_truth_rd
program define _pt_truth_rd, rclass
    syntax , EFFect(real) CONFy(real) INTy(real) SEEDval(integer)
    clear
    set seed `seedval'
    set obs 500000
    gen double L = rnormal()
    gen double p1 = invlogit(`inty' + `effect' + `confy'*L)
    gen double p0 = invlogit(`inty' + `confy'*L)
    quietly summarize p1, meanonly
    local r1 = r(mean)
    quietly summarize p0, meanonly
    return scalar rd = `r1' - r(mean)
end

* Multi-period panel, exogenous AR(1) confounder (no treatment->confounder
* feedback), time-varying treatment.  regime==-1 confounded (observed);
* 0/1 static always/never for building forward-sim oracles.
capture program drop _tv_gen
program define _tv_gen
    syntax , Nper(integer) Tper(integer) EFFect(real) CONFa(real) CONFy(real) ///
             INTa(real) INTy(real) SEEDval(integer) REGime(integer) [CONTy]
    clear
    set seed `seedval'
    set obs `=`nper'*`tper''
    gen long id = ceil(_n/`tper')
    bysort id: gen int period = _n - 1
    gen double L = .
    gen byte a = .
    sort id period
    quietly by id: replace L = rnormal(0,1) if period==0
    quietly forvalues p = 1/`=`tper'-1' {
        by id: replace L = 0.5*L[_n-1] + rnormal(0,0.8) if period==`p'
    }
    if `regime' == -1 quietly replace a = runiform() < invlogit(`inta' + `confa'*L)
    else              quietly replace a = `regime'
    if "`conty'" != "" {
        quietly gen double ycont = `inty' + `effect'*a + `confy'*L + rnormal(0,1)
        quietly gen byte outcome = 0
    }
    else {
        quietly gen byte outcome = runiform() < invlogit(`inty' + `effect'*a + `confy'*L)
    }
end

* Multi-period discrete-time survival panel, time-varying treatment.  Rows after
* the first event are dropped (standard person-period survival structure).
capture program drop _surv_gen
program define _surv_gen
    syntax , Nper(integer) Tper(integer) LHR(real) CONFa(real) CONFy(real) ///
             BASEhaz(real) SEEDval(integer) REGime(integer)
    clear
    set seed `seedval'
    set obs `=`nper'*`tper''
    gen long id = ceil(_n/`tper')
    bysort id: gen int period = _n - 1
    gen double L = .
    gen byte a = .
    sort id period
    quietly by id: replace L = rnormal() if period==0
    quietly forvalues p = 1/`=`tper'-1' {
        by id: replace L = 0.5*L[_n-1] + rnormal(0,0.8) if period==`p'
    }
    if `regime' == -1 quietly replace a = runiform() < invlogit(`confa'*L)
    else              quietly replace a = `regime'
    quietly gen double haz = invlogit(`basehaz' + `lhr'*a + `confy'*L)
    quietly gen byte outcome = runiform() < haz
    quietly bysort id (period): gen byte pastev = sum(outcome) > outcome
    quietly drop if pastev==1
    drop pastev haz
end

* Forward-sim ORACLES for the non-collapsible / no-closed-form estimands.
* Each builds the always/never counterfactual worlds at large N from a given seed
* and fits the estimator's OWN working model to read off the marginal parameter.
* Because they are stochastic, the calling scenario runs each at TWO independent
* seeds and asserts the two agree tightly (oracle-stability guard) before using
* the average as truth -- so the recovery tolerance bounds estimator error alone,
* not oracle Monte-Carlo noise. Measured oracle MC-SD at nper=200000 is ~0.0015
* for the log-OR oracle, ~3% of the 0.05 recovery tolerance.

* Marginal log-OR oracle: pooled logit y ~ a + period on always+never worlds.
capture program drop _oracle_logor
program define _oracle_logor, rclass
    syntax , Nper(integer) EFFect(real) CONFa(real) CONFy(real) ///
             INTa(real) INTy(real) SEEDval(integer)
    foreach r in 1 0 {
        _tv_gen, nper(`nper') tper(4) effect(`effect') confa(`confa') ///
            confy(`confy') inta(`inta') inty(`inty') seedval(`=`seedval'+`r'') regime(`r')
        tempfile _cf`r'
        save `_cf`r''
    }
    use `_cf1', clear
    append using `_cf0'
    quietly logit outcome a period
    return scalar truth = _b[a]
end

* Marginal log-HR oracle: stcox a on always+never worlds (discrete-time survival).
capture program drop _oracle_loghr
program define _oracle_loghr, rclass
    syntax , Nper(integer) LHR(real) CONFa(real) CONFy(real) ///
             BASEhaz(real) SEEDval(integer)
    foreach r in 1 0 {
        _surv_gen, nper(`nper') tper(6) lhr(`lhr') confa(`confa') ///
            confy(`confy') basehaz(`basehaz') seedval(`=`seedval'+`r'') regime(`r')
        tempfile _cf`r'
        save `_cf`r''
    }
    use `_cf1', clear
    append using `_cf0'
    * NB: _t0/_t/_d/_st are stset-reserved system names; use neutral names here.
    gen double entryt = period
    gen double exitt  = period + 1
    stset exitt, enter(entryt) failure(outcome)
    quietly stcox a, nolog
    return scalar truth = _b[a]
end

* Marginal cumulative-incidence risk difference at a horizon (first-event CIF).
capture program drop _oracle_cumincrd
program define _oracle_cumincrd, rclass
    syntax , Nper(integer) EFFect(real) CONFa(real) CONFy(real) ///
             INTa(real) INTy(real) HORizon(integer) SEEDval(integer)
    foreach r in 1 0 {
        _tv_gen, nper(`nper') tper(4) effect(`effect') confa(`confa') ///
            confy(`confy') inta(`inta') inty(`inty') seedval(`=`seedval'+`r'') regime(`r')
        bysort id (period): gen byte _cum = sum(outcome) > 0
        quietly summarize _cum if period==`horizon', meanonly
        local ci`r' = r(mean)
    }
    return scalar truth = `ci1' - `ci0'
end

* Two-seed oracle-stability wrapper: run an oracle program at two seeds, assert
* agreement within GUARD (proves oracle MC noise is small), return the average as
* r(truth). ORACLE is the program name; OPTS its argument string minus seedval.
capture program drop _stable_oracle
program define _stable_oracle, rclass
    syntax , ORACLE(string) SEEDa(integer) SEEDb(integer) GUARD(real) OPTS(string)
    `oracle', `opts' seedval(`seeda')
    local ta = r(truth)
    `oracle', `opts' seedval(`seedb')
    local tb = r(truth)
    * oracle-stability guard: two independent forward-sims must agree tightly
    assert abs(`ta' - `tb') < `guard'
    return scalar truth = (`ta' + `tb') / 2
    return scalar spread = abs(`ta' - `tb')
end

**# LINEAR ATE scenarios (collapsible: analytic truth = effect)

* --- D1: positive ATE, point treatment, moderate confounding ---
local ++test_count
capture noisily {
    _pt_gen, n(200000) effect(2.5) confa(0.9) confy(1.1) inta(-0.1) inty(1.0) seedval(70101)
    quietly regress ycont a
    local naive = _b[a]
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L)
    replace outcome = ycont
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(linear) period_spec(none) nolog
    local est = _b[a]
    display as text "  D1 truth=2.5  naive=" %7.4f `naive' "  IPTW=" %7.4f `est'
    assert abs(`naive' - 2.5) > 0.20
    assert abs(`est'   - 2.5) < 0.03
    assert reldif(e(effects)[1,1], `est') < 1e-8
}
if _rc==0 {
    display as result "  PASS D1: linear ATE recovery (positive, point)"
    local ++pass_count
}
else {
    display as error "  FAIL D1 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D1"
}

* --- D2: negative ATE, point treatment, strong confounding ---
local ++test_count
capture noisily {
    _pt_gen, n(200000) effect(-1.8) confa(1.1) confy(1.3) inta(0.1) inty(0.5) seedval(70202)
    quietly regress ycont a
    local naive = _b[a]
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L)
    replace outcome = ycont
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(linear) period_spec(none) nolog
    local est = _b[a]
    display as text "  D2 truth=-1.8  naive=" %7.4f `naive' "  IPTW=" %7.4f `est'
    assert abs(`naive' - (-1.8)) > 0.20
    assert abs(`est'   - (-1.8)) < 0.03
}
if _rc==0 {
    display as result "  PASS D2: linear ATE recovery (negative, strong confounding)"
    local ++pass_count
}
else {
    display as error "  FAIL D2 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D2"
}

* --- D3: null ATE = 0, point treatment (naive is confounded away from 0) ---
local ++test_count
capture noisily {
    _pt_gen, n(200000) effect(0.0) confa(1.0) confy(1.2) inta(-0.2) inty(0.3) seedval(70303)
    quietly regress ycont a
    local naive = _b[a]
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L)
    replace outcome = ycont
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(linear) period_spec(none) nolog
    local est = _b[a]
    display as text "  D3 truth=0  naive=" %7.4f `naive' "  IPTW=" %7.4f `est'
    assert abs(`naive') > 0.20
    assert abs(`est')   < 0.03
}
if _rc==0 {
    display as result "  PASS D3: linear null-ATE recovery"
    local ++pass_count
}
else {
    display as error "  FAIL D3 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D3"
}

* --- D4: multi-period time-varying treatment, positive ATE ---
local ++test_count
capture noisily {
    _tv_gen, nper(40000) tper(4) effect(1.3) confa(0.8) confy(0.9) inta(-0.1) inty(1.0) seedval(70404) regime(-1) conty
    quietly regress ycont a
    local naive = _b[a]
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L)
    replace outcome = ycont
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(linear) period_spec(linear) nolog
    local est = _b[a]
    display as text "  D4 truth=1.3  naive=" %7.4f `naive' "  IPTW=" %7.4f `est'
    assert abs(`naive' - 1.3) > 0.10
    assert abs(`est'   - 1.3) < 0.07
}
if _rc==0 {
    display as result "  PASS D4: linear ATE recovery (multi-period time-varying)"
    local ++pass_count
}
else {
    display as error "  FAIL D4 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D4"
}

* --- D5: point ATE with a time-fixed outcome_cov() adjustment covariate ---
* Adding a precision covariate X (baseline, time-fixed) to the outcome model must
* not change the recovered marginal ATE (still = effect).
local ++test_count
capture noisily {
    clear
    set seed 70505
    set obs 200000
    gen long id = _n
    gen int period = 0
    gen double L = rnormal()
    gen double X = rnormal()
    gen byte a = runiform() < invlogit(-0.1 + 0.9*L)
    gen double ycont = 1.0 + 2.0*a + 1.1*L + 0.7*X + rnormal(0,1)
    gen byte outcome = 0
    quietly regress ycont a
    local naive = _b[a]
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L) baseline_covariates(X)
    replace outcome = ycont
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(linear) period_spec(none) outcome_cov(X) nolog
    local est = _b[a]
    display as text "  D5 truth=2.0  naive=" %7.4f `naive' "  IPTW=" %7.4f `est'
    assert abs(`naive' - 2.0) > 0.10
    assert abs(`est'   - 2.0) < 0.03
}
if _rc==0 {
    display as result "  PASS D5: linear ATE recovery with outcome_cov() adjustment"
    local ++pass_count
}
else {
    display as error "  FAIL D5 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D5"
}

**# RISK DIFFERENCE scenarios (collapsible marginal RD via msm_predict)

* --- D6: point RD, harmful ---
local ++test_count
capture noisily {
    _pt_truth_rd, effect(0.8) confy(1.0) inty(-0.7) seedval(999001)
    local truth = r(rd)
    _pt_gen, n(200000) effect(0.8) confa(0.9) confy(1.0) inta(-0.1) inty(-0.7) seedval(70606) binary
    quietly ttest outcome, by(a)
    local naive = r(mu_2) - r(mu_1)
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(logistic) period_spec(none) nolog
    msm_predict, times(0) type(cum_inc) difference samples(50) seed(55)
    local est = r(rd_0)
    display as text "  D6 truth=" %6.4f `truth' "  naive=" %6.4f `naive' "  IPTW=" %6.4f `est'
    assert abs(`naive' - `truth') > 0.05
    assert abs(`est'   - `truth') < 0.02
}
if _rc==0 {
    display as result "  PASS D6: risk-difference recovery (harmful, point)"
    local ++pass_count
}
else {
    display as error "  FAIL D6 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D6"
}

* --- D7: point RD, protective ---
local ++test_count
capture noisily {
    _pt_truth_rd, effect(-0.9) confy(1.0) inty(0.2) seedval(999002)
    local truth = r(rd)
    _pt_gen, n(200000) effect(-0.9) confa(1.0) confy(1.0) inta(0.0) inty(0.2) seedval(70707) binary
    quietly ttest outcome, by(a)
    local naive = r(mu_2) - r(mu_1)
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(logistic) period_spec(none) nolog
    msm_predict, times(0) type(cum_inc) difference samples(50) seed(55)
    local est = r(rd_0)
    display as text "  D7 truth=" %6.4f `truth' "  naive=" %6.4f `naive' "  IPTW=" %6.4f `est'
    assert abs(`naive' - `truth') > 0.05
    assert abs(`est'   - `truth') < 0.02
    assert `est' < 0
}
if _rc==0 {
    display as result "  PASS D7: risk-difference recovery (protective, point)"
    local ++pass_count
}
else {
    display as error "  FAIL D7 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D7"
}

* --- D8: point RD, null -> RD ~ 0 (naive confounded away from 0) ---
local ++test_count
capture noisily {
    _pt_gen, n(200000) effect(0.0) confa(1.0) confy(1.2) inta(-0.2) inty(-0.3) seedval(70808) binary
    quietly ttest outcome, by(a)
    local naive = r(mu_2) - r(mu_1)
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(logistic) period_spec(none) nolog
    msm_predict, times(0) type(cum_inc) difference samples(50) seed(55)
    local est = r(rd_0)
    display as text "  D8 truth=0  naive=" %6.4f `naive' "  IPTW=" %6.4f `est'
    assert abs(`naive') > 0.05
    assert abs(`est')   < 0.02
}
if _rc==0 {
    display as result "  PASS D8: risk-difference null recovery"
    local ++pass_count
}
else {
    display as error "  FAIL D8 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D8"
}

* --- D9: multi-period cumulative-incidence RD at a horizon (forward-sim oracle) ---
local ++test_count
capture noisily {
    * oracle: two-seed forward-sim cumulative-incidence RD at horizon t=3
    _stable_oracle, oracle(_oracle_cumincrd) seeda(88088) seedb(52011) guard(0.02) ///
        opts("nper(200000) effect(0.8) confa(0.8) confy(0.7) inta(-0.1) inty(-1.0) horizon(3)")
    local truth = r(truth)
    local spread = r(spread)
    * observed confounded sample
    _tv_gen, nper(40000) tper(4) effect(0.8) confa(0.8) confy(0.7) inta(-0.1) inty(-1.0) seedval(70909) regime(-1)
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(logistic) period_spec(linear) nolog
    msm_predict, times(0 1 2 3) type(cum_inc) difference samples(50) seed(99)
    local est = r(rd_3)
    display as text "  D9 truth=" %6.4f `truth' " (oracle spread " %6.4f `spread' ")  IPTW rd_3=" %6.4f `est'
    assert abs(`est' - `truth') < 0.03
}
if _rc==0 {
    display as result "  PASS D9: multi-period cumulative-incidence RD recovery"
    local ++pass_count
}
else {
    display as error "  FAIL D9 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D9"
}

**# MARGINAL LOG-OR scenarios (non-collapsible; forward-sim pooled-logit oracle)

* --- D10: multi-period harmful log-OR, strong confounding (positivity ok) ---
local ++test_count
capture noisily {
    _stable_oracle, oracle(_oracle_logor) seeda(31013) seedb(90417) guard(0.02) ///
        opts("nper(200000) effect(`=ln(1.9)') confa(1.0) confy(0.8) inta(-0.1) inty(-1.1)")
    local truth = r(truth)
    local spread = r(spread)
    _tv_gen, nper(40000) tper(4) effect(`=ln(1.9)') confa(1.0) confy(0.8) inta(-0.1) inty(-1.1) seedval(71010) regime(-1)
    quietly logit outcome a period
    local naive = _b[a]
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(logistic) period_spec(linear) nolog
    local est = _b[a]
    display as text "  D10 truth=" %6.4f `truth' " (spread " %6.4f `spread' ")  naive=" %6.4f `naive' "  IPTW=" %6.4f `est'
    assert abs(`naive' - `truth') > 0.15
    assert abs(`est'   - `truth') < 0.05
}
if _rc==0 {
    display as result "  PASS D10: marginal log-OR recovery (harmful, strong confounding)"
    local ++pass_count
}
else {
    display as error "  FAIL D10 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D10"
}

* --- D11: multi-period null log-OR = 0 ---
local ++test_count
capture noisily {
    _tv_gen, nper(40000) tper(4) effect(0.0) confa(0.9) confy(0.9) inta(-0.1) inty(-0.8) seedval(71111) regime(-1)
    tempfile obs11
    save `obs11'
    quietly logit outcome a period
    local naive = _b[a]
    * truth is exactly 0 (no treatment term in the outcome DGP)
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(logistic) period_spec(linear) nolog
    local est = _b[a]
    display as text "  D11 truth=0  naive=" %6.4f `naive' "  IPTW=" %6.4f `est'
    assert abs(`naive') > 0.10
    assert abs(`est')   < 0.05
}
if _rc==0 {
    display as result "  PASS D11: marginal null log-OR recovery"
    local ++pass_count
}
else {
    display as error "  FAIL D11 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D11"
}

**# MARGINAL LOG-HR scenarios (Cox; forward-sim stcox oracle)

* --- D12: time-varying protective log-HR ---
local ++test_count
capture noisily {
    _stable_oracle, oracle(_oracle_loghr) seeda(41214) seedb(73320) guard(0.04) ///
        opts("nper(150000) lhr(-0.5) confa(0.8) confy(0.6) basehaz(-2.3)")
    local truth = r(truth)
    local spread = r(spread)
    _surv_gen, nper(60000) tper(6) lhr(-0.5) confa(0.8) confy(0.6) basehaz(-2.3) seedval(71212) regime(-1)
    quietly logit outcome a
    local naive = _b[a]
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(cox) period_spec(none) nolog
    local est = _b[a]
    display as text "  D12 truth=" %6.4f `truth' " (spread " %6.4f `spread' ")  naive=" %6.4f `naive' "  IPTW=" %6.4f `est'
    assert abs(`naive' - `truth') > 0.15
    assert abs(`est'   - `truth') < 0.06
    assert `est' < 0
}
if _rc==0 {
    display as result "  PASS D12: marginal log-HR recovery (protective, time-varying)"
    local ++pass_count
}
else {
    display as error "  FAIL D12 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D12"
}

* --- D13: time-varying harmful log-HR ---
local ++test_count
capture noisily {
    _stable_oracle, oracle(_oracle_loghr) seeda(41315) seedb(80426) guard(0.04) ///
        opts("nper(150000) lhr(0.6) confa(0.8) confy(0.6) basehaz(-2.5)")
    local truth = r(truth)
    local spread = r(spread)
    _surv_gen, nper(60000) tper(6) lhr(0.6) confa(0.8) confy(0.6) basehaz(-2.5) seedval(71313) regime(-1)
    quietly logit outcome a
    local naive = _b[a]
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(cox) period_spec(none) nolog
    local est = _b[a]
    display as text "  D13 truth=" %6.4f `truth' " (spread " %6.4f `spread' ")  naive=" %6.4f `naive' "  IPTW=" %6.4f `est'
    assert abs(`naive' - `truth') > 0.15
    assert abs(`est'   - `truth') < 0.06
    assert `est' > 0
}
if _rc==0 {
    display as result "  PASS D13: marginal log-HR recovery (harmful, time-varying)"
    local ++pass_count
}
else {
    display as error "  FAIL D13 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D13"
}

**# WEIGHT MACHINERY scenarios

* --- D14: IPCW -- informative censoring, linear ATE recovered via censor weights ---
* Naive (complete-case) regression on uncensored is biased; treatment + censoring
* weights jointly recover the additive ATE = effect.
local ++test_count
capture noisily {
    _pt_gen, n(200000) effect(1.5) confa(0.8) confy(1.0) inta(0.0) inty(2.0) seedval(71414) cint(-0.3) cconf(0.9)
    quietly regress ycont a if censor==0
    local naive = _b[a]
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) censor(censor) covariates(L)
    replace outcome = ycont
    msm_weight, treat_d_cov(L) censor_d_cov(L) nolog
    msm_fit, model(linear) period_spec(none) nolog
    local est = _b[a]
    display as text "  D14 truth=1.5  naive(cc)=" %7.4f `naive' "  IPTW+IPCW=" %7.4f `est'
    assert abs(`naive' - 1.5) > 0.10
    assert abs(`est'   - 1.5) < 0.06
}
if _rc==0 {
    display as result "  PASS D14: IPCW censoring recovery (linear ATE)"
    local ++pass_count
}
else {
    display as error "  FAIL D14 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D14"
}

* --- D15: truncate() bounded gate -- moderate truncation still recovers RD ---
* Light symmetric truncation (1st/99th pct) barely attenuates; the marginal RD is
* still recovered. This guards that truncation does not silently bias the estimand
* away from the truth under good positivity.
local ++test_count
capture noisily {
    _pt_truth_rd, effect(0.8) confy(1.0) inty(-0.7) seedval(999015)
    local truth = r(rd)
    _pt_gen, n(120000) effect(0.8) confa(0.9) confy(1.0) inta(0.0) inty(-0.7) seedval(71515) binary
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L)
    msm_weight, treat_d_cov(L) truncate(1) nolog
    local n_trunc = r(n_truncated)
    msm_fit, model(logistic) period_spec(none) nolog
    msm_predict, times(0) type(cum_inc) difference samples(50) seed(1)
    local est = r(rd_0)
    display as text "  D15 truth=" %6.4f `truth' "  truncate(1) RD=" %6.4f `est' "  (n_trunc=`n_trunc')"
    assert `n_trunc' > 0
    assert abs(`est' - `truth') < 0.03
}
if _rc==0 {
    display as result "  PASS D15: truncation bounded-gate RD recovery"
    local ++pass_count
}
else {
    display as error "  FAIL D15 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D15"
}

* --- D16: stronger treatment confounding still recovers marginal log-OR ---
local ++test_count
capture noisily {
    _stable_oracle, oracle(_oracle_logor) seeda(61619) seedb(15927) guard(0.02) ///
        opts("nper(200000) effect(`=ln(0.55)') confa(1.3) confy(1.0) inta(0.0) inty(-0.6)")
    local truth = r(truth)
    local spread = r(spread)
    _tv_gen, nper(40000) tper(4) effect(`=ln(0.55)') confa(1.3) confy(1.0) inta(0.0) inty(-0.6) seedval(71616) regime(-1)
    quietly logit outcome a period
    local naive = _b[a]
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(logistic) period_spec(linear) nolog
    local est = _b[a]
    display as text "  D16 truth=" %6.4f `truth' " (spread " %6.4f `spread' ")  naive=" %6.4f `naive' "  IPTW=" %6.4f `est'
    assert abs(`naive' - `truth') > 0.15
    assert abs(`est'   - `truth') < 0.06
}
if _rc==0 {
    display as result "  PASS D16: marginal log-OR recovery under stronger confounding"
    local ++pass_count
}
else {
    display as error "  FAIL D16 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D16"
}

**# SCOPE BOUNDARY (documented known answer, not an estimator bug)

* --- D17: time-invariant (baseline) treatment is out of scope ---
* msm targets TIME-VARYING treatment; a single-point-in-time treatment held
* constant across a panel makes A_t ~ lagged A_t perfectly predicted, so
* msm_weight must REFUSE to fabricate weights (default fitfailure(error)) rather
* than silently produce a marginal fallback. It must exit with a nonzero code and
* name the cause. This pins the documented scope boundary (msm.sthlp: "consider
* teffects ipw instead") as a regression.
local ++test_count
capture noisily {
    clear
    set seed 71717
    set obs 30000
    gen long id = _n
    gen double L = rnormal()
    gen byte a = runiform() < invlogit(0.8*L)
    expand 4
    bysort id: gen int period = _n - 1
    gen byte outcome = runiform() < invlogit(-2 + 0.5*a + 0.5*L)
    bysort id (period): gen byte pastev = sum(outcome) > outcome
    drop if pastev==1
    drop pastev
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L)
    capture msm_weight, treat_d_cov(L) nolog
    local wrc = _rc
    display as text "  D17 baseline-treatment msm_weight rc=`wrc' (expect 498 refuse)"
    * 498 = documented refusal to fabricate weights (fitfailure(error) default).
    * The improved diagnostic (v1.2.3) names the time-invariant-treatment cause;
    * the hard-fail code itself is the machine-checkable contract here.
    assert `wrc' == 498
}
if _rc==0 {
    display as result "  PASS D17: time-invariant treatment correctly refused (out of scope)"
    local ++pass_count
}
else {
    display as error "  FAIL D17 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D17"
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED:`failed_tests'"
    display "RESULT: validation_msm_dgp_recovery tests=`test_count' pass=`pass_count' fail=`fail_count'"
    capture log close
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_msm_dgp_recovery tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close
