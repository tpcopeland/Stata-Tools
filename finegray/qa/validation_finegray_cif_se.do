* validation_finegray_cif_se.do
* Deterministic regression and sensitivity checks for the finegray_cif /
* finegray_predict analytic CIF standard error.
*
* finegray reports an influence-function (sandwich) SE for the cumulative
* incidence:  SE = sqrt(sum_i psi_i^2),  psi_i = factor*(q_i + PSIb_i*g'),
* capturing BOTH baseline-hazard and coefficient uncertainty, with the
* censoring weights G(t) treated as known.  crossval_cif.do checks this SE
* against a subject bootstrap (a Monte-Carlo oracle, noisy at feasible reps);
* riskRegression/cmprsk expose no Fine-Gray CIF SE, so there is no external
* analytic reference.
*
* The delete-one JACKKNIFE variance,
* jvar = (n-1)/n * sum_i (F_(-i) - Fbar)^2, is computed by an independent
* full-refit mechanism that never touches the analytic-SE Mata code.  It is not
* an exact oracle for the shipped fixed-weight influence function: each refit
* re-estimates the censoring weights, whereas the analytic SE treats G as
* fixed.  The seeded ratio is therefore a reproducible sensitivity envelope
* that catches gross scaling/path errors, not proof of equality to the same
* asymptotic variance.
*
* Section 9 removes that caveat rather than living with it: on data with NO
* censoring, G(t) is identically 1, a refit has nothing to re-estimate, and the
* fixed-weight analytic SE and the delete-one jackknife estimate the same
* quantity.  That is the only cell here that can carry a tight band, and it
* does.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "validation_finegray_cif_se.log", replace name(_cse)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* PIN THE RNG STREAM, not just the seed.  Both fixtures below are single-seed
* and their acceptance bands are narrow (the uncensored section's is
* [0.98, 1.02]); a future Stata whose default generator changed would move the
* fixture silently and the band would read as a finding about the estimator.
set rng mt64

* Acceptable analytic/jackknife SE ratio.  Observed ~0.985 across times and
* profiles (deterministic): the lower edge covers the censoring-known gap plus
* margin; the upper edge guards against the analytic SE exceeding the jackknife.
local lo = 0.93
local hi = 1.05

**# ---------------------------------------------------------------
**# Seeded Fine-Gray competing-risks DGP (one fit; jackknife reused
**# across both covariate profiles)
**# ---------------------------------------------------------------
clear
set seed 4321
set obs 150
gen long id = _n
gen double x1 = rnormal()
gen double x2 = rbinomial(1, 0.4)
gen double u  = runiform()
gen double te = -ln(u) / exp(0.4*x1 - 0.3*x2)
gen double tc = runiform()*4
gen double t  = min(te, tc)
gen byte d = te <= tc
gen byte status = 0
replace status = 1 if d==1 & runiform() > 0.4
replace status = 2 if d==1 & status==0
stset t, failure(d) id(id)
finegray x1 x2, compete(status) cause(1) nolog
assert e(converged) == 1

* Two covariate profiles and three horizons
local times "0.5 1 2"
* Profile A = (x1=0, x2=0); Profile B = (x1=0.5, x2=1)

* Analytic SEs (influence-function) at both profiles
finegray_cif, at(x1=0 x2=0) attime(`times') ci
matrix A_A = r(table)
finegray_cif, at(x1=0.5 x2=1) attime(`times') ci
matrix A_B = r(table)

**# ---------------------------------------------------------------
**# Delete-one jackknife (shared loop): leave out each subject, refit,
**# evaluate the CIF point estimate at both profiles and all horizons.
**# ---------------------------------------------------------------
preserve
quietly keep if e(sample)
quietly levelsof id, local(ids)
tempfile base
quietly save `base'

* accumulators: a* = profile A, b* = profile B; suffix = horizon index 1..3
forvalues k = 1/3 {
    scalar sa`k' = 0
    scalar qa`k' = 0
    scalar sb`k' = 0
    scalar qb`k' = 0
}
scalar njk = 0

foreach i of local ids {
    quietly {
        use `base', clear
        drop if id == `i'
        stset t, failure(d) id(id)
        capture finegray x1 x2, compete(status) cause(1) nolog
        local jk_rc = _rc
        if `jk_rc' == 0 & e(converged) != 1 local jk_rc = 430
        if `jk_rc' == 0 {
            scalar njk = njk + 1
            finegray_cif, at(x1=0 x2=0) attime(`times')
            matrix JA = r(table)
            finegray_cif, at(x1=0.5 x2=1) attime(`times')
            matrix JB = r(table)
            forvalues k = 1/3 {
                scalar sa`k' = sa`k' + JA[`k',2]
                scalar qa`k' = qa`k' + JA[`k',2]^2
                scalar sb`k' = sb`k' + JB[`k',2]
                scalar qb`k' = qb`k' + JB[`k',2]^2
            }
        }
    }
}
restore

* A survivor-only jackknife is a different statistic and can hide systematic
* nonconvergence.  Every planned delete-one fit must contribute.
local ++test_count
if njk == 150 {
    display as result "  PASS: all 150 delete-one fits converged"
    local ++pass_count
}
else {
    display as error "  FAIL: only " njk " of 150 delete-one fits converged"
    local ++fail_count
}

local hlabel1 "0.5"
local hlabel2 "1"
local hlabel3 "2"

* Profile A: tests 2-4
forvalues k = 1/3 {
    local ++test_count
    scalar mA = sa`k'/njk
    scalar jvarA = (njk-1)/njk * (qa`k' - njk*mA^2)
    scalar jseA  = sqrt(jvarA)
    scalar anseA = A_A[`k',3]
    scalar ratA  = anseA/jseA
    display as text "  profile A, t=`hlabel`k'': analytic SE=" %8.5f anseA ///
        "  jackknife SE=" %8.5f jseA "  ratio=" %6.3f ratA
    * stata-dev-ignore: rc-only-test — the captured statement IS the content oracle (an analytic-versus-jackknife SE ratio inside a measured envelope); the following if _rc is the pass/fail bookkeeping for that comparison, not a return-code-only test
    capture assert anseA > 0 & jseA > 0 & ratA >= `lo' & ratA <= `hi'
    if _rc == 0 {
        display as result "  PASS: CIF SE stays within jackknife sensitivity envelope (profile A, t=`hlabel`k'')"
        local ++pass_count
    }
    else {
        display as error "  FAIL: CIF SE vs jackknife out of [`lo',`hi'] (profile A, t=`hlabel`k'', ratio=`=ratA')"
        local ++fail_count
    }
}

* Profile B: tests 5-7
forvalues k = 1/3 {
    local ++test_count
    scalar mB = sb`k'/njk
    scalar jvarB = (njk-1)/njk * (qb`k' - njk*mB^2)
    scalar jseB  = sqrt(jvarB)
    scalar anseB = A_B[`k',3]
    scalar ratB  = anseB/jseB
    display as text "  profile B, t=`hlabel`k'': analytic SE=" %8.5f anseB ///
        "  jackknife SE=" %8.5f jseB "  ratio=" %6.3f ratB
    * stata-dev-ignore: rc-only-test — the captured statement IS the content oracle (an analytic-versus-jackknife SE ratio inside a measured envelope); the following if _rc is the pass/fail bookkeeping for that comparison, not a return-code-only test
    capture assert anseB > 0 & jseB > 0 & ratB >= `lo' & ratB <= `hi'
    if _rc == 0 {
        display as result "  PASS: CIF SE stays within jackknife sensitivity envelope (profile B, t=`hlabel`k'')"
        local ++pass_count
    }
    else {
        display as error "  FAIL: CIF SE vs jackknife out of [`lo',`hi'] (profile B, t=`hlabel`k'', ratio=`=ratB')"
        local ++fail_count
    }
}

**# ---------------------------------------------------------------
**# 8. finegray_cif and finegray_predict report the SAME analytic SE
**#    at a common profile/time (the SE is one routine; both surfaces
**#    must agree exactly).
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
    * The jackknife loop above left the active e() from the last delete-one
    * refit, whose estimation sample no longer matches the restored data.
    * Post-estimation commands correctly reject that state (r(459)), so refit
    * on the full sample before comparing the two SE surfaces.
    quietly finegray x1 x2, compete(status) cause(1) nolog
    assert e(converged) == 1

    * Use observation 1's covariate profile (the estimation data must stay in
    * memory: the influence-function SE is built from e(sample)).
    scalar v1 = x1[1]
    scalar v2 = x2[1]
    finegray_cif, at(x1=`=v1' x2=`=v2') attime(1) ci
    matrix CC = r(table)
    scalar se_cif = CC[1,3]
    * finegray_predict, cif ci at t=1 for every obs; obs 1 carries profile A.
    gen double tt = 1
    finegray_predict pc, cif timevar(tt) ci
    * Recover SE from the cloglog-scale limits:
    *   g = ln(-ln(1-cif)); seg = (uci_g - g)/z ; se = seg*(1-cif)*(-ln(1-cif))
    scalar cifp = pc[1]
    scalar z    = invnormal(1 - (1 - c(level)/100)/2)
    scalar gg   = ln(-ln(1 - cifp))
    scalar ggu  = ln(-ln(1 - pc_uci[1]))
    scalar segp = (ggu - gg)/z
    scalar se_pred = segp*(1 - cifp)*(-ln(1 - cifp))
    drop tt pc pc_lci pc_uci
    display as text "  finegray_cif SE=" %9.6f se_cif "  finegray_predict SE=" %9.6f se_pred
    assert !missing(se_cif, se_pred)
    assert reldif(se_cif, se_pred) < 1e-4
}
if _rc == 0 {
    display as result "  PASS: finegray_cif and finegray_predict SE agree"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_cif vs finegray_predict SE disagree (rc=`=_rc')"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 9. THE ONE CELL WHERE THE JACKKNIFE IS AN EXACT ORACLE:
**#    no censoring, no truncation.
**# ---------------------------------------------------------------
* Every envelope above is loose for one stated reason: each delete-one refit
* re-estimates the censoring distribution G, while the analytic influence
* function treats G as fixed, so the two are not estimating the same variance
* and the ratio can only be bounded, not pinned.  Remove the censoring and that
* gap closes by construction -- with every subject failing from cause 1 or 2,
* G(t) is identically 1, there is nothing left for a refit to re-estimate, and
* the fixed-weight analytic SE and the jackknife are estimating the SAME
* quantity.  This is therefore the only cell in the file that can carry a tight
* band, and it is the one that would catch a scaling error the loose envelopes
* let through.
*
* MEASURED 2026-09-02 (seeded, deterministic): analytic 0.018712, jackknife
* 0.018760, ratio 0.99748.  The band below is eight times that deviation and is
* not comparable to the [`lo',`hi'] used above, which has to absorb the
* censoring-known gap.
*
* n = 1000, not 2000: delete-one is n full refits, which measured 53 s here and
* would have been about 10 minutes at n = 2000 for a file that otherwise runs
* in seconds.  The identity being checked does not depend on n.
local ulo = 0.98
local uhi = 1.02

clear
set seed 20260902
set obs 1000
gen long id = _n
gen double x1 = rnormal()
gen double x2 = rbinomial(1, 0.5)
gen double u  = runiform()
gen double t  = -ln(u) / exp(0.5*x1 - 0.4*x2)
* No censoring: everyone fails, from cause 1 or cause 2.
gen byte status = cond(runiform() < 0.6, 1, 2)
gen byte d = 1
stset t, failure(d) id(id)
quietly finegray x1 x2, compete(status) cause(1) nolog
assert e(converged) == 1

* The horizon is the median cause-1 failure time on the FULL sample, held fixed
* across every refit: a horizon recomputed inside the loop would make each
* delete-one replicate a different estimand and the jackknife meaningless.
quietly summarize t if status == 1, detail
scalar uhz = r(p50)
quietly count if status == 0
assert r(N) == 0
finegray_cif, at(x1=0.5 x2=1) attime(`=uhz') ci
matrix UA = r(table)
scalar uanse = UA[1,3]

preserve
quietly keep if e(sample)
quietly levelsof id, local(uids)
tempfile ubase
quietly save `ubase'
scalar usum = 0
scalar uqsum = 0
scalar unjk = 0
foreach i of local uids {
    quietly {
        use `ubase', clear
        drop if id == `i'
        stset t, failure(d) id(id)
        capture finegray x1 x2, compete(status) cause(1) nolog
        local jk_rc = _rc
        if `jk_rc' == 0 & e(converged) != 1 local jk_rc = 430
        if `jk_rc' == 0 {
            scalar unjk = unjk + 1
            finegray_cif, at(x1=0.5 x2=1) attime(`=uhz')
            matrix UJ = r(table)
            scalar usum  = usum + UJ[1,2]
            scalar uqsum = uqsum + UJ[1,2]^2
        }
    }
}
restore

local ++test_count
if unjk == 1000 {
    display as result "  PASS: all 1000 uncensored delete-one fits converged"
    local ++pass_count
}
else {
    display as error "  FAIL: only " unjk " of 1000 uncensored delete-one fits converged"
    local ++fail_count
}

local ++test_count
scalar ujvar = (unjk-1)/unjk * (uqsum - usum^2/unjk)
scalar ujse  = sqrt(ujvar)
scalar uratio = uanse/ujse
display as text "  uncensored, t=" %6.4f uhz ": analytic SE=" %8.5f uanse ///
    "  jackknife SE=" %8.5f ujse "  ratio=" %7.5f uratio
* stata-dev-ignore: rc-only-test — the captured statement IS the content oracle (an analytic-versus-jackknife SE ratio inside a measured envelope); the following if _rc is the pass/fail bookkeeping for that comparison, not a return-code-only test
capture assert uanse > 0 & ujse > 0 & uratio >= `ulo' & uratio <= `uhi'
if _rc == 0 {
    display as result "  PASS: with G identically 1 the analytic and jackknife CIF SEs agree to [`ulo',`uhi']"
    local ++pass_count
}
else {
    display as error "  FAIL: uncensored CIF SE ratio `=uratio' outside [`ulo',`uhi']"
    local ++fail_count
}

**# ---------------------------------------------------------------
**# 10. EXACT INFLUENCE-FUNCTION ORACLE for the ordinary branch
**#     (independently derived, independently coded, no package routine)
**# ---------------------------------------------------------------
* Everything above this section is a RESAMPLING envelope: a delete-one
* jackknife, which re-estimates G in every refit while the analytic SE treats G
* as fixed, so only the uncensored cell can carry a tight band.
*
* WHAT WOULD CLOSE THAT PROPERLY, AND WHY IT CANNOT BE SOURCED.  An external
* analytic oracle for the CIF variance does not exist in the literature this
* package is grounded in, and that was checked rather than assumed:
*
*   Fine & Gray (1999) sec. 5, p.501   the limiting process J1{t;z0} is "quite
*                                      complicated" and is NOT obtained
*                                      analytically; their bands come from a
*                                      multiplier-bootstrap SIMULATION
*   Geskus (2011) sec. 3.2, p.43-44    eq. (21) is the COEFFICIENT information
*                                      matrix; no CIF variance appears
*   Zhang, Zhang & Fine (2011) App. B  W-hat^(1)_{beta,i} is the COEFFICIENT
*                                      influence function; no CIF term
*   Zhou et al. (2012) p.377           "The variance is rather complicated, with
*                                      bootstrapping providing practicable
*                                      inferences for F_1(t, Z0)."
*
* and riskRegression/cmprsk expose no Fine-Gray CIF standard error, so there is
* no software oracle either.  What CAN be done exactly, and is done here, is to
* re-derive the estimand the package documents -- the fixed-weight CIF influence
* function -- and recompute it from scratch.  This is an internal consistency
* check with an external estimand, not an external oracle, and it is stated that
* way rather than dressed up.
*
* THE DERIVATION IMPLEMENTED BELOW.  With the weights treated as known,
*
*   w_i(u) = 1                       if X_i >= u
*          = G(u-)/G(X_i-)           if X_i < u and subject i had the competing
*                                    event
*          = 0                       otherwise
*   S0(u)  = sum_i w_i(u) exp(Z_i'b),   S1(u) = sum_i w_i(u) exp(Z_i'b) Z_i
*   zbar   = S1/S0,   dLambda10(u) = dN1(u)/S0(u)                  [Breslow]
*   Omega  = sum_{u: dN1>0} dN1(u) { S2(u)/S0(u) - zbar zbar' }
*   eta_i  = int (Z_i - zbar) dN1_i(u) - int w_i(u)(Z_i - zbar) e^{Z_i'b} dL(u)
*   A_i(t) = int_0^t { dN1_i(u) - w_i(u) e^{Z_i'b} dL(u) } / S0(u)
*   q(t)   = int_0^t zbar(u) dLambda10(u)
*   H(t)   = Lambda10(t) exp(z0'b),  F(t) = 1 - exp{-H(t)}
*   psi^H_i = e^{z0'b} [ A_i(t) + (Lambda10(t) z0 - q(t))' Omega^{-1} eta_i ]
*   psi^F_i = exp{-H(t)} psi^H_i
*   SE(F)   = sqrt( sum_i (psi^F_i)^2 )                 [no finite-sample factor]
*
* Nothing below calls _finegray_score_residuals, _finegray_km_censor or any
* other package Mata function: the weights, the risk-set sums, the baseline, the
* information, the score residuals and the influence functions are all rebuilt
* here from _t, _d, status and the fitted e(b).
*
* THE LICENSING GATE.  The weight above uses G at its LEFT limit, which is
* Geskus (2011) eq. (11), p.41.  Rather than assume that is what the package
* does, section 10a rebuilds Lambda10 under BOTH conventions and requires the
* left-limit one to reproduce e(basehaz) exactly while the right-continuous one
* does not.  That measurement is what licenses the influence-function comparison
* that follows: if the two implementations disagreed about the weight, agreeing
* about the SE would mean nothing.
*
* MEASURED 2026-09-04 (Stata 17 MP):
*   10a  mreldif(rebuilt Lambda10, e(basehaz)) over the whole 397-point curve:
*        left limit G(u-)  1.23e-15      right-continuous G(u)  1.13e-03
*   10b  censored, 2 profiles x 3 horizons, CIF and SE:   8.31e-17
*   10c  fault injection (coefficient term dropped):      4.21e-03  (must be
*        LARGER than the gate, and it is by 7 orders)
*   10d  uncensored, 3 horizons, CIF and SE:              3.92e-16
* Note that Stata's reldif(a, b) is |a-b|/(|b|+1), so on quantities of order
* 0.02-0.5 these are effectively absolute differences; the 1e-10 gate still
* sits 6-7 orders above the agreement and 7 orders below what 10c produces.
*
* SCOPE.  This closes the ORDINARY right-censored branch (and its uncensored
* special case) for finegray_cif's analytic SE at a covariate profile.  The
* delayed-entry, tvc(), bstrata() and cluster() branches are NOT covered here
* and remain resampling envelopes, for a stated reason in each case: their
* influence functions are documented package derivations with no published form
* to re-derive from, and re-coding a derivation from the same help file would be
* a transcription check rather than an independent one.  The clustered
* delayed-entry branch is calibrated instead, in
* validation_finegray_lt_cluster_cif_se.do.

capture program drop _cse_ifse
program define _cse_ifse, rclass
    * Independent fixed-weight CIF influence-function SE.
    *   gmode(1) right-continuous G(u); gmode(2) left-limit G(u-)
    *   nobeta   drop the coefficient-uncertainty term (fault injection)
    syntax , AT(numlist) TIMES(numlist) [GMODE(integer 2) NOBETA CURVE(name)]
    local nb = ("`nobeta'" != "")
    tempname z0 res
    matrix `z0' = (`: subinstr local at " " ", ", all')
    matrix `z0' = `z0''
    * The baseline curve is returned as a MATRIX, never through a macro: a
    * `local t = M[i,1]' round trip formats the time to display precision, and a
    * baseline time that comes back a few ulps low selects the previous row of
    * e(basehaz) and manufactures a whole increment of disagreement.
    local cv = ""
    if "`curve'" != "" local cv "`curve'"
    mata: _cse_ifse_core("`z0'", "`times'", `gmode', `nb', "`res'", "`cv'")
    return matrix table = `res'
end

mata:
mata set matastrict off
real scalar _cse_gat(real colvector grid, real colvector val, real scalar u)
{
    real scalar k
    k = sum(grid :<= u)
    if (k == 0) return(1)
    return(val[k])
}

void _cse_ifse_core(string scalar z0name, string scalar timestr,
                    real scalar gmode, real scalar nobeta, string scalar resname,
                    string scalar curvename)
{
    real colvector tt, dd, ev, ce, ut, at, Gr, Gl, Gv, Gx, dL, sel, At, w, we, psiF
    real matrix Z, zbar, Amat, Wall, Om, Ominv, eta, S2, out
    real colvector b, z0, eb, times
    real scalar n, m, J, i, j, k, a, s, Y, dC, run, u, Gu, S0, d1, L0, H, ez0, se
    real rowvector S1, zb, q, cvec

    tt = st_data(., "_t"); dd = st_data(., "_d"); ev = st_data(., "status")
    Z  = st_data(., ("x1", "x2"))
    b  = st_matrix("e(b)")'
    z0 = st_matrix(z0name)
    times = strtoreal(tokens(timestr))'
    n = rows(tt); eb = exp(Z * b); ez0 = exp(z0' * b)

    /* censoring Kaplan-Meier, both conventions */
    at = uniqrows(tt); m = rows(at)
    Gr = J(m, 1, 1); Gl = J(m, 1, 1); run = 1
    for (a = 1; a <= m; a++) {
        s  = at[a]
        Y  = colsum(tt :>= s)
        dC = colsum((tt :== s) :& (dd :== 0))
        Gl[a] = run
        if (Y > 0) run = run * (1 - dC/Y)
        Gr[a] = run
    }
    Gv = (gmode == 1 ? Gr : Gl)
    Gx = J(n, 1, 1)
    for (i = 1; i <= n; i++) Gx[i] = _cse_gat(at, Gv, tt[i])

    ce = select(tt, (dd :== 1) :& (ev :== 1))
    ut = uniqrows(ce); J = rows(ut)
    dL = J(J, 1, 0); zbar = J(J, cols(Z), 0)
    Om = J(cols(Z), cols(Z), 0); Amat = J(n, J, 0); Wall = J(n, J, 0)
    for (j = 1; j <= J; j++) {
        u  = ut[j]
        Gu = _cse_gat(at, Gv, u)
        w  = (tt :>= u) :+ ((tt :< u) :& (ev :== 2)) :* (Gu :/ Gx)
        Wall[., j] = w
        we = w :* eb
        S0 = colsum(we); S1 = colsum(we :* Z); S2 = quadcross(Z, we, Z)
        zb = S1 / S0
        d1 = colsum((tt :== u) :& (dd :== 1) :& (ev :== 1))
        zbar[j, .] = zb
        dL[j] = d1 / S0
        Om = Om + d1 * (S2/S0 - zb' * zb)
        Amat[., j] = (((tt :== u) :& (dd :== 1) :& (ev :== 1)) :- we * dL[j]) :/ S0
    }
    eta = J(n, cols(Z), 0)
    for (j = 1; j <= J; j++) {
        we  = Wall[., j] :* eb
        eta = eta :+ ((tt :== ut[j]) :& (dd :== 1) :& (ev :== 1)) :* (Z :- zbar[j, .]) ///
                  :- (we * dL[j]) :* (Z :- zbar[j, .])
    }
    Ominv = invsym(Om)

    out = J(rows(times), 4, .)
    for (k = 1; k <= rows(times); k++) {
        sel = (ut :<= times[k])
        L0  = colsum(select(dL, sel))
        q   = colsum(select(zbar :* dL, sel))
        At  = rowsum(select(Amat, sel'))
        H   = L0 * ez0
        cvec = (L0 :* z0' :- q)
        if (nobeta) psiF = exp(-H) :* (ez0 :* At)
        else        psiF = exp(-H) :* (ez0 :* (At :+ (eta * Ominv * cvec')))
        se = sqrt(colsum(psiF:^2))
        out[k, 1] = times[k]
        out[k, 2] = 1 - exp(-H)
        out[k, 3] = se
        out[k, 4] = L0
    }
    st_matrix(resname, out)
    st_matrixcolstripe(resname, (J(4, 1, ""), ("time" \ "cif" \ "se" \ "lambda0")))
    if (curvename != "") st_matrix(curvename, (ut, runningsum(dL)))
}
mata set matastrict on
end

**# 10a. Which G convention does the package's weight use?  MEASURE it.
clear
set seed 4321
set obs 900
gen long id = _n
gen double x1 = rnormal()
gen double x2 = rbinomial(1, 0.4)
gen double u  = runiform()
gen double te = -ln(u) / exp(0.4*x1 - 0.3*x2)
gen double tc = runiform()*4
gen double t  = min(te, tc)
gen byte d = te <= tc
gen byte status = 0
replace status = 1 if d==1 & runiform() > 0.4
replace status = 2 if d==1 & status==0
stset t, failure(d) id(id)
quietly finegray x1 x2, compete(status) cause(1) nolog basehaz
assert e(converged) == 1
matrix IF_BH = e(basehaz)
scalar if_bhlast = IF_BH[rowsof(IF_BH), colsof(IF_BH)]

local ++test_count
capture noisily {
    * Compare the WHOLE baseline curve as a matrix.  e(basehaz) is (event time,
    * cumulative subdistribution hazard) by cause-1 event time; the independent
    * rebuild uses the same grid, so mreldif over both columns compares every
    * increment at once and also pins that the two grids agree.
    quietly _cse_ifse, at(0.5 1) times(1e9) gmode(2) curve(IF_CL)
    quietly _cse_ifse, at(0.5 1) times(1e9) gmode(1) curve(IF_CR)
    assert rowsof(IF_CL) == rowsof(IF_BH)
    assert colsof(IF_CL) == colsof(IF_BH)
    local dL = mreldif(IF_CL, IF_BH)
    local dR = mreldif(IF_CR, IF_BH)
    assert !missing(`dL', `dR')
    display as text "  10a G convention over the whole baseline curve (" ///
        as result rowsof(IF_BH) as text " event times): mreldif left-limit = " ///
        as result %9.2e `dL' as text ", right-continuous = " as result %9.2e `dR'
    * Left limit reproduces the shipped baseline; the right-continuous
    * convention does not.  Both halves matter: the first licenses section 10b,
    * the second proves the fixture can tell the two conventions apart.
    assert `dL' < 1e-12
    assert `dR' > 1e-4
}
if _rc == 0 {
    display as result "  PASS: 10a the shipped weight uses G at its LEFT limit (Geskus eq. 11)"
    local ++pass_count
}
else {
    display as error "  FAIL: 10a G-convention identification (rc=`=_rc')"
    local ++fail_count
}

**# 10b. Right-censored branch: independent IF versus the shipped analytic SE
local ++test_count
capture noisily {
    local ifmax = 0
    foreach prof in "0 0" "0.5 1" {
        local p1 : word 1 of `prof'
        local p2 : word 2 of `prof'
        quietly finegray_cif, at(x1=`p1' x2=`p2') attime(0.4 0.9 1.6) ci nograph
        assert `"`r(se_method)'"' == "analytic"
        matrix IF_P = r(table)
        quietly _cse_ifse, at(`p1' `p2') times(0.4 0.9 1.6) gmode(2)
        matrix IF_M = r(table)
        forvalues k = 1/3 {
            assert !missing(IF_P[`k',2], IF_P[`k',3], IF_M[`k',2], IF_M[`k',3])
            assert IF_P[`k',3] > 0 & IF_M[`k',3] > 0
            local dc = reldif(IF_M[`k',2], IF_P[`k',2])
            local ds = reldif(IF_M[`k',3], IF_P[`k',3])
            if `dc' > `ifmax' local ifmax = `dc'
            if `ds' > `ifmax' local ifmax = `ds'
        }
    }
    display as text "  10b censored branch: max relative difference (CIF and SE, " ///
        "2 profiles x 3 horizons) = " as result %9.2e `ifmax'
    assert `ifmax' < 1e-10
}
if _rc == 0 {
    display as result "  PASS: 10b independent influence-function SE == shipped analytic SE (censored)"
    local ++pass_count
}
else {
    display as error "  FAIL: 10b censored influence-function comparison (rc=`=_rc')"
    local ++fail_count
}

**# 10c. Fault injection: the comparison must be able to fail
* Dropping the coefficient-uncertainty term leaves a well-formed, positive,
* plausible standard error.  If 10b still passed on it, 10b would be measuring
* the baseline term alone.
local ++test_count
capture noisily {
    quietly finegray_cif, at(x1=0.5 x2=1) attime(0.4 0.9 1.6) ci nograph
    matrix IF_P = r(table)
    quietly _cse_ifse, at(0.5 1) times(0.4 0.9 1.6) gmode(2) nobeta
    matrix IF_N = r(table)
    local fmin = 1e300
    forvalues k = 1/3 {
        assert !missing(IF_N[`k',3])
        assert IF_N[`k',3] > 0
        local dsn = reldif(IF_N[`k',3], IF_P[`k',3])
        if `dsn' < `fmin' local fmin = `dsn'
    }
    display as text "  10c fault injection (no coefficient term): min relative " ///
        "SE difference = " as result %9.2e `fmin'
    assert `fmin' > 1e-3
}
if _rc == 0 {
    display as result "  PASS: 10c dropping the coefficient term is detected"
    local ++pass_count
}
else {
    display as error "  FAIL: 10c fault injection not detected (rc=`=_rc')"
    local ++fail_count
}

**# 10d. Uncensored special case: G == 1, so the weight question disappears
local ++test_count
capture noisily {
    clear
    set seed 91011
    set obs 800
    gen long id = _n
    gen double x1 = rnormal()
    gen double x2 = rbinomial(1, 0.4)
    gen double u  = runiform()
    gen double t  = -ln(u) / exp(0.4*x1 - 0.3*x2)
    gen byte d = 1
    gen byte status = 1
    replace status = 2 if runiform() < 0.4
    stset t, failure(d) id(id)
    quietly finegray x1 x2, compete(status) cause(1) nolog
    assert e(converged) == 1
    quietly count if _d == 0
    assert r(N) == 0
    quietly finegray_cif, at(x1=0.5 x2=1) attime(0.4 0.9 1.6) ci nograph
    assert `"`r(se_method)'"' == "analytic"
    matrix IF_UP = r(table)
    quietly _cse_ifse, at(0.5 1) times(0.4 0.9 1.6) gmode(2)
    matrix IF_UM = r(table)
    local umax = 0
    forvalues k = 1/3 {
        assert !missing(IF_UP[`k',2], IF_UP[`k',3], IF_UM[`k',2], IF_UM[`k',3])
        assert IF_UP[`k',3] > 0
        local dc = reldif(IF_UM[`k',2], IF_UP[`k',2])
        local ds = reldif(IF_UM[`k',3], IF_UP[`k',3])
        if `dc' > `umax' local umax = `dc'
        if `ds' > `umax' local umax = `ds'
    }
    display as text "  10d uncensored branch: max relative difference = " ///
        as result %9.2e `umax'
    assert `umax' < 1e-10
}
if _rc == 0 {
    display as result "  PASS: 10d independent influence-function SE == shipped analytic SE (uncensored)"
    local ++pass_count
}
else {
    display as error "  FAIL: 10d uncensored influence-function comparison (rc=`=_rc')"
    local ++fail_count
}

capture program drop _cse_ifse

**# Summary
display as text _newline "RESULT: validation_finegray_cif_se tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _cse
    exit 1
}
display as result "ALL TESTS PASSED"
log close _cse
