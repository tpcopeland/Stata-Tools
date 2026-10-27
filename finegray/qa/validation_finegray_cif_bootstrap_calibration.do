* validation_finegray_cif_bootstrap_calibration.do
* Monte Carlo inference calibration of the confidence interval that
* finegray_cif, ci bootstrap(#) reports for the cumulative incidence function.
* Package: finegray
*
* Usage (from finegray/qa):
*   stata-mp -b do validation_finegray_cif_bootstrap_calibration.do         gate
*   stata-mp -b do validation_finegray_cif_bootstrap_calibration.do smoke   code path
*   global FG_CAL_REPS 5   (then do the file)   code path at 5 replicates
* The smoke form (argument smoke, or FG_CAL_REPS set to anything other than
* the gate R) runs SMOKE_R (or FG_CAL_REPS) replicates per DGP at B = 25,
* checks the code path only, never applies a band, prints smoke=1 on the
* RESULT line and is never gate evidence.
*
* WHAT THE ROUTE REPORTS (read from finegray_cif.ado, not assumed).  With
* bootstrap(B) the command refits e(refitcmd) on B subject resamples (bsample;
* whole clusters under cluster()), re-estimating the censoring weights each
* time, and replaces column 3 of r(table) with the SAMPLE SD of the B
* replicate CIFs (r(se_method) = "bootstrap").  The limits are NOT bootstrap
* percentiles: the bootstrap SD is passed to the same delta-method
* complementary log-log interval as the analytic route
* (_finegray_cloglog_ci in _finegray_mata.ado):
*     theta = ln(-ln(1 - F)),  se_theta = SE / ((1 - F) * (-ln(1 - F))),
*     limits = 1 - exp(-exp(theta -/+ z * se_theta)).
* So this file calibrates two things: the bootstrap SD as an estimate of the
* sampling SD of F-hat (CIF scale), and the cloglog-normal interval built from
* it.  Fine & Gray (1999) sec. 5, pp.501-502 (corpus notes read 2026-10-27):
* intervals for the CIF are formed on a monotone transformed scale m[F] so they
* stay in [0,1]; ln(-ln(1-u)) is the model's own link (sec. 2, p.497).
*
* SEEDS.  Each arm sets its master seed ONCE (set rng mt64; set seed SEED_x)
* and c(rngstate) is retained at the start of every replicate.  The inner
* bootstrap seed is the subtle part: finegray_cif snapshots c(rngstate) before
* its replications and RESTORES it afterwards whether or not seed() is given.
* Without seed() the B resamples would therefore be drawn from the caller's
* stream and then rewound, so replicate r+1's data would be generated from the
* very uniforms replicate r's bsample consumed.  Each replicate instead draws
* its own inner seed from the master stream (runiformint(1, 2^31-2), posted
* with the replicate) and passes it as seed(); the restore then leaves the
* master stream exactly where the draw left it, so outer and inner streams
* never overlap and any replicate replays from its stored rngstate alone.
*
* ADEMP (Morris, White & Crowther 2019, Table 1 p.2076; written before the
* gated run)
*   Aims        Does the bootstrap(#) CIF interval cover the population CIF at
*               its nominal 95% rate, and does the bootstrap SD match the
*               empirical SD of the CIF estimate, at a realistic N?
*   DGP         The known-CIF generator of validation_finegray_cif_recovery.do
*               (copied below with only its internal `set seed' removed, so
*               the suite seeds once):
*                 F1(t; z) = 1 - (1 - p(1 - exp(-t)))^exp(b z1), z1 ~ N(0,1),
*                 cause-2 times Exp(1), censoring U(0, cmax), n = 500.
*               A  light censoring: p = 0.4, b = 0.5, cmax = 8 (12.3%
*                  censored), horizons 0.5 1 2.
*               B  heavy censoring: p = 0.6, b = 0.4, cmax = 2 (42.5%
*                  censored), horizons 0.25 0.75 1.25.  This is the arm where
*                  the censoring-weight estimation, which the bootstrap
*                  re-estimates and the analytic SE treats as known, is
*                  largest.
*   Estimand    F1(t; z1 = 1) at each horizon, in closed form from the DGP.
*   Methods     finegray z1, compete(status) cause(1); then
*               finegray_cif, at(z1=1) attime(h1 h2 h3) ci bootstrap(B)
*               seed(<inner>) nograph.  Diagnostic only, same fit: the
*               analytic (fixed-weight influence-function) interval.
*               Negative control: the reported interval halved in width on the
*               cloglog scale around the same centre.
*   Performance per arm x horizon: coverage of the reported interval (gate);
*               ModSE / EmpSE with ModSE = sqrt(mean(SE^2)) over replicates
*               (gate); bias with MCSE, bias-eliminated coverage, cloglog-
*               scale SE ratio, analytic ModSE/EmpSE and coverage (reported);
*               replicates usable (gate: all R).
*
* R, B AND THE COST TRADE-OFF.  A refit costs about 0.03 s at n = 500 (timed
* 2026-10-27, processors 1), so one bootstrap(100) call is about 3 s and the
* study is R x B x 2 arms refits.  Inside a 45-minute single-threaded budget
* that is about 80,000 refits.  B is set from its effect on coverage, R from
* the MCSE: the bootstrap SD has relative Monte Carlo error about
* 1/sqrt(2B) (0.071 at B = 100), and an SE that is noisy with CV c lowers
* normal-interval coverage by about 0.88 c^2 / 2 at 95% (second-order Taylor
* of 2 Phi(1.96(1+e)) - 1), i.e. 0.002 at B = 100 and 0.001 at B = 200, both
* far inside the band.  Doubling B would buy 0.1 points of coverage bias and
* halve R; spending the budget on R instead narrows the band.  Sizing R from
* R = p(1-p)/MCSE^2 (Morris et al. eq. 1, p.2089) for MCSE about 1.1 points at
* p = 0.95 gives R = 400, so R = 400 per arm, B = 100: 80,000 refits.  The
* price is a band of [0.917, 0.983], about 3.3 points either side, wider than
* the [0.929, 0.971] of R = 1000; a coverage shortfall smaller than about 3
* points is not detectable here.
*
* GATES (computed in-suite from R, never typed; Morris et al. Table 6 p.2086)
*   G1  every replicate: fit converges, bootstrap() returns, r(se_method) is
*       "bootstrap", and every horizon carries a finite CIF, SE > 0 and
*       limits; usable + failed == R and usable == R           (both modes)
*   G2  coverage in 0.95 +/- 3 sqrt(0.95 x 0.05 / R) at every horizon
*   G3  |ModSE/EmpSE - 1| <= 3 MCSE(ratio), MCSE = sqrt(Var(SE^2) /
*       (4 R ModSE^4) + 1 / (2 (R - 1))), at every horizon
*   G4  negative control: the half-width interval's coverage falls below the
*       G2 band at every horizon (the gate can go red)
* Each arm runs 3 horizons x 2 gated rates = 6 two-sided 3-MCSE checks, 12 in
* all; under exact calibration and independence about 3% of runs would raise
* a false alarm somewhere (the horizons are positively correlated, so less).
*
* EXPECTED CLASS (written before the run): NOMINAL in both arms.  The help
* (finegray_cif.sthlp, bootstrap(); finegray_methods.sthlp##cif) declares no
* conservatism for this route, so over-coverage above the band is a DEFECT,
* not CONSERVATIVE-DECLARED.
*
* WORKED RUN: see the block written after the first full-R run, below the
* constants.

version 16.0
clear all
set more off
set varabbrev off
set linesize 200

args mode
local smoke = ("`mode'" == "smoke")
if "`mode'" != "" & !`smoke' {
    display as error "unknown argument `mode'; the only accepted argument is smoke"
    exit 198
}

local qa_dir "`c(pwd)'"
local suite "validation_finegray_cif_bootstrap_calibration"
capture log close _fgcalb
log using "`qa_dir'/`suite'.log", replace text name(_fgcalb)

do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap
local orig_plus "`r(orig_plus)'"
local orig_personal "`r(orig_personal)'"
local plus_dir "`r(plus_dir)'"
local personal_dir "`r(personal_dir)'"

**# Predeclared design
local R_GATE  = 400
local B_GATE  = 100
local SMOKE_R = 10
local B_SMOKE = 25
local R = cond(`smoke', `SMOKE_R', `R_GATE')
if "$FG_CAL_REPS" != "" {
    capture confirm integer number $FG_CAL_REPS
    if _rc | real("$FG_CAL_REPS") < 2 {
        display as error "FG_CAL_REPS must be an integer of at least 2"
        log close _fgcalb
        exit 198
    }
    local R = $FG_CAL_REPS
    if `R' != `R_GATE' local smoke = 1
}
local B = cond(`smoke', `B_SMOKE', `B_GATE')
local NOBS    = 500
local ZP      = 1
local NOMINAL = 0.95
local Z       = invnormal(1 - (1 - `NOMINAL') / 2)
local SEED_A  = 20261027
local SEED_B  = 20261028

* arm parameters
local A_p    = 0.4
local A_b    = 0.5
local A_cmax = 8
local A_H    0.5 1 2
local B_p    = 0.6
local B_b    = 0.4
local B_cmax = 2
local B_H    0.25 0.75 1.25
local NH = 3

local cov_mcse = sqrt(`NOMINAL' * (1 - `NOMINAL') / `R')
local cov_lo   = `NOMINAL' - 3 * `cov_mcse'
local cov_hi   = `NOMINAL' + 3 * `cov_mcse'

* WORKED RUN 2026-10-27 (Stata 17 MP, processors 1, mt64; R = 400, B = 100;
* 2110 s wall; the gates above were fixed before it).  400/400 replicates
* usable per arm, 0 skipped bootstrap refits.  Band [0.9173, 0.9827].
*   arm t     truth    bias (MCSE)       EmpSE   ratio (MCSE)    cover  BE-cov  half-w
*   A   0.5   0.24598 -0.00150 (0.00120) 0.02390 1.0389 (0.0357) 0.9575 0.9575 0.6875
*   A   1     0.38158 -0.00041 (0.00146) 0.02924 1.0153 (0.0357) 0.9575 0.9550 0.6875
*   A   2     0.50331 -0.00134 (0.00159) 0.03186 1.0092 (0.0357) 0.9375 0.9325 0.6950
*   B   0.25  0.19138 -0.00122 (0.00110) 0.02207 1.0296 (0.0357) 0.9550 0.9500 0.6775
*   B   0.75  0.43326 -0.00036 (0.00167) 0.03345 0.9960 (0.0356) 0.9475 0.9475 0.6750
*   B   1.25  0.56552  0.00130 (0.00181) 0.03617 1.0202 (0.0357) 0.9575 0.9625 0.6775
* Class NOMINAL in both arms.  Diagnostic, same fits: the analytic
* fixed-weight interval covered 0.9475-0.9675 with ratio 0.988-1.047, and
* mean(SE_analytic / SE_bootstrap) was 0.999-1.015, so on these DGPs the
* weight-estimation term the analytic SE omits is under 2% of the SE even at
* 42% censoring.

display as text "`suite': R=`R' per arm (gate R=`R_GATE'), B=`B' (gate B=`B_GATE'), n=`NOBS', smoke=`smoke'"
display as text "  seeds: arm A `SEED_A', arm B `SEED_B' (mt64, set once per arm)"
display as text "  coverage band [" %6.4f `cov_lo' ", " %6.4f `cov_hi' "] (MCSE " %6.4f `cov_mcse' ")"

local test_count = 0
local pass_count = 0
local fail_count = 0

timer clear 1
timer on 1

**# Generator (validation_finegray_cif_recovery.do, internal set seed removed)
* stata-dev-ignore: unseeded-draw — this is a generator PROGRAM, not a script: the arm loop below sets the master seed once before its first call and retains c(rngstate) per replicate, so every draw replays
capture program drop _fgcalb_dgp
program define _fgcalb_dgp
    syntax , n(integer) p(real) b(real) [cmax(real 8)]
    clear
    quietly set obs `n'
    gen double z1 = rnormal()
    gen double lp = `b'*z1
    gen double _pz = 1 - (1-`p')^exp(lp)
    gen double _u  = runiform()
    gen byte cause = cond(runiform() < _pz, 1, 2)
    gen double _t1 = -ln(1 - (1 - (1 - _u*_pz)^exp(-lp))/`p')
    gen double _t2 = -ln(runiform())
    gen double tevent = cond(cause==1, _t1, _t2)
    gen double c = runiform()*`cmax'
    gen double time = min(tevent, c)
    gen byte status = cond(tevent <= c, cause, 0)
    gen byte anyevent = status > 0
    gen long id = _n
    drop _pz _u _t1 _t2
end

**# Performance measures for one arm x horizon
* Rates are over the usable replicates; G1 requires usable == R, so the
* denominator is R whenever a rate is gated.
capture program drop _fgcalb_perf
program define _fgcalb_perf, rclass
    syntax , est(varname) se(varname) lo(varname) hi(varname) ///
        truth(real) z(real)
    tempvar ok v cv cvbe g hw lon hin cvn
    quietly gen byte `ok' = !missing(`est', `se', `lo', `hi') & `se' > 0
    quietly count if `ok'
    local n = r(N)
    return scalar n = `n'
    if `n' < 2 exit
    quietly summarize `est' if `ok'
    local m = r(mean)
    local emp = r(sd)
    return scalar mean = `m'
    return scalar bias = `m' - `truth'
    return scalar bias_mcse = `emp' / sqrt(`n')
    return scalar empse = `emp'
    quietly gen double `v' = `se'^2 if `ok'
    quietly summarize `v'
    local mod = sqrt(r(mean))
    local varv = r(Var)
    return scalar modse = `mod'
    return scalar ratio = `mod' / `emp'
    return scalar ratio_mcse = sqrt(`varv' / (4 * `n' * `mod'^4) + 1 / (2 * (`n' - 1)))
    quietly gen byte `cv' = (`lo' <= `truth' & `truth' <= `hi') if `ok'
    quietly summarize `cv', meanonly
    return scalar cov = r(mean)
    quietly gen byte `cvbe' = (`lo' <= `m' & `m' <= `hi') if `ok'
    quietly summarize `cvbe', meanonly
    return scalar cov_be = r(mean)
    * The reported interval is theta-hat -/+ hw on the cloglog scale; the
    * negative control keeps the centre and halves hw.
    quietly gen double `g' = cloglog(`est') if `ok'
    quietly gen double `hw' = (cloglog(`hi') - cloglog(`lo')) / 2 if `ok'
    quietly gen double `lon' = invcloglog(`g' - `hw' / 2) if `ok'
    quietly gen double `hin' = invcloglog(`g' + `hw' / 2) if `ok'
    quietly gen byte `cvn' = (`lon' <= `truth' & `truth' <= `hin') if `ok'
    quietly summarize `cvn', meanonly
    return scalar cov_neg = r(mean)
    * cloglog-scale calibration (diagnostic): implied se_theta = hw / z
    quietly summarize `g'
    local empg = r(sd)
    quietly replace `v' = (`hw' / `z')^2 if `ok'
    quietly summarize `v'
    return scalar ratio_g = sqrt(r(mean)) / `empg'
end

**# Replicates
* One row per arm x replicate, every replicate posted, failures included.
* stage: 0 usable, 1 fit error, 2 not converged, 3 analytic finegray_cif
* error, 4 bootstrap finegray_cif error, 5 wrong se_method, 6 nonfinite or
* nonpositive cell.
tempfile reps
tempname P
local pvars "byte arm long rep int rc byte stage long bseed int bfail double pcens"
forvalues k = 1/`NH' {
    local pvars "`pvars' double(cif`k' se`k' lci`k' uci`k' ase`k' alci`k' auci`k')"
}
postfile `P' `pvars' using "`reps'", replace
mata: _fgcalb_st = J(2 * `R', 1, "")

local armno = 0
foreach arm in A B {
    local ++armno
    display as text _newline "Arm `arm': p=``arm'_p' b=``arm'_b' cmax=``arm'_cmax' horizons ``arm'_H'"
    set rng mt64
    set seed `SEED_`arm''
    tempname T AT
    forvalues r = 1/`R' {
        mata: _fgcalb_st[(`armno' - 1) * `R' + `r'] = c("rngstate")
        _fgcalb_dgp, n(`NOBS') p(``arm'_p') b(``arm'_b') cmax(``arm'_cmax')
        local bseed = runiformint(1, 2147483646)
        quietly count if status == 0
        local pcens = r(N) / _N
        quietly stset time, failure(anyevent == 1) id(id)
        local stage = 0
        local rc = 0
        local bfail = .
        capture quietly finegray z1, compete(status) cause(1) nolog
        if _rc {
            local rc = _rc
            local stage = 1
        }
        else if e(converged) != 1 local stage = 2
        if `stage' == 0 {
            capture quietly finegray_cif, at(z1=`ZP') attime(``arm'_H') ci nograph
            if _rc {
                local rc = _rc
                local stage = 3
            }
            else matrix `AT' = r(table)
        }
        if `stage' == 0 {
            capture quietly finegray_cif, at(z1=`ZP') attime(``arm'_H') ci ///
                nograph bootstrap(`B') seed(`bseed')
            if _rc {
                local rc = _rc
                local stage = 4
            }
            else if `"`r(se_method)'"' != "bootstrap" local stage = 5
            else {
                matrix `T' = r(table)
                local bfail = r(bootstrap_failed)
            }
        }
        local plist ""
        forvalues k = 1/`NH' {
            if `stage' == 0 {
                local plist "`plist' (`=`T'[`k',2]') (`=`T'[`k',3]') (`=`T'[`k',4]') (`=`T'[`k',5]')"
                local plist "`plist' (`=`AT'[`k',3]') (`=`AT'[`k',4]') (`=`AT'[`k',5]')"
                if missing(`T'[`k',2], `T'[`k',3], `T'[`k',4], `T'[`k',5]) local stage = 6
                else if `T'[`k',3] <= 0 local stage = 6
            }
            else local plist "`plist' (.) (.) (.) (.) (.) (.) (.)"
        }
        post `P' (`armno') (`r') (`rc') (`stage') (`bseed') (`bfail') (`pcens') `plist'
        if `stage' != 0 display as error "  arm `arm' replicate `r': stage `stage' rc `rc'"
    }
}
postclose `P'

**# Replicate ledger
use "`reps'", clear
sort arm rep
quietly gen strL rngstate = ""
mata: st_sstore(., "rngstate", _fgcalb_st)
mata: mata drop _fgcalb_st
* Replay replicate r of arm a alone: set rng mt64; set rngstate <rngstate>,
* then the replicate body above with seed(bseed).
quietly save "`qa_dir'/`suite'_replicates.dta", replace

**# Performance and gates
local armno = 0
foreach arm in A B {
    local ++armno
    quietly count if arm == `armno'
    local nrow = r(N)
    quietly count if arm == `armno' & stage == 0
    local n_ok = r(N)
    forvalues s = 1/6 {
        quietly count if arm == `armno' & stage == `s'
        local n_s`s' = r(N)
    }
    quietly summarize bfail if arm == `armno' & stage == 0
    local bfail_tot = r(sum)
    local bfail_max = r(max)
    quietly summarize pcens if arm == `armno'
    local pcens_m = r(mean)

    display as text _newline "Arm `arm' performance: `n_ok' of `R' replicates usable" ///
        " (fit error `n_s1', not converged `n_s2', analytic cif `n_s3', bootstrap `n_s4', se_method `n_s5', nonfinite `n_s6')"
    display as text "  skipped bootstrap refits inside usable replicates: total `bfail_tot', max per replicate `bfail_max' (of B=`B')"
    display as text "  mean censored fraction " %5.3f `pcens_m'

    **## G1 every replicate usable, counters reconcile (both modes)
    local ++test_count
    local ok = (`nrow' == `R' & `n_ok' + `n_s1' + `n_s2' + `n_s3' + `n_s4' + `n_s5' + `n_s6' == `R' & `n_ok' == `R')
    if `ok' {
        display as result "  PASS: G1/`arm' all `R' replicates usable at every horizon"
        local ++pass_count
    }
    else {
        display as error "  FAIL: G1/`arm' usable `n_ok' of `R' (rows `nrow')"
        local ++fail_count
    }

    **## G1b no bootstrap refit skipped inside a usable replicate (both modes)
    * A replicate whose SD rests on fewer than B refits would otherwise count
    * as usable; every refit must succeed.
    local ++test_count
    local ok = (`bfail_tot' == 0 & `bfail_tot' < .)
    if `ok' {
        display as result "  PASS: G1b/`arm' no skipped bootstrap refit (B=`B')"
        local ++pass_count
    }
    else {
        display as error "  FAIL: G1b/`arm' `bfail_tot' skipped bootstrap refits, max `bfail_max' per replicate"
        local ++fail_count
    }

    local cov_all = 1
    local rat_all = 1
    local neg_all = 1
    forvalues k = 1/`NH' {
        local hh : word `k' of ``arm'_H'
        local truth = 1 - (1 - ``arm'_p'*(1 - exp(-`hh')))^exp(``arm'_b'*`ZP')
        preserve
        quietly keep if arm == `armno' & stage == 0
        _fgcalb_perf, est(cif`k') se(se`k') lo(lci`k') hi(uci`k') truth(`truth') z(`Z')
        local n = r(n)
        foreach s in mean bias bias_mcse empse modse ratio ratio_mcse cov cov_be cov_neg ratio_g {
            local `s' = r(`s')
        }
        _fgcalb_perf, est(cif`k') se(ase`k') lo(alci`k') hi(auci`k') truth(`truth') z(`Z')
        local a_ratio = r(ratio)
        local a_ratio_mcse = r(ratio_mcse)
        local a_cov = r(cov)
        quietly gen double _abr = ase`k' / se`k'
        quietly summarize _abr
        local a_over_b = r(mean)
        restore

        display as text "  t=`hh' truth=" %7.5f `truth' " mean=" %7.5f `mean' ///
            " bias=" %8.5f `bias' " (MCSE " %7.5f `bias_mcse' ")"
        display as text "         EmpSE=" %7.5f `empse' " ModSE(boot)=" %7.5f `modse' ///
            " ratio=" %6.4f `ratio' " (MCSE " %6.4f `ratio_mcse' ") cloglog-ratio=" %6.4f `ratio_g'
        display as text "         coverage=" %6.4f `cov' " band [" %6.4f `cov_lo' ", " %6.4f `cov_hi' ///
            "] bias-eliminated=" %6.4f `cov_be' " half-width control=" %6.4f `cov_neg'
        display as text "         diagnostic analytic: ratio=" %6.4f `a_ratio' " (MCSE " %6.4f `a_ratio_mcse' ///
            ") coverage=" %6.4f `a_cov' " mean(SE_analytic/SE_boot)=" %6.4f `a_over_b'

        local c_ok = (`cov' >= `cov_lo' & `cov' <= `cov_hi' & `cov' < .)
        local r_ok = (abs(`ratio' - 1) <= 3 * `ratio_mcse' & `ratio' < . & `ratio_mcse' < .)
        if !`c_ok' local cov_all = 0
        if !`r_ok' local rat_all = 0
        if !(`cov_neg' < `cov_lo' & `cov_neg' < .) local neg_all = 0
        local cov`arm'`k' = `cov'
        local rat`arm'`k' = `ratio'
    }

    if !`smoke' {
        **## G2 coverage in band at every horizon
        local ++test_count
        if `cov_all' {
            display as result "  PASS: G2/`arm' bootstrap-interval coverage inside the band at every horizon"
            local ++pass_count
        }
        else {
            display as error "  FAIL: G2/`arm' bootstrap-interval coverage outside the band at a horizon"
            local ++fail_count
        }

        **## G3 bootstrap SD / empirical SD within 1 +/- 3 MCSE
        local ++test_count
        if `rat_all' {
            display as result "  PASS: G3/`arm' ModSE(bootstrap)/EmpSE within 1 +/- 3 MCSE at every horizon"
            local ++pass_count
        }
        else {
            display as error "  FAIL: G3/`arm' ModSE(bootstrap)/EmpSE outside 1 +/- 3 MCSE at a horizon"
            local ++fail_count
        }

        **## G4 negative control goes red
        local ++test_count
        if `neg_all' {
            display as result "  PASS: G4/`arm' half-width interval falls below the band at every horizon"
            local ++pass_count
        }
        else {
            display as error "  FAIL: G4/`arm' half-width negative control did not fall below the band"
            local ++fail_count
        }
        local cls = cond(`cov_all' & `rat_all', "NOMINAL", "DEFECT")
        display as text "  CLASS: finegray_cif bootstrap() arm `arm': `cls'"
    }
}

**# Summary
timer off 1
quietly timer list 1
local secs = round(r(t1))

sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'"
capture program drop _fgcalb_dgp
capture program drop _fgcalb_perf

display as text _newline "runtime `secs' seconds"
display as text "RESULT: `suite' tests=`test_count' pass=`pass_count' fail=`fail_count' smoke=`smoke' secs=`secs'"
if `fail_count' > 0 {
    display as error "`suite': `fail_count' check(s) FAILED"
    log close _fgcalb
    exit 9
}
if `smoke' {
    display as text "SMOKE RUN: code path exercised only; not gate evidence"
    log close _fgcalb
    exit 0
}
display as result "`suite': all checks passed"
log close _fgcalb
