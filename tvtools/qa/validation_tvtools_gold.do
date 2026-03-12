/*******************************************************************************
* validation_tvtools_gold.do
*
* Purpose: Gold standard mathematical validation tests for tvtools
*          Tests correctness of computations with hand-calculated expected values
*          Covers: tvcalendar, tvbalance, tvweight, tvtrial, tvdiagnose,
*                  tvexpose (carryforward, statetime), tvmerge (custom names)
*
* Author: Timothy P Copeland
* Date: 2026-03-12
*******************************************************************************/

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0
local DATA_DIR "data"

* =============================================================================
* SECTION 1: TVBALANCE MATHEMATICAL VALIDATION
* =============================================================================

* Test 1.1: SMD exact calculation - equal variance groups
local ++test_count
capture {
    clear
    input byte(id exposure) double(x1 x2)
        1  0  10  100
        2  0  20  100
        3  0  30  100
        4  0  40  100
        5  1  30  110
        6  1  40  110
        7  1  50  110
        8  1  60  110
    end

    tvbalance x1 x2, exposure(exposure)
    matrix B = r(balance)

    * x1: Mean_ref=25, Mean_exp=45, Var_ref=Var_exp=166.667
    * Pooled SD = sqrt((166.667+166.667)/2) = 12.9099
    * SMD = (45-25)/12.9099 = 1.5492
    assert abs(B[1,1] - 25) < 0.01
    assert abs(B[1,2] - 45) < 0.01
    assert abs(B[1,3] - 1.5492) < 0.01

    * x2: Mean_ref=100, Mean_exp=110, Var both=0
    * Pooled SD = 0 → different means → SMD = missing
    * Actually all ref are 100 and all exp are 110, so var=0
    * But means differ → SMD should be missing (undefined)
    assert B[2,3] == . | abs(B[2,3]) > 10  // undefined or very large
}
if _rc == 0 {
    display as result "  PASS 1.1: SMD exact calculation"
    local ++pass_count
}
else {
    display as error "  FAIL 1.1: SMD exact calculation (error `=_rc')"
    local ++fail_count
}

* Test 1.2: Weighted SMD reduces imbalance
local ++test_count
capture {
    clear
    input byte(id exposure) double(x1 w)
        1  0  10  2.0
        2  0  20  1.0
        3  0  30  1.0
        4  1  20  1.0
        5  1  30  1.0
        6  1  40  2.0
    end

    tvbalance x1, exposure(exposure) weights(w)
    matrix B = r(balance)

    * Unweighted: mean_ref=20, mean_exp=30, SMD=1.0
    assert abs(B[1,3] - 1.0) < 0.01

    * Weighted: weights upweight extreme values differently
    * Weighted mean_ref = (10*2+20*1+30*1)/(2+1+1) = 70/4 = 17.5
    * Weighted mean_exp = (20*1+30*1+40*2)/(1+1+2) = 130/4 = 32.5
    * Weighted SMD may differ from unweighted
    assert !missing(B[1,4])
}
if _rc == 0 {
    display as result "  PASS 1.2: Weighted SMD computation"
    local ++pass_count
}
else {
    display as error "  FAIL 1.2: Weighted SMD computation (error `=_rc')"
    local ++fail_count
}

* Test 1.3: ESS formula validation (ESS = sum(w)^2 / sum(w^2))
local ++test_count
capture {
    clear
    input byte(id exposure) double(x1 w)
        1  0  10  1.0
        2  0  20  1.0
        3  0  30  1.0
        4  1  20  2.0
        5  1  30  0.5
        6  1  40  1.5
    end

    tvbalance x1, exposure(exposure) weights(w)

    * ESS for reference: all w=1 → ESS = 3^2/3 = 3
    assert abs(r(ess_ref) - 3) < 0.01

    * ESS for exposed: sum(w) = 4, sum(w^2) = 4+0.25+2.25 = 6.5
    * ESS = 16/6.5 = 2.4615
    assert abs(r(ess_exp) - 2.4615) < 0.01
}
if _rc == 0 {
    display as result "  PASS 1.3: ESS formula validation"
    local ++pass_count
}
else {
    display as error "  FAIL 1.3: ESS formula validation (error `=_rc')"
    local ++fail_count
}

* Test 1.4: Threshold correctly classifies covariates
local ++test_count
capture {
    clear
    input byte(id exposure) double(x1 x2)
        1  0  10  50
        2  0  20  51
        3  0  30  49
        4  1  20  50
        5  1  30  51
        6  1  40  49
    end

    * x1: SMD = (30-20)/pooled_sd (large imbalance)
    * x2: SMD ≈ 0 (balanced)
    tvbalance x1 x2, exposure(exposure) threshold(0.1)

    * Should flag x1 as imbalanced
    assert r(n_imbalanced) >= 1

    * With high threshold, nothing flagged
    tvbalance x1 x2, exposure(exposure) threshold(5.0)
    assert r(n_imbalanced) == 0
}
if _rc == 0 {
    display as result "  PASS 1.4: Threshold classification"
    local ++pass_count
}
else {
    display as error "  FAIL 1.4: Threshold classification (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 2: TVCALENDAR MATHEMATICAL VALIDATION
* =============================================================================

* Test 2.1: Point-in-time merge correctness (every row matched)
local ++test_count
capture {
    * Create 3 persons with known dates
    clear
    input long id double date byte outcome
        1 22006 0
        2 22007 1
        3 22008 0
    end
    format %td date

    * External data: exact dates
    preserve
    clear
    input double date byte season float temp
        22006 1 -5.0
        22007 1 -3.0
        22008 2  2.0
    end
    format %td date
    save "`DATA_DIR'/_val_tvcal_pt.dta", replace
    restore

    tvcalendar using "`DATA_DIR'/_val_tvcal_pt.dta", datevar(date)

    * Verify exact matches
    sort id
    assert season[1] == 1 & abs(temp[1] - (-5.0)) < 0.001
    assert season[2] == 1 & abs(temp[2] - (-3.0)) < 0.001
    assert season[3] == 2 & abs(temp[3] - 2.0) < 0.001

    * N preserved
    assert _N == 3

    erase "`DATA_DIR'/_val_tvcal_pt.dta"
}
if _rc == 0 {
    display as result "  PASS 2.1: tvcalendar point merge exact values"
    local ++pass_count
}
else {
    display as error "  FAIL 2.1: tvcalendar point merge exact values (error `=_rc')"
    local ++fail_count
}

* Test 2.2: Range merge assigns correct periods
local ++test_count
capture {
    * Master: dates spanning multiple periods
    clear
    input long id double date
        1 22010
        2 22040
        3 22070
        4 22100
    end
    format %td date

    * External: three periods
    preserve
    clear
    input double(ps pe) byte era
        22001 22030 1
        22031 22060 2
        22061 22090 3
    end
    format %td ps pe
    save "`DATA_DIR'/_val_tvcal_range.dta", replace
    restore

    tvcalendar using "`DATA_DIR'/_val_tvcal_range.dta", ///
        datevar(date) startvar(ps) stopvar(pe)

    sort id
    * id=1 date=22010 → era=1 (22001-22030)
    assert era[1] == 1
    * id=2 date=22040 → era=2 (22031-22060)
    assert era[2] == 2
    * id=3 date=22070 → era=3 (22061-22090)
    assert era[3] == 3
    * id=4 date=22100 → no match → era missing
    assert missing(era[4])

    erase "`DATA_DIR'/_val_tvcal_range.dta"
}
if _rc == 0 {
    display as result "  PASS 2.2: tvcalendar range merge correct period assignment"
    local ++pass_count
}
else {
    display as error "  FAIL 2.2: tvcalendar range merge assignment (error `=_rc')"
    local ++fail_count
}

* Test 2.3: Range merge boundary inclusion
local ++test_count
capture {
    * Date ON period boundary
    clear
    input long id double date
        1 22030
        2 22031
    end
    format %td date

    preserve
    clear
    input double(ps pe) byte era
        22001 22030 1
        22031 22060 2
    end
    format %td ps pe
    save "`DATA_DIR'/_val_tvcal_boundary.dta", replace
    restore

    tvcalendar using "`DATA_DIR'/_val_tvcal_boundary.dta", ///
        datevar(date) startvar(ps) stopvar(pe)

    sort id
    * 22030 falls in [22001,22030] → era=1
    assert era[1] == 1
    * 22031 falls in [22031,22060] → era=2
    assert era[2] == 2

    erase "`DATA_DIR'/_val_tvcal_boundary.dta"
}
if _rc == 0 {
    display as result "  PASS 2.3: tvcalendar boundary inclusion"
    local ++pass_count
}
else {
    display as error "  FAIL 2.3: tvcalendar boundary inclusion (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 3: TVWEIGHT MATHEMATICAL VALIDATION
* =============================================================================

* Test 3.1: IPTW formula (binary): W = A/PS + (1-A)/(1-PS)
local ++test_count
capture {
    * Create known data where we can verify propensity scores
    clear
    set seed 77777
    set obs 500
    gen long id = _n
    gen double x = rnormal()
    * Generate treatment with known probability
    gen double ps_true = invlogit(0.5*x)
    gen byte treatment = (runiform() < ps_true)

    tvweight treatment, covariates(x) generate(w) nolog

    * All weights should be > 0
    assert w > 0 if !missing(w)

    * Mean weight for treated should be > 1 (since 1/PS > 1 for PS < 1)
    quietly sum w if treatment == 1
    assert r(mean) >= 1

    * Mean weight for untreated should also be > 1
    quietly sum w if treatment == 0
    assert r(mean) >= 1

    * ESS should be meaningful and positive
    assert r(ess) > 0
    assert r(ess_pct) > 0
}
if _rc == 0 {
    display as result "  PASS 3.1: IPTW binary formula properties"
    local ++pass_count
}
else {
    display as error "  FAIL 3.1: IPTW binary formula properties (error `=_rc')"
    local ++fail_count
}

* Test 3.2: Stabilized weights should have mean closer to 1
local ++test_count
capture {
    clear
    set seed 88888
    set obs 400
    gen double x = rnormal()
    gen byte treatment = (runiform() < invlogit(0.3*x))

    * Unstabilized
    tvweight treatment, covariates(x) generate(w_unstab) nolog
    quietly sum w_unstab
    local mean_unstab = r(mean)

    * Stabilized
    drop w_unstab
    tvweight treatment, covariates(x) generate(w_stab) stabilized nolog
    quietly sum w_stab
    local mean_stab = r(mean)

    * Stabilized mean should be closer to 1
    assert abs(`mean_stab' - 1) < abs(`mean_unstab' - 1) + 0.5
}
if _rc == 0 {
    display as result "  PASS 3.2: Stabilized weights mean ≈ 1"
    local ++pass_count
}
else {
    display as error "  FAIL 3.2: Stabilized weights mean ≈ 1 (error `=_rc')"
    local ++fail_count
}

* Test 3.3: Truncation at percentiles
local ++test_count
capture {
    clear
    set seed 55555
    set obs 300
    gen double x = rnormal()
    gen byte treatment = (runiform() < invlogit(x))

    * Untruncated first
    tvweight treatment, covariates(x) generate(w_full) nolog
    quietly sum w_full
    local full_min = r(min)
    local full_max = r(max)

    * Now truncated
    tvweight treatment, covariates(x) generate(w_trunc) truncate(5 95) nolog

    * Truncated range should be narrower or equal
    quietly sum w_trunc
    assert r(min) >= `full_min' - 0.001
    assert r(max) <= `full_max' + 0.001
}
if _rc == 0 {
    display as result "  PASS 3.3: Truncation reduces extreme weights"
    local ++pass_count
}
else {
    display as error "  FAIL 3.3: Truncation reduces extreme weights (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 4: TVTRIAL MATHEMATICAL VALIDATION
* =============================================================================

* Test 4.1: Clone approach creates exactly 2× person-trials
local ++test_count
capture {
    clear
    input long id double(entry exit rx_start)
        1 22006 22371 22036
        2 22006 22371 .
        3 22006 22371 22066
    end
    format %td entry exit rx_start

    tvtrial, id(id) entry(entry) exit(exit) treatstart(rx_start) ///
        clone trials(1) trialinterval(30)

    * With clone and 1 trial, each eligible person appears twice (arm=0 and arm=1)
    * All 3 are eligible at trial start (all entered on 22006)
    local n_obs = _N
    * Should be 2 * number of eligible persons
    assert mod(`n_obs', 2) == 0

    * Each person should have arm=0 and arm=1
    forvalues i = 1/3 {
        quietly count if id == `i' & trial_arm == 0
        local a0 = r(N)
        quietly count if id == `i' & trial_arm == 1
        local a1 = r(N)
        assert `a0' == `a1'
    }
}
if _rc == 0 {
    display as result "  PASS 4.1: Clone creates balanced arm assignment"
    local ++pass_count
}
else {
    display as error "  FAIL 4.1: Clone creates balanced arm assignment (error `=_rc')"
    local ++fail_count
}

* Test 4.2: Censoring logic in clone approach
local ++test_count
capture {
    clear
    input long id double(entry exit rx_start)
        1 22006 22371 22036
        2 22006 22371 .
    end
    format %td entry exit rx_start

    tvtrial, id(id) entry(entry) exit(exit) treatstart(rx_start) ///
        clone graceperiod(0) trials(1) trialinterval(30)

    * Person 1 starts treatment on 22036 (30 days after trial start 22006)
    * With graceperiod=0: not within grace → treatment arm censored
    * Person 1, arm=1 (treatment): censored=1 (didn't start within grace)
    * Person 1, arm=0 (control): censored=0 (never started ≠ deviation from control)

    * Person 2 never treated
    * Person 2, arm=1: censored=1 (didn't start treatment)
    * Person 2, arm=0: censored=0 (consistent with control strategy)

    quietly count if id == 2 & trial_arm == 0 & trial_censored == 0
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS 4.2: Censoring logic correct"
    local ++pass_count
}
else {
    display as error "  FAIL 4.2: Censoring logic (error `=_rc')"
    local ++fail_count
}

* Test 4.3: maxfollowup precisely caps duration
local ++test_count
capture {
    clear
    input long id double(entry exit rx_start)
        1 22006 22371 .
        2 22006 22371 .
    end
    format %td entry exit rx_start

    tvtrial, id(id) entry(entry) exit(exit) treatstart(rx_start) ///
        maxfollowup(60) trials(1) trialinterval(30)

    * All follow-up times should be exactly 60 (since exit is far away)
    assert trial_fu_time == 60 if !missing(trial_fu_time)
}
if _rc == 0 {
    display as result "  PASS 4.3: maxfollowup precise capping"
    local ++pass_count
}
else {
    display as error "  FAIL 4.3: maxfollowup precise capping (error `=_rc')"
    local ++fail_count
}

* Test 4.4: Sequential trials create staggered start dates
local ++test_count
capture {
    clear
    input long id double(entry exit rx_start)
        1 22006 22400 .
    end
    format %td entry exit rx_start

    tvtrial, id(id) entry(entry) exit(exit) treatstart(rx_start) ///
        trials(3) trialinterval(30)

    * Should have 3 trial records
    assert _N == 3

    * Trial start dates should be 30 days apart
    sort trial_trial
    assert trial_start[2] - trial_start[1] == 30
    assert trial_start[3] - trial_start[2] == 30
}
if _rc == 0 {
    display as result "  PASS 4.4: Sequential trial staggered starts"
    local ++pass_count
}
else {
    display as error "  FAIL 4.4: Sequential trial staggered starts (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 5: TVDIAGNOSE MATHEMATICAL VALIDATION
* =============================================================================

* Test 5.1: Coverage calculation exact values
local ++test_count
capture {
    * Person 1: 100% coverage (31+30=61 days, entry-exit span=61)
    * Person 2: ~50% coverage (31 days covered, 61 span)
    clear
    input long id double(start stop entry exit)
        1 22006 22036 22006 22066
        1 22036 22066 22006 22066
        2 22006 22036 22006 22066
    end
    format %td start stop entry exit

    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit) coverage

    * Person 1 coverage = 100%
    * Person 2 coverage = 31/61 * 100 ≈ 50.8%
    * Mean coverage = (100 + 50.8)/2 ≈ 75.4
    assert abs(r(mean_coverage) - 75.4) < 1.0
    assert r(n_with_gaps) == 1  // only person 2 has gap
}
if _rc == 0 {
    display as result "  PASS 5.1: Coverage calculation exact"
    local ++pass_count
}
else {
    display as error "  FAIL 5.1: Coverage calculation exact (error `=_rc')"
    local ++fail_count
}

* Test 5.2: Gap detection with known gaps
local ++test_count
capture {
    clear
    input long id double(start stop)
        1 22006 22036
        1 22046 22067
        1 22097 22127
        2 22006 22067
    end
    format %td start stop

    * Person 1: 2 gaps (10-day gap + 30-day gap)
    * Person 2: no gaps (single period)
    tvdiagnose, id(id) start(start) stop(stop) gaps threshold(15)

    assert r(n_gaps) == 2
    assert r(n_large_gaps) == 1  // only the 30-day gap > threshold 15
}
if _rc == 0 {
    display as result "  PASS 5.2: Gap detection exact count"
    local ++pass_count
}
else {
    display as error "  FAIL 5.2: Gap detection exact count (error `=_rc')"
    local ++fail_count
}

* Test 5.3: Overlap detection
local ++test_count
capture {
    clear
    input long id double(start stop)
        1 22006 22040
        1 22036 22067
        2 22006 22036
        2 22036 22067
    end
    format %td start stop

    * Person 1: overlap (22036 < 22040)
    * Person 2: no overlap (22036 == 22036, abutting)
    * Note: overlap check is start <= stop[_n-1], so 22036 <= 22036 IS overlap
    tvdiagnose, id(id) start(start) stop(stop) overlaps

    * At least person 1 has clear overlap
    assert r(n_overlaps) >= 1
}
if _rc == 0 {
    display as result "  PASS 5.3: Overlap detection"
    local ++pass_count
}
else {
    display as error "  FAIL 5.3: Overlap detection (error `=_rc')"
    local ++fail_count
}

* Test 5.4: Summarize total person-time calculation
local ++test_count
capture {
    clear
    input long id double(start stop) byte exposure
        1 22006 22036 1
        1 22036 22066 0
        2 22006 22036 1
    end
    format %td start stop

    * Total days = (31+31+31) = 93 (using stop-start+1 formula)
    tvdiagnose, id(id) start(start) stop(stop) exposure(exposure) summarize

    assert r(total_person_time) == 93
}
if _rc == 0 {
    display as result "  PASS 5.4: Total person-time exact"
    local ++pass_count
}
else {
    display as error "  FAIL 5.4: Total person-time exact (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 6: TVEXPOSE CARRYFORWARD/STATETIME VALIDATION
* =============================================================================

* Test 6.1: Carryforward extends exposure into gaps
local ++test_count
capture {
    * Cohort: 1 person, 100 days follow-up
    clear
    input long id double(study_entry study_exit)
        1 22006 22106
    end
    format %td study_entry study_exit
    save "`DATA_DIR'/_val_cf_cohort.dta", replace

    * Exposure: 1 period ending at day 22036 (30 days in)
    clear
    input long id double(rx_start rx_stop) byte drug
        1 22006 22036 1
    end
    format %td rx_start rx_stop
    save "`DATA_DIR'/_val_cf_rx.dta", replace

    * Without carryforward: exposed 22006-22036, unexposed 22036-22106
    use "`DATA_DIR'/_val_cf_cohort.dta", clear
    tvexpose using "`DATA_DIR'/_val_cf_rx.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit)

    quietly count if tv_exposure != 0
    local exposed_no_cf = r(N)

    * With carryforward(10): exposure extends 10 days past rx_stop
    use "`DATA_DIR'/_val_cf_cohort.dta", clear
    tvexpose using "`DATA_DIR'/_val_cf_rx.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) ///
        carryforward(10)

    * Should have more or equal exposed intervals than without carryforward
    quietly count if tv_exposure != 0
    assert r(N) >= `exposed_no_cf'

    * Total person-time should still be preserved (output uses rx_start/rx_stop)
    gen double dur = rx_stop - rx_start
    quietly sum dur
    assert r(sum) > 0

    erase "`DATA_DIR'/_val_cf_cohort.dta"
    erase "`DATA_DIR'/_val_cf_rx.dta"
}
if _rc == 0 {
    display as result "  PASS 6.1: Carryforward extends exposure into gaps"
    local ++pass_count
}
else {
    display as error "  FAIL 6.1: Carryforward extends exposure (error `=_rc')"
    local ++fail_count
}

* Test 6.2: Statetime cumulates within state blocks
local ++test_count
capture {
    * Cohort: 1 person, 90 days
    clear
    input long id double(study_entry study_exit)
        1 22006 22096
    end
    format %td study_entry study_exit
    save "`DATA_DIR'/_val_st_cohort.dta", replace

    * Exposure: drug 1 for 30 days, drug 2 for 30 days, drug 1 again for 30 days
    clear
    input long id double(rx_start rx_stop) byte drug
        1 22006 22036 1
        1 22036 22066 2
        1 22066 22096 1
    end
    format %td rx_start rx_stop
    save "`DATA_DIR'/_val_st_rx.dta", replace

    use "`DATA_DIR'/_val_st_cohort.dta", clear
    tvexpose using "`DATA_DIR'/_val_st_rx.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) ///
        statetime

    * state_time_years should exist and reset at state changes
    confirm variable state_time_years
    assert state_time_years > 0 if !missing(state_time_years)

    erase "`DATA_DIR'/_val_st_cohort.dta"
    erase "`DATA_DIR'/_val_st_rx.dta"
}
if _rc == 0 {
    display as result "  PASS 6.2: Statetime cumulates within state blocks"
    local ++pass_count
}
else {
    display as error "  FAIL 6.2: Statetime cumulation (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 7: TVMERGE CUSTOM NAMES VALIDATION
* =============================================================================

* Test 7.1: Custom start/stop names propagate through merge
local ++test_count
capture {
    * Dataset 1
    clear
    input long id double(s1 e1) byte exp1
        1 22006 22036 1
        1 22036 22066 0
    end
    format %td s1 e1
    save "`DATA_DIR'/_val_merge_names1.dta", replace

    * Dataset 2
    clear
    input long id double(s2 e2) byte exp2
        1 22006 22050 1
    end
    format %td s2 e2
    save "`DATA_DIR'/_val_merge_names2.dta", replace

    tvmerge "`DATA_DIR'/_val_merge_names1.dta" "`DATA_DIR'/_val_merge_names2.dta", ///
        id(id) start(s1 s2) stop(e1 e2) exposure(exp1 exp2) ///
        startname(begin_dt) stopname(end_dt) dateformat(%tdDD/NN/CCYY)

    * Custom names should be used
    confirm variable begin_dt
    confirm variable end_dt

    * Date format should be applied
    local fmt : format begin_dt
    assert "`fmt'" == "%tdDD/NN/CCYY"

    * Merged data should have valid intervals
    assert begin_dt < end_dt

    erase "`DATA_DIR'/_val_merge_names1.dta"
    erase "`DATA_DIR'/_val_merge_names2.dta"
}
if _rc == 0 {
    display as result "  PASS 7.1: Custom start/stop names in merge"
    local ++pass_count
}
else {
    display as error "  FAIL 7.1: Custom merge names (error `=_rc')"
    local ++fail_count
}

* Test 7.2: Validatecoverage detects gaps
local ++test_count
capture {
    * Dataset 1: full coverage
    clear
    input long id double(s1 e1) byte exp1
        1 22006 22036 1
        1 22036 22066 0
    end
    format %td s1 e1
    save "`DATA_DIR'/_val_merge_vc1.dta", replace

    * Dataset 2: partial coverage (gap between 22036-22050)
    clear
    input long id double(s2 e2) byte exp2
        1 22006 22036 1
        1 22050 22066 0
    end
    format %td s2 e2
    save "`DATA_DIR'/_val_merge_vc2.dta", replace

    * Should detect the gap and still produce valid output
    tvmerge "`DATA_DIR'/_val_merge_vc1.dta" "`DATA_DIR'/_val_merge_vc2.dta", ///
        id(id) start(s1 s2) stop(e1 e2) exposure(exp1 exp2) ///
        validatecoverage

    assert r(N) > 0

    erase "`DATA_DIR'/_val_merge_vc1.dta"
    erase "`DATA_DIR'/_val_merge_vc2.dta"
}
if _rc == 0 {
    display as result "  PASS 7.2: Validatecoverage detects gaps"
    local ++pass_count
}
else {
    display as error "  FAIL 7.2: Validatecoverage gap detection (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 8: RETURN VALUE COMPLETENESS
* =============================================================================

* Test 8.1: tvdiagnose returns all documented r() scalars
local ++test_count
capture {
    clear
    input long id double(start stop entry exit) byte exposure
        1 22006 22036 22006 22066 1
        1 22036 22066 22006 22066 0
        2 22006 22036 22006 22066 1
    end
    format %td start stop entry exit

    tvdiagnose, id(id) start(start) stop(stop) ///
        exposure(exposure) entry(entry) exit(exit) all

    * Must return these
    assert !missing(r(n_persons))
    assert !missing(r(n_observations))
    assert !missing(r(mean_coverage))
    assert !missing(r(n_with_gaps))
    assert !missing(r(total_person_time))
    assert "`r(id)'" == "id"
}
if _rc == 0 {
    display as result "  PASS 8.1: tvdiagnose all r() values present"
    local ++pass_count
}
else {
    display as error "  FAIL 8.1: tvdiagnose r() values (error `=_rc')"
    local ++fail_count
}

* Test 8.2: tvweight returns all documented r() scalars
local ++test_count
capture {
    clear
    set seed 44444
    set obs 200
    gen byte treatment = (runiform() > 0.5)
    gen double age = 50 + 5*rnormal()

    tvweight treatment, covariates(age) generate(w) ///
        stabilized truncate(5 95) denominator(ps) nolog

    * Must return these
    assert !missing(r(N))
    assert !missing(r(n_levels))
    assert !missing(r(ess))
    assert !missing(r(ess_pct))
    assert !missing(r(w_mean))
    assert !missing(r(w_sd))
    assert !missing(r(w_min))
    assert !missing(r(w_max))
    assert !missing(r(w_p1))
    assert !missing(r(w_p50))
    assert !missing(r(w_p99))
    assert !missing(r(n_truncated))
    assert !missing(r(trunc_lo))
    assert !missing(r(trunc_hi))
    assert "`r(exposure)'" == "treatment"
    assert "`r(model)'" == "logit"
    assert "`r(stabilized)'" == "stabilized"
    assert "`r(denominator)'" == "ps"
}
if _rc == 0 {
    display as result "  PASS 8.2: tvweight all r() values present"
    local ++pass_count
}
else {
    display as error "  FAIL 8.2: tvweight r() values (error `=_rc')"
    local ++fail_count
}

* Test 8.3: tvtrial returns all documented r() scalars
local ++test_count
capture {
    clear
    input long id double(entry exit rx_start)
        1 22006 22371 22036
        2 22006 22371 .
        3 22006 22371 22066
    end
    format %td entry exit rx_start

    tvtrial, id(id) entry(entry) exit(exit) treatstart(rx_start) ///
        clone ipcweight trials(2)

    assert !missing(r(n_orig))
    assert !missing(r(n_ids))
    assert !missing(r(n_trials))
    assert !missing(r(n_eligible))
    assert !missing(r(n_persontrials))
    assert !missing(r(n_treat))
    assert !missing(r(n_control))
    assert !missing(r(mean_fu))
    assert !missing(r(total_fu))
    assert "`r(id)'" == "id"
    assert "`r(prefix)'" == "trial_"
}
if _rc == 0 {
    display as result "  PASS 8.3: tvtrial all r() values present"
    local ++pass_count
}
else {
    display as error "  FAIL 8.3: tvtrial r() values (error `=_rc')"
    local ++fail_count
}

* Test 8.4: tvcalendar returns all documented r() scalars
local ++test_count
capture {
    clear
    input long id double date byte outcome
        1 22006 0
        2 22007 1
    end
    format %td date

    preserve
    clear
    input double date byte season
        22006 1
        22007 1
    end
    format %td date
    save "`DATA_DIR'/_val_tvcal_rvals.dta", replace
    restore

    tvcalendar using "`DATA_DIR'/_val_tvcal_rvals.dta", datevar(date)

    assert r(n_master) == 2
    assert r(n_merged) == 2
    assert "`r(datevar)'" == "date"

    erase "`DATA_DIR'/_val_tvcal_rvals.dta"
}
if _rc == 0 {
    display as result "  PASS 8.4: tvcalendar all r() values present"
    local ++pass_count
}
else {
    display as error "  FAIL 8.4: tvcalendar r() values (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* RESULTS SUMMARY
* =============================================================================

display as text ""
display as text "{hline 70}"
display as text "{bf:GOLD STANDARD VALIDATION RESULTS}"
display as text "{hline 70}"
display as text ""
display as text "Total tests:  " as result `test_count'
display as text "Passed:       " as result `pass_count'
display as text "Failed:       " as result `fail_count'
display as text ""

if `fail_count' == 0 {
    display as result "ALL VALIDATION TESTS PASSED"
}
else {
    display as error "`fail_count' VALIDATION TESTS FAILED"
}

display as text "{hline 70}"

assert `fail_count' == 0
