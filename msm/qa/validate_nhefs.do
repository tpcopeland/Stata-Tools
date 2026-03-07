* validate_nhefs.do — V3: NHEFS Benchmarks
* Part A: Ch12 — Point treatment IPTW (cross-sectional)
*   Benchmark: stabilized IPTW ATE = 3.44 kg (CI: 2.41-4.47)
*   Weight mean ~0.999, weight SD ~0.288
* Part B: Ch17 — Pooled logistic person-period
*   Restructure to person-month, fit MSM pipeline

version 16.0
set more off
set varabbrev off

local qa_dir "/home/tpcopeland/Stata-Tools/msm/qa"
local data_dir "`qa_dir'/data"
adopath ++ "/home/tpcopeland/Stata-Tools/msm"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display "V3: NHEFS BENCHMARKS"
display "Date: $S_DATE $S_TIME"
display ""

* =========================================================================
* PART A: Chapter 12 — Point Treatment IPTW
* Reference: Hernan & Robins, Program 12.3-12.4
* Cross-sectional: N=1,566 (complete cases)
* Treatment: qsmk (quit smoking)
* Outcome: wt82_71 (weight change kg)
* Covariates: sex, race, age, age^2, smokeintensity, smokeintensity^2,
*             smokeyrs, smokeyrs^2, exercise, active, wt71, wt71^2
* =========================================================================
display "PART A: Chapter 12 — Point Treatment IPTW"
display ""

use "`data_dir'/nhefs.dta", clear

* Drop missing outcome (as per Hernan & Robins)
drop if missing(wt82_71)
local N_a = _N

* Create quadratic terms
gen double age_sq = age^2
gen double smokeintensity_sq = smokeintensity^2
gen double smokeyrs_sq = smokeyrs^2
gen double wt71_sq = wt71^2

* =========================================================================
* Test 3.1: Point-treatment weight mean ~0.999
* =========================================================================
local ++test_count
capture {
    * Denominator model: P(qsmk=1 | all covariates)
    logit qsmk sex race age age_sq smokeintensity smokeintensity_sq ///
        smokeyrs smokeyrs_sq exercise active wt71 wt71_sq, nolog

    predict double p_denom, pr

    * Numerator model: P(qsmk=1)  (marginal probability for stabilization)
    logit qsmk, nolog
    predict double p_numer, pr

    * Stabilized weight
    gen double sw = .
    replace sw = p_numer / p_denom if qsmk == 1
    replace sw = (1 - p_numer) / (1 - p_denom) if qsmk == 0

    summarize sw
    local sw_mean = r(mean)
    local sw_sd = r(sd)
    display "  Weight mean: " %7.4f `sw_mean' " (published: 0.999)"
    display "  Weight SD:   " %7.4f `sw_sd' " (published: 0.288)"

    assert abs(`sw_mean' - 0.999) < 0.01
}
if _rc == 0 {
    display as result "  PASS 3.1: Weight mean ~0.999"
    local ++pass_count
}
else {
    display as error "  FAIL 3.1: Weight mean not matching published (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.1"
}

* =========================================================================
* Test 3.2: Point-treatment weight SD ~0.288
* =========================================================================
local ++test_count
capture {
    assert abs(`sw_sd' - 0.288) < 0.05
}
if _rc == 0 {
    display as result "  PASS 3.2: Weight SD ~0.288"
    local ++pass_count
}
else {
    display as error "  FAIL 3.2: Weight SD not matching published (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.2"
}

* =========================================================================
* Test 3.3: Stabilized IPTW ATE ~3.44 kg
* =========================================================================
local ++test_count
capture {
    regress wt82_71 qsmk [pw=sw], vce(robust)
    local ate = _b[qsmk]
    local ate_se = _se[qsmk]
    local ate_lo = `ate' - 1.96 * `ate_se'
    local ate_hi = `ate' + 1.96 * `ate_se'
    display "  ATE: " %6.2f `ate' " kg (published: 3.44)"
    display "  95% CI: [" %5.2f `ate_lo' ", " %5.2f `ate_hi' "] (published: 2.41-4.47)"

    * Within 0.30 of published value
    assert abs(`ate' - 3.44) < 0.30
}
if _rc == 0 {
    display as result "  PASS 3.3: ATE ~3.44 kg (within 0.30)"
    local ++pass_count
}
else {
    display as error "  FAIL 3.3: ATE not matching published (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.3"
}

* =========================================================================
* Test 3.4: 95% CI covers published value
* =========================================================================
local ++test_count
capture {
    assert `ate_lo' < 3.44 & `ate_hi' > 3.44
}
if _rc == 0 {
    display as result "  PASS 3.4: 95% CI covers published 3.44"
    local ++pass_count
}
else {
    display as error "  FAIL 3.4: CI should cover 3.44 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.4"
}

* Clean up Part A variables
drop p_denom p_numer sw age_sq smokeintensity_sq smokeyrs_sq wt71_sq

* =========================================================================
* PART B: Chapter 17 — Person-Period Pooled Logistic
* Create person-month data from NHEFS, model death over 120 months
* =========================================================================
display ""
display "PART B: Chapter 17 — Person-Period MSM"
display ""

* =========================================================================
* Test 3.5: Person-period restructuring creates valid panel
* =========================================================================
local ++test_count
capture {
    * Create person-period from NHEFS
    * Follow-up: 120 months (1982 questionnaire is ~10 years after baseline)
    * Outcome: death
    * Treatment: qsmk (time-fixed in this case, but structured as panel)

    use "`data_dir'/nhefs.dta", clear
    drop if missing(wt82_71)

    * Generate ID
    gen long id = _n
    local n_persons = _N

    * Expand to person-month (10 periods for tractability)
    expand 10
    sort id
    by id: gen int period = _n - 1

    * Treatment is time-fixed: qsmk doesn't change
    * Outcome: death at end of follow-up
    gen byte died = (death == 1) & (period == 9)

    * Time-varying: none in this simplified version
    * Baseline covariates
    gen double age_sq = age^2
    gen double wt71_sq = wt71^2
    gen double smokeint_sq = smokeintensity^2
    gen double smokeyrs_sq = smokeyrs^2

    * Verify panel structure
    quietly {
        tempvar dup_check
        bysort id period: gen byte `dup_check' = _N
        count if `dup_check' > 1
    }
    assert r(N) == 0
    display "  Person-periods: " _N " (" `n_persons' " x 10)"

    save "`data_dir'/nhefs_personperiod.dta", replace
}
if _rc == 0 {
    display as result "  PASS 3.5: Person-period restructuring valid"
    local ++pass_count
}
else {
    display as error "  FAIL 3.5: Person-period restructuring failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.5"
}

* =========================================================================
* Test 3.6: msm pipeline runs on NHEFS person-period data
* =========================================================================
local ++test_count
capture {
    use "`data_dir'/nhefs_personperiod.dta", clear

    msm_prepare, id(id) period(period) treatment(qsmk) ///
        outcome(died) baseline_covariates(sex race age wt71)

    * Since treatment is time-fixed, denominator = baseline covariates
    msm_weight, treat_d_cov(sex race age wt71) ///
        treat_n_cov(sex race) nolog

    msm_fit, model(logistic) outcome_cov(sex race age wt71) ///
        period_spec(linear) nolog

    local b_qsmk = _b[qsmk]
    local or_qsmk = exp(`b_qsmk')
    display "  qsmk log-OR: " %7.4f `b_qsmk' " (OR: " %7.4f `or_qsmk' ")"
}
if _rc == 0 {
    display as result "  PASS 3.6: MSM pipeline runs on NHEFS"
    local ++pass_count
}
else {
    display as error "  FAIL 3.6: MSM pipeline failed on NHEFS (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.6"
}

* =========================================================================
* Test 3.7: Cox model runs on NHEFS person-period
* =========================================================================
local ++test_count
capture {
    msm_fit, model(cox) outcome_cov(sex race age wt71) nolog

    local hr_qsmk = exp(_b[qsmk])
    display "  Cox HR for qsmk: " %7.4f `hr_qsmk'
    * HR should be positive (model ran) - qsmk effect on death
    assert `hr_qsmk' > 0
}
if _rc == 0 {
    display as result "  PASS 3.7: Cox model runs on NHEFS"
    local ++pass_count
}
else {
    display as error "  FAIL 3.7: Cox model failed on NHEFS (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.7"
}

* =========================================================================
* Test 3.8: Weight properties on real data
* =========================================================================
local ++test_count
capture {
    * Reload and refit logistic for weight diagnostics
    use "`data_dir'/nhefs_personperiod.dta", clear

    msm_prepare, id(id) period(period) treatment(qsmk) ///
        outcome(died) baseline_covariates(sex race age wt71)
    msm_weight, treat_d_cov(sex race age wt71) ///
        treat_n_cov(sex race) nolog

    msm_diagnose
    local ess = r(ess)
    local ess_pct = r(ess_pct)
    display "  ESS: " %9.1f `ess' " (" %5.1f `ess_pct' "%)"
    assert `ess_pct' > 50
}
if _rc == 0 {
    display as result "  PASS 3.8: Real-data weight ESS > 50%"
    local ++pass_count
}
else {
    display as error "  FAIL 3.8: ESS too low on real data (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3.8"
}

* =========================================================================
* SUMMARY
* =========================================================================
display ""
display "V3: NHEFS SUMMARY"
display "Total tests:  `test_count'"
display "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
    display as error "Failed tests:`failed_tests'"
}
else {
    display "Failed:       `fail_count'"
}

local v_status = cond(`fail_count' > 0, "FAIL", "PASS")
display ""
display "RESULT: V3 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"
display ""
display "Completed: $S_DATE $S_TIME"

if `fail_count' > 0 {
    exit 1
}
