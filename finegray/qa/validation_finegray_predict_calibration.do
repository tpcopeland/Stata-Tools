* validation_finegray_predict_calibration.do
* Monte Carlo inference calibration of the row-level CIF confidence limits
* that finegray_predict, cif ci produces, and of the xb prediction the same
* route returns for given subjects.
* Package: finegray
*
* Usage (from finegray/qa):
*   stata-mp -b do validation_finegray_predict_calibration.do         gate
*   stata-mp -b do validation_finegray_predict_calibration.do smoke   code path
*   global FG_CAL_REPS 5   (then do the file)   code path at 5 replicates
* The smoke form (argument smoke, or FG_CAL_REPS set to anything other than
* the gate R) runs SMOKE_R (or FG_CAL_REPS) replicates per DGP, checks the
* code path and the deterministic identities only, never applies a band,
* prints smoke=1 on the RESULT line and is never gate evidence.
*
* WHAT THE ROUTE REPORTS (read from finegray_predict.ado and
* _finegray_mata.ado, not assumed).
*   cif ci   Each evaluation row gets newvar (the CIF at that row's own
*            timevar() value and covariates) and newvar_lci / newvar_uci.  The
*            SE is the fixed-weight influence-function SE: censoring weights
*            (and, under delayed entry, entry weights) treated as known
*            (finegray_predict.sthlp, ci).  It is computed by
*            _finegray_cif_predict, which calls _finegray_cif_core, the SAME
*            routine finegray_cif's analytic ci reaches through
*            _finegray_cif_var_st; both routes then form the limits with the
*            same _finegray_cloglog_ci:
*              theta = ln(-ln(1 - F)), se_theta = SE / ((1 - F)(-ln(1 - F))),
*              limits = 1 - exp(-exp(theta -/+ z se_theta)).
*            The SE itself is not stored, so this file recovers it exactly
*            from the limits, SE = (cloglog(uci) - cloglog(lci)) / (2 z) x
*            (1 - F)(-ln(1 - F)), and P2 checks the recovery against
*            finegray_cif's r(table) SE on every replicate.  Shared code is a
*            reason to expect agreement, not a substitute for calibrating this
*            route's own output, so every rate below is computed from
*            finegray_predict's variables.
*   xb       The linear predictor z'b-hat.  No SE and no limits are exposed:
*            ci requires cif (r(198) with xb).  The xb cell therefore has no
*            interval to calibrate; P3 asserts that contract, and xb's bias
*            and empirical SE are reported against the true x'beta, with the
*            e(V) delta-method Wald coverage shown as a diagnostic that is NOT
*            package output (for one covariate it is the coefficient's own
*            coverage, gated in validation_variance_default_mc.do).
* Fine & Gray (1999) sec. 5, pp.501-502 (corpus notes read 2026-10-27): CIF
* intervals are formed on a monotone transformed scale m[F] so they stay in
* [0,1]; ln(-ln(1-u)) is the model's own link (sec. 2, p.497).
*
* ADEMP (Morris, White & Crowther 2019, Table 1 p.2076; written before the
* gated run)
*   Aims        Do the finegray_predict cif ci limits cover each given
*               subject's true CIF at the nominal 95% rate, is the implied SE
*               calibrated to the empirical SD of the row CIF, and is xb
*               unbiased for x'beta?
*   DGP         The known-CIF generator of validation_finegray_cif_recovery.do,
*               copied below with two declared changes: its internal
*               `set seed' is removed (the suite seeds once) and pin()
*               overwrites z1 in the first rows after it is drawn and before
*               any outcome is drawn, so the random-number sequence is
*               unchanged and the pinned rows are ordinary subjects of the
*               fit with fixed covariates.
*                 F1(t; z) = 1 - (1 - p(1 - exp(-t)))^exp(b z1), z1 ~ N(0,1),
*                 cause-2 times Exp(1), censoring U(0, cmax), n = 500.
*               A  light censoring: p = 0.4, b = 0.5, cmax = 8 (about 12%
*                  censored), horizons 0.5 1 2.
*               B  heavy censoring: p = 0.6, b = 0.4, cmax = 2 (about 42%
*                  censored), horizons 0.25 0.75 1.25.  The arm where the
*                  censoring-weight variability the fixed-weight SE omits is
*                  largest.
*   Estimand    Five given subjects per replicate (rows 1-5):
*                 row 1-3  z1 =  1 at horizons h1, h2, h3
*                 row 4    z1 =  0 at h2
*                 row 5    z1 = -1 at h2
*               truth F1(h; z1) in closed form; xb truth = b z1.
*   Methods     finegray z1, compete(status) cause(1); then
*               finegray_predict double pc in 1/5, cif timevar(hev) ci and
*               finegray_predict double xbv in 1/5, xb.  Identity check on
*               the same fit: finegray_cif, at(z1=.) attime(.) ci.
*               Negative control: the reported interval halved in width on the
*               cloglog scale around the same centre.
*   Performance per arm x subject: coverage of [pc_lci, pc_uci] (gate);
*               ModSE / EmpSE with ModSE = sqrt(mean(SE^2)) of the implied SE
*               (gate); bias with MCSE, bias-eliminated coverage, cloglog-
*               scale ratio (reported); replicates usable (gate: all R).
*
* R AND SEEDS.  R = 1000 per arm (about 0.07 s per replicate at n = 500,
* processors 1: 144 s in all on 2026-10-27).  Coverage MCSE at the nominal rate
* sqrt(0.95 x 0.05 / 1000) = 0.0069, band [0.929, 0.971].  Master seeds
* 20261029 (arm A) and 20261030 (arm B), set once per arm under mt64;
* c(rngstate) is retained at the start of every replicate in the ledger
* validation_finegray_predict_calibration_replicates.dta (gitignored), so any
* replicate replays alone.  The route draws no random numbers.
*
* GATES (computed in-suite from R, never typed; Morris et al. Table 6 p.2086)
*   P1  every replicate: fit converges, predict returns, all five rows carry a
*       finite CIF and finite limits with lci < cif < uci; usable + failed ==
*       R and usable == R                                     (both modes)
*   P2  shared core: on every usable replicate, predict's CIF and limits
*       equal finegray_cif's at the same profile and horizon within 1e-10,
*       and the SE recovered from predict's limits equals finegray_cif's
*       r(table) SE within 1e-8 relative                     (both modes)
*   P3  xb: xbv equals z1 x _b[z1] within 1e-12 on every replicate, and
*       finegray_predict, xb ci is refused r(198) creating nothing
*                                                             (both modes)
*   P4  coverage in 0.95 +/- 3 sqrt(0.95 x 0.05 / R) for every subject
*   P5  |ModSE/EmpSE - 1| <= 3 MCSE(ratio), MCSE = sqrt(Var(SE^2) /
*       (4 R ModSE^4) + 1 / (2 (R - 1))), for every subject
*   P6  negative control: the half-width interval's coverage falls below the
*       P4 band for every subject (the gate can go red)
* Each arm runs 5 subjects x 2 gated rates = 10 two-sided 3-MCSE checks, 20 in
* all; under exact calibration and independence about 5% of runs would raise
* a false alarm somewhere (rows 1-3 and 4-5 share a fit, so less).
*
* EXPECTED CLASS (written before the run): NOMINAL in both arms, arm B the
* one at risk.  finegray_predict.sthlp says only that the SE "omits
* weight-estimation variability"; it declares no conservatism, so coverage
* above the band is a DEFECT, as is coverage below it.
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
local suite "validation_finegray_predict_calibration"
capture log close _fgcalp
log using "`qa_dir'/`suite'.log", replace text name(_fgcalp)

do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap
local orig_plus "`r(orig_plus)'"
local orig_personal "`r(orig_personal)'"
local plus_dir "`r(plus_dir)'"
local personal_dir "`r(personal_dir)'"

**# Predeclared design
local R_GATE  = 1000
local SMOKE_R = 10
local R = cond(`smoke', `SMOKE_R', `R_GATE')
if "$FG_CAL_REPS" != "" {
    capture confirm integer number $FG_CAL_REPS
    if _rc | real("$FG_CAL_REPS") < 2 {
        display as error "FG_CAL_REPS must be an integer of at least 2"
        log close _fgcalp
        exit 198
    }
    local R = $FG_CAL_REPS
    if `R' != `R_GATE' local smoke = 1
}
local NOBS    = 500
local NOMINAL = 0.95
local Z       = invnormal(1 - (1 - `NOMINAL') / 2)
local SEED_A  = 20261029
local SEED_B  = 20261030

* arm parameters
local A_p    = 0.4
local A_b    = 0.5
local A_cmax = 8
local A_H    0.5 1 2
local B_p    = 0.6
local B_b    = 0.4
local B_cmax = 2
local B_H    0.25 0.75 1.25

* the five given subjects: covariate and horizon index
local NP = 5
local PZ   1 1 1 0 -1
local PHK  1 2 3 2 2

local cov_mcse = sqrt(`NOMINAL' * (1 - `NOMINAL') / `R')
local cov_lo   = `NOMINAL' - 3 * `cov_mcse'
local cov_hi   = `NOMINAL' + 3 * `cov_mcse'

* WORKED RUN 2026-10-27 (Stata 17 MP, processors 1, mt64; R = 1000; 144 s
* wall; the gates above were fixed before it).  1000/1000 replicates usable
* per arm; censored 12.2% (A), 42.4% (B).  Band [0.9293, 0.9707]; ratio MCSE
* 0.0224-0.0225.  P2 max differences 2.2e-15 (CIF, limits) and 4.7e-15
* (relative SE).
*   arm subj z1  t     truth    bias (MCSE)       EmpSE   ratio  cover  BE-cov half-w
*   A   1    1   0.5   0.24598  0.00036 (0.00080) 0.02540 0.9837 0.9460 0.9430 0.6760
*   A   2    1   1     0.38158  0.00053 (0.00094) 0.02960 1.0007 0.9580 0.9570 0.6740
*   A   3    1   2     0.50331  0.00102 (0.00102) 0.03240 0.9924 0.9440 0.9420 0.6840
*   A   4    0   1     0.25285 -0.00066 (0.00065) 0.02067 0.9911 0.9420 0.9430 0.6700
*   A   5   -1   1     0.16205 -0.00051 (0.00066) 0.02095 0.9804 0.9440 0.9460 0.6600
*   B   1    1   0.25  0.19138 -0.00170 (0.00075) 0.02360 0.9587 0.9390 0.9400 0.6600
*   B   2    1   0.75  0.43326 -0.00215 (0.00106) 0.03354 0.9827 0.9440 0.9410 0.6720
*   B   3    1   1.25  0.56552 -0.00270 (0.00117) 0.03702 0.9940 0.9500 0.9500 0.6490
*   B   4    0   0.75  0.31658 -0.00103 (0.00073) 0.02316 1.0215 0.9540 0.9530 0.6720
*   B   5   -1   0.75  0.22520  0.00048 (0.00081) 0.02549 1.0382 0.9560 0.9560 0.6730
* Class NOMINAL in both arms.  Closest to an edge: arm B subject 1 (ratio
* 0.959, 1.8 MCSE below 1; bias 2.3 MCSE), inside every gate.  xb (no
* interval exposed): bias +0.0055 (MCSE 0.0024) in A and -0.0027 (0.0024) in
* B at |z1| = 1, EmpSE 0.077; diagnostic e(V) Wald coverage 0.948 / 0.954.

display as text "`suite': R=`R' per arm (gate R=`R_GATE'), n=`NOBS', smoke=`smoke'"
display as text "  seeds: arm A `SEED_A', arm B `SEED_B' (mt64, set once per arm)"
display as text "  coverage band [" %6.4f `cov_lo' ", " %6.4f `cov_hi' "] (MCSE " %6.4f `cov_mcse' ")"

local test_count = 0
local pass_count = 0
local fail_count = 0

timer clear 1
timer on 1

**# Generator (validation_finegray_cif_recovery.do; set seed removed, pin() added)
* stata-dev-ignore: unseeded-draw — this is a generator PROGRAM, not a script: the arm loop below sets the master seed once before its first call and retains c(rngstate) per replicate, so every draw replays
capture program drop _fgcalp_dgp
program define _fgcalp_dgp
    syntax , n(integer) p(real) b(real) [cmax(real 8) pin(numlist)]
    clear
    quietly set obs `n'
    gen double z1 = rnormal()
    * pin(): fixed covariates for the given subjects, set after the draw so
    * the random-number sequence is the recovery generator's own.
    local j = 0
    foreach v of local pin {
        local ++j
        quietly replace z1 = `v' in `j'
    }
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

**# Performance measures for one arm x subject
capture program drop _fgcalp_perf
program define _fgcalp_perf, rclass
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
    quietly gen double `g' = cloglog(`est') if `ok'
    quietly gen double `hw' = (cloglog(`hi') - cloglog(`lo')) / 2 if `ok'
    quietly gen double `lon' = invcloglog(`g' - `hw' / 2) if `ok'
    quietly gen double `hin' = invcloglog(`g' + `hw' / 2) if `ok'
    quietly gen byte `cvn' = (`lon' <= `truth' & `truth' <= `hin') if `ok'
    quietly summarize `cvn', meanonly
    return scalar cov_neg = r(mean)
    quietly summarize `g'
    local empg = r(sd)
    quietly replace `v' = (`hw' / `z')^2 if `ok'
    quietly summarize `v'
    return scalar ratio_g = sqrt(r(mean)) / `empg'
end

**# Replicates
* One row per arm x replicate, every replicate posted, failures included.
* stage: 0 usable, 1 fit error, 2 not converged, 3 predict cif ci error,
* 4 predict xb error, 5 finegray_cif error, 6 nonfinite or misordered row.
tempfile reps
tempname P
local pvars "byte arm long rep int rc byte stage double(pcens bhat v11)"
forvalues j = 1/`NP' {
    local pvars "`pvars' double(cif`j' lci`j' uci`j' xb`j' cifc`j' sec`j' lcic`j' ucic`j')"
}
postfile `P' `pvars' using "`reps'", replace
mata: _fgcalp_st = J(2 * `R', 1, "")

local armno = 0
foreach arm in A B {
    local ++armno
    display as text _newline "Arm `arm': p=``arm'_p' b=``arm'_b' cmax=``arm'_cmax' horizons ``arm'_H'"
    local h1 : word 1 of ``arm'_H'
    local h2 : word 2 of ``arm'_H'
    local h3 : word 3 of ``arm'_H'
    set rng mt64
    set seed `SEED_`arm''
    tempname T1 T0 TM
    forvalues r = 1/`R' {
        mata: _fgcalp_st[(`armno' - 1) * `R' + `r'] = c("rngstate")
        _fgcalp_dgp, n(`NOBS') p(``arm'_p') b(``arm'_b') cmax(``arm'_cmax') pin(`PZ')
        quietly count if status == 0
        local pcens = r(N) / _N
        quietly gen double hev = .
        forvalues j = 1/`NP' {
            local kk : word `j' of `PHK'
            quietly replace hev = `h`kk'' in `j'
        }
        quietly stset time, failure(anyevent == 1) id(id)
        local stage = 0
        local rc = 0
        local bhat = .
        local v11 = .
        capture quietly finegray z1, compete(status) cause(1) nolog
        if _rc {
            local rc = _rc
            local stage = 1
        }
        else if e(converged) != 1 local stage = 2
        else {
            local bhat = _b[z1]
            local v11 = el(e(V), 1, 1)
        }
        if `stage' == 0 {
            capture quietly finegray_predict double pc in 1/`NP', cif timevar(hev) ci
            if _rc {
                local rc = _rc
                local stage = 3
            }
        }
        if `stage' == 0 {
            capture quietly finegray_predict double xbv in 1/`NP', xb
            if _rc {
                local rc = _rc
                local stage = 4
            }
        }
        if `stage' == 0 {
            capture {
                quietly finegray_cif, at(z1=1) attime(`h1' `h2' `h3') ci nograph
                matrix `T1' = r(table)
                quietly finegray_cif, at(z1=0) attime(`h2') ci nograph
                matrix `T0' = r(table)
                quietly finegray_cif, at(z1=-1) attime(`h2') ci nograph
                matrix `TM' = r(table)
            }
            if _rc {
                local rc = _rc
                local stage = 5
            }
        }
        local plist ""
        forvalues j = 1/`NP' {
            if `stage' == 0 {
                local c_ = pc[`j']
                local l_ = pc_lci[`j']
                local u_ = pc_uci[`j']
                local x_ = xbv[`j']
                if `j' <= 3 local mrow "`T1'[`j',"
                else if `j' == 4 local mrow "`T0'[1,"
                else local mrow "`TM'[1,"
                local plist "`plist' (`c_') (`l_') (`u_') (`x_')"
                local plist "`plist' (`=`mrow'2]') (`=`mrow'3]') (`=`mrow'4]') (`=`mrow'5]')"
                if missing(`c_', `l_', `u_', `x_') local stage = 6
                else if !(`l_' < `c_' & `c_' < `u_') local stage = 6
            }
            else local plist "`plist' (.) (.) (.) (.) (.) (.) (.) (.)"
        }
        post `P' (`armno') (`r') (`rc') (`stage') (`pcens') (`bhat') (`v11') `plist'
        if `stage' != 0 display as error "  arm `arm' replicate `r': stage `stage' rc `rc'"
    }

    **## P3 contract half: xb exposes no interval (on the last replicate's fit)
    capture drop xbci
    capture finegray_predict double xbci, xb ci
    local xbci_rc`arm' = _rc
    capture confirm variable xbci
    local xbci_made`arm' = (_rc == 0)
    capture confirm variable xbci_lci
    if _rc == 0 local xbci_made`arm' = 1
}
postclose `P'

**# Replicate ledger
use "`reps'", clear
sort arm rep
quietly gen strL rngstate = ""
mata: st_sstore(., "rngstate", _fgcalp_st)
mata: mata drop _fgcalp_st
* Replay replicate r of arm a alone: set rng mt64; set rngstate <rngstate>,
* then the replicate body above.
quietly save "`qa_dir'/`suite'_replicates.dta", replace

* Implied SE from predict's own limits (the package's cloglog formula
* inverted), and the identity diagnostics against finegray_cif.
forvalues j = 1/`NP' {
    quietly gen double se`j' = (cloglog(uci`j') - cloglog(lci`j')) / (2 * `Z') ///
        * (1 - cif`j') * (-ln(1 - cif`j')) if stage == 0
    quietly gen double dpt`j' = max(abs(cif`j' - cifc`j'), abs(lci`j' - lcic`j'), ///
        abs(uci`j' - ucic`j')) if stage == 0
    quietly gen double dse`j' = abs(se`j' - sec`j') / sec`j' if stage == 0
    local zj : word `j' of `PZ'
    quietly gen double dxb`j' = abs(xb`j' - `zj' * bhat) if stage == 0
}

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
    quietly summarize pcens if arm == `armno'
    local pcens_m = r(mean)
    display as text _newline "Arm `arm' performance: `n_ok' of `R' replicates usable" ///
        " (fit error `n_s1', not converged `n_s2', predict cif `n_s3', predict xb `n_s4', finegray_cif `n_s5', nonfinite `n_s6')"
    display as text "  mean censored fraction " %5.3f `pcens_m'

    **## P1 every replicate usable, counters reconcile (both modes)
    local ++test_count
    local ok = (`nrow' == `R' & `n_ok' + `n_s1' + `n_s2' + `n_s3' + `n_s4' + `n_s5' + `n_s6' == `R' & `n_ok' == `R')
    if `ok' {
        display as result "  PASS: P1/`arm' all `R' replicates usable for all `NP' subjects"
        local ++pass_count
    }
    else {
        display as error "  FAIL: P1/`arm' usable `n_ok' of `R' (rows `nrow')"
        local ++fail_count
    }

    **## P2 predict and finegray_cif share the analytic core (both modes)
    local dpt_max = 0
    local dse_max = 0
    forvalues j = 1/`NP' {
        quietly summarize dpt`j' if arm == `armno' & stage == 0
        if r(max) > `dpt_max' | missing(r(max)) local dpt_max = r(max)
        quietly summarize dse`j' if arm == `armno' & stage == 0
        if r(max) > `dse_max' | missing(r(max)) local dse_max = r(max)
    }
    local ++test_count
    local ok = (`dpt_max' < 1e-10 & `dse_max' < 1e-8 & `n_ok' > 0)
    local lab : display "P2/`arm' predict = finegray_cif: max |CIF, limits| diff " %9.2e `dpt_max' ", max rel SE diff " %9.2e `dse_max'
    if `ok' {
        display as result "  PASS: `lab'"
        local ++pass_count
    }
    else {
        display as error "  FAIL: `lab'"
        local ++fail_count
    }

    **## P3 xb identity and no-interval contract (both modes)
    local dxb_max = 0
    forvalues j = 1/`NP' {
        quietly summarize dxb`j' if arm == `armno' & stage == 0
        if r(max) > `dxb_max' | missing(r(max)) local dxb_max = r(max)
    }
    local ++test_count
    local ok = (`dxb_max' < 1e-12 & `xbci_rc`arm'' == 198 & !`xbci_made`arm'' & `n_ok' > 0)
    local lab : display "P3/`arm' xb = z1*_b[z1] (max diff " %9.2e `dxb_max' "); xb ci refused rc=`xbci_rc`arm'', nothing created"
    if `ok' {
        display as result "  PASS: `lab'"
        local ++pass_count
    }
    else {
        display as error "  FAIL: `lab'"
        local ++fail_count
    }

    local cov_all = 1
    local rat_all = 1
    local neg_all = 1
    forvalues j = 1/`NP' {
        local zj : word `j' of `PZ'
        local kk : word `j' of `PHK'
        local hh : word `kk' of ``arm'_H'
        local truth = 1 - (1 - ``arm'_p'*(1 - exp(-`hh')))^exp(``arm'_b'*`zj')
        preserve
        quietly keep if arm == `armno' & stage == 0
        _fgcalp_perf, est(cif`j') se(se`j') lo(lci`j') hi(uci`j') truth(`truth') z(`Z')
        foreach s in mean bias bias_mcse empse modse ratio ratio_mcse cov cov_be cov_neg ratio_g {
            local `s' = r(`s')
        }
        * xb against the true x'beta; Wald coverage from e(V) is a diagnostic
        quietly summarize xb`j'
        local xb_bias = r(mean) - ``arm'_b' * `zj'
        local xb_mcse = r(sd) / sqrt(r(N))
        local xb_emp = r(sd)
        quietly gen byte _xcv = abs(xb`j' - ``arm'_b' * `zj') <= `Z' * abs(`zj') * sqrt(v11)
        quietly summarize _xcv, meanonly
        local xb_cov = r(mean)
        restore

        display as text "  subject `j' (z1=`zj', t=`hh') truth=" %7.5f `truth' " mean=" %7.5f `mean' ///
            " bias=" %8.5f `bias' " (MCSE " %7.5f `bias_mcse' ")"
        display as text "         EmpSE=" %7.5f `empse' " ModSE(implied)=" %7.5f `modse' ///
            " ratio=" %6.4f `ratio' " (MCSE " %6.4f `ratio_mcse' ") cloglog-ratio=" %6.4f `ratio_g'
        display as text "         coverage=" %6.4f `cov' " band [" %6.4f `cov_lo' ", " %6.4f `cov_hi' ///
            "] bias-eliminated=" %6.4f `cov_be' " half-width control=" %6.4f `cov_neg'
        if `zj' != 0 {
            display as text "         xb: truth=" %6.3f ``arm'_b' * `zj' " bias=" %8.5f `xb_bias' ///
                " (MCSE " %7.5f `xb_mcse' ") EmpSE=" %7.5f `xb_emp' ///
                " diagnostic e(V) Wald coverage (not package output)=" %6.4f `xb_cov'
        }
        else display as text "         xb: z1=0, xb is identically 0 = truth"

        if !(`cov' >= `cov_lo' & `cov' <= `cov_hi' & `cov' < .) local cov_all = 0
        if !(abs(`ratio' - 1) <= 3 * `ratio_mcse' & `ratio' < . & `ratio_mcse' < .) local rat_all = 0
        if !(`cov_neg' < `cov_lo' & `cov_neg' < .) local neg_all = 0
    }

    if !`smoke' {
        **## P4 coverage in band for every subject
        local ++test_count
        if `cov_all' {
            display as result "  PASS: P4/`arm' predict ci coverage inside the band for every subject"
            local ++pass_count
        }
        else {
            display as error "  FAIL: P4/`arm' predict ci coverage outside the band for a subject"
            local ++fail_count
        }

        **## P5 implied SE / empirical SD within 1 +/- 3 MCSE
        local ++test_count
        if `rat_all' {
            display as result "  PASS: P5/`arm' ModSE(implied)/EmpSE within 1 +/- 3 MCSE for every subject"
            local ++pass_count
        }
        else {
            display as error "  FAIL: P5/`arm' ModSE(implied)/EmpSE outside 1 +/- 3 MCSE for a subject"
            local ++fail_count
        }

        **## P6 negative control goes red
        local ++test_count
        if `neg_all' {
            display as result "  PASS: P6/`arm' half-width interval falls below the band for every subject"
            local ++pass_count
        }
        else {
            display as error "  FAIL: P6/`arm' half-width negative control did not fall below the band"
            local ++fail_count
        }
        local cls = cond(`cov_all' & `rat_all', "NOMINAL", "DEFECT")
        display as text "  CLASS: finegray_predict cif ci arm `arm': `cls'"
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
capture program drop _fgcalp_dgp
capture program drop _fgcalp_perf

display as text _newline "runtime `secs' seconds"
display as text "RESULT: `suite' tests=`test_count' pass=`pass_count' fail=`fail_count' smoke=`smoke' secs=`secs'"
if `fail_count' > 0 {
    display as error "`suite': `fail_count' check(s) FAILED"
    log close _fgcalp
    exit 9
}
if `smoke' {
    display as text "SMOKE RUN: code path exercised only; not gate evidence"
    log close _fgcalp
    exit 0
}
display as result "`suite': all checks passed"
log close _fgcalp
