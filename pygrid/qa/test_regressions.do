*! test_regressions.do Version 1.0.1  2026/08/30
*! Regressions from the pygrid 1.0.1 deep review
*! Author: Timothy P Copeland, Karolinska Institutet

version 16.0
clear all
capture log close _all
log using "test_regressions.log", replace text

do "_pygrid_qa_common.do"
_pygrid_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0

**# Source-window validation

**## Reversed source windows fail before mutation
capture noisily {
    clear
    input long id double(window_start window_end)
        1 10 9
        2 10 20
    end
    tempfile before
    save `before'
    set varabbrev on
    capture noisily pygrid, id(id) start(window_start) end(window_end) axis(fixed)
    local call_rc = _rc
    assert `call_rc' == 459
    assert "`c(varabbrev)'" == "on"
    _pygrid_assert_data_equal using `before', order
    set varabbrev off
}
local case_rc = _rc
set varabbrev off
_pygrid_record, rc(`case_rc') name("reversed source windows fail closed") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Coverage restrictions may empty otherwise valid windows
capture noisily {
    clear
    input long id double(window_start window_end coverage_start)
        1 10 20 30
        2 10 20 10
    end
    pygrid, id(id) start(window_start) end(window_end) axis(fixed) ///
        pyunit(day) coverage(coverage_start)
    assert _N == 1
    assert id == 2
    assert r(N_empty_window) == 1
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("restriction-induced empty windows remain supported") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# Stamped-grid integrity

**## Edited period values invalidate the structural signature
capture noisily {
    tempfile events before
    clear
    input long id double event_date
        1 18444
    end
    save `events'
    clear
    input long id double(window_start window_end)
        1 18263 18627
    end
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    replace period = period + 1
    save `before'
    capture noisily pyattach using `events', id(id) date(event_date) ///
        count(n) orphans(report)
    local call_rc = _rc
    assert `call_rc' == 459
    _pygrid_assert_data_equal using `before', order
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("edited period is rejected without mutation") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Coordinated interval and person-time edits still invalidate the grid
capture noisily {
    tempfile events before
    clear
    input long id double event_date
        1 18444
    end
    save `events'
    clear
    input long id double(window_start window_end)
        1 18263 18627
    end
    pygrid, id(id) start(window_start) end(window_end) axis(calendar) pyunit(day)
    replace period_start = period_start + 1
    replace period_stop = period_stop + 1
    replace person_years = period_stop - period_start + 1
    save `before'
    capture noisily pyattach using `events', id(id) date(event_date) ///
        count(n) orphans(report)
    local call_rc = _rc
    assert `call_rc' == 459
    _pygrid_assert_data_equal using `before', order
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("coordinated structural edits are rejected") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Edited metadata invalidates the stamped contract
capture noisily {
    tempfile events before
    clear
    input long id double event_date
        1 18628
    end
    save `events'
    clear
    input long id double(window_start window_end)
        1 18263 18992
    end
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    char _dta[pygrid_width] "2"
    save `before'
    capture noisily pyattach using `events', id(id) date(event_date) ///
        count(n) orphans(report)
    local call_rc = _rc
    assert `call_rc' == 459
    _pygrid_assert_data_equal using `before', order
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("edited grid metadata is rejected") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Row reordering remains valid and caller order is preserved
capture noisily {
    tempfile events
    clear
    input long id double event_date
        1 18444
        2 18809
    end
    save `events'
    clear
    input long id double(window_start window_end)
        1 18263 18992
        2 18263 18992
    end
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    generate long caller_order = _n
    gsort -caller_order
    pyattach using `events', id(id) date(event_date) count(n) orphans(report)
    assert caller_order == _N - _n + 1
    assert n == 1 if (id == 1 & period == 2010) | (id == 2 & period == 2011)
    assert n == 0 if !((id == 1 & period == 2010) | (id == 2 & period == 2011))
    assert r(N_attached) == 2
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("row reordering is signature-stable") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# Calendar anchor

**## Five-month blocks use January 1960 as their exact origin
capture noisily {
    clear
    input long id double(window_start window_end)
        1 18642 18706
    end
    format window_start window_end %td
    pygrid, id(id) start(window_start) end(window_end) axis(calendar) ///
        unit(month) width(5)
    assert _N == 1
    assert period == ym(2010, 11)
    assert period_start == td(15jan2011)
    assert period_stop == td(20mar2011)
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("odd-width month blocks pin the 1960 origin") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# Summary

capture noisily _pygrid_result test_regressions `test_count' `pass_count' ///
    `fail_count' `skip_count'
local suite_rc = _rc
capture log close _all
if `suite_rc' exit `suite_rc'
