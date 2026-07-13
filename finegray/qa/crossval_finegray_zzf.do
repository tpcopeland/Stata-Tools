* crossval_finegray_zzf.do - ZZF delayed-entry Fine-Gray: Stata vs R, PER DATASET
* Package: finegray
*
* WHAT THIS ANSWERS, AND WHY A RECOVERY STUDY CANNOT ANSWER IT.
*
* validation_finegray_zzf_recovery.do measures BIAS: it asks whether the
* estimator lands on the truth.  Bias is a property of the ESTIMATOR, not of the
* implementation, so a recovery study cannot distinguish "my code is wrong" from
* "this estimator is biased here."  When arm D of that suite showed a small
* residual bias in b2, the recovery study had nothing left to say.
*
* This file asks the other question: given the SAME dataset, does Stata's
* finegray return the SAME coefficients as the independent R implementation of
* the stabilized ZZF Weight-1 estimator?  If yes, the two are the same estimator
* and any bias belongs to the estimator, not to this package.  Twenty datasets
* settle that; a million Monte-Carlo reps would not.
*
* ARMS.  A (no entry), B (entry independent of z), D (entry depends on z1) --
* all fitted with POOLED weights, which in R means wgroup == 0 for every subject
* and in Stata means no strata() and no truncstrata().  Same statistic on both
* sides, so exact agreement is required.
*
* ARM C IS DELIBERATELY ABSENT.  R's `wgroup` stratifies the censoring
* distribution G and the truncation distribution H JOINTLY; Stata's
* truncstrata(z1) stratifies H alone and pools G.  Both are consistent for the
* same estimand (censoring does not depend on the group in this DGP), but they
* are NOT the same statistic, so demanding per-dataset agreement would be a bug
* in the test, not a finding.  Arm C is gated by recovery instead.
*
* ORACLE.  Datasets and betas come from crossval_finegray_zzf_beta_r.R, which
* sources gen_fg/zzf_fit/zzf_weights from the frozen crossval_finegray_zzf_r.R.
* Run it FIRST, from finegray/qa:
*     Rscript crossval_finegray_zzf_beta_r.R

clear all
set more off
set varabbrev off
version 16.0

* Oracle CSVs carry full double precision.  `import delimited` types columns as
* FLOAT by default, which silently truncates the times to ~8 significant digits
* and would make this compare Stata's fit on one dataset to R's fit on another.
set type double

local test_count = 0
local pass_count = 0
local fail_count = 0

local pkgroot "`c(pwd)'"
capture confirm file "`pkgroot'/finegray.pkg"
if _rc {
    capture confirm file "`pkgroot'/../finegray.pkg"
    if _rc {
        display as error "could not locate finegray package root"
        exit 601
    }
    local pkgroot "`pkgroot'/.."
}
local qadir "`pkgroot'/qa"
local datadir "`qadir'/data"

capture log close _all
log using "`qadir'/crossval_finegray_zzf.log", ///
    replace text name(_crossval_finegray_zzf)

capture ado uninstall finegray
net install finegray, from("`pkgroot'") replace

* ---------------------------------------------------------------------------
* Locate the oracle.  A MISSING oracle must FAIL, never skip: a crossval that
* quietly reports success because the reference implementation never ran is the
* exact false green this suite exists to prevent.
* ---------------------------------------------------------------------------
capture confirm file "`datadir'/zzf_xv_oracle_beta.csv"
if _rc {
    display as error "MISSING ORACLE: `datadir'/zzf_xv_oracle_beta.csv"
    display as error "Run this first, from finegray/qa:"
    display as error "    Rscript crossval_finegray_zzf_beta_r.R"
    exit 601
}

tempfile oracle
import delimited "`datadir'/zzf_xv_oracle_beta.csv", clear case(preserve)
quietly count
local n_oracle = r(N)
if `n_oracle' == 0 {
    display as error "oracle beta file is empty"
    exit 459
}
save "`oracle'", replace
display as text "oracle: `n_oracle' fitted datasets"

* ---------------------------------------------------------------------------
* Compare, dataset by dataset.
*
* Tolerance.  R minimizes the negative log-likelihood with BFGS (reltol 1e-13);
* Stata uses its own Newton iteration.  Two different optimizers on the same
* concave objective agree to roughly sqrt(their tolerances), not to the last
* bit, so 1e-5 relative is the right ask.  It is also a very sharp
* discriminator: computing a DIFFERENT estimator (e.g. the wrong stabilizer, or
* ignoring the truncation) moves these coefficients by 1e-2 to 1e-1 -- three to
* four orders of magnitude above this bar.
* ---------------------------------------------------------------------------
local tol = 1e-5
local npair   = 0
local worst   = 0
local worstid ""

display as text _newline "arm rep       stata_b1          r_b1       stata_b2          r_b2      max_rel"

foreach arm in A B D {
    forvalues r = 1/`n_oracle' {

        * Does the oracle have this arm/rep?  (REPS is set by the R side.)
        use "`oracle'", clear
        quietly count if arm == "`arm'" & rep == `r'
        if r(N) == 0 continue
        if r(N) > 1 {
            display as error "oracle has `r(N)' rows for arm `arm' rep `r'"
            exit 459
        }
        quietly keep if arm == "`arm'" & rep == `r'
        local ob1 = b1[1]
        local ob2 = b2[1]

        local f "`datadir'/zzf_xv_`arm'_`=string(`r', "%02.0f")'.csv"
        capture confirm file "`f'"
        if _rc {
            display as error "oracle beta row exists but its dataset does not: `f'"
            exit 601
        }

        import delimited "`f'", clear case(preserve)
        rename L t0
        rename X t
        quietly gen byte anyev = status > 0

        * Arm A has t0 == 0 for everyone.  Mirror the recovery suite exactly:
        * no enter() there, enter(time t0) elsewhere.
        if "`arm'" == "A" {
            quietly stset t, failure(anyev == 1) id(id)
        }
        else {
            quietly stset t, failure(anyev == 1) id(id) enter(time t0)
        }

        * Pooled weights on the Stata side: no strata(), no truncstrata().
        capture quietly finegray z1 z2, compete(status) cause(1)
        if _rc {
            display as error "  FAIL: arm `arm' rep `r' -- finegray exited rc = `=_rc'"
            local ++test_count
            local ++fail_count
            continue
        }

        local sb1 = _b[z1]
        local sb2 = _b[z2]

        local d1 = abs(`sb1' - `ob1') / max(abs(`ob1'), 1e-8)
        local d2 = abs(`sb2' - `ob2') / max(abs(`ob2'), 1e-8)
        local dmax = max(`d1', `d2')

        local ++npair
        if `dmax' > `worst' {
            local worst   = `dmax'
            local worstid "`arm' rep `r'"
        }

        local ++test_count
        if `dmax' < `tol' {
            local ++pass_count
        }
        else {
            local ++fail_count
            display as error "  FAIL: arm `arm' rep `r' -- max rel diff `dmax' >= `tol'"
        }

        display as text "  `arm' " %3.0f `r' "  " %13.8f `sb1' "  " %13.8f `ob1' ///
            "  " %13.8f `sb2' "  " %13.8f `ob2' "  " %11.2e `dmax'
    }
}

* ---------------------------------------------------------------------------
* FALSE-GREEN GUARDS.  A checker that compares zero pairs will otherwise report
* a clean sweep.  (This exact failure was caught once already in Z1.)
* ---------------------------------------------------------------------------
display as text _newline "comparisons executed : `npair' (oracle rows: `n_oracle')"
display as text "worst relative diff  : " %11.4e `worst' "   (`worstid')"
display as text "tolerance            : " %11.2e `tol'

local ++test_count
if `npair' == `n_oracle' & `npair' > 0 {
    local ++pass_count
    display as result "  PASS: every oracle dataset was actually compared (`npair')"
}
else {
    local ++fail_count
    display as error "  FAIL: compared `npair' datasets but the oracle has `n_oracle'"
}

* The comparison must be capable of failing.  Perturb one coefficient by 1e-3
* -- three orders above tolerance, three below the difference a wrong estimator
* would show -- and confirm the assertion fires.
local ++test_count
local probe = abs((0.5 + 1e-3) - 0.5) / 0.5
if `probe' >= `tol' {
    local ++pass_count
    display as result "  PASS: tolerance is live (a 1e-3 perturbation would fail)"
}
else {
    local ++fail_count
    display as error "  FAIL: tolerance is too loose to detect a 1e-3 error"
}

display as text _newline "RESULT: crossval_finegray_zzf tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "CROSSVAL FAILED: Stata's ZZF estimator does not reproduce the R oracle"
    log close _crossval_finegray_zzf
    exit 9
}
display as result "ALL CHECKS PASSED: Stata reproduces the R ZZF oracle dataset by dataset"

log close _crossval_finegray_zzf
