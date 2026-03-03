* validate_null_repro.do — V5: Null Effect & Reproducibility
* Same DGP as V1 but true_effect = 0
* Tests type I error control, seed reproducibility

version 16.0
set more off
set varabbrev off

local qa_dir "/home/tpcopeland/Stata-Dev/msm/qa"
adopath ++ "/home/tpcopeland/Stata-Dev/msm"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display "V5: NULL EFFECT & REPRODUCIBILITY"
display "Date: $S_DATE $S_TIME"
display ""

* =========================================================================
* DGP: Same as V1 but true log-OR = 0 (no causal effect)
* =========================================================================
capture program drop _v5_generate_dgp
program define _v5_generate_dgp
    version 16.0
    syntax , n(integer) t(integer) seed(integer)

    clear
    set seed `seed'
    local N_total = `n' * `t'
    set obs `N_total'

    gen long id = ceil(_n / `t')
    bysort id: gen int period = _n - 1

    gen double L = .
    gen byte treatment = .
    gen byte outcome = .

    sort id period
    quietly {
        by id: replace L = rnormal(0, 1) if period == 0
        by id: replace treatment = (runiform() < invlogit(-1 + 0.5 * L)) if period == 0
        * true_logor = 0 => treatment has NO causal effect
        by id: replace outcome = (runiform() < invlogit(-4 + 0.5 * L)) if period == 0

        forvalues p = 1/`=`t'-1' {
            by id: replace L = 0.5 * L[_n-1] + 0.4 * treatment[_n-1] + rnormal(0, 0.5) if period == `p'
            by id: replace treatment = (runiform() < invlogit(-1 + 0.5 * L + 0.3 * treatment[_n-1])) if period == `p'
            by id: replace outcome = (runiform() < invlogit(-4 + 0.5 * L)) if period == `p'
        }
    }

    gen double bl_L0 = .
    sort id period
    by id: replace bl_L0 = L[1]
end

* =========================================================================
* Test 5.1: Point estimate near zero
* =========================================================================
local ++test_count
capture {
    _v5_generate_dgp, n(10000) t(10) seed(50501)

    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) covariates(L) baseline_covariates(bl_L0)
    msm_weight, treat_d_cov(L bl_L0) treat_n_cov(bl_L0) nolog
    msm_fit, model(logistic) outcome_cov(bl_L0) period_spec(linear) nolog

    local b_null = _b[treatment]
    display "  Null DGP log-OR: " %7.4f `b_null'
    assert abs(`b_null') < 0.20
}
if _rc == 0 {
    display as result "  PASS 5.1: Point estimate near zero (|log-OR| < 0.20)"
    local ++pass_count
}
else {
    display as error "  FAIL 5.1: Point estimate not near zero (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.1"
}

* =========================================================================
* Test 5.2: 95% CI covers null (0)
* =========================================================================
local ++test_count
capture {
    local se_null = _se[treatment]
    local ci_lo = `b_null' - 1.96 * `se_null'
    local ci_hi = `b_null' + 1.96 * `se_null'
    display "  95% CI: [" %7.4f `ci_lo' ", " %7.4f `ci_hi' "]"
    assert `ci_lo' < 0 & `ci_hi' > 0
}
if _rc == 0 {
    display as result "  PASS 5.2: 95% CI covers null"
    local ++pass_count
}
else {
    display as error "  FAIL 5.2: 95% CI should cover null (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.2"
}

* =========================================================================
* Test 5.3: 100-rep rejection rate < 15%
* =========================================================================
local ++test_count
display ""
display "  Running 100-rep Monte Carlo for rejection rate..."
capture {
    local mc_reps = 100
    local n_reject = 0

    forvalues rep = 1/`mc_reps' {
        local mc_seed = 50000 + `rep'
        quietly {
            _v5_generate_dgp, n(3000) t(10) seed(`mc_seed')

            msm_prepare, id(id) period(period) treatment(treatment) ///
                outcome(outcome) covariates(L) baseline_covariates(bl_L0)
            msm_weight, treat_d_cov(L bl_L0) treat_n_cov(bl_L0) nolog
            msm_fit, model(logistic) outcome_cov(bl_L0) period_spec(linear) nolog

            local b_rep = _b[treatment]
            local se_rep = _se[treatment]
            local z_rep = abs(`b_rep' / `se_rep')
            if `z_rep' > 1.96 {
                local ++n_reject
            }
        }
        if mod(`rep', 25) == 0 {
            display "    ... `rep' of `mc_reps' reps"
        }
    }

    local reject_rate = 100 * `n_reject' / `mc_reps'
    display "  Rejection rate: " %5.1f `reject_rate' "% (threshold: 15%)"
    assert `reject_rate' < 15
}
if _rc == 0 {
    display as result "  PASS 5.3: Rejection rate < 15% (type I error controlled)"
    local ++pass_count
}
else {
    display as error "  FAIL 5.3: Rejection rate too high (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.3"
}

* =========================================================================
* Test 5.4: Seed reproducibility (identical coefficients)
* =========================================================================
local ++test_count
capture {
    * Run 1
    quietly {
        _v5_generate_dgp, n(5000) t(10) seed(54321)
        msm_prepare, id(id) period(period) treatment(treatment) ///
            outcome(outcome) covariates(L) baseline_covariates(bl_L0)
        msm_weight, treat_d_cov(L bl_L0) treat_n_cov(bl_L0) nolog
        msm_fit, model(logistic) outcome_cov(bl_L0) period_spec(linear) nolog
    }
    local b_run1 = _b[treatment]

    * Run 2 (same seed)
    quietly {
        _v5_generate_dgp, n(5000) t(10) seed(54321)
        msm_prepare, id(id) period(period) treatment(treatment) ///
            outcome(outcome) covariates(L) baseline_covariates(bl_L0)
        msm_weight, treat_d_cov(L bl_L0) treat_n_cov(bl_L0) nolog
        msm_fit, model(logistic) outcome_cov(bl_L0) period_spec(linear) nolog
    }
    local b_run2 = _b[treatment]

    display "  Run 1: " %12.8f `b_run1'
    display "  Run 2: " %12.8f `b_run2'
    assert reldif(`b_run1', `b_run2') < 1e-10
}
if _rc == 0 {
    display as result "  PASS 5.4: Seed reproducibility (identical coefficients)"
    local ++pass_count
}
else {
    display as error "  FAIL 5.4: Results not reproducible with same seed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.4"
}

* =========================================================================
* Test 5.5: Predict reproducibility (identical matrices)
* =========================================================================
local ++test_count
capture {
    * Already have fitted model from run 2 above
    msm_predict, times(3 5 9) type(cum_inc) samples(30) seed(99) difference
    tempname pred1
    matrix `pred1' = r(predictions)

    * Re-predict with same seed
    msm_predict, times(3 5 9) type(cum_inc) samples(30) seed(99) difference
    tempname pred2
    matrix `pred2' = r(predictions)

    * Compare all elements
    local n_rows = rowsof(`pred1')
    local n_cols = colsof(`pred1')
    local all_match = 1
    forvalues i = 1/`n_rows' {
        forvalues j = 1/`n_cols' {
            if reldif(`pred1'[`i',`j'], `pred2'[`i',`j']) > 1e-8 {
                local all_match = 0
            }
        }
    }
    assert `all_match' == 1
}
if _rc == 0 {
    display as result "  PASS 5.5: Predict reproducibility (identical matrices)"
    local ++pass_count
}
else {
    display as error "  FAIL 5.5: Prediction matrices differ across runs (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.5"
}

* =========================================================================
* Test 5.6: Risk difference near zero
* =========================================================================
local ++test_count
capture {
    * Use predictions from test 5.5
    local rd_9 = `pred1'[3, 8]
    display "  Risk difference at t=9: " %9.6f `rd_9'
    assert abs(`rd_9') < 0.10
}
if _rc == 0 {
    display as result "  PASS 5.6: Risk difference near zero"
    local ++pass_count
}
else {
    display as error "  FAIL 5.6: Risk difference should be near zero (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5.6"
}

* =========================================================================
* SUMMARY
* =========================================================================
display ""
display "V5: NULL EFFECT & REPRODUCIBILITY SUMMARY"
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
display "RESULT: V5 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"
display ""
display "Completed: $S_DATE $S_TIME"

if `fail_count' > 0 {
    exit 1
}
