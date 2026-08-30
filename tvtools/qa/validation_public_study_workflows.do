*! validation_public_study_workflows.do -- known answers for public-study data shapes
*!
*! Small, hand-enumerated analogues of two public survival datasets:
*!   - survival::heart (Stanford heart transplant): delayed entry, a treatment
*!     switch during follow-up, and death at or after the switch.
*!   - survival::pbc/pbcseq (Mayo PBC): irregular repeated laboratory values,
*!     missing updates, and asynchronously changing covariates.
*!
*! These are independent known-answer checks. No value is copied from tvtools.

clear all
set more off
set varabbrev off
version 16.0

capture log close _all
quietly log using "validation_public_study_workflows.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as result "tvtools validation: public-study workflow known answers -- $S_DATE $S_TIME"

**# Stanford heart-transplant data shape

**## Delayed entry on a common 30-day elapsed grid
local ++test_count
capture noisily {
    clear
    set obs 1
    generate long rowid = 1
    generate double origin = mdy(1, 1, 2000)
    generate double enter = origin + 10
    generate double exit = origin + 75
    format origin enter exit %td

    tvsplit, id(rowid) start(enter) stop(exit) ///
        elapsed(origin, width(30) unit(day) generate(fu))
    sort rowid enter

    assert _N == 3
    assert enter[1] == origin[1] + 10 & exit[1] == origin[1] + 29
    assert enter[2] == origin[2] + 30 & exit[2] == origin[2] + 59
    assert enter[3] == origin[3] + 60 & exit[3] == origin[3] + 75
    assert fu[1] == 0 & fu[2] == 30 & fu[3] == 60
    generate double days = exit - enter + 1
    quietly summarize days, meanonly
    assert r(sum) == 66
}
if _rc == 0 {
    display as result "  PASS [H1]: delayed-entry interval follows the common elapsed grid"
    local ++pass_count
}
else {
    display as error "  FAIL [H1]: delayed-entry elapsed grid (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H1"
}

**## Transplant switch followed by death
local ++test_count
capture noisily {
    clear
    input long id double(entry exit)
        1 0 50
    end
    tempfile cohort transplant intervals
    save `cohort'

    clear
    input long id double(start stop) byte transplant
        1 20 50 1
    end
    save `transplant'

    use `cohort', clear
    tvexpose using `transplant', id(id) start(start) stop(stop) ///
        exposure(transplant) reference(0) entry(entry) exit(exit) ///
        generate(tx)
    save `intervals'

    clear
    input long id double(death_date)
        1 35
    end
    tvevent using `intervals', id(id) date(death_date) ///
        generate(death) type(single) replace
    sort id start

    assert _N == 2
    assert start[1] == 0 & stop[1] == 19 & tx[1] == 0 & death[1] == 0
    assert start[2] == 20 & stop[2] == 35 & tx[2] == 1 & death[2] == 1
    generate double days = stop - start + 1
    quietly summarize days, meanonly
    assert r(sum) == 36
}
if _rc == 0 {
    display as result "  PASS [H2]: transplant switch and subsequent death are mapped exactly"
    local ++pass_count
}
else {
    display as error "  FAIL [H2]: transplant/death workflow (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H2"
}

**## Death exactly when transplantation begins
local ++test_count
capture noisily {
    clear
    input long id double(entry exit)
        1 0 50
    end
    tempfile cohort transplant intervals
    save `cohort'

    clear
    input long id double(start stop) byte transplant
        1 20 50 1
    end
    save `transplant'

    use `cohort', clear
    tvexpose using `transplant', id(id) start(start) stop(stop) ///
        exposure(transplant) reference(0) entry(entry) exit(exit) ///
        generate(tx)
    save `intervals'

    clear
    input long id double(death_date)
        1 20
    end
    tvevent using `intervals', id(id) date(death_date) ///
        generate(death) type(single) replace
    sort id start

    assert _N == 2
    assert start[1] == 0 & stop[1] == 19 & tx[1] == 0 & death[1] == 0
    assert start[2] == 20 & stop[2] == 20 & tx[2] == 1 & death[2] == 1
}
if _rc == 0 {
    display as result "  PASS [H3]: a boundary-day death is assigned to the new exposure state"
    local ++pass_count
}
else {
    display as error "  FAIL [H3]: boundary-day event mapping (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' H3"
}

**# Mayo PBC sequential-laboratory data shape

**## Irregular updates with a missing measurement
local ++test_count
capture noisily {
    clear
    input long id double(entry exit)
        1 0 20
    end
    tempfile cohort points episodes
    save `cohort'

    clear
    input long id double(day) int bili10
        1  0 11
        1  5 .
        1  8 20
        1 20 30
    end
    drop if missing(bili10)
    sort id day
    by id (day): generate double stop = day[_n + 1] - 1
    replace stop = 20 if missing(stop)
    rename day start
    save `episodes'

    use `cohort', clear
    tvexpose using `episodes', id(id) start(start) stop(stop) ///
        exposure(bili10) reference(0) entry(entry) exit(exit) ///
        generate(tv_bili10)
    sort id start

    assert _N == 3
    assert start[1] == 0 & stop[1] == 7 & tv_bili10[1] == 11
    assert start[2] == 8 & stop[2] == 19 & tv_bili10[2] == 20
    assert start[3] == 20 & stop[3] == 20 & tv_bili10[3] == 30
    generate double days = stop - start + 1
    quietly summarize days, meanonly
    assert r(sum) == 21
}
if _rc == 0 {
    display as result "  PASS [P1]: nonmissing lab updates carry forward to the next update"
    local ++pass_count
}
else {
    display as error "  FAIL [P1]: irregular sequential lab values (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P1"
}

**## Asynchronous laboratory updates create the union grid
local ++test_count
capture noisily {
    clear
    input long id double(start stop bili)
        1 0  7 1.1
        1 8 20 2.0
    end
    tempfile bili protime
    save `bili'

    clear
    input long id double(start stop protime)
        1  0  4 10
        1  5 11 11
        1 12 20 12
    end
    save `protime'

    tvmerge `bili' `protime', id(id) start(start start) stop(stop stop) ///
        exposure(bili protime)
    sort id start

    assert _N == 4
    assert start[1] == 0  & stop[1] == 4  & abs(bili[1] - 1.1) < 1e-12 & protime[1] == 10
    assert start[2] == 5  & stop[2] == 7  & abs(bili[2] - 1.1) < 1e-12 & protime[2] == 11
    assert start[3] == 8  & stop[3] == 11 & abs(bili[3] - 2.0) < 1e-12 & protime[3] == 11
    assert start[4] == 12 & stop[4] == 20 & abs(bili[4] - 2.0) < 1e-12 & protime[4] == 12
    generate double days = stop - start + 1
    quietly summarize days, meanonly
    assert r(sum) == 21
}
if _rc == 0 {
    display as result "  PASS [P2]: asynchronous lab histories merge onto the exact union grid"
    local ++pass_count
}
else {
    display as error "  FAIL [P2]: asynchronous laboratory merge (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P2"
}

**# Summary
local test_count = `pass_count' + `fail_count'
display as result "Public-study workflow known answers: `pass_count'/`test_count' passed"
display "RESULT: validation_public_study_workflows tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "FAILED: `failed_tests'"
    exit 1
}
