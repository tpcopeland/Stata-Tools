clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "validation_tvexpose_priority.log", replace nomsg

* Shared scaffold: test globals + helpers + sandboxed install bootstrap
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

* ---------------------------------------------------------------------------
* Known-answer and independent-oracle suite for tvexpose priority().
*
* Contract: on every day of the study window the exposure is the value of the
* highest-priority episode active that day, or reference() if none is. A
* lower-priority episode resumes when a higher-priority one ends.
*
* Through 1.17.6 priority() ran an iterative pairwise truncation that
*   (a) never resumed a lower-priority episode after a higher one inside it
*       ended -- those days were silently reported as reference, rc 0; and
*   (b) never resolved two overlapping episodes of the same value when a
*       different value started between them, so the tiling invariant fired
*       and the call failed with r(498).
* Tests 1 and 2 are those two geometries with exact expected rows. Test 5 is
* an oracle that shares no code with tvexpose: it expands every clipped
* episode to person-days, picks the top-ranked value per day, and compares.
* ---------------------------------------------------------------------------

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as result "tvtools QA: tvexpose priority() -- $S_DATE $S_TIME"

capture program drop _prio_expect
program define _prio_expect
    * Assert the in-memory output equals the matrix rows (start stop value).
    args M
    sort id rx_start
    assert _N == rowsof(`M')
    forvalues i = 1/`=rowsof(`M')' {
        assert rx_start[`i'] == `M'[`i', 1]
        assert rx_stop[`i'] == `M'[`i', 2]
        assert tv_drug[`i'] == `M'[`i', 3]
    }
end

**# Test 1: lower priority resumes after a nested higher-priority episode

local ++test_count
capture {
    tempfile m1 e1
    clear
    input long id double(entry exit)
        1 90 160
    end
    save "`m1'"
    clear
    input long id double(rx_start rx_stop) byte drug
        1 100 150 1
        1 120 130 2
    end
    save "`e1'"

    use "`m1'", clear
    tvexpose using "`e1'", id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) entry(entry) exit(exit) priority(2 1)
    matrix X = (90, 99, 0 \ 100, 119, 1 \ 120, 130, 2 \ 131, 150, 1 \ 151, 160, 0)
    _prio_expect X
}
if _rc == 0 {
    display as result "  PASS 1: lower-priority exposure resumes after higher ends"
    local ++pass_count
}
else {
    display as error "  FAIL 1: priority() resumption (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

**# Test 2: nested same-value episodes split by a lower-priority start

local ++test_count
capture {
    tempfile m2 e2
    clear
    input long id double(entry exit)
        1 100 200
    end
    save "`m2'"
    clear
    input long id double(rx_start rx_stop) byte drug
        1  92 113 3
        1 157 164 2
        1 159 170 1
        1 160 161 2
    end
    save "`e2'"

    use "`m2'", clear
    tvexpose using "`e2'", id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) entry(entry) exit(exit) priority(3 2 1)
    assert r(total_time) == 101
    matrix X = (100, 113, 3 \ 114, 156, 0 \ 157, 164, 2 \ 165, 170, 1 \ 171, 200, 0)
    _prio_expect X
}
if _rc == 0 {
    display as result "  PASS 2: nested same-value episodes resolve (was r(498))"
    local ++pass_count
}
else {
    display as error "  FAIL 2: nested same-value priority geometry (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

**# Test 3: a value priority() omits ranks below every listed value

local ++test_count
capture {
    tempfile m3 e3
    clear
    input long id double(entry exit)
        1 100 200
    end
    save "`m3'"
    clear
    input long id double(rx_start rx_stop) byte drug
        1 110 180 3
        1 130 140 1
    end
    save "`e3'"

    use "`m3'", clear
    tvexpose using "`e3'", id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) entry(entry) exit(exit) priority(1 2)
    matrix X = (100, 109, 0 \ 110, 129, 3 \ 130, 140, 1 \ 141, 180, 3 \ 181, 200, 0)
    _prio_expect X
}
if _rc == 0 {
    display as result "  PASS 3: unlisted value yields to listed, then resumes"
    local ++pass_count
}
else {
    display as error "  FAIL 3: unlisted-below-listed precedence (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

**# Test 4: two overlapping unlisted values have no order -> refuse

local ++test_count
capture {
    tempfile m4 e4
    clear
    input long id double(entry exit)
        1 100 200
    end
    save "`m4'"
    clear
    input long id double(rx_start rx_stop) byte drug
        1 110 150 3
        1 140 170 4
        1 120 125 1
    end
    save "`e4'"

    use "`m4'", clear
    quietly datasignature
    local sig0 "`r(datasignature)'"
    capture noisily tvexpose using "`e4'", id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) entry(entry) exit(exit) priority(1 2)
    assert _rc == 498
    quietly datasignature
    assert "`r(datasignature)'" == "`sig0'"

    * Non-overlapping unlisted values are not a conflict.
    use "`e4'", clear
    replace rx_start = 151 if drug == 4
    save "`e4'", replace
    use "`m4'", clear
    tvexpose using "`e4'", id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) entry(entry) exit(exit) priority(1 2)
    matrix X = (100, 109, 0 \ 110, 119, 3 \ 120, 125, 1 \ 126, 150, 3 \ ///
        151, 170, 4 \ 171, 200, 0)
    _prio_expect X
}
if _rc == 0 {
    display as result "  PASS 4: overlapping unranked values refused, data intact"
    local ++pass_count
}
else {
    display as error "  FAIL 4: unranked-overlap refusal (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

**# Test 5: independent person-day oracle over random geometries

local ++test_count
capture {
    foreach seed in 20261001 7 911 {
        set seed `seed'
        tempfile mas epi expect
        clear
        quietly set obs 250
        generate long id = _n
        generate double entry = 1000 + floor(200 * runiform())
        generate double exit = entry + floor(400 * runiform())
        quietly save "`mas'"

        clear
        quietly set obs 1500
        generate long id = 1 + floor(250 * runiform())
        generate double rx_start = 950 + floor(700 * runiform())
        generate double rx_stop = rx_start + floor(90 * runiform())
        generate byte drug = 1 + floor(4 * runiform())
        quietly save "`epi'"

        * Random full ranking of the four values, highest first.
        clear
        quietly set obs 4
        generate byte v = _n
        generate double u = runiform()
        sort u
        local prio ""
        forvalues i = 1/4 {
            local prio "`prio' `=v[`i']'"
        }

        * Oracle: clip, expand to days, keep the top-ranked value per day.
        use "`epi'", clear
        quietly joinby id using "`mas'"
        quietly replace rx_start = max(rx_start, entry)
        quietly replace rx_stop = min(rx_stop, exit)
        quietly keep if rx_start <= rx_stop
        generate long row = _n
        generate long ndays = rx_stop - rx_start + 1
        quietly expand ndays
        bysort row: generate double day = rx_start + _n - 1
        generate byte key = 0
        local k = 4
        foreach v of local prio {
            quietly replace key = `k' if drug == `v'
            local --k
        }
        bysort id day (key): keep if _n == _N
        keep id day drug
        rename drug want
        quietly save "`expect'"

        use "`mas'", clear
        generate long ndays = exit - entry + 1
        quietly expand ndays
        bysort id: generate double day = entry + _n - 1
        keep id day
        quietly merge 1:1 id day using "`expect'", assert(master match) nogenerate
        quietly replace want = 0 if missing(want)
        quietly save "`expect'", replace

        use "`mas'", clear
        quietly tvexpose using "`epi'", id(id) start(rx_start) stop(rx_stop) ///
            exposure(drug) reference(0) entry(entry) exit(exit) priority(`prio')
        generate long ndays = rx_stop - rx_start + 1
        quietly expand ndays
        bysort id rx_start: generate double day = rx_start + _n - 1
        keep id day tv_drug
        quietly merge 1:1 id day using "`expect'"
        assert _merge == 3
        assert tv_drug == want
        display as text "    seed `seed' priority(`prio'): " _N " person-days match"
    }
}
if _rc == 0 {
    display as result "  PASS 5: person-day oracle agrees on 3 random designs"
    local ++pass_count
}
else {
    display as error "  FAIL 5: person-day oracle (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

**# Test 6: a value listed twice in priority() is refused

local ++test_count
capture {
    tempfile m6 e6
    clear
    input long id double(entry exit)
        1 90 160
    end
    save "`m6'"
    clear
    input long id double(rx_start rx_stop) byte drug
        1 100 150 1
        1 120 130 2
    end
    save "`e6'"

    * Through 1.17.7-pre a duplicate silently took its later rank, so
    * priority(2 1 2) ranked 1 above 2 at rc 0.
    use "`m6'", clear
    quietly datasignature
    local sig0 "`r(datasignature)'"
    set varabbrev on
    capture noisily tvexpose using "`e6'", id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) entry(entry) exit(exit) priority(2 1 2)
    local rc6 = _rc
    local va6 "`c(varabbrev)'"
    set varabbrev off
    assert `rc6' == 198
    assert "`va6'" == "on"
    quietly datasignature
    assert "`r(datasignature)'" == "`sig0'"

    * A range that repeats a value is the same defect.
    capture tvexpose using "`e6'", id(id) start(rx_start) stop(rx_stop) ///
        exposure(drug) reference(0) entry(entry) exit(exit) priority(1/2 1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS 6: duplicate priority() value refused, caller state intact"
    local ++pass_count
}
else {
    display as error "  FAIL 6: duplicate priority() value (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

**# Summary

display as result _newline "tvtools QA tvexpose priority Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: validation_tvexpose_priority tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
