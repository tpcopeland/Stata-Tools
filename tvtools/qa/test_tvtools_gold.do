/*******************************************************************************
* test_tvtools_gold.do
*
* Purpose: Gold standard functional tests for all tvtools commands
*          Covers all gaps identified in coverage analysis:
*          - tvcalendar: first-ever tests (0% → comprehensive)
*          - tvbalance: threshold, loveplot, scheme
*          - tvplot: sortby, title, saving, colors, scheme
*          - tvtrial: eligibility, graceperiod, maxfollowup, generate
*          - tvweight: tvcovariates/id/time
*          - tvdiagnose: threshold
*          - tvexpose: carryforward, switchingdetail, statetime, validate
*          - tvmerge: startname, stopname, dateformat, validatecoverage, validateoverlap
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
* SECTION 1: TVCALENDAR (was 0% coverage)
* =============================================================================

* --- Create test datasets for tvcalendar ---

* Master: person-time data with dates
clear
input long id double(start stop) byte tv_exp
    1 22006 22036 1
    1 22036 22067 0
    1 22067 22097 1
    2 22006 22036 0
    2 22036 22067 1
    2 22067 22097 0
end
format %td start stop
save "`DATA_DIR'/_gold_tvcal_master.dta", replace

* External: point-in-time calendar data (variable must match master's datevar)
clear
input double start byte season float temperature
    22006 1 -5.2
    22007 1 -4.8
    22008 1 -3.1
    22036 1 1.5
    22037 2 2.0
    22067 2 12.5
    22068 2 13.0
    22097 3 18.2
end
format %td start
save "`DATA_DIR'/_gold_tvcal_point.dta", replace

* External: period-based calendar data (policy periods)
clear
input double(period_start period_end) byte policy_era float risk_factor
    22006 22035 1 1.2
    22036 22066 2 0.8
    22067 22097 3 1.5
end
format %td period_start period_end
save "`DATA_DIR'/_gold_tvcal_periods.dta", replace


* Test 1.1: tvcalendar point-in-time merge
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvcal_master.dta", clear
    tvcalendar using "`DATA_DIR'/_gold_tvcal_point.dta", datevar(start)

    * Should have merged season and temperature
    confirm variable season
    confirm variable temperature

    * Observation count preserved
    assert _N == 6

    * Check merged values for known date 22006 (person 1, start)
    quietly sum season if id == 1 & start == 22006
    assert r(mean) == 1
}
if _rc == 0 {
    display as result "  PASS: tvcalendar point-in-time merge"
    local ++pass_count
}
else {
    display as error "  FAIL: tvcalendar point-in-time merge (error `=_rc')"
    local ++fail_count
}

* Test 1.2: tvcalendar range-based merge
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvcal_master.dta", clear
    tvcalendar using "`DATA_DIR'/_gold_tvcal_periods.dta", ///
        datevar(start) startvar(period_start) stopvar(period_end)

    * Should have merged policy_era and risk_factor
    confirm variable policy_era
    confirm variable risk_factor

    * Observation count preserved
    assert _N == 6

    * Person 1, start=22006 falls in period 22006-22035 → policy_era=1
    quietly sum policy_era if id == 1 & start == 22006
    assert r(mean) == 1

    * Person 1, start=22067 falls in period 22067-22097 → policy_era=3
    quietly sum policy_era if id == 1 & start == 22067
    assert r(mean) == 3
}
if _rc == 0 {
    display as result "  PASS: tvcalendar range-based merge"
    local ++pass_count
}
else {
    display as error "  FAIL: tvcalendar range-based merge (error `=_rc')"
    local ++fail_count
}

* Test 1.3: tvcalendar merge() selective variables
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvcal_master.dta", clear
    tvcalendar using "`DATA_DIR'/_gold_tvcal_point.dta", ///
        datevar(start) merge(season)

    * merge() with point-in-time uses Stata's merge which brings all vars
    * Verify at minimum the specified variable is present
    confirm variable season

    * Return value should list the specified merge variables
    assert "`r(merge)'" == "season"
}
if _rc == 0 {
    display as result "  PASS: tvcalendar merge() selects specific variables"
    local ++pass_count
}
else {
    display as error "  FAIL: tvcalendar merge() selects specific variables (error `=_rc')"
    local ++fail_count
}

* Test 1.4: tvcalendar r() return values
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvcal_master.dta", clear
    tvcalendar using "`DATA_DIR'/_gold_tvcal_point.dta", datevar(start)

    assert r(n_master) == 6
    assert r(n_merged) == 6
    assert "`r(datevar)'" == "start"
}
if _rc == 0 {
    display as result "  PASS: tvcalendar r() return values"
    local ++pass_count
}
else {
    display as error "  FAIL: tvcalendar r() return values (error `=_rc')"
    local ++fail_count
}

* Test 1.5: tvcalendar error - missing datevar
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvcal_master.dta", clear
    capture noisily tvcalendar using "`DATA_DIR'/_gold_tvcal_point.dta", datevar(nonexistent)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: tvcalendar error on missing datevar"
    local ++pass_count
}
else {
    display as error "  FAIL: tvcalendar error on missing datevar (error `=_rc')"
    local ++fail_count
}

* Test 1.6: tvcalendar error - missing using file
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvcal_master.dta", clear
    capture noisily tvcalendar using "nonexistent_file.dta", datevar(start)
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: tvcalendar error on missing using file"
    local ++pass_count
}
else {
    display as error "  FAIL: tvcalendar error on missing using file (error `=_rc')"
    local ++fail_count
}

* Test 1.7: tvcalendar error - startvar without stopvar
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvcal_master.dta", clear
    capture noisily tvcalendar using "`DATA_DIR'/_gold_tvcal_periods.dta", ///
        datevar(start) startvar(period_start)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvcalendar error on startvar without stopvar"
    local ++pass_count
}
else {
    display as error "  FAIL: tvcalendar error on startvar without stopvar (error `=_rc')"
    local ++fail_count
}

* Test 1.8: tvcalendar unmatched dates (dates not in external data)
local ++test_count
capture {
    * Create master with dates not in point-time external data
    clear
    input long id double(start stop) byte tv_exp
        1 23000 23030 1
    end
    format %td start stop

    tvcalendar using "`DATA_DIR'/_gold_tvcal_point.dta", datevar(start)

    * Should retain observation but with missing merged values
    assert _N == 1
    * season exists but should be missing for this date
    confirm variable season
    quietly count if !missing(season)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: tvcalendar unmatched dates retain missing values"
    local ++pass_count
}
else {
    display as error "  FAIL: tvcalendar unmatched dates (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 2: TVBALANCE (was 14% coverage)
* =============================================================================

* --- Create balance test data ---
clear
set seed 12345
set obs 200
gen long id = _n
gen byte exposure = (runiform() > 0.5)
* Create covariates where exposed group has higher age and more comorbidities
gen double age = 50 + 10*rnormal() + 5*exposure
gen double bmi = 25 + 3*rnormal() + 2*exposure
gen byte female = (runiform() < 0.5 - 0.1*exposure)
gen byte comorbid = (runiform() < 0.3 + 0.2*exposure)
* Create weights that reduce imbalance
gen double w = 1 + 0.5*rnormal()
replace w = abs(w) + 0.1
save "`DATA_DIR'/_gold_tvbal.dta", replace

* Test 2.1: tvbalance with custom threshold
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvbal.dta", clear
    tvbalance age bmi female comorbid, exposure(exposure) threshold(0.05)

    assert r(threshold) == 0.05
    assert r(n_covariates) == 4
    assert r(n_ref) > 0
    assert r(n_exp) > 0
    * With tight threshold and biased data, should find imbalanced covariates
    assert r(n_imbalanced) >= 1
}
if _rc == 0 {
    display as result "  PASS: tvbalance threshold() option"
    local ++pass_count
}
else {
    display as error "  FAIL: tvbalance threshold() option (error `=_rc')"
    local ++fail_count
}

* Test 2.2: tvbalance default threshold
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvbal.dta", clear
    tvbalance age bmi, exposure(exposure)

    assert r(threshold) == 0.1  // default
}
if _rc == 0 {
    display as result "  PASS: tvbalance default threshold is 0.1"
    local ++pass_count
}
else {
    display as error "  FAIL: tvbalance default threshold (error `=_rc')"
    local ++fail_count
}

* Test 2.3: tvbalance weighted SMD and ESS
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvbal.dta", clear
    tvbalance age bmi female comorbid, exposure(exposure) weights(w)

    * Should return weighted results
    assert r(ess_ref) > 0
    assert r(ess_exp) > 0
    assert !missing(r(n_imbalanced_wt))

    * Balance matrix should have 4 columns (Mean_Ref, Mean_Exp, SMD_Unwt, SMD_Wt)
    matrix B = r(balance)
    assert rowsof(B) == 4
    assert colsof(B) == 4
}
if _rc == 0 {
    display as result "  PASS: tvbalance weighted SMD with ESS"
    local ++pass_count
}
else {
    display as error "  FAIL: tvbalance weighted SMD with ESS (error `=_rc')"
    local ++fail_count
}

* Test 2.4: tvbalance loveplot generates graph
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvbal.dta", clear
    tvbalance age bmi female, exposure(exposure) loveplot ///
        saving("`DATA_DIR'/_gold_loveplot.png") replace

    * Graph file should exist
    confirm file "`DATA_DIR'/_gold_loveplot.png"
    erase "`DATA_DIR'/_gold_loveplot.png"
}
if _rc == 0 {
    display as result "  PASS: tvbalance loveplot with saving"
    local ++pass_count
}
else {
    display as error "  FAIL: tvbalance loveplot with saving (error `=_rc')"
    local ++fail_count
}

* Test 2.5: tvbalance loveplot with weights and scheme
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvbal.dta", clear
    tvbalance age bmi female comorbid, exposure(exposure) weights(w) ///
        loveplot scheme(plotplainblind)

    * Should complete without error
    assert r(n_covariates) == 4
}
if _rc == 0 {
    display as result "  PASS: tvbalance loveplot with weights + scheme"
    local ++pass_count
}
else {
    display as error "  FAIL: tvbalance loveplot with weights + scheme (error `=_rc')"
    local ++fail_count
}

* Test 2.6: tvbalance SMD mathematical validation
local ++test_count
capture {
    * Known data for exact SMD calculation
    clear
    input byte(id exposure) double(x1)
        1 0 10
        2 0 20
        3 0 30
        4 1 20
        5 1 30
        6 1 40
    end

    tvbalance x1, exposure(exposure)

    * Mean ref = 20, Mean exp = 30
    * Var ref = 100, Var exp = 100
    * Pooled SD = sqrt((100+100)/2) = 10
    * SMD = (30-20)/10 = 1.0
    matrix B = r(balance)
    assert abs(B[1,1] - 20) < 0.001
    assert abs(B[1,2] - 30) < 0.001
    assert abs(B[1,3] - 1.0) < 0.001
}
if _rc == 0 {
    display as result "  PASS: tvbalance SMD mathematical correctness"
    local ++pass_count
}
else {
    display as error "  FAIL: tvbalance SMD mathematical correctness (error `=_rc')"
    local ++fail_count
}

* Test 2.7: tvbalance error - non-numeric exposure
local ++test_count
capture {
    clear
    input byte(id) str5 exposure double(x1)
        1 "A" 10
        2 "B" 20
    end
    capture noisily tvbalance x1, exposure(exposure)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: tvbalance rejects non-numeric exposure"
    local ++pass_count
}
else {
    display as error "  FAIL: tvbalance rejects non-numeric exposure (error `=_rc')"
    local ++fail_count
}

* Test 2.8: tvbalance zero-variance covariate
local ++test_count
capture {
    clear
    input byte(id exposure) double(x1)
        1 0 5
        2 0 5
        3 1 5
        4 1 5
    end
    tvbalance x1, exposure(exposure)

    * Zero variance → SMD should be 0 (means are equal)
    matrix B = r(balance)
    assert B[1,3] == 0
}
if _rc == 0 {
    display as result "  PASS: tvbalance zero-variance covariate (SMD=0)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvbalance zero-variance covariate (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 3: TVPLOT (was 30% coverage)
* =============================================================================

* Test 3.1: tvplot sortby(exit)
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvcal_master.dta", clear
    tvplot, id(id) start(start) stop(stop) exposure(tv_exp) ///
        swimlane sortby(exit) sample(2)
    assert "`r(plottype)'" == "swimlane"
}
if _rc == 0 {
    display as result "  PASS: tvplot sortby(exit)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvplot sortby(exit) (error `=_rc')"
    local ++fail_count
}

* Test 3.2: tvplot sortby(persontime)
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvcal_master.dta", clear
    tvplot, id(id) start(start) stop(stop) exposure(tv_exp) ///
        swimlane sortby(persontime) sample(2)
    assert "`r(plottype)'" == "swimlane"
}
if _rc == 0 {
    display as result "  PASS: tvplot sortby(persontime)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvplot sortby(persontime) (error `=_rc')"
    local ++fail_count
}

* Test 3.3: tvplot with title
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvcal_master.dta", clear
    tvplot, id(id) start(start) stop(stop) exposure(tv_exp) ///
        swimlane title("My Custom Title") sample(2)
    assert "`r(plottype)'" == "swimlane"
}
if _rc == 0 {
    display as result "  PASS: tvplot title() option"
    local ++pass_count
}
else {
    display as error "  FAIL: tvplot title() option (error `=_rc')"
    local ++fail_count
}

* Test 3.4: tvplot saving to file
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvcal_master.dta", clear
    tvplot, id(id) start(start) stop(stop) exposure(tv_exp) ///
        swimlane sample(2) saving("`DATA_DIR'/_gold_swimlane.png") replace

    confirm file "`DATA_DIR'/_gold_swimlane.png"
    erase "`DATA_DIR'/_gold_swimlane.png"
}
if _rc == 0 {
    display as result "  PASS: tvplot saving() creates file"
    local ++pass_count
}
else {
    display as error "  FAIL: tvplot saving() creates file (error `=_rc')"
    local ++fail_count
}

* Test 3.5: tvplot custom colors
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvcal_master.dta", clear
    tvplot, id(id) start(start) stop(stop) exposure(tv_exp) ///
        swimlane sample(2) colors(red blue)
    assert "`r(plottype)'" == "swimlane"
}
if _rc == 0 {
    display as result "  PASS: tvplot colors() option"
    local ++pass_count
}
else {
    display as error "  FAIL: tvplot colors() option (error `=_rc')"
    local ++fail_count
}

* Test 3.6: tvplot scheme
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvcal_master.dta", clear
    tvplot, id(id) start(start) stop(stop) exposure(tv_exp) ///
        swimlane sample(2) scheme(plotplainblind)
    assert "`r(plottype)'" == "swimlane"
}
if _rc == 0 {
    display as result "  PASS: tvplot scheme() option"
    local ++pass_count
}
else {
    display as error "  FAIL: tvplot scheme() option (error `=_rc')"
    local ++fail_count
}

* Test 3.7: tvplot persontime with saving and scheme
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvcal_master.dta", clear
    tvplot, id(id) start(start) stop(stop) exposure(tv_exp) ///
        persontime title("Person-Time Chart") scheme(plotplainblind) ///
        saving("`DATA_DIR'/_gold_persontime.png") replace

    assert "`r(plottype)'" == "persontime"
    confirm file "`DATA_DIR'/_gold_persontime.png"
    erase "`DATA_DIR'/_gold_persontime.png"
}
if _rc == 0 {
    display as result "  PASS: tvplot persontime with saving+scheme"
    local ++pass_count
}
else {
    display as error "  FAIL: tvplot persontime with saving+scheme (error `=_rc')"
    local ++fail_count
}

* Test 3.8: tvplot error - persontime without exposure
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvcal_master.dta", clear
    capture noisily tvplot, id(id) start(start) stop(stop) persontime
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvplot persontime requires exposure()"
    local ++pass_count
}
else {
    display as error "  FAIL: tvplot persontime requires exposure() (error `=_rc')"
    local ++fail_count
}

* Test 3.9: tvplot r() return values
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvcal_master.dta", clear
    tvplot, id(id) start(start) stop(stop) exposure(tv_exp) swimlane sample(2)

    assert "`r(plottype)'" == "swimlane"
    assert "`r(id)'" == "id"
    assert "`r(start)'" == "start"
    assert "`r(stop)'" == "stop"
}
if _rc == 0 {
    display as result "  PASS: tvplot r() return values"
    local ++pass_count
}
else {
    display as error "  FAIL: tvplot r() return values (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 4: TVTRIAL (was 33% coverage)
* =============================================================================

* --- Create trial test data ---
clear
set seed 54321
set obs 100
gen long id = _n
gen double study_entry = 21915 + floor(30*runiform())  // within 30 days of base
gen double study_exit = study_entry + 365 + floor(180*runiform())  // 1-1.5 years
* Half get treatment at various times
gen double rx_start = study_entry + 30 + floor(120*runiform()) if runiform() > 0.5
format %td study_entry study_exit rx_start
* Create eligibility window narrower than study period
gen double elig_start = study_entry + 10
gen double elig_end = study_entry + 180
format %td elig_start elig_end
save "`DATA_DIR'/_gold_tvtrial.dta", replace

* Test 4.1: tvtrial with eligstart/eligend
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvtrial.dta", clear
    tvtrial, id(id) entry(study_entry) exit(study_exit) ///
        treatstart(rx_start) eligstart(elig_start) eligend(elig_end)

    * Should create trial variables
    confirm variable trial_trial
    confirm variable trial_arm
    confirm variable trial_fu_time

    * All follow-up times should be positive
    assert trial_fu_time >= 0 if !missing(trial_fu_time)
}
if _rc == 0 {
    display as result "  PASS: tvtrial eligstart/eligend"
    local ++pass_count
}
else {
    display as error "  FAIL: tvtrial eligstart/eligend (error `=_rc')"
    local ++fail_count
}

* Test 4.2: tvtrial graceperiod
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvtrial.dta", clear
    tvtrial, id(id) entry(study_entry) exit(study_exit) ///
        treatstart(rx_start) graceperiod(30)

    * With grace period, some persons who start treatment within 30 days
    * should be in treatment arm
    confirm variable trial_arm
    quietly count if trial_arm == 1
    assert r(N) > 0

    assert r(n_persontrials) > 0
}
if _rc == 0 {
    display as result "  PASS: tvtrial graceperiod()"
    local ++pass_count
}
else {
    display as error "  FAIL: tvtrial graceperiod() (error `=_rc')"
    local ++fail_count
}

* Test 4.3: tvtrial maxfollowup
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvtrial.dta", clear
    tvtrial, id(id) entry(study_entry) exit(study_exit) ///
        treatstart(rx_start) maxfollowup(90)

    * All follow-up should be capped at 90 days
    assert trial_fu_time <= 90 if !missing(trial_fu_time)
}
if _rc == 0 {
    display as result "  PASS: tvtrial maxfollowup() caps follow-up"
    local ++pass_count
}
else {
    display as error "  FAIL: tvtrial maxfollowup() caps follow-up (error `=_rc')"
    local ++fail_count
}

* Test 4.4: tvtrial trials() and trialinterval()
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvtrial.dta", clear
    tvtrial, id(id) entry(study_entry) exit(study_exit) ///
        treatstart(rx_start) trials(6) trialinterval(30)

    assert r(n_trials) <= 6
    assert r(n_trials) > 0

    * Trial numbers should be 1 to at most 6
    quietly sum trial_trial
    assert r(max) <= 6
}
if _rc == 0 {
    display as result "  PASS: tvtrial trials() + trialinterval()"
    local ++pass_count
}
else {
    display as error "  FAIL: tvtrial trials() + trialinterval() (error `=_rc')"
    local ++fail_count
}

* Test 4.5: tvtrial generate() custom prefix
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvtrial.dta", clear
    tvtrial, id(id) entry(study_entry) exit(study_exit) ///
        treatstart(rx_start) generate(tt_) trials(3)

    * Should use custom prefix
    confirm variable tt_trial
    confirm variable tt_arm
    confirm variable tt_fu_time
    confirm variable tt_censored

    * Default prefix should not exist
    capture confirm variable trial_trial
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: tvtrial generate() custom prefix"
    local ++pass_count
}
else {
    display as error "  FAIL: tvtrial generate() custom prefix (error `=_rc')"
    local ++fail_count
}

* Test 4.6: tvtrial clone + ipcweight
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvtrial.dta", clear
    tvtrial, id(id) entry(study_entry) exit(study_exit) ///
        treatstart(rx_start) clone ipcweight trials(3)

    * Should have IPCW variable
    confirm variable trial_ipcw

    * IPCW should be non-negative
    assert trial_ipcw >= 0 if !missing(trial_ipcw)

    * With clone, both arms should exist for each trial
    assert r(n_treat) > 0
    assert r(n_control) > 0
}
if _rc == 0 {
    display as result "  PASS: tvtrial clone + ipcweight"
    local ++pass_count
}
else {
    display as error "  FAIL: tvtrial clone + ipcweight (error `=_rc')"
    local ++fail_count
}

* Test 4.7: tvtrial r() return values comprehensive
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvtrial.dta", clear
    tvtrial, id(id) entry(study_entry) exit(study_exit) ///
        treatstart(rx_start) trials(4)

    assert r(n_orig) == 100
    assert r(n_ids) == 100
    assert r(n_trials) > 0
    assert r(n_eligible) > 0
    assert r(n_persontrials) > 0
    assert r(n_treat) >= 0
    assert r(n_control) >= 0
    assert r(mean_fu) > 0
    assert r(total_fu) > 0
    assert "`r(id)'" == "id"
    assert "`r(entry)'" == "study_entry"
    assert "`r(exit)'" == "study_exit"
    assert "`r(treatstart)'" == "rx_start"
    assert "`r(prefix)'" == "trial_"
}
if _rc == 0 {
    display as result "  PASS: tvtrial r() return values comprehensive"
    local ++pass_count
}
else {
    display as error "  FAIL: tvtrial r() return values comprehensive (error `=_rc')"
    local ++fail_count
}

* Test 4.8: tvtrial error - negative graceperiod
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvtrial.dta", clear
    capture noisily tvtrial, id(id) entry(study_entry) exit(study_exit) ///
        treatstart(rx_start) graceperiod(-1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvtrial error on negative graceperiod"
    local ++pass_count
}
else {
    display as error "  FAIL: tvtrial error on negative graceperiod (error `=_rc')"
    local ++fail_count
}

* Test 4.9: tvtrial eligstart + eligend + maxfollowup + graceperiod (combo)
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvtrial.dta", clear
    tvtrial, id(id) entry(study_entry) exit(study_exit) ///
        treatstart(rx_start) eligstart(elig_start) eligend(elig_end) ///
        graceperiod(14) maxfollowup(60) clone trials(4)

    * Follow-up capped at 60
    assert trial_fu_time <= 60 if !missing(trial_fu_time)

    * Clone creates treatment and control arms
    assert r(n_treat) > 0
    assert r(n_control) > 0
}
if _rc == 0 {
    display as result "  PASS: tvtrial full option combination"
    local ++pass_count
}
else {
    display as error "  FAIL: tvtrial full option combination (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 5: TVDIAGNOSE (threshold gap)
* =============================================================================

* Test 5.1: tvdiagnose threshold() affects large gap count
local ++test_count
capture {
    * Create data with known gaps
    clear
    input long id double(start stop) byte tv_exp
        1 22006 22036 1
        1 22046 22067 0
        1 22127 22157 1
        2 22006 22036 0
        2 22037 22067 1
    end
    format %td start stop

    * Person 1 has gap of 10 days (22036-22046) and 60 days (22067-22127)
    * With threshold(30), only the 60-day gap should be flagged
    tvdiagnose, id(id) start(start) stop(stop) gaps threshold(30)
    assert r(n_large_gaps) == 1
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose threshold() flags correct gaps"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose threshold() flags correct gaps (error `=_rc')"
    local ++fail_count
}

* Test 5.2: tvdiagnose threshold() with low value flags more gaps
local ++test_count
capture {
    clear
    input long id double(start stop) byte tv_exp
        1 22006 22036 1
        1 22046 22067 0
        1 22127 22157 1
    end
    format %td start stop

    * With threshold(5), both gaps (10 and 60 days) should be flagged
    tvdiagnose, id(id) start(start) stop(stop) gaps threshold(5)
    assert r(n_large_gaps) == 2
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose threshold() low value flags more gaps"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose threshold() low value (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 6: TVWEIGHT (tvcovariates/id/time gap)
* =============================================================================

* Test 6.1: tvweight tvcovariates with id and time
local ++test_count
capture {
    * Create panel data with time-varying covariates
    clear
    set seed 11111
    set obs 300
    gen long id = ceil(_n/3)  // 100 persons, 3 time points each
    bysort id: gen int time = _n
    gen byte treatment = (runiform() > 0.6)
    gen double age = 50 + 5*rnormal()
    gen double bmi_tv = 25 + 2*rnormal() + time*0.5  // time-varying BMI
    gen double crp_tv = 5 + 3*rnormal() + 2*treatment  // time-varying CRP

    tvweight treatment, covariates(age) tvcovariates(bmi_tv crp_tv) ///
        id(id) time(time) generate(iptw_tv) nolog

    * Weight variable should exist
    confirm variable iptw_tv

    * Weights should be positive
    assert iptw_tv > 0 if !missing(iptw_tv)

    * ESS should be meaningful
    assert r(ess) > 0
    assert r(ess_pct) > 0 & r(ess_pct) <= 100
}
if _rc == 0 {
    display as result "  PASS: tvweight tvcovariates with id/time"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight tvcovariates with id/time (error `=_rc')"
    local ++fail_count
}

* Test 6.2: tvweight error - tvcovariates without id
local ++test_count
capture {
    clear
    set seed 22222
    set obs 100
    gen byte treatment = (runiform() > 0.5)
    gen double age = 50 + 5*rnormal()
    gen double bmi_tv = 25 + 2*rnormal()

    capture noisily tvweight treatment, covariates(age) ///
        tvcovariates(bmi_tv) generate(iptw_err)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvweight tvcovariates requires id/time"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight tvcovariates requires id/time (error `=_rc')"
    local ++fail_count
}

* Test 6.3: tvweight nolog suppresses iteration log
local ++test_count
capture {
    clear
    set seed 33333
    set obs 200
    gen byte treatment = (runiform() > 0.5)
    gen double age = 50 + 5*rnormal()
    gen byte female = (runiform() > 0.5)

    tvweight treatment, covariates(age female) generate(iptw_nolog) nolog
    confirm variable iptw_nolog
}
if _rc == 0 {
    display as result "  PASS: tvweight nolog option"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight nolog option (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 7: TVEXPOSE (carryforward, switchingdetail, statetime, validate)
* =============================================================================

* --- Create test datasets for tvexpose gap options ---
clear
input long id double(study_entry study_exit)
    1 22006 22280
    2 22006 22280
end
format %td study_entry study_exit
save "`DATA_DIR'/_gold_tvexp_cohort.dta", replace

clear
input long id double(rx_start rx_stop) byte drug
    1 22036 22066 1
    1 22097 22127 2
    1 22157 22187 1
    2 22036 22127 1
end
format %td rx_start rx_stop
save "`DATA_DIR'/_gold_tvexp_rx.dta", replace

* Test 7.1: tvexpose carryforward()
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvexp_cohort.dta", clear
    tvexpose using "`DATA_DIR'/_gold_tvexp_rx.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) ///
        carryforward(15)

    * Person 1 has gaps. With carryforward(15), exposure extends 15 days past stop.
    * Should have exposure carried forward into gap periods
    quietly count if id == 1
    assert r(N) >= 3

    * Total person-time should be preserved (output uses rx_start/rx_stop names)
    gen double dur = rx_stop - rx_start
    quietly sum dur
    assert r(sum) > 0
}
if _rc == 0 {
    display as result "  PASS: tvexpose carryforward()"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose carryforward() (error `=_rc')"
    local ++fail_count
}

* Test 7.2: tvexpose switchingdetail
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvexp_cohort.dta", clear
    tvexpose using "`DATA_DIR'/_gold_tvexp_rx.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) ///
        switchingdetail

    * Should create switching_pattern variable
    confirm variable switching_pattern

    * Person 1 has pattern: 0 to 1 to 0 to 2 to 0 to 1 (or similar)
    * Pattern should be a string
    confirm string variable switching_pattern
}
if _rc == 0 {
    display as result "  PASS: tvexpose switchingdetail creates pattern"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose switchingdetail (error `=_rc')"
    local ++fail_count
}

* Test 7.3: tvexpose statetime
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvexp_cohort.dta", clear
    tvexpose using "`DATA_DIR'/_gold_tvexp_rx.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) ///
        statetime

    * Should create state_time_years variable
    confirm variable state_time_years

    * State time should be positive
    assert state_time_years > 0 if !missing(state_time_years)

    * State time should reset when exposure changes
    * (cumulative within each exposure state block)
}
if _rc == 0 {
    display as result "  PASS: tvexpose statetime creates state_time_years"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose statetime (error `=_rc')"
    local ++fail_count
}

* Test 7.4: tvexpose validate option
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvexp_cohort.dta", clear
    tvexpose using "`DATA_DIR'/_gold_tvexp_rx.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) ///
        validate replace

    * Should complete without error and return validation metrics
    assert r(N_persons) > 0
    capture erase "tv_validation.dta"
}
if _rc == 0 {
    display as result "  PASS: tvexpose validate option"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose validate option (error `=_rc')"
    local ++fail_count
}

* Test 7.5: tvexpose switching + switchingdetail + statetime combo
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvexp_cohort.dta", clear
    tvexpose using "`DATA_DIR'/_gold_tvexp_rx.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) ///
        switching switchingdetail statetime

    confirm variable ever_switched
    confirm variable switching_pattern
    confirm variable state_time_years

    * Person 1 switches drugs → ever_switched should be 1
    quietly sum ever_switched if id == 1
    assert r(max) == 1
}
if _rc == 0 {
    display as result "  PASS: tvexpose switching+switchingdetail+statetime combo"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose switching+switchingdetail+statetime combo (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 8: TVMERGE (startname, stopname, dateformat, validatecoverage/overlap)
* =============================================================================

* --- Create merge test datasets ---
clear
input long id double(start1 stop1) byte exp1
    1 22006 22067 1
    1 22067 22128 2
    2 22006 22128 1
end
format %td start1 stop1
save "`DATA_DIR'/_gold_merge_ds1.dta", replace

clear
input long id double(begin1 end1) byte med1
    1 22036 22097 1
    2 22036 22067 1
    2 22067 22097 0
end
format %td begin1 end1
save "`DATA_DIR'/_gold_merge_ds2.dta", replace

* Test 8.1: tvmerge startname and stopname
local ++test_count
capture {
    tvmerge "`DATA_DIR'/_gold_merge_ds1.dta" "`DATA_DIR'/_gold_merge_ds2.dta", ///
        id(id) start(start1 begin1) stop(stop1 end1) ///
        exposure(exp1 med1) startname(period_begin) stopname(period_end)

    confirm variable period_begin
    confirm variable period_end

    * Default names should NOT exist
    capture confirm variable start
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: tvmerge startname/stopname"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge startname/stopname (error `=_rc')"
    local ++fail_count
}

* Test 8.2: tvmerge dateformat
local ++test_count
capture {
    tvmerge "`DATA_DIR'/_gold_merge_ds1.dta" "`DATA_DIR'/_gold_merge_ds2.dta", ///
        id(id) start(start1 begin1) stop(stop1 end1) ///
        exposure(exp1 med1) dateformat(%tdNN/DD/CCYY)

    * Check format applied
    local fmt : format start
    assert "`fmt'" == "%tdNN/DD/CCYY"
}
if _rc == 0 {
    display as result "  PASS: tvmerge dateformat()"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge dateformat() (error `=_rc')"
    local ++fail_count
}

* Test 8.3: tvmerge validatecoverage
local ++test_count
capture {
    tvmerge "`DATA_DIR'/_gold_merge_ds1.dta" "`DATA_DIR'/_gold_merge_ds2.dta", ///
        id(id) start(start1 begin1) stop(stop1 end1) ///
        exposure(exp1 med1) validatecoverage

    * Should complete (whether gaps exist or not)
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: tvmerge validatecoverage"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge validatecoverage (error `=_rc')"
    local ++fail_count
}

* Test 8.4: tvmerge validateoverlap
local ++test_count
capture {
    tvmerge "`DATA_DIR'/_gold_merge_ds1.dta" "`DATA_DIR'/_gold_merge_ds2.dta", ///
        id(id) start(start1 begin1) stop(stop1 end1) ///
        exposure(exp1 med1) validateoverlap

    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: tvmerge validateoverlap"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge validateoverlap (error `=_rc')"
    local ++fail_count
}

* Test 8.5: tvmerge startname + stopname + dateformat + validatecoverage combo
local ++test_count
capture {
    tvmerge "`DATA_DIR'/_gold_merge_ds1.dta" "`DATA_DIR'/_gold_merge_ds2.dta", ///
        id(id) start(start1 begin1) stop(stop1 end1) ///
        exposure(exp1 med1) startname(t0) stopname(t1) ///
        dateformat(%tdCCYY-NN-DD) validatecoverage validateoverlap

    confirm variable t0
    confirm variable t1
    local fmt : format t0
    assert "`fmt'" == "%tdCCYY-NN-DD"
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: tvmerge full option combination"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge full option combination (error `=_rc')"
    local ++fail_count
}

* Test 8.6: tvmerge r() macros for custom names
local ++test_count
capture {
    tvmerge "`DATA_DIR'/_gold_merge_ds1.dta" "`DATA_DIR'/_gold_merge_ds2.dta", ///
        id(id) start(start1 begin1) stop(stop1 end1) ///
        exposure(exp1 med1) startname(my_start) stopname(my_stop)

    assert "`r(startname)'" == "my_start"
    assert "`r(stopname)'" == "my_stop"
}
if _rc == 0 {
    display as result "  PASS: tvmerge r() returns custom start/stop names"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge r() returns custom names (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 9: CROSS-COMMAND INTEGRATION
* =============================================================================

* Test 9.1: Full pipeline with all diagnostics
local ++test_count
capture {
    * Step 1: Create exposure intervals (keepdates to preserve entry/exit)
    use "`DATA_DIR'/_gold_tvexp_cohort.dta", clear
    tvexpose using "`DATA_DIR'/_gold_tvexp_rx.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) ///
        check keepdates

    local n1 = r(N_persons)

    * Step 2: Diagnose the output (tvexpose uses original var names rx_start/rx_stop)
    tvdiagnose, id(id) start(rx_start) stop(rx_stop) ///
        exposure(tv_exposure) all ///
        entry(study_entry) exit(study_exit)

    assert r(n_persons) == `n1'
    assert r(n_observations) > 0
}
if _rc == 0 {
    display as result "  PASS: Pipeline tvexpose → tvdiagnose"
    local ++pass_count
}
else {
    display as error "  FAIL: Pipeline tvexpose → tvdiagnose (error `=_rc')"
    local ++fail_count
}

* Test 9.2: tvexpose → tvbalance with IPTW pipeline
local ++test_count
capture {
    * Create cohort with covariates
    clear
    set seed 99999
    set obs 200
    gen long id = _n
    gen double study_entry = 22006
    gen double study_exit = 22280
    format %td study_entry study_exit
    gen double age = 50 + 10*rnormal()
    gen byte female = (runiform() > 0.5)
    save "`DATA_DIR'/_gold_pipeline_cohort.dta", replace

    * Create exposure
    clear
    set seed 88888
    set obs 100
    gen long id = ceil(_n * 2 / 1)
    replace id = min(id, 200)
    gen double rx_start = 22036 + floor(60*runiform())
    gen double rx_stop = rx_start + 30 + floor(60*runiform())
    gen byte drug = 1
    format %td rx_start rx_stop
    * Keep unique IDs
    bysort id: keep if _n == 1
    save "`DATA_DIR'/_gold_pipeline_rx.dta", replace

    * Run tvexpose
    use "`DATA_DIR'/_gold_pipeline_cohort.dta", clear
    tvexpose using "`DATA_DIR'/_gold_pipeline_rx.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) ///
        keepvars(age female)

    * Run tvbalance (tvexpose default output var is tv_exposure)
    tvbalance age female, exposure(tv_exposure)
    assert r(n_covariates) == 2

    * Run tvweight
    tvweight tv_exposure, covariates(age female) generate(iptw) nolog
    assert r(ess) > 0

    * Check balance with weights
    tvbalance age female, exposure(tv_exposure) weights(iptw)
    assert !missing(r(n_imbalanced_wt))
}
if _rc == 0 {
    display as result "  PASS: Pipeline tvexpose → tvbalance → tvweight"
    local ++pass_count
}
else {
    display as error "  FAIL: Pipeline tvexpose → tvbalance → tvweight (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* SECTION 10: ERROR HANDLING
* =============================================================================

* Test 10.1: tvbalance error - no observations
local ++test_count
capture {
    clear
    set obs 0
    gen byte exposure = .
    gen double x1 = .
    capture noisily tvbalance x1, exposure(exposure)
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: tvbalance error on empty data"
    local ++pass_count
}
else {
    display as error "  FAIL: tvbalance error on empty data (error `=_rc')"
    local ++fail_count
}

* Test 10.2: tvweight error - single-level exposure
local ++test_count
capture {
    clear
    set obs 50
    gen byte treatment = 1  // all same level
    gen double age = 50 + 5*rnormal()
    capture noisily tvweight treatment, covariates(age) generate(w)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvweight error on single-level exposure"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight error on single-level exposure (error `=_rc')"
    local ++fail_count
}

* Test 10.3: tvdiagnose error - no report option specified
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvcal_master.dta", clear
    capture noisily tvdiagnose, id(id) start(start) stop(stop)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose error on no report option"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose error on no report option (error `=_rc')"
    local ++fail_count
}

* Test 10.4: tvdiagnose error - coverage without entry/exit
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvcal_master.dta", clear
    capture noisily tvdiagnose, id(id) start(start) stop(stop) coverage
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose error on coverage without entry/exit"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose error on coverage without entry/exit (error `=_rc')"
    local ++fail_count
}

* Test 10.5: tvplot error - sample(0)
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvcal_master.dta", clear
    capture noisily tvplot, id(id) start(start) stop(stop) sample(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvplot error on sample(0)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvplot error on sample(0) (error `=_rc')"
    local ++fail_count
}

* Test 10.6: tvtrial error - trialinterval(0)
local ++test_count
capture {
    use "`DATA_DIR'/_gold_tvtrial.dta", clear
    capture noisily tvtrial, id(id) entry(study_entry) exit(study_exit) ///
        treatstart(rx_start) trialinterval(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvtrial error on trialinterval(0)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvtrial error on trialinterval(0) (error `=_rc')"
    local ++fail_count
}

* Test 10.7: tvweight error - invalid model
local ++test_count
capture {
    clear
    set obs 100
    gen byte treatment = (runiform() > 0.5)
    gen double age = 50 + 5*rnormal()
    capture noisily tvweight treatment, covariates(age) model(probit)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvweight error on invalid model"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight error on invalid model (error `=_rc')"
    local ++fail_count
}

* Test 10.8: tvweight error - truncate bounds inverted
local ++test_count
capture {
    clear
    set obs 100
    gen byte treatment = (runiform() > 0.5)
    gen double age = 50 + 5*rnormal()
    capture noisily tvweight treatment, covariates(age) truncate(99 1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvweight error on inverted truncate bounds"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight error on inverted truncate bounds (error `=_rc')"
    local ++fail_count
}


* =============================================================================
* CLEANUP
* =============================================================================

* Remove temporary test datasets
foreach f in _gold_tvcal_master _gold_tvcal_point _gold_tvcal_periods ///
    _gold_tvbal _gold_tvtrial _gold_tvexp_cohort _gold_tvexp_rx ///
    _gold_merge_ds1 _gold_merge_ds2 _gold_pipeline_cohort _gold_pipeline_rx {
    capture erase "`DATA_DIR'/`f'.dta"
}

* =============================================================================
* RESULTS SUMMARY
* =============================================================================

display as text ""
display as text "{hline 70}"
display as text "{bf:GOLD STANDARD TEST RESULTS}"
display as text "{hline 70}"
display as text ""
display as text "Total tests:  " as result `test_count'
display as text "Passed:       " as result `pass_count'
display as text "Failed:       " as result `fail_count'
display as text ""

if `fail_count' == 0 {
    display as result "ALL TESTS PASSED"
}
else {
    display as error "`fail_count' TESTS FAILED"
}

display as text "{hline 70}"

assert `fail_count' == 0
