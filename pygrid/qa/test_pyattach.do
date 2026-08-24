*! test_pyattach.do Version 1.0.0  2026/08/12
*! Functional and error-path tests for pyattach
*! Author: Timothy P Copeland, Karolinska Institutet

version 16.0
clear all
capture log close _all
log using "test_pyattach.log", replace text

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

**# Measures and attachment behavior

**## Count, sum, any, max, rate, and zero fill
capture noisily {
    tempfile events
    clear
    input long eid double(event_date cost) byte icu
        1 18263 10 0
        1 18627 20 1
        1 18628 30 0
    end
    save `events'
    _pygrid_make_calendar, n(2) start(`d2010') end(`e2012')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    pyattach using `events', id(eid) date(event_date) count(n) ///
        sum(cost total_cost) any(had) max(icu any_icu) rate(rate) ///
        orphans(report) noisily
    sort id period
    assert _N == 6
    assert n[1] == 2 & n[2] == 1
    assert total_cost[1] == 30 & total_cost[2] == 30
    assert had[1] == 1 & any_icu[1] == 1
    assert n[4] == 0 & total_cost[4] == 0 & had[4] == 0
    assert !missing(rate[1], 2 / person_years[1])
    assert reldif(rate[1], 2 / person_years[1]) < 1e-12
    assert r(N_attached) == 3 & r(N_zerofilled) == 4
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("all measures and zero fill") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## if filters numerator but leaves denominator unchanged
capture noisily {
    tempfile events grid
    clear
    input long id double(event_date) byte include
        1 18263 1
        1 18264 0
        2 18265 0
    end
    save `events'
    _pygrid_make_calendar, n(2) start(`d2010') end(`e2010')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    local N_before = _N
    quietly summarize person_years, meanonly
    local py_before = r(sum)
    pyattach using `events', id(id) date(event_date) count(n_include) ///
        if(include == 1) orphans(report)
    local n_eligible = r(N_eligible)
    local n_attached = r(N_attached)
    assert _N == `N_before'
    quietly summarize person_years, meanonly
    assert !missing(r(sum), `py_before')
    assert reldif(r(sum), `py_before') < 1e-12
    assert `n_eligible' == 1 & `n_attached' == 1
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("using-file if leaves denominator unchanged") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## nozerofill and all-missing sum remain missing
capture noisily {
    tempfile events
    clear
    set obs 1
    generate long id = 1
    generate double event_date = `d2010'
    generate double cost = .a
    save `events'
    _pygrid_make_calendar, n(2) start(`d2010') end(`e2010')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    pyattach using `events', id(id) date(event_date) sum(cost total_cost) ///
        nozerofill orphans(report)
    sort id
    assert missing(total_cost[1])
    assert missing(total_cost[2])
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("nozerofill all-missing sum") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Repeated calls accumulate and preserve characteristics
capture noisily {
    tempfile events
    clear
    input long id double(event_date) byte kind
        1 18263 1
        1 18264 0
    end
    save `events'
    _pygrid_make_calendar, n(1) start(`d2010') end(`e2010')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    pyattach using `events', id(id) date(event_date) count(all_events) orphans(report)
    pyattach using `events', id(id) date(event_date) count(kind_events) ///
        if(kind == 1) orphans(report)
    assert all_events == 2 & kind_events == 1
    local stamp : char _dta[pygrid_version]
    assert "`stamp'" == "1.0.0"
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("repeated attachment and stamp persistence") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## String identifier and different using name
capture noisily {
    tempfile events
    clear
    input str12 event_id double(event_date)
        "person-a" 18263
    end
    save `events'
    clear
    input str12 id double(window_start window_end)
        "person-a" 18263 18627
        "person-b" 18263 18627
    end
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    pyattach using `events', id(event_id) date(event_date) count(n) orphans(report)
    sort id
    assert n[1] == 1 & n[2] == 0
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("string identifier with renamed using key") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Anniversary bucket assignment
capture noisily {
    tempfile events
    clear
    set obs 3
    generate long id = 1
    generate double event_date = cond(_n == 1, `d2010', ///
        cond(_n == 2, floor(`d2010' + 365.25), floor(`d2010' + 2 * 365.25)))
    save `events'
    clear
    set obs 1
    generate long id = 1
    generate double origin = `d2010'
    generate double end = td(15apr2013)
    pygrid, id(id) start(origin) end(end) axis(anniversary) origin(origin)
    pyattach using `events', id(id) date(event_date) count(n) orphans(report)
    sort period
    assert n[1] == 1 & n[2] == 1 & n[3] == 1
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("anniversary event buckets") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Repeated episodes sharing an identifier and period attach by interval
capture noisily {
    tempfile events orphan_file
    clear
    input long id double(event_date value)
        1 18267 10
        1 18353 20
        1 18449 30
    end
    save `events'
    clear
    input long id double(window_start window_end origin) byte episode
        1 18263 18272 18263 1
        1 18445 18454 18445 2
    end
    pygrid, id(id) start(window_start) end(window_end) axis(calendar) ///
        keep(episode origin)
    pyattach using `events', id(id) date(event_date) count(n) ///
        sum(value total) orphans(save(`orphan_file'))
    sort episode
    assert _N == 2
    assert n[1] == 1 & n[2] == 1
    assert total[1] == 10 & total[2] == 30
    assert r(N_attached) == 2 & r(N_orphan) == 1
    preserve
    use `orphan_file', clear
    assert _N == 1 & event_date == td(01apr2010)
    restore

    clear
    input long id double(window_start window_end origin) byte episode
        1 18263 18272 18263 1
        1 18445 18454 18445 2
    end
    pygrid, id(id) start(window_start) end(window_end) axis(anniversary) ///
        origin(origin) keep(episode)
    pyattach using `events', id(id) date(event_date) count(n_anniv) ///
        orphans(report)
    sort episode
    assert n_anniv[1] == 1 & n_anniv[2] == 1
    assert r(N_attached) == 2 & r(N_orphan) == 1
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("same-id same-period episode attachment") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# Orphans and errors

**## Default orphan error preserves denominator and posts accounting
capture noisily {
    tempfile events before
    clear
    input long id double(event_date)
        1 18262
    end
    save `events'
    _pygrid_make_calendar, n(1) start(`d2010') end(`e2010')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    save `before'
    capture noisily pyattach using `events', id(id) date(event_date) count(n)
    assert _rc == 459
    assert r(N_orphan) == 1 & r(N_attached) == 0
    cf _all using `before', all
    capture confirm variable n
    assert _rc == 111
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("orphan error preserves grid") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## All-orphan reporting returns the full zero-filled denominator
capture noisily {
    local using_path "pygrid using suffix"
    capture erase "`using_path'.dta"
    clear
    input long id double(event_date)
        1 18262
    end
    save "`using_path'.dta"
    _pygrid_make_calendar, n(1) start(`d2010') end(`e2010')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    pyattach using "`using_path'", id(id) date(event_date) count(n) any(had_event) ///
        orphans(report)
    assert _N == 1
    assert n == 0 & had_event == 0
    assert r(N_attached) == 0 & r(N_orphan) == 1
    assert r(N_zerofilled) == 1
    erase "`using_path'.dta"
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("all-orphan report zero fills") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Boundary events attach once and outside dates report as orphans
capture noisily {
    tempfile events
    clear
    input long id double(event_date)
        1 18263
        1 18627
        1 18628
        1 18262
    end
    save `events'
    _pygrid_make_calendar, n(1) start(`d2010') end(`e2011')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    pyattach using `events', id(id) date(event_date) count(n) orphans(report)
    sort period
    assert n[1] == 2 & n[2] == 1
    assert r(N_attached) == 3 & r(N_orphan) == 1
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("boundary assignment and orphan reporting") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Orphan save writes exactly original orphan rows
capture noisily {
    tempfile events orphan_file
    clear
    input long event_id double(event_date value)
        1 18263 10
        1 18262 20
        9 18263 30
    end
    save `events'
    _pygrid_make_calendar, n(1) start(`d2010') end(`e2010')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    local spaced_path "pygrid orphan path with space.dta"
    capture erase "`spaced_path'"
    pyattach using `events', id(event_id) date(event_date) count(n) ///
        orphans(save("`spaced_path'"))
    confirm file "`spaced_path'"
    copy "`spaced_path'" `orphan_file'
    erase "`spaced_path'"
    preserve
    use `orphan_file', clear
    assert _N == 2
    assert value[1] + value[2] == 50
    restore
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("orphan save payload") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Missing keys and dates are ineligible, not orphans
capture noisily {
    tempfile events
    clear
    input long id double(event_date)
        1 18263
        . 18263
        1 .a
    end
    save `events'
    _pygrid_make_calendar, n(1) start(`d2010') end(`e2010')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    pyattach using `events', id(id) date(event_date) count(n) orphans(report)
    assert r(N_using) == 3
    assert r(N_eligible) == 1
    assert r(N_orphan) == 0
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("ineligible missing keys and dates") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## An empty eligible subset returns the unchanged zero-filled denominator
capture noisily {
    tempfile events orphan_file
    clear
    input long id double(event_date value) byte include
        1 18263 10 0
        2 18264 20 0
    end
    save `events'
    _pygrid_make_calendar, n(2) start(`d2010') end(`e2010')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    pyattach using `events', id(id) date(event_date) count(n) ///
        sum(value total) if(include == 1) orphans(save(`orphan_file'))
    assert _N == 2
    assert n == 0 & total == 0
    assert r(N_using) == 2 & r(N_eligible) == 0
    assert r(N_attached) == 0 & r(N_orphan) == 0
    assert r(N_zerofilled) == 2
    preserve
    use `orphan_file', clear
    assert _N == 0
    confirm variable id event_date value include
    restore
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("empty eligible subset zero fills") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Non-grid data and invalid measure contracts
capture noisily {
    tempfile events
    clear
    set obs 1
    generate id = 1
    generate double event_date = 1
    save `events'
    clear
    set obs 1
    generate id = 1
    capture noisily pyattach using `events', id(id) date(event_date) count(n)
    assert _rc == 459
    _pygrid_make_calendar, n(1) start(1) end(10)
    pygrid, id(id) start(window_start) end(window_end) axis(fixed)
    capture noisily pyattach using `events', id(id) date(event_date) rate(rate)
    assert _rc == 198
    capture noisily pyattach using `events', id(id) date(event_date) ///
        count(dup) any(dup)
    assert _rc == 198
    capture noisily pyattach using `events', id(id) date(id) count(n)
    assert _rc == 198
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("non-grid and measure-contract errors") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Identifier type and datetime errors
capture noisily {
    tempfile string_events tc_events
    clear
    set obs 1
    generate str4 id = "1"
    generate double event_date = 1
    save `string_events'
    clear
    set obs 1
    generate long id = 1
    generate double event_date = clock("01jan2010 00:00", "DMY hm")
    format event_date %tc
    save `tc_events'
    _pygrid_make_calendar, n(1) start(1) end(10)
    pygrid, id(id) start(window_start) end(window_end) axis(fixed)
    capture noisily pyattach using `string_events', id(id) date(event_date) count(n)
    assert _rc == 109
    capture noisily pyattach using `tc_events', id(id) date(event_date) count(n)
    assert _rc == 109
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("using type and datetime errors") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Varabbrev restored on success and error
capture noisily {
    tempfile events
    clear
    set obs 1
    generate id = 1
    generate double event_date = 1
    save `events'
    set varabbrev on
    _pygrid_make_calendar, n(1) start(1) end(10)
    pygrid, id(id) start(window_start) end(window_end) axis(fixed)
    pyattach using `events', id(id) date(event_date) count(n) orphans(report)
    assert "`c(varabbrev)'" == "on"
    capture noisily pyattach using `events', id(id) date(event_date) count(n2) ///
        orphans(bad)
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("pyattach varabbrev restoration") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# Deep-review regressions

**## Exclusive grids do not attach terminal-day events
capture noisily {
    tempfile events
    clear
    set obs 1
    generate long id = 1
    generate double event_date = td(31dec2010)
    save `events'
    _pygrid_make_calendar, n(1) start(`d2010') end(`e2010')
    pygrid, id(id) start(window_start) end(window_end) axis(calendar) ///
        noinclusive pyunit(day)
    pyattach using `events', id(id) date(event_date) count(n) orphans(report)
    assert n == 0
    assert r(N_attached) == 0
    assert r(N_orphan) == 1
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("exclusive terminal-day attachment") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Fractional event dates are rejected without changing the grid
capture noisily {
    tempfile events before
    clear
    set obs 1
    generate long id = 1
    generate double event_date = 1.5
    save `events'
    _pygrid_make_calendar, n(1) start(1) end(2)
    pygrid, id(id) start(window_start) end(window_end) axis(fixed) pyunit(day)
    save `before'
    capture noisily pyattach using `events', id(id) date(event_date) count(n) ///
        orphans(report)
    assert _rc == 459
    cf _all using `before', all
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("fractional event-date rejection") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## Nonmissing person-time corruption is rejected
capture noisily {
    tempfile events before
    clear
    set obs 1
    generate long id = 1
    generate double event_date = 1
    save `events'
    _pygrid_make_calendar, n(1) start(1) end(10)
    pygrid, id(id) start(window_start) end(window_end) axis(fixed) pyunit(day)
    replace person_years = 1000
    save `before'
    capture noisily pyattach using `events', id(id) date(event_date) ///
        count(n) rate(rate) orphans(report)
    assert _rc == 459
    cf _all using `before', all
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("person-time integrity rejection") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**## strL identifiers receive the documented input error
capture noisily {
    tempfile events before
    clear
    set obs 1
    generate strL event_id = "person-a"
    generate double event_date = 1
    save `events'
    clear
    set obs 1
    generate str12 id = "person-a"
    generate double window_start = 1
    generate double window_end = 2
    pygrid, id(id) start(window_start) end(window_end) axis(fixed) pyunit(day)
    save `before'
    capture noisily pyattach using `events', id(event_id) date(event_date) ///
        count(n) orphans(report)
    assert _rc == 109
    cf _all using `before', all
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("strL identifier rejection") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# Summary
capture noisily _pygrid_result test_pyattach `test_count' `pass_count' `fail_count' `skip_count'
local suite_rc = _rc
capture log close
if `suite_rc' exit `suite_rc'
