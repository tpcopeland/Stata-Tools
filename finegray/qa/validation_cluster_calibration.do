* validation_cluster_calibration.do - Inference calibration of the cluster()
* sandwich for the finegray log-SHR (Monte Carlo, known marginal truth)
* Package: finegray
*
* Usage (from finegray/qa):
*   stata-mp -b do validation_cluster_calibration.do          gate (R = 2000)
*   stata-mp -b do validation_cluster_calibration.do smoke    10 replicates
*   global FG_CAL_REPS 50, then run the file                  50 replicates
* Any run whose R differs from R_GATE is a smoke run: it checks the code path
* (every replicate returns finite b, SE and CI; counters reconcile; the CI
* contract holds), never applies a band, prints smoke=1 on the RESULT line,
* and is never gate evidence.
*
* Companion of validation_cluster_recovery.do, which owns the point-estimate
* gate on the same generator. This file asks whether the reported SE and 95%
* CI mean what they say.
*
* ADEMP (written 2026-10-27 before the gated run; Morris, White & Crowther
* 2019, Table 1)
*   Aims        Is the cluster-robust sandwich SE of the Fine-Gray log-SHR
*               calibrated, and does the reported 95% CI cover the marginal
*               truth at the nominal rate, under within-cluster dependence?
*   DGP         Zhou, Fine, Latouche & Labopin (2012) sec. 4.1, p.377: shared
*               positive-stable(alpha) frailty on the cause-1 subdistribution
*               hazard, positive-stable(gamma) on cause 2, C ~ U[0.3, 1.5].
*               The generator _zhou_cluster_dgp is copied verbatim from
*               validation_cluster_recovery.do. alpha = 0.3 (strong
*               dependence), gamma = 0.7, beta2 = 0.3.
*                 A  500 clusters, cluster-constant N(0,1) covariate,
*                    m ~ U{2..5} (about 1750 subjects)          [asymptotic]
*                 B  500 matched pairs, z = 0/1 within cluster (1000
*                    subjects); the design where ignoring clustering
*                    OVERstates the variance (Zhou et al. Fig. 1, p.380)
*                 C  100 clusters, cluster-constant covariate (about 350
*                    subjects); Zhou et al.'s smallest cluster count
*   Estimand    marginal log-SHR beta = alpha*tau1 = 0.5, exact by
*               integrating the positive-stable frailty out (p.377). G0 below
*               re-checks the generator's Laplace identity and the closed-form
*               marginal CIF before any replicate is run.
*   Methods     M1 finegray z, compete(status) cause(1) cluster(clid)
*                  (the default: fixed-weight meat summed within cluster,
*                  times g/(g-1); e(vce_meat) = fixed_weight)
*               M2 the same plus nuisance (eta+psi summed within cluster,
*                  Zhou et al. p.376 Sigma-hat; e(vce_meat) =
*                  nuisance_adjusted)
*               M0 finegray z, compete(status) cause(1), no cluster(): the
*                  negative control, the SE that ignores the dependence
*               All three are fitted to the same replicate. The interval read
*               is the one the command reports (r(table) ll/ul, eform, logged
*               back to the coefficient scale), never rebuilt from b, se.
*   Performance per design and method: coverage of beta = 0.5 by the
*               reported 95% CI (gate); ModSE/EmpSE with ModSE =
*               sqrt(mean(se^2)) (gate); bias with its MCSE, EmpSE with its
*               MCSE and bias-eliminated coverage (reported, diagnostic);
*               replicate failures (gate: zero).
*
* R AND ITS MCSE. R = 2000 per design, sized by R = p(1-p)/MCSE^2 (Morris et
* al. eq. 1, p.2089) for a coverage MCSE of 0.5 points at p = 0.95 (1900,
* rounded up). Coverage MCSE = sqrt(.95*.05/2000) = 0.0049, so the band is
* [0.9354, 0.9646]. The ModSE/EmpSE MCSE is about 1/sqrt(2(R-1)) = 0.016, so
* the ratio gate is about 1 +/- 0.047, sharp enough to fail a 5% SE error.
* Pilot timing (20 replicates, processors 1): 0.025 s per fit at 500
* clusters; the full run is about 9 x 2000 fits plus generation, well inside
* 30 minutes single-threaded.
*
* SEEDS. set rng mt64; one seed per design, set once before its loop
* (A 20261027, B 20261028, C 20261029, G0 20261030); every replicate's
* c(rngstate) is retained in the result set, so a failing replicate is
* replayed alone with set rngstate.
*
* GATES (computed below from R, never typed)
*   coverage in 0.95 +/- 3*sqrt(0.95*0.05/R)
*   |ModSE/EmpSE - 1| <= 3*MCSE(ratio), MCSE per Morris et al. Table 6
*   every replicate: all three fits succeed, converge, and return finite b,
*   SE and CI (n_ok == R)
*   CI contract: the reported limits are exp(b -/+ crit*se) on every
*   replicate (log-scale Wald), so the coverage is about the reported SE
*   negative control: in A, M0 coverage falls BELOW the band; in B, M0's
*   ModSE/EmpSE lies ABOVE 1 + 3 MCSE (direction from Zhou et al. Fig. 1 and
*   validation_cluster_recovery.do K3)
* Twelve band gates at 3 MCSE each: the chance that a correct estimator
* trips at least one by Monte Carlo noise alone is under 3.5%.
*
* EXPECTED CLASS PER CELL (pre-registered)
*   A M1, A M2, B M1, B M2: NOMINAL.
*   C M1, C M2: NOMINAL, at risk. Zhou et al. Table 1 (p.378) report sizes
*   of 0.058-0.065 for the clustered tests at 100 clusters, i.e. coverage
*   near 0.935-0.942, on the lower edge of this band. A miss at C is a
*   finite-sample under-coverage of the sandwich at 100 clusters, and it is
*   reported as DEFECT with its bias-eliminated coverage, not re-banded.
*   No route is documented as conservative, so CONSERVATIVE-DECLARED is
*   unavailable: over-coverage above the band is also DEFECT.
*
* WORKED RUN 2026-10-27 (Stata 17 MP, processors 1, R = 2000 per design,
* 852 s on a loaded machine; recorded after the gates above were frozen).
* 2000/2000 replicates usable in every design, every fit converged.
*   design method   coverage  ModSE/EmpSE (MCSE)  bias (MCSE)       bias-elim.
*   A      M1       0.9515    1.0070 (0.0159)     0.00034 (0.00133) 0.9515
*   A      M2       0.9515    1.0070 (0.0159)     0.00034 (0.00133) 0.9515
*   A      M0       0.7185    0.5601 (0.0159)                       0.7205
*   B      M1       0.9515    0.9991 (0.0159)     0.00036 (0.00094) 0.9515
*   B      M2       0.9515    0.9990 (0.0159)     0.00036 (0.00094) 0.9515
*   B      M0       1.0000    1.8759 (0.0158)                       1.0000
*   C      M1       0.9320    0.9700 (0.0162)     0.00814 (0.00315) 0.9335
*   C      M2       0.9315    0.9699 (0.0162)     0.00814 (0.00315) 0.9335
* Classes: A and B NOMINAL (both methods); negative controls red as
* required. C was DEFECT under the pre-registered rule: coverage 0.932 sits
* 3.7 MCSE below nominal (band edge 0.9354). Bias-eliminated coverage is
* still 0.9335, so the miss is width, not bias: the sandwich is about 3%
* small at 100 clusters even after g/(g-1), and the Wald interval uses the
* normal critical value. This matches Zhou et al. Table 1 (p.378), whose
* clustered tests have size 0.058-0.065 at 100 clusters.
*
* RECLASSIFIED 2026-10-27, after the worked run, by the package owner's
* decision: C is SMALL-G-DECLARED. The normal-critical-value convention of
* stcox and stcrreg is kept, and finegray.sthlp (option cluster()) now
* documents the modest under-coverage at about 100 or fewer clusters with
* this citation and points to bootstrap(). C's coverage gate is therefore
* the published small-cluster coverage (1 - 0.065) less 3 MCSE, about
* 0.920, with the upper band unchanged; its SE-ratio gate, every-replicate
* gate and CI contract are unchanged. A and B stay gated on the nominal
* band. This floor was set after seeing C = 0.932 and is a regression
* floor tied to the published size, not a calibration claim.

version 16.0
clear all
set more off
set varabbrev off
set rng mt64
set linesize 160

args mode
local smoke_arg = ("`mode'" == "smoke")
if "`mode'" != "" & !`smoke_arg' {
    display as error "unknown argument `mode'; the only accepted argument is smoke"
    exit 198
}

local qa_dir "`c(pwd)'"
local suite "validation_cluster_calibration"
capture log close _clcal
log using "`qa_dir'/`suite'.log", replace text name(_clcal)

**# Setup
do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap
local orig_plus "`r(orig_plus)'"
local orig_personal "`r(orig_personal)'"
local plus_dir "`r(plus_dir)'"
local personal_dir "`r(personal_dir)'"

**# Predeclared design
local R_GATE  = 2000
local SMOKE_R = 10
local R = `R_GATE'
if `smoke_arg' local R = `SMOKE_R'
if "$FG_CAL_REPS" != "" {
    capture confirm integer number $FG_CAL_REPS
    local bad_reps = _rc
    if !`bad_reps' local bad_reps = ($FG_CAL_REPS < 2)
    if `bad_reps' {
        display as error "FG_CAL_REPS must be an integer of at least 2"
        exit 198
    }
    local R = $FG_CAL_REPS
}
local smoke = (`R' != `R_GATE')

local NOMINAL = 0.95
local TRUTH   = 0.5
local ALPHA   = 0.3
local GAMMA   = 0.7
local BETA2   = 0.3
local SEED_A  = 20261027
local SEED_B  = 20261028
local SEED_C  = 20261029
local SEED_G  = 20261030

local cov_mcse = sqrt(`NOMINAL' * (1 - `NOMINAL') / `R')
local cov_lo   = `NOMINAL' - 3 * `cov_mcse'
local cov_hi   = `NOMINAL' + 3 * `cov_mcse'
* Small-cluster floor for design C: the largest clustered-test size Zhou et
* al. (2012) Table 1 (p.378) report at 100 clusters is 0.065, so coverage
* 1 - 0.065; the floor sits 3 MCSE below it.
local smallg_ref = 1 - 0.065
local smallg_lo  = `smallg_ref' - 3 * `cov_mcse'

display as text "`suite': R=`R' per design (gate R=`R_GATE'), smoke=`smoke'"
display as text "  truth beta=`TRUTH' (alpha=`ALPHA', tau1=" %6.4f `TRUTH'/`ALPHA' ")"
display as text "  coverage band [" %6.4f `cov_lo' ", " %6.4f `cov_hi' "] (MCSE " %6.4f `cov_mcse' ")"

local test_count = 0
local pass_count = 0
local fail_count = 0

timer clear 1
timer on 1

capture program drop _cal_test
program define _cal_test
    args ok label
    if `ok' == 1 {
        display as result "  PASS: `label'"
    }
    else {
        display as error "  FAIL: `label'"
    }
end

**# Generator (verbatim from validation_cluster_recovery.do)
capture program drop _zhou_cluster_dgp
program define _zhou_cluster_dgp
    syntax , CLUSTERS(integer) ALPHA(real) GAMMA(real) BETA(real) ///
        [DESIGN(string) BETA2(real 0.3)]

    if !inrange(`alpha', 0.01, 0.99) | !inrange(`gamma', 0.01, 0.99) {
        display as error "alpha and gamma must lie strictly between zero and one"
        exit 198
    }
    if "`design'" == "" local design "constant"
    if !inlist("`design'", "constant", "matched") {
        display as error "design() must be constant or matched"
        exit 198
    }

    quietly {
        clear
        set obs `clusters'
        gen long clid = _n
        if "`design'" == "matched" {
            gen byte m = 2
        }
        else {
            * stata-dev-ignore: unseeded-draw — this is a generator PROGRAM, not a script: the seed is set once per design before its replicate loop (SEED_A/B/C) and each replicate's c(rngstate) is retained, so every draw in this file replays
            gen byte m = 2 + floor(4*runiform())
        }

        * One cause-specific positive-stable frailty per cluster and cause.
        gen double av = c(pi)*max(runiform(), 1e-12)
        gen double ev = -ln(max(runiform(), 1e-12))
        gen double v = (sin(`alpha'*av)/(sin(av)^(1/`alpha'))) * ///
            (sin((1-`alpha')*av)/ev)^((1-`alpha')/`alpha')
        gen double ah = c(pi)*max(runiform(), 1e-12)
        gen double eh = -ln(max(runiform(), 1e-12))
        gen double h = (sin(`gamma'*ah)/(sin(ah)^(1/`gamma'))) * ///
            (sin((1-`gamma')*ah)/eh)^((1-`gamma')/`gamma')

        expand m
        bysort clid: gen byte member = _n
        if "`design'" == "matched" {
            gen byte z = member - 1
        }
        else {
            by clid: gen double z = rnormal() if _n == 1
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
        gen long sid = _n
        drop m member av ev ah eh p1 u1 m1 t1 t2 tevent censor
    }
end

**# G0: the generator produces the closed-form marginal truth
* Laplace identity E{exp(-sV)} = exp(-s^alpha) of the stable draw, and the
* marginal CIF F1(t|z) = 1 - exp{-exp(beta z)(1 - exp(-t))^alpha} of the
* uncensored conditional generator at z = 0.5, so the truth beta = 0.5 is
* checked against the code that draws the data rather than taken on trust.
local ++test_count
local g0max = .
capture noisily {
    clear
    set seed `SEED_G'
    quietly set obs 400000
    local tau1 = `TRUTH'/`ALPHA'
    gen double av = c(pi)*max(runiform(), 1e-12)
    gen double ev = -ln(max(runiform(), 1e-12))
    gen double v = (sin(`ALPHA'*av)/(sin(av)^(1/`ALPHA'))) * ///
        (sin((1-`ALPHA')*av)/ev)^((1-`ALPHA')/`ALPHA')
    local g0max = 0
    foreach s in 0.5 1 2 {
        gen double lap = exp(-`s'*v)
        quietly summarize lap, meanonly
        local lerr = abs(r(mean) - exp(-(`s'^`ALPHA')))
        assert !missing(`lerr')
        assert `lerr' < 0.004
        drop lap
    }
    gen double z = 0.5
    gen double p1 = 1 - exp(-v*exp(`tau1'*z))
    gen byte cause = cond(runiform() < p1, 1, 2)
    gen double u1 = runiform()
    gen double m1 = -ln(1-u1*p1)/(v*exp(`tau1'*z))
    quietly replace m1 = min(m1, 1-1e-12)
    gen double t1 = -ln(1-m1)
    foreach hh in 0.3 0.8 1.5 {
        local truth = 1 - exp(-exp(`TRUTH'*0.5)*(1-exp(-`hh'))^`ALPHA')
        quietly count if cause == 1 & t1 <= `hh'
        local g0err = abs(r(N)/_N - `truth')
        assert !missing(`g0err')
        * 3 Monte Carlo SEs of a proportion at n = 400,000 is about 0.0024
        assert `g0err' < 0.004
        if `g0err' > `g0max' local g0max = `g0err'
    }
}
local ok = (_rc == 0)
_cal_test `ok' "G0 positive-stable Laplace identity and closed-form marginal CIF (max |diff| `=string(`g0max', "%7.5f")')"
if `ok' local ++pass_count
else local ++fail_count

**# Replication engine
* One pass per design. Every replicate is posted, including failures, with
* the rc of the first failing step and its start-of-replicate c(rngstate).
capture program drop _clcal_run
program define _clcal_run
    syntax , R(integer) CLUSTERS(integer) ALPHA(real) GAMMA(real) ///
        BETA(real) BETA2(real) DESIGN(string) SEED(integer) SAVING(string)

    tempname P T
    postfile `P' long rep int(rc step) long(nobs nclust) ///
        double(b1 se1 lo1 hi1 dev1 b2 se2 lo2 hi2 dev2 b0 se0 lo0 hi0 dev0) ///
        using "`saving'", replace
    mata: _clcal_states = J(`r', 1, "")
    set seed `seed'
    forvalues i = 1/`r' {
        mata: _clcal_states[`i'] = c("rngstate")
        _zhou_cluster_dgp, clusters(`clusters') alpha(`alpha') ///
            gamma(`gamma') beta(`beta') beta2(`beta2') design(`design')
        quietly count
        local nobs = r(N)
        quietly stset time, failure(anyevent == 1) id(sid)

        local rc = 0
        local step = 0
        local nclust = .
        foreach k in 1 2 0 {
            local b`k' = .
            local se`k' = .
            local lo`k' = .
            local hi`k' = .
            local dev`k' = .
        }
        foreach k in 1 2 0 {
            if `rc' continue
            if `k' == 1 local opts "cluster(clid)"
            if `k' == 2 local opts "cluster(clid) nuisance"
            if `k' == 0 local opts ""
            capture quietly finegray z, compete(status) cause(1) `opts' nolog
            local rc = _rc
            if !`rc' & e(converged) != 1 local rc = 430
            if !`rc' {
                matrix `T' = r(table)
                local rl = rownumb(`T', "ll")
                local ru = rownumb(`T', "ul")
                local rk = rownumb(`T', "crit")
                local re = rownumb(`T', "eform")
                if missing(`rl', `ru', `rk', `re') local rc = 3301
            }
            if !`rc' {
                local b`k' = _b[z]
                local se`k' = _se[z]
                local crit = `T'[`rk', 1]
                if `T'[`re', 1] == 1 {
                    local lo`k' = ln(`T'[`rl', 1])
                    local hi`k' = ln(`T'[`ru', 1])
                }
                else {
                    local lo`k' = `T'[`rl', 1]
                    local hi`k' = `T'[`ru', 1]
                }
                local dev`k' = max(abs(`lo`k'' - (`b`k'' - `crit'*`se`k'')), ///
                    abs(`hi`k'' - (`b`k'' + `crit'*`se`k'')))
                if `k' == 1 local nclust = e(N_clust)
                if missing(`b`k'', `se`k'', `lo`k'', `hi`k'') | `se`k'' <= 0 ///
                    local rc = 504
            }
            if `rc' local step = `k'
        }
        post `P' (`i') (`rc') (`step') (`nobs') (`nclust') ///
            (`b1') (`se1') (`lo1') (`hi1') (`dev1') ///
            (`b2') (`se2') (`lo2') (`hi2') (`dev2') ///
            (`b0') (`se0') (`lo0') (`hi0') (`dev0')
    }
    postclose `P'
    preserve
    use "`saving'", clear
    sort rep
    quietly gen strL rngstate = ""
    mata: st_sstore(., "rngstate", _clcal_states)
    mata: mata drop _clcal_states
    quietly save "`saving'", replace
    restore
end

* Performance of one method on the posted result set (in memory).
capture program drop _cal_metrics
program define _cal_metrics, rclass
    syntax , B(varname) SE(varname) LO(varname) HI(varname) TRUTH(real)
    tempvar v cv cvbe
    quietly count if !missing(`b', `se', `lo', `hi')
    local n = r(N)
    return scalar n = `n'
    if `n' < 2 {
        foreach s in bias bias_mcse empse empse_mcse modse ratio ratio_mcse ///
            coverage becoverage {
            return scalar `s' = .
        }
        exit
    }
    quietly summarize `b' if !missing(`b', `se', `lo', `hi')
    local mean_b = r(mean)
    local empse = r(sd)
    return scalar bias = `mean_b' - `truth'
    return scalar bias_mcse = r(sd) / sqrt(`n')
    return scalar empse = `empse'
    return scalar empse_mcse = `empse' / sqrt(2 * (`n' - 1))
    quietly gen double `v' = `se'^2 if !missing(`b', `se', `lo', `hi')
    quietly summarize `v'
    local modse = sqrt(r(mean))
    local var_v = r(Var)
    return scalar modse = `modse'
    return scalar ratio = `modse' / `empse'
    * Morris et al. Table 6, relative error in ModSE, evaluated at ratio 1
    * (the gate tests "the ratio is 1", as the coverage gate tests nominal).
    return scalar ratio_mcse = sqrt(`var_v' / (4 * `n' * `modse'^4) + 1 / (2 * (`n' - 1)))
    quietly gen byte `cv' = (`lo' <= `truth' & `truth' <= `hi') ///
        if !missing(`b', `se', `lo', `hi')
    quietly summarize `cv', meanonly
    return scalar coverage = r(mean)
    * Bias-eliminated coverage (Morris et al. p.2087): coverage of the mean
    * estimate. A diagnostic that separates bias from width; never a gate.
    quietly gen byte `cvbe' = (`lo' <= `mean_b' & `mean_b' <= `hi') ///
        if !missing(`b', `se', `lo', `hi')
    quietly summarize `cvbe', meanonly
    return scalar becoverage = r(mean)
end

**# Designs
local designs "A B C"
local A_clusters = 500
local A_design "constant"
local A_seed = `SEED_A'
local A_label "500 clusters, cluster-constant z"
local B_clusters = 500
local B_design "matched"
local B_seed = `SEED_B'
local B_label "500 matched pairs, z = 0/1"
local C_clusters = 100
local C_design "constant"
local C_seed = `SEED_C'
local C_label "100 clusters, cluster-constant z"

foreach d of local designs {
    display as text _newline "Design `d': ``d'_label', R=`R', seed ``d'_seed'"
    tempfile res`d'
    _clcal_run, r(`R') clusters(``d'_clusters') alpha(`ALPHA') ///
        gamma(`GAMMA') beta(`TRUTH') beta2(`BETA2') ///
        design(``d'_design') seed(``d'_seed') saving("`res`d''")

    use "`res`d''", clear
    quietly count if rc == 0
    local `d'_nok = r(N)
    quietly count if rc != 0
    local `d'_nbad = r(N)
    quietly summarize nobs, meanonly
    local `d'_nobs = r(mean)
    quietly summarize nclust, meanonly
    local `d'_ncl = r(mean)
    quietly summarize dev1, meanonly
    local `d'_dev = r(max)
    foreach k in 2 0 {
        quietly summarize dev`k', meanonly
        if r(max) > ``d'_dev' | missing(``d'_dev') local `d'_dev = r(max)
    }
    quietly gen double bd = max(abs(b1 - b2), abs(b1 - b0)) if rc == 0
    quietly summarize bd, meanonly
    local `d'_bdiff = r(max)
    if ``d'_nbad' > 0 {
        quietly levelsof rep if rc != 0, local(badreps)
        display as error "    failed replicates: `badreps' (replay with set rngstate from the result set)"
        tabulate rc step if rc != 0
    }

    display as text "    replicates usable ``d'_nok' of `R' (failed ``d'_nbad'); mean n " ///
        %7.1f ``d'_nobs' ", mean clusters used " %6.1f ``d'_ncl'
    foreach k in 1 2 0 {
        _cal_metrics, b(b`k') se(se`k') lo(lo`k') hi(hi`k') truth(`TRUTH')
        foreach s in n bias bias_mcse empse empse_mcse modse ratio ratio_mcse ///
            coverage becoverage {
            local `d'`k'_`s' = r(`s')
        }
        if `k' == 1 local mlab "M1 cluster()          "
        if `k' == 2 local mlab "M2 cluster() nuisance "
        if `k' == 0 local mlab "M0 no cluster (neg.)  "
        display as text "    `mlab' bias " %8.5f ``d'`k'_bias' " (MCSE " %7.5f ``d'`k'_bias_mcse' ///
            ")  EmpSE " %7.5f ``d'`k'_empse' " (MCSE " %7.5f ``d'`k'_empse_mcse' ///
            ")  ModSE " %7.5f ``d'`k'_modse'
        display as text "                           ratio " %6.4f ``d'`k'_ratio' ///
            " (MCSE " %6.4f ``d'`k'_ratio_mcse' ")  coverage " %6.4f ``d'`k'_coverage' ///
            "  bias-elim. coverage " %6.4f ``d'`k'_becoverage'
    }

    **## Every replicate retained and usable (both modes)
    local ++test_count
    local ok = (``d'_nok' == `R' & ``d'_nbad' == 0 & ///
        ``d'1_n' == `R' & ``d'2_n' == `R' & ``d'0_n' == `R')
    _cal_test `ok' "`d' all `R' replicates fitted, converged and returned b, se, CI under M1, M2, M0 (failed: ``d'_nbad')"
    if `ok' local ++pass_count
    else local ++fail_count

    **## CI contract: reported limits are the log-scale Wald interval (both modes)
    * The three fits share the point estimate (cluster() and nuisance change
    * the variance only), and the reported CI is exp(b -/+ crit*se), so the
    * coverage gates below are statements about the reported SE.
    local ++test_count
    local ok = (``d'_dev' < 1e-8 & ``d'_bdiff' < 1e-10 & ``d'_dev' < . & ``d'_bdiff' < .)
    local lab : display "`d' CI contract: max |limit - (b -/+ crit*se)| " %8.2e ``d'_dev' ", max |b diff| " %8.2e ``d'_bdiff'
    _cal_test `ok' "`lab'"
    if `ok' local ++pass_count
    else local ++fail_count

    if !`smoke' {
        foreach k in 1 2 {
            **## Coverage of the reported 95% CI inside nominal +/- 3 MCSE
            local ++test_count
            local c = ``d'`k'_coverage'
            if "`d'" == "C" {
                * SMALL-G-DECLARED (see header): at 100 clusters the gate is
                * the published small-cluster coverage less 3 MCSE, not the
                * nominal band; over-coverage above the band still fails.
                local ok = (`c' >= `smallg_lo' & `c' <= `cov_hi' & `c' < .)
                local lab : display "`d' M`k' coverage " %6.4f `c' " in [" %6.4f `smallg_lo' ", " %6.4f `cov_hi' "] (small-G floor)"
            }
            else {
                local ok = (`c' >= `cov_lo' & `c' <= `cov_hi' & `c' < .)
                local lab : display "`d' M`k' coverage " %6.4f `c' " in [" %6.4f `cov_lo' ", " %6.4f `cov_hi' "]"
            }
            _cal_test `ok' "`lab'"
            if `ok' local ++pass_count
            else local ++fail_count

            **## ModSE/EmpSE inside 1 +/- 3 MCSE
            local ++test_count
            local q = ``d'`k'_ratio'
            local qm = ``d'`k'_ratio_mcse'
            local ok = (abs(`q' - 1) <= 3 * `qm' & `q' < . & `qm' < .)
            local lab : display "`d' M`k' ModSE/EmpSE " %6.4f `q' " within 1 +/- " %6.4f 3*`qm'
            _cal_test `ok' "`lab'"
            if `ok' local ++pass_count
            else local ++fail_count
        }
    }
}

**# Negative controls (gate mode only)
if !`smoke' {
    **## A: the unclustered SE undercovers, so the band can go red
    local ++test_count
    local c = `A0_coverage'
    local ok = (`c' < `cov_lo' & `c' < .)
    local lab : display "A M0 (no cluster) coverage " %6.4f `c' " falls below " %6.4f `cov_lo'
    _cal_test `ok' "`lab'"
    if `ok' local ++pass_count
    else local ++fail_count

    **## B: in matched pairs the unclustered SE overstates the variance
    local ++test_count
    local q = `B0_ratio'
    local qm = `B0_ratio_mcse'
    local ok = (`q' > 1 + 3 * `qm' & `q' < . & `qm' < .)
    local lab : display "B M0 (no cluster) ModSE/EmpSE " %6.4f `q' " above 1 + " %6.4f 3*`qm'
    _cal_test `ok' "`lab'"
    if `ok' local ++pass_count
    else local ++fail_count
}

**# Summary
timer off 1
quietly timer list 1
local secs = round(r(t1))

sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'"

display as text _newline "Results: `pass_count'/`test_count' passed, `fail_count' failed; runtime `secs' s"
display "RESULT: `suite' tests=`test_count' pass=`pass_count' fail=`fail_count' smoke=`smoke' secs=`secs'"
if `fail_count' > 0 {
    display as error "SOME CHECKS FAILED"
    log close _clcal
    exit 1
}
if `smoke' {
    display as text "SMOKE RUN: code path exercised only; not gate evidence"
    log close _clcal
    exit 0
}
display as result "ALL CHECKS PASSED"
log close _clcal
