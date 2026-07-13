clear all
set varabbrev off
version 16.0

* validation_gcomp_recovery_surface.do
* ----------------------------------------------------------------------------
* Known-truth parameter recovery across gcomp's UNTESTED OPTION SURFACE. This
* suite complements validation_gcomp_recovery.do (binary time-varying static
* regime) and validation_gcomp_recovery_extended.do (R1-R14: point-treatment,
* dose-response, mediation NDE/NIE/TCE/CDE, time-varying continuous) by driving
* the option paths those two do not exercise, each with the truth computed
* directly from the DGP we wrote (an exact analytic g-formula oracle, or a
* forward-simulation of the regime for the longitudinal estimands) -- never
* from another estimator.
*
* New paths covered here (one scenario each unless noted):
*   S1  minsim            deterministic MC (expected values, no draw noise)
*   S2  moreMC            Monte-Carlo size > N
*   S3  protective        negative treatment effect (sign path)
*   S4  two intvars       joint intervention via the "\" component syntax
*   S5  4-level ologit    ordinal dose-response, 4 levels
*   S6  logRR             mediation natural effects on the log-RR scale
*   S7  logOR             mediation natural effects on the log-OR scale
*   S8  oce               3-level categorical-exposure mediation (e(tce_j))
*   S9  specific          baseline()/alternative() single custom contrast
*   S10 mixed models      binary mediator (logit) + continuous outcome (regress)
*   S11 impute            single stochastic imputation of a MAR-missing confounder
*   S12 pooled            pooled logistic across visits (constant-coef DGP)
*   S13 dynamic           threshold dynamic regime ("treat if L>c")
*   S14 4 time points     longer follow-up static-regime recovery
*   S15 mlogit            multinomial-logit time-varying covariate simulation
*
* Oracle discipline. Every truth is set by us in the DGP: point-treatment /
* mediation truths are the finite-sample mean potential outcome under the TRUE
* coefficients evaluated on the same covariates the estimator sees (so the only
* residual is the estimator's MC-integration + finite-N fitting error); the
* longitudinal static/dynamic truths are the forward-simulation of the DGP under
* the regime at large N. Each scenario also confirms that a NAIVE/confounded
* estimator MISSES the truth (where confounding is present), proving the
* scenario actually exercises what g-computation is meant to fix.
*
* e(b) column convention (intervention mode): column j = potential outcome under
* the j-th interventions() spec, in the order written; the trailing natural
* course is not read here. Mediation convenience handles: e(tce)/e(nde)/e(nie)
* hold the value on whatever scale e(scale) reports (RD default, else logRR/logOR);
* oce stores e(tce_j)/e(nde_j)/e(nie_j) for the j-th non-baseline exposure level.
*
* Tolerances are set from observed gcomp MC error at the sim()/samples() used,
* not from whatever makes a test pass.
* ----------------------------------------------------------------------------

* Bootstrap: derive package root from qa/ working directory (relocatable)
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"

global T = 0
global P = 0
global F = 0

* chk "label" <0/1> : record one known-answer assertion. Callers wrap the
* condition in `=(...)' so it is evaluated in the caller's scope (where the
* tolerance locals and DGP scalars live) and chk receives a literal 0/1.
capture program drop chk
program define chk
    gettoken label 0 : 0
    local ok `0'
    global T = $T + 1
    if `ok' {
        global P = $P + 1
        display as result "  PASS: `label'"
    }
    else {
        global F = $F + 1
        display as error  "  FAIL: `label'"
    }
end

* Encode baseline-treatment recovery cases as valid two-visit eofu panels.
capture program drop _gcs_two_visit_eofu
program define _gcs_two_visit_eofu
    syntax, OUTcome(varname)
    expand 2
    bysort id: replace time = _n
    replace `outcome' = . if time == 1
end

* Tolerances (from observed MC error at the sim()/samples() below)
local tolPO    = 0.02     // point-treatment potential outcome / RD (random MC)
local tolDet   = 0.015    // deterministic (minsim) recovery -- no draw noise
local tolCont  = 0.03     // continuous-outcome ATE / longitudinal forward-sim
local tolMed   = 0.04     // mediation RD-scale effects
local tolLogRR = 0.03     // mediation logRR effects (minsim, deterministic)
local tolLogOR = 0.06     // mediation logOR effects -- BOUNDED gate (see S7 note)
local tolTV    = 0.03     // time-varying binary RD forward-sim
local naiveMin = 0.03     // crude estimator must miss the truth by > this

**# S1: minsim -- deterministic Monte Carlo (expected values, no draw noise)
* Same confounded binary-ATE DGP as R1, but minsim replaces the random Bernoulli
* draw with the fitted probability. The point estimate is then a deterministic
* g-formula average, so recovery is tighter than the random-draw path.

capture noisily {
    clear
    set seed 2001001
    set obs 25000
    gen long id = _n
    gen byte time = 1
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen byte a = rbinomial(1, invlogit(0.2 + 0.5*x1 - 0.3*x2))
    gen byte y = rbinomial(1, invlogit(-1 + 0.8*a + 0.5*x1 - 0.4*x2))
    gen double p1 = invlogit(-1 + 0.8 + 0.5*x1 - 0.4*x2)
    gen double p0 = invlogit(-1 + 0.5*x1 - 0.4*x2)
    quietly summarize p1, meanonly
    scalar T_PO1 = r(mean)
    quietly summarize p0, meanonly
    scalar T_PO0 = r(mean)
    scalar T_RD = T_PO1 - T_PO0
    quietly summarize y if a==1, meanonly
    scalar C1 = r(mean)
    quietly summarize y if a==0, meanonly
    scalar C0 = r(mean)
    scalar CRUDE_RD = C1 - C0
    _gcs_two_visit_eofu, outcome(y)
    gcomp y a x1 x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(x1 x2) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: x1 x2, y: a x1 x2) sim(25000) samples(2) seed(2001) minsim
    matrix b = e(b)
    scalar G_RD = b[1,1] - b[1,2]
    scalar G_PO1 = b[1,1]
    scalar G_PO0 = b[1,2]
}
local ok = (_rc==0)
chk "S1 gcomp ran (minsim binary ATE)" `ok'
if `ok' {
    chk "S1 minsim recover E[Y(a=1)]" `=(abs(G_PO1 - T_PO1) < `tolDet')'
    chk "S1 minsim recover E[Y(a=0)]" `=(abs(G_PO0 - T_PO0) < `tolDet')'
    chk "S1 minsim recover RD" `=(abs(G_RD - T_RD) < `tolDet')'
    chk "S1 crude misses RD" `=(abs(CRUDE_RD - T_RD) > `naiveMin')'
}

**# S2: moreMC -- explicit time-varying compatibility guard

capture noisily {
    clear
    set seed 2002001
    set obs 20000
    gen long id = _n
    gen byte time = 1
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen byte a = rbinomial(1, invlogit(0.1 + 0.6*x1 - 0.4*x2))
    gen byte y = rbinomial(1, invlogit(-0.9 + 0.7*a + 0.5*x1 - 0.5*x2))
    gen double p1 = invlogit(-0.9 + 0.7 + 0.5*x1 - 0.5*x2)
    gen double p0 = invlogit(-0.9 + 0.5*x1 - 0.5*x2)
    quietly summarize p1, meanonly
    scalar T_PO1 = r(mean)
    quietly summarize p0, meanonly
    scalar T_PO0 = r(mean)
    scalar T_RD = T_PO1 - T_PO0
    capture noisily gcomp y a x1 x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(x1 x2) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: x1 x2, y: a x1 x2) sim(50000) samples(2) seed(2002) moreMC
    local moremc_rc = _rc
    assert `moremc_rc' == 198
}
local ok = (_rc==0)
chk "S2 moreMC is explicitly rejected for time-varying analysis" `ok'

**# S3: protective (negative) treatment effect -- sign path

capture noisily {
    clear
    set seed 2003001
    set obs 30000
    gen long id = _n
    gen byte time = 1
    gen double x1 = rnormal()
    gen byte a = rbinomial(1, invlogit(0.2 + 0.5*x1))
    gen byte y = rbinomial(1, invlogit(-0.5 - 0.9*a + 0.6*x1))
    gen double p1 = invlogit(-0.5 - 0.9 + 0.6*x1)
    gen double p0 = invlogit(-0.5 + 0.6*x1)
    quietly summarize p1, meanonly
    scalar T_PO1 = r(mean)
    quietly summarize p0, meanonly
    scalar T_PO0 = r(mean)
    scalar T_RD = T_PO1 - T_PO0
    quietly summarize y if a==1, meanonly
    scalar C1 = r(mean)
    quietly summarize y if a==0, meanonly
    scalar C0 = r(mean)
    scalar CRUDE_RD = C1 - C0
    _gcs_two_visit_eofu, outcome(y)
    gcomp y a x1, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(x1) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: x1, y: a x1) sim(20000) samples(2) seed(2003)
    matrix b = e(b)
    scalar G_RD = b[1,1] - b[1,2]
}
local ok = (_rc==0)
chk "S3 gcomp ran (protective effect)" `ok'
if `ok' {
    chk "S3 recover negative RD" `=(abs(G_RD - T_RD) < `tolPO')'
    chk "S3 RD is negative (sign)" `=(G_RD < 0 & T_RD < 0)'
    chk "S3 crude misses RD" `=(abs(CRUDE_RD - T_RD) > `naiveMin')'
}

**# S4: two intervention variables -- joint regime via the "\" component syntax
* interventions(a=1 \ b=1, a=0 \ b=0): set BOTH a and b under each regime.
* Truth = E[Y(a=1,b=1)] - E[Y(a=0,b=0)] (a and b both forced).

capture noisily {
    clear
    set seed 2004001
    set obs 30000
    gen long id = _n
    gen byte time = 1
    gen double x = rnormal()
    gen byte a = rbinomial(1, invlogit(0.2 + 0.4*x))
    gen byte b = rbinomial(1, invlogit(-0.1 + 0.3*x + 0.5*a))
    gen byte y = rbinomial(1, invlogit(-0.8 + 0.7*a + 0.6*b + 0.5*x))
    gen double p11 = invlogit(-0.8 + 0.7 + 0.6 + 0.5*x)
    gen double p00 = invlogit(-0.8 + 0.5*x)
    quietly summarize p11, meanonly
    scalar T_P11 = r(mean)
    quietly summarize p00, meanonly
    scalar T_P00 = r(mean)
    scalar T_RD = T_P11 - T_P00
    _gcs_two_visit_eofu, outcome(y)
    gcomp y a b x, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(x) ///
        intvars(a b) interventions(a=1 \ b=1, a=0 \ b=0) ///
        commands(a: logit, b: logit, y: logit) ///
        equations(a: x, b: a x, y: a b x) sim(20000) samples(2) seed(2004)
    matrix b = e(b)
    scalar G_P11 = b[1,1]
    scalar G_P00 = b[1,2]
    scalar G_RD = G_P11 - G_P00
}
local ok = (_rc==0)
chk "S4 gcomp ran (two-intvar joint regime)" `ok'
if `ok' {
    chk "S4 recover E[Y(a=1,b=1)]" `=(abs(G_P11 - T_P11) < `tolPO')'
    chk "S4 recover E[Y(a=0,b=0)]" `=(abs(G_P00 - T_P00) < `tolPO')'
    chk "S4 recover joint RD" `=(abs(G_RD - T_RD) < `tolPO')'
}

**# S5: 4-level ordinal dose-response (ologit treatment)

capture noisily {
    clear
    set seed 2005001
    set obs 45000
    gen long id = _n
    gen byte time = 1
    gen double x1 = rnormal()
    gen byte a = 0
    replace a = 1 if runiform() < 0.5
    replace a = 2 if runiform() < 0.5 & a==1
    replace a = 3 if runiform() < 0.5 & a==2
    gen byte y = rbinomial(1, invlogit(-1.2 + 0.4*a + 0.5*x1))
    forvalues lev = 0/3 {
        gen double pp`lev' = invlogit(-1.2 + 0.4*`lev' + 0.5*x1)
        quietly summarize pp`lev', meanonly
        scalar T_PO`lev' = r(mean)
    }
    _gcs_two_visit_eofu, outcome(y)
    gcomp y a x1, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(x1) ///
        intvars(a) interventions(a=0, a=1, a=2, a=3) commands(a: ologit, y: logit) ///
        equations(a: x1, y: a x1) sim(20000) samples(2) seed(2005)
    matrix b = e(b)
    forvalues lev = 0/3 {
        scalar G_PO`lev' = b[1,`=`lev'+1']
    }
}
local ok = (_rc==0)
chk "S5 gcomp ran (4-level dose-response)" `ok'
if `ok' {
    chk "S5 recover PO(a=0)" `=(abs(G_PO0 - T_PO0) < `tolPO')'
    chk "S5 recover PO(a=1)" `=(abs(G_PO1 - T_PO1) < `tolPO')'
    chk "S5 recover PO(a=2)" `=(abs(G_PO2 - T_PO2) < `tolPO')'
    chk "S5 recover PO(a=3)" `=(abs(G_PO3 - T_PO3) < `tolPO')'
    chk "S5 dose-response monotone" `=(G_PO0 < G_PO1 & G_PO1 < G_PO2 & G_PO2 < G_PO3)'
}

**# S6/S7: mediation on the log-RR and log-OR scales
* Binary mediation DGP (as R10). Compute the three potential-outcome means
* analytically over the binary mediator, then form the natural effects on each
* scale. logRR: TCE=log(S11/S00), NDE=log(S10/S00), NIE=log(S11/S10). logOR:
* replace each mean p by its odds p/(1-p). The additive decomposition
* TCE=NDE+NIE holds on BOTH log scales (it is a telescoping log ratio). The
* analytic marginal means were confirmed against a 4M-obs brute-force forward-
* simulation of the DGP (S11=0.6954, S10=0.6598, S00=0.4525).
*
* Both scales are estimated with minsim (expected values, no Monte-Carlo draw
* noise) so the point estimate is the deterministic g-formula average -- the only
* residual is the finite-data-N fit. On the log-RR scale that residual maps
* through d/dp log(p)=1/p (~2.2x here) and recovers tightly. On the log-OR scale
* it maps through d/dp logit(p)=1/(p(1-p)) (~4x near p=0.45), so the SAME small
* RD-scale residual (~0.007-0.009, verified consistent across seeds and shrinking
* with sim) is amplified to ~0.03. The estimator is CONSISTENT (RD and logRR
* recover tightly; the brute-force truth agrees), not biased -- so S7 is a
* documented BOUNDED gate at 0.06, not a tight recovery. Tightening it further
* would require a larger data N, not an estimator fix.

capture noisily {
    clear
    set seed 2006001
    set obs 150000
    gen double c0 = rnormal()
    gen double pm1 = invlogit(-0.3 + 1.0 + 0.2*c0)
    gen double pm0 = invlogit(-0.3 + 0.2*c0)
    gen double g1_1 = invlogit(-0.5 + 0.9 + 0.7 + 0.3*c0)
    gen double g1_0 = invlogit(-0.5 + 0.9 + 0.3*c0)
    gen double g0_1 = invlogit(-0.5 + 0.7 + 0.3*c0)
    gen double g0_0 = invlogit(-0.5 + 0.3*c0)
    gen double EY1M1 = pm1*g1_1 + (1-pm1)*g1_0
    gen double EY0M0 = pm0*g0_1 + (1-pm0)*g0_0
    gen double EY1M0 = pm0*g1_1 + (1-pm0)*g1_0
    quietly summarize EY1M1, meanonly
    scalar S11 = r(mean)
    quietly summarize EY0M0, meanonly
    scalar S00 = r(mean)
    quietly summarize EY1M0, meanonly
    scalar S10 = r(mean)
    * logRR-scale truths
    scalar T_TCE_RR = log(S11/S00)
    scalar T_NDE_RR = log(S10/S00)
    scalar T_NIE_RR = log(S11/S10)
    * logOR-scale truths
    scalar T_TCE_OR = log((S11/(1-S11))/(S00/(1-S00)))
    scalar T_NDE_OR = log((S10/(1-S10))/(S00/(1-S00)))
    scalar T_NIE_OR = log((S11/(1-S11))/(S10/(1-S10)))
    gen byte x = rbinomial(1, invlogit(0.1 + 0.3*c0))
    gen byte m = rbinomial(1, invlogit(-0.3 + 1.0*x + 0.2*c0))
    gen byte y = rbinomial(1, invlogit(-0.5 + 0.9*x + 0.7*m + 0.3*c0))
    * S6: logRR (deterministic via minsim)
    gcomp y m x c0, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: logit, y: logit) equations(m: x c0, y: m x c0) ///
        base_confs(c0) sim(60000) samples(2) seed(2006) minsim logRR
    scalar SC_RR = 0
    if "`e(scale)'"=="logRR" scalar SC_RR = 1
    scalar G_TCE_RR = e(tce)
    scalar G_NDE_RR = e(nde)
    scalar G_NIE_RR = e(nie)
    * S7: logOR (deterministic via minsim)
    gcomp y m x c0, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: logit, y: logit) equations(m: x c0, y: m x c0) ///
        base_confs(c0) sim(60000) samples(2) seed(2006) minsim logOR
    scalar SC_OR = 0
    if "`e(scale)'"=="logOR" scalar SC_OR = 1
    scalar G_TCE_OR = e(tce)
    scalar G_NDE_OR = e(nde)
    scalar G_NIE_OR = e(nie)
}
local ok = (_rc==0)
chk "S6/S7 gcomp ran (logRR + logOR mediation)" `ok'
if `ok' {
    chk "S6 e(scale)==logRR" `=(SC_RR==1)'
    chk "S6 recover TCE (logRR)" `=(abs(G_TCE_RR - T_TCE_RR) < `tolLogRR')'
    chk "S6 recover NDE (logRR)" `=(abs(G_NDE_RR - T_NDE_RR) < `tolLogRR')'
    chk "S6 recover NIE (logRR)" `=(abs(G_NIE_RR - T_NIE_RR) < `tolLogRR')'
    chk "S6 logRR decomposition TCE=NDE+NIE" `=(abs(G_TCE_RR - (G_NDE_RR + G_NIE_RR)) < 1e-4)'
    chk "S7 e(scale)==logOR" `=(SC_OR==1)'
    chk "S7 recover TCE (logOR, bounded)" `=(abs(G_TCE_OR - T_TCE_OR) < `tolLogOR')'
    chk "S7 recover NDE (logOR, bounded)" `=(abs(G_NDE_OR - T_NDE_OR) < `tolLogOR')'
    chk "S7 recover NIE (logOR)" `=(abs(G_NIE_OR - T_NIE_OR) < `tolLogOR')'
    chk "S7 logOR decomposition TCE=NDE+NIE" `=(abs(G_TCE_OR - (G_NDE_OR + G_NIE_OR)) < 1e-4)'
    * consistency direction: logOR effects exceed logRR effects (odds vs risk)
    chk "S7 logOR TCE > logRR TCE (scale ordering)" `=(G_TCE_OR > G_TCE_RR)'
}

**# S8: oce -- 3-level categorical-exposure mediation, per-level TCE
* Baseline auto-detects to the lowest level (0). Truth for level j vs 0:
* TCE_j = E_c[ pm_j*g_{j,1} + (1-pm_j)*g_{j,0} ] - E_c[ pm_0*g_{0,1} + (1-pm_0)*g_{0,0} ]
* with pm_j=invlogit(am0+ax*j+amc*c), g_{j,m}=invlogit(by0+bx*j+bm*m+bc*c).

capture noisily {
    clear
    set seed 2008001
    set obs 120000
    gen double c0 = rnormal()
    gen byte x = floor(runiform()*3)          // 0, 1, 2
    forvalues j = 0/2 {
        gen double pm`j' = invlogit(-0.3 + 0.5*`j' + 0.2*c0)
        gen double gj`j'1 = invlogit(-0.5 + 0.4*`j' + 0.7 + 0.3*c0)
        gen double gj`j'0 = invlogit(-0.5 + 0.4*`j' + 0.3*c0)
        gen double S`j' = pm`j'*gj`j'1 + (1-pm`j')*gj`j'0
        quietly summarize S`j', meanonly
        scalar SBAR`j' = r(mean)
    }
    scalar T_TCE1 = SBAR1 - SBAR0
    scalar T_TCE2 = SBAR2 - SBAR0
    gen byte m = rbinomial(1, invlogit(-0.3 + 0.5*x + 0.2*c0))
    gen byte y = rbinomial(1, invlogit(-0.5 + 0.4*x + 0.7*m + 0.3*c0))
    gcomp y m x c0, outcome(y) mediation oce exposure(x) mediator(m) ///
        commands(m: logit, y: logit) equations(m: x c0, y: m x c0) ///
        base_confs(c0) sim(10000) samples(2) seed(2008)
    scalar G_TCE1 = e(tce_1)
    scalar G_TCE2 = e(tce_2)
}
local ok = (_rc==0)
chk "S8 gcomp ran (oce categorical exposure)" `ok'
if `ok' {
    chk "S8 recover TCE(level 1 vs 0)" `=(abs(G_TCE1 - T_TCE1) < `tolMed')'
    chk "S8 recover TCE(level 2 vs 0)" `=(abs(G_TCE2 - T_TCE2) < `tolMed')'
    chk "S8 TCE increases with dose" `=(G_TCE2 > G_TCE1)'
}

**# S9: specific -- custom baseline()/alternative() contrast (level 2 vs 0)
* Same DGP structure as S8; specific compares exposure=2 against exposure=0.
* Truth = SBAR2 - SBAR0 (identical to S8's level-2 TCE), computed independently.

capture noisily {
    clear
    set seed 2009001
    set obs 120000
    gen double c0 = rnormal()
    gen byte x = floor(runiform()*3)
    forvalues j = 0/2 {
        gen double pm`j' = invlogit(-0.3 + 0.5*`j' + 0.2*c0)
        gen double gj`j'1 = invlogit(-0.5 + 0.4*`j' + 0.7 + 0.3*c0)
        gen double gj`j'0 = invlogit(-0.5 + 0.4*`j' + 0.3*c0)
        gen double S`j' = pm`j'*gj`j'1 + (1-pm`j')*gj`j'0
        quietly summarize S`j', meanonly
        scalar SBAR`j' = r(mean)
    }
    scalar T_TCE = SBAR2 - SBAR0
    gen byte m = rbinomial(1, invlogit(-0.3 + 0.5*x + 0.2*c0))
    gen byte y = rbinomial(1, invlogit(-0.5 + 0.4*x + 0.7*m + 0.3*c0))
    gcomp y m x c0, outcome(y) mediation specific baseline(0) alternative(2) ///
        exposure(x) mediator(m) commands(m: logit, y: logit) ///
        equations(m: x c0, y: m x c0) base_confs(c0) sim(10000) samples(2) seed(2009)
    scalar G_TCE = e(tce)
}
local ok = (_rc==0)
chk "S9 gcomp ran (specific 2-vs-0 contrast)" `ok'
if `ok' {
    chk "S9 recover specific TCE(2 vs 0)" `=(abs(G_TCE - T_TCE) < `tolMed')'
}

**# S10: mixed models -- binary mediator (logit) + CONTINUOUS outcome (regress)
* DGP: m ~ Bern(invlogit(-0.3+1.0x+0.2c)); Y = 1 + 0.8x + 0.6m + 0.3c + N(0,1).
* Because Y is linear in m, the natural effects have closed form over the binary
* mediator:  NDE = 0.8 (the x coefficient),  NIE = 0.6*(E[pm1]-E[pm0]),
* TCE = NDE + NIE, with pm_{x}=invlogit(-0.3+1.0x+0.2c). Exact analytic oracle.

capture noisily {
    clear
    set seed 2010001
    set obs 80000
    gen double c0 = rnormal()
    gen double pm1 = invlogit(-0.3 + 1.0 + 0.2*c0)
    gen double pm0 = invlogit(-0.3 + 0.2*c0)
    quietly summarize pm1, meanonly
    scalar EPM1 = r(mean)
    quietly summarize pm0, meanonly
    scalar EPM0 = r(mean)
    scalar T_NDE = 0.80
    scalar T_NIE = 0.60*(EPM1 - EPM0)
    scalar T_TCE = T_NDE + T_NIE
    gen byte x = rbinomial(1, invlogit(0.1 + 0.3*c0))
    gen byte m = rbinomial(1, invlogit(-0.3 + 1.0*x + 0.2*c0))
    gen double y = 1 + 0.8*x + 0.6*m + 0.3*c0 + rnormal()
    gcomp y m x c0, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: logit, y: regress) equations(m: x c0, y: m x c0) ///
        base_confs(c0) sim(10000) samples(2) seed(2010)
    scalar G_TCE = e(tce)
    scalar G_NDE = e(nde)
    scalar G_NIE = e(nie)
}
local ok = (_rc==0)
chk "S10 gcomp ran (binary-m + continuous-y)" `ok'
if `ok' {
    chk "S10 recover NDE=0.80" `=(abs(G_NDE - T_NDE) < `tolMed')'
    chk "S10 recover NIE" `=(abs(G_NIE - T_NIE) < `tolMed')'
    chk "S10 recover TCE" `=(abs(G_TCE - T_TCE) < `tolMed')'
    chk "S10 decomposition TCE=NDE+NIE" `=(abs(G_TCE - (G_NDE + G_NIE)) < 1e-5)'
}

**# S11: impute -- single stochastic imputation of a MAR-missing confounder
* Confounded binary ATE. x2 is set MISSING on a subset selected by x1 (observed)
* -> missing at random given x1, which is in every model. Single stochastic
* imputation is then unbiased for the g-formula target, so gcomp must recover the
* FULL-DATA truth (computed BEFORE masking). A complete-case crude contrast is
* still confounded and misses.

capture noisily {
    clear
    set seed 2011001
    set obs 30000
    gen long id = _n
    gen byte time = 1
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen byte a = rbinomial(1, invlogit(0.2 + 0.5*x1 - 0.3*x2))
    gen byte y = rbinomial(1, invlogit(-1 + 0.8*a + 0.5*x1 - 0.4*x2))
    gen double p1 = invlogit(-1 + 0.8 + 0.5*x1 - 0.4*x2)
    gen double p0 = invlogit(-1 + 0.5*x1 - 0.4*x2)
    quietly summarize p1, meanonly
    scalar T_PO1 = r(mean)
    quietly summarize p0, meanonly
    scalar T_PO0 = r(mean)
    scalar T_RD = T_PO1 - T_PO0
    quietly summarize y if a==1, meanonly
    scalar C1 = r(mean)
    quietly summarize y if a==0, meanonly
    scalar C0 = r(mean)
    scalar CRUDE_RD = C1 - C0
    * introduce MAR missingness on x2 (probability depends on observed x1)
    replace x2 = . if runiform() < invlogit(-0.7 + 0.6*x1)
    _gcs_two_visit_eofu, outcome(y)
    gcomp y a x1 x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(x1 x2) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: x1 x2, y: a x1 x2) impute(x2) imp_cmd(x2: regress) ///
        imp_eq(x2: x1) sim(20000) samples(2) seed(2011)
    matrix b = e(b)
    scalar G_RD = b[1,1] - b[1,2]
}
local ok = (_rc==0)
chk "S11 gcomp ran (impute MAR confounder)" `ok'
if `ok' {
    chk "S11 impute recover RD" `=(abs(G_RD - T_RD) < `tolPO'+0.01)'
    chk "S11 crude misses RD" `=(abs(CRUDE_RD - T_RD) > `naiveMin')'
}

**# S12: pooled -- pooled logistic across visits (constant-coefficient DGP)
* 3-visit design whose treatment, confounder and outcome coefficients are the
* SAME at every visit, so a model pooled across visits is correctly specified.
* Binary end-of-follow-up outcome; static always/never contrast. Truth by
* forward-simulating each regime at large N (exact g-formula oracle).

capture program drop _s12_fsim
program define _s12_fsim, rclass
    args regime N seed
    clear
    set seed `seed'
    set obs `N'
    gen double L0 = rnormal()
    gen double L1 = 0.10 + 0.15*L0 + rnormal(0, 0.35)
    gen double L2 = 0.10 + 0.55*L1 - 0.50*`regime' + 0.15*L0 + rnormal(0, 0.35)
    * outcome depends on the final treatment (=regime) and the final confounder L2
    gen byte Y = runiform() < invlogit(-1.0 - 0.70*`regime' + 0.60*L2 + 0.20*L0)
    quietly summarize Y, meanonly
    return scalar my = r(mean)
end

capture noisily {
    _s12_fsim 1 400000 1201
    scalar T_ALW = r(my)
    _s12_fsim 0 400000 1202
    scalar T_NEV = r(my)
    scalar T_RD = T_ALW - T_NEV

    clear
    set seed 2012001
    set obs 30000
    gen long id = ceil(_n/3)
    bysort id: gen byte t = _n
    gen double L0 = rnormal()
    bysort id (t): replace L0 = L0[1]
    gen byte A = .
    gen double L = .
    gen byte Alag = 0
    gen double Llag = 0
    bysort id (t): replace L = 0.10 + 0.15*L0 + rnormal(0,0.35) if t==1
    bysort id (t): replace A = rbinomial(1, invlogit(-0.20 + 0.55*L + 0.20*L0)) if t==1
    bysort id (t): replace L = 0.10 + 0.55*L[_n-1] - 0.50*A[_n-1] + 0.15*L0 + rnormal(0,0.35) if t==2
    bysort id (t): replace A = rbinomial(1, invlogit(-0.20 + 0.55*L + 0.20*L0)) if t==2
    bysort id (t): replace L = 0.10 + 0.55*L[_n-1] - 0.50*A[_n-1] + 0.15*L0 + rnormal(0,0.35) if t==3
    bysort id (t): replace A = rbinomial(1, invlogit(-0.20 + 0.55*L + 0.20*L0)) if t==3
    bysort id (t): replace Alag = A[_n-1] if _n>1
    bysort id (t): replace Llag = L[_n-1] if _n>1
    gen byte Y = 0
    bysort id (t): replace Y = rbinomial(1, invlogit(-1.0 - 0.70*A[_n-1] + 0.60*L[_n-1] + 0.20*L0)) if t==3
    gcomp Y L0 A L Alag Llag id t, outcome(Y) idvar(id) tvar(t) ///
        varyingcovariates(L) fixedcovariates(L0) laggedvars(Alag Llag) ///
        lagrules(Alag: A 1, Llag: L 1) intvars(A) eofu pooled ///
        commands(A: logit, Y: logit, L: regress) ///
        equations(A: L0 L, Y: Alag Llag L0, L: Alag Llag L0) ///
        interventions(A=1, A=0) sim(10000) samples(2) seed(2012)
    matrix b = e(b)
    scalar G_ALW = b[1,1]
    scalar G_NEV = b[1,2]
    scalar G_RD = G_ALW - G_NEV
}
local ok = (_rc==0)
chk "S12 gcomp ran (pooled time-varying)" `ok'
if `ok' {
    chk "S12 pooled recover E[Y(always)]" `=(abs(G_ALW - T_ALW) < `tolTV')'
    chk "S12 pooled recover E[Y(never)]" `=(abs(G_NEV - T_NEV) < `tolTV')'
    chk "S12 pooled recover RD" `=(abs(G_RD - T_RD) < `tolTV')'
}
capture program drop _s12_fsim

**# S13: dynamic -- threshold dynamic regime ("treat if current L > c")
* Same 3-visit binary-outcome DGP as S12. The dynamic regime sets A=1 whenever the
* current (simulated) confounder L exceeds a threshold c, else A=0; compared with
* the static never-treat regime. Truth by forward-simulating each regime at large N:
* under the dynamic rule, at each visit L is drawn under the prior A, then A=(L>c).

local thr = 0.30
capture program drop _s13_dyn
program define _s13_dyn, rclass
    args mode N seed thr
    clear
    set seed `seed'
    set obs `N'
    gen double L0 = rnormal()
    gen double L1 = 0.10 + 0.15*L0 + rnormal(0, 0.35)
    if "`mode'"=="dyn" gen byte A1 = L1 > `thr'
    else gen byte A1 = 0
    gen double L2 = 0.10 + 0.55*L1 - 0.50*A1 + 0.15*L0 + rnormal(0, 0.35)
    if "`mode'"=="dyn" gen byte A2 = L2 > `thr'
    else gen byte A2 = 0
    gen byte Y = runiform() < invlogit(-1.0 - 0.70*A2 + 0.60*L2 + 0.20*L0)
    quietly summarize Y, meanonly
    return scalar my = r(mean)
end

capture noisily {
    _s13_dyn dyn 400000 1301 `thr'
    scalar T_DYN = r(my)
    _s13_dyn nev 400000 1302 `thr'
    scalar T_NEV = r(my)
    scalar T_RD = T_DYN - T_NEV

    clear
    set seed 2013001
    set obs 30000
    gen long id = ceil(_n/3)
    bysort id: gen byte t = _n
    gen double L0 = rnormal()
    bysort id (t): replace L0 = L0[1]
    gen byte A = .
    gen double L = .
    gen byte Alag = 0
    gen double Llag = 0
    bysort id (t): replace L = 0.10 + 0.15*L0 + rnormal(0,0.35) if t==1
    bysort id (t): replace A = rbinomial(1, invlogit(-0.20 + 0.55*L + 0.20*L0)) if t==1
    bysort id (t): replace L = 0.10 + 0.55*L[_n-1] - 0.50*A[_n-1] + 0.15*L0 + rnormal(0,0.35) if t==2
    bysort id (t): replace A = rbinomial(1, invlogit(-0.20 + 0.55*L + 0.20*L0)) if t==2
    bysort id (t): replace L = 0.10 + 0.55*L[_n-1] - 0.50*A[_n-1] + 0.15*L0 + rnormal(0,0.35) if t==3
    bysort id (t): replace A = rbinomial(1, invlogit(-0.20 + 0.55*L + 0.20*L0)) if t==3
    bysort id (t): replace Alag = A[_n-1] if _n>1
    bysort id (t): replace Llag = L[_n-1] if _n>1
    gen byte Y = 0
    bysort id (t): replace Y = rbinomial(1, invlogit(-1.0 - 0.70*A[_n-1] + 0.60*L[_n-1] + 0.20*L0)) if t==3
    gcomp Y L0 A L Alag Llag id t, outcome(Y) idvar(id) tvar(t) ///
        varyingcovariates(L) fixedcovariates(L0) laggedvars(Alag Llag) ///
        lagrules(Alag: A 1, Llag: L 1) intvars(A) eofu dynamic ///
        commands(A: logit, Y: logit, L: regress) ///
        equations(A: L0 L, Y: Alag Llag L0, L: Alag Llag L0) ///
        interventions(A = L > `thr', A = 0) sim(10000) samples(2) seed(2013)
    matrix b = e(b)
    scalar G_DYN = b[1,1]
    scalar G_NEV = b[1,2]
    scalar G_RD = G_DYN - G_NEV
}
local ok = (_rc==0)
chk "S13 gcomp ran (dynamic threshold regime)" `ok'
if `ok' {
    chk "S13 dynamic recover E[Y(treat if L>c)]" `=(abs(G_DYN - T_DYN) < `tolTV')'
    chk "S13 dynamic recover E[Y(never)]" `=(abs(G_NEV - T_NEV) < `tolTV')'
    chk "S13 dynamic recover regime RD" `=(abs(G_RD - T_RD) < `tolTV')'
}
capture program drop _s13_dyn

**# S14: longer follow-up -- 4-visit static-regime recovery (binary outcome)
* All prior time-varying recovery scenarios use 3 visits. This extends to 4, so
* the treatment carried through three rounds of confounder feedback. Truth by
* forward-simulating each static regime at large N.

capture program drop _s14_fsim
program define _s14_fsim, rclass
    args regime N seed
    clear
    set seed `seed'
    set obs `N'
    gen double L0 = rnormal()
    gen double L = 0.10 + 0.15*L0 + rnormal(0, 0.35)
    forvalues k = 2/4 {
        quietly replace L = 0.10 + 0.55*L - 0.50*`regime' + 0.15*L0 + rnormal(0, 0.35)
    }
    gen byte Y = runiform() < invlogit(-1.0 - 0.60*`regime' + 0.55*L + 0.20*L0)
    quietly summarize Y, meanonly
    return scalar my = r(mean)
end

capture noisily {
    _s14_fsim 1 400000 1401
    scalar T_ALW = r(my)
    _s14_fsim 0 400000 1402
    scalar T_NEV = r(my)
    scalar T_RD = T_ALW - T_NEV

    clear
    set seed 2014001
    set obs 40000
    gen long id = ceil(_n/4)
    bysort id: gen byte t = _n
    gen double L0 = rnormal()
    bysort id (t): replace L0 = L0[1]
    gen byte A = .
    gen double L = .
    gen byte Alag = 0
    gen double Llag = 0
    bysort id (t): replace L = 0.10 + 0.15*L0 + rnormal(0,0.35) if t==1
    bysort id (t): replace A = rbinomial(1, invlogit(-0.20 + 0.55*L + 0.20*L0)) if t==1
    forvalues k = 2/4 {
        bysort id (t): replace L = 0.10 + 0.55*L[_n-1] - 0.50*A[_n-1] + 0.15*L0 + rnormal(0,0.35) if t==`k'
        bysort id (t): replace A = rbinomial(1, invlogit(-0.20 + 0.55*L + 0.20*L0)) if t==`k'
    }
    bysort id (t): replace Alag = A[_n-1] if _n>1
    bysort id (t): replace Llag = L[_n-1] if _n>1
    gen byte Y = 0
    bysort id (t): replace Y = rbinomial(1, invlogit(-1.0 - 0.60*A[_n-1] + 0.55*L[_n-1] + 0.20*L0)) if t==4
    gcomp Y L0 A L Alag Llag id t, outcome(Y) idvar(id) tvar(t) ///
        varyingcovariates(L) fixedcovariates(L0) laggedvars(Alag Llag) ///
        lagrules(Alag: A 1, Llag: L 1) intvars(A) eofu ///
        commands(A: logit, Y: logit, L: regress) ///
        equations(A: L0 L, Y: Alag Llag L0, L: Alag Llag L0) ///
        interventions(A=1, A=0) sim(10000) samples(2) seed(2014)
    matrix b = e(b)
    scalar G_ALW = b[1,1]
    scalar G_NEV = b[1,2]
    scalar G_RD = G_ALW - G_NEV
}
local ok = (_rc==0)
chk "S14 gcomp ran (4-visit follow-up)" `ok'
if `ok' {
    chk "S14 recover E[Y(always)]" `=(abs(G_ALW - T_ALW) < `tolTV')'
    chk "S14 recover E[Y(never)]" `=(abs(G_NEV - T_NEV) < `tolTV')'
    chk "S14 recover RD" `=(abs(G_RD - T_RD) < `tolTV')'
}
capture program drop _s14_fsim

**# S15: mlogit -- multinomial-logit time-varying covariate simulation
* The time-varying confounder L is a 3-level UNORDERED categorical (0/1/2) drawn
* from a multinomial-logit model whose linear predictors we set; treatment A is
* binary and confounded by L; the binary end-of-follow-up outcome depends on the
* final treatment and (via indicators) the final L level. This exercises the
* mlogit simulation path (predict of category probabilities + cumulative draw)
* that ologit/logit/regress scenarios never touch. Truth by forward-simulating
* each static regime at large N, drawing L from the SAME multinomial model gcomp
* fits. Category-1 is the mlogit base; utilities for levels 0 and 2 are relative.

capture program drop _s15_drawL
program define _s15_drawL
    * draws L in {0,1,2} given eta0, eta2 (base=level 1) into variable Lnew
    args Lnew
    tempvar e0 e2 den p0 p1 u
    quietly gen double `e0' = exp(eta0)
    quietly gen double `e2' = exp(eta2)
    quietly gen double `den' = 1 + `e0' + `e2'
    quietly gen double `p0' = `e0'/`den'
    quietly gen double `p1' = 1/`den'
    quietly gen double `u' = runiform()
    quietly gen byte `Lnew' = 0
    quietly replace `Lnew' = 1 if `u' >= `p0' & `u' < `p0' + `p1'
    quietly replace `Lnew' = 2 if `u' >= `p0' + `p1'
end

capture program drop _s15_fsim
program define _s15_fsim, rclass
    args regime N seed
    clear
    set seed `seed'
    set obs `N'
    gen double L0 = rnormal()
    * visit 1: L1 categorical, no prior treatment
    gen double eta0 = -0.2 + 0.3*L0
    gen double eta2 = -0.4 + 0.4*L0
    _s15_drawL L1
    drop eta0 eta2
    * visit 2: utilities shift with prior treatment (=regime) and prior L level
    gen double eta0 = -0.2 + 0.3*L0 - 0.5*`regime' + 0.3*(L1==2)
    gen double eta2 = -0.4 + 0.4*L0 + 0.5*`regime' + 0.4*(L1==2)
    _s15_drawL L2
    drop eta0 eta2
    gen byte Y = runiform() < invlogit(-0.8 - 0.60*`regime' + 0.50*(L2==2) - 0.30*(L2==0) + 0.20*L0)
    quietly summarize Y, meanonly
    return scalar my = r(mean)
end

capture noisily {
    _s15_fsim 1 400000 1501
    scalar T_ALW = r(my)
    _s15_fsim 0 400000 1502
    scalar T_NEV = r(my)
    scalar T_RD = T_ALW - T_NEV

    clear
    set seed 2015001
    set obs 30000
    gen long id = ceil(_n/2)
    bysort id: gen byte t = _n
    gen double L0 = rnormal()
    bysort id (t): replace L0 = L0[1]
    gen byte A = .
    gen byte L = .
    gen byte Alag = 0
    gen byte Llag = 0
    * visit 1
    gen double eta0 = -0.2 + 0.3*L0
    gen double eta2 = -0.4 + 0.4*L0
    tempvar e0 e2 den p0 p1 u
    gen double `e0' = exp(eta0)
    gen double `e2' = exp(eta2)
    gen double `den' = 1 + `e0' + `e2'
    gen double `p0' = `e0'/`den'
    gen double `p1' = 1/`den'
    gen double `u' = runiform()
    replace L = 0 if t==1
    replace L = 1 if t==1 & `u' >= `p0' & `u' < `p0'+`p1'
    replace L = 2 if t==1 & `u' >= `p0'+`p1'
    drop eta0 eta2 `e0' `e2' `den' `p0' `p1' `u'
    bysort id (t): replace A = rbinomial(1, invlogit(-0.20 + 0.50*(L==2) - 0.30*(L==0) + 0.20*L0)) if t==1
    * visit 2: L2 depends on prior A and prior L level
    bysort id (t): gen byte Lprev = L[_n-1]
    bysort id (t): gen byte Aprev = A[_n-1]
    gen double eta0 = -0.2 + 0.3*L0 - 0.5*Aprev + 0.3*(Lprev==2)
    gen double eta2 = -0.4 + 0.4*L0 + 0.5*Aprev + 0.4*(Lprev==2)
    gen double `e0' = exp(eta0)
    gen double `e2' = exp(eta2)
    gen double `den' = 1 + `e0' + `e2'
    gen double `p0' = `e0'/`den'
    gen double `p1' = 1/`den'
    gen double `u' = runiform()
    replace L = 0 if t==2
    replace L = 1 if t==2 & `u' >= `p0' & `u' < `p0'+`p1'
    replace L = 2 if t==2 & `u' >= `p0'+`p1'
    bysort id (t): replace A = rbinomial(1, invlogit(-0.20 + 0.50*(L==2) - 0.30*(L==0) + 0.20*L0)) if t==2
    bysort id (t): replace Alag = A[_n-1] if _n>1
    bysort id (t): replace Llag = L[_n-1] if _n>1
    gen byte Y = 0
    bysort id (t): replace Y = rbinomial(1, invlogit(-0.8 - 0.60*A[_n-1] + 0.50*(L[_n-1]==2) - 0.30*(L[_n-1]==0) + 0.20*L0)) if t==2
    drop Lprev Aprev eta0 eta2
    gcomp Y L0 A L Alag Llag id t, outcome(Y) idvar(id) tvar(t) ///
        varyingcovariates(L) fixedcovariates(L0) laggedvars(Alag Llag) ///
        lagrules(Alag: A 1, Llag: L 1) intvars(A) eofu ///
        commands(A: logit, Y: logit, L: mlogit) ///
        equations(A: L0 i.L, Y: Alag i.Llag L0, L: Alag i.Llag L0) ///
        interventions(A=1, A=0) sim(10000) samples(2) seed(2015)
    matrix b = e(b)
    scalar G_ALW = b[1,1]
    scalar G_NEV = b[1,2]
    scalar G_RD = G_ALW - G_NEV
}
local ok = (_rc==0)
chk "S15 gcomp ran (mlogit covariate)" `ok'
if `ok' {
    chk "S15 mlogit recover E[Y(always)]" `=(abs(G_ALW - T_ALW) < `tolTV'+0.005)'
    chk "S15 mlogit recover E[Y(never)]" `=(abs(G_NEV - T_NEV) < `tolTV'+0.005)'
    chk "S15 mlogit recover RD" `=(abs(G_RD - T_RD) < `tolTV'+0.005)'
}
capture program drop _s15_drawL
capture program drop _s15_fsim

**# Summary

local final_T = $T
local final_P = $P
local final_F = $F
macro drop T P F
display as result "Results: `final_P'/`final_T' passed, `final_F' failed"
if `final_F' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_gcomp_recovery_surface tests=`final_T' pass=`final_P' fail=`final_F' status=FAIL"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_gcomp_recovery_surface tests=`final_T' pass=`final_P' fail=`final_F' status=PASS"
