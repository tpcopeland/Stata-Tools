clear all
set more off
version 16.0
set varabbrev off
* the RESULT: line is longer than 80 characters; a wrapped line would hide smoke=
set linesize 255

* validation_iivw_links_calibration.do
*
* Inference calibration of the REPORTED standard error and 95% interval of the weighted
* iivw_fit GEE for the Poisson-log and binomial-logit links, under the two analytic
* variance routes the help file supports for these links:
*   vce(fixed)    cluster-robust sandwich with the IIW weights treated as KNOWN
*   vce(stacked)  two-step influence-function sandwich (canonical links: both of these qualify)
* (the default refit bootstrap is calibrated in validation_iivw_inference.do).
*   stata-mp -b do validation_iivw_links_calibration.do          gate (sim lane)
*   stata-mp -b do validation_iivw_links_calibration.do smoke    code path only
* The smoke form runs 10 replicates per cell, checks that every replicate returns a finite
* estimate/SE/interval for both routes, never applies a band, prints smoke=1, exits 0.
*
* ADEMP (Morris, White & Crowther 2019, Table 1; written before the gated run)
*   Aims        Do the reported SE and interval of the weighted link-GEE have nominal coverage
*               and an SE that tracks the empirical SD, for each analytic route?
*   DGPs        the informative-visit DGPs of _iivw_links_dgp.do, 2 links x 2 DGPs = 4 cells,
*               n = 400 subjects (see validation_iivw_links_recovery.do for the truths; the
*               truth is the MARGINAL coefficient, closed form for Poisson, quadrature for
*               logit).
*   Estimand    marginal b_x (Poisson 1.0906; logit DGP1 1.1132, DGP2 .9319).
*   Methods     iivw_weight (IIW, visit_cov(Z), scores) then iivw_fit family(poisson|binomial)
*               with vce(fixed) and vce(stacked). The interval is READ from e(iivw_ci).
*               Negative controls on the same replicates: (i) the weighted GLM with an
*               observation-level robust SE that IGNORES clustering (must under-cover: rows
*               of a subject share Z, x and the subject effect), (ii) the reported fixed
*               interval shrunk to half width.
*   Performance coverage (gate), ModSE/EmpSE with ModSE = sqrt(mean se^2) (gate), bias with
*               MCSE (reported), failures (gate: zero).
* GATES (computed from R below, never typed)
*   coverage in .95 +/- 3*sqrt(.95*.05/R); R = 1000 -> MCSE .0069, band [.9293, .9707]
*   |ModSE/EmpSE - 1| <= 3*MCSE(ratio), MCSE per Morris et al. Table 6
*   n_ok == R in every cell; negative controls fall BELOW the coverage band
* Seeds: set seed 2026150c once per cell (c = cell 1..4), each replicate's c(rngstate) kept.
*
* EXPECTED CLASS (fixed BEFORE the gated run): NOMINAL for BOTH routes in all four cells.
*   iivw_fit.sthlp does NOT declare vce(fixed) conservative: it says the omitted nuisance
*   correction "can make the interval either narrower or wider" and "do not assume the fixed
*   sandwich is conservative". With no declared direction there is no CONSERVATIVE-DECLARED
*   class to claim, so a fixed interval above the band would be a DEFECT (undeclared
*   over-coverage), not a pass. vce(stacked) is described as the analytic correction, so
*   NOMINAL is the only class it may claim. An R = 300 pilot (uncorrected DGP) read coverage .947-.970
*   and ModSE/EmpSE .99-1.04, with stacked and fixed SEs agreeing to
*   about 0.5%: with the visit driver Z outside the outcome model the nuisance-estimation
*   correction is nearly orthogonal to the outcome score here, so this suite certifies the
*   interval's calibration in these cells but cannot, by itself, discriminate the two routes.
* WORKED RUN (R = 1000 per cell, n = 400, first gated run on the corrected DGP, gates unchanged;
*   bias with MCSE, coverage, ModSE/EmpSE) -- fixed / stacked
*   poisson DGP1: +.0014 (.0018)  .950 / .949   1.029 / 1.024      no-clustering SE .763
*   poisson DGP2: -.0026 (.0030)  .960 / .960   1.017 / 1.015      no-clustering SE .549
*   logit   DGP1: +.0054 (.0034)  .942 / .942   1.009 / 1.009      no-clustering SE .920
*   logit   DGP2: +.0066 (.0039)  .946 / .947   .970 / .970        no-clustering SE .779
*   band [.9293, .9707]. Weakest negative control: logit DGP1 no-clustering SE at .920
*   (subjects contribute few binary rows, so ignoring clustering costs little there); it is
*   still below the band; the half-width control is C6's second leg and also below it.

args mode
local smoke = ("`mode'" == "smoke")
if "`mode'" != "" & !`smoke' {
    display as error "unknown argument `mode'; the only accepted argument is smoke"
    exit 198
}
do "`c(pwd)'/_iivw_qa_common.do"
local qa_dir "`c(pwd)'"
if substr("`qa_dir'", -3, 3) != "/qa" {
    display as error "validation_iivw_links_calibration.do must be run from iivw/qa"
    exit 198
}
iivw_qa_bootstrap
do "`qa_dir'/_iivw_links_dgp.do"

local R_GATE  = 1000
local SMOKE_R = 10
local R       = cond(`smoke', `SMOKE_R', `R_GATE')
local NOMINAL = 0.95
local NOBS    = 400
local cov_mcse = sqrt(`NOMINAL' * (1 - `NOMINAL') / `R')
local cov_lo   = `NOMINAL' - 3 * `cov_mcse'
local cov_hi   = `NOMINAL' + 3 * `cov_mcse'
display as text "validation_iivw_links_calibration: R=`R' per cell (gate R=`R_GATE'), n=`NOBS', smoke=`smoke'"
display as text "  coverage band [" %6.4f `cov_lo' ", " %6.4f `cov_hi' "] (MCSE " %6.4f `cov_mcse' ")"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _lkc_block
program define _lkc_block
    syntax , DGP(integer) LINK(string) N(integer) R(integer) SEED(integer) FILE(string)
    local fam = cond("`link'" == "logit", "binomial", "poisson")
    tempname P
    postfile `P' int rep int rc double(bf sf lf uf bs ss ls us nb ns) ///
        str2045 rngstate using "`file'", replace
    set seed `seed'
    forvalues r = 1/`r' {
        local st = c(rngstate)
        _lk_gen, dgp(`dgp') link(`link') n(`n')
        local bf = .
        local sf = .
        local lf = .
        local uf = .
        local bs = .
        local ss = .
        local ls = .
        local us = .
        local nb = .
        local ns = .
        tempname CI
        capture quietly {
            iivw_weight, id(id) time(t) visit_cov(Z) wtype(iivw) maxfu(3) baseline(entry) ///
                nolog replace scores
            iivw_fit y x, family(`fam') vce(fixed) timespec(linear) nolog replace
            matrix `CI' = e(iivw_ci)
            local bf = _b[x]
            local sf = _se[x]
            local lf = `CI'[1, colnumb(`CI', "y:x")]
            local uf = `CI'[2, colnumb(`CI', "y:x")]
            iivw_fit y x, family(`fam') vce(stacked) timespec(linear) nolog replace
            matrix `CI' = e(iivw_ci)
            local bs = _b[x]
            local ss = _se[x]
            local ls = `CI'[1, colnumb(`CI', "y:x")]
            local us = `CI'[2, colnumb(`CI', "y:x")]
            glm y x t [pweight = _iivw_weight], family(`fam') vce(robust) nolog
            local nb = _b[x]
            local ns = _se[x]
        }
        post `P' (`r') (_rc) (`bf') (`sf') (`lf') (`uf') (`bs') (`ss') (`ls') (`us') ///
            (`nb') (`ns') ("`st'")
    }
    postclose `P'
end

capture program drop _lkc_perf
program define _lkc_perf, rclass
    syntax , B(string) SE(string) LO(string) HI(string) TRUTH(real)
    quietly count if rc == 0 & !missing(`b', `se', `lo', `hi')
    local nok = r(N)
    quietly summarize `b'
    local emp = r(sd)
    return scalar bias = r(mean) - `truth'
    return scalar bmcse = r(sd) / sqrt(r(N))
    tempvar v cv
    quietly gen double `v' = `se'^2
    quietly summarize `v'
    local mod = sqrt(r(mean))
    local varv = r(Var)
    return scalar ratio = `mod' / `emp'
    return scalar rmcse = sqrt(`varv' / (4 * `nok' * `mod'^4) + 1 / (2 * (`nok' - 1)))
    quietly gen byte `cv' = (`lo' <= `truth' & `truth' <= `hi') if !missing(`lo', `hi')
    quietly summarize `cv', meanonly
    return scalar cov = r(mean)
    return scalar nok = `nok'
end

capture program drop _cal_incov
program define _cal_incov, rclass
    args cov lo hi
    return scalar ok = (`cov' < . & `cov' >= `lo' & `cov' <= `hi')
end

local cells "poisson:1 poisson:2 logit:1 logit:2"
local ci = 0
local nbad_all = 0
foreach c of local cells {
    local ++ci
    tokenize "`c'", parse(":")
    local link `1'
    local dgp `3'
    tempfile f`ci'
    _lk_truth, dgp(`dgp') link(`link')
    local truth`ci' = r(bx)
    _lkc_block, dgp(`dgp') link(`link') n(`NOBS') r(`R') seed(`=20261500 + `ci'') file("`f`ci''")
    use "`f`ci''", clear
    quietly count if rc != 0 | missing(bf, sf, lf, uf, bs, ss, ls, us, nb, ns)
    local nbad`ci' = r(N)
    local nbad_all = `nbad_all' + r(N)
    _lkc_perf, b(bf) se(sf) lo(lf) hi(uf) truth(`truth`ci'')
    foreach m in cov ratio rmcse bias bmcse nok {
        local `m'_f`ci' = r(`m')
    }
    _lkc_perf, b(bs) se(ss) lo(ls) hi(us) truth(`truth`ci'')
    foreach m in cov ratio rmcse bias bmcse nok {
        local `m'_s`ci' = r(`m')
    }
    * negative control (i): obs-level robust SE ignoring clustering
    quietly gen byte ncv = (bf - invnormal(.975) * ns <= `truth`ci'' & `truth`ci'' <= bf + invnormal(.975) * ns) if !missing(bf, ns)
    quietly summarize ncv, meanonly
    local negcov`ci' = r(mean)
    * negative control (ii): reported fixed interval at half width
    quietly gen byte hcv = ((bf + (lf - bf) / 2) <= `truth`ci'' & `truth`ci'' <= (bf + (uf - bf) / 2)) if !missing(lf, uf)
    quietly summarize hcv, meanonly
    local halfcov`ci' = r(mean)
    display as text _newline "`link' DGP`dgp' (n=`NOBS', R=`R'): truth b_x " %8.4f `truth`ci'' ", failed fits `nbad`ci''"
    display as text "  vce(fixed)   bias " %8.4f `bias_f`ci'' " (MCSE " %7.4f `bmcse_f`ci'' ")  coverage " %6.4f `cov_f`ci'' "  ModSE/EmpSE " %6.4f `ratio_f`ci'' " (MCSE " %6.4f `rmcse_f`ci'' ")"
    display as text "  vce(stacked) bias " %8.4f `bias_s`ci'' " (MCSE " %7.4f `bmcse_s`ci'' ")  coverage " %6.4f `cov_s`ci'' "  ModSE/EmpSE " %6.4f `ratio_s`ci'' " (MCSE " %6.4f `rmcse_s`ci'' ")"
    display as text "  neg control (no clustering): coverage " %6.4f `negcov`ci'' "; half-width fixed interval: coverage " %6.4f `halfcov`ci''
}

**# C1: every replicate fit and returned finite b, se, ci for both routes (both modes)
local ++test_count
if `nbad_all' == 0 {
    display as result "  PASS: C1 all `R' replicates in all 4 cells returned b, se, ci for both routes"
    local ++pass_count
}
else {
    display as error "  FAIL: C1 `nbad_all' replicates failed or returned missing values"
    local ++fail_count
    local failed_tests "`failed_tests' C1"
}

if !`smoke' {
    local ci = 0
    foreach c of local cells {
        local ++ci
        tokenize "`c'", parse(":")
        local lab "`1' DGP`3'"
        local tn = `ci' + 1
        **# C2-C5: per cell, coverage and ModSE/EmpSE of both routes inside the gates
        local ++test_count
        local allok 1
        foreach rt in f s {
            _cal_incov `cov_`rt'`ci'' `cov_lo' `cov_hi'
            if r(ok) != 1 local allok 0
            if !(abs(`ratio_`rt'`ci'' - 1) <= 3 * `rmcse_`rt'`ci'' & `ratio_`rt'`ci'' < .) local allok 0
        }
        if `allok' {
            display as result "  PASS: C`tn' `lab' fixed (cov " %6.4f `cov_f`ci'' ", ratio " %6.4f `ratio_f`ci'' ") and stacked (cov " %6.4f `cov_s`ci'' ", ratio " %6.4f `ratio_s`ci'' ") NOMINAL"
            local ++pass_count
        }
        else {
            display as error "  FAIL: C`tn' `lab' fixed (cov " %6.4f `cov_f`ci'' ", ratio " %6.4f `ratio_f`ci'' ") stacked (cov " %6.4f `cov_s`ci'' ", ratio " %6.4f `ratio_s`ci'' ") outside gates"
            local ++fail_count
            local failed_tests "`failed_tests' C`tn'"
        }
    }
    **# C6: negative controls fall below the band in every cell
    local ++test_count
    local allred 1
    forvalues k = 1/4 {
        _cal_incov `negcov`k'' `cov_lo' `cov_hi'
        local r1 = r(ok)
        _cal_incov `halfcov`k'' `cov_lo' `cov_hi'
        local r2 = r(ok)
        if `r1' != 0 | `r2' != 0 | `negcov`k'' >= `cov_lo' | `halfcov`k'' >= `cov_lo' local allred 0
    }
    if `allred' {
        display as result "  PASS: C6 negative controls fall below the band in all 4 cells (no-clustering SE: " ///
            %6.4f `negcov1' " " %6.4f `negcov2' " " %6.4f `negcov3' " " %6.4f `negcov4' ")"
        local ++pass_count
    }
    else {
        display as error "  FAIL: C6 a negative control did not go red"
        local ++fail_count
        local failed_tests "`failed_tests' C6"
    }
}

display "RESULT: validation_iivw_links_calibration tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0 smoke=`smoke'"
if `smoke' display as text "SMOKE RUN: code path exercised only; not gate evidence"
iivw_qa_sandbox_restore
if `fail_count' > 0 exit 1
