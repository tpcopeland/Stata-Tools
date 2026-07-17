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
*   LINEAR PROBABILITY MODEL (model(linear), _b[treatment]) -- the documented
*   LPM for the prepared BINARY outcome; _b[a] is the marginal risk difference:
*     D1 positive RD, point treatment, moderate confounding   [analytic truth]
*     D2 negative RD, point treatment, strong confounding     [analytic truth]
*     D3 null RD = 0, point treatment                         [exact 0]
*     D4 multi-period time-varying treatment, hazard LPM      [forward-sim oracle]
*     D5 point RD with a time-fixed outcome_cov() covariate   [analytic truth]
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
*     D14 IPCW: informative censoring, marginal hazard RD via censor weights.
*         Regression for finding N05 (fixed under A10, 2026-07-17): the
*         cumulative censoring weight used to be off by one against msm's own
*         within-period timing convention. Asserts recovery at TWO censoring
*         strengths -- a single strength near ca=2 passes by error cancellation.
*         Do NOT collapse it back to one strength.
*     D15 truncate(): bounded gate -- moderate truncation still recovers RD
*     D16 stronger treatment confounding still recovers marginal log-OR
*     D18 A10: stabilized numerator covariates must enter the outcome model
*     D19 A10: time-varying numerator covariates have no unsafe opt-out
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
*   y ~ Bernoulli(expit(inty + effect*a + confy*L))
* Optional informative censoring:  c ~ Bernoulli(expit(cint + cconf*L)).
*
* The outcome is binary, unconditionally.  This generator used to carry a
* continuous `ycont` branch behind a binary() toggle; that branch existed only
* to be smuggled past msm_prepare via `replace outcome = ycont` (audit Q10) and
* is gone.  msm_prepare requires a binary outcome and the weighting layer reads
* the outcome as a risk process, so a continuous outcome is not a supported
* input to any part of this package -- there is nothing for such a branch to
* legitimately test, and keeping it available is how Q10 happened.
capture program drop _pt_gen
program define _pt_gen
    syntax , N(integer) EFFect(real) CONFa(real) CONFy(real) INTa(real) ///
             INTy(real) SEEDval(integer) [CINT(real 999) CCONF(real 0)]
    clear
    set seed `seedval'
    set obs `n'
    gen long id = _n
    gen int period = 0
    gen double L = rnormal()
    gen byte a = runiform() < invlogit(`inta' + `confa'*L)
    gen byte outcome = runiform() < invlogit(`inty' + `effect'*a + `confy'*L)
    if `cint' != 999 {
        gen byte censor = runiform() < invlogit(`cint' + `cconf'*L)
    }
end

* Analytic marginal risk difference for the point binary DGP:
*   E_{L,X}[ p(a=1) - p(a=0) ]
* computed by Monte-Carlo integration over the KNOWN L (and, when bx() is given,
* X) distribution -- independent of the estimator. Returns r(rd).
* bx() defaults to 0, in which case X drops out and this is the plain E_L form.
capture program drop _pt_truth_rd
program define _pt_truth_rd, rclass
    syntax , EFFect(real) CONFy(real) INTy(real) SEEDval(integer) [BX(real 0)]
    clear
    set seed `seedval'
    set obs 500000
    gen double L = rnormal()
    gen double X = rnormal()
    gen double p1 = invlogit(`inty' + `effect' + `confy'*L + `bx'*X)
    gen double p0 = invlogit(`inty' + `confy'*L + `bx'*X)
    quietly summarize p1, meanonly
    local r1 = r(mean)
    quietly summarize p0, meanonly
    return scalar rd = `r1' - r(mean)
end

* Multi-period panel, exogenous AR(1) confounder (no treatment->confounder
* feedback), time-varying treatment.  regime==-1 confounded (observed);
* 0/1 static always/never for building forward-sim oracles.
*
* Binary outcome only -- the continuous conty() branch is gone for the same
* reason as _pt_gen's (audit Q10).  Note this is a REPEATED-MEASURES panel: it
* does not drop post-event rows, so it suits estimands read off msm_predict
* (cumulative incidence) and the pooled logit.  Anything fitting the outcome
* directly as a risk process wants _surv_gen instead -- msm's weighting layer
* treats a nonzero prior outcome as a terminal event.
capture program drop _tv_gen
program define _tv_gen
    syntax , Nper(integer) Tper(integer) EFFect(real) CONFa(real) CONFy(real) ///
             INTa(real) INTy(real) SEEDval(integer) REGime(integer)
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
    quietly gen byte outcome = runiform() < invlogit(`inty' + `effect'*a + `confy'*L)
end

* Multi-period discrete-time survival panel, time-varying treatment.  Rows after
* the first event are dropped (standard person-period survival structure).
*
* Optional informative censoring (cint() != 999):  c ~ Bernoulli(expit(cint +
* cconf*L + ca*a)).  The timing follows the convention msm itself enforces:
* CENSORING IS ASSESSED FIRST within a period, so a censored row carries no
* observed outcome and msm_fit excludes it (msm_fit.ado:370 keeps only
* censor==0 rows).  Rows after the censoring row are dropped.
*
* ca() matters for whether the fixture can discriminate at all.  Censoring that
* depends only on L does NOT meaningfully bias the treatment contrast: IP
* treatment weighting already makes a independent of L, so L-selection is
* symmetric across arms and IPTW alone recovers the truth.  Censoring must
* depend on TREATMENT (ca() != 0) for censor weights to be genuinely required.
capture program drop _surv_gen
program define _surv_gen
    syntax , Nper(integer) Tper(integer) LHR(real) CONFa(real) CONFy(real) ///
             BASEhaz(real) SEEDval(integer) REGime(integer) ///
             [CINT(real 999) CCONF(real 0) CA(real 0)]
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
    if `cint' != 999 {
        quietly gen byte censor = runiform() < invlogit(`cint' + `cconf'*L + `ca'*a)
        quietly replace outcome = 0 if censor==1
        quietly bysort id (period): gen byte pastc = sum(censor) > censor
        quietly drop if pastc==1
        drop pastc
    }
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

* Marginal additive-hazard (LPM) oracle: regress outcome a period on the
* always+never worlds.  This is the estimand msm_fit reports for
* model(linear) period_spec(linear) on a person-period survival panel -- the
* linear-probability projection of the discrete-time hazard onto (1, a, period).
* It has no closed form (the per-period risk difference varies with the L
* distribution, and the period trend is a working model), so the truth is read
* off the estimator's OWN working model fitted to the true counterfactual
* worlds -- the same forward-sim pattern used by _oracle_logor/_oracle_loghr.
* Built WITHOUT censoring: the estimand is defined on complete follow-up, which
* is what IPCW is supposed to recover from a censored sample.
capture program drop _oracle_lpm_haz
program define _oracle_lpm_haz, rclass
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
    quietly regress outcome a period
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

**# LINEAR PROBABILITY MODEL scenarios (binary outcome; marginal risk difference)
*
* Q10.  These scenarios previously mapped a dummy binary outcome through
* msm_prepare and then ran `replace outcome = ycont`, smuggling a continuous
* outcome past the binary contract msm_prepare enforces.  That is not a
* supported use of the package: model(linear) is documented as the linear
* PROBABILITY model for the prepared binary outcome, and the weighting layer
* reads the outcome as a risk process (a nonzero prior outcome is a terminal
* event via its running outcome sum), so a continuous outcome silently
* corrupted the risk history the tests claimed to validate.
*
* Rewritten per the audit's own Q10 fix -- "use binary outcomes for the
* documented linear probability model".  With correct IP treatment weights the
* pseudo-population has a independent of L, so the LPM coefficient on a is the
* marginal RISK DIFFERENCE, and the truth is computed analytically from the
* known DGP by Monte-Carlo integration over L (never from another estimator).

* --- D1: positive marginal RD, point treatment, moderate confounding ---
local ++test_count
capture noisily {
    _pt_truth_rd, effect(0.8) confy(1.0) inty(-0.7) seedval(999101)
    local truth = r(rd)
    _pt_gen, n(200000) effect(0.8) confa(0.9) confy(1.0) inta(-0.1) inty(-0.7) seedval(70101)
    quietly regress outcome a
    local naive = _b[a]
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(linear) period_spec(none) nolog
    local est = _b[a]
    display as text "  D1 truth=" %6.4f `truth' "  naive=" %7.4f `naive' "  IPTW=" %7.4f `est'
    assert abs(`naive' - `truth') > 0.05
    assert abs(`est'   - `truth') < 0.01
    assert reldif(e(effects)[1,1], `est') < 1e-8
}
if _rc==0 {
    display as result "  PASS D1: LPM marginal-RD recovery (positive, point)"
    local ++pass_count
}
else {
    display as error "  FAIL D1 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D1"
}

* --- D2: negative marginal RD, point treatment, strong confounding ---
local ++test_count
capture noisily {
    _pt_truth_rd, effect(-1.2) confy(1.3) inty(0.5) seedval(999102)
    local truth = r(rd)
    _pt_gen, n(200000) effect(-1.2) confa(1.1) confy(1.3) inta(0.1) inty(0.5) seedval(70202)
    quietly regress outcome a
    local naive = _b[a]
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(linear) period_spec(none) nolog
    local est = _b[a]
    display as text "  D2 truth=" %6.4f `truth' "  naive=" %7.4f `naive' "  IPTW=" %7.4f `est'
    assert abs(`naive' - `truth') > 0.05
    assert abs(`est'   - `truth') < 0.01
    assert `est' < 0
}
if _rc==0 {
    display as result "  PASS D2: LPM marginal-RD recovery (negative, strong confounding)"
    local ++pass_count
}
else {
    display as error "  FAIL D2 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D2"
}

* --- D3: null marginal RD = 0, point treatment ---
* effect=0 makes p(a=1|L) == p(a=0|L) pointwise, so the marginal RD is EXACTLY
* zero by construction -- no Monte-Carlo integration needed.  The naive estimate
* is confounded away from 0.
local ++test_count
capture noisily {
    _pt_gen, n(200000) effect(0.0) confa(1.0) confy(1.2) inta(-0.2) inty(-0.3) seedval(70303)
    quietly regress outcome a
    local naive = _b[a]
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(linear) period_spec(none) nolog
    local est = _b[a]
    display as text "  D3 truth=0  naive=" %7.4f `naive' "  IPTW=" %7.4f `est'
    assert abs(`naive') > 0.05
    assert abs(`est')   < 0.01
}
if _rc==0 {
    display as result "  PASS D3: LPM null marginal-RD recovery"
    local ++pass_count
}
else {
    display as error "  FAIL D3 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D3"
}

* --- D4: multi-period time-varying treatment, LPM on the discrete-time hazard ---
* A binary outcome over multiple periods IS a risk process, so this uses the
* person-period survival panel (rows after the first event dropped) rather than
* the repeated-measures panel -- that is the structure msm's weighting layer
* assumes.  The estimand (the LPM projection of the hazard onto (1, a, period))
* has no closed form, so truth comes from the two-seed forward-sim oracle.
local ++test_count
capture noisily {
    _stable_oracle, oracle(_oracle_lpm_haz) seeda(41013) seedb(80417) guard(0.01) ///
        opts("nper(200000) lhr(0.9) confa(0.8) confy(1.2) basehaz(-2.0)")
    local truth = r(truth)
    local spread = r(spread)
    _surv_gen, nper(60000) tper(6) lhr(0.9) confa(0.8) confy(1.2) basehaz(-2.0) seedval(70404) regime(-1)
    quietly regress outcome a period
    local naive = _b[a]
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(linear) period_spec(linear) nolog
    local est = _b[a]
    display as text "  D4 truth=" %6.4f `truth' " (oracle spread " %6.4f `spread' ")  naive=" %7.4f `naive' "  IPTW=" %7.4f `est'
    assert abs(`naive' - `truth') > 0.03
    assert abs(`est'   - `truth') < 0.015
}
if _rc==0 {
    display as result "  PASS D4: LPM hazard recovery (multi-period time-varying)"
    local ++pass_count
}
else {
    display as error "  FAIL D4 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D4"
}

* --- D5: point RD with a time-fixed outcome_cov() adjustment covariate ---
* Adding a precision covariate X (baseline, time-fixed) to the outcome model must
* not change the recovered marginal RD.  X enters the DGP nonlinearly (through
* the logit), so this is not trivially true: it holds because a is independent of
* X in the IP-weighted pseudo-population, which by Frisch-Waugh-Lovell leaves the
* coefficient on a untouched.  The truth marginalizes over BOTH L and X.
local ++test_count
capture noisily {
    _pt_truth_rd, effect(0.9) confy(1.0) inty(-0.5) bx(0.7) seedval(999105)
    local truth = r(rd)
    clear
    set seed 70505
    set obs 200000
    gen long id = _n
    gen int period = 0
    gen double L = rnormal()
    gen double X = rnormal()
    gen byte a = runiform() < invlogit(-0.1 + 0.9*L)
    gen byte outcome = runiform() < invlogit(-0.5 + 0.9*a + 1.0*L + 0.7*X)
    quietly regress outcome a
    local naive = _b[a]
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L) baseline_covariates(X)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(linear) period_spec(none) outcome_cov(X) nolog
    local est = _b[a]
    display as text "  D5 truth=" %6.4f `truth' "  naive=" %7.4f `naive' "  IPTW=" %7.4f `est'
    assert abs(`naive' - `truth') > 0.05
    assert abs(`est'   - `truth') < 0.01
}
if _rc==0 {
    display as result "  PASS D5: LPM marginal-RD recovery with outcome_cov() adjustment"
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
    _pt_gen, n(200000) effect(0.8) confa(0.9) confy(1.0) inta(-0.1) inty(-0.7) seedval(70606)
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
    _pt_gen, n(200000) effect(-0.9) confa(1.0) confy(1.0) inta(0.0) inty(0.2) seedval(70707)
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
    _pt_gen, n(200000) effect(0.0) confa(1.0) confy(1.2) inta(-0.2) inty(-0.3) seedval(70808)
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

* --- D14: IPCW -- informative censoring, marginal hazard RD via censor weights ---
*
* Q10 rewrite (binary outcome; the old form ran `replace outcome = ycont` BEFORE
* msm_weight, which the audit noted destroyed the censor model's own sample --
* the censor helper requires outcome==0, so almost every continuous row was
* excluded and the test validated nothing it claimed to).
*
* REGRESSION for finding N05 (surfaced 2026-07-17 by the Q10 rewrite, fixed the
* same day under A10).  This test was RED on msm 1.2.3 and is green on the fix.
*
* The test asserts recovery at TWO censoring strengths, and that is deliberate.
* A correct IPCW recovers the truth at EVERY censoring strength.  The broken
* censor weights instead carried a fixed additive distortion (~ +0.026 on this
* DGP, stable across seeds) which happened to cancel the real censoring bias
* near ca=2 and to be the entire error at ca=0.  Asserting a single strength
* near ca=2 would therefore have reported a false green built on error
* cancellation -- exactly how the previous generation of these tests stayed
* green.  Do NOT collapse this back to one strength.
*
* Measured on msm 1.2.3 (truth 0.11432 from the two-seed forward-sim oracle):
*
*     ca     err IPTW-only     err IPTW+IPCW
*     0.0        -0.001            +0.026     <- IPCW INTRODUCED bias
*     1.0        -0.024            +0.012
*     2.0        -0.049            -0.004     <- cancellation, not recovery
*
* Mechanism (msm_weight.ado): the cumulative censoring weight zeroed its own
* log-factor on any row where outcome != 0 (`replace _log_cw = 0 if !_at_risk |
* outcome != 0`, and _denom_complete was restricted to outcome == 0), so an EVENT
* row never received its own period's censoring factor while a non-event row
* always did.  Measured directly: 1744/1744 event rows carried the prior period's
* weight unchanged, vs 0/12912 non-event rows.  That was an off-by-one against
* msm's own timing convention -- msm_fit.ado:370 excludes censor==1 rows from the
* estimation sample, which means censoring precedes outcome assessment within a
* period, so an observed event at t implies survival of censoring at t and its
* factor belongs in the weight.  msm_weight instead conditioned the censoring
* model on the CURRENT outcome, which is the opposite (outcome-first) convention.
*
* Hernan, Brumback & Robins (2000), Epidemiology 11:561-570, p.563 settles which
* convention is right: sw-dagger_i(t) = prod over k=0..t INCLUSIVE of
* pr[C(k)=0 | Cbar(k-1)=0, Abar(k-1), V] / pr[C(k)=0 | Cbar(k-1)=0, Abar(k-1),
* Lbar(k)], applied "for a subject at risk at month t".  Conditioning is on
* history only -- the current outcome D(k) appears in no conditioning set -- and
* p.564 fits the censoring model on subjects "alive and uncensored in month k".
* That is censor-first, i.e. msm_fit was right and msm_weight was wrong.
* See _literature/msm/hernan-2000-msm-zidovudine.notes.md.
local ++test_count
capture noisily {
    _stable_oracle, oracle(_oracle_lpm_haz) seeda(41013) seedb(80417) guard(0.01) ///
        opts("nper(200000) lhr(0.9) confa(0.8) confy(1.2) basehaz(-2.0)")
    local truth = r(truth)

    * ca(2.0): censoring depends on treatment, so IPCW is genuinely required.
    _surv_gen, nper(60000) tper(6) lhr(0.9) confa(0.8) confy(1.2) basehaz(-2.0) ///
        seedval(71414) regime(-1) cint(-1.6) cconf(0.9) ca(2.0)
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) censor(censor) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(linear) period_spec(linear) nolog
    local naive_hi = _b[a]
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) censor(censor) covariates(L)
    msm_weight, treat_d_cov(L) censor_d_cov(L) nolog
    msm_fit, model(linear) period_spec(linear) nolog
    local est_hi = _b[a]

    * ca(0.0): censoring depends on L only.  IP treatment weighting already makes
    * a independent of L, so IPTW alone is unbiased here -- adding censor weights
    * must LEAVE IT THERE.  A correction that moves an already-correct estimate
    * away from the truth is not a correction.
    _surv_gen, nper(60000) tper(6) lhr(0.9) confa(0.8) confy(1.2) basehaz(-2.0) ///
        seedval(71414) regime(-1) cint(-1.6) cconf(0.9) ca(0.0)
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) censor(censor) covariates(L)
    msm_weight, treat_d_cov(L) nolog
    msm_fit, model(linear) period_spec(linear) nolog
    local naive_lo = _b[a]
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) censor(censor) covariates(L)
    msm_weight, treat_d_cov(L) censor_d_cov(L) nolog
    msm_fit, model(linear) period_spec(linear) nolog
    local est_lo = _b[a]

    display as text "  D14 truth=" %6.4f `truth'
    display as text "      ca=2.0  no-IPCW=" %7.4f `naive_hi' "  IPTW+IPCW=" %7.4f `est_hi'
    display as text "      ca=0.0  no-IPCW=" %7.4f `naive_lo' "  IPTW+IPCW=" %7.4f `est_lo'

    * The fixture discriminates: without censor weights, ca=2.0 is meaningfully
    * biased.  (If this assertion ever fails, the DGP has stopped exercising the
    * censoring machinery and the recovery assertions below are vacuous.)
    assert abs(`naive_hi' - `truth') > 0.03
    * ... and ca=0.0 is already unbiased without them.
    assert abs(`naive_lo' - `truth') < 0.01

    * Recovery must hold at BOTH strengths.
    assert abs(`est_hi' - `truth') < 0.015
    assert abs(`est_lo' - `truth') < 0.015
}
if _rc==0 {
    display as result "  PASS D14: IPCW censoring recovery (marginal hazard RD)"
    local ++pass_count
}
else {
    display as error "  FAIL D14 (rc=`=_rc') -- IPCW regression for finding N05 (A10)"
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
    _pt_gen, n(120000) effect(0.8) confa(0.9) confy(1.0) inta(0.0) inty(-0.7) seedval(71515)
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

**# A10 -- stabilized numerator contract

* --- D18: numerator covariates must enter the structural outcome model ---
*
* This is the audit's own A10 reproduction (finding A10, "Runtime DGP": true
* effect 1; identical numerator and denominator models made every stabilized
* weight exactly 1; the default fit omitting V estimated 2.8384 and the fit with
* outcome_cov(V) estimated 1.0036).
*
* The numerator and denominator models here are IDENTICAL (both `a ~ V'), so
* every stabilized weight is exactly 1 and the weighting does literally nothing.
* Every bit of confounding control therefore has to come from the outcome model
* -- which is precisely why a numerator covariate has to appear in it.  A
* stabilized weight that looks perfect (mean 1, no spread, no truncation, no
* positivity warning) is completely compatible with a badly confounded estimate.
*
* The DGP is linear in the probability, so the LPM is correctly specified and the
* marginal risk difference is EXACTLY 0.15 by construction -- no oracle needed.
*
* On msm 1.2.3 the omitted-V fit returned rc=0 and a confounded estimate; this
* test fails on that code at the `assert `omit_rc' == 198' line.
local ++test_count
capture noisily {
    clear
    set seed 70418
    set obs 200000
    gen long id = _n
    gen int period = 0
    gen byte V = runiform() < 0.5
    gen byte a = runiform() < invlogit(-0.75 + 1.5*V)
    gen double p = 0.30 + 0.15*a + 0.30*V
    gen byte outcome = runiform() < p
    drop p
    local truth = 0.15

    quietly regress outcome a
    local naive = _b[a]

    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(V)
    msm_weight, treat_d_cov(V) treat_n_cov(V) nolog

    * The stabilization is exact -- identical numerator and denominator models.
    * If this ever fails, the scenario has stopped making its own point and the
    * assertions below no longer show what they claim to.
    quietly summarize _msm_weight
    assert r(N) == 200000
    assert reldif(r(min), 1) < 1e-8
    assert reldif(r(max), 1) < 1e-8

    * Omitting V is refused, not silently estimated.
    capture msm_fit, model(linear) period_spec(none) nolog
    local omit_rc = _rc

    msm_fit, model(linear) period_spec(none) outcome_cov(V) nolog
    local est = _b[a]

    display as text "  D18 truth=" %6.4f `truth' "  naive=" %7.4f `naive' ///
        "  weights==1  omit_rc=`omit_rc'  MSM=" %7.4f `est'

    assert `omit_rc' == 198
    * The fixture discriminates: omitting V really is badly confounded here, so
    * the refusal above is preventing a wrong answer rather than being pedantic.
    assert abs(`naive' - `truth') > 0.05
    assert abs(`est'   - `truth') < 0.01
}
if _rc==0 {
    display as result "  PASS D18: numerator covariate required in the outcome model"
    local ++pass_count
}
else {
    display as error "  FAIL D18 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D18"
}

* --- D19: time-varying numerator covariates have no unsafe opt-out -----------
*
* The stabilized numerator's V is baseline-fixed by definition -- Hernan,
* Brumback & Robins (2000) p.562 define V as "a vector of time-independent
* baseline covariates", and the MSM is conditional on it.  Handing a
* time-varying confounder to treat_n_cov() silently changes the estimand into a
* history MSM that msm_fit's prediction-ready form cannot represent.
local ++test_count
capture noisily {
    _surv_gen, nper(4000) tper(5) lhr(0.5) confa(0.8) confy(0.8) basehaz(-2.2) ///
        seedval(70419) regime(-1)
    msm_prepare, id(id) period(period) treatment(a) outcome(outcome) covariates(L)

    * L is an AR(1) within id, so it is emphatically not baseline-fixed.
    capture msm_weight, treat_d_cov(L) treat_n_cov(L) nolog
    local tv_rc = _rc

    * The former historymsm flag merely silenced the check; it could not create
    * or verify a compatible history MSM. It is therefore no longer accepted.
    capture msm_weight, treat_d_cov(L) treat_n_cov(L) historymsm nolog replace
    local hist_rc = _rc

    display as text "  D19 time-varying numerator rc=`tv_rc' (want 198)" ///
        "   historymsm rc=`hist_rc' (want 198)"
    assert `tv_rc' == 198
    assert `hist_rc' == 198
}
if _rc==0 {
    display as result "  PASS D19: time-varying numerator has no unsafe opt-out"
    local ++pass_count
}
else {
    display as error "  FAIL D19 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D19"
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
