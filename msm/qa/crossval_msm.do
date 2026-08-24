* crossval_msm.do
* Master cross-validation: msm package vs R, Python, teffects, and true counterfactuals
* 
* Workflow:
*   1. Generate shared DGP datasets (Stata -> CSV)
*   2. Run msm on DGP1 (time-varying) and DGP2 (one-period binary outcome)
*   3. Run R cross-validation (reads same CSV, exports results)
*   4. Run Python cross-validation (reads same CSV, exports results)
*   5. Compare Stata teffects ipw on DGP2
*   6. Compare all results with tolerances
*
* By default, all generated files live in a temporary staging directory and are
* deleted on success. Pass "keep" to retain the staging directory for debugging.

version 16.0
set more off
set varabbrev off

* === Bootstrap ===
local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local mode = lower(strtrim("`0'"))
local keep_outputs = inlist("`mode'", "keep", "retain")

* lint: unseeded-ok — uniqueness, not reproducibility
local work_id = string(floor(runiform() * 1000000000), "%09.0f")
local work_root "`c(tmpdir)'/msm_crossval_`work_id'"
local work_qa_dir "`work_root'/qa"
local data_dir "`work_qa_dir'/crossval_data"
local results_dir "`work_qa_dir'/crossval_results"
local stage_log "`work_root'/crossval_msm.log"

capture mkdir "`work_root'"
capture mkdir "`work_qa_dir'"
capture mkdir "`data_dir'"
capture mkdir "`results_dir'"

copy "`qa_dir'/_crossval_dgp_generate.do" "`work_qa_dir'/_crossval_dgp_generate.do", replace
copy "`qa_dir'/crossval_r.R" "`work_qa_dir'/crossval_r.R", replace
copy "`qa_dir'/crossval_python.py" "`work_qa_dir'/crossval_python.py", replace

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

capture log close crossval
log using "`stage_log'", replace name(crossval)

display "Cross-validation staging directory: `work_root'"
if `keep_outputs' {
    display "Staging retention: keep"
}
else {
    display "Staging retention: cleanup on success"
}

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

local orig_pwd "`c(pwd)'"
cd "`work_qa_dir'"
do "`work_qa_dir'/_crossval_dgp_generate.do"
cd "`orig_pwd'"

* ============================================================
* STEP 2: Run msm on DGP1 (time-varying treatment)
* ============================================================
display "STEP 2: Running msm on DGP1..."

use "`data_dir'/dgp1_panel.dta", clear

quietly msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) covariates(L) baseline_covariates(V)

quietly msm_weight, treat_d_cov(L V) treat_n_cov(V) nolog

local stata_w_mean = r(mean_weight)
local stata_w_sd = r(sd_weight)
local stata_ess = r(ess)

quietly msm_fit, model(logistic) outcome_cov(V) period_spec(linear) nolog

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
display "STEP 2b: Running msm on DGP2..."

use "`data_dir'/dgp2_point.dta", clear

quietly summarize true_rd, meanonly
local true_pt_ate = r(mean)

quietly msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) baseline_covariates(X1 X2)
quietly msm_weight, treat_d_cov(X1 X2) nolog

quietly summarize _msm_weight
local stata_pt_w_mean = r(mean)
local stata_pt_w_sd = r(sd)

quietly msm_fit, model(linear) period_spec(none) vce(robust) nolog
local stata_pt_ate = _b[treatment]
local stata_pt_se = _se[treatment]

display "  msm results (DGP2, one-period binary outcome):"
display "    Weight mean: " %9.4f `stata_pt_w_mean'
display "    Weight SD:   " %9.4f `stata_pt_w_sd'
display "    Risk diff.:  " %9.4f `stata_pt_ate'
display "    SE:          " %9.4f `stata_pt_se'
display "    True RD:     " %9.4f `true_pt_ate'

* Export the package-produced propensity score and stabilized weight.
preserve
    keep id _msm_ps _msm_weight
    rename (_msm_ps _msm_weight) (ps_stata sw_stata)
    export delimited using "`results_dir'/stata_weights_dgp2.csv", replace
restore

* ============================================================
* STEP 3: teffects ipw comparison (DGP2)
* ============================================================
display "STEP 3: Running teffects ipw on DGP2..."

teffects ipw (outcome) (treatment X1 X2), ate nolog
local teffects_ate = r(table)[1,1]
local teffects_se = r(table)[2,1]

display "  teffects ipw results:"
display "    ATE: " %9.4f `teffects_ate'
display "    SE:  " %9.4f `teffects_se'

* ============================================================
* STEP 4: Run R cross-validation
* ============================================================
display "STEP 4: Running R cross-validation..."

capture erase "`results_dir'/r_results.csv"
capture noisily shell Rscript "`work_qa_dir'/crossval_r.R" > "`results_dir'/r_output.log" 2>&1
local r_shell_rc = _rc
capture confirm file "`results_dir'/r_results.csv"
local r_file_rc = _rc
mata: st_numscalar("r_r_complete", ///
    any(strpos(cat(st_local("results_dir") + "/r_output.log"), ///
    "=== R CROSS-VALIDATION COMPLETE ===") :> 0))
if `r_shell_rc' | `r_file_rc' | r_r_complete != 1 {
    display as error "R cross-validation did not produce r_results.csv"
    display as error "See `results_dir'/r_output.log"
    exit 459
}
display "  R script completed. See `results_dir'/r_output.log"

* ============================================================
* STEP 5: Run Python cross-validation
* ============================================================
display "STEP 5: Running Python cross-validation..."

capture erase "`results_dir'/py_results.csv"
capture noisily shell python3 "`work_qa_dir'/crossval_python.py" > "`results_dir'/py_output.log" 2>&1
local py_shell_rc = _rc
capture confirm file "`results_dir'/py_results.csv"
local py_file_rc = _rc
mata: st_numscalar("r_py_complete", ///
    any(strpos(cat(st_local("results_dir") + "/py_output.log"), ///
    "=== PYTHON CROSS-VALIDATION COMPLETE ===") :> 0))
if `py_shell_rc' | `py_file_rc' | r_py_complete != 1 {
    display as error "Python cross-validation did not produce py_results.csv"
    display as error "See `results_dir'/py_output.log"
    exit 459
}
display "  Python script completed. See `results_dir'/py_output.log"

* ============================================================
* STEP 6: Load and compare results
* ============================================================
display "STEP 6: CROSS-VALIDATION COMPARISONS"

* --- 6A: Load R results ---
preserve
    import delimited using "`results_dir'/r_results.csv", clear varnames(1)
    confirm variable method weight_mean weight_sd coef se or_hr
    assert _N == 4
    isid method
    foreach m in r_manual_iptw r_ipwtm r_naive r_point_treatment {
        quietly count if method == "`m'"
        assert r(N) == 1
    }
    assert !missing(weight_mean, weight_sd, coef, se) ///
        if inlist(method, "r_manual_iptw", "r_ipwtm", "r_point_treatment")
    assert weight_mean > 0 & weight_sd >= 0 & se > 0 ///
        if inlist(method, "r_manual_iptw", "r_ipwtm", "r_point_treatment")
    display "R results:"
    list method weight_mean weight_sd coef se or_hr, noobs separator(0)

    * Extract R manual IPTW results
    quietly summarize coef if method == "r_manual_iptw", meanonly
    local r_b = r(mean)
    quietly summarize se if method == "r_manual_iptw", meanonly
    local r_se = r(mean)
    quietly summarize weight_mean if method == "r_manual_iptw", meanonly
    local r_w_mean = r(mean)
    quietly summarize weight_sd if method == "r_manual_iptw", meanonly
    local r_w_sd = r(mean)

    * Extract R point-treatment results
    quietly summarize coef if method == "r_point_treatment", meanonly
    local r_pt_ate = r(mean)
    quietly summarize se if method == "r_point_treatment", meanonly
    local r_pt_se = r(mean)
    quietly summarize weight_mean if method == "r_point_treatment", meanonly
    local r_pt_w_mean = r(mean)

    * Independent package smoke result: this must not be a silently swallowed NA.
    quietly summarize coef if method == "r_ipwtm", meanonly
    local r_ipwtm_b = r(mean)
    quietly summarize se if method == "r_ipwtm", meanonly
    local r_ipwtm_se = r(mean)
    quietly summarize weight_mean if method == "r_ipwtm", meanonly
    local r_ipwtm_w_mean = r(mean)
restore

* --- 6B: Load Python results ---
preserve
    import delimited using "`results_dir'/py_results.csv", clear varnames(1)
    confirm variable method weight_mean weight_sd coef se or_hr
    assert _N == 3
    isid method
    foreach m in py_manual_iptw py_naive py_point_treatment {
        quietly count if method == "`m'"
        assert r(N) == 1
    }
    assert !missing(weight_mean, weight_sd, coef, se) ///
        if inlist(method, "py_manual_iptw", "py_point_treatment")
    assert weight_mean > 0 & weight_sd >= 0 & se > 0 ///
        if inlist(method, "py_manual_iptw", "py_point_treatment")
    display "Python results:"
    list method weight_mean weight_sd coef se or_hr, noobs separator(0)

    * Extract Python IPTW results
    quietly summarize coef if method == "py_manual_iptw", meanonly
    local py_b = r(mean)
    quietly summarize se if method == "py_manual_iptw", meanonly
    local py_se = r(mean)
    quietly summarize weight_mean if method == "py_manual_iptw", meanonly
    local py_w_mean = r(mean)
    quietly summarize weight_sd if method == "py_manual_iptw", meanonly
    local py_w_sd = r(mean)

    * Extract Python point-treatment results
    quietly summarize coef if method == "py_point_treatment", meanonly
    local py_pt_ate = r(mean)
    quietly summarize se if method == "py_point_treatment", meanonly
    local py_pt_se = r(mean)
    quietly summarize weight_mean if method == "py_point_treatment", meanonly
    local py_pt_w_mean = r(mean)
restore

* ============================================================
* COMPARISON TABLE
* ============================================================
display "DGP1: TIME-VARYING TREATMENT (conditional DGP coefficient = -0.3567)"
display "  Source            Weight Mean  Weight SD   Log-OR     SE"
display "  ------            -----------  ---------   ------     --"
display "  Stata msm        " %9.4f `stata_w_mean' "   " %8.4f `stata_w_sd' "   " %8.4f `stata_b' "  " %7.4f `stata_se'
display "  R (manual IPTW)  " %9.4f `r_w_mean' "   " %8.4f `r_w_sd' "   " %8.4f `r_b' "  " %7.4f `r_se'
display "  Python (manual)  " %9.4f `py_w_mean' "   " %8.4f `py_w_sd' "   " %8.4f `py_b' "  " %7.4f `py_se'

display "DGP2: ONE-PERIOD BINARY OUTCOME (sample-average true RD = " %7.4f `true_pt_ate' ")"
display "  Source            Weight Mean  Risk diff. SE"
display "  ------            -----------  ---------- --"
display "  Stata msm        " %9.4f `stata_pt_w_mean' "    " %8.4f `stata_pt_ate' "  " %7.4f `stata_pt_se'
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
    assert `diff' < 0.0001
}
if _rc == 0 {
    display as result "  PASS C1: Stata vs R weight means agree (diff < 1e-4)"
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
    assert `diff' < 0.0001
}
if _rc == 0 {
    display as result "  PASS C2: Stata vs Python weight means agree (diff < 1e-4)"
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
    assert `diff' < 0.001
}
if _rc == 0 {
    display as result "  PASS C3: Stata vs R treatment effects agree (diff < 1e-3)"
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
    assert `diff' < 0.001
}
if _rc == 0 {
    display as result "  PASS C4: Stata vs Python treatment effects agree (diff < 1e-3)"
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
    assert `diff' < 0.001
}
if _rc == 0 {
    display as result "  PASS C5: R vs Python treatment effects agree (diff < 1e-3)"
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

* --- Test C7: non-collapsibility smoke check (DGP1) ---
* NOT a truth-recovery test. ln(0.70) is the CONDITIONAL data-generating
* coefficient (conditional on L, V, t). msm fits a MARGINAL structural model,
* whose exposure log-OR is non-collapsible with the conditional one: it is
* attenuated TOWARD THE NULL even with confounding fully removed by the weights
* (Pang, Kaufman & Platt 2016, Stat Methods Med Res 25(5):1925; the mean
* difference is collapsible but the log-OR is not). Asserting the marginal
* estimate ~= the conditional ln(0.70) is a category error -- it passed here
* only because the wide 0.20 tolerance happened to straddle the attenuation
* (observed marginal ~-0.17 vs conditional -0.357, gap 0.18). The correctly
* defined MARGINAL recovery lives in validation_msm_recovery.do (exogenous-L
* DGP + point-treatment scenario). This smoke check asserts only the
* qualitative non-collapsibility signature: same sign, strictly attenuated.
local ++test_count
capture {
    display "  C7: msm marginal log-OR = " %7.4f `stata_b' ///
        " ; conditional ln(0.70) = " %7.4f `true_logor'
    assert `stata_b' < 0                       // same (protective) sign
    assert `stata_b' > `true_logor'            // attenuated toward the null
}
if _rc == 0 {
    display as result "  PASS C7: msm marginal estimate is attenuated toward null vs conditional (non-collapsibility)"
    local ++pass_count
}
else {
    display as error "  FAIL C7: msm marginal estimate does not show the expected non-collapsibility signature"
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

* --- Test C9: msm vs teffects risk-difference agreement (DGP2) ---
local ++test_count
capture {
    local diff = abs(`stata_pt_ate' - `teffects_ate')
    display "  C9: Stata msm vs teffects RD diff = " %7.4f `diff'
    assert `diff' < 0.02
}
if _rc == 0 {
    display as result "  PASS C9: msm vs teffects agree (diff < 0.02)"
    local ++pass_count
}
else {
    display as error "  FAIL C9: msm vs teffects disagree"
    local ++fail_count
    local failed_tests "`failed_tests' C9"
}

* --- Test C10: Stata msm vs R vs Python risk-difference agreement (DGP2) ---
local ++test_count
capture {
    local diff_sr = abs(`stata_pt_ate' - `r_pt_ate')
    local diff_sp = abs(`stata_pt_ate' - `py_pt_ate')
    local diff_rp = abs(`r_pt_ate' - `py_pt_ate')
    display "  C10: Stata-R = " %6.4f `diff_sr' ", Stata-Py = " %6.4f `diff_sp' ", R-Py = " %6.4f `diff_rp'
    assert `diff_sr' < 0.001 & `diff_sp' < 0.001 & `diff_rp' < 0.001
}
if _rc == 0 {
    display as result "  PASS C10: msm/R/Python point-treatment risk differences agree"
    local ++pass_count
}
else {
    display as error "  FAIL C10: Point-treatment ATEs disagree"
    local ++fail_count
    local failed_tests "`failed_tests' C10"
}

* --- Test C11: all point-treatment estimates recover the sample-average RD ---
local ++test_count
capture {
    assert abs(`stata_pt_ate' - `true_pt_ate') < 0.04
    assert abs(`teffects_ate' - `true_pt_ate') < 0.04
    assert abs(`r_pt_ate' - `true_pt_ate') < 0.04
    assert abs(`py_pt_ate' - `true_pt_ate') < 0.04
}
if _rc == 0 {
    display as result "  PASS C11: all point-treatment estimates recover the sample-average RD"
    local ++pass_count
}
else {
    display as error "  FAIL C11: a point-treatment estimate misses the known RD"
    local ++fail_count
    local failed_tests "`failed_tests' C11"
}

* --- Test C12: row-level weight parity Stata vs R (DGP1) ---
* msm, R, and Python compute the SAME stabilized-weight formula (num=P(A|V),
* den=P(A|L,V), pooled logit) ON THE SAME at-risk (decision-risk) estimation
* sample, so agreement should be row-level tight, not merely correlated -- a
* correlation >0.95 survives a systematic scale error, and the prior gate hid a
* real divergence: before the crossval_r.R / crossval_python.py scripts were
* aligned to msm's at-risk restriction (audit A11) they fit the treatment models
* on ALL person-periods, so their weights drifted from msm's by up to ~2.4
* (compounding ~1%/period) yet still correlated >0.99. The merge must be
* COMPLETE: every (id,period) on both sides (audit Q09: "fail on merge
* omissions"). TOL set 50x above the observed cross-solver residual (max abs
* ~1.9e-6, max rel ~2.6e-7 between Stata logit, R glm, and Python statsmodels)
* and ~24000x below the pre-alignment divergence it must catch.
local TOL_ABS = 1e-4
local TOL_REL = 1e-4
local ++test_count
capture {
    preserve
        import delimited using "`results_dir'/stata_weights_dgp1.csv", clear varnames(1)
        local _n_stata = _N
        tempfile stata_w
        save `stata_w'

        import delimited using "`results_dir'/r_weights_dgp1.csv", clear varnames(1)
        local _n_r = _N
        merge 1:1 id period using `stata_w'
        * Merge omission => a dropped/duplicated row the correlation gate hid.
        assert _merge == 3
        assert _N == `_n_stata' & _N == `_n_r'
        drop _merge

        gen double _adiff = abs(stata_weight - r_manual_weight)
        gen double _rdiff = _adiff / max(abs(stata_weight), 1e-8)
        quietly summarize _adiff, meanonly
        local _maxabs = r(max)
        quietly summarize _rdiff, meanonly
        local _maxrel = r(max)
        display "  C12: Stata-R row-level max |diff| = " %9.6f `_maxabs' ///
            " ; max rel = " %9.6f `_maxrel' " (n=" `_n_stata' ")"
        assert `_maxabs' < `TOL_ABS'
        assert `_maxrel' < `TOL_REL'
    restore
}
if _rc == 0 {
    display as result "  PASS C12: Stata-R weights agree row-level (complete merge, max |diff| < `TOL_ABS')"
    local ++pass_count
}
else {
    display as error "  FAIL C12: Stata-R row-level weight parity failed (merge omission or diff too large)"
    local ++fail_count
    local failed_tests "`failed_tests' C12"
}

* --- Test C13: row-level weight parity Stata vs Python (DGP1) ---
local ++test_count
capture {
    preserve
        import delimited using "`results_dir'/stata_weights_dgp1.csv", clear varnames(1)
        local _n_stata = _N
        tempfile stata_w
        save `stata_w'

        import delimited using "`results_dir'/py_weights_dgp1.csv", clear varnames(1)
        local _n_py = _N
        merge 1:1 id period using `stata_w'
        assert _merge == 3
        assert _N == `_n_stata' & _N == `_n_py'
        drop _merge

        gen double _adiff = abs(stata_weight - py_weight)
        gen double _rdiff = _adiff / max(abs(stata_weight), 1e-8)
        quietly summarize _adiff, meanonly
        local _maxabs = r(max)
        quietly summarize _rdiff, meanonly
        local _maxrel = r(max)
        display "  C13: Stata-Python row-level max |diff| = " %9.6f `_maxabs' ///
            " ; max rel = " %9.6f `_maxrel' " (n=" `_n_stata' ")"
        assert `_maxabs' < `TOL_ABS'
        assert `_maxrel' < `TOL_REL'
    restore
}
if _rc == 0 {
    display as result "  PASS C13: Stata-Python weights agree row-level (complete merge, max |diff| < `TOL_ABS')"
    local ++pass_count
}
else {
    display as error "  FAIL C13: Stata-Python row-level weight parity failed (merge omission or diff too large)"
    local ++fail_count
    local failed_tests "`failed_tests' C13"
}

* --- Test C14: complete row-level PS and weight parity on DGP2 ---
local ++test_count
capture {
    preserve
        import delimited using "`results_dir'/stata_weights_dgp2.csv", clear varnames(1)
        isid id
        local _n_stata2 = _N
        tempfile stata_pt
        save `stata_pt'

        import delimited using "`results_dir'/r_weights_dgp2.csv", clear varnames(1)
        isid id
        local _n_r2 = _N
        tempfile r_pt
        save `r_pt'

        import delimited using "`results_dir'/py_weights_dgp2.csv", clear varnames(1)
        isid id
        local _n_py2 = _N
        merge 1:1 id using `r_pt'
        assert _merge == 3
        drop _merge
        merge 1:1 id using `stata_pt'
        assert _merge == 3
        drop _merge
        assert _N == `_n_stata2' & _N == `_n_r2' & _N == `_n_py2'

        foreach pair in ps_r ps_py sw_r sw_py {
            gen double diff_`pair' = .
        }
        replace diff_ps_r  = abs(ps_stata - r_ps)
        replace diff_ps_py = abs(ps_stata - py_ps)
        replace diff_sw_r  = abs(sw_stata - r_sw)
        replace diff_sw_py = abs(sw_stata - py_sw)
        foreach d in ps_r ps_py sw_r sw_py {
            quietly summarize diff_`d', meanonly
            local max_`d' = r(max)
            assert r(max) < 0.0001
        }
        display "  C14 max |diff|: PS R=" %9.6f `max_ps_r' ///
            " Py=" %9.6f `max_ps_py' " ; SW R=" %9.6f `max_sw_r' ///
            " Py=" %9.6f `max_sw_py' " (n=" _N ")"
    restore
}
if _rc == 0 {
    display as result "  PASS C14: DGP2 PS/weights agree row-level after complete merges"
    local ++pass_count
}
else {
    display as error "  FAIL C14: DGP2 merge completeness or PS/weight parity failed"
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

* --- Test C16: msm interval is a valid final-stage interval (DGP1) ---
* Reclassified smoke check. The prior version asserted the 95% CI COVERS the
* conditional ln(0.70); that passed vacuously because the final-stage CI is wide
* (SE ~0.11) and straddles zero, the marginal estimate, AND the conditional
* value at once -- a wide interval covers everything, so coverage of the
* conditional target proves nothing, and the target is the wrong estimand
* anyway (see C7 / Pang 2016 non-collapsibility). Here we assert only that the
* interval is well-formed and the point estimate sits inside it, using z (GLM
* inference). Coverage of the MARGINAL estimand is validated in
* validation_msm_recovery.do, not against the conditional coefficient here.
local ++test_count
capture {
    local _zc = invnormal(0.975)
    local ci_lo = `stata_b' - `_zc' * `stata_se'
    local ci_hi = `stata_b' + `_zc' * `stata_se'
    display "  C16: msm 95% CI = [" %7.4f `ci_lo' ", " %7.4f `ci_hi' "]"
    assert !missing(`ci_lo', `ci_hi', `stata_se')
    assert `stata_se' > 0
    assert `ci_lo' < `ci_hi'
    assert `ci_lo' < `stata_b' & `stata_b' < `ci_hi'
    * Document (not assert) that the conditional target need not be covered.
    local _covers_cond = (`ci_lo' < `true_logor' & `true_logor' < `ci_hi')
    display "        (conditional ln(0.70) inside CI: `_covers_cond' -- not an oracle; see C7)"
}
if _rc == 0 {
    display as result "  PASS C16: msm final-stage interval is well-formed and contains its estimate"
    local ++pass_count
}
else {
    display as error "  FAIL C16: msm interval is malformed"
    local ++fail_count
    local failed_tests "`failed_tests' C16"
}

* --- Test C17: the independent R ipw::ipwtm backend really ran ---
* ipwtm and msm use different longitudinal specification conventions here, so
* this is an execution/finite-output guard rather than a false equality claim.
local ++test_count
capture {
    assert !missing(`r_ipwtm_b', `r_ipwtm_se', `r_ipwtm_w_mean')
    assert `r_ipwtm_se' > 0
    assert `r_ipwtm_w_mean' > 0
}
if _rc == 0 {
    display as result "  PASS C17: ipw::ipwtm produced finite weights and inference"
    local ++pass_count
}
else {
    display as error "  FAIL C17: ipw::ipwtm was missing or non-finite"
    local ++fail_count
    local failed_tests "`failed_tests' C17"
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
do "`qa_dir'/_record_qa_result.do" crossval_msm ///
    `test_count' `pass_count' `fail_count' 0
display "RESULT: crossval_msm tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0 status=`cv_status'"

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

    replace source = "stata_msm" in 4
    replace dgp = "DGP2" in 4
    replace weight_mean = `stata_pt_w_mean' in 4
    replace coef = `stata_pt_ate' in 4
    replace se = `stata_pt_se' in 4
    replace metric = "RD" in 4

    replace source = "teffects" in 5
    replace dgp = "DGP2" in 5
    replace coef = `teffects_ate' in 5
    replace se = `teffects_se' in 5
    replace metric = "RD" in 5

    replace source = "R_iptw" in 6
    replace dgp = "DGP2" in 6
    replace weight_mean = `r_pt_w_mean' in 6
    replace coef = `r_pt_ate' in 6
    replace se = `r_pt_se' in 6
    replace metric = "RD" in 6

    replace source = "Python_iptw" in 7
    replace dgp = "DGP2" in 7
    replace weight_mean = `py_pt_w_mean' in 7
    replace coef = `py_pt_ate' in 7
    replace se = `py_pt_se' in 7
    replace metric = "RD" in 7

    replace source = "true_cf" in 8
    replace dgp = "DGP3" in 8
    replace coef = `pooled_true_logor' in 8
    replace metric = "log-OR" in 8

    export delimited using "`results_dir'/crossval_summary.csv", replace
    display "Saved: `results_dir'/crossval_summary.csv"
restore

log close crossval

if `keep_outputs' {
    display as text "Retained staging directory: " as result "`work_root'"
}
else {
    if "`c(os)'" == "Windows" {
        capture shell rmdir /s /q "`work_root'"
    }
    else {
        capture shell rm -rf "`work_root'"
    }
}

if `fail_count' > 0 {
    exit 1
}
