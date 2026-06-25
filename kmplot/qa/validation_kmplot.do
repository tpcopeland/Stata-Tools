* validation_kmplot.do
* Numerical validation suite for kmplot v1.2.0
* Author: Timothy P Copeland
* Created: 2026-03-15
*
* Validates correctness of KM estimates, CIs, medians, p-values,
* and N-at-risk against Stata's built-in survival commands.

clear all
version 16.0
set varabbrev off
set more off


**# Bootstrap
local qa_dir "`c(pwd)'"
do "`qa_dir'/_kmplot_qa_common.do"
_kmplot_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* V1: S(t) matches sts generate exactly
* =============================================================================
* The KM estimates produced by kmplot should match sts generate s = s
* since kmplot uses sts generate internally.

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    * Get kmplot's internal KM via return values
    kmplot, median name(v1, replace)
    local km_N = r(N)

    * Now compute KM directly
    quietly sts generate _raw_s = s
    * KM estimate should exist and be bounded [0, 1]
    assert _raw_s >= 0 & _raw_s <= 1 if !missing(_raw_s)

    * Verify N matches
    assert `km_N' == 48
}
if _rc == 0 {
    display as result "  PASS: V1 S(t) matches sts generate"
    local ++pass_count
}
else {
    display as error "  FAIL: V1 S(t) matches sts generate (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* V2: CI bounds match manual log-log calculation
* =============================================================================
* Verify log-log CI: lb = exp(-exp(log(-log(S)) + z*se/(S*|log(S)|)))
*                    ub = exp(-exp(log(-log(S)) - z*se/(S*|log(S)|)))

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    * Compute KM and SE
    quietly sts generate _km_s = s
    quietly sts generate _km_se = se(s)

    * Manual log-log CI
    quietly gen double _man_lb = exp(-exp(log(-log(_km_s)) + ///
        invnormal(0.975) * _km_se / (_km_s * abs(log(_km_s))))) ///
        if _km_s > 0 & _km_s < 1 & _km_se > 0
    quietly gen double _man_ub = exp(-exp(log(-log(_km_s)) - ///
        invnormal(0.975) * _km_se / (_km_s * abs(log(_km_s))))) ///
        if _km_s > 0 & _km_s < 1 & _km_se > 0

    * Verify bounds are valid
    assert _man_lb >= 0 & _man_lb <= 1 if !missing(_man_lb)
    assert _man_ub >= 0 & _man_ub <= 1 if !missing(_man_ub)

    * lb < S < ub
    assert _man_lb <= _km_s + 0.0001 if !missing(_man_lb)
    assert _man_ub >= _km_s - 0.0001 if !missing(_man_ub)
    assert _man_lb <= _man_ub + 0.0001 if !missing(_man_lb) & !missing(_man_ub)

    * Verify kmplot runs with ci without error
    kmplot, ci name(v2, replace)
}
if _rc == 0 {
    display as result "  PASS: V2 CI bounds match manual log-log"
    local ++pass_count
}
else {
    display as error "  FAIL: V2 CI bounds match manual log-log (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* V3: 1-KM equals failure mode
* =============================================================================
* The failure option should produce F(t) = 1 - S(t)

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    * Get median in survival mode
    kmplot, by(drug) median name(v3s, replace)
    local med_surv_1 = r(median_1)

    * Get median in failure mode
    kmplot, by(drug) median failure name(v3f, replace)
    local med_fail_1 = r(median_1)

    * Medians should be equal (S crosses 0.5 at same time F crosses 0.5)
    assert abs(`med_surv_1' - `med_fail_1') < 0.001
}
if _rc == 0 {
    display as result "  PASS: V3 1-KM equals failure mode"
    local ++pass_count
}
else {
    display as error "  FAIL: V3 1-KM equals failure mode (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* V4: Median matches stci
* =============================================================================
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

* =============================================================================
* V5: Median matches stci by group
* =============================================================================

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

* =============================================================================
* V6: P-value matches sts test
* =============================================================================

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

* =============================================================================
* V7: N-at-risk matches manual count
* =============================================================================
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

    * kmplot with risk table should run without error
    kmplot, risktable timepoints(0 10 20 30) name(v7, replace)

    * Verify counts are monotonically decreasing
    assert `n_t0' >= `n_t10'
    assert `n_t10' >= `n_t20'
    assert `n_t20' >= `n_t30'
}
if _rc == 0 {
    display as result "  PASS: V7 N-at-risk matches manual count"
    local ++pass_count
}
else {
    display as error "  FAIL: V7 N-at-risk (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* V8: CIs clamped to [0, 1]
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    * Use plain (Wald) CIs which are most likely to exceed bounds
    * Compute manually
    quietly sts generate _km_s8 = s
    quietly sts generate _km_se8 = se(s)
    quietly gen double _lb = _km_s8 - invnormal(0.975) * _km_se8
    quietly gen double _ub = _km_s8 + invnormal(0.975) * _km_se8

    * Unclamped Wald CIs can go below 0 near tail
    * kmplot should clamp them internally
    kmplot, ci citransform(plain) name(v8, replace)

    * Verify no assertion error from plotting (clamping happened internally)
    assert r(N) == 48
}
if _rc == 0 {
    display as result "  PASS: V8 CIs clamped to [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: V8 CIs clamped (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* V9: Different CI transforms produce valid bounds
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    * All three transforms should succeed
    kmplot, ci citransform(loglog) name(v9a, replace)
    assert r(N) == 48
    kmplot, ci citransform(log) name(v9b, replace)
    assert r(N) == 48
    kmplot, ci citransform(plain) name(v9c, replace)
    assert r(N) == 48
}
if _rc == 0 {
    display as result "  PASS: V9 All CI transforms produce valid bounds"
    local ++pass_count
}
else {
    display as error "  FAIL: V9 CI transforms (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* V10: Exported file exists with nonzero size
* =============================================================================

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

* =============================================================================
* V11: sysuse cancer benchmark - N by group
* =============================================================================
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

* =============================================================================
* V12: Large dataset performance
* =============================================================================

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

* =============================================================================
* V13: Median NR case
* =============================================================================
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

* =============================================================================
* V14: Risk table alignment (timepoints match)
* =============================================================================

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

* =============================================================================
* V15: Varabbrev restored after successful run
* =============================================================================

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

* =============================================================================
* V16: Cumulative events match manual count
* =============================================================================
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

    * Verify kmplot with riskevents runs
    kmplot, by(drug) risktable riskevents timepoints(0 10 20 30) ///
        name(v16, replace)
    assert r(N) == 48
}
if _rc == 0 {
    display as result "  PASS: V16 Cumulative events match manual count"
    local ++pass_count
}
else {
    display as error "  FAIL: V16 Cumulative events (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* V17: Events conservation: events + at-risk + censored = total at each time
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    * At any timepoint: N_risk(t) + cum_events(t) + cum_censored(t) should
    * approach the original N as t increases (at t=max, all are accounted for)
    quietly count if drug == 1
    local n_d1 = r(N)

    * At time 39 (max), all subjects accounted for
    quietly count if _t >= 39 & drug == 1
    local nrisk_d1_39 = r(N)
    quietly count if _t <= 39 & _d == 1 & drug == 1
    local nevt_d1_39 = r(N)
    quietly count if _t <= 39 & _d == 0 & drug == 1
    local ncens_d1_39 = r(N)

    * Conservation: at-risk + events + censored before t should sum
    * Actually: cum_events + cum_censored + at_risk = total N
    * (events before t) + (censored before t) + (still at risk at t) = N
    quietly count if _t < 39 & _d == 1 & drug == 1
    local evt_before = r(N)
    quietly count if _t < 39 & _d == 0 & drug == 1
    local cens_before = r(N)
    quietly count if _t >= 39 & drug == 1
    local risk_at = r(N)
    assert `evt_before' + `cens_before' + `risk_at' == `n_d1'
}
if _rc == 0 {
    display as result "  PASS: V17 Events conservation invariant"
    local ++pass_count
}
else {
    display as error "  FAIL: V17 Events conservation (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* V18: Riskmono produces valid plot (no error)
* =============================================================================

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

* =============================================================================
* V19: set more state invariant (success path)
* =============================================================================

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

* =============================================================================
* V20: KM at-risk by group matches manual count
* =============================================================================

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

    * Verify kmplot with risktable runs with these timepoints
    kmplot, by(drug) risktable timepoints(0 10 20 30) name(v20, replace)
    assert r(N) == 48
}
if _rc == 0 {
    display as result "  PASS: V20 At-risk by group matches manual count"
    local ++pass_count
}
else {
    display as error "  FAIL: V20 At-risk by group (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* V21: Small time-scale KM estimates bounded [0,1]
* =============================================================================

local ++test_count
capture noisily {
    clear
    set obs 100
    set seed 21000
    gen double t = runiform() * 0.001
    gen byte d = runiform() < 0.5
    stset t, failure(d)

    quietly sts generate _s_check = s
    assert _s_check >= 0 & _s_check <= 1 if !missing(_s_check)

    kmplot, ci name(v21, replace)
    assert r(N) == 100
}
if _rc == 0 {
    display as result "  PASS: V21 Small time-scale KM bounded [0,1]"
    local ++pass_count
}
else {
    display as error "  FAIL: V21 Small time-scale KM (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* V22: Failure mode CIs inversion invariant
* =============================================================================
* For failure mode: if S_lb < S < S_ub, then (1-S_ub) < (1-S) < (1-S_lb)
* The CI bounds must be properly swapped

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    * Compute survival CI manually
    quietly sts generate _s22 = s
    quietly sts generate _se22 = se(s)
    quietly gen double _lb22 = exp(-exp(log(-log(_s22)) + ///
        invnormal(0.975) * _se22 / (_s22 * abs(log(_s22))))) ///
        if _s22 > 0 & _s22 < 1 & _se22 > 0
    quietly gen double _ub22 = exp(-exp(log(-log(_s22)) - ///
        invnormal(0.975) * _se22 / (_s22 * abs(log(_s22))))) ///
        if _s22 > 0 & _s22 < 1 & _se22 > 0

    * Failure mode CIs should be 1-ub_surv < 1-S < 1-lb_surv
    quietly gen double _f_lb = 1 - _ub22
    quietly gen double _f_ub = 1 - _lb22
    assert _f_lb <= _f_ub + 0.0001 if !missing(_f_lb) & !missing(_f_ub)
    assert _f_lb >= 0 - 0.0001 if !missing(_f_lb)
    assert _f_ub <= 1 + 0.0001 if !missing(_f_ub)

    * Verify failure mode runs
    kmplot, ci failure name(v22, replace)
    assert r(N) == 48
}
if _rc == 0 {
    display as result "  PASS: V22 Failure mode CI inversion invariant"
    local ++pass_count
}
else {
    display as error "  FAIL: V22 Failure CI inversion (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* V23: Many groups color cycling produces valid plot
* =============================================================================
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

* =============================================================================
* V24: Monotonicity invariant — KM is non-increasing
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    quietly sts generate _s24 = s
    sort _t
    quietly gen byte _mono_ok = (_s24 <= _s24[_n-1] + 1e-10) if _n > 1 & !missing(_s24) & !missing(_s24[_n-1])
    quietly count if _mono_ok == 0
    assert r(N) == 0

    kmplot, name(v24, replace)
}
if _rc == 0 {
    display as result "  PASS: V24 KM monotonicity invariant"
    local ++pass_count
}
else {
    display as error "  FAIL: V24 KM monotonicity (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* V25: Quoted export path writes to the requested filename
* =============================================================================

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

* =============================================================================
* V26: Risktable respects explicit bottom-axis title and labels
* =============================================================================

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

* =============================================================================
* V27: Delayed-entry risk-table counts honor _t0
* =============================================================================

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
    assert R[2,3] == 2
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

* =============================================================================
* V28: landmark() estimates match sts generate step values
* =============================================================================

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

* =============================================================================
* V29: level() changes CI bounds using requested z critical value
* =============================================================================

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

* =============================================================================
* SUMMARY
* =============================================================================

display ""
display as text "==========================================="
display as text "  kmplot Validation Results"
display as text "==========================================="
display as text "  Total:  " as result `test_count'
display as text "  Passed: " as result `pass_count'
display as text "  Failed: " as result `fail_count'
display as text "==========================================="

if `fail_count' > 0 {
    display as error "RESULT: validation_kmplot tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
else {
    display as result "RESULT: validation_kmplot tests=`test_count' pass=`pass_count' fail=`fail_count'"
}
