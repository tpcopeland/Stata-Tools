clear all
set more off
version 16.0
set varabbrev off

* test_iivw_v200_phase1.do
*
* v2.0.0 Phase 1 regressions: the statistical weight contracts.
*
*   C1  The Andersen-Gill risk set ended at each subject's LAST VISIT. Nobody
*       was at risk between their final visit and their actual end of follow-up,
*       so risk-set membership was a function of the visit process itself. Both
*       source papers define the at-risk process as I(C_i > t) with C_i the end
*       of follow-up (Buzkova & Lumley 2007 p.7 eq.8; Tompkins 2025 p.5), and
*       the method author's own R package ships addcensoredrows() for exactly
*       this. Measured: ~26% attenuation of the visit-intensity coefficient.
*   C6  The stabilized IIW numerator was refit WITHOUT restricting to the
*       denominator's e(sample), so an intensity ratio was formed from two
*       models evaluated over different risk sets.
*   C7  The IPTW stabilization prevalence was computed over EVERY first row
*       rather than over the propensity model's e(sample), so differential
*       missingness by arm rescaled treated and control weights in opposite
*       directions.
*   C5  With cluster() above the panel level (clinic, not patient), the
*       bootstrap's idcluster() id was passed straight through as the
*       random-intercept grouping AND as iivw_weight's id(): a whole clinic
*       became one "subject" in both the mixed model and the visit-intensity
*       counting process.
*   H17 Baseline-as-entry becomes the DEFAULT in 2.0.0; baseevent is the
*       explicit legacy opt-in.
*
* The C1 arm is a known-truth recovery test: the DGP sets gamma = 0.5 and the
* truth is computed from the DGP, not from another estimator.

capture log close
* Q6: no disposable log in the package tree. This suite used to write
* test_iivw_v200_phase1.log into qa/, which is gitignored but is still ~4 MB of debris carrying the
* local Stata license header, and the release hygiene gate had been taught to
* whitelist exactly these files. The batch invocation
* (`stata-mp -b do <suite>.do') already produces a readable log in the cwd, and
* run_all.log captures everything when the suite runs under the runner, so the
* named log was pure redundancy.
tempfile _suite_log
log using "`_suite_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = substr("`qa_dir'", 1, strlen("`qa_dir'") - strlen("/qa"))

do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap, pkgdir("`pkg_dir'")

**# Data builders

* Registry DGP with a known visit-intensity coefficient.
*
*   z ~ N(0,1) subject-level; end of follow-up C_i ~ U(tau/2, tau) (Coulombe's
*   censoring design); follow-up visits from a Poisson process with intensity
*   0.6*exp(gamma*z) on (0, C_i]; a baseline row at t=0 for EVERY subject.
*
* The baseline row is what makes a zero-follow-up-visit subject representable
* at all: the package's data model is one row per visit, so without it such a
* subject has no rows and cannot enter any risk set. Under the 2.0.0 default
* (baseline = study entry) those subjects contribute (0, C_i] with no event --
* exactly the risk time the old construction threw away.
capture program drop _p1_make_registry
program define _p1_make_registry
    syntax , N(integer) GAMma(real) [SEED(integer 20260713) TAU(real 10)]
    clear
    set seed `seed'
    set obs `n'
    gen long pid = _n
    gen double z = rnormal()
    gen double cens = (`tau'/2) + (`tau'/2)*runiform()
    tempfile base
    quietly save `base'

    gen double rate = 0.6*exp(`gamma'*z)
    expand 100
    bysort pid: gen int k = _n
    gen double gap = -ln(runiform())/rate
    bysort pid (k): gen double vtime = sum(gap)
    quietly keep if vtime <= cens
    keep pid vtime
    tempfile fu
    quietly save `fu'

    use `base', clear
    gen double vtime = 0
    append using `fu'
    bysort pid (vtime): replace z = z[1]
    bysort pid (vtime): replace cens = cens[1]
    sort pid vtime
    label variable vtime "Visit time"
end

**# T1 (C1): the corrected risk set recovers the true visit-intensity coefficient

local ++test_count
capture noisily {
    _p1_make_registry, n(3000) gamma(0.5)

    * Truth is 0.5 BY CONSTRUCTION -- it is the number the DGP was built with,
    * not an estimate borrowed from another estimator. A systematic residual is
    * therefore a bug, not a method difference.
    quietly iivw_weight, id(pid) time(vtime) visit_cov(z) censor(cens) nolog
    matrix b_fix = r(visit_b)
    local g_fix = b_fix[1, colnumb(b_fix, "z")]
    local n_fix = r(visit_N)

    * And the v1.x risk set, still reachable via the explicit legacy option, must
    * still be visibly attenuated -- if it is not, the DGP is not exercising the
    * defect and this test proves nothing.
    quietly iivw_weight, id(pid) time(vtime) visit_cov(z) endatlastvisit ///
        generate(_leg_) nolog
    matrix b_leg = r(visit_b)
    local g_leg = b_leg[1, colnumb(b_leg, "z")]
    local n_leg = r(visit_N)

    display as text "  true gamma      = 0.500"
    display as text "  censor(cens)    = " %7.4f `g_fix' "   (intervals: `n_fix')"
    display as text "  endatlastvisit  = " %7.4f `g_leg' "   (intervals: `n_leg')"

    * Recovery. Tolerance from a worked run at n=3000; the corrected arm sat
    * within 0.02 of truth.
    if abs(`g_fix' - 0.5) > 0.05 {
        display as error "T1 FAIL: corrected risk set did not recover gamma=0.5 (got `g_fix')"
        error 9
    }
    * The legacy arm must be attenuated toward zero by a wide margin. Measured
    * ~26% attenuation; require at least 10% so this cannot pass by accident.
    if `g_leg' > 0.45 {
        display as error "T1 FAIL: legacy risk set is not attenuated (got `g_leg'); the DGP"
        display as error "  does not exercise C1, so the corrected arm proves nothing"
        error 9
    }
    * The censored construction must actually add risk time.
    if `n_fix' <= `n_leg' {
        display as error "T1 FAIL: censor() added no intervals (`n_fix' vs `n_leg')"
        error 9
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: T1 censoring rows recover the true visit-intensity coefficient"
}
else {
    local ++fail_count
    display as error "FAIL: T1 C1 known-truth recovery"
}

**# T2 (C1): zero-follow-up-visit subjects are in the risk set for their full follow-up

local ++test_count
capture noisily {
    * Hand-built, fully countable panel. Three subjects:
    *   A: baseline at 0, visits at 2 and 4; followed to 10
    *   B: baseline at 0, visit at 3;        followed to 10
    *   C: baseline at 0, NO follow-up visit; followed to 10
    * Under the 2.0.0 default the baseline row is study entry, so the modeled
    * events are A's two visits and B's one visit = 3 events. The risk-set
    * intervals are A:(0,2],(2,4],(4,10]  B:(0,3],(3,10]  C:(0,10] = 6.
    * The old construction gave A:2, B:1, C:0 = 3 intervals and dropped C
    * entirely -- a subject under observation for the whole study, absent from
    * every risk set.
    clear
    input long pid double vtime double z double cens
    1 0 0.5 10
    1 2 0.5 10
    1 4 0.5 10
    2 0 -0.5 10
    2 3 -0.5 10
    3 0 1.0 10
    end

    quietly iivw_weight, id(pid) time(vtime) visit_cov(z) censor(cens) nolog
    local nint = r(visit_N)
    local nsub = r(visit_N_sub)
    local ncens = r(n_censor_rows)

    display as text "  intervals=`nint' subjects=`nsub' censoring rows=`ncens'"

    if `nint' != 6 {
        display as error "T2 FAIL: expected 6 risk-set intervals, got `nint'"
        error 9
    }
    if `nsub' != 3 {
        display as error "T2 FAIL: expected 3 subjects in the risk set, got `nsub'"
        display as error "  a subject with no follow-up visit is still under observation"
        error 9
    }
    if `ncens' != 3 {
        display as error "T2 FAIL: expected 3 censoring rows, got `ncens'"
        error 9
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: T2 zero-follow-up-visit subjects contribute their full risk time"
}
else {
    local ++fail_count
    display as error "FAIL: T2 C1 risk-set membership"
}

**# T3 (C1): the censoring contract must be an explicit choice

local ++test_count
capture noisily {
    _p1_make_registry, n(200) gamma(0.5)

    * No censor(), no maxfu(), no endatlastvisit. In v1.x this silently produced
    * the attenuated weights. In 2.0.0 the user must say what their design is.
    capture iivw_weight, id(pid) time(vtime) visit_cov(z) nolog
    if _rc != 198 {
        display as error "T3 FAIL: an unspecified end of follow-up gave rc=`=_rc', not 198"
        display as error "  the silent default was a ~26% attenuated estimate"
        error 9
    }

    * maxfu() is the common-follow-up convenience form.
    quietly iivw_weight, id(pid) time(vtime) visit_cov(z) maxfu(10) nolog
    if r(maxfu) != 10 {
        display as error "T3 FAIL: maxfu(10) not recorded in the contract"
        error 9
    }

    * censor() and maxfu() are mutually exclusive.
    capture iivw_weight, id(pid) time(vtime) visit_cov(z) censor(cens) maxfu(10) ///
        replace nolog
    if _rc != 198 {
        display as error "T3 FAIL: censor()+maxfu() together gave rc=`=_rc', not 198"
        error 9
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: T3 end of follow-up must be stated explicitly"
}
else {
    local ++fail_count
    display as error "FAIL: T3 C1 explicit-choice contract"
}

**# T4 (C1): invalid censoring specifications are rejected

local ++test_count
capture noisily {
    * First prove the option EXISTS and accepts a valid specification. Without
    * this, every assertion below passes on a package that has no censor()
    * option at all: "option censor() not allowed" is also rc 198. That is the
    * exact shape of a false green, and this suite must not ship one.
    clear
    input long pid double vtime double z double cens
    1 0 0.5 10
    1 2 0.5 10
    2 0 -0.5 10
    2 5 -0.5 10
    end
    quietly iivw_weight, id(pid) time(vtime) visit_cov(z) censor(cens) nolog

    * Censoring time before the last visit: the subject cannot be censored at a
    * time they were observably still visiting.
    clear
    input long pid double vtime double z double cens
    1 0 0.5 10
    1 2 0.5 10
    1 4 0.5 10
    2 0 -0.5 3
    2 5 -0.5 3
    end
    capture iivw_weight, id(pid) time(vtime) visit_cov(z) censor(cens) nolog
    if _rc != 198 {
        display as error "T4 FAIL: censor() < last visit gave rc=`=_rc', not 198"
        error 9
    }

    * Censoring time not constant within subject.
    clear
    input long pid double vtime double z double cens
    1 0 0.5 10
    1 2 0.5 12
    2 0 -0.5 10
    2 5 -0.5 10
    end
    capture iivw_weight, id(pid) time(vtime) visit_cov(z) censor(cens) nolog
    if _rc != 198 {
        display as error "T4 FAIL: nonconstant censor() gave rc=`=_rc', not 198"
        error 9
    }

    * Missing censoring time.
    clear
    input long pid double vtime double z double cens
    1 0 0.5 10
    1 2 0.5 10
    2 0 -0.5 .
    2 5 -0.5 .
    end
    capture iivw_weight, id(pid) time(vtime) visit_cov(z) censor(cens) nolog
    if _rc != 198 {
        display as error "T4 FAIL: missing censor() gave rc=`=_rc', not 198"
        error 9
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: T4 invalid censoring specifications are rejected"
}
else {
    local ++fail_count
    display as error "FAIL: T4 C1 censoring validation"
}

**# T5 (C6): the IIW numerator and denominator share one risk set

local ++test_count
capture noisily {
    * Missingness confined to a covariate that only the DENOMINATOR model uses.
    * Rows missing xdenom can never receive a weight, yet in v1.x they still
    * entered the numerator model -- changing its coefficients and the risk sets
    * of the rows that DO get weights.
    _p1_make_registry, n(400) gamma(0.5) seed(424242)
    gen double xdenom = z + rnormal()
    gen double xstab = rnormal()
    * Knock out xdenom for a quarter of the subjects.
    quietly replace xdenom = . if mod(pid, 4) == 0

    * xdenom is deliberately blanked for a quarter of the subjects above, so
    * those rows get no weight. From 3.0.0 that is an error unless acknowledged;
    * this test is ABOUT the rows that get no weight, so it acknowledges it.
    quietly iivw_weight, id(pid) time(vtime) visit_cov(z xdenom) ///
        stabcov(xstab) censor(cens) allowmissingweights nolog
    local n_den = r(visit_N)
    local n_num = r(stab_N)

    display as text "  denominator intervals=`n_den'  numerator intervals=`n_num'"

    if `n_den' != `n_num' {
        display as error "T5 FAIL: numerator and denominator risk sets differ"
        display as error "  (`n_num' vs `n_den' intervals); the stabilized intensity ratio"
        display as error "  is not the estimator the theory describes"
        error 9
    }

    * The missing-xdenom rows must get no weight at all, not a weight built from
    * a numerator that learned from them. Baseline rows are exempt: under
    * baseline(entry) they are study entry, observed with probability 1, and
    * carry the conventional weight of 1 whatever their covariates say.
    bysort pid (vtime): gen byte _isbase = (_n == 1)
    quietly count if missing(xdenom) & !missing(_iivw_iw) & !_isbase
    if r(N) > 0 {
        display as error "T5 FAIL: `=r(N)' modeled rows missing a denominator covariate got a weight"
        error 9
    }
    drop _isbase
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: T5 stabilized IIW uses a common numerator/denominator risk set"
}
else {
    local ++fail_count
    display as error "FAIL: T5 C6 common risk set"
}

**# T6 (C7): IPTW prevalence comes from the propensity model's own sample

local ++test_count
capture noisily {
    * 20 subjects, 10 treated / 10 control, treatment covariate missing for five
    * TREATED subjects. The propensity model is fit on the 15 complete cases, in
    * which prevalence is 5/15 = 0.333333. v1.x recomputed prevalence over all
    * 20 first rows and got 0.5 -- scaling treated weights by 1.5 and control
    * weights by 0.75 relative to the correct numerator.
    clear
    set seed 991
    set obs 20
    gen long pid = _n
    gen byte tx = (pid <= 10)
    gen double xt = rnormal()
    quietly replace xt = . if pid <= 5
    expand 3
    bysort pid: gen double vtime = _n - 1
    sort pid vtime

    * xt is deliberately missing for pid<=5, so those subjects get no
    * propensity score and no weight -- which is exactly the point of the test.
    quietly iivw_weight, id(pid) time(vtime) treat(tx) treat_cov(xt) ///
        wtype(iptw) allowmissingweights nolog

    local prev = r(ps_prevalence)
    local psn  = r(ps_N)
    display as text "  propensity-model N=`psn'  prevalence=" %9.6f `prev'

    if `psn' != 15 {
        display as error "T6 FAIL: propensity model N reported as `psn', expected 15"
        error 9
    }
    if abs(`prev' - 1/3) > 1e-8 {
        display as error "T6 FAIL: prevalence `prev', expected 0.333333 (5 treated of 15"
        display as error "  analyzable subjects); 0.5 is the all-first-rows figure"
        error 9
    }

    * And the numerator that actually reached the weights must be that one:
    * for a treated subject tw = p/ps, so tw*ps recovers p exactly.
    quietly gen double _chk = _iivw_tw * _iivw_ps if tx == 1
    quietly summarize _chk, meanonly
    if abs(r(mean) - 1/3) > 1e-6 {
        display as error "T6 FAIL: treated weights imply numerator " as error %9.6f r(mean) ///
            as error ", expected 0.333333"
        error 9
    }
    drop _chk
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: T6 IPTW prevalence is computed on the propensity model's sample"
}
else {
    local ++fail_count
    display as error "FAIL: T6 C7 IPTW prevalence sample"
}

**# T7 (C5): a clinic-clustered bootstrap keeps the PATIENT as the panel unit

local ++test_count
capture noisily {
    * 8 clinics x 5 patients x 4 visits. The random intercept is on the patient.
    * bootstrap, cluster(clinic) idcluster(bsid) makes bsid the resampled CLINIC.
    * v1.x passed bsid straight through as mixed's grouping variable, so the
    * model had 8 groups (clinics) where it should have had 40 (patients) --
    * and _iivw_bs_refit passed the same bsid as iivw_weight's id(), making an
    * entire clinic one "subject" in the visit-intensity counting process.
    clear
    set seed 5150
    set obs 40
    gen long patient = _n
    gen long clinic = ceil(_n/5)
    gen double u = rnormal()
    expand 4
    bysort patient: gen double vtime = _n
    gen double x = rnormal()
    gen double y = 0.5*x + u + rnormal()
    sort patient vtime

    * Drive the helper directly with the two ids, exactly as the bootstrap does.
    tempvar bsid
    quietly gen long `bsid' = clinic

    quietly _iivw_bs_estimate y x, model(mixed) panelid(patient) ///
        bsid(`bsid') nolog
    * mixed stores e(N_g) as a MATRIX, one column per random-effects level --
    * a bare scalar assignment dies with r(109).
    matrix ng = e(N_g)
    local ngroups = ng[1, 1]
    display as text "  random-intercept groups = `ngroups' (patients, not clinics)"

    if `ngroups' != 40 {
        display as error "T7 FAIL: mixed used `ngroups' random-intercept groups, expected 40"
        display as error "  8 means the clinic draw id was used as the panel unit"
        error 9
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: T7 clinic-clustered bootstrap groups the random intercept by patient"
}
else {
    local ++fail_count
    display as error "FAIL: T7 C5 mixed bootstrap grouping"
}

**# T8 (C5): a patient spanning two clinics is rejected, not silently resampled

local ++test_count
capture noisily {
    clear
    set seed 77
    set obs 20
    gen long patient = _n
    gen long clinic = ceil(_n/5)
    expand 4
    bysort patient: gen double vtime = _n
    gen double x = rnormal()
    gen double y = 0.5*x + rnormal()
    * Patient 1 straddles two clinics: the hierarchy the bootstrap assumes is
    * violated, and group(bsid, patient) would silently split them.
    quietly replace clinic = 99 if patient == 1 & vtime > 2
    sort patient vtime

    capture iivw_fit y x, id(patient) time(vtime) model(mixed) ///
        cluster(clinic) bootstrap(5) unweighted nolog
    if _rc != 459 {
        display as error "T8 FAIL: a patient spanning two clusters gave rc=`=_rc', not 459"
        error 9
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: T8 non-nested panel/cluster hierarchy is rejected"
}
else {
    local ++fail_count
    display as error "FAIL: T8 C5 nesting guard"
}

**# T9 (H17): baseline-as-entry is the default; baseline(event) is the legacy opt-in

local ++test_count
capture noisily {
    _p1_make_registry, n(200) gamma(0.5)

    quietly iivw_weight, id(pid) time(vtime) visit_cov(z) censor(cens) nolog
    if r(nobaseevent) != 1 {
        display as error "T9 FAIL: the 2.0.0 default must be baseline-as-entry"
        error 9
    }

    * baseline(event) models the first visit as a recurrent event, which the
    * legacy contract only permits when every subject HAS a follow-up visit --
    * so it must be exercised on a panel that satisfies that, not on the
    * registry DGP (whose zero-follow-up-visit subjects it correctly rejects).
    quietly bysort pid (vtime): gen long _nv = _N
    preserve
    quietly keep if _nv >= 2
    quietly iivw_weight, id(pid) time(vtime) visit_cov(z) censor(cens) ///
        baseline(event) generate(_be_) nolog
    if r(nobaseevent) != 0 {
        display as error "T9 FAIL: baseline(event) did not restore the legacy contract"
        error 9
    }
    restore
    drop _nv

    * The 1.x option name must fail LOUDLY, not become a silent no-op. Stata's
    * `syntax [, noBASEevent]' cannot tell an explicit positive form from an
    * omitted option -- both leave the macro empty -- so keeping the old name
    * would have meant silently ignoring whatever the user asked for.
    capture iivw_weight, id(pid) time(vtime) visit_cov(z) censor(cens) ///
        nobaseevent generate(_nb_) nolog
    if _rc != 198 {
        display as error "T9 FAIL: nobaseevent gave rc=`=_rc', not 198"
        error 9
    }

    * And an unrecognized baseline() value is an error, not a silent default.
    capture iivw_weight, id(pid) time(vtime) visit_cov(z) censor(cens) ///
        baseline(whatever) generate(_wh_) nolog
    if _rc != 198 {
        display as error "T9 FAIL: baseline(whatever) gave rc=`=_rc', not 198"
        error 9
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "PASS: T9 baseline(entry) is the default, baseline(event) the legacy option"
}
else {
    local ++fail_count
    display as error "FAIL: T9 H17 default baseline contract"
}

**# Summary

display _newline as text "v2.0.0 Phase 1 statistical-contract regressions"
display as text "  tests:  " as result `test_count'
display as text "  passed: " as result `pass_count'
display as text "  failed: " as result `fail_count'

display "RESULT: iivw_v200_phase1 tests=`test_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 {
    log close
    exit 1
}

log close
