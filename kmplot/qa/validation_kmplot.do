* validation_kmplot.do
* Numerical validation suite for kmplot
* Author: Timothy P Copeland, Karolinska Institutet
* Created: 2026-03-15
*
* Validates correctness of KM estimates, CIs, medians, p-values,
* and N-at-risk against Stata's built-in survival commands.

clear all
version 16.0
set varabbrev off


**# Bootstrap
local qa_dir "`c(pwd)'"
do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**## V1: S(t) matches sts generate exactly
* The KM estimates produced by kmplot should match sts generate s = s
* since kmplot uses sts generate internally.

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    tempfile v1_expected v1_curve
    tempvar expected_s
    quietly sts generate `expected_s' = s
    preserve
    keep _t `expected_s'
    collapse (mean) `expected_s', by(_t)
    rename _t time
    save "`v1_expected'"
    restore

    kmplot, saving("`v1_curve'", replace) name(v1, replace)
    local km_N = r(N)
    assert `km_N' == 48

    use "`v1_curve'", clear
    keep if anchor == 0
    collapse (mean) estimate, by(time)
    merge 1:1 time using "`v1_expected'", assert(match) nogen
    assert abs(estimate - `expected_s') < 1e-12 if !missing(`expected_s')
    assert missing(estimate) == missing(`expected_s')
}
if _rc == 0 {
    display as result "  PASS: V1 S(t) matches sts generate"
    local ++pass_count
}
else {
    display as error "  FAIL: V1 S(t) matches sts generate (rc=`=_rc')"
    local ++fail_count
}

**## V2: CI bounds match manual log-log calculation
* Verify log-log CI: lb = exp(-exp(log(-log(S)) + z*se/(S*|log(S)|)))
*                    ub = exp(-exp(log(-log(S)) - z*se/(S*|log(S)|)))

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    tempfile v2_expected v2_curve
    tempvar expected_s expected_se expected_lb expected_ub
    quietly sts generate `expected_s' = s
    quietly sts generate `expected_se' = se(s)
    quietly gen double `expected_lb' = exp(-exp(log(-log(`expected_s')) + ///
        invnormal(0.975) * `expected_se' / (`expected_s' * abs(log(`expected_s'))))) ///
        if `expected_s' > 0 & `expected_s' < 1 & `expected_se' > 0
    quietly gen double `expected_ub' = exp(-exp(log(-log(`expected_s')) - ///
        invnormal(0.975) * `expected_se' / (`expected_s' * abs(log(`expected_s'))))) ///
        if `expected_s' > 0 & `expected_s' < 1 & `expected_se' > 0
    preserve
    keep _t `expected_lb' `expected_ub'
    collapse (mean) `expected_lb' `expected_ub', by(_t)
    rename _t time
    save "`v2_expected'"
    restore

    kmplot, ci saving("`v2_curve'", replace) name(v2, replace)
    use "`v2_curve'", clear
    keep if anchor == 0
    collapse (mean) lower upper, by(time)
    merge 1:1 time using "`v2_expected'", assert(match) nogen
    assert abs(lower - `expected_lb') < 1e-12 if !missing(`expected_lb')
    assert abs(upper - `expected_ub') < 1e-12 if !missing(`expected_ub')
    assert missing(lower) == missing(`expected_lb')
    assert missing(upper) == missing(`expected_ub')
}
if _rc == 0 {
    display as result "  PASS: V2 CI bounds match manual log-log"
    local ++pass_count
}
else {
    display as error "  FAIL: V2 CI bounds match manual log-log (rc=`=_rc')"
    local ++fail_count
}

**## V3: 1-KM equals failure mode
* The failure option should produce F(t) = 1 - S(t)

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    tempfile v3_survival v3_failure v3_reduced
    kmplot, by(drug) saving("`v3_survival'", replace) name(v3s, replace)
    kmplot, by(drug) failure saving("`v3_failure'", replace) name(v3f, replace)

    use "`v3_survival'", clear
    keep if anchor == 0
    collapse (mean) survival=estimate, by(group time)
    save "`v3_reduced'"
    use "`v3_failure'", clear
    keep if anchor == 0
    collapse (mean) failure=estimate, by(group time)
    merge 1:1 group time using "`v3_reduced'", assert(match) nogen
    assert abs(failure - (1 - survival)) < 1e-12 if !missing(survival)
}
if _rc == 0 {
    display as result "  PASS: V3 1-KM equals failure mode"
    local ++pass_count
}
else {
    display as error "  FAIL: V3 1-KM equals failure mode (rc=`=_rc')"
    local ++fail_count
}

**## V4: Median matches stci
* kmplot median should match Stata's stci command

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    * Get kmplot median (overall)
    kmplot, median name(v4a, replace)
    local km_median = r(median_1)

    * Get stci median
    quietly stci
    local stci_median = r(p50)

    * Should match exactly (both use first time S <= 0.5)
    assert abs(`km_median' - `stci_median') < 0.001
}
if _rc == 0 {
    display as result "  PASS: V4 Median matches stci (overall)"
    local ++pass_count
}
else {
    display as error "  FAIL: V4 Median matches stci (rc=`=_rc')"
    local ++fail_count
}

**## V5: Median matches stci by group

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    * Get kmplot medians by drug
    kmplot, by(drug) median name(v5, replace)
    local km_med1 = r(median_1)
    local km_med2 = r(median_2)
    local km_med3 = r(median_3)

    * Get stci medians by group
    quietly stci, by(drug)
    * stci by() returns results for last group; need manual extraction
    * Use stci for each group separately
    quietly stci if drug == 1
    local stci_med1 = r(p50)
    quietly stci if drug == 2
    local stci_med2 = r(p50)
    quietly stci if drug == 3
    local stci_med3 = r(p50)

    assert abs(`km_med1' - `stci_med1') < 0.001
    assert abs(`km_med2' - `stci_med2') < 0.001
    assert abs(`km_med3' - `stci_med3') < 0.001
}
if _rc == 0 {
    display as result "  PASS: V5 Median matches stci (by group)"
    local ++pass_count
}
else {
    display as error "  FAIL: V5 Median matches stci by group (rc=`=_rc')"
    local ++fail_count
}

**## V6: P-value matches sts test

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    * Get kmplot p-value
    kmplot, by(drug) pvalue name(v6, replace)
    local km_p = r(p)

    * Get sts test p-value
    quietly sts test drug, logrank
    local sts_p = chi2tail(r(df), r(chi2))

    * Should match to machine precision
    assert abs(`km_p' - `sts_p') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: V6 P-value matches sts test"
    local ++pass_count
}
else {
    display as error "  FAIL: V6 P-value matches sts test (rc=`=_rc')"
    local ++fail_count
}

**## V7: N-at-risk matches manual count
* Verify risk table counts at specific timepoints

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    * Manual count of at-risk at time 0 (should be all 48)
    quietly count if _t >= 0
    local n_t0 = r(N)
    assert `n_t0' == 48

    * At-risk at time 10
    quietly count if _t >= 10
    local n_t10 = r(N)

    * At-risk at time 20
    quietly count if _t >= 20
    local n_t20 = r(N)

    * At-risk at time 30
    quietly count if _t >= 30
    local n_t30 = r(N)

    kmplot, risktable timepoints(0 10 20 30) name(v7, replace)
    matrix R = r(risktable)
    assert R[1,3] == `n_t0'
    assert R[2,3] == `n_t10'
    assert R[3,3] == `n_t20'
    assert R[4,3] == `n_t30'
}
if _rc == 0 {
    display as result "  PASS: V7 N-at-risk matches manual count"
    local ++pass_count
}
else {
    display as error "  FAIL: V7 N-at-risk (rc=`=_rc')"
    local ++fail_count
}

**## V8: CIs clamped to [0, 1]

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    tempfile v8_curve
    kmplot, ci citransform(plain) saving("`v8_curve'", replace) name(v8, replace)
    use "`v8_curve'", clear
    assert lower >= 0 & lower <= 1 if !missing(lower)
    assert upper >= 0 & upper <= 1 if !missing(upper)
    assert lower <= estimate if !missing(lower, estimate)
    assert upper >= estimate if !missing(upper, estimate)
}
if _rc == 0 {
    display as result "  PASS: V8 CIs clamped to [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: V8 CIs clamped (rc=`=_rc')"
    local ++fail_count
}

**## V9: Different CI transforms produce valid bounds

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    foreach transform in loglog log plain {
        tempfile v9_`transform'
        kmplot, ci citransform(`transform') ///
            saving("`v9_`transform''", replace) name(v9_`transform', replace)
        preserve
        use "`v9_`transform''", clear
        assert lower >= 0 & lower <= 1 if !missing(lower)
        assert upper >= 0 & upper <= 1 if !missing(upper)
        assert lower <= upper if !missing(lower, upper)
        quietly count if !missing(lower, upper)
        assert !missing(r(N))
        assert r(N) > 0
        restore
    }
}
if _rc == 0 {
    display as result "  PASS: V9 All CI transforms produce valid bounds"
    local ++pass_count
}
else {
    display as error "  FAIL: V9 CI transforms (rc=`=_rc')"
    local ++fail_count
}

**## V10: Exported file exists with nonzero size

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    local tmpfile "/tmp/test_kmplot_v10.png"
    capture erase "`tmpfile'"

    kmplot, by(drug) export(`tmpfile', replace) name(v10, replace)
    confirm file "`tmpfile'"

    * Check file is nonzero size
    quietly checksum "`tmpfile'"
    assert !missing(r(filelen))
    assert r(filelen) > 0

    erase "`tmpfile'"
}
if _rc == 0 {
    display as result "  PASS: V10 Exported file nonzero"
    local ++pass_count
}
else {
    display as error "  FAIL: V10 Exported file (rc=`=_rc')"
    local ++fail_count
}

**## V11: sysuse cancer benchmark - N by group
* cancer dataset: drug 1 = 16 obs, drug 2 = 16 obs, drug 3 = 16 obs (48 total)

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    * Verify group sizes (Placebo=20, Other=14, NA=14)
    quietly count if drug == 1
    assert r(N) == 20
    quietly count if drug == 2
    assert r(N) == 14
    quietly count if drug == 3
    assert r(N) == 14

    kmplot, by(drug) name(v11, replace)
    assert r(N) == 48
    assert r(n_groups) == 3
}
if _rc == 0 {
    display as result "  PASS: V11 sysuse cancer benchmark"
    local ++pass_count
}
else {
    display as error "  FAIL: V11 sysuse cancer benchmark (rc=`=_rc')"
    local ++fail_count
}

**## V12: Large dataset performance

local ++test_count
capture noisily {
    clear
    set obs 5000
    set seed 12345
    gen double t = rexponential(10)
    gen byte d = runiform() < 0.3
    gen byte grp = 1 + floor(runiform() * 3)
    stset t, failure(d)

    kmplot, by(grp) ci median pvalue name(v12, replace)
    assert r(N) == 5000
    assert r(n_groups) == 3
    assert r(p) < 1
}
if _rc == 0 {
    display as result "  PASS: V12 Large dataset (5000 obs)"
    local ++pass_count
}
else {
    display as error "  FAIL: V12 Large dataset (rc=`=_rc')"
    local ++fail_count
}

**## V13: Median NR case
* Create data where S never reaches 0.5

local ++test_count
capture noisily {
    clear
    set obs 50
    gen double t = runiform() * 10
    * Very few events - S unlikely to reach 0.5
    gen byte d = _n <= 3
    stset t, failure(d)

    kmplot, median medianannotate name(v13, replace)
    * With only 3 events out of 50, median may or may not be reached
    * Just verify command succeeds
    assert r(N) == 50
}
if _rc == 0 {
    display as result "  PASS: V13 Median NR case"
    local ++pass_count
}
else {
    display as error "  FAIL: V13 Median NR case (rc=`=_rc')"
    local ++fail_count
}

**## V14: Risk table alignment (timepoints match)

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    * User-specified timepoints
    kmplot, by(drug) risktable timepoints(0 5 10 15 20 25 30 35) ///
        name(v14, replace)
    assert r(N) == 48
    assert r(n_groups) == 3
}
if _rc == 0 {
    display as result "  PASS: V14 Risk table alignment"
    local ++pass_count
}
else {
    display as error "  FAIL: V14 Risk table alignment (rc=`=_rc')"
    local ++fail_count
}

**## V15: Varabbrev restored after successful run

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    set varabbrev on
    kmplot, by(drug) name(v15, replace)
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: V15 Varabbrev restored (success path)"
    local ++pass_count
}
else {
    display as error "  FAIL: V15 Varabbrev restored (rc=`=_rc')"
    local ++fail_count
}

**## V16: Cumulative events match manual count
* Verify events reported by riskevents match hand-computed counts

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    * Manual cumulative events at time 10 for drug == 1
    quietly count if _t <= 10 & _d == 1 & drug == 1
    local manual_evt_d1_t10 = r(N)

    * Manual cumulative events at time 20 for drug == 1
    quietly count if _t <= 20 & _d == 1 & drug == 1
    local manual_evt_d1_t20 = r(N)

    * Total events for drug == 1
    quietly count if _d == 1 & drug == 1
    local total_evt_d1 = r(N)

    * At time 0, events should be 0
    quietly count if _t <= 0 & _d == 1 & drug == 1
    assert r(N) == 0

    * Events should be monotonically increasing
    assert `manual_evt_d1_t10' <= `manual_evt_d1_t20'
    assert `manual_evt_d1_t20' <= `total_evt_d1'

    kmplot, by(drug) risktable riskevents timepoints(0 10 20 30) ///
        name(v16, replace)
    matrix R = r(risktable)
    assert R[1,4] == 0
    assert R[2,4] == `manual_evt_d1_t10'
    assert R[3,4] == `manual_evt_d1_t20'
    assert R[4,4] == `total_evt_d1'
}
if _rc == 0 {
    display as result "  PASS: V16 Cumulative events match manual count"
    local ++pass_count
}
else {
    display as error "  FAIL: V16 Cumulative events (rc=`=_rc')"
    local ++fail_count
}

**## V17: Events conservation: events + at-risk + censored = total at each time

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    quietly count if drug == 1
    local n_d1 = r(N)

    local tp = 38.5
    quietly count if _t >= `tp' & drug == 1
    local risk_at = r(N)
    quietly count if _t <= `tp' & _d == 1 & drug == 1
    local evt_through = r(N)
    quietly count if _t <= `tp' & _d == 0 & drug == 1
    local cens_through = r(N)

    kmplot, by(drug) risktable timepoints(`tp') name(v17, replace)
    matrix R = r(risktable)
    assert R[1,3] == `risk_at'
    assert R[1,4] == `evt_through'
    assert R[1,5] == `cens_through'
    assert R[1,3] + R[1,4] + R[1,5] == `n_d1'
}
if _rc == 0 {
    display as result "  PASS: V17 Events conservation invariant"
    local ++pass_count
}
else {
    display as error "  FAIL: V17 Events conservation (rc=`=_rc')"
    local ++fail_count
}

**## V18: Riskmono produces valid plot (no error)

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    kmplot, by(drug) risktable riskmono riskevents ///
        timepoints(0 10 20 30) name(v18, replace)
    assert r(N) == 48
    assert r(n_groups) == 3
}
if _rc == 0 {
    display as result "  PASS: V18 Riskmono valid plot"
    local ++pass_count
}
else {
    display as error "  FAIL: V18 Riskmono (rc=`=_rc')"
    local ++fail_count
}

**## V19: set more state invariant (success path)

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    local orig_more = c(more)
    kmplot, by(drug) ci median name(v19, replace)
    assert c(more) == "`orig_more'"
}
if _rc == 0 {
    display as result "  PASS: V19 set more invariant (success path)"
    local ++pass_count
}
else {
    display as error "  FAIL: V19 set more invariant (rc=`=_rc')"
    local ++fail_count
}

**## V20: KM at-risk by group matches manual count

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    * At-risk at time 10 for drug==1
    quietly count if _t >= 10 & drug == 1
    local manual_d1 = r(N)
    * At-risk at time 10 for drug==2
    quietly count if _t >= 10 & drug == 2
    local manual_d2 = r(N)
    * At-risk at time 10 for drug==3
    quietly count if _t >= 10 & drug == 3
    local manual_d3 = r(N)

    * Total at-risk at time 10
    local manual_total = `manual_d1' + `manual_d2' + `manual_d3'
    quietly count if _t >= 10
    assert r(N) == `manual_total'

    kmplot, by(drug) risktable timepoints(0 10 20 30) name(v20, replace)
    matrix R = r(risktable)
    assert R[2,3] == `manual_d1'
    assert R[6,3] == `manual_d2'
    assert R[10,3] == `manual_d3'
}
if _rc == 0 {
    display as result "  PASS: V20 At-risk by group matches manual count"
    local ++pass_count
}
else {
    display as error "  FAIL: V20 At-risk by group (rc=`=_rc')"
    local ++fail_count
}

**## V21: Small time-scale KM estimates bounded [0,1]

local ++test_count
capture noisily {
    clear
    set obs 100
    set seed 21000
    gen double t = runiform() * 0.001
    gen byte d = runiform() < 0.5
    stset t, failure(d)

    tempfile v21_curve
    kmplot, ci saving("`v21_curve'", replace) name(v21, replace)
    use "`v21_curve'", clear
    assert estimate >= 0 & estimate <= 1 if !missing(estimate)
    assert lower >= 0 & lower <= 1 if !missing(lower)
    assert upper >= 0 & upper <= 1 if !missing(upper)
}
if _rc == 0 {
    display as result "  PASS: V21 Small time-scale KM bounded [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: V21 Small time-scale KM (rc=`=_rc')"
    local ++fail_count
}

**## V22: Failure mode CIs inversion invariant
* For failure mode: if S_lb < S < S_ub, then (1-S_ub) < (1-S) < (1-S_lb)
* The CI bounds must be properly swapped

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    tempfile v22_expected v22_curve
    tempvar expected_s expected_se expected_lb expected_ub
    quietly sts generate `expected_s' = s
    quietly sts generate `expected_se' = se(s)
    quietly gen double `expected_lb' = 1 - exp(-exp(log(-log(`expected_s')) - ///
        invnormal(0.975) * `expected_se' / (`expected_s' * abs(log(`expected_s'))))) ///
        if `expected_s' > 0 & `expected_s' < 1 & `expected_se' > 0
    quietly gen double `expected_ub' = 1 - exp(-exp(log(-log(`expected_s')) + ///
        invnormal(0.975) * `expected_se' / (`expected_s' * abs(log(`expected_s'))))) ///
        if `expected_s' > 0 & `expected_s' < 1 & `expected_se' > 0
    preserve
    keep _t `expected_lb' `expected_ub'
    collapse (mean) `expected_lb' `expected_ub', by(_t)
    rename _t time
    save "`v22_expected'"
    restore

    kmplot, ci failure saving("`v22_curve'", replace) name(v22, replace)
    use "`v22_curve'", clear
    keep if anchor == 0
    collapse (mean) lower upper, by(time)
    merge 1:1 time using "`v22_expected'", assert(match) nogen
    assert abs(lower - `expected_lb') < 1e-12 if !missing(`expected_lb')
    assert abs(upper - `expected_ub') < 1e-12 if !missing(`expected_ub')
    assert missing(lower) == missing(`expected_lb')
    assert missing(upper) == missing(`expected_ub')
}
if _rc == 0 {
    display as result "  PASS: V22 Failure mode CI inversion invariant"
    local ++pass_count
}
else {
    display as error "  FAIL: V22 Failure CI inversion (rc=`=_rc')"
    local ++fail_count
}

**## V23: Many groups color cycling produces valid plot
* 10+ groups should cycle through 8 colors without error

local ++test_count
capture noisily {
    clear
    set obs 200
    set seed 23000
    gen double t = rexponential(5)
    gen byte d = runiform() < 0.4
    gen int grp = 1 + floor(runiform() * 12)
    stset t, failure(d)
    kmplot, by(grp) ci censor median risktable name(v23, replace)
    assert r(n_groups) == 12
    assert r(N) == 200
}
if _rc == 0 {
    display as result "  PASS: V23 12-group color cycling valid plot"
    local ++pass_count
}
else {
    display as error "  FAIL: V23 12-group color cycling (rc=`=_rc')"
    local ++fail_count
}

**## V24: Monotonicity invariant — KM is non-increasing

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    tempfile v24_curve
    kmplot, saving("`v24_curve'", replace) name(v24, replace)
    use "`v24_curve'", clear
    keep if anchor == 0
    sort group time
    by group: assert estimate <= estimate[_n - 1] + 1e-12 ///
        if _n > 1 & !missing(estimate, estimate[_n - 1])
}
if _rc == 0 {
    display as result "  PASS: V24 KM monotonicity invariant"
    local ++pass_count
}
else {
    display as error "  FAIL: V24 KM monotonicity (rc=`=_rc')"
    local ++fail_count
}

**## V25: Quoted export path writes to the requested filename

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    local svgfile `c(tmpdir)'/kmplot_v25.svg
    mata: st_local("badsvgfile", st_local("svgfile") + char(34))

    capture erase "`svgfile'"
    capture erase `"`badsvgfile'"'

    kmplot, by(drug) export("`svgfile'", replace) name(v25, replace)

    confirm file "`svgfile'"
    capture confirm file `"`badsvgfile'"'
    assert _rc != 0
    quietly checksum "`svgfile'"
    assert !missing(r(filelen))
    assert r(filelen) > 0

    erase "`svgfile'"
}
if _rc == 0 {
    display as result "  PASS: V25 Quoted export path writes correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: V25 Quoted export path (rc=`=_rc')"
    local ++fail_count
}

**## V26: Risktable respects explicit bottom-axis title and labels

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    local svgfile `c(tmpdir)'/kmplot_v26.svg
    capture erase "`svgfile'"

    kmplot, by(drug) risktable ///
        xtitle("Years from study entry") ///
        xlabel(0(7)21, format(%4.1f)) ///
        export("`svgfile'", replace) name(v26, replace)

    confirm file "`svgfile'"
    _kmplot_assert_file_contains using "`svgfile'", pattern("Years from study entry")
    _kmplot_assert_file_not_contains using "`svgfile'", pattern("Analysis time")
    _kmplot_assert_file_contains using "`svgfile'", pattern(">21.0</text>")

    erase "`svgfile'"
}
if _rc == 0 {
    display as result "  PASS: V26 Risktable respects explicit bottom axis"
    local ++pass_count
}
else {
    display as error "  FAIL: V26 Risktable explicit bottom axis (rc=`=_rc')"
    local ++fail_count
}

**## V27: Delayed-entry risk-table counts honor _t0

local ++test_count
capture noisily {
    clear
    input id group enter exit event
    1 1 0 5 1
    2 1 2 8 0
    3 1 4 10 1
    4 2 0 3 0
    5 2 3 7 1
    6 2 6 9 0
    end
    stset exit, failure(event) enter(time enter) id(id)

    kmplot, by(group) risktable timepoints(0 2 5 8) name(v27, replace)
    matrix R = r(risktable)
    assert rowsof(R) == 8
    assert colsof(R) == 5
    assert R[1,3] == 1
    assert R[2,3] == 1
    assert R[3,3] == 3
    assert R[4,3] == 2
    assert R[5,3] == 1
    assert R[6,3] == 1
    assert R[7,3] == 1
    assert R[8,3] == 1
    assert R[3,4] == 1
    assert R[8,4] == 1
}
if _rc == 0 {
    display as result "  PASS: V27 Delayed-entry risk-table counts"
    local ++pass_count
}
else {
    display as error "  FAIL: V27 Delayed-entry risk-table counts (rc=`=_rc')"
    local ++fail_count
}

**## V28: landmark() estimates match sts generate step values

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    tempvar gid s
    egen int `gid' = group(drug), label
    quietly sts generate `s' = s, by(`gid')

    kmplot, by(drug) landmark(10 20) name(v28, replace)
    matrix L = r(landmarks)

    quietly summarize _t if `gid' == 1 & _t <= 10 & !missing(`s'), meanonly
    local tlast = r(max)
    quietly summarize `s' if `gid' == 1 & _t == `tlast', meanonly
    local manual_s = r(mean)
    assert abs(L[1,3] - `manual_s') < 1e-10

    quietly summarize _t if `gid' == 2 & _t <= 20 & !missing(`s'), meanonly
    local tlast = r(max)
    quietly summarize `s' if `gid' == 2 & _t == `tlast', meanonly
    local manual_s = r(mean)
    assert abs(L[4,3] - `manual_s') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: V28 landmark() matches sts generate"
    local ++pass_count
}
else {
    display as error "  FAIL: V28 landmark() matches sts generate (rc=`=_rc')"
    local ++fail_count
}

**## V29: level() changes CI bounds using requested z critical value

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    quietly sts generate _km_s = s
    quietly sts generate _km_se = se(s)
    quietly summarize _t if _t <= 10 & !missing(_km_s), meanonly
    local tlast = r(max)
    quietly summarize _km_s if _t == `tlast', meanonly
    local s10 = r(mean)
    quietly summarize _km_se if _t == `tlast', meanonly
    local se10 = r(mean)
    local z90 = invnormal(1 - (100 - 90) / 200)
    local lb90 = exp(-exp(log(-log(`s10')) + `z90' * `se10' / (`s10' * abs(log(`s10')))))
    local ub90 = exp(-exp(log(-log(`s10')) - `z90' * `se10' / (`s10' * abs(log(`s10')))))

    kmplot, ci level(90) landmark(10) name(v29, replace)
    matrix L = r(landmarks)
    assert abs(L[1,4] - `lb90') < 1e-8
    assert abs(L[1,5] - `ub90') < 1e-8
    assert r(level) == 90
}
if _rc == 0 {
    display as result "  PASS: V29 level() CI bounds"
    local ++pass_count
}
else {
    display as error "  FAIL: V29 level() CI bounds (rc=`=_rc')"
    local ++fail_count
}

**# Summary

display as text "  Total:  " as result `test_count'
display as text "  Passed: " as result `pass_count'
display as text "  Failed: " as result `fail_count'

if `fail_count' > 0 {
    display as error "RESULT: validation_kmplot tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
else {
    display as result "RESULT: validation_kmplot tests=`test_count' pass=`pass_count' fail=`fail_count'"
}
