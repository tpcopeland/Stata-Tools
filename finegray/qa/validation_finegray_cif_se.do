* validation_finegray_cif_se.do
* Closed-form (deterministic) oracle for the finegray_cif / finegray_predict
* analytic CIF standard error.
*
* finegray reports an influence-function (sandwich) SE for the cumulative
* incidence:  SE = sqrt(sum_i psi_i^2),  psi_i = factor*(q_i + PSIb_i*g'),
* capturing BOTH baseline-hazard and coefficient uncertainty, with the
* censoring weights G(t) treated as known.  crossval_cif.do checks this SE
* against a subject bootstrap (a Monte-Carlo oracle, noisy at feasible reps);
* riskRegression/cmprsk expose no Fine-Gray CIF SE, so there is no external
* analytic reference.
*
* This suite supplies the deterministic oracle the bootstrap cannot: the
* delete-one JACKKNIFE variance,  jvar = (n-1)/n * sum_i (F_(-i) - Fbar)^2,
* which is consistent for the same asymptotic variance as the influence-
* function estimator but is computed by an entirely independent mechanism
* (refitting on leave-one-subject-out samples — it never touches the SE Mata
* code).  Because removing one subject perturbs the censoring KM only
* infinitesimally, the jackknife matches the G-known analytic SE far more
* tightly than the bootstrap does: the analytic SE sits a hair (~1-2%) BELOW
* the jackknife (the known-censoring assumption), and never materially above
* it.  The DGP is seeded, so every number here is reproducible.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "validation_finegray_cif_se.log", replace name(_cse)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

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
        if _rc == 0 {
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

local hlabel1 "0.5"
local hlabel2 "1"
local hlabel3 "2"

* Profile A: tests 1-3
forvalues k = 1/3 {
    local ++test_count
    scalar mA = sa`k'/njk
    scalar jvarA = (njk-1)/njk * (qa`k' - njk*mA^2)
    scalar jseA  = sqrt(jvarA)
    scalar anseA = A_A[`k',3]
    scalar ratA  = anseA/jseA
    display as text "  profile A, t=`hlabel`k'': analytic SE=" %8.5f anseA ///
        "  jackknife SE=" %8.5f jseA "  ratio=" %6.3f ratA
    capture assert anseA > 0 & jseA > 0 & ratA >= `lo' & ratA <= `hi'
    if _rc == 0 {
        display as result "  PASS: CIF SE matches jackknife oracle (profile A, t=`hlabel`k'')"
        local ++pass_count
    }
    else {
        display as error "  FAIL: CIF SE vs jackknife out of [`lo',`hi'] (profile A, t=`hlabel`k'', ratio=`=ratA')"
        local ++fail_count
    }
}

* Profile B: tests 4-6
forvalues k = 1/3 {
    local ++test_count
    scalar mB = sb`k'/njk
    scalar jvarB = (njk-1)/njk * (qb`k' - njk*mB^2)
    scalar jseB  = sqrt(jvarB)
    scalar anseB = A_B[`k',3]
    scalar ratB  = anseB/jseB
    display as text "  profile B, t=`hlabel`k'': analytic SE=" %8.5f anseB ///
        "  jackknife SE=" %8.5f jseB "  ratio=" %6.3f ratB
    capture assert anseB > 0 & jseB > 0 & ratB >= `lo' & ratB <= `hi'
    if _rc == 0 {
        display as result "  PASS: CIF SE matches jackknife oracle (profile B, t=`hlabel`k'')"
        local ++pass_count
    }
    else {
        display as error "  FAIL: CIF SE vs jackknife out of [`lo',`hi'] (profile B, t=`hlabel`k'', ratio=`=ratB')"
        local ++fail_count
    }
}

**# ---------------------------------------------------------------
**# 7. finegray_cif and finegray_predict report the SAME analytic SE
**#    at a common profile/time (the SE is one routine; both surfaces
**#    must agree exactly).
**# ---------------------------------------------------------------
local ++test_count
capture noisily {
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

**# Summary
display as text _newline "RESULT: validation_finegray_cif_se tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _cse
    exit 1
}
display as result "ALL TESTS PASSED"
log close _cse
