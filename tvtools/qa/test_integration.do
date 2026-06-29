clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_integration.log", replace nomsg

* Shared scaffold: test globals + helpers + sandboxed install bootstrap
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""
local run_only = 0
local quiet = 0

* run_test/test_pass/test_fail harness counters (folded into the totals below)
global TVQA_PASS = 0
global TVQA_FAIL = 0
global TVQA_FAILED ""
global TVQA_CURRENT ""

display as result "tvtools QA: cross-command integration -- $S_DATE $S_TIME"


**# ===== merged from test_tvtools.do L7507-8086: _CROSS_CUTTING: integration + per-command gap coverage + errors =====


* SECTION 9: _CROSS_CUTTING - Cross-cutting, integration, and error handling

capture noisily {
local DATA_DIR "data"




* SECTION 5: TVDIAGNOSE (threshold gap)

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

* SECTION 6: TVWEIGHT (tvcovariates/id/time gap)

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

* SECTION 7: TVEXPOSE (carryforward, switchingdetail, statetime, validate)

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

* SECTION 8: TVMERGE (startname, stopname, dateformat, validatecoverage/overlap)

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

* SECTION 9: CROSS-COMMAND INTEGRATION

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


* SECTION 10: ERROR HANDLING

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
    clear
    set obs 10
    gen long id = ceil(_n / 2)
    gen double start = mdy(1,1,2020) + (_n - 1) * 30
    gen double stop = start + 29
    format %td start stop
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
    clear
    set obs 10
    gen long id = ceil(_n / 2)
    gen double start = mdy(1,1,2020) + (_n - 1) * 30
    gen double stop = start + 29
    format %td start stop
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

* CLEANUP

* Remove temporary test datasets
foreach f in _gold_tvexp_cohort _gold_tvexp_rx ///
    _gold_merge_ds1 _gold_merge_ds2 {
    capture erase "`DATA_DIR'/`f'.dta"
}

}

* ===== Summary =====
* Fold the run_test/test_pass/test_fail harness counters into the totals.
local pass_count = `pass_count' + $TVQA_PASS
local fail_count = `fail_count' + $TVQA_FAIL
local failed_tests "`failed_tests' $TVQA_FAILED"
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA cross-command integration Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: test_integration tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"

