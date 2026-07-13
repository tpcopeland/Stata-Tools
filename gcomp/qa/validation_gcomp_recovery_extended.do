clear all
set varabbrev off
version 16.0

* validation_gcomp_recovery_extended.do
* ----------------------------------------------------------------------------
* Known-truth parameter recovery across gcomp's estimand surface. For a causal
* estimator the first-class correctness check is "does it return the number I
* built into the data?" -- an exact analytic oracle, because we wrote the DGP.
* This suite complements validation_gcomp_recovery.do (time-varying static
* regime) by exercising the point-treatment / baseline-standardized path, the
* multi-level dose-response path, and the mediation (obe) NDE/NIE/TCE/CDE
* decomposition -- each with the truth computed directly from the DGP, never
* from another estimator.
*
* Oracle construction. Every point-treatment / dose-response truth is the mean
* potential outcome under the TRUE model coefficients evaluated on the same
* covariates the estimator sees (an exact finite-sample g-formula oracle, so the
* only residual is the estimator's Monte-Carlo integration error). Mediation
* natural effects are integrated analytically over the binary mediator (or given
* in closed form for the linear-model case: NIE=a*b, NDE=c', TCE=c'+a*b). Each
* scenario also confirms a NAIVE/confounded estimator MISSES the truth, proving
* the scenario actually exercises the confounding the estimator is meant to fix.
*
* e(b) column convention (intervention mode): column j = potential outcome under
* the j-th interventions() spec, in the order written; the final column is the
* natural course. So interventions(a=1, a=0) -> col1=E[Y(a=1)], col2=E[Y(a=0)].
*
* Tolerances are set from observed gcomp MC error at the sim()/samples() used
* here, not from whatever makes a test pass.
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

* Tolerances (from observed MC error)
local tolPO   = 0.02      // point-treatment potential outcome / RD
local tolCont = 0.03      // continuous-outcome ATE
local tolNull = 0.02      // null-effect RD (must be ~0)
local tolMod  = 0.05      // effect-modification marginal ATE
local tolLog  = 0.06      // derived logRR / logOR
local tolTCE  = 0.04      // mediation total effect
local tolNE   = 0.05      // natural direct / indirect effect
local tolCDE  = 0.04      // controlled direct effect
local naiveMin= 0.03      // crude estimator must miss the truth by > this

**# R1: binary-outcome ATE recovery (logit), moderate confounding

capture noisily {
    clear
    set seed 1001001
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
    scalar CRUDE1 = r(mean)
    quietly summarize y if a==0, meanonly
    scalar CRUDE0 = r(mean)
    scalar CRUDE_RD = CRUDE1 - CRUDE0
    gcomp y a x1 x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(x1 x2) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: x1 x2, y: a x1 x2) sim(20000) samples(2) seed(1001)
    matrix b = e(b)
    scalar G_PO1 = b[1,1]
    scalar G_PO0 = b[1,2]
    scalar G_RD = G_PO1 - G_PO0
}
local ok = (_rc==0)
chk "R1 gcomp ran (binary ATE)" `ok'
if `ok' {
    chk "R1 recover E[Y(a=1)]" `=(abs(G_PO1 - T_PO1) < `tolPO')'
    chk "R1 recover E[Y(a=0)]" `=(abs(G_PO0 - T_PO0) < `tolPO')'
    chk "R1 recover RD" `=(abs(G_RD  - T_RD)  < `tolPO')'
    chk "R1 crude misses RD" `=(abs(CRUDE_RD - T_RD) > `naiveMin')'
    * derived scales from recovered POs
    scalar T_lRR = log(T_PO1/T_PO0)
    scalar G_lRR = log(G_PO1/G_PO0)
    chk "R1 recover marginal logRR" `=(abs(G_lRR - T_lRR) < `tolLog')'
    scalar T_lOR = log((T_PO1/(1-T_PO1))/(T_PO0/(1-T_PO0)))
    scalar G_lOR = log((G_PO1/(1-G_PO1))/(G_PO0/(1-G_PO0)))
    chk "R1 recover marginal logOR" `=(abs(G_lOR - T_lOR) < `tolLog')'
}

**# R2: continuous-outcome ATE recovery (regress); truth = linear coefficient

capture noisily {
    clear
    set seed 1002001
    set obs 30000
    gen long id = _n
    gen byte time = 1
    gen double x1 = rnormal()
    gen byte a = rbinomial(1, invlogit(0.3 + 0.6*x1))
    gen double y = 2 + 1.5*a + 0.8*x1 + rnormal()
    scalar T_ATE = 1.5
    quietly summarize y if a==1, meanonly
    scalar C1 = r(mean)
    quietly summarize y if a==0, meanonly
    scalar C0 = r(mean)
    scalar CRUDE = C1 - C0
    gcomp y a x1, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(x1) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: regress) ///
        equations(a: x1, y: a x1) sim(20000) samples(2) seed(1002)
    matrix b = e(b)
    scalar G_ATE = b[1,1] - b[1,2]
}
local ok = (_rc==0)
chk "R2 gcomp ran (continuous ATE)" `ok'
if `ok' {
    chk "R2 recover ATE=1.5" `=(abs(G_ATE - T_ATE) < `tolCont')'
    chk "R2 crude misses ATE" `=(abs(CRUDE - T_ATE) > `naiveMin')'
}

**# R3: null-effect recovery -- treatment has NO effect, confounder does

capture noisily {
    clear
    set seed 1003001
    set obs 30000
    gen long id = _n
    gen byte time = 1
    gen double x1 = rnormal()
    gen byte a = rbinomial(1, invlogit(0.4 + 0.7*x1))
    gen byte y = rbinomial(1, invlogit(-0.5 + 0*a + 0.6*x1))
    scalar T_RD = 0
    quietly summarize y if a==1, meanonly
    scalar C1 = r(mean)
    quietly summarize y if a==0, meanonly
    scalar C0 = r(mean)
    scalar CRUDE_RD = C1 - C0
    gcomp y a x1, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(x1) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: x1, y: a x1) sim(20000) samples(2) seed(1003)
    matrix b = e(b)
    scalar G_RD = b[1,1] - b[1,2]
}
local ok = (_rc==0)
chk "R3 gcomp ran (null effect)" `ok'
if `ok' {
    chk "R3 recover null RD~0" `=(abs(G_RD) < `tolNull')'
    chk "R3 crude shows spurious RD" `=(abs(CRUDE_RD) > `naiveMin')'
}

**# R4: effect modification (treatment-covariate interaction); marginal ATE.
* The a*x1 interaction is carried as an explicit derived variable ax1 recomputed
* under each intervention via derrules() (gcomp's equations() take variable names,
* not factor-variable notation), so this also exercises the derived()/derrules()
* path. Marginal ATE = E[1.0 + 0.8*x1] over the sample.

capture noisily {
    clear
    set seed 1004001
    set obs 40000
    gen long id = _n
    gen byte time = 1
    gen double x1 = rnormal(0.5, 1)
    gen byte a = rbinomial(1, invlogit(0.2 + 0.5*x1))
    gen double ax1 = a*x1
    gen double y = 1 + 1.0*a + 0.5*x1 + 0.8*ax1 + rnormal()
    quietly summarize x1, meanonly
    scalar T_ATE = 1.0 + 0.8*r(mean)
    gcomp y a x1 ax1, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(x1) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: regress) ///
        derived(ax1) derrules(ax1: a*x1) ///
        equations(a: x1, y: a x1 ax1) sim(20000) samples(2) seed(1004)
    matrix b = e(b)
    scalar G_ATE = b[1,1] - b[1,2]
}
local ok = (_rc==0)
chk "R4 gcomp ran (effect modification)" `ok'
if `ok' {
    chk "R4 recover marginal ATE" `=(abs(G_ATE - T_ATE) < `tolMod')'
}

**# R5: strong confounding -- crude badly biased, gcomp recovers

capture noisily {
    clear
    set seed 1005001
    set obs 30000
    gen long id = _n
    gen byte time = 1
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen byte a = rbinomial(1, invlogit(0.0 + 1.2*x1 - 1.0*x2))
    gen byte y = rbinomial(1, invlogit(-0.8 + 0.6*a + 1.0*x1 - 0.9*x2))
    gen double p1 = invlogit(-0.8 + 0.6 + 1.0*x1 - 0.9*x2)
    gen double p0 = invlogit(-0.8 + 1.0*x1 - 0.9*x2)
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
    gcomp y a x1 x2, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(x1 x2) ///
        intvars(a) interventions(a=1, a=0) commands(a: logit, y: logit) ///
        equations(a: x1 x2, y: a x1 x2) sim(20000) samples(2) seed(1005)
    matrix b = e(b)
    scalar G_RD = b[1,1] - b[1,2]
}
local ok = (_rc==0)
chk "R5 gcomp ran (strong confounding)" `ok'
if `ok' {
    chk "R5 recover RD" `=(abs(G_RD - T_RD) < `tolPO')'
    chk "R5 crude misses RD" `=(abs(CRUDE_RD - T_RD) > `naiveMin')'
}

**# R6: multiple baseline confounders (4 covariates)

capture noisily {
    clear
    set seed 1006001
    set obs 30000
    gen long id = _n
    gen byte time = 1
    forvalues k = 1/4 {
        gen double x`k' = rnormal()
    }
    gen byte a = rbinomial(1, invlogit(0.1 + 0.4*x1 - 0.3*x2 + 0.2*x3 - 0.25*x4))
    gen byte y = rbinomial(1, invlogit(-0.7 + 0.7*a + 0.4*x1 - 0.3*x2 + 0.3*x3 - 0.2*x4))
    gen double p1 = invlogit(-0.7 + 0.7 + 0.4*x1 - 0.3*x2 + 0.3*x3 - 0.2*x4)
    gen double p0 = invlogit(-0.7 + 0.4*x1 - 0.3*x2 + 0.3*x3 - 0.2*x4)
    quietly summarize p1, meanonly
    scalar T_PO1 = r(mean)
    quietly summarize p0, meanonly
    scalar T_PO0 = r(mean)
    scalar T_RD = T_PO1 - T_PO0
    gcomp y a x1 x2 x3 x4, outcome(y) idvar(id) tvar(time) eofu ///
        fixedcovariates(x1 x2 x3 x4) intvars(a) interventions(a=1, a=0) ///
        commands(a: logit, y: logit) equations(a: x1 x2 x3 x4, y: a x1 x2 x3 x4) ///
        sim(20000) samples(2) seed(1006)
    matrix b = e(b)
    scalar G_RD = b[1,1] - b[1,2]
}
local ok = (_rc==0)
chk "R6 gcomp ran (4 confounders)" `ok'
if `ok' {
    chk "R6 recover RD" `=(abs(G_RD - T_RD) < `tolPO')'
}

**# R7: multi-level dose-response (ordinal treatment 0/1/2)

capture noisily {
    clear
    set seed 1007001
    set obs 30000
    gen long id = _n
    gen byte time = 1
    gen double x1 = rnormal()
    gen byte a = 0
    replace a = 1 if runiform() < 0.34
    replace a = 2 if runiform() < 0.34 & a==1
    gen byte y = rbinomial(1, invlogit(-1 + 0.5*a + 0.5*x1))
    forvalues lev = 0/2 {
        gen double pp`lev' = invlogit(-1 + 0.5*`lev' + 0.5*x1)
        quietly summarize pp`lev', meanonly
        scalar T_PO`lev' = r(mean)
    }
    gcomp y a x1, outcome(y) idvar(id) tvar(time) eofu fixedcovariates(x1) ///
        intvars(a) interventions(a=0, a=1, a=2) commands(a: ologit, y: logit) ///
        equations(a: x1, y: a x1) sim(20000) samples(2) seed(1007)
    matrix b = e(b)
    scalar G_PO0 = b[1,1]
    scalar G_PO1 = b[1,2]
    scalar G_PO2 = b[1,3]
}
local ok = (_rc==0)
chk "R7 gcomp ran (3-level dose-response)" `ok'
if `ok' {
    chk "R7 recover PO(a=0)" `=(abs(G_PO0 - T_PO0) < `tolPO')'
    chk "R7 recover PO(a=1)" `=(abs(G_PO1 - T_PO1) < `tolPO')'
    chk "R7 recover PO(a=2)" `=(abs(G_PO2 - T_PO2) < `tolPO')'
    chk "R7 dose-response monotone" `=(G_PO0 < G_PO1 & G_PO1 < G_PO2)'
}

**# R8: linear mediation -- closed-form NDE/NIE/TCE (regress m and y)
* M = 0.5 + 1.2*x + 0.4*c ; Y = 1 + 0.8*x + 0.6*m + 0.3*c
* NIE = a*b = 1.2*0.6 = 0.72 ; NDE = c' = 0.8 ; TCE = 1.52 (exact)

capture noisily {
    clear
    set seed 1008001
    set obs 40000
    gen double c0 = rnormal()
    gen byte x = rbinomial(1, invlogit(0.1 + 0.3*c0))
    gen double m = 0.5 + 1.2*x + 0.4*c0 + rnormal()
    gen double y = 1 + 0.8*x + 0.6*m + 0.3*c0 + rnormal()
    scalar T_TCE = 1.52
    scalar T_NDE = 0.80
    scalar T_NIE = 0.72
    gcomp y m x c0, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: regress, y: regress) equations(m: x c0, y: m x c0) ///
        base_confs(c0) sim(8000) samples(2) seed(1008)
    scalar G_TCE = e(tce)
    scalar G_NDE = e(nde)
    scalar G_NIE = e(nie)
}
local ok = (_rc==0)
chk "R8 gcomp ran (linear mediation)" `ok'
if `ok' {
    chk "R8 recover TCE=1.52" `=(abs(G_TCE - T_TCE) < `tolTCE')'
    chk "R8 recover NDE=0.80" `=(abs(G_NDE - T_NDE) < `tolNE')'
    chk "R8 recover NIE=0.72" `=(abs(G_NIE - T_NIE) < `tolNE')'
    chk "R8 decomposition TCE=NDE+NIE" `=(abs(G_TCE - (G_NDE + G_NIE)) < 1e-5)'
}

**# R9: linear-model CDE independence -- CDE(m)=c'=0.8 for every m level

capture noisily {
    clear
    set seed 1009001
    set obs 40000
    gen double c0 = rnormal()
    gen byte x = rbinomial(1, invlogit(0.1 + 0.3*c0))
    gen double m = 0.5 + 1.2*x + 0.4*c0 + rnormal()
    gen double y = 1 + 0.8*x + 0.6*m + 0.3*c0 + rnormal()
    scalar T_CDE = 0.80
    gcomp y m x c0, outcome(y) mediation obe exposure(x) mediator(m) control(0) ///
        commands(m: regress, y: regress) equations(m: x c0, y: m x c0) ///
        base_confs(c0) sim(8000) samples(2) seed(1009)
    scalar G_CDE0 = e(cde)
    gcomp y m x c0, outcome(y) mediation obe exposure(x) mediator(m) control(2) ///
        commands(m: regress, y: regress) equations(m: x c0, y: m x c0) ///
        base_confs(c0) sim(8000) samples(2) seed(1009)
    scalar G_CDE2 = e(cde)
}
local ok = (_rc==0)
chk "R9 gcomp ran (linear CDE)" `ok'
if `ok' {
    chk "R9 recover CDE(m=0)=0.8" `=(abs(G_CDE0 - T_CDE) < `tolCDE')'
    chk "R9 recover CDE(m=2)=0.8" `=(abs(G_CDE2 - T_CDE) < `tolCDE')'
    chk "R9 CDE is mediator-level-invariant" `=(abs(G_CDE0 - G_CDE2) < `tolCDE')'
}

**# R10: binary mediation -- NDE/NIE/TCE against an analytic (over-m) oracle
* M ~ Bern(invlogit(-0.3+1.0x+0.2c)) ; Y ~ Bern(invlogit(-0.5+0.9x+0.7m+0.3c))

capture noisily {
    clear
    set seed 1010001
    set obs 150000
    gen double c0 = rnormal()
    * analytic potential-outcome pieces on the fitting covariates
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
    scalar T_TCE = S11 - S00
    scalar T_NDE = S10 - S00
    scalar T_NIE = S11 - S10
    * now the observed data and the fit
    gen byte x = rbinomial(1, invlogit(0.1 + 0.3*c0))
    gen byte m = rbinomial(1, invlogit(-0.3 + 1.0*x + 0.2*c0))
    gen byte y = rbinomial(1, invlogit(-0.5 + 0.9*x + 0.7*m + 0.3*c0))
    gcomp y m x c0, outcome(y) mediation obe exposure(x) mediator(m) ///
        commands(m: logit, y: logit) equations(m: x c0, y: m x c0) ///
        base_confs(c0) sim(10000) samples(2) seed(1010)
    scalar G_TCE = e(tce)
    scalar G_NDE = e(nde)
    scalar G_NIE = e(nie)
}
local ok = (_rc==0)
chk "R10 gcomp ran (binary mediation)" `ok'
if `ok' {
    chk "R10 recover TCE" `=(abs(G_TCE - T_TCE) < `tolTCE')'
    chk "R10 recover NDE" `=(abs(G_NDE - T_NDE) < `tolNE')'
    chk "R10 recover NIE" `=(abs(G_NIE - T_NIE) < `tolNE')'
    chk "R10 decomposition TCE=NDE+NIE" `=(abs(G_TCE - (G_NDE + G_NIE)) < 1e-5)'
}

**# R11: binary CDE recovery + mediator-level dependence
* True CDE(m) = E_c[ invlogit(-0.5+0.9+0.7m+0.3c) - invlogit(-0.5+0.7m+0.3c) ]

capture noisily {
    clear
    set seed 1011001
    set obs 150000
    gen double c0 = rnormal()
    gen double cde0 = invlogit(-0.5 + 0.9 + 0.3*c0) - invlogit(-0.5 + 0.3*c0)
    gen double cde1 = invlogit(-0.5 + 0.9 + 0.7 + 0.3*c0) - invlogit(-0.5 + 0.7 + 0.3*c0)
    quietly summarize cde0, meanonly
    scalar T_CDE0 = r(mean)
    quietly summarize cde1, meanonly
    scalar T_CDE1 = r(mean)
    gen byte x = rbinomial(1, invlogit(0.1 + 0.3*c0))
    gen byte m = rbinomial(1, invlogit(-0.3 + 1.0*x + 0.2*c0))
    gen byte y = rbinomial(1, invlogit(-0.5 + 0.9*x + 0.7*m + 0.3*c0))
    gcomp y m x c0, outcome(y) mediation obe exposure(x) mediator(m) control(0) ///
        commands(m: logit, y: logit) equations(m: x c0, y: m x c0) ///
        base_confs(c0) sim(10000) samples(2) seed(1011)
    scalar G_CDE0 = e(cde)
    gcomp y m x c0, outcome(y) mediation obe exposure(x) mediator(m) control(1) ///
        commands(m: logit, y: logit) equations(m: x c0, y: m x c0) ///
        base_confs(c0) sim(10000) samples(2) seed(1011)
    scalar G_CDE1 = e(cde)
}
local ok = (_rc==0)
chk "R11 gcomp ran (binary CDE)" `ok'
if `ok' {
    chk "R11 recover CDE(m=0)" `=(abs(G_CDE0 - T_CDE0) < `tolCDE')'
    chk "R11 recover CDE(m=1)" `=(abs(G_CDE1 - T_CDE1) < `tolCDE')'
    chk "R11 CDE depends on mediator level" `=(G_CDE0 > G_CDE1)'
}

**# R12: control() numeric guard -- malformed control(m=0) must fail loudly,
* not silently collapse the CDE to the total effect (regression test)

capture noisily {
    clear
    set seed 1012001
    set obs 20000
    gen double c0 = rnormal()
    gen byte x = rbinomial(1, invlogit(0.1 + 0.3*c0))
    gen byte m = rbinomial(1, invlogit(-0.3 + 1.0*x + 0.2*c0))
    gen byte y = rbinomial(1, invlogit(-0.5 + 0.9*x + 0.7*m + 0.3*c0))
}
capture gcomp y m x c0, outcome(y) mediation obe exposure(x) mediator(m) control(m=0) ///
    commands(m: logit, y: logit) equations(m: x c0, y: m x c0) base_confs(c0) sim(500) samples(2) seed(1012)
chk "R12 control(m=0) rejected with rc=198" `=(_rc==198)'
capture gcomp y m x c0, outcome(y) mediation obe exposure(x) mediator(m) control(0) ///
    commands(m: logit, y: logit) equations(m: x c0, y: m x c0) base_confs(c0) sim(2000) samples(2) seed(1012)
chk "R12 control(0) still accepted" `=(_rc==0)'

**# R13: time-varying CONTINUOUS (regress) outcome, static-regime recovery
* 3-visit sequential design; continuous outcome at end of follow-up whose only
* treatment channel is the DIRECT effect of the final treatment (Alag). The
* time-varying confounder L still confounds treatment assignment (and must be
* adjusted for), but does not carry the effect into Y. Truth = E[Y(always)] and
* E[Y(never)] by forward-simulating each static regime at large N (exact g-formula
* oracle). This confirms the continuous-outcome intervention path recovers a
* known effect through the varyingcovariates() machinery.
*
* NOTE: R13 exercises the DIRECT-effect continuous tv path (effect carried by the
* final treatment Alag). The harder LAGGED-confounder cascade case (effect
* propagates A(t-1) -> L(t) -> Y through Llag) is covered by R14 below, and by the
* binary-outcome recovery in validation_gcomp_recovery.do.

capture program drop _gcx_fsim
program define _gcx_fsim, rclass
    args regime N seed
    clear
    set seed `seed'
    set obs `N'
    gen double L0 = rnormal()
    gen double L1 = 0.10 + 0.15*L0 + rnormal(0, 0.35)
    gen double L2 = 0.10 + 0.55*L1 - 0.50*`regime' + 0.15*L0 + rnormal(0, 0.35)
    gen double Y  = 1.0 - 0.60*`regime' + 0.20*L0 + rnormal(0, 0.5)
    quietly summarize Y, meanonly
    return scalar my = r(mean)
end

capture noisily {
    _gcx_fsim 1 400000 771
    scalar T_ALW = r(my)
    _gcx_fsim 0 400000 772
    scalar T_NEV = r(my)
    scalar T_RD = T_ALW - T_NEV

    clear
    set seed 1013001
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
    gen double Y = .
    bysort id (t): replace Y = 1.0 - 0.60*A[_n-1] + 0.20*L0 + rnormal(0,0.5) if t==3
    gcomp Y L0 A L Alag Llag id t, outcome(Y) idvar(id) tvar(t) ///
        varyingcovariates(L) fixedcovariates(L0) laggedvars(Alag Llag) ///
        lagrules(Alag: A 1, Llag: L 1) intvars(A) eofu ///
        commands(A: logit, Y: regress, L: regress) ///
        equations(A: L0 L, Y: Alag L0, L: Alag Llag L0) ///
        interventions(A=1, A=0) sim(10000) samples(2) seed(1013)
    matrix b = e(b)
    scalar G_ALW = b[1,1]
    scalar G_NEV = b[1,2]
    scalar G_RD = G_ALW - G_NEV
}
local ok = (_rc==0)
chk "R13 gcomp ran (time-varying continuous)" `ok'
if `ok' {
    chk "R13 recover E[Y(always)]" `=(abs(G_ALW - T_ALW) < `tolCont')'
    chk "R13 recover E[Y(never)]" `=(abs(G_NEV - T_NEV) < `tolCont')'
    chk "R13 recover regime RD" `=(abs(G_RD  - T_RD)  < `tolCont')'
}
capture program drop _gcx_fsim

**# R14: time-varying CONTINUOUS (regress) outcome, LAGGED-confounder CASCADE
* Regression test for the eofu continuous-outcome cascade bug (gcomp v1.4.3).
* Pure cascade: A(t-1) -> L(t) -> Y. The end-of-follow-up continuous outcome Y
* depends only on the lagged confounder Llag (=L at t-1), which itself carries the
* treatment through L(t)=...-0.50*A(t-1)... . Y is legitimately MISSING at
* intermediate visits (measured only at t=3). Before the fix, the outcome
* missing-data screen dropped those intermediate rows, severing the cascade and
* flattening the estimated RD toward 0 (recovered ~0 instead of the truth). The
* fix requires the eofu outcome only at the final visit; the cascade now recovers.
*
* Truth (exact g-formula oracle): only A1 channels into Y (via L2). Under a static
* regime a in {0,1}: L2 = 0.10 + 0.55*L1 - 0.50*a + 0.15*L0, Y = 1.0 + 0.50*L2 +
* 0.20*L0. Intervening a: 1 vs 0 shifts L2 by -0.50, so RD = 0.50*(-0.50) = -0.25.
* Forward-simulate each regime at large N to average over L0/L1 noise.

capture program drop _gcx_casc
program define _gcx_casc, rclass
    args regime N seed
    clear
    set seed `seed'
    set obs `N'
    gen double L0 = rnormal()
    gen double L1 = 0.10 + 0.15*L0 + rnormal(0, 0.35)
    gen double L2 = 0.10 + 0.55*L1 - 0.50*`regime' + 0.15*L0 + rnormal(0, 0.35)
    gen double Y  = 1.0 + 0.50*L2 + 0.20*L0 + rnormal(0, 0.5)
    quietly summarize Y, meanonly
    return scalar my = r(mean)
end

capture noisily {
    _gcx_casc 1 400000 781
    scalar TC_ALW = r(my)
    _gcx_casc 0 400000 782
    scalar TC_NEV = r(my)
    scalar TC_RD = TC_ALW - TC_NEV

    clear
    set seed 1014001
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
    * continuous outcome measured ONLY at end of follow-up (missing at t=1,2)
    gen double Y = .
    bysort id (t): replace Y = 1.0 + 0.50*L[_n-1] + 0.20*L0 + rnormal(0,0.5) if t==3

    * naive/confounded contrast must MISS the truth (L1 confounds A1 and L2->Y)
    bysort id (t): gen byte A1 = A[1]
    quietly regress Y i.A1 if t==3
    scalar C_NAIVE = _b[1.A1]

    gcomp Y L0 A L Alag Llag id t, outcome(Y) idvar(id) tvar(t) ///
        varyingcovariates(L) fixedcovariates(L0) laggedvars(Alag Llag) ///
        lagrules(Alag: A 1, Llag: L 1) intvars(A) eofu ///
        commands(A: logit, Y: regress, L: regress) ///
        equations(A: L0 L, Y: Llag L0, L: Alag Llag L0) ///
        interventions(A=1, A=0) sim(10000) samples(2) seed(1014)
    matrix b = e(b)
    scalar GC_ALW = b[1,1]
    scalar GC_NEV = b[1,2]
    scalar GC_RD = GC_ALW - GC_NEV
}
local ok = (_rc==0)
chk "R14 gcomp ran (continuous cascade)" `ok'
if `ok' {
    chk "R14 naive contrast misses truth" `=(abs(C_NAIVE - TC_RD) > `naiveMin')'
    chk "R14 recover E[Y(always)]" `=(abs(GC_ALW - TC_ALW) < `tolCont')'
    chk "R14 recover E[Y(never)]" `=(abs(GC_NEV - TC_NEV) < `tolCont')'
    chk "R14 recover cascade RD" `=(abs(GC_RD - TC_RD) < `tolCont')'
}
capture program drop _gcx_casc

**# Summary

local final_T = $T
local final_P = $P
local final_F = $F
macro drop T P F
display as result "Results: `final_P'/`final_T' passed, `final_F' failed"
if `final_F' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_gcomp_recovery_extended tests=`final_T' pass=`final_P' fail=`final_F' status=FAIL"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_gcomp_recovery_extended tests=`final_T' pass=`final_P' fail=`final_F' status=PASS"
