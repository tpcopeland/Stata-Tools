*! validation_pyattach_known_truth.do Version 1.0.0  2026/08/12
*! Hand-computed denominator and orphan validation for pyattach
*! Author: Timothy P Copeland, Karolinska Institutet

version 16.0
clear all
capture log close _all
log using "validation_pyattach_known_truth.log", replace text

do "_pygrid_qa_common.do"
_pygrid_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0
local d2010 = td(01jan2010)
local e2010 = td(31dec2010)
local d2011 = td(01jan2011)
local e2011 = td(31dec2011)
local d2012 = td(01jan2012)
local e2012 = td(31dec2012)

**# Denominator regression

**## Ten persons by three years retain 26 zero-event rows
capture noisily {
    tempfile events
    clear
    input long id double(event_date)
        1 18263
        2 18628
        3 18993
        4 18263
    end
    save `events'
    _pygrid_make_calendar, n(10) start(`d2010') end(`e2012')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    pyattach using `events', id(id) date(event_date) count(n) orphans(report)
    local n_zero = r(N_zerofilled)
    quietly summarize n, meanonly
    assert !missing(r(mean))
    assert reldif(r(mean), 4 / 30) < 1e-12
    assert _N == 30
    quietly count if n == 0
    assert r(N) == 26
    quietly summarize n if n > 0, meanonly
    assert r(mean) == 1
    assert `n_zero' == 26
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("full-denominator zero-fill regression") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Hand-counted orphan classification
capture noisily {
    tempfile events
    clear
    input long id double(event_date)
        1 18262
        1 18263
        2 18263
        9 18263
    end
    save `events'
    _pygrid_make_calendar, n(2) start(`d2010') end(`e2010')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    pyattach using `events', id(id) date(event_date) count(n) orphans(report)
    assert r(N_eligible) == 4
    assert r(N_attached) == 2
    assert r(N_orphan) == 2
    assert r(N_orphan_nokey) == 1
    assert r(events) == 2
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("hand-counted orphan classes") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Boundary dates conserve all eligible events
capture noisily {
    tempfile events
    clear
    input long id double(event_date)
        1 18263
        1 18627
        1 18628
        1 18992
    end
    save `events'
    _pygrid_make_calendar, n(1) start(`d2010') end(`e2011')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    pyattach using `events', id(id) date(event_date) count(n) orphans(report)
    sort period
    assert n[1] == 2 & n[2] == 2
    assert r(N_attached) == r(N_eligible)
    assert r(N_orphan) == 0
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("boundary-event conservation") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Filtered numerator has exact overall rate
capture noisily {
    tempfile events
    clear
    input long id double(event_date) byte er
        1 18263 1
        1 18264 0
        2 18265 1
        2 18266 0
    end
    save `events'
    _pygrid_make_calendar, n(2) start(`d2010') end(`e2010')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    quietly summarize person_years, meanonly
    local total_py = r(sum)
    pyattach using `events', id(id) date(event_date) count(n_er) rate(er_rate) ///
        if(er == 1) orphans(report)
    assert r(events) == 2
    assert !missing(r(rate_overall), 2 / `total_py')
    assert reldif(r(rate_overall), 2 / `total_py') < 1e-12
    quietly summarize n_er, meanonly
    assert r(sum) == 2
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("filtered-numerator exact rate") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## All-missing sum convention differs only by nozerofill
capture noisily {
    tempfile events
    clear
    set obs 1
    generate long id = 1
    generate double event_date = `d2010'
    generate double cost = .
    save `events'
    _pygrid_make_calendar, n(1) start(`d2010') end(`e2010')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    pyattach using `events', id(id) date(event_date) sum(cost total_default) orphans(report)
    assert total_default == 0
    pyattach using `events', id(id) date(event_date) sum(cost total_missing) ///
        nozerofill orphans(report)
    assert missing(total_missing)
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("all-missing sum convention") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Shifted bucket cannot attach an event to a neighboring period
capture noisily {
    tempfile events
    clear
    set obs 1
    generate long id = 1
    generate double event_date = td(31dec2010)
    save `events'
    _pygrid_make_calendar, n(1) start(`=td(01jan2010)') end(`=td(31dec2011)')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    pyattach using `events', id(id) date(event_date) count(n) orphans(report)
    sort period
    assert n[1] == 1 & n[2] == 0
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("bucket guard boundary truth") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# Summary
capture noisily _pygrid_result validation_pyattach_known_truth ///
    `test_count' `pass_count' `fail_count' `skip_count'
local suite_rc = _rc
capture log close
if `suite_rc' exit `suite_rc'
