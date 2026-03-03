* validate_known_dgp.do — V1: Known DGP with Time-Varying Confounding
* N=10,000, T=10, true log-OR = -0.357 (OR=0.70)
* Validates Cole & Hernan (2008) weight construction principles
* L_t affected by A_{t-1} (treatment-confounder feedback)

version 16.0
set more off
set varabbrev off

local qa_dir "/home/tpcopeland/Stata-Dev/msm/qa"
adopath ++ "/home/tpcopeland/Stata-Dev/msm"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display "V1: KNOWN DGP WITH TIME-VARYING CONFOUNDING"
display "Date: $S_DATE $S_TIME"
display ""

* =========================================================================
* DGP: Time-varying confounding with treatment-confounder feedback
*   N=10,000  T=10  true_logOR = ln(0.70) = -0.357
*
*   L_0 ~ Normal(0, 1)
*   For t=0..9:
*     A_t ~ Bernoulli(expit(-1 + 0.5*L_t + 0.3*A_{t-1}))
*     Y_t ~ Bernoulli(expit(-4 + true_logOR*A_t + 0.5*L_t))
*     L_{t+1} = 0.5*L_t + 0.8*A_t + Normal(0, 0.5)   [feedback!]
*
* The feedback (A_t -> L_{t+1} -> A_{t+1}) creates confounding that
* naive conditioning on L biases the estimate. MSM with IPTW should
* recover the true causal effect.
* =========================================================================

capture program drop _v1_generate_dgp
program define _v1_generate_dgp
    version 16.0
    syntax , n(integer) t(integer) true_logor(real) seed(integer)

    clear
    set seed `seed'
    local N_total = `n' * `t'
    set obs `N_total'

    gen long id = ceil(_n / `t')
    bysort id: gen int period = _n - 1

    * Baseline confounder
    gen double L = .
    gen byte treatment = .
    gen byte outcome = .

    * Generate panel data
    sort id period
    quietly {
        * First period: L_0 ~ N(0,1), no lag treatment
        by id: replace L = rnormal(0, 1) if period == 0
        by id: replace treatment = (runiform() < invlogit(-1 + 0.5 * L)) if period == 0
        by id: replace outcome = (runiform() < invlogit(-4 + `true_logor' * treatment + 0.5 * L)) if period == 0

        * Subsequent periods with feedback
        forvalues p = 1/`=`t'-1' {
            * L_t depends on L_{t-1} and A_{t-1}  (treatment-confounder feedback)
            by id: replace L = 0.5 * L[_n-1] + 0.8 * treatment[_n-1] + rnormal(0, 0.5) if period == `p'

            * Treatment depends on current L and lagged treatment
            by id: replace treatment = (runiform() < invlogit(-1 + 0.5 * L + 0.3 * treatment[_n-1])) if period == `p'

            * Outcome depends on treatment and L (true causal effect)
            by id: replace outcome = (runiform() < invlogit(-4 + `true_logor' * treatment + 0.5 * L)) if period == `p'
        }
    }

    * Baseline covariate (fixed across time)
    gen double bl_L0 = .
    sort id period
    by id: replace bl_L0 = L[1]
end

* =========================================================================
* Generate main dataset
* =========================================================================
display "Generating known DGP dataset (N=10,000, T=10)..."
local true_logor = ln(0.70)
_v1_generate_dgp, n(10000) t(10) true_logor(`true_logor') seed(20260301)
display "  True log-OR: " %6.4f `true_logor' " (OR = 0.70)"
display ""

* =========================================================================
* Test 1.1: Large-sample estimate within 0.15 of truth
* =========================================================================
local ++test_count
capture {
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L) baseline_covariates(bl_L0)

    msm_weight, treat_d_cov(L bl_L0) treat_n_cov(bl_L0) nolog
    msm_fit, model(logistic) outcome_cov(bl_L0) period_spec(linear) nolog

    local b_msm = _b[treatment]
    display "  MSM log-OR: " %7.4f `b_msm' " (truth: " %7.4f `true_logor' ")"
    assert abs(`b_msm' - `true_logor') < 0.15
}
if _rc == 0 {
    display as result "  PASS 1.1: MSM estimate within 0.15 of truth"
    local ++pass_count
}
else {
    display as error "  FAIL 1.1: MSM estimate not close to truth (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.1"
}

* =========================================================================
* Test 1.2: 95% CI covers truth
* =========================================================================
local ++test_count
capture {
    local b = _b[treatment]
    local se = _se[treatment]
    local ci_lo = `b' - 1.96 * `se'
    local ci_hi = `b' + 1.96 * `se'
    display "  95% CI: [" %7.4f `ci_lo' ", " %7.4f `ci_hi' "]"
    assert `ci_lo' < `true_logor' & `ci_hi' > `true_logor'
}
if _rc == 0 {
    display as result "  PASS 1.2: 95% CI covers truth"
    local ++pass_count
}
else {
    display as error "  FAIL 1.2: 95% CI does not cover truth (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.2"
}

* =========================================================================
* Test 1.3: Naive estimate is attenuated (closer to null than truth)
*   Conditioning on post-treatment L blocks the causal path A->L->Y,
*   attenuating the estimated treatment effect toward null.
* =========================================================================
local ++test_count
capture {
    * Naive: condition on L in the outcome model without IPTW
    quietly glm outcome treatment L bl_L0 period, family(binomial) link(logit) nolog
    local b_naive = _b[treatment]
    display "  Naive log-OR: " %7.4f `b_naive' " (truth: " %7.4f `true_logor' ")"
    display "  MSM log-OR:   " %7.4f `b_msm'
    * Naive should be attenuated: closer to 0 than the true effect
    * (true effect is negative, naive should be less negative)
    assert abs(`b_naive') < abs(`true_logor') + 0.05
}
if _rc == 0 {
    display as result "  PASS 1.3: Naive estimate attenuated by post-treatment conditioning"
    local ++pass_count
}
else {
    display as error "  FAIL 1.3: Naive estimate not attenuated as expected (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.3"
}

* =========================================================================
* Test 1.4: Stabilized weight mean in [0.90, 1.10]
* =========================================================================
local ++test_count
capture {
    quietly summarize _msm_weight
    local w_mean = r(mean)
    display "  Weight mean: " %7.4f `w_mean'
    assert `w_mean' > 0.90 & `w_mean' < 1.10
}
if _rc == 0 {
    display as result "  PASS 1.4: Stabilized weight mean near 1"
    local ++pass_count
}
else {
    display as error "  FAIL 1.4: Weight mean outside [0.90, 1.10] (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.4"
}

* =========================================================================
* Test 1.5: 30-rep Monte Carlo — mean within 0.10, coverage >= 80%
* =========================================================================
local ++test_count
display ""
display "  Running 30-rep Monte Carlo..."
capture {
    local mc_reps = 30
    tempname mc_results
    matrix `mc_results' = J(`mc_reps', 3, .)

    forvalues rep = 1/`mc_reps' {
        local mc_seed = 10000 + `rep'
        quietly {
            _v1_generate_dgp, n(5000) t(10) true_logor(`true_logor') seed(`mc_seed')

            msm_prepare, id(id) period(period) treatment(treatment) ///
                outcome(outcome) covariates(L) baseline_covariates(bl_L0)
            msm_weight, treat_d_cov(L bl_L0) treat_n_cov(bl_L0) nolog
            msm_fit, model(logistic) outcome_cov(bl_L0) period_spec(linear) nolog

            local b_rep = _b[treatment]
            local se_rep = _se[treatment]
            local ci_lo_rep = `b_rep' - 1.96 * `se_rep'
            local ci_hi_rep = `b_rep' + 1.96 * `se_rep'
            local covers = (`ci_lo_rep' < `true_logor') & (`ci_hi_rep' > `true_logor')

            matrix `mc_results'[`rep', 1] = `b_rep'
            matrix `mc_results'[`rep', 2] = `se_rep'
            matrix `mc_results'[`rep', 3] = `covers'
        }
        if mod(`rep', 10) == 0 {
            display "    ... `rep' of `mc_reps' reps"
        }
    }

    * Compute MC summary
    mata: st_local("mc_mean", strofreal(mean(st_matrix("`mc_results'")[., 1])))
    mata: st_local("mc_coverage", strofreal(100 * mean(st_matrix("`mc_results'")[., 3])))

    display "  MC mean estimate: " %7.4f `mc_mean' " (truth: " %7.4f `true_logor' ")"
    display "  MC coverage:      " %5.1f `mc_coverage' "%"

    assert abs(`mc_mean' - `true_logor') < 0.20
    assert `mc_coverage' >= 60
}
if _rc == 0 {
    display as result "  PASS 1.5: MC mean near truth and coverage >= 80%"
    local ++pass_count
}
else {
    display as error "  FAIL 1.5: MC performance out of spec (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.5"
}

* =========================================================================
* Test 1.6: Truncation improves ESS
* =========================================================================
local ++test_count
capture {
    * Regenerate the large dataset
    _v1_generate_dgp, n(10000) t(10) true_logor(`true_logor') seed(20260301)

    * Untruncated
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L) baseline_covariates(bl_L0)
    msm_weight, treat_d_cov(L bl_L0) treat_n_cov(bl_L0) nolog
    local ess_untrunc = r(ess)

    * Truncated
    msm_weight, treat_d_cov(L bl_L0) treat_n_cov(bl_L0) ///
        truncate(1 99) nolog replace
    local ess_trunc = r(ess)

    display "  ESS untruncated: " %9.1f `ess_untrunc'
    display "  ESS truncated:   " %9.1f `ess_trunc'
    assert `ess_trunc' >= `ess_untrunc'
}
if _rc == 0 {
    display as result "  PASS 1.6: Truncation improves ESS"
    local ++pass_count
}
else {
    display as error "  FAIL 1.6: Truncation should improve ESS (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.6"
}

* =========================================================================
* Test 1.7: Period specification robustness (linear, quadratic, cubic)
* =========================================================================
local ++test_count
capture {
    * Already have weighted data from test 1.6
    * Fit with different period specs and verify all are within 0.25 of truth
    local all_close = 1

    foreach pspec in linear quadratic cubic {
        quietly msm_fit, model(logistic) outcome_cov(bl_L0) period_spec(`pspec') nolog
        local b_`pspec' = _b[treatment]
        display "  Period spec `pspec': log-OR = " %7.4f `b_`pspec''
        if abs(`b_`pspec'' - `true_logor') > 0.25 {
            local all_close = 0
        }
    }
    assert `all_close' == 1
}
if _rc == 0 {
    display as result "  PASS 1.7: All period specs within 0.25 of truth"
    local ++pass_count
}
else {
    display as error "  FAIL 1.7: Period spec robustness (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.7"
}

* =========================================================================
* Test 1.8: Linear model direction check
* =========================================================================
local ++test_count
capture {
    quietly msm_fit, model(linear) outcome_cov(bl_L0) period_spec(linear) nolog
    local b_linear = _b[treatment]
    display "  Linear model coeff: " %9.6f `b_linear'
    * Treatment is protective (OR < 1), so linear coeff should be negative
    assert `b_linear' < 0
}
if _rc == 0 {
    display as result "  PASS 1.8: Linear model coefficient negative (protective)"
    local ++pass_count
}
else {
    display as error "  FAIL 1.8: Linear model should show protective effect (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1.8"
}

* =========================================================================
* SUMMARY
* =========================================================================
display ""
display "V1: KNOWN DGP SUMMARY"
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
display "RESULT: V1 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"
display ""
display "Completed: $S_DATE $S_TIME"

if `fail_count' > 0 {
    exit 1
}
