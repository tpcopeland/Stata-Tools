/*******************************************************************************
* validation_audit_tvevent.do
*
* Audit-closure known-answer checks for tvevent name safety, event validation,
* empty recurring schemas, quantity algebra, and strict input integrity.
*
* Author: Timothy P Copeland, Karolinska Institutet
* Date: 2026-07-13
*******************************************************************************/

clear all
set varabbrev off
version 16.0

capture log close _all
quietly log using "validation_audit_tvevent.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

display as result "tvtools QA: audit closure for tvevent -- $S_DATE $S_TIME"

**# Shared interval fixture
quietly {
    clear
    input long id double(start stop) byte exposure int dose
        1 1 10 1 5
    end
    tempfile base_intervals
    save `base_intervals'
}

**# 1. keepvars collisions are rejected transactionally
local ++test_count
capture noisily {
    clear
    input long id double eventdate int(dose outcome start stop elapsed) byte sentinel
        1 4 999 7 101 102 103 71
    end
    foreach bad in dose outcome start stop elapsed eventdate {
        local extra ""
        if "`bad'" == "outcome" local extra "generate(outcome)"
        if "`bad'" == "elapsed" local extra "timegen(elapsed)"
        capture noisily tvevent using "`base_intervals'", id(id) ///
            date(eventdate) keepvars(`bad') `extra'
        local cmdrc = _rc
        assert `cmdrc' == 198
        assert _N == 1 & sentinel == 71 & dose == 999 & outcome == 7
    }

    clear
    input long id double(ed1 ed2) int(seq gs ge) byte sentinel
        1 4 . 7 8 9 72
    end
    foreach bad in seq gs ge {
        capture noisily tvevent using "`base_intervals'", id(id) date(ed) ///
            type(recurring) enum(seq) gapstart(gs) gapstop(ge) ///
            keepvars(`bad')
        local cmdrc = _rc
        assert `cmdrc' == 198
        assert _N == 1 & sentinel == 72 & seq == 7 & gs == 8 & ge == 9
    }

    * Automatic keepvars preserve only safe master fields. Protected output
    * names and names already present in the interval source are excluded,
    * while an explicit request for the same names above remains an error.
    clear
    input long id double(eventdate start stop) int(dose outcome cohort) byte sentinel
        1 4 101 102 999 7 42 75
    end
    tvevent using "`base_intervals'", id(id) date(eventdate) ///
        generate(outcome) replace
    confirm variable cohort sentinel
    assert cohort == 42 & sentinel == 75
    assert outcome == 1 & eventdate == 4
    assert start == 1 & stop == 4 & dose == 5
}
if _rc == 0 {
    display as result "  PASS: explicit collisions fail and automatic keepvars exclude protected names"
    local ++pass_count
}
else {
    display as error "  FAIL: keepvars collision contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' keep_collisions"
}

**# 2. person-level keepvars must be unique within ID
local ++test_count
capture noisily {
    clear
    input long id double eventdate int cohort byte sentinel
        1 3 10 73
        1 4 20 74
    end
    capture noisily tvevent using "`base_intervals'", id(id) ///
        date(eventdate) keepvars(cohort)
    local cmdrc = _rc
    assert `cmdrc' == 459
    assert _N == 2 & cohort[1] == 10 & cohort[2] == 20
    assert sentinel[1] == 73 & sentinel[2] == 74
}
if _rc == 0 {
    display as result "  PASS: nonunique person-level keepvars are rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: keepvars uniqueness (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' keep_unique"
}

**# 3. validate checks the actual interval union and counts affected persons
quietly {
    clear
    input long id double(start stop)
        1 1 3
        1 7 10
    end
    tempfile gap_intervals
    save `gap_intervals'
}

local ++test_count
capture noisily {
    clear
    input long id double eventdate
        1 5
        1 8
    end
    tvevent using "`gap_intervals'", id(id) date(eventdate) ///
        generate(outcome) validate
    local outside = r(v_outside_bounds)
    local multiple = r(v_multiple_events)
    local nevents = r(N_events)
    assert `outside' == 1
    assert `multiple' == 1
    assert `nevents' == 1
    quietly count if outcome == 1 & stop == 8
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: gap events are outside and duplicate rows count one person"
    local ++pass_count
}
else {
    display as error "  FAIL: actual-union validation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' union_validation"
}

**# 4. empty recurring input has the complete requested schema
local ++test_count
capture noisily {
    clear
    set obs 0
    generate long id = .
    generate double ed1 = .
    generate double ed2 = .
    tvevent using "`base_intervals'", id(id) date(ed) type(recurring) ///
        generate(outcome) timegen(elapsed) enum(seq) ///
        gapstart(gs) gapstop(ge)
    confirm variable outcome ed elapsed seq gs ge
    assert _N == 1
    assert outcome == 0 & missing(ed)
    assert elapsed == 9 & seq == 1 & gs == 0 & ge == 9
    assert r(N) == 1 & r(N_events) == 0
    assert "`r(enum)'" == "seq" & "`r(gapstart)'" == "gs"
    assert "`r(gapstop)'" == "ge" & "`r(timegen)'" == "elapsed"
}
if _rc == 0 {
    display as result "  PASS: empty recurring input preserves full output schema"
    local ++pass_count
}
else {
    display as error "  FAIL: empty recurring schema (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' empty_recurring"
}

**# 5. all-missing single-event input uses the same ordinary output path
local ++test_count
capture noisily {
    clear
    input long id double eventdate
        1 .
    end
    tvevent using "`base_intervals'", id(id) date(eventdate) ///
        generate(outcome) timegen(elapsed) validate
    confirm variable outcome eventdate elapsed
    assert _N == 1 & outcome == 0 & missing(eventdate) & elapsed == 9
    assert r(N) == 1 & r(N_events) == 0
}
if _rc == 0 {
    display as result "  PASS: all-missing single events retain the full schema"
    local ++pass_count
}
else {
    display as error "  FAIL: all-missing event schema (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' all_missing"
}

**# 6. all-missing recurring input uses the same full-schema path
local ++test_count
capture noisily {
    clear
    input long id double(ed1 ed2) int cohort
        1 . . 42
    end
    tvevent using "`base_intervals'", id(id) date(ed) type(recurring) ///
        generate(outcome) timegen(elapsed) enum(seq) ///
        gapstart(gs) gapstop(ge) validate
    confirm variable outcome ed elapsed seq gs ge cohort
    assert _N == 1
    assert outcome == 0 & missing(ed) & elapsed == 9
    assert seq == 1 & gs == 0 & ge == 9 & cohort == 42
    assert r(N) == 1 & r(N_events) == 0
    assert "`r(enum)'" == "seq" & "`r(gapstart)'" == "gs"
    assert "`r(gapstop)'" == "ge" & "`r(timegen)'" == "elapsed"
}
if _rc == 0 {
    display as result "  PASS: all-missing recurring events retain the full schema"
    local ++pass_count
}
else {
    display as error "  FAIL: all-missing recurring schema (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' recurring_all_missing"
}

**# 7. recurring event stubs must be a contiguous numbered sequence
local ++test_count
capture noisily {
    clear
    input long id double(ed1 ed3) byte sentinel
        1 2 4 76
    end
    capture noisily tvevent using "`base_intervals'", id(id) date(ed) ///
        type(recurring) generate(outcome)
    local cmdrc = _rc
    assert `cmdrc' == 111
    assert _N == 1 & id == 1 & ed1 == 2 & ed3 == 4 & sentinel == 76
    capture confirm variable outcome
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: noncontiguous recurring stubs fail transactionally"
    local ++pass_count
}
else {
    display as error "  FAIL: recurring stub continuity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' recurring_stub_gap"
}

**# 8. unsupported recurring competing-risk syntax is an explicit error
local ++test_count
capture noisily {
    clear
    input long id double(ed1 ed2 death) byte sentinel
        1 4 . 8 76
    end
    capture noisily tvevent using "`base_intervals'", id(id) date(ed) ///
        type(recurring) compete(death)
    local cmdrc = _rc
    assert `cmdrc' == 198
    assert _N == 1 & sentinel == 76 & death == 8
}
if _rc == 0 {
    display as result "  PASS: recurring compete() fails instead of being ignored"
    local ++pass_count
}
else {
    display as error "  FAIL: recurring compete contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' recurring_compete"
}

**# Quantity fixture: one 10-day row split at day 4
quietly {
    clear
    input long id double(start stop ratev totalv cumv)
        1 1 10 2 100 10
    end
    char ratev[tvtools_quantity] "rate"
    char totalv[tvtools_quantity] "total"
    char cumv[tvtools_quantity] "cumulative"
    char cumv[tvtools_history_point] "start"
    tempfile quantities
    save `quantities'

    clear
    input long id double(ed1 ed2)
        1 4 .
    end
    tempfile recurring_event
    save `recurring_event'
}

**# 9. rate/total/cumulative algebra is exact under event splitting
local ++test_count
capture noisily {
    use `recurring_event', clear
    tvevent using "`quantities'", id(id) date(ed) type(recurring) ///
        generate(outcome) rate(ratev) total(totalv) cumulative(cumv)
    local ratevars "`r(rate_vars)'"
    local totalvars "`r(total_vars)'"
    local cumvars "`r(cumulative_vars)'"
    local nr = r(n_rate)
    local nt = r(n_total)
    local nc = r(n_cumulative)
    sort start
    assert _N == 2
    assert start[1] == 1 & stop[1] == 4
    assert start[2] == 5 & stop[2] == 10
    assert ratev == 2 & cumv == 10
    assert totalv[1] == 40 & totalv[2] == 60
    quietly summarize totalv, meanonly
    assert r(sum) == 100
    assert "`ratevars'" == "ratev" & "`totalvars'" == "totalv"
    assert "`cumvars'" == "cumv" & `nr' == 1 & `nt' == 1 & `nc' == 1
    assert "`: char cumv[tvtools_history_point]'" == "start"
}
if _rc == 0 {
    display as result "  PASS: rate invariant, total conserved, cumulative carried"
    local ++pass_count
}
else {
    display as error "  FAIL: quantity algebra (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' quantities"
}

**# 10. continuous() remains a truthful compatibility alias for total()
local ++test_count
capture noisily {
    use `recurring_event', clear
    tvevent using "`quantities'", id(id) date(ed) type(recurring) ///
        generate(outcome) rate(ratev) continuous(totalv) cumulative(cumv)
    local continuousvars "`r(continuous_vars)'"
    local ncontinuous = r(n_continuous)
    sort start
    assert totalv[1] == 40 & totalv[2] == 60
    assert "`continuousvars'" == "totalv" & `ncontinuous' == 1
}
if _rc == 0 {
    display as result "  PASS: continuous() aliases interval totals"
    local ++pass_count
}
else {
    display as error "  FAIL: continuous alias (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' continuous_alias"
}

**# 11. quantity metadata omissions, mismatches, and history errors fail safely
local ++test_count
capture noisily {
    use `recurring_event', clear
    generate byte sentinel = 79
    capture noisily tvevent using "`quantities'", id(id) date(ed) ///
        type(recurring) generate(outcome)
    local cmdrc = _rc
    assert `cmdrc' == 498 & _N == 1 & sentinel == 79

    capture noisily tvevent using "`quantities'", id(id) date(ed) ///
        type(recurring) generate(outcome) total(ratev totalv) cumulative(cumv)
    local cmdrc = _rc
    assert `cmdrc' == 498 & _N == 1 & sentinel == 79

    preserve
    use `quantities', clear
    char cumv[tvtools_history_point] ""
    tempfile bad_history
    save `bad_history'
    restore
    capture noisily tvevent using "`bad_history'", id(id) date(ed) ///
        type(recurring) generate(outcome) rate(ratev) total(totalv) cumulative(cumv)
    local cmdrc = _rc
    assert `cmdrc' == 498 & _N == 1 & sentinel == 79
}
if _rc == 0 {
    display as result "  PASS: quantity metadata is mandatory and transactional"
    local ++pass_count
}
else {
    display as error "  FAIL: quantity metadata contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' quantity_metadata"
}

**# 12. quantity variables cannot collide with any requested output
local ++test_count
capture noisily {
    tempfile collision_source
    foreach qvar in elapsed seq gs ge {
        clear
        set obs 1
        generate long id = 1
        generate double start = 1
        generate double stop = 10
        generate double value = 100
        rename value `qvar'
        char `qvar'[tvtools_quantity] "total"
        save "`collision_source'", replace

        clear
        set obs 1
        generate long id = 1
        generate double ed1 = 4
        generate double ed2 = .
        generate byte sentinel = 77
        local outputopt ""
        if "`qvar'" == "elapsed" local outputopt "timegen(elapsed)"
        if "`qvar'" == "seq" local outputopt "enum(seq)"
        if "`qvar'" == "gs" local outputopt "gapstart(gs)"
        if "`qvar'" == "ge" local outputopt "gapstop(ge)"
        capture noisily tvevent using "`collision_source'", id(id) ///
            date(ed) type(recurring) total(`qvar') `outputopt' replace
        local cmdrc = _rc
        assert `cmdrc' == 198
        assert _N == 1 & id == 1 & ed1 == 4 & missing(ed2) & sentinel == 77
    }
}
if _rc == 0 {
    display as result "  PASS: quantity/output collisions fail early and transactionally"
    local ++pass_count
}
else {
    display as error "  FAIL: quantity/output name safety (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' quantity_output_names"
}

**# 13. interval rows are strict by default with exact dropinvalid accounting
quietly {
    clear
    input double(id start stop q)
        1 1   10 10
        . 1    3  5
        2 .    3  5
        3 1.5  3  5
        4 5    3  5
        5 1    3  .
    end
    tempfile malformed_intervals
    save `malformed_intervals'
}

local ++test_count
capture noisily {
    clear
    input double(id eventdate) byte sentinel
        1 4 80
    end
    capture noisily tvevent using "`malformed_intervals'", id(id) ///
        date(eventdate) generate(outcome) total(q) verbose
    local cmdrc = _rc
    assert `cmdrc' == 498 & _N == 1 & sentinel == 80

    tvevent using "`malformed_intervals'", id(id) date(eventdate) ///
        generate(outcome) total(q) dropinvalid
    local ninv = r(n_invalid)
    local ni = r(n_invalid_intervals)
    local niid = r(n_invalid_interval_id)
    local nidate = r(n_invalid_interval_dates)
    local niorder = r(n_invalid_interval_order)
    local niq = r(n_invalid_quantity)
    matrix F = r(flow)
    assert `ninv' == 5 & `ni' == 5
    assert `niid' == 1 & `nidate' == 2 & `niorder' == 1 & `niq' == 1
    assert rowsof(F) == 2 & colsof(F) == 3
    assert F[1,1] == 5 & F[1,2] == 1 & F[1,3] == 4
    assert F[2,1] == 6 & F[2,2] == 1 & F[2,3] == 5
    assert _N == 1 & id == 1 & start == 1 & stop == 4 & q == 4
}
if _rc == 0 {
    display as result "  PASS: malformed intervals have exact strict/dropinvalid accounting"
    local ++pass_count
}
else {
    display as error "  FAIL: interval integrity policy (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' interval_integrity"
}

**# 14. malformed event rows are strict; missing event dates remain censored
local ++test_count
capture noisily {
    clear
    input double(id eventdate) byte sentinel
        . 2   81
        1 1.5 82
        2 .   83
        3 2   84
    end
    capture noisily tvevent using "`base_intervals'", id(id) ///
        date(eventdate) generate(outcome)
    local cmdrc = _rc
    assert `cmdrc' == 498 & _N == 4 & sentinel[1] == 81

    * Supply intervals for both valid event-source IDs.
    preserve
    clear
    input long id double(start stop) byte exposure int dose
        2 1 10 0 0
        3 1 10 0 0
    end
    tempfile two_intervals
    save `two_intervals'
    restore
    tvevent using "`two_intervals'", id(id) date(eventdate) ///
        generate(outcome) dropinvalid
    local ninv = r(n_invalid)
    local nm = r(n_invalid_master)
    local nmid = r(n_invalid_master_id)
    local nmd = r(n_invalid_master_dates)
    matrix F = r(flow)
    assert `ninv' == 2 & `nm' == 2 & `nmid' == 1 & `nmd' == 1
    assert _N == 2
    quietly count if id == 2 & outcome == 0
    assert r(N) == 1
    quietly count if id == 3 & outcome == 1 & stop == 2
    assert r(N) == 1
    assert F[1,1] == 2 & F[1,2] == 2
}
if _rc == 0 {
    display as result "  PASS: event-row integrity distinguishes censoring from malformed dates"
    local ++pass_count
}
else {
    display as error "  FAIL: event integrity policy (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' event_integrity"
}

**# 15. string interval bounds fail before caller mutation
quietly {
    clear
    input long id str3(start stop) byte exposure
        1 "1" "10" 1
    end
    tempfile string_intervals
    save `string_intervals'
}

local ++test_count
capture noisily {
    clear
    input long id double eventdate byte sentinel
        1 4 85
    end
    capture noisily tvevent using "`string_intervals'", id(id) ///
        date(eventdate) generate(outcome)
    local cmdrc = _rc
    assert `cmdrc' == 109
    assert _N == 1 & id == 1 & eventdate == 4 & sentinel == 85
}
if _rc == 0 {
    display as result "  PASS: string bounds fail transactionally"
    local ++pass_count
}
else {
    display as error "  FAIL: string-bound validation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' string_bounds"
}

display "RESULT: validation_audit_tvevent tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}

capture log close _all
