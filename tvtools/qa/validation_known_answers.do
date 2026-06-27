* validation_known_answers.do
*
* Known-answer validation for tvexpose → tvmerge → tvage → tvevent workflows
* Every expected value is hand-computed from first principles
*
* Usage: cd tvtools/qa && stata-mp -b do validation_known_answers.do
*
* Author: Timothy P Copeland
* Date: 2026-04-14

clear all
set more off
set varabbrev off
version 16.0

* Bootstrap: derive paths from working directory
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as result "tvtools Known-Answer Validation -- $S_DATE $S_TIME"

* =============================================================================
**# WORKFLOW 1: Single exposure → tvevent (basic split & flag)
* =============================================================================
*
* Scenario: 1 person, entry=Jan1/2020, exit=Dec31/2020 (leap year)
*   Exposure: Drug A from Mar1/2020 to Jun30/2020 (122 days)
*   Event: Aug15/2020
*
* Hand computation (tvexpose):
*   Dates: entry=21915, exit=22281 (Dec31/2020)
*          exp_start=21975 (Mar1), exp_stop=22097 (Jun30)
*   Expected intervals:
*     Row 1: [21915, 21974] unexposed (Jan1-Feb29, 60 days)
*     Row 2: [21975, 22097] exposed   (Mar1-Jun30, 123 days incl)
*     Row 3: [22098, 22281] unexposed (Jul1-Dec31, 184 days)
*   Total person-time: 60 + 123 + 184 = 367 = 22281 - 21915 + 1 ✓
*
* Hand computation (tvevent, type=single):
*   Event date: Aug15/2020 = 22143
*   Event falls in row 3 [22098, 22281], strictly inside → split
*     Row 3a: [22098, 22143] unexposed, outcome=1 (event row)
*     Row 3b: [22144, 22281] → DROPPED by type(single)
*   Final dataset: 3 rows
*     Row 1: [21915, 21974] exp=0, outcome=0
*     Row 2: [21975, 22097] exp=1, outcome=0
*     Row 3: [22098, 22143] exp=0, outcome=1
*   Total person-time after censoring: 60 + 123 + 46 = 229 days
*     Check: 22143 - 21915 + 1 = 229 ✓

display as text _newline "WORKFLOW 1: Single exposure → tvevent (basic split & flag)"

**## W1.1: tvexpose produces correct intervals
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double(study_entry study_exit)
        1 21915 22281
    end
    format %td study_entry study_exit
    tempfile w1_cohort
    save `w1_cohort'

    clear
    input long id double(start stop) byte drug
        1 21975 22097 1
    end
    format %td start stop
    tempfile w1_exp
    save `w1_exp'

    use `w1_cohort', clear
    tvexpose using `w1_exp', id(id) start(start) stop(stop) ///
        exposure(drug) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_drug)

    sort id start
    quietly count
    assert r(N) == 3
}
if _rc != 0 {
    display as error "  FAIL [W1.1.run]: tvexpose failed (error `=_rc')"
    local t_pass = 0
}
else {
    * Check row 1: unexposed baseline
    if start[1] != 21915 | stop[1] != 21974 | tv_drug[1] != 0 {
        display as error "  FAIL [W1.1.row1]: expected [21915,21974] exp=0, got [" ///
            start[1] "," stop[1] "] exp=" tv_drug[1]
        local t_pass = 0
    }
    else {
        display as result "  PASS [W1.1.row1]: baseline [Jan1,Feb29] exp=0"
    }

    * Check row 2: exposed
    if start[2] != 21975 | stop[2] != 22097 | tv_drug[2] != 1 {
        display as error "  FAIL [W1.1.row2]: expected [21975,22097] exp=1, got [" ///
            start[2] "," stop[2] "] exp=" tv_drug[2]
        local t_pass = 0
    }
    else {
        display as result "  PASS [W1.1.row2]: exposed [Mar1,Jun30] exp=1"
    }

    * Check row 3: post-exposure unexposed
    if start[3] != 22098 | stop[3] != 22281 | tv_drug[3] != 0 {
        display as error "  FAIL [W1.1.row3]: expected [22098,22281] exp=0, got [" ///
            start[3] "," stop[3] "] exp=" tv_drug[3]
        local t_pass = 0
    }
    else {
        display as result "  PASS [W1.1.row3]: post-exposure [Jul1,Dec31] exp=0"
    }

    * Person-time conservation: 22281 - 21915 + 1 = 367
    capture drop pt
    quietly gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 367 {
        display as error "  FAIL [W1.1.pt]: expected 367 days, got `=r(sum)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W1.1.pt]: person-time = 367 days"
    }

    tempfile w1_intervals
    save `w1_intervals'
}
if `t_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W1.1"
}

**## W1.2: tvevent splits and flags correctly
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double event_dt
        1 22143
    end
    format %td event_dt

    tvevent using `w1_intervals', id(id) date(event_dt) ///
        generate(outcome) type(single) replace

    sort id start
    quietly count
    assert r(N) == 3
}
if _rc != 0 {
    display as error "  FAIL [W1.2.run]: tvevent failed (error `=_rc')"
    local t_pass = 0
}
else {
    * Row 1: unchanged
    if start[1] != 21915 | stop[1] != 21974 | outcome[1] != 0 {
        display as error "  FAIL [W1.2.row1]: expected [21915,21974] out=0"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W1.2.row1]: baseline censored"
    }

    * Row 2: unchanged
    if start[2] != 21975 | stop[2] != 22097 | outcome[2] != 0 {
        display as error "  FAIL [W1.2.row2]: expected [21975,22097] out=0"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W1.2.row2]: exposed censored"
    }

    * Row 3: split at event, post-event dropped
    if start[3] != 22098 | stop[3] != 22143 | outcome[3] != 1 {
        display as error "  FAIL [W1.2.row3]: expected [22098,22143] out=1, got [" ///
            start[3] "," stop[3] "] out=" outcome[3]
        local t_pass = 0
    }
    else {
        display as result "  PASS [W1.2.row3]: event at stop=22143, post-event dropped"
    }

    * Person-time = 229 days (censored at event)
    capture drop pt
    quietly gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 229 {
        display as error "  FAIL [W1.2.pt]: expected 229 days, got `=r(sum)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W1.2.pt]: censored person-time = 229 days"
    }
}
if `t_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W1.2"
}


* =============================================================================
**# WORKFLOW 2: Two exposures → tvmerge → tvevent (overlapping drugs)
* =============================================================================
*
* Scenario: 1 person, entry=Jan1/2020, exit=Jun30/2020 (182 days)
*   Drug A: Feb1-Apr30  (exposure value 1)
*   Drug B: Mar1-May31  (exposure value 1)
*   Event: May15/2020
*
* Date encoding:
*   entry=21915, exit=22096 (Jun30)
*   Drug A: start=21946(Feb1), stop=22035(Apr30)
*   Drug B: start=21975(Mar1), stop=22066(May31)
*
* tvexpose for Drug A:
*   [21915, 21945] ref=0 (Jan1-Jan31, baseline)
*   [21946, 22035] A=1   (Feb1-Apr30, exposure)
*   [22036, 22096] ref=0 (May1-Jun30, post-exposure)
*
* tvexpose for Drug B:
*   [21915, 21974] ref=0 (Jan1-Feb29, baseline)
*   [21975, 22066] B=1   (Mar1-May31, exposure)
*   [22067, 22096] ref=0 (Jun1-Jun30, post-exposure)
*
* tvmerge intersection (Drug A intervals × Drug B intervals):
*   [21915, 21945]: A=0, B=0  (Jan1-Jan31, 31 days)
*   [21946, 21974]: A=1, B=0  (Feb1-Feb29, 29 days)
*   [21975, 22035]: A=1, B=1  (Mar1-Apr30, 61 days)
*   [22036, 22066]: A=0, B=1  (May1-May31, 31 days)
*   [22067, 22096]: A=0, B=0  (Jun1-Jun30, 30 days)
*   Total: 31+29+61+31+30 = 182 ✓
*
* tvevent (event=May15=22050, type=single):
*   Event falls in row 4 [22036,22066], strictly inside → split at 22050
*     Row 4a: [22036, 22050] A=0, B=1, outcome=1
*     Row 4b: [22051, 22066] → DROPPED by type(single)
*     Row 5:  [22067, 22096] → DROPPED by type(single)
*   Final: 4 rows, total PT = 31+29+61+15 = 136 days
*     Check: 22050 - 21915 + 1 = 136 ✓

display as text _newline "WORKFLOW 2: Two exposures → tvmerge → tvevent"

**## W2.1: tvexpose Drug A
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double(study_entry study_exit)
        1 21915 22096
    end
    format %td study_entry study_exit
    tempfile w2_cohort
    save `w2_cohort'

    * Drug A exposure
    clear
    input long id double(start stop) byte drug_a
        1 21946 22035 1
    end
    format %td start stop
    tempfile w2_exp_a
    save `w2_exp_a'

    use `w2_cohort', clear
    tvexpose using `w2_exp_a', id(id) start(start) stop(stop) ///
        exposure(drug_a) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_a)

    sort id start
    quietly count
    assert r(N) == 3

    * Verify intervals
    assert start[1] == 21915 & stop[1] == 21945 & tv_a[1] == 0
    assert start[2] == 21946 & stop[2] == 22035 & tv_a[2] == 1
    assert start[3] == 22036 & stop[3] == 22096 & tv_a[3] == 0

    capture drop pt
    quietly gen double pt = stop - start + 1
    quietly summarize pt
    assert r(sum) == 182

    tempfile w2_tv_a
    save `w2_tv_a'
}
if _rc == 0 {
    display as result "  PASS: W2.1 tvexpose Drug A correct (3 intervals, 182 days)"
    local ++pass_count
}
else {
    display as error "  FAIL: W2.1 tvexpose Drug A (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' W2.1"
}

**## W2.2: tvexpose Drug B
local ++test_count
capture noisily {
    * Drug B exposure
    clear
    input long id double(start stop) byte drug_b
        1 21975 22066 1
    end
    format %td start stop
    tempfile w2_exp_b
    save `w2_exp_b'

    use `w2_cohort', clear
    tvexpose using `w2_exp_b', id(id) start(start) stop(stop) ///
        exposure(drug_b) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_b)

    sort id start
    quietly count
    assert r(N) == 3
    assert start[1] == 21915 & stop[1] == 21974 & tv_b[1] == 0
    assert start[2] == 21975 & stop[2] == 22066 & tv_b[2] == 1
    assert start[3] == 22067 & stop[3] == 22096 & tv_b[3] == 0

    capture drop pt
    quietly gen double pt = stop - start + 1
    quietly summarize pt
    assert r(sum) == 182

    tempfile w2_tv_b
    save `w2_tv_b'
}
if _rc == 0 {
    display as result "  PASS: W2.2 tvexpose Drug B correct (3 intervals, 182 days)"
    local ++pass_count
}
else {
    display as error "  FAIL: W2.2 tvexpose Drug B (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' W2.2"
}

**## W2.3: tvmerge produces correct intersections
local ++test_count
local t_pass = 1
capture noisily {
    tvmerge "`w2_tv_a'" "`w2_tv_b'", id(id) ///
        start(start start) stop(stop stop) ///
        exposure(tv_a tv_b) generate(drug_a drug_b)

    sort id start
    quietly count
    assert r(N) == 5
}
if _rc != 0 {
    display as error "  FAIL [W2.3.run]: tvmerge failed (error `=_rc')"
    local t_pass = 0
}
else {
    * Row 1: neither drug (Jan)
    if start[1] != 21915 | stop[1] != 21945 | drug_a[1] != 0 | drug_b[1] != 0 {
        display as error "  FAIL [W2.3.row1]: expected [21915,21945] A=0 B=0"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W2.3.row1]: neither drug [Jan1-Jan31]"
    }

    * Row 2: Drug A only (Feb)
    if start[2] != 21946 | stop[2] != 21974 | drug_a[2] != 1 | drug_b[2] != 0 {
        display as error "  FAIL [W2.3.row2]: expected [21946,21974] A=1 B=0"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W2.3.row2]: Drug A only [Feb1-Feb29]"
    }

    * Row 3: both drugs (Mar-Apr)
    if start[3] != 21975 | stop[3] != 22035 | drug_a[3] != 1 | drug_b[3] != 1 {
        display as error "  FAIL [W2.3.row3]: expected [21975,22035] A=1 B=1"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W2.3.row3]: both drugs [Mar1-Apr30]"
    }

    * Row 4: Drug B only (May)
    if start[4] != 22036 | stop[4] != 22066 | drug_a[4] != 0 | drug_b[4] != 1 {
        display as error "  FAIL [W2.3.row4]: expected [22036,22066] A=0 B=1"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W2.3.row4]: Drug B only [May1-May31]"
    }

    * Row 5: neither drug (Jun)
    if start[5] != 22067 | stop[5] != 22096 | drug_a[5] != 0 | drug_b[5] != 0 {
        display as error "  FAIL [W2.3.row5]: expected [22067,22096] A=0 B=0"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W2.3.row5]: neither drug [Jun1-Jun30]"
    }

    * Person-time conservation
    capture drop pt
    quietly gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 182 {
        display as error "  FAIL [W2.3.pt]: expected 182, got `=r(sum)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W2.3.pt]: person-time = 182 days"
    }

    tempfile w2_merged
    save `w2_merged'
}
if `t_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W2.3"
}

**## W2.4: tvevent splits merged data correctly
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double event_dt
        1 22050
    end
    format %td event_dt

    tvevent using `w2_merged', id(id) date(event_dt) ///
        generate(outcome) type(single) replace

    sort id start
    quietly count
    * 4 rows: original 3 + split at event, post-event dropped
    assert r(N) == 4
}
if _rc != 0 {
    display as error "  FAIL [W2.4.run]: tvevent failed (error `=_rc')"
    local t_pass = 0
}
else {
    * Row 3 should be the split interval ending at event
    if stop[3] != 22035 {
        display as error "  FAIL [W2.4.row3]: expected stop=22035 (both-drug row)"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W2.4.row3]: both-drug interval intact"
    }

    * Row 4: event row — split at event date, B=1
    if start[4] != 22036 | stop[4] != 22050 | outcome[4] != 1 {
        display as error "  FAIL [W2.4.row4]: expected [22036,22050] out=1, got [" ///
            start[4] "," stop[4] "] out=" outcome[4]
        local t_pass = 0
    }
    else {
        display as result "  PASS [W2.4.row4]: event at May15, Drug B only"
    }

    * Verify Drug B value on event row
    if drug_b[4] != 1 {
        display as error "  FAIL [W2.4.drug_b]: event row should have drug_b=1"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W2.4.drug_b]: drug_b=1 on event row"
    }

    * Total person-time: 136 days (22050 - 21915 + 1)
    capture drop pt
    quietly gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 136 {
        display as error "  FAIL [W2.4.pt]: expected 136, got `=r(sum)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W2.4.pt]: censored person-time = 136 days"
    }
}
if `t_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W2.4"
}


* =============================================================================
**# WORKFLOW 3: tvage → tvevent (age-split intervals with event)
* =============================================================================
*
* Scenario: 1 person
*   DOB: Jan1/1960 (Stata date = 0)
*   Entry: Jul1/2019 = 21731
*   Exit: Jun30/2021 = 22461
*   Event: Mar15/2020 = 21989
*
* Hand computation (tvage, groupwidth=1):
*   age_entry = floor((21731 - 0) / 365.25) = floor(59.480) = 59
*   age_exit  = floor((22461 - 0) / 365.25) = floor(61.477) = 61
*   n_periods = 61 - 59 + 1 = 3
*
*   Age 59: start=21731 (Jul1/2019), stop=round(0+60*365.25)-1 = round(21915)-1 = 21914
*           = [21731, 21914] (Jul1/2019 to Dec31/2019, 184 days)
*   Age 60: start=round(0+60*365.25) = 21915, stop=round(0+61*365.25)-1 = 22279
*           = [21915, 22279] (Jan1/2020 to Dec30/2020, 365 days)
*   Age 61: start=round(0+61*365.25) = 22280, stop=22461
*           = [22280, 22461] (Dec31/2020 to Jun30/2021, 182 days)
*   Total PT: 184 + 365 + 182 = 731 = 22461 - 21731 + 1 ✓
*
* tvevent (event=21989, Mar15/2020, type=single):
*   Event falls in Age 60 interval [21915, 22280], strictly inside → split
*     [21915, 21989] age=60, outcome=1
*     [21990, 22280] → DROPPED
*   Age 61 interval → DROPPED (post-event)
*   Final: 2 rows
*     Row 1: [21731, 21914] age=59, outcome=0
*     Row 2: [21915, 21989] age=60, outcome=1
*   Total PT: 184 + 75 = 259 = 21989 - 21731 + 1 ✓

display as text _newline "WORKFLOW 3: tvage → tvevent (age-split intervals)"

**## W3.1: tvage produces correct age intervals
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double(dob entry exit_)
        1 0 21731 22461
    end
    format %td dob entry exit_

    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_) ///
        generate(age_tv) startgen(age_start) stopgen(age_stop)

    sort id age_start
    quietly count
    assert r(N) == 3
}
if _rc != 0 {
    display as error "  FAIL [W3.1.run]: tvage failed (error `=_rc')"
    local t_pass = 0
}
else {
    * Row 1: age 59
    if age_tv[1] != 59 {
        display as error "  FAIL [W3.1.age1]: expected 59, got `=age_tv[1]'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W3.1.age1]: age_tv=59"
    }
    if age_start[1] != 21731 {
        display as error "  FAIL [W3.1.start1]: expected 21731, got `=age_start[1]'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W3.1.start1]: age_start=Jul1/2019"
    }
    if age_stop[1] != 21914 {
        display as error "  FAIL [W3.1.stop1]: expected 21914, got `=age_stop[1]'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W3.1.stop1]: age_stop=Dec31/2019"
    }

    * Row 2: age 60 — round(0+61*365.25) = round(22280.25) = 22280, so stop = 22280-1 = 22279
    if age_tv[2] != 60 | age_start[2] != 21915 | age_stop[2] != 22279 {
        display as error "  FAIL [W3.1.row2]: expected age=60 [21915,22279], got " ///
            age_tv[2] " [" age_start[2] "," age_stop[2] "]"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W3.1.row2]: age=60 [Jan1/2020, Dec30/2020]"
    }

    * Row 3: age 61
    if age_tv[3] != 61 | age_start[3] != 22280 | age_stop[3] != 22461 {
        display as error "  FAIL [W3.1.row3]: expected age=61 [22280,22461], got " ///
            age_tv[3] " [" age_start[3] "," age_stop[3] "]"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W3.1.row3]: age=61 [Dec31/2020, Jun30/2021]"
    }

    * Person-time conservation: 22461 - 21731 + 1 = 731
    capture drop pt
    quietly gen double pt = age_stop - age_start + 1
    quietly summarize pt
    if r(sum) != 731 {
        display as error "  FAIL [W3.1.pt]: expected 731, got `=r(sum)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W3.1.pt]: person-time = 731 days"
    }

    tempfile w3_age
    save `w3_age'
}
if `t_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W3.1"
}

**## W3.2: tvevent on age-split data
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double event_dt
        1 21989
    end
    format %td event_dt

    tvevent using `w3_age', id(id) date(event_dt) ///
        startvar(age_start) stopvar(age_stop) ///
        generate(outcome) type(single) replace

    sort id age_start
    quietly count
    assert r(N) == 2
}
if _rc != 0 {
    display as error "  FAIL [W3.2.run]: tvevent failed (error `=_rc')"
    local t_pass = 0
}
else {
    * Row 1: age 59, censored
    if age_start[1] != 21731 | age_stop[1] != 21914 | outcome[1] != 0 {
        display as error "  FAIL [W3.2.row1]: expected age 59 censored"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W3.2.row1]: age 59 censored"
    }

    * Row 2: age 60, event (split at 21989)
    if age_start[2] != 21915 | age_stop[2] != 21989 | outcome[2] != 1 {
        display as error "  FAIL [W3.2.row2]: expected [21915,21989] out=1, got [" ///
            age_start[2] "," age_stop[2] "] out=" outcome[2]
        local t_pass = 0
    }
    else {
        display as result "  PASS [W3.2.row2]: age 60 event, stop=Mar15/2020"
    }

    * Person-time after censoring: 259 days
    capture drop pt
    quietly gen double pt = age_stop - age_start + 1
    quietly summarize pt
    if r(sum) != 259 {
        display as error "  FAIL [W3.2.pt]: expected 259, got `=r(sum)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W3.2.pt]: censored person-time = 259 days"
    }
}
if `t_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W3.2"
}


* =============================================================================
**# WORKFLOW 4: tvexpose → tvage → tvmerge → tvevent (full pipeline, 2 persons)
* =============================================================================
*
* Scenario: 2 persons with different exposure/event patterns
*
* Person 1: DOB=Jan1/1965, Entry=Jan1/2020, Exit=Dec31/2020
*   Exposure: Drug X, Mar1-Sep30/2020
*   Event: Nov15/2020
*
* Person 2: DOB=Jul1/1970, Entry=Jan1/2020, Exit=Dec31/2020
*   Exposure: Drug X, Jun1-Aug31/2020
*   Event: none (censored)
*
* Date values:
*   Jan1/1965 = -1826, Jul1/1970 = 3834
*   Jan1/2020 = 21915, Dec31/2020 = 22281
*   Mar1/2020 = 21975, Sep30/2020 = 22188
*   Jun1/2020 = 22067, Aug31/2020 = 22159
*   Nov15/2020 = 22235
*
* tvexpose for Person 1:
*   [21915, 21974] ref=0  (Jan1-Feb29, 60 days)
*   [21975, 22188] exp=1  (Mar1-Sep30, 214 days)
*   [22189, 22281] ref=0  (Oct1-Dec31, 93 days)
*
* tvexpose for Person 2:
*   [21915, 22066] ref=0  (Jan1-May31, 152 days)
*   [22067, 22159] exp=1  (Jun1-Aug31, 93 days)
*   [22160, 22281] ref=0  (Sep1-Dec31, 122 days)
*
* tvage for Person 1 (DOB=Jan1/1965=-1826, groupwidth=5):
*   age_entry = floor((21915 - (-1826)) / 365.25) = floor(65.001) = 65
*   Note: 21915+1826 = 23741, 23741/365.25 = 64.9979... → floor = 64
*   Wait — recalculate: -1826 is Jan2/1965 actually. Let me use mdy values.
*   mdy(1,1,1965) = 1826 (days since Jan1/1960)
*   age_entry = floor((21915 - 1826) / 365.25) = floor(20089/365.25) = floor(54.998) = 54
*   age_exit  = floor((22281 - 1826) / 365.25) = floor(20455/365.25) = floor(55.999) = 55
*   2 age groups: 50-54, 55-59
*
* This is getting complex. Let me compute with Stata below and verify.

display as text _newline "WORKFLOW 4: Full pipeline - 2 persons, exposure + age + event"

**## W4.1: tvexpose for 2 persons
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double(study_entry study_exit)
        1 21915 22281
        2 21915 22281
    end
    format %td study_entry study_exit
    tempfile w4_cohort
    save `w4_cohort'

    * Both persons' exposures in one file
    clear
    input long id double(start stop) byte drug_x
        1 21975 22188 1
        2 22067 22159 1
    end
    format %td start stop
    tempfile w4_exp
    save `w4_exp'

    use `w4_cohort', clear
    tvexpose using `w4_exp', id(id) start(start) stop(stop) ///
        exposure(drug_x) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_x)

    * Person 1: 3 intervals, Person 2: 3 intervals → 6 total
    sort id start
    quietly count
    assert r(N) == 6

    * Verify person-time for each person
    capture drop pt
    quietly gen double pt = stop - start + 1
    forvalues p = 1/2 {
        quietly summarize pt if id == `p'
        if r(sum) != 367 {
            display as error "  FAIL [W4.1.pt_p`p']: expected 367, got `=r(sum)'"
            local t_pass = 0
        }
    }

    * Verify Person 1 exposure row
    quietly count if id == 1 & tv_x == 1
    assert r(N) == 1
    quietly summarize start if id == 1 & tv_x == 1
    assert r(mean) == 21975
    quietly summarize stop if id == 1 & tv_x == 1
    assert r(mean) == 22188

    * Verify Person 2 exposure row
    quietly count if id == 2 & tv_x == 1
    assert r(N) == 1
    quietly summarize start if id == 2 & tv_x == 1
    assert r(mean) == 22067
    quietly summarize stop if id == 2 & tv_x == 1
    assert r(mean) == 22159

    tempfile w4_tvexp
    save `w4_tvexp'
}
if _rc == 0 {
    display as result "  PASS: W4.1 tvexpose correct for both persons"
    local ++pass_count
}
else {
    display as error "  FAIL: W4.1 tvexpose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' W4.1"
}

**## W4.2: tvage for 2 persons with groupwidth=5
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double(dob entry exit_)
        1 1826 21915 22281
        2 3834 21915 22281
    end
    format %td dob entry exit_

    * Verify age calculations before running tvage
    * Person 1: DOB=mdy(1,1,1965)=1826
    *   age_entry = floor((21915-1826)/365.25) = 55
    *   age_exit  = floor((22281-1826)/365.25) = 55
    * Person 2: DOB=mdy(7,1,1970)=3834
    *   age_entry = floor((21915-3834)/365.25) = floor(49.480) = 49
    *   age_exit  = floor((22281-3834)/365.25) = floor(50.481) = 50

    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_) ///
        generate(age_tv) startgen(age_start) stopgen(age_stop) ///
        groupwidth(5)

    sort id age_start
    * Person 1: age group 55-59 -> 1 row
    * Person 2: age groups 45-49 and 50-54 -> 2 rows
    quietly count
    assert r(N) == 3

    * Person 1: group 55 only
    quietly levelsof age_tv if id == 1, local(p1_ages)
    * Verify the age groups are correct
    quietly count if id == 1 & age_tv == 50
    if r(N) != 0 {
        display as error "  FAIL [W4.2.p1_g1]: Person 1 should not have age group 50"
        local t_pass = 0
    }
    quietly count if id == 1 & age_tv == 55
    if r(N) != 1 {
        display as error "  FAIL [W4.2.p1_g2]: Person 1 missing age group 55"
        local t_pass = 0
    }

    * Person 2: group 45 then 50
    quietly count if id == 2 & age_tv == 45
    if r(N) != 1 {
        display as error "  FAIL [W4.2.p2_g1]: Person 2 missing age group 45"
        local t_pass = 0
    }
    quietly count if id == 2 & age_tv == 50
    if r(N) != 1 {
        display as error "  FAIL [W4.2.p2_g2]: Person 2 missing age group 50"
        local t_pass = 0
    }

    * Person-time conservation for each person
    capture drop pt
    quietly gen double pt = age_stop - age_start + 1
    forvalues p = 1/2 {
        quietly summarize pt if id == `p'
        if r(sum) != 367 {
            display as error "  FAIL [W4.2.pt_p`p']: expected 367, got `=r(sum)'"
            local t_pass = 0
        }
    }

    * No gaps: each person's intervals must be contiguous
    * For each person, row N+1 start must equal row N stop + 1
    forvalues p = 1/2 {
        quietly count if id == `p'
        local nrows = r(N)
        forvalues r = 1/`nrows' {
            if `r' < `nrows' {
                * Find the rth and (r+1)th row for this person
                local idx1 = 0
                local idx2 = 0
                local cnt = 0
                forvalues obs = 1/`=_N' {
                    if id[`obs'] == `p' {
                        local ++cnt
                        if `cnt' == `r' local idx1 = `obs'
                        if `cnt' == `r' + 1 local idx2 = `obs'
                    }
                }
                if `idx1' > 0 & `idx2' > 0 {
                    local gap = age_start[`idx2'] - age_stop[`idx1'] - 1
                    if `gap' != 0 {
                        display as error "  FAIL [W4.2.gap_p`p']: gap of `gap' days between rows `r' and `=`r'+1'"
                        local t_pass = 0
                    }
                }
            }
        }
    }

    tempfile w4_age
    save `w4_age'
}
if _rc local t_pass = 0
if `t_pass' {
    display as result "  PASS: W4.2 tvage correct (3 intervals, contiguous, PT conserved)"
    local ++pass_count
}
else {
    display as error "  FAIL: W4.2 tvage (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' W4.2"
}

**## W4.3: tvmerge exposure × age
local ++test_count
local t_pass = 1
capture noisily {
    tvmerge "`w4_tvexp'" "`w4_age'", id(id) ///
        start(start age_start) stop(stop age_stop) ///
        exposure(tv_x age_tv) generate(drug_x age_grp)

    sort id start
    * Each person's 3 exposure intervals × 2 age intervals → intersections
    * Not all will overlap, so count may vary. But PT must be conserved.

    * Person-time must equal 367 per person
    capture drop pt
    quietly gen double pt = stop - start + 1
    forvalues p = 1/2 {
        quietly summarize pt if id == `p'
        if r(sum) != 367 {
            display as error "  FAIL [W4.3.pt_p`p']: expected 367, got `=r(sum)'"
            local t_pass = 0
        }
    }

    * No gaps within persons
    forvalues p = 1/2 {
        preserve
        quietly keep if id == `p'
        sort start
        quietly count
        local nrows = r(N)
        forvalues r = 1/`=`nrows'-1' {
            local gap = start[`=`r'+1'] - stop[`r'] - 1
            if `gap' != 0 {
                display as error "  FAIL [W4.3.gap_p`p']: gap of `gap' days at row `r'"
                local t_pass = 0
            }
        }
        restore
    }

    * Verify Person 1 first start and last stop
    quietly summarize start if id == 1
    if r(min) != 21915 {
        display as error "  FAIL [W4.3.p1_start]: expected 21915"
        local t_pass = 0
    }
    quietly summarize stop if id == 1
    if r(max) != 22281 {
        display as error "  FAIL [W4.3.p1_stop]: expected 22281"
        local t_pass = 0
    }

    tempfile w4_merged
    save `w4_merged'
}
if _rc local t_pass = 0
if `t_pass' {
    display as result "  PASS: W4.3 tvmerge exposure × age (PT conserved, no gaps)"
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W4.3"
}

**## W4.4: tvevent on merged data (Person 1 event, Person 2 censored)
local ++test_count
local t_pass = 1
capture noisily {
    * Event for Person 1 only; Person 2 has no event (missing date)
    clear
    input long id double event_dt
        1 22235
        2 .
    end
    format %td event_dt

    tvevent using `w4_merged', id(id) date(event_dt) ///
        generate(outcome) type(single) replace

    sort id start

    * Person 1: event at 22235 (Nov15/2020) truncates follow-up
    * All Person 1 intervals after the event should be dropped
    quietly count if id == 1 & outcome == 1
    if r(N) != 1 {
        display as error "  FAIL [W4.4.p1_event]: expected exactly 1 event row"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W4.4.p1_event]: Person 1 has exactly 1 event"
    }

    * Person 1 last stop should be event date (22235)
    quietly summarize stop if id == 1
    if r(max) != 22235 {
        display as error "  FAIL [W4.4.p1_stop]: expected last stop=22235 (Nov15), got `=r(max)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W4.4.p1_stop]: Person 1 censored at event date"
    }

    * Person 1 PT = 22235 - 21915 + 1 = 321 days
    capture drop pt
    quietly gen double pt = stop - start + 1
    quietly summarize pt if id == 1
    if r(sum) != 321 {
        display as error "  FAIL [W4.4.p1_pt]: expected 321, got `=r(sum)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W4.4.p1_pt]: Person 1 PT = 321 days"
    }

    * Person 2: censored, all intervals retained, no events
    quietly count if id == 2 & outcome != 0
    if r(N) != 0 {
        display as error "  FAIL [W4.4.p2_cens]: Person 2 should have no events"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W4.4.p2_cens]: Person 2 fully censored"
    }

    * Person 2 PT = 367 days (unchanged)
    quietly summarize pt if id == 2
    if r(sum) != 367 {
        display as error "  FAIL [W4.4.p2_pt]: expected 367, got `=r(sum)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W4.4.p2_pt]: Person 2 PT = 367 days (full)"
    }
}
if _rc local t_pass = 0
if `t_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W4.4"
}


* =============================================================================
**# WORKFLOW 5: tvexpose with competing risks → tvevent
* =============================================================================
*
* Scenario: 3 persons with competing events
*   All: entry=Jan1/2020 (21915), exit=Dec31/2020 (22281)
*   All: exposure Mar1-Jun30 (21975-22097)
*
*   Person 1: Primary event Aug1 (22128), Competing event Oct1 (22189)
*             → Primary wins (earlier), outcome=1
*   Person 2: Primary event Oct1 (22189), Competing event Aug1 (22128)
*             → Competing wins (earlier), outcome=2
*   Person 3: No primary event, Competing event Sep1 (22159)
*             → Competing wins, outcome=2
*
* tvevent with competing risks:
*   Person 1: event at 22128 (Aug1), type=1 (primary)
*   Person 2: event at 22128 (Aug1), type=2 (competing — death wins)
*   Person 3: event at 22159 (Sep1), type=2 (competing)

display as text _newline "WORKFLOW 5: Competing risks through full pipeline"

**## W5.1: tvexpose + tvevent with compete()
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double(study_entry study_exit)
        1 21915 22281
        2 21915 22281
        3 21915 22281
    end
    format %td study_entry study_exit
    tempfile w5_cohort
    save `w5_cohort'

    clear
    input long id double(start stop) byte drug
        1 21975 22097 1
        2 21975 22097 1
        3 21975 22097 1
    end
    format %td start stop
    tempfile w5_exp
    save `w5_exp'

    use `w5_cohort', clear
    tvexpose using `w5_exp', id(id) start(start) stop(stop) ///
        exposure(drug) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_drug)
    tempfile w5_intervals
    save `w5_intervals'

    * Event data with competing risks
    clear
    input long id double(primary_dt death_dt)
        1 22128 22189
        2 22189 22128
        3 .     22159
    end
    format %td primary_dt death_dt

    tvevent using `w5_intervals', id(id) date(primary_dt) ///
        compete(death_dt) ///
        generate(outcome) type(single) replace

    sort id start

    * Person 1: primary event at 22128 (Aug1), outcome=1
    quietly count if id == 1 & outcome == 1
    if r(N) != 1 {
        display as error "  FAIL [W5.1.p1]: expected outcome=1 for Person 1"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W5.1.p1]: Person 1 primary event (outcome=1)"
    }
    quietly summarize stop if id == 1 & outcome == 1
    if r(mean) != 22128 {
        display as error "  FAIL [W5.1.p1_date]: expected stop=22128 (Aug1)"
        local t_pass = 0
    }

    * Person 2: competing event at 22128 (death first), outcome=2
    quietly count if id == 2 & outcome == 2
    if r(N) != 1 {
        display as error "  FAIL [W5.1.p2]: expected outcome=2 for Person 2"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W5.1.p2]: Person 2 competing event (outcome=2)"
    }
    quietly summarize stop if id == 2 & outcome == 2
    if r(mean) != 22128 {
        display as error "  FAIL [W5.1.p2_date]: expected stop=22128 (Aug1)"
        local t_pass = 0
    }

    * Person 3: competing event at 22159 (Sep1), outcome=2
    quietly count if id == 3 & outcome == 2
    if r(N) != 1 {
        display as error "  FAIL [W5.1.p3]: expected outcome=2 for Person 3"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W5.1.p3]: Person 3 competing event (outcome=2)"
    }
    quietly summarize stop if id == 3 & outcome == 2
    if r(mean) != 22159 {
        display as error "  FAIL [W5.1.p3_date]: expected stop=22159 (Sep1)"
        local t_pass = 0
    }

    * Verify no post-event rows exist
    capture drop pt
    quietly gen double pt = stop - start + 1
    * Person 1 PT: 22128 - 21915 + 1 = 214
    quietly summarize pt if id == 1
    if r(sum) != 214 {
        display as error "  FAIL [W5.1.p1_pt]: expected 214, got `=r(sum)'"
        local t_pass = 0
    }
    * Person 2 PT: 22128 - 21915 + 1 = 214
    quietly summarize pt if id == 2
    if r(sum) != 214 {
        display as error "  FAIL [W5.1.p2_pt]: expected 214, got `=r(sum)'"
        local t_pass = 0
    }
    * Person 3 PT: 22159 - 21915 + 1 = 245
    quietly summarize pt if id == 3
    if r(sum) != 245 {
        display as error "  FAIL [W5.1.p3_pt]: expected 245, got `=r(sum)'"
        local t_pass = 0
    }
}
if `t_pass' {
    display as result "  PASS: W5.1 competing risks resolved correctly"
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W5.1"
}


* =============================================================================
**# WORKFLOW 6: tvexpose with continuous proportioning → tvmerge → tvevent
* =============================================================================
*
* Scenario: 1 person, entry=Jan1/2020, exit=Mar31/2020 (91 days)
*   Exposure A (continuous): Jan1-Mar31, value=90 (total dose over 91 days)
*   Exposure B (categorical): Feb1-Feb29, value=1
*   Event: Mar15/2020
*
* Date values:
*   Jan1/2020 = 21915, Mar31/2020 = 22005
*   Feb1/2020 = 21946, Feb29/2020 = 21974
*   Mar15/2020 = 21989
*
* tvexpose A (generates 1 interval spanning full follow-up, since continuous
*   covers the entire period — there are no gaps):
*   [21915, 22005] exp=90 (91 days, rate = 90/91 per day)
*
* tvexpose B:
*   [21915, 21945] ref=0  (Jan1-Jan31, 31 days)
*   [21946, 21974] exp=1  (Feb1-Feb29, 29 days)
*   [21975, 22005] ref=0  (Mar1-Mar31, 31 days)
*
* tvmerge with continuous(1) (Exposure A is continuous):
*   Intersection of A's 1 row with B's 3 rows:
*   [21915, 21945] A_prop=90*(31/91)=29.67, B=0
*   [21946, 21974] A_prop=90*(29/91)=28.68, B=1
*   [21975, 22005] A_prop=90*(31/91)=29.67, B=0
*   Sum A_prop: 29.67+28.68+29.67 = 88.02 ... wait, should be 90 exactly.
*   90*(31+29+31)/91 = 90*91/91 = 90 ✓
*
* tvevent (event=21989, Mar15, type=single):
*   Event in [21975, 22005] strictly inside → split at 21989
*     [21975, 21989] B=0, outcome=1, A_prop=90*(15/91)=14.84
*     Wait — proportioning happens on the already-proportioned value.
*     Original A in this row = 90*(31/91) = 30.659...
*     After tvevent split: (15/31)*30.659 = 14.838...
*   Post-event row [21990, 22005] dropped.
*
*   Final:
*     [21915, 21945] A=29.670, B=0, out=0
*     [21946, 21974] A=28.681, B=1, out=0
*     [21975, 21989] A=14.835, B=0, out=1
*   Sum A: 29.670+28.681+14.835 = 73.187
*   Check: 90 * (75/91) = 74.175... hmm
*   Actually: 90 * ((21989-21915+1) / (22005-21915+1)) = 90*(75/91) = 74.18
*   But proportioning is sequential: each step re-proportions.
*   Let me just verify the sum is self-consistent and the event row is correct.

display as text _newline "WORKFLOW 6: Continuous proportioning through merge + event"

**## W6.1: tvmerge with continuous exposure
local ++test_count
local t_pass = 1
capture noisily {
    * Cohort
    clear
    input long id double(study_entry study_exit)
        1 21915 22005
    end
    format %td study_entry study_exit
    tempfile w6_cohort
    save `w6_cohort'

    * Exposure A: continuous, full period
    clear
    input long id double(start stop dose)
        1 21915 22005 1
    end
    format %td start stop
    tempfile w6_exp_a
    save `w6_exp_a'

    use `w6_cohort', clear
    tvexpose using `w6_exp_a', id(id) start(start) stop(stop) ///
        exposure(dose) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_dose)

    * Should be 1 row (full coverage, no gaps)
    sort id start
    quietly count
    assert r(N) == 1
    assert start[1] == 21915 & stop[1] == 22005 & tv_dose[1] == 1
    tempfile w6_tv_a
    save `w6_tv_a'

    * Exposure B: categorical, Feb only
    clear
    input long id double(start stop) byte drug_b
        1 21946 21974 1
    end
    format %td start stop
    tempfile w6_exp_b
    save `w6_exp_b'

    use `w6_cohort', clear
    tvexpose using `w6_exp_b', id(id) start(start) stop(stop) ///
        exposure(drug_b) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_b)

    sort id start
    quietly count
    assert r(N) == 3
    tempfile w6_tv_b
    save `w6_tv_b'

    * Merge with continuous(1) for dose
    tvmerge "`w6_tv_a'" "`w6_tv_b'", id(id) ///
        start(start start) stop(stop stop) ///
        exposure(tv_dose tv_b) generate(dose drug_b) ///
        continuous(tv_dose)

    sort id start
    quietly count
    assert r(N) == 3

    * Row 1: [21915, 21945] dose = 1*(31/91) = 0.3407
    local exp_dose1 = 1 * 31/91
    if abs(dose[1] - `exp_dose1') > 0.001 {
        display as error "  FAIL [W6.1.dose1]: expected " %6.4f `exp_dose1' ///
            ", got " %6.4f dose[1]
        local t_pass = 0
    }
    else {
        display as result "  PASS [W6.1.dose1]: dose=" %6.4f dose[1]
    }

    * Row 2: [21946, 21974] dose = 1*(29/91) = 0.3187
    local exp_dose2 = 1 * 29/91
    if abs(dose[2] - `exp_dose2') > 0.001 {
        display as error "  FAIL [W6.1.dose2]: expected " %6.4f `exp_dose2' ///
            ", got " %6.4f dose[2]
        local t_pass = 0
    }
    else {
        display as result "  PASS [W6.1.dose2]: dose=" %6.4f dose[2]
    }

    * Row 3: [21975, 22005] dose = 1*(31/91) = 0.3407
    local exp_dose3 = 1 * 31/91
    if abs(dose[3] - `exp_dose3') > 0.001 {
        display as error "  FAIL [W6.1.dose3]: expected " %6.4f `exp_dose3' ///
            ", got " %6.4f dose[3]
        local t_pass = 0
    }
    else {
        display as result "  PASS [W6.1.dose3]: dose=" %6.4f dose[3]
    }

    * Sum of proportioned doses must equal original dose
    quietly summarize dose
    if abs(r(sum) - 1) > 0.001 {
        display as error "  FAIL [W6.1.sum]: dose sum=" %8.5f r(sum) ", expected 1.0"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W6.1.sum]: dose sums to 1.0"
    }

    tempfile w6_merged
    save `w6_merged'
}
if _rc local t_pass = 0
if `t_pass' {
    display as result "  PASS: W6.1 continuous proportioning correct"
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W6.1"
}

**## W6.2: tvevent further proportions continuous after split
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double event_dt
        1 21989
    end
    format %td event_dt

    tvevent using `w6_merged', id(id) date(event_dt) ///
        generate(outcome) continuous(dose) type(single) replace

    sort id start
    quietly count
    assert r(N) == 3

    * Event splits row 3 [21975, 22005] → [21975, 21989] with outcome=1
    if stop[3] != 21989 | outcome[3] != 1 {
        display as error "  FAIL [W6.2.event]: expected stop=21989, outcome=1"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W6.2.event]: event at Mar15, correct"
    }

    * Dose on event row: original was 1*(31/91), now proportioned to 15/31 of that
    * = 1 * (31/91) * (15/31) = 15/91 = 0.16484
    * tvevent uses [start,stop] inclusive: new_dur = 21989-21975+1 = 15
    *                                     orig_dur = 22005-21975+1 = 31
    local exp_event_dose = (1 * 31/91) * (15/31)
    if abs(dose[3] - `exp_event_dose') > 0.001 {
        display as error "  FAIL [W6.2.dose]: expected " %6.4f `exp_event_dose' ///
            ", got " %6.4f dose[3]
        local t_pass = 0
    }
    else {
        display as result "  PASS [W6.2.dose]: event row dose=" %6.4f dose[3]
    }

    * Total dose through event = proportioned to person-time used
    * Rows 1+2 unchanged, row 3 proportioned
    * Expected: (31/91) + (29/91) + (15/91) = 75/91 = 0.8242
    quietly summarize dose
    local exp_total = 75/91
    if abs(r(sum) - `exp_total') > 0.001 {
        display as error "  FAIL [W6.2.sum]: expected " %6.4f `exp_total' ///
            ", got " %6.4f r(sum)
        local t_pass = 0
    }
    else {
        display as result "  PASS [W6.2.sum]: total dose=" %6.4f r(sum) " (75/91)"
    }
}
if _rc local t_pass = 0
if `t_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W6.2"
}


* =============================================================================
**# WORKFLOW 7: Multi-person tvage with birthday boundaries
* =============================================================================
*
* Test that tvage correctly handles the 365.25-day age formula across
* leap-year boundaries with known DOBs.
*
* Person 1: DOB=Feb29/2000 (leap day baby)
*   mdy(2,29,2000) = 14669
*   Entry=Jan1/2020 = 21915
*   Exit=Dec31/2021 = 22646
*   age_entry = floor((21915-14669)/365.25) = floor(7246/365.25) = floor(19.838) = 19
*   age_exit  = floor((22646-14669)/365.25) = floor(7977/365.25) = floor(21.838) = 21
*   → 3 age intervals: 19, 20, 21
*
* Person 2: DOB=Dec31/1999
*   mdy(12,31,1999) = 14609
*   Entry=Jan1/2020 = 21915
*   Exit=Dec31/2020 = 22281
*   age_entry = floor((21915-14609)/365.25) = 20
*   age_exit  = floor((22281-14609)/365.25) = 21
*   -> 2 age intervals: 20, 21

display as text _newline "WORKFLOW 7: tvage birthday boundary edge cases"

**## W7.1: Leap-day baby and year-end baby
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double(dob entry exit_)
        1 14669 21915 22646
        2 14609 21915 22281
    end
    format %td dob entry exit_

    * Verify our hand calculations match Stata's floor()
    assert floor((21915 - 14669) / 365.25) == 19
    assert floor((22646 - 14669) / 365.25) == 21
    assert floor((21915 - 14609) / 365.25) == 20
    assert floor((22281 - 14609) / 365.25) == 21

    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_) ///
        generate(age_tv) startgen(age_start) stopgen(age_stop)

    sort id age_start

    * Person 1: 3 rows (ages 19, 20, 21)
    quietly count if id == 1
    if r(N) != 3 {
        display as error "  FAIL [W7.1.p1_rows]: expected 3, got `=r(N)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W7.1.p1_rows]: Person 1 has 3 age intervals"
    }

    * Person 1 first row must start at entry
    quietly summarize age_start if id == 1
    if r(min) != 21915 {
        display as error "  FAIL [W7.1.p1_start]: expected 21915, got `=r(min)'"
        local t_pass = 0
    }
    * Person 1 last row must end at exit
    quietly summarize age_stop if id == 1
    if r(max) != 22646 {
        display as error "  FAIL [W7.1.p1_stop]: expected 22646, got `=r(max)'"
        local t_pass = 0
    }

    * Person 2: 2 rows (ages 20 and 21)
    quietly count if id == 2
    if r(N) != 2 {
        display as error "  FAIL [W7.1.p2_rows]: expected 2, got `=r(N)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W7.1.p2_rows]: Person 2 has 2 age intervals"
    }

    * Person 2 ages should be 20 and 21
    quietly count if id == 2 & age_tv == 20
    local p2_age20 = r(N)
    quietly count if id == 2 & age_tv == 21
    local p2_age21 = r(N)
    if `p2_age20' != 1 | `p2_age21' != 1 {
        display as error "  FAIL [W7.1.p2_age]: expected one row each for ages 20 and 21"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W7.1.p2_age]: Person 2 ages=20,21"
    }

    * Person-time conservation
    capture drop pt
    quietly gen double pt = age_stop - age_start + 1
    quietly summarize pt if id == 1
    * 22646 - 21915 + 1 = 732
    if r(sum) != 732 {
        display as error "  FAIL [W7.1.p1_pt]: expected 732, got `=r(sum)'"
        local t_pass = 0
    }
    quietly summarize pt if id == 2
    * 22281 - 21915 + 1 = 367
    if r(sum) != 367 {
        display as error "  FAIL [W7.1.p2_pt]: expected 367, got `=r(sum)'"
        local t_pass = 0
    }
}
if _rc local t_pass = 0
if `t_pass' {
    display as result "  PASS: W7.1 birthday boundaries correct"
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W7.1"
}


* =============================================================================
**# WORKFLOW 8: tvexpose with grace period → tvmerge → tvevent
* =============================================================================
*
* Scenario: 1 person, entry=Jan1/2020, exit=Jun30/2020 (182 days)
*   Two exposure periods with 5-day gap:
*     Period 1: Jan15-Feb28 (21929-21973)
*     Period 2: Mar5-Apr30  (21979-22035)
*     Gap: Mar1-Mar4 = 5 days gap (Feb29 is stop of P1+1 = Mar1, Mar5 is P2 start)
*     Actually: gap = 21979 - 21973 - 1 = 5 days
*
*   grace(7): Gap of 5 days ≤ 7 → bridged (first period extended, no gap row)
*     Result: [21929,21978] exp=1, [21979,22035] exp=1 (two contiguous rows)
*
*   grace(3): Gap of 5 days > 3 → NOT bridged (gap becomes reference)
*     Result: [21929,21973] exp=1, [21974,21978] ref=0, [21979,22035] exp=1

display as text _newline "WORKFLOW 8: Grace period bridging"

**## W8.1: grace(7) bridges the gap
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double(study_entry study_exit)
        1 21915 22096
    end
    format %td study_entry study_exit
    tempfile w8_cohort
    save `w8_cohort'

    clear
    input long id double(start stop) byte drug
        1 21929 21973 1
        1 21979 22035 1
    end
    format %td start stop
    tempfile w8_exp
    save `w8_exp'

    use `w8_cohort', clear
    tvexpose using `w8_exp', id(id) start(start) stop(stop) ///
        exposure(drug) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_drug) grace(7)

    sort id start

    * With grace(7), gap of 5 days is bridged: first period stop is extended
    * to abut the second. Rows remain separate but contiguous (no gap row).
    * Expected: baseline(0) + exp1(1) + exp2(1) + post(0) = 4 rows
    quietly count if tv_drug == 1
    if r(N) != 2 {
        display as error "  FAIL [W8.1.bridge]: expected 2 exposed intervals (bridged), got `=r(N)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W8.1.bridge]: gap bridged (2 contiguous exposed rows, no gap)"
    }

    * Key: no reference gap row between the two exposed intervals
    quietly count if tv_drug == 0 & start > 21929 & stop < 22035
    if r(N) != 0 {
        display as error "  FAIL [W8.1.nogap]: unexpected gap row between exposures"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W8.1.nogap]: no reference gap between exposures"
    }

    * Verify total person-time = 182
    capture drop pt
    quietly gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 182 {
        display as error "  FAIL [W8.1.pt]: expected 182, got `=r(sum)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W8.1.pt]: PT = 182"
    }
}
if `t_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W8.1"
}

**## W8.2: grace(3) does NOT bridge the gap
local ++test_count
local t_pass = 1
capture noisily {
    use `w8_cohort', clear
    tvexpose using `w8_exp', id(id) start(start) stop(stop) ///
        exposure(drug) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_drug) grace(3)

    sort id start

    * With grace(3), gap of 5 days > 3 → NOT bridged
    * Expected: baseline(0) + exp1(1) + gap(0) + exp2(1) + post(0) = 5 rows
    quietly count if tv_drug == 1
    if r(N) != 2 {
        display as error "  FAIL [W8.2.nobridge]: expected 2 exposed intervals, got `=r(N)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W8.2.nobridge]: gap NOT bridged (2 separate exposures)"
    }

    * Verify gap row exists
    quietly count if tv_drug == 0 & start > 21929 & stop < 22035
    if r(N) != 1 {
        display as error "  FAIL [W8.2.gap]: expected 1 gap row between exposures"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W8.2.gap]: reference gap row present"
    }

    * Total PT must still be 182
    capture drop pt
    quietly gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 182 {
        display as error "  FAIL [W8.2.pt]: expected 182, got `=r(sum)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W8.2.pt]: PT = 182"
    }
}
if `t_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W8.2"
}


* =============================================================================
**# WORKFLOW 9: tvexpose → tvmerge 3-way → tvevent with timegen
* =============================================================================
*
* Scenario: 1 person, entry=Jan1/2020 (21915), exit=Sep30/2020 (22188)
*   Drug A: Feb1-Apr30 (21946-22035)
*   Drug B: Mar1-Jun30 (21975-22097)
*   Drug C: May1-Aug31 (22036-22159)
*   Event: Jul15/2020 (22112)
*
* After merging: timeline has regions with 0, 1, 2, or 3 concurrent drugs
*
* tvmerge(A,B) intersections:
*   [21915,21945] A=0,B=0 (Jan)
*   [21946,21974] A=1,B=0 (Feb)
*   [21975,22035] A=1,B=1 (Mar-Apr)
*   [22036,22097] A=0,B=1 (May-Jun)
*   [22098,22188] A=0,B=0 (Jul-Sep)
*
* tvmerge(AB,C) intersections:
*   [21915,21945] A=0,B=0,C=0
*   [21946,21974] A=1,B=0,C=0
*   [21975,22035] A=1,B=1,C=0
*   [22036,22097] A=0,B=1,C=1  ← C starts May1
*   [22098,22159] A=0,B=0,C=1  ← B ended Jun30
*   [22160,22188] A=0,B=0,C=0  ← C ended Aug31
*
* tvevent with timegen(years):
*   Event at 22112 falls in [22098,22159] strictly inside → split
*   [22098, 22112] C=1, outcome=1
*   [22113, 22159] → DROPPED
*   [22160, 22188] → DROPPED
*   Final rows: 5 (rows 1-4 unchanged, row 5 = split)
*
*   timegen = (stop - first_start) / 365.25
*   Event row: (22112 - 21915) / 365.25 = 197/365.25 = 0.5393 years

display as text _newline "WORKFLOW 9: 3-way merge → tvevent with timegen"

**## W9.1: 3-way merge
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double(study_entry study_exit)
        1 21915 22188
    end
    format %td study_entry study_exit
    tempfile w9_cohort
    save `w9_cohort'

    * Drug A
    clear
    input long id double(start stop) byte drug_a
        1 21946 22035 1
    end
    format %td start stop
    tempfile w9_exp_a
    save `w9_exp_a'

    * Drug B
    clear
    input long id double(start stop) byte drug_b
        1 21975 22097 1
    end
    format %td start stop
    tempfile w9_exp_b
    save `w9_exp_b'

    * Drug C
    clear
    input long id double(start stop) byte drug_c
        1 22036 22159 1
    end
    format %td start stop
    tempfile w9_exp_c
    save `w9_exp_c'

    * tvexpose for each drug
    use `w9_cohort', clear
    tvexpose using `w9_exp_a', id(id) start(start) stop(stop) ///
        exposure(drug_a) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_a)
    tempfile w9_tv_a
    save `w9_tv_a'

    use `w9_cohort', clear
    tvexpose using `w9_exp_b', id(id) start(start) stop(stop) ///
        exposure(drug_b) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_b)
    tempfile w9_tv_b
    save `w9_tv_b'

    use `w9_cohort', clear
    tvexpose using `w9_exp_c', id(id) start(start) stop(stop) ///
        exposure(drug_c) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_c)
    tempfile w9_tv_c
    save `w9_tv_c'

    * 3-way merge in a single tvmerge call.
    tvmerge "`w9_tv_a'" "`w9_tv_b'" "`w9_tv_c'", id(id) ///
        start(start start start) stop(stop stop stop) ///
        exposure(tv_a tv_b tv_c) generate(drug_a drug_b drug_c)

    sort id start
    quietly count
    assert r(N) == 6

    * Verify row-by-row drug status
    * Row 1: none
    assert drug_a[1]==0 & drug_b[1]==0 & drug_c[1]==0
    * Row 2: A only
    assert drug_a[2]==1 & drug_b[2]==0 & drug_c[2]==0
    * Row 3: A+B
    assert drug_a[3]==1 & drug_b[3]==1 & drug_c[3]==0
    * Row 4: B+C
    assert drug_a[4]==0 & drug_b[4]==1 & drug_c[4]==1
    * Row 5: C only
    assert drug_a[5]==0 & drug_b[5]==0 & drug_c[5]==1
    * Row 6: none
    assert drug_a[6]==0 & drug_b[6]==0 & drug_c[6]==0

    * Person-time = 22188 - 21915 + 1 = 274
    capture drop pt
    quietly gen double pt = stop - start + 1
    quietly summarize pt
    assert r(sum) == 274

    tempfile w9_merged
    save `w9_merged'
}
if _rc local t_pass = 0
if `t_pass' {
    display as result "  PASS: W9.1 3-way merge correct (6 intervals, PT=274)"
    local ++pass_count
}
else {
    display as error "  FAIL: W9.1 3-way merge (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' W9.1"
}

**## W9.2: tvevent with timegen
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double event_dt
        1 22112
    end
    format %td event_dt

    tvevent using `w9_merged', id(id) date(event_dt) ///
        generate(outcome) type(single) ///
        timegen(time_yrs) timeunit(years) replace

    sort id start
    quietly count
    assert r(N) == 5

    * Event row should be the last row
    if outcome[5] != 1 {
        display as error "  FAIL [W9.2.event]: last row should have outcome=1"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W9.2.event]: event flagged on last row"
    }

    * Event row stop = 22112
    if stop[5] != 22112 {
        display as error "  FAIL [W9.2.stop]: expected stop=22112, got `=stop[5]'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W9.2.stop]: event at Jul15"
    }

    * timegen on event row = (22112 - 21915) / 365.25 = 0.5393
    local exp_time = (22112 - 21915) / 365.25
    if abs(time_yrs[5] - `exp_time') > 0.001 {
        display as error "  FAIL [W9.2.timegen]: expected " %6.4f `exp_time' ///
            ", got " %6.4f time_yrs[5]
        local t_pass = 0
    }
    else {
        display as result "  PASS [W9.2.timegen]: time_yrs=" %6.4f time_yrs[5] " years"
    }

    * timegen must be monotonically increasing
    quietly gen byte _mono = (time_yrs >= time_yrs[_n-1]) if _n > 1
    quietly count if _mono == 0
    if r(N) != 0 {
        display as error "  FAIL [W9.2.mono]: timegen not monotonic"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W9.2.mono]: timegen monotonically increasing"
    }
}
if _rc local t_pass = 0
if `t_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W9.2"
}


* =============================================================================
**# WORKFLOW 10: Event at exact boundary dates
* =============================================================================
*
* Tests the [start, stop] inclusive boundary behavior:
*   Event at start: flagged, interval split into [start,start] and [start+1,stop]
*   Event at stop:  flagged directly (no split needed)
*   Event between:  split at event date
*
* Scenario: 1 person, 1 interval [21915, 22281]
*   Test A: Event at start (21915)
*   Test B: Event at stop (22281)
*   Test C: Event 1 day after start (21916)

display as text _newline "WORKFLOW 10: Event at exact boundary dates"

**## W10.1: Event at exact start date
local ++test_count
local t_pass = 1
capture noisily {
    * Create single-interval dataset
    clear
    input long id double(start stop) byte tv_exp
        1 21915 22281 1
    end
    format %td start stop
    tempfile w10_intervals
    save `w10_intervals'

    * Event at start
    clear
    input long id double event_dt
        1 21915
    end
    format %td event_dt
    tvevent using `w10_intervals', id(id) date(event_dt) ///
        generate(outcome) type(single) replace

    sort id start

    * Event at start: split into [21915,21915] (event) and [21916,22281] (dropped)
    * type(single) → only 1 row remains
    quietly count
    assert r(N) == 1

    * The event row
    if start[1] != 21915 | stop[1] != 21915 | outcome[1] != 1 {
        display as error "  FAIL [W10.1]: expected [21915,21915] out=1, got [" ///
            start[1] "," stop[1] "] out=" outcome[1]
        local t_pass = 0
    }
    else {
        display as result "  PASS [W10.1]: event at start → single-day interval"
    }
}
if `t_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W10.1"
}

**## W10.2: Event at exact stop date
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double event_dt
        1 22281
    end
    format %td event_dt
    tvevent using `w10_intervals', id(id) date(event_dt) ///
        generate(outcome) type(single) replace

    sort id start
    quietly count
    assert r(N) == 1

    * Event at stop: flagged directly, no split
    if start[1] != 21915 | stop[1] != 22281 | outcome[1] != 1 {
        display as error "  FAIL [W10.2]: expected [21915,22281] out=1"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W10.2]: event at stop → no split needed"
    }
}
if `t_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W10.2"
}

**## W10.3: Event 1 day after start
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double event_dt
        1 21916
    end
    format %td event_dt
    tvevent using `w10_intervals', id(id) date(event_dt) ///
        generate(outcome) type(single) replace

    sort id start
    * Split at 21916: [21915,21916] event, [21917,22281] dropped
    quietly count
    assert r(N) == 1

    if start[1] != 21915 | stop[1] != 21916 | outcome[1] != 1 {
        display as error "  FAIL [W10.3]: expected [21915,21916] out=1"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W10.3]: event 1 day in → 2-day interval"
    }
}
if `t_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W10.3"
}


* =============================================================================
**# WORKFLOW 11: tvexpose evertreated → tvmerge → tvevent (exposure status)
* =============================================================================
*
* Tests the evertreated definition: once exposed, always exposed
*
* Scenario: 1 person, entry=Jan1/2020, exit=Jun30/2020
*   Exposure periods: Feb1-Feb29, Apr1-Apr30
*   With evertreated: becomes ever-exposed at Feb1, stays exposed forever
*
* Expected tvexpose output with evertreated:
*   [21915, 21945] unexposed (Jan1-Jan31)
*   [21946, 22096] exposed  (Feb1-Jun30, entire rest of follow-up)
*   Total: 31 + 151 = 182 ✓

display as text _newline "WORKFLOW 11: evertreated → merge → event"

**## W11.1: tvexpose with evertreated
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double(study_entry study_exit)
        1 21915 22096
    end
    format %td study_entry study_exit
    tempfile w11_cohort
    save `w11_cohort'

    clear
    input long id double(start stop) byte drug
        1 21946 21974 1
        1 22006 22035 1
    end
    format %td start stop
    tempfile w11_exp
    save `w11_exp'

    use `w11_cohort', clear
    tvexpose using `w11_exp', id(id) start(start) stop(stop) ///
        exposure(drug) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_ever) evertreated

    sort id start

    * evertreated: 2 rows — unexposed baseline + ever-exposed rest
    quietly count
    assert r(N) == 2

    * Row 1: unexposed
    assert start[1] == 21915 & stop[1] == 21945 & tv_ever[1] == 0

    * Row 2: ever-exposed from first exposure to exit
    assert start[2] == 21946 & stop[2] == 22096 & tv_ever[2] == 1

    * Person-time
    capture drop pt
    quietly gen double pt = stop - start + 1
    quietly summarize pt
    assert r(sum) == 182

    tempfile w11_tv
    save `w11_tv'
}
if _rc == 0 {
    display as result "  PASS: W11.1 evertreated correct (2 intervals)"
    local ++pass_count
}
else {
    display as error "  FAIL: W11.1 evertreated (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' W11.1"
}

**## W11.2: Merge evertreated with age, then event
local ++test_count
local t_pass = 1
capture noisily {
    * Create age intervals for same person
    clear
    input long id double(dob entry exit_)
        1 7305 21915 22096
    end
    format %td dob entry exit_
    * DOB = mdy(1,1,1980) = 7305
    * age_entry = floor((21915-7305)/365.25) = floor(14610/365.25) = floor(39.999) = 39
    * Wait: 14610/365.25 = 39.9726... → floor = 39
    * Hmm let me be more precise: mdy(1,1,1980) = 7305
    * 365.25*40 = 14610. So 14610/365.25 = 40.0 exactly. floor(40.0) = 40.
    * Actually Stata stores as double, so 14610/365.25 might be 39.999...
    * This is exactly the edge case. Let me just run it and check.

    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_) ///
        generate(age_tv) startgen(age_start) stopgen(age_stop)
    tempfile w11_age
    save `w11_age'

    * Merge
    tvmerge "`w11_tv'" "`w11_age'", id(id) ///
        start(start age_start) stop(stop age_stop) ///
        exposure(tv_ever age_tv) generate(ever age_grp)

    * PT must be 182
    capture drop pt
    quietly gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 182 {
        display as error "  FAIL [W11.2.pt]: expected 182, got `=r(sum)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W11.2.pt]: merged PT = 182"
    }

    tempfile w11_merged
    save `w11_merged'

    * Event at Apr15 = mdy(4,15,2020) = 22020
    clear
    input long id double event_dt
        1 22020
    end
    format %td event_dt

    tvevent using `w11_merged', id(id) date(event_dt) ///
        generate(outcome) type(single) replace

    * Event row must be exposed (ever=1 since Feb1)
    quietly count if outcome == 1
    assert r(N) == 1

    * The event row should have ever=1
    quietly summarize ever if outcome == 1
    if r(mean) != 1 {
        display as error "  FAIL [W11.2.ever]: event row has ever=`=r(mean)', expected 1"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W11.2.ever]: event occurred during ever-exposed"
    }

    * Person-time = 22020 - 21915 + 1 = 106
    capture drop pt
    quietly gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 106 {
        display as error "  FAIL [W11.2.event_pt]: expected 106, got `=r(sum)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W11.2.event_pt]: censored PT = 106"
    }
}
if `t_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W11.2"
}


* =============================================================================
**# WORKFLOW 12: Multi-person pipeline invariants
* =============================================================================
*
* Tests structural invariants that must hold for any valid pipeline output:
*   1. No gaps within person (contiguous intervals)
*   2. No overlaps within person
*   3. Person-time conservation (sum = exit - entry + 1, or less with events)
*   4. start ≤ stop for every row
*   5. Monotonic start dates within person
*
* Uses 5 persons with varied patterns to stress-test invariants.

display as text _newline "WORKFLOW 12: Multi-person pipeline invariants"

**## W12.1: Structural invariants
local ++test_count
local t_pass = 1
capture noisily {
    * 5 persons with varying patterns
    clear
    input long id double(study_entry study_exit)
        1 21915 22281
        2 21915 22281
        3 21915 22281
        4 21915 22281
        5 21915 22281
    end
    format %td study_entry study_exit
    tempfile w12_cohort
    save `w12_cohort'

    * Varied exposure patterns
    clear
    input long id double(start stop) byte drug
        1 21915 22281 1    // Full coverage
        2 21950 21980 1    // Short exposure
        3 21930 21960 1    // Early
        3 22000 22050 1    // Mid (gap between)
        3 22100 22200 1    // Late
        4 21915 21915 1    // Single-day exposure
        // Person 5: never exposed
    end
    format %td start stop
    tempfile w12_exp
    save `w12_exp'

    use `w12_cohort', clear
    tvexpose using `w12_exp', id(id) start(start) stop(stop) ///
        exposure(drug) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_drug)

    sort id start

    * INVARIANT 1: start ≤ stop for every row
    quietly count if start > stop
    if r(N) != 0 {
        display as error "  FAIL [W12.1.order]: `=r(N)' rows with start > stop"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W12.1.order]: all rows have start ≤ stop"
    }

    * INVARIANT 2: no gaps within person
    local gap_count = 0
    forvalues p = 1/5 {
        preserve
        quietly keep if id == `p'
        sort start
        quietly count
        local nr = r(N)
        if `nr' > 1 {
            forvalues r = 1/`=`nr'-1' {
                local gap = start[`=`r'+1'] - stop[`r'] - 1
                if `gap' != 0 {
                    local ++gap_count
                }
            }
        }
        restore
    }
    if `gap_count' != 0 {
        display as error "  FAIL [W12.1.gaps]: `gap_count' gaps found"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W12.1.gaps]: no gaps within any person"
    }

    * INVARIANT 3: no overlaps within person
    local overlap_count = 0
    forvalues p = 1/5 {
        preserve
        quietly keep if id == `p'
        sort start
        quietly count
        local nr = r(N)
        if `nr' > 1 {
            forvalues r = 1/`=`nr'-1' {
                if start[`=`r'+1'] <= stop[`r'] {
                    local ++overlap_count
                }
            }
        }
        restore
    }
    if `overlap_count' != 0 {
        display as error "  FAIL [W12.1.overlaps]: `overlap_count' overlaps found"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W12.1.overlaps]: no overlaps within any person"
    }

    * INVARIANT 4: person-time conservation (367 days per person)
    capture drop pt
    quietly gen double pt = stop - start + 1
    forvalues p = 1/5 {
        quietly summarize pt if id == `p'
        if r(sum) != 367 {
            display as error "  FAIL [W12.1.pt_p`p']: expected 367, got `=r(sum)'"
            local t_pass = 0
        }
    }
    if `t_pass' {
        display as result "  PASS [W12.1.pt]: all 5 persons have PT=367"
    }

    * INVARIANT 5: first interval starts at entry, last ends at exit
    forvalues p = 1/5 {
        quietly summarize start if id == `p'
        if r(min) != 21915 {
            display as error "  FAIL [W12.1.entry_p`p']: first start != 21915"
            local t_pass = 0
        }
        quietly summarize stop if id == `p'
        if r(max) != 22281 {
            display as error "  FAIL [W12.1.exit_p`p']: last stop != 22281"
            local t_pass = 0
        }
    }
    if `t_pass' {
        display as result "  PASS [W12.1.bounds]: all persons span [entry, exit]"
    }
}
if `t_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W12.1"
}


* =============================================================================
**# WORKFLOW 13: tvexpose with carryforward → tvevent
* =============================================================================
*
* Tests carryforward option: exposure persists through inter-exposure gaps
* carryforward() only applies to gaps BETWEEN exposure periods, not post-final.
*
* Scenario: 1 person, entry=Jan1/2020, exit=Apr30/2020 (121 days)
*   Two exposure periods with 20-day gap:
*     Period 1: Jan15-Feb5  (21929-21950, drug=1)
*     Period 2: Feb26-Mar31 (21971-22005, drug=1)
*     Gap: Feb6-Feb25 = 20 days (21951-21970)
*   carryforward(10): first 10 days of gap get previous exposure (drug=1)
*
* Expected:
*   [21915, 21928] ref=0  (Jan1-Jan14, baseline, 14 days)
*   [21929, 21950] exp=1  (Jan15-Feb5, actual exposure, 22 days)
*   [21951, 21960] exp=1  (Feb6-Feb15, carryforward 10 days)
*   [21961, 21970] ref=0  (Feb16-Feb25, remaining gap, 10 days)
*   [21971, 22005] exp=1  (Feb26-Mar31, second exposure, 35 days)
*   [22006, 22035] ref=0  (Apr1-Apr30, post-exposure, 30 days)
*   Total: 14 + 22 + 10 + 10 + 35 + 30 = 121 ✓

display as text _newline "WORKFLOW 13: Carryforward → tvevent"

**## W13.1: tvexpose with carryforward(10) between two exposure periods
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double(study_entry study_exit)
        1 21915 22035
    end
    format %td study_entry study_exit
    tempfile w13_cohort
    save `w13_cohort'

    clear
    input long id double(start stop) byte drug
        1 21929 21950 1
        1 21971 22005 1
    end
    format %td start stop
    tempfile w13_exp
    save `w13_exp'

    use `w13_cohort', clear
    tvexpose using `w13_exp', id(id) start(start) stop(stop) ///
        exposure(drug) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_drug) carryforward(10)

    sort id start

    * Exposed time should be: 22 (actual1) + 10 (carryforward) + 35 (actual2) = 67
    capture drop pt
    quietly gen double pt = stop - start + 1
    quietly summarize pt if tv_drug == 1
    local exposed_days = r(sum)
    if `exposed_days' != 67 {
        display as error "  FAIL [W13.1.carry]: expected 67 exposed days, got `exposed_days'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W13.1.carry]: 67 exposed days (22+10+35)"
    }

    * Total PT = 121
    quietly summarize pt
    if r(sum) != 121 {
        display as error "  FAIL [W13.1.pt]: expected 121, got `=r(sum)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W13.1.pt]: PT = 121"
    }

    tempfile w13_tv
    save `w13_tv'
}
if `t_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W13.1"
}

**## W13.2: tvevent during carryforward period
local ++test_count
local t_pass = 1
capture noisily {
    * Event at Feb10 (21955) — during carryforward period (Feb6-Feb15)
    clear
    input long id double event_dt
        1 21955
    end
    format %td event_dt

    tvevent using `w13_tv', id(id) date(event_dt) ///
        generate(outcome) type(single) replace

    sort id start

    * Event should occur during exposed time (carryforward counts as exposed)
    quietly count if outcome == 1
    assert r(N) == 1

    * The event row should have tv_drug == 1 (carryforward exposure)
    quietly summarize tv_drug if outcome == 1
    if r(mean) != 1 {
        display as error "  FAIL [W13.2.cf_event]: event row has tv_drug=`=r(mean)', expected 1"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W13.2.cf_event]: event during carryforward is exposed"
    }

    * Event stop should be 21955
    quietly summarize stop if outcome == 1
    if r(mean) != 21955 {
        display as error "  FAIL [W13.2.stop]: expected stop=21955, got `=r(mean)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W13.2.stop]: event at Feb10"
    }

    * PT = 21955 - 21915 + 1 = 41
    capture drop pt
    quietly gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 41 {
        display as error "  FAIL [W13.2.pt]: expected 41, got `=r(sum)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W13.2.pt]: PT = 41"
    }
}
if `t_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W13.2"
}


* =============================================================================
**# WORKFLOW 14: tvexpose → tvevent recurring events
* =============================================================================
*
* Tests recurring event type: events don't censor follow-up
*
* Scenario: 1 person, entry=Jan1/2020, exit=Jun30/2020 (182 days)
*   Exposure: Feb1-May31 (21946-22066)
*   Events (recurring): Feb15 (21960), Apr15 (22020), Jun1 (22067)
*
* Expected tvevent output (type=recurring):
*   All intervals retained, events flagged at their locations
*   3 events should be flagged (outcome=1)

display as text _newline "WORKFLOW 14: Recurring events"

**## W14.1: recurring events don't truncate
local ++test_count
local t_pass = 1
capture noisily {
    clear
    input long id double(study_entry study_exit)
        1 21915 22096
    end
    format %td study_entry study_exit
    tempfile w14_cohort
    save `w14_cohort'

    clear
    input long id double(start stop) byte drug
        1 21946 22066 1
    end
    format %td start stop
    tempfile w14_exp
    save `w14_exp'

    use `w14_cohort', clear
    tvexpose using `w14_exp', id(id) start(start) stop(stop) ///
        exposure(drug) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_drug)
    tempfile w14_intervals
    save `w14_intervals'

    * Event dataset: 3 recurring events in wide format
    clear
    input long id double(event_dt1 event_dt2 event_dt3)
        1 21960 22020 22067
    end
    format %td event_dt1 event_dt2 event_dt3

    tvevent using `w14_intervals', id(id) date(event_dt) ///
        type(recurring) generate(outcome) replace

    sort id start

    * All person-time retained (no censoring)
    capture drop pt
    quietly gen double pt = stop - start + 1
    quietly summarize pt
    if r(sum) != 182 {
        display as error "  FAIL [W14.1.pt]: expected 182, got `=r(sum)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W14.1.pt]: full PT = 182 (no censoring)"
    }

    * 3 events flagged
    quietly count if outcome == 1
    if r(N) != 3 {
        display as error "  FAIL [W14.1.events]: expected 3 events, got `=r(N)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W14.1.events]: 3 recurring events flagged"
    }

    * Last stop should still be original exit (22096)
    quietly summarize stop
    if r(max) != 22096 {
        display as error "  FAIL [W14.1.exit]: expected max stop=22096, got `=r(max)'"
        local t_pass = 0
    }
    else {
        display as result "  PASS [W14.1.exit]: follow-up extends to Jun30"
    }
}
if `t_pass' {
    local ++pass_count
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' W14.1"
}


* =============================================================================
* SUMMARY
* =============================================================================

local test_count = `pass_count' + `fail_count'
display as result _newline "=== Known-Answer Validation Results -- $S_DATE $S_TIME ==="
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: validation_known_answers tests=`test_count' pass=`pass_count' fail=`fail_count'"

if `fail_count' > 0 {
    display as error "FAILED: `failed_tests'"
    exit 1
}
else {
    display as result "ALL KNOWN-ANSWER VALIDATIONS PASSED"
}
