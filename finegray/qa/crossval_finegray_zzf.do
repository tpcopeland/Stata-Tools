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
* ARMS.  A/B/D use pooled weights; C implements ZZF equation (7) with the same
* discrete group for censoring and entry; X uses genuinely distinct censoring
* and entry groups.  C and X close the old blind spot where the suite never
* cross-validated truncstrata() or a true cross-classification.
*
* ORACLE.  Datasets and betas come from crossval_finegray_zzf_beta_r.R, which
* sources gen_fg/zzf_fit/zzf_weights from the frozen crossval_finegray_zzf_r.R.
* The suite regenerates it on every run.  Stale ignored CSVs are not evidence.

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
* Regenerate and validate the oracle manifest.  The generator owns data/ and
* creates it, so this path works from a clean checkout.
* ---------------------------------------------------------------------------
* Pin the full oracle size here.  The R generator accepts smaller environment
* overrides for direct smoke work; inheriting one into this suite must not turn
* a 100-dataset cross-validation into a green three-dataset smoke run.
*
* FAIL-CLOSED GENERATION (FG-02).  Stata's `shell' does NOT put the child's exit
* status in _rc -- a bare `shell /usr/bin/false' returns _rc 0 -- so the former
* `if _rc' guard could never see an R failure.  With an ignored data/ cache from
* a prior good run still present, a broken or missing Rscript (which never even
* reaches R's own stale-file cleanup) would let the suite consume last run's
* oracle as if it were fresh and report 102/102.  Two guards close that:
*   1. erase the oracle index files HERE, in Stata, before calling R, so a
*      no-op Rscript cannot leave a stale oracle+manifest behind; and
*   2. capture R's REAL exit code through a sentinel file and fail on nonzero.
capture erase "`datadir'/zzf_xv_oracle_beta.csv"
capture erase "`datadir'/zzf_xv_manifest.csv"
tempfile rcsent
shell ZZF_XV_N=3000 ZZF_XV_REPS=20 Rscript "`qadir'/crossval_finegray_zzf_beta_r.R" ; echo $? > "`rcsent'"
capture confirm file "`rcsent'"
if _rc {
    display as error "R oracle wrapper produced no exit-status sentinel"
    exit 9
}
tempname _shrc
file open `_shrc' using "`rcsent'", read text
file read `_shrc' _rc_line
file close `_shrc'
local _rexit = real(trim("`_rc_line'"))
if `_rexit' != 0 {
    display as error "R oracle generation failed (child exit `=trim(`"`_rc_line'"')')"
    display as error "no stale oracle is consumed: the index files were erased before R ran"
    exit 9
}
capture confirm file "`datadir'/zzf_xv_oracle_beta.csv"
if _rc {
    display as error "MISSING ORACLE: `datadir'/zzf_xv_oracle_beta.csv"
    exit 601
}
capture confirm file "`datadir'/zzf_xv_manifest.csv"
if _rc {
    display as error "MISSING ORACLE MANIFEST: `datadir'/zzf_xv_manifest.csv"
    exit 601
}

tempfile manifest
import delimited "`datadir'/zzf_xv_manifest.csv", clear case(preserve)
capture assert schema_version == 2
if _rc {
    display as error "unsupported or malformed ZZF oracle manifest"
    exit 459
}
capture isid arm
if _rc {
    display as error "oracle manifest contains duplicate arm rows"
    exit 459
}
local expected_arms "A B C D X"
quietly count if !inlist(arm, "A", "B", "C", "D", "X")
if r(N) != 0 {
    display as error "oracle manifest contains an unknown arm"
    exit 459
}
foreach arm of local expected_arms {
    quietly count if arm == "`arm'"
    if r(N) != 1 {
        display as error "oracle manifest has `r(N)' rows for required arm `arm'"
        exit 459
    }
}
capture assert method == "pooled" if inlist(arm, "A", "B", "D")
if _rc {
    display as error "oracle manifest has the wrong method for a pooled arm"
    exit 459
}
capture assert method == "same" if arm == "C"
if _rc {
    display as error "oracle manifest has the wrong method for arm C"
    exit 459
}
capture assert method == "cross" if arm == "X"
if _rc {
    display as error "oracle manifest has the wrong method for arm X"
    exit 459
}
capture assert ///
    (inlist(arm, "A", "B", "D") & fit_options == "pooled") | ///
    (arm == "C" & fit_options == "strata(z1) truncstrata(z1)") | ///
    (arm == "X" & fit_options == "strata(cgroup) truncstrata(tgroup)")
if _rc {
    display as error "oracle manifest fit_options do not match the required arm contract"
    exit 459
}
quietly summarize expected_reps, meanonly
if r(min) != r(max) | r(min) != 20 {
    display as error "oracle manifest must specify exactly 20 replications per arm"
    exit 459
}
local expected_reps = r(min)
quietly summarize expected_n, meanonly
if r(min) != r(max) | r(min) != 3000 {
    display as error "oracle manifest must specify exactly 3000 subjects per dataset"
    exit 459
}
local expected_n = r(min)
local n_arms = r(N)
save "`manifest'", replace

tempfile oracle
import delimited "`datadir'/zzf_xv_oracle_beta.csv", clear case(preserve)
quietly count
local n_oracle = r(N)
if `n_oracle' != `n_arms' * `expected_reps' {
    display as error "oracle has `n_oracle' rows; manifest requires `=`n_arms' * `expected_reps''"
    exit 459
}
capture isid arm rep
if _rc {
    display as error "oracle has duplicate arm/rep rows"
    exit 459
}
capture assert n == `expected_n'
if _rc {
    display as error "oracle beta rows do not contain the required `expected_n' subjects"
    exit 459
}
foreach arm of local expected_arms {
    quietly count if arm == "`arm'"
    if r(N) != `expected_reps' {
        display as error "oracle arm `arm' has `r(N)' rows; expected `expected_reps'"
        exit 459
    }
}
save "`oracle'", replace
display as text "oracle: `n_oracle' fitted datasets (`n_arms' arms x `expected_reps' reps)"

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

foreach arm of local expected_arms {
    forvalues r = 1/`expected_reps' {

        use "`oracle'", clear
        quietly count if arm == "`arm'" & rep == `r'
        if r(N) != 1 {
            display as error "oracle has `r(N)' rows for required arm `arm' rep `r'"
            exit 459
        }
        quietly keep if arm == "`arm'" & rep == `r'
        local ob1 = b1[1]
        local ob2 = b2[1]
        local on  = n[1]

        local f "`datadir'/zzf_xv_`arm'_`=string(`r', "%02.0f")'.csv"
        capture confirm file "`f'"
        if _rc {
            display as error "oracle beta row exists but its dataset does not: `f'"
            exit 601
        }

        import delimited "`f'", clear case(preserve)
        foreach v in id L X status z1 z2 cgroup tgroup {
            capture confirm numeric variable `v'
            if _rc {
                display as error "oracle dataset `arm'/`r' lacks numeric variable `v'"
                exit 459
            }
        }
        quietly count
        if r(N) != `on' {
            display as error "oracle dataset `arm'/`r' has `r(N)' rows; beta row records `on'"
            exit 459
        }
        capture isid id
        if _rc {
            display as error "oracle dataset `arm'/`r' has missing or duplicate IDs"
            exit 459
        }
        capture assert !missing(id, L, X, status, z1, z2, cgroup, tgroup) & ///
            L >= 0 & L < X & inlist(status, 0, 1, 2)
        if _rc {
            display as error "oracle dataset `arm'/`r' violates its schema or support"
            exit 459
        }
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

        local weightopts ""
        if "`arm'" == "C" local weightopts "strata(z1) truncstrata(z1)"
        if "`arm'" == "X" local weightopts "strata(cgroup) truncstrata(tgroup)"
        capture quietly finegray z1 z2, compete(status) cause(1) `weightopts'
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
