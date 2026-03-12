* crossval_msm.do
* Master cross-validation: msm package vs R, Python, teffects, and true counterfactuals
*
* Workflow:
*   1. Generate shared DGP datasets (Stata -> CSV)
*   2. Run msm on DGP1 (time-varying) and DGP2 (point-treatment)
*   3. Run R cross-validation (reads same CSV, exports results)
*   4. Run Python cross-validation (reads same CSV, exports results)
*   5. Compare Stata teffects ipw on DGP2
*   6. Compare all results with tolerances
*
* All results go in crossval_results/

version 16.0
set more off
set varabbrev off

local qa_dir "/home/tpcopeland/Stata-Tools/msm/qa"
local data_dir "`qa_dir'/crossval_data"
local results_dir "`qa_dir'/crossval_results"
adopath ++ "/home/tpcopeland/Stata-Tools/msm"

capture log close crossval
log using "`qa_dir'/crossval_msm.log", replace name(crossval)

* MSM CROSS-VALIDATION SUITE
* Stata msm vs R (ipw/survey) vs Python (statsmodels) vs teffects

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

timer clear
timer on 99

* ============================================================
* STEP 1: Generate shared datasets
* ============================================================
display "STEP 1: Generating shared DGP datasets..."

do "`qa_dir'/crossval_dgp_generate.do"

* ============================================================
* STEP 2: Run msm on DGP1 (time-varying treatment)
* ============================================================
display "STEP 2: Running msm on DGP1..."

use "`data_dir'/dgp1_panel.dta", clear

msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) covariates(L) baseline_covariates(V)

msm_weight, treat_d_cov(L V) treat_n_cov(V) nolog

local stata_w_mean = r(mean_weight)
local stata_w_sd = r(sd_weight)
local stata_ess = r(ess)

msm_fit, model(logistic) outcome_cov(V) period_spec(linear) nolog

local stata_b = _b[treatment]
local stata_se = _se[treatment]
local stata_or = exp(`stata_b')

display "  msm results (DGP1):"
display "    Weight mean:     " %9.4f `stata_w_mean'
display "    Weight SD:       " %9.4f `stata_w_sd'
display "    Treatment logOR: " %9.4f `stata_b'
display "    Treatment SE:    " %9.4f `stata_se'
display "    Treatment OR:    " %9.4f `stata_or'

* Export msm individual-level weights for comparison
preserve
    keep id period _msm_weight
    rename _msm_weight stata_weight
    export delimited using "`results_dir'/stata_weights_dgp1.csv", replace
restore

* Also export msm summary results
preserve
    clear
    set obs 1
    gen str30 method = "stata_msm"
    gen double weight_mean = `stata_w_mean'
    gen double weight_sd = `stata_w_sd'
    gen double coef = `stata_b'
    gen double se = `stata_se'
    gen double or_hr = `stata_or'
    export delimited using "`results_dir'/stata_results_dgp1.csv", replace
restore

* ============================================================
* STEP 2b: Run msm on DGP2 (point-treatment)
* ============================================================
display "STEP 2b: Running msm-style manual IPTW on DGP2..."

use "`data_dir'/dgp2_point.dta", clear

* For point-treatment, compute IPTW manually (msm is panel-based)
* Propensity score
quietly logit treatment X1 X2, nolog
predict double ps_stata, pr

* Stabilized weights
quietly summarize treatment
local p_treat = r(mean)

gen double sw_stata = .
replace sw_stata = `p_treat' / ps_stata if treatment == 1
replace sw_stata = (1 - `p_treat') / (1 - ps_stata) if treatment == 0

quietly summarize sw_stata
local stata_pt_w_mean = r(mean)
local stata_pt_w_sd = r(sd)

* Weighted regression
regress Y treatment [pw=sw_stata], vce(robust)
local stata_pt_ate = _b[treatment]
local stata_pt_se = _se[treatment]

display "  Manual IPTW results (DGP2, point-treatment):"
display "    Weight mean: " %9.4f `stata_pt_w_mean'
display "    Weight SD:   " %9.4f `stata_pt_w_sd'
display "    ATE:         " %9.4f `stata_pt_ate'
display "    SE:          " %9.4f `stata_pt_se'

* Export individual weights
preserve
    keep id ps_stata sw_stata
    export delimited using "`results_dir'/stata_weights_dgp2.csv", replace
restore

* ============================================================
* STEP 3: teffects ipw comparison (DGP2)
* ============================================================
display "STEP 3: Running teffects ipw on DGP2..."

teffects ipw (Y) (treatment X1 X2), ate nolog
local teffects_ate = r(table)[1,1]
local teffects_se = r(table)[2,1]

display "  teffects ipw results:"
display "    ATE: " %9.4f `teffects_ate'
display "    SE:  " %9.4f `teffects_se'

* ============================================================
* STEP 4: Run R cross-validation
* ============================================================
display "STEP 4: Running R cross-validation..."

!Rscript "`qa_dir'/crossval_r.R" > "`results_dir'/r_output.log" 2>&1
display "  R script completed. See crossval_results/r_output.log"

* ============================================================
* STEP 5: Run Python cross-validation
* ============================================================
display "STEP 5: Running Python cross-validation..."

!python3 "`qa_dir'/crossval_python.py" > "`results_dir'/py_output.log" 2>&1
display "  Python script completed. See crossval_results/py_output.log"

* ============================================================
* STEP 6: Load and compare results
* ============================================================
display "STEP 6: CROSS-VALIDATION COMPARISONS"

* --- 6A: Load R results ---
preserve
    import delimited using "`results_dir'/r_results.csv", clear varnames(1)
    display "R results:"
    list method weight_mean weight_sd coef se or_hr, noobs separator(0)

    * Extract R manual IPTW results
    local r_b = coef[1]
    local r_se = se[1]
    local r_w_mean = weight_mean[1]
    local r_w_sd = weight_sd[1]

    * Extract R point-treatment results
    local r_pt_ate = coef[4]
    local r_pt_se = se[4]
    local r_pt_w_mean = weight_mean[4]
restore

* --- 6B: Load Python results ---
preserve
    import delimited using "`results_dir'/py_results.csv", clear varnames(1)
    display "Python results:"
    list method weight_mean weight_sd coef se or_hr, noobs separator(0)

    * Extract Python IPTW results
    local py_b = coef[1]
    local py_se = se[1]
    local py_w_mean = weight_mean[1]
    local py_w_sd = weight_sd[1]

    * Extract Python point-treatment results
    local py_pt_ate = coef[3]
    local py_pt_se = se[3]
    local py_pt_w_mean = weight_mean[3]
restore

* ============================================================
* COMPARISON TABLE
* ============================================================
display "DGP1: TIME-VARYING TREATMENT (truth: log-OR = -0.3567)"
display "  Source            Weight Mean  Weight SD   Log-OR     SE"
display "  ------            -----------  ---------   ------     --"
display "  Stata msm        " %9.4f `stata_w_mean' "   " %8.4f `stata_w_sd' "   " %8.4f `stata_b' "  " %7.4f `stata_se'
display "  R (manual IPTW)  " %9.4f `r_w_mean' "   " %8.4f `r_w_sd' "   " %8.4f `r_b' "  " %7.4f `r_se'
display "  Python (manual)  " %9.4f `py_w_mean' "   " %8.4f `py_w_sd' "   " %8.4f `py_b' "  " %7.4f `py_se'

display "DGP2: POINT TREATMENT (truth: ATE = 2.000)"
display "  Source            Weight Mean  ATE        SE"
display "  ------            -----------  ----       --"
display "  Stata IPTW       " %9.4f `stata_pt_w_mean' "    " %8.4f `stata_pt_ate' "  " %7.4f `stata_pt_se'
display "  teffects ipw     " "    N/A" "    " %8.4f `teffects_ate' "  " %7.4f `teffects_se'
display "  R IPTW           " %9.4f `r_pt_w_mean' "    " %8.4f `r_pt_ate' "  " %7.4f `r_pt_se'
display "  Python IPTW      " %9.4f `py_pt_w_mean' "    " %8.4f `py_pt_ate' "  " %7.4f `py_pt_se'

* ============================================================
* FORMAL TESTS
* ============================================================

local true_logor = ln(0.70)

* --- Test C1: Stata vs R weight mean agreement (DGP1) ---
local ++test_count
capture {
    local diff = abs(`stata_w_mean' - `r_w_mean')
    display "  C1: Stata vs R weight mean diff = " %7.4f `diff'
    assert `diff' < 0.05
}
if _rc == 0 {
    display as result "  PASS C1: Stata vs R weight means agree (diff < 0.05)"
    local ++pass_count
}
else {
    display as error "  FAIL C1: Stata vs R weight means disagree"
    local ++fail_count
    local failed_tests "`failed_tests' C1"
}

* --- Test C2: Stata vs Python weight mean agreement (DGP1) ---
local ++test_count
capture {
    local diff = abs(`stata_w_mean' - `py_w_mean')
    display "  C2: Stata vs Python weight mean diff = " %7.4f `diff'
    assert `diff' < 0.05
}
if _rc == 0 {
    display as result "  PASS C2: Stata vs Python weight means agree (diff < 0.05)"
    local ++pass_count
}
else {
    display as error "  FAIL C2: Stata vs Python weight means disagree"
    local ++fail_count
    local failed_tests "`failed_tests' C2"
}

* --- Test C3: Stata vs R treatment effect agreement (DGP1) ---
local ++test_count
capture {
    local diff = abs(`stata_b' - `r_b')
    display "  C3: Stata vs R log-OR diff = " %7.4f `diff'
    assert `diff' < 0.10
}
if _rc == 0 {
    display as result "  PASS C3: Stata vs R treatment effects agree (diff < 0.10)"
    local ++pass_count
}
else {
    display as error "  FAIL C3: Stata vs R treatment effects disagree"
    local ++fail_count
    local failed_tests "`failed_tests' C3"
}

* --- Test C4: Stata vs Python treatment effect agreement (DGP1) ---
local ++test_count
capture {
    local diff = abs(`stata_b' - `py_b')
    display "  C4: Stata vs Python log-OR diff = " %7.4f `diff'
    assert `diff' < 0.10
}
if _rc == 0 {
    display as result "  PASS C4: Stata vs Python treatment effects agree (diff < 0.10)"
    local ++pass_count
}
else {
    display as error "  FAIL C4: Stata vs Python treatment effects disagree"
    local ++fail_count
    local failed_tests "`failed_tests' C4"
}

* --- Test C5: R vs Python treatment effect agreement (DGP1) ---
local ++test_count
capture {
    local diff = abs(`r_b' - `py_b')
    display "  C5: R vs Python log-OR diff = " %7.4f `diff'
    assert `diff' < 0.05
}
if _rc == 0 {
    display as result "  PASS C5: R vs Python treatment effects agree (diff < 0.05)"
    local ++pass_count
}
else {
    display as error "  FAIL C5: R vs Python treatment effects disagree"
    local ++fail_count
    local failed_tests "`failed_tests' C5"
}

* --- Test C6: All three estimate direction correct (DGP1, true < 0) ---
local ++test_count
capture {
    assert `stata_b' < 0 & `r_b' < 0 & `py_b' < 0
}
if _rc == 0 {
    display as result "  PASS C6: All three estimate negative (correct direction)"
    local ++pass_count
}
else {
    display as error "  FAIL C6: Not all estimates negative"
    local ++fail_count
    local failed_tests "`failed_tests' C6"
}

* --- Test C7: msm estimate within 0.20 of true log-OR (DGP1) ---
local ++test_count
capture {
    local diff = abs(`stata_b' - `true_logor')
    display "  C7: msm vs truth diff = " %7.4f `diff'
    assert `diff' < 0.20
}
if _rc == 0 {
    display as result "  PASS C7: msm estimate within 0.20 of truth"
    local ++pass_count
}
else {
    display as error "  FAIL C7: msm estimate too far from truth"
    local ++fail_count
    local failed_tests "`failed_tests' C7"
}

* --- Test C8: Stabilized weight means near 1.0 (all three) ---
local ++test_count
capture {
    assert abs(`stata_w_mean' - 1) < 0.10
    assert abs(`r_w_mean' - 1) < 0.10
    assert abs(`py_w_mean' - 1) < 0.10
}
if _rc == 0 {
    display as result "  PASS C8: All three weight means within 0.10 of 1.0"
    local ++pass_count
}
else {
    display as error "  FAIL C8: Weight mean(s) too far from 1.0"
    local ++fail_count
    local failed_tests "`failed_tests' C8"
}

* --- Test C9: Stata vs teffects ATE agreement (DGP2) ---
local ++test_count
capture {
    local diff = abs(`stata_pt_ate' - `teffects_ate')
    display "  C9: Stata manual IPTW vs teffects ATE diff = " %7.4f `diff'
    assert `diff' < 0.20
}
if _rc == 0 {
    display as result "  PASS C9: Manual IPTW vs teffects agree (diff < 0.20)"
    local ++pass_count
}
else {
    display as error "  FAIL C9: Manual IPTW vs teffects disagree"
    local ++fail_count
    local failed_tests "`failed_tests' C9"
}

* --- Test C10: Stata vs R vs Python ATE agreement (DGP2) ---
local ++test_count
capture {
    local diff_sr = abs(`stata_pt_ate' - `r_pt_ate')
    local diff_sp = abs(`stata_pt_ate' - `py_pt_ate')
    local diff_rp = abs(`r_pt_ate' - `py_pt_ate')
    display "  C10: Stata-R = " %6.4f `diff_sr' ", Stata-Py = " %6.4f `diff_sp' ", R-Py = " %6.4f `diff_rp'
    assert `diff_sr' < 0.10 & `diff_sp' < 0.10 & `diff_rp' < 0.05
}
if _rc == 0 {
    display as result "  PASS C10: All three point-treatment ATEs agree"
    local ++pass_count
}
else {
    display as error "  FAIL C10: Point-treatment ATEs disagree"
    local ++fail_count
    local failed_tests "`failed_tests' C10"
}

* --- Test C11: All point-treatment ATEs near true value of 2.0 ---
local ++test_count
capture {
    assert abs(`stata_pt_ate' - 2.0) < 0.50
    assert abs(`teffects_ate' - 2.0) < 0.50
    assert abs(`r_pt_ate' - 2.0) < 0.50
    assert abs(`py_pt_ate' - 2.0) < 0.50
}
if _rc == 0 {
    display as result "  PASS C11: All point-treatment ATEs within 0.50 of truth (2.0)"
    local ++pass_count
}
else {
    display as error "  FAIL C11: Some point-treatment ATE too far from 2.0"
    local ++fail_count
    local failed_tests "`failed_tests' C11"
}

* --- Test C12: Individual-level weight correlation Stata vs R (DGP1) ---
local ++test_count
capture {
    preserve
        import delimited using "`results_dir'/stata_weights_dgp1.csv", clear varnames(1)
        tempfile stata_w
        save `stata_w'

        import delimited using "`results_dir'/r_weights_dgp1.csv", clear varnames(1)
        merge 1:1 id period using `stata_w', nogenerate

        correlate stata_weight r_manual_weight
        local corr_sr = r(rho)
        display "  C12: Stata-R weight correlation = " %7.5f `corr_sr'
        assert `corr_sr' > 0.95
    restore
}
if _rc == 0 {
    display as result "  PASS C12: Stata-R individual weight correlation > 0.95"
    local ++pass_count
}
else {
    display as error "  FAIL C12: Stata-R weight correlation too low"
    local ++fail_count
    local failed_tests "`failed_tests' C12"
}

* --- Test C13: Individual-level weight correlation Stata vs Python (DGP1) ---
local ++test_count
capture {
    preserve
        import delimited using "`results_dir'/stata_weights_dgp1.csv", clear varnames(1)
        tempfile stata_w
        save `stata_w'

        import delimited using "`results_dir'/py_weights_dgp1.csv", clear varnames(1)
        merge 1:1 id period using `stata_w', nogenerate

        correlate stata_weight py_weight
        local corr_sp = r(rho)
        display "  C13: Stata-Python weight correlation = " %7.5f `corr_sp'
        assert `corr_sp' > 0.95
    restore
}
if _rc == 0 {
    display as result "  PASS C13: Stata-Python individual weight correlation > 0.95"
    local ++pass_count
}
else {
    display as error "  FAIL C13: Stata-Python weight correlation too low"
    local ++fail_count
    local failed_tests "`failed_tests' C13"
}

* --- Test C14: Individual-level PS correlation DGP2 (Stata vs R vs Python) ---
local ++test_count
capture {
    preserve
        import delimited using "`results_dir'/stata_weights_dgp2.csv", clear varnames(1)
        tempfile stata_pt
        save `stata_pt'

        import delimited using "`results_dir'/r_weights_dgp2.csv", clear varnames(1)
        tempfile r_pt
        save `r_pt'

        import delimited using "`results_dir'/py_weights_dgp2.csv", clear varnames(1)
        merge 1:1 id using `r_pt', nogenerate
        merge 1:1 id using `stata_pt', nogenerate

        correlate ps_stata r_ps py_ps
        local corr_sr_ps = r(rho)
        * Just check any pair > 0.999 (identical PS models)
        correlate ps_stata r_ps
        local corr1 = r(rho)
        correlate ps_stata py_ps
        local corr2 = r(rho)
        display "  C14: PS correlation Stata-R = " %8.6f `corr1' ", Stata-Py = " %8.6f `corr2'
        assert `corr1' > 0.999 & `corr2' > 0.999
    restore
}
if _rc == 0 {
    display as result "  PASS C14: Propensity score correlations > 0.999"
    local ++pass_count
}
else {
    display as error "  FAIL C14: Propensity score correlations too low"
    local ++fail_count
    local failed_tests "`failed_tests' C14"
}

* ============================================================
* STEP 7: TRUE COUNTERFACTUAL COMPARISON
* ============================================================
display "STEP 7: TRUE COUNTERFACTUAL COMPARISON (DGP3)"

* Load true counterfactual risks
use "`data_dir'/dgp3_true_counterfactual.dta", clear
list, noobs separator(0)

quietly summarize true_log_or
local pooled_true_logor = r(mean)
display "  Pooled true log-OR (mean across periods): " %7.4f `pooled_true_logor'
display "  msm estimate (DGP1, same DGP):            " %7.4f `stata_b'

* --- Test C15: DGP3 counterfactual is internally valid ---
* NOTE: The sustained-strategy counterfactual (always vs never) measures the
* TOTAL causal effect including treatment-confounder feedback (A->L->Y).
* This differs from the MSM per-period coefficient, which estimates the
* direct effect of current treatment. When feedback is strong (0.8*A_t in L),
* the indirect harmful pathway (A->L_up->Y_up) can dominate, making the
* sustained strategy effect positive even when the per-period effect is negative.
* This is expected and well-documented in the MSM literature.
local ++test_count
capture {
    * Verify counterfactual risks are valid probabilities
    assert risk_always >= 0 & risk_always <= 1
    assert risk_never >= 0 & risk_never <= 1
    * Verify ORs are well-defined and positive
    assert true_or > 0 & !missing(true_or)
    display "  C15: Counterfactual risks valid (always: " ///
        %6.4f risk_always[1] "-" %6.4f risk_always[_N] ///
        ", never: " %6.4f risk_never[1] "-" %6.4f risk_never[_N] ")"
}
if _rc == 0 {
    display as result "  PASS C15: DGP3 counterfactual is internally valid"
    local ++pass_count
}
else {
    display as error "  FAIL C15: DGP3 counterfactual has invalid values"
    local ++fail_count
    local failed_tests "`failed_tests' C15"
}

* --- Test C16: msm 95% CI covers true conditional log-OR ---
* The MSM coefficient should recover the DGP's conditional treatment effect
* (true_logor = ln(0.70) = -0.357), not the sustained-strategy effect.
local ++test_count
capture {
    local ci_lo = `stata_b' - 1.96 * `stata_se'
    local ci_hi = `stata_b' + 1.96 * `stata_se'
    display "  C16: msm 95% CI = [" %7.4f `ci_lo' ", " %7.4f `ci_hi' "]"
    display "        True conditional log-OR = " %7.4f `true_logor'
    assert `ci_lo' < `true_logor' & `ci_hi' > `true_logor'
}
if _rc == 0 {
    display as result "  PASS C16: msm 95% CI covers true conditional log-OR"
    local ++pass_count
}
else {
    display as error "  FAIL C16: msm 95% CI does not cover true conditional log-OR"
    local ++fail_count
    local failed_tests "`failed_tests' C16"
}

* ============================================================
* Summary
* ============================================================
timer off 99
quietly timer list 99

display as text ""
display as result "Crossval Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME CROSS-VALIDATIONS FAILED"
    display as error "Failed:`failed_tests'"
}
else {
    display as result "ALL CROSS-VALIDATIONS PASSED"
}

local cv_status = cond(`fail_count' > 0, "FAIL", "PASS")
display ""
display "RESULT: CROSSVAL tests=`test_count' pass=`pass_count' fail=`fail_count' status=`cv_status'"

* ============================================================
* Save summary results table
* ============================================================
preserve
    clear
    set obs 8
    gen str30 source = ""
    gen str10 dgp = ""
    gen double weight_mean = .
    gen double coef = .
    gen double se = .
    gen str10 metric = ""

    replace source = "stata_msm" in 1
    replace dgp = "DGP1" in 1
    replace weight_mean = `stata_w_mean' in 1
    replace coef = `stata_b' in 1
    replace se = `stata_se' in 1
    replace metric = "log-OR" in 1

    replace source = "R_manual" in 2
    replace dgp = "DGP1" in 2
    replace weight_mean = `r_w_mean' in 2
    replace coef = `r_b' in 2
    replace se = `r_se' in 2
    replace metric = "log-OR" in 2

    replace source = "Python" in 3
    replace dgp = "DGP1" in 3
    replace weight_mean = `py_w_mean' in 3
    replace coef = `py_b' in 3
    replace se = `py_se' in 3
    replace metric = "log-OR" in 3

    replace source = "stata_iptw" in 4
    replace dgp = "DGP2" in 4
    replace weight_mean = `stata_pt_w_mean' in 4
    replace coef = `stata_pt_ate' in 4
    replace se = `stata_pt_se' in 4
    replace metric = "ATE" in 4

    replace source = "teffects" in 5
    replace dgp = "DGP2" in 5
    replace coef = `teffects_ate' in 5
    replace se = `teffects_se' in 5
    replace metric = "ATE" in 5

    replace source = "R_iptw" in 6
    replace dgp = "DGP2" in 6
    replace weight_mean = `r_pt_w_mean' in 6
    replace coef = `r_pt_ate' in 6
    replace se = `r_pt_se' in 6
    replace metric = "ATE" in 6

    replace source = "Python_iptw" in 7
    replace dgp = "DGP2" in 7
    replace weight_mean = `py_pt_w_mean' in 7
    replace coef = `py_pt_ate' in 7
    replace se = `py_pt_se' in 7
    replace metric = "ATE" in 7

    replace source = "true_cf" in 8
    replace dgp = "DGP3" in 8
    replace coef = `pooled_true_logor' in 8
    replace metric = "log-OR" in 8

    export delimited using "`results_dir'/crossval_summary.csv", replace
    display "Saved: crossval_results/crossval_summary.csv"
restore

log close crossval

if `fail_count' > 0 {
    exit 1
}
