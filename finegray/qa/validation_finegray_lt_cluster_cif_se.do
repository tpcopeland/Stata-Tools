* validation_finegray_lt_cluster_cif_se.do
* Calibrated Monte Carlo for the CLUSTERED, DELAYED-ENTRY analytic CIF standard
* error reported by finegray_cif.
* Package: finegray
*
* ---------------------------------------------------------------------------
* WHY A SIMULATION AND NOT AN IDENTITY
* ---------------------------------------------------------------------------
* validation_finegray_lt_se.do sections 7-8 rebuild the clustered delayed-entry
* COEFFICIENT sandwich from outside the package and gate it at 1e-10.  Two gaps
* remained (2026-09-02 audit, FG-09): there was no clustered delayed-entry CIF
* check at all, and the coefficient reconstruction consumes the package's own
* residual routine, so a defect inside that routine is invisible to it.
*
* An external identity would close both, and it is not available.  Every source
* in the corpus was read for one and none supplies it:
*
*   Fine & Gray (1999) sec. 5, p.501    The CIF prediction limit J1{t;z0} is
*                                       "quite complicated" and is NOT obtained
*                                       analytically; their confidence bands are
*                                       produced by SIMULATION (multiplier
*                                       bootstrap with iid standard normals).
*                                       There is no closed-form CIF influence
*                                       function in the founding paper.
*   Zhou, Fine, Latouche & Labopin      p.377, verbatim: "The variance is rather
*   (2012), the paper that grounds      complicated, with bootstrapping providing
*   cluster()                           practicable inferences for F_1(t, Z0)."
*                                       The authors of the clustered estimator
*                                       supply no closed-form CIF variance even
*                                       under RIGHT CENSORING, and recommend the
*                                       bootstrap.
*   Geskus (2011) sec. 3.2, p.43-44     The "no sandwich needed" argument and
*                                       eq. (21) are about the COEFFICIENT
*                                       information matrix.  No CIF variance.
*   Zhang, Zhang & Fine (2011) App. B   W-hat^(1)_{beta,i} = l_i + v_i + w_i is
*                                       the COEFFICIENT influence function under
*                                       delayed entry.  No CIF term.
*   Zhou et al. (2011) sec. 4-5         Stratified baseline; the CIF is declared
*                                       infeasible in the highly-stratified
*                                       regime and no CIF variance is given for
*                                       the regular one.
*
* So there is no sourced influence-function form for the CIF under clustering,
* and a fortiori none under clustering PLUS left truncation.  A 1e-8 identity
* gate is therefore not writable, and this file does the only other thing that
* is evidence: it CALIBRATES the reported standard error against the sampling
* distribution it claims to describe, on a DGP whose marginal truth is exact.
*
* The scope disclaimer at finegray_methods.sthlp ("treat clustered delayed-entry
* and clustered stratified standard errors as an implementation of the natural
* extension, not as a result established in the cited literature") therefore
* STAYS.  What this file adds is that the extension is now calibrated rather
* than only asserted.
*
* ---------------------------------------------------------------------------
* THE DGP AND ITS EXACT MARGINAL TRUTH
* ---------------------------------------------------------------------------
* Zhou et al. (2012) sec. 4.1, p.377: a POSITIVE-STABLE(alpha) shared frailty on
* the subdistribution hazard is the construction under which the marginal model
* is again proportional-subdistribution-hazards.  Conditional on the cluster
* frailty V and a cluster-constant covariate z, the generator below draws
*
*     F1(t | z, V) = 1 - exp{ -V exp(tau1 z) (1 - exp(-t)) }
*
* (subdistribution hazard V exp(tau1 z) exp(-t): proportional in z with
* coefficient tau1).  A positive-stable(alpha) law has E{exp(-sV)} =
* exp(-s^alpha), so integrating V out gives the MARGINAL cumulative incidence in
* closed form:
*
*     F1(t | z) = 1 - exp{ - exp(beta z) (1 - exp(-t))^alpha },   beta = alpha*tau1
*
* which is again a Fine-Gray model, with marginal coefficient beta and marginal
* baseline Lambda_10(t) = (1 - exp(-t))^alpha.  That closed form is this file's
* known truth, and gate G0 below verifies it against a large uncensored,
* untruncated simulation rather than trusting the algebra.
*
* Left truncation is added independently of everything else (entry = 0 with
* probability LTP, otherwise uniform on [0, LTMAX], and a subject whose entry
* reaches its exit is not sampled), which is the standard left-truncation
* sampling under L independent of T.  The ZZF/Geskus weight is consistent for
* the POPULATION F1 above, so the truth is unchanged by the truncation.
*
* ---------------------------------------------------------------------------
* PRE-REGISTERED PASS RULE -- fixed BEFORE the study was run
* ---------------------------------------------------------------------------
* What was known in advance: a 10-replication timing pilot (0.17 s/replication,
* n ~ 1220) and, from ONE of those replications, that the clustered analytic CIF
* SE was larger than the unclustered one (0.0241 vs 0.0190 at t = 0.15).  No
* SE/SD ratio and no coverage had been computed when the rules below were
* written.
*
* B = 1.96 * sqrt(0.95 * 0.05 / NREP) is the Monte Carlo standard error bound on
* a 95% coverage proportion; every coverage band below is 0.95 +/- B, computed
* from NREP rather than chosen.
*
*   ARM F -- shared positive-stable frailty, cluster-constant covariate
*     R1  ratio_cl(h) = mean(analytic clustered SE) / SD(CIF-hat) lies in
*         [0.90, 1.10] at every horizon h.                      [PRIMARY]
*     R2  coverage of the clustered 95% CI lies in 0.95 +/- B at every horizon.
*                                                               [PRIMARY]
*     R3  mean(clustered SE) / mean(unclustered SE) > 1.10 at every horizon.
*                                                          [DISCRIMINATION]
*     R4  ratio_naive(h) < 0.90 at every horizon AND the unclustered coverage
*         falls below 0.95 - B at at least one horizon.        [DISCRIMINATION]
*     R7  |mean(CIF-hat) - truth| < 0.5 * SD(CIF-hat) at every horizon, so R1
*         and R2 are statements about the standard error and not about a biased
*         point estimate.
*
*   ARM I -- identical cluster sizes and identical marginal law, but each
*            subject draws its OWN frailty and covariate, so cluster membership
*            carries no dependence
*     R5  ratio_cl(h) AND ratio_naive(h) both lie in [0.90, 1.10], both
*         coverages lie in 0.95 +/- B, and
*         |mean(clustered SE)/mean(unclustered SE) - 1| < 0.05, at every
*         horizon.  This is what stops R1-R4 from being satisfied by a clustered
*         SE that is simply always larger.
*
*   BOTH ARMS
*     R6  at least 0.98 * NREP replications must be usable; drops are counted by
*         cause and printed.  A study that silently conditions on the
*         replications that survived is not a coverage study.
*
* R3 and R4 are the reason this file discriminates: without them a build that
* ignored cluster() entirely could satisfy R1 and R2 on a fixture where the
* dependence was too weak to matter.
*
* ---------------------------------------------------------------------------
* MEASURED 2026-09-04 (Stata 17 MP, mt64, NREP = 1200, runtime 5m29s)
* ---------------------------------------------------------------------------
* Recorded AFTER the rules above were fixed, and reproduced by every run.
*
*   ARM F, 1200/1200 replications used, mean n = 1210
*     t     truth     mean CIF   MC SD    ratio_cl  ratio_naive  cov_cl  cov_nv
*     0.15  0.38074   0.37932    0.02333   1.0316     0.8014     0.9508   ~0.84
*     0.40  0.52158   0.52098    0.02369   1.0046     0.7723     0.9558   ~0.83
*     0.90  0.62810   0.62806    0.02266   1.0022     0.7755     0.9542   ~0.83
*
*   ARM I, 1200/1200 replications used
*     0.15  0.38074   0.38051    0.01878   0.9946     0.9968     0.9567
*     0.40  0.52158   0.52113    0.01852   0.9873     0.9888     0.9567
*     0.90  0.62810   0.62787    0.01751   1.0031     1.0046     0.9533
*
* So on this DGP the clustered analytic CIF standard error is calibrated to
* within 3% of the sampling standard deviation and covers at nominal, while the
* unclustered one is 20-23% too small and undercovers by about 12 points -- and
* the two coincide, and both cover, once the within-cluster dependence is
* removed.  That is a calibration result, not an identity: it says the extension
* behaves, not that it equals a published formula, because no published formula
* for this quantity exists.

clear all
set varabbrev off
version 16.0
set rng mt64

capture log close _all
log using "validation_finegray_lt_cluster_cif_se.log", replace text name(_ltccif)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qadir "`c(pwd)'"
local pkg_dir = regexr("`qadir'", "/qa$", "")
capture confirm file "`pkg_dir'/finegray.pkg"
if _rc {
    display as error "validation_finegray_lt_cluster_cif_se.do must run from finegray/qa"
    capture log close _ltccif
    exit 601
}
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

* --- study constants ---------------------------------------------------------
* NREP is a local so the study size is one edit, and the coverage bands below
* are derived from it rather than written as fixed numbers.  1200 replications
* x 2 arms x 2 fits runs in about 7 minutes at n ~ 1220, which is why this file
* is in the `core' lane rather than in `gates'.
local NREP    = 1200
local NCLUST  = 500
local ALPHA   = 0.5
local BETA    = 0.5
local GAMMA   = 0.7
local BETA2   = 0.3
local ZPROF   = 0.5
local HORIZ   0.15 0.40 0.90
local NH : word count `HORIZ'
local MCSEB = 1.96 * sqrt(0.95 * 0.05 / `NREP')
local SEED_F = 20260904
local SEED_I = 20260905
local SEED_G = 20260906

display as text _newline "finegray clustered delayed-entry CIF SE calibration"
display as text "  NREP = `NREP', clusters = `NCLUST', alpha = `ALPHA', beta = `BETA'"
display as text "  horizons: `HORIZ'   profile: z = `ZPROF'"
display as text "  coverage band: 0.95 +/- " %6.4f `MCSEB' ///
    " (1.96*sqrt(.95*.05/`NREP'))"

* --- the generator -----------------------------------------------------------
* design(shared)  one frailty and one covariate per CLUSTER (Zhou et al. 2012
*                 sec. 4.1's cluster-constant design)
* design(indep)   one frailty and one covariate per SUBJECT; the cluster ids and
*                 the cluster-size distribution are identical, so the two arms
*                 differ in dependence and in nothing else
capture program drop _fgltc_dgp
program define _fgltc_dgp
    syntax , CLUSTERS(integer) ALPHA(real) GAMMA(real) BETA(real) ///
        [BETA2(real 0.3) DESIGN(string) LTMAX(real 0.6) LTP(real 0.4)]
    if "`design'" == "" local design "shared"
    if !inlist("`design'", "shared", "indep") {
        display as error "design() must be shared or indep"
        exit 198
    }
    if !inrange(`alpha', 0.01, 0.99) | !inrange(`gamma', 0.01, 0.99) {
        display as error "alpha and gamma must lie strictly between zero and one"
        exit 198
    }
    quietly {
        clear
        set obs `clusters'
        gen long clid = _n
        * stata-dev-ignore: unseeded-draw — this is a generator PROGRAM, not a script: every call site seeds first (`set seed `SEED_G'' before G0's draws, `set seed `seed'' at the top of _fgltc_run before each arm's replication loop), so every draw in this file replays from SEED_G/SEED_F/SEED_I
        gen byte m = 2 + floor(4*runiform())
        expand m
        bysort clid: gen byte member = _n

        * Positive-stable(alpha) via Chambers-Mallows-Stuck.  Drawn once per
        * cluster under design(shared) and once per subject under design(indep).
        gen double av = c(pi)*max(runiform(), 1e-12)
        gen double ev = -ln(max(runiform(), 1e-12))
        gen double v = (sin(`alpha'*av)/(sin(av)^(1/`alpha'))) * ///
            (sin((1-`alpha')*av)/ev)^((1-`alpha')/`alpha')
        gen double ah = c(pi)*max(runiform(), 1e-12)
        gen double eh = -ln(max(runiform(), 1e-12))
        gen double h = (sin(`gamma'*ah)/(sin(ah)^(1/`gamma'))) * ///
            (sin((1-`gamma')*ah)/eh)^((1-`gamma')/`gamma')
        gen double z = rnormal()
        if "`design'" == "shared" {
            by clid: replace v = v[1]
            by clid: replace h = h[1]
            by clid: replace z = z[1]
        }

        local tau1 = `beta'/`alpha'
        local tau2 = `beta2'/`gamma'
        gen double p1 = 1 - exp(-v*exp(`tau1'*z))
        gen byte cause = cond(runiform() < p1, 1, 2)
        gen double u1 = runiform()
        gen double m1 = -ln(1-u1*p1)/(v*exp(`tau1'*z))
        replace m1 = min(m1, 1-1e-12)
        gen double t1 = -ln(1-m1)
        gen double t2 = -ln(max(runiform(), 1e-12))/(h*exp(`tau2'*z))
        gen double tevent = cond(cause == 1, t1, t2)
        gen double censor = 0.3 + 1.2*runiform()
        gen double time = min(tevent, censor)
        gen byte status = cond(tevent <= censor, cause, 0)
        gen byte anyevent = status != 0
        * Left truncation, independent of everything: a subject whose entry
        * reaches its exit is never sampled.
        gen double entry = cond(runiform() < `ltp', 0, `ltmax'*runiform())
        drop if entry >= time
        gen long sid = _n
        drop m member av ev ah eh p1 u1 m1 t1 t2 tevent censor
    }
end

* =============================================================================
* G0. The closed-form marginal CIF is what the generator actually produces
* =============================================================================
* The whole study's truth rests on integrating the positive-stable frailty out.
* Check the algebra against the generator itself, with no censoring and no
* truncation, at a covariate value the study uses.  Also check the generator's
* defining Laplace transform, so a wrong stable draw cannot make G0 pass by
* cancelling against a wrong integral.
local ++test_count
capture noisily {
    clear
    set seed `SEED_G'
    set obs 400000
    local tau1 = `BETA'/`ALPHA'
    gen double av = c(pi)*max(runiform(), 1e-12)
    gen double ev = -ln(max(runiform(), 1e-12))
    gen double v = (sin(`ALPHA'*av)/(sin(av)^(1/`ALPHA'))) * ///
        (sin((1-`ALPHA')*av)/ev)^((1-`ALPHA')/`ALPHA')
    * E{exp(-sV)} = exp(-s^alpha)
    foreach s in 0.5 1 2 {
        gen double lap = exp(-`s'*v)
        quietly summarize lap, meanonly
        local lerr = abs(r(mean) - exp(-(`s'^`ALPHA')))
        display as text "    G0 Laplace s=`s': error = " as result %9.2e `lerr'
        assert !missing(`lerr')
        assert `lerr' < 0.004
        drop lap
    }
    * The conditional generator, uncensored and untruncated, at z = ZPROF
    gen double z = `ZPROF'
    gen double p1 = 1 - exp(-v*exp(`tau1'*z))
    gen byte cause = cond(runiform() < p1, 1, 2)
    gen double u1 = runiform()
    gen double m1 = -ln(1-u1*p1)/(v*exp(`tau1'*z))
    replace m1 = min(m1, 1-1e-12)
    gen double t1 = -ln(1-m1)
    gen double tobs = cond(cause == 1, t1, 999)
    foreach hh of local HORIZ {
        local truth = 1 - exp(-exp(`BETA'*`ZPROF')*(1-exp(-`hh'))^`ALPHA')
        quietly count if cause == 1 & tobs <= `hh'
        local emp = r(N)/_N
        local g0err = abs(`emp' - `truth')
        display as text "    G0 marginal CIF at t=`hh': empirical = " ///
            as result %7.5f `emp' as text ", closed form = " ///
            as result %7.5f `truth' as text ", |diff| = " as result %9.2e `g0err'
        assert !missing(`emp', `truth')
        * 3 Monte Carlo SEs of a proportion at n = 400,000 is about 0.0024
        assert `g0err' < 0.004
    }
}
if _rc == 0 {
    display as result "  PASS: G0 closed-form marginal CIF matches the generator"
    local ++pass_count
}
else {
    display as error "  FAIL: G0 closed-form marginal CIF (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* The replication engine
* =============================================================================
* One pass per arm.  Each replication fits the SAME data twice -- once with
* cluster(clid) and once without -- so the clustered and unclustered standard
* errors describe the same estimate and the same sample, and the contrast
* between them is not a sampling artefact.
capture program drop _fgltc_run
program define _fgltc_run, rclass
    syntax , NREP(integer) CLUSTERS(integer) ALPHA(real) GAMMA(real) ///
        BETA(real) BETA2(real) ZPROF(real) SEED(integer) ///
        DESIGN(string) HORIZ(numlist)
    local nh : word count `horiz'

    tempname pf
    tempfile res
    local pvars ""
    forvalues k = 1/`nh' {
        local pvars "`pvars' cif`k' secl`k' senv`k' cvcl`k' cvnv`k'"
    }
    postfile `pf' `pvars' using "`res'", replace

    * Declared ONCE, not inside the loop: a tempname minted per replication
    * would leave NREP x 2 matrices alive until the program returned.
    tempname CC NN

    local drop_fit = 0
    local drop_cif = 0
    local drop_conv = 0
    local used = 0
    local nsum = 0

    set seed `seed'
    forvalues r = 1/`nrep' {
        _fgltc_dgp, clusters(`clusters') alpha(`alpha') gamma(`gamma') ///
            beta(`beta') beta2(`beta2') design(`design')
        quietly count
        local nsum = `nsum' + r(N)
        quietly stset time, failure(anyevent == 1) enter(entry) id(sid)

        capture quietly finegray z, compete(status) cause(1) cluster(clid) nolog
        if _rc != 0 {
            local ++drop_fit
            continue
        }
        if e(converged) != 1 {
            local ++drop_conv
            continue
        }
        capture quietly finegray_cif, at(z=`zprof') attime(`horiz') ci nograph
        if _rc != 0 {
            local ++drop_cif
            continue
        }
        if `"`r(se_method)'"' != "analytic" {
            local ++drop_cif
            continue
        }
        matrix `CC' = r(table)

        capture quietly finegray z, compete(status) cause(1) nolog
        if _rc != 0 {
            local ++drop_fit
            continue
        }
        capture quietly finegray_cif, at(z=`zprof') attime(`horiz') ci nograph
        if _rc != 0 {
            local ++drop_cif
            continue
        }
        matrix `NN' = r(table)

        * Both tables must carry finite content on every requested horizon, or
        * the replication is a drop rather than a datum: reldif and inequality
        * comparisons downstream are satisfied by missing values.
        local bad = 0
        forvalues k = 1/`nh' {
            if missing(`CC'[`k',2], `CC'[`k',3], `CC'[`k',4], `CC'[`k',5], ///
                       `NN'[`k',3], `NN'[`k',4], `NN'[`k',5]) local bad = 1
            if `CC'[`k',3] <= 0 | `NN'[`k',3] <= 0 local bad = 1
        }
        if `bad' {
            local ++drop_cif
            continue
        }

        local plist ""
        forvalues k = 1/`nh' {
            local hh : word `k' of `horiz'
            local truth = 1 - exp(-exp(`beta'*`zprof')*(1-exp(-`hh'))^`alpha')
            local cvc = (`CC'[`k',4] <= `truth') & (`truth' <= `CC'[`k',5])
            local cvn = (`NN'[`k',4] <= `truth') & (`truth' <= `NN'[`k',5])
            local plist "`plist' (`=`CC'[`k',2]') (`=`CC'[`k',3]') (`=`NN'[`k',3]') (`cvc') (`cvn')"
        }
        post `pf' `plist'
        local ++used
    }
    postclose `pf'

    return scalar used = `used'
    return scalar drop_fit = `drop_fit'
    return scalar drop_cif = `drop_cif'
    return scalar drop_conv = `drop_conv'
    return scalar nmean = `nsum'/`nrep'
    return local resfile "`res'"
    * The postfile is a tempfile owned by this program's frame, so hand the
    * caller the summarised numbers rather than the path alone.
    use "`res'", clear
    forvalues k = 1/`nh' {
        quietly summarize cif`k'
        return scalar cifmean`k' = r(mean)
        return scalar cifsd`k'   = r(sd)
        quietly summarize secl`k'
        return scalar seclmean`k' = r(mean)
        quietly summarize senv`k'
        return scalar senvmean`k' = r(mean)
        quietly summarize cvcl`k'
        return scalar covcl`k' = r(mean)
        quietly summarize cvnv`k'
        return scalar covnv`k' = r(mean)
    }
end

* =============================================================================
* ARM F -- shared frailty, cluster-constant covariate
* =============================================================================
display as text _newline "  ARM F: shared positive-stable frailty, cluster-constant covariate"
_fgltc_run, nrep(`NREP') clusters(`NCLUST') alpha(`ALPHA') gamma(`GAMMA') ///
    beta(`BETA') beta2(`BETA2') zprof(`ZPROF') seed(`SEED_F') ///
    design(shared) horiz(`HORIZ')

local F_used = r(used)
local F_dfit = r(drop_fit)
local F_dcif = r(drop_cif)
local F_dcon = r(drop_conv)
local F_nmean = r(nmean)
forvalues k = 1/`NH' {
    local F_cifm`k' = r(cifmean`k')
    local F_cifsd`k' = r(cifsd`k')
    local F_secl`k' = r(seclmean`k')
    local F_senv`k' = r(senvmean`k')
    local F_covcl`k' = r(covcl`k')
    local F_covnv`k' = r(covnv`k')
}

display as text "    mean n per replication = " %7.1f `F_nmean'
display as text "    replications used = `F_used' of `NREP'" ///
    "  (repdrop= fit `F_dfit', converge `F_dcon', cif `F_dcif')"
forvalues k = 1/`NH' {
    local hh : word `k' of `HORIZ'
    local truth = 1 - exp(-exp(`BETA'*`ZPROF')*(1-exp(-`hh'))^`ALPHA')
    display as text "    t=`hh'  truth=" %7.5f `truth' ///
        "  mean CIF=" %7.5f `F_cifm`k'' "  MC SD=" %7.5f `F_cifsd`k'' ///
        "  SE_cl=" %7.5f `F_secl`k'' "  SE_naive=" %7.5f `F_senv`k''
    display as text "           ratio_cl=" %6.4f (`F_secl`k''/`F_cifsd`k'') ///
        "  ratio_naive=" %6.4f (`F_senv`k''/`F_cifsd`k'') ///
        "  cover_cl=" %6.4f `F_covcl`k'' "  cover_naive=" %6.4f `F_covnv`k''
}

* R6 (arm F)
local ++test_count
capture noisily {
    assert !missing(`F_used')
    assert `F_used' >= 0.98 * `NREP'
    assert `F_used' + `F_dfit' + `F_dcon' + `F_dcif' == `NREP'
}
if _rc == 0 {
    display as result "  PASS: R6/F replication attrition within the pre-registered bound"
    local ++pass_count
}
else {
    display as error "  FAIL: R6/F replication attrition (rc=`=_rc')"
    local ++fail_count
}

* R7 (arm F) -- bias small relative to sampling noise
local ++test_count
capture noisily {
    forvalues k = 1/`NH' {
        local hh : word `k' of `HORIZ'
        local truth = 1 - exp(-exp(`BETA'*`ZPROF')*(1-exp(-`hh'))^`ALPHA')
        assert !missing(`F_cifm`k'', `F_cifsd`k'')
        assert `F_cifsd`k'' > 0
        assert abs(`F_cifm`k'' - `truth') < 0.5 * `F_cifsd`k''
    }
}
if _rc == 0 {
    display as result "  PASS: R7/F CIF bias below half a Monte Carlo SD at every horizon"
    local ++pass_count
}
else {
    display as error "  FAIL: R7/F CIF bias (rc=`=_rc')"
    local ++fail_count
}

* R1 (arm F) -- the primary calibration
local ++test_count
capture noisily {
    forvalues k = 1/`NH' {
        assert !missing(`F_secl`k'', `F_cifsd`k'')
        assert `F_secl`k'' > 0 & `F_cifsd`k'' > 0
        assert inrange(`F_secl`k''/`F_cifsd`k'', 0.90, 1.10)
    }
}
if _rc == 0 {
    display as result "  PASS: R1/F clustered analytic SE / Monte Carlo SD in [0.90, 1.10]"
    local ++pass_count
}
else {
    display as error "  FAIL: R1/F clustered SE calibration (rc=`=_rc')"
    local ++fail_count
}

* R2 (arm F) -- the primary coverage
local ++test_count
capture noisily {
    forvalues k = 1/`NH' {
        assert !missing(`F_covcl`k'')
        assert inrange(`F_covcl`k'', 0.95 - `MCSEB', 0.95 + `MCSEB')
    }
}
if _rc == 0 {
    display as result "  PASS: R2/F clustered 95% CI coverage within the MCSE band"
    local ++pass_count
}
else {
    display as error "  FAIL: R2/F clustered coverage (rc=`=_rc')"
    local ++fail_count
}

* R3 + R4 (arm F) -- the discrimination
local ++test_count
capture noisily {
    local nunder = 0
    forvalues k = 1/`NH' {
        assert !missing(`F_senv`k'', `F_covnv`k'')
        assert `F_senv`k'' > 0
        assert `F_secl`k''/`F_senv`k'' > 1.10
        assert `F_senv`k''/`F_cifsd`k'' < 0.90
        if `F_covnv`k'' < 0.95 - `MCSEB' local ++nunder
    }
    assert `nunder' >= 1
}
if _rc == 0 {
    display as result "  PASS: R3+R4/F the unclustered SE is measurably too small and undercovers"
    local ++pass_count
}
else {
    display as error "  FAIL: R3+R4/F discrimination (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* ARM I -- independent subjects, identical cluster sizes and marginal law
* =============================================================================
display as text _newline "  ARM I: per-subject frailty and covariate (no within-cluster dependence)"
_fgltc_run, nrep(`NREP') clusters(`NCLUST') alpha(`ALPHA') gamma(`GAMMA') ///
    beta(`BETA') beta2(`BETA2') zprof(`ZPROF') seed(`SEED_I') ///
    design(indep) horiz(`HORIZ')

local I_used = r(used)
local I_dfit = r(drop_fit)
local I_dcif = r(drop_cif)
local I_dcon = r(drop_conv)
local I_nmean = r(nmean)
forvalues k = 1/`NH' {
    local I_cifm`k' = r(cifmean`k')
    local I_cifsd`k' = r(cifsd`k')
    local I_secl`k' = r(seclmean`k')
    local I_senv`k' = r(senvmean`k')
    local I_covcl`k' = r(covcl`k')
    local I_covnv`k' = r(covnv`k')
}

display as text "    mean n per replication = " %7.1f `I_nmean'
display as text "    replications used = `I_used' of `NREP'" ///
    "  (repdrop= fit `I_dfit', converge `I_dcon', cif `I_dcif')"
forvalues k = 1/`NH' {
    local hh : word `k' of `HORIZ'
    local truth = 1 - exp(-exp(`BETA'*`ZPROF')*(1-exp(-`hh'))^`ALPHA')
    display as text "    t=`hh'  truth=" %7.5f `truth' ///
        "  mean CIF=" %7.5f `I_cifm`k'' "  MC SD=" %7.5f `I_cifsd`k'' ///
        "  SE_cl=" %7.5f `I_secl`k'' "  SE_naive=" %7.5f `I_senv`k''
    display as text "           ratio_cl=" %6.4f (`I_secl`k''/`I_cifsd`k'') ///
        "  ratio_naive=" %6.4f (`I_senv`k''/`I_cifsd`k'') ///
        "  cover_cl=" %6.4f `I_covcl`k'' "  cover_naive=" %6.4f `I_covnv`k''
}

* R6 (arm I)
local ++test_count
capture noisily {
    assert !missing(`I_used')
    assert `I_used' >= 0.98 * `NREP'
    assert `I_used' + `I_dfit' + `I_dcon' + `I_dcif' == `NREP'
}
if _rc == 0 {
    display as result "  PASS: R6/I replication attrition within the pre-registered bound"
    local ++pass_count
}
else {
    display as error "  FAIL: R6/I replication attrition (rc=`=_rc')"
    local ++fail_count
}

* R5 (arm I) -- the control
local ++test_count
capture noisily {
    forvalues k = 1/`NH' {
        assert !missing(`I_secl`k'', `I_senv`k'', `I_cifsd`k'', `I_covcl`k'', `I_covnv`k'')
        assert `I_cifsd`k'' > 0 & `I_secl`k'' > 0 & `I_senv`k'' > 0
        assert inrange(`I_secl`k''/`I_cifsd`k'', 0.90, 1.10)
        assert inrange(`I_senv`k''/`I_cifsd`k'', 0.90, 1.10)
        assert abs(`I_secl`k''/`I_senv`k'' - 1) < 0.05
        assert inrange(`I_covcl`k'', 0.95 - `MCSEB', 0.95 + `MCSEB')
        assert inrange(`I_covnv`k'', 0.95 - `MCSEB', 0.95 + `MCSEB')
    }
}
if _rc == 0 {
    display as result "  PASS: R5/I clustered and unclustered SEs agree and both cover when subjects are independent"
    local ++pass_count
}
else {
    display as error "  FAIL: R5/I independence control (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
capture program drop _fgltc_run
capture program drop _fgltc_dgp

display _newline as text ///
    "RESULT: validation_finegray_lt_cluster_cif_se tests=`test_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 {
    display as error "validation_finegray_lt_cluster_cif_se: `fail_count' check(s) FAILED"
    capture log close _ltccif
    exit 9
}

display as result ///
    "validation_finegray_lt_cluster_cif_se: the clustered delayed-entry analytic CIF SE is calibrated on this DGP"
capture log close _ltccif
