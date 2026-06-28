clear all
set more off
set varabbrev off
version 16.0

capture log close
log using "validation_flow.log", replace nomsg

* Shared scaffold: sandboxed install bootstrap
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as result "tvtools QA: attrition/flow report validation -- $S_DATE $S_TIME"

**# TEST 1: tvmerge flow drops a non-matching person under force (known truth)
local ++test_count
capture noisily {
    * Dataset A: ids 1,2,3 ; Dataset B: ids 1,2 (id 3 has no match)
    clear
    input id double(start stop) expa
        1 100 300 1
        2 100 300 1
        3 100 300 1
    end
    format start stop %td
    tempfile fa
    save "`fa'"
    clear
    input id double(start stop) expb
        1 100 300 1
        2 100 300 1
    end
    format start stop %td
    tempfile fb
    save "`fb'"

    tvmerge "`fa'" "`fb'", id(id) start(start start) stop(stop stop) ///
        exposure(expa expb) force flow
    matrix F = r(flow)
    * persons: in=3, out=2, dropped=1 ; records: in=5 (3+2)
    assert F[1,1] == 3
    assert F[1,2] == 2
    assert F[1,3] == 1
    assert F[2,1] == 5
    assert F[2,3] == F[2,1] - F[2,2]
    * row/col names present
    local rn : rownames F
    assert "`rn'" == "persons records"
    local cn : colnames F
    assert "`cn'" == "in out dropped"
}
if _rc == 0 {
    display as result "  PASS: tvmerge flow reports persons in=3 out=2 dropped=1"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge flow known truth (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**# TEST 2: tvmerge flow with fully matched data drops nobody
local ++test_count
capture noisily {
    clear
    input id double(start stop) expa
        1 100 300 1
        2 100 300 1
    end
    format start stop %td
    tempfile fa2
    save "`fa2'"
    clear
    input id double(start stop) expb
        1 100 300 1
        2 100 300 1
    end
    format start stop %td
    tempfile fb2
    save "`fb2'"

    tvmerge "`fa2'" "`fb2'", id(id) start(start start) stop(stop stop) ///
        exposure(expa expb) flow
    matrix F = r(flow)
    assert F[1,1] == 2
    assert F[1,2] == 2
    assert F[1,3] == 0
}
if _rc == 0 {
    display as result "  PASS: tvmerge flow drops nobody when ids fully match"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge flow no-drop baseline (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# TEST 3: tvexpose flow persons in == out for a clean cohort
local ++test_count
capture noisily {
    * Episodes
    clear
    input id double(rx_start rx_stop) exp_type
        1 120 200 1
        2 130 220 1
    end
    format rx_start rx_stop %td
    tempfile epi
    save "`epi'"
    * Cohort (2 valid persons)
    clear
    input id double(study_entry study_exit)
        1 100 365
        2 100 365
    end
    format study_entry study_exit %td
    tvexpose using "`epi'", id(id) start(rx_start) stop(rx_stop) ///
        exposure(exp_type) reference(0) entry(study_entry) exit(study_exit) ///
        generate(tv_exp) flow
    matrix F = r(flow)
    assert F[1,1] == 2
    assert F[1,2] == 2
    assert F[1,3] == 0
    * records out (intervals) is positive and >= persons
    assert F[2,2] >= 2
}
if _rc == 0 {
    display as result "  PASS: tvexpose flow keeps all persons in a clean cohort"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose flow (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**# TEST 4: tvevent flow persons consistent; matrix well-formed
local ++test_count
capture noisily {
    * Interval data (the using source): 2 persons
    clear
    input id double(start stop)
        1 100 400
        2 100 400
    end
    format start stop %td
    tempfile ivl
    save "`ivl'"
    * Events in memory
    clear
    input id double eventdate
        1 250
        2 .
    end
    format eventdate %td
    tvevent using "`ivl'", id(id) date(eventdate) flow replace
    matrix F = r(flow)
    assert rowsof(F) == 2 & colsof(F) == 3
    assert F[1,1] == 2
    assert F[1,2] == 2
    * records out >= records in - (no person dropped); splitting may add rows
    assert F[2,1] == 2
}
if _rc == 0 {
    display as result "  PASS: tvevent flow reports 2 persons in/out, well-formed matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: tvevent flow (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**# TEST 5: flow is a pure side-channel — output identical with/without it
local ++test_count
capture noisily {
    clear
    input id double(start stop) expa
        1 100 300 1
        2 100 300 1
    end
    format start stop %td
    tempfile fa3
    save "`fa3'"
    clear
    input id double(start stop) expb
        1 100 300 1
        2 100 300 1
    end
    format start stop %td
    tempfile fb3
    save "`fb3'"

    tvmerge "`fa3'" "`fb3'", id(id) start(start start) stop(stop stop) ///
        exposure(expa expb) saveas(`c(tmpdir)'/noflow.dta) replace
    tvmerge "`fa3'" "`fb3'", id(id) start(start start) stop(stop stop) ///
        exposure(expa expb) flow saveas(`c(tmpdir)'/withflow.dta) replace

    use "`c(tmpdir)'/noflow.dta", clear
    quietly ds
    sort `r(varlist)'
    datasignature
    local s1 "`r(datasignature)'"
    use "`c(tmpdir)'/withflow.dta", clear
    quietly ds
    sort `r(varlist)'
    datasignature
    assert "`r(datasignature)'" == "`s1'" & "`s1'" != ""
}
if _rc == 0 {
    display as result "  PASS: flow does not alter the output dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: flow side-channel purity (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

* ===== Summary =====
display as result _newline "attrition/flow report validation Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: validation_flow tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
