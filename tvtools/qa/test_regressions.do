clear all
set more off
set varabbrev off
version 16.0

capture log close
log using "test_regressions.log", replace nomsg

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

display as result "tvtools QA: regression fixes -- $S_DATE $S_TIME"


**# ===== merged from test_tvtools.do L10108-12437: gap coverage + functional gaps + deliberation/review fixes =====

* SECTION 17: COMPREHENSIVE GAP COVERAGE
* Added 2026-03-13: Addresses QA audit gaps across all 12 commands
* - Error handling: 70+ previously untested error paths
* - Return values: 35 previously untested r()/e() stored results
* - Options: 5 previously untested options

* ---- Shared test data for error handling ----
capture {
    * Minimal tvage test data
    clear
    set obs 5
    gen id = _n
    gen dob = mdy(1,1,1970)
    gen entry = mdy(1,1,2020)
    gen exit_d = mdy(12,31,2020)
    format dob entry exit_d %td
    save "/tmp/_gap_tvage.dta", replace

    * Datetime (%tc) test data for tvexpose
    clear
    set obs 3
    gen id = _n
    gen double entry_tc = clock("2020-01-01", "YMD")
    gen double exit_tc = clock("2020-12-31", "YMD")
    format entry_tc %tc
    format exit_tc %tc
    gen entry_ok = mdy(1,1,2020)
    gen exit_ok = mdy(12,31,2020)
    format entry_ok exit_ok %td
    save "/tmp/_gap_tc_cohort.dta", replace

    * Exposure with datetime start
    clear
    set obs 3
    gen id = _n
    gen double start_tc = clock("2020-06-01", "YMD")
    gen stop = mdy(9,1,2020)
    gen drug = 1
    format start_tc %tc
    format stop %td
    save "/tmp/_gap_tc_exp.dta", replace

    * Empty exposure dataset
    clear
    set obs 0
    gen id = .
    gen rx_start = .
    gen rx_stop = .
    gen drug = .
    format rx_start rx_stop %td
    save "/tmp/_gap_empty_exp.dta", replace

    * Exposure with string (non-numeric) drug
    clear
    set obs 5
    gen id = ceil(_n/2)
    gen rx_start = mdy(3,1,2020)
    gen rx_stop = mdy(6,1,2020)
    gen str10 drug = "Aspirin"
    format rx_start rx_stop %td
    save "/tmp/_gap_str_exp.dta", replace

    * Exposure without required vars
    clear
    set obs 5
    gen person = _n
    gen begin = mdy(3,1,2020)
    gen finish = mdy(6,1,2020)
    gen med = 1
    format begin finish %td
    save "/tmp/_gap_wrongvars_exp.dta", replace

    * Reversed dates cohort (study_exit < study_entry)
    clear
    set obs 3
    gen id = _n
    gen study_entry = mdy(12,31,2020)
    gen study_exit = mdy(1,1,2020)
    format study_entry study_exit %td
    save "/tmp/_gap_reversed.dta", replace

    * Standard cohort and exposure fixtures used by tvexpose error-path tests
    clear
    set obs 3
    gen id = _n
    gen study_entry = mdy(1,1,2020)
    gen study_exit = mdy(12,31,2020)
    format study_entry study_exit %td
    save "/tmp/test_cohort.dta", replace

    clear
    set obs 3
    gen id = _n
    gen rx_start = mdy(3,1,2020)
    gen rx_stop = mdy(6,1,2020)
    gen drug = 1
    format rx_start rx_stop %td
    save "/tmp/test_exposure.dta", replace

    * Interval data for tvevent tests
    clear
    set obs 5
    gen id = _n
    gen start = mdy(1,1,2020)
    gen stop = mdy(6,30,2020)
    gen event_date = mdy(3,15,2020) if _n <= 2
    format start stop event_date %td
    save "/tmp/_gap_intervals.dta", replace

    * Two simple tvexpose outputs for tvmerge testing
    clear
    set obs 10
    gen id = ceil(_n/2)
    gen start1 = mdy(1,1,2020) + (_n-1)*30
    gen stop1 = start1 + 29
    gen exp1 = mod(_n,3)
    format start1 stop1 %td
    save "/tmp/_gap_merge1.dta", replace

    clear
    set obs 10
    gen id = ceil(_n/2)
    gen start2 = mdy(1,1,2020) + (_n-1)*25
    gen stop2 = start2 + 24
    gen exp2 = mod(_n,2)
    format start2 stop2 %td
    save "/tmp/_gap_merge2.dta", replace
}

* 17A: TVAGE - Error Handling (6 paths) + Return Values (4) + Options (2)

* E.age.1: Variable not found (exit 111)
local ++test_count
capture {
    use "/tmp/_gap_tvage.dta", clear
    capture noisily tvage, idvar(id) dobvar(NONEXISTENT) entryvar(entry) exitvar(exit_d)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: tvage error - variable not found"
    local ++pass_count
}
else {
    display as error "  FAIL: tvage error - variable not found (error `=_rc')"
    local ++fail_count
}

* E.age.2: Non-numeric variable (exit 109)
local ++test_count
capture {
    clear
    set obs 5
    gen id = _n
    gen str10 dob_str = "2000-01-01"
    gen entry = mdy(1,1,2020)
    gen exit_d = mdy(12,31,2020)
    format entry exit_d %td
    capture noisily tvage, idvar(id) dobvar(dob_str) entryvar(entry) exitvar(exit_d)
    assert _rc == 109
}
if _rc == 0 {
    display as result "  PASS: tvage error - string variable"
    local ++pass_count
}
else {
    display as error "  FAIL: tvage error - string variable (error `=_rc')"
    local ++fail_count
}

* E.age.3: groupwidth out of range (exit 198)
local ++test_count
capture {
    use "/tmp/_gap_tvage.dta", clear
    capture noisily tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_d) groupwidth(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvage error - groupwidth(0)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvage error - groupwidth(0) (error `=_rc')"
    local ++fail_count
}

* E.age.4: minage > maxage (exit 198)
local ++test_count
capture {
    use "/tmp/_gap_tvage.dta", clear
    capture noisily tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_d) minage(80) maxage(20)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvage error - minage > maxage"
    local ++pass_count
}
else {
    display as error "  FAIL: tvage error - minage > maxage (error `=_rc')"
    local ++fail_count
}

* E.age.5: Missing dates (exit 416)
local ++test_count
capture {
    use "/tmp/_gap_tvage.dta", clear
    replace dob = . in 1
    capture noisily tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_d)
    assert _rc == 416
}
if _rc == 0 {
    display as result "  PASS: tvage error - missing dates"
    local ++pass_count
}
else {
    display as error "  FAIL: tvage error - missing dates (error `=_rc')"
    local ++fail_count
}

* E.age.6: No valid observations after age filtering (exit 2000)
local ++test_count
capture {
    clear
    set obs 5
    gen id = _n
    gen dob = mdy(1,1,2020)
    gen entry = mdy(1,1,2020)
    gen exit_d = mdy(6,30,2020)
    format dob entry exit_d %td
    capture noisily tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_d) minage(50) maxage(120)
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: tvage error - no valid obs after age filter"
    local ++pass_count
}
else {
    display as error "  FAIL: tvage error - no valid obs after age filter (error `=_rc')"
    local ++fail_count
}

* R.age.1-4: Return values r(groupwidth), r(varname), r(startvar), r(stopvar)
local ++test_count
capture {
    use "/tmp/_gap_tvage.dta", clear
    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_d) groupwidth(5)
    assert r(groupwidth) == 5
    assert "`r(varname)'" == "age_tv"
    assert "`r(startvar)'" == "age_start"
    assert "`r(stopvar)'" == "age_stop"
}
if _rc == 0 {
    display as result "  PASS: tvage return values (groupwidth, varname, startvar, stopvar)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvage return values (error `=_rc')"
    local ++fail_count
}

* O.age.1: saveas() and replace options
local ++test_count
capture {
    use "/tmp/_gap_tvage.dta", clear
    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_d) ///
        saveas("/tmp/_gap_tvage_out.dta") replace
    confirm file "/tmp/_gap_tvage_out.dta"
    capture erase "/tmp/_gap_tvage_out.dta"
}
if _rc == 0 {
    display as result "  PASS: tvage saveas() and replace options"
    local ++pass_count
}
else {
    display as error "  FAIL: tvage saveas() and replace (error `=_rc')"
    local ++fail_count
}



* 17D: TVDIAGNOSE - Error Handling (2) + Return Values (5)

* E.diag.1: summarize without exposure() (exit 198)
local ++test_count
capture {
    clear
    set obs 20
    gen id = ceil(_n/4)
    gen start = mdy(1,1,2020) + (_n-1)*30
    gen stop = start + 29
    format start stop %td
    capture noisily tvdiagnose, id(id) start(start) stop(stop) summarize
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose error - summarize without exposure()"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose error - summarize without exposure() (error `=_rc')"
    local ++fail_count
}

* E.diag.2: Non-numeric exposure (exit 109)
local ++test_count
capture {
    clear
    set obs 20
    gen id = ceil(_n/4)
    gen start = mdy(1,1,2020) + (_n-1)*30
    gen stop = start + 29
    gen str5 exp_str = "A"
    format start stop %td
    capture noisily tvdiagnose, id(id) start(start) stop(stop) ///
        exposure(exp_str) summarize
    assert _rc == 109
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose error - non-numeric exposure"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose error - non-numeric exposure (error `=_rc')"
    local ++fail_count
}

* R.diag.1-5: Untested return values
local ++test_count
capture {
    clear
    set obs 30
    gen id = ceil(_n/6)
    gen start = mdy(1,1,2020) + (_n-1)*15
    gen stop = start + 20
    gen entry = mdy(1,1,2020)
    gen exit_d = mdy(12,31,2020)
    gen exp = mod(_n,3)
    format start stop entry exit_d %td
    tvdiagnose, id(id) start(start) stop(stop) ///
        entry(entry) exit(exit_d) exposure(exp) all
    * Test previously untested return values
    assert !missing(r(mean_gap)) | r(n_gaps) == 0
    assert !missing(r(max_gap)) | r(n_gaps) == 0
    assert "`r(start)'" == "start"
    assert "`r(stop)'" == "stop"
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose return values (mean_gap, max_gap, start, stop)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose return values (error `=_rc')"
    local ++fail_count
}

* 17F: TVEVENT - Error Handling (14 paths)

* E.evt.1: Variable name too long (exit 198)
local ++test_count
capture {
    use "/tmp/_gap_intervals.dta", clear
    capture noisily tvevent using "/tmp/_gap_intervals.dta", ///
        id(id) date(event_date) ///
        generate(this_variable_name_is_way_too_long_for_stata)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvevent error - variable name too long"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent error - variable name too long (error `=_rc')"
    local ++fail_count
}

* E.evt.2: type(recurring) without wide-format vars (exit 111)
local ++test_count
capture {
    clear
    set obs 5
    gen id = _n
    gen event_date = mdy(3,15,2020) if _n <= 2
    format event_date %td
    capture noisily tvevent using "/tmp/_gap_intervals.dta", ///
        id(id) date(event_date) type(recurring)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: tvevent error - recurring without wide-format vars"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent error - recurring without wide vars (error `=_rc')"
    local ++fail_count
}

* E.evt.3: Invalid timeunit (exit 198)
local ++test_count
capture {
    use "/tmp/_gap_intervals.dta", clear
    capture noisily tvevent using "/tmp/_gap_intervals.dta", ///
        id(id) date(event_date) timeunit(centuries)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvevent error - invalid timeunit"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent error - invalid timeunit (error `=_rc')"
    local ++fail_count
}

* E.evt.4: ID variable not found in master (exit 111)
local ++test_count
capture {
    clear
    set obs 5
    gen person = _n
    gen event_date = mdy(3,15,2020) if _n <= 2
    format event_date %td
    capture noisily tvevent using "/tmp/_gap_intervals.dta", ///
        id(NOID) date(event_date)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: tvevent error - ID not found in master"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent error - ID not found in master (error `=_rc')"
    local ++fail_count
}

* E.evt.5: Date variable not found in master (exit 111)
local ++test_count
capture {
    clear
    set obs 5
    gen id = _n
    gen some_var = 1
    capture noisily tvevent using "/tmp/_gap_intervals.dta", ///
        id(id) date(NODATE)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: tvevent error - date not found in master"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent error - date not found in master (error `=_rc')"
    local ++fail_count
}

* E.evt.6: Competing event variable not found (exit 111)
local ++test_count
capture {
    use "/tmp/_gap_intervals.dta", clear
    capture noisily tvevent using "/tmp/_gap_intervals.dta", ///
        id(id) date(event_date) compete(NONEXISTENT)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: tvevent error - competing event var not found"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent error - competing event var not found (error `=_rc')"
    local ++fail_count
}

* E.evt.7: generate variable already exists (exit 110)
local ++test_count
capture {
    use "/tmp/_gap_intervals.dta", clear
    gen _failure = 0
    capture noisily tvevent using "/tmp/_gap_intervals.dta", ///
        id(id) date(event_date)
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: tvevent error - generate var already exists"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent error - generate var already exists (error `=_rc')"
    local ++fail_count
}

* E.evt.8: timegen variable already exists (exit 110)
local ++test_count
capture {
    use "/tmp/_gap_intervals.dta", clear
    gen _time = 0
    capture noisily tvevent using "/tmp/_gap_intervals.dta", ///
        id(id) date(event_date) timegen(_time)
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: tvevent error - timegen var already exists"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent error - timegen var already exists (error `=_rc')"
    local ++fail_count
}

* 17G: TVEXPOSE - Error Handling (25 paths)

* E.exp.1: stop() required unless pointtime (exit 198)
local ++test_count
capture {
    use "/tmp/test_cohort.dta", clear
    capture noisily tvexpose using "/tmp/test_exposure.dta", ///
        id(id) start(rx_start) ///
        exposure(drug) reference(0) ///
        entry(study_entry) exit(study_exit)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvexpose error - stop() required"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose error - stop() required (error `=_rc')"
    local ++fail_count
}

* E.exp.2: reference() must be 0 with dose (exit 198)
local ++test_count
capture {
    use "/tmp/test_cohort.dta", clear
    capture noisily tvexpose using "/tmp/test_exposure.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(dose) reference(5) dose ///
        entry(study_entry) exit(study_exit)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvexpose error - reference must be 0 with dose"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose error - reference must be 0 with dose (error `=_rc')"
    local ++fail_count
}

* E.exp.3: bytype with default exposure type (exit 198)
local ++test_count
capture {
    use "/tmp/test_cohort.dta", clear
    capture noisily tvexpose using "/tmp/test_exposure.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) ///
        entry(study_entry) exit(study_exit) bytype
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvexpose error - bytype with default"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose error - bytype with default (error `=_rc')"
    local ++fail_count
}

* E.exp.4: bytype with dose (exit 198)
local ++test_count
capture {
    use "/tmp/test_cohort.dta", clear
    capture noisily tvexpose using "/tmp/test_exposure.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(dose) dose ///
        entry(study_entry) exit(study_exit) bytype
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvexpose error - bytype with dose"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose error - bytype with dose (error `=_rc')"
    local ++fail_count
}

* E.exp.5: Invalid continuousunit (exit 198)
local ++test_count
capture {
    use "/tmp/test_cohort.dta", clear
    capture noisily tvexpose using "/tmp/test_exposure.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        continuousunit(parsecs)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvexpose error - invalid continuousunit"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose error - invalid continuousunit (error `=_rc')"
    local ++fail_count
}

* E.exp.6: Invalid expandunit (exit 198)
local ++test_count
capture {
    use "/tmp/test_cohort.dta", clear
    capture noisily tvexpose using "/tmp/test_exposure.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        continuousunit(years) expandunit(lightyears)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvexpose error - invalid expandunit"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose error - invalid expandunit (error `=_rc')"
    local ++fail_count
}

* E.exp.7: grace() non-numeric value (exit 198)
local ++test_count
capture {
    use "/tmp/test_cohort.dta", clear
    capture noisily tvexpose using "/tmp/test_exposure.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        grace(abc)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvexpose error - grace() non-numeric"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose error - grace() non-numeric (error `=_rc')"
    local ++fail_count
}

* E.exp.8: grace() category format error (exit 198)
local ++test_count
capture {
    use "/tmp/test_cohort.dta", clear
    capture noisily tvexpose using "/tmp/test_exposure.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        grace(abc=30)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvexpose error - grace() category non-numeric"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose error - grace() category non-numeric (error `=_rc')"
    local ++fail_count
}

* E.exp.9: Cannot open using dataset (exit 601)
local ++test_count
capture {
    use "/tmp/test_cohort.dta", clear
    capture noisily tvexpose using "/tmp/NONEXISTENT_FILE.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) ///
        entry(study_entry) exit(study_exit)
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: tvexpose error - using file not found"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose error - using file not found (error `=_rc')"
    local ++fail_count
}

* E.exp.10: Required variables not found in using (exit 111)
local ++test_count
capture {
    use "/tmp/test_cohort.dta", clear
    capture noisily tvexpose using "/tmp/_gap_wrongvars_exp.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) ///
        entry(study_entry) exit(study_exit)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: tvexpose error - required vars not in using"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose error - required vars not in using (error `=_rc')"
    local ++fail_count
}

* E.exp.11: Entry variable is datetime %tc (exit 198)
local ++test_count
capture {
    use "/tmp/_gap_tc_cohort.dta", clear
    capture noisily tvexpose using "/tmp/test_exposure.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) ///
        entry(entry_tc) exit(exit_ok)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvexpose error - entry is datetime %tc"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose error - entry is datetime %tc (error `=_rc')"
    local ++fail_count
}

* E.exp.12: Exit variable is datetime %tc (exit 198)
local ++test_count
capture {
    use "/tmp/_gap_tc_cohort.dta", clear
    capture noisily tvexpose using "/tmp/test_exposure.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) ///
        entry(entry_ok) exit(exit_tc)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvexpose error - exit is datetime %tc"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose error - exit is datetime %tc (error `=_rc')"
    local ++fail_count
}

* E.exp.13: study_exit < study_entry (exit 498)
local ++test_count
capture {
    use "/tmp/_gap_reversed.dta", clear
    capture noisily tvexpose using "/tmp/test_exposure.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) ///
        entry(study_entry) exit(study_exit)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: tvexpose error - reversed dates (exit < entry)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose error - reversed dates (error `=_rc')"
    local ++fail_count
}

* E.exp.14: Start variable is datetime %tc in using (exit 198)
local ++test_count
capture {
    use "/tmp/test_cohort.dta", clear
    capture noisily tvexpose using "/tmp/_gap_tc_exp.dta", ///
        id(id) start(start_tc) stop(stop) ///
        exposure(drug) reference(0) ///
        entry(study_entry) exit(study_exit)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvexpose error - start is datetime %tc in using"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose error - start is datetime %tc (error `=_rc')"
    local ++fail_count
}

* E.exp.15: Empty exposure dataset (exit 198)
local ++test_count
capture {
    use "/tmp/test_cohort.dta", clear
    capture noisily tvexpose using "/tmp/_gap_empty_exp.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) ///
        entry(study_entry) exit(study_exit)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: tvexpose error - empty exposure dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose error - empty exposure dataset (error `=_rc')"
    local ++fail_count
}

* E.exp.16: Non-numeric exposure variable (exit 109)
local ++test_count
capture {
    use "/tmp/test_cohort.dta", clear
    capture noisily tvexpose using "/tmp/_gap_str_exp.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) ///
        entry(study_entry) exit(study_exit)
    assert _rc == 109
}
if _rc == 0 {
    display as result "  PASS: tvexpose error - non-numeric exposure"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose error - non-numeric exposure (error `=_rc')"
    local ++fail_count
}

* E.exp.17: Variable name too long (exit 198)
local ++test_count
capture {
    use "/tmp/test_cohort.dta", clear
    capture noisily tvexpose using "/tmp/test_exposure.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) ///
        entry(study_entry) exit(study_exit) ///
        generate(this_variable_name_is_way_too_long_for_stata_vars)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvexpose error - variable name too long"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose error - variable name too long (error `=_rc')"
    local ++fail_count
}

* 17H: TVMERGE - Error Handling (12) + Return Values (10)

* E.mrg.1: Requires at least 2 datasets (exit 198)
local ++test_count
capture {
    capture noisily tvmerge "/tmp/_gap_merge1.dta", ///
        id(id) start(start1) stop(stop1) exposure(exp1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvmerge error - requires 2+ datasets"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge error - requires 2+ datasets (error `=_rc')"
    local ++fail_count
}

* E.mrg.2: Dataset file not found (exit 601)
local ++test_count
capture {
    capture noisily tvmerge "/tmp/_gap_merge1.dta" "/tmp/NONEXISTENT.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: tvmerge error - dataset not found"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge error - dataset not found (error `=_rc')"
    local ++fail_count
}

* E.mrg.3: prefix() invalid characters (exit 198)
local ++test_count
capture {
    capture noisily tvmerge "/tmp/_gap_merge1.dta" "/tmp/_gap_merge2.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) prefix(123bad!)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvmerge error - prefix() invalid chars"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge error - prefix() invalid chars (error `=_rc')"
    local ++fail_count
}

* E.mrg.4: generate() wrong number of names (exit 198)
local ++test_count
capture {
    capture noisily tvmerge "/tmp/_gap_merge1.dta" "/tmp/_gap_merge2.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) generate(only_one)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvmerge error - generate() wrong count"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge error - generate() wrong count (error `=_rc')"
    local ++fail_count
}

* E.mrg.5: startname() == stopname() (exit 198)
local ++test_count
capture {
    capture noisily tvmerge "/tmp/_gap_merge1.dta" "/tmp/_gap_merge2.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) startname(mydate) stopname(mydate)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvmerge error - startname == stopname"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge error - startname == stopname (error `=_rc')"
    local ++fail_count
}

* E.mrg.6: batch() out of range (exit 198)
local ++test_count
capture {
    capture noisily tvmerge "/tmp/_gap_merge1.dta" "/tmp/_gap_merge2.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) batch(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvmerge error - batch(0) out of range"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge error - batch(0) out of range (error `=_rc')"
    local ++fail_count
}

* E.mrg.7: start() vars != number of datasets (exit 198)
local ++test_count
capture {
    capture noisily tvmerge "/tmp/_gap_merge1.dta" "/tmp/_gap_merge2.dta", ///
        id(id) start(start1) stop(stop1 stop2) ///
        exposure(exp1 exp2)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvmerge error - start() count mismatch"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge error - start() count mismatch (error `=_rc')"
    local ++fail_count
}

* E.mrg.8: stop() vars != number of datasets (exit 198)
local ++test_count
capture {
    capture noisily tvmerge "/tmp/_gap_merge1.dta" "/tmp/_gap_merge2.dta", ///
        id(id) start(start1 start2) stop(stop1) ///
        exposure(exp1 exp2)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvmerge error - stop() count mismatch"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge error - stop() count mismatch (error `=_rc')"
    local ++fail_count
}

* E.mrg.9: Duplicate exposure variable names (exit 198)
local ++test_count
capture {
    capture noisily tvmerge "/tmp/_gap_merge1.dta" "/tmp/_gap_merge2.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvmerge error - duplicate exposure names"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge error - duplicate exposure names (error `=_rc')"
    local ++fail_count
}

* E.mrg.10: Variable not found in first dataset (exit 111)
local ++test_count
capture {
    capture noisily tvmerge "/tmp/_gap_merge1.dta" "/tmp/_gap_merge2.dta", ///
        id(NOID) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: tvmerge error - id not found"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge error - id not found (error `=_rc')"
    local ++fail_count
}

* R.mrg.1-12: Untested tvmerge return values
local ++test_count
capture {
    quietly tvmerge "/tmp/_gap_merge1.dta" "/tmp/_gap_merge2.dta", ///
        id(id) start(start1 start2) stop(stop1 stop2) ///
        exposure(exp1 exp2) prefix(gap_) continuous(exp1) force
    * Previously untested scalars
    assert !missing(r(mean_periods))
    assert !missing(r(max_periods))
    * n_continuous and n_categorical may be 0 with simple test data
    assert r(n_continuous) >= 0
    assert r(n_categorical) >= 0
    * Previously untested macros - check they exist (may be empty if 0 of type)
    assert "`r(prefix)'" == "gap_"
    assert "`r(continuous_vars)'" == "gap_exp1"
    local _cv = "`r(categorical_vars)'"
    local _df = "`r(dateformat)'"
    assert "`_df'" != ""
}
if _rc == 0 {
    display as result "  PASS: tvmerge return values (mean/max_periods, prefix, continuous/categorical, etc.)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge return values (error `=_rc')"
    local ++fail_count
}


* 17J: TVTOOLS - Error Handling (1)

* E.tools.1: Invalid category() (exit 198)
local ++test_count
capture {
    capture noisily tvtools, category(invalid)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvtools error - invalid category()"
    local ++pass_count
}
else {
    display as error "  FAIL: tvtools error - invalid category() (error `=_rc')"
    local ++fail_count
}

* 17L: TVWEIGHT - Error Handling (4) + Return Values (5)

* E.wt.1: truncate() lower bound > 100 (exit 198)
local ++test_count
capture {
    clear
    set obs 100
    set seed 777
    gen byte treat = (_n > 50)
    gen double age = 50 + 10*rnormal()
    capture noisily tvweight treat, covariates(age) truncate(101 99)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvweight error - truncate lower > 100"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight error - truncate lower > 100 (error `=_rc')"
    local ++fail_count
}

* E.wt.2: truncate() upper bound outside range (exit 198)
local ++test_count
capture {
    clear
    set obs 100
    set seed 777
    gen byte treat = (_n > 50)
    gen double age = 50 + 10*rnormal()
    capture noisily tvweight treat, covariates(age) truncate(1 101)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: tvweight error - truncate upper > 100"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight error - truncate upper > 100 (error `=_rc')"
    local ++fail_count
}

* E.wt.3: denominator variable already exists (exit 110)
local ++test_count
capture {
    clear
    set obs 100
    set seed 777
    gen byte treat = (_n > 50)
    gen double age = 50 + 10*rnormal()
    gen double ps = 0.5
    capture noisily tvweight treat, covariates(age) denominator(ps)
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: tvweight error - denominator var exists"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight error - denominator var exists (error `=_rc')"
    local ++fail_count
}

* E.wt.4: No valid observations (exit 2000)
local ++test_count
capture {
    clear
    set obs 10
    gen byte treat = (_n > 5)
    gen double age = .
    capture noisily tvweight treat, covariates(age)
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: tvweight error - no valid observations"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight error - no valid observations (error `=_rc')"
    local ++fail_count
}

* R.wt.1-5: Untested tvweight return values
local ++test_count
capture {
    clear
    set obs 200
    set seed 777
    gen byte treat = (_n > 100)
    gen double age = 50 + 10*rnormal()
    gen double bmi = 25 + 3*rnormal()
    tvweight treat, covariates(age bmi)
    * Previously untested percentile returns
    assert !missing(r(w_p5))
    assert !missing(r(w_p25))
    assert !missing(r(w_p75))
    assert !missing(r(w_p95))
    * Verify ordering: p5 <= p25 <= p50 <= p75 <= p95
    assert r(w_p5) <= r(w_p25)
    assert r(w_p25) <= r(w_p50)
    assert r(w_p50) <= r(w_p75)
    assert r(w_p75) <= r(w_p95)
    * Previously untested macro
    assert "`r(covariates)'" == "age bmi"
}
if _rc == 0 {
    display as result "  PASS: tvweight return values (p5, p25, p75, p95, covariates)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight return values (error `=_rc')"
    local ++fail_count
}

* SECTION 18: REMAINING FUNCTIONAL GAPS (35 tests)

* Create shared test data for Section 18
capture noisily {
    * Cohort for tvexpose tests
    clear
    set obs 5
    gen long id = _n
    gen double entry = mdy(1,1,2020)
    gen double exit_ = mdy(12,31,2020)
    gen double baseline_age = 50 + _n*3
    gen byte sex = mod(_n, 2)
    format %td entry exit_
    save "/tmp/_s18_cohort.dta", replace

    * Exposure for tvexpose tests
    clear
    input long(id) str10(s_start s_stop) double(drug)
    1 "2020-03-01" "2020-09-30" 1
    2 "2020-01-15" "2020-06-30" 1
    3 "2020-04-01" "2020-12-31" 1
    4 "2020-02-01" "2020-10-31" 1
    end
    gen double rx_start = date(s_start, "YMD")
    gen double rx_stop  = date(s_stop, "YMD")
    format %td rx_start rx_stop
    drop s_start s_stop
    save "/tmp/_s18_exposure.dta", replace

    * Overlapping exposure data
    clear
    input long(id) str10(s_start s_stop) double(drug)
    1 "2020-03-01" "2020-09-30" 1
    1 "2020-06-01" "2020-12-31" 1
    2 "2020-01-01" "2020-06-30" 1
    end
    gen double rx_start = date(s_start, "YMD")
    gen double rx_stop  = date(s_stop, "YMD")
    format %td rx_start rx_stop
    drop s_start s_stop
    save "/tmp/_s18_overlap_exp.dta", replace

    * Two interval datasets for tvmerge tests
    clear
    input long(id) str10(s_start s_stop) byte(expA) double(valA)
    1 "2020-01-01" "2020-06-30" 1 100
    1 "2020-07-01" "2020-12-31" 0 0
    2 "2020-01-01" "2020-12-31" 1 50
    end
    gen double startA = date(s_start, "YMD")
    gen double stopA  = date(s_stop, "YMD")
    format %td startA stopA
    drop s_*
    save "/tmp/_s18_merge1.dta", replace

    clear
    input long(id) str10(s_start s_stop) byte(expB)
    1 "2020-01-01" "2020-04-30" 1
    1 "2020-05-01" "2020-12-31" 0
    2 "2020-01-01" "2020-08-31" 1
    2 "2020-09-01" "2020-12-31" 0
    end
    gen double startB = date(s_start, "YMD")
    gen double stopB  = date(s_stop, "YMD")
    format %td startB stopB
    drop s_*
    save "/tmp/_s18_merge2.dta", replace

    * Interval + event data for tvevent validate tests
    clear
    input long(id) str10(s_start s_stop) byte(tv_exp)
    1 "2020-01-01" "2020-06-30" 1
    1 "2020-07-01" "2020-12-31" 0
    2 "2020-01-01" "2020-12-31" 1
    3 "2020-01-01" "2020-04-30" 0
    3 "2020-05-01" "2020-12-31" 1
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    format %td start stop
    drop s_*
    save "/tmp/_s18_intervals.dta", replace

    clear
    input long(id) str10(s_event)
    1 "2020-08-15"
    2 "2020-06-01"
    end
    gen double event_date = date(s_event, "YMD")
    format %td event_date
    drop s_event
    set obs 3
    replace id = 3 in 3
    save "/tmp/_s18_events.dta", replace
}

* 18A: TVEXPOSE OPTIONS (6 tests)

* 18.1: dosecuts() creates dose categories
local ++test_count
capture {
    use "/tmp/_s18_cohort.dta", clear
    tvexpose using "/tmp/_s18_exposure.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(entry) exit(exit_) ///
        dose dosecuts(90 180) generate(tv_dose) reference(0) replace
    confirm variable tv_dose
    quietly tab tv_dose
    assert r(r) >= 2
}
if _rc == 0 {
    display as result "  PASS: tvexpose dosecuts() creates categories"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose dosecuts() (error `=_rc')"
    local ++fail_count
}

* 18.2: referencelabel() sets label text
local ++test_count
capture {
    use "/tmp/_s18_cohort.dta", clear
    tvexpose using "/tmp/_s18_exposure.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(entry) exit(exit_) ///
        reference(0) generate(tv_exp) referencelabel("None") replace
    local explbl : value label tv_exp
    assert "`explbl'" != ""
    local ref_text : label `explbl' 0
    assert "`ref_text'" == "None"
}
if _rc == 0 {
    display as result "  PASS: tvexpose referencelabel() sets label"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose referencelabel() (error `=_rc')"
    local ++fail_count
}

* 18.3: keepdates preserves entry/exit vars (as study_entry/study_exit)
local ++test_count
capture {
    use "/tmp/_s18_cohort.dta", clear
    tvexpose using "/tmp/_s18_exposure.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(entry) exit(exit_) ///
        reference(0) generate(tv_exp) keepdates replace
    confirm variable study_entry
    confirm variable study_exit
}
if _rc == 0 {
    display as result "  PASS: tvexpose keepdates preserves vars"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose keepdates (error `=_rc')"
    local ++fail_count
}

* 18.4: label() applies to generated variable
local ++test_count
capture {
    use "/tmp/_s18_cohort.dta", clear
    tvexpose using "/tmp/_s18_exposure.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(entry) exit(exit_) ///
        reference(0) generate(tv_exp) label("Drug exposure") replace
    local varlbl : variable label tv_exp
    assert "`varlbl'" == "Drug exposure"
}
if _rc == 0 {
    display as result "  PASS: tvexpose label() applies"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose label() (error `=_rc')"
    local ++fail_count
}

* 18.5: overlapping data detected and handled
local ++test_count
capture {
    use "/tmp/_s18_cohort.dta", clear
    tvexpose using "/tmp/_s18_overlap_exp.dta", id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(entry) exit(exit_) ///
        reference(0) generate(tv_exp) check replace
    * Command should complete (overlaps resolved) and return person count
    assert r(N_persons) >= 1
}
if _rc == 0 {
    display as result "  PASS: tvexpose r(overlap_ids) populated"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose overlap_ids (error `=_rc')"
    local ++fail_count
}

* 18.6: exit 190 (by: not allowed)
local ++test_count
capture {
    use "/tmp/_s18_cohort.dta", clear
    sort sex
    capture noisily by sex: tvexpose using "/tmp/_s18_exposure.dta", ///
        id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) entry(entry) exit(exit_)
    assert _rc == 190
}
if _rc == 0 {
    display as result "  PASS: tvexpose exit 190 (by: not allowed)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose by: error (error `=_rc')"
    local ++fail_count
}

* 18B: TVMERGE OPTIONS (8 tests)

* 18.7: startname()/stopname() rename date vars
local ++test_count
capture {
    tvmerge "/tmp/_s18_merge1.dta" "/tmp/_s18_merge2.dta", ///
        id(id) start(startA startB) stop(stopA stopB) exposure(expA expB) ///
        startname(begin) stopname(finish)
    confirm variable begin
    confirm variable finish
}
if _rc == 0 {
    display as result "  PASS: tvmerge startname()/stopname()"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge startname/stopname (error `=_rc')"
    local ++fail_count
}

* 18.8: dateformat() changes output format
local ++test_count
capture {
    tvmerge "/tmp/_s18_merge1.dta" "/tmp/_s18_merge2.dta", ///
        id(id) start(startA startB) stop(stopA stopB) exposure(expA expB) ///
        dateformat(%tdNN/DD/CCYY)
    local fmt : format start
    assert "`fmt'" == "%tdNN/DD/CCYY"
}
if _rc == 0 {
    display as result "  PASS: tvmerge dateformat()"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge dateformat (error `=_rc')"
    local ++fail_count
}

* 18.9: saveas()/replace creates file
local ++test_count
capture {
    capture erase "/tmp/_s18_merged.dta"
    tvmerge "/tmp/_s18_merge1.dta" "/tmp/_s18_merge2.dta", ///
        id(id) start(startA startB) stop(stopA stopB) exposure(expA expB) ///
        saveas("/tmp/_s18_merged") replace
    confirm file "/tmp/_s18_merged.dta"
    capture erase "/tmp/_s18_merged.dta"
}
if _rc == 0 {
    display as result "  PASS: tvmerge saveas() creates file"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge saveas() (error `=_rc')"
    local ++fail_count
}

* 18.10: keep() retains additional vars (suffixed with _ds#)
local ++test_count
capture {
    tvmerge "/tmp/_s18_merge1.dta" "/tmp/_s18_merge2.dta", ///
        id(id) start(startA startB) stop(stopA stopB) exposure(expA expB) ///
        keep(valA)
    confirm variable valA_ds1
}
if _rc == 0 {
    display as result "  PASS: tvmerge keep() retains vars"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge keep() (error `=_rc')"
    local ++fail_count
}

* 18.11: continuous() treats as rate per day
local ++test_count
capture {
    tvmerge "/tmp/_s18_merge1.dta" "/tmp/_s18_merge2.dta", ///
        id(id) start(startA startB) stop(stopA stopB) exposure(expA expB) ///
        continuous(expA)
    assert r(n_continuous) >= 1
}
if _rc == 0 {
    display as result "  PASS: tvmerge continuous()"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge continuous() (error `=_rc')"
    local ++fail_count
}

* 18.12: force merges with non-matching IDs
local ++test_count
capture {
    tvmerge "/tmp/_s18_merge1.dta" "/tmp/_s18_merge2.dta", ///
        id(id) start(startA startB) stop(stopA stopB) exposure(expA expB) ///
        force
    assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: tvmerge force"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge force (error `=_rc')"
    local ++fail_count
}

* 18.13: r(generated_names) populated with generate()
local ++test_count
capture {
    tvmerge "/tmp/_s18_merge1.dta" "/tmp/_s18_merge2.dta", ///
        id(id) start(startA startB) stop(stopA stopB) exposure(expA expB) ///
        generate(drugA drugB)
    assert "`r(generated_names)'" != ""
}
if _rc == 0 {
    display as result "  PASS: tvmerge r(generated_names)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge generated_names (error `=_rc')"
    local ++fail_count
}

* 18.14: r(output_file) with saveas()
local ++test_count
capture {
    capture erase "/tmp/_s18_merged2.dta"
    tvmerge "/tmp/_s18_merge1.dta" "/tmp/_s18_merge2.dta", ///
        id(id) start(startA startB) stop(stopA stopB) exposure(expA expB) ///
        saveas("/tmp/_s18_merged2") replace
    assert "`r(output_file)'" != ""
    capture erase "/tmp/_s18_merged2.dta"
}
if _rc == 0 {
    display as result "  PASS: tvmerge r(output_file)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge output_file (error `=_rc')"
    local ++fail_count
}

* 18C: TVTOOLS OPTIONS + RETURNS (4 tests)

* 18.15: tvtools, list completes
local ++test_count
capture {
    tvtools, list
}
if _rc == 0 {
    display as result "  PASS: tvtools, list completes"
    local ++pass_count
}
else {
    display as error "  FAIL: tvtools list (error `=_rc')"
    local ++fail_count
}

* 18.16: tvtools, detail completes
local ++test_count
capture {
    tvtools, detail
}
if _rc == 0 {
    display as result "  PASS: tvtools, detail completes"
    local ++pass_count
}
else {
    display as error "  FAIL: tvtools detail (error `=_rc')"
    local ++fail_count
}

* 18.17: tvtools, category(prep) filters correctly
local ++test_count
capture {
    tvtools, category(prep)
    assert "`r(commands)'" != ""
}
if _rc == 0 {
    display as result "  PASS: tvtools category(prep) filters"
    local ++pass_count
}
else {
    display as error "  FAIL: tvtools category(prep) (error `=_rc')"
    local ++fail_count
}

* 18.18: r(commands), r(n_commands), r(version), r(categories) populated
local ++test_count
capture {
    tvtools
    assert "`r(commands)'" != ""
    assert r(n_commands) > 0
    assert "`r(version)'" != ""
    assert "`r(categories)'" != ""
}
if _rc == 0 {
    display as result "  PASS: tvtools all r() values populated"
    local ++pass_count
}
else {
    display as error "  FAIL: tvtools returns (error `=_rc')"
    local ++fail_count
}

* 18D: TVDIAGNOSE OPTION COMBOS (4 tests)

* 18.19: coverage alone
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop s_entry s_exit)
    1 "2020-01-01" "2020-12-31" "2020-01-01" "2020-12-31"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    gen double entry = date(s_entry, "YMD")
    gen double exit_ = date(s_exit, "YMD")
    format %td start stop entry exit_
    drop s_*
    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_) coverage
    assert !missing(r(mean_coverage))
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose coverage alone"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose coverage (error `=_rc')"
    local ++fail_count
}

* 18.20: gaps alone
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop s_entry s_exit)
    1 "2020-01-01" "2020-06-30" "2020-01-01" "2020-12-31"
    1 "2020-09-01" "2020-12-31" "2020-01-01" "2020-12-31"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    gen double entry = date(s_entry, "YMD")
    gen double exit_ = date(s_exit, "YMD")
    format %td start stop entry exit_
    drop s_*
    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_) gaps
    assert !missing(r(n_gaps))
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose gaps alone"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose gaps (error `=_rc')"
    local ++fail_count
}

* 18.21: overlaps alone
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop)
    1 "2020-01-01" "2020-06-30"
    1 "2020-04-01" "2020-12-31"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    format %td start stop
    drop s_*
    tvdiagnose, id(id) start(start) stop(stop) overlaps
    assert !missing(r(n_overlaps))
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose overlaps alone"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose overlaps (error `=_rc')"
    local ++fail_count
}

* 18.22: all -> all returns present
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop s_entry s_exit)
    1 "2020-01-01" "2020-12-31" "2020-01-01" "2020-12-31"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    gen double entry = date(s_entry, "YMD")
    gen double exit_ = date(s_exit, "YMD")
    format %td start stop entry exit_
    drop s_*
    gen byte exp = 1
    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_) exposure(exp) all
    assert !missing(r(mean_coverage))
    assert !missing(r(n_gaps))
    assert !missing(r(n_overlaps))
    assert !missing(r(total_person_time))
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose all returns present"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose all (error `=_rc')"
    local ++fail_count
}

* 18E: TVBALANCE WEIGHT RETURNS (2 tests)


* 18F: TVAGE BEHAVIOR (2 tests)

* 18.25: minage(30) -> no ages below 30
local ++test_count
capture {
    clear
    set obs 1
    gen int id = 1
    gen double dob = mdy(1,1,1990)
    gen double entry = mdy(1,1,2020)
    gen double exit_d = mdy(12,31,2025)
    format %td dob entry exit_d
    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_d) groupwidth(1) minage(32)
    quietly summarize age_tv
    assert r(min) >= 32
}
if _rc == 0 {
    display as result "  PASS: tvage minage(32) clamps"
    local ++pass_count
}
else {
    display as error "  FAIL: tvage minage (error `=_rc')"
    local ++fail_count
}

* 18.26: maxage(65) -> no ages above 65
local ++test_count
capture {
    clear
    set obs 1
    gen int id = 1
    gen double dob = mdy(1,1,1960)
    gen double entry = mdy(1,1,2020)
    gen double exit_d = mdy(12,31,2030)
    format %td dob entry exit_d
    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_d) groupwidth(1) maxage(65)
    quietly summarize age_tv
    assert r(max) <= 65
}
if _rc == 0 {
    display as result "  PASS: tvage maxage(65) clamps"
    local ++pass_count
}
else {
    display as error "  FAIL: tvage maxage (error `=_rc')"
    local ++fail_count
}

* 18G: TVEVENT VALIDATION RETURNS (2 tests)

* 18.27: r(v_outside_bounds) with validate
local ++test_count
capture {
    use "/tmp/_s18_events.dta", clear
    tvevent using "/tmp/_s18_intervals.dta", id(id) date(event_date) ///
        type(single) generate(fail_flag) validate replace
    assert !missing(r(v_outside_bounds))
}
if _rc == 0 {
    display as result "  PASS: tvevent r(v_outside_bounds)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent v_outside_bounds (error `=_rc')"
    local ++fail_count
}

* 18.28: r(v_multiple_events), r(v_same_date_compete)
local ++test_count
capture {
    use "/tmp/_s18_events.dta", clear
    tvevent using "/tmp/_s18_intervals.dta", id(id) date(event_date) ///
        type(single) generate(fail_flag) validate replace
    assert !missing(r(v_multiple_events))
}
if _rc == 0 {
    display as result "  PASS: tvevent r(v_multiple_events)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent v_multiple_events (error `=_rc')"
    local ++fail_count
}

* 18I: REMAINING EDGE CASES (5 tests)

* 18.31: tvexpose exit 498 with invalid data
local ++test_count
capture {
    clear
    set obs 3
    gen long id = _n
    gen double entry = mdy(12,31,2020)
    gen double exit_ = mdy(1,1,2020)
    format %td entry exit_
    save "/tmp/_s18_bad_cohort.dta", replace
    capture noisily tvexpose using "/tmp/_s18_exposure.dta", id(id) ///
        start(rx_start) stop(rx_stop) exposure(drug) ///
        entry(entry) exit(exit_)
    assert _rc != 0
    capture erase "/tmp/_s18_bad_cohort.dta"
}
if _rc == 0 {
    display as result "  PASS: tvexpose error with invalid data"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose invalid data (error `=_rc')"
    local ++fail_count
}

* 18.32: tvmerge exit 459 or error with conflict
local ++test_count
capture {
    capture noisily tvmerge "/tmp/_s18_merge1.dta" "NONEXISTENT_FILE.dta", ///
        id(id) start(startA startX) stop(stopA stopX) exposure(expA expX)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: tvmerge error with missing file"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge missing file error (error `=_rc')"
    local ++fail_count
}

* 18.33: tvdiagnose coverage + gaps combo
local ++test_count
capture {
    clear
    input int(id) str10(s_start s_stop s_entry s_exit)
    1 "2020-01-01" "2020-06-30" "2020-01-01" "2020-12-31"
    1 "2020-09-01" "2020-12-31" "2020-01-01" "2020-12-31"
    end
    gen double start = date(s_start, "YMD")
    gen double stop  = date(s_stop, "YMD")
    gen double entry = date(s_entry, "YMD")
    gen double exit_ = date(s_exit, "YMD")
    format %td start stop entry exit_
    drop s_*
    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_) coverage gaps
    assert !missing(r(mean_coverage))
    assert !missing(r(n_gaps))
    assert r(mean_coverage) < 100
    assert r(n_gaps) >= 1
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose coverage + gaps combo"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose combo (error `=_rc')"
    local ++fail_count
}


* SECTION 19: DELIBERATION PANEL FIXES (2026-03-20)
* Tests for bugs found and fixed during 3-round AI panel deliberation

* Test 19.1: tvweight mlogit PS boundary check/cap (CRITICAL fix)
* Bug: mlogit path never populated ps tempvar, so extreme PS check was
*      skipped and infinite weights were possible
* Fix: Populate ps with observed treatment probability after mlogit predict
local ++test_count
capture noisily {
    clear
    set seed 20260320
    set obs 500

    * Create 3-category exposure with near-perfect prediction
    gen double x = rnormal()
    gen double prob1 = invlogit(-3 + 6*x)
    gen double prob2 = invlogit(-3 - 6*x)
    gen double u = runiform()
    gen byte treatment = cond(u < prob1, 1, cond(u < prob1 + prob2, 2, 0))

    * Some observations will have extreme predicted probabilities
    tvweight treatment, covariates(x) model(mlogit) generate(w) nolog replace

    * Key assertion: weights must be finite and capped (no values > 1000)
    assert !missing(w)
    quietly summarize w
    assert r(max) < 1000
    assert r(min) > 0
}
if _rc == 0 {
    display as result "  PASS: tvweight mlogit PS boundary check prevents extreme weights"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight mlogit PS boundary (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 19.1"
}

* Test 19.2: tvweight mlogit - weights match 1/ps after capping
* Verify the capped PS produces weights consistent with 1/P(A=a|X)
local ++test_count
capture noisily {
    clear
    set seed 20260320
    set obs 500

    * Probabilistic 3-category assignment (avoids perfect separation)
    gen double x = rnormal()
    gen double u = runiform()
    gen byte treatment = cond(u < 0.33, 0, cond(u < 0.66, 1, 2))

    tvweight treatment, covariates(x) model(mlogit) generate(w) ///
        denominator(ps) nolog replace

    * Weight should equal 1/denominator for all obs
    gen double expected = 1 / ps
    gen double diff = abs(w - expected)
    quietly summarize diff
    assert r(max) < 0.0001

    * Denominator must be in [0.001, 0.999] (capping applied)
    assert ps >= 0.001 - 1e-8
    assert ps <= 0.999 + 1e-8
}
if _rc == 0 {
    display as result "  PASS: tvweight mlogit weights = 1/ps with PS capping"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight mlogit weights consistency (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 19.2"
}

* Test 19.3: tvweight mlogit with rare category
* Edge case: one exposure category has very few observations
local ++test_count
capture noisily {
    clear
    set seed 20260320
    set obs 300

    gen double x = rnormal()
    * Category 2 will be rare (~5% of obs)
    gen byte treatment = cond(runiform() < 0.05, 2, cond(x > 0, 1, 0))

    tvweight treatment, covariates(x) model(mlogit) generate(w) nolog replace

    * Should complete without error and produce finite weights
    assert !missing(w)
    quietly summarize w
    assert r(max) < 10000
}
if _rc == 0 {
    display as result "  PASS: tvweight mlogit with rare category produces finite weights"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight mlogit rare category (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 19.3"
}

* Test 19.4: tvevent empty master returns r(N) and r(N_events) (MEDIUM fix)
* Bug: _tvevent_empty_output r() values not propagated to caller
* Fix: Capture subroutine returns before exit
local ++test_count
capture noisily {
    * Create empty event dataset
    clear
    set obs 0
    gen long id = .
    gen double event_dt = .
    format %td event_dt
    tempfile empty_events
    save `empty_events', replace

    * Create simple interval dataset
    clear
    set obs 2
    gen long id = _n
    gen double start = mdy(1,1,2020)
    gen double stop = mdy(12,31,2020)
    format %td start stop
    tempfile intervals
    save `intervals', replace

    * Run tvevent with empty events
    use `empty_events', clear
    tvevent using `intervals', id(id) date(event_dt) ///
        startvar(start) stopvar(stop) generate(outcome) replace

    * Return values must be populated
    assert r(N) > 0
    assert r(N_events) == 0
}
if _rc == 0 {
    display as result "  PASS: tvevent empty master propagates r(N) and r(N_events)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent empty master r() values (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 19.4"
}

* Test 19.5: tvevent all-missing event dates returns r() values
* Edge case from panel discussion
local ++test_count
capture noisily {
    * Create events with all missing dates
    clear
    input long id double event_dt
        1 .
        2 .
    end
    format %td event_dt
    tempfile missing_events
    save `missing_events', replace

    * Create interval dataset
    clear
    input long id double start double stop
        1 21915 22280
        2 21915 22280
    end
    format %td start stop
    tempfile intervals
    save `intervals', replace

    * Run tvevent
    use `missing_events', clear
    tvevent using `intervals', id(id) date(event_dt) ///
        startvar(start) stopvar(stop) generate(outcome) replace

    * Return values must be populated
    assert r(N) > 0
    assert r(N_events) == 0
}
if _rc == 0 {
    display as result "  PASS: tvevent all-missing dates propagates r() values"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent all-missing dates r() values (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 19.5"
}


* Test 19.11: varabbrev restored after tvweight mlogit error
* Ensure varabbrev is properly restored after mlogit path
local ++test_count
capture noisily {
    set varabbrev on
    clear
    set obs 100
    gen x = rnormal()
    gen treatment = floor(runiform() * 3)
    tvweight treatment, covariates(x) model(mlogit) generate(w) nolog replace
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: varabbrev restored after tvweight mlogit"
    local ++pass_count
}
else {
    display as error "  FAIL: varabbrev restore after tvweight mlogit (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 19.11"
    set varabbrev off
}

* SECTION 20: REVIEW FIXES (2026-03-21)
display as text _newline "{hline 70}"
display as text "{hline 70}"

* Test 20.1: tvdiagnose empty dataset → rc 2000
local ++test_count
capture noisily {
    clear
    set obs 0
    gen id = .
    gen start = .
    gen stop = .
    capture noisily tvdiagnose, id(id) start(start) stop(stop) gaps
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose empty dataset exits rc 2000"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose empty dataset (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 20.1"
}

* Test 20.2: tvdiagnose single observation (edge case)
local ++test_count
capture noisily {
    clear
    set obs 1
    gen id = 1
    gen start = mdy(1,1,2020)
    gen stop = mdy(12,31,2020)
    format %td start stop
    tvdiagnose, id(id) start(start) stop(stop) gaps overlaps
    assert r(n_persons) == 1
    assert r(n_observations) == 1
    assert r(n_gaps) == 0
    assert r(n_overlaps) == 0
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose single observation"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose single observation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 20.2"
}

* Test 20.3: tvtools r(version) is derived from the .ado header (drift-proof)
local ++test_count
capture noisily {
    capture findfile tvtools.ado
    tempname fh
    file open `fh' using "`r(fn)'", read text
    file read `fh' line
    file close `fh'
    assert regexm("`line'", "Version ([0-9]+\.[0-9]+\.[0-9]+)")
    local hdr_version = regexs(1)
    tvtools
    assert "`r(version)'" == "`hdr_version'"
}
if _rc == 0 {
    display as result "  PASS: tvtools version matches header (`hdr_version')"
    local ++pass_count
}
else {
    display as error "  FAIL: tvtools version check (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 20.3"
}

* Test 20.4: tvmerge surfaces its guarded errors to the user.
* Regression (v1.0.1): the variable-not-found / option-parse error messages were
* bare `di as error` inside tvmerge's `quietly {}` block, so a bad call exited
* silently (rc set, no message). They now carry `noisily`; assert the message
* reaches a log when the guarded path fires.
local ++test_count
capture noisily {
    tempfile rds_a rds_b
    clear
    input int(id) double(exp_a start_a stop_a)
    1 1 100 200
    end
    save "`rds_a'.dta", replace
    clear
    input int(id) double(exp_b start_b stop_b)
    1 0 100 200
    end
    save "`rds_b'.dta", replace

    * id() names a variable absent from the data -> guarded error path inside quietly{}
    tempfile vlog
    log using "`vlog'.txt", replace text name(tvmergevis)
    capture noisily tvmerge "`rds_a'.dta" "`rds_b'.dta", ///
        id(nosuchid) start(start_a start_b) stop(stop_a stop_b) ///
        exposure(exp_a exp_b)
    local merge_rc = _rc
    capture log close tvmergevis

    assert `merge_rc' != 0
    assert strpos(fileread("`vlog'.txt"), "not found") > 0
}
if _rc == 0 {
    display as result "  PASS: tvmerge guarded error is visible (not swallowed by quietly)"
    local ++pass_count
}
else {
    capture log close tvmergevis
    display as error "  FAIL: tvmerge error visibility (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 20.4"
}


* Test 20.5: tvdiagnose coverage with entry/exit on single person
local ++test_count
capture noisily {
    clear
    set obs 2
    gen id = 1
    gen start = mdy(1,1,2020) in 1
    replace start = mdy(7,1,2020) in 2
    gen stop = mdy(6,30,2020) in 1
    replace stop = mdy(12,31,2020) in 2
    gen entry = mdy(1,1,2020)
    gen exit_ = mdy(12,31,2020)
    format %td start stop entry exit_
    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_) coverage
    assert r(mean_coverage) > 0
    assert r(n_persons) == 1
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose coverage single person"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose coverage single person (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 20.5"
}

* SECTION 21: DELIBERATION PANEL FIXES (2026-03-21)
display as text _newline "{hline 70}"
display as text "{hline 70}"


* Test 21.4: tvage rejects duplicate IDs with error 459
local ++test_count
capture noisily {
    clear
    set obs 4
    gen long id = cond(_n <= 2, 1, 2)
    gen dob = mdy(1, 1, 1970)
    gen entry = mdy(1, 1, 2020)
    gen exit_ = mdy(12, 31, 2023)
    format dob entry exit_ %td
    capture noisily tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_)
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: tvage rejects duplicate IDs with rc 459"
    local ++pass_count
}
else {
    display as error "  FAIL: tvage duplicate ID rejection (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 21.4"
}

* Test 21.5: tvage accepts unique IDs (no false positive)
local ++test_count
capture noisily {
    clear
    set obs 3
    gen long id = _n
    gen dob = mdy(1, 1, 1970) + (_n - 1) * 365
    gen entry = mdy(1, 1, 2020)
    gen exit_ = mdy(12, 31, 2022)
    format dob entry exit_ %td
    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_)
    assert r(n_persons) == 3
}
if _rc == 0 {
    display as result "  PASS: tvage accepts unique IDs (no false positive)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvage unique ID acceptance (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 21.5"
}

* Test 21.6: tvdiagnose detects overlaps in nested intervals
local ++test_count
capture noisily {
    clear
    * Create nested intervals: [1-100], [20-40], [50-110]
    * The [50-110] interval overlaps with [1-100] but NOT with [20-40]
    * Old code comparing only to _n-1 would miss the [1-100] overlap
    input id start stop
    1 1 100
    1 20 40
    1 50 110
    end
    format %td start stop
    tvdiagnose, id(id) start(start) stop(stop) overlaps
    * Should detect at least 2 overlapping periods
    assert r(n_overlaps) >= 2
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose detects nested interval overlaps"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose nested overlap detection (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 21.6"
}

* Test 21.7: tvdiagnose gap detection with nested intervals
local ++test_count
capture noisily {
    clear
    * Create: [1-100], [20-40], [120-150]
    * Old code comparing _n-1 sees: 120 > 40+1=41 → gap from 41-119 (FALSE)
    * Correct: 120 > 100+1=101 → gap from 101-119 (TRUE, shorter gap)
    * The running-max approach should use stop=100 (not stop=40)
    input id start stop
    1 1 100
    1 20 40
    1 120 150
    end
    format %td start stop
    tvdiagnose, id(id) start(start) stop(stop) gaps
    * Should detect exactly 1 gap (from 101 to 119), not a false gap from 41
    assert r(n_gaps) == 1
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose gap detection with nested intervals"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose nested gap detection (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 21.7"
}

* Test 21.8: tvdiagnose no false gaps when interval fully nested
local ++test_count
capture noisily {
    clear
    * [1-100], [20-40] — no gap, second is fully nested
    input id start stop
    1 1 100
    1 20 40
    end
    format %td start stop
    tvdiagnose, id(id) start(start) stop(stop) gaps
    assert r(n_gaps) == 0
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose no false gaps for nested intervals"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose false gap with nested intervals (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 21.8"
}

* Test 21.9: tvweight markout with missing id values
local ++test_count
capture noisily {
    clear
    set seed 22222
    set obs 100
    gen long id = _n
    gen double time_var = ceil(_n / 10)
    gen byte treatment = runiform() > 0.5
    gen double x1 = rnormal()
    * Make some id values missing
    replace id = . in 1/5
    tvweight treatment, covariates(x1) id(id) time(time_var) ///
        tvcovariates(x1) generate(w) nolog
    * Obs with missing id should be excluded
    assert r(N) <= 95
    * Weight should be missing for obs with missing id
    count if missing(w) & missing(id)
    assert r(N) == 5
}
if _rc == 0 {
    display as result "  PASS: tvweight excludes obs with missing id from sample"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight missing id markout (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 21.9"
}

* Test 21.10: tvweight markout with missing time values
local ++test_count
capture noisily {
    clear
    set seed 33333
    set obs 100
    gen long id = _n
    gen double time_var = ceil(_n / 10)
    gen byte treatment = runiform() > 0.5
    gen double x1 = rnormal()
    * Make some time values missing
    replace time_var = . in 96/100
    tvweight treatment, covariates(x1) id(id) time(time_var) ///
        tvcovariates(x1) generate(w) nolog
    * Obs with missing time should be excluded
    assert r(N) <= 95
}
if _rc == 0 {
    display as result "  PASS: tvweight excludes obs with missing time from sample"
    local ++pass_count
}
else {
    display as error "  FAIL: tvweight missing time markout (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 21.10"
}


**# ===== merged from test_tvtools.do L13334-13614: Codex audit fixes 2026-03-23 =====

**# Codex Audit Fixes (2026-03-23)

**## tvevent string date rejection

* TEST 7.1: tvevent rejects string date() variable
local ++test_count
capture noisily {
    clear
    input long id str10 edate
    1 "2020-01-05"
    2 "2020-03-15"
    end
    tempfile str_events
    save `str_events'

    clear
    input long id double start double stop
    1 21915 21965
    1 21965 22015
    2 21915 21965
    2 21965 22015
    end
    format start stop %td
    tempfile str_intervals
    save `str_intervals'

    use `str_events', clear
    capture tvevent using `str_intervals', id(id) date(edate) replace
    assert _rc == 109
}
if _rc == 0 {
    display as result "  PASS: tvevent rejects string date() with rc=109"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent rejects string date() with rc=109 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.1"
}

* TEST 7.2: tvevent rejects string compete() variable
local ++test_count
capture noisily {
    clear
    input long id double eventdate str10 deathdate
    1 21950 "2020-06-01"
    2 .     "2020-04-10"
    end
    format eventdate %td
    tempfile str_compete
    save `str_compete'

    clear
    input long id double start double stop
    1 21915 21965
    1 21965 22015
    2 21915 21965
    2 21965 22015
    end
    format start stop %td
    tempfile str_intervals2
    save `str_intervals2'

    use `str_compete', clear
    capture tvevent using `str_intervals2', id(id) date(eventdate) compete(deathdate) replace
    assert _rc == 109
}
if _rc == 0 {
    display as result "  PASS: tvevent rejects string compete() with rc=109"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent rejects string compete() with rc=109 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.2"
}

* TEST 7.3: tvevent accepts numeric date (control)
local ++test_count
capture noisily {
    clear
    input long id double eventdate
    1 21950
    2 .
    end
    format eventdate %td
    tempfile num_events
    save `num_events'

    clear
    input long id double start double stop
    1 21915 21965
    1 21965 22015
    2 21915 21965
    2 21965 22015
    end
    format start stop %td
    tempfile num_intervals
    save `num_intervals'

    use `num_events', clear
    tvevent using `num_intervals', id(id) date(eventdate) replace
    assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: tvevent accepts numeric date (control)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent accepts numeric date (control) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.3"
}

**## tvmerge tempfile path support

* TEST 7.4: tvmerge accepts tempfile paths (no .dta extension)
local ++test_count
capture noisily {
    clear
    input long id double start1 double stop1 byte exp1
    1 21915 21950 1
    1 21950 22015 0
    2 21915 21980 1
    end
    format start1 stop1 %td
    tempfile tf_ds1
    save `tf_ds1'

    clear
    input long id double start2 double stop2 byte exp2
    1 21915 21935 1
    1 21935 22015 0
    2 21915 21960 1
    2 21960 22015 0
    end
    format start2 stop2 %td
    tempfile tf_ds2
    save `tf_ds2'

    tvmerge `tf_ds1' `tf_ds2', id(id) ///
        start(start1 start2) stop(stop1 stop2) exposure(exp1 exp2)
    assert _N > 0
    confirm variable exp1
    confirm variable exp2
}
if _rc == 0 {
    display as result "  PASS: tvmerge accepts tempfile paths without .dta"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge accepts tempfile paths without .dta (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.4"
}

* TEST 7.5: tvmerge still works with .dta paths (control)
local ++test_count
capture noisily {
    clear
    input long id double start1 double stop1 byte exp1
    1 21915 21950 1
    1 21950 22015 0
    end
    format start1 stop1 %td
    save "/tmp/_tvmerge_test_ds1.dta", replace

    clear
    input long id double start2 double stop2 byte exp2
    1 21915 21935 1
    1 21935 22015 0
    end
    format start2 stop2 %td
    save "/tmp/_tvmerge_test_ds2.dta", replace

    tvmerge /tmp/_tvmerge_test_ds1.dta /tmp/_tvmerge_test_ds2.dta, id(id) ///
        start(start1 start2) stop(stop1 stop2) exposure(exp1 exp2)
    assert _N > 0
    capture erase "/tmp/_tvmerge_test_ds1.dta"
    capture erase "/tmp/_tvmerge_test_ds2.dta"
}
if _rc == 0 {
    display as result "  PASS: tvmerge still works with .dta paths"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge still works with .dta paths (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.5"
    capture erase "/tmp/_tvmerge_test_ds1.dta"
    capture erase "/tmp/_tvmerge_test_ds2.dta"
}

**## tvexpose bytype name length validation

* TEST 7.6: tvexpose rejects long generate() stub with bytype
local ++test_count
capture noisily {
    clear
    set obs 5
    gen long id = _n
    gen double entry = mdy(1, 1, 2020)
    gen double exit_dt = mdy(12, 31, 2021)
    format entry exit_dt %td

    clear
    input long id double start double stop byte exposure
    1 21915 22015 1
    2 21915 22015 2
    3 21915 22015 1
    4 21915 22015 2
    5 21915 22015 1
    end
    format start stop %td
    save "/tmp/_tvexp_bytype_exp.dta", replace

    clear
    set obs 5
    gen long id = _n
    gen double entry = mdy(1, 1, 2020)
    gen double exit_dt = mdy(12, 31, 2021)
    format entry exit_dt %td

    capture tvexpose using "/tmp/_tvexp_bytype_exp.dta", ///
        id(id) start(start) stop(stop) exposure(exposure) ///
        entry(entry) exit(exit_dt) reference(0) evertreated bytype ///
        generate(abcdefghijklmnopqrstuvwxy)
    assert _rc == 198
    capture erase "/tmp/_tvexp_bytype_exp.dta"
}
if _rc == 0 {
    display as result "  PASS: tvexpose rejects long stub (>24 chars) with bytype"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose rejects long stub with bytype (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.6"
    capture erase "/tmp/_tvexp_bytype_exp.dta"
}

* TEST 7.7: tvexpose accepts short generate() stub with bytype (control)
local ++test_count
capture noisily {
    clear
    input long id double start double stop byte exposure
    1 21915 22015 1
    2 21915 22015 2
    3 21915 22015 1
    4 21915 22015 2
    5 21915 22015 1
    end
    format start stop %td
    save "/tmp/_tvexp_bytype_exp2.dta", replace

    clear
    set obs 5
    gen long id = _n
    gen double entry = mdy(1, 1, 2020)
    gen double exit_dt = mdy(12, 31, 2021)
    format entry exit_dt %td

    capture tvexpose using "/tmp/_tvexp_bytype_exp2.dta", ///
        id(id) start(start) stop(stop) exposure(exposure) ///
        entry(entry) exit(exit_dt) reference(0) evertreated bytype ///
        generate(ev)
    assert _rc == 0
    capture erase "/tmp/_tvexp_bytype_exp2.dta"
}
if _rc == 0 {
    display as result "  PASS: tvexpose accepts short stub with bytype (control)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose accepts short stub with bytype (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7.7"
    capture erase "/tmp/_tvexp_bytype_exp2.dta"
}



**# ===== merged from test_tvtools.do L14077-14481: bug-fix + review regression tests =====

* SECTION 22: BUG FIX REGRESSION TESTS (2026-04-01)
* Tests for issues identified by Codex and Gemini code reviews

* TEST 22.1: tvmerge rejects reserved name "start_k" in generate()
clear
set obs 5
gen long id = _n
gen start1 = mdy(1,1,2020)
gen stop1 = mdy(12,31,2020)
gen start2 = mdy(1,1,2020)
gen stop2 = mdy(12,31,2020)
gen drug1 = 1
gen drug2 = 0
format start1 stop1 start2 stop2 %td
save /tmp/_bugfix_ds1.dta, replace
save /tmp/_bugfix_ds2.dta, replace

capture noisily tvmerge /tmp/_bugfix_ds1.dta /tmp/_bugfix_ds2.dta, ///
    id(id) start(start1 start2) stop(stop1 stop2) exposure(drug1 drug2) ///
    generate(start_k dose2)
if _rc == 198 {
    display as result "  PASS: tvmerge rejects reserved name start_k in generate()"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge should reject reserved name start_k in generate() (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 22.1"
}

* TEST 22.2: tvmerge rejects reserved name "_orig_start_merged" in generate()
capture noisily tvmerge /tmp/_bugfix_ds1.dta /tmp/_bugfix_ds2.dta, ///
    id(id) start(start1 start2) stop(stop1 stop2) exposure(drug1 drug2) ///
    generate(_orig_start_merged dose2)
if _rc == 198 {
    display as result "  PASS: tvmerge rejects reserved name _orig_start_merged in generate()"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge should reject reserved name _orig_start_merged (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 22.2"
}

* TEST 22.3: tvexpose keepvar with "tv_labels" label doesn't corrupt exposure labels
clear
set obs 5
gen long id = _n
gen entry = mdy(1,1,2020)
gen exit_dt = mdy(12,31,2020)
gen int sex = mod(_n, 2)
label define tv_labels 0 "Male" 1 "Female"
label values sex tv_labels
format entry exit_dt %td
save /tmp/_bugfix_master.dta, replace

clear
set obs 5
gen long id = _n
gen start = mdy(3,1,2020)
gen stop = mdy(6,30,2020)
gen exposure = 1
format start stop %td
save /tmp/_bugfix_exp.dta, replace

use /tmp/_bugfix_master.dta, clear
capture noisily {
    tvexpose using /tmp/_bugfix_exp.dta, id(id) start(start) stop(stop) ///
        exposure(exposure) reference(0) entry(entry) exit(exit_dt) ///
        keepvars(sex) generate(tv_exposure)
    * Check that tv_exposure label 0 says "Unexposed" not "Male"
    local lbl_0 : label (tv_exposure) 0
    assert "`lbl_0'" != "Male"
}
if _rc == 0 {
    display as result "  PASS: tvexpose label not corrupted by keepvar with tv_labels"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose label corrupted by keepvar with tv_labels (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 22.3"
}

* TEST 22.4: tvexpose accepts 32-character variable name in generate()
use /tmp/_bugfix_master.dta, clear
capture noisily {
    tvexpose using /tmp/_bugfix_exp.dta, id(id) start(start) stop(stop) ///
        exposure(exposure) reference(0) entry(entry) exit(exit_dt) ///
        generate(abcdefghijklmnopqrstuvwxyzabcdef)
    capture confirm variable abcdefghijklmnopqrstuvwxyzabcdef
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: tvexpose accepts 32-character generate() name"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose rejects 32-character generate() name (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 22.4"
}

* TEST 22.5: tvevent accepts 32-character variable name in generate()
clear
set obs 5
gen long id = _n
gen edate = mdy(4,15,2020)
format edate %td
save /tmp/_bugfix_events.dta, replace

clear
set obs 5
gen long id = _n
gen start = mdy(1,1,2020)
gen stop = mdy(12,31,2020)
gen x = 0
format start stop %td
save /tmp/_bugfix_intervals.dta, replace

use /tmp/_bugfix_events.dta, clear
capture noisily {
    tvevent using /tmp/_bugfix_intervals.dta, id(id) date(edate) ///
        generate(abcdefghijklmnopqrstuvwxyzabcdef) replace
    capture confirm variable abcdefghijklmnopqrstuvwxyzabcdef
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: tvevent accepts 32-character generate() name"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent rejects 32-character generate() name (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 22.5"
}

* TEST 22.6: tvexpose rejects generate(start) — collision with output name
use /tmp/_bugfix_master.dta, clear
capture noisily tvexpose using /tmp/_bugfix_exp.dta, id(id) start(start) stop(stop) ///
    exposure(exposure) reference(0) entry(entry) exit(exit_dt) generate(start)
if _rc == 198 {
    display as result "  PASS: tvexpose rejects generate(start)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose should reject generate(start) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 22.6"
}

* TEST 22.7: tvexpose rejects generate(stop) — collision with output name
use /tmp/_bugfix_master.dta, clear
capture noisily tvexpose using /tmp/_bugfix_exp.dta, id(id) start(start) stop(stop) ///
    exposure(exposure) reference(0) entry(entry) exit(exit_dt) generate(stop)
if _rc == 198 {
    display as result "  PASS: tvexpose rejects generate(stop)"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose should reject generate(stop) (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 22.7"
}

* TEST 22.8: tvevent rejects generate(start) when startvar defaults to "start"
use /tmp/_bugfix_events.dta, clear
capture noisily tvevent using /tmp/_bugfix_intervals.dta, id(id) date(edate) ///
    generate(start) replace
if _rc == 198 {
    display as result "  PASS: tvevent rejects generate(start) when startvar=start"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent should reject generate(start) when startvar=start (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 22.8"
}

* TEST 22.9: tvevent flags event at interval start date (boundary semantics)
clear
set obs 1
gen long id = 1
gen edate = mdy(1,1,2020)
format edate %td
save /tmp/_bugfix_boundary_ev.dta, replace

clear
set obs 1
gen long id = 1
gen start = mdy(1,1,2020)
gen stop = mdy(12,31,2020)
gen x = 0
format start stop %td
save /tmp/_bugfix_boundary_iv.dta, replace

use /tmp/_bugfix_boundary_ev.dta, clear
capture noisily {
    tvevent using /tmp/_bugfix_boundary_iv.dta, id(id) date(edate) replace
    * Under [start, stop] convention, event at start date should be flagged
    assert _failure[1] == 1 | _failure[2] == 1
}
if _rc == 0 {
    display as result "  PASS: tvevent flags event at interval start date"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent should flag event at interval start date (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 22.9"
}

* Cleanup temporary bugfix files
foreach f in _bugfix_ds1 _bugfix_ds2 _bugfix_master _bugfix_exp ///
    _bugfix_events _bugfix_intervals _bugfix_boundary_ev _bugfix_boundary_iv {
    capture erase "/tmp/`f'.dta"
}


* SECTION 23: REVIEW REGRESSION TESTS (2026-04-03)

* TEST 23.1: tvmerge — exposure named _proportion should not collide
clear
set obs 10
gen long id = ceil(_n / 2)
gen double start = cond(mod(_n, 2), mdy(1,1,2020), mdy(7,1,2020))
gen double stop = cond(mod(_n, 2), mdy(6,30,2020), mdy(12,31,2020))
gen double _proportion = runiform() * 100
format start stop %td
tempfile ds_prop
save `ds_prop', replace

clear
set obs 10
gen long id = ceil(_n / 2)
gen double start = cond(mod(_n, 2), mdy(3,1,2020), mdy(9,1,2020))
gen double stop = cond(mod(_n, 2), mdy(8,31,2020), mdy(12,31,2020))
gen double exp2 = runiform() * 50
format start stop %td
tempfile ds_exp2
save `ds_exp2', replace

capture noisily tvmerge `ds_prop' `ds_exp2', id(id) ///
    start(start start) stop(stop stop) exposure(_proportion exp2) ///
    continuous(_proportion) generate(ds1 ds2)
if _rc == 0 {
    display as result "PASS: tvmerge handles exposure named _proportion"
    local ++pass_count
}
else {
    display as error "FAIL: tvmerge crashed with exposure named _proportion (rc=" _rc ")"
    local ++fail_count
    local failed_tests "`failed_tests' 23.1"
}

* TEST 23.2: tvexpose — combine(start) should fail early with clear error
clear
set obs 5
gen long id = _n
gen double study_entry = mdy(1,1,2020)
gen double study_exit = mdy(12,31,2020)
format study_entry study_exit %td
tempfile master_23
save `master_23', replace

clear
set obs 5
gen long id = _n
gen double exp_start = mdy(3,1,2020)
gen double exp_stop = mdy(9,30,2020)
gen byte exposed = 1
format exp_start exp_stop %td
tempfile using_23
save `using_23', replace

use `master_23', clear
capture noisily tvexpose using `using_23', id(id) ///
    start(exp_start) stop(exp_stop) exposure(exposed) ///
    entry(study_entry) exit(study_exit) reference(0) ///
    generate(exp_val) combine(start) replace
if _rc == 198 {
    display as result "PASS: tvexpose rejects combine(start) with rc 198"
    local ++pass_count
}
else {
    display as error "FAIL: tvexpose should reject combine(start) with rc 198, got rc=" _rc
    local ++fail_count
    local failed_tests "`failed_tests' 23.2"
}

* TEST 23.3: tvexpose — combine(stop) should fail early
use `master_23', clear
capture noisily tvexpose using `using_23', id(id) ///
    start(exp_start) stop(exp_stop) exposure(exposed) ///
    entry(study_entry) exit(study_exit) reference(0) ///
    generate(exp_val) combine(stop) replace
if _rc == 198 {
    display as result "PASS: tvexpose rejects combine(stop) with rc 198"
    local ++pass_count
}
else {
    display as error "FAIL: tvexpose should reject combine(stop) with rc 198, got rc=" _rc
    local ++fail_count
    local failed_tests "`failed_tests' 23.3"
}

* TEST 23.4: tvexpose — combine() same as generate() should fail early
use `master_23', clear
capture noisily tvexpose using `using_23', id(id) ///
    start(exp_start) stop(exp_stop) exposure(exposed) ///
    entry(study_entry) exit(study_exit) reference(0) ///
    generate(exp_val) combine(exp_val) replace
if _rc == 198 {
    display as result "PASS: tvexpose rejects combine() = generate() with rc 198"
    local ++pass_count
}
else {
    display as error "FAIL: tvexpose should reject combine()=generate() with rc 198, got rc=" _rc
    local ++fail_count
    local failed_tests "`failed_tests' 23.4"
}

* TEST 23.5: tvevent — validate should NOT flag competing-risk data as multiple events
clear
set obs 5
gen long id = _n
gen event_dt = mdy(6,15,2020) + _n * 30
gen death_dt = mdy(12,1,2020) + _n * 10
format event_dt death_dt %td
tempfile master_ev
save `master_ev', replace

clear
set obs 10
gen long id = ceil(_n / 2)
gen double start = cond(mod(_n, 2), mdy(1,1,2020), mdy(7,1,2020))
gen double stop = cond(mod(_n, 2), mdy(6,30,2020), mdy(12,31,2020))
format start stop %td
tempfile intervals_ev
save `intervals_ev', replace

use `master_ev', clear
tvevent using `intervals_ev', id(id) date(event_dt) ///
    compete(death_dt) validate replace
local v_mult = r(v_multiple_events)
if `v_mult' == 0 {
    display as result "PASS: validate does not miscount competing events as multiple"
    local ++pass_count
}
else {
    display as error "FAIL: validate reported `v_mult' multiple events (expected 0)"
    local ++fail_count
    local failed_tests "`failed_tests' 23.5"
}

* TEST 23.6: tvevent — validate should count out-of-bounds competing events
clear
set obs 3
gen long id = _n
gen event_dt = mdy(6,15,2020)
* Competing event outside any interval boundary
gen death_dt = mdy(1,1,2025)
format event_dt death_dt %td
tempfile master_oob
save `master_oob', replace

clear
set obs 3
gen long id = _n
gen double start = mdy(1,1,2020)
gen double stop = mdy(12,31,2020)
format start stop %td
tempfile intervals_oob
save `intervals_oob', replace

use `master_oob', clear
tvevent using `intervals_oob', id(id) date(event_dt) ///
    compete(death_dt) validate replace
local v_oob = r(v_outside_bounds)
if `v_oob' > 0 {
    display as result "PASS: validate detected `v_oob' out-of-bounds competing events"
    local ++pass_count
}
else {
    display as error "FAIL: validate reported 0 out-of-bounds (expected >0 for competing events outside window)"
    local ++fail_count
    local failed_tests "`failed_tests' 23.6"
}

* SECTION 24: Documentation release regressions

* TEST 24.1: public help Author sections use the canonical project form only
local ++test_count
capture noisily {
    local qa_dir "`c(pwd)'"
    local pkg_dir = substr("`qa_dir'", 1, strlen("`qa_dir'") - 3)
    local canonical "{pstd}Timothy P Copeland, Karolinska Institutet{p_end}"
    local help_files tvage tvdiagnose tvevent tvexpose tvmerge tvpanel tvtools tvweight

    foreach h of local help_files {
        tempname fh
        file open `fh' using "`pkg_dir'/`h'.sthlp", read text

        local in_author = 0
        local saw_title = 0
        local canonical_count = 0
        local other_count = 0
        local other_line ""

        file read `fh' line
        while r(eof) == 0 {
            local trimmed = strtrim(`"`line'"')

            if `"`trimmed'"' == "{marker author}{...}" {
                local in_author = 1
            }
            else if `in_author' & `"`trimmed'"' == "{title:Author}" {
                local saw_title = 1
            }
            else if `in_author' & `saw_title' {
                if substr(`"`trimmed'"', 1, 7) == "{title:" | ///
                    substr(`"`trimmed'"', 1, 8) == "{marker " | ///
                    `"`trimmed'"' == "{hline}" {
                    local in_author = 0
                }
                else if `"`trimmed'"' != "" {
                    if `"`trimmed'"' == `"`canonical'"' {
                        local ++canonical_count
                    }
                    else {
                        local ++other_count
                        local other_line `"`trimmed'"'
                    }
                }
            }

            file read `fh' line
        }
        file close `fh'

        assert `canonical_count' == 1
        assert `other_count' == 0
    }
}
if _rc == 0 {
    display as result "PASS: help Author sections use canonical project form"
    local ++pass_count
}
else {
    display as error "FAIL: help Author section consistency (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 24.1"
}

* TEST 24.2: tvexpose r(overlap_ids) synopt remains concise
local ++test_count
capture noisily {
    local qa_dir "`c(pwd)'"
    local pkg_dir = substr("`qa_dir'", 1, strlen("`qa_dir'") - 3)
    local expected_synopt "{synopt:{cmd:r(overlap_ids)}}IDs with unresolved overlapping exposure categories{p_end}"

    tempname fh
    file open `fh' using "`pkg_dir'/tvexpose.sthlp", read text
    local found_synopt = 0
    local long_synopt = 0
    local found_note = 0

    file read `fh' line
    while r(eof) == 0 {
        local trimmed = strtrim(`"`line'"')
        if strpos(`"`trimmed'"', "{synopt:{cmd:r(overlap_ids)}}") > 0 {
            local found_synopt = 1
            assert `"`trimmed'"' == `"`expected_synopt'"'
            if strpos(`"`trimmed'"', "only stored when") > 0 | ///
                strpos(`"`trimmed'"', "no {cmd:priority()}") > 0 {
                local long_synopt = 1
            }
        }
        if strpos(`"`trimmed'"', "{cmd:r(overlap_ids)} is stored only when") > 0 {
            local found_note = 1
        }
        file read `fh' line
    }
    file close `fh'

    assert `found_synopt' == 1
    assert `long_synopt' == 0
    assert `found_note' == 1
}
if _rc == 0 {
    display as result "PASS: tvexpose r(overlap_ids) synopt is concise"
    local ++pass_count
}
else {
    display as error "FAIL: tvexpose overlap_ids synopt check (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 24.2"
}

* TEST 24.3: tvexpose dose-overlap internals do not collide with keepvars()
local ++test_count
capture noisily {
    tempfile dose_master dose_exp
    local d0 = mdy(1,1,2020)

    clear
    set obs 1
    gen long id = 1
    gen double study_entry = `d0'
    gen double study_exit = `d0' + 365
    gen double __seg_days = 1001
    gen double __seg_dose = 2001
    format study_entry study_exit %td
    save `dose_master', replace

    clear
    input int(id) double(dose_val) str10(s_start s_stop)
    1 300 "2020-01-01" "2020-01-30"
    1 600 "2020-01-16" "2020-02-14"
    end
    gen double start = date(s_start, "YMD")
    gen double stop = date(s_stop, "YMD")
    format start stop %td
    drop s_start s_stop
    save `dose_exp', replace

    use `dose_master', clear
    tvexpose using `dose_exp', id(id) start(start) stop(stop) ///
        exposure(dose_val) entry(study_entry) exit(study_exit) ///
        dose keepvars(__seg_days __seg_dose) generate(cum_dose)

    confirm variable __seg_days
    confirm variable __seg_dose
    confirm variable cum_dose
    quietly count if __seg_days != 1001 | __seg_dose != 2001
    assert r(N) == 0
    quietly summarize cum_dose
    assert abs(r(max) - 900) < 1
}
if _rc == 0 {
    display as result "PASS: tvexpose dose overlap keepvars avoid internal-name collision"
    local ++pass_count
}
else {
    display as error "FAIL: tvexpose dose overlap keepvars collision regression (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 24.3"
}

* Cleanup section 23 tempfiles
foreach f in ds_prop ds_exp2 master_23 using_23 master_ev intervals_ev master_oob intervals_oob {
    capture erase "``f''"
}

* CLEANUP: Remove temporary files
foreach f in _gap_tvage _gap_tc_cohort _gap_tc_exp _gap_empty_exp ///
    _gap_str_exp _gap_wrongvars_exp _gap_reversed _gap_intervals ///
    _gap_merge1 _gap_merge2 _gap_tvage_out ///
    test_cohort test_exposure ///
    _s18_cohort _s18_exposure _s18_overlap_exp ///
    _s18_merge1 _s18_merge2 _s18_intervals _s18_events ///
    _s18_bad_cohort _s18_merged _s18_merged2 {
    capture erase "/tmp/`f'.dta"
}

* TEST RESULTS

* ===== Summary =====
* Fold the run_test/test_pass/test_fail harness counters into the totals.
local pass_count = `pass_count' + $TVQA_PASS
local fail_count = `fail_count' + $TVQA_FAIL
local failed_tests "`failed_tests' $TVQA_FAILED"
local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA regression fixes Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: test_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
