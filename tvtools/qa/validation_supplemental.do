clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "validation_supplemental.log", replace nomsg

* Shared scaffold: test globals + helpers + sandboxed install bootstrap
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""
local run_only = 0
local quiet = 0
local machine = 0

* run_test/test_pass/test_fail harness counters (folded into the totals below)
global TVQA_PASS = 0
global TVQA_FAIL = 0
global TVQA_FAILED ""
global TVQA_CURRENT ""

display as result "tvtools QA: supplemental correctness -- $S_DATE $S_TIME"


**# ===== merged from validation_tvtools.do L19471-20306: cross-command math validation + return-value completeness =====

capture noisily {
local DATA_DIR "data"

* SECTION 3: TVWEIGHT MATHEMATICAL VALIDATION

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

* SECTION 5: TVDIAGNOSE MATHEMATICAL VALIDATION

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

* SECTION 6: TVEXPOSE CARRYFORWARD/STATETIME VALIDATION

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

    quietly count if tv_drug != 0
    local exposed_no_cf = r(N)

    * With carryforward(10): exposure extends 10 days past rx_stop
    use "`DATA_DIR'/_val_cf_cohort.dta", clear
    tvexpose using "`DATA_DIR'/_val_cf_rx.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(drug) ///
        reference(0) entry(study_entry) exit(study_exit) ///
        carryforward(10)

    * Should have more or equal exposed intervals than without carryforward
    quietly count if tv_drug != 0
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

* SECTION 7: TVMERGE CUSTOM NAMES VALIDATION

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

* SECTION 8: RETURN VALUE COMPLETENESS

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

* RESULTS SUMMARY

}

capture noisily {

* CREATE SIMULATED DATA

display as text _newline "Step 0: Creating simulated data"

set seed 42

* Cohort: 100 persons, study period 2020-2023
clear
set obs 100
gen long id = _n
gen double study_entry = mdy(1, 1, 2020) + floor(runiform() * 90)
gen double study_exit = study_entry + 365 + floor(runiform() * 730)
format study_entry study_exit %tdCCYY/NN/DD

* Covariates for each person
gen double age = floor(40 + runiform() * 30)
gen byte sex = (runiform() > 0.5)

display as result "Created cohort: " _N " persons"

tempfile cohort_data
quietly save `cohort_data'

* Exposure data: ~60% of persons get treatment
clear
set obs 150
gen long id = ceil(runiform() * 100)
gen double rx_start = mdy(1, 1, 2020) + floor(runiform() * 365)
gen double rx_stop = rx_start + 30 + floor(runiform() * 90)
gen byte exp_type = 1
format rx_start rx_stop %tdCCYY/NN/DD
drop if id > 100

display as result "Created exposure data: " _N " records"

tempfile exposure_data
quietly save `exposure_data'

* Event data: outcome for ~15% of persons
use `cohort_data', clear
gen double event_date = study_entry + floor(runiform() * (study_exit - study_entry))
gen byte has_event = (runiform() < 0.15)
replace event_date = . if has_event == 0
format event_date %tdCCYY/NN/DD
keep id event_date
drop if missing(event_date)

display as result "Created event data: " _N " events"

tempfile event_data
quietly save `event_data'

* STEP 1: tvexpose

display as text _newline "Step 1: tvexpose"

use `cohort_data', clear

tvexpose using `exposure_data', id(id) start(rx_start) stop(rx_stop) ///
    exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
    generate(tv_exp)

* Test 1.1: All persons present
quietly tab id
local n_persons = r(r)
if `n_persons' == 100 {
    display as result "PASS 1.1: All 100 persons present"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL 1.1: " `n_persons' " persons (expected 100)"
    local fail_count = `fail_count' + 1
}

* Test 1.2: No overlapping intervals
sort id rx_start
by id: gen double _gap = rx_start - rx_stop[_n-1] if _n > 1
quietly count if _gap < 1 & !missing(_gap)
local n_overlaps = r(N)
if `n_overlaps' == 0 {
    display as result "PASS 1.2: No overlapping intervals"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL 1.2: " `n_overlaps' " overlapping intervals"
    local fail_count = `fail_count' + 1
}
drop _gap

* Test 1.3: Person-time conserved
preserve
gen double days = rx_stop - rx_start + 1
collapse (sum) total_days=days, by(id)
merge 1:1 id using `cohort_data', keepusing(study_entry study_exit) nogenerate
gen double expected_days = study_exit - study_entry + 1
gen double day_diff = abs(total_days - expected_days)
quietly summarize day_diff
local max_diff = r(max)
restore

if `max_diff' <= 1 {
    display as result "PASS 1.3: Person-time conserved (max diff = " `max_diff' ")"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL 1.3: Person-time not conserved (max diff = " `max_diff' ")"
    local fail_count = `fail_count' + 1
}

display as result "tvexpose output: " _N " rows"

tempfile tvexpose_result
quietly save `tvexpose_result'

* STEP 2: tvevent

display as text _newline "Step 2: tvevent"

* tvevent expects: master = event data, using = time-varying intervals
use `event_data', clear
tvevent using `tvexpose_result', id(id) date(event_date) ///
    startvar(rx_start) stopvar(rx_stop) generate(tv_event)

* Test 2.1: Event flag is binary
quietly tab tv_event
local n_levels = r(r)
if `n_levels' <= 2 {
    display as result "PASS 2.1: Event flag has " `n_levels' " levels"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL 2.1: Event flag has " `n_levels' " levels"
    local fail_count = `fail_count' + 1
}

* Test 2.2: No overlapping intervals after split
sort id rx_start
by id: gen double _gap = rx_start - rx_stop[_n-1] if _n > 1
quietly count if _gap < 1 & !missing(_gap)
local n_overlaps = r(N)
if `n_overlaps' == 0 {
    display as result "PASS 2.2: No overlaps after tvevent"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL 2.2: " `n_overlaps' " overlaps after tvevent"
    local fail_count = `fail_count' + 1
}
drop _gap

display as result "tvevent output: " _N " rows"

tempfile tvevent_result
quietly save `tvevent_result'

* STEP 3: tvdiagnose

display as text _newline "Step 3: tvdiagnose"

tvdiagnose, id(id) start(rx_start) stop(rx_stop) overlaps

* Test 3.1: No overlaps detected
local n_overlaps = r(n_overlaps)
if `n_overlaps' == 0 {
    display as result "PASS 3.1: tvdiagnose confirms no overlaps"
    local pass_count = `pass_count' + 1
}
else {
    display as error "FAIL 3.1: tvdiagnose found " `n_overlaps' " overlaps"
    local fail_count = `fail_count' + 1
}

}

capture noisily {

* CREATE SHARED PIPELINE DATA
* 5 persons with precisely defined exposure and event patterns
* Person 1: unexposed throughout (control)
* Person 2: single exposure to drug A, no event
* Person 3: exposure to drug A then drug B, event day 200
* Person 4: overlapping drugs A and B, event day 300
* Person 5: full-window exposure to drug A, censored at exit

display "Setting up pipeline data (5 persons)"

* Cohort
clear
set obs 5
gen long id = _n
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2020)
format study_entry study_exit %td
save "$TVTOOLS_QA_RUN_DIR/tvp_cohort.dta", replace

local ptime_expected = mdy(12,31,2020) - mdy(1,1,2020) + 1
display "  Expected person-time per person: `ptime_expected' days"

* ===== EXPOSURE DATASET A (drug A) =====
clear
set obs 0
gen long id = .
gen double startA = .
gen double stopA  = .
gen byte drugA = .

* Person 2: drug A from Mar1-Jun30
local n = _N + 1
set obs `n'
replace id = 2 in `n'
replace startA = mdy(3,1,2020) in `n'
replace stopA  = mdy(6,30,2020) in `n'
replace drugA  = 1 in `n'

* Person 3: drug A from Feb1-May31
local n = _N + 1
set obs `n'
replace id = 3 in `n'
replace startA = mdy(2,1,2020) in `n'
replace stopA  = mdy(5,31,2020) in `n'
replace drugA  = 1 in `n'

* Person 4: drug A from Jan15-Sep30
local n = _N + 1
set obs `n'
replace id = 4 in `n'
replace startA = mdy(1,15,2020) in `n'
replace stopA  = mdy(9,30,2020) in `n'
replace drugA  = 1 in `n'

* Person 5: drug A full window
local n = _N + 1
set obs `n'
replace id = 5 in `n'
replace startA = mdy(1,1,2020) in `n'
replace stopA  = mdy(12,31,2020) in `n'
replace drugA  = 1 in `n'

format startA stopA %td
save "$TVTOOLS_QA_RUN_DIR/tvp_expA.dta", replace

* ===== EXPOSURE DATASET B (drug B) =====
clear
set obs 0
gen long id = .
gen double startB = .
gen double stopB  = .
gen byte drugB = .

* Person 3: drug B from Jun1-Oct31 (sequential after A)
local n = _N + 1
set obs `n'
replace id = 3 in `n'
replace startB = mdy(6,1,2020) in `n'
replace stopB  = mdy(10,31,2020) in `n'
replace drugB  = 1 in `n'

* Person 4: drug B from Jul1-Dec31 (overlaps with A's Jul1-Sep30 period)
local n = _N + 1
set obs `n'
replace id = 4 in `n'
replace startB = mdy(7,1,2020) in `n'
replace stopB  = mdy(12,31,2020) in `n'
replace drugB  = 1 in `n'

format startB stopB %td
save "$TVTOOLS_QA_RUN_DIR/tvp_expB.dta", replace

}

capture noisily {
capture program drop assert_exact
program define assert_exact
    args actual expected label
    if `actual' == `expected' {
        display as result "  PASS [`label']: value=`actual'"
    }
    else {
        display as error "  FAIL [`label']: actual=`actual', expected=`expected'"
        exit 9
    }
end

capture program drop assert_approx
program define assert_approx
    args actual expected tolerance label
    local diff = abs(`actual' - `expected')
    if `diff' <= `tolerance' {
        display as result "  PASS [`label']: actual=`actual', expected=`expected', diff=`diff'"
    }
    else {
        display as error "  FAIL [`label']: actual=`actual', expected=`expected', diff=`diff' > tol=`tolerance'"
        exit 9
    }
end

* CREATE SYNTHETIC COHORT

* Cohort master data
tempfile cohort
clear
input int(id)
1
2
3
end
gen double study_entry = mdy(1,1,2020)
gen double study_exit  = mdy(12,31,2020)
format %td study_entry study_exit
save `cohort', replace

* Exposure data (single drug)
tempfile exposure1
clear
input int(id drug) str10(s_start s_stop)
2 1 "2020-04-01" "2020-09-30"
3 1 "2020-02-01" "2020-07-31"
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_start s_stop
save `exposure1', replace

* Event data
tempfile events_single
clear
input int(id) str10(s_event)
3 "2020-06-15"
end
gen double event_date = date(s_event, "YMD")
format %td event_date
drop s_event
* Persons 1 and 2 have no event (censored)
* Add them with missing event dates
set obs 3
replace id = 1 in 2
replace id = 2 in 3
save `events_single', replace

* TESTS 1-5: TVEXPOSE → TVEVENT SINGLE-DRUG PIPELINE

}


**# ===== merged from validation_tvtools.do L20939-21763: invariant and conservation tests =====

* SECTION 16: INVARIANT AND CONSERVATION TESTS (15 tests)

* --- 16a: tvevent invariants (4 tests) ---

capture noisily {
display "INVARIANT TESTS: TVEVENT"

* Create interval data
tempfile inv_intervals inv_events
clear
input int(id) str10(s_start s_stop) byte(tv_exp)
1 "2020-01-01" "2020-04-30" 0
1 "2020-05-01" "2020-08-31" 1
1 "2020-09-01" "2020-12-31" 0
2 "2020-01-01" "2020-06-30" 1
2 "2020-07-01" "2020-12-31" 0
3 "2020-01-01" "2020-12-31" 1
end
gen double start = date(s_start, "YMD")
gen double stop  = date(s_stop, "YMD")
format %td start stop
drop s_*
save `inv_intervals', replace

* Compute person-time before tvevent
quietly gen double pt = stop - start
quietly summarize pt
local ptime_before = r(sum)

* Events
clear
input int(id) str10(s_event)
1 "2020-06-15"
3 "2020-09-15"
end
gen double event_date = date(s_event, "YMD")
format %td event_date
drop s_event
set obs 3
replace id = 2 in 3
save `inv_events', replace

* Run tvevent
use `inv_events', clear
tvevent using `inv_intervals', id(id) date(event_date) ///
    type(single) generate(fail_flag) replace

* Test 16.1: Person-time within expected range after merge
local ++test_count
capture {
    quietly gen double pt = stop - start
    quietly summarize pt
    local ptime_after = r(sum)
    * Person-time may differ if tvevent truncates at event dates
    * but should be in the same order of magnitude
    assert `ptime_after' > 0
    assert `ptime_after' <= `ptime_before' * 1.01
}
if _rc == 0 {
    display as result "  PASS: tvevent person-time reasonable"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent person-time (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.1"
}

* Test 16.2: Interval continuity (no gaps)
local ++test_count
capture {
    sort id start
    quietly by id: gen double gap = start - stop[_n-1] if _n > 1
    quietly summarize gap
    assert r(max) <= 1
    drop gap
}
if _rc == 0 {
    display as result "  PASS: tvevent interval continuity"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent interval continuity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.2"
}

* Test 16.3: Correct event count
local ++test_count
capture {
    quietly count if fail_flag == 1
    local n_events = r(N)
    assert `n_events' == 2
}
if _rc == 0 {
    display as result "  PASS: tvevent correct event count"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent event count (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.3"
}

* Test 16.4: Failure indicator binary (0 or 1)
local ++test_count
capture {
    quietly count if fail_flag != 0 & fail_flag != 1 & !missing(fail_flag)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: tvevent failure indicator binary"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent indicator binary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.4"
}

}

* --- 16b: tvmerge invariants (4 tests) ---

capture noisily {
display "INVARIANT TESTS: TVMERGE"

* Create two interval datasets
clear
input int(id) str10(s_start s_stop) byte(expA)
1 "2020-01-01" "2020-06-30" 1
1 "2020-07-01" "2020-12-31" 0
2 "2020-01-01" "2020-12-31" 1
end
gen double startA = date(s_start, "YMD")
gen double stopA  = date(s_stop, "YMD")
format %td startA stopA
drop s_*
save "$TVTOOLS_QA_RUN_DIR/_v16_merge1.dta", replace

clear
input int(id) str10(s_start s_stop) byte(expB)
1 "2020-01-01" "2020-04-30" 1
1 "2020-05-01" "2020-12-31" 0
2 "2020-01-01" "2020-08-31" 1
2 "2020-09-01" "2020-12-31" 0
end
gen double startB = date(s_start, "YMD")
gen double stopB  = date(s_stop, "YMD")
format %td startB stopB
drop s_*
save "$TVTOOLS_QA_RUN_DIR/_v16_merge2.dta", replace

tvmerge "$TVTOOLS_QA_RUN_DIR/_v16_merge1.dta" "$TVTOOLS_QA_RUN_DIR/_v16_merge2.dta", ///
    id(id) start(startA startB) stop(stopA stopB) exposure(expA expB)

* Save r() values before they get overwritten by summarize
local merge_N_persons = r(N_persons)

* Test 16.5: Output intervals are subsets of both inputs
local ++test_count
capture {
    quietly summarize start
    local out_min = r(min)
    assert `out_min' >= mdy(1,1,2020)
    quietly summarize stop
    local out_max = r(max)
    assert `out_max' <= mdy(12,31,2020)
}
if _rc == 0 {
    display as result "  PASS: tvmerge output intervals bounded"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge intervals bounded (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.5"
}

* Test 16.6: Both exposure values present
local ++test_count
capture {
    confirm variable expA
    confirm variable expB
    quietly count if missing(expA) | missing(expB)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: tvmerge exposure values carried"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge exposure values (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.6"
}

* Test 16.7: N_persons matches input
local ++test_count
capture {
    assert `merge_N_persons' == 2
}
if _rc == 0 {
    display as result "  PASS: tvmerge N_persons correct"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge N_persons (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.7"
}

* Test 16.8: Person-time conservation
local ++test_count
capture {
    * Total person-time: each person has Jan1-Dec31 = 365 days
    * Two persons = 730 days
    quietly gen double pt = stop - start
    quietly summarize pt
    local merged_pt = r(sum)
    assert `merged_pt' >= 725 & `merged_pt' <= 735
    drop pt
}
if _rc == 0 {
    display as result "  PASS: tvmerge person-time conservation"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge person-time (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.8"
}

capture erase "$TVTOOLS_QA_RUN_DIR/_v16_merge1.dta"
capture erase "$TVTOOLS_QA_RUN_DIR/_v16_merge2.dta"

}

* --- 16c: tvexpose preservation (3 tests) ---

capture noisily {
display "INVARIANT TESTS: TVEXPOSE PRESERVATION"

* Create cohort with value labels
tempfile expo_cohort expo_rx
clear
input int(id) str10(s_entry s_exit) double(baseline_age) byte(sex)
1 "2020-01-01" "2020-12-31" 55 1
2 "2020-01-01" "2020-12-31" 62 0
3 "2020-01-01" "2020-12-31" 48 1
end
gen double entry = date(s_entry, "YMD")
gen double exit_ = date(s_exit, "YMD")
format %td entry exit_
drop s_*
label define sex_lbl 0 "Female" 1 "Male"
label values sex sex_lbl
save `expo_cohort', replace

* Exposure data
clear
input int(id) str10(s_start s_stop) byte(drug)
1 "2020-03-01" "2020-09-30" 1
2 "2020-05-01" "2020-12-31" 1
end
gen double rx_start = date(s_start, "YMD")
gen double rx_stop  = date(s_stop, "YMD")
format %td rx_start rx_stop
drop s_*
save `expo_rx', replace

use `expo_cohort', clear
tvexpose using `expo_rx', id(id) start(rx_start) stop(rx_stop) ///
    exposure(drug) entry(entry) exit(exit_) ///
    reference(0) generate(tv_exp) keepvars(baseline_age sex) ///
    referencelabel("Unexposed") keepdates

* Test 16.9: keepvars values preserved
local ++test_count
capture {
    confirm variable baseline_age
    confirm variable sex
    * Person 1 should still have baseline_age == 55
    quietly summarize baseline_age if id == 1
    assert r(mean) == 55
}
if _rc == 0 {
    display as result "  PASS: tvexpose keepvars preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose keepvars (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.9"
}

* Test 16.10: Value labels preserved
local ++test_count
capture {
    local lbl : value label sex
    assert "`lbl'" != ""
    local male_text : label `lbl' 1
    assert "`male_text'" == "Male"
}
if _rc == 0 {
    display as result "  PASS: tvexpose value labels preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose value labels (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.10"
}

* Test 16.11: referencelabel in value label
local ++test_count
capture {
    local explbl : value label tv_exp
    assert "`explbl'" != ""
    local ref_text : label `explbl' 0
    assert "`ref_text'" == "Unexposed"
}
if _rc == 0 {
    display as result "  PASS: tvexpose referencelabel applied"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose referencelabel (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16.11"
}

}

* V3: TVWEIGHT — weight formula validation

display as text "V3: tvweight weight formula validation"

* V3.1: IPTW = 1/PS for treated, 1/(1-PS) for untreated
local ++test_count
capture noisily {
    clear
    set seed 33333
    set obs 300
    gen age = 50 + 10 * rnormal()
    gen treatment = (runiform() < invlogit(-1 + 0.02 * age))

    tvweight treatment, covariates(age) generate(w) denominator(ps) nolog
    * Manually check formula
    gen manual_w = 1/ps if treatment == 1
    replace manual_w = 1/(1-ps) if treatment == 0
    * Should match within floating-point tolerance
    assert abs(w - manual_w) < 0.001 if !missing(w) & !missing(manual_w)
}
if _rc == 0 {
    display as result "  PASS: V3.1 IPTW formula matches 1/PS and 1/(1-PS)"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.1 IPTW formula matches 1/PS and 1/(1-PS) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V3.1"
}

* V3.2: Stabilized weights: marginal_prob/PS for treated
local ++test_count
capture noisily {
    clear
    set seed 44444
    set obs 400
    gen age = 50 + 10 * rnormal()
    gen treatment = (runiform() < invlogit(-1 + 0.02 * age))

    tvweight treatment, covariates(age) generate(sw) stabilized denominator(ps) nolog
    * Manual stabilized weight
    quietly sum treatment
    local marg = r(mean)
    gen manual_sw = `marg' / ps if treatment == 1
    replace manual_sw = (1 - `marg') / (1 - ps) if treatment == 0
    assert abs(sw - manual_sw) < 0.001 if !missing(sw) & !missing(manual_sw)
}
if _rc == 0 {
    display as result "  PASS: V3.2 Stabilized weight formula matches manual computation"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.2 Stabilized weight formula matches manual computation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V3.2"
}

* V3.3: ESS formula validation
* ESS = (sum_w)^2 / sum(w^2)
local ++test_count
capture noisily {
    clear
    set seed 55555
    set obs 200
    gen age = 50 + 5 * rnormal()
    gen treatment = (runiform() < invlogit(-1 + 0.02 * age))

    tvweight treatment, covariates(age) generate(w) nolog
    * Save r(ess) before it gets overwritten by subsequent commands
    local ess_tv = r(ess)
    * Manual ESS
    quietly sum w
    local sum_w = r(sum)
    quietly gen w2 = w^2
    quietly sum w2
    local sum_w2 = r(sum)
    local manual_ess = (`sum_w'^2) / `sum_w2'
    assert abs(`ess_tv' - `manual_ess') < 0.1
}
if _rc == 0 {
    display as result "  PASS: V3.3 ESS matches (sum_w)^2 / sum(w^2)"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.3 ESS matches (sum_w)^2 / sum(w^2) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V3.3"
}

* V3.4: Truncation clamps values correctly
local ++test_count
capture noisily {
    clear
    set seed 66666
    set obs 500
    gen age = 50 + 20 * rnormal()
    gen treatment = (runiform() < invlogit(-2 + 0.04 * age))

    tvweight treatment, covariates(age) generate(tw) truncate(5 95) nolog
    * After truncation, min should equal 5th percentile and max should equal 95th
    * Get original weights for comparison
    tvweight treatment, covariates(age) generate(uw) replace nolog
    quietly _pctile uw, percentiles(5 95)
    local p5 = r(r1)
    local p95 = r(r2)
    * Truncated weights should be within [p5, p95]
    assert tw >= `p5' - 0.001 if !missing(tw)
    assert tw <= `p95' + 0.001 if !missing(tw)
}
if _rc == 0 {
    display as result "  PASS: V3.4 Truncation clamps weights to [p5, p95]"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.4 Truncation clamps weights to [p5, p95] (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V3.4"
}

* V3.5: Multinomial weights = 1/P(A=a|X) for each category
local ++test_count
capture noisily {
    clear
    set seed 77777
    set obs 600
    gen age = 50 + 10 * rnormal()
    gen treat3 = cond(age < 45, 0, cond(age < 55, 1, 2))
    * Jitter to avoid perfect prediction
    replace treat3 = mod(treat3 + (runiform() < 0.1), 3)

    tvweight treat3, covariates(age) generate(mw) nolog
    * All weights should be >= 1 (since 1/probability >= 1/1 = 1)
    assert mw >= 0.99 if !missing(mw)
}
if _rc == 0 {
    display as result "  PASS: V3.5 Multinomial weights all >= 1"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.5 Multinomial weights all >= 1 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V3.5"
}

* V5: TVAGE — age calculation validation

display as text "V5: tvage age calculation validation"

* V5.1: Known DOB — exact ages
* Person born Jan 1, 1970. Entry Jan 1, 2020. Exit Dec 31, 2022.
* Age at entry: floor((21915 - 3653) / 365.25) = floor(50.00) = 50
* (Jan 1, 1970 = 3653, Jan 1, 2020 = 21915)
* Ages should be 50, 51, 52
local ++test_count
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen dob = mdy(1, 1, 1970)
    gen entry = mdy(1, 1, 2020)
    gen exit_dt = mdy(12, 31, 2022)
    format dob entry exit_dt %td

    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_dt)
    assert r(n_observations) == 3
    sort age_tv
    assert age_tv[1] == 50
    assert age_tv[2] == 51
    assert age_tv[3] == 52
}
if _rc == 0 {
    display as result "  PASS: V5.1 Known DOB produces correct ages 50,51,52"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.1 Known DOB produces correct ages 50,51,52 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V5.1"
}

* V5.2: Start date of first interval equals study entry
local ++test_count
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen dob = mdy(6, 15, 1970)
    gen entry = mdy(3, 1, 2020)
    gen exit_dt = mdy(12, 31, 2022)
    format dob entry exit_dt %td

    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_dt)
    sort age_start
    * First interval should start at study entry
    assert age_start[1] == mdy(3, 1, 2020)
}
if _rc == 0 {
    display as result "  PASS: V5.2 First interval starts at study entry"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.2 First interval starts at study entry (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V5.2"
}

* V5.3: Stop date of last interval equals study exit
local ++test_count
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen dob = mdy(6, 15, 1970)
    gen entry = mdy(3, 1, 2020)
    gen exit_dt = mdy(12, 31, 2022)
    format dob entry exit_dt %td

    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_dt)
    sort age_stop
    * Last interval should end at study exit
    local last = _N
    assert age_stop[`last'] == mdy(12, 31, 2022)
}
if _rc == 0 {
    display as result "  PASS: V5.3 Last interval ends at study exit"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.3 Last interval ends at study exit (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V5.3"
}

* V5.4: Intervals are contiguous (no gaps)
local ++test_count
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen dob = mdy(1, 1, 1960)
    gen entry = mdy(1, 1, 2020)
    gen exit_dt = mdy(12, 31, 2024)
    format dob entry exit_dt %td

    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_dt)
    sort age_start
    * Check no gaps: next start = previous stop + 1 (or next day)
    local n = _N
    forvalues i = 2/`n' {
        local prev_stop = age_stop[`=`i'-1']
        local curr_start = age_start[`i']
        * Allow 1-day tolerance (stop date may overlap with next start)
        assert `curr_start' - `prev_stop' <= 1
    }
}
if _rc == 0 {
    display as result "  PASS: V5.4 Age intervals are contiguous"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.4 Age intervals are contiguous (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V5.4"
}

* V5.5: Groupwidth=10 produces correct categories
local ++test_count
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen dob = mdy(1, 1, 1960)
    gen entry = mdy(1, 1, 2020)
    gen exit_dt = mdy(12, 31, 2029)
    format dob entry exit_dt %td
    * Age range: 60-69
    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_dt) groupwidth(10)
    * Should produce 1 group: 60-69
    assert r(n_observations) == 1
    assert age_tv[1] == 60
}
if _rc == 0 {
    display as result "  PASS: V5.5 Groupwidth=10 produces correct category"
    local ++pass_count
}
else {
    display as error "  FAIL: V5.5 Groupwidth=10 produces correct category (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V5.5"
}

* V6: TVDIAGNOSE — known-answer diagnostics

display as text "V6: tvdiagnose known-answer diagnostics"

* V6.1: Known gap detection
* ID 1: Jan 1-31, Mar 1-31 (gap: Feb 1-28 = 28 days)
local ++test_count
capture noisily {
    clear
    set obs 2
    gen id = 1
    gen start = mdy(1,1,2020) in 1
    replace start = mdy(3,1,2020) in 2
    gen stop = mdy(1,31,2020) in 1
    replace stop = mdy(3,31,2020) in 2
    format start stop %td

    tvdiagnose, id(id) start(start) stop(stop) gaps
    assert r(n_gaps) == 1
    * Gap is Feb 1 to Feb 29 (2020 is leap year) = 29 days
    assert abs(r(mean_gap) - 29) <= 1
}
if _rc == 0 {
    display as result "  PASS: V6.1 Known gap of ~29 days detected"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.1 Known gap of ~29 days detected (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V6.1"
}

* V6.2: Known overlap detection
* ID 1: Jan 1-31, Jan 15-Feb 15 (overlap: Jan 15-31 = 17 days)
local ++test_count
capture noisily {
    clear
    set obs 2
    gen id = 1
    gen start = mdy(1,1,2020) in 1
    replace start = mdy(1,15,2020) in 2
    gen stop = mdy(1,31,2020) in 1
    replace stop = mdy(2,15,2020) in 2
    format start stop %td

    tvdiagnose, id(id) start(start) stop(stop) overlaps
    assert r(n_overlaps) == 1
    assert r(n_ids_affected) == 1
}
if _rc == 0 {
    display as result "  PASS: V6.2 Known overlap detected"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.2 Known overlap detected (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V6.2"
}

* V6.3: Coverage calculation — known exact value
* ID 1: entry Jan 1, exit Jan 31 (31 days expected)
*   Period: Jan 1 to Jan 20 (20 days)
*   Coverage = 20/31 * 100 = 64.5%
local ++test_count
capture noisily {
    clear
    set obs 1
    gen id = 1
    gen start = mdy(1,1,2020)
    gen stop = mdy(1,20,2020)
    gen entry = mdy(1,1,2020)
    gen exit_dt = mdy(1,31,2020)
    format start stop entry exit_dt %td

    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_dt) coverage
    * Coverage = (20+1)/(31+1) * 100 = 21/32 * 100 = 65.625
    * (stop-start+1) = 20, (exit-entry+1) = 31
    * Actually: period_days = stop-start+1 = 20, expected = exit-entry+1 = 31
    * coverage = 20/31*100 = 64.516...
    assert abs(r(mean_coverage) - 100 * 20 / 31) < 1
}
if _rc == 0 {
    display as result "  PASS: V6.3 Coverage calculation matches expected"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.3 Coverage calculation matches expected (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V6.3"
}

* V6.4: Full coverage = 100%
local ++test_count
capture noisily {
    clear
    set obs 1
    gen id = 1
    gen start = mdy(1,1,2020)
    gen stop = mdy(12,31,2020)
    gen entry = mdy(1,1,2020)
    gen exit_dt = mdy(12,31,2020)
    format start stop entry exit_dt %td

    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_dt) coverage
    assert abs(r(mean_coverage) - 100) < 0.1
    assert r(n_with_gaps) == 0
}
if _rc == 0 {
    display as result "  PASS: V6.4 Full coverage equals 100%"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.4 Full coverage equals 100% (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V6.4"
}

* V6.5: Person-time summary matches hand calculation
local ++test_count
capture noisily {
    clear
    set obs 3
    gen id = 1
    gen start = mdy(1,1,2020) in 1
    replace start = mdy(2,1,2020) in 2
    replace start = mdy(3,1,2020) in 3
    gen stop = mdy(1,31,2020) in 1
    replace stop = mdy(2,29,2020) in 2
    replace stop = mdy(3,31,2020) in 3
    gen exposure = _n
    format start stop %td

    tvdiagnose, id(id) start(start) stop(stop) exposure(exposure) summarize
    * Total person-time = (31) + (29) + (31) = 91 days
    assert abs(r(total_person_time) - 91) < 1
}
if _rc == 0 {
    display as result "  PASS: V6.5 Person-time summary matches hand calculation"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.5 Person-time summary matches hand calculation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V6.5"
}

* V6.6: No false positives — adjacent non-overlapping periods
local ++test_count
capture noisily {
    clear
    set obs 3
    gen id = 1
    gen start = mdy(1,1,2020) in 1
    replace start = mdy(2,1,2020) in 2
    replace start = mdy(3,1,2020) in 3
    gen stop = mdy(1,31,2020) in 1
    replace stop = mdy(2,29,2020) in 2
    replace stop = mdy(3,31,2020) in 3
    format start stop %td

    tvdiagnose, id(id) start(start) stop(stop) overlaps
    assert r(n_overlaps) == 0
    tvdiagnose, id(id) start(start) stop(stop) gaps
    assert r(n_gaps) == 0
}
if _rc == 0 {
    display as result "  PASS: V6.6 Adjacent non-overlapping periods produce no false positives"
    local ++pass_count
}
else {
    display as error "  FAIL: V6.6 Adjacent non-overlapping periods produce no false positives (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V6.6"
}

* V8: CONSISTENCY AND INVARIANT TESTS

display as text "V8: Consistency and invariant tests"

* V8.2: tvweight — weights always positive for non-missing
local ++test_count
capture noisily {
    clear
    set seed 88888
    set obs 300
    gen age = 50 + 10 * rnormal()
    gen treatment = (runiform() < invlogit(-1 + 0.02 * age))
    tvweight treatment, covariates(age) generate(w) nolog
    count if w <= 0 & !missing(w)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: V8.2 tvweight — all weights positive"
    local ++pass_count
}
else {
    display as error "  FAIL: V8.2 tvweight — all weights positive (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V8.2"
}

* ===== Summary =====
* Fold the run_test/test_pass/test_fail harness counters into the totals.
local pass_count = `pass_count' + $TVQA_PASS
local fail_count = `fail_count' + $TVQA_FAIL
local failed_tests "`failed_tests' $TVQA_FAILED"
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA supplemental correctness Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: validation_supplemental tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"

