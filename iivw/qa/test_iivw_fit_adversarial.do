clear all
version 16.0
set varabbrev off

* test_iivw_fit_adversarial.do - adversarial coverage for iivw_fit
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_fit_adversarial.do
*   stata-mp -b do test_iivw_fit_adversarial.do 5

args run_only
* Q5: a bad selector must be an error, not a silent zero-test pass.
* `do this.do 999' used to execute nothing and print "ALL TESTS PASSED".
do "`c(pwd)'/_iivw_qa_common.do"
iivw_qa_selector "`run_only'"
local run_only = `r(run_only)'

**# Setup

local qa_dir  "`c(pwd)'"
* Sysdir sandbox + path resolution (Q3/Q8): the sandbox keeps this suite's
* net install out of the USER's real ado tree even when run standalone, and
* the "/qa" suffix is stripped by length, not by first-occurrence subinstr()
* (which mangles any path whose ancestors contain "qa").
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"
local repo_dir "`r(repo_dir)'"

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _adv_setup_panel
program define _adv_setup_panel, rclass
    version 16.0
    syntax [, NIDS(integer 48) VISITS(integer 5) SEED(integer 20260506) ///
        WTYPE(string) COARSETIME]

    if "`wtype'" == "" local wtype "iivw"

    clear
    set seed `seed'
    set obs `=`nids' * `visits''

    gen long id = ceil(_n / `visits')
    bysort id: gen int visit_n = _n

    if "`coarsetime'" != "" {
        gen double months = visit_n - 1
    }
    else {
        gen double months = (visit_n - 1) * 2 + runiform() * 0.05
        replace months = 0 if visit_n == 1
    }

    gen double severity = 2 + 0.2 * months + sin(id / 5) + rnormal(0, 0.35)
    bysort id (months): gen double sev_bl = severity[1]
    gen byte treated = mod(id, 2)
    bysort id (months): replace treated = treated[1]
    gen long site = mod(id, 6) + 1
    gen byte arm = mod(id, 3)
    label define adv_arm 0 "Placebo" 1 "Low dose" 2 "High dose", replace
    label values arm adv_arm

    gen double y = 10 - 0.35 * severity - 0.45 * treated + ///
        0.04 * months + 0.12 * arm + rnormal(0, 0.4)
    gen double linp = -1.1 + 0.25 * severity - 0.3 * treated + 0.05 * months
    gen byte event = (runiform() < invlogit(linp))
    gen int count_y = max(0, round(exp(0.2 + 0.08 * severity + 0.02 * months + rnormal(0, 0.2))))

    label variable months "Months since baseline"
    label variable severity "Visit severity"
    label variable sev_bl "Baseline severity"
    label variable treated "Treatment"
    label variable site "Clinic site"
    label variable arm "Treatment arm"
    label variable y "Continuous outcome"
    label variable event "Binary event"
    label variable count_y "Count outcome"

    if "`wtype'" != "none" {
        if "`wtype'" == "iivw" {
            iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity event) nolog
        }
        else if "`wtype'" == "fiptiw" {
            iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity event) ///
                treat(treated) treat_cov(sev_bl) wtype(fiptiw) nolog
        }
        else if "`wtype'" == "iptw" {
            iivw_weight, id(id) time(months) ///
                treat(treated) treat_cov(sev_bl) wtype(iptw) nolog
        }
        else {
            display as error "unknown _adv_setup_panel wtype(): `wtype'"
            error 198
        }
    }

    return scalar N = _N
end

**# Adversarial tests

**## 1. GEE binomial/logit with cluster override
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    capture noisily {
        _adv_setup_panel, wtype(fiptiw)
        iivw_fit event treated sev_bl, model(gee) family(binomial) ///
            link(logit) timespec(linear) cluster(site) nolog

        assert e(N) > 0
        assert e(converged) == 1
        assert "`e(iivw_model)'" == "gee"
        assert "`e(iivw_weighttype)'" == "fiptiw"
        assert "`e(iivw_cluster)'" == "site"
        assert "`e(clustvar)'" == "site"
        assert e(N_clust) <= 6
    }
    if _rc == 0 {
        display as result "  PASS: A1 - GEE binomial/logit with cluster override"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A1 - GEE binomial/logit cluster (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A1"
    }
}

**## 2. Mixed model with timespec(none)
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    capture noisily {
        _adv_setup_panel, wtype(fiptiw)
        iivw_fit y treated sev_bl, model(mixed) experimentalmixed timespec(none) ///
            cluster(site) nolog

        assert e(N) > 0
        assert "`e(iivw_model)'" == "mixed"
        assert "`e(iivw_timespec)'" == "none"
        assert "`e(iivw_cluster)'" == "site"
        assert "`e(iivw_display_vars)'" == "treated sev_bl"
    }
    if _rc == 0 {
        display as result "  PASS: A2 - Mixed model with timespec(none)"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A2 - mixed timespec(none) (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A2"
    }
}

**## 3. All supported timespec() paths
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    capture noisily {
        foreach ts in linear quadratic cubic "ns(3)" none {
            _adv_setup_panel, seed(20260513)
            iivw_fit y severity, model(gee) timespec(`ts') replace nolog
            assert "`e(iivw_timespec)'" == "`ts'"

            if "`ts'" == "linear" {
                assert "`e(iivw_display_vars)'" == "severity months"
            }
            else if "`ts'" == "quadratic" {
                confirm variable _iivw_time_sq
                assert "`e(iivw_display_vars)'" == "severity months _iivw_time_sq"
            }
            else if "`ts'" == "cubic" {
                confirm variable _iivw_time_sq
                confirm variable _iivw_time_cu
                assert "`e(iivw_display_vars)'" == ///
                    "severity months _iivw_time_sq _iivw_time_cu"
            }
            else if "`ts'" == "ns(3)" {
                confirm variable _iivw_tns1
                confirm variable _iivw_tns2
                confirm variable _iivw_tns3
                assert "`e(iivw_display_vars)'" == ///
                    "severity _iivw_tns1 _iivw_tns2 _iivw_tns3"
            }
            else if "`ts'" == "none" {
                assert "`e(iivw_display_vars)'" == "severity"
            }
        }
    }
    if _rc == 0 {
        display as result "  PASS: A3 - All supported timespec() paths"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A3 - timespec paths (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A3"
    }
}

**## 4. Natural spline no-variation guard
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    capture noisily {
        _adv_setup_panel, seed(20260514)
        capture iivw_fit y severity if visit_n == 1, timespec(ns(3)) nolog
        assert _rc == 198
        capture confirm variable _iivw_tns1
        assert _rc != 0
        local fitted : char _dta[_iivw_fitted]
        assert "`fitted'" == ""
    }
    if _rc == 0 {
        display as result "  PASS: A4 - ns() rejects no time variation"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A4 - ns() no-variation guard (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A4"
    }
}

**## 5. Natural spline tied-knot guard
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    capture noisily {
        _adv_setup_panel, seed(20260515) coarsetime
        capture iivw_fit y severity, timespec(ns(8)) nolog
        assert _rc == 198
        capture confirm variable _iivw_tns1
        assert _rc != 0
        local fitted : char _dta[_iivw_fitted]
        assert "`fitted'" == ""
    }
    if _rc == 0 {
        display as result "  PASS: A5 - ns() rejects tied knots"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A5 - ns() tied-knot guard (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A5"
    }
}

**## 6. ns(0) is rejected as invalid degrees of freedom
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    capture noisily {
        _adv_setup_panel, seed(20260516)
        capture iivw_fit y severity, timespec(ns(0)) nolog
        assert _rc == 198
        capture confirm variable _iivw_tns1
        assert _rc != 0
        local fitted : char _dta[_iivw_fitted]
        assert "`fitted'" == ""
    }
    if _rc == 0 {
        display as result "  PASS: A6 - ns(0) rejected"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A6 - ns(0) validation (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A6"
    }
}

**## 7. Categorical basecat plus interaction path
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
    capture noisily {
        _adv_setup_panel, seed(20260517) wtype(fiptiw)
        iivw_fit y arm severity, categorical(arm) basecat(2) ///
            interaction(arm) timespec(quadratic) nolog

        confirm variable _iivw_cat_placebo
        confirm variable _iivw_cat_low_dose
        confirm variable _iivw_ix_placebo_time
        confirm variable _iivw_ix_placebo_tsq
        confirm variable _iivw_ix_low_dose_time
        confirm variable _iivw_ix_low_dose_tsq

        assert _iivw_cat_placebo == (arm == 0) if !missing(_iivw_cat_placebo)
        assert _iivw_cat_low_dose == (arm == 1) if !missing(_iivw_cat_low_dose)
        assert "`e(iivw_categorical)'" == "arm"
        assert "`e(iivw_interaction)'" == "arm"
        local base : char _dta[_iivw_basecat]
        assert "`base'" == "2"
    }
    if _rc == 0 {
        display as result "  PASS: A7 - categorical/basecat interaction path"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A7 - categorical/basecat interaction (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A7"
    }
}

**## 8. Cross-variable categorical name collisions fall back safely
local ++test_count
if `run_only' == 0 | `run_only' == 8 {
    capture noisily {
        _adv_setup_panel, seed(20260518)
        gen byte grp1 = mod(id, 2)
        gen byte grp2 = mod(floor(id / 2), 2)
        label define dup01 0 "Control" 1 "Active", replace
        label values grp1 dup01
        label values grp2 dup01

        iivw_fit y grp1 grp2 severity, categorical(grp1 grp2) nolog

        confirm variable _iivw_cat_active
        confirm variable _iivw_cat_grp2_1
        local cats "`e(iivw_cat_vars)'"
        assert strpos("`cats'", "_iivw_cat_active") > 0
        assert strpos("`cats'", "_iivw_cat_grp2_1") > 0
    }
    if _rc == 0 {
        display as result "  PASS: A8 - categorical name collisions fallback"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A8 - categorical name collisions (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A8"
    }
}

**## 9. replace controls generated time-variable collisions
local ++test_count
if `run_only' == 0 | `run_only' == 9 {
    capture noisily {
        * ---------------------------------------------------------------
        * UPDATED FOR 3.0.0 -- this test used to assert the defect.
        *
        * It created an UNOWNED `_iivw_time_sq = 999', called iivw_fit with
        * `replace', and asserted `r(max) < 999' -- i.e. it asserted that the
        * user's column had been DESTROYED. That is exactly blocker #10: the old
        * rule inferred ownership from the name, so any column sitting under the
        * prefix was fair game.
        *
        * The contract is now: `replace' overwrites a column iivw can PROVE it
        * created, and refuses anything else without mutating it. So the same
        * setup must now be refused (110) with the value intact, and a genuinely
        * owned column must still be replaceable.
        * ---------------------------------------------------------------
        _adv_setup_panel, seed(20260519)
        gen double _iivw_time_sq = 999

        * no replace: blocked, as before
        capture iivw_fit y severity, timespec(quadratic) nolog
        assert _rc == 110

        * WITH replace: still blocked, because we did not create this column
        capture iivw_fit y severity, timespec(quadratic) replace nolog
        assert _rc == 110
        quietly summarize _iivw_time_sq
        assert r(min) == 999 & r(max) == 999

        * Drop the impostor. Now iivw_fit creates the column itself, stamps it,
        * and a rerun with replace overwrites its OWN output without complaint.
        drop _iivw_time_sq
        iivw_fit y severity, timespec(quadratic) nolog
        confirm variable _iivw_time_sq
        assert "`: char _iivw_time_sq[_iivw_owner]'" == "iivw|_iivw_|design|2"

        iivw_fit y severity, timespec(quadratic) replace nolog
        assert "`e(iivw_timespec)'" == "quadratic"
        confirm variable _iivw_time_sq
    }
    if _rc == 0 {
        display as result "  PASS: A9 - replace overwrites only iivw-owned time vars"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A9 - replace collision behavior (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A9"
    }
}

**## 10. Bootstrap honors cluster override metadata
local ++test_count
if `run_only' == 0 | `run_only' == 10 {
    capture noisily {
        _adv_setup_panel, nids(36) visits(4) seed(20260520)
        set seed 720
        iivw_fit y severity, model(gee) timespec(linear) ///
            cluster(site) bootstrap(6) nolog

        assert e(N_reps) == 6
        assert "`e(vce)'" == "bootstrap"
        assert "`e(iivw_cluster)'" == "site"
    }
    if _rc == 0 {
        display as result "  PASS: A10 - bootstrap with cluster override"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A10 - bootstrap cluster override (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A10"
    }
}

**## 11. e(sample) respects if/in and missing covariates
local ++test_count
if `run_only' == 0 | `run_only' == 11 {
    capture noisily {
        _adv_setup_panel, seed(20260521)
        gen long rowno = _n
        replace severity = . if id <= 3
        replace y = . if id == 4

        * severity is a visit covariate, so blanking it after weighting makes
        * the stored weights describe data that no longer exists -- from 2.0.0
        * iivw_fit refuses that (rc 459). Re-weight on the mutated data, which
        * is what the analyst would have to do anyway. The exclusions this test
        * is actually about (if/in and missing covariates) are unaffected.
        * severity was blanked for id<=3 above, so some rows can carry no
        * weight. From 3.0.0 that is an error unless the analyst says they mean
        * it -- which, for a test whose whole subject is the exclusion of
        * unweighted rows, they do. allowmissingweights is the acknowledgment.
        quietly iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(severity event) replace allowmissingweights nolog

        quietly count if id > 5 & rowno <= 220 & ///
            !missing(y, severity, _iivw_weight, months, id)
        local expected = r(N)

        iivw_fit y severity if id > 5 in 1/220, timespec(linear) nolog
        assert e(N) == `expected'
        quietly count if e(sample)
        assert r(N) == e(N)
        quietly count if e(sample) & ///
            (id <= 5 | rowno > 220 | missing(y, severity))
        assert r(N) == 0
    }
    if _rc == 0 {
        display as result "  PASS: A11 - e(sample) and sample exclusions"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A11 - e(sample) exclusions (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A11"
    }
}

**## 12. Post-estimation metadata is complete for generated terms
local ++test_count
if `run_only' == 0 | `run_only' == 12 {
    capture noisily {
        _adv_setup_panel, seed(20260522) wtype(fiptiw)
        iivw_fit y treated arm sev_bl, categorical(arm) interaction(treated arm) ///
            timespec(ns(3)) cluster(site) nolog

        assert "`e(iivw_cmd)'" == "iivw_fit"
        assert "`e(iivw_weighttype)'" == "fiptiw"
        assert "`e(iivw_timespec)'" == "ns(3)"
        assert "`e(iivw_cluster)'" == "site"
        assert "`e(iivw_weight_var)'" == "_iivw_weight"
        assert "`e(iivw_categorical)'" == "arm"
        assert "`e(iivw_interaction)'" == "treated arm"
        assert strpos("`e(iivw_display_vars)'", "_iivw_tns3") > 0
        assert strpos("`e(iivw_ix_vars)'", "_iivw_ix_treated_tns3") > 0
        assert strpos("`e(iivw_ix_vars)'", "_iivw_ix_low_dose_tns3") > 0
    }
    if _rc == 0 {
        display as result "  PASS: A12 - post-estimation metadata complete"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A12 - post-estimation metadata (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A12"
    }
}

**## 13. e() and fit metadata preserved after failed-validation refit (v1.0.6+)
local ++test_count
if `run_only' == 0 | `run_only' == 13 {
    capture noisily {
        _adv_setup_panel, seed(20260523)
        iivw_fit y severity, timespec(linear) nolog
        scalar b_before = _b[severity]
        local cmd_before "`e(iivw_cmd)'"
        local model_before "`e(iivw_model)'"

        capture iivw_fit y severity, timespec(badvalue) nolog
        assert _rc == 198
        assert "`e(iivw_cmd)'" == "`cmd_before'"
        assert "`e(iivw_model)'" == "`model_before'"
        assert reldif(_b[severity], b_before) < 1e-12

        * v1.0.6+: validation-stage failures preserve fit metadata too
        assert "`: char _dta[_iivw_fitted]'"   == "1"
        assert "`: char _dta[_iivw_timespec]'" == "linear"
    }
    if _rc == 0 {
        display as result "  PASS: A13 - e() and fit metadata preserved after failed validation"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A13 - e() after failed refit (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A13"
    }
}

**## 14. varabbrev restored on success and error
local ++test_count
if `run_only' == 0 | `run_only' == 14 {
    capture noisily {
        _adv_setup_panel, seed(20260524)

        set varabbrev on
        iivw_fit y severity, timespec(linear) nolog
        assert "`c(varabbrev)'" == "on"

        capture iivw_fit y severity, family(badfamily) nolog
        assert _rc != 0
        assert "`c(varabbrev)'" == "on"

        set varabbrev off
        capture iivw_fit y severity, link(badlink) nolog
        assert _rc != 0
        assert "`c(varabbrev)'" == "off"
    }
    if _rc == 0 {
        display as result "  PASS: A14 - varabbrev restored on success/error"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A14 - varabbrev restore (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A14"
    }
}

**## 15. no-weight and stale-weight guards
local ++test_count
if `run_only' == 0 | `run_only' == 15 {
    capture noisily {
        _adv_setup_panel, seed(20260525) wtype(none)
        capture iivw_fit y severity, timespec(linear) nolog
        assert _rc == 198

        _adv_setup_panel, seed(20260525)
        drop _iivw_weight
        capture iivw_fit y severity, timespec(linear) nolog
        assert _rc == 111
        local fitted : char _dta[_iivw_fitted]
        assert "`fitted'" == ""
    }
    if _rc == 0 {
        display as result "  PASS: A15 - no-weight and stale-weight guards"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A15 - no-weight guards (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A15"
    }
}

**## 16. Invalid family/link errors do not mark dataset as fitted
local ++test_count
if `run_only' == 0 | `run_only' == 16 {
    capture noisily {
        _adv_setup_panel, seed(20260526)
        capture iivw_fit y severity, family(badfamily) nolog
        assert _rc != 0
        local fitted1 : char _dta[_iivw_fitted]
        assert "`fitted1'" == ""

        _adv_setup_panel, seed(20260527)
        capture iivw_fit y severity, link(badlink) nolog
        assert _rc != 0
        local fitted2 : char _dta[_iivw_fitted]
        assert "`fitted2'" == ""

        _adv_setup_panel, seed(20260530)
        capture iivw_fit y severity, bootstrap(-1) nolog
        assert _rc == 198
        local fitted3 : char _dta[_iivw_fitted]
        assert "`fitted3'" == ""
    }
    if _rc == 0 {
        display as result "  PASS: A16 - invalid family/link leave no fitted metadata"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A16 - family/link error metadata (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A16"
    }
}

**## 17. no predictors with timespec(none) remains valid
local ++test_count
if `run_only' == 0 | `run_only' == 17 {
    capture noisily {
        _adv_setup_panel, seed(20260528)
        iivw_fit y, model(gee) timespec(none) nolog
        assert e(N) > 0
        assert "`e(iivw_display_vars)'" == ""
        quietly count if e(sample)
        assert r(N) == e(N)
    }
    if _rc == 0 {
        display as result "  PASS: A17 - intercept-only weighted model"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A17 - intercept-only model (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A17"
    }
}

**## 18. bootstrap with mixed where supported
local ++test_count
if `run_only' == 0 | `run_only' == 18 {
    capture noisily {
        _adv_setup_panel, nids(30) visits(4) seed(20260529)
        set seed 729
        iivw_fit y severity, model(mixed) experimentalmixed timespec(linear) bootstrap(5) nolog

        assert e(N_reps) == 5
        assert "`e(vce)'" == "bootstrap"
        assert "`e(iivw_model)'" == "mixed"
    }
    if _rc == 0 {
        display as result "  PASS: A18 - mixed bootstrap path"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A18 - mixed bootstrap path (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A18"
    }
}

**## 19. unlabeled negative categorical levels get valid dummy names
local ++test_count
if `run_only' == 0 | `run_only' == 19 {
    capture noisily {
        _adv_setup_panel, nids(36) visits(4) seed(20260611)
        gen int dose = mod(id, 3) - 1

        iivw_fit y dose, categorical(dose) basecat(0) ///
            timespec(none) nolog

        confirm variable _iivw_cat_dose_m1
        confirm variable _iivw_cat_dose_1
        assert strpos("`e(iivw_cat_vars)'", "_iivw_cat_dose_m1") > 0
        assert strpos("`e(iivw_cat_vars)'", "_iivw_cat_dose_1") > 0
    }
    if _rc == 0 {
        display as result "  PASS: A19 - negative categorical levels generate valid names"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A19 - negative categorical names (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' A19"
    }
}

**# Summary

iivw_qa_summary, name(test_iivw_fit_adversarial) tests(`test_count') pass(`pass_count') ///
    fail(`fail_count') runonly(`run_only') failedtests("`failed_tests'")


clear
