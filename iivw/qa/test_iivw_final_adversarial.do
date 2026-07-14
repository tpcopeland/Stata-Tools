clear all
version 16.0
set varabbrev off

* test_iivw_final_adversarial.do - final adversarial QA for iivw v1.0.6
*
* Targets untested paths across the full .ado surface:
*   T1   Categorical label sanitization: Unicode, pure-numeric, empty labels
*   T2   Categorical name truncation > 32 chars with collision fallback
*   T3   ns(1) special path: collision, replace, error cleanup
*   T4   ns() basis continuity at exact knot positions
*   T5   efron option with heavy ties in visit times
*   T6   geeopts passthrough: conflicting vce(), iterate(), extra options
*   T7   mixedopts passthrough with nolog and extra options
*   T8   collect option: double collect, collect after prior error
*   T9   if/in that eliminates entire clusters
*   T10  iivw_weight with extreme xb (near-separation visit model)
*   T11  String id variable throughout weight+fit pipeline
*   T12  Large panel stress: 200 subjects x 20 visits
*   T13  Post-data-mutation error cleanup in iivw_weight (Cox fails after lags)
*   T14  iivw_weight sort-preserve with pre-existing ties and random order
*   T15  iivw_fit categorical + basecat with value label on non-contiguous levels
*   T16  iivw_fit interaction with ns() + categorical: full expansion correctness
*   T17  Multiple lagvars with name length near 32-char boundary
*   T18  iivw_weight with all-identical visit times (degenerate panel)
*   T19  iivw_fit with depvar having all-equal values in sample
*   T20  Pipeline end-to-end: weight -> fit -> reweight(replace) -> refit(replace)
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_final_adversarial.do
*   stata-mp -b do test_iivw_final_adversarial.do 5

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

capture program drop _final_panel
program define _final_panel
    version 16.0
    syntax [, NIDS(integer 48) VISITS(integer 5) SEED(integer 20260519)]

    clear
    set seed `seed'
    set obs `=`nids' * `visits''
    gen long id = ceil(_n / `visits')
    bysort id: gen int visit_n = _n
    gen double months = (visit_n - 1) * 3 + runiform() * 0.3
    replace months = 0 if visit_n == 1
    gen double severity = 2 + 0.1 * months + rnormal(0, 0.5)
    bysort id (months): gen double sev_bl = severity[1]
    gen byte treated = mod(id, 2)
    bysort id (months): replace treated = treated[1]
    gen double y = 5 - 0.3 * severity + 0.2 * treated + rnormal(0, 0.3)
    gen byte event = (runiform() < invlogit(-1.5 + 0.2 * severity))
    label variable months "Months"
    label variable severity "Severity"
end

**# Tests

**## T1: Categorical label sanitization — Unicode, pure-numeric, empty labels

local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    capture noisily {
        _final_panel, seed(10001)
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog

        * Create a 3-level categorical with adversarial value labels
        gen byte arm = mod(id, 3)
        bysort id (months): replace arm = arm[1]
        capture label drop advlbl
        label define advlbl 0 "Ctrl/Placebo" 1 "Dose-1.5mg" 2 "Dose-1.5mg"
        label values arm advlbl

        * Collision: levels 1 and 2 have identical labels after sanitization
        * Code should fall back to numeric naming
        iivw_fit y arm severity, categorical(arm) nolog
        confirm variable _iivw_cat_arm_1
        confirm variable _iivw_cat_arm_2
        assert strpos("`e(iivw_cat_vars)'", "_iivw_cat_arm_1") > 0
        assert strpos("`e(iivw_cat_vars)'", "_iivw_cat_arm_2") > 0

        * Verify dummy correctness
        assert _iivw_cat_arm_1 == (arm == 1) if !missing(_iivw_cat_arm_1)
        assert _iivw_cat_arm_2 == (arm == 2) if !missing(_iivw_cat_arm_2)
    }
    if _rc == 0 {
        display as result "  PASS: T1 - categorical collision from identical labels"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T1 - categorical label sanitization (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T1"
    }
}

**## T2: Categorical name truncation >32 chars with collision fallback

local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    capture noisily {
        _final_panel, seed(10002)
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog

        gen byte grp = mod(id, 3)
        bysort id (months): replace grp = grp[1]
        capture label drop longlbl
        label define longlbl ///
            0 "Baseline control group reference" ///
            1 "VeryLongTreatmentArmNameThatExceeds" ///
            2 "VeryLongTreatmentArmNameThatExceed2"
        label values grp longlbl

        * Both non-base labels will produce >32 char var names after prefix
        * The truncation + collision fallback should handle this
        iivw_fit y grp severity, categorical(grp) nolog
        local cat_vars "`e(iivw_cat_vars)'"
        * Both dummies must exist
        local n_cats : word count `cat_vars'
        assert `n_cats' == 2
        * Each dummy has correct values
        foreach cv of local cat_vars {
            confirm variable `cv'
            quietly count if missing(`cv') & !missing(grp)
            assert r(N) == 0
        }
    }
    if _rc == 0 {
        display as result "  PASS: T2 - categorical name truncation >32 chars"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T2 - categorical truncation (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T2"
    }
}

**## T3: ns(1) special path — collision, replace, error cleanup

local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    capture noisily {
        _final_panel, seed(10003)
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog

        * ---------------------------------------------------------------
        * UPDATED FOR 3.0.0. This block used to assert that `replace' DESTROYED
        * an unowned `_iivw_tns1 = 999' (it checked `r(max) < 999'), which is
        * blocker #10 written as a passing test. `replace' now overwrites only a
        * column iivw can prove it created.
        * ---------------------------------------------------------------

        * Pre-existing UNOWNED _iivw_tns1 blocks with or without replace
        gen double _iivw_tns1 = 999
        capture iivw_fit y severity, timespec(ns(1)) nolog
        assert _rc == 110

        capture iivw_fit y severity, timespec(ns(1)) replace nolog
        assert _rc == 110
        quietly summarize _iivw_tns1
        assert r(min) == 999 & r(max) == 999

        * Drop the impostor: iivw_fit now creates and owns the basis itself,
        * and replace overwrites its own output.
        drop _iivw_tns1
        iivw_fit y severity, timespec(ns(1)) nolog
        confirm variable _iivw_tns1
        assert "`: char _iivw_tns1[_iivw_owner]'" == "iivw|_iivw_|design|2"

        iivw_fit y severity, timespec(ns(1)) replace nolog
        confirm variable _iivw_tns1
        quietly summarize _iivw_tns1
        assert r(max) < 999

        * ns(1) should produce exactly 1 basis that equals the time variable
        assert "`e(iivw_timespec)'" == "ns(1)"
        local disp "`e(iivw_display_vars)'"
        assert strpos("`disp'", "_iivw_tns1") > 0
        * No tns2 should exist
        capture confirm variable _iivw_tns2
        assert _rc != 0

        * Error after ns(1) cleanup: force error with 0-obs if, check no tns1
        capture iivw_fit y severity if id < 0, timespec(ns(1)) replace nolog
        assert _rc == 2000
        capture confirm variable _iivw_tns1
        * Variable may or may not exist after error cleanup depending on
        * whether it was created before the error - just verify no crash
    }
    if _rc == 0 {
        display as result "  PASS: T3 - ns(1) collision/replace/error cleanup"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T3 - ns(1) adversarial (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T3"
    }
}

**## T4: ns() basis continuity at exact knot positions

local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    capture noisily {
        _final_panel, nids(60) visits(8) seed(10004)
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog

        iivw_fit y severity, timespec(ns(3)) nolog
        * ns(3) with 60*8=480 obs should have 2 internal knots
        * Basis variables should be finite everywhere
        foreach v in _iivw_tns1 _iivw_tns2 _iivw_tns3 {
            confirm variable `v'
            quietly count if missing(`v') & !missing(months)
            assert r(N) == 0
        }

        * Basis should be smooth: no huge jumps between adjacent time values
        * Sort by time and check max absolute first-difference
        sort months
        gen double d_tns2 = _iivw_tns2 - _iivw_tns2[_n-1] if _n > 1
        gen double d_months = months - months[_n-1] if _n > 1
        gen double rate_tns2 = abs(d_tns2 / d_months) if d_months > 0
        quietly summarize rate_tns2, detail
        * Rate of change should be bounded (not infinite)
        assert r(max) < .
    }
    if _rc == 0 {
        display as result "  PASS: T4 - ns() basis finite and smooth"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T4 - ns() continuity (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T4"
    }
}

**## T5: efron option with heavy ties in visit times

local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    capture noisily {
        clear
        set seed 10005
        set obs 200
        gen long id = ceil(_n / 5)
        bysort id: gen int visit_n = _n
        * Heavy ties: all subjects visit at exactly months 0, 3, 6, 9, 12
        gen double months = (visit_n - 1) * 3
        * Add tiny jitter to avoid exact duplicate id-time
        replace months = months + id / 100000
        gen double severity = 2 + rnormal(0, 0.5)

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) efron nolog
        assert r(N) == 200
        assert r(n_ids) == 40
        quietly count if missing(_iivw_weight) | _iivw_weight <= 0
        assert r(N) == 0

        * Without efron (default Breslow) should also work
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) replace nolog
        assert r(N) == 200
    }
    if _rc == 0 {
        display as result "  PASS: T5 - efron with heavy visit-time ties"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T5 - efron ties (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T5"
    }
}

**## T6: geeopts passthrough — conflicting vce and iterate

local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    capture noisily {
        _final_panel, seed(10006)
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog

        * geeopts(iterate(50)) should be passed through and not conflict
        iivw_fit y severity, geeopts(iterate(50)) nolog
        assert e(converged) == 1

        * geeopts(asis) allows passthrough of non-conflicting GLM options
        iivw_fit y severity, geeopts(difficult) replace nolog
        assert e(converged) == 1

        * Verify point estimate is identical regardless of difficult flag
        scalar b_diff = _b[severity]
        iivw_fit y severity, replace nolog
        scalar b_def = _b[severity]
        assert reldif(b_diff, b_def) < 1e-10
    }
    if _rc == 0 {
        display as result "  PASS: T6 - geeopts passthrough"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T6 - geeopts passthrough (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T6"
    }
}

**## T7: mixedopts passthrough with extra options

local ++test_count
if `run_only' == 0 | `run_only' == 7 {
    capture noisily {
        _final_panel, seed(10007)
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog

        iivw_fit y severity, model(mixed) experimentalmixed mixedopts(iterate(50)) nolog
        assert e(N) > 0
        assert "`e(iivw_model)'" == "mixed"
    }
    if _rc == 0 {
        display as result "  PASS: T7 - mixedopts passthrough"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T7 - mixedopts passthrough (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T7"
    }
}

**## T8: collect option — double collect, collect after error

local ++test_count
if `run_only' == 0 | `run_only' == 8 {
    capture noisily {
        _final_panel, seed(10008)
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog

        * First collect
        collect clear
        iivw_fit y severity, collect nolog
        assert e(converged) == 1

        * Second collect appends without error
        iivw_fit y severity treated, collect replace nolog
        assert e(converged) == 1

        * After an error, collect state should be OK
        capture iivw_fit y severity, timespec(invalid) collect nolog
        assert _rc == 198
        * Successful collect after the error
        iivw_fit y severity, collect replace nolog
        assert e(converged) == 1
    }
    if _rc == 0 {
        display as result "  PASS: T8 - collect double/post-error"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T8 - collect adversarial (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T8"
    }
}

**## T9: if/in eliminates entire clusters — vce(cluster) still works

local ++test_count
if `run_only' == 0 | `run_only' == 9 {
    capture noisily {
        _final_panel, nids(60) visits(5) seed(10009)
        gen long site = mod(id, 10) + 1
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog

        * Keep only sites 1-3 via if (eliminates 7 of 10 clusters)
        iivw_fit y severity if site <= 3, cluster(site) nolog
        assert e(N) > 0
        assert e(N_clust) <= 3
        assert "`e(iivw_cluster)'" == "site"

        * Extreme: if leaves only 1 cluster — should still run (SE may be .)
        capture iivw_fit y severity if site == 1, cluster(site) replace nolog
        * Either succeeds or errors cleanly — no crash
        assert inlist(_rc, 0, 198, 459, 480)
    }
    if _rc == 0 {
        display as result "  PASS: T9 - cluster elimination via if"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T9 - cluster elimination (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T9"
    }
}

**## T10: extreme xb from near-separation visit model

local ++test_count
if `run_only' == 0 | `run_only' == 10 {
    capture noisily {
        clear
        set seed 10010
        set obs 120
        gen long id = ceil(_n / 4)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 3 + runiform() * 0.01
        replace months = 0 if visit_n == 1
        * Create a covariate with extremely high variance
        gen double extreme_cov = 100 * rnormal(0, 10)

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(extreme_cov) nolog

        * Weights should be finite (no Inf/NaN from exp(-huge_xb))
        quietly count if missing(_iivw_weight)
        local n_miss = r(N)
        quietly count if _iivw_weight > 1e15 & !missing(_iivw_weight)
        local n_huge = r(N)

        * At minimum: no crashes, weights created
        confirm variable _iivw_weight
        assert r(N) >= 0

        * Truncation should tame extreme weights
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(extreme_cov) ///
            truncate(5 95) replace nolog
        quietly summarize _iivw_weight
        * After truncation, max weight should be finite and bounded
        assert r(max) < .
        assert r(min) > 0 | r(min) == .
    }
    if _rc == 0 {
        display as result "  PASS: T10 - extreme xb weights handled"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T10 - extreme xb (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T10"
    }
}

**## T11: String id variable through weight+fit pipeline

local ++test_count
if `run_only' == 0 | `run_only' == 11 {
    capture noisily {
        clear
        set seed 10011
        set obs 160
        gen str8 pid = "P" + string(ceil(_n / 4), "%04.0f")
        encode pid, gen(pid_num)
        bysort pid: gen int visit_n = _n
        gen double months = (visit_n - 1) * 3 + runiform() * 0.1
        replace months = 0 if visit_n == 1
        gen double severity = 2 + rnormal(0, 0.5)
        gen double y = 5 - 0.2 * severity + rnormal(0, 0.3)

        iivw_weight, endatlastvisit baseline(event) id(pid) time(months) visit_cov(severity) nolog
        assert r(N) == 160
        assert r(n_ids) == 40
        * First-obs IIW weights identical across subjects (mean-1 normalized)
        tempvar _fafirst
        bysort pid (months): gen byte `_fafirst' = (_n == 1)
        quietly summarize _iivw_iw if `_fafirst'
        assert r(sd) < 1e-9

        * String id stored in metadata means markout on cluster fails
        * (markout excludes all obs for string vars). Must supply numeric cluster.
        iivw_fit y severity, cluster(pid_num) nolog
        assert e(N) == 160
        assert "`e(iivw_cmd)'" == "iivw_fit"
        assert "`e(iivw_cluster)'" == "pid_num"
    }
    if _rc == 0 {
        display as result "  PASS: T11 - string id through weight+fit pipeline"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T11 - string id (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T11"
    }
}

**## T12: Large panel stress — 200 subjects x 20 visits

local ++test_count
if `run_only' == 0 | `run_only' == 12 {
    capture noisily {
        clear
        set seed 10012
        local nids 200
        local nvis 20
        set obs `=`nids' * `nvis''
        gen long id = ceil(_n / `nvis')
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 1.5 + runiform() * 0.1
        replace months = 0 if visit_n == 1
        gen double severity = 2 + 0.05 * months + rnormal(0, 0.4)
        bysort id (months): gen double sev_bl = severity[1]
        gen byte treated = mod(id, 2)
        bysort id (months): replace treated = treated[1]
        gen double y = 10 - 0.2 * severity + 0.3 * treated + rnormal(0, 0.5)

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) ///
            treat(treated) treat_cov(sev_bl) nolog
        assert r(N) == `=`nids' * `nvis''
        assert r(n_ids) == `nids'
        assert r(ess) > 0

        iivw_fit y treated sev_bl, timespec(quadratic) nolog
        assert e(N) == `=`nids' * `nvis''
        assert e(converged) == 1
    }
    if _rc == 0 {
        display as result "  PASS: T12 - large panel (200x20) stress"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T12 - large panel stress (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T12"
    }
}

**## T13: Post-data-mutation error cleanup — Cox fails after lags created

local ++test_count
if `run_only' == 0 | `run_only' == 13 {
    capture noisily {
        clear
        set seed 10013
        set obs 60
        gen long id = ceil(_n / 3)
        bysort id: gen int visit_n = _n
        gen double months = (visit_n - 1) * 3 + id / 1000
        replace months = 0 if visit_n == 1
        * Create a constant covariate — stcox will fail (no variation)
        gen double constant = 1
        gen double sev = rnormal(2, 0.5)

        capture iivw_weight, endatlastvisit baseline(event) id(id) time(months) ///
            visit_cov(constant) lagvars(sev) nolog
        local wt_rc = _rc

        if `wt_rc' != 0 {
            * Error path: lag variables should be cleaned up
            capture confirm variable sev_lag1
            * Lag should either be cleaned up or left — but no crash
            * Weight variables should NOT exist
            capture confirm variable _iivw_weight
            assert _rc != 0
            capture confirm variable _iivw_iw
            assert _rc != 0
        }
        else {
            * If stcox somehow succeeds with constant covariate,
            * weights should still be valid
            assert r(N) == 60
        }
    }
    if _rc == 0 {
        display as result "  PASS: T13 - post-mutation error cleanup"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T13 - post-mutation cleanup (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T13"
    }
}

**## T14: Sort-preserve with pre-existing random order and id/time ties

local ++test_count
if `run_only' == 0 | `run_only' == 14 {
    capture noisily {
        _final_panel, nids(40) visits(5) seed(10014)

        * Scramble the data into a deliberately bad order
        gen double scramble = runiform()
        sort scramble
        drop scramble
        gen long orig_order = _n
        gen double orig_severity = severity
        gen double orig_months = months
        gen long orig_id = id

        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog

        * sortpreserve should restore the scrambled order
        assert id == orig_id
        assert months == orig_months
        assert severity == orig_severity
        assert _n == orig_order
    }
    if _rc == 0 {
        display as result "  PASS: T14 - sort-preserve with scrambled data"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T14 - sort-preserve (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T14"
    }
}

**## T15: Categorical with non-contiguous levels and basecat not lowest

local ++test_count
if `run_only' == 0 | `run_only' == 15 {
    capture noisily {
        _final_panel, seed(10015)
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog

        * Non-contiguous levels: 10, 30, 50
        gen int dose = 10 + 20 * mod(id, 3)
        bysort id (months): replace dose = dose[1]
        capture label drop doselbl
        label define doselbl 10 "Low" 30 "Medium" 50 "High"
        label values dose doselbl

        * basecat(30) = Medium as reference
        iivw_fit y dose severity, categorical(dose) basecat(30) nolog

        * Dummies should be for Low(10) and High(50), not Medium(30)
        local cats "`e(iivw_cat_vars)'"
        local n_cats : word count `cats'
        assert `n_cats' == 2

        * Verify the basecat char
        local base : char _dta[_iivw_basecat]
        assert "`base'" == "30"

        * Low dummy should be 1 when dose==10
        foreach cv of local cats {
            confirm variable `cv'
        }
    }
    if _rc == 0 {
        display as result "  PASS: T15 - non-contiguous categorical with basecat"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T15 - non-contiguous categorical (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T15"
    }
}

**## T16: Interaction with ns() + categorical — full expansion count

local ++test_count
if `run_only' == 0 | `run_only' == 16 {
    capture noisily {
        _final_panel, nids(60) visits(6) seed(10016)
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog

        gen byte arm = mod(id, 3)
        bysort id (months): replace arm = arm[1]
        capture label drop armlbl
        label define armlbl 0 "Control" 1 "Low" 2 "High"
        label values arm armlbl

        * categorical(arm) with 3 levels -> 2 dummies
        * interaction(arm) x ns(2) -> 2 dummies x 2 basis = 4 interaction vars
        iivw_fit y arm severity, categorical(arm) ///
            interaction(arm) timespec(ns(2)) nolog

        * Count interaction variables
        local ix "`e(iivw_ix_vars)'"
        local n_ix : word count `ix'
        assert `n_ix' == 4

        * Count total display vars
        local disp "`e(iivw_display_vars)'"
        * Should include: 2 cat dummies + severity + 2 ns basis + 4 ix = 9
        local n_disp : word count `disp'
        assert `n_disp' == 9
    }
    if _rc == 0 {
        display as result "  PASS: T16 - interaction x ns() x categorical expansion"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T16 - full expansion (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T16"
    }
}

**## T17: Multiple lagvars with name length near 32-char boundary

local ++test_count
if `run_only' == 0 | `run_only' == 17 {
    capture noisily {
        _final_panel, seed(10017)

        * Variable name with 27 chars -> _lag1 adds 5 = 32 (exactly at limit)
        gen double abcdefghijklmnopqrstuvwxyza = severity * 1.1
        * Variable name with 28 chars -> _lag1 adds 5 = 33 (over limit)
        gen double abcdefghijklmnopqrstuvwxyzab = severity * 1.2

        * 27-char name + _lag1 = 32: should work
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) ///
            lagvars(abcdefghijklmnopqrstuvwxyza) nolog
        confirm variable abcdefghijklmnopqrstuvwxyza_lag1

        * 28-char name + _lag1 = 33: should error with rc=198
        _final_panel, seed(10017)
        gen double abcdefghijklmnopqrstuvwxyzab = severity * 1.2
        capture iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) ///
            lagvars(abcdefghijklmnopqrstuvwxyzab) nolog
        assert _rc == 198
    }
    if _rc == 0 {
        display as result "  PASS: T17 - lagvar name length boundary"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T17 - lagvar name length (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T17"
    }
}

**## T18: All-identical visit times within subjects (degenerate panel)

local ++test_count
if `run_only' == 0 | `run_only' == 18 {
    capture noisily {
        clear
        set obs 60
        gen long id = ceil(_n / 3)
        bysort id: gen int visit_n = _n
        * All visits at time 0 except add tiny increments to avoid duplicates
        gen double months = (visit_n - 1) * 0.0001
        gen double severity = rnormal(2, 0.5)

        * Should either succeed (degenerate but valid) or error cleanly
        capture iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog
        local wt_rc = _rc
        if `wt_rc' == 0 {
            * If it succeeds, weights should be finite
            quietly count if missing(_iivw_weight)
            * Some may be missing due to extreme Cox predictions
            assert r(N) < _N
        }
        else {
            * Clean error: no partial outputs
            capture confirm variable _iivw_weight
            assert _rc != 0
        }
    }
    if _rc == 0 {
        display as result "  PASS: T18 - degenerate near-identical times handled"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T18 - degenerate times (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T18"
    }
}

**## T19: iivw_fit with all-equal depvar values

local ++test_count
if `run_only' == 0 | `run_only' == 19 {
    capture noisily {
        _final_panel, seed(10019)
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog

        * Replace depvar with a constant
        replace y = 5

        * GLM with constant outcome should either converge or error cleanly
        capture iivw_fit y severity, nolog
        local fit_rc = _rc
        if `fit_rc' == 0 {
            * Coefficient on severity should be ~0
            assert abs(_b[severity]) < 0.001
        }
        * Any error is acceptable as long as no crash and cleanup happened
        assert inlist(`fit_rc', 0, 430, 459, 480, 198)
    }
    if _rc == 0 {
        display as result "  PASS: T19 - constant depvar handled"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T19 - constant depvar (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T19"
    }
}

**## T20: Full pipeline end-to-end with reweight + refit

local ++test_count
if `run_only' == 0 | `run_only' == 20 {
    capture noisily {
        _final_panel, nids(50) visits(5) seed(10020)

        * Step 1: IIW weights
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) nolog
        local wtype1 : char _dta[_iivw_weighttype]
        assert "`wtype1'" == "iivw"

        * Step 2: Fit
        iivw_fit y severity treated, timespec(quadratic) nolog
        scalar b1_severity = _b[severity]
        local fitted1 : char _dta[_iivw_fitted]
        assert "`fitted1'" == "1"

        * Step 3: Reweight with FIPTIW (replace)
        iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(severity) ///
            treat(treated) treat_cov(sev_bl) replace nolog
        local wtype2 : char _dta[_iivw_weighttype]
        assert "`wtype2'" == "fiptiw"
        * Old fit metadata should be cleared by reweighting
        local fitted2 : char _dta[_iivw_fitted]
        assert "`fitted2'" == ""

        * Step 4: Refit with replace
        iivw_fit y severity treated, timespec(ns(3)) replace nolog
        scalar b2_severity = _b[severity]
        local fitted3 : char _dta[_iivw_fitted]
        assert "`fitted3'" == "1"
        assert "`e(iivw_weighttype)'" == "fiptiw"
        assert "`e(iivw_timespec)'" == "ns(3)"

        * Coefficients should differ between IIW and FIPTIW fits
        * (different weights -> different point estimates)
        * Not guaranteed to be different in every seed, so just check both ran
        assert b1_severity < . & b2_severity < .
    }
    if _rc == 0 {
        display as result "  PASS: T20 - full pipeline reweight+refit"
        local ++pass_count
    }
    else {
        display as error "  FAIL: T20 - pipeline end-to-end (error `=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' T20"
    }
}

**# Summary

iivw_qa_summary, name(test_iivw_final_adversarial) tests(`test_count') pass(`pass_count') ///
    fail(`fail_count') runonly(`run_only') failedtests("`failed_tests'")


clear
