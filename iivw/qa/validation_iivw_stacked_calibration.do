* =============================================================================
* validation_iivw_stacked_calibration.do - is vce(stacked) the right SIZE?
* =============================================================================
* Route covered: iivw_fit weighted GEE, vce(stacked), the two-step
* influence-function sandwich. crossval_iivw_stacked_geex.do proves that the
* matrix equals the one geex builds from the same estimating equations;
* test_iivw_stacked.do proves the arithmetic. Neither says the standard error
* has the right MAGNITUDE against the sampling distribution of the estimator,
* which is the question here. It promotes what probe_stacked_calibration.do
* learned (that diagnostic is untouched; this is a separate, preregistered
* gate) into a suite with computed gates and a negative control.
*
* ADEMP (Morris, White & Crowther 2019, Stat Med 38:2074, Table 1)
*   Aims        Do the standard error and Wald 95% interval iivw_fit reports
*               under vce(stacked) have nominal properties when the weights
*               are ESTIMATED from a correctly specified model?
*   DGP         Cell iptw   : n=400 subjects, 5 visits (t=1..5), confounded
*                             binary treatment a ~ Bern(expit(0.5 k1 - 0.4 k2)),
*                             y = 1 + 0.5 a + 0.8 k1 - 0.6 k2 + 0.1 t + N(0,1).
*                             IPTW from the correctly specified logit.
*               Cell fiptiw : n=400 subjects, irregular visits (exponential
*                             gaps, rate exp(-0.3 + 0.4 z1 + 0.3 a), follow-up
*                             to maxfu 7, first visit at t in (0.05, 0.45)),
*                             a ~ Bern(expit(0.5 k1 - 0.4 k2)),
*                             y = 1 + 0.5 a + 0.8 k1 - 0.6 k2 + 0.6 z1 + 0.1 t
*                             + N(0,1). FIPTIW weight from the correctly
*                             specified Cox visit model (z1, a) and logit.
*   Estimand    the coefficient of a in the marginal model y ~ a + t, true
*               value 0.5 (additive effect, correct propensity and visit models)
*   Methods     iivw_weight ..., scores ; iivw_fit y a, timespec(linear)
*               vce(stacked)  [under test]
*               iivw_fit ..., vce(fixed)  [negative control: the same
*               estimator with the weight-estimation derivative term absent]
*   Performance coverage of the interval iivw_fit REPORTS (e(iivw_ci)); ModSE
*               = sqrt(mean(se^2)) over EmpSE = SD of the estimates; bias with
*               its MCSE (reported); failed fits (gate: zero)
*
* GATES (computed in the suite from R, never typed)
*   coverage in 0.95 +/- 3*sqrt(0.95*0.05/R)
*   |ModSE/EmpSE - 1| <= 3 * MCSE(ratio), MCSE per Morris et al. Table 6
*   every replicate returns a finite estimate, SE and interval
*   R = 1000 per cell: coverage MCSE 0.0069, band [0.9293, 0.9707]. R was chosen
*   from R = p(1-p)/MCSE^2 for a 0.7-point MCSE and the measured cost of ~0.25 s
*   per replicate (the weighting and two fits), about 4 minutes per cell.
*   Seed 20261016 set once; each replicate's c(rngstate) is retained, so a
*   failing replicate can be replayed alone.
*
* PREREGISTERED EXPECTATION (written before the gated run)
*   stacked : NOMINAL in both cells. Class NOMINAL.
*   fixed   : CONSERVATIVE in both cells. With a correctly specified propensity
*             model an estimated score is more efficient than a known one, so
*             treating the weights as known over-covers. Class
*             CONSERVATIVE-DECLARED is the label this expectation would carry;
*             the suite asserts it as the negative control (the fixed variance
*             must FAIL the nominal gate, from above), which shows the gate can
*             go red. A stacked result outside the band, or a fixed result
*             inside it, is a DEFECT or a vacuous control respectively.
*
* The smoke form (`smoke' argument) runs 10 replicates per cell, checks the
* code path (every replicate returns finite b, se and interval, counters
* reconcile, the verdict code runs), never applies a band and prints smoke=1.
* It is not calibration evidence. Lane: sensitivity (gate), full (smoke).
*
* WORKED RUN (2026-10-15, R=1000 per cell, seed 20261016; gates frozen above
* before it, nothing was re-tuned after seeing it; ~6 minutes in all)
*   cell iptw   : bias +0.0032 (MCSE 0.0017); EmpSE 0.0548
*                 stacked ModSE/EmpSE 1.0024 (MCSE 0.0233), coverage 0.9550
*                 fixed   ModSE/EmpSE 2.3079 (MCSE 0.0523), coverage 1.0000
*   cell fiptiw : bias -0.0023 (MCSE 0.0031); EmpSE 0.0988
*                 stacked ModSE/EmpSE 0.9590 (MCSE 0.0219), coverage 0.9340
*                 fixed   ModSE/EmpSE 1.5055 (MCSE 0.0342), coverage 0.9930
*   Both stacked cells are NOMINAL by the gate; the fiptiw cell sits 0.5 point
*   above the lower edge of the band with ModSE about 4% below EmpSE, inside
*   3 MCSE but not a result to read as exactly 1. Both fixed cells are
*   CONSERVATIVE, which is the negative control going red (C4). Class per cell:
*   stacked NOMINAL; fixed CONSERVATIVE (asserted as the control, not as a
*   supported route; vce(fixed) is not the route under test).
* =============================================================================

clear all
set more off
* A RESULT: line longer than the batch log's 80-column wrap would be cut at the
* receipt parser, losing the smoke= flag.
set linesize 255
version 16.0
set varabbrev off

args mode
local smoke = ("`mode'" == "smoke")
if "`mode'" != "" & !`smoke' {
    display as error "unknown argument `mode'; the only accepted argument is smoke"
    exit 198
}

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "validation_iivw_stacked_calibration.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap

**# Predeclared design
local R_GATE  = 1000
local SMOKE_R = 10
local R       = cond(`smoke', `SMOKE_R', `R_GATE')
local SEED    = 20261016
local NOMINAL = 0.95
local TRUTH   = 0.5
local NSUB    = 400

local cov_mcse = sqrt(`NOMINAL' * (1 - `NOMINAL') / `R')
local cov_lo   = `NOMINAL' - 3 * `cov_mcse'
local cov_hi   = `NOMINAL' + 3 * `cov_mcse'

display as text "validation_iivw_stacked_calibration: R=`R' (gate R=`R_GATE'), seed `SEED', smoke=`smoke'"
display as text "  coverage band [" %6.4f `cov_lo' ", " %6.4f `cov_hi' "] (MCSE " %6.4f `cov_mcse' ")"

local test_count = 8
local pass_count = 0
local fail_count = 0
local skip_count = 0
local failed_tests ""

**# DGP
capture program drop _cal_dgp
program define _cal_dgp
    args cell nsub
    clear
    quietly set obs `nsub'
    * lint: unseeded-ok -- the seed is set once before the replicate loop and
    * each replicate's c(rngstate) is retained; reseeding here would repeat draws.
    quietly gen long id = _n
    quietly gen double k1 = rnormal()
    quietly gen double k2 = rnormal()
    quietly gen double z1 = rnormal()
    quietly gen byte a = runiform() < invlogit(0.5*k1 - 0.4*k2)
    if "`cell'" == "iptw" {
        quietly expand 5
        quietly bysort id: gen int j = _n
        quietly gen double t = j
        quietly gen double y = 1 + 0.5*a + 0.8*k1 - 0.6*k2 + 0.1*t + rnormal()
    }
    else {
        quietly expand 25
        quietly bysort id: gen int j = _n
        quietly gen double gap = -ln(runiform())/exp(-0.3 + 0.4*z1 + 0.3*a)
        quietly replace gap = 0.05 + 0.4*runiform() if j == 1
        quietly bysort id (j): gen double t = sum(gap)
        quietly keep if t < 7
        quietly gen double y = 1 + 0.5*a + 0.8*k1 - 0.6*k2 + 0.6*z1 + 0.1*t + rnormal()
    }
    quietly sort id t
end

* One replicate: weights with scores, then both variance estimators on the SAME
* weights. Returns the estimate, the reported SE and the reported interval.
capture program drop _cal_fit
program define _cal_fit, rclass
    args cell
    if "`cell'" == "iptw" {
        iivw_weight, id(id) time(t) treat(a) treat_cov(k1 k2) wtype(iptw) ///
            scores nolog
    }
    else {
        iivw_weight, id(id) time(t) visit_cov(z1) treat(a) treat_cov(k1 k2) ///
            wtype(fiptiw) maxfu(7) scores nolog
    }
    iivw_fit y a, timespec(linear) vce(stacked)
    tempname ci
    matrix `ci' = e(iivw_ci)
    return scalar b   = _b[a]
    return scalar se_s = _se[a]
    return scalar lo_s = `ci'[1, 1]
    return scalar hi_s = `ci'[2, 1]
    iivw_fit y a, timespec(linear) vce(fixed)
    matrix `ci' = e(iivw_ci)
    return scalar se_f = _se[a]
    return scalar lo_f = `ci'[1, 1]
    return scalar hi_f = `ci'[2, 1]
    return scalar b_f = _b[a]
end

* The reported interval's first column must be the coefficient of a, which the
* loop reads by position. Checked once, on a throwaway panel, before any
* replicate is accepted.
capture program drop _cal_check_cols
program define _cal_check_cols
    quietly _cal_dgp iptw 120
    quietly iivw_weight, id(id) time(t) treat(a) treat_cov(k1 k2) wtype(iptw) ///
        scores nolog
    quietly iivw_fit y a, timespec(linear) vce(stacked)
    local cn : colnames e(iivw_ci)
    local first : word 1 of `cn'
    if "`first'" != "a" & "`first'" != "y:a" {
        display as error "e(iivw_ci) first column is `first', expected a"
        exit 459
    }
end
set seed 1
_cal_check_cols

* c(rngstate) is too long for a str# post: start states are held in Mata and
* attached as a strL column after the loop. Each cell takes its own stream of
* the one seed (set rng mt64s; set seed; set rngstream), and every replicate is
* retained, failed ones included.
set rng mt64s
local cells iptw fiptiw
local ic = 0
foreach cell of local cells {
    local ++ic
    display as text _newline "cell `cell': `R' replicates"
    set seed `SEED'
    set rngstream `ic'
    tempfile reps_`cell'
    tempname P
    postfile `P' long rep int rc double(b se_s lo_s hi_s se_f lo_f hi_f b_f) ///
        using "`reps_`cell''", replace
    mata: _cal_states = J(`R', 1, "")
    forvalues r = 1/`R' {
        mata: _cal_states[`r'] = c("rngstate")
        quietly _cal_dgp `cell' `NSUB'
        capture quietly _cal_fit `cell'
        local rc = _rc
        if `rc' == 0 {
            post `P' (`r') (0) (r(b)) (r(se_s)) (r(lo_s)) (r(hi_s)) ///
                (r(se_f)) (r(lo_f)) (r(hi_f)) (r(b_f))
        }
        else {
            post `P' (`r') (`rc') (.) (.) (.) (.) (.) (.) (.) (.)
        }
    }
    postclose `P'

    preserve
    quietly use "`reps_`cell''", clear
    quietly sort rep
    quietly gen strL rngstate = ""
    mata: st_sstore(., "rngstate", _cal_states)
    mata: mata drop _cal_states
    quietly count if rc == 0 & !missing(b, se_s, lo_s, hi_s, se_f, lo_f, hi_f)
    local n_ok = r(N)
    local n_bad = `R' - `n_ok'
    if `n_bad' > 0 {
        quietly summarize rep if rc != 0 | missing(b, se_s, lo_s, hi_s, se_f, lo_f, hi_f), meanonly
        local first_bad = r(min)
        local st_bad = rngstate[`first_bad']
        display as error "`cell': `n_bad' failed replicate(s); first = `first_bad'"
        display as error "  replay alone: set rngstate `st_bad'"
    }

    * the estimator is the same under both variances
    quietly gen double bdiff = abs(b - b_f)
    quietly summarize bdiff, meanonly
    local bdiff_max = r(max)

    quietly summarize b
    local mean_b = r(mean)
    local emp_se = r(sd)
    local bias = `mean_b' - `TRUTH'
    local bias_mcse = r(sd) / sqrt(r(N))
    local emp_mcse = `emp_se' / sqrt(2 * (r(N) - 1))

    foreach v in s f {
        quietly gen double v_`v' = se_`v'^2
        quietly summarize v_`v'
        local mod_`v' = sqrt(r(mean))
        local varv_`v' = r(Var)
        local ratio_`v' = `mod_`v'' / `emp_se'
        * Morris et al. Table 6, relative error in ModSE, approximate
        local rmcse_`v' = `ratio_`v'' * sqrt(`varv_`v'' / (4 * `n_ok' * `mod_`v''^4) ///
            + 1 / (2 * (`n_ok' - 1)))
        quietly gen byte cov_`v' = (lo_`v' <= `TRUTH' & `TRUTH' <= hi_`v') ///
            if !missing(lo_`v', hi_`v')
        quietly summarize cov_`v', meanonly
        local cov_`v' = r(mean)
    }
    restore

    display as text "  bias " %9.5f `bias' " (MCSE " %8.5f `bias_mcse' ")  EmpSE " ///
        %9.5f `emp_se' " (MCSE " %8.5f `emp_mcse' ")  n_ok `n_ok'/`R'"
    display as text "  stacked: ModSE " %9.5f `mod_s' "  ModSE/EmpSE " %7.4f `ratio_s' ///
        " (MCSE " %7.4f `rmcse_s' ")  coverage " %6.4f `cov_s'
    display as text "  fixed  : ModSE " %9.5f `mod_f' "  ModSE/EmpSE " %7.4f `ratio_f' ///
        " (MCSE " %7.4f `rmcse_f' ")  coverage " %6.4f `cov_f'
    display as text "  gate: coverage in [" %6.4f `cov_lo' ", " %6.4f `cov_hi' "]"

    * ---- C1: every replicate returned finite b, se, interval; same estimator
    local ok = (`n_bad' == 0) & (`bdiff_max' < 1e-12)
    if `ok' {
        local ++pass_count
        display "PASS C1-`cell': all `R' replicates returned b, se and interval"
    }
    else {
        local ++fail_count
        local failed_tests "`failed_tests' C1-`cell'"
        display "FAIL C1-`cell': `n_bad' failed replicates (b diff `bdiff_max')"
    }

    if `smoke' {
        * smoke contract: count only the checks that run (C1), so skip stays 0
        local test_count = `test_count' - 3
        display as text "  smoke form: gates C2-C4 not applied for `cell'"
    }
    else {
        * ---- C2: stacked coverage inside nominal +/- 3 MCSE ('< .' guards a
        * missing rate, which compares above every number)
        if `cov_s' < . & `cov_s' >= `cov_lo' & `cov_s' <= `cov_hi' {
            local ++pass_count
            display "PASS C2-`cell': stacked coverage " %6.4f `cov_s' " inside the band"
        }
        else {
            local ++fail_count
            local failed_tests "`failed_tests' C2-`cell'"
            display "FAIL C2-`cell': stacked coverage " %6.4f `cov_s' " outside [" ///
                %6.4f `cov_lo' ", " %6.4f `cov_hi' "] (DEFECT)"
        }
        * ---- C3: stacked ModSE/EmpSE within 3 MCSE of 1
        if `ratio_s' < . & abs(`ratio_s' - 1) <= 3 * `rmcse_s' {
            local ++pass_count
            display "PASS C3-`cell': stacked ModSE/EmpSE " %7.4f `ratio_s' " within 1 +/- 3 MCSE"
        }
        else {
            local ++fail_count
            local failed_tests "`failed_tests' C3-`cell'"
            display "FAIL C3-`cell': stacked ModSE/EmpSE " %7.4f `ratio_s' ///
                " outside 1 +/- " %7.4f 3*`rmcse_s' " (DEFECT)"
        }
        * ---- C4: negative control. The fixed-weight variance (the stacked one
        * with the weight-estimation term absent) must FAIL the same gate, from
        * above. A gate that passes it could not detect a missing correction.
        if `cov_f' < . & `cov_f' > `cov_hi' & `ratio_f' < . & ///
                `ratio_f' > 1 + 3 * `rmcse_f' {
            local ++pass_count
            display "PASS C4-`cell': fixed variance goes red (coverage " %6.4f `cov_f' ///
                " > " %6.4f `cov_hi' ", ratio " %7.4f `ratio_f' ")"
        }
        else {
            local ++fail_count
            local failed_tests "`failed_tests' C4-`cell'"
            display "FAIL C4-`cell': the fixed variance does not fail the gate; the control is vacuous"
        }
    }
}

**# SUMMARY
display as text _newline "validation_iivw_stacked_calibration: `pass_count'/`test_count' passed, `fail_count' failed, `skip_count' skipped"
local executed = `pass_count' + `fail_count'
if `executed' + `skip_count' != `test_count' {
    display as error "counter corruption: pass+fail+skip != tests"
    display "RESULT: validation_iivw_stacked_calibration tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count' smoke=`smoke'"
    iivw_qa_sandbox_restore
    exit 198
}
if `fail_count' > 0 {
    display as error "FAILED TESTS: `failed_tests'"
    display "RESULT: validation_iivw_stacked_calibration tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count' smoke=`smoke'"
    iivw_qa_sandbox_restore
    exit 1
}
if `smoke' {
    display as text "SMOKE RUN: code path exercised only; not gate evidence"
    display "RESULT: validation_iivw_stacked_calibration tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count' smoke=1"
}
else {
    display as result "ALL EXECUTED TESTS PASSED"
    display "RESULT: validation_iivw_stacked_calibration tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count' smoke=0"
}
iivw_qa_sandbox_restore
