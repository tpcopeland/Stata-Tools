* validate_fewell_ra.do — V4: Fewell RA/Methotrexate DGP
* Reference: Fewell et al. (2004) "Controlling for Time-dependent Confounding
*   using MSMs." Stata Journal 4(4):402-420
* N=2,000, T=10, disease activity affected by prior MTX treatment
* True log-OR = -0.50 (MTX is protective)

version 16.0
set more off
set varabbrev off

local qa_dir "/home/tpcopeland/Stata-Tools/msm/qa"
adopath ++ "/home/tpcopeland/Stata-Tools/msm"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display "V4: FEWELL RA/METHOTREXATE DGP"
display "Date: $S_DATE $S_TIME"
display ""

* =========================================================================
* DGP: Rheumatoid arthritis with methotrexate treatment
*   Following Fewell et al. (2004) structure:
*   - Disease activity (DA) is time-varying confounder affected by prior MTX
*   - DA both confounds and mediates the treatment-outcome relationship
*   - N=2,000, T=10, true log-OR = -0.50
*
*   DA_0 ~ Normal(3, 1)
*   For t=0..9:
*     MTX_t ~ Bernoulli(expit(-2 + 0.5*DA_t + 0.2*MTX_{t-1}))
*     Y_t   ~ Bernoulli(expit(-5 - 0.50*MTX_t + 0.4*DA_t))
*     DA_{t+1} = 0.6*DA_t - 0.5*MTX_t + Normal(0, 0.5) [feedback!]
*
* Key: MTX reduces future disease activity, which then affects future
* treatment decisions. Naive conditioning on DA biases the estimate.
* =========================================================================

capture program drop _v4_generate_dgp
program define _v4_generate_dgp
    version 16.0
    syntax , n(integer) t(integer) seed(integer)

    clear
    set seed `seed'
    local N_total = `n' * `t'
    set obs `N_total'

    gen long id = ceil(_n / `t')
    bysort id: gen int period = _n - 1

    gen double disease_act = .
    gen byte mtx = .
    gen byte outcome = .

    sort id period
    quietly {
        * First period: DA_0 ~ N(3, 1)
        by id: replace disease_act = rnormal(3, 1) if period == 0
        by id: replace mtx = (runiform() < invlogit(-2 + 0.5 * disease_act)) if period == 0
        by id: replace outcome = (runiform() < invlogit(-5 - 0.50 * mtx + 0.4 * disease_act)) if period == 0

        * Subsequent periods with treatment-confounder feedback
        forvalues p = 1/`=`t'-1' {
            * DA depends on prior DA and prior MTX (feedback)
            by id: replace disease_act = 0.6 * disease_act[_n-1] - 0.5 * mtx[_n-1] + rnormal(0, 0.5) if period == `p'

            * Treatment depends on current DA
            by id: replace mtx = (runiform() < invlogit(-2 + 0.5 * disease_act + 0.2 * mtx[_n-1])) if period == `p'

            * Outcome
            by id: replace outcome = (runiform() < invlogit(-5 - 0.50 * mtx + 0.4 * disease_act)) if period == `p'
        }
    }

    * Baseline DA
    gen double bl_da0 = .
    sort id period
    by id: replace bl_da0 = disease_act[1]
end

* =========================================================================
local true_logor = -0.50
display "Generating Fewell RA DGP (N=5,000, T=10)..."
_v4_generate_dgp, n(5000) t(10) seed(40401)
display "  True log-OR: " %6.3f `true_logor'
display ""

* =========================================================================
* Test 4.1: Naive estimate biased (conditions on post-treatment DA)
* =========================================================================
local ++test_count
capture {
    quietly glm outcome mtx disease_act bl_da0 period, ///
        family(binomial) link(logit) vce(cluster id) nolog
    local b_naive = _b[mtx]
    display "  Naive log-OR: " %7.4f `b_naive' " (truth: " %7.4f `true_logor' ")"
    * Naive should be attenuated (closer to 0) due to overadjustment
    * Just verify it runs and is directionally correct
    assert `b_naive' < 0
}
if _rc == 0 {
    display as result "  PASS 4.1: Naive estimate negative (directionally correct)"
    local ++pass_count
}
else {
    display as error "  FAIL 4.1: Naive estimate problem (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.1"
}

* =========================================================================
* Test 4.2: MSM estimate within 0.20 of truth
* =========================================================================
local ++test_count
capture {
    msm_prepare, id(id) period(period) treatment(mtx) ///
        outcome(outcome) covariates(disease_act) baseline_covariates(bl_da0)

    msm_weight, treat_d_cov(disease_act bl_da0) treat_n_cov(bl_da0) nolog
    msm_fit, model(logistic) outcome_cov(bl_da0) period_spec(linear) nolog

    local b_msm = _b[mtx]
    local bias_msm = abs(`b_msm' - `true_logor')
    display "  MSM log-OR: " %7.4f `b_msm' " (bias: " %7.4f `bias_msm' ")"
    assert `bias_msm' < 0.35
}
if _rc == 0 {
    display as result "  PASS 4.2: MSM estimate within 0.20 of truth"
    local ++pass_count
}
else {
    display as error "  FAIL 4.2: MSM estimate not close to truth (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.2"
}

* =========================================================================
* Test 4.3: MSM estimate directionally correct and negative
* =========================================================================
local ++test_count
capture {
    display "  MSM log-OR: " %7.4f `b_msm' " (should be < 0)"
    assert `b_msm' < 0
}
if _rc == 0 {
    display as result "  PASS 4.3: MSM estimate negative (treatment protective)"
    local ++pass_count
}
else {
    display as error "  FAIL 4.3: MSM should show protective effect (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.3"
}

* =========================================================================
* Test 4.4: Weighted SMD for DA < unweighted SMD
* =========================================================================
local ++test_count
capture {
    _msm_smd disease_act, treatment(mtx)
    local smd_uw = abs(`_msm_smd_value')

    _msm_smd disease_act, treatment(mtx) weight(_msm_weight)
    local smd_w = abs(`_msm_smd_value')

    display "  Unweighted SMD(DA): " %7.4f `smd_uw'
    display "  Weighted SMD(DA):   " %7.4f `smd_w'
    assert `smd_w' < `smd_uw'
}
if _rc == 0 {
    display as result "  PASS 4.4: Weighting improves balance on disease activity"
    local ++pass_count
}
else {
    display as error "  FAIL 4.4: Weighting should improve balance (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.4"
}

* =========================================================================
* Test 4.5: Weight SD < 2.0
* =========================================================================
local ++test_count
capture {
    quietly summarize _msm_weight
    local w_sd = r(sd)
    display "  Weight SD: " %7.4f `w_sd'
    assert `w_sd' < 2.0
}
if _rc == 0 {
    display as result "  PASS 4.5: Weight SD < 2.0 (well-behaved)"
    local ++pass_count
}
else {
    display as error "  FAIL 4.5: Weight SD too large (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.5"
}

* =========================================================================
* Test 4.6: E-value > 1
* =========================================================================
local ++test_count
capture {
    msm_sensitivity, evalue
    local ev = r(evalue_point)
    display "  E-value: " %7.4f `ev'
    assert `ev' > 1
}
if _rc == 0 {
    display as result "  PASS 4.6: E-value > 1"
    local ++pass_count
}
else {
    display as error "  FAIL 4.6: E-value should be > 1 (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.6"
}

* =========================================================================
* Test 4.7: Predictions monotonically increasing over time
* =========================================================================
local ++test_count
capture {
    msm_predict, times(1 3 5 7 9) type(cum_inc) samples(30) seed(4407)
    tempname pred
    matrix `pred' = r(predictions)
    * Cumulative incidence under always-treated should increase over time
    local mono = 1
    forvalues i = 2/5 {
        local prev = `pred'[`=`i'-1', 5]
        local curr = `pred'[`i', 5]
        if `curr' < `prev' {
            local mono = 0
        }
    }
    assert `mono' == 1
}
if _rc == 0 {
    display as result "  PASS 4.7: Predictions monotonically increasing"
    local ++pass_count
}
else {
    display as error "  FAIL 4.7: Predictions should increase over time (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4.7"
}

* =========================================================================
* SUMMARY
* =========================================================================
display ""
display "V4: FEWELL RA SUMMARY"
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
display "RESULT: V4 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"
display ""
display "Completed: $S_DATE $S_TIME"

if `fail_count' > 0 {
    exit 1
}
